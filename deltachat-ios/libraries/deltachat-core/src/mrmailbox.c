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


#include <sys/stat.h>
#include <sys/types.h> /* for getpid() */
#include <unistd.h>    /* for getpid() */
#include <openssl/opensslv.h>
#include "mrmailbox_internal.h"
#include "mrimap.h"
#include "mrsmtp.h"
#include "mrmimeparser.h"
#include "mrmimefactory.h"
#include "mrtools.h"
#include "mrjob.h"
#include "mrloginparam.h"
#include "mrkey.h"
#include "mrpgp.h"
#include "mrapeerstate.h"


/*******************************************************************************
 * Handle groups for received messages
 ******************************************************************************/


#define MR_CREATE_GROUP_AS_NEEDED  0x01


static uint32_t lookup_group_by_grpid__(mrmailbox_t* mailbox, mrmimeparser_t* mime_parser, int create_flags,
                                        uint32_t from_id, carray* to_ids)
{
	/* search the grpid in the header */
	uint32_t              chat_id = 0;
	clistiter*            cur;
	struct mailimf_field* field;
	char*                 grpid1 = NULL, *grpid2 = NULL, *grpid3 = NULL, *grpid4 = NULL;
	const char*           grpid = NULL; /* must not be freed, just one of the others */
	char*                 grpname = NULL;
	sqlite3_stmt*         stmt;
	int                   i, to_ids_cnt = carray_count(to_ids);
	char*                 self_addr = NULL;
	int                   recreate_member_list = 0;
	int                   send_EVENT_CHAT_MODIFIED = 0;

	/* special commands */
	char*                 X_MrRemoveFromGrp = NULL; /* pointer somewhere into mime_parser, must not be freed */
	char*                 X_MrAddToGrp = NULL; /* pointer somewhere into mime_parser, must not be freed */
	int                   X_MrGrpNameChanged = 0;
	int                   X_MrGrpImageChanged = 0;

	for( cur = clist_begin(mime_parser->m_header->fld_list); cur!=NULL ; cur=clist_next(cur) )
	{
		field = (struct mailimf_field*)clist_content(cur);
		if( field )
		{
			if( field->fld_type == MAILIMF_FIELD_OPTIONAL_FIELD )
			{
				struct mailimf_optional_field* optional_field = field->fld_data.fld_optional_field;
				if( optional_field && optional_field->fld_name ) {
					if( strcasecmp(optional_field->fld_name, "X-MrGrpId")==0 || strcasecmp(optional_field->fld_name, "Chat-Group-ID")==0 ) {
						grpid1 = safe_strdup(optional_field->fld_value);
					}
					else if( strcasecmp(optional_field->fld_name, "X-MrGrpName")==0 || strcasecmp(optional_field->fld_name, "Chat-Group-Name")==0 ) {
						grpname = mr_decode_header_string(optional_field->fld_value); /* this is no changed groupname message */
					}
					else if( strcasecmp(optional_field->fld_name, "X-MrRemoveFromGrp")==0 || strcasecmp(optional_field->fld_name, "Chat-Group-Member-Removed")==0 ) {
						X_MrRemoveFromGrp = optional_field->fld_value;
						mime_parser->m_is_system_message = MR_SYSTEM_MEMBER_REMOVED_FROM_GROUP;
					}
					else if( strcasecmp(optional_field->fld_name, "X-MrAddToGrp")==0 || strcasecmp(optional_field->fld_name, "Chat-Group-Member-Added")==0 ) {
						X_MrAddToGrp = optional_field->fld_value;
						mime_parser->m_is_system_message = MR_SYSTEM_MEMBER_ADDED_TO_GROUP;
					}
					else if( strcasecmp(optional_field->fld_name, "X-MrGrpNameChanged")==0 || strcasecmp(optional_field->fld_name, "Chat-Group-Name-Changed")==0 ) {
						X_MrGrpNameChanged = 1;
						mime_parser->m_is_system_message = MR_SYSTEM_GROUPNAME_CHANGED;
					}
					else if( strcasecmp(optional_field->fld_name, "Chat-Group-Image")==0 ) {
						X_MrGrpImageChanged = 1;
						mime_parser->m_is_system_message = MR_SYSTEM_GROUPIMAGE_CHANGED;
					}
				}
			}
			else if( field->fld_type == MAILIMF_FIELD_MESSAGE_ID )
			{
				struct mailimf_message_id* fld_message_id = field->fld_data.fld_message_id;
				if( fld_message_id ) {
					grpid2 = mr_extract_grpid_from_rfc724_mid(fld_message_id->mid_value);
				}
			}
			else if( field->fld_type == MAILIMF_FIELD_IN_REPLY_TO )
			{
				struct mailimf_in_reply_to* fld_in_reply_to = field->fld_data.fld_in_reply_to;
				if( fld_in_reply_to ) {
					grpid3 = mr_extract_grpid_from_rfc724_mid_list(fld_in_reply_to->mid_list);
				}
			}
			else if( field->fld_type == MAILIMF_FIELD_REFERENCES )
			{
				struct mailimf_references* fld_references = field->fld_data.fld_references;
				if( fld_references ) {
					grpid4 = mr_extract_grpid_from_rfc724_mid_list(fld_references->mid_list);
				}
			}

		}
	}

	grpid = grpid1? grpid1 : (grpid2? grpid2 : (grpid3? grpid3 : grpid4));
	if( grpid == NULL ) {
		goto cleanup;
	}

	/* check, if we have a chat with this group ID */
	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_CHATS_WHERE_grpid,
		"SELECT id FROM chats WHERE grpid=?;");
	sqlite3_bind_text (stmt, 1, grpid, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt)==SQLITE_ROW ) {
		chat_id = sqlite3_column_int(stmt, 0);
	}

	/* check if the sender is a member of the existing group -
	if not, the message does not go to the group chat but to the normal chat with the sender */
	if( chat_id!=0 && !mrmailbox_is_contact_in_chat__(mailbox, chat_id, from_id) ) {
		chat_id = 0;
		goto cleanup;
	}

	/* check if the group does not exist but should be created */
	int group_explicitly_left = mrmailbox_group_explicitly_left__(mailbox, grpid);

	self_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", "");
	if( chat_id == 0
	 && (create_flags&MR_CREATE_GROUP_AS_NEEDED)
	 && grpname
	 && X_MrRemoveFromGrp==NULL /*otherwise, a pending "quit" message may pop up*/
	 && (!group_explicitly_left || (X_MrAddToGrp&&strcasecmp(self_addr,X_MrAddToGrp)==0) ) /*re-create explicitly left groups only if ourself is re-added*/
	 )
	{
		stmt = mrsqlite3_prepare_v2_(mailbox->m_sql,
			"INSERT INTO chats (type, name, grpid) VALUES(?, ?, ?);");
		sqlite3_bind_int (stmt, 1, MR_CHAT_TYPE_GROUP);
		sqlite3_bind_text(stmt, 2, grpname, -1, SQLITE_STATIC);
		sqlite3_bind_text(stmt, 3, grpid, -1, SQLITE_STATIC);
		if( sqlite3_step(stmt)!=SQLITE_DONE ) {
			goto cleanup;
		}
		sqlite3_finalize(stmt);
		chat_id = sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj);
		recreate_member_list = 1;
	}

	/* again, check chat_id */
	if( chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		chat_id = 0;
		if( group_explicitly_left ) {
			chat_id = MR_CHAT_ID_TRASH; /* we got a message for a chat we've deleted - do not show this even as a normal chat */
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
			uint32_t to_id = (uint32_t)(uintptr_t)carray_get(to_ids, i); /* to_id is only once in to_ids and is non-special */
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
			goto cleanup;
		}
	}

cleanup:
	free(grpid1);
	free(grpid2);
	free(grpid3);
	free(grpid4);
	free(grpname);
	free(self_addr);
	return chat_id;
}


/*******************************************************************************
 * Receive a message and add it to the database
 ******************************************************************************/


