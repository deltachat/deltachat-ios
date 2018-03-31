/*******************************************************************************
 *
 *                              Delta Chat Core
 *                      Copyright (C) 2017 Björn Petersen
 *                   Contact: r10s@b44t.com, http://b44t.com
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see http://www.gnu.org/licenses/ .
 *
 ******************************************************************************/


#include "mrmailbox_internal.h"
#include "mrmimeparser.h"
#include "mrmimefactory.h"
#include "mrimap.h"
#include "mrjob.h"
#include "mrarray-private.h"
#include <netpgp-extra.h>


/*******************************************************************************
 * Add contacts to database on receiving messages
 ******************************************************************************/


static void add_or_lookup_contact_by_addr__(mrmailbox_t* mailbox, const char* display_name_enc, const char* addr_spec, int origin, mrarray_t* ids, int* check_self)
{
	/* is addr_spec equal to SELF? */
	int dummy;
	if( check_self == NULL ) { check_self = &dummy; }

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || addr_spec == NULL ) {
		return;
	}

	*check_self = 0;

	char* self_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", "");
		if( strcasecmp(self_addr, addr_spec)==0 ) {
			*check_self = 1;
		}
	free(self_addr);

	if( *check_self ) {
		return;
	}

	/* add addr_spec if missing, update otherwise */
	char* display_name_dec = NULL;
	if( display_name_enc ) {
		display_name_dec = mr_decode_header_string(display_name_enc);
		mr_normalize_name(display_name_dec);
	}

	uint32_t row_id = mrmailbox_add_or_lookup_contact__(mailbox, display_name_dec /*can be NULL*/, addr_spec, origin, NULL);

	free(display_name_dec);

	if( row_id ) {
		if( !mrarray_search_id(ids, row_id, NULL) ) {
			mrarray_add_id(ids, row_id);
		}
	}
}


static void mrmailbox_add_or_lookup_contacts_by_mailbox_list__(mrmailbox_t* mailbox, struct mailimf_mailbox_list* mb_list, int origin, mrarray_t* ids, int* check_self)
{
	clistiter* cur;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || mb_list == NULL ) {
		return;
	}

	for( cur = clist_begin(mb_list->mb_list); cur!=NULL ; cur=clist_next(cur) ) {
		struct mailimf_mailbox* mb = (struct mailimf_mailbox*)clist_content(cur);
		if( mb ) {
			add_or_lookup_contact_by_addr__(mailbox, mb->mb_display_name, mb->mb_addr_spec, origin, ids, check_self);
		}
	}
}


static void mrmailbox_add_or_lookup_contacts_by_address_list__(mrmailbox_t* mailbox, struct mailimf_address_list* adr_list, int origin, mrarray_t* ids, int* check_self)
{
	clistiter* cur;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || adr_list == NULL /*may be NULL eg. if bcc is given as `Bcc: \n` in the header */ ) {
		return;
	}

	for( cur = clist_begin(adr_list->ad_list); cur!=NULL ; cur=clist_next(cur) ) {
		struct mailimf_address* adr = (struct mailimf_address*)clist_content(cur);
		if( adr ) {
			if( adr->ad_type == MAILIMF_ADDRESS_MAILBOX ) {
				struct mailimf_mailbox* mb = adr->ad_data.ad_mailbox; /* can be NULL */
				if( mb ) {
					add_or_lookup_contact_by_addr__(mailbox, mb->mb_display_name, mb->mb_addr_spec, origin, ids, check_self);
				}
			}
			else if( adr->ad_type == MAILIMF_ADDRESS_GROUP ) {
				struct mailimf_group* group = adr->ad_data.ad_group; /* can be NULL */
				if( group && group->grp_mb_list /*can be NULL*/ ) {
					mrmailbox_add_or_lookup_contacts_by_mailbox_list__(mailbox, group->grp_mb_list, origin, ids, check_self);
				}
			}
		}
	}
}


/*******************************************************************************
 * Check if a message is a reply to a known message (messenger or non-messenger)
 ******************************************************************************/


static int is_known_rfc724_mid__(mrmailbox_t* mailbox, const char* rfc724_mid)
{
	if( rfc724_mid ) {
		sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_msgs_WHERE_cm,
			"SELECT m.id FROM msgs m "
			" LEFT JOIN chats c ON m.chat_id=c.id "
			" WHERE m.rfc724_mid=? "
			" AND m.chat_id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL)
			" AND c.blocked=0;");
		sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
		if( sqlite3_step(stmt) == SQLITE_ROW ) {
			return 1;
		}
	}
	return 0;
}


static int is_known_rfc724_mid_in_list__(mrmailbox_t* mailbox, const clist* mid_list)
{
	if( mid_list ) {
		clistiter* cur;
		for( cur = clist_begin(mid_list); cur!=NULL ; cur=clist_next(cur) ) {
			if( is_known_rfc724_mid__(mailbox, clist_content(cur)) ) {
				return 1;
			}
		}
	}

	return 0;
}


static int mrmailbox_is_reply_to_known_message__(mrmailbox_t* mailbox, mrmimeparser_t* mime_parser)
{
	/* check if the message is a reply to a known message; the replies are identified by the Message-ID from
	`In-Reply-To`/`References:` (to support non-Delta-Clients) or from `Chat-Predecessor:` (Delta clients, see comment in mrchat.c) */

	struct mailimf_optional_field* optional_field;
	if( (optional_field=mrmimeparser_lookup_optional_field2(mime_parser, "Chat-Predecessor", "X-MrPredecessor")) != NULL )
	{
		if( is_known_rfc724_mid__(mailbox, optional_field->fld_value) ) {
			return 1;
		}
	}

	struct mailimf_field* field;
	if( (field=mrmimeparser_lookup_field(mime_parser, "In-Reply-To"))!=NULL
	 && field->fld_type == MAILIMF_FIELD_IN_REPLY_TO )
	{
		struct mailimf_in_reply_to* fld_in_reply_to = field->fld_data.fld_in_reply_to;
		if( fld_in_reply_to ) {
			if( is_known_rfc724_mid_in_list__(mailbox, field->fld_data.fld_in_reply_to->mid_list) ) {
				return 1;
			}
		}
	}

	if( (field=mrmimeparser_lookup_field(mime_parser, "References"))!=NULL
	 && field->fld_type == MAILIMF_FIELD_REFERENCES )
	{
		struct mailimf_references* fld_references = field->fld_data.fld_references;
		if( fld_references ) {
			if( is_known_rfc724_mid_in_list__(mailbox, field->fld_data.fld_references->mid_list) ) {
				return 1;
			}
		}
	}

	return 0;
}


/*******************************************************************************
 * Check if a message is a reply to any messenger message
 ******************************************************************************/


static int is_msgrmsg_rfc724_mid__(mrmailbox_t* mailbox, const char* rfc724_mid)
{
	if( rfc724_mid ) {
		sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_msgs_WHERE_mcm,
			"SELECT id FROM msgs "
			" WHERE rfc724_mid=? "
			" AND msgrmsg!=0 "
			" AND chat_id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL) ";");
		sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
		if( sqlite3_step(stmt) == SQLITE_ROW ) {
			return 1;
		}
	}
	return 0;
}


static int is_msgrmsg_rfc724_mid_in_list__(mrmailbox_t* mailbox, const clist* mid_list)
{
	if( mid_list ) {
		clistiter* cur;
		for( cur = clist_begin(mid_list); cur!=NULL ; cur=clist_next(cur) ) {
			if( is_msgrmsg_rfc724_mid__(mailbox, clist_content(cur)) ) {
				return 1;
			}
		}
	}

	return 0;
}


