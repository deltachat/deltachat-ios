#include <assert.h>
#include <netpgp-extra.h>
#include "dc_context.h"
#include "dc_mimeparser.h"
#include "dc_mimefactory.h"
#include "dc_imap.h"
#include "dc_job.h"
#include "dc_array.h"
#include "dc_apeerstate.h"


/*******************************************************************************
 * Add contacts to database on receiving messages
 ******************************************************************************/


static void add_or_lookup_contact_by_addr(dc_context_t* context, const char* display_name_enc, const char* addr_spec, int origin, dc_array_t* ids, int* check_self)
{
	/* is addr_spec equal to SELF? */
	int dummy = 0;
	if (check_self==NULL) { check_self = &dummy; }

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || addr_spec==NULL) {
		return;
	}

	*check_self = 0;

	char* self_addr = dc_sqlite3_get_config(context->sql, "configured_addr", "");
		if (dc_addr_cmp(self_addr, addr_spec)==0) {
			*check_self = 1;
		}
	free(self_addr);

	if (*check_self) {
		return;
	}

	/* add addr_spec if missing, update otherwise */
	char* display_name_dec = NULL;
	if (display_name_enc) {
		display_name_dec = dc_decode_header_words(display_name_enc);
		dc_normalize_name(display_name_dec);
	}

	uint32_t row_id = dc_add_or_lookup_contact(context, display_name_dec /*can be NULL*/, addr_spec, origin, NULL);

	free(display_name_dec);

	if (row_id) {
		if (!dc_array_search_id(ids, row_id, NULL)) {
			dc_array_add_id(ids, row_id);
		}
	}
}


static void dc_add_or_lookup_contacts_by_mailbox_list(dc_context_t* context, const struct mailimf_mailbox_list* mb_list, int origin, dc_array_t* ids, int* check_self)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || mb_list==NULL) {
		return;
	}

	for (clistiter* cur = clist_begin(mb_list->mb_list); cur!=NULL ; cur=clist_next(cur)) {
		struct mailimf_mailbox* mb = (struct mailimf_mailbox*)clist_content(cur);
		if (mb) {
			add_or_lookup_contact_by_addr(context, mb->mb_display_name, mb->mb_addr_spec, origin, ids, check_self);
		}
	}
}


static void dc_add_or_lookup_contacts_by_address_list(dc_context_t* context, const struct mailimf_address_list* adr_list, int origin, dc_array_t* ids, int* check_self)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || adr_list==NULL /*may be NULL eg. if bcc is given as `Bcc: \n` in the header */) {
		return;
	}

	for (clistiter* cur = clist_begin(adr_list->ad_list); cur!=NULL ; cur=clist_next(cur)) {
		struct mailimf_address* adr = (struct mailimf_address*)clist_content(cur);
		if (adr) {
			if (adr->ad_type==MAILIMF_ADDRESS_MAILBOX) {
				struct mailimf_mailbox* mb = adr->ad_data.ad_mailbox; /* can be NULL */
				if (mb) {
					add_or_lookup_contact_by_addr(context, mb->mb_display_name, mb->mb_addr_spec, origin, ids, check_self);
				}
			}
			else if (adr->ad_type==MAILIMF_ADDRESS_GROUP) {
				struct mailimf_group* group = adr->ad_data.ad_group; /* can be NULL */
				if (group && group->grp_mb_list /*can be NULL*/) {
					dc_add_or_lookup_contacts_by_mailbox_list(context, group->grp_mb_list, origin, ids, check_self);
				}
			}
		}
	}
}


/*******************************************************************************
 * Check if a message is a reply to a known message (messenger or non-messenger)
 ******************************************************************************/


static int is_known_rfc724_mid(dc_context_t* context, const char* rfc724_mid)
{
	int is_known = 0;
	if (rfc724_mid) {
		sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
			"SELECT m.id FROM msgs m "
			" LEFT JOIN chats c ON m.chat_id=c.id "
			" WHERE m.rfc724_mid=? "
			" AND m.chat_id>" DC_STRINGIFY(DC_CHAT_ID_LAST_SPECIAL)
			" AND c.blocked=0;");
		sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
		if (sqlite3_step(stmt)==SQLITE_ROW) {
			is_known = 1;
		}
		sqlite3_finalize(stmt);
	}
	return is_known;
}


static int is_known_rfc724_mid_in_list(dc_context_t* context, const clist* mid_list)
{
	if (mid_list) {
		clistiter* cur;
		for (cur = clist_begin(mid_list); cur!=NULL ; cur=clist_next(cur)) {
			if (is_known_rfc724_mid(context, clist_content(cur))) {
				return 1;
			}
		}
	}

	return 0;
}


static int dc_is_reply_to_known_message(dc_context_t* context, dc_mimeparser_t* mime_parser)
{
	/* check if the message is a reply to a known message; the replies are identified by the Message-ID from
	`In-Reply-To`/`References:` (to support non-Delta-Clients) or from `Chat-Predecessor:` (Delta clients, see comment in dc_chat.c) */

	struct mailimf_optional_field* optional_field = NULL;
	if ((optional_field=dc_mimeparser_lookup_optional_field(mime_parser, "Chat-Predecessor"))!=NULL)
	{
		if (is_known_rfc724_mid(context, optional_field->fld_value)) {
			return 1;
		}
	}

	struct mailimf_field* field = NULL;
	if ((field=dc_mimeparser_lookup_field(mime_parser, "In-Reply-To"))!=NULL
	 && field->fld_type==MAILIMF_FIELD_IN_REPLY_TO)
	{
		struct mailimf_in_reply_to* fld_in_reply_to = field->fld_data.fld_in_reply_to;
		if (fld_in_reply_to) {
			if (is_known_rfc724_mid_in_list(context, field->fld_data.fld_in_reply_to->mid_list)) {
				return 1;
			}
		}
	}

	if ((field=dc_mimeparser_lookup_field(mime_parser, "References"))!=NULL
	 && field->fld_type==MAILIMF_FIELD_REFERENCES)
	{
		struct mailimf_references* fld_references = field->fld_data.fld_references;
		if (fld_references) {
			if (is_known_rfc724_mid_in_list(context, field->fld_data.fld_references->mid_list)) {
				return 1;
			}
		}
	}

	return 0;
}


/*******************************************************************************
 * Misc. Tools
 ******************************************************************************/


static void calc_timestamps(dc_context_t* context, uint32_t chat_id, uint32_t from_id, time_t message_timestamp, int is_fresh_msg,
                               time_t* sort_timestamp, time_t* sent_timestamp, time_t* rcvd_timestamp)
{
	*rcvd_timestamp = time(NULL);

	*sent_timestamp = message_timestamp;
	if (*sent_timestamp > *rcvd_timestamp /* no sending times in the future */) {
		*sent_timestamp = *rcvd_timestamp;
	}

	*sort_timestamp = message_timestamp; /* truncatd below to smeared time (not to _now_ to keep the order) */

	/* use the last message from another user (including SELF) as the MINIMUM for sort_timestamp;
	this is to force fresh messages popping up at the end of the list.
	(we do this check only for fresh messages, other messages may pop up whereever, this may happen eg. when restoring old messages or synchronizing different clients) */
	if (is_fresh_msg)
	{
		sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
			"SELECT MAX(timestamp) FROM msgs WHERE chat_id=? and from_id!=? AND timestamp>=?");
		sqlite3_bind_int  (stmt,  1, chat_id);
		sqlite3_bind_int  (stmt,  2, from_id);
		sqlite3_bind_int64(stmt,  3, *sort_timestamp);
		if (sqlite3_step(stmt)==SQLITE_ROW)
		{
			time_t last_msg_time = sqlite3_column_int64(stmt, 0);
			if (last_msg_time > 0 /* may happen as we do not check against sqlite3_column_type()!=SQLITE_NULL */) {
				if (*sort_timestamp <= last_msg_time) {
					*sort_timestamp = last_msg_time+1; /* this may result in several incoming messages having the same
					                                     one-second-after-the-last-other-message-timestamp.  however, this is no big deal
					                                     as we do not try to recrete the order of bad-date-messages and as we always order by ID as second criterion */
				}
			}
		}
		sqlite3_finalize(stmt);
	}

	/* use the (smeared) current time as the MAXIMUM */
	if (*sort_timestamp >= dc_smeared_time(context)) {
		*sort_timestamp = dc_create_smeared_timestamp(context);
	}
}


