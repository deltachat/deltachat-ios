#include "dc_context.h"
#include "dc_mimefactory.h"
#include "dc_apeerstate.h"


#define LINEEND "\r\n" /* lineend used in IMF */


/*******************************************************************************
 * Load data
 ******************************************************************************/


void dc_mimefactory_init(dc_mimefactory_t* factory, dc_context_t* context)
{
	if (factory==NULL || context==NULL) {
		return;
	}

	memset(factory, 0, sizeof(dc_mimefactory_t));
	factory->context = context;
}


void dc_mimefactory_empty(dc_mimefactory_t* factory)
{
	if (factory==NULL) {
		return;
	}

	free(factory->from_addr);
	factory->from_addr = NULL;

	free(factory->from_displayname);
	factory->from_displayname = NULL;

	free(factory->selfstatus);
	factory->selfstatus = NULL;

	free(factory->rfc724_mid);
	factory->rfc724_mid = NULL;

	if (factory->recipients_names) {
		clist_free_content(factory->recipients_names);
		clist_free(factory->recipients_names);
		factory->recipients_names = NULL;
	}

	if (factory->recipients_addr) {
		clist_free_content(factory->recipients_addr);
		clist_free(factory->recipients_addr);
		factory->recipients_addr = NULL;
	}

	dc_msg_unref(factory->msg);
	factory->msg = NULL;

	dc_chat_unref(factory->chat);
	factory->chat = NULL;

	free(factory->in_reply_to);
	factory->in_reply_to = NULL;

	free(factory->references);
	factory->references = NULL;

	if (factory->out) {
		mmap_string_free(factory->out);
		factory->out = NULL;
	}
	factory->out_encrypted = 0;
	factory->loaded = DC_MF_NOTHING_LOADED;

	free(factory->error);
	factory->error = NULL;

	factory->timestamp = 0;
}


static void set_error(dc_mimefactory_t* factory, const char* text)
{
	if (factory==NULL) {
		return;
	}

	free(factory->error);
	factory->error = dc_strdup_keep_null(text);
}


static void load_from(dc_mimefactory_t* factory)
{
	factory->from_addr        = dc_sqlite3_get_config(factory->context->sql, "configured_addr", NULL);
	factory->from_displayname = dc_sqlite3_get_config(factory->context->sql, "displayname", NULL);

	factory->selfstatus       = dc_sqlite3_get_config(factory->context->sql, "selfstatus", NULL);
	if (factory->selfstatus==NULL) {
		factory->selfstatus = dc_stock_str(factory->context, DC_STR_STATUSLINE);
	}
}