static int mrmailbox_is_reply_to_messenger_message__(mrmailbox_t* mailbox, mrmimeparser_t* mime_parser)
{
	/* function checks, if the message defined by mime_parser references a message send by us from Delta Chat.

	This is similar to is_reply_to_known_message__() but
	- checks also if any of the referenced IDs are send by a messenger
	- it is okay, if the referenced messages are moved to trash here
	- no check for the Chat-* headers (function is only called if it is no messenger message itself) */

	struct mailimf_field* field;
	if( (field=mrmimeparser_lookup_field(mime_parser, "In-Reply-To"))!=NULL
	 && field->fld_type==MAILIMF_FIELD_IN_REPLY_TO )
	{
		struct mailimf_in_reply_to* fld_in_reply_to = field->fld_data.fld_in_reply_to;
		if( fld_in_reply_to ) {
			if( is_msgrmsg_rfc724_mid_in_list__(mailbox, field->fld_data.fld_in_reply_to->mid_list) ) {
				return 1;
			}
		}
	}

	if( (field=mrmimeparser_lookup_field(mime_parser, "References"))!=NULL
	 && field->fld_type==MAILIMF_FIELD_REFERENCES )
	{
		struct mailimf_references* fld_references = field->fld_data.fld_references;
		if( fld_references ) {
			if( is_msgrmsg_rfc724_mid_in_list__(mailbox, field->fld_data.fld_references->mid_list) ) {
				return 1;
			}
		}
	}

	return 0;
}


/*******************************************************************************
 * Misc. Tools
 ******************************************************************************/


static void mrmailbox_calc_timestamps__(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t from_id, time_t message_timestamp, int is_fresh_msg,
                                        time_t* sort_timestamp, time_t* sent_timestamp, time_t* rcvd_timestamp)
{
	*rcvd_timestamp = time(NULL);

	*sent_timestamp = message_timestamp;
	if( *sent_timestamp > *rcvd_timestamp /* no sending times in the future */ ) {
		*sent_timestamp = *rcvd_timestamp;
	}

	*sort_timestamp = message_timestamp; /* truncatd below to smeared time (not to _now_ to keep the order) */

	/* use the last message from another user (including SELF) as the MINIMUM for sort_timestamp;
	this is to force fresh messages popping up at the end of the list.
	(we do this check only for fresh messages, other messages may pop up whereever, this may happen eg. when restoring old messages or synchronizing different clients) */
	if( is_fresh_msg )
	{
		sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_timestamp_FROM_msgs_WHERE_timestamp,
			"SELECT MAX(timestamp) FROM msgs WHERE chat_id=? and from_id!=? AND timestamp>=?");
		sqlite3_bind_int  (stmt,  1, chat_id);
		sqlite3_bind_int  (stmt,  2, from_id);
		sqlite3_bind_int64(stmt,  3, *sort_timestamp);
		if( sqlite3_step(stmt)==SQLITE_ROW )
		{
			time_t last_msg_time = sqlite3_column_int64(stmt, 0);
			if( last_msg_time > 0 /* may happen as we do not check against sqlite3_column_type()!=SQLITE_NULL */ ) {
				if( *sort_timestamp <= last_msg_time ) {
					*sort_timestamp = last_msg_time+1; /* this may result in several incoming messages having the same
					                                     one-second-after-the-last-other-message-timestamp.  however, this is no big deal
					                                     as we do not try to recrete the order of bad-date-messages and as we always order by ID as second criterion */
				}
			}
		}
	}

	/* use the (smeared) current time as the MAXIMUM */
	if( *sort_timestamp >= mr_smeared_time__() ) {
		*sort_timestamp = mr_create_smeared_timestamp__();
	}
}


static mrarray_t* search_chat_ids_by_contact_ids(mrmailbox_t* mailbox, const mrarray_t* unsorted_contact_ids)
{
	/* searches chat_id's by the given contact IDs, may return zero, one or more chat_id's */
	sqlite3_stmt* stmt = NULL;
	mrarray_t*    contact_ids = mrarray_new(mailbox, 23);
	char*         contact_ids_str = NULL, *q3 = NULL;
	mrarray_t*    chat_ids = mrarray_new(mailbox, 23);

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC  ) {
		goto cleanup;
	}

	/* copy array, remove duplicates and SELF, sort by ID */
	{
		int i, iCnt = mrarray_get_cnt(unsorted_contact_ids);
		if( iCnt <= 0 ) {
			goto cleanup;
		}

		for( i = 0; i < iCnt; i++ ) {
			uint32_t curr_id = mrarray_get_id(unsorted_contact_ids, i);
			if( curr_id != MR_CONTACT_ID_SELF && !mrarray_search_id(contact_ids, curr_id, NULL) ) {
				mrarray_add_id(contact_ids, curr_id);
			}
		}

		if( mrarray_get_cnt(contact_ids)==0 ) {
			goto cleanup;
		}

		mrarray_sort_ids(contact_ids); /* for easy comparison, we also sort the sql result below */
	}

	/* collect all possible chats with the contact count as the data (as contact_ids have no doubles, this is sufficient) */
	contact_ids_str = mrarray_get_string(contact_ids, ",");
	q3 = sqlite3_mprintf("SELECT DISTINCT cc.chat_id, cc.contact_id "
	                     " FROM chats_contacts cc "
	                     " LEFT JOIN chats c ON c.id=cc.chat_id "
	                     " WHERE cc.chat_id IN(SELECT chat_id FROM chats_contacts WHERE contact_id IN(%s))"
	                     "   AND c.type=" MR_STRINGIFY(MR_CHAT_TYPE_GROUP) /* do not select normal chats which are equal to a group with a single member and without SELF */
	                     "   AND cc.contact_id!=" MR_STRINGIFY(MR_CONTACT_ID_SELF) /* ignore SELF, we've also removed it above - if the user has left the group, it is still the same group */
	                     " ORDER BY cc.chat_id, cc.contact_id;",
	                     contact_ids_str);
	stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, q3);
	{
		uint32_t last_chat_id = 0, matches = 0, mismatches = 0;

		while( sqlite3_step(stmt)==SQLITE_ROW )
		{
			uint32_t chat_id    = sqlite3_column_int(stmt, 0);
			uint32_t contact_id = sqlite3_column_int(stmt, 1);

			if( chat_id != last_chat_id ) {
				if( matches == mrarray_get_cnt(contact_ids) && mismatches == 0 ) {
					mrarray_add_id(chat_ids, last_chat_id);
				}
				last_chat_id = chat_id;
				matches = 0;
				mismatches = 0;
			}

			if( contact_id == mrarray_get_id(contact_ids, matches) ) {
				matches++;
			}
			else {
				mismatches++;
			}
		}

		if( matches == mrarray_get_cnt(contact_ids) && mismatches == 0 ) {
			mrarray_add_id(chat_ids, last_chat_id);
		}
	}

cleanup:
	if( stmt ) { sqlite3_finalize(stmt); }
	free(contact_ids_str);
	mrarray_unref(contact_ids);
	if( q3 ) { sqlite3_free(q3); }
	return chat_ids;
}