static void receive_imf(mrmailbox_t* ths, const char* imf_raw_not_terminated, size_t imf_raw_bytes,
                          const char* server_folder, uint32_t server_uid, uint32_t flags)
{
	/* the function returns the number of created messages in the database */
	int              incoming = 0;
	int              incoming_origin = MR_ORIGIN_UNSET;
	#define          outgoing (!incoming)

	carray*          to_ids = NULL;

	uint32_t         from_id = 0;
	int              from_id_blocked = 0;
	uint32_t         to_id   = 0;
	uint32_t         chat_id = 0;
	int              state   = MR_STATE_UNDEFINED;

	sqlite3_stmt*    stmt;
	size_t           i, icnt;
	uint32_t         first_dblocal_id = 0;
	char*            rfc724_mid = NULL; /* Message-ID from the header */
	time_t           message_timestamp = MR_INVALID_TIMESTAMP;
	mrmimeparser_t*  mime_parser = mrmimeparser_new(ths->m_blobdir, ths);
	int              db_locked = 0;
	int              transaction_pending = 0;
	clistiter*       cur1;
	const struct mailimf_field* field;

	carray*          created_db_entries = carray_new(16);
	int              create_event_to_send = MR_EVENT_MSGS_CHANGED;

	carray*          rr_event_to_send = carray_new(16);

	int              has_return_path = 0;
	char*            txt_raw = NULL;

	mrmailbox_log_info(ths, 0, "Receive message #%lu from %s.", server_uid, server_folder? server_folder:"?");

	to_ids = carray_new(16);
	if( to_ids==NULL || created_db_entries==NULL || rr_event_to_send==NULL || mime_parser == NULL ) {
		mrmailbox_log_info(ths, 0, "Bad param.");
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
	if( mime_parser->m_header == NULL ) {
		mrmailbox_log_info(ths, 0, "No header.");
		goto cleanup; /* Error - even adding an empty record won't help as we do not know the message ID */
	}

	mrsqlite3_lock(ths->m_sql);
	db_locked = 1;

	mrsqlite3_begin_transaction__(ths->m_sql);
	transaction_pending = 1;


		/* Check, if the mail comes from extern, resp. is not send by us.  This is a _really_ important step
		as messages send by us are used to validate other mail senders and receivers.
		For this purpose, we assume, the `Return-Path:`-header is never present if the message is send by us.
		The `Received:`-header may be another idea, however, this is also set if mails are transfered from other accounts via IMAP.
		Using `From:` alone is no good idea, as mailboxes may use different sending-addresses - moreover, they may change over the years.
		However, we use `From:` as an additional hint below. */
		for( cur1 = clist_begin(mime_parser->m_header->fld_list); cur1!=NULL ; cur1=clist_next(cur1) )
		{
			field = (struct mailimf_field*)clist_content(cur1);
			if( field )
			{
				if( field->fld_type == MAILIMF_FIELD_RETURN_PATH )
				{
					has_return_path = 1;
				}
				else if( field->fld_type == MAILIMF_FIELD_OPTIONAL_FIELD )
				{
					struct mailimf_optional_field* optional_field = field->fld_data.fld_optional_field;
					if( optional_field && strcasecmp(optional_field->fld_name, "Return-Path")==0 )
					{
						has_return_path = 1; /* "MAILIMF_FIELD_OPTIONAL_FIELD.Return-Path" should be "MAILIMF_FIELD_RETURN_PATH", however, this is not always the case */
					}
				}
			}
		}

		if( has_return_path ) {
			incoming = 1;
		}


		/* for incoming messages, get From: and check if it is known (for known From:'s we add the other To:/Cc:/Bcc: in the 3rd pass) */
		if( incoming
		 && (field=mr_find_mailimf_field(mime_parser->m_header,  MAILIMF_FIELD_FROM  ))!=NULL )
		{
			struct mailimf_from* fld_from = field->fld_data.fld_from;
			if( fld_from )
			{
				int check_self;
				carray* from_list = carray_new(16);
				mrmailbox_add_or_lookup_contacts_by_mailbox_list__(ths, fld_from->frm_mb_list, MR_ORIGIN_INCOMING_UNKNOWN_FROM, from_list, &check_self);
				if( check_self )
				{
					incoming = 0; /* The `Return-Path:`-approach above works well, however, there may be messages outgoing messages which we also receive -
					              for these messages, the `Return-Path:` is set although we're the sender.  To correct these cases, we add an
					              additional From: check - which, however, will not work for older From:-addresses used on the mailbox. */
				}
				else
				{
					if( carray_count(from_list)>=1 ) /* if there is no from given, from_id stays 0 which is just fine.  These messages are very rare, however, we have to add the to the database (they to to the "deaddrop" chat) to avoid a re-download from the server. See also [**] */
					{
						from_id = (uint32_t)(uintptr_t)carray_get(from_list, 0);
						incoming_origin = mrmailbox_get_contact_origin__(ths, from_id, &from_id_blocked);
					}
				}
				carray_free(from_list);
			}
		}

		/* Make sure, to_ids starts with the first To:-address (Cc: and Bcc: are added in the loop below pass) */
		if( (field=mr_find_mailimf_field(mime_parser->m_header, MAILIMF_FIELD_TO))!=NULL )
		{
			struct mailimf_to* fld_to = field->fld_data.fld_to; /* can be NULL */
			if( fld_to )
			{
				mrmailbox_add_or_lookup_contacts_by_address_list__(ths, fld_to->to_addr_list /*!= NULL*/,
					outgoing? MR_ORIGIN_OUTGOING_TO : (incoming_origin>=MR_ORIGIN_MIN_VERIFIED? MR_ORIGIN_INCOMING_TO : MR_ORIGIN_INCOMING_UNKNOWN_TO), to_ids, NULL);
			}
		}

		if( mrmimeparser_has_nonmeta(mime_parser) )
		{

			/**********************************************************************
			 * Add parts
			 *********************************************************************/

			/* collect the rest information */
			for( cur1 = clist_begin(mime_parser->m_header->fld_list); cur1!=NULL ; cur1=clist_next(cur1) )
			{
				field = (struct mailimf_field*)clist_content(cur1);
				if( field )
				{
					if( field->fld_type == MAILIMF_FIELD_MESSAGE_ID )
					{
						struct mailimf_message_id* fld_message_id = field->fld_data.fld_message_id;
						if( fld_message_id ) {
							rfc724_mid = safe_strdup(fld_message_id->mid_value);
						}
					}
					else if( field->fld_type == MAILIMF_FIELD_CC )
					{
						struct mailimf_cc* fld_cc = field->fld_data.fld_cc;
						if( fld_cc ) {
							mrmailbox_add_or_lookup_contacts_by_address_list__(ths, fld_cc->cc_addr_list,
								outgoing? MR_ORIGIN_OUTGOING_CC : (incoming_origin>=MR_ORIGIN_MIN_VERIFIED? MR_ORIGIN_INCOMING_CC : MR_ORIGIN_INCOMING_UNKNOWN_CC), to_ids, NULL);
						}
					}
					else if( field->fld_type == MAILIMF_FIELD_BCC )
					{
						struct mailimf_bcc* fld_bcc = field->fld_data.fld_bcc;
						if( outgoing && fld_bcc ) {
							mrmailbox_add_or_lookup_contacts_by_address_list__(ths, fld_bcc->bcc_addr_list,
								MR_ORIGIN_OUTGOING_BCC, to_ids, NULL);
						}
					}
					else if( field->fld_type == MAILIMF_FIELD_ORIG_DATE )
					{
						struct mailimf_orig_date* orig_date = field->fld_data.fld_orig_date;
						if( orig_date ) {
							message_timestamp = mr_timestamp_from_date(orig_date->dt_date_time); /* is not yet checked against bad times! */
						}
					}
				}

			} /* for */


			/* check if the message introduces a new chat:
			- outgoing messages introduce a chat with the first to: address if they are send by a messenger
			- incoming messages introduce a chat only for known contacts if they are send by a messenger
			(of course, the user can add other chats manually later) */
			if( incoming )
			{
				state = (flags&MR_IMAP_SEEN)? MR_STATE_IN_SEEN : MR_STATE_IN_FRESH;
				to_id = MR_CONTACT_ID_SELF;

				/* test if there is a normal chat with the sender - if so, this allows us to create groups in the next step */
				int test_normal_chat_id = mrmailbox_lookup_real_nchat_by_contact_id__(ths, from_id); /* note that the test_normal_chat_id is also used below (saves one lookup call) */

				/* check for a group chat */
				chat_id = lookup_group_by_grpid__(ths, mime_parser, (test_normal_chat_id || incoming_origin>=MR_ORIGIN_MIN_START_NEW_NCHAT/*always false, for now*/)? MR_CREATE_GROUP_AS_NEEDED : 0, from_id, to_ids);
				if( chat_id == 0 )
				{
					if( mrmimeparser_is_mailinglist_message(mime_parser) )
					{
						chat_id = MR_CHAT_ID_TRASH;
						mrmailbox_log_info(ths, 0, "Message belongs to a mailing list and is ignored.");
						/* currently we do not show mailing list messages as the would result in lots of unwanted mesages:
						(NB: typical mailing list header: `From: sender@gmx.net To: list@address.net)

						- even if we know the sender, it does not make sense, to extract an mailing list message from the context and
						  show it in the thread

						- if we do not know the sender, it may be "known" by the is_reply_to_known_message__() function -
						  this would be even more irritating as the sender may be unknown to the user
						  (typical scenario: the users posts a message to a mailing list and an formally unknown user answers -
						  this message would pop up in Delta Chat as it is a reply to a sent message)

						"Mailing lists messages" in this sense are messages marked by List-Id or Precedence headers.
						For the future, we might want to show mailing lists as groups.
						NB: MR_CHAT_ID_TRASH does not remove the message on IMAP, it simply copies it to an invisible chat
						(we have to track the message-id as otherwise the message pops up again and again) */
					}
					else
					{
						chat_id = test_normal_chat_id;
						if( chat_id == 0 )
						{
							if( incoming_origin>=MR_ORIGIN_MIN_START_NEW_NCHAT/*always false, for now*/ )
							{
								chat_id = mrmailbox_create_or_lookup_nchat_by_contact_id__(ths, from_id);
							}
							else if( mrmailbox_is_reply_to_known_message__(ths, mime_parser) )
							{
								mrmailbox_scaleup_contact_origin__(ths, from_id, MR_ORIGIN_INCOMING_REPLY_TO);
								//chat_id = mrmailbox_create_or_lookup_nchat_by_contact_id__(ths, from_id); -- we do not want any chat to be created implicitly.  Because of the origin-scale-up, the contact requests will pop up and this should be just fine.
								mrmailbox_log_info(ths, 0, "Message is a reply to a known message, mark sender as known.");
							}
						}
					}

					if( chat_id == 0 ) {
						chat_id = MR_CHAT_ID_DEADDROP;
						if( state == MR_STATE_IN_FRESH ) {
							if( incoming_origin<MR_ORIGIN_MIN_VERIFIED && mime_parser->m_is_send_by_messenger==0 ) {
								state = MR_STATE_IN_NOTICED; /* degrade state for unknown senders and non-delta messages (the latter may be removed if we run into spam problems, currently this is fine) (noticed messages do count as being unread; therefore, the deaddrop will not popup in the chatlist) */
							}
						}
					}
				}
			}
			else /* outgoing */
			{
				state = MR_STATE_OUT_DELIVERED; /* the mail is on the IMAP server, probably it is also deliverd.  We cannot recreate other states (read, error). */
				from_id = MR_CONTACT_ID_SELF;
				if( carray_count(to_ids) >= 1 ) {
					to_id   = (uint32_t)(uintptr_t)carray_get(to_ids, 0);

					chat_id = lookup_group_by_grpid__(ths, mime_parser, MR_CREATE_GROUP_AS_NEEDED, from_id, to_ids);
					if( chat_id == 0 )
					{
						chat_id = mrmailbox_lookup_real_nchat_by_contact_id__(ths, to_id);
						if( chat_id == 0 && mime_parser->m_is_send_by_messenger && !mrmailbox_is_contact_blocked__(ths, to_id) ) {
							chat_id = mrmailbox_create_or_lookup_nchat_by_contact_id__(ths, to_id);
						}
					}
				}

				if( chat_id == 0 ) {
					chat_id = MR_CHAT_ID_TO_DEADDROP;
				}
			}

			/* correct message_timestamp, it should not be used before,
			however, we cannot do this earlier as we need from_id to be set */
			message_timestamp = mrmailbox_correct_bad_timestamp__(ths, chat_id, from_id, message_timestamp, (flags&MR_IMAP_SEEN)? 0 : 1 /*fresh message?*/);

			/* unarchive chat */
			mrmailbox_unarchive_chat__(ths, chat_id);

			/* check, if the mail is already in our database - if so, there's nothing more to do
			(we may get a mail twice eg. it it is moved between folders) */
			if( rfc724_mid == NULL ) {
				/* header is lacking a Message-ID - this may be the case, if the message was sent from this account and the mail client
				the the SMTP-server set the ID (true eg. for the Webmailer used in all-inkl-KAS)
				in these cases, we build a message ID based on some useful header fields that do never change (date, to)
				we do not use the folder-local id, as this will change if the mail is moved to another folder. */
				rfc724_mid = mr_create_incoming_rfc724_mid(message_timestamp, from_id, to_ids);
				if( rfc724_mid == NULL ) {
					mrmailbox_log_info(ths, 0, "Cannot create Message-ID.");
					goto cleanup;
				}
			}

			{
				char*    old_server_folder = NULL;
				uint32_t old_server_uid = 0;
				if( mrmailbox_rfc724_mid_exists__(ths, rfc724_mid, &old_server_folder, &old_server_uid) ) {
					/* The message is already added to our database; rollback.  If needed, update the server_uid which may have changed if the message was moved around on the server. */
					if( strcmp(old_server_folder, server_folder)!=0 || old_server_uid!=server_uid ) {
						mrsqlite3_rollback__(ths->m_sql);
						transaction_pending = 0;
						mrmailbox_update_server_uid__(ths, rfc724_mid, server_folder, server_uid);
					}
					free(old_server_folder);
					mrmailbox_log_info(ths, 0, "Message already in DB.");
					goto cleanup;
				}
			}

			/* if the message is not send by a messenger, check if it sent at least a reply to a messenger message
			(later, we move these replies to the Chats-folder) */
			int msgrmsg = mime_parser->m_is_send_by_messenger; /* 1 or 0 for yes/no */
			if( msgrmsg )
			{
				mrmailbox_log_info(ths, 0, "Message sent by another messenger (will be moved to Chats-folder).");
			}
			else
			{
				if( mrmailbox_is_reply_to_messenger_message__(ths, mime_parser) )
				{
					mrmailbox_log_info(ths, 0, "Message is a reply to a messenger message (will be moved to Chats-folder).");
					msgrmsg = 2; /* 2=no, but is reply to messenger message */
				}
			}

			/* fine, so far.  now, split the message into simple parts usable as "short messages"
			and add them to the database (mails send by other messenger clients should result
			into only one message; mails send by other clients may result in several messages (eg. one per attachment)) */
			icnt = carray_count(mime_parser->m_parts); /* should be at least one - maybe empty - part */
			for( i = 0; i < icnt; i++ )
			{
				mrmimepart_t* part = (mrmimepart_t*)carray_get(mime_parser->m_parts, i);
				if( part->m_is_meta ) {
					continue;
				}

				if( part->m_type == MR_MSG_TEXT ) {
					txt_raw = mr_mprintf("%s\n\n%s", mime_parser->m_subject? mime_parser->m_subject : "", part->m_msg_raw);
					if( mime_parser->m_is_system_message ) {
						mrparam_set_int(part->m_param, MRP_SYSTEM_CMD, mime_parser->m_is_system_message);
					}
				}

				stmt = mrsqlite3_predefine__(ths->m_sql, INSERT_INTO_msgs_msscftttsmttpb,
					"INSERT INTO msgs (rfc724_mid,server_folder,server_uid,chat_id,from_id, to_id,timestamp,type, state,msgrmsg,txt,txt_raw,param,bytes)"
					" VALUES (?,?,?,?,?, ?,?,?, ?,?,?,?,?,?);");
				sqlite3_bind_text (stmt,  1, rfc724_mid, -1, SQLITE_STATIC);
				sqlite3_bind_text (stmt,  2, server_folder, -1, SQLITE_STATIC);
				sqlite3_bind_int  (stmt,  3, server_uid);
				sqlite3_bind_int  (stmt,  4, chat_id);
				sqlite3_bind_int  (stmt,  5, from_id);
				sqlite3_bind_int  (stmt,  6, to_id);
				sqlite3_bind_int64(stmt,  7, message_timestamp);
				sqlite3_bind_int  (stmt,  8, part->m_type);
				sqlite3_bind_int  (stmt,  9, state);
				sqlite3_bind_int  (stmt, 10, msgrmsg);
				sqlite3_bind_text (stmt, 11, part->m_msg? part->m_msg : "", -1, SQLITE_STATIC);
				sqlite3_bind_text (stmt, 12, txt_raw? txt_raw : "", -1, SQLITE_STATIC);
				sqlite3_bind_text (stmt, 13, part->m_param->m_packed, -1, SQLITE_STATIC);
				sqlite3_bind_int  (stmt, 14, part->m_bytes);
				if( sqlite3_step(stmt) != SQLITE_DONE ) {
					mrmailbox_log_info(ths, 0, "Cannot write DB.");
					goto cleanup; /* i/o error - there is nothing more we can do - in other cases, we try to write at least an empty record */
				}

				free(txt_raw);
				txt_raw = NULL;

				if( first_dblocal_id == 0 ) {
					first_dblocal_id = sqlite3_last_insert_rowid(ths->m_sql->m_cobj);
				}

				carray_add(created_db_entries, (void*)(uintptr_t)chat_id, NULL);
				carray_add(created_db_entries, (void*)(uintptr_t)first_dblocal_id, NULL);
			}

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
				else if( chat_id == MR_CHAT_ID_DEADDROP ) {
					create_event_to_send = MR_EVENT_MSGS_CHANGED;
					/*if( mrsqlite3_get_config_int__(ths->m_sql, "show_deaddrop", 0)!=0 ) {
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

			int mdns_enabled = mrsqlite3_get_config_int__(ths->m_sql, "mdns_enabled", MR_MDNS_DEFAULT_ENABLED);
			icnt = carray_count(mime_parser->m_reports);
			for( i = 0; i < icnt; i++ )
			{
				int                        mdn_consumed = 0;
				struct mailmime*           report_root = carray_get(mime_parser->m_reports, i);
				struct mailmime_parameter* report_type = mr_find_ct_parameter(report_root, "report-type");
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
							if( mr_mime_transfer_decode(report_data, &report_body, &report_body_bytes, &to_mmap_string_unref) )
							{
								struct mailmime* report_parsed = NULL;
								size_t dummy = 0;
								if( mailmime_parse(report_body, report_body_bytes, &dummy, &report_parsed)==MAIL_NO_ERROR
								 && report_parsed!=NULL )
								{
									struct mailimf_fields* report_fields = mr_find_mailimf_fields(report_parsed);
									if( report_fields )
									{
										struct mailimf_optional_field* of_disposition = mr_find_mailimf_field2(report_fields, "Disposition"); /* MUST be preset, _if_ preset, we assume a sort of attribution and do not go into details */
										struct mailimf_optional_field* of_org_msgid   = mr_find_mailimf_field2(report_fields, "Original-Message-ID"); /* can't live without */
										if( of_disposition && of_disposition->fld_value && of_org_msgid && of_org_msgid->fld_value )
										{
											char* rfc724_mid = NULL;
											dummy = 0;
											if( mailimf_msg_id_parse(of_org_msgid->fld_value, strlen(of_org_msgid->fld_value), &dummy, &rfc724_mid)==MAIL_NO_ERROR
											 && rfc724_mid!=NULL )
											{
												uint32_t chat_id = 0;
												uint32_t msg_id = 0;
												if( mrmailbox_mdn_from_ext__(ths, from_id, rfc724_mid, &chat_id, &msg_id) ) {
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

					CAVE: we rely on mrimap_markseen_msg() not to move messages that are aready in the correct folder.
					otherwiese, the moved message get a new server_uid and is "fresh" again and we will be here again to move it away -
					a classical deadlock, see also (***) */
					if( mime_parser->m_is_send_by_messenger || mdn_consumed ) {
						char* jobparam = mr_mprintf("%c=%s\n%c=%lu", MRP_SERVER_FOLDER, server_folder, MRP_SERVER_UID, server_uid);
							mrjob_add__(ths, MRJ_MARKSEEN_MDN_ON_IMAP, 0, jobparam);
						free(jobparam);
					}
				}

			} /* for() */

		}

		/* debug print? */
		if( mrsqlite3_get_config_int__(ths->m_sql, "save_eml", 0) ) {
			char* emlname = mr_mprintf("%s/%s-%i.eml", ths->m_blobdir, server_folder, (int)first_dblocal_id /*may be 0 for MDNs*/);
			FILE* emlfileob = fopen(emlname, "w");
			if( emlfileob ) {
				fwrite(imf_raw_not_terminated, 1, imf_raw_bytes, emlfileob);
				fclose(emlfileob);
			}
			free(emlname);
		}

	/* end sql-transaction */
	mrsqlite3_commit__(ths->m_sql);
	transaction_pending = 0;

	/* done */
cleanup:
	if( transaction_pending ) {
		mrsqlite3_rollback__(ths->m_sql);
	}

	if( db_locked ) {
		mrsqlite3_unlock(ths->m_sql);
	}

	if( mime_parser ) {
		mrmimeparser_unref(mime_parser);
	}

	if( rfc724_mid ) {
		free(rfc724_mid);
	}

	if( to_ids ) {
		carray_free(to_ids);
	}

	if( created_db_entries ) {
		if( create_event_to_send ) {
			size_t i, icnt = carray_count(created_db_entries);
			for( i = 0; i < icnt; i += 2 ) {
				ths->m_cb(ths, create_event_to_send, (uintptr_t)carray_get(created_db_entries, i), (uintptr_t)carray_get(created_db_entries, i+1));
			}
		}
		carray_free(created_db_entries);
	}

	if( rr_event_to_send ) {
		size_t i, icnt = carray_count(rr_event_to_send);
		for( i = 0; i < icnt; i += 2 ) {
			ths->m_cb(ths, MR_EVENT_MSG_READ, (uintptr_t)carray_get(rr_event_to_send, i), (uintptr_t)carray_get(rr_event_to_send, i+1));
		}
		carray_free(rr_event_to_send);
	}

	free(txt_raw);
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


static uintptr_t cb_dummy(mrmailbox_t* mailbox, int event, uintptr_t data1, uintptr_t data2)
{
	return 0;
}
static int32_t cb_get_config_int(mrimap_t* imap, const char* key, int32_t value)
{
	mrmailbox_t* mailbox = (mrmailbox_t*)imap->m_userData;
	mrsqlite3_lock(mailbox->m_sql);
		int32_t ret = mrsqlite3_get_config_int__(mailbox->m_sql, key, value);
	mrsqlite3_unlock(mailbox->m_sql);
	return ret;
}
static void cb_set_config_int(mrimap_t* imap, const char* key, int32_t def)
{
	mrmailbox_t* mailbox = (mrmailbox_t*)imap->m_userData;
	mrsqlite3_lock(mailbox->m_sql);
		mrsqlite3_set_config_int__(mailbox->m_sql, key, def);
	mrsqlite3_unlock(mailbox->m_sql);
}
static void cb_receive_imf(mrimap_t* imap, const char* imf_raw_not_terminated, size_t imf_raw_bytes, const char* server_folder, uint32_t server_uid, uint32_t flags)
{
	mrmailbox_t* mailbox = (mrmailbox_t*)imap->m_userData;
	receive_imf(mailbox, imf_raw_not_terminated, imf_raw_bytes, server_folder, server_uid, flags);
}


/**
 * Create a new mailbox object.  After creation it is usually
 * opened, connected and mails are fetched.
 * After usage, the object should be deleted using mrmailbox_unref().
 *
 * @memberof mrmailbox_t
 *
 * @param cb a callback function that is called for events (update,
 *     state changes etc.) and to get some information form the client (eg. translation
 *     for a given string).
 *     See mrevent.h for a list of possible events that may be passed to the callback.
 *     - The callback MAY be called from _any_ thread, not only the main/GUI thread!
 *     - The callback MUST NOT call any mrmailbox_* and related functions unless stated
 *       otherwise!
 *     - The callback SHOULD return _fast_, for GUI updates etc. you should
 *       post yourself an asynchronous message to your GUI thread, if needed.
 *     - If not mentioned otherweise, the callback should return 0.
 *
 * @param userdata can be used by the client for any purpuse.  He finds it
 *     later in mrmailbox_get_userdata().
 *
 * @param os_name is only for decorative use and is shown eg. in the X-Mailer header
 *     in the form "Delta Chat <version> for <osName>"
 *
 * @return a mailbox object with some public members the object must be passed to the other mailbox functions
 *     and the object must be freed using mrmailbox_unref() after usage.
 */
mrmailbox_t* mrmailbox_new(mrmailboxcb_t cb, void* userdata, const char* os_name)
{
	mrmailbox_get_thread_index(); /* make sure, the main thread has the index #1, only for a nicer look of the logs */

	mrmailbox_t* ths = NULL;

	if( (ths=calloc(1, sizeof(mrmailbox_t)))==NULL ) {
		exit(23); /* cannot allocate little memory, unrecoverable error */
	}

	pthread_mutex_init(&ths->m_log_ringbuf_critical, NULL);

	pthread_mutex_init(&ths->m_wake_lock_critical, NULL);

	ths->m_sql      = mrsqlite3_new(ths);
	ths->m_cb       = cb? cb : cb_dummy;
	ths->m_userdata = userdata;
	ths->m_imap     = mrimap_new(cb_get_config_int, cb_set_config_int, cb_receive_imf, (void*)ths, ths);
	ths->m_smtp     = mrsmtp_new(ths);
	ths->m_os_name  = safe_strdup(os_name);

	mrjob_init_thread(ths);

	mrpgp_init(ths);

	/* Random-seed.  An additional seed with more random data is done just before key generation
	(the timespan between this call and the key generation time is typically random.
	Moreover, later, we add a hash of the first message data to the random-seed
	(it would be okay to seed with even more sensible data, the seed values cannot be recovered from the PRNG output, see OpenSSL's RAND_seed() ) */
	{
	uintptr_t seed[5];
	seed[0] = (uintptr_t)time(NULL);     /* time */
	seed[1] = (uintptr_t)seed;           /* stack */
	seed[2] = (uintptr_t)ths;            /* heap */
	seed[3] = (uintptr_t)pthread_self(); /* thread ID */
	seed[4] = (uintptr_t)getpid();       /* process ID */
	mrpgp_rand_seed(ths, seed, sizeof(seed));
	}

	if( s_localize_mb_obj==NULL ) {
		s_localize_mb_obj = ths;
	}

	return ths;
}


/**
 * Free a mailbox object.
 * If app runs can only be terminated by a forced kill, this may be superfluous.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new().
 *
 * @return none
 */
void mrmailbox_unref(mrmailbox_t* mailbox)
{
	if( mailbox==NULL ) {
		return;
	}

	mrpgp_exit(mailbox);

	mrjob_exit_thread(mailbox);

	if( mrmailbox_is_open(mailbox) ) {
		mrmailbox_close(mailbox);
	}

	mrimap_unref(mailbox->m_imap);
	mrsmtp_unref(mailbox->m_smtp);
	mrsqlite3_unref(mailbox->m_sql);
	pthread_mutex_destroy(&mailbox->m_wake_lock_critical);

	pthread_mutex_destroy(&mailbox->m_log_ringbuf_critical);
	for( int i = 0; i < MR_LOG_RINGBUF_SIZE; i++ ) {
		free(mailbox->m_log_ringbuf[i]);
	}

	free(mailbox->m_os_name);
	free(mailbox);

	if( s_localize_mb_obj==mailbox ) {
		s_localize_mb_obj = NULL;
	}
}


static void update_config_cache__(mrmailbox_t* ths, const char* key)
{
	if( key==NULL || strcmp(key, "e2ee_enabled")==0 ) {
		ths->m_e2ee_enabled = mrsqlite3_get_config_int__(ths->m_sql, "e2ee_enabled", MR_E2EE_DEFAULT_ENABLED);
	}
}


/**
 * Open mailbox database.  If the given file does not exist, it is
 * created and can be set up using mrmailbox_set_config() afterwards.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox: the mailbox object as created by mrmailbox_new
 *
 * @param dbfile the file to use to store the database, sth. like "~/file" won't work on all systems, if in doubt, use absolute paths
 *
 * @param blobdir a directory to store the blobs in, the trailing slash is added by us, so if you want to
 * avoid double slashes, do not add one. If you give NULL as blobdir, `dbfile-blobs` is used in the same directory as _dbfile_ will be created in.
 *
 * @return 1 on success, 0 on failure
 */
int mrmailbox_open(mrmailbox_t* mailbox, const char* dbfile, const char* blobdir)
{
	int success = 0;
	int db_locked = 0;

	if( mailbox == NULL || dbfile == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	db_locked = 1;

	/* Open() sets up the object and connects to the given database
	from which all configuration is read/written to. */

	/* Create/open sqlite database */
	if( !mrsqlite3_open__(mailbox->m_sql, dbfile, 0) ) {
		goto cleanup;
	}
	mrjob_kill_action__(mailbox, MRJ_CONNECT_TO_IMAP);

	/* backup dbfile name */
	mailbox->m_dbfile = safe_strdup(dbfile);

	/* set blob-directory
	(to avoid double slashed, the given directory should not end with an slash) */
	if( blobdir && blobdir[0] ) {
		mailbox->m_blobdir = safe_strdup(blobdir);
	}
	else {
		mailbox->m_blobdir = mr_mprintf("%s-blobs", dbfile);
		mr_create_folder(mailbox->m_blobdir, mailbox);
	}

	/* cache some settings */
	update_config_cache__(mailbox, NULL);

	/* success */
	success = 1;

	/* cleanup */
cleanup:
	if( !success ) {
		if( mrsqlite3_is_open(mailbox->m_sql) ) {
			mrsqlite3_close__(mailbox->m_sql);
		}
	}

	if( db_locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}

	return success;
}


/**
 * Close mailbox database.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new()
 *
 * @return none
 */
void mrmailbox_close(mrmailbox_t* mailbox)
{
	if( mailbox == NULL ) {
		return;
	}

	mrimap_disconnect(mailbox->m_imap);
	mrsmtp_disconnect(mailbox->m_smtp);

	mrsqlite3_lock(mailbox->m_sql);

		if( mrsqlite3_is_open(mailbox->m_sql) ) {
			mrsqlite3_close__(mailbox->m_sql);
		}

		free(mailbox->m_dbfile);
		mailbox->m_dbfile = NULL;

		free(mailbox->m_blobdir);
		mailbox->m_blobdir = NULL;

	mrsqlite3_unlock(mailbox->m_sql);
}


/**
 * Check if a given mailbox database is open.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new().
 *
 * @return 0=mailbox is not open, 1=mailbox is open.
 */
int mrmailbox_is_open(const mrmailbox_t* mailbox)
{
	if( mailbox == NULL ) {
		return 0; /* error - database not opened */
	}

	return mrsqlite3_is_open(mailbox->m_sql);
}


int mrmailbox_poke_eml_file(mrmailbox_t* ths, const char* filename)
{
	/* mainly for testing, may be called by mrmailbox_import_spec() */
	int     success = 0;
	char*   data = NULL;
	size_t  data_bytes;

	if( ths == NULL ) {
		return 0;
	}

	if( mr_read_file(filename, (void**)&data, &data_bytes, ths) == 0 ) {
		goto cleanup;
	}

	receive_imf(ths, data, data_bytes, "import", 0, 0); /* this static function is the reason why this function is not moved to mrmailbox_imex.c */
	success = 1;

cleanup:
	free(data);

	return success;
}


/*******************************************************************************
 * INI-handling, Information
 ******************************************************************************/


/**
 * Configure the mailbox.  The configuration is handled by key=value pairs. Typical configuration options are:
 *
 * - addr         = address to display (needed)
 * - mail_server  = IMAP-server, guessed if left out
 * - mail_user    = IMAP-username, guessed if left out
 * - mail_pw      = IMAP-password (needed)
 * - mail_port    = IMAP-port, guessed if left out
 * - send_server  = SMTP-server, guessed if left out
 * - send_user    = SMTP-user, guessed if left out
 * - send_pw      = SMTP-password, guessed if left out
 * - send_port    = SMTP-port, guessed if left out
 * - server_flags = IMAP-/SMTP-flags, guessed if left out
 * - displayname  = Own name to use when sending messages.  MUAs are allowed to spread this way eg. using CC, defaults to empty
 * - selfstatus   = Own status to display eg. in email footers, defaults to a standard text
 * - e2ee_enabled = 0=no e2ee, 1=prefer encryption (default)
 *
 * @memberof mrmailbox_t
 *
 * @param ths the mailbox object
 *
 * @param key the option to change, typically one of the strings listed above
 *
 * @param value the value to save for "key"
 *
 * @return 0=failure, 1=success
 */
int mrmailbox_set_config(mrmailbox_t* ths, const char* key, const char* value)
{
	int ret;

	if( ths == NULL || key == NULL ) { /* "value" may be NULL */
		return 0;
	}

	mrsqlite3_lock(ths->m_sql);
		ret = mrsqlite3_set_config__(ths->m_sql, key, value);
		update_config_cache__(ths, key);
	mrsqlite3_unlock(ths->m_sql);

	return ret;
}


/**
 * Get a configuration option.  The configuration option is typically set by mrmailbox_set_config() or by the library itself.
 *
 * @memberof mrmailbox_t
 *
 * @param ths the mailbox object as created by mrmmailbox_new()
 *
 * @param key the key to query
 *
 * @param def default value to return if "key" is unset
 *
 * @return Returns current value of "key", if "key" is unset, "def" is returned (which may be NULL)
 *     If the returned values is not NULL, the return value must be free()'d,
 */
char* mrmailbox_get_config(mrmailbox_t* ths, const char* key, const char* def)
{
	char* ret;

	if( ths == NULL || key == NULL ) { /* "def" may be NULL */
		return strdup_keep_null(def);
	}

	mrsqlite3_lock(ths->m_sql);
		ret = mrsqlite3_get_config__(ths->m_sql, key, def);
	mrsqlite3_unlock(ths->m_sql);

	return ret; /* the returned string must be free()'d, returns NULL only if "def" is NULL and "key" is unset */
}


/**
 * Configure the mailbox.  Similar to mrmailbox_set_config() but sets an integer instead of a string.
 * If there is already a key with a string set, this is overwritten by the given integer value.
 *
 * @memberof mrmailbox_t
 */
int mrmailbox_set_config_int(mrmailbox_t* ths, const char* key, int32_t value)
{
	int ret;

	if( ths == NULL || key == NULL ) {
		return 0;
	}

	mrsqlite3_lock(ths->m_sql);
		ret = mrsqlite3_set_config_int__(ths->m_sql, key, value);
		update_config_cache__(ths, key);
	mrsqlite3_unlock(ths->m_sql);

	return ret;
}


/**
 * Get a configuration option. Similar as mrmailbox_get_config() but gets the value as an integer instead of a string.
 *
 * @memberof mrmailbox_t
 */
int32_t mrmailbox_get_config_int(mrmailbox_t* ths, const char* key, int32_t def)
{
	int32_t ret;

	if( ths == NULL || key == NULL ) {
		return def;
	}

	mrsqlite3_lock(ths->m_sql);
		ret = mrsqlite3_get_config_int__(ths->m_sql, key, def);
	mrsqlite3_unlock(ths->m_sql);

	return ret;
}


/**
 * Get information about the mailbox.  The information is returned by a multi-line string and contains information about the current
 * configuration and the last log entries.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as returned by mrmailbox_new().
 *
 * @return String which must be free()'d after usage.  Never returns NULL.
 */
char* mrmailbox_get_info(mrmailbox_t* mailbox)
{
	const char* unset = "0";
	char *displayname = NULL, *temp = NULL, *l_readable_str = NULL, *l2_readable_str = NULL, *fingerprint_str = NULL;
	mrloginparam_t *l = NULL, *l2 = NULL;
	int contacts, chats, real_msgs, deaddrop_msgs, is_configured, dbversion, mdns_enabled, e2ee_enabled, prv_key_count, pub_key_count;
	mrkey_t* self_public = mrkey_new();

	mrstrbuilder_t  ret;
	mrstrbuilder_init(&ret);

	if( mailbox == NULL ) {
		return safe_strdup("ErrBadPtr");
	}

	/* read data (all pointers may be NULL!) */
	l = mrloginparam_new();
	l2 = mrloginparam_new();

	mrsqlite3_lock(mailbox->m_sql);

		mrloginparam_read__(l, mailbox->m_sql, "");
		mrloginparam_read__(l2, mailbox->m_sql, "configured_" /*the trailing underscore is correct*/);

		displayname     = mrsqlite3_get_config__(mailbox->m_sql, "displayname", NULL);

		chats           = mrmailbox_get_chat_cnt__(mailbox);
		real_msgs       = mrmailbox_get_real_msg_cnt__(mailbox);
		deaddrop_msgs   = mrmailbox_get_deaddrop_msg_cnt__(mailbox);
		contacts        = mrmailbox_get_real_contact_cnt__(mailbox);

		is_configured   = mrsqlite3_get_config_int__(mailbox->m_sql, "configured", 0);

		dbversion       = mrsqlite3_get_config_int__(mailbox->m_sql, "dbversion", 0);

		e2ee_enabled    = mailbox->m_e2ee_enabled;

		mdns_enabled    = mrsqlite3_get_config_int__(mailbox->m_sql, "mdns_enabled", MR_MDNS_DEFAULT_ENABLED);

		sqlite3_stmt* stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "SELECT COUNT(*) FROM keypairs;");
		sqlite3_step(stmt);
		prv_key_count = sqlite3_column_int(stmt, 0);
		sqlite3_finalize(stmt);

		stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "SELECT COUNT(*) FROM acpeerstates;");
		sqlite3_step(stmt);
		pub_key_count = sqlite3_column_int(stmt, 0);
		sqlite3_finalize(stmt);

		if( mrkey_load_self_public__(self_public, l2->m_addr, mailbox->m_sql) ) {
			fingerprint_str = mrkey_render_fingerprint(self_public, mailbox);
		}
		else {
			fingerprint_str = safe_strdup("<Not yet calculated>");
		}

	mrsqlite3_unlock(mailbox->m_sql);

	l_readable_str = mrloginparam_get_readable(l);
	l2_readable_str = mrloginparam_get_readable(l2);

	/* create info
	- some keys are display lower case - these can be changed using the `set`-command
	- we do not display the password here; in the cli-utility, you can see it using `get mail_pw`
	- use neutral speach; the Delta Chat Core is not directly related to any front end or end-product
	- contributors: You're welcome to add your names here */
	temp = mr_mprintf(
		"Chats: %i\n"
		"Chat messages: %i\n"
		"Messages in mailbox: %i\n"
		"Contacts: %i\n"
		"Database=%s, dbversion=%i, Blobdir=%s\n"
		"\n"
		"displayname=%s\n"
		"configured=%i\n"
		"config0=%s\n"
		"config1=%s\n"
		"mdns_enabled=%i\n"
		"e2ee_enabled=%i\n"
		"E2EE_DEFAULT_ENABLED=%i\n"
		"Private keys=%i, public keys=%i, fingerprint=\n%s\n"
		"\n"
		"Using Delta Chat Core v%i.%i.%i, SQLite %s-ts%i, libEtPan %i.%i, OpenSSL %i.%i.%i%c. Compiled " __DATE__ ", " __TIME__ " for %i bit usage.\n\n"
		"Log excerpt:\n"
		/* In the frontends, additional software hints may follow here. */

		, chats, real_msgs, deaddrop_msgs, contacts
		, mailbox->m_dbfile? mailbox->m_dbfile : unset,   dbversion,   mailbox->m_blobdir? mailbox->m_blobdir : unset

        , displayname? displayname : unset
		, is_configured
		, l_readable_str, l2_readable_str

		, mdns_enabled

		, e2ee_enabled
		, MR_E2EE_DEFAULT_ENABLED
		, prv_key_count, pub_key_count, fingerprint_str

		, MR_VERSION_MAJOR, MR_VERSION_MINOR, MR_VERSION_REVISION
		, SQLITE_VERSION, sqlite3_threadsafe()   ,  libetpan_get_version_major(), libetpan_get_version_minor()
		, (int)(OPENSSL_VERSION_NUMBER>>28), (int)(OPENSSL_VERSION_NUMBER>>20)&0xFF, (int)(OPENSSL_VERSION_NUMBER>>12)&0xFF, (char)('a'-1+((OPENSSL_VERSION_NUMBER>>4)&0xFF))
		, sizeof(void*)*8

		);
	mrstrbuilder_cat(&ret, temp);
	free(temp);

	/* add log excerpt */
	pthread_mutex_lock(&mailbox->m_log_ringbuf_critical); /*take care not to log here! */
		for( int i = 0; i < MR_LOG_RINGBUF_SIZE; i++ ) {
			int j = (mailbox->m_log_ringbuf_pos+i) % MR_LOG_RINGBUF_SIZE;
			if( mailbox->m_log_ringbuf[j] ) {
				struct tm wanted_struct;
				memcpy(&wanted_struct, localtime(&mailbox->m_log_ringbuf_times[j]), sizeof(struct tm));
				temp = mr_mprintf("\n%02i:%02i:%02i ", (int)wanted_struct.tm_hour, (int)wanted_struct.tm_min, (int)wanted_struct.tm_sec);
					mrstrbuilder_cat(&ret, temp);
					mrstrbuilder_cat(&ret, mailbox->m_log_ringbuf[j]);
				free(temp);
			}
		}
	pthread_mutex_unlock(&mailbox->m_log_ringbuf_critical);

	/* free data */
	mrloginparam_unref(l);
	mrloginparam_unref(l2);
	free(displayname);
	free(l_readable_str);
	free(l2_readable_str);
	free(fingerprint_str);
	mrkey_unref(self_public);
	return ret.m_buf; /* must be freed by the caller */
}


/*******************************************************************************
 * Misc.
 ******************************************************************************/


int mrmailbox_get_archived_count__(mrmailbox_t* mailbox)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_chats_WHERE_archived, "SELECT COUNT(*) FROM chats WHERE blocked=0 AND archived=1;");
	if( sqlite3_step(stmt) == SQLITE_ROW ) {
		return sqlite3_column_int(stmt, 0);
	}
	return 0;
}


int mrmailbox_reset_tables(mrmailbox_t* ths, int bits)
{
	mrmailbox_log_info(ths, 0, "Resetting tables (%i)...", bits);

	mrsqlite3_lock(ths->m_sql);

		if( bits & 1 ) {
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM jobs;");
			mrmailbox_log_info(ths, 0, "Job resetted.");
		}

		if( bits & 2 ) {
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM acpeerstates;");
			mrmailbox_log_info(ths, 0, "Peerstates resetted.");
		}

		if( bits & 4 ) {
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM keypairs;");
			mrmailbox_log_info(ths, 0, "Private keypairs resetted.");
		}

		if( bits & 8 ) {
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM contacts WHERE id>" MR_STRINGIFY(MR_CONTACT_ID_LAST_SPECIAL) ";"); /* the other IDs are reserved - leave these rows to make sure, the IDs are not used by normal contacts*/
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM chats WHERE id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL) ";");
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM chats_contacts;");
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM msgs WHERE id>" MR_STRINGIFY(MR_MSG_ID_LAST_SPECIAL) ";");
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM config WHERE keyname LIKE 'imap.%' OR keyname LIKE 'configured%';");
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM leftgrps;");
			mrmailbox_log_info(ths, 0, "Rest but server config resetted.");
		}

		update_config_cache__(ths, NULL);

	mrsqlite3_unlock(ths->m_sql);

	ths->m_cb(ths, MR_EVENT_MSGS_CHANGED, 0, 0);

	return 1;
}