static dc_array_t* search_chat_ids_by_contact_ids(dc_context_t* context, const dc_array_t* unsorted_contact_ids)
{
	/* searches chat_id's by the given contact IDs, may return zero, one or more chat_id's */
	sqlite3_stmt* stmt = NULL;
	dc_array_t*   contact_ids = dc_array_new(context, 23);
	char*         contact_ids_str = NULL;
	char*         q3 = NULL;
	dc_array_t*   chat_ids = dc_array_new(context, 23);

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	/* copy array, remove duplicates and SELF, sort by ID */
	{
		int i, iCnt = dc_array_get_cnt(unsorted_contact_ids);
		if (iCnt <= 0) {
			goto cleanup;
		}

		for (i = 0; i < iCnt; i++) {
			uint32_t curr_id = dc_array_get_id(unsorted_contact_ids, i);
			if (curr_id!=DC_CONTACT_ID_SELF && !dc_array_search_id(contact_ids, curr_id, NULL)) {
				dc_array_add_id(contact_ids, curr_id);
			}
		}

		if (dc_array_get_cnt(contact_ids)==0) {
			goto cleanup;
		}

		dc_array_sort_ids(contact_ids); /* for easy comparison, we also sort the sql result below */
	}

	/* collect all possible chats with the contact count as the data (as contact_ids have no doubles, this is sufficient) */
	contact_ids_str = dc_array_get_string(contact_ids, ",");
	q3 = sqlite3_mprintf("SELECT DISTINCT cc.chat_id, cc.contact_id "
	                     " FROM chats_contacts cc "
	                     " LEFT JOIN chats c ON c.id=cc.chat_id "
	                     " WHERE cc.chat_id IN(SELECT chat_id FROM chats_contacts WHERE contact_id IN(%s))"
	                     "   AND c.type=" DC_STRINGIFY(DC_CHAT_TYPE_GROUP) /* no verified groups and no single chats (which are equal to a group with a single member and without SELF) */
	                     "   AND cc.contact_id!=" DC_STRINGIFY(DC_CONTACT_ID_SELF) /* ignore SELF, we've also removed it above - if the user has left the group, it is still the same group */
	                     " ORDER BY cc.chat_id, cc.contact_id;",
	                     contact_ids_str);
	stmt = dc_sqlite3_prepare(context->sql, q3);
	{
		uint32_t last_chat_id = 0, matches = 0, mismatches = 0;

		while (sqlite3_step(stmt)==SQLITE_ROW)
		{
			uint32_t chat_id    = sqlite3_column_int(stmt, 0);
			uint32_t contact_id = sqlite3_column_int(stmt, 1);

			if (chat_id!=last_chat_id) {
				if (matches==dc_array_get_cnt(contact_ids) && mismatches==0) {
					dc_array_add_id(chat_ids, last_chat_id);
				}
				last_chat_id = chat_id;
				matches = 0;
				mismatches = 0;
			}

			if (contact_id==dc_array_get_id(contact_ids, matches)) {
				matches++;
			}
			else {
				mismatches++;
			}
		}

		if (matches==dc_array_get_cnt(contact_ids) && mismatches==0) {
			dc_array_add_id(chat_ids, last_chat_id);
		}
	}

cleanup:
	sqlite3_finalize(stmt);
	free(contact_ids_str);
	dc_array_unref(contact_ids);
	sqlite3_free(q3);
	return chat_ids;
}


static char* create_adhoc_grp_id(dc_context_t* context, dc_array_t* member_ids /*including SELF*/)
{
	/* algorithm:
	- sort normalized, lowercased, e-mail addresses alphabetically
	- put all e-mail addresses into a single string, separate the addresss by a single comma
	- sha-256 this string (without possibly terminating null-characters)
	- encode the first 64 bits of the sha-256 output as lowercase hex (results in 16 characters from the set [0-9a-f])
	 */
	dc_array_t*     member_addrs = dc_array_new(context, 23);
	char*           member_ids_str = dc_array_get_string(member_ids, ",");
	sqlite3_stmt*   stmt = NULL;
	char*           q3 = NULL;
	char*           addr = NULL;
	int             i = 0;
	int             iCnt = 0;
	uint8_t*        binary_hash = NULL;
	char*           ret = NULL;
	dc_strbuilder_t member_cs;
	dc_strbuilder_init(&member_cs, 0);

	/* collect all addresses and sort them */
	q3 = sqlite3_mprintf("SELECT addr FROM contacts WHERE id IN(%s) AND id!=" DC_STRINGIFY(DC_CONTACT_ID_SELF), member_ids_str);
	stmt = dc_sqlite3_prepare(context->sql, q3);
	addr = dc_sqlite3_get_config(context->sql, "configured_addr", "no-self");
	dc_strlower_in_place(addr);
	dc_array_add_ptr(member_addrs, addr);
	while (sqlite3_step(stmt)==SQLITE_ROW) {
		addr = dc_strdup((const char*)sqlite3_column_text(stmt, 0));
		dc_strlower_in_place(addr);
		dc_array_add_ptr(member_addrs, addr);
	}
	dc_array_sort_strings(member_addrs);

	/* build a single, comma-separated (cs) string from all addresses */
	iCnt = dc_array_get_cnt(member_addrs);
	for (i = 0; i < iCnt; i++) {
		if (i) { dc_strbuilder_cat(&member_cs, ","); }
		dc_strbuilder_cat(&member_cs, (const char*)dc_array_get_ptr(member_addrs, i));
	}

	/* make sha-256 from the string */
	{
		pgp_hash_t hasher;
		pgp_hash_sha256(&hasher);
		hasher.init(&hasher);
		hasher.add(&hasher, (const uint8_t*)member_cs.buf, strlen(member_cs.buf));
		binary_hash = malloc(hasher.size);
		hasher.finish(&hasher, binary_hash);
	}

	/* output the first 8 bytes as 16 hex-characters - CAVE: if the lenght changes here, also adapt dc_extract_grpid_from_rfc724_mid() */
	ret = calloc(1, 256);
	for (i = 0; i < 8; i++) {
		sprintf(&ret[i*2], "%02x", (int)binary_hash[i]);
	}

	/* cleanup */
	dc_array_free_ptr(member_addrs);
	dc_array_unref(member_addrs);
	free(member_ids_str);
	free(binary_hash);
	sqlite3_finalize(stmt);
	sqlite3_free(q3);
	free(member_cs.buf);
	return ret;
}


static uint32_t create_group_record(dc_context_t* context, const char* grpid, const char* grpname, int create_blocked, int create_verified)
{
	uint32_t      chat_id = 0;
	sqlite3_stmt* stmt = NULL;

	stmt = dc_sqlite3_prepare(context->sql,
		"INSERT INTO chats (type, name, grpid, blocked) VALUES(?, ?, ?, ?);");
	sqlite3_bind_int (stmt, 1, create_verified? DC_CHAT_TYPE_VERIFIED_GROUP : DC_CHAT_TYPE_GROUP);
	sqlite3_bind_text(stmt, 2, grpname, -1, SQLITE_STATIC);
	sqlite3_bind_text(stmt, 3, grpid, -1, SQLITE_STATIC);
	sqlite3_bind_int (stmt, 4, create_blocked);
	if (sqlite3_step(stmt)!=SQLITE_DONE) {
		goto cleanup;
	}
	chat_id = dc_sqlite3_get_rowid(context->sql, "chats", "grpid", grpid);

cleanup:
	sqlite3_finalize(stmt);
	return chat_id;
}


/*******************************************************************************
 * Handle groups for received messages
 ******************************************************************************/