static char* create_adhoc_grp_id__(mrmailbox_t* mailbox, mrarray_t* member_ids /*including SELF*/)
{
	/* algorithm:
	- sort normalized, lowercased, e-mail addresses alphabetically
	- put all e-mail addresses into a single string, separate the addresss by a single comma
	- sha-256 this string (without possibly terminating null-characters)
	- encode the first 64 bits of the sha-256 output as lowercase hex (results in 16 characters from the set [0-9a-f])
	 */
	mrarray_t*     member_addrs = mrarray_new(mailbox, 23);
	char*          member_ids_str = mrarray_get_string(member_ids, ",");
	mrstrbuilder_t member_cs;
	sqlite3_stmt*  stmt = NULL;
	char*          q3 = NULL, *addr;
	int            i, iCnt;
	uint8_t*       binary_hash = NULL;
	char*          ret = NULL;

	mrstrbuilder_init(&member_cs, 0);

	/* collect all addresses and sort them */
	q3 = sqlite3_mprintf("SELECT addr FROM contacts WHERE id IN(%s) AND id!=" MR_STRINGIFY(MR_CONTACT_ID_SELF), member_ids_str);
	stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, q3);
	addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", "no-self");
	mr_strlower_in_place(addr);
	mrarray_add_ptr(member_addrs, addr);
	while( sqlite3_step(stmt)==SQLITE_ROW ) {
		addr = safe_strdup((const char*)sqlite3_column_text(stmt, 0));
		mr_strlower_in_place(addr);
		mrarray_add_ptr(member_addrs, addr);
	}
	mrarray_sort_strings(member_addrs);

	/* build a single, comma-separated (cs) string from all addresses */
	iCnt = mrarray_get_cnt(member_addrs);
	for( i = 0; i < iCnt; i++ ) {
		if( i ) { mrstrbuilder_cat(&member_cs, ","); }
		mrstrbuilder_cat(&member_cs, (const char*)mrarray_get_ptr(member_addrs, i));
	}

	/* make sha-256 from the string */
	{
		pgp_hash_t hasher;
		pgp_hash_sha256(&hasher);
		hasher.init(&hasher);
		hasher.add(&hasher, (const uint8_t*)member_cs.m_buf, strlen(member_cs.m_buf));
		binary_hash = malloc(hasher.size);
		hasher.finish(&hasher, binary_hash);
	}

	/* output the first 8 bytes as 16 hex-characters - CAVE: if the lenght changes here, also adapt mr_extract_grpid_from_rfc724_mid() */
	ret = calloc(1, 256);
	for( i = 0; i < 8; i++ ) {
		sprintf(&ret[i*2], "%02x", (int)binary_hash[i]);
	}

	/* cleanup */
	mrarray_free_ptr(member_addrs);
	mrarray_unref(member_addrs);
	free(member_ids_str);
	free(binary_hash);
	if( stmt ) { sqlite3_finalize(stmt); }
	if( q3 ) { sqlite3_free(q3); }
	free(member_cs.m_buf);
	return ret;
}


static uint32_t create_group_record__(mrmailbox_t* mailbox, const char* grpid, const char* grpname, int create_blocked)
{
	uint32_t      chat_id = 0;
	sqlite3_stmt* stmt = NULL;

	stmt = mrsqlite3_prepare_v2_(mailbox->m_sql,
		"INSERT INTO chats (type, name, grpid, blocked) VALUES(?, ?, ?, ?);");
	sqlite3_bind_int (stmt, 1, MR_CHAT_TYPE_GROUP);
	sqlite3_bind_text(stmt, 2, grpname, -1, SQLITE_STATIC);
	sqlite3_bind_text(stmt, 3, grpid, -1, SQLITE_STATIC);
	sqlite3_bind_int (stmt, 4, create_blocked);
	if( sqlite3_step(stmt)!=SQLITE_DONE ) {
		goto cleanup;
	}
	chat_id = sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj);

cleanup:
	if( stmt) { sqlite3_finalize(stmt); }
	return chat_id;
}


/*******************************************************************************
 * Handle groups for received messages
 ******************************************************************************/


static void create_or_lookup_adhoc_group__(mrmailbox_t* mailbox, mrmimeparser_t* mime_parser, int create_blocked,
                                           int32_t from_id, const mrarray_t* to_ids,/*does not contain SELF*/
                                           uint32_t* ret_chat_id, int* ret_chat_id_blocked)
{
	/* if we're here, no grpid was found, check there is an existing ad-hoc
	group matching the to-list or if we can create one */
	mrarray_t*    member_ids      = NULL;
	uint32_t      chat_id         = 0;
	int           chat_id_blocked = 0, i;
	mrarray_t*    chat_ids        = NULL;
	char*         chat_ids_str    = NULL, *q3 = NULL;
	sqlite3_stmt* stmt            = NULL;
	char*         grpid           = NULL;
	char*         grpname         = NULL;

	/* build member list from the given ids */
	if( mrarray_get_cnt(to_ids)==0 || mrmimeparser_is_mailinglist_message(mime_parser) ) {
		goto cleanup; /* too few contacts or a mailinglist */
	}
	member_ids = mrarray_duplicate(to_ids);
	if( !mrarray_search_id(member_ids, from_id, NULL) )            { mrarray_add_id(member_ids, from_id); }
	if( !mrarray_search_id(member_ids, MR_CONTACT_ID_SELF, NULL) ) { mrarray_add_id(member_ids, MR_CONTACT_ID_SELF); }
	if( mrarray_get_cnt(member_ids) < 3 ) {
		goto cleanup; /* too few contacts given */
	}

	/* check if the member list matches other chats, if so, choose the one with the most recent activity */
	chat_ids = search_chat_ids_by_contact_ids(mailbox, member_ids);
	if( mrarray_get_cnt(chat_ids)>0 ) {
		chat_ids_str = mrarray_get_string(chat_ids, ",");
		q3 = sqlite3_mprintf("SELECT c.id, c.blocked "
							 " FROM chats c "
							 " LEFT JOIN msgs m ON m.chat_id=c.id "
							 " WHERE c.id IN(%s) "
							 " ORDER BY m.timestamp DESC, m.id DESC "
							 " LIMIT 1;",
							 chat_ids_str);
		stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, q3);
		if( sqlite3_step(stmt)==SQLITE_ROW ) {
			chat_id         = sqlite3_column_int(stmt, 0);
			chat_id_blocked = sqlite3_column_int(stmt, 1);
			goto cleanup; /* success, chat found */
		}
	}

	/* we do not check if the message is a reply to another group, this may result in
	chats with unclear member list. instead we create a new group in the following lines ... */

	/* create a new ad-hoc group
	- there is no need to check if this group exists; otherwise we would have catched it above */
	if( (grpid = create_adhoc_grp_id__(mailbox, member_ids)) == NULL ) {
		goto cleanup;
	}

	/* use subject as initial chat name */
	if( mime_parser->m_subject && mime_parser->m_subject[0] ) {
		grpname = safe_strdup(mime_parser->m_subject);
	}
	else {
		grpname = mrstock_str_repl_pl(MR_STR_MEMBER,  mrarray_get_cnt(member_ids));
	}

	/* create group record */
	chat_id = create_group_record__(mailbox, grpid, grpname, create_blocked);
	chat_id_blocked = create_blocked;
	for( i = 0; i < mrarray_get_cnt(member_ids); i++ ) {
		mrmailbox_add_contact_to_chat__(mailbox, chat_id, mrarray_get_id(member_ids, i));
	}

	mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, chat_id, 0);

cleanup:
	mrarray_unref(member_ids);
	mrarray_unref(chat_ids);
	free(chat_ids_str);
	free(grpid);
	free(grpname);
	if( stmt ) { sqlite3_finalize(stmt); }
	if( q3 ) { sqlite3_free(q3); }
	if( ret_chat_id )         { *ret_chat_id         = chat_id; }
	if( ret_chat_id_blocked ) { *ret_chat_id_blocked = chat_id_blocked; }
}