/**
 * Find out the version of the Delta Chat core library.
 *
 * @memberof mrmailbox_t
 *
 * @return String with version number as `major.minor.revision`. The return value must be free()'d.
 */
char* mrmailbox_get_version_str(void)
{
	return mr_mprintf("%i.%i.%i", (int)MR_VERSION_MAJOR, (int)MR_VERSION_MINOR, (int)MR_VERSION_REVISION);
}


void mrmailbox_wake_lock(mrmailbox_t* mailbox)
{
	if( mailbox == NULL ) {
		return;
	}
	pthread_mutex_lock(&mailbox->m_wake_lock_critical);
		mailbox->m_wake_lock++;
		if( mailbox->m_wake_lock == 1 ) {
			mailbox->m_cb(mailbox, MR_EVENT_WAKE_LOCK, 1, 0);
		}
	pthread_mutex_unlock(&mailbox->m_wake_lock_critical);
}


void mrmailbox_wake_unlock(mrmailbox_t* mailbox)
{
	if( mailbox == NULL ) {
		return;
	}
	pthread_mutex_lock(&mailbox->m_wake_lock_critical);
		if( mailbox->m_wake_lock == 1 ) {
			mailbox->m_cb(mailbox, MR_EVENT_WAKE_LOCK, 0, 0);
		}
		mailbox->m_wake_lock--;
	pthread_mutex_unlock(&mailbox->m_wake_lock_critical);
}


/*******************************************************************************
 * Connect
 ******************************************************************************/


void mrmailbox_connect_to_imap(mrmailbox_t* ths, mrjob_t* job /*may be NULL if the function is called directly!*/)
{
	int             is_locked = 0;
	mrloginparam_t* param = mrloginparam_new();

	if( mrimap_is_connected(ths->m_imap) ) {
		mrmailbox_log_info(ths, 0, "Already connected or trying to connect.");
		goto cleanup;
	}

	mrsqlite3_lock(ths->m_sql);
	is_locked = 1;

		if( mrsqlite3_get_config_int__(ths->m_sql, "configured", 0) == 0 ) {
			mrmailbox_log_error(ths, 0, "Not configured.");
			goto cleanup;
		}

		mrloginparam_read__(param, ths->m_sql, "configured_" /*the trailing underscore is correct*/);

	mrsqlite3_unlock(ths->m_sql);
	is_locked = 0;

	if( !mrimap_connect(ths->m_imap, param) ) {
		mrjob_try_again_later(job, MR_STANDARD_DELAY);
		goto cleanup;
	}

cleanup:
	if( param ) {
		mrloginparam_unref(param);
	}

	if( is_locked ) {
		mrsqlite3_unlock(ths->m_sql);
	}
}


/**
 * Connect to the mailbox using the configured settings.  We connect using IMAP-IDLE or, if this is not possible,
 * a using pull algorithm.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new()
 *
 * @return None
 */
void mrmailbox_connect(mrmailbox_t* mailbox)
{
	if( mailbox == NULL ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);

		mailbox->m_smtp->m_log_connect_errors = 1;
		mailbox->m_imap->m_log_connect_errors = 1;

		mrjob_kill_action__(mailbox, MRJ_CONNECT_TO_IMAP);
		mrjob_add__(mailbox, MRJ_CONNECT_TO_IMAP, 0, NULL);

	mrsqlite3_unlock(mailbox->m_sql);
}


/**
 * Disonnect the mailbox from the server.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new()
 *
 * @return None
 */
void mrmailbox_disconnect(mrmailbox_t* mailbox)
{
	if( mailbox == NULL ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);
		mrjob_kill_action__(mailbox, MRJ_CONNECT_TO_IMAP);
	mrsqlite3_unlock(mailbox->m_sql);

	mrimap_disconnect(mailbox->m_imap);
	mrsmtp_disconnect(mailbox->m_smtp);
}


/**
 * Stay alive.
 * The library tries itself to stay alive. For this purpose there is an additional
 * "heartbeat" thread that checks if the IDLE-thread is up and working. This check is done about every minute.
 * However, depending on the operating system, this thread may be delayed or stopped, if this is the case you can
 * force additional checks manually by just calling mrmailbox_heartbeat() about every minute.
 * If in doubt, call this function too often, not too less :-)
 *
 * @memberof mrmailbox_t
 */
void mrmailbox_heartbeat(mrmailbox_t* ths)
{
	if( ths == NULL ) {
		return;
	}

	//mrmailbox_log_info(ths, 0, "<3 Mailbox");
	mrimap_heartbeat(ths->m_imap);
}

/**
 * Get a list of chats.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned by mrmailbox_new()
 *
 * @param listflags A combination of flags:
 *     - if the flag MR_GCL_ARCHIVED_ONLY is set, only archived chats are returned.
 *       if MR_GCL_ARCHIVED_ONLY is not set, only unarchived chats are returned and
 *       the pseudo-chat MR_CHAT_ID_ARCHIVED_LINK is added if there are _any_ archived
 *       chats
 *     - if the flag MR_GCL_NO_SPECIALS is set, deaddrop and archive link are not added
 *       to the list (may be used eg. for selecting chats on forwarding, the flag is
 *      F not needed when MR_GCL_ARCHIVED_ONLY is already set)

 * @param query An optional query for filtering the list.  Only chats matching this query
 *     are returned.  Give NULL for no filtering.
 *
 * @return A chatlist as an mrchatlist_t object. Must be freed using
 *     mrchatlist_unref() when no longer used
 */
mrchatlist_t* mrmailbox_get_chatlist(mrmailbox_t* mailbox, int listflags, const char* query)
{
	int success = 0;
	int db_locked = 0;
	mrchatlist_t* obj = mrchatlist_new(mailbox);

	mrsqlite3_lock(mailbox->m_sql);
	db_locked = 1;

	if( !mrchatlist_load_from_db__(obj, listflags, query) ) {
		goto cleanup;
	}

	/* success */

	success = 1;

	/* cleanup */
cleanup:
	if( db_locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}

	if( success ) {
		return obj;
	}
	else {
		mrchatlist_unref(obj);
		return NULL;
	}
}


/**
 * Get chat object by a chat ID.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The ID of the chat to get the chat object for.
 *
 * @return A chat object of the type mrchat_t, must be freed using mrchat_unref() when done.
 */
mrchat_t* mrmailbox_get_chat(mrmailbox_t* mailbox, uint32_t chat_id)
{
	int success = 0;
	int db_locked = 0;
	mrchat_t* obj = mrchat_new(mailbox);

	mrsqlite3_lock(mailbox->m_sql);
	db_locked = 1;

	if( !mrchat_load_from_db__(obj, chat_id) ) {
		goto cleanup;
	}

	/* success */
	success = 1;

	/* cleanup */
cleanup:
	if( db_locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}

	if( success ) {
		return obj;
	}
	else {
		mrchat_unref(obj);
		return NULL;
	}
}


/**
 * Mark all message in a chat as _noticed_.
 * _Noticed_ messages are no longer _fresh_ and do not count as being unseen.
 * IMAP/MDNs is not done for noticed messages.  See also mrmailbox_marknoticed_contact()
 * and mrmailbox_markseen_msgs()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The chat ID of which all messages should be marked as being noticed.
 *
 * @return None.
 */
void mrmailbox_marknoticed_chat(mrmailbox_t* mailbox, uint32_t chat_id)
{
	/* marking a chat as "seen" is done by marking all fresh chat messages as "noticed" -
	"noticed" messages are not counted as being unread but are still waiting for being marked as "seen" using mrmailbox_markseen_msgs() */
	sqlite3_stmt* stmt;

	if( mailbox == NULL ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);

		stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_state_WHERE_chat_id_AND_state,
			"UPDATE msgs SET state=" MR_STRINGIFY(MR_STATE_IN_NOTICED) " WHERE chat_id=? AND state=" MR_STRINGIFY(MR_STATE_IN_FRESH) ";");
		sqlite3_bind_int(stmt, 1, chat_id);
		sqlite3_step(stmt);

	mrsqlite3_unlock(mailbox->m_sql);
}


/**
 * Check, if there is a normal chat with a given contact.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param contact_id The contact ID to check.
 *
 * @return If there is a normal chat with the given contact_id, this chat_id is
 *     returned.  If there is no normal chat with the contact_id, the function
 *     returns 0.
 */
uint32_t mrmailbox_get_chat_id_by_contact_id(mrmailbox_t* mailbox, uint32_t contact_id)
{
	uint32_t chat_id = 0;

	mrsqlite3_lock(mailbox->m_sql);

		chat_id = mrmailbox_lookup_real_nchat_by_contact_id__(mailbox, contact_id);

	mrsqlite3_unlock(mailbox->m_sql);

	return chat_id;
}


/**
 * Create a normal chat with a single user.  To create group chats,
 * see mrmailbox_create_group_chat()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param contact_id The contact ID to create the chat for.  If there is already
 *     a chat with this contact, the already existing ID is returned.
 *
 * @return The created or reused chat ID on success. 0 on errors.
 */
uint32_t mrmailbox_create_chat_by_contact_id(mrmailbox_t* mailbox, uint32_t contact_id)
{
	uint32_t      chat_id = 0;
	int           send_event = 0, locked = 0;

	if( mailbox == NULL ) {
		return 0;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		chat_id = mrmailbox_lookup_real_nchat_by_contact_id__(mailbox, contact_id);
		if( chat_id ) {
			mrmailbox_log_warning(mailbox, 0, "Chat with contact %i already exists.", (int)contact_id);
			goto cleanup;
		}

        if( 0==mrmailbox_real_contact_exists__(mailbox, contact_id) ) {
			mrmailbox_log_warning(mailbox, 0, "Cannot create chat, contact %i does not exist.", (int)contact_id);
			goto cleanup;
        }

		chat_id = mrmailbox_create_or_lookup_nchat_by_contact_id__(mailbox, contact_id);
		if( chat_id ) {
			send_event = 1;
		}

		mrmailbox_scaleup_contact_origin__(mailbox, contact_id, MR_ORIGIN_CREATE_CHAT);

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

cleanup:
	if( locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}

	if( send_event ) {
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0);
	}

	return chat_id;
}


static carray* mrmailbox_get_chat_media__(mrmailbox_t* mailbox, uint32_t chat_id, int msg_type, int or_msg_type)
{
	carray* ret = carray_new(100);

	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_WHERE_ctt,
		"SELECT id FROM msgs WHERE chat_id=? AND (type=? OR type=?) ORDER BY timestamp, id;");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, msg_type);
	sqlite3_bind_int(stmt, 3, or_msg_type>0? or_msg_type : msg_type);
	while( sqlite3_step(stmt) == SQLITE_ROW ) {
		carray_add(ret, (void*)(uintptr_t)sqlite3_column_int(stmt, 0), NULL);
	}

	return ret;
}


/**
 * Returns all message IDs of the given types in a chat.  Typically used to show
 * a gallery.  The result must be carray_free()'d
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The chat ID to get all messages with media from.
 *
 * @param msg_type Specify a message type to query here, one of the MR_MSG_* constats.
 *
 * @param or_msg_type Another message type to return, one of the MR_MSG_* constats.
 *     The function will return both types then.  0 if you need only one.
 *
 * @return An array with messages from the given chat ID that have the wanted message types.
 */
carray* mrmailbox_get_chat_media(mrmailbox_t* mailbox, uint32_t chat_id, int msg_type, int or_msg_type)
{
	carray* ret = NULL;

	if( mailbox ) {
		mrsqlite3_lock(mailbox->m_sql);
			ret = mrmailbox_get_chat_media__(mailbox, chat_id, msg_type, or_msg_type);
		mrsqlite3_unlock(mailbox->m_sql);
	}

	return ret;
}


/**
 * Returns all message IDs of the given types in a chat.  Typically used to show
 * a gallery.  The result must be carray_free()'d
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param curr_msg_id  This is the current (image) message displayed.
 *
 * @param dir 1=get the next (image) message, -1=get the previous one.
 *
 * @return Returns the message ID that should be displayed next. The
 *     returned message is in the same chat as the given one.
 *     Typically, this result is passed again to mrmailbox_get_next_media()
 *     later on the next swipe.
 */
uint32_t mrmailbox_get_next_media(mrmailbox_t* mailbox, uint32_t curr_msg_id, int dir)
{
	uint32_t ret_msg_id = 0;
	mrmsg_t* msg = mrmsg_new();
	int      locked = 0;
	carray*  list = NULL;
	int      i, cnt;

	if( mailbox == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( !mrmsg_load_from_db__(msg, mailbox, curr_msg_id) ) {
			goto cleanup;
		}

		if( (list=mrmailbox_get_chat_media__(mailbox, msg->m_chat_id, msg->m_type, 0))==NULL ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	cnt = carray_count(list);
	for( i = 0; i < cnt; i++ ) {
		if( curr_msg_id == (uint32_t)(uintptr_t)carray_get(list, i) )
		{
			if( dir > 0 ) {
				/* get the next message from the current position */
				if( i+1 < cnt ) {
					ret_msg_id = (uint32_t)(uintptr_t)carray_get(list, i+1);
				}
			}
			else if( dir < 0 ) {
				/* get the previous message from the current position */
				if( i-1 >= 0 ) {
					ret_msg_id = (uint32_t)(uintptr_t)carray_get(list, i-1);
				}
			}
			break;
		}
	}


cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( list ) { carray_free(list); }
	mrmsg_unref(msg);
	return ret_msg_id;
}


/**
 * Get contact IDs belonging to a chat.
 *
 * - for normal chats, the function always returns exactly one contact,
 *   MR_CONTACT_ID_SELF is _not_ returned.
 *
 * - for group chats all members are returned, MR_CONTACT_ID_SELF is returned
 *   explicitly as it may happen that oneself gets removed from a still existing
 *   group
 *
 * - for the deaddrop, all contacts are returned, MR_CONTACT_ID_SELF is not
 *   added
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id Chat ID to get the belonging contact IDs for.
 *
 * @return an array of contact IDs belonging to the chat; must be freed using carray_free() when done.
 */
carray* mrmailbox_get_chat_contacts(mrmailbox_t* mailbox, uint32_t chat_id)
{
	/* Normal chats do not include SELF.  Group chats do (as it may happen that one is deleted from a
	groupchat but the chats stays visible, moreover, this makes displaying lists easier) */
	carray*       ret = carray_new(100);
	sqlite3_stmt* stmt;

	if( mailbox == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);

		if( chat_id == MR_CHAT_ID_DEADDROP )
		{
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_WHERE_chat_id,
				"SELECT DISTINCT from_id FROM msgs WHERE chat_id=? and from_id!=0 ORDER BY id DESC;"); /* from_id in the deaddrop chat may be 0, see comment [**] */
			sqlite3_bind_int(stmt, 1, chat_id);
		}
		else
		{
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_c_FROM_chats_contacts_WHERE_c_ORDER_BY,
				"SELECT cc.contact_id FROM chats_contacts cc"
					" LEFT JOIN contacts c ON c.id=cc.contact_id"
					" WHERE cc.chat_id=?"
					" ORDER BY c.id=1, LOWER(c.name||c.addr), c.id;");
			sqlite3_bind_int(stmt, 1, chat_id);
		}

		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			carray_add(ret, (void*)(uintptr_t)sqlite3_column_int(stmt, 0), NULL);
		}

	mrsqlite3_unlock(mailbox->m_sql);

cleanup:
	return ret;
}



/**
 * Returns the message IDs of all _fresh_ messages of any chat. Typically used for implementing
 * notification summaries.  The result must be free()'d.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 */
carray* mrmailbox_get_fresh_msgs(mrmailbox_t* mailbox)
{
	int           show_deaddrop, success = 0, locked = 0;
	carray*       ret = carray_new(128);
	sqlite3_stmt* stmt = NULL;

	if( mailbox==NULL || ret == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		show_deaddrop = 0;//mrsqlite3_get_config_int__(mailbox->m_sql, "show_deaddrop", 0);

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_LEFT_JOIN_contacts_WHERE_fresh,
			"SELECT m.id"
				" FROM msgs m"
				" LEFT JOIN contacts ct ON m.from_id=ct.id"
				" WHERE m.state=" MR_STRINGIFY(MR_STATE_IN_FRESH) " AND m.chat_id!=? AND ct.blocked=0"
				" ORDER BY m.timestamp DESC,m.id DESC;"); /* the list starts with the newest messages*/
		sqlite3_bind_int(stmt, 1, show_deaddrop? 0 : MR_CHAT_ID_DEADDROP);

		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			carray_add(ret, (void*)(uintptr_t)sqlite3_column_int(stmt, 0), NULL);
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	success = 1;

cleanup:
	if( locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}

	if( success ) {
		return ret;
	}
	else {
		if( ret ) {
			carray_free(ret);
		}
		return NULL;
	}
}


