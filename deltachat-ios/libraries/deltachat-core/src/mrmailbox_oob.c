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


/*******************************************************************************
 * Alice's random_public and random_secret mini-datastore
 ******************************************************************************/


static void store_random__(mrmailbox_t* mailbox, const char* datastore_name, const char* to_add)
{
	// prepend new random to the list of all tags
	#define MAX_REMEMBERED_RANDOMS 10
	#define MAX_REMEMBERED_CHARS (MAX_REMEMBERED_RANDOMS*(MR_CREATE_ID_LEN+1))
	char* old_randoms = mrsqlite3_get_config__(mailbox->m_sql, datastore_name, "");
	if( strlen(old_randoms) > MAX_REMEMBERED_CHARS ) {
		old_randoms[MAX_REMEMBERED_CHARS] = 0; // the oldest tag may be incomplete und unrecognizable, however, this is no problem as it would be deleted soon anyway
	}
	char* new_randoms = mr_mprintf("%s,%s", to_add, old_randoms);
	mrsqlite3_set_config__(mailbox->m_sql, datastore_name, new_randoms);

	free(old_randoms);
	free(new_randoms);
}


static int lookup_random__(mrmailbox_t* mailbox, const char* datastore_name, const char* to_lookup)
{
	int            found       = 0;
	char*          old_randoms = NULL;
	carray*        lines       = NULL;

	//mrstrbuilder_t new_randoms;  -- we do not delete the randoms to allow multiple scans, the randoms are deleted when new are generated
	//mrstrbuilder_init(&new_randoms, 0);

	old_randoms = mrsqlite3_get_config__(mailbox->m_sql, datastore_name, "");
	mr_str_replace(&old_randoms, ",", "\n");
	lines = mr_split_into_lines(old_randoms);
	for( int i = 0; i < carray_count(lines); i++ ) {
		char* random  = (char*)carray_get(lines, i); mr_trim(random);
		if( strlen(random) >= 4 && strcmp(random, to_lookup) == 0 ) {
			found = 1;
		}
		//else {
		//	mrstrbuilder_catf(&new_randoms, "%s,", random);
		//}
	}

	//mrsqlite3_set_config__(mailbox->m_sql, datastore_name, new_randoms.m_buf);
	//free(new_randoms.m_buf);

	mr_free_splitted_lines(lines);
	free(old_randoms);
	return found;
}



/*******************************************************************************
 * Tools
 ******************************************************************************/


#define OPENPGP4FPR_SCHEME "OPENPGP4FPR:" /* yes: uppercase */
#define MAILTO_SCHEME      "mailto:"
#define MATMSG_SCHEME      "MATMSG:"
#define VCARD_BEGIN        "BEGIN:VCARD"
#define SMTP_SCHEME        "SMTP:"


/**
 * Check a scanned QR code.
 * The function should be called after a QR code is scanned.
 * The function takes the raw text scanned and checks what can be done with it.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object.
 * @param qr The text of the scanned QR code.
 *
 * @return Parsed QR code as an mrlot_t object.
 */