static void create_or_lookup_adhoc_group(dc_context_t* context, dc_mimeparser_t* mime_parser, int create_blocked,
                                           int32_t from_id, const dc_array_t* to_ids,/*does not contain SELF*/
                                           uint32_t* ret_chat_id, int* ret_chat_id_blocked)
{
	/* if we're here, no grpid was found, check there is an existing ad-hoc
	group matching the to-list or if we can create one */
	dc_array_t*    member_ids = NULL;
	uint32_t       chat_id = 0;
	int            chat_id_blocked = 0;
	int            i = 0;
	dc_array_t*    chat_ids = NULL;
	char*          chat_ids_str = NULL;
	char*          q3 = NULL;
	sqlite3_stmt*  stmt = NULL;
	char*          grpid = NULL;
	char*          grpname = NULL;

	/* build member list from the given ids */
	if (dc_array_get_cnt(to_ids)==0 || dc_mimeparser_is_mailinglist_message(mime_parser)) {
		goto cleanup; /* too few contacts or a mailinglist */
	}
	member_ids = dc_array_duplicate(to_ids);
	if (!dc_array_search_id(member_ids, from_id, NULL))            { dc_array_add_id(member_ids, from_id); }
	if (!dc_array_search_id(member_ids, DC_CONTACT_ID_SELF, NULL)) { dc_array_add_id(member_ids, DC_CONTACT_ID_SELF); }
	if (dc_array_get_cnt(member_ids) < 3) {
		goto cleanup; /* too few contacts given */
	}

	/* check if the member list matches other chats, if so, choose the one with the most recent activity */
	chat_ids = search_chat_ids_by_contact_ids(context, member_ids);
	if (dc_array_get_cnt(chat_ids)>0) {
		chat_ids_str = dc_array_get_string(chat_ids, ",");
		q3 = sqlite3_mprintf("SELECT c.id, c.blocked "
							 " FROM chats c "
							 " LEFT JOIN msgs m ON m.chat_id=c.id "
							 " WHERE c.id IN(%s) "
							 " ORDER BY m.timestamp DESC, m.id DESC "
							 " LIMIT 1;",
							 chat_ids_str);
		stmt = dc_sqlite3_prepare(context->sql, q3);
		if (sqlite3_step(stmt)==SQLITE_ROW) {
			chat_id         = sqlite3_column_int(stmt, 0);
			chat_id_blocked = sqlite3_column_int(stmt, 1);
			goto cleanup; /* success, chat found */
		}
	}

	/* we do not check if the message is a reply to another group, this may result in
	chats with unclear member list. instead we create a new group in the following lines ... */

	/* create a new ad-hoc group
	- there is no need to check if this group exists; otherwise we would have catched it above */
	if ((grpid = create_adhoc_grp_id(context, member_ids))==NULL) {
		goto cleanup;
	}

	/* use subject as initial chat name */
	if (mime_parser->subject && mime_parser->subject[0]) {
		grpname = dc_strdup(mime_parser->subject);
	}
	else {
		grpname = dc_stock_str_repl_int(context, DC_STR_MEMBER,  dc_array_get_cnt(member_ids));
	}

	/* create group record */
	chat_id = create_group_record(context, grpid, grpname, create_blocked, 0);
	chat_id_blocked = create_blocked;
	for (i = 0; i < dc_array_get_cnt(member_ids); i++) {
		dc_add_to_chat_contacts_table(context, chat_id, dc_array_get_id(member_ids, i));
	}

	context->cb(context, DC_EVENT_CHAT_MODIFIED, chat_id, 0);

cleanup:
	dc_array_unref(member_ids);
	dc_array_unref(chat_ids);
	free(chat_ids_str);
	free(grpid);
	free(grpname);
	sqlite3_finalize(stmt);
	sqlite3_free(q3);
	if (ret_chat_id)         { *ret_chat_id         = chat_id; }
	if (ret_chat_id_blocked) { *ret_chat_id_blocked = chat_id_blocked; }
}


static int check_verified_properties(dc_context_t* context, dc_mimeparser_t* mimeparser,
                                       uint32_t from_id, const dc_array_t* to_ids)
{
	int              everythings_okay = 0;
	dc_contact_t*    contact = dc_contact_new(context);
	dc_apeerstate_t* peerstate = dc_apeerstate_new(context);
	char*            to_ids_str = NULL;
	char*            q3 = NULL;
	sqlite3_stmt*    stmt = NULL;

	// ensure, the contact is verified
	if (!dc_contact_load_from_db(contact, context->sql, from_id)
	 || !dc_apeerstate_load_by_addr(peerstate, context->sql, contact->addr)
	 || dc_contact_is_verified_ex(contact, peerstate) < DC_BIDIRECT_VERIFIED) {
		dc_log_warning(context, 0, "Cannot verifiy group; sender is not verified.");
		goto cleanup;
	}

	// ensure, the message is encrypted
	if (!mimeparser->e2ee_helper->encrypted) {
		dc_log_warning(context, 0, "Cannot verifiy group; message is not encrypted properly.");
		goto cleanup;
	}

	// ensure, the message is signed with a verified key of the sender
	if (!dc_apeerstate_has_verified_key(peerstate, mimeparser->e2ee_helper->signatures)) {
		dc_log_warning(context, 0, "Cannot verifiy group; message is not signed properly.");
		goto cleanup;
    }

	// check that all members are verified.
	// if a verification is missing, check if this was just gossiped - as we've verified the sender, we verify the member then.
	to_ids_str = dc_array_get_string(to_ids, ",");
	q3 = sqlite3_mprintf("SELECT c.addr, LENGTH(ps.verified_key_fingerprint) "
						 " FROM contacts c "
						 " LEFT JOIN acpeerstates ps ON c.addr=ps.addr "
						 " WHERE c.id IN(%s) ",
						 to_ids_str);
	stmt = dc_sqlite3_prepare(context->sql, q3);
	while (sqlite3_step(stmt)==SQLITE_ROW)
	{
		const char* to_addr     = (const char*)sqlite3_column_text(stmt, 0);
		int is_verified         =              sqlite3_column_int (stmt, 1);

		if (dc_hash_find_str(mimeparser->e2ee_helper->gossipped_addr, to_addr)
		 && dc_apeerstate_load_by_addr(peerstate, context->sql, to_addr))
		{
			// if we're here, we know the gossip key is verified:
			// - use the gossip-key as verified-key if there is no verified-key
			// - OR if the verified-key does not match public-key or gossip-key
			//   (otherwise a verified key can _only_ be updated through QR scan which might be annoying,
			//   see https://github.com/nextleap-project/countermitm/issues/46 for a discussion about this point)
			if (!is_verified
			 ||   (strcmp(peerstate->verified_key_fingerprint, peerstate->public_key_fingerprint)!=0
			    && strcmp(peerstate->verified_key_fingerprint, peerstate->gossip_key_fingerprint)!=0))
			{
				dc_log_info(context, 0, "Marking gossipped key %s as verified due to verified %s.", to_addr, contact->addr);
				dc_apeerstate_set_verified(peerstate, DC_PS_GOSSIP_KEY, peerstate->gossip_key_fingerprint, DC_BIDIRECT_VERIFIED);
				dc_apeerstate_save_to_db(peerstate, context->sql, 0);
				is_verified = 1;
			}
		}

		if (!is_verified)
		{
			dc_log_warning(context, 0, "Cannot verifiy group; recipient %s is not gossipped.", to_addr);
			goto cleanup;
		}
	}

	// it's up to the caller to check if the sender is a member of the group
	// (we do this for both, verified and unverified group, so we do not check this here)
	everythings_okay = 1;

cleanup:
	sqlite3_finalize(stmt);
	dc_contact_unref(contact);
	dc_apeerstate_unref(peerstate);
	free(to_ids_str);
	sqlite3_free(q3);
	return everythings_okay;
}


