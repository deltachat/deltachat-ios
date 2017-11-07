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
 *******************************************************************************
 *
 * File:    mrmimefactory.c
 *
 ******************************************************************************/


#include <stdlib.h>
#include <string.h>
#include "mrmailbox.h"
#include "mrmimefactory.h"
#include "mrtools.h"

#define LINEEND "\r\n" /* lineend used in IMF */



/*******************************************************************************
 * Load data
 ******************************************************************************/


void mrmimefactory_init(mrmimefactory_t* factory, mrmailbox_t* mailbox)
{
	if( factory == NULL || mailbox == NULL ) {
		return;
	}

	memset(factory, 0, sizeof(mrmimefactory_t));
	factory->m_mailbox = mailbox;
}


void mrmimefactory_empty(mrmimefactory_t* factory)
{
	if( factory == NULL ) {
		return;
	}

	free(factory->m_from_addr);
	factory->m_from_addr = NULL;

	free(factory->m_from_displayname);
	factory->m_from_displayname = NULL;

	free(factory->m_selfstatus);
	factory->m_selfstatus = NULL;

	if( factory->m_recipients_names ) {
		clist_free_content(factory->m_recipients_names);
		clist_free(factory->m_recipients_names);
		factory->m_recipients_names = NULL;
	}

	if( factory->m_recipients_addr ) {
		clist_free_content(factory->m_recipients_addr);
		clist_free(factory->m_recipients_addr);
		factory->m_recipients_addr = NULL;
	}

	mrmsg_unref(factory->m_msg);
	factory->m_msg = NULL;

	mrchat_unref(factory->m_chat);
	factory->m_chat = NULL;

	if( factory->m_out ) {
		mmap_string_free(factory->m_out);
		factory->m_out = NULL;
	}
	factory->m_out_encrypted = 0;
	factory->m_loaded = MR_MF_NOTHING_LOADED;

	factory->m_timestamp = 0;
}


static void load_from__(mrmimefactory_t* factory)
{
	factory->m_from_addr        = mrsqlite3_get_config__(factory->m_mailbox->m_sql, "configured_addr", NULL);
	factory->m_from_displayname = mrsqlite3_get_config__(factory->m_mailbox->m_sql, "displayname", NULL);

	factory->m_selfstatus       = mrsqlite3_get_config__(factory->m_mailbox->m_sql, "selfstatus", NULL);
	if( factory->m_selfstatus == NULL ) {
		factory->m_selfstatus = mrstock_str(MR_STR_STATUSLINE);
	}
}