mrlot_t* mrmailbox_check_qr(mrmailbox_t* mailbox, const char* qr)
{
	int             locked        = 0;
	char*           payload       = NULL;
	char*           addr          = NULL; /* must be normalized, if set */
	char*           fingerprint   = NULL; /* must be normalized, if set */
	char*           name          = NULL;
	char*           random_public = NULL;
	char*           random_secret = NULL;
	mrapeerstate_t* peerstate     = mrapeerstate_new();
	mrlot_t*        qr_parsed     = mrlot_new();

	qr_parsed->m_state = 0;

	if( mailbox==NULL || mailbox->m_magic!=MR_MAILBOX_MAGIC || qr==NULL ) {
		goto cleanup;
	}

	mrmailbox_log_info(mailbox, 0, "Scanned QR code: %s", qr);

	/* split parameters from the qr code
	 ------------------------------------ */

	if( strncasecmp(qr, OPENPGP4FPR_SCHEME, strlen(OPENPGP4FPR_SCHEME)) == 0 )
	{
		/* scheme: OPENPGP4FPR:1234567890123456789012345678901234567890#v=mail%40domain.de&n=Name */
		payload  = safe_strdup(&qr[strlen(OPENPGP4FPR_SCHEME)]);
		char* fragment = strchr(payload, '#'); /* must not be freed, only a pointer inside payload */
		if( fragment )
		{
			*fragment = 0;
			fragment++;

			mrparam_t* param = mrparam_new();
			mrparam_set_urlencoded(param, fragment);

			addr = mrparam_get(param, 'v', NULL);
			if( addr ) {
				char* name_urlencoded = mrparam_get(param, 'n', NULL);
				if( name_urlencoded ) {
					name = mr_url_decode(name_urlencoded);
					mr_normalize_name(name);
					free(name_urlencoded);
				}
				random_public = mrparam_get(param, 'p', "");
				random_secret = mrparam_get(param, 's', "");
			}

			mrparam_unref(param);
		}

		fingerprint = mr_normalize_fingerprint(payload);
	}
	else if( strncasecmp(qr, MAILTO_SCHEME, strlen(MAILTO_SCHEME)) == 0 )
	{
		/* scheme: mailto:addr...?subject=...&body=... */
		payload = safe_strdup(&qr[strlen(MAILTO_SCHEME)]);
		char* query = strchr(payload, '?'); /* must not be freed, only a pointer inside payload */
		if( query ) {
			*query = 0;
		}
		addr = safe_strdup(payload);
	}
	else if( strncasecmp(qr, SMTP_SCHEME, strlen(SMTP_SCHEME)) == 0 )
	{
		/* scheme: `SMTP:addr...:subject...:body...` */
		payload = safe_strdup(&qr[strlen(SMTP_SCHEME)]);
		char* colon = strchr(payload, ':'); /* must not be freed, only a pointer inside payload */
		if( colon ) {
			*colon = 0;
		}
		addr = safe_strdup(payload);
	}
	else if( strncasecmp(qr, MATMSG_SCHEME, strlen(MATMSG_SCHEME)) == 0 )
	{
		/* scheme: `MATMSG:TO:addr...;SUB:subject...;BODY:body...;` - there may or may not be linebreaks after the fields */
		char* to = strstr(qr, "TO:"); /* does not work when the text `TO:` is used in subject/body _and_ TO: is not the first field. we ignore this case. */
		if( to ) {
			addr = safe_strdup(&to[3]);
			char* semicolon = strchr(addr, ';');
			if( semicolon ) { *semicolon = 0; }
		}
		else {
			qr_parsed->m_state = MR_QR_ERROR;
			qr_parsed->m_text1 = safe_strdup("Bad e-mail address.");
			goto cleanup;
		}
	}
	else if( strncasecmp(qr, VCARD_BEGIN, strlen(VCARD_BEGIN)) == 0 )
	{
		/* scheme: `VCARD:BEGIN\nN:last name;first name;...;\nEMAIL:addr...;` */
		carray* lines = mr_split_into_lines(qr);
		for( int i = 0; i < carray_count(lines); i++ ) {
			char* key   = (char*)carray_get(lines, i); mr_trim(key);
			char* value = strchr(key, ':');
			if( value ) {
				*value = 0;
				value++;
				char* semicolon = strchr(key, ';'); if( semicolon ) { *semicolon = 0; } /* handle `EMAIL;type=work:` stuff */
				if( strcasecmp(key, "EMAIL") == 0 ) {
					semicolon = strchr(value, ';'); if( semicolon ) { *semicolon = 0; } /* use the first EMAIL */
					addr = safe_strdup(value);
				}
				else if( strcasecmp(key, "N") == 0 ) {
					semicolon = strchr(value, ';'); if( semicolon ) { semicolon = strchr(semicolon+1, ';'); if( semicolon ) { *semicolon = 0; } } /* the N format is `lastname;prename;wtf;title` - skip everything after the second semicolon */
					name = safe_strdup(value);
					mr_str_replace(&name, ";", ","); /* the format "lastname,prename" is handled by mr_normalize_name() */
					mr_normalize_name(name);
				}
			}
		}
		mr_free_splitted_lines(lines);
	}

	/* check the paramters
	  ---------------------- */

	if( addr ) {
		char* temp = mr_url_decode(addr);     free(addr); addr = temp; /* urldecoding is needed at least for OPENPGP4FPR but should not hurt in the other cases */
		      temp = mr_normalize_addr(addr); free(addr); addr = temp;

		if( strlen(addr) < 3 || strchr(addr, '@')==NULL || strchr(addr, '.')==NULL ) {
			qr_parsed->m_state = MR_QR_ERROR;
			qr_parsed->m_text1 = safe_strdup("Bad e-mail address.");
			goto cleanup;
		}
	}

	if( fingerprint ) {
		if( strlen(fingerprint) != 40 ) {
			qr_parsed->m_state = MR_QR_ERROR;
			qr_parsed->m_text1 = safe_strdup("Bad fingerprint length in QR code.");
			goto cleanup;
		}
	}

	/* let's see what we can do with the parameters
	  ---------------------------------------------- */

	if( fingerprint )
	{
		/* fingerprint set ... */

		if( addr == NULL )
		{
			/* _only_ fingerprint set ... */
			mrsqlite3_lock(mailbox->m_sql);
			locked = 1;

				if( mrapeerstate_load_by_fingerprint__(peerstate, mailbox->m_sql, fingerprint) ) {
					qr_parsed->m_state = MR_QR_FPR_OK;
					qr_parsed->m_id    = mrmailbox_add_or_lookup_contact__(mailbox, NULL, peerstate->m_addr, MR_ORIGIN_UNHANDLED_QR_SCAN, NULL);
					// TODO: add this to the security log
				}
				else {
					qr_parsed->m_text1 = mr_format_fingerprint(fingerprint);
					qr_parsed->m_state = MR_QR_FPR_WITHOUT_ADDR;
				}

			mrsqlite3_unlock(mailbox->m_sql);
			locked = 0;
		}
		else
		{
			/* fingerprint and addr set ... */  // TODO: add the states to the security log
			mrsqlite3_lock(mailbox->m_sql);
			locked = 1;

				qr_parsed->m_state = MR_QR_FPR_ASK_OOB;
				qr_parsed->m_id    = mrmailbox_add_or_lookup_contact__(mailbox, name, addr, MR_ORIGIN_UNHANDLED_QR_SCAN, NULL);
				if( mrapeerstate_load_by_addr__(peerstate, mailbox->m_sql, addr) ) {
					if( strcasecmp(peerstate->m_fingerprint, fingerprint) != 0 ) {
						mrmailbox_log_info(mailbox, 0, "Fingerprint mismatch for %s: Scanned: %s, saved: %s", addr, fingerprint, peerstate->m_fingerprint);
						qr_parsed->m_state = MR_QR_FPR_MISMATCH;
					}
				}

				if( qr_parsed->m_state == MR_QR_FPR_ASK_OOB ) {
					qr_parsed->m_fingerprint  = safe_strdup(fingerprint);
					qr_parsed->m_random_public = safe_strdup(random_public);
					qr_parsed->m_random_secret = safe_strdup(random_secret);
				}

			mrsqlite3_unlock(mailbox->m_sql);
			locked = 0;
		}
	}
	else if( addr )
	{
        qr_parsed->m_state = MR_QR_ADDR;
		qr_parsed->m_id    = mrmailbox_add_or_lookup_contact__(mailbox, name, addr, MR_ORIGIN_UNHANDLED_QR_SCAN, NULL);
	}
	else
	{
        qr_parsed->m_state = MR_QR_TEXT;
		qr_parsed->m_text1 = safe_strdup(qr);
	}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	free(addr);
	free(fingerprint);
	mrapeerstate_unref(peerstate);
	free(payload);
	free(name);
	free(random_public);
	free(random_secret);
	return qr_parsed;
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


static uint32_t chat_id_2_contact_id(mrmailbox_t* mailbox, uint32_t chat_id)
{
	uint32_t   contact_id = 0;
	mrarray_t* contacts = mrmailbox_get_chat_contacts(mailbox, chat_id);

	if( mrarray_get_cnt(contacts) != 1 ) {
		goto cleanup;
	}

	contact_id = mrarray_get_id(contacts, 0);

cleanup:
	mrarray_unref(contacts);
	return contact_id;
}


static int fingerprint_equals_sender(mrmailbox_t* mailbox, const char* fingerprint, uint32_t chat_id)
{
	int             fingerprint_equal      = 0;
	int             locked                 = 0;
	mrarray_t*      contacts               = mrmailbox_get_chat_contacts(mailbox, chat_id);
	mrcontact_t*    contact                = mrcontact_new();
	mrapeerstate_t* peerstate              = mrapeerstate_new();
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

	if( strcasecmp(fingerprint_normalized, peerstate->m_fingerprint) == 0 ) {
		fingerprint_equal = 1;
	}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	free(fingerprint_normalized);
	mrcontact_unref(contact);
	mrarray_unref(contacts);
	return fingerprint_equal;
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


static void send_handshake_msg(mrmailbox_t* mailbox, uint32_t chat_id, const char* step, const char* random, const char* fingerprint)
{
	mrmsg_t* msg = mrmsg_new();

	msg->m_type = MR_MSG_TEXT;
	msg->m_text = mr_mprintf("Secure-Join: %s", step);
	msg->m_hidden = 1;
	mrparam_set_int(msg->m_param, MRP_SYSTEM_CMD,       MR_SYSTEM_OOB_VERIFY_MESSAGE);
	mrparam_set    (msg->m_param, MRP_SYSTEM_CMD_PARAM, step);

	if( random ) {
		mrparam_set(msg->m_param, MRP_SYSTEM_CMD_PARAM2, random);
	}

	if( fingerprint ) {
		mrparam_set(msg->m_param, MRP_SYSTEM_CMD_PARAM3, fingerprint);
	}

	if( strcmp(step, "request") != 0 ) {
		mrparam_set_int(msg->m_param, MRP_GUARANTEE_E2EE, 1); /* all but the first message MUST be encrypted */
	}

	mrmailbox_send_msg_object(mailbox, chat_id, msg);

	mrmsg_unref(msg);
}


#define         PLEASE_PROVIDE_RANDOM_SECRET 2
#define         SECURE_JOIN_BROADCAST        4
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
 * OOB verification main flow
 ******************************************************************************/


/**
 * Get QR code text that will offer an oob verification.
 * The QR code is compatible to the OPENPGP4FPR format so that a basic
 * fingerprint comparison also works eg. with K-9 or OpenKeychain.
 *
 * The scanning Delta Chat device will pass the scanned content to
 * mrmailbox_check_qr() then; if this function reutrns
 * MR_QR_FINGERPRINT_ASK_OOB oob-verification can be joined using
 * mrmailbox_oob_join()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object.
 *
 * @return Text that should go to the qr code.
 */
char* mrmailbox_oob_get_qr(mrmailbox_t* mailbox)
{
	/* ==================================
	   ==== Alice - the inviter side ====
	   ================================== */

	int      locked               = 0;
	char*    qr                   = NULL;
	char*    self_addr            = NULL;
	char*    self_addr_urlencoded = NULL;
	char*    self_name            = NULL;
	char*    self_name_urlencoded = NULL;
	char*    fingerprint          = NULL;
	char*    random_public        = NULL;
	char*    random_secret        = NULL;

	if( mailbox == NULL || mailbox->m_magic!=MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	mrmailbox_ensure_secret_key_exists(mailbox);

	// random_public will be used to allow starting the handshake, random_secret will be used to validate the fingerprint
	random_public = mr_create_id();
	random_secret = mr_create_id();

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( (self_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", NULL)) == NULL ) {
			goto cleanup;
		}

		self_name = mrsqlite3_get_config__(mailbox->m_sql, "displayname", "");

		store_random__(mailbox, "secureJoin.randomPublics", random_public);
		store_random__(mailbox, "secureJoin.randomSecrets", random_secret);

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	if( (fingerprint=get_self_fingerprint(mailbox)) == NULL ) {
		goto cleanup;
	}

	self_addr_urlencoded = mr_url_encode(self_addr);
	self_name_urlencoded = mr_url_encode(self_name);
	qr = mr_mprintf(OPENPGP4FPR_SCHEME "%s#v=%s&n=%s&p=%s&s=%s", fingerprint, self_addr_urlencoded, self_name_urlencoded, random_public, random_secret);

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	free(self_addr_urlencoded);
	free(self_addr);
	free(self_name);
	free(self_name_urlencoded);
	free(fingerprint);
	free(random_secret);
	return qr? qr : safe_strdup(NULL);
}


/**
 * Join an OOB-verification initiated on another device with mrmailbox_oob_get_qr().
 * This function is typically called when mrmailbox_check_qr() returns
 * lot.m_state=MR_QR_FINGERPRINT_ASK_OOB
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
 */
int mrmailbox_oob_join(mrmailbox_t* mailbox, const char* qr)
{
	/* =================================
	   ==== Bob - the joiner's side ====
	   ================================= */

	int      success           = 0;
	int      ongoing_allocated = 0;
	#define  CHECK_EXIT        if( mr_shall_stop_ongoing ) { goto cleanup; }
	uint32_t chat_id           = 0;
	mrlot_t* qr_scan           = NULL;

	mrmailbox_log_info(mailbox, 0, "Requesting secure-join ...");

	mrmailbox_ensure_secret_key_exists(mailbox);

	if( (ongoing_allocated=mrmailbox_alloc_ongoing(mailbox)) == 0 ) {
		goto cleanup;
	}

	if( ((qr_scan=mrmailbox_check_qr(mailbox, qr))==NULL) || qr_scan->m_state!=MR_QR_FPR_ASK_OOB ) {
		goto cleanup;
	}

	if( (chat_id=mrmailbox_create_chat_by_contact_id(mailbox, qr_scan->m_id)) == 0 ) {
		goto cleanup;
	}

	CHECK_EXIT

	if( mailbox->m_cb(mailbox, MR_EVENT_IS_OFFLINE, 0, 0)!=0 ) {
		mrmailbox_log_error(mailbox, MR_ERR_NONETWORK, NULL);
		goto cleanup;
	}

	CHECK_EXIT

	s_bobs_status = 0;
	s_bob_expects = PLEASE_PROVIDE_RANDOM_SECRET;

	mrsqlite3_lock(mailbox->m_sql);
		s_bobs_qr_scan = qr_scan;
	mrsqlite3_unlock(mailbox->m_sql);

	send_handshake_msg(mailbox, chat_id, "request", qr_scan->m_random_public, NULL); // Bob -> Alice

	while( 1 ) {
		CHECK_EXIT

		usleep(300*1000);
	}

cleanup:
	s_bob_expects = 0;

	if( s_bobs_status == BOB_SUCCESS ) {
		success = 1;
	}

	mrsqlite3_lock(mailbox->m_sql);
		s_bobs_qr_scan = NULL;
	mrsqlite3_unlock(mailbox->m_sql);

	mrlot_unref(qr_scan);

	if( ongoing_allocated ) { mrmailbox_free_ongoing(mailbox); }
	return success;
}


/*
 * mrmailbox_oob_is_handshake_message__() should be called called for each
 * incoming mail. if the mail belongs to an oob-verify handshake, the function
 * returns 1. The caller should unlock everything, stop normal message
 * processing and call mrmailbox_oob_handle_handshake_message() then.
 */
int mrmailbox_oob_is_handshake_message__(mrmailbox_t* mailbox, mrmimeparser_t* mimeparser)
{
	if( mailbox == NULL || mimeparser == NULL || lookup_field(mimeparser, "Secure-Join") == NULL ) {
		return 0;
	}

	return 1; /* processing is continued in mrmailbox_oob_handle_handshake_message() */
}


void mrmailbox_oob_handle_handshake_message(mrmailbox_t* mailbox, mrmimeparser_t* mimeparser, uint32_t chat_id)
{
	int                   locked = 0;
	const char*           step   = NULL;

	if( mailbox == NULL || mimeparser == NULL || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	if( (step=lookup_field(mimeparser, "Secure-Join")) == NULL ) {
		goto cleanup;
	}
	mrmailbox_log_info(mailbox, 0, ">>>>>>>>>>>>>>>>>>>>>>>>> secure-join message '%s' received", step);

	if( strcmp(step, "request")==0 )
	{
		/* ==================================
		   ==== Alice - the inviter side ====
		   ================================== */

		// this message may be unencrypted (Bob, the joinder and the sender, might not have Alice's key yet)

		// it just ensures, we have Bobs key now. If we do _not_ have the key because eg. MitM has removed it,
		// send_message() will fail with the error "End-to-end-encryption unavailable unexpectedly.", so, there is no additional check needed here.

		// verify that the `Secure-Join-Random-Public:`-header matches random_public written to the QR code
		uint32_t    contact_id = chat_id_2_contact_id(mailbox, chat_id);
		const char* random_public = NULL;
		if( (random_public=lookup_field(mimeparser, "Secure-Join-Random-Public")) == NULL ) {
			mrmailbox_log_warning(mailbox, 0, "Secure-join denied (random-public missing)."); // do not raise an error, this might just be spam or come from an old request
			goto cleanup;
		}

		mrsqlite3_lock(mailbox->m_sql);
		locked = 1;
			if( lookup_random__(mailbox, "secureJoin.randomPublics", random_public) == 0 ) {
				mrmailbox_log_warning(mailbox, 0, "Secure-join denied (bad random-public).");  // do not raise an error, this might just be spam or come from an old request
				goto cleanup;
			}
		mrsqlite3_unlock(mailbox->m_sql);
		locked = 0;

		mrmailbox_log_info(mailbox, 0, "Secure-join requested.");

		mailbox->m_cb(mailbox, MR_EVENT_SECURE_JOIN_REQUESTED, contact_id, 0);

		send_handshake_msg(mailbox, chat_id, "please-provide-random-secret", NULL, NULL); // Alice -> Bob
	}
	else if( strcmp(step, "please-provide-random-secret")==0 )
	{
		/* =================================
		   ==== Bob - the joiner's side ====
		   ================================= */

		if( !mimeparser->m_decrypted_and_validated ) {
			mrmailbox_log_error(mailbox, 0, "Secure-join failed (mail not encrypted).");
			end_bobs_joining(mailbox, BOB_ERROR);
			goto cleanup;
		}

		// verify that Alice's Autocrypt key and fingerprint matches the QR-code
		mrsqlite3_lock(mailbox->m_sql);
		locked = 1;
			if( s_bobs_qr_scan == NULL || s_bob_expects != PLEASE_PROVIDE_RANDOM_SECRET ) {
				goto cleanup; // no error, just aborted somehow or a mail from another handshake
			}
			char* scanned_fingerprint_of_alice = safe_strdup(s_bobs_qr_scan->m_fingerprint);
			char* random_secret                = safe_strdup(s_bobs_qr_scan->m_random_secret);
		mrsqlite3_unlock(mailbox->m_sql);
		locked = 0;

		if( !fingerprint_equals_sender(mailbox, scanned_fingerprint_of_alice, chat_id) ) {
			mrmailbox_log_error(mailbox, 0, "Secure-join failed (fingerprint mismatch).");
			end_bobs_joining(mailbox, BOB_ERROR);
			goto cleanup;
		}

		mrmailbox_log_info(mailbox, 0, "Fingerprint validated.");

		char* own_fingerprint = get_self_fingerprint(mailbox);

		s_bob_expects = SECURE_JOIN_BROADCAST;
		send_handshake_msg(mailbox, chat_id, "random-secret", random_secret, own_fingerprint); // Bob -> Alice

		free(own_fingerprint);
		free(scanned_fingerprint_of_alice);
		free(random_secret);
	}
	else if( strcmp(step, "random-secret")==0 )
	{
		/* ==================================
		   ==== Alice - the inviter side ====
		   ================================== */

		if( !mimeparser->m_decrypted_and_validated ) {
			mrmailbox_log_error(mailbox, 0, "Secure-join failed (mail not encrypted).");
			goto cleanup;
		}

		// verify that Secure-Join-Fingerprint:-header matches the fingerprint of Bob
		const char* fingerprint = NULL;
		if( (fingerprint=lookup_field(mimeparser, "Secure-Join-Fingerprint")) == NULL ) {
			mrmailbox_log_error(mailbox, 0, "Secure-join failed (fingerprint not provided together with random-secret).");
			goto cleanup;
		}

		if( !fingerprint_equals_sender(mailbox, fingerprint, chat_id) ) {
			mrmailbox_log_error(mailbox, 0, "Secure-join failed (fingerprint mismatch).");
			goto cleanup;
		}

		mrmailbox_log_info(mailbox, 0, "Fingerprint validated.");

		// verify that the `Secure-Join-Random-Secret:`-header matches the secret written to the QR code
		const char* random_secret = NULL;
		if( (random_secret=lookup_field(mimeparser, "Secure-Join-Random-Secret")) == NULL ) {
			mrmailbox_log_error(mailbox, 0, "Secure-join failed (requested random-secret not provided).");
			goto cleanup;
		}

		uint32_t contact_id = chat_id_2_contact_id(mailbox, chat_id);
		mrsqlite3_lock(mailbox->m_sql);
		locked = 1;
			if( lookup_random__(mailbox, "secureJoin.randomSecrets", random_secret) == 0 ) {
				mrmailbox_log_error(mailbox, 0, "Secure-join failed (random-secret invalid).");
				goto cleanup;
			}
			mrmailbox_scaleup_contact_origin__(mailbox, contact_id, MR_ORIGIN_SECURE_INVITED);
		mrsqlite3_unlock(mailbox->m_sql);
		locked = 0;

		mrmailbox_log_info(mailbox, 0, "Random secret validated.");

		mrmailbox_add_system_msg(mailbox, chat_id, "Secure-join connection established.");

		send_handshake_msg(mailbox, chat_id, "broadcast", NULL, NULL); // Alice -> Bob and all other group members
	}
	else if( strcmp(step, "broadcast")==0 )
	{
		/* =================================
		   ==== Bob - the joiner's side ====
		   ================================= */

		if( s_bob_expects != SECURE_JOIN_BROADCAST ) {
			mrmailbox_log_warning(mailbox, 0, "Unexpected secure-join mail order.");
			goto cleanup; // ignore the mail without raising and error; may come from another handshake
		}

		if( !mimeparser->m_decrypted_and_validated ) {
			mrmailbox_log_error(mailbox, 0, "Secure-join failed (mail not encrypted).");
			end_bobs_joining(mailbox, BOB_ERROR);
			goto cleanup;
		}

		uint32_t contact_id = chat_id_2_contact_id(mailbox, chat_id);
		mrsqlite3_lock(mailbox->m_sql);
		locked = 1;
			mrmailbox_scaleup_contact_origin__(mailbox, contact_id, MR_ORIGIN_SECURE_JOINED);
		mrsqlite3_unlock(mailbox->m_sql);
		locked = 0;

		mrmailbox_add_system_msg(mailbox, chat_id, "Secure-join connection established.");

		s_bob_expects = 0;
		end_bobs_joining(mailbox, BOB_SUCCESS);
	}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
}