int dc_mimefactory_load_msg(dc_mimefactory_t* factory, uint32_t msg_id)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;

	if (factory==NULL || msg_id <= DC_MSG_ID_LAST_SPECIAL
	 || factory->context==NULL
	 || factory->msg /*call empty() before */) {
		goto cleanup;
	}

	dc_context_t* context = factory->context;

	factory->recipients_names = clist_new();
	factory->recipients_addr  = clist_new();
	factory->msg              = dc_msg_new_untyped(context);
	factory->chat             = dc_chat_new(context);

		if (dc_msg_load_from_db(factory->msg, context, msg_id)
		 && dc_chat_load_from_db(factory->chat, factory->msg->chat_id))
		{
			load_from(factory);

			factory->req_mdn = 0;

			if (dc_chat_is_self_talk(factory->chat))
			{
				clist_append(factory->recipients_names, (void*)dc_strdup_keep_null(factory->from_displayname));
				clist_append(factory->recipients_addr,  (void*)dc_strdup(factory->from_addr));
			}
			else
			{
				stmt = dc_sqlite3_prepare(context->sql,
					"SELECT c.authname, c.addr "
					" FROM chats_contacts cc "
					" LEFT JOIN contacts c ON cc.contact_id=c.id "
					" WHERE cc.chat_id=? AND cc.contact_id>" DC_STRINGIFY(DC_CONTACT_ID_LAST_SPECIAL) ";");
				sqlite3_bind_int(stmt, 1, factory->msg->chat_id);
				while (sqlite3_step(stmt)==SQLITE_ROW)
				{
					const char* authname            = (const char*)sqlite3_column_text(stmt, 0);
					const char* addr                = (const char*)sqlite3_column_text(stmt, 1);
					if (clist_search_string_nocase(factory->recipients_addr, addr)==0)
					{
						clist_append(factory->recipients_names, (void*)((authname&&authname[0])? dc_strdup(authname) : NULL));
						clist_append(factory->recipients_addr,  (void*)dc_strdup(addr));
					}
				}
				sqlite3_finalize(stmt);
				stmt = NULL;

				int command = dc_param_get_int(factory->msg->param, DC_PARAM_CMD, 0);
				if (command==DC_CMD_MEMBER_REMOVED_FROM_GROUP /* for added members, the list is just fine */) {
					char* email_to_remove     = dc_param_get(factory->msg->param, DC_PARAM_CMD_ARG, NULL);
					char* self_addr           = dc_sqlite3_get_config(context->sql, "configured_addr", "");
					if (email_to_remove && strcasecmp(email_to_remove, self_addr)!=0)
					{
						if (clist_search_string_nocase(factory->recipients_addr, email_to_remove)==0)
						{
							clist_append(factory->recipients_names, NULL);
							clist_append(factory->recipients_addr,  (void*)email_to_remove);
						}
					}
					free(self_addr);
				}

				if (command!=DC_CMD_AUTOCRYPT_SETUP_MESSAGE
				 && command!=DC_CMD_SECUREJOIN_MESSAGE
				 && dc_sqlite3_get_config_int(context->sql, "mdns_enabled", DC_MDNS_DEFAULT_ENABLED)) {
					factory->req_mdn = 1;
				}
			}

			stmt = dc_sqlite3_prepare(context->sql,
				"SELECT mime_in_reply_to, mime_references FROM msgs WHERE id=?");
			sqlite3_bind_int  (stmt, 1, factory->msg->id);
			if (sqlite3_step(stmt)==SQLITE_ROW) {
				factory->in_reply_to = dc_strdup((const char*)sqlite3_column_text(stmt, 0));
				factory->references  = dc_strdup((const char*)sqlite3_column_text(stmt, 1));
			}
			sqlite3_finalize(stmt);
			stmt = NULL;

			success = 1;
			factory->loaded = DC_MF_MSG_LOADED;
			factory->timestamp = factory->msg->timestamp;
			factory->rfc724_mid = dc_strdup(factory->msg->rfc724_mid);
		}

		if (success) {
			factory->increation = dc_msg_is_increation(factory->msg);
		}

cleanup:
	sqlite3_finalize(stmt);
	return success;
}


int dc_mimefactory_load_mdn(dc_mimefactory_t* factory, uint32_t msg_id)
{
	int           success = 0;
	dc_contact_t* contact = NULL;

	if (factory==NULL) {
		goto cleanup;
	}

	factory->recipients_names = clist_new();
	factory->recipients_addr  = clist_new();
	factory->msg              = dc_msg_new_untyped(factory->context);

	if (!dc_sqlite3_get_config_int(factory->context->sql, "mdns_enabled", DC_MDNS_DEFAULT_ENABLED)) {
		goto cleanup; /* MDNs not enabled - check this is late, in the job. the use may have changed its choice while offline ... */
	}

	contact = dc_contact_new(factory->context);
	if (!dc_msg_load_from_db(factory->msg, factory->context, msg_id)
	 || !dc_contact_load_from_db(contact, factory->context->sql, factory->msg->from_id)) {
		goto cleanup;
	}

	if (contact->blocked
	 || factory->msg->chat_id<=DC_CHAT_ID_LAST_SPECIAL/* Do not send MDNs trash etc.; chats.blocked is already checked by the caller in dc_markseen_msgs() */) {
		goto cleanup;
	}

	if (factory->msg->from_id <= DC_CONTACT_ID_LAST_SPECIAL) {
		goto cleanup;
	}

	clist_append(factory->recipients_names, (void*)((contact->authname&&contact->authname[0])? dc_strdup(contact->authname) : NULL));
	clist_append(factory->recipients_addr,  (void*)dc_strdup(contact->addr));

	load_from(factory);

	factory->timestamp = dc_create_smeared_timestamp(factory->context);
	factory->rfc724_mid = dc_create_outgoing_rfc724_mid(NULL, factory->from_addr);

	success = 1;
	factory->loaded = DC_MF_MDN_LOADED;

cleanup:
	dc_contact_unref(contact);
	return success;
}