int mrmimefactory_load_msg(mrmimefactory_t* factory, uint32_t msg_id)
{
	int success = 0, locked = 0;

	if( factory == NULL || msg_id <= MR_MSG_ID_LAST_SPECIAL
	 || factory->m_mailbox == NULL
	 || factory->m_msg /*call empty() before */ ) {
		goto cleanup;
	}

	mrmailbox_t* mailbox = factory->m_mailbox;

	factory->m_recipients_names = clist_new();
	factory->m_recipients_addr  = clist_new();
	factory->m_msg              = mrmsg_new();
	factory->m_chat             = mrchat_new(mailbox);

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( mrmsg_load_from_db__(factory->m_msg, mailbox, msg_id)
		 && mrchat_load_from_db__(factory->m_chat, factory->m_msg->m_chat_id) )
		{
			sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_na_FROM_chats_contacs_JOIN_contacts_WHERE_cc,
				"SELECT c.authname, c.addr FROM chats_contacts cc LEFT JOIN contacts c ON cc.contact_id=c.id WHERE cc.chat_id=? AND cc.contact_id>?;");
			sqlite3_bind_int(stmt, 1, factory->m_msg->m_chat_id);
			sqlite3_bind_int(stmt, 2, MR_CONTACT_ID_LAST_SPECIAL);
			while( sqlite3_step(stmt) == SQLITE_ROW )
			{
				const char* authname = (const char*)sqlite3_column_text(stmt, 0);
				const char* addr = (const char*)sqlite3_column_text(stmt, 1);
				if( clist_search_string_nocase(factory->m_recipients_addr, addr)==0 )
				{
					clist_append(factory->m_recipients_names, (void*)((authname&&authname[0])? safe_strdup(authname) : NULL));
					clist_append(factory->m_recipients_addr,  (void*)safe_strdup(addr));
				}
			}

			int system_command = mrparam_get_int(factory->m_msg->m_param, MRP_SYSTEM_CMD, 0);
			if( system_command==MR_SYSTEM_MEMBER_REMOVED_FROM_GROUP /* for added members, the list is just fine */) {
				char* email_to_remove = mrparam_get(factory->m_msg->m_param, MRP_SYSTEM_CMD_PARAM, NULL);
				char* self_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", "");
				if( email_to_remove && strcasecmp(email_to_remove, self_addr)!=0 )
				{
					if( clist_search_string_nocase(factory->m_recipients_addr, email_to_remove)==0 )
					{
						clist_append(factory->m_recipients_names, NULL);
						clist_append(factory->m_recipients_addr,  (void*)email_to_remove);
					}
				}
				free(self_addr);
			}

			load_from__(factory);

			factory->m_req_mdn = 0;
			if( mrsqlite3_get_config_int__(mailbox->m_sql, "mdns_enabled", MR_MDNS_DEFAULT_ENABLED) ) {
				factory->m_req_mdn = 1;
			}

			/* Get a predecessor of the mail to send.
			For simplicity, we use the last message send not by us.
			This is not 100% accurate and may even be a newer message if first sending fails and new messages arrive -
			however, as we currently only use it to identifify answers from different email addresses, this is sufficient.

			Our first idea was to write the predecessor to the `In-Reply-To:` header, however, this results
			in infinite depth thread views eg. in thunderbird.  Maybe we can work around this issue by using only one
			predecessor anchor a day, however, for the moment, we just use the `X-MrPredecessor` header that does not
			disturb other mailers.

			Finally, maybe the Predecessor/In-Reply-To header is not needed for all answers but only to the first ones -
			or after the sender has changes its email address. */
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_rfc724_FROM_msgs_ORDER_BY_timestamp_LIMIT_1,
				"SELECT rfc724_mid FROM msgs WHERE timestamp=(SELECT max(timestamp) FROM msgs WHERE chat_id=? AND from_id!=?);");
			sqlite3_bind_int  (stmt, 1, factory->m_msg->m_chat_id);
			sqlite3_bind_int  (stmt, 2, MR_CONTACT_ID_SELF);
			if( sqlite3_step(stmt) == SQLITE_ROW ) {
				factory->m_predecessor = strdup_keep_null((const char*)sqlite3_column_text(stmt, 0));
			}

			/* get a References:-header: either the same as the last one or a random one.
			To avoid endless nested threads, we do not use In-Reply-To: here but link subsequent mails to the same reference.
			This "same reference" is re-calculated after 24 hours to avoid completely different messages being linked to an old context.

			Regarding multi-client: Different clients will create difference References:-header, maybe we will sync these headers some day,
			however one could also see this as a feature :) (there may be different contextes on different clients)
			(also, the References-header is not the most important thing, and, at least for now, we do not want to make things too complicated.  */
			time_t prev_msg_time = 0;
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_MAX_timestamp_FROM_msgs,
				"SELECT max(timestamp) FROM msgs WHERE chat_id=? AND id!=?");
			sqlite3_bind_int  (stmt, 1, factory->m_msg->m_chat_id);
			sqlite3_bind_int  (stmt, 2, factory->m_msg->m_id);
			if( sqlite3_step(stmt) == SQLITE_ROW ) {
				prev_msg_time = sqlite3_column_int64(stmt, 0);
			}

			#define NEW_THREAD_THRESHOLD 24*60*60
			if( prev_msg_time != 0 && factory->m_msg->m_timestamp - prev_msg_time < NEW_THREAD_THRESHOLD ) {
				factory->m_references = mrparam_get(factory->m_chat->m_param, MRP_REFERENCES, NULL);
			}

			if( factory->m_references == NULL ) {
				factory->m_references = mr_create_dummy_references_mid();
				mrparam_set(factory->m_chat->m_param, MRP_REFERENCES, factory->m_references);
				mrchat_update_param__(factory->m_chat);
			}

			success = 1;
			factory->m_loaded = MR_MF_MSG_LOADED;
			factory->m_timestamp = factory->m_msg->m_timestamp;
			factory->m_rfc724_mid = safe_strdup(factory->m_msg->m_rfc724_mid);
		}

		if( success ) {
			factory->m_increation = mrmsg_is_increation__(factory->m_msg);
		}
	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	return success;
}