/* the function tries extracts the group-id from the message and returns the
corresponding chat_id.  If the chat_id is not existant, it is created.
If the message contains groups commands (name, profile image, changed members),
they are executed as well.

if no group-id could be extracted from the message, create_or_lookup_adhoc_group() is called
which tries to create or find out the chat_id by:
- is there a group with the same recipients? if so, use this (if there are multiple, use the most recent one)
- create an ad-hoc group based on the recipient list

So when the function returns, the caller has the group id matching the current
state of the group. */
static void create_or_lookup_group(dc_context_t* context, dc_mimeparser_t* mime_parser, int create_blocked,
                                     int32_t from_id, const dc_array_t* to_ids,
                                     uint32_t* ret_chat_id, int* ret_chat_id_blocked)
{
	uint32_t      chat_id = 0;
	int           chat_id_blocked = 0;
	int           chat_id_verified = 0;
	char*         grpid = NULL;
	char*         grpname = NULL;
	sqlite3_stmt* stmt;
	int           i = 0;
	int           to_ids_cnt = dc_array_get_cnt(to_ids);
	char*         self_addr = NULL;
	int           recreate_member_list = 0;
	int           send_EVENT_CHAT_MODIFIED = 0;
	char*         X_MrRemoveFromGrp = NULL; /* pointer somewhere into mime_parser, must not be freed */
	char*         X_MrAddToGrp = NULL; /* pointer somewhere into mime_parser, must not be freed */
	int           X_MrGrpNameChanged = 0;
	const char*   X_MrGrpImageChanged = NULL;

	/* search the grpid in the header */
	{
		struct mailimf_field*          field = NULL;
		struct mailimf_optional_field* optional_field = NULL;

		if ((optional_field=dc_mimeparser_lookup_optional_field(mime_parser, "Chat-Group-ID"))!=NULL) {
			grpid = dc_strdup(optional_field->fld_value);
		}

		if (grpid==NULL)
		{
			if ((field=dc_mimeparser_lookup_field(mime_parser, "Message-ID"))!=NULL && field->fld_type==MAILIMF_FIELD_MESSAGE_ID) {
				struct mailimf_message_id* fld_message_id = field->fld_data.fld_message_id;
				if (fld_message_id) {
					grpid = dc_extract_grpid_from_rfc724_mid(fld_message_id->mid_value);
				}
			}

			if (grpid==NULL)
			{
				if ((field=dc_mimeparser_lookup_field(mime_parser, "In-Reply-To"))!=NULL && field->fld_type==MAILIMF_FIELD_IN_REPLY_TO) {
					struct mailimf_in_reply_to* fld_in_reply_to = field->fld_data.fld_in_reply_to;
					if (fld_in_reply_to) {
						grpid = dc_extract_grpid_from_rfc724_mid_list(fld_in_reply_to->mid_list);
					}
				}

				if (grpid==NULL)
				{
					if ((field=dc_mimeparser_lookup_field(mime_parser, "References"))!=NULL && field->fld_type==MAILIMF_FIELD_REFERENCES) {
						struct mailimf_references* fld_references = field->fld_data.fld_references;
						if (fld_references) {
							grpid = dc_extract_grpid_from_rfc724_mid_list(fld_references->mid_list);
						}
					}

					if (grpid==NULL)
					{
						create_or_lookup_adhoc_group(context, mime_parser, create_blocked, from_id, to_ids, &chat_id, &chat_id_blocked);
						goto cleanup;
					}
				}
			}
		}

		if ((optional_field=dc_mimeparser_lookup_optional_field(mime_parser, "Chat-Group-Name"))!=NULL) {
			grpname = dc_decode_header_words(optional_field->fld_value); /* this is no changed groupname message */
		}

		if ((optional_field=dc_mimeparser_lookup_optional_field(mime_parser, "Chat-Group-Member-Removed"))!=NULL) {
			X_MrRemoveFromGrp = optional_field->fld_value;
			mime_parser->is_system_message = DC_CMD_MEMBER_REMOVED_FROM_GROUP;
		}
		else if ((optional_field=dc_mimeparser_lookup_optional_field(mime_parser, "Chat-Group-Member-Added"))!=NULL) {
			X_MrAddToGrp = optional_field->fld_value;
			mime_parser->is_system_message = DC_CMD_MEMBER_ADDED_TO_GROUP;
		}
		else if ((optional_field=dc_mimeparser_lookup_optional_field(mime_parser, "Chat-Group-Name-Changed"))!=NULL) {
			X_MrGrpNameChanged = 1;
			mime_parser->is_system_message = DC_CMD_GROUPNAME_CHANGED;
		}
		else if ((optional_field=dc_mimeparser_lookup_optional_field(mime_parser, "Chat-Group-Image"))!=NULL) {
			X_MrGrpImageChanged = optional_field->fld_value;
			mime_parser->is_system_message = DC_CMD_GROUPIMAGE_CHANGED;
		}
	}

	/* check, if we have a chat with this group ID */
	if ((chat_id=dc_get_chat_id_by_grpid(context, grpid, &chat_id_blocked, &chat_id_verified))!=0) {
		if (chat_id_verified
		 && !check_verified_properties(context, mime_parser, from_id, to_ids)) {
			chat_id          = 0; // force the creation of an unverified ad-hoc group.
			chat_id_blocked  = 0;
			chat_id_verified = 0;
			free(grpid);
			grpid = NULL;
			free(grpname);
			grpname = NULL;
		}
	}

	/* check if the sender is a member of the existing group -
	if not, the message does not go to the group chat but to the normal chat with the sender */
	if (chat_id!=0 && !dc_is_contact_in_chat(context, chat_id, from_id)) {
		chat_id = 0;
		create_or_lookup_adhoc_group(context, mime_parser, create_blocked, from_id, to_ids, &chat_id, &chat_id_blocked);
		goto cleanup;
	}

	/* check if the group does not exist but should be created */
	int group_explicitly_left = dc_is_group_explicitly_left(context, grpid);

	self_addr = dc_sqlite3_get_config(context->sql, "configured_addr", "");
	if (chat_id==0
	 && !dc_mimeparser_is_mailinglist_message(mime_parser)
	 && grpid
	 && grpname
	 && X_MrRemoveFromGrp==NULL /*otherwise, a pending "quit" message may pop up*/
	 && (!group_explicitly_left || (X_MrAddToGrp&&dc_addr_cmp(self_addr,X_MrAddToGrp)==0)) /*re-create explicitly left groups only if ourself is re-added*/
	)
	{
		int create_verified = 0;
		if (dc_mimeparser_lookup_field(mime_parser, "Chat-Verified")) {
			if (check_verified_properties(context, mime_parser, from_id, to_ids)) {
				create_verified = 1;
			}
		}

		chat_id = create_group_record(context, grpid, grpname, create_blocked, create_verified);
		chat_id_blocked  = create_blocked;
		chat_id_verified = create_verified;
		recreate_member_list = 1;
	}

	/* again, check chat_id */
	if (chat_id <= DC_CHAT_ID_LAST_SPECIAL) {
		chat_id = 0;
		if (group_explicitly_left) {
			chat_id = DC_CHAT_ID_TRASH; /* we got a message for a chat we've deleted - do not show this even as a normal chat */
		}
		else {
			create_or_lookup_adhoc_group(context, mime_parser, create_blocked, from_id, to_ids, &chat_id, &chat_id_blocked);
		}
		goto cleanup;
	}

	/* execute group commands */
	if (X_MrAddToGrp || X_MrRemoveFromGrp)
	{
		recreate_member_list = 1;
	}
	else if (X_MrGrpNameChanged && grpname && strlen(grpname) < 200)
	{
		stmt = dc_sqlite3_prepare(context->sql, "UPDATE chats SET name=? WHERE id=?;");
		sqlite3_bind_text(stmt, 1, grpname, -1, SQLITE_STATIC);
		sqlite3_bind_int (stmt, 2, chat_id);
		sqlite3_step(stmt);
		sqlite3_finalize(stmt);
		context->cb(context, DC_EVENT_CHAT_MODIFIED, chat_id, 0);
	}

	if (X_MrGrpImageChanged)
	{
		int   ok = 0;
		char* grpimage = NULL;
		if( strcmp(X_MrGrpImageChanged, "0")==0 ) {
			ok = 1; // group image deleted
		}
		else {
			for (int i = 0; i < carray_count(mime_parser->parts); i++) {
				dc_mimepart_t* part = (dc_mimepart_t*)carray_get(mime_parser->parts, i);
				if (part->type==DC_MSG_IMAGE) {
					grpimage = dc_param_get(part->param, DC_PARAM_FILE, NULL);
					ok = 1; // new group image set
				}
			}
		}

		if (ok) {
			dc_chat_t* chat = dc_chat_new(context);
				dc_log_info(context, 0, "New group image set to %s.", grpimage? "DELETED" : grpimage);
				dc_chat_load_from_db(chat, chat_id);
				dc_param_set(chat->param, DC_PARAM_PROFILE_IMAGE, grpimage/*may be NULL*/);
				dc_chat_update_param(chat);
			dc_chat_unref(chat);
			free(grpimage);
			send_EVENT_CHAT_MODIFIED = 1;
		}
	}

	/* add members to group/check members
	for recreation: we should add a timestamp */
	if (recreate_member_list)
	{
		const char* skip = X_MrRemoveFromGrp? X_MrRemoveFromGrp : NULL;

		stmt = dc_sqlite3_prepare(context->sql, "DELETE FROM chats_contacts WHERE chat_id=?;");
		sqlite3_bind_int (stmt, 1, chat_id);
		sqlite3_step(stmt);
		sqlite3_finalize(stmt);

		if (skip==NULL || dc_addr_cmp(self_addr, skip)!=0) {
			dc_add_to_chat_contacts_table(context, chat_id, DC_CONTACT_ID_SELF);
		}

		if (from_id > DC_CONTACT_ID_LAST_SPECIAL) {
			if (dc_addr_equals_contact(context, self_addr, from_id)==0
			 && (skip==NULL || dc_addr_equals_contact(context, skip, from_id)==0)) {
				dc_add_to_chat_contacts_table(context, chat_id, from_id);
			}
		}

		for (i = 0; i < to_ids_cnt; i++)
		{
			uint32_t to_id = dc_array_get_id(to_ids, i); /* to_id is only once in to_ids and is non-special */
			if (dc_addr_equals_contact(context, self_addr, to_id)==0
			 && (skip==NULL || dc_addr_equals_contact(context, skip, to_id)==0)) {
				dc_add_to_chat_contacts_table(context, chat_id, to_id);
			}
		}
		send_EVENT_CHAT_MODIFIED = 1;
	}

	if (send_EVENT_CHAT_MODIFIED) {
		context->cb(context, DC_EVENT_CHAT_MODIFIED, chat_id, 0);
	}

	/* check the number of receivers -
	the only critical situation is if the user hits "Reply" instead of "Reply all" in a non-messenger-client */
	if (to_ids_cnt==1 && mime_parser->is_send_by_messenger==0) {
		int is_contact_cnt = dc_get_chat_contact_cnt(context, chat_id);
		if (is_contact_cnt > 3 /* to_ids_cnt==1 may be "From: A, To: B, SELF" as SELF is not counted in to_ids_cnt. So everything up to 3 is no error. */) {
			chat_id = 0;
			create_or_lookup_adhoc_group(context, mime_parser, create_blocked, from_id, to_ids, &chat_id, &chat_id_blocked);
			goto cleanup;
		}
	}

cleanup:
	free(grpid);
	free(grpname);
	free(self_addr);
	if (ret_chat_id)         { *ret_chat_id = chat_id; }
	if (ret_chat_id_blocked) { *ret_chat_id_blocked = chat_id? chat_id_blocked : 0; }
}