/*******************************************************************************
 * Render
 ******************************************************************************/


static int is_file_size_okay(const dc_msg_t* msg)
{
	int      file_size_okay = 1;
	char*    pathNfilename = dc_param_get(msg->param, DC_PARAM_FILE, NULL);
	uint64_t bytes = dc_get_filebytes(msg->context, pathNfilename);

	if (bytes>DC_MSGSIZE_UPPER_LIMIT) {
		file_size_okay = 0;
	}

	free(pathNfilename);
	return file_size_okay;
}


static struct mailmime* build_body_text(char* text)
{
	struct mailmime_fields*  mime_fields = NULL;
	struct mailmime*         message_part = NULL;
	struct mailmime_content* content = NULL;

	content = mailmime_content_new_with_str("text/plain");
	clist_append(content->ct_parameters, mailmime_param_new_with_data("charset", "utf-8")); /* format=flowed currently does not really affect us, see https://www.ietf.org/rfc/rfc3676.txt */

	mime_fields = mailmime_fields_new_encoding(MAILMIME_MECHANISM_8BIT);

	message_part = mailmime_new_empty(content, mime_fields);
	mailmime_set_body_text(message_part, text, strlen(text));

	return message_part;
}


static struct mailmime* build_body_file(const dc_msg_t* msg, const char* base_name, char** ret_file_name_as_sent)
{
	struct mailmime_fields*  mime_fields = NULL;
	struct mailmime*         mime_sub = NULL;
	struct mailmime_content* content = NULL;

	char* pathNfilename = dc_param_get(msg->param, DC_PARAM_FILE, NULL);
	char* mimetype = dc_param_get(msg->param, DC_PARAM_MIMETYPE, NULL);
	char* suffix = dc_get_filesuffix_lc(pathNfilename);
	char* filename_to_send = NULL;
	char* filename_encoded = NULL;

	if (pathNfilename==NULL) {
		goto cleanup;
	}

	/* get file name to use for sending (for privacy purposes, we do not transfer the original filenames eg. for images; these names are normally not needed and contain timesamps, running numbers etc.) */
	if (msg->type==DC_MSG_VOICE) {
		struct tm wanted_struct;
		memcpy(&wanted_struct, localtime(&msg->timestamp), sizeof(struct tm));
		filename_to_send = dc_mprintf("voice-message_%04i-%02i-%02i_%02i-%02i-%02i.%s",
			(int)wanted_struct.tm_year+1900, (int)wanted_struct.tm_mon+1, (int)wanted_struct.tm_mday,
			(int)wanted_struct.tm_hour, (int)wanted_struct.tm_min, (int)wanted_struct.tm_sec,
			suffix? suffix : "dat");
	}
	else if (msg->type==DC_MSG_AUDIO) {
		filename_to_send = dc_get_filename(pathNfilename);
	}
	else if (msg->type==DC_MSG_IMAGE || msg->type==DC_MSG_GIF) {
		if (base_name==NULL) {
			base_name = "image";
		}
		filename_to_send = dc_mprintf("%s.%s", base_name, suffix? suffix : "dat");
	}
	else if (msg->type==DC_MSG_VIDEO) {
		filename_to_send = dc_mprintf("video.%s", suffix? suffix : "dat");
	}
	else {
		filename_to_send = dc_get_filename(pathNfilename);
	}