int mrmimefactory_load_mdn(mrmimefactory_t* factory, uint32_t msg_id)
{
	int           success = 0, locked = 0;
	mrcontact_t*  contact = mrcontact_new();

	if( factory == NULL ) {
		goto cleanup;
	}

	mrmailbox_t* mailbox = factory->m_mailbox;

	factory->m_recipients_names = clist_new();
	factory->m_recipients_addr  = clist_new();
	factory->m_msg              = mrmsg_new();

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( !mrsqlite3_get_config_int__(mailbox->m_sql, "mdns_enabled", MR_MDNS_DEFAULT_ENABLED) ) {
			goto cleanup; /* MDNs not enabled - check this is late, in the job. the use may have changed its choice while offline ... */
		}

		if( !mrmsg_load_from_db__(factory->m_msg, mailbox, msg_id)
		 || !mrcontact_load_from_db__(contact, mailbox->m_sql, factory->m_msg->m_from_id) ) {
			goto cleanup;
		}

		if( contact->m_blocked
		 || factory->m_msg->m_chat_id<=MR_CHAT_ID_LAST_SPECIAL/* Do not send MDNs for contact requests, trash etc. */ ) {
			goto cleanup;
		}

		if( factory->m_msg->m_from_id <= MR_CONTACT_ID_LAST_SPECIAL ) {
			goto cleanup;
		}

		clist_append(factory->m_recipients_names, (void*)((contact->m_authname&&contact->m_authname[0])? safe_strdup(contact->m_authname) : NULL));
		clist_append(factory->m_recipients_addr,  (void*)safe_strdup(contact->m_addr));

		load_from__(factory);

		factory->m_timestamp = mr_create_smeared_timestamp__();
		factory->m_rfc724_mid = mr_create_outgoing_rfc724_mid(NULL, factory->m_from_addr);

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	success = 1;
	factory->m_loaded = MR_MF_MDN_LOADED;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	return success;
}


/*******************************************************************************
 * Render
 ******************************************************************************/


static struct mailmime* build_body_text(char* text)
{
	struct mailmime_fields*    mime_fields;
	struct mailmime*           message_part;
	struct mailmime_content*   content;

	content = mailmime_content_new_with_str("text/plain");
	clist_append(content->ct_parameters, mailmime_param_new_with_data("charset", "utf-8")); /* format=flowed currently does not really affect us, see https://www.ietf.org/rfc/rfc3676.txt */

	mime_fields = mailmime_fields_new_encoding(MAILMIME_MECHANISM_8BIT);

	message_part = mailmime_new_empty(content, mime_fields);
	mailmime_set_body_text(message_part, text, strlen(text));

	return message_part;
}


static struct mailmime* build_body_file(const mrmsg_t* msg, const char* base_name, char** ret_file_name_as_sended)
{
	struct mailmime_fields*  mime_fields;
	struct mailmime*         mime_sub = NULL;
	struct mailmime_content* content;

	char* pathNfilename = mrparam_get(msg->m_param, MRP_FILE, NULL);
	char* mimetype = mrparam_get(msg->m_param, MRP_MIMETYPE, NULL);
	char* suffix = mr_get_filesuffix_lc(pathNfilename);
	char* filename_to_send = NULL;

	if( pathNfilename == NULL ) {
		goto cleanup;
	}

