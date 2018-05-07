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


#include <stdarg.h>
#include <unistd.h>
#include "mrmailbox_internal.h"
#include "mrkey.h"
#include "mrapeerstate.h"
#include "mrmimeparser.h"
#include "mrmimefactory.h"
#include "mrjob.h"

#define      LOCK                 { mrsqlite3_lock  (mailbox->m_sql); locked = 1; }
#define      UNLOCK  if( locked ) { mrsqlite3_unlock(mailbox->m_sql); locked = 0; }


/*******************************************************************************
 * Tools: Alice's invitenumber and auth mini-datastore
 ******************************************************************************/


/* the "mini-datastore is used to remember Alice's last few invitenumbers and
auths as they're written to a QR code.  This is needed for later
comparison when the data are provided by Bob. */


static void store_tag__(mrmailbox_t* mailbox, const char* datastore_name, const char* to_add)
{
	// prepend new tag to the list of all tags
	#define MAX_REMEMBERED_TAGS 10
	#define MAX_REMEMBERED_CHARS (MAX_REMEMBERED_TAGS*(MR_CREATE_ID_LEN+1))
	char* old_tags = mrsqlite3_get_config__(mailbox->m_sql, datastore_name, "");
	if( strlen(old_tags) > MAX_REMEMBERED_CHARS ) {
		old_tags[MAX_REMEMBERED_CHARS] = 0; // the oldest tag may be incomplete and unrecognizable, however, this should not be a problem as it would be deleted soon anyway
	}
	char* new_tags = mr_mprintf("%s,%s", to_add, old_tags);
	mrsqlite3_set_config__(mailbox->m_sql, datastore_name, new_tags);

	free(old_tags);
	free(new_tags);
}


static int lookup_tag__(mrmailbox_t* mailbox, const char* datastore_name, const char* to_lookup)
{
	int            found       = 0;
	char*          old_tags    = NULL;
	carray*        lines       = NULL;

	old_tags = mrsqlite3_get_config__(mailbox->m_sql, datastore_name, "");
	mr_str_replace(&old_tags, ",", "\n");
	lines = mr_split_into_lines(old_tags);
	for( int i = 0; i < carray_count(lines); i++ ) {
		char* tag  = (char*)carray_get(lines, i); mr_trim(tag);
		if( strlen(tag) >= 4 && strcmp(tag, to_lookup) == 0 ) {
			found = 1;
		}
	}

	mr_free_splitted_lines(lines);
	free(old_tags);
	return found;
}


/*******************************************************************************
 * Tools: Handle degraded keys and lost verificaton
 ******************************************************************************/


void mrmailbox_handle_degrade_event(mrmailbox_t* mailbox, mrapeerstate_t* peerstate)
{
	sqlite3_stmt* stmt            = NULL;
	int           locked          = 0;
	uint32_t      contact_id      = 0;
	uint32_t      contact_chat_id = 0;

	if( mailbox == NULL || peerstate == NULL ) {
		goto cleanup;
	}

	// - we do not issue an warning for MRA_DE_ENCRYPTION_PAUSED as this is quite normal
	// - currently, we do not issue an extra warning for MRA_DE_VERIFICATION_LOST - this always comes
	//   together with MRA_DE_FINGERPRINT_CHANGED which is logged, the idea is not to bother
	//   with things they cannot fix, so the user is just kicked from the verified group
	//   (and he will know this and can fix this)

	if( peerstate->m_degrade_event & MRA_DE_FINGERPRINT_CHANGED )
	{
		LOCK

			stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "SELECT id FROM contacts WHERE addr=?;");
				sqlite3_bind_text(stmt, 1, peerstate->m_addr, -1, SQLITE_STATIC);
				sqlite3_step(stmt);
				contact_id = sqlite3_column_int(stmt, 0);
			sqlite3_finalize(stmt);

			if( contact_id == 0 ) {
				goto cleanup;
			}

			mrmailbox_create_or_lookup_nchat_by_contact_id__(mailbox, contact_id, MR_CHAT_DEADDROP_BLOCKED, &contact_chat_id, NULL);

		UNLOCK

		char* msg = mr_mprintf("Changed setup for %s", peerstate->m_addr);
		mrmailbox_add_device_msg(mailbox, contact_chat_id, msg);
		free(msg);
		mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, contact_chat_id, 0);
	}

cleanup:
	UNLOCK
}