/* the function tries extracts the group-id from the message and returns the
corresponding chat_id.  If the chat_id is not existant, it is created.
If the message contains groups commands (name, profile image, changed members),
they are executed as well.

if no group-id could be extracted from the message, create_or_lookup_adhoc_group__() is called
which tries to create or find out the chat_id by:
- is there a group with the same recipients? if so, use this (if there are multiple, use the most recent one)
- create an ad-hoc group based on the recipient list

So when the function returns, the caller has the group id matching the current
state of the group. */
static void create_or_lookup_group__(mrmailbox_t* mailbox, mrmimeparser_t* mime_parser, int create_blocked,
                                     int32_t from_id, const mrarray_t* to_ids,
                                     uint32_t* ret_chat_id, int* ret_chat_id_blocked)
{
	uint32_t              chat_id = 0;
	int                   chat_id_blocked = 0;
	char*                 grpid = NULL;
	char*                 grpname = NULL;
	sqlite3_stmt*         stmt;
	int                   i, to_ids_cnt = mrarray_get_cnt(to_ids);
	char*                 self_addr = NULL;
	int                   recreate_member_list = 0;
	int                   send_EVENT_CHAT_MODIFIED = 0;

	char*                 X_MrRemoveFromGrp = NULL; /* pointer somewhere into mime_parser, must not be freed */
	char*                 X_MrAddToGrp = NULL; /* pointer somewhere into mime_parser, must not be freed */
	int                   X_MrGrpNameChanged = 0;
	int                   X_MrGrpImageChanged = 0;

	/* search the grpid in the header */
	{
		struct mailimf_field*          field = NULL;
		struct mailimf_optional_field* optional_field = NULL;

		if( (optional_field=mrmimeparser_lookup_optional_field2(mime_parser, "Chat-Group-ID", "X-MrGrpId"))!=NULL ) {
			grpid = safe_strdup(optional_field->fld_value);
		}

		if( grpid == NULL )
		{
			if( (field=mrmimeparser_lookup_field(mime_parser, "Message-ID"))!=NULL && field->fld_type==MAILIMF_FIELD_MESSAGE_ID ) {
				struct mailimf_message_id* fld_message_id = field->fld_data.fld_message_id;
				if( fld_message_id ) {
					grpid = mr_extract_grpid_from_rfc724_mid(fld_message_id->mid_value);
				}
			}

			if( grpid == NULL )
			{
				if( (field=mrmimeparser_lookup_field(mime_parser, "In-Reply-To"))!=NULL && field->fld_type==MAILIMF_FIELD_IN_REPLY_TO ) {
					struct mailimf_in_reply_to* fld_in_reply_to = field->fld_data.fld_in_reply_to;
					if( fld_in_reply_to ) {
						grpid = mr_extract_grpid_from_rfc724_mid_list(fld_in_reply_to->mid_list);
					}
				}

				if( grpid == NULL )
				{
					if( (field=mrmimeparser_lookup_field(mime_parser, "References"))!=NULL && field->fld_type==MAILIMF_FIELD_REFERENCES ) {
						struct mailimf_references* fld_references = field->fld_data.fld_references;
						if( fld_references ) {
							grpid = mr_extract_grpid_from_rfc724_mid_list(fld_references->mid_list);
						}
					}

					if( grpid == NULL )
					{
						create_or_lookup_adhoc_group__(mailbox, mime_parser, create_blocked, from_id, to_ids, &chat_id, &chat_id_blocked);
						goto cleanup;
					}
				}
			}
		}

		if( (optional_field=mrmimeparser_lookup_optional_field2(mime_parser, "Chat-Group-Name", "X-MrGrpName"))!=NULL ) {
			grpname = mr_decode_header_string(optional_field->fld_value); /* this is no changed groupname message */
		}

		if( (optional_field=mrmimeparser_lookup_optional_field2(mime_parser, "Chat-Group-Member-Removed", "X-MrRemoveFromGrp"))!=NULL ) {
			X_MrRemoveFromGrp = optional_field->fld_value;
			mime_parser->m_is_system_message = MR_SYSTEM_MEMBER_REMOVED_FROM_GROUP;
		}
		else if( (optional_field=mrmimeparser_lookup_optional_field2(mime_parser, "Chat-Group-Member-Added", "X-MrAddToGrp"))!=NULL ) {
			X_MrAddToGrp = optional_field->fld_value;
			mime_parser->m_is_system_message = MR_SYSTEM_MEMBER_ADDED_TO_GROUP;
		}
		else if( (optional_field=mrmimeparser_lookup_optional_field2(mime_parser, "Chat-Group-Name-Changed", "X-MrGrpNameChanged"))!=NULL ) {
			X_MrGrpNameChanged = 1;
			mime_parser->m_is_system_message = MR_SYSTEM_GROUPNAME_CHANGED;
		}
		else if( (optional_field=mrmimeparser_lookup_optional_field(mime_parser, "Chat-Group-Image"))!=NULL ) {
			X_MrGrpImageChanged = 1;
			mime_parser->m_is_system_message = MR_SYSTEM_GROUPIMAGE_CHANGED;
		}
	}

	/* check, if we have a chat with this group ID */
	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_CHATS_WHERE_grpid,
		"SELECT id, blocked FROM chats WHERE grpid=?;");
	sqlite3_bind_text (stmt, 1, grpid, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt)==SQLITE_ROW ) {
		chat_id = sqlite3_column_int(stmt, 0);
		chat_id_blocked = sqlite3_column_int(stmt, 1);
	}

	/* check if the sender is a member of the existing group -
	if not, the message does not go to the group chat but to the normal chat with the sender */
	if( chat_id!=0 && !mrmailbox_is_contact_in_chat__(mailbox, chat_id, from_id) ) {
		chat_id = 0;
		create_or_lookup_adhoc_group__(mailbox, mime_parser, create_blocked, from_id, to_ids, &chat_id, &chat_id_blocked);
		goto cleanup;
	}

	/* check if the group does not exist but should be created */
	int group_explicitly_left = mrmailbox_is_group_explicitly_left__(mailbox, grpid);

	self_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", "");
	if( chat_id == 0
	 && !mrmimeparser_is_mailinglist_message(mime_parser)
	 && grpname
	 && X_MrRemoveFromGrp==NULL /*otherwise, a pending "quit" message may pop up*/
	 && (!group_explicitly_left || (X_MrAddToGrp&&strcasecmp(self_addr,X_MrAddToGrp)==0) ) /*re-create explicitly left groups only if ourself is re-added*/
	 )
	{
		chat_id = create_group_record__(mailbox, grpid, grpname, create_blocked);
		chat_id_blocked = create_blocked;
		recreate_member_list = 1;
	}

	/* again, check chat_id */
	if( chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		chat_id = 0;
		if( group_explicitly_left ) {
			chat_id = MR_CHAT_ID_TRASH; /* we got a message for a chat we've deleted - do not show this even as a normal chat */
		}
		else {
			create_or_lookup_adhoc_group__(mailbox, mime_parser, create_blocked, from_id, to_ids, &chat_id, &chat_id_blocked);
		}
		goto cleanup;
	}

	/* execute group commands */
	if( X_MrAddToGrp || X_MrRemoveFromGrp )
	{
		recreate_member_list = 1;
	}
	else if( X_MrGrpNameChanged && grpname && strlen(grpname) < 200 )
	{
		stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "UPDATE chats SET name=? WHERE id=?;");
		sqlite3_bind_text(stmt, 1, grpname, -1, SQLITE_STATIC);
		sqlite3_bind_int (stmt, 2, chat_id);
		sqlite3_step(stmt);
		sqlite3_finalize(stmt);
		mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, chat_id, 0);
	}

	if( X_MrGrpImageChanged )
	{
		int   ok = 0;
		char* grpimage = NULL;
		if( carray_count(mime_parser->m_parts)>=1 ) {
			mrmimepart_t* textpart = (mrmimepart_t*)carray_get(mime_parser->m_parts, 0);
			if( textpart->m_type == MR_MSG_TEXT ) {
				if( carray_count(mime_parser->m_parts)>=2 ) {
					mrmimepart_t* imgpart = (mrmimepart_t*)carray_get(mime_parser->m_parts, 1);
					if( imgpart->m_type == MR_MSG_IMAGE ) {
						grpimage = mrparam_get(imgpart->m_param, MRP_FILE, NULL);
						ok = 1;
					}
				}
				else {
					ok = 1;
				}
			}
		}

		if( ok ) {
			mrchat_t* chat = mrchat_new(mailbox);
				mrmailbox_log_info(mailbox, 0, "New group image set to %s.", grpimage? "DELETED" : grpimage);
				mrchat_load_from_db__(chat, chat_id);
				mrparam_set(chat->m_param, MRP_PROFILE_IMAGE, grpimage/*may be NULL*/);
				mrchat_update_param__(chat);
			mrchat_unref(chat);
			free(grpimage);
			send_EVENT_CHAT_MODIFIED = 1;
		}
	}

	/* add members to group/check members
	for recreation: we should add a timestamp */
	if( recreate_member_list )
	{
		const char* skip = X_MrRemoveFromGrp? X_MrRemoveFromGrp : NULL;

		stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "DELETE FROM chats_contacts WHERE chat_id=?;");
		sqlite3_bind_int (stmt, 1, chat_id);
		sqlite3_step(stmt);
		sqlite3_finalize(stmt);

		if( skip==NULL || strcasecmp(self_addr, skip) != 0 ) {
			mrmailbox_add_contact_to_chat__(mailbox, chat_id, MR_CONTACT_ID_SELF);
		}

		if( from_id > MR_CONTACT_ID_LAST_SPECIAL ) {
			if( mrmailbox_contact_addr_equals__(mailbox, from_id, self_addr)==0
			 && (skip==NULL || mrmailbox_contact_addr_equals__(mailbox, from_id, skip)==0) ) {
				mrmailbox_add_contact_to_chat__(mailbox, chat_id, from_id);
			}
		}

		for( i = 0; i < to_ids_cnt; i++ )
		{
			uint32_t to_id = mrarray_get_id(to_ids, i); /* to_id is only once in to_ids and is non-special */
			if( mrmailbox_contact_addr_equals__(mailbox, to_id, self_addr)==0
			 && (skip==NULL || mrmailbox_contact_addr_equals__(mailbox, to_id, skip)==0) ) {
				mrmailbox_add_contact_to_chat__(mailbox, chat_id, to_id);
			}
		}
		send_EVENT_CHAT_MODIFIED = 1;
	}

	if( send_EVENT_CHAT_MODIFIED ) {
		mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, chat_id, 0);
	}

	/* check the number of receivers -
	the only critical situation is if the user hits "Reply" instead of "Reply all" in a non-messenger-client */
	if( to_ids_cnt == 1 && mime_parser->m_is_send_by_messenger==0 ) {
		int is_contact_cnt = mrmailbox_get_chat_contact_count__(mailbox, chat_id);
		if( is_contact_cnt > 3 /* to_ids_cnt==1 may be "From: A, To: B, SELF" as SELF is not counted in to_ids_cnt. So everything up to 3 is no error. */ ) {
			chat_id = 0;
			create_or_lookup_adhoc_group__(mailbox, mime_parser, create_blocked, from_id, to_ids, &chat_id, &chat_id_blocked);
			goto cleanup;
		}
	}