/**
 * Get all message IDs belonging to a chat.
 * Optionally, some special markers added to the ID-array may help to
 * implement virtual lists.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The chat ID of which the messages IDs should be queried.
 *
 * @param flags If set to MR_GCM_ADD_DAY_MARKER, the marker MR_MSG_ID_DAYMARKER will
 *     be added before each day (regarding the local timezone).  Set this to 0 if you do not want this behaviour.
 *
 * @param marker1before An optional message ID.  If set, the id MR_MSG_ID_MARKER1 will be added just
 *   before the given ID in the returned array.  Set this to 0 if you do not want this behaviour.
 *
 * @return Array of message IDs, must be carray_free()'d when no longer used.
 */
carray* mrmailbox_get_chat_msgs(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t flags, uint32_t marker1before)
{
	int           success = 0, locked = 0;
	carray*       ret = carray_new(512);
	sqlite3_stmt* stmt = NULL;

	uint32_t      curr_id;
	time_t        curr_local_timestamp;
	int           curr_day, last_day = 0;
	long          cnv_to_local = mr_gm2local_offset();
	#define       SECONDS_PER_DAY 86400

	if( mailbox==NULL || ret == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( chat_id == MR_CHAT_ID_STARRED )
		{
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_LEFT_JOIN_contacts_WHERE_starred,
				"SELECT m.id, m.timestamp"
					" FROM msgs m"
					" LEFT JOIN contacts ct ON m.from_id=ct.id"
					" WHERE m.starred=1 AND ct.blocked=0"
					" ORDER BY m.timestamp,m.id;"); /* the list starts with the oldest message*/
		}
		else
		{
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_LEFT_JOIN_contacts_WHERE_c,
				"SELECT m.id, m.timestamp"
					" FROM msgs m"
					" LEFT JOIN contacts ct ON m.from_id=ct.id"
					" WHERE m.chat_id=? AND ct.blocked=0"
					" ORDER BY m.timestamp,m.id;"); /* the list starts with the oldest message*/
			sqlite3_bind_int(stmt, 1, chat_id);
		}

		while( sqlite3_step(stmt) == SQLITE_ROW )
		{
			curr_id = sqlite3_column_int(stmt, 0);

			/* add user marker */
			if( curr_id == marker1before ) {
				carray_add(ret, (void*)MR_MSG_ID_MARKER1, NULL);
			}

			/* add daymarker, if needed */
			if( flags&MR_GCM_ADDDAYMARKER ) {
				curr_local_timestamp = (time_t)sqlite3_column_int64(stmt, 1) + cnv_to_local;
				curr_day = curr_local_timestamp/SECONDS_PER_DAY;
				if( curr_day != last_day ) {
					carray_add(ret, (void*)MR_MSG_ID_DAYMARKER, NULL);
					last_day = curr_day;
				}
			}

			carray_add(ret, (void*)(uintptr_t)curr_id, NULL);
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	success = 1;

cleanup:
	if( locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}

	if( success ) {
		return ret;
	}
	else {
		if( ret ) {
			carray_free(ret);
		}
		return NULL;
	}
}


/**
 * Search messages containing the given query string.
 * Searching can be done globally (chat_id=0) or in a specified chat only (chat_id
 * set).
 *
 * Global chat results are typically displayed using mrmsg_get_summary(), chat
 * search results may just hilite the corresponding messages and present a
 * prev/next button.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id ID of the chat to search messages in.
 *     Set this to 0 for a global search.
 *
 * @param query The query to search for.
 *
 * @return An array of message IDs. Must be freed using carray_free() when no longer needed.
 *     If nothing can be found, the function returns NULL.
 */
carray* mrmailbox_search_msgs(mrmailbox_t* mailbox, uint32_t chat_id, const char* query)
{
	int           success = 0, locked = 0;
	carray*       ret = carray_new(100);
	char*         strLikeInText = NULL, *strLikeBeg=NULL, *real_query = NULL;
	sqlite3_stmt* stmt = NULL;

	if( mailbox==NULL || ret == NULL || query == NULL ) {
		goto cleanup;
	}

	real_query = safe_strdup(query);
	mr_trim(real_query);
	if( real_query[0]==0 ) {
		success = 1; /*empty result*/
		goto cleanup;
	}

	strLikeInText = mr_mprintf("%%%s%%", real_query);
	strLikeBeg = mr_mprintf("%s%%", real_query); /*for the name search, we use "Name%" which is fast as it can use the index ("%Name%" could not). */

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		/* Incremental search with "LIKE %query%" cannot take advantages from any index
		("query%" could for COLLATE NOCASE indexes, see http://www.sqlite.org/optoverview.html#like_opt )
		An alternative may be the FULLTEXT sqlite stuff, however, this does not really help with incremental search.
		An extra table with all words and a COLLATE NOCASE indexes may help, however,
		this must be updated all the time and probably consumes more time than we can save in tenthousands of searches.
		For now, we just expect the following query to be fast enough :-) */
		#define QUR1  "SELECT m.id, m.timestamp" \
		                  " FROM msgs m" \
		                  " LEFT JOIN contacts ct ON m.from_id=ct.id" \
		                  " WHERE"
		#define QUR2      " AND ct.blocked=0 AND (txt LIKE ? OR ct.name LIKE ?)"
		if( chat_id ) {
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_WHERE_chat_id_AND_query,
				QUR1 " m.chat_id=? " QUR2 " ORDER BY m.timestamp,m.id;"); /* chats starts with the oldest message*/
			sqlite3_bind_int (stmt, 1, chat_id);
			sqlite3_bind_text(stmt, 2, strLikeInText, -1, SQLITE_STATIC);
			sqlite3_bind_text(stmt, 3, strLikeBeg, -1, SQLITE_STATIC);
		}
		else {
			int show_deaddrop = 0;//mrsqlite3_get_config_int__(mailbox->m_sql, "show_deaddrop", 0);
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_WHERE_query,
				QUR1 " (m.chat_id>? OR m.chat_id=?) " QUR2 " ORDER BY m.timestamp DESC,m.id DESC;"); /* chat overview starts with the newest message*/
			sqlite3_bind_int (stmt, 1, MR_CHAT_ID_LAST_SPECIAL);
			sqlite3_bind_int (stmt, 2, show_deaddrop? MR_CHAT_ID_DEADDROP : MR_CHAT_ID_LAST_SPECIAL+1 /*just any ID that is already selected*/);
			sqlite3_bind_text(stmt, 3, strLikeInText, -1, SQLITE_STATIC);
			sqlite3_bind_text(stmt, 4, strLikeBeg, -1, SQLITE_STATIC);
		}

		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			carray_add(ret, (void*)(uintptr_t)sqlite3_column_int(stmt, 0), NULL);
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	success = 1;

cleanup:
	if( locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}
	free(strLikeInText);
	free(strLikeBeg);
	free(real_query);
	if( success ) {
		return ret;
	}
	else {
		if( ret ) {
			carray_free(ret);
		}
		return NULL;
	}
}


static void set_draft_int(mrmailbox_t* mailbox, mrchat_t* chat, uint32_t chat_id, const char* msg)
{
	sqlite3_stmt* stmt;
	mrchat_t*     chat_to_delete = NULL;

	if( mailbox == NULL ) {
		goto cleanup;
	}

	if( chat==NULL ) {
		if( (chat=mrmailbox_get_chat(mailbox, chat_id)) == NULL ) {
			goto cleanup;
		}
		chat_to_delete = chat;
	}

	if( msg && msg[0]==0 ) {
		msg = NULL; /* an empty draft is no draft */
	}

	if( chat->m_draft_text==NULL && msg==NULL
	 && chat->m_draft_timestamp==0 ) {
		goto cleanup; /* nothing to do - there is no old and no new draft */
	}

	if( chat->m_draft_timestamp && chat->m_draft_text && msg && strcmp(chat->m_draft_text, msg)==0 ) {
		goto cleanup; /* for equal texts, we do not update the timestamp */
	}

	/* save draft in object - NULL or empty: clear draft */
	free(chat->m_draft_text);
	chat->m_draft_text      = msg? safe_strdup(msg) : NULL;
	chat->m_draft_timestamp = msg? time(NULL) : 0;

	/* save draft in database */
	mrsqlite3_lock(mailbox->m_sql);

		stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_chats_SET_draft_WHERE_id,
			"UPDATE chats SET draft_timestamp=?, draft_txt=? WHERE id=?;");
		sqlite3_bind_int64(stmt, 1, chat->m_draft_timestamp);
		sqlite3_bind_text (stmt, 2, chat->m_draft_text? chat->m_draft_text : "", -1, SQLITE_STATIC); /* SQLITE_STATIC: we promise the buffer to be valid until the query is done */
		sqlite3_bind_int  (stmt, 3, chat->m_id);

		sqlite3_step(stmt);

	mrsqlite3_unlock(mailbox->m_sql);

	mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0);

cleanup:
	mrchat_unref(chat_to_delete);
}


/**
 * Save a draft for a chat.
 *
 * To get the draft for a given chat ID, use mrchat_t::m_draft_text
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The chat ID to save the draft for.
 *
 * @param msg The message text to save as a draft.
 *
 * @return None.
 */
void mrmailbox_set_draft(mrmailbox_t* mailbox, uint32_t chat_id, const char* msg)
{
	set_draft_int(mailbox, NULL, chat_id, msg);
}


int mrchat_set_draft(mrchat_t* chat, const char* msg) /* deprecated */
{
	set_draft_int(chat->m_mailbox, chat, chat->m_id, msg);
	return 1;
}



#define IS_SELF_IN_GROUP__ (mrmailbox_is_contact_in_chat__(mailbox, chat_id, MR_CONTACT_ID_SELF)==1)
#define DO_SEND_STATUS_MAILS (mrparam_get_int(chat->m_param, MRP_UNPROMOTED, 0)==0)


int mrmailbox_get_fresh_msg_count__(mrmailbox_t* mailbox, uint32_t chat_id)
{
	sqlite3_stmt* stmt = NULL;

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_state_AND_chat_id,
		"SELECT COUNT(*) FROM msgs WHERE state=" MR_STRINGIFY(MR_STATE_IN_FRESH) " AND chat_id=?;"); /* we have an index over the state-column, this should be sufficient as there are typically only few fresh messages */
	sqlite3_bind_int(stmt, 1, chat_id);

	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


uint32_t mrmailbox_get_last_deaddrop_fresh_msg__(mrmailbox_t* mailbox)
{
	sqlite3_stmt* stmt = NULL;

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_msgs_WHERE_fresh_AND_deaddrop,
		"SELECT id FROM msgs WHERE state=" MR_STRINGIFY(MR_STATE_IN_FRESH) " AND chat_id=" MR_STRINGIFY(MR_CHAT_ID_DEADDROP) " ORDER BY timestamp DESC, id DESC;"); /* we have an index over the state-column, this should be sufficient as there are typically only few fresh messages */

	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


int mrmailbox_get_total_msg_count__(mrmailbox_t* mailbox, uint32_t chat_id)
{
	sqlite3_stmt* stmt = NULL;

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_chat_id,
		"SELECT COUNT(*) FROM msgs WHERE chat_id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);

	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


size_t mrmailbox_get_chat_cnt__(mrmailbox_t* mailbox)
{
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_sql->m_cobj==NULL ) {
		return 0; /* no database, no chats - this is no error (needed eg. for information) */
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_chats, "SELECT COUNT(*) FROM chats WHERE id>?;");
	sqlite3_bind_int(stmt, 1, MR_CHAT_ID_LAST_SPECIAL);

	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


uint32_t mrmailbox_lookup_real_nchat_by_contact_id__(mrmailbox_t* mailbox, uint32_t contact_id) /* checks for "real" chats (non-trash, non-unknown) */
{
	sqlite3_stmt* stmt;
	uint32_t chat_id = 0;

	if( mailbox == NULL || mailbox->m_sql->m_cobj==NULL ) {
		return 0; /* no database, no chats - this is no error (needed eg. for information) */
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_chats_WHERE_contact_id,
			"SELECT c.id"
			" FROM chats c"
			" INNER JOIN chats_contacts j ON c.id=j.chat_id"
			" WHERE c.type=? AND c.id>? AND j.contact_id=?;");
	sqlite3_bind_int(stmt, 1, MR_CHAT_TYPE_NORMAL);
	sqlite3_bind_int(stmt, 2, MR_CHAT_ID_LAST_SPECIAL);
	sqlite3_bind_int(stmt, 3, contact_id);

	if( sqlite3_step(stmt) == SQLITE_ROW ) {
		chat_id = sqlite3_column_int(stmt, 0);
	}

	return chat_id;
}


uint32_t mrmailbox_create_or_lookup_nchat_by_contact_id__(mrmailbox_t* mailbox, uint32_t contact_id)
{
	uint32_t      chat_id = 0;
	mrcontact_t*  contact = NULL;
	char*         chat_name;
	char*         q = NULL;
	sqlite3_stmt* stmt = NULL;

	if( mailbox == NULL || mailbox->m_sql->m_cobj==NULL ) {
		return 0; /* database not opened - error */
	}

	if( contact_id == 0 ) {
		return 0;
	}

	if( (chat_id=mrmailbox_lookup_real_nchat_by_contact_id__(mailbox, contact_id)) != 0 ) {
		return chat_id; /* soon success */
	}

	/* get fine chat name */
	contact = mrcontact_new(mailbox);
	if( !mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id) ) {
		goto cleanup;
	}

	chat_name = (contact->m_name&&contact->m_name[0])? contact->m_name : contact->m_addr;

	/* create chat record */
	q = sqlite3_mprintf("INSERT INTO chats (type, name) VALUES(%i, %Q)", MR_CHAT_TYPE_NORMAL, chat_name);
	stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, q);
	if( stmt == NULL) {
		goto cleanup;
	}

    if( sqlite3_step(stmt) != SQLITE_DONE ) {
		goto cleanup;
    }

    chat_id = sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj);

	sqlite3_free(q);
	q = NULL;
	sqlite3_finalize(stmt);
	stmt = NULL;

	/* add contact IDs to the new chat record (may be replaced by mrmailbox_add_contact_to_chat__()) */
	q = sqlite3_mprintf("INSERT INTO chats_contacts (chat_id, contact_id) VALUES(%i, %i)", chat_id, contact_id);
	stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, q);

	if( sqlite3_step(stmt) != SQLITE_DONE ) {
		goto cleanup;
	}

	sqlite3_free(q);
	q = NULL;
	sqlite3_finalize(stmt);
	stmt = NULL;

	/* add already existing messages to the chat record */
	q = sqlite3_mprintf("UPDATE msgs SET chat_id=%i WHERE (chat_id=%i AND from_id=%i) OR (chat_id=%i AND to_id=%i);",
		chat_id,
		MR_CHAT_ID_DEADDROP, contact_id,
		MR_CHAT_ID_TO_DEADDROP, contact_id);
	stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, q);

    if( sqlite3_step(stmt) != SQLITE_DONE ) {
		goto cleanup;
    }

	/* cleanup */
cleanup:
	if( q ) {
		sqlite3_free(q);
	}

	if( stmt ) {
		sqlite3_finalize(stmt);
	}

	if( contact ) {
		mrcontact_unref(contact);
	}
	return chat_id;
}


void mrmailbox_unarchive_chat__(mrmailbox_t* mailbox, uint32_t chat_id)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_chats_SET_unarchived, "UPDATE chats SET archived=0 WHERE id=?");
	sqlite3_bind_int (stmt, 1, chat_id);
	sqlite3_step(stmt);
}



/**
 * Get the total number of messages in a chat.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The ID of the chat to count the messages for.
 *
 * @return Number of total messages in the given chat. 0 for errors or empty chats.
 */
int mrmailbox_get_total_msg_count(mrmailbox_t* mailbox, uint32_t chat_id)
{
	int ret;

	if( mailbox == NULL ) {
		return 0;
	}

	mrsqlite3_lock(mailbox->m_sql);
		ret = mrmailbox_get_total_msg_count__(mailbox, chat_id);
	mrsqlite3_unlock(mailbox->m_sql);

	return ret;
}


/**
 * Get the number of _fresh_ messages in a chat.  Typically used to implement
 * a badge with a number in the chatlist.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The ID of the chat to count the messages for.
 *
 * @return Number of fresh messages in the given chat. 0 for errors or if there are no fresh messages.
 */
int mrmailbox_get_fresh_msg_count(mrmailbox_t* mailbox, uint32_t chat_id)
{
	int ret;

	if( mailbox == NULL ) {
		return 0;
	}

	mrsqlite3_lock(mailbox->m_sql);
		ret = mrmailbox_get_fresh_msg_count__(mailbox, chat_id);
	mrsqlite3_unlock(mailbox->m_sql);

	return ret;
}


/**
 * Archive or unarchive a chat.
 *
 * Archived chats are not included in the default chatlist returned
 * by mrmailbox_get_chatlist().  Instead, if there are _any_ archived chats,
 * the pseudo-chat with the chat_id MR_CHAT_ID_ARCHIVED_LINK will be added the the
 * end of the chatlist.
 *
 * To get a list of archived chats, use mrmailbox_get_chatlist() with the flag MR_GCL_ARCHIVED_ONLY.
 *
 * To find out the archived state of a given chat, use mrchat_t::m_archived
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The ID of the chat to archive or unarchive.
 *
 * @param archive 1=archive chat, 0=unarchive chat
 *
 * @return None
 */
void mrmailbox_archive_chat(mrmailbox_t* mailbox, uint32_t chat_id, int archive)
{
	if( mailbox == NULL || chat_id <= MR_CHAT_ID_LAST_SPECIAL || (archive!=0 && archive!=1) ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);
		sqlite3_stmt* stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "UPDATE chats SET archived=? WHERE id=?;");
		sqlite3_bind_int  (stmt, 1, archive);
		sqlite3_bind_int  (stmt, 2, chat_id);
		sqlite3_step(stmt);
		sqlite3_finalize(stmt);
	mrsqlite3_unlock(mailbox->m_sql);
}


/*******************************************************************************
 * Delete a chat
 ******************************************************************************/


/* _If_ deleting a group chat would implies to leave the group, things get complicated
as this would require to send a message before the chat is deleted physically.
To make things even more complicated, there may be other chat messages waiting to be send.

We used the following approach:
1. If we do not need to send a message, we delete the chat directly
2. If we need to send a message, we set chats.blocked=1 and add the parameter
   MRP_DEL_AFTER_SEND with a random value to both, the last message to be send and to the
   chat (we would use msg_id, however, we may not get this in time)
3. When the messag with the MRP_DEL_AFTER_SEND-value of the chat was send to IMAP, we physically
   delete the chat.

However, from 2017-11-02, we do not implicitly leave the group as this results in different behaviours to normal
chat and _only_ leaving a group is also a valid usecase. */


int mrmailbox_delete_chat_part2(mrmailbox_t* mailbox, uint32_t chat_id)
{
	int       success = 0, locked = 0, pending_transaction = 0;
	mrchat_t* obj = mrchat_new(mailbox);
	char*     q3 = NULL;

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

        if( !mrchat_load_from_db__(obj, chat_id) ) {
			goto cleanup;
        }

		mrsqlite3_begin_transaction__(mailbox->m_sql);
		pending_transaction = 1;

			q3 = sqlite3_mprintf("DELETE FROM msgs WHERE chat_id=%i;", chat_id);
			if( !mrsqlite3_execute__(mailbox->m_sql, q3) ) {
				goto cleanup;
			}
			sqlite3_free(q3);
			q3 = NULL;

			q3 = sqlite3_mprintf("DELETE FROM chats_contacts WHERE chat_id=%i;", chat_id);
			if( !mrsqlite3_execute__(mailbox->m_sql, q3) ) {
				goto cleanup;
			}
			sqlite3_free(q3);
			q3 = NULL;

			q3 = sqlite3_mprintf("DELETE FROM chats WHERE id=%i;", chat_id);
			if( !mrsqlite3_execute__(mailbox->m_sql, q3) ) {
				goto cleanup;
			}
			sqlite3_free(q3);
			q3 = NULL;

		mrsqlite3_commit__(mailbox->m_sql);
		pending_transaction = 0;

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	success = 1;

cleanup:
	if( pending_transaction ) { mrsqlite3_rollback__(mailbox->m_sql); }
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrchat_unref(obj);
	if( q3 ) { sqlite3_free(q3); }
	return success;
}


/**
 * Delete a chat:
 *
 * - messages are deleted from the device and the chat database entry is deleted
 *
 * - messages are _not_ deleted from the server
 *
 * - the chat is not blocked, so new messages from the user/the group may appear
 *   and the user may create the chat again
 *
 * - this is also one of the reasons, why groups are _not left_ -  this would
 *   be unexpected as deleting a normal chat also does not prevent new mails
 *
 * - moreover, there may be valid reasons only to leave a group and only to
 *   delete a group
 *
 * - another argument is, that leaving a group requires sending a message to
 *   all group members - esp. for groups not used for a longer time, this is
 *   really unexpected
 *
 * - to leave a chat, use mrmailbox_remove_contact_from_chat(mailbox, chat_id, MR_CONTACT_ID_SELF)
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The ID of the chat to delete.
 *
 * @return None
 */