	/* get file name to use for sending (for privacy purposes, we do not transfer the original filenames eg. for images; these names are normally not needed and contain timesamps, running numbers etc.) */
	if( msg->m_type == MR_MSG_VOICE ) {
		struct tm wanted_struct;
		memcpy(&wanted_struct, localtime(&msg->m_timestamp), sizeof(struct tm));
		filename_to_send = mr_mprintf("voice-message_%04i-%02i-%02i_%02i-%02i-%02i.%s",
			(int)wanted_struct.tm_year+1900, (int)wanted_struct.tm_mon+1, (int)wanted_struct.tm_mday,
			(int)wanted_struct.tm_hour, (int)wanted_struct.tm_min, (int)wanted_struct.tm_sec,
			suffix? suffix : "dat");
	}
	else if( msg->m_type == MR_MSG_AUDIO ) {
		char* author = mrparam_get(msg->m_param, MRP_AUTHORNAME, NULL);
		char* title = mrparam_get(msg->m_param, MRP_TRACKNAME, NULL);
		if( author && author[0] && title && title[0] && suffix ) {
			filename_to_send = mr_mprintf("%s - %s.%s",  author, title, suffix); /* the separator ` - ` is used on the receiver's side to construct the information; we avoid using ID3-scanners for security purposes */
		}
		else {
			filename_to_send = mr_get_filename(pathNfilename);
		}
		free(author);
		free(title);
	}
	else if( msg->m_type == MR_MSG_IMAGE || msg->m_type == MR_MSG_GIF ) {
		if( base_name == NULL ) {
			base_name = "image";
		}
		filename_to_send = mr_mprintf("%s.%s", base_name, suffix? suffix : "dat");
	}
	else if( msg->m_type == MR_MSG_VIDEO ) {
		filename_to_send = mr_mprintf("video.%s", suffix? suffix : "dat");
	}
	else {
		filename_to_send = mr_get_filename(pathNfilename);
	}

	/* check mimetype */
	if( mimetype == NULL && suffix != NULL ) {
		if( strcmp(suffix, "png")==0 ) {
			mimetype = safe_strdup("image/png");
		}
		else if( strcmp(suffix, "jpg")==0 || strcmp(suffix, "jpeg")==0 || strcmp(suffix, "jpe")==0 ) {
			mimetype = safe_strdup("image/jpeg");
		}
		else if( strcmp(suffix, "gif")==0 ) {
			mimetype = safe_strdup("image/gif");
		}
		else {
			mimetype = safe_strdup("application/octet-stream");
		}
	}

	if( mimetype == NULL ) {
		goto cleanup;
	}

	/* create mime part, for Content-Disposition, see RFC 2183.
	`Content-Disposition: attachment` seems not to make a difference to `Content-Disposition: inline` at least on tested Thunderbird and Gma'l in 2017.
	But I've heard about problems with inline and outl'k, so we just use the attachment-type until we run into other problems ... */
	mime_fields = mailmime_fields_new_filename(MAILMIME_DISPOSITION_TYPE_ATTACHMENT,
		safe_strdup(filename_to_send), MAILMIME_MECHANISM_BASE64);

	if( ret_file_name_as_sended ) {
		*ret_file_name_as_sended = safe_strdup(filename_to_send);
	}

	content = mailmime_content_new_with_str(mimetype);

	mime_sub = mailmime_new_empty(content, mime_fields);

	mailmime_set_body_file(mime_sub, safe_strdup(pathNfilename));

cleanup:
	free(pathNfilename);
	free(mimetype);
	free(filename_to_send);
	free(suffix);
	return mime_sub;
}


static char* get_subject(const mrchat_t* chat, const mrmsg_t* msg, int afwd_email)
{
	char *ret, *raw_subject = mrmsg_get_summarytext_by_raw(msg->m_type, msg->m_text, msg->m_param, APPROX_SUBJECT_CHARS);
	const char* fwd = afwd_email? "Fwd: " : "";

	if( chat->m_type==MR_CHAT_GROUP )
	{
		ret = mr_mprintf(MR_CHAT_PREFIX " %s: %s%s", chat->m_name, fwd, raw_subject);
	}
	else
	{
		ret = mr_mprintf(MR_CHAT_PREFIX " %s%s", fwd, raw_subject);
	}

	free(raw_subject);
	return ret;
}