/*******************************************************************************
 * Receive a message and add it to the database
 ******************************************************************************/


void dc_receive_imf(dc_context_t* context, const char* imf_raw_not_terminated, size_t imf_raw_bytes,
                           const char* server_folder, uint32_t server_uid, uint32_t flags)
{
	/* the function returns the number of created messages in the database */
	int              incoming = 1;
	int              incoming_origin = 0;
	#define          outgoing (!incoming)

	dc_array_t*      to_ids = NULL;
	int              to_self = 0;

	uint32_t         from_id = 0;
	int              from_id_blocked = 0;
	uint32_t         to_id = 0;
	uint32_t         chat_id = 0;
	int              chat_id_blocked = 0;
	int              state = DC_STATE_UNDEFINED;
	int              hidden = 0;
	int              add_delete_job = 0;
	uint32_t         insert_msg_id = 0;

	sqlite3_stmt*    stmt = NULL;
	size_t           i = 0;
	size_t           icnt = 0;
	char*            rfc724_mid = NULL; /* Message-ID from the header */
	time_t           sort_timestamp = DC_INVALID_TIMESTAMP;
	time_t           sent_timestamp = DC_INVALID_TIMESTAMP;
	time_t           rcvd_timestamp = DC_INVALID_TIMESTAMP;
	dc_mimeparser_t* mime_parser = dc_mimeparser_new(context->blobdir, context);
	int              transaction_pending = 0;
	const struct mailimf_field* field;
	char*            mime_in_reply_to = NULL;
	char*            mime_references = NULL;

	carray*          created_db_entries = carray_new(16);
	int              create_event_to_send = DC_EVENT_MSGS_CHANGED;

	carray*          rr_event_to_send = carray_new(16);

	char*            txt_raw = NULL;

	dc_log_info(context, 0, "Receiving message %s/%lu...", server_folder? server_folder:"?", server_uid);

	to_ids = dc_array_new(context, 16);
	if (to_ids==NULL || created_db_entries==NULL || rr_event_to_send==NULL || mime_parser==NULL) {
		dc_log_info(context, 0, "Bad param.");
		goto cleanup;
	}

	/* parse the imf to mailimf_message {
	        mailimf_fields* msg_fields {
	          clist* fld_list; // list of mailimf_field
	        }
	        mailimf_body* msg_body { //!=NULL
                const char * bd_text; //!=NULL
                size_t bd_size;
	        }
	   };
	normally, this is done by mailimf_message_parse(), however, as we also need the MIME data,
	we use mailmime_parse() through dc_mimeparser (both call mailimf_struct_multiple_parse() somewhen, I did not found out anything
	that speaks against this approach yet) */
	dc_mimeparser_parse(mime_parser, imf_raw_not_terminated, imf_raw_bytes);
	if (dc_hash_cnt(&mime_parser->header)==0) {
		dc_log_info(context, 0, "No header.");
		goto cleanup; /* Error - even adding an empty record won't help as we do not know the message ID */
	}

	/* messages without a Return-Path header typically are outgoing, however, if the Return-Path header
	is missing for other reasons, see issue #150, foreign messages appear as own messages, this is very confusing.
	as it may even be confusing when _own_ messages sent from other devices with other e-mail-adresses appear as being sent from SELF
	we disabled this check for now */
	#if 0
	if (!dc_mimeparser_lookup_field(mime_parser, "Return-Path")) {
		incoming = 0;
	}
	#endif

	if ((field=dc_mimeparser_lookup_field(mime_parser, "Date"))!=NULL && field->fld_type==MAILIMF_FIELD_ORIG_DATE) {
		struct mailimf_orig_date* orig_date = field->fld_data.fld_orig_date;
		if (orig_date) {
			sent_timestamp = dc_timestamp_from_date(orig_date->dt_date_time); // is not yet checked against bad times! we do this later if we have the database information.
		}
	}

	dc_sqlite3_begin_transaction(context->sql);
	transaction_pending = 1;

		/* get From: and check if it is known (for known From:'s we add the other To:/Cc: in the 3rd pass)
		or if From: is equal to SELF (in this case, it is any outgoing messages, we do not check Return-Path any more as this is unreliable, see issue #150 */
		if ((field=dc_mimeparser_lookup_field(mime_parser, "From"))!=NULL
		 && field->fld_type==MAILIMF_FIELD_FROM)
		{
			struct mailimf_from* fld_from = field->fld_data.fld_from;
			if (fld_from)
			{
				int check_self;
				dc_array_t* from_list = dc_array_new(context, 16);
				dc_add_or_lookup_contacts_by_mailbox_list(context, fld_from->frm_mb_list, DC_ORIGIN_INCOMING_UNKNOWN_FROM, from_list, &check_self);
				if (check_self)
				{
					incoming = 0;

					if (dc_mimeparser_sender_equals_recipient(mime_parser))
					{
						from_id = DC_CONTACT_ID_SELF;
					}
				}
				else
				{
					if (dc_array_get_cnt(from_list)>=1) /* if there is no from given, from_id stays 0 which is just fine. These messages are very rare, however, we have to add them to the database (they go to the "deaddrop" chat) to avoid a re-download from the server. See also [**] */
					{
						from_id = dc_array_get_id(from_list, 0);
						incoming_origin = dc_get_contact_origin(context, from_id, &from_id_blocked);
					}
				}
				dc_array_unref(from_list);
			}
		}

		/* Make sure, to_ids starts with the first To:-address (Cc: is added in the loop below pass) */
		if ((field=dc_mimeparser_lookup_field(mime_parser, "To"))!=NULL
		 && field->fld_type==MAILIMF_FIELD_TO)
		{
			struct mailimf_to* fld_to = field->fld_data.fld_to; /* can be NULL */
			if (fld_to)
			{
				dc_add_or_lookup_contacts_by_address_list(context, fld_to->to_addr_list /*!= NULL*/,
					outgoing? DC_ORIGIN_OUTGOING_TO : (incoming_origin>=DC_ORIGIN_MIN_VERIFIED? DC_ORIGIN_INCOMING_TO : DC_ORIGIN_INCOMING_UNKNOWN_TO), to_ids, &to_self);
			}
		}

		if (dc_mimeparser_has_nonmeta(mime_parser))
		{

			/**********************************************************************
			 * Add parts
			 *********************************************************************/

			/* collect the rest information, CC: is added to the to-list, BCC: is ignored
			(we should not add BCC to groups as this would split groups. We could add them as "known contacts",
			however, the benefit is very small and this may leak data that is expected to be hidden) */
			if ((field=dc_mimeparser_lookup_field(mime_parser, "Cc"))!=NULL && field->fld_type==MAILIMF_FIELD_CC)
			{
				struct mailimf_cc* fld_cc = field->fld_data.fld_cc;
				if (fld_cc) {
					dc_add_or_lookup_contacts_by_address_list(context, fld_cc->cc_addr_list,
						outgoing? DC_ORIGIN_OUTGOING_CC : (incoming_origin>=DC_ORIGIN_MIN_VERIFIED? DC_ORIGIN_INCOMING_CC : DC_ORIGIN_INCOMING_UNKNOWN_CC), to_ids, NULL);
				}
			}

			/* get Message-ID; if the header is lacking one, generate one based on fields that do never change.
			(missing Message-IDs may come if the mail was set from this account with another client that relies in the SMTP server to generate one.
			true eg. for the Webmailer used in all-inkl-KAS) */
			if ((field=dc_mimeparser_lookup_field(mime_parser, "Message-ID"))!=NULL && field->fld_type==MAILIMF_FIELD_MESSAGE_ID) {
				struct mailimf_message_id* fld_message_id = field->fld_data.fld_message_id;
				if (fld_message_id) {
					rfc724_mid = dc_strdup(fld_message_id->mid_value);
				}
			}

			if (rfc724_mid==NULL) {
				rfc724_mid = dc_create_incoming_rfc724_mid(sent_timestamp, from_id, to_ids);
				if (rfc724_mid==NULL) {
					dc_log_info(context, 0, "Cannot create Message-ID.");
					goto cleanup;
				}
			}

			/* check, if the mail is already in our database - if so, just update the folder/uid (if the mail was moved around) and finish.
			(we may get a mail twice eg. if it is moved between folders. make sure, this check is done eg. before securejoin-processing) */
			{
				char*    old_server_folder = NULL;
				uint32_t old_server_uid = 0;
				if (dc_rfc724_mid_exists(context, rfc724_mid, &old_server_folder, &old_server_uid)) {
					if (strcmp(old_server_folder, server_folder)!=0 || old_server_uid!=server_uid) {
						dc_sqlite3_rollback(context->sql);
						transaction_pending = 0;
						dc_update_server_uid(context, rfc724_mid, server_folder, server_uid);
					}
					free(old_server_folder);
					dc_log_info(context, 0, "Message already in DB.");
					goto cleanup;
				}
			}

			/* check if the message introduces a new chat:
			- outgoing messages introduce a chat with the first to: address if they are sent by a messenger
			- incoming messages introduce a chat only for known contacts if they are sent by a messenger
			(of course, the user can add other chats manually later) */
			if (incoming)
			{
				state = (flags&DC_IMAP_SEEN)? DC_STATE_IN_SEEN : DC_STATE_IN_FRESH;
				to_id = DC_CONTACT_ID_SELF;

				// handshake messages must be processed before chats are created (eg. contacs may be marked as verified)
				assert( chat_id==0);
				if (dc_mimeparser_lookup_field(mime_parser, "Secure-Join")) {
					dc_sqlite3_commit(context->sql);
						int handshake = dc_handle_securejoin_handshake(context, mime_parser, from_id);
						if (handshake & DC_HANDSHAKE_STOP_NORMAL_PROCESSING) {
							hidden = 1;
							add_delete_job = (handshake & DC_HANDSHAKE_ADD_DELETE_JOB);
							state = DC_STATE_IN_SEEN;
						}
					dc_sqlite3_begin_transaction(context->sql);
				}

				/* test if there is a normal chat with the sender - if so, this allows us to create groups in the next step */
				uint32_t test_normal_chat_id = 0;
				int      test_normal_chat_id_blocked = 0;
				dc_lookup_real_nchat_by_contact_id(context, from_id, &test_normal_chat_id, &test_normal_chat_id_blocked);

				/* get the chat_id - a chat_id here is no indicator that the chat is displayed in the normal list, it might also be
				blocked and displayed in the deaddrop as a result */
				if (chat_id==0)
				{
					/* try to create a group
					(groups appear automatically only if the _sender_ is known, see core issue #54) */
					int create_blocked = ((test_normal_chat_id&&test_normal_chat_id_blocked==DC_CHAT_NOT_BLOCKED) || incoming_origin>=DC_ORIGIN_MIN_START_NEW_NCHAT/*always false, for now*/)? DC_CHAT_NOT_BLOCKED : DC_CHAT_DEADDROP_BLOCKED;
					create_or_lookup_group(context, mime_parser, create_blocked, from_id, to_ids, &chat_id, &chat_id_blocked);
					if (chat_id && chat_id_blocked && !create_blocked) {
						dc_unblock_chat(context, chat_id);
						chat_id_blocked = 0;
					}
				}

				if (chat_id==0)
				{
					/* check if the message belongs to a mailing list */
					if (dc_mimeparser_is_mailinglist_message(mime_parser)) {
						chat_id = DC_CHAT_ID_TRASH;
						dc_log_info(context, 0, "Message belongs to a mailing list and is ignored.");
					}
				}

				if (chat_id==0)
				{
					/* try to create a normal chat */
					int create_blocked = (incoming_origin>=DC_ORIGIN_MIN_START_NEW_NCHAT/*always false, for now*/ || from_id==to_id)? DC_CHAT_NOT_BLOCKED : DC_CHAT_DEADDROP_BLOCKED;
					if (test_normal_chat_id) {
						chat_id         = test_normal_chat_id;
						chat_id_blocked = test_normal_chat_id_blocked;
					}
					else {
						dc_create_or_lookup_nchat_by_contact_id(context, from_id, create_blocked, &chat_id, &chat_id_blocked);
					}

					if (chat_id && chat_id_blocked) {
						if (!create_blocked) {
							dc_unblock_chat(context, chat_id);
							chat_id_blocked = 0;
						}
						else if (dc_is_reply_to_known_message(context, mime_parser)) {
							dc_scaleup_contact_origin(context, from_id, DC_ORIGIN_INCOMING_REPLY_TO); /* we do not want any chat to be created implicitly.  Because of the origin-scale-up, the contact requests will pop up and this should be just fine. */
							dc_log_info(context, 0, "Message is a reply to a known message, mark sender as known.");
							incoming_origin = DC_MAX(incoming_origin, DC_ORIGIN_INCOMING_REPLY_TO);
						}
					}
				}

				if (chat_id==0)
				{
					/* maybe from_id is null or sth. else is suspicious, move message to trash */
					chat_id = DC_CHAT_ID_TRASH;
				}

				/* degrade state for unknown senders and non-delta messages
				(the latter may be removed if we run into spam problems, currently this is fine)
				(noticed messages do count as being unread; therefore, the deaddrop will not popup in the chatlist) */
				if (chat_id_blocked && state==DC_STATE_IN_FRESH)
				{
					if (incoming_origin < DC_ORIGIN_MIN_VERIFIED
					 && mime_parser->is_send_by_messenger == 0
					 && !dc_is_mvbox(context, server_folder))
					{
						state = DC_STATE_IN_NOTICED;
					}
				}
			}
			else /* outgoing */
			{
				state = DC_STATE_OUT_DELIVERED; /* the mail is on the IMAP server, probably it is also delivered.  We cannot recreate other states (read, error). */
				from_id = DC_CONTACT_ID_SELF;
				if (dc_array_get_cnt(to_ids) >= 1) {
					to_id   = dc_array_get_id(to_ids, 0);

					if (chat_id==0)
					{
						create_or_lookup_group(context, mime_parser, DC_CHAT_NOT_BLOCKED, from_id, to_ids, &chat_id, &chat_id_blocked);
						if (chat_id && chat_id_blocked) {
							dc_unblock_chat(context, chat_id);
							chat_id_blocked = 0;
						}
					}

					if (chat_id==0)
					{
						int create_blocked = (mime_parser->is_send_by_messenger && !dc_is_contact_blocked(context, to_id))? DC_CHAT_NOT_BLOCKED : DC_CHAT_DEADDROP_BLOCKED;
						dc_create_or_lookup_nchat_by_contact_id(context, to_id, create_blocked, &chat_id, &chat_id_blocked);
						if (chat_id && chat_id_blocked && !create_blocked) {
							dc_unblock_chat(context, chat_id);
							chat_id_blocked = 0;
						}
					}
				}

				if (chat_id==0) {
					if (dc_array_get_cnt(to_ids)==0 && to_self) {
						/* from_id==to_id==DC_CONTACT_ID_SELF - this is a self-sent messages, maybe an Autocrypt Setup Message */
						dc_create_or_lookup_nchat_by_contact_id(context, DC_CONTACT_ID_SELF, DC_CHAT_NOT_BLOCKED, &chat_id, &chat_id_blocked);
						if (chat_id && chat_id_blocked) {
							dc_unblock_chat(context, chat_id);
							chat_id_blocked = 0;
						}
					}
				}

				if (chat_id==0) {
					chat_id = DC_CHAT_ID_TRASH;
				}
			}

			/* correct message_timestamp, it should not be used before,
			however, we cannot do this earlier as we need from_id to be set */
			calc_timestamps(context, chat_id, from_id, sent_timestamp, (flags&DC_IMAP_SEEN)? 0 : 1 /*fresh message?*/,
				&sort_timestamp, &sent_timestamp, &rcvd_timestamp);

			/* unarchive chat */
			dc_unarchive_chat(context, chat_id);

			// if the mime-headers should be saved, find out its size
			// (the mime-header ends with an empty line)
			int save_mime_headers = dc_sqlite3_get_config_int(context->sql, "save_mime_headers", 0);
			int header_bytes = imf_raw_bytes;
			if (save_mime_headers) {
				char* p;
				if ((p=strstr(imf_raw_not_terminated, "\r\n\r\n"))!=NULL) {
					header_bytes = (p-imf_raw_not_terminated)+4;
				}
				else if ((p=strstr(imf_raw_not_terminated, "\n\n"))!=NULL) {
					header_bytes = (p-imf_raw_not_terminated)+2;
				}
			}

			if ((field=dc_mimeparser_lookup_field(mime_parser, "In-Reply-To"))!=NULL
			 && field->fld_type==MAILIMF_FIELD_IN_REPLY_TO)
			{
				struct mailimf_in_reply_to* fld_in_reply_to = field->fld_data.fld_in_reply_to;
				if (fld_in_reply_to) {
					mime_in_reply_to = dc_str_from_clist(field->fld_data.fld_in_reply_to->mid_list, " ");
				}
			}

			if ((field=dc_mimeparser_lookup_field(mime_parser, "References"))!=NULL
			 && field->fld_type==MAILIMF_FIELD_REFERENCES)
			{
				struct mailimf_references* fld_references = field->fld_data.fld_references;
				if (fld_references) {
					mime_references = dc_str_from_clist(field->fld_data.fld_references->mid_list, " ");
				}
			}

			/* fine, so far.  now, split the message into simple parts usable as "short messages"
			and add them to the database (mails sent by other messenger clients should result
			into only one message; mails sent by other clients may result in several messages (eg. one per attachment)) */
			icnt = carray_count(mime_parser->parts); /* should be at least one - maybe empty - part */
			stmt = dc_sqlite3_prepare(context->sql,
				"INSERT INTO msgs (rfc724_mid, server_folder, server_uid, chat_id, from_id, to_id,"
				" timestamp, timestamp_sent, timestamp_rcvd, type, state, msgrmsg, "
				" txt, txt_raw, param, bytes, hidden, mime_headers, "
				" mime_in_reply_to, mime_references)"
				" VALUES (?,?,?,?,?,?, ?,?,?,?,?,?, ?,?,?,?,?,?, ?,?);");
			for (i = 0; i < icnt; i++)
			{
				dc_mimepart_t* part = (dc_mimepart_t*)carray_get(mime_parser->parts, i);
				if (part->is_meta) {
					continue;
				}

				if (part->type==DC_MSG_TEXT) {
					txt_raw = dc_mprintf("%s\n\n%s", mime_parser->subject? mime_parser->subject : "", part->msg_raw);
				}

				if (mime_parser->is_system_message) {
					dc_param_set_int(part->param, DC_PARAM_CMD, mime_parser->is_system_message);
				}

				sqlite3_reset(stmt);
				sqlite3_bind_text (stmt,  1, rfc724_mid, -1, SQLITE_STATIC);
				sqlite3_bind_text (stmt,  2, server_folder, -1, SQLITE_STATIC);
				sqlite3_bind_int  (stmt,  3, server_uid);
				sqlite3_bind_int  (stmt,  4, chat_id);
				sqlite3_bind_int  (stmt,  5, from_id);
				sqlite3_bind_int  (stmt,  6, to_id);
				sqlite3_bind_int64(stmt,  7, sort_timestamp);
				sqlite3_bind_int64(stmt,  8, sent_timestamp);
				sqlite3_bind_int64(stmt,  9, rcvd_timestamp);
				sqlite3_bind_int  (stmt, 10, part->type);
				sqlite3_bind_int  (stmt, 11, state);
				sqlite3_bind_int  (stmt, 12, mime_parser->is_send_by_messenger);
				sqlite3_bind_text (stmt, 13, part->msg? part->msg : "", -1, SQLITE_STATIC);
				sqlite3_bind_text (stmt, 14, txt_raw? txt_raw : "", -1, SQLITE_STATIC);
				sqlite3_bind_text (stmt, 15, part->param->packed, -1, SQLITE_STATIC);
				sqlite3_bind_int  (stmt, 16, part->bytes);
				sqlite3_bind_int  (stmt, 17, hidden);
				sqlite3_bind_text (stmt, 18, save_mime_headers? imf_raw_not_terminated : NULL, header_bytes, SQLITE_STATIC);
				sqlite3_bind_text (stmt, 19, mime_in_reply_to, -1, SQLITE_STATIC);
				sqlite3_bind_text (stmt, 20, mime_references, -1, SQLITE_STATIC);
				if (sqlite3_step(stmt)!=SQLITE_DONE) {
					dc_log_info(context, 0, "Cannot write DB.");
					goto cleanup; /* i/o error - there is nothing more we can do - in other cases, we try to write at least an empty record */
				}

				free(txt_raw);
				txt_raw = NULL;

				insert_msg_id = dc_sqlite3_get_rowid(context->sql, "msgs", "rfc724_mid", rfc724_mid);

				carray_add(created_db_entries, (void*)(uintptr_t)chat_id, NULL);
				carray_add(created_db_entries, (void*)(uintptr_t)insert_msg_id, NULL);
			}

			dc_log_info(context, 0, "Message has %i parts and is assigned to chat #%i.", icnt, chat_id);

			/* check event to send */
			if (chat_id==DC_CHAT_ID_TRASH)
			{
				create_event_to_send = 0;
			}
			else if (incoming && state==DC_STATE_IN_FRESH)
			{
				if (from_id_blocked) {
					create_event_to_send = 0;
				}
				else if (chat_id_blocked) {
					create_event_to_send = DC_EVENT_MSGS_CHANGED;
					/*if (dc_sqlite3_get_config_int(context->sql, "show_deaddrop", 0)!=0) {
						create_event_to_send = DC_EVENT_INCOMING_MSG;
					}*/
				}
				else {
					create_event_to_send = DC_EVENT_INCOMING_MSG;
				}
			}

			dc_do_heuristics_moves(context, server_folder, insert_msg_id);
		}
		else
		{
			// there are no non-meta data in message, do some basic calculations so that the varaiables are correct in the further processing
			if (sent_timestamp > time(NULL)) {
				sent_timestamp = time(NULL);
			}
		}


		if (carray_count(mime_parser->reports) > 0)
		{
			/******************************************************************
			 * Handle reports (mainly MDNs)
			 *****************************************************************/

			int mdns_enabled = dc_sqlite3_get_config_int(context->sql, "mdns_enabled", DC_MDNS_DEFAULT_ENABLED);
			icnt = carray_count(mime_parser->reports);
			for (i = 0; i < icnt; i++)
			{
				int                        mdn_consumed = 0;
				struct mailmime*           report_root = carray_get(mime_parser->reports, i);
				struct mailmime_parameter* report_type = mailmime_find_ct_parameter(report_root, "report-type");
				if (report_root==NULL || report_type==NULL || report_type->pa_value==NULL) {
					continue;
				}

				if (strcmp(report_type->pa_value, "disposition-notification")==0
				 && clist_count(report_root->mm_data.mm_multipart.mm_mp_list) >= 2 /* the first part is for humans, the second for machines */)
				{
					if (mdns_enabled /*to get a clear functionality, do not show incoming MDNs if the options is disabled*/)
					{
						struct mailmime* report_data = (struct mailmime*)clist_content(clist_next(clist_begin(report_root->mm_data.mm_multipart.mm_mp_list)));
						if (report_data
						 && report_data->mm_content_type->ct_type->tp_type==MAILMIME_TYPE_COMPOSITE_TYPE
						 && report_data->mm_content_type->ct_type->tp_data.tp_composite_type->ct_type==MAILMIME_COMPOSITE_TYPE_MESSAGE
						 && strcmp(report_data->mm_content_type->ct_subtype, "disposition-notification")==0)
						{
							/* we received a MDN (although the MDN is only a header, we parse it as a complete mail) */
							const char* report_body = NULL;
							size_t      report_body_bytes = 0;
							char*       to_mmap_string_unref = NULL;
							if (mailmime_transfer_decode(report_data, &report_body, &report_body_bytes, &to_mmap_string_unref))
							{
								struct mailmime* report_parsed = NULL;
								size_t dummy = 0;
								if (mailmime_parse(report_body, report_body_bytes, &dummy, &report_parsed)==MAIL_NO_ERROR
								 && report_parsed!=NULL)
								{
									struct mailimf_fields* report_fields = mailmime_find_mailimf_fields(report_parsed);
									if (report_fields)
									{
										struct mailimf_optional_field* of_disposition = mailimf_find_optional_field(report_fields, "Disposition"); /* MUST be preset, _if_ preset, we assume a sort of attribution and do not go into details */
										struct mailimf_optional_field* of_org_msgid   = mailimf_find_optional_field(report_fields, "Original-Message-ID"); /* can't live without */
										if (of_disposition && of_disposition->fld_value && of_org_msgid && of_org_msgid->fld_value)
										{
											char* rfc724_mid = NULL;
											dummy = 0;
											if (mailimf_msg_id_parse(of_org_msgid->fld_value, strlen(of_org_msgid->fld_value), &dummy, &rfc724_mid)==MAIL_NO_ERROR
											 && rfc724_mid!=NULL)
											{
												uint32_t chat_id = 0;
												uint32_t msg_id = 0;
												if (dc_mdn_from_ext(context, from_id, rfc724_mid, sent_timestamp, &chat_id, &msg_id)) {
													carray_add(rr_event_to_send, (void*)(uintptr_t)chat_id, NULL);
													carray_add(rr_event_to_send, (void*)(uintptr_t)msg_id, NULL);
												}
												mdn_consumed = (msg_id!=0);
												free(rfc724_mid);
											}
										}
									}
									mailmime_free(report_parsed);
								}

								if (to_mmap_string_unref) { mmap_string_unref(to_mmap_string_unref); }
							}
						}
					}

					/* Move the MDN away to the chats folder.  We do this for:
					- Consumed or not consumed MDNs from other messengers
					- Consumed MDNs from normal MUAs
					Unconsumed MDNs from normal MUAs are _not_ moved.
					NB: we do not delete the MDN as it may be used by other clients */
					if (mime_parser->is_send_by_messenger || mdn_consumed) {
						dc_param_t* param = dc_param_new();
						dc_param_set(param, DC_PARAM_SERVER_FOLDER, server_folder);
						dc_param_set_int(param, DC_PARAM_SERVER_UID, server_uid);
						if (mime_parser->is_send_by_messenger
						 && dc_sqlite3_get_config_int(context->sql, "mvbox_move", DC_MVBOX_MOVE_DEFAULT)) {
							dc_param_set_int(param, DC_PARAM_ALSO_MOVE, 1);
						}
						dc_job_add(context, DC_JOB_MARKSEEN_MDN_ON_IMAP, 0, param->packed, 0);
						dc_param_unref(param);
					}
				}

			} /* for() */

		}

		if (add_delete_job && carray_count(created_db_entries)>=2) {
			dc_job_add(context, DC_JOB_DELETE_MSG_ON_IMAP, (int)(uintptr_t)carray_get(created_db_entries, 1), NULL, 0);
		}

	dc_sqlite3_commit(context->sql);
	transaction_pending = 0;

cleanup:
	if (transaction_pending) { dc_sqlite3_rollback(context->sql); }

	dc_mimeparser_unref(mime_parser);
	free(rfc724_mid);
	free(mime_in_reply_to);
	free(mime_references);
	dc_array_unref(to_ids);

	if (created_db_entries) {
		if (create_event_to_send) {
			size_t i, icnt = carray_count(created_db_entries);
			for (i = 0; i < icnt; i += 2) {
				context->cb(context, create_event_to_send, (uintptr_t)carray_get(created_db_entries, i), (uintptr_t)carray_get(created_db_entries, i+1));
			}
		}
		carray_free(created_db_entries);
	}

	if (rr_event_to_send) {
		size_t i, icnt = carray_count(rr_event_to_send);
		for (i = 0; i < icnt; i += 2) {
			context->cb(context, DC_EVENT_MSG_READ, (uintptr_t)carray_get(rr_event_to_send, i), (uintptr_t)carray_get(rr_event_to_send, i+1));
		}
		carray_free(rr_event_to_send);
	}

	free(txt_raw);
	sqlite3_finalize(stmt);
}