void mrmailbox_delete_chat(mrmailbox_t* mailbox, uint32_t chat_id)
{
	mrchat_t*    chat = mrmailbox_get_chat(mailbox, chat_id);
	mrcontact_t* contact = NULL;
	mrmsg_t*     msg = mrmsg_new();

	if( mailbox == NULL || chat_id <= MR_CHAT_ID_LAST_SPECIAL || chat == NULL ) {
		goto cleanup;
	}

	#ifdef GROUP_DELETE_IMPLIES_LEAVING
	if( chat->m_type == MR_CHAT_TYPE_GROUP
	 && mrmailbox_is_contact_in_chat(mailbox, chat_id, MR_CONTACT_ID_SELF)
	 && DO_SEND_STATUS_MAILS )
	{
		/* _first_ mark chat to being delete and _then_ send the message to inform others that we've quit the group
		(the order is important - otherwise the message may be send asynchronous before we update the group. */
		int link_msg_to_chat_deletion = (int)time(NULL);

		mrparam_set_int(chat->m_param, MRP_DEL_AFTER_SEND, link_msg_to_chat_deletion);
		mrsqlite3_lock(mailbox->m_sql);
			sqlite3_stmt* stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "UPDATE chats SET blocked=1, param=? WHERE id=?;");
			sqlite3_bind_text (stmt, 1, chat->m_param->m_packed, -1, SQLITE_STATIC);
			sqlite3_bind_int  (stmt, 2, chat_id);
			sqlite3_step(stmt);
			sqlite3_finalize(stmt);
			mrmailbox_set_group_explicitly_left__(mailbox, chat->m_grpid);
		mrsqlite3_unlock(mailbox->m_sql);

		contact = mrmailbox_get_contact(mailbox, MR_CONTACT_ID_SELF);
		msg->m_type = MR_MSG_TEXT;
		msg->m_text = mrstock_str(MR_STR_MSGGROUPLEFT);
		mrparam_set_int(msg->m_param, MRP_SYSTEM_CMD, MR_SYSTEM_MEMBER_REMOVED_FROM_GROUP);
		mrparam_set    (msg->m_param, MRP_SYSTEM_CMD_PARAM, contact->m_addr);
		mrparam_set_int(msg->m_param, MRP_DEL_AFTER_SEND, link_msg_to_chat_deletion);
		mrmailbox_send_msg(mailbox, chat->m_id, msg);
	}
	else
	#endif
	{
		/* directly delete the chat */
		mrmailbox_delete_chat_part2(mailbox, chat_id);
	}

	mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0);

cleanup:
	mrchat_unref(chat);
	mrcontact_unref(contact);
	mrmsg_unref(msg);
}



/*******************************************************************************
 * Sending messages
 ******************************************************************************/


void mrmailbox_send_msg_to_imap(mrmailbox_t* mailbox, mrjob_t* job)
{
	mrmimefactory_t  mimefactory;
	char*            server_folder = NULL;
	uint32_t         server_uid = 0;

	mrmimefactory_init(&mimefactory, mailbox);

	/* connect to IMAP-server */
	if( !mrimap_is_connected(mailbox->m_imap) ) {
		mrmailbox_connect_to_imap(mailbox, NULL);
		if( !mrimap_is_connected(mailbox->m_imap) ) {
			mrjob_try_again_later(job, MR_STANDARD_DELAY);
			goto cleanup;
		}
	}

	/* create message */
	if( mrmimefactory_load_msg(&mimefactory, job->m_foreign_id)==0
	 || mimefactory.m_from_addr == NULL ) {
		goto cleanup; /* should not happen as we've send the message to the SMTP server before */
	}

	if( !mrmimefactory_render(&mimefactory, 1/*encrypt to self*/) ) {
		goto cleanup; /* should not happen as we've send the message to the SMTP server before */
	}

	if( !mrimap_append_msg(mailbox->m_imap, mimefactory.m_msg->m_timestamp, mimefactory.m_out->str, mimefactory.m_out->len, &server_folder, &server_uid) ) {
		mrjob_try_again_later(job, MR_STANDARD_DELAY);
		goto cleanup;
	}
	else {
		mrsqlite3_lock(mailbox->m_sql);
			mrmailbox_update_server_uid__(mailbox, mimefactory.m_msg->m_rfc724_mid, server_folder, server_uid);
		mrsqlite3_unlock(mailbox->m_sql);
	}

	/* check, if the chat shall be deleted pysically */
	#ifdef GROUP_DELETE_IMPLIES_LEAVING
	if( mrparam_get_int(mimefactory.m_chat->m_param, MRP_DEL_AFTER_SEND, 0)!=0
	 && mrparam_get_int(mimefactory.m_chat->m_param, MRP_DEL_AFTER_SEND, 0)==mrparam_get_int(mimefactory.m_msg->m_param, MRP_DEL_AFTER_SEND, 0) ) {
		mrmailbox_delete_chat_part2(mailbox, mimefactory.m_chat->m_id);
	}
	#endif

cleanup:
	mrmimefactory_empty(&mimefactory);
	free(server_folder);
}


static void mark_as_error(mrmailbox_t* mailbox, mrmsg_t* msg)
{
	if( mailbox==NULL || msg==NULL ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);
		mrmailbox_update_msg_state__(mailbox, msg->m_id, MR_STATE_OUT_ERROR);
	mrsqlite3_unlock(mailbox->m_sql);
	mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, msg->m_chat_id, 0);
}


void mrmailbox_send_msg_to_smtp(mrmailbox_t* mailbox, mrjob_t* job)
{
	mrmimefactory_t mimefactory;

	mrmimefactory_init(&mimefactory, mailbox);

	/* connect to SMTP server, if not yet done */
	if( !mrsmtp_is_connected(mailbox->m_smtp) ) {
		mrloginparam_t* loginparam = mrloginparam_new();
			mrsqlite3_lock(mailbox->m_sql);
				mrloginparam_read__(loginparam, mailbox->m_sql, "configured_");
			mrsqlite3_unlock(mailbox->m_sql);
			int connected = mrsmtp_connect(mailbox->m_smtp, loginparam);
		mrloginparam_unref(loginparam);
		if( !connected ) {
			mrjob_try_again_later(job, MR_STANDARD_DELAY);
			goto cleanup;
		}
	}

	/* load message data */
	if( !mrmimefactory_load_msg(&mimefactory, job->m_foreign_id)
	 || mimefactory.m_from_addr == NULL ) {
		mrmailbox_log_warning(mailbox, 0, "Cannot load data to send, maybe the message is deleted in between.");
		goto cleanup; /* no redo, no IMAP - there won't be more recipients next time (as the data does not exist, there is no need in calling mark_as_error()) */
	}

	/* check if the message is ready (normally, only video files may be delayed this way) */
	if( mimefactory.m_increation ) {
		mrmailbox_log_info(mailbox, 0, "File is in creation, retrying later.");
		mrjob_try_again_later(job, MR_INCREATION_POLL);
		goto cleanup;
	}

	/* send message - it's okay if there are not recipients, this is a group with only OURSELF; we only upload to IMAP in this case */
	if( clist_count(mimefactory.m_recipients_addr) > 0 ) {
		if( !mrmimefactory_render(&mimefactory, 0/*encrypt_to_self*/) ) {
			mark_as_error(mailbox, mimefactory.m_msg);
			mrmailbox_log_error(mailbox, 0, "Empty message."); /* should not happen */
			goto cleanup; /* no redo, no IMAP - there won't be more recipients next time. */
		}

		/* have we guaranteed encryption but cannot fullfill it for any reason? Do not send the message then.*/
		if( mrparam_get_int(mimefactory.m_msg->m_param, MRP_GUARANTEE_E2EE, 0) && !mimefactory.m_out_encrypted ) {
			mark_as_error(mailbox, mimefactory.m_msg);
			mrmailbox_log_error(mailbox, 0, "End-to-end-encryption unavailable unexpectedly.");
			goto cleanup; /* unrecoverable */
		}

		if( !mrsmtp_send_msg(mailbox->m_smtp, mimefactory.m_recipients_addr, mimefactory.m_out->str, mimefactory.m_out->len) ) {
			mrsmtp_disconnect(mailbox->m_smtp);
			mrjob_try_again_later(job, MR_AT_ONCE); /* MR_AT_ONCE is only the _initial_ delay, if the second try failes, the delay gets larger */
			goto cleanup;
		}
	}

	/* done */
	mrsqlite3_lock(mailbox->m_sql);
	mrsqlite3_begin_transaction__(mailbox->m_sql);

		/* debug print? */
		if( mrsqlite3_get_config_int__(mailbox->m_sql, "save_eml", 0) ) {
			char* emlname = mr_mprintf("%s/to-smtp-%i.eml", mailbox->m_blobdir, (int)mimefactory.m_msg->m_id);
			FILE* emlfileob = fopen(emlname, "w");
			if( emlfileob ) {
				fwrite(mimefactory.m_out->str, 1, mimefactory.m_out->len, emlfileob);
				fclose(emlfileob);
			}
			free(emlname);
		}

		mrmailbox_update_msg_state__(mailbox, mimefactory.m_msg->m_id, MR_STATE_OUT_DELIVERED);
		if( mimefactory.m_out_encrypted && mrparam_get_int(mimefactory.m_msg->m_param, MRP_GUARANTEE_E2EE, 0)==0 ) {
			mrparam_set_int(mimefactory.m_msg->m_param, MRP_GUARANTEE_E2EE, 1); /* can upgrade to E2EE - fine! */
			mrmsg_save_param_to_disk__(mimefactory.m_msg);
		}

		if( (mailbox->m_imap->m_server_flags&MR_NO_EXTRA_IMAP_UPLOAD)==0 ) {
			mrjob_add__(mailbox, MRJ_SEND_MSG_TO_IMAP, mimefactory.m_msg->m_id, NULL); /* send message to IMAP in another job */
		}

	mrsqlite3_commit__(mailbox->m_sql);
	mrsqlite3_unlock(mailbox->m_sql);

	mailbox->m_cb(mailbox, MR_EVENT_MSG_DELIVERED, mimefactory.m_msg->m_chat_id, mimefactory.m_msg->m_id);

cleanup:
	mrmimefactory_empty(&mimefactory);
}


uint32_t mrmailbox_send_msg_i__(mrmailbox_t* mailbox, mrchat_t* chat, const mrmsg_t* msg, time_t timestamp)
{
	char*         rfc724_mid = NULL;
	sqlite3_stmt* stmt;
	uint32_t      msg_id = 0, to_id = 0;

	if( chat->m_type==MR_CHAT_TYPE_GROUP && !mrmailbox_is_contact_in_chat__(mailbox, chat->m_id, MR_CONTACT_ID_SELF) ) {
		mrmailbox_log_error(mailbox, MR_ERR_SELF_NOT_IN_GROUP, NULL);
		goto cleanup;
	}

	{
		char* from = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", NULL);
		if( from == NULL ) { goto cleanup; }
			rfc724_mid = mr_create_outgoing_rfc724_mid(chat->m_type==MR_CHAT_TYPE_GROUP? chat->m_grpid : NULL, from);
		free(from);
	}

	if( chat->m_type == MR_CHAT_TYPE_NORMAL )
	{
		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_c_FROM_chats_contacts_WHERE_c,
			"SELECT contact_id FROM chats_contacts WHERE chat_id=?;");
		sqlite3_bind_int(stmt, 1, chat->m_id);
		if( sqlite3_step(stmt) != SQLITE_ROW ) {
			goto cleanup;
		}
		to_id = sqlite3_column_int(stmt, 0);
	}
	else if( chat->m_type == MR_CHAT_TYPE_GROUP )
	{
		if( mrparam_get_int(chat->m_param, MRP_UNPROMOTED, 0)==1 ) {
			/* mark group as being no longer unpromoted */
			mrparam_set(chat->m_param, MRP_UNPROMOTED, NULL);
			mrchat_update_param__(chat);
		}
	}

	/* check if we can guarantee E2EE for this message.  If we can, we won't send the message without E2EE later (because of a reset, changed settings etc. - messages may be delayed significally if there is no network present) */
	int can_guarantee_e2ee = 0;
	if( mailbox->m_e2ee_enabled ) {
		can_guarantee_e2ee = 1;
		sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_p_FROM_chats_contacs_JOIN_contacts_peerstates_WHERE_cc,
			"SELECT ps.prefer_encrypted "
			 " FROM chats_contacts cc "
			 " LEFT JOIN contacts c ON cc.contact_id=c.id "
			 " LEFT JOIN acpeerstates ps ON c.addr=ps.addr "
			 " WHERE cc.chat_id=? AND cc.contact_id>?;");
		sqlite3_bind_int(stmt, 1, chat->m_id);
		sqlite3_bind_int(stmt, 2, MR_CONTACT_ID_LAST_SPECIAL);
		while( sqlite3_step(stmt) == SQLITE_ROW )
		{
			int prefer_encrypted = sqlite3_column_type(stmt, 0)==SQLITE_NULL? MRA_PE_NOPREFERENCE : sqlite3_column_int(stmt, 0);
			if( prefer_encrypted != MRA_PE_MUTUAL ) { /* when gossip becomes available, gossip keys should be used only in groups */
				can_guarantee_e2ee = 0;
				break;
			}
		}
	}

	if( can_guarantee_e2ee ) {
		mrparam_set_int(msg->m_param, MRP_GUARANTEE_E2EE, 1);
	}
	else {
		/* if we cannot guarantee E2EE, clear the flag (may be set if the message was loaded from the database, eg. for forwarding messages ) */
		mrparam_set(msg->m_param, MRP_GUARANTEE_E2EE, NULL);
	}
	mrparam_set(msg->m_param, MRP_ERRONEOUS_E2EE, NULL); /* reset eg. on forwarding */

	/* add message to the database */
	stmt = mrsqlite3_predefine__(mailbox->m_sql, INSERT_INTO_msgs_mcftttstpb,
		"INSERT INTO msgs (rfc724_mid,chat_id,from_id,to_id, timestamp,type,state, txt,param) VALUES (?,?,?,?, ?,?,?, ?,?);");
	sqlite3_bind_text (stmt,  1, rfc724_mid, -1, SQLITE_STATIC);
	sqlite3_bind_int  (stmt,  2, MR_CHAT_ID_MSGS_IN_CREATION);
	sqlite3_bind_int  (stmt,  3, MR_CONTACT_ID_SELF);
	sqlite3_bind_int  (stmt,  4, to_id);
	sqlite3_bind_int64(stmt,  5, timestamp);
	sqlite3_bind_int  (stmt,  6, msg->m_type);
	sqlite3_bind_int  (stmt,  7, MR_STATE_OUT_PENDING);
	sqlite3_bind_text (stmt,  8, msg->m_text? msg->m_text : "",  -1, SQLITE_STATIC);
	sqlite3_bind_text (stmt,  9, msg->m_param->m_packed, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) != SQLITE_DONE ) {
		goto cleanup;
	}

	msg_id = sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj);

	/* finalize message object on database, we set the chat ID late as we don't know it sooner */
	mrmailbox_update_msg_chat_id__(mailbox, msg_id, chat->m_id);
	mrjob_add__(mailbox, MRJ_SEND_MSG_TO_SMTP, msg_id, NULL); /* resuts on an asynchronous call to mrmailbox_send_msg_to_smtp()  */

cleanup:
	free(rfc724_mid);
	return msg_id;
}


/**
 * Send a simple text message to the given chat.
 *
 * Sends the event #MR_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id Chat ID to send the message to.
 *
 * @param text_to_send Text to send to the chat defined by the chat ID.
 *
 * @return The ID of the message that is about being sent.
 */
uint32_t mrmailbox_send_text_msg(mrmailbox_t* mailbox, uint32_t chat_id, const char* text_to_send)
{
	mrmsg_t* msg = mrmsg_new();
	uint32_t ret = 0;

	if( mailbox == NULL || chat_id <= MR_CHAT_ID_LAST_SPECIAL || text_to_send == NULL ) {
		goto cleanup;
	}

	msg->m_type = MR_MSG_TEXT;
	mrmsg_set_text(msg, text_to_send);

	ret = mrmailbox_send_msg(mailbox, chat_id, msg);

cleanup:
	mrmsg_unref(msg);
	return ret;
}


/**
 * save message in database and send it, the given message object is not unref'd
 * by the function but some fields are set up!
 *
 * Sends the event #MR_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id Chat ID to send the message to.
 *
 * @param msg Message object to send to the chat defined by the chat ID.
 *     The function does not take ownership of the object, so you have to
 *     free it using mrmsg_unref() as usual.
 *
 * @return The ID of the message that is about being sent.
 */
uint32_t mrmailbox_send_msg(mrmailbox_t* mailbox, uint32_t chat_id, mrmsg_t* msg)
{
	char* pathNfilename = NULL;

	if( mailbox == NULL || msg == NULL || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		return 0;
	}

	msg->m_id      = 0;
	msg->m_mailbox = mailbox;

	if( msg->m_type == MR_MSG_TEXT )
	{
		; /* the caller should check if the message text is empty */
	}
	else if( MR_MSG_NEEDS_ATTACHMENT(msg->m_type) )
	{
		pathNfilename = mrparam_get(msg->m_param, MRP_FILE, NULL);
		if( pathNfilename )
		{
			/* Got an attachment. Take care, the file may not be ready in this moment!
			This is useful eg. if a video should be sended and already shown as "being processed" in the chat.
			In this case, the user should create an `.increation`; when the file is deleted later on, the message is sended.
			(we do not use a state in the database as this would make eg. forwarding such messages much more complicated) */

			if( msg->m_type == MR_MSG_FILE || msg->m_type == MR_MSG_IMAGE )
			{
				/* Correct the type, take care not to correct already very special formats as GIF or VOICE.
				Typical conversions:
				- from FILE to AUDIO/VIDEO/IMAGE
				- from FILE/IMAGE to GIF */
				int   better_type = 0;
				char* better_mime = NULL;
				mrmsg_guess_msgtype_from_suffix(pathNfilename, &better_type, &better_mime);
				if( better_type ) {
					msg->m_type = better_type;
					mrparam_set(msg->m_param, MRP_MIMETYPE, better_mime);
				}
				free(better_mime);
			}

			if( (msg->m_type == MR_MSG_IMAGE || msg->m_type == MR_MSG_GIF)
			 && (mrparam_get_int(msg->m_param, MRP_WIDTH, 0)<=0 || mrparam_get_int(msg->m_param, MRP_HEIGHT, 0)<=0) ) {
				/* set width/height of images, if not yet done */
				unsigned char* buf = NULL; size_t buf_bytes; uint32_t w, h;
				if( mr_read_file(pathNfilename, (void**)&buf, &buf_bytes, msg->m_mailbox) ) {
					if( mr_get_filemeta(buf, buf_bytes, &w, &h) ) {
						mrparam_set_int(msg->m_param, MRP_WIDTH, w);
						mrparam_set_int(msg->m_param, MRP_HEIGHT, h);
					}
				}
				free(buf);
			}

			mrmailbox_log_info(mailbox, 0, "Attaching \"%s\" for message type #%i.", pathNfilename, (int)msg->m_type);

			if( msg->m_text ) { free(msg->m_text); }
			if( msg->m_type == MR_MSG_AUDIO ) {
				char* filename = mr_get_filename(pathNfilename);
				char* author = mrparam_get(msg->m_param, MRP_AUTHORNAME, "");
				char* title = mrparam_get(msg->m_param, MRP_TRACKNAME, "");
				msg->m_text = mr_mprintf("%s %s %s", filename, author, title); /* for outgoing messages, also add the mediainfo. For incoming messages, this is not needed as the filename is build from these information */
				free(filename);
				free(author);
				free(title);
			}
			else if( MR_MSG_MAKE_FILENAME_SEARCHABLE(msg->m_type) ) {
				msg->m_text = mr_get_filename(pathNfilename);
			}
			else if( MR_MSG_MAKE_SUFFIX_SEARCHABLE(msg->m_type) ) {
				msg->m_text = mr_get_filesuffix_lc(pathNfilename);
			}
		}
		else
		{
			mrmailbox_log_error(mailbox, 0, "Attachment missing for message of type #%i.", (int)msg->m_type); /* should not happen */
			goto cleanup;
		}
	}
	else
	{
		mrmailbox_log_error(mailbox, 0, "Cannot send messages of type #%i.", (int)msg->m_type); /* should not happen */
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	mrsqlite3_begin_transaction__(mailbox->m_sql);

		mrmailbox_unarchive_chat__(mailbox, chat_id);

		mailbox->m_smtp->m_log_connect_errors = 1;

		{
			mrchat_t* chat = mrchat_new(mailbox);
			if( mrchat_load_from_db__(chat, chat_id) ) {
				msg->m_id = mrmailbox_send_msg_i__(mailbox, chat, msg, mr_create_smeared_timestamp__());
			}
			mrchat_unref(chat);
		}

	mrsqlite3_commit__(mailbox->m_sql);
	mrsqlite3_unlock(mailbox->m_sql);

	mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, chat_id, msg->m_id);

cleanup:
	free(pathNfilename);
	return msg->m_id;
}


/*******************************************************************************
 * Handle Group Chats
 ******************************************************************************/


int mrmailbox_group_explicitly_left__(mrmailbox_t* mailbox, const char* grpid)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_FROM_leftgrps_WHERE_grpid, "SELECT id FROM leftgrps WHERE grpid=?;");
	sqlite3_bind_text (stmt, 1, grpid, -1, SQLITE_STATIC);
	return (sqlite3_step(stmt)==SQLITE_ROW);
}


void mrmailbox_set_group_explicitly_left__(mrmailbox_t* mailbox, const char* grpid)
{
	if( !mrmailbox_group_explicitly_left__(mailbox, grpid) )
	{
		sqlite3_stmt* stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "INSERT INTO leftgrps (grpid) VALUES(?);");
		sqlite3_bind_text (stmt, 1, grpid, -1, SQLITE_STATIC);
		sqlite3_step(stmt);
		sqlite3_finalize(stmt);
	}
}


static int mrmailbox_real_group_exists__(mrmailbox_t* mailbox, uint32_t chat_id)
{
	sqlite3_stmt* stmt;
	int           ret = 0;

	if( mailbox == NULL || mailbox->m_sql->m_cobj==NULL
	 || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		return 0;
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_chats_WHERE_id,
		"SELECT id FROM chats WHERE id=? AND type=?;");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, MR_CHAT_TYPE_GROUP);

	if( sqlite3_step(stmt) == SQLITE_ROW ) {
		ret = 1;
	}

	return ret;
}


int mrmailbox_add_contact_to_chat__(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t contact_id)
{
	/* add a contact to a chat; the function does not check the type or if any of the record exist or are already added to the chat! */
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, INSERT_INTO_chats_contacts,
		"INSERT INTO chats_contacts (chat_id, contact_id) VALUES(?, ?)");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, contact_id);
	return (sqlite3_step(stmt)==SQLITE_DONE)? 1 : 0;
}


/**
 * Create a new group chat.
 *
 * After creation, the groups has one member with the
 * ID [MR_CONTACT_ID_SELF](@ref mrcontact_t::m_id) and is in _unpromoted_ state.  This means, you can
 * add or remove members, change the name, the group image and so on without
 * messages being send to all group members.
 *
 * This changes as soon as the first message is sent to the group members and
 * the group becomes _promoted_.  After that, all changes are synced with all
 * group members by sending status message.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 *
 * @param chat_name The name of the group chat to create.
 *     The name may be changed later using mrmailbox_set_chat_name().
 *     To find out the name of a group later, see mrchat_t::m_name
 *
 * @return The chat ID of the new group chat, 0 on errors.
 */