/*******************************************************************************
 * Tools: Misc.
 ******************************************************************************/


static int encrypted_and_signed(mrmimeparser_t* mimeparser, const char* expected_fingerprint)
{
	if( !mimeparser->m_e2ee_helper->m_encrypted ) {
		mrmailbox_log_warning(mimeparser->m_mailbox, 0, "Message not encrypted.");
		return 0;
	}

	if( mrhash_count(mimeparser->m_e2ee_helper->m_signatures)<=0 ) {
		mrmailbox_log_warning(mimeparser->m_mailbox, 0, "Message not signed.");
		return 0;
	}

	if( expected_fingerprint == NULL ) {
		mrmailbox_log_warning(mimeparser->m_mailbox, 0, "Fingerprint for comparison missing.");
		return 0;
	}

	if( mrhash_find_str(mimeparser->m_e2ee_helper->m_signatures, expected_fingerprint) == NULL ) {
		mrmailbox_log_warning(mimeparser->m_mailbox, 0, "Message does not match expected fingerprint %s.", expected_fingerprint);
		return 0;
	}

	return 1;
}


static char* get_self_fingerprint(mrmailbox_t* mailbox)
{
	int      locked      = 0;
	char*    self_addr   = NULL;
	mrkey_t* self_key    = mrkey_new();
	char*    fingerprint = NULL;

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( (self_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", NULL)) == NULL
		 || !mrkey_load_self_public__(self_key, self_addr, mailbox->m_sql) ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	if( (fingerprint=mrkey_get_fingerprint(self_key)) == NULL ) {
		goto cleanup;
	}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	free(self_addr);
	mrkey_unref(self_key);
	return fingerprint;
}


static uint32_t chat_id_2_contact_id(mrmailbox_t* mailbox, uint32_t contact_chat_id)
{
	uint32_t   contact_id = 0;
	mrarray_t* contacts = mrmailbox_get_chat_contacts(mailbox, contact_chat_id);

	if( mrarray_get_cnt(contacts) != 1 ) {
		goto cleanup;
	}

	contact_id = mrarray_get_id(contacts, 0);

cleanup:
	mrarray_unref(contacts);
	return contact_id;
}


static int fingerprint_equals_sender(mrmailbox_t* mailbox, const char* fingerprint, uint32_t contact_chat_id)
{
	int             fingerprint_equal      = 0;
	int             locked                 = 0;
	mrarray_t*      contacts               = mrmailbox_get_chat_contacts(mailbox, contact_chat_id);
	mrcontact_t*    contact                = mrcontact_new(mailbox);
	mrapeerstate_t* peerstate              = mrapeerstate_new(mailbox);
	char*           fingerprint_normalized = NULL;

	if( mrarray_get_cnt(contacts) != 1 ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( !mrcontact_load_from_db__(contact, mailbox->m_sql, mrarray_get_id(contacts, 0))
		 || !mrapeerstate_load_by_addr__(peerstate, mailbox->m_sql, contact->m_addr) ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	fingerprint_normalized = mr_normalize_fingerprint(fingerprint);

	if( strcasecmp(fingerprint_normalized, peerstate->m_public_key_fingerprint) == 0 ) {
		fingerprint_equal = 1;
	}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	free(fingerprint_normalized);
	mrcontact_unref(contact);
	mrarray_unref(contacts);
	return fingerprint_equal;
}


static int mark_peer_as_verified__(mrmailbox_t* mailbox, const char* fingerprint)
{
	int             success = 0;
	mrapeerstate_t* peerstate = mrapeerstate_new(mailbox);

	if( !mrapeerstate_load_by_fingerprint__(peerstate, mailbox->m_sql, fingerprint) ) {
		goto cleanup;
	}

	if( !mrapeerstate_set_verified(peerstate, MRA_PUBLIC_KEY, fingerprint, MRV_BIDIRECTIONAL) ) {
		goto cleanup;
	}

	// set MUTUAL as an out-of-band-verification is a strong hint that encryption is wanted.
	// the state may be corrected by the Autocrypt headers as usual later;
	// maybe it is a good idea to add the prefer-encrypt-state to the QR code.
	peerstate->m_prefer_encrypt = MRA_PE_MUTUAL;
	peerstate->m_to_save       |= MRA_SAVE_ALL;

	mrapeerstate_save_to_db__(peerstate, mailbox->m_sql, 0);
	success = 1;

cleanup:
	mrapeerstate_unref(peerstate);
	return success;
}


static const char* lookup_field(mrmimeparser_t* mimeparser, const char* key)
{
	const char* value = NULL;
	struct mailimf_field* field = mrmimeparser_lookup_field(mimeparser, key);
	if( field == NULL || field->fld_type != MAILIMF_FIELD_OPTIONAL_FIELD
	 || field->fld_data.fld_optional_field == NULL || (value=field->fld_data.fld_optional_field->fld_value) == NULL ) {
		return NULL;
	}
	return value;
}


static void send_handshake_msg(mrmailbox_t* mailbox, uint32_t contact_chat_id, const char* step, const char* param2, const char* fingerprint, const char* grpid)
{
	mrmsg_t* msg = mrmsg_new();

	msg->m_type = MR_MSG_TEXT;
	msg->m_text = mr_mprintf("Secure-Join: %s", step);
	msg->m_hidden = 1;
	mrparam_set_int(msg->m_param, MRP_CMD,       MR_CMD_SECUREJOIN_MESSAGE);
	mrparam_set    (msg->m_param, MRP_CMD_PARAM, step);

	if( param2 ) {
		mrparam_set(msg->m_param, MRP_CMD_PARAM2, param2); // depening on step, this goes either to Secure-Join-Invitenumber or Secure-Join-Auth in mrmimefactory.c
	}

	if( fingerprint ) {
		mrparam_set(msg->m_param, MRP_CMD_PARAM3, fingerprint);
	}

	if( grpid ) {
		mrparam_set(msg->m_param, MRP_CMD_PARAM4, grpid);
	}

	if( strcmp(step, "vg-request")==0 || strcmp(step, "vc-request")==0 ) {
		mrparam_set_int(msg->m_param, MRP_FORCE_PLAINTEXT, 1); // the request message MUST NOT be encrypted - it may be that the key has changed and the message cannot be decrypted otherwise
	}
	else {
		mrparam_set_int(msg->m_param, MRP_GUARANTEE_E2EE, 1); /* all but the first message MUST be encrypted */
	}

	mrmailbox_send_msg_object(mailbox, contact_chat_id, msg);

	mrmsg_unref(msg);
}


static void could_not_establish_secure_connection(mrmailbox_t* mailbox, uint32_t contact_chat_id, const char* details)
{
	uint32_t     contact_id = chat_id_2_contact_id(mailbox, contact_chat_id);
	mrcontact_t* contact    = mrmailbox_get_contact(mailbox, contact_id);
	char*        msg        = mr_mprintf("Could not establish secure connection to %s.", contact? contact->m_addr : "?");

	mrmailbox_add_device_msg(mailbox, contact_chat_id, msg);

	mrmailbox_log_error(mailbox, 0, "%s (%s)", msg, details); // additionaly raise an error; this typically results in a toast (inviter side) or a dialog (joiner side)

	free(msg);
	mrcontact_unref(contact);
}


static void secure_connection_established(mrmailbox_t* mailbox, uint32_t contact_chat_id)
{
	uint32_t     contact_id = chat_id_2_contact_id(mailbox, contact_chat_id);
	mrcontact_t* contact    = mrmailbox_get_contact(mailbox, contact_id);
	char*        msg        = mr_mprintf("Secure connection to %s established.", contact? contact->m_addr : "?");

	mrmailbox_add_device_msg(mailbox, contact_chat_id, msg);

	// in addition to MR_EVENT_MSGS_CHANGED (sent by mrmailbox_add_device_msg()), also send MR_EVENT_CHAT_MODIFIED to update all views
	mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, contact_chat_id, 0);

	free(msg);
	mrcontact_unref(contact);
}


#define         VC_AUTH_REQUIRED     2
#define         VC_CONTACT_CONFIRM   6
static int      s_bob_expects = 0;

static mrlot_t* s_bobs_qr_scan = NULL; // should be surround eg. by mrsqlite3_lock/unlock

#define         BOB_ERROR       0
#define         BOB_SUCCESS     1
static int      s_bobs_status = 0;


static void end_bobs_joining(mrmailbox_t* mailbox, int status)
{
	s_bobs_status = status;
	mrmailbox_stop_ongoing_process(mailbox);
}


/*******************************************************************************
 * Secure-join main flow
 ******************************************************************************/


/**
 * Get QR code text that will offer an secure-join verification.
 * The QR code is compatible to the OPENPGP4FPR format so that a basic
 * fingerprint comparison also works eg. with K-9 or OpenKeychain.
 *
 * The scanning Delta Chat device will pass the scanned content to
 * mrmailbox_check_qr() then; if this function returns
 * MR_QR_ASK_VERIFYCONTACT or MR_QR_ASK_VERIFYGROUP an out-of-band-verification
 * can be joined using mrmailbox_join_securejoin()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object.
 *
 * @param contact_chat_id If set to the ID of a chat, the "Joining a verified group" protocol is offered in the QR code.
 *     If set to 0, the "Setup Verified Contact" protocol is offered in the QR code.
 *
 * @return Text that should go to the qr code.
 */
char* mrmailbox_get_securejoin_qr(mrmailbox_t* mailbox, uint32_t group_chat_id)
{
	/* =========================================================
	   ====             Alice - the inviter side            ====
	   ====   Step 1 in "Setup verified contact" protocol   ====
	   ========================================================= */

	int       locked               = 0;
	char*     qr                   = NULL;
	char*     self_addr            = NULL;
	char*     self_addr_urlencoded = NULL;
	char*     self_name            = NULL;
	char*     self_name_urlencoded = NULL;
	char*     fingerprint          = NULL;
	char*     invitenumber         = NULL;
	char*     auth                 = NULL;
	mrchat_t* chat                 = NULL;
	char*     group_name           = NULL;
	char*     group_name_urlencoded= NULL;

	if( mailbox == NULL || mailbox->m_magic!=MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	mrmailbox_ensure_secret_key_exists(mailbox);

	// invitenumber will be used to allow starting the handshake, auth will be used to verify the fingerprint
	invitenumber  = mr_create_id();
	auth          = mr_create_id();

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( (self_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", NULL)) == NULL ) {
			mrmailbox_log_error(mailbox, 0, "Not configured.");
			goto cleanup;
		}

		self_name = mrsqlite3_get_config__(mailbox->m_sql, "displayname", "");

		store_tag__(mailbox, "secureJoin.invitenumbers", invitenumber);
		store_tag__(mailbox, "secureJoin.auths", auth);

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	if( (fingerprint=get_self_fingerprint(mailbox)) == NULL ) {
		goto cleanup;
	}

	self_addr_urlencoded = mr_url_encode(self_addr);
	self_name_urlencoded = mr_url_encode(self_name);

	if( group_chat_id )
	{
		// parameters used: a=g=x=i=s=
		chat = mrmailbox_get_chat(mailbox, group_chat_id);
		if( chat->m_type != MR_CHAT_TYPE_VERIFIED_GROUP ) {
			mrmailbox_log_error(mailbox, 0, "Secure join is only available for verified groups.");
			goto cleanup;
		}
		group_name = mrchat_get_name(chat);
		group_name_urlencoded = mr_url_encode(group_name);
		qr = mr_mprintf(OPENPGP4FPR_SCHEME "%s#a=%s&g=%s&x=%s&i=%s&s=%s", fingerprint, self_addr_urlencoded, group_name_urlencoded, chat->m_grpid, invitenumber, auth);
	}
	else
	{
		// parameters used: a=n=i=s=
		qr = mr_mprintf(OPENPGP4FPR_SCHEME "%s#a=%s&n=%s&i=%s&s=%s", fingerprint, self_addr_urlencoded, self_name_urlencoded, invitenumber, auth);
	}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	free(self_addr_urlencoded);
	free(self_addr);
	free(self_name);
	free(self_name_urlencoded);
	free(fingerprint);
	free(invitenumber);
	free(auth);
	mrchat_unref(chat);
	free(group_name);
	free(group_name_urlencoded);
	return qr? qr : safe_strdup(NULL);
}


/**
 * Join an out-of-band-verification initiated on another device with mrmailbox_get_securejoin_qr().
 * This function is typically called when mrmailbox_check_qr() returns
 * lot.m_state=MR_QR_ASK_VERIFYCONTACT or lot.m_state=MR_QR_ASK_VERIFYGROUP.
 *
 * This function takes some time and sends and receives several messages.
 * You should call it in a separate thread; if you want to abort it, you should
 * call mrmailbox_stop_ongoing_process().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object
 * @param qr The text of the scanned QR code. Typically, the same string as given
 *     to mrmailbox_check_qr().
 *
 * @return 0=Out-of-band verification failed or aborted, 1=Out-of-band
 *     verification successfull, the UI may redirect to the corresponding chat
 *     where a new system message with the state was added.
 *
 *     TODO: check if we should say to the caller, which activity to show after
 *     vc-request:
 *     - for a qr-scan while group-creation, returning to the chatlist might be better
 *     - for a qr-scan to add a contact (even without handshake), opening the created normal-chat is better
 *     (for vg-request always the new group is shown, this is perfect)
 */
uint32_t mrmailbox_join_securejoin(mrmailbox_t* mailbox, const char* qr)
{
	/* ==========================================================
	   ====             Bob - the joiner's side             =====
	   ====   Step 2 in "Setup verified contact" protocol   =====
	   ========================================================== */

	int      ret_chat_id       = 0;
	int      ongoing_allocated = 0;
	#define  CHECK_EXIT        if( mr_shall_stop_ongoing ) { goto cleanup; }
	uint32_t contact_chat_id   = 0;
	mrlot_t* qr_scan           = NULL;
	int      join_vg           = 0;

	mrmailbox_log_info(mailbox, 0, "Requesting secure-join ...");

	mrmailbox_ensure_secret_key_exists(mailbox);

	if( (ongoing_allocated=mrmailbox_alloc_ongoing(mailbox)) == 0 ) {
		goto cleanup;
	}

	if( ((qr_scan=mrmailbox_check_qr(mailbox, qr))==NULL)
	 || (qr_scan->m_state!=MR_QR_ASK_VERIFYCONTACT && qr_scan->m_state!=MR_QR_ASK_VERIFYGROUP) ) {
		mrmailbox_log_error(mailbox, 0, "Unknown QR code.");
		goto cleanup;
	}

	if( (contact_chat_id=mrmailbox_create_chat_by_contact_id(mailbox, qr_scan->m_id)) == 0 ) {
		mrmailbox_log_error(mailbox, 0, "Unknown contact.");
		goto cleanup;
	}

	CHECK_EXIT

	if( mailbox->m_cb(mailbox, MR_EVENT_IS_OFFLINE, 0, 0)!=0 ) {
		mrmailbox_log_error(mailbox, MR_ERR_NONETWORK, NULL);
		goto cleanup;
	}

	CHECK_EXIT

	join_vg = (qr_scan->m_state==MR_QR_ASK_VERIFYGROUP);

	s_bobs_status = 0;
	mrsqlite3_lock(mailbox->m_sql);
		s_bobs_qr_scan = qr_scan;
	mrsqlite3_unlock(mailbox->m_sql);

	if( fingerprint_equals_sender(mailbox, qr_scan->m_fingerprint, contact_chat_id) ) {
		// the scanned fingerprint matches Alice's key, we can proceed to step 4b) directly and save two mails
		mrmailbox_log_info(mailbox, 0, "Taking protocol shortcut.");
		s_bob_expects = VC_CONTACT_CONFIRM;
		mailbox->m_cb(mailbox, MR_EVENT_SECUREJOIN_JOINER_PROGRESS, chat_id_2_contact_id(mailbox, contact_chat_id), 4);
		char* own_fingerprint = get_self_fingerprint(mailbox);
		send_handshake_msg(mailbox, contact_chat_id, join_vg? "vg-request-with-auth" : "vc-request-with-auth",
			qr_scan->m_auth, own_fingerprint, join_vg? qr_scan->m_text2 : NULL); // Bob -> Alice
		free(own_fingerprint);
	}
	else {
		s_bob_expects = VC_AUTH_REQUIRED;
		send_handshake_msg(mailbox, contact_chat_id, join_vg? "vg-request" : "vc-request",
			qr_scan->m_invitenumber, NULL, NULL); // Bob -> Alice
	}

	while( 1 ) {
		CHECK_EXIT

		usleep(300*1000); // 0.3 seconds
	}

cleanup:
	s_bob_expects = 0;

	if( s_bobs_status == BOB_SUCCESS ) {
		if( join_vg ) {
			mrsqlite3_lock(mailbox->m_sql);
				ret_chat_id = mrmailbox_get_chat_id_by_grpid__(mailbox, qr_scan->m_text2, NULL, NULL);
			mrsqlite3_unlock(mailbox->m_sql);
		}
		else {
			ret_chat_id = contact_chat_id;
		}
	}

	mrsqlite3_lock(mailbox->m_sql);
		s_bobs_qr_scan = NULL;
	mrsqlite3_unlock(mailbox->m_sql);

	mrlot_unref(qr_scan);

	if( ongoing_allocated ) { mrmailbox_free_ongoing(mailbox); }
	return ret_chat_id;
}


int mrmailbox_handle_securejoin_handshake(mrmailbox_t* mailbox, mrmimeparser_t* mimeparser, uint32_t contact_id)
{
	int          locked = 0;
	const char*  step   = NULL;
	int          join_vg = 0;
	char*        scanned_fingerprint_of_alice = NULL;
	char*        auth = NULL;
	char*        own_fingerprint = NULL;
	uint32_t     contact_chat_id = 0;
	int          contact_chat_id_blocked = 0;
	char*        grpid = NULL;
	int          ret = 0;

	if( mailbox == NULL || mimeparser == NULL || contact_id <= MR_CONTACT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	if( (step=lookup_field(mimeparser, "Secure-Join")) == NULL ) {
		goto cleanup;
	}
	mrmailbox_log_info(mailbox, 0, ">>>>>>>>>>>>>>>>>>>>>>>>> secure-join message '%s' received", step);

	join_vg = (strncmp(step, "vg-", 3)==0);
	LOCK
		mrmailbox_create_or_lookup_nchat_by_contact_id__(mailbox, contact_id, MR_CHAT_NOT_BLOCKED, &contact_chat_id, &contact_chat_id_blocked);
		if( contact_chat_id_blocked ) {
			mrmailbox_unblock_chat__(mailbox, contact_chat_id);
		}
	UNLOCK

	ret = MR_IS_HANDSHAKE_STOP_NORMAL_PROCESSING;

	if( strcmp(step, "vg-request")==0 || strcmp(step, "vc-request")==0 )
	{
		/* =========================================================
		   ====             Alice - the inviter side            ====
		   ====   Step 3 in "Setup verified contact" protocol   ====
		   ========================================================= */

		// this message may be unencrypted (Bob, the joinder and the sender, might not have Alice's key yet)

		// it just ensures, we have Bobs key now. If we do _not_ have the key because eg. MitM has removed it,
		// send_message() will fail with the error "End-to-end-encryption unavailable unexpectedly.", so, there is no additional check needed here.

		// verify that the `Secure-Join-Invitenumber:`-header matches invitenumber written to the QR code
		const char* invitenumber = NULL;
		if( (invitenumber=lookup_field(mimeparser, "Secure-Join-Invitenumber")) == NULL ) {
			mrmailbox_log_warning(mailbox, 0, "Secure-join denied (invitenumber missing)."); // do not raise an error, this might just be spam or come from an old request
			goto cleanup;
		}

		LOCK
			if( lookup_tag__(mailbox, "secureJoin.invitenumbers", invitenumber) == 0 ) {
				mrmailbox_log_warning(mailbox, 0, "Secure-join denied (bad invitenumber).");  // do not raise an error, this might just be spam or come from an old request
				goto cleanup;
			}
		UNLOCK

		mrmailbox_log_info(mailbox, 0, "Secure-join requested.");

		mailbox->m_cb(mailbox, MR_EVENT_SECUREJOIN_INVITER_PROGRESS, contact_id, 3);

		send_handshake_msg(mailbox, contact_chat_id, join_vg? "vg-auth-required" : "vc-auth-required",
			NULL, NULL, NULL); // Alice -> Bob
	}
	else if( strcmp(step, "vg-auth-required")==0 || strcmp(step, "vc-auth-required")==0 )
	{
		/* ==========================================================
		   ====             Bob - the joiner's side             =====
		   ====   Step 4 in "Setup verified contact" protocol   =====
		   ========================================================== */

		// verify that Alice's Autocrypt key and fingerprint matches the QR-code
		LOCK
			if( s_bobs_qr_scan == NULL || s_bob_expects != VC_AUTH_REQUIRED || (join_vg && s_bobs_qr_scan->m_state!=MR_QR_ASK_VERIFYGROUP) ) {
				mrmailbox_log_warning(mailbox, 0, "auth-required message out of sync.");
				goto cleanup; // no error, just aborted somehow or a mail from another handshake
			}
			scanned_fingerprint_of_alice = safe_strdup(s_bobs_qr_scan->m_fingerprint);
			auth = safe_strdup(s_bobs_qr_scan->m_auth);
			if( join_vg ) {
				grpid = safe_strdup(s_bobs_qr_scan->m_text2);
			}
		UNLOCK

		if( !encrypted_and_signed(mimeparser, scanned_fingerprint_of_alice) ) {
			could_not_establish_secure_connection(mailbox, contact_chat_id, mimeparser->m_e2ee_helper->m_encrypted? "No valid signature." : "Not encrypted.");
			end_bobs_joining(mailbox, BOB_ERROR);
			goto cleanup;
		}

		if( !fingerprint_equals_sender(mailbox, scanned_fingerprint_of_alice, contact_chat_id) ) {
			// MitM?
			could_not_establish_secure_connection(mailbox, contact_chat_id, "Fingerprint mismatch on joiner-side.");
			end_bobs_joining(mailbox, BOB_ERROR);
			goto cleanup;
		}

		mrmailbox_log_info(mailbox, 0, "Fingerprint verified.");

		own_fingerprint = get_self_fingerprint(mailbox);

		mailbox->m_cb(mailbox, MR_EVENT_SECUREJOIN_JOINER_PROGRESS, contact_id, 4);

		s_bob_expects = VC_CONTACT_CONFIRM;
		send_handshake_msg(mailbox, contact_chat_id, join_vg? "vg-request-with-auth" : "vc-request-with-auth",
			auth, own_fingerprint, grpid); // Bob -> Alice
	}
	else if( strcmp(step, "vg-request-with-auth")==0 || strcmp(step, "vc-request-with-auth")==0 )
	{
		/* ============================================================
		   ====              Alice - the inviter side              ====
		   ====   Steps 5+6 in "Setup verified contact" protocol   ====
		   ====  Step 6 in "Out-of-band verified groups" protocol  ====
		   ============================================================ */

		// verify that Secure-Join-Fingerprint:-header matches the fingerprint of Bob
		const char* fingerprint = NULL;
		if( (fingerprint=lookup_field(mimeparser, "Secure-Join-Fingerprint")) == NULL ) {
			could_not_establish_secure_connection(mailbox, contact_chat_id, "Fingerprint not provided.");
			goto cleanup;
		}

		if( !encrypted_and_signed(mimeparser, fingerprint) ) {
			could_not_establish_secure_connection(mailbox, contact_chat_id, "Auth not encrypted.");
			goto cleanup;
		}

		if( !fingerprint_equals_sender(mailbox, fingerprint, contact_chat_id) ) {
			// MitM?
			could_not_establish_secure_connection(mailbox, contact_chat_id, "Fingerprint mismatch on inviter-side.");
			goto cleanup;
		}

		mrmailbox_log_info(mailbox, 0, "Fingerprint verified.");

		// verify that the `Secure-Join-Auth:`-header matches the secret written to the QR code
		const char* auth = NULL;
		if( (auth=lookup_field(mimeparser, "Secure-Join-Auth")) == NULL ) {
			could_not_establish_secure_connection(mailbox, contact_chat_id, "Auth not provided.");
			goto cleanup;
		}

		LOCK
			if( lookup_tag__(mailbox, "secureJoin.auths", auth) == 0 ) {
				mrsqlite3_unlock(mailbox->m_sql);
				locked = 0;
				could_not_establish_secure_connection(mailbox, contact_chat_id, "Auth invalid.");
				goto cleanup;
			}

			if( !mark_peer_as_verified__(mailbox, fingerprint) ) {
				mrsqlite3_unlock(mailbox->m_sql);
				locked = 0;
				could_not_establish_secure_connection(mailbox, contact_chat_id, "Fingerprint mismatch on inviter-side."); // should not happen, we've compared the fingerprint some lines above
				goto cleanup;
			}

			mrmailbox_scaleup_contact_origin__(mailbox, contact_id, MR_ORIGIN_SECUREJOIN_INVITED);
		UNLOCK

		mrmailbox_log_info(mailbox, 0, "Auth verified.");

		secure_connection_established(mailbox, contact_chat_id);

		mailbox->m_cb(mailbox, MR_EVENT_CONTACTS_CHANGED, contact_id/*selected contact*/, 0);
		mailbox->m_cb(mailbox, MR_EVENT_SECUREJOIN_INVITER_PROGRESS, contact_id, 6);

		if( join_vg ) {
			// the vg-member-added message is special: this is a normal Chat-Group-Member-Added message with an additional Secure-Join header
			grpid = safe_strdup(lookup_field(mimeparser, "Secure-Join-Group"));
			int is_verified = 0;
			LOCK
				uint32_t verified_chat_id = mrmailbox_get_chat_id_by_grpid__(mailbox, grpid, NULL, &is_verified);
			UNLOCK
			if( verified_chat_id == 0 || !is_verified ) {
				mrmailbox_log_error(mailbox, 0, "Verified chat not found.");
				goto cleanup;
			}

			mrmailbox_add_contact_to_chat4(mailbox, verified_chat_id, contact_id, 1/*from_handshake*/); // Alice -> Bob and all members
		}
		else {
			send_handshake_msg(mailbox, contact_chat_id, "vc-contact-confirm",
				NULL, NULL, NULL); // Alice -> Bob
		}
	}
	else if( strcmp(step, "vg-member-added")==0 || strcmp(step, "vc-contact-confirm")==0 )
	{
		/* ==========================================================
		   ====             Bob - the joiner's side             =====
		   ====   Step 7 in "Setup verified contact" protocol   =====
		   ========================================================== */

		if( join_vg ) {
			// vg-member-added is just part of a Chat-Group-Member-Added which should be kept in any way, eg. for multi-client
			ret = MR_IS_HANDSHAKE_CONTINUE_NORMAL_PROCESSING;
		}

		if( s_bob_expects != VC_CONTACT_CONFIRM ) {
			if( join_vg ) {
				mrmailbox_log_info(mailbox, 0, "vg-member-added received as broadcast.");
			}
			else {
				mrmailbox_log_warning(mailbox, 0, "Unexpected secure-join mail order.");
			}
			goto cleanup;
		}

		LOCK
			if( s_bobs_qr_scan == NULL || (join_vg && s_bobs_qr_scan->m_state!=MR_QR_ASK_VERIFYGROUP) ) {
				mrmailbox_log_warning(mailbox, 0, "Message out of sync or belongs to a different handshake.");
				goto cleanup;
			}
			scanned_fingerprint_of_alice = safe_strdup(s_bobs_qr_scan->m_fingerprint);
		UNLOCK

		if( !encrypted_and_signed(mimeparser, scanned_fingerprint_of_alice) ) {
			could_not_establish_secure_connection(mailbox, contact_chat_id, "Contact confirm message not encrypted.");
			end_bobs_joining(mailbox, BOB_ERROR);
			goto cleanup;
		}

		// TODO: for the broadcasted vg-member-added, make sure, the message is ours (eg. by comparing Chat-Group-Member-Added against SELF)

		LOCK
			if( !mark_peer_as_verified__(mailbox, scanned_fingerprint_of_alice) ) {
				could_not_establish_secure_connection(mailbox, contact_chat_id, "Fingerprint mismatch on joiner-side."); // MitM? - key has changed since vc-auth-required message
				goto cleanup;
			}

			mrmailbox_scaleup_contact_origin__(mailbox, contact_id, MR_ORIGIN_SECUREJOIN_JOINED);
		UNLOCK

		secure_connection_established(mailbox, contact_chat_id);

		mailbox->m_cb(mailbox, MR_EVENT_CONTACTS_CHANGED, 0/*no select event*/, 0);

		s_bob_expects = 0;
		end_bobs_joining(mailbox, BOB_SUCCESS);
	}

	// delete the message in 20 seconds - typical handshake last about 5 seconds, so do not disturb the connection _now_.
	// for errors, we do not the corresoinding message at all, it may come eg. from another device or may be useful to find out what was going wrong.
	if( ret == MR_IS_HANDSHAKE_STOP_NORMAL_PROCESSING ) {
		struct mailimf_field* field;
		if( (field=mrmimeparser_lookup_field(mimeparser, "Message-ID"))!=NULL && field->fld_type==MAILIMF_FIELD_MESSAGE_ID ) {
			struct mailimf_message_id* fld_message_id = field->fld_data.fld_message_id;
			if( fld_message_id && fld_message_id->mid_value ) {
				mrjob_add__(mailbox, MRJ_DELETE_MSG_ON_IMAP, mrmailbox_rfc724_mid_exists__(mailbox, fld_message_id->mid_value, NULL, NULL), NULL, 20);
			}
		}
	}

cleanup:

	UNLOCK

	free(scanned_fingerprint_of_alice);
	free(auth);
	free(own_fingerprint);
	free(grpid);
	return ret;
}