	/* check mimetype */
	if (mimetype==NULL && suffix!=NULL) {
		if (strcmp(suffix, "png")==0) {
			mimetype = dc_strdup("image/png");
		}
		else if (strcmp(suffix, "jpg")==0 || strcmp(suffix, "jpeg")==0 || strcmp(suffix, "jpe")==0) {
			mimetype = dc_strdup("image/jpeg");
		}
		else if (strcmp(suffix, "gif")==0) {
			mimetype = dc_strdup("image/gif");
		}
		else {
			mimetype = dc_strdup("application/octet-stream");
		}
	}

	if (mimetype==NULL) {
		goto cleanup;
	}

	/* create mime part, for Content-Disposition, see RFC 2183.
	`Content-Disposition: attachment` seems not to make a difference to `Content-Disposition: inline` at least on tested Thunderbird and Gma'l in 2017.
	But I've heard about problems with inline and outl'k, so we just use the attachment-type until we run into other problems ... */
	int needs_ext = dc_needs_ext_header(filename_to_send);

	mime_fields = mailmime_fields_new_filename(MAILMIME_DISPOSITION_TYPE_ATTACHMENT,
		needs_ext? NULL : dc_strdup(filename_to_send), MAILMIME_MECHANISM_BASE64);

	if (needs_ext) {
		for (clistiter* cur1 = clist_begin(mime_fields->fld_list); cur1!=NULL; cur1 = clist_next(cur1)) {
			struct mailmime_field* field = (struct mailmime_field*)clist_content(cur1);
			if (field && field->fld_type==MAILMIME_FIELD_DISPOSITION && field->fld_data.fld_disposition)
			{
				struct mailmime_disposition* file_disposition = field->fld_data.fld_disposition;
				if (file_disposition)
				{
					struct mailmime_disposition_parm* parm = mailmime_disposition_parm_new(
						MAILMIME_DISPOSITION_PARM_PARAMETER, NULL, NULL, NULL, NULL, 0,
						mailmime_parameter_new(strdup("filename*"), dc_encode_ext_header(filename_to_send)));
					if (parm) {
						clist_append(file_disposition->dsp_parms, parm);
					}
				}

				break;
			}
		}
	}

	content = mailmime_content_new_with_str(mimetype);
	clist_append(content->ct_parameters, mailmime_param_new_with_data("name",
			(filename_encoded=dc_encode_header_words(filename_to_send))));

	mime_sub = mailmime_new_empty(content, mime_fields);

	mailmime_set_body_file(mime_sub, dc_get_abs_path(msg->context, pathNfilename));

	if (ret_file_name_as_sent) {
		*ret_file_name_as_sent = dc_strdup(filename_to_send);
	}

cleanup:
	free(pathNfilename);
	free(mimetype);
	free(filename_to_send);
	free(filename_encoded);
	free(suffix);
	return mime_sub;
}


static char* get_subject(const dc_chat_t* chat, const dc_msg_t* msg, int afwd_email)
{
	dc_context_t* context = chat? chat->context : NULL;
	char*         ret = NULL;
	char*         raw_subject = dc_msg_get_summarytext_by_raw(msg->type, msg->text, msg->param, DC_APPROX_SUBJECT_CHARS, context);
	const char*   fwd = afwd_email? "Fwd: " : "";

	if (dc_param_get_int(msg->param, DC_PARAM_CMD, 0)==DC_CMD_AUTOCRYPT_SETUP_MESSAGE)
	{
		ret = dc_stock_str(context, DC_STR_AC_SETUP_MSG_SUBJECT); /* do not add the "Chat:" prefix for setup messages */
	}
	else if (DC_CHAT_TYPE_IS_MULTI(chat->type))
	{
		ret = dc_mprintf(DC_CHAT_PREFIX " %s: %s%s", chat->name, fwd, raw_subject);
	}
	else
	{
		ret = dc_mprintf(DC_CHAT_PREFIX " %s%s", fwd, raw_subject);
	}

	free(raw_subject);
	return ret;
}