uint32_t mrmailbox_create_group_chat(mrmailbox_t* mailbox, const char* chat_name)
{
	uint32_t      chat_id = 0;
	int           locked = 0;
	char*         draft_txt = NULL, *grpid = NULL;
	sqlite3_stmt* stmt = NULL;

	if( mailbox == NULL || chat_name==NULL || chat_name[0]==0 ) {
		return 0;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		draft_txt = mrstock_str_repl_string(MR_STR_NEWGROUPDRAFT, chat_name);
		grpid = mr_create_id();

		stmt = mrsqlite3_prepare_v2_(mailbox->m_sql,
			"INSERT INTO chats (type, name, draft_timestamp, draft_txt, grpid, param) VALUES(?, ?, ?, ?, ?, 'U=1');" /*U=MRP_UNPROMOTED*/ );
		sqlite3_bind_int  (stmt, 1, MR_CHAT_TYPE_GROUP);
		sqlite3_bind_text (stmt, 2, chat_name, -1, SQLITE_STATIC);
		sqlite3_bind_int64(stmt, 3, time(NULL));
		sqlite3_bind_text (stmt, 4, draft_txt, -1, SQLITE_STATIC);
		sqlite3_bind_text (stmt, 5, grpid, -1, SQLITE_STATIC);
		if(  sqlite3_step(stmt)!=SQLITE_DONE ) {
			goto cleanup;
		}

		if( (chat_id=sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj)) == 0 ) {
			goto cleanup;
		}

		if( mrmailbox_add_contact_to_chat__(mailbox, chat_id, MR_CONTACT_ID_SELF) ) {
			goto cleanup;
		}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( stmt) { sqlite3_finalize(stmt); }
	free(draft_txt);
	free(grpid);

	if( chat_id ) {
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0);
	}

	return chat_id;
}


/**
 * Set group name.
 *
 * If the group is already _promoted_ (any message was sent to the group),
 * all group members are informed by a special message that is sent automatically by this function.
 *
 * @memberof mrmailbox_t
 *
 * @param chat_id The chat ID to set the name for.  Must be a group chat.
 *
 * @param new_name New name of the group.
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 *
 * @return 1=success, 0=error
 */
int mrmailbox_set_chat_name(mrmailbox_t* mailbox, uint32_t chat_id, const char* new_name)
{
	/* the function only sets the names of group chats; normal chats get their names from the contacts */
	int       success = 0, locked = 0;
	mrchat_t* chat = mrchat_new(mailbox);
	mrmsg_t*  msg = mrmsg_new();
	char*     q3 = NULL;

	if( mailbox==NULL || new_name==NULL || new_name[0]==0 ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( 0==mrmailbox_real_group_exists__(mailbox, chat_id)
		 || 0==mrchat_load_from_db__(chat, chat_id) ) {
			goto cleanup;
		}

		if( strcmp(chat->m_name, new_name)==0 ) {
			success = 1;
			goto cleanup; /* name not modified */
		}

		if( !IS_SELF_IN_GROUP__ ) {
			mrmailbox_log_error(mailbox, MR_ERR_SELF_NOT_IN_GROUP, NULL);
			goto cleanup; /* we shoud respect this - whatever we send to the group, it gets discarded anyway! */
		}

		q3 = sqlite3_mprintf("UPDATE chats SET name=%Q WHERE id=%i;", new_name, chat_id);
		if( !mrsqlite3_execute__(mailbox->m_sql, q3) ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* send a status mail to all group members, also needed for outself to allow multi-client */
	if( DO_SEND_STATUS_MAILS )
	{
		msg->m_type = MR_MSG_TEXT;
		msg->m_text = mrstock_str_repl_string2(MR_STR_MSGGRPNAME, chat->m_name, new_name);
		mrparam_set_int(msg->m_param, MRP_SYSTEM_CMD, MR_SYSTEM_GROUPNAME_CHANGED);
		msg->m_id = mrmailbox_send_msg(mailbox, chat->m_id, msg);
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, chat_id, msg->m_id);
	}
	mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, chat_id, 0);

	success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( q3 ) { sqlite3_free(q3); }
	mrchat_unref(chat);
	mrmsg_unref(msg);
	return success;
}


/**
 * Set group image.
 *
 * If the group is already _promoted_ (any message was sent to the group),
 * all group members are informed by a special message that is sent automatically by this function.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 *
 * @param chat_id The chat ID to set the image for.
 *
 * @param new_image Full path of the image to use as the group image.  If you pass NULL here,
 *     the group image is deleted (for promoted groups, all members are informed about this change anyway).
 *
 * @return 1=success, 0=error
 */
int mrmailbox_set_chat_image(mrmailbox_t* mailbox, uint32_t chat_id, const char* new_image /*NULL=remove image*/)
{
	int       success = 0, locked = 0;;
	mrchat_t* chat = mrchat_new(mailbox);
	mrmsg_t*  msg = mrmsg_new();

	if( mailbox==NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( 0==mrmailbox_real_group_exists__(mailbox, chat_id)
		 || 0==mrchat_load_from_db__(chat, chat_id) ) {
			goto cleanup;
		}

		if( !IS_SELF_IN_GROUP__ ) {
			mrmailbox_log_error(mailbox, MR_ERR_SELF_NOT_IN_GROUP, NULL);
			goto cleanup; /* we shoud respect this - whatever we send to the group, it gets discarded anyway! */
		}

		mrparam_set(chat->m_param, MRP_PROFILE_IMAGE, new_image/*may be NULL*/);
		if( !mrchat_update_param__(chat) ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* send a status mail to all group members, also needed for outself to allow multi-client */
	if( DO_SEND_STATUS_MAILS )
	{
		mrparam_set_int(msg->m_param, MRP_SYSTEM_CMD,       MR_SYSTEM_GROUPIMAGE_CHANGED);
		mrparam_set    (msg->m_param, MRP_SYSTEM_CMD_PARAM, new_image);
		msg->m_type = MR_MSG_TEXT;
		msg->m_text = mrstock_str(new_image? MR_STR_MSGGRPIMGCHANGED : MR_STR_MSGGRPIMGDELETED);
		msg->m_id = mrmailbox_send_msg(mailbox, chat->m_id, msg);
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, chat_id, msg->m_id);
	}
	mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, chat_id, 0);

	success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrchat_unref(chat);
	mrmsg_unref(msg);
	return success;
}


int mrmailbox_get_chat_contact_count__(mrmailbox_t* mailbox, uint32_t chat_id)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_chats_contacts_WHERE_chat_id,
		"SELECT COUNT(*) FROM chats_contacts WHERE chat_id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);
	if( sqlite3_step(stmt) == SQLITE_ROW ) {
		return sqlite3_column_int(stmt, 0);
	}
	return 0;
}


int mrmailbox_is_contact_in_chat__(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t contact_id)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_void_FROM_chats_contacts_WHERE_chat_id_AND_contact_id,
		"SELECT contact_id FROM chats_contacts WHERE chat_id=? AND contact_id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, contact_id);
	return (sqlite3_step(stmt) == SQLITE_ROW)? 1 : 0;
}


/**
 * Check if a given contact ID is a member of a group chat.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 *
 * @param chat_id The chat ID to check.
 *
 * @param contact_id The contact ID to check.  To check if yourself is member
 *     of the chat, pass MR_CONTACT_ID_SELF (1) here.
 *
 * @return 1=contact ID is member of chat ID, 0=contact is not in chat
 */
int mrmailbox_is_contact_in_chat(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t contact_id)
{
	/* this function works for group and for normal chats, however, it is more useful for group chats.
	MR_CONTACT_ID_SELF may be used to check, if the user itself is in a group chat (MR_CONTACT_ID_SELF is not added to normal chats) */
	int ret = 0;
	if( mailbox ) {
		mrsqlite3_lock(mailbox->m_sql);
			ret = mrmailbox_is_contact_in_chat__(mailbox, chat_id, contact_id);
		mrsqlite3_unlock(mailbox->m_sql);
	}
	return ret;
}


/**
 * Add a member to a group.
 *
 * If the group is already _promoted_ (any message was sent to the group),
 * all group members are informed by a special message that is sent automatically by this function.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 *
 * @param chat_id The chat ID to add the contact to.  Must be a group chat.
 *
 * @param contact_id The contact ID to add to the chat.
 *
 * @return 1=member added to group, 0=error
 */
int mrmailbox_add_contact_to_chat(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t contact_id /*may be MR_CONTACT_ID_SELF*/)
{
	int          success = 0, locked = 0;
	mrcontact_t* contact = mrmailbox_get_contact(mailbox, contact_id); /* mrcontact_load_from_db__() does not load SELF fields */
	mrchat_t*    chat = mrchat_new(mailbox);
	mrmsg_t*     msg = mrmsg_new();
	char*        self_addr = NULL;

	if( mailbox == NULL || contact == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( 0==mrmailbox_real_group_exists__(mailbox, chat_id) /*this also makes sure, not contacts are added to special or normal chats*/
		 || (0==mrmailbox_real_contact_exists__(mailbox, contact_id) && contact_id!=MR_CONTACT_ID_SELF)
		 || 0==mrchat_load_from_db__(chat, chat_id) ) {
			goto cleanup;
		}

		if( !IS_SELF_IN_GROUP__ ) {
			mrmailbox_log_error(mailbox, MR_ERR_SELF_NOT_IN_GROUP, NULL);
			goto cleanup; /* we shoud respect this - whatever we send to the group, it gets discarded anyway! */
		}

		self_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", "");
		if( strcasecmp(contact->m_addr, self_addr)==0 ) {
			goto cleanup; /* ourself is added using MR_CONTACT_ID_SELF, do not add it explicitly. if SELF is not in the group, members cannot be added at all. */
		}

		if( 1==mrmailbox_is_contact_in_chat__(mailbox, chat_id, contact_id) ) {
			success = 1;
			goto cleanup;
		}

		if( 0==mrmailbox_add_contact_to_chat__(mailbox, chat_id, contact_id) ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* send a status mail to all group members */
	if( DO_SEND_STATUS_MAILS )
	{
		msg->m_type = MR_MSG_TEXT;
		msg->m_text = mrstock_str_repl_string(MR_STR_MSGADDMEMBER, (contact->m_authname&&contact->m_authname[0])? contact->m_authname : contact->m_addr);
		mrparam_set_int(msg->m_param, MRP_SYSTEM_CMD, MR_SYSTEM_MEMBER_ADDED_TO_GROUP);
		mrparam_set    (msg->m_param, MRP_SYSTEM_CMD_PARAM, contact->m_addr);
		msg->m_id = mrmailbox_send_msg(mailbox, chat->m_id, msg);
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, chat_id, msg->m_id);
	}
	mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, chat_id, 0);

	success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrchat_unref(chat);
	mrcontact_unref(contact);
	mrmsg_unref(msg);
	free(self_addr);
	return success;
}


/**
 * Remove a member from a group.
 *
 * If the group is already _promoted_ (any message was sent to the group),
 * all group members are informed by a special message that is sent automatically by this function.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 *
 * @param chat_id The chat ID to remove the contact from.  Must be a group chat.
 *
 * @param contact_id The contact ID to remove from the chat.
 *
 * @return 1=member removed from group, 0=error
 */
int mrmailbox_remove_contact_from_chat(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t contact_id /*may be MR_CONTACT_ID_SELF*/)
{
	int          success = 0, locked = 0;
	mrcontact_t* contact = mrmailbox_get_contact(mailbox, contact_id); /* mrcontact_load_from_db__() does not load SELF fields */
	mrchat_t*    chat = mrchat_new(mailbox);
	mrmsg_t*     msg = mrmsg_new();
	char*        q3 = NULL;

	if( mailbox == NULL || (contact_id<=MR_CONTACT_ID_LAST_SPECIAL && contact_id!=MR_CONTACT_ID_SELF) ) {
		goto cleanup; /* we do not check if "contact_id" exists but just delete all records with the id from chats_contacts */
	}                 /* this allows to delete pending references to deleted contacts.  Of course, this should _not_ happen. */

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( 0==mrmailbox_real_group_exists__(mailbox, chat_id)
		 || 0==mrchat_load_from_db__(chat, chat_id) ) {
			goto cleanup;
		}

		if( !IS_SELF_IN_GROUP__ ) {
			mrmailbox_log_error(mailbox, MR_ERR_SELF_NOT_IN_GROUP, NULL);
			goto cleanup; /* we shoud respect this - whatever we send to the group, it gets discarded anyway! */
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* send a status mail to all group members - we need to do this before we update the database -
	otherwise the !IS_SELF_IN_GROUP__-check in mrchat_send_msg() will fail. */
	if( contact )
	{
		if( DO_SEND_STATUS_MAILS )
		{
			msg->m_type = MR_MSG_TEXT;
			if( contact->m_id == MR_CONTACT_ID_SELF ) {
				mrmailbox_set_group_explicitly_left__(mailbox, chat->m_grpid);
				msg->m_text = mrstock_str(MR_STR_MSGGROUPLEFT);
			}
			else {
				msg->m_text = mrstock_str_repl_string(MR_STR_MSGDELMEMBER, (contact->m_authname&&contact->m_authname[0])? contact->m_authname : contact->m_addr);
			}
			mrparam_set_int(msg->m_param, MRP_SYSTEM_CMD, MR_SYSTEM_MEMBER_REMOVED_FROM_GROUP);
			mrparam_set    (msg->m_param, MRP_SYSTEM_CMD_PARAM, contact->m_addr);
			msg->m_id = mrmailbox_send_msg(mailbox, chat->m_id, msg);
			mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, chat_id, msg->m_id);
		}
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		q3 = sqlite3_mprintf("DELETE FROM chats_contacts WHERE chat_id=%i AND contact_id=%i;", chat_id, contact_id);
		if( !mrsqlite3_execute__(mailbox->m_sql, q3) ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, chat_id, 0);

	success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( q3 ) { sqlite3_free(q3); }
	mrchat_unref(chat);
	mrcontact_unref(contact);
	mrmsg_unref(msg);
	return success;
}



/*******************************************************************************
 * Handle Contacts
 ******************************************************************************/


int mrmailbox_real_contact_exists__(mrmailbox_t* mailbox, uint32_t contact_id)
{
	sqlite3_stmt* stmt;
	int           ret = 0;

	if( mailbox == NULL || mailbox->m_sql->m_cobj==NULL
	 || contact_id <= MR_CONTACT_ID_LAST_SPECIAL ) {
		return 0;
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_WHERE_id,
		"SELECT id FROM contacts WHERE id=?;");
	sqlite3_bind_int(stmt, 1, contact_id);

	if( sqlite3_step(stmt) == SQLITE_ROW ) {
		ret = 1;
	}

	return ret;
}


size_t mrmailbox_get_real_contact_cnt__(mrmailbox_t* mailbox)
{
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_sql->m_cobj==NULL ) {
		return 0;
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_contacts, "SELECT COUNT(*) FROM contacts WHERE id>?;");
	sqlite3_bind_int(stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


uint32_t mrmailbox_add_or_lookup_contact__( mrmailbox_t* mailbox,
                                           const char*  name /*can be NULL, the caller may use mr_normalize_name() before*/,
                                           const char*  addr__,
                                           int          origin,
                                           int*         sth_modified )
{
	sqlite3_stmt* stmt;
	uint32_t      row_id = 0;
	int           dummy;
	char*         addr = NULL;

	if( sth_modified == NULL ) {
		sth_modified = &dummy;
	}

	*sth_modified = 0;

	if( mailbox == NULL || addr__ == NULL || origin <= 0 ) {
		return 0;
	}

	/* normalize the email-address:
	- remove leading `mailto:` */
	addr = mr_normalize_addr(addr__);

	/* rough check if email-address is valid */
	if( strlen(addr) < 3 || strchr(addr, '@')==NULL || strchr(addr, '.')==NULL ) {
		mrmailbox_log_warning(mailbox, 0, "Bad address \"%s\" for contact \"%s\".", addr, name?name:"<unset>");
		goto cleanup;
	}

	/* insert email-address to database or modify the record with the given email-address.
	we treat all email-addresses case-insensitive. */
	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_inao_FROM_contacts_a,
		"SELECT id, name, addr, origin, authname FROM contacts WHERE addr=? COLLATE NOCASE;");
	sqlite3_bind_text(stmt, 1, (const char*)addr, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) == SQLITE_ROW )
	{
		const char  *row_name, *row_addr, *row_authname;
		int         row_origin, update_addr = 0, update_name = 0, update_authname = 0;

		row_id       = sqlite3_column_int(stmt, 0);
		row_name     = (const char*)sqlite3_column_text(stmt, 1); if( row_name == NULL ) { row_name = ""; }
		row_addr     = (const char*)sqlite3_column_text(stmt, 2); if( row_addr == NULL ) { row_addr = addr; }
		row_origin   = sqlite3_column_int(stmt, 3);
		row_authname = (const char*)sqlite3_column_text(stmt, 4); if( row_authname == NULL ) { row_authname = ""; }

		if( name && name[0] ) {
			if( row_name && row_name[0] ) {
				if( origin>=row_origin && strcmp(name, row_name)!=0 ) {
					update_name = 1;
				}
			}
			else {
				update_name = 1;
			}

			if( origin == MR_ORIGIN_INCOMING_UNKNOWN_FROM && strcmp(name, row_authname)!=0 ) {
				update_authname = 1;
			}
		}

		if( origin>=row_origin && strcmp(addr, row_addr)!=0 /*really compare case-sensitive here*/ ) {
			update_addr = 1;
		}

		if( update_name || update_authname || update_addr || origin>row_origin )
		{
			stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_contacts_nao_WHERE_i,
				"UPDATE contacts SET name=?, addr=?, origin=?, authname=? WHERE id=?;");
			sqlite3_bind_text(stmt, 1, update_name?       name   : row_name, -1, SQLITE_STATIC);
			sqlite3_bind_text(stmt, 2, update_addr?       addr   : row_addr, -1, SQLITE_STATIC);
			sqlite3_bind_int (stmt, 3, origin>row_origin? origin : row_origin);
			sqlite3_bind_text(stmt, 4, update_authname?   name   : row_authname, -1, SQLITE_STATIC);
			sqlite3_bind_int (stmt, 5, row_id);
			sqlite3_step     (stmt);

			if( update_name )
			{
				/* Update the contact name also if it is used as a group name.
				This is one of the few duplicated data, however, getting the chat list is much faster this way.*/
				stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_chats_SET_n_WHERE_c,
					"UPDATE chats SET name=? WHERE type=? AND id IN(SELECT chat_id FROM chats_contacts WHERE contact_id=?);");
				sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
				sqlite3_bind_int (stmt, 2, MR_CHAT_TYPE_NORMAL);
				sqlite3_bind_int (stmt, 3, row_id);
				sqlite3_step     (stmt);
			}
		}

		*sth_modified = 1;
	}
	else
	{
		stmt = mrsqlite3_predefine__(mailbox->m_sql, INSERT_INTO_contacts_neo,
			"INSERT INTO contacts (name, addr, origin) VALUES(?, ?, ?);");
		sqlite3_bind_text(stmt, 1, name? name : "", -1, SQLITE_STATIC); /* avoid NULL-fields in column */
		sqlite3_bind_text(stmt, 2, addr,    -1, SQLITE_STATIC);
		sqlite3_bind_int (stmt, 3, origin);
		if( sqlite3_step(stmt) == SQLITE_DONE )
		{
			row_id = sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj);
			*sth_modified = 1;
		}
		else
		{
			mrmailbox_log_error(mailbox, 0, "Cannot add contact."); /* should not happen */
		}
	}

cleanup:
	free(addr);
	return row_id;
}


void mrmailbox_scaleup_contact_origin__(mrmailbox_t* mailbox, uint32_t contact_id, int origin)
{
	if( mailbox == NULL ) {
		return;
	}

	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_contacts_SET_origin_WHERE_id,
		"UPDATE contacts SET origin=? WHERE id=? AND origin<?;");
	sqlite3_bind_int(stmt, 1, origin);
	sqlite3_bind_int(stmt, 2, contact_id);
	sqlite3_bind_int(stmt, 3, origin);
	sqlite3_step(stmt);
}


int mrmailbox_is_contact_blocked__(mrmailbox_t* mailbox, uint32_t contact_id)
{
	int          is_blocked = 0;
	mrcontact_t* ths = mrcontact_new();

	if( mrcontact_load_from_db__(ths, mailbox->m_sql, contact_id) ) { /* we could optimize this by loading only the needed fields */
		if( ths->m_blocked ) {
			is_blocked = 1;
		}
	}

	mrcontact_unref(ths);
	return is_blocked;
}


int mrmailbox_get_contact_origin__(mrmailbox_t* mailbox, uint32_t contact_id, int* ret_blocked)
{
	int          ret = MR_ORIGIN_UNSET;
	int          dummy; if( ret_blocked==NULL ) { ret_blocked = &dummy; }
	mrcontact_t* ths = mrcontact_new();

	*ret_blocked = 0;

	if( !mrcontact_load_from_db__(ths, mailbox->m_sql, contact_id) ) { /* we could optimize this by loading only the needed fields */
		goto cleanup;
	}

	if( ths->m_blocked ) {
		*ret_blocked = 1;
		goto cleanup;
	}

	ret = ths->m_origin;

cleanup:
	mrcontact_unref(ths);
	return ret;
}


/**
 * Add a single contact. and return the ID.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @param name Name of the contact to add.
 *
 * @param addr E-mail-address of the contact to add. If the email address
 *     already exists, the name is updated and the origin is increased to
 *     "manually created".
 *
 * @return Contact ID of the created or reused contact.
 */
uint32_t mrmailbox_create_contact(mrmailbox_t* mailbox, const char* name, const char* addr)
{
	uint32_t contact_id = 0;

	if( mailbox == NULL || addr == NULL || addr[0]==0 ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);

		contact_id = mrmailbox_add_or_lookup_contact__(mailbox, name, addr, MR_ORIGIN_MANUALLY_CREATED, NULL);

	mrsqlite3_unlock(mailbox->m_sql);

	mailbox->m_cb(mailbox, MR_EVENT_CONTACTS_CHANGED, 0, 0);

cleanup:
	return contact_id;
}


/**
 * Add a number of contacts. The contacts must be added as
 *
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new().
 *
 * @param adr_book A multi-line string in the format in the format
 *     `Name one\nAddress one\nName two\Address two`.  If an email address
 *      already exists, the name is updated and the origin is increased to
 *      "manually created".
 *
 * @return The number of modified or added contacts.
 */
int mrmailbox_add_address_book(mrmailbox_t* mailbox, const char* adr_book) /* format: Name one\nAddress one\nName two\Address two */
{
	carray* lines = NULL;
	size_t  i, iCnt;
	int     sth_modified, modify_cnt = 0;

	if( mailbox == NULL || adr_book == NULL ) {
		goto cleanup;
	}

	if( (lines=mr_split_into_lines(adr_book))==NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);

		mrsqlite3_begin_transaction__(mailbox->m_sql);

		iCnt = carray_count(lines);
		for( i = 0; i+1 < iCnt; i += 2 ) {
			char* name = (char*)carray_get(lines, i);
			char* addr = (char*)carray_get(lines, i+1);
			mrcontact_normalize_name(name);
			mrmailbox_add_or_lookup_contact__(mailbox, name, addr, MR_ORIGIN_ADRESS_BOOK, &sth_modified);
			if( sth_modified ) {
				modify_cnt++;
			}
		}

		mrsqlite3_commit__(mailbox->m_sql);

	mrsqlite3_unlock(mailbox->m_sql);

cleanup:
	mr_free_splitted_lines(lines);

	return modify_cnt;
}