int mrmimefactory_render(mrmimefactory_t* factory, int encrypt_to_self)
{
	if( factory == NULL
	 || factory->m_loaded == MR_MF_NOTHING_LOADED
	 || factory->m_out/*call empty() before*/ ) {
		return 0;
	}

	struct mailimf_fields*       imf_fields;
	struct mailmime*             message = NULL;
	char*                        message_text = NULL, *message_text2 = NULL, *subject_str = NULL;
	int                          afwd_email = 0;
	int                          col = 0;
	int                          success = 0;
	int                          parts = 0;
	mrmailbox_e2ee_helper_t      e2ee_helper;
	int                          e2ee_guaranteed = 0;
	int                          system_command = 0;
	int                          force_unencrypted = 0;
	char*                        grpimage = NULL;

	memset(&e2ee_helper, 0, sizeof(mrmailbox_e2ee_helper_t));


	/* create basic mail
	 *************************************************************************/

	{
		struct mailimf_mailbox_list* from = mailimf_mailbox_list_new_empty();
		mailimf_mailbox_list_add(from, mailimf_mailbox_new(factory->m_from_displayname? mr_encode_header_string(factory->m_from_displayname) : NULL, safe_strdup(factory->m_from_addr)));

		struct mailimf_address_list* to = NULL;
		if( factory->m_recipients_names && factory->m_recipients_addr && clist_count(factory->m_recipients_addr)>0 ) {
			clistiter *iter1, *iter2;
			to = mailimf_address_list_new_empty();
			for( iter1=clist_begin(factory->m_recipients_names),iter2=clist_begin(factory->m_recipients_addr);  iter1!=NULL&&iter2!=NULL;  iter1=clist_next(iter1),iter2=clist_next(iter2)) {
				const char* name = clist_content(iter1);
				const char* addr = clist_content(iter2);
				mailimf_address_list_add(to, mailimf_address_new(MAILIMF_ADDRESS_MAILBOX, mailimf_mailbox_new(name? mr_encode_header_string(name) : NULL, safe_strdup(addr)), NULL));
			}
		}

		clist* references_list = NULL;
		if( factory->m_references ) {
			references_list = clist_new();
			clist_append(references_list,  (void*)safe_strdup(factory->m_references));
		}

		imf_fields = mailimf_fields_new_with_data_all(mailimf_get_date(factory->m_timestamp), from,
			NULL /* sender */, NULL /* reply-to */,
			to, NULL /* cc */, NULL /* bcc */, safe_strdup(factory->m_rfc724_mid), NULL /* in-reply-to */,
			references_list /* references */,
			NULL /* subject set later */);

		mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("X-Mailer"),
			mr_mprintf("Delta Chat %i.%i.%i for %s", MR_VERSION_MAJOR, MR_VERSION_MINOR, MR_VERSION_REVISION, factory->m_mailbox->m_os_name))); /* only informational, for debugging, may be removed in the release. Also do not rely on this as it may be removed by MTAs. */

		mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("X-MrMsg"), strdup("1.0"))); /* mark message as being sent by a messenger */
		if( factory->m_predecessor ) {
			mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("X-MrPredecessor"), strdup(factory->m_predecessor)));
		}

		if( factory->m_req_mdn ) {
			/* we use "Chat-Disposition-Notification-To" as replies to "Disposition-Notification-To" are weired in many cases, are just freetext and/or do not follow any standard. */
			mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Disposition-Notification-To"), strdup(factory->m_from_addr)));
		}

		message = mailmime_new_message_data(NULL);
		mailmime_set_imf_fields(message, imf_fields);
	}

	if( factory->m_loaded == MR_MF_MSG_LOADED )
	{
		/* Render a normal message
		 *********************************************************************/

		mrchat_t* chat = factory->m_chat;
		mrmsg_t*  msg  = factory->m_msg;

		struct mailmime* meta_part = NULL;

		/* build header etc. */
		if( chat->m_type==MR_CHAT_GROUP )
		{
			mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("X-MrGrpId"), safe_strdup(chat->m_grpid)));
			mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("X-MrGrpName"), mr_encode_header_string(chat->m_name)));

			system_command = mrparam_get_int(msg->m_param, MRP_SYSTEM_CMD, 0);
			if( system_command == MR_SYSTEM_MEMBER_REMOVED_FROM_GROUP ) {
				char* email_to_remove = mrparam_get(msg->m_param, MRP_SYSTEM_CMD_PARAM, NULL);
				if( email_to_remove ) {
					mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("X-MrRemoveFromGrp"), email_to_remove));
				}
			}
			else if( system_command == MR_SYSTEM_MEMBER_ADDED_TO_GROUP ) {
				char* email_to_add = mrparam_get(msg->m_param, MRP_SYSTEM_CMD_PARAM, NULL);
				if( email_to_add ) {
					mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("X-MrAddToGrp"), email_to_add));
					grpimage = mrparam_get(chat->m_param, MRP_PROFILE_IMAGE, NULL);
				}
			}
			else if( system_command == MR_SYSTEM_GROUPNAME_CHANGED ) {
				mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("X-MrGrpNameChanged"), strdup("1")));
			}
			else if( system_command == MR_SYSTEM_GROUPIMAGE_CHANGED ) {
				grpimage = mrparam_get(msg->m_param, MRP_SYSTEM_CMD_PARAM, NULL);
				if( grpimage==NULL ) {
					mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Group-Image"), safe_strdup("0")));
				}
			}
		}

		if( grpimage )
		{
			mrmsg_t* meta = mrmsg_new();
			meta->m_type = MR_MSG_IMAGE;
			mrparam_set(meta->m_param, MRP_FILE, grpimage);
			char* filename_as_sended = NULL;
			if( (meta_part=build_body_file(meta, "group-image", &filename_as_sended))!=NULL ) {
				mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Group-Image"), filename_as_sended/*takes ownership*/));
			}
			mrmsg_unref(meta);
		}

		if( msg->m_type == MR_MSG_VOICE || msg->m_type == MR_MSG_AUDIO || msg->m_type == MR_MSG_VIDEO )
		{
			if( msg->m_type == MR_MSG_VOICE ) {
				mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("X-MrVoiceMessage"), strdup("1")));
			}

			int duration_ms = mrparam_get_int(msg->m_param, MRP_DURATION, 0);
			if( duration_ms > 0 ) {
				mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("X-MrDurationMs"), mr_mprintf("%i", (int)duration_ms)));
			}
		}

		/* add text part - we even add empty text and force a MIME-multipart-message as:
		- some Apps have problems with Non-text in the main part (eg. "Mail" from stock Android)
		- we can add "forward hints" this way
		- it looks better */
		afwd_email = mrparam_exists(msg->m_param, MRP_FORWARDED);
		char* fwdhint = NULL;
		if( afwd_email ) {
			fwdhint = safe_strdup("---------- Forwarded message ----------" LINEEND "From: Delta Chat" LINEEND LINEEND); /* do not chage this! expected this way in the simplifier to detect forwarding! */
		}

		int write_m_text = 0;
		if( msg->m_type==MR_MSG_TEXT && msg->m_text && msg->m_text[0] ) { /* m_text may also contain data otherwise, eg. the filename of attachments */
			write_m_text = 1;
		}

		char* footer = factory->m_selfstatus;
		message_text = mr_mprintf("%s%s%s%s%s",
			fwdhint? fwdhint : "",
			write_m_text? msg->m_text : "",
			(write_m_text&&footer&&footer[0])? (LINEEND LINEEND) : "",
			(footer&&footer[0])? ("-- " LINEEND)  : "",
			(footer&&footer[0])? footer       : "");
		struct mailmime* text_part = build_body_text(message_text);
		mailmime_smart_add_part(message, text_part);
		parts++;

		free(fwdhint);

		/* add attachment part */
		if( MR_MSG_NEEDS_ATTACHMENT(msg->m_type) ) {
			struct mailmime* file_part = build_body_file(msg, NULL, NULL);
			if( file_part ) {
				mailmime_smart_add_part(message, file_part);
				parts++;
			}
		}

		if( parts == 0 ) {
			goto cleanup;
		}

		if( meta_part ) {
			mailmime_smart_add_part(message, meta_part); /* meta parts are only added if there are other parts */
			parts++;
		}

		e2ee_guaranteed = mrparam_get_int(factory->m_msg->m_param, MRP_GUARANTEE_E2EE, 0);
	}
	else if( factory->m_loaded == MR_MF_MDN_LOADED )
	{
		/* Render a MDN
		 *********************************************************************/

		struct mailmime* multipart = mailmime_multiple_new("multipart/report"); /* RFC 6522, this also requires the `report-type` parameter which is equal to the MIME subtype of the second body part of the multipart/report */
		struct mailmime_content* content = multipart->mm_content_type;
		clist_append(content->ct_parameters, mailmime_param_new_with_data("report-type", "disposition-notification")); /* RFC  */
		mailmime_add_part(message, multipart);

		/* first body part: always human-readable, always REQUIRED by RFC 6522 */
		char *p1 = NULL, *p2 = NULL;
		if( mrparam_get_int(factory->m_msg->m_param, MRP_GUARANTEE_E2EE, 0) ) {
			p1 = mrstock_str(MR_STR_ENCRYPTEDMSG); /* we SHOULD NOT spread encrypted subjects, date etc. in potentially unencrypted MDNs */
		}
		else {
			p1 = mrmsg_get_summarytext(factory->m_msg, APPROX_SUBJECT_CHARS);
		}
		p2 = mrstock_str_repl_string(MR_STR_READRCPT_MAILBODY, p1);
		message_text = mr_mprintf("%s" LINEEND, p2);
		free(p2);
		free(p1);

		struct mailmime* human_mime_part = build_body_text(message_text);
		mailmime_add_part(multipart, human_mime_part);


		/* second body part: machine-readable, always REQUIRED by RFC 6522 */
		message_text2 = mr_mprintf(
			"Reporting-UA: Delta Chat %i.%i.%i" LINEEND
			"Original-Recipient: rfc822;%s" LINEEND
			"Final-Recipient: rfc822;%s" LINEEND
			"Original-Message-ID: <%s>" LINEEND
			"Disposition: manual-action/MDN-sent-automatically; displayed" LINEEND, /* manual-action: the user has configured the MUA to send MDNs (automatic-action implies the receipts cannot be disabled) */
			MR_VERSION_MAJOR, MR_VERSION_MINOR, MR_VERSION_REVISION,
			factory->m_from_addr,
			factory->m_from_addr,
			factory->m_msg->m_rfc724_mid);

		struct mailmime_content* content_type = mailmime_content_new_with_str("message/disposition-notification");
		struct mailmime_fields* mime_fields = mailmime_fields_new_encoding(MAILMIME_MECHANISM_8BIT);
		struct mailmime* mach_mime_part = mailmime_new_empty(content_type, mime_fields);
		mailmime_set_body_text(mach_mime_part, message_text2, strlen(message_text2));

		mailmime_add_part(multipart, mach_mime_part);

		/* currently, we do not send MDNs encrypted:
		- in a multi-device-setup that is not set up properly, MDNs would disturb the communication as they
		  are send automatically which may lead to spreading outdated Autocrypt headers.
		- they do not carry any information but the Message-ID
		- this save some KB
		- in older versions, we did not encrypt messages to ourself when they to to SMTP - however, if these messages
		  are forwarded for any reasons (eg. gmail always forwards to IMAP), we have no chance to decrypt them;
		  this issue is fixed with 0.9.4 */
		force_unencrypted = 1;
	}
	else
	{
		goto cleanup;
	}


	/* Encrypt the message
	 *************************************************************************/

	if( !force_unencrypted ) {
		if( encrypt_to_self==0 || e2ee_guaranteed ) {
			/* we're here (1) _always_ on SMTP and (2) on IMAP _only_ if SMTP was encrypted before */
			mrmailbox_e2ee_encrypt(factory->m_mailbox, factory->m_recipients_addr, e2ee_guaranteed, encrypt_to_self, message, &e2ee_helper);
		}
	}

	/* add a subject line */
	if( e2ee_helper.m_encryption_successfull ) {
		char* e = mrstock_str(MR_STR_ENCRYPTEDMSG); subject_str = mr_mprintf(MR_CHAT_PREFIX " %s", e); free(e);
		factory->m_out_encrypted = 1;
	}
	else {
		if( factory->m_loaded==MR_MF_MDN_LOADED ) {
			char* e = mrstock_str(MR_STR_READRCPT); subject_str = mr_mprintf(MR_CHAT_PREFIX " %s", e); free(e);
		}
		else {
			subject_str = get_subject(factory->m_chat, factory->m_msg, afwd_email);
		}
	}
	struct mailimf_subject* subject = mailimf_subject_new(mr_encode_header_string(subject_str));
	mailimf_fields_add(imf_fields, mailimf_field_new(MAILIMF_FIELD_SUBJECT, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, subject, NULL, NULL, NULL));

	/* create the full mail and return */
	factory->m_out = mmap_string_new("");
	mailmime_write_mem(factory->m_out, &col, message);

	//{char* t4=mr_null_terminate(ret->str,ret->len); printf("MESSAGE:\n%s\n",t4);free(t4);}

	success = 1;

cleanup:
	if( message ) {
		mailmime_free(message);
	}
	mrmailbox_e2ee_thanks(&e2ee_helper); /* frees data referenced by "mailmime" but not freed by mailmime_free() */
	free(message_text); free(message_text2); /* mailmime_set_body_text() does not take ownership of "text" */
	free(subject_str);
	free(grpimage);
	return success;
}