int dc_mimefactory_render(dc_mimefactory_t* factory)
{
	struct mailimf_fields* imf_fields = NULL;
	struct mailmime*       message = NULL;
	char*                  message_text = NULL;
	char*                  message_text2 = NULL;
	char*                  subject_str = NULL;
	int                    afwd_email = 0;
	int                    col = 0;
	int                    success = 0;
	int                    parts = 0;
	int                    e2ee_guaranteed = 0;
	int                    min_verified = DC_NOT_VERIFIED;
	int                    force_plaintext = 0; // 1=add Autocrypt-header (needed eg. for handshaking), 2=no Autocrypte-header (used for MDN)
	char*                  grpimage = NULL;
	dc_e2ee_helper_t       e2ee_helper;
	memset(&e2ee_helper, 0, sizeof(dc_e2ee_helper_t));

	if (factory==NULL || factory->loaded==DC_MF_NOTHING_LOADED || factory->out/*call empty() before*/) {
		set_error(factory, "Invalid use of mimefactory-object.");
		goto cleanup;
	}

	/* create basic mail
	 *************************************************************************/

	{
		struct mailimf_mailbox_list* from = mailimf_mailbox_list_new_empty();
		mailimf_mailbox_list_add(from, mailimf_mailbox_new(factory->from_displayname? dc_encode_header_words(factory->from_displayname) : NULL, dc_strdup(factory->from_addr)));

		struct mailimf_address_list* to = NULL;
		if (factory->recipients_names && factory->recipients_addr && clist_count(factory->recipients_addr)>0) {
			clistiter *iter1, *iter2;
			to = mailimf_address_list_new_empty();
			for (iter1=clist_begin(factory->recipients_names),iter2=clist_begin(factory->recipients_addr);  iter1!=NULL&&iter2!=NULL;  iter1=clist_next(iter1),iter2=clist_next(iter2)) {
				const char* name = clist_content(iter1);
				const char* addr = clist_content(iter2);
				mailimf_address_list_add(to, mailimf_address_new(MAILIMF_ADDRESS_MAILBOX, mailimf_mailbox_new(name? dc_encode_header_words(name) : NULL, dc_strdup(addr)), NULL));
			}
		}

		clist* references_list = NULL;
		if (factory->references && factory->references[0]) {
			references_list = dc_str_to_clist(factory->references, " ");
		}

		clist* in_reply_to_list = NULL;
		if (factory->in_reply_to && factory->in_reply_to[0]) {
			in_reply_to_list = dc_str_to_clist(factory->in_reply_to, " ");
		}

		imf_fields = mailimf_fields_new_with_data_all(mailimf_get_date(factory->timestamp), from,
			NULL /* sender */, NULL /* reply-to */,
			to, NULL /* cc */, NULL /* bcc */, dc_strdup(factory->rfc724_mid), in_reply_to_list,
			references_list /* references */,
			NULL /* subject set later */);

		/* Add a X-Mailer header. This is only informational for debugging and may be removed in the release.
		We do not rely on this header as it may be removed by MTAs. */
		mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("X-Mailer"),
			dc_mprintf("Delta Chat %s%s%s",
			DC_VERSION_STR,
			factory->context->os_name? " for " : "",
			factory->context->os_name? factory->context->os_name : "")));

		mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Version"), strdup("1.0"))); /* mark message as being sent by a messenger */

		if (factory->req_mdn) {
			/* we use "Chat-Disposition-Notification-To" as replies to "Disposition-Notification-To" are weird in many cases, are just freetext and/or do not follow any standard. */
			mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Disposition-Notification-To"), strdup(factory->from_addr)));
		}

		message = mailmime_new_message_data(NULL);
		mailmime_set_imf_fields(message, imf_fields);
	}

	if (factory->loaded==DC_MF_MSG_LOADED)
	{
		/* Render a normal message
		 *********************************************************************/

		dc_chat_t* chat = factory->chat;
		dc_msg_t*  msg  = factory->msg;

		struct mailmime* meta_part = NULL;
		char* placeholdertext = NULL;

		if (chat->type==DC_CHAT_TYPE_VERIFIED_GROUP) {
			mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Verified"), strdup("1")));
			force_plaintext   = 0;
			e2ee_guaranteed   = 1;
			min_verified      = DC_BIDIRECT_VERIFIED;
		}
		else {
			if ((force_plaintext = dc_param_get_int(factory->msg->param, DC_PARAM_FORCE_PLAINTEXT, 0))==0) {
				e2ee_guaranteed = dc_param_get_int(factory->msg->param, DC_PARAM_GUARANTEE_E2EE, 0);
			}
		}

		/* build header etc. */
		int command = dc_param_get_int(msg->param, DC_PARAM_CMD, 0);
		if (DC_CHAT_TYPE_IS_MULTI(chat->type))
		{
			mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Group-ID"), dc_strdup(chat->grpid)));
			mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Group-Name"), dc_encode_header_words(chat->name)));


			if (command==DC_CMD_MEMBER_REMOVED_FROM_GROUP)
			{
				char* email_to_remove = dc_param_get(msg->param, DC_PARAM_CMD_ARG, NULL);
				if (email_to_remove) {
					mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Group-Member-Removed"), email_to_remove));
				}
			}
			else if (command==DC_CMD_MEMBER_ADDED_TO_GROUP)
			{
				char* email_to_add = dc_param_get(msg->param, DC_PARAM_CMD_ARG, NULL);
				if (email_to_add) {
					mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Group-Member-Added"), email_to_add));
					grpimage = dc_param_get(chat->param, DC_PARAM_PROFILE_IMAGE, NULL);
				}

				if (dc_param_get_int(msg->param, DC_PARAM_CMD_ARG2, 0)&DC_FROM_HANDSHAKE) {
					dc_log_info(msg->context, 0, "sending secure-join message '%s' >>>>>>>>>>>>>>>>>>>>>>>>>", "vg-member-added");
					mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Secure-Join"), strdup("vg-member-added")));
				}
			}
			else if (command==DC_CMD_GROUPNAME_CHANGED)
			{
				mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Group-Name-Changed"), strdup("1")));
			}
			else if (command==DC_CMD_GROUPIMAGE_CHANGED)
			{
				grpimage = dc_param_get(msg->param, DC_PARAM_CMD_ARG, NULL);
				if (grpimage==NULL) {
					mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Group-Image"), dc_strdup("0")));
				}
			}
		}

		if (command==DC_CMD_AUTOCRYPT_SETUP_MESSAGE) {
			mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Autocrypt-Setup-Message"), strdup("v1")));
			placeholdertext = dc_stock_str(factory->context, DC_STR_AC_SETUP_MSG_BODY);
		}

		if (command==DC_CMD_SECUREJOIN_MESSAGE) {
			char* step = dc_param_get(msg->param, DC_PARAM_CMD_ARG, NULL);
			if (step) {
				dc_log_info(msg->context, 0, "sending secure-join message '%s' >>>>>>>>>>>>>>>>>>>>>>>>>", step);
				mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Secure-Join"), step/*mailimf takes ownership of string*/));

				char* param2 = dc_param_get(msg->param, DC_PARAM_CMD_ARG2, NULL);
				if (param2) {
					mailimf_fields_add(imf_fields, mailimf_field_new_custom(
						(strcmp(step, "vg-request-with-auth")==0 || strcmp(step, "vc-request-with-auth")==0)?
							strdup("Secure-Join-Auth") : strdup("Secure-Join-Invitenumber"),
						param2/*mailimf takes ownership of string*/));
				}

				char* fingerprint = dc_param_get(msg->param, DC_PARAM_CMD_ARG3, NULL);
				if (fingerprint) {
					mailimf_fields_add(imf_fields, mailimf_field_new_custom(
						strdup("Secure-Join-Fingerprint"),
						fingerprint/*mailimf takes ownership of string*/));
				}

				char* grpid = dc_param_get(msg->param, DC_PARAM_CMD_ARG4, NULL);
				if (grpid) {
					mailimf_fields_add(imf_fields, mailimf_field_new_custom(
						strdup("Secure-Join-Group"),
						grpid/*mailimf takes ownership of string*/));
				}
			}
		}

		if (grpimage)
		{
			dc_msg_t* meta = dc_msg_new_untyped(factory->context);
			meta->type = DC_MSG_IMAGE;
			dc_param_set(meta->param, DC_PARAM_FILE, grpimage);
			char* filename_as_sent = NULL;
			if ((meta_part=build_body_file(meta, "group-image", &filename_as_sent))!=NULL) {
				mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Group-Image"), filename_as_sent/*takes ownership*/));
			}
			dc_msg_unref(meta);
		}

		if (msg->type==DC_MSG_VOICE || msg->type==DC_MSG_AUDIO || msg->type==DC_MSG_VIDEO)
		{
			if (msg->type==DC_MSG_VOICE) {
				mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Voice-Message"), strdup("1")));
			}

			int duration_ms = dc_param_get_int(msg->param, DC_PARAM_DURATION, 0);
			if (duration_ms > 0) {
				mailimf_fields_add(imf_fields, mailimf_field_new_custom(strdup("Chat-Duration"), dc_mprintf("%i", (int)duration_ms)));
			}
		}

		/* add text part - we even add empty text and force a MIME-multipart-message as:
		- some Apps have problems with Non-text in the main part (eg. "Mail" from stock Android)
		- we can add "forward hints" this way
		- it looks better */
		afwd_email = dc_param_exists(msg->param, DC_PARAM_FORWARDED);
		char* fwdhint = NULL;
		if (afwd_email) {
			fwdhint = dc_strdup("---------- Forwarded message ----------" LINEEND "From: Delta Chat" LINEEND LINEEND); /* do not chage this! expected this way in the simplifier to detect forwarding! */
		}

		const char* final_text = NULL;
		if (placeholdertext) {
			final_text = placeholdertext;
		}
		else if (msg->text && msg->text[0]) {
			final_text = msg->text;
		}

		char* footer = factory->selfstatus;
		message_text = dc_mprintf("%s%s%s%s%s",
			fwdhint? fwdhint : "",
			final_text? final_text : "",
			(final_text&&footer&&footer[0])? (LINEEND LINEEND) : "",
			(footer&&footer[0])? ("-- " LINEEND)  : "",
			(footer&&footer[0])? footer       : "");
		struct mailmime* text_part = build_body_text(message_text);
		mailmime_smart_add_part(message, text_part);
		parts++;

		free(fwdhint);
		free(placeholdertext);

		/* add attachment part */
		if (DC_MSG_NEEDS_ATTACHMENT(msg->type)) {
			if (!is_file_size_okay(msg)) {
				char* error = dc_mprintf("Message exceeds the recommended %i MB.", DC_MSGSIZE_MAX_RECOMMENDED/1000/1000);
				set_error(factory, error);
				free(error);
				goto cleanup;
			}

			struct mailmime* file_part = build_body_file(msg, NULL, NULL);
			if (file_part) {
				mailmime_smart_add_part(message, file_part);
				parts++;
			}
		}

		if (parts==0) {
			set_error(factory, "Empty message.");
			goto cleanup;
		}

		if (meta_part) {
			mailmime_smart_add_part(message, meta_part); /* meta parts are only added if there are other parts */
			parts++;
		}
	}
	else if (factory->loaded==DC_MF_MDN_LOADED)
	{
		/* Render a MDN
		 *********************************************************************/

		struct mailmime* multipart = mailmime_multiple_new("multipart/report"); /* RFC 6522, this also requires the `report-type` parameter which is equal to the MIME subtype of the second body part of the multipart/report */
		struct mailmime_content* content = multipart->mm_content_type;
		clist_append(content->ct_parameters, mailmime_param_new_with_data("report-type", "disposition-notification")); /* RFC  */
		mailmime_add_part(message, multipart);

		/* first body part: always human-readable, always REQUIRED by RFC 6522 */
		char *p1 = NULL, *p2 = NULL;
		if (dc_param_get_int(factory->msg->param, DC_PARAM_GUARANTEE_E2EE, 0)) {
			p1 = dc_stock_str(factory->context, DC_STR_ENCRYPTEDMSG); /* we SHOULD NOT spread encrypted subjects, date etc. in potentially unencrypted MDNs */
		}
		else {
			p1 = dc_msg_get_summarytext(factory->msg, DC_APPROX_SUBJECT_CHARS);
		}
		p2 = dc_stock_str_repl_string(factory->context, DC_STR_READRCPT_MAILBODY, p1);
		message_text = dc_mprintf("%s" LINEEND, p2);
		free(p2);
		free(p1);

		struct mailmime* human_mime_part = build_body_text(message_text);
		mailmime_add_part(multipart, human_mime_part);


		/* second body part: machine-readable, always REQUIRED by RFC 6522 */
		message_text2 = dc_mprintf(
			"Reporting-UA: Delta Chat %s" LINEEND
			"Original-Recipient: rfc822;%s" LINEEND
			"Final-Recipient: rfc822;%s" LINEEND
			"Original-Message-ID: <%s>" LINEEND
			"Disposition: manual-action/MDN-sent-automatically; displayed" LINEEND, /* manual-action: the user has configured the MUA to send MDNs (automatic-action implies the receipts cannot be disabled) */
			DC_VERSION_STR,
			factory->from_addr,
			factory->from_addr,
			factory->msg->rfc724_mid);

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
		force_plaintext = DC_FP_NO_AUTOCRYPT_HEADER;
	}
	else
	{
		set_error(factory, "No message loaded.");
		goto cleanup;
	}


	/* Encrypt the message
	 *************************************************************************/

	if (factory->loaded==DC_MF_MDN_LOADED) {
		char* e = dc_stock_str(factory->context, DC_STR_READRCPT); subject_str = dc_mprintf(DC_CHAT_PREFIX " %s", e); free(e);
	}
	else {
		subject_str = get_subject(factory->chat, factory->msg, afwd_email);
	}

	struct mailimf_subject* subject = mailimf_subject_new(dc_encode_header_words(subject_str));
	mailimf_fields_add(imf_fields, mailimf_field_new(MAILIMF_FIELD_SUBJECT, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, subject, NULL, NULL, NULL));

	if (force_plaintext!=DC_FP_NO_AUTOCRYPT_HEADER) {
		dc_e2ee_encrypt(factory->context, factory->recipients_addr, force_plaintext, e2ee_guaranteed, min_verified, message, &e2ee_helper);
	}

	if (e2ee_helper.encryption_successfull) {
		factory->out_encrypted = 1;
	}

	/* create the full mail and return */
	factory->out = mmap_string_new("");
	mailmime_write_mem(factory->out, &col, message);

	//{char* t4=dc_null_terminate(ret->str,ret->len); printf("MESSAGE:\n%s\n",t4);free(t4);}

	success = 1;

cleanup:
	if (message) {
		mailmime_free(message);
	}
	dc_e2ee_thanks(&e2ee_helper); // frees data referenced by "mailmime" but not freed by mailmime_free()
	free(message_text);           // mailmime_set_body_text() does not take ownership of "text"
	free(message_text2);          //   - " --
	free(subject_str);
	free(grpimage);
	return success;
}