/**
 * Returns known and unblocked contacts.
 *
 * To get information about a single contact, see mrmailbox_get_contact().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @param query A string to filter the list.  Typically used to implement an
 *     incremental search.  NULL for no filtering.
 *
 * @return An array containing all contact IDs.  Must be carray_free()'d
 *     after usage.
 */
carray* mrmailbox_get_known_contacts(mrmailbox_t* mailbox, const char* query)
{
	int           locked = 0;
	carray*       ret = carray_new(100);
	char*         s3strLikeCmd = NULL;
	sqlite3_stmt* stmt;

	if( mailbox == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( query ) {
			if( (s3strLikeCmd=sqlite3_mprintf("%%%s%%", query))==NULL ) {
				goto cleanup;
			}
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_WHERE_query_ORDER_BY,
				"SELECT id FROM contacts"
					" WHERE id>? AND origin>=? AND blocked=0 AND (name LIKE ? OR addr LIKE ?)" /* see comments in mrmailbox_search_msgs() about the LIKE operator */
					" ORDER BY LOWER(name||addr),id;");
			sqlite3_bind_int (stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
			sqlite3_bind_int (stmt, 2, MR_ORIGIN_MIN_CONTACT_LIST);
			sqlite3_bind_text(stmt, 3, s3strLikeCmd, -1, SQLITE_STATIC);
			sqlite3_bind_text(stmt, 4, s3strLikeCmd, -1, SQLITE_STATIC);
		}
		else {
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_ORDER_BY,
				"SELECT id FROM contacts"
					" WHERE id>? AND origin>=? AND blocked=0"
					" ORDER BY LOWER(name||addr),id;");
			sqlite3_bind_int(stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
			sqlite3_bind_int(stmt, 2, MR_ORIGIN_MIN_CONTACT_LIST);
		}

		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			carray_add(ret, (void*)(uintptr_t)sqlite3_column_int(stmt, 0), NULL);
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

cleanup:
	if( locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}
	if( s3strLikeCmd ) {
		sqlite3_free(s3strLikeCmd);
	}
	return ret;
}


/**
 * Get blocked contacts.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @return An array containing all blocked contact IDs.  Must be carray_free()'d
 *     after usage.
 */
carray* mrmailbox_get_blocked_contacts(mrmailbox_t* mailbox)
{
	carray*       ret = carray_new(100);
	sqlite3_stmt* stmt;

	if( mailbox == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_WHERE_blocked,
			"SELECT id FROM contacts"
				" WHERE id>? AND blocked!=0"
				" ORDER BY LOWER(name||addr),id;");
		sqlite3_bind_int(stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			carray_add(ret, (void*)(uintptr_t)sqlite3_column_int(stmt, 0), NULL);
		}

	mrsqlite3_unlock(mailbox->m_sql);

cleanup:
	return ret;
}


/**
 * Get the number of blocked contacts.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 */
int mrmailbox_get_blocked_count(mrmailbox_t* mailbox)
{
	int           ret = 0, locked = 0;
	sqlite3_stmt* stmt;

	if( mailbox == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_contacts_WHERE_blocked,
			"SELECT COUNT(*) FROM contacts"
				" WHERE id>? AND blocked!=0");
		sqlite3_bind_int(stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
		if( sqlite3_step(stmt) != SQLITE_ROW ) {
			goto cleanup;
		}
		ret = sqlite3_column_int(stmt, 0);

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	return ret;
}


/**
 * Get a single contact object.  For a list, see eg. mrmailbox_get_known_contacts().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @param contact_id ID of the contact to get the object for.
 *
 * @return The contact object, must be freed using mrcontact_unref() when no
 *     longer used.  NULL on errors.
 */
mrcontact_t* mrmailbox_get_contact(mrmailbox_t* mailbox, uint32_t contact_id)
{
	mrcontact_t* ret = mrcontact_new();

	mrsqlite3_lock(mailbox->m_sql);

		if( contact_id == MR_CONTACT_ID_SELF )
		{
			ret->m_id   = contact_id;
			ret->m_name = mrstock_str(MR_STR_SELF);
			ret->m_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", NULL);
		}
		else
		{
			if( !mrcontact_load_from_db__(ret, mailbox->m_sql, contact_id) ) {
				mrcontact_unref(ret);
				ret = NULL;
			}
		}

	mrsqlite3_unlock(mailbox->m_sql);

	return ret; /* may be NULL */
}


static void marknoticed_contact__(mrmailbox_t* mailbox, uint32_t contact_id)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_state_WHERE_from_id_AND_state,
		"UPDATE msgs SET state=" MR_STRINGIFY(MR_STATE_IN_NOTICED) " WHERE from_id=? AND state=" MR_STRINGIFY(MR_STATE_IN_FRESH) ";");
	sqlite3_bind_int(stmt, 1, contact_id);
	sqlite3_step(stmt);
}


/**
 * Mark all messages send by the given contact
 * as _noticed_.  See also mrmailbox_marknoticed_chat() and
 * mrmailbox_markseen_msgs()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmmailbox_new()
 *
 * @param contact_id The contact ID of which all messages should be marked as noticed.
 *
 * @return none
 */
void mrmailbox_marknoticed_contact(mrmailbox_t* mailbox, uint32_t contact_id)
{
    if( mailbox == NULL ) {
		return;
    }
    mrsqlite3_lock(mailbox->m_sql);
		marknoticed_contact__(mailbox, contact_id);
    mrsqlite3_unlock(mailbox->m_sql);
}


/**
 * Block or unblock a contact.
 *
 * May result in a MR_EVENT_BLOCKING_CHANGED event.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @param contact_id The ID of the contact to block or unblock.
 *
 * @param new_blocking 1=block contact, 0=unblock contact
 *
 * @return None.
 */
void mrmailbox_block_contact(mrmailbox_t* mailbox, uint32_t contact_id, int new_blocking)
{
	int locked = 0, send_event = 0, transaction_pending = 0;
	mrcontact_t*  contact = mrcontact_new();
	sqlite3_stmt* stmt;

	if( mailbox == NULL ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id)
		 && contact->m_blocked != new_blocking )
		{
			mrsqlite3_begin_transaction__(mailbox->m_sql);
			transaction_pending = 1;

				stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_contacts_SET_b_WHERE_i,
					"UPDATE contacts SET blocked=? WHERE id=?;");
				sqlite3_bind_int(stmt, 1, new_blocking);
				sqlite3_bind_int(stmt, 2, contact_id);
				if( sqlite3_step(stmt)!=SQLITE_DONE ) {
					goto cleanup;
				}

				/* also (un)block all chats with _only_ this contact - we do not delete them to allow a non-destructive blocking->unblocking.
				(Maybe, beside normal chats (type=100) we should also block group chats with only this user.
				However, I'm not sure about this point; it may be confusing if the user wants to add other people;
				this would result in recreating the same group...) */
				stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_chats_SET_blocked,
					"UPDATE chats SET blocked=? WHERE type=? AND id IN (SELECT chat_id FROM chats_contacts WHERE contact_id=?);");
				sqlite3_bind_int(stmt, 1, new_blocking);
				sqlite3_bind_int(stmt, 2, MR_CHAT_TYPE_NORMAL);
				sqlite3_bind_int(stmt, 3, contact_id);
				if( sqlite3_step(stmt)!=SQLITE_DONE ) {
					goto cleanup;
				}

				/* mark all messages from the blocked contact as being noticed (this is to remove the deaddrop popup) */
				marknoticed_contact__(mailbox, contact_id);

			mrsqlite3_commit__(mailbox->m_sql);
			transaction_pending = 0;

			send_event = 1;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	if( send_event ) {
		mailbox->m_cb(mailbox, MR_EVENT_CONTACTS_CHANGED, 0, 0);
	}

cleanup:
	if( transaction_pending ) {
		mrsqlite3_rollback__(mailbox->m_sql);
	}

	if( locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}

	mrcontact_unref(contact);
}


static void cat_fingerprint(mrstrbuilder_t* ret, const char* addr, const char* fingerprint_str)
{
	mrstrbuilder_cat(ret, addr);
	mrstrbuilder_cat(ret, ":\n");
	mrstrbuilder_cat(ret, fingerprint_str);
	mrstrbuilder_cat(ret, "\n\n");
}


/**
 * Get encryption info.
 * Get a multi-line encryption info, containing your fingerprint and the
 * fingerprint of the contact, used eg. to compare the fingerprints.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @param contact_id ID of the contact to get the encryption info for.
 *
 * @return multi-line text, must be free()'d after usage.
 */
char* mrmailbox_get_contact_encrinfo(mrmailbox_t* mailbox, uint32_t contact_id)
{
	int             locked = 0;
	int             e2ee_enabled = 0;
	int             explain_id = 0;
	mrloginparam_t* loginparam = mrloginparam_new();
	mrcontact_t*    contact = mrcontact_new();
	mrapeerstate_t* peerstate = mrapeerstate_new();
	int             peerstate_ok = 0;
	mrkey_t*        self_key = mrkey_new();
	char*           fingerprint_str_self = NULL;
	char*           fingerprint_str_other = NULL;
	char*           p;

	mrstrbuilder_t  ret;
	mrstrbuilder_init(&ret);

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( !mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id) ) {
			goto cleanup;
		}
		peerstate_ok = mrapeerstate_load_from_db__(peerstate, mailbox->m_sql, contact->m_addr);
		mrloginparam_read__(loginparam, mailbox->m_sql, "configured_");
		e2ee_enabled = mailbox->m_e2ee_enabled;

		mrkey_load_self_public__(self_key, loginparam->m_addr, mailbox->m_sql);

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* show the encryption that would be used for the next outgoing message */
	if( e2ee_enabled
	 && peerstate_ok
	 && peerstate->m_prefer_encrypt==MRA_PE_MUTUAL
	 && peerstate->m_public_key->m_binary!=NULL )
	{
		/* e2e fine and used */
		p = mrstock_str(MR_STR_ENCR_E2E); mrstrbuilder_cat(&ret, p); free(p);
		explain_id = MR_STR_E2E_FINE;
	}
	else
	{
		/* e2e not used ... first, show status quo ... */
		if( !(loginparam->m_server_flags&MR_IMAP_SOCKET_PLAIN)
		 && !(loginparam->m_server_flags&MR_SMTP_SOCKET_PLAIN) )
		{
			p = mrstock_str(MR_STR_ENCR_TRANSP); mrstrbuilder_cat(&ret, p); free(p);
		}
		else
		{
			p = mrstock_str(MR_STR_ENCR_NONE); mrstrbuilder_cat(&ret, p); free(p);
		}

		/* ... and then explain why we cannot use e2e */
		if( peerstate_ok && peerstate->m_public_key->m_binary!=NULL && peerstate->m_prefer_encrypt!=MRA_PE_MUTUAL ) {
			explain_id = MR_STR_E2E_DIS_BY_RCPT;
		}
		else if( !e2ee_enabled ) {
			explain_id = MR_STR_E2E_DIS_BY_YOU;
		}
		else {
			explain_id = MR_STR_E2E_NO_AUTOCRYPT;
		}
	}

	/* show fingerprints for comparison (sorted by email-address to make a device-side-by-side comparison easier) */
	if( peerstate_ok
	 && peerstate->m_public_key->m_binary!=NULL )
	{
		if( self_key->m_binary == NULL ) {
			mrpgp_rand_seed(mailbox, peerstate->m_addr, strlen(peerstate->m_addr) /*just some random data*/);
			mrmailbox_ensure_secret_key_exists(mailbox);
			mrsqlite3_lock(mailbox->m_sql);
			locked = 1;
				mrkey_load_self_public__(self_key, loginparam->m_addr, mailbox->m_sql);
			mrsqlite3_unlock(mailbox->m_sql);
			locked = 0;
		}

		mrstrbuilder_cat(&ret, " ");
		p = mrstock_str(MR_STR_FINGERPRINTS); mrstrbuilder_cat(&ret, p); free(p);
		mrstrbuilder_cat(&ret, ":\n\n");

		fingerprint_str_self = mrkey_render_fingerprint(self_key, mailbox);
		fingerprint_str_other = mrkey_render_fingerprint(peerstate->m_public_key, mailbox);

		if( strcmp(loginparam->m_addr, peerstate->m_addr)<0 ) {
			cat_fingerprint(&ret, loginparam->m_addr, fingerprint_str_self);
			cat_fingerprint(&ret, peerstate->m_addr, fingerprint_str_other);
		}
		else {
			cat_fingerprint(&ret, peerstate->m_addr, fingerprint_str_other);
			cat_fingerprint(&ret, loginparam->m_addr, fingerprint_str_self);
		}
	}
	else
	{
		mrstrbuilder_cat(&ret, "\n\n");
	}

	p = mrstock_str(explain_id); mrstrbuilder_cat(&ret, p); free(p);

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrapeerstate_unref(peerstate);
	mrcontact_unref(contact);
	mrloginparam_unref(loginparam);
	mrkey_unref(self_key);
	free(fingerprint_str_self);
	free(fingerprint_str_other);
	return ret.m_buf;
}


/**
 * Delete a contact.  The contact is deleted from the local device.  It may happen that this is not
 * possible as the contact is in used.  In this case, the contact can be blocked.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @param contact_id ID of the contact to delete.
 *
 * @return 1=success, 0=error
 */
int mrmailbox_delete_contact(mrmailbox_t* mailbox, uint32_t contact_id)
{
	int           locked = 0, success = 0;
	sqlite3_stmt* stmt;

	if( mailbox == NULL || contact_id <= MR_CONTACT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		/* we can only delete contacts that are not in use anywhere; this function is mainly for the user who has just
		created an contact manually and wants to delete it a moment later */
		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_chats_contacts_WHERE_contact_id,
			"SELECT COUNT(*) FROM chats_contacts WHERE contact_id=?;");
		sqlite3_bind_int(stmt, 1, contact_id);
		if( sqlite3_step(stmt) != SQLITE_ROW || sqlite3_column_int(stmt, 0) >= 1 ) {
			goto cleanup;
		}

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_ft,
			"SELECT COUNT(*) FROM msgs WHERE from_id=? OR to_id=?;");
		sqlite3_bind_int(stmt, 1, contact_id);
		sqlite3_bind_int(stmt, 2, contact_id);
		if( sqlite3_step(stmt) != SQLITE_ROW || sqlite3_column_int(stmt, 0) >= 1 ) {
			goto cleanup;
		}

		stmt = mrsqlite3_predefine__(mailbox->m_sql, DELETE_FROM_contacts_WHERE_id,
			"DELETE FROM contacts WHERE id=?;");
		sqlite3_bind_int(stmt, 1, contact_id);
		if( sqlite3_step(stmt) != SQLITE_DONE ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	mailbox->m_cb(mailbox, MR_EVENT_CONTACTS_CHANGED, 0, 0);

	success = 1;

cleanup:
	if( locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}
	return success;
}


int mrmailbox_contact_addr_equals__(mrmailbox_t* mailbox, uint32_t contact_id, const char* other_addr)
{
	int addr_are_equal = 0;
	if( other_addr ) {
		mrcontact_t* contact = mrcontact_new();
		if( mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id) ) {
			if( contact->m_addr ) {
				if( strcasecmp(contact->m_addr, other_addr)==0 ) {
					addr_are_equal = 1;
				}
			}
		}
		mrcontact_unref(contact);
	}
	return addr_are_equal;
}



/*******************************************************************************
 * Handle Messages
 ******************************************************************************/


void mrmailbox_update_msg_chat_id__(mrmailbox_t* mailbox, uint32_t msg_id, uint32_t chat_id)
{
    sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_chat_id_WHERE_id,
		"UPDATE msgs SET chat_id=? WHERE id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, msg_id);
	sqlite3_step(stmt);
}


void mrmailbox_update_msg_state__(mrmailbox_t* mailbox, uint32_t msg_id, int state)
{
    sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_state_WHERE_id,
		"UPDATE msgs SET state=? WHERE id=?;");
	sqlite3_bind_int(stmt, 1, state);
	sqlite3_bind_int(stmt, 2, msg_id);
	sqlite3_step(stmt);
}


size_t mrmailbox_get_real_msg_cnt__(mrmailbox_t* mailbox)
{
	if( mailbox->m_sql->m_cobj==NULL ) {
		return 0;
	}

	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_assigned,
		"SELECT COUNT(*) FROM msgs WHERE id>? AND chat_id>?;");
	sqlite3_bind_int(stmt, 1, MR_MSG_ID_LAST_SPECIAL);
	sqlite3_bind_int(stmt, 2, MR_CHAT_ID_LAST_SPECIAL);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		mrsqlite3_log_error(mailbox->m_sql, "mr_get_assigned_msg_cnt_() failed.");
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


size_t mrmailbox_get_deaddrop_msg_cnt__(mrmailbox_t* mailbox)
{
	if( mailbox==NULL || mailbox->m_sql->m_cobj==NULL ) {
		return 0;
	}

	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_unassigned,
		"SELECT COUNT(*) FROM msgs WHERE chat_id=?;");
	sqlite3_bind_int(stmt, 1, MR_CHAT_ID_DEADDROP);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


int mrmailbox_rfc724_mid_cnt__(mrmailbox_t* mailbox, const char* rfc724_mid)
{
	if( mailbox==NULL || mailbox->m_sql->m_cobj==NULL ) {
		return 0;
	}

	/* check the number of messages with the same rfc724_mid */
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_rfc724_mid,
		"SELECT COUNT(*) FROM msgs WHERE rfc724_mid=?;");
	sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


/* check, if the given Message-ID exists in the database (if not, the message is normally downloaded from the server and parsed,
so, we should even keep unuseful messages in the database (we can leave the other fields empty to safe space) */
int mrmailbox_rfc724_mid_exists__(mrmailbox_t* mailbox, const char* rfc724_mid, char** ret_server_folder, uint32_t* ret_server_uid)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_ss_FROM_msgs_WHERE_m,
		"SELECT server_folder, server_uid FROM msgs WHERE rfc724_mid=?;");
	sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		*ret_server_folder = NULL;
		*ret_server_uid = 0;
		return 0;
	}

	*ret_server_folder = safe_strdup((char*)sqlite3_column_text(stmt, 0));
	*ret_server_uid = sqlite3_column_int(stmt, 1); /* may be 0 */
	return 1;
}


void mrmailbox_update_server_uid__(mrmailbox_t* mailbox, const char* rfc724_mid, const char* server_folder, uint32_t server_uid)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_ss_WHERE_rfc724_mid,
		"UPDATE msgs SET server_folder=?, server_uid=? WHERE rfc724_mid=?;"); /* we update by "rfc724_mid" instead "id" as there may be several db-entries refering to the same "rfc724_mid" */
	sqlite3_bind_text(stmt, 1, server_folder, -1, SQLITE_STATIC);
	sqlite3_bind_int (stmt, 2, server_uid);
	sqlite3_bind_text(stmt, 3, rfc724_mid, -1, SQLITE_STATIC);
	sqlite3_step(stmt);
}


/**
 * Get a single message object of the type mrmsg_t.
 * For a list of messages in a chat, see mrmailbox_get_chat_msgs()
 * For a list or chats, see mrmailbox_get_chatlist()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new()
 *
 * @param msg_id The message ID for which the message object should be created.
 *
 * @return A mrmsg_t message object. When done, the object must be freed using mrmsg_unref()
 */
mrmsg_t* mrmailbox_get_msg(mrmailbox_t* mailbox, uint32_t msg_id)
{
	int success = 0;
	int db_locked = 0;
	mrmsg_t* obj = mrmsg_new();

	mrsqlite3_lock(mailbox->m_sql);
	db_locked = 1;

		if( !mrmsg_load_from_db__(obj, mailbox, msg_id) ) {
			goto cleanup;
		}

		success = 1;

cleanup:
	if( db_locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}

	if( success ) {
		return obj;
	}
	else {
		mrmsg_unref(obj);
		return NULL;
	}
}


/**
 * Get an informational text for a single message. the text is multiline and may
 * contain eg. the raw text of the message.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new().
 *
 * @param msg_id the message id for which information should be generated
 *
 * @return text string, must be free()'d after usage
 */
char* mrmailbox_get_msg_info(mrmailbox_t* mailbox, uint32_t msg_id)
{
	mrstrbuilder_t ret;
	int            locked = 0;
	sqlite3_stmt*  stmt;
	mrmsg_t*       msg = mrmsg_new();
	char           *rawtxt = NULL, *p;

	mrstrbuilder_init(&ret);

	if( mailbox == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		mrmsg_load_from_db__(msg, mailbox, msg_id);

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_txt_raw_FROM_msgs_WHERE_id,
			"SELECT txt_raw FROM msgs WHERE id=?;");
		sqlite3_bind_int(stmt, 1, msg_id);
		if( sqlite3_step(stmt) != SQLITE_ROW ) {
			p = mr_mprintf("Cannot load message #%i.", (int)msg_id); mrstrbuilder_cat(&ret, p); free(p);
			goto cleanup;
		}

		rawtxt = safe_strdup((char*)sqlite3_column_text(stmt, 0));

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* add time */
	mrstrbuilder_cat(&ret, "Date: ");
	p = mr_timestamp_to_str(msg->m_timestamp); mrstrbuilder_cat(&ret, p); free(p);
	mrstrbuilder_cat(&ret, "\n");

	/* add encryption state */
	int e2ee_errors;
	if( (e2ee_errors=mrparam_get_int(msg->m_param, MRP_ERRONEOUS_E2EE, 0)) ) {
		if( e2ee_errors&MR_VALIDATE_BAD_SIGNATURE/* check worst errors first */ ) {
			p = safe_strdup("End-to-end, bad signature");
		}
		else if( e2ee_errors&MR_VALIDATE_UNKNOWN_SIGNATURE ) {
			p = safe_strdup("End-to-end, unknown signature");
		}
		else if( e2ee_errors&MR_VALIDATE_NOT_MUTUAL ) {
			p = safe_strdup("End-to-end, not mutual");
		}
		else {
			p = safe_strdup("End-to-end, no signature");
		}
	}
	else if( mrparam_get_int(msg->m_param, MRP_GUARANTEE_E2EE, 0) ) {
		if( !msg->m_mailbox->m_e2ee_enabled ) {
			p = safe_strdup("End-to-end, transport for replies");
		}
		else {
			p = safe_strdup("End-to-end");
		}
	}
	else {
		p = safe_strdup("Transport");
	}
	mrstrbuilder_cat(&ret, "Encryption: ");
	mrstrbuilder_cat(&ret, p); free(p);
	mrstrbuilder_cat(&ret, "\n");

	/* add "suspicious" status */
	if( msg->m_state==MR_STATE_IN_FRESH ) {
		mrstrbuilder_cat(&ret, "Status: Fresh\n");
	}
	else if( msg->m_state==MR_STATE_IN_NOTICED ) {
		mrstrbuilder_cat(&ret, "Status: Noticed\n");
	}

	/* add file info */
	char* file = mrparam_get(msg->m_param, MRP_FILE, NULL);
	if( file ) {
		p = mr_mprintf("File: %s, %i bytes\n", file, mr_get_filebytes(file)); mrstrbuilder_cat(&ret, p); free(p);
	}

	if( msg->m_type != MR_MSG_TEXT ) {
		p = mr_mprintf("Type: %i\n", msg->m_type); mrstrbuilder_cat(&ret, p); free(p);
	}

	int w = mrparam_get_int(msg->m_param, MRP_WIDTH, 0), h = mrparam_get_int(msg->m_param, MRP_HEIGHT, 0);
	if( w != 0 || h != 0 ) {
		p = mr_mprintf("Dimension: %i x %i\n", w, h); mrstrbuilder_cat(&ret, p); free(p);
	}

	int duration = mrparam_get_int(msg->m_param, MRP_DURATION, 0);
	if( duration != 0 ) {
		p = mr_mprintf("Duration: %i ms\n", duration); mrstrbuilder_cat(&ret, p); free(p);
	}

	/* add rawtext */
	if( rawtxt && rawtxt[0] ) {
		mrstrbuilder_cat(&ret, "\n");
		mrstrbuilder_cat(&ret, rawtxt);
	}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrmsg_unref(msg);
	free(rawtxt);
	return ret.m_buf;
}