cleanup:
	free(grpid);
	free(grpname);
	free(self_addr);
	if( ret_chat_id )         { *ret_chat_id         = chat_id;                   }
	if( ret_chat_id_blocked ) { *ret_chat_id_blocked = chat_id? chat_id_blocked : 0; }
}


/*******************************************************************************
 * Receive a message and add it to the database
 ******************************************************************************/


void mrmailbox_receive_imf(mrmailbox_t* mailbox, const char* imf_raw_not_terminated, size_t imf_raw_bytes,
                           const char* server_folder, uint32_t server_uid, uint32_t flags)
{
	/* the function returns the number of created messages in the database */
	int              incoming = 0;
	int              incoming_origin = 0;
	#define          outgoing (!incoming)

	mrarray_t*       to_ids = NULL;
	int              to_self = 0;

	uint32_t         from_id = 0;
	int              from_id_blocked = 0;
	uint32_t         to_id   = 0;
	uint32_t         chat_id = 0;
	int              chat_id_blocked = 0;
	int              state   = MR_STATE_UNDEFINED;
	int              hidden = 0;

	sqlite3_stmt*    stmt;
	size_t           i, icnt;
	uint32_t         first_dblocal_id = 0;
	char*            rfc724_mid = NULL; /* Message-ID from the header */
	time_t           sort_timestamp = MR_INVALID_TIMESTAMP;
	time_t           sent_timestamp = MR_INVALID_TIMESTAMP;
	time_t           rcvd_timestamp = MR_INVALID_TIMESTAMP;
	mrmimeparser_t*  mime_parser = mrmimeparser_new(mailbox->m_blobdir, mailbox);
	int              db_locked = 0;
	int              transaction_pending = 0;
	const struct mailimf_field* field;

	carray*          created_db_entries = carray_new(16);
	int              create_event_to_send = MR_EVENT_MSGS_CHANGED;

	carray*          rr_event_to_send = carray_new(16);

	int              has_return_path = 0;
	int              is_handshake_message = 0;
	char*            txt_raw = NULL;

	mrmailbox_log_info(mailbox, 0, "Receiving message %s/%lu...", server_folder? server_folder:"?", server_uid);

	to_ids = mrarray_new(mailbox, 16);
	if( to_ids==NULL || created_db_entries==NULL || rr_event_to_send==NULL || mime_parser == NULL ) {
		mrmailbox_log_info(mailbox, 0, "Bad param.");
		goto cleanup;
	}

	/* parse the imf to mailimf_message {
	        mailimf_fields* msg_fields {
	          clist* fld_list; // list of mailimf_field
	        }
	        mailimf_body* msg_body { // != NULL
                const char * bd_text; // != NULL
                size_t bd_size;
	        }
	   };
	normally, this is done by mailimf_message_parse(), however, as we also need the MIME data,
	we use mailmime_parse() through MrMimeParser (both call mailimf_struct_multiple_parse() somewhen, I did not found out anything
	that speaks against this approach yet) */
	mrmimeparser_parse(mime_parser, imf_raw_not_terminated, imf_raw_bytes);
	if( mrhash_count(&mime_parser->m_header)==0 ) {
		mrmailbox_log_info(mailbox, 0, "No header.");
		goto cleanup; /* Error - even adding an empty record won't help as we do not know the message ID */
	}

	/* Check, if the mail comes from extern, resp. is not sent by us.  This is a _really_ important step
	as messages sent by us are used to validate other mail senders and receivers.
	For this purpose, we assume, the `Return-Path:`-header is never present if the message is sent by us.
	The `Received:`-header may be another idea, however, this is also set if mails are transfered from other accounts via IMAP.
	Using `From:` alone is no good idea, as mailboxes may use different sending-addresses - moreover, they may change over the years.
	However, we use `From:` as an additional hint below. */
	if( mrmimeparser_lookup_field(mime_parser, "Return-Path") ) {
		has_return_path = 1;
	}

	if( has_return_path ) {
		incoming = 1;
	}

	mrsqlite3_lock(mailbox->m_sql);
	db_locked = 1;
	mrsqlite3_begin_transaction__(mailbox->m_sql);
	transaction_pending = 1;

		/* for incoming messages, get From: and check if it is known (for known From:'s we add the other To:/Cc:/Bcc: in the 3rd pass) */
		if( incoming
		 && (field=mrmimeparser_lookup_field(mime_parser, "From"))!=NULL
		 && field->fld_type==MAILIMF_FIELD_FROM)
		{
			struct mailimf_from* fld_from = field->fld_data.fld_from;
			if( fld_from )
			{
				int check_self;
				mrarray_t* from_list = mrarray_new(mailbox, 16);
				mrmailbox_add_or_lookup_contacts_by_mailbox_list__(mailbox, fld_from->frm_mb_list, MR_ORIGIN_INCOMING_UNKNOWN_FROM, from_list, &check_self);
				if( check_self )
				{
					if( mrmimeparser_sender_equals_recipient(mime_parser) )
					{
						from_id = MR_CONTACT_ID_SELF;
					}
					else
					{
						incoming = 0; /* The `Return-Path:`-approach above works well, however, there may be outgoing messages which we also receive -
									  for these messages, the `Return-Path:` is set although we're the sender.  To correct these cases, we add an
									  additional From: check - which, however, will not work for older From:-addresses used on the mailbox. */
					}
				}
				else
				{
					if( mrarray_get_cnt(from_list)>=1 ) /* if there is no from given, from_id stays 0 which is just fine. These messages are very rare, however, we have to add them to the database (they go to the "deaddrop" chat) to avoid a re-download from the server. See also [**] */
					{
						from_id = mrarray_get_id(from_list, 0);
						incoming_origin = mrmailbox_get_contact_origin__(mailbox, from_id, &from_id_blocked);
					}
				}
				mrarray_unref(from_list);
			}
		}

		/* Make sure, to_ids starts with the first To:-address (Cc: and Bcc: are added in the loop below pass) */
		if( (field=mrmimeparser_lookup_field(mime_parser, "To"))!=NULL
		 && field->fld_type==MAILIMF_FIELD_TO )
		{
			struct mailimf_to* fld_to = field->fld_data.fld_to; /* can be NULL */
			if( fld_to )
			{
				mrmailbox_add_or_lookup_contacts_by_address_list__(mailbox, fld_to->to_addr_list /*!= NULL*/,
					outgoing? MR_ORIGIN_OUTGOING_TO : (incoming_origin>=MR_ORIGIN_MIN_VERIFIED? MR_ORIGIN_INCOMING_TO : MR_ORIGIN_INCOMING_UNKNOWN_TO), to_ids, &to_self);
			}
		}

		if( mrmimeparser_has_nonmeta(mime_parser) )
		{

			/**********************************************************************
			 * Add parts
			 *********************************************************************/

			/* collect the rest information */
			if( (field=mrmimeparser_lookup_field(mime_parser, "Cc"))!=NULL && field->fld_type==MAILIMF_FIELD_CC )
			{
				struct mailimf_cc* fld_cc = field->fld_data.fld_cc;
				if( fld_cc ) {
					mrmailbox_add_or_lookup_contacts_by_address_list__(mailbox, fld_cc->cc_addr_list,
						outgoing? MR_ORIGIN_OUTGOING_CC : (incoming_origin>=MR_ORIGIN_MIN_VERIFIED? MR_ORIGIN_INCOMING_CC : MR_ORIGIN_INCOMING_UNKNOWN_CC), to_ids, NULL);
				}
			}

			if( (field=mrmimeparser_lookup_field(mime_parser, "Bcc"))!=NULL && field->fld_type==MAILIMF_FIELD_BCC )
			{
				struct mailimf_bcc* fld_bcc = field->fld_data.fld_bcc;
				if( outgoing && fld_bcc ) {
					mrmailbox_add_or_lookup_contacts_by_address_list__(mailbox, fld_bcc->bcc_addr_list,
						MR_ORIGIN_OUTGOING_BCC, to_ids, NULL);
				}
			}

			/* check if the message introduces a new chat:
			- outgoing messages introduce a chat with the first to: address if they are sent by a messenger
			- incoming messages introduce a chat only for known contacts if they are sent by a messenger
			(of course, the user can add other chats manually later) */
			if( incoming )
			{
				state = (flags&MR_IMAP_SEEN)? MR_STATE_IN_SEEN : MR_STATE_IN_FRESH;
				to_id = MR_CONTACT_ID_SELF;

				/* test if there is a normal chat with the sender - if so, this allows us to create groups in the next step */
				uint32_t test_normal_chat_id = 0;
				int      test_normal_chat_id_blocked = 0;
				mrmailbox_lookup_real_nchat_by_contact_id__(mailbox, from_id, &test_normal_chat_id, &test_normal_chat_id_blocked);

				/* get the chat_id - a chat_id here is no indicator that the chat is displayed in the normal list, it might also be
				blocked and displayed in the deaddrop as a result */
				if( chat_id == 0 )
				{
					/* try to create a group
					(groups appear automatically only if the _sender_ is known, see core issue #54) */
					int create_blocked = ((test_normal_chat_id&&test_normal_chat_id_blocked==MR_CHAT_NOT_BLOCKED) || incoming_origin>=MR_ORIGIN_MIN_START_NEW_NCHAT/*always false, for now*/)? MR_CHAT_NOT_BLOCKED : MR_CHAT_DEADDROP_BLOCKED;
					create_or_lookup_group__(mailbox, mime_parser, create_blocked, from_id, to_ids, &chat_id, &chat_id_blocked);
					if( chat_id && chat_id_blocked && !create_blocked ) {
						mrmailbox_unblock_chat__(mailbox, chat_id);
						chat_id_blocked = 0;
					}
				}

				if( chat_id == 0 )
				{
					/* check if the message belongs to a mailing list */
					if( mrmimeparser_is_mailinglist_message(mime_parser) ) {
						chat_id = MR_CHAT_ID_TRASH;
						mrmailbox_log_info(mailbox, 0, "Message belongs to a mailing list and is ignored.");
					}
				}

				if( chat_id == 0 )
				{
					/* try to create a normal chat */
					int create_blocked = (incoming_origin>=MR_ORIGIN_MIN_START_NEW_NCHAT/*always false, for now*/ || from_id==to_id)? MR_CHAT_NOT_BLOCKED : MR_CHAT_DEADDROP_BLOCKED;
					if( test_normal_chat_id ) {
						chat_id         = test_normal_chat_id;
						chat_id_blocked = test_normal_chat_id_blocked;
					}
					else {
						mrmailbox_create_or_lookup_nchat_by_contact_id__(mailbox, from_id, create_blocked, &chat_id, &chat_id_blocked);
					}

					if( chat_id && chat_id_blocked ) {
						if( !create_blocked ) {
							mrmailbox_unblock_chat__(mailbox, chat_id);
							chat_id_blocked = 0;
						}
						else if( mrmailbox_is_reply_to_known_message__(mailbox, mime_parser) ) {
							mrmailbox_scaleup_contact_origin__(mailbox, from_id, MR_ORIGIN_INCOMING_REPLY_TO); /* we do not want any chat to be created implicitly.  Because of the origin-scale-up, the contact requests will pop up and this should be just fine. */
							mrmailbox_log_info(mailbox, 0, "Message is a reply to a known message, mark sender as known.");
							incoming_origin = MR_MAX(incoming_origin, MR_ORIGIN_INCOMING_REPLY_TO);
						}
					}
				}

				if( chat_id == 0 )
				{
					/* maybe from_id is null or sth. else is suspicious, move message to trash */
					chat_id = MR_CHAT_ID_TRASH;
				}

				/* degrade state for unknown senders and non-delta messages
				(the latter may be removed if we run into spam problems, currently this is fine)
				(noticed messages do count as being unread; therefore, the deaddrop will not popup in the chatlist) */
				if( chat_id_blocked && state == MR_STATE_IN_FRESH ) {
					if( incoming_origin<MR_ORIGIN_MIN_VERIFIED && mime_parser->m_is_send_by_messenger==0 ) {
						state = MR_STATE_IN_NOTICED;
					}
				}
			}
			else /* outgoing */
			{
				state = MR_STATE_OUT_DELIVERED; /* the mail is on the IMAP server, probably it is also delivered.  We cannot recreate other states (read, error). */
				from_id = MR_CONTACT_ID_SELF;
				if( mrarray_get_cnt(to_ids) >= 1 ) {
					to_id   = mrarray_get_id(to_ids, 0);

					if( chat_id == 0 )
					{
						create_or_lookup_group__(mailbox, mime_parser, MR_CHAT_NOT_BLOCKED, from_id, to_ids, &chat_id, &chat_id_blocked);
						if( chat_id && chat_id_blocked ) {
							mrmailbox_unblock_chat__(mailbox, chat_id);
							chat_id_blocked = 0;
						}
					}

					if( chat_id == 0 )
					{
						int create_blocked = (mime_parser->m_is_send_by_messenger && !mrmailbox_is_contact_blocked__(mailbox, to_id))? MR_CHAT_NOT_BLOCKED : MR_CHAT_DEADDROP_BLOCKED;
						mrmailbox_create_or_lookup_nchat_by_contact_id__(mailbox, to_id, create_blocked, &chat_id, &chat_id_blocked);
						if( chat_id && chat_id_blocked && !create_blocked ) {
							mrmailbox_unblock_chat__(mailbox, chat_id);
							chat_id_blocked = 0;
						}
					}
				}

				if( chat_id == 0 ) {
					if( mrarray_get_cnt(to_ids) == 0 && to_self ) {
						/* from_id == to_id == MR_CONTACT_ID_SELF - this is a self-sent messages, maybe an Autocrypt Setup Message */
						mrmailbox_create_or_lookup_nchat_by_contact_id__(mailbox, MR_CONTACT_ID_SELF, MR_CHAT_NOT_BLOCKED, &chat_id, &chat_id_blocked);
						if( chat_id && chat_id_blocked ) {
							mrmailbox_unblock_chat__(mailbox, chat_id);
							chat_id_blocked = 0;
						}
					}
				}

				if( chat_id == 0 ) {
					chat_id = MR_CHAT_ID_TRASH;
				}
			}

			/* check of the message is a special handshake message; if so, mark it as "seen" here and handle it when done */
			is_handshake_message = mrmailbox_oob_is_handshake_message__(mailbox, mime_parser);
			if( is_handshake_message ) {
				hidden = 1;
				if( state==MR_STATE_IN_FRESH || state==MR_STATE_IN_NOTICED ) {
					state = MR_STATE_IN_SEEN;
				}
			}

			/* correct message_timestamp, it should not be used before,
			however, we cannot do this earlier as we need from_id to be set */
			if( (field=mrmimeparser_lookup_field(mime_parser, "Date"))!=NULL && field->fld_type==MAILIMF_FIELD_ORIG_DATE ) {
				struct mailimf_orig_date* orig_date = field->fld_data.fld_orig_date;
				if( orig_date ) {
					sent_timestamp = mr_timestamp_from_date(orig_date->dt_date_time); /* is not yet checked against bad times! */
				}
			}
			mrmailbox_calc_timestamps__(mailbox, chat_id, from_id, sent_timestamp, (flags&MR_IMAP_SEEN)? 0 : 1 /*fresh message?*/,
				&sort_timestamp, &sent_timestamp, &rcvd_timestamp);

			/* unarchive chat */
			mrmailbox_unarchive_chat__(mailbox, chat_id);

			/* check, if the mail is already in our database - if so, there's nothing more to do
			(we may get a mail twice eg. if it is moved between folders) */
			if( (field=mrmimeparser_lookup_field(mime_parser, "Message-ID"))!=NULL && field->fld_type==MAILIMF_FIELD_MESSAGE_ID ) {
				struct mailimf_message_id* fld_message_id = field->fld_data.fld_message_id;
				if( fld_message_id ) {
					rfc724_mid = safe_strdup(fld_message_id->mid_value);
				}
			}

			if( rfc724_mid == NULL ) {
				/* header is lacking a Message-ID - this may be the case, if the message was sent from this account and the mail client
				the the SMTP-server set the ID (true eg. for the Webmailer used in all-inkl-KAS)
				in these cases, we build a message ID based on some useful header fields that do never change (date, to)
				we do not use the folder-local id, as this will change if the mail is moved to another folder. */
				rfc724_mid = mr_create_incoming_rfc724_mid(sort_timestamp, from_id, to_ids);
				if( rfc724_mid == NULL ) {
					mrmailbox_log_info(mailbox, 0, "Cannot create Message-ID.");
					goto cleanup;
				}
			}

			{
				char*    old_server_folder = NULL;
				uint32_t old_server_uid = 0;
				if( mrmailbox_rfc724_mid_exists__(mailbox, rfc724_mid, &old_server_folder, &old_server_uid) ) {
					/* The message is already added to our database; rollback.  If needed, update the server_uid which may have changed if the message was moved around on the server. */
					if( strcmp(old_server_folder, server_folder)!=0 || old_server_uid!=server_uid ) {
						mrsqlite3_rollback__(mailbox->m_sql);
						transaction_pending = 0;
						mrmailbox_update_server_uid__(mailbox, rfc724_mid, server_folder, server_uid);
					}
					free(old_server_folder);
					mrmailbox_log_info(mailbox, 0, "Message already in DB.");
					goto cleanup;
				}
			}

			/* if the message is not sent by a messenger, check if it is sent at least as a reply to a messenger message
			(later, we move these replies to the Chats-folder) */
			int msgrmsg = mime_parser->m_is_send_by_messenger; /* 1 or 0 for yes/no */
			if( msgrmsg )
			{
				mrmailbox_log_info(mailbox, 0, "Message sent by another messenger (will be moved to Chats-folder).");
			}
			else
			{
				if( mrmailbox_is_reply_to_messenger_message__(mailbox, mime_parser) )
				{
					mrmailbox_log_info(mailbox, 0, "Message is a reply to a messenger message (will be moved to Chats-folder).");
					msgrmsg = 2; /* 2=no, but is reply to messenger message */
				}
			}

			/* fine, so far.  now, split the message into simple parts usable as "short messages"
			and add them to the database (mails sent by other messenger clients should result
			into only one message; mails sent by other clients may result in several messages (eg. one per attachment)) */
			icnt = carray_count(mime_parser->m_parts); /* should be at least one - maybe empty - part */
			for( i = 0; i < icnt; i++ )
			{
				mrmimepart_t* part = (mrmimepart_t*)carray_get(mime_parser->m_parts, i);
				if( part->m_is_meta ) {
					continue;
				}

				if( part->m_type == MR_MSG_TEXT ) {
					txt_raw = mr_mprintf("%s\n\n%s", mime_parser->m_subject? mime_parser->m_subject : "", part->m_msg_raw);
				}

				if( mime_parser->m_is_system_message ) {
					mrparam_set_int(part->m_param, MRP_SYSTEM_CMD, mime_parser->m_is_system_message);
				}

				stmt = mrsqlite3_predefine__(mailbox->m_sql, INSERT_INTO_msgs_msscftttsmttpb,
					"INSERT INTO msgs (rfc724_mid,server_folder,server_uid,chat_id,from_id, to_id,timestamp,timestamp_sent,timestamp_rcvd,type, state,msgrmsg,txt,txt_raw,param, bytes,hidden)"
					" VALUES (?,?,?,?,?, ?,?,?,?,?, ?,?,?,?,?, ?,?);");
				sqlite3_bind_text (stmt,  1, rfc724_mid, -1, SQLITE_STATIC);
				sqlite3_bind_text (stmt,  2, server_folder, -1, SQLITE_STATIC);
				sqlite3_bind_int  (stmt,  3, server_uid);
				sqlite3_bind_int  (stmt,  4, chat_id);
				sqlite3_bind_int  (stmt,  5, from_id);
				sqlite3_bind_int  (stmt,  6, to_id);
				sqlite3_bind_int64(stmt,  7, sort_timestamp);
				sqlite3_bind_int64(stmt,  8, sent_timestamp);
				sqlite3_bind_int64(stmt,  9, rcvd_timestamp);
				sqlite3_bind_int  (stmt, 10, part->m_type);
				sqlite3_bind_int  (stmt, 11, state);
				sqlite3_bind_int  (stmt, 12, msgrmsg);
				sqlite3_bind_text (stmt, 13, part->m_msg? part->m_msg : "", -1, SQLITE_STATIC);
				sqlite3_bind_text (stmt, 14, txt_raw? txt_raw : "", -1, SQLITE_STATIC);
				sqlite3_bind_text (stmt, 15, part->m_param->m_packed, -1, SQLITE_STATIC);
				sqlite3_bind_int  (stmt, 16, part->m_bytes);
				sqlite3_bind_int  (stmt, 17, hidden);
				if( sqlite3_step(stmt) != SQLITE_DONE ) {
					mrmailbox_log_info(mailbox, 0, "Cannot write DB.");
					goto cleanup; /* i/o error - there is nothing more we can do - in other cases, we try to write at least an empty record */
				}

				free(txt_raw);
				txt_raw = NULL;

				if( first_dblocal_id == 0 ) {
					first_dblocal_id = sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj);
				}

				carray_add(created_db_entries, (void*)(uintptr_t)chat_id, NULL);
				carray_add(created_db_entries, (void*)(uintptr_t)first_dblocal_id, NULL);
			}

			mrmailbox_log_info(mailbox, 0, "Message has %i parts and is moved to chat #%i.", icnt, chat_id);

			/* check event to send */
			if( chat_id == MR_CHAT_ID_TRASH )
			{
				create_event_to_send = 0;
			}
			else if( incoming && state==MR_STATE_IN_FRESH )
			{
				if( from_id_blocked ) {
					create_event_to_send = 0;
				}
				else if( chat_id_blocked ) {
					create_event_to_send = MR_EVENT_MSGS_CHANGED;
					/*if( mrsqlite3_get_config_int__(mailbox->m_sql, "show_deaddrop", 0)!=0 ) {
						create_event_to_send = MR_EVENT_INCOMING_MSG;
					}*/
				}
				else {
					create_event_to_send = MR_EVENT_INCOMING_MSG;
				}
			}
		}


		if( carray_count(mime_parser->m_reports) > 0 )
		{
			/******************************************************************
			 * Handle reports (mainly MDNs)
			 *****************************************************************/

			int mdns_enabled = mrsqlite3_get_config_int__(mailbox->m_sql, "mdns_enabled", MR_MDNS_DEFAULT_ENABLED);
			icnt = carray_count(mime_parser->m_reports);
			for( i = 0; i < icnt; i++ )
			{
				int                        mdn_consumed = 0;
				struct mailmime*           report_root = carray_get(mime_parser->m_reports, i);
				struct mailmime_parameter* report_type = mailmime_find_ct_parameter(report_root, "report-type");
				if( report_root==NULL || report_type==NULL || report_type->pa_value==NULL ) {
					continue;
				}

				if( strcmp(report_type->pa_value, "disposition-notification") == 0
				 && clist_count(report_root->mm_data.mm_multipart.mm_mp_list) >= 2 /* the first part is for humans, the second for machines */ )
				{
					if( mdns_enabled /*to get a clear functionality, do not show incoming MDNs if the options is disabled*/ )
					{
						struct mailmime* report_data = (struct mailmime*)clist_content(clist_next(clist_begin(report_root->mm_data.mm_multipart.mm_mp_list)));
						if( report_data
						 && report_data->mm_content_type->ct_type->tp_type==MAILMIME_TYPE_COMPOSITE_TYPE
						 && report_data->mm_content_type->ct_type->tp_data.tp_composite_type->ct_type==MAILMIME_COMPOSITE_TYPE_MESSAGE
						 && strcmp(report_data->mm_content_type->ct_subtype, "disposition-notification")==0 )
						{
							/* we received a MDN (although the MDN is only a header, we parse it as a complete mail) */
							const char* report_body = NULL;
							size_t      report_body_bytes = 0;
							char*       to_mmap_string_unref = NULL;
							if( mailmime_transfer_decode(report_data, &report_body, &report_body_bytes, &to_mmap_string_unref) )
							{
								struct mailmime* report_parsed = NULL;
								size_t dummy = 0;
								if( mailmime_parse(report_body, report_body_bytes, &dummy, &report_parsed)==MAIL_NO_ERROR
								 && report_parsed!=NULL )
								{
									struct mailimf_fields* report_fields = mailmime_find_mailimf_fields(report_parsed);
									if( report_fields )
									{
										struct mailimf_optional_field* of_disposition = mailimf_find_optional_field(report_fields, "Disposition"); /* MUST be preset, _if_ preset, we assume a sort of attribution and do not go into details */
										struct mailimf_optional_field* of_org_msgid   = mailimf_find_optional_field(report_fields, "Original-Message-ID"); /* can't live without */
										if( of_disposition && of_disposition->fld_value && of_org_msgid && of_org_msgid->fld_value )
										{
											char* rfc724_mid = NULL;
											dummy = 0;
											if( mailimf_msg_id_parse(of_org_msgid->fld_value, strlen(of_org_msgid->fld_value), &dummy, &rfc724_mid)==MAIL_NO_ERROR
											 && rfc724_mid!=NULL )
											{
												uint32_t chat_id = 0;
												uint32_t msg_id = 0;
												if( mrmailbox_mdn_from_ext__(mailbox, from_id, rfc724_mid, &chat_id, &msg_id) ) {
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

								if( to_mmap_string_unref ) { mmap_string_unref(to_mmap_string_unref); }
							}
						}
					}

					/* Move the MDN away to the chats folder.  We do this for:
					- Consumed or not consumed MDNs from other messengers
					- Consumed MDNs from normal MUAs
					Unconsumed MDNs from normal MUAs are _not_ moved.
					NB: we do not delete the MDN as it may be used by other clients

					CAVE: we rely on mrimap_markseen_msg() not to move messages that are already in the correct folder.
					otherwise, the moved message get a new server_uid and is "fresh" again and we will be here again to move it away -
					a classical deadlock, see also (***) in mrimap.c */
					if( mime_parser->m_is_send_by_messenger || mdn_consumed ) {
						char* jobparam = mr_mprintf("%c=%s\n%c=%lu", MRP_SERVER_FOLDER, server_folder, MRP_SERVER_UID, server_uid);
							mrjob_add__(mailbox, MRJ_MARKSEEN_MDN_ON_IMAP, 0, jobparam);
						free(jobparam);
					}
				}

			} /* for() */

		}

		/* debug print? */
		if( mrsqlite3_get_config_int__(mailbox->m_sql, "save_eml", 0) ) {
			char* emlname = mr_mprintf("%s/%s-%i.eml", mailbox->m_blobdir, server_folder, (int)first_dblocal_id /*may be 0 for MDNs*/);
			FILE* emlfileob = fopen(emlname, "w");
			if( emlfileob ) {
				fwrite(imf_raw_not_terminated, 1, imf_raw_bytes, emlfileob);
				fclose(emlfileob);
			}
			free(emlname);
		}


	mrsqlite3_commit__(mailbox->m_sql);
	transaction_pending = 0;

cleanup:
	if( transaction_pending ) { mrsqlite3_rollback__(mailbox->m_sql); }
	if( db_locked ) { mrsqlite3_unlock(mailbox->m_sql); }

	if( is_handshake_message ) {
		mrmailbox_oob_handle_handshake_message(mailbox, mime_parser, chat_id); /* must be called after unlocking before deletion of mime_parser */
	}

	mrmimeparser_unref(mime_parser);
	free(rfc724_mid);
	mrarray_unref(to_ids);

	if( created_db_entries ) {
		if( create_event_to_send ) {
			size_t i, icnt = carray_count(created_db_entries);
			for( i = 0; i < icnt; i += 2 ) {
				mailbox->m_cb(mailbox, create_event_to_send, (uintptr_t)carray_get(created_db_entries, i), (uintptr_t)carray_get(created_db_entries, i+1));
			}
		}
		carray_free(created_db_entries);
	}

	if( rr_event_to_send ) {
		size_t i, icnt = carray_count(rr_event_to_send);
		for( i = 0; i < icnt; i += 2 ) {
			mailbox->m_cb(mailbox, MR_EVENT_MSG_READ, (uintptr_t)carray_get(rr_event_to_send, i), (uintptr_t)carray_get(rr_event_to_send, i+1));
		}
		carray_free(rr_event_to_send);
	}

	free(txt_raw);
}