/**
 * Forward a list of messages to another chat.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new()
 *
 * @param msg_ids an array of uint32_t containing all message IDs that should be forwarded
 *
 * @param msg_cnt the number of messages IDs in the msg_ids array
 *
 * @param chat_id The destination chat ID.
 *
 * @return none
 */
void mrmailbox_forward_msgs(mrmailbox_t* mailbox, const uint32_t* msg_ids, int msg_cnt, uint32_t chat_id)
{
	mrmsg_t*      msg = mrmsg_new();
	mrchat_t*     chat = mrchat_new(mailbox);
	mrcontact_t*  contact = mrcontact_new();
	int           locked = 0, transaction_pending = 0;
	carray*       created_db_entries = carray_new(16);
	char*         idsstr = NULL, *q3 = NULL;
	sqlite3_stmt* stmt = NULL;
	time_t        curr_timestamp;

	if( mailbox == NULL || msg_ids==NULL || msg_cnt <= 0 || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;
	mrsqlite3_begin_transaction__(mailbox->m_sql);
	transaction_pending = 1;

		mrmailbox_unarchive_chat__(mailbox, chat_id);

		mailbox->m_smtp->m_log_connect_errors = 1;

		if( !mrchat_load_from_db__(chat, chat_id) ) {
			goto cleanup;
		}

		curr_timestamp = mr_create_smeared_timestamps__(msg_cnt);

		idsstr = mr_arr_to_string(msg_ids, msg_cnt);
		q3 = sqlite3_mprintf("SELECT id FROM msgs WHERE id IN(%s) ORDER BY timestamp,id", idsstr);
		stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, q3);
		while( sqlite3_step(stmt)==SQLITE_ROW )
		{
			int src_msg_id = sqlite3_column_int(stmt, 0);
			if( !mrmsg_load_from_db__(msg, mailbox, src_msg_id) ) {
				goto cleanup;
			}

			mrparam_set_int(msg->m_param, MRP_FORWARDED, 1);

			uint32_t new_msg_id = mrmailbox_send_msg_i__(mailbox, chat, msg, curr_timestamp++);
			carray_add(created_db_entries, (void*)(uintptr_t)chat_id, NULL);
			carray_add(created_db_entries, (void*)(uintptr_t)new_msg_id, NULL);
		}

	mrsqlite3_commit__(mailbox->m_sql);
	transaction_pending = 0;

cleanup:
	if( transaction_pending ) { mrsqlite3_rollback__(mailbox->m_sql); }
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( created_db_entries ) {
		size_t i, icnt = carray_count(created_db_entries);
		for( i = 0; i < icnt; i += 2 ) {
			mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, (uintptr_t)carray_get(created_db_entries, i), (uintptr_t)carray_get(created_db_entries, i+1));
		}
		carray_free(created_db_entries);
	}
	mrcontact_unref(contact);
	mrmsg_unref(msg);
	mrchat_unref(chat);
	if( stmt ) { sqlite3_finalize(stmt); }
	free(idsstr);
	if( q3 ) { sqlite3_free(q3); }
}


/**
 * Star/unstar messages by setting the last parameter to 0 (unstar) or 1(star).
 * Starred messages are collected in a virtual chat that can be shown using
 * mrmailbox_get_chat_msgs() using the chat_id MR_CHAT_ID_STARRED.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new()
 *
 * @param msg_ids An array of uint32_t message IDs defining the messages to star or unstar
 *
 * @param msg_cnt The number of IDs in msg_ids
 *
 * @param star 0=unstar the messages in msg_ids, 1=star them
 *
 * @return none
 */
void mrmailbox_star_msgs(mrmailbox_t* mailbox, const uint32_t* msg_ids, int msg_cnt, int star)
{
	int i;

	if( mailbox == NULL || msg_ids == NULL || msg_cnt <= 0 || (star!=0 && star!=1) ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);
	mrsqlite3_begin_transaction__(mailbox->m_sql);

		for( i = 0; i < msg_cnt; i++ )
		{
			sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_starred_WHERE_id,
				"UPDATE msgs SET starred=? WHERE id=?;");
			sqlite3_bind_int(stmt, 1, star);
			sqlite3_bind_int(stmt, 2, msg_ids[i]);
			sqlite3_step(stmt);
		}

	mrsqlite3_commit__(mailbox->m_sql);
	mrsqlite3_unlock(mailbox->m_sql);
}


/*******************************************************************************
 * Delete messages
 ******************************************************************************/


/* internal function */
void mrmailbox_delete_msg_on_imap(mrmailbox_t* mailbox, mrjob_t* job)
{
	int      locked = 0, delete_from_server = 1;
	mrmsg_t* msg = mrmsg_new();

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( !mrmsg_load_from_db__(msg, mailbox, job->m_foreign_id) ) {
			goto cleanup;
		}

		if( mrmailbox_rfc724_mid_cnt__(mailbox, msg->m_rfc724_mid) != 1 ) {
			mrmailbox_log_info(mailbox, 0, "The message is deleted from the server when all message are deleted.");
			delete_from_server = 0;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* if this is the last existing part of the message, we delete the message from the server */
	if( delete_from_server )
	{
		if( !mrimap_is_connected(mailbox->m_imap) ) {
			mrmailbox_connect_to_imap(mailbox, NULL);
			if( !mrimap_is_connected(mailbox->m_imap) ) {
				mrjob_try_again_later(job, MR_STANDARD_DELAY);
				goto cleanup;
			}
		}

		if( !mrimap_delete_msg(mailbox->m_imap, msg->m_rfc724_mid, msg->m_server_folder, msg->m_server_uid) )
		{
			mrjob_try_again_later(job, MR_STANDARD_DELAY);
			goto cleanup;
		}
	}

	/* we delete the database entry ...
	- if the message is successfully removed from the server
	- or if there are other parts of the messages in the database (in this case we have not deleted if from the server)
	(As long as the message is not removed from the IMAP-server, we need at least one database entry to avoid a re-download) */
	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, DELETE_FROM_msgs_WHERE_id, "DELETE FROM msgs WHERE id=?;");
		sqlite3_bind_int(stmt, 1, msg->m_id);
		sqlite3_step(stmt);

		char* pathNfilename = mrparam_get(msg->m_param, MRP_FILE, NULL);
		if( pathNfilename ) {
			if( strncmp(mailbox->m_blobdir, pathNfilename, strlen(mailbox->m_blobdir))==0 )
			{
				char* strLikeFilename = mr_mprintf("%%f=%s%%", pathNfilename);
				sqlite3_stmt* stmt2 = mrsqlite3_prepare_v2_(mailbox->m_sql, "SELECT id FROM msgs WHERE type!=? AND param LIKE ?;"); /* if this gets too slow, an index over "type" should help. */
				sqlite3_bind_int (stmt2, 1, MR_MSG_TEXT);
				sqlite3_bind_text(stmt2, 2, strLikeFilename, -1, SQLITE_STATIC);
				int file_used_by_other_msgs = (sqlite3_step(stmt2)==SQLITE_ROW)? 1 : 0;
				free(strLikeFilename);
				sqlite3_finalize(stmt2);

				if( !file_used_by_other_msgs )
				{
					mr_delete_file(pathNfilename, mailbox);

					char* increation_file = mr_mprintf("%s.increation", pathNfilename);
					mr_delete_file(increation_file, mailbox);
					free(increation_file);

					char* filenameOnly = mr_get_filename(pathNfilename);
					if( msg->m_type==MR_MSG_VOICE ) {
						char* waveform_file = mr_mprintf("%s/%s.waveform", mailbox->m_blobdir, filenameOnly);
						mr_delete_file(waveform_file, mailbox);
						free(waveform_file);
					}
					else if( msg->m_type==MR_MSG_VIDEO ) {
						char* preview_file = mr_mprintf("%s/%s-preview.jpg", mailbox->m_blobdir, filenameOnly);
						mr_delete_file(preview_file, mailbox);
						free(preview_file);
					}
					free(filenameOnly);
				}
			}
			free(pathNfilename);
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

cleanup:
	if( locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}
	mrmsg_unref(msg);
}


/**
 * Delete a list of messages. The messages are deleted on the current device and
 * on the IMAP server.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new()
 *
 * @param msg_ids an array of uint32_t containing all message IDs that should be deleted
 *
 * @param msg_cnt the number of messages IDs in the msg_ids array
 *
 * @return none
 */
void mrmailbox_delete_msgs(mrmailbox_t* mailbox, const uint32_t* msg_ids, int msg_cnt)
{
	int i;

	if( mailbox == NULL || msg_ids == NULL || msg_cnt <= 0 ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);
	mrsqlite3_begin_transaction__(mailbox->m_sql);

		for( i = 0; i < msg_cnt; i++ )
		{
			mrmailbox_update_msg_chat_id__(mailbox, msg_ids[i], MR_CHAT_ID_TRASH);
			mrjob_add__(mailbox, MRJ_DELETE_MSG_ON_IMAP, msg_ids[i], NULL); /* results in a call to mrmailbox_delete_msg_on_imap() */
		}

	mrsqlite3_commit__(mailbox->m_sql);
	mrsqlite3_unlock(mailbox->m_sql);
}


/*******************************************************************************
 * mark message as seen
 ******************************************************************************/


void mrmailbox_markseen_msg_on_imap(mrmailbox_t* mailbox, mrjob_t* job)
{
	int      locked = 0;
	mrmsg_t* msg = mrmsg_new();
	char*    new_server_folder = NULL;
	uint32_t new_server_uid = 0;
	int      in_ms_flags = 0, out_ms_flags = 0;

	if( !mrimap_is_connected(mailbox->m_imap) ) {
		mrmailbox_connect_to_imap(mailbox, NULL);
		if( !mrimap_is_connected(mailbox->m_imap) ) {
			mrjob_try_again_later(job, MR_STANDARD_DELAY);
			goto cleanup;
		}
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( !mrmsg_load_from_db__(msg, mailbox, job->m_foreign_id) ) {
			goto cleanup;
		}

		/* add an additional job for sending the MDN (here in a thread for fast ui resonses) (an extra job as the MDN has a lower priority) */
		if( mrparam_get_int(msg->m_param, MRP_WANTS_MDN, 0) /* MRP_WANTS_MDN is set only for one part of a multipart-message */
		 && mrsqlite3_get_config_int__(mailbox->m_sql, "mdns_enabled", MR_MDNS_DEFAULT_ENABLED) ) {
			in_ms_flags |= MR_MS_SET_MDNSent_FLAG;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	if( msg->m_is_msgrmsg ) {
		in_ms_flags |= MR_MS_ALSO_MOVE;
	}

	if( mrimap_markseen_msg(mailbox->m_imap, msg->m_server_folder, msg->m_server_uid,
		   in_ms_flags, &new_server_folder, &new_server_uid, &out_ms_flags) != 0 )
	{
		if( (new_server_folder && new_server_uid) || out_ms_flags&MR_MS_MDNSent_JUST_SET )
		{
			mrsqlite3_lock(mailbox->m_sql);
			locked = 1;

				if( new_server_folder && new_server_uid )
				{
					mrmailbox_update_server_uid__(mailbox, msg->m_rfc724_mid, new_server_folder, new_server_uid);
				}

				if( out_ms_flags&MR_MS_MDNSent_JUST_SET )
				{
					mrjob_add__(mailbox, MRJ_SEND_MDN, msg->m_id, NULL); /* results in a call to mrmailbox_send_mdn() */
				}

			mrsqlite3_unlock(mailbox->m_sql);
			locked = 0;
		}
	}
	else
	{
		mrjob_try_again_later(job, MR_STANDARD_DELAY);
	}

cleanup:
	if( locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}
	mrmsg_unref(msg);
	free(new_server_folder);
}


void mrmailbox_markseen_mdn_on_imap(mrmailbox_t* mailbox, mrjob_t* job)
{
	char*    server_folder = mrparam_get    (job->m_param, MRP_SERVER_FOLDER, NULL);
	uint32_t server_uid    = mrparam_get_int(job->m_param, MRP_SERVER_UID, 0);
	char*    new_server_folder = NULL;
	uint32_t new_server_uid    = 0;
	int      out_ms_flags = 0;

	if( !mrimap_is_connected(mailbox->m_imap) ) {
		mrmailbox_connect_to_imap(mailbox, NULL);
		if( !mrimap_is_connected(mailbox->m_imap) ) {
			mrjob_try_again_later(job, MR_STANDARD_DELAY);
			goto cleanup;
		}
	}

	if( mrimap_markseen_msg(mailbox->m_imap, server_folder, server_uid, MR_MS_ALSO_MOVE, &new_server_folder, &new_server_uid, &out_ms_flags) == 0 ) {
		mrjob_try_again_later(job, MR_STANDARD_DELAY);
	}

cleanup:
	free(server_folder);
	free(new_server_folder);
}


/**
 * Mark a message as _seen_, updates the IMAP state and
 * sends MDNs. if the message is not in a real chat (eg. a contact request), the
 * message is only marked as NOTICED and no IMAP/MDNs is done.  See also
 * mrmailbox_marknoticed_chat() and mrmailbox_marknoticed_contact()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object.
 *
 * @param msg_ids an array of uint32_t containing all the messages IDs that should be marked as seen.
 *
 * @param msg_cnt The number of message IDs in msg_ids.
 *
 * @return none
 */
void mrmailbox_markseen_msgs(mrmailbox_t* mailbox, const uint32_t* msg_ids, int msg_cnt)
{
	int i, send_event = 0;

	if( mailbox == NULL || msg_ids == NULL || msg_cnt <= 0 ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);
	mrsqlite3_begin_transaction__(mailbox->m_sql);

		for( i = 0; i < msg_cnt; i++ )
		{
			sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_seen_WHERE_id_AND_chat_id_AND_freshORnoticed,
				"UPDATE msgs SET state=" MR_STRINGIFY(MR_STATE_IN_SEEN)
				" WHERE id=? AND chat_id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL) " AND (state=" MR_STRINGIFY(MR_STATE_IN_FRESH) " OR state=" MR_STRINGIFY(MR_STATE_IN_NOTICED) ");");
			sqlite3_bind_int(stmt, 1, msg_ids[i]);
			sqlite3_step(stmt);
			if( sqlite3_changes(mailbox->m_sql->m_cobj) )
			{
				mrmailbox_log_info(mailbox, 0, "Seen message #%i.", msg_ids[i]);
				mrjob_add__(mailbox, MRJ_MARKSEEN_MSG_ON_IMAP, msg_ids[i], NULL); /* results in a call to mrmailbox_markseen_msg_on_imap() */
				send_event = 1;
			}
			else
			{
				/* message may be in contact requests, mark as NOTICED, this does not force IMAP updated nor send MDNs */
				sqlite3_stmt* stmt2 = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_noticed_WHERE_id_AND_fresh,
					"UPDATE msgs SET state=" MR_STRINGIFY(MR_STATE_IN_NOTICED)
					" WHERE id=? AND state=" MR_STRINGIFY(MR_STATE_IN_FRESH) ";");
				sqlite3_bind_int(stmt2, 1, msg_ids[i]);
				sqlite3_step(stmt2);
				if( sqlite3_changes(mailbox->m_sql->m_cobj) ) {
					send_event = 1;
				}
			}
		}

	mrsqlite3_commit__(mailbox->m_sql);
	mrsqlite3_unlock(mailbox->m_sql);

	/* the event us needed eg. to remove the deaddrop from the chatlist */
	if( send_event ) {
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0);
	}
}


int mrmailbox_mdn_from_ext__(mrmailbox_t* mailbox, uint32_t from_id, const char* rfc724_mid,
                                     uint32_t* ret_chat_id,
                                     uint32_t* ret_msg_id)
{
	if( mailbox == NULL || from_id <= MR_CONTACT_ID_LAST_SPECIAL || rfc724_mid == NULL || ret_chat_id==NULL || ret_msg_id==NULL
	 || *ret_chat_id != 0 || *ret_msg_id != 0 ) {
		return 0;
	}

	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_it_FROM_msgs_JOIN_chats_WHERE_rfc724,
		"SELECT m.id, c.id, c.type, m.state FROM msgs m "
		" LEFT JOIN chats c ON m.chat_id=c.id "
		" WHERE rfc724_mid=? AND from_id=1 "
		" ORDER BY m.id;"); /* the ORDER BY makes sure, if one rfc724_mid is splitted into its parts, we always catch the same one. However, we do not send multiparts, we do not request MDNs for multiparts, and should not receive read requests for multiparts. So this is currently more theoretical. */
	sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	*ret_msg_id    = sqlite3_column_int(stmt, 0);
	*ret_chat_id   = sqlite3_column_int(stmt, 1);
	int chat_type  = sqlite3_column_int(stmt, 2);
	int msg_state  = sqlite3_column_int(stmt, 3);

	if( msg_state!=MR_STATE_OUT_PENDING && msg_state!=MR_STATE_OUT_DELIVERED ) {
		return 0; /* eg. already marked as MDNS_RCVD. however, it is importent, that the message ID is set above as this will allow the caller eg. to move the message away */
	}

	/* normal chat? that's quite easy. */
	if( chat_type == MR_CHAT_TYPE_NORMAL )
	{
		mrmailbox_update_msg_state__(mailbox, *ret_msg_id, MR_STATE_OUT_MDN_RCVD);
		return 1; /* send event about new state */
	}

	/* group chat: collect receipt senders */
	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_c_FROM_msgs_mdns_WHERE_mc, "SELECT contact_id FROM msgs_mdns WHERE msg_id=? AND contact_id=?;");
	sqlite3_bind_int(stmt, 1, *ret_msg_id);
	sqlite3_bind_int(stmt, 2, from_id);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		stmt = mrsqlite3_predefine__(mailbox->m_sql, INSERT_INTO_msgs_mdns, "INSERT INTO msgs_mdns (msg_id, contact_id) VALUES (?, ?);");
		sqlite3_bind_int(stmt, 1, *ret_msg_id);
		sqlite3_bind_int(stmt, 2, from_id);
		sqlite3_step(stmt);
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_mdns_WHERE_m, "SELECT COUNT(*) FROM msgs_mdns WHERE msg_id=?;");
	sqlite3_bind_int(stmt, 1, *ret_msg_id);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0; /* error */
	}

	/*
	Groupsize:  Min. MDNs

	1 S         n/a
	2 SR        1
	3 SRR       2
	4 SRRR      2
	5 SRRRR     3
	6 SRRRRR    3

	(S=Sender, R=Recipient)
	*/
	int ist_cnt  = sqlite3_column_int(stmt, 0);
	int soll_cnt = (mrmailbox_get_chat_contact_count__(mailbox, *ret_chat_id)+1/*for rounding, SELF is already included!*/) / 2;
	if( ist_cnt < soll_cnt ) {
		return 0; /* wait for more receipts */
	}

	/* got enough receipts :-) */
	stmt = mrsqlite3_predefine__(mailbox->m_sql, DELETE_FROM_msgs_mdns_WHERE_m, "DELETE FROM msgs_mdns WHERE msg_id=?;");
	sqlite3_bind_int(stmt, 1, *ret_msg_id);
	sqlite3_step(stmt);

	mrmailbox_update_msg_state__(mailbox, *ret_msg_id, MR_STATE_OUT_MDN_RCVD);
	return 1;
}


void mrmailbox_send_mdn(mrmailbox_t* mailbox, mrjob_t* job)
{
	mrmimefactory_t mimefactory;
	mrmimefactory_init(&mimefactory, mailbox);

	if( mailbox == NULL || job == NULL ) {
		return;
	}

	/* connect to SMTP server, if not yet done */
	if( !mrsmtp_is_connected(mailbox->m_smtp) ) {
		mrloginparam_t* loginparam = mrloginparam_new();
			mrsqlite3_lock(mailbox->m_sql);
				mrloginparam_read__(loginparam, mailbox->m_sql, "configured_");
			mrsqlite3_unlock(mailbox->m_sql);
			int connected = mrsmtp_connect(mailbox->m_smtp, loginparam);
		mrloginparam_unref(loginparam);
		if( !connected ) {
			mrjob_try_again_later(job, MR_STANDARD_DELAY);
			goto cleanup;
		}
	}

    if( !mrmimefactory_load_mdn(&mimefactory, job->m_foreign_id)
     || !mrmimefactory_render(&mimefactory, 0/*encrypt to self*/) ) {
		goto cleanup;
    }

	//char* t1=mr_null_terminate(mimefactory.m_out->str,mimefactory.m_out->len);printf("~~~~~MDN~~~~~\n%s\n~~~~~/MDN~~~~~",t1);free(t1); // DEBUG OUTPUT

	if( !mrsmtp_send_msg(mailbox->m_smtp, mimefactory.m_recipients_addr, mimefactory.m_out->str, mimefactory.m_out->len) ) {
		mrsmtp_disconnect(mailbox->m_smtp);
		mrjob_try_again_later(job, MR_AT_ONCE); /* MR_AT_ONCE is only the _initial_ delay, if the second try failes, the delay gets larger */
		goto cleanup;
	}

cleanup:
	mrmimefactory_empty(&mimefactory);
}

