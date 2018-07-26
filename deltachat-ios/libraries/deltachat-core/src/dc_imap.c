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


#include <stdlib.h>
#include <libetpan/libetpan.h>
#include <sys/stat.h>
#include <string.h>
#include <unistd.h>
#include "dc_context.h"
#include "dc_imap.h"
#include "dc_job.h"
#include "dc_loginparam.h"


static int  setup_handle_if_needed   (dc_imap_t*);
static void unsetup_handle           (dc_imap_t*);


/*******************************************************************************
 * Tools
 ******************************************************************************/


static int is_error(dc_imap_t* imap, int code)
{
	if (code==MAILIMAP_NO_ERROR /*0*/
	 || code==MAILIMAP_NO_ERROR_AUTHENTICATED /*1*/
	 || code==MAILIMAP_NO_ERROR_NON_AUTHENTICATED /*2*/)
	{
		return 0;
	}

	if (code==MAILIMAP_ERROR_STREAM /*4*/
	 || code==MAILIMAP_ERROR_PARSE /*5*/)
	{
		dc_log_info(imap->context, 0, "IMAP stream lost; we'll reconnect soon.");
		imap->should_reconnect = 1;
	}

	return 1;
}


static char* get_error_msg(dc_imap_t* imap, const char* what_failed, int code)
{
	char*           stock = NULL;
	dc_strbuilder_t msg;
	dc_strbuilder_init(&msg, 1000);

	switch (code) {
		case MAILIMAP_ERROR_LOGIN:
			stock = dc_stock_str_repl_string(imap->context, DC_STR_CANNOT_LOGIN, imap->imap_user);
			dc_strbuilder_cat(&msg, stock);
			break;

		default:
			dc_strbuilder_catf(&msg, "%s, IMAP-error #%i", what_failed, code);
			break;
	}
	free(stock);
	stock = NULL;

	if (imap->etpan->imap_response) {
		dc_strbuilder_cat(&msg, "\n\n");
		stock = dc_stock_str_repl_string2(imap->context, DC_STR_SERVER_RESPONSE, imap->imap_server, imap->etpan->imap_response);
		dc_strbuilder_cat(&msg, stock);
	}
	free(stock);
	stock = NULL;

	return msg.buf;
}


static void get_config_lastseenuid(dc_imap_t* imap, const char* folder, uint32_t* uidvalidity, uint32_t* lastseenuid)
{
	*uidvalidity = 0;
	*lastseenuid = 0;

	char* key = dc_mprintf("imap.mailbox.%s", folder);
	char* val1 = imap->get_config(imap, key, NULL), *val2 = NULL, *val3 = NULL;
	if (val1)
	{
		/* the entry has the format `imap.mailbox.<folder>=<uidvalidity>:<lastseenuid>` */
		val2 = strchr(val1, ':');
		if (val2)
		{
			*val2 = 0;
			val2++;

			val3 = strchr(val2, ':');
			if (val3) { *val3 = 0; /* ignore everything bethind an optional second colon to allow future enhancements */ }

			*uidvalidity = atol(val1);
			*lastseenuid = atol(val2);
		}
	}
	free(val1); /* val2 and val3 are only pointers inside val1 and MUST NOT be free()'d */
	free(key);
}


static void set_config_lastseenuid(dc_imap_t* imap, const char* folder, uint32_t uidvalidity, uint32_t lastseenuid)
{
	char* key = dc_mprintf("imap.mailbox.%s", folder);
	char* val = dc_mprintf("%lu:%lu", uidvalidity, lastseenuid);
	imap->set_config(imap, key, val);
	free(val);
	free(key);
}


/*******************************************************************************
 * Handle folders
 ******************************************************************************/


static int get_folder_meaning(const dc_imap_t* imap, struct mailimap_mbx_list_flags* flags, const char* folder_name, bool force_fallback)
{
	#define MEANING_NORMAL       1
	#define MEANING_INBOX        2
	#define MEANING_IGNORE       3
	#define MEANING_SENT_OBJECTS 4

	char* lower = NULL;
	int   ret_meaning = MEANING_NORMAL;

	if (!force_fallback && (imap->has_xlist || flags!=NULL))
	{
		/* We check for flags if we get some (LIST may also return some, see https://tools.ietf.org/html/rfc6154 )
		or if has_xlist is set.  However, we also allow a NULL-pointer for "no flags" if has_xlist is true. */
		if (flags && flags->mbf_oflags)
		{
			clistiter* iter2;
			for (iter2=clist_begin(flags->mbf_oflags); iter2!=NULL; iter2=clist_next(iter2))
			{
				struct mailimap_mbx_list_oflag* oflag = (struct mailimap_mbx_list_oflag*)clist_content(iter2);
				switch (oflag->of_type)
				{
					case MAILIMAP_MBX_LIST_OFLAG_FLAG_EXT:
						if (strcasecmp(oflag->of_flag_ext, "spam")==0
						 || strcasecmp(oflag->of_flag_ext, "trash")==0
						 || strcasecmp(oflag->of_flag_ext, "drafts")==0
						 || strcasecmp(oflag->of_flag_ext, "junk")==0)
						{
							ret_meaning = MEANING_IGNORE;
						}
						else if (strcasecmp(oflag->of_flag_ext, "sent")==0)
						{
							ret_meaning = MEANING_SENT_OBJECTS;
						}
						else if (strcasecmp(oflag->of_flag_ext, "inbox")==0)
						{
							ret_meaning = MEANING_INBOX;
						}
						break;
				}
			}
		}

		if (ret_meaning==MEANING_NORMAL && strcasecmp(folder_name, "INBOX")==0) {
			ret_meaning = MEANING_INBOX;
		}
	}
	else
	{
		/* we have no flag list; try some known default names */
		lower = dc_strlower(folder_name);
		if (strcmp(lower, "spam")==0
		 || strcmp(lower, "junk")==0
		 || strcmp(lower, "indésirables")==0 /* fr */

		 || strcmp(lower, "trash")==0
		 || strcmp(lower, "deleted")==0
		 || strcmp(lower, "deleted items")==0
		 || strcmp(lower, "papierkorb")==0   /* de */
		 || strcmp(lower, "corbeille")==0    /* fr */
		 || strcmp(lower, "papelera")==0     /* es */
		 || strcmp(lower, "papperskorg")==0  /* sv */

		 || strcmp(lower, "drafts")==0
		 || strcmp(lower, "entwürfe")==0     /* de */
		 || strcmp(lower, "brouillons")==0   /* fr */
		 || strcmp(lower, "borradores")==0   /* es */
		 || strcmp(lower, "utkast")==0       /* sv */
		 )
		{
			ret_meaning = MEANING_IGNORE;
		}
		else if (strcmp(lower, "inbox")==0) /* the "INBOX" foldername is IMAP-standard */
		{
			ret_meaning = MEANING_INBOX;
		}
		else if (strcmp(lower, "sent")==0 || strcmp(lower, "sent objects")==0 || strcmp(lower, "gesendet")==0)
		{
			ret_meaning = MEANING_SENT_OBJECTS;
		}
	}

	free(lower);
	return ret_meaning;
}


typedef struct dc_imapfolder_t
{
	char* name_to_select;
	char* name_utf8;
	int   meaning;
} dc_imapfolder_t;


static clist* list_folders(dc_imap_t* imap)
{
	clist*     imap_list = NULL;
	clistiter* iter1 = NULL;
	clist *    ret_list = clist_new();
	int        r = 0;
	int        xlist_works = 0;

	if (imap==NULL || imap->etpan==NULL) {
		goto cleanup;
	}

	/* the "*" not only gives us the folders from the main directory, but also all subdirectories; so the resulting foldernames may contain
	delimiters as "folder/subdir/subsubdir" etc.  However, as we do not really use folders, this is just fine (otherwise we'd implement this
	functinon recursively. */
	if (imap->has_xlist)  {
		r = mailimap_xlist(imap->etpan, "", "*", &imap_list);
	}
	else {
		r = mailimap_list(imap->etpan, "", "*", &imap_list);
	}

	if (is_error(imap, r) || imap_list==NULL) {
		imap_list = NULL;
		dc_log_warning(imap->context, 0, "Cannot get folder list.");
		goto cleanup;
	}

	if (clist_count(imap_list)<=0) {
		dc_log_warning(imap->context, 0, "Folder list is empty.");
		goto cleanup;
	}

	//default IMAP delimiter if none is returned by the list command
	imap->imap_delimiter = '.';
	for (iter1 = clist_begin(imap_list); iter1!=NULL ; iter1 = clist_next(iter1))
	{
		struct mailimap_mailbox_list* imap_folder = (struct mailimap_mailbox_list*)clist_content(iter1);
		if (imap_folder->mb_delimiter) {
			/* Set IMAP delimiter */
			imap->imap_delimiter = imap_folder->mb_delimiter;
		}

		dc_imapfolder_t* ret_folder = calloc(1, sizeof(dc_imapfolder_t));

		if (strcasecmp(imap_folder->mb_name, "INBOX")==0) {
			/* Force upper case INBOX as we also use it directly this way; a unified name is needed as we use the folder name to remember the last uid.
			Servers may return any case, however, all variants MUST lead to the same INBOX, see RFC 3501 5.1 */
			ret_folder->name_to_select = dc_strdup("INBOX");
		}
		else {
			ret_folder->name_to_select = dc_strdup(imap_folder->mb_name);
		}

		ret_folder->name_utf8      = dc_decode_modified_utf7(imap_folder->mb_name, 0);
		ret_folder->meaning        = get_folder_meaning(imap, imap_folder->mb_flag, ret_folder->name_utf8, false);

		if (ret_folder->meaning==MEANING_IGNORE || ret_folder->meaning==MEANING_SENT_OBJECTS /*MEANING_INBOX is no hint for a working XLIST*/) {
			xlist_works = 1;
		}

		clist_append(ret_list, (void*)ret_folder);
	}

	/* at least my own server claims that it support XLIST but does not return folder flags. So, if we did not get a single
	flag, fall back to the default behaviour */
	if (!xlist_works) {
		for (iter1 = clist_begin(ret_list); iter1!=NULL ; iter1 = clist_next(iter1))
		{
			dc_imapfolder_t* ret_folder = (struct dc_imapfolder_t*)clist_content(iter1);
			ret_folder->meaning = get_folder_meaning(imap, NULL, ret_folder->name_utf8, true);
		}
	}

cleanup:
	if (imap_list) {
		mailimap_list_result_free(imap_list);
	}
	return ret_list;
}


static void free_folders(clist* folders)
{
	if (folders) {
		clistiter* iter1;
		for (iter1 = clist_begin(folders); iter1!=NULL ; iter1 = clist_next(iter1)) {
			dc_imapfolder_t* ret_folder = (struct dc_imapfolder_t*)clist_content(iter1);
			free(ret_folder->name_to_select);
			free(ret_folder->name_utf8);
			free(ret_folder);
		}
		clist_free(folders);
	}
}


static int init_chat_folders(dc_imap_t* imap)
{
	int        success = 0;
	clist*     folder_list = NULL;
	clistiter* iter1;
	char*      normal_folder = NULL;
	char*      sent_folder = NULL;
	char*      chats_folder = NULL;

	if (imap==NULL || imap->etpan==NULL) {
		goto cleanup;
	}

	if (imap->sent_folder && imap->sent_folder[0]) {
		success = 1;
		goto cleanup;
	}

	free(imap->sent_folder);
	imap->sent_folder = NULL;

	free(imap->moveto_folder);
	imap->moveto_folder = NULL;
	//this sets imap->imap_delimiter as side-effect
	folder_list = list_folders(imap);

	//as a fallback, the chats_folder is created under INBOX as required e.g. for DomainFactory
	char fallback_folder[64];
	snprintf(fallback_folder, sizeof(fallback_folder), "INBOX%c%s", imap->imap_delimiter, DC_CHATS_FOLDER);

	for (iter1 = clist_begin(folder_list); iter1!=NULL ; iter1 = clist_next(iter1)) {
		dc_imapfolder_t* folder = (struct dc_imapfolder_t*)clist_content(iter1);
		if (strcmp(folder->name_utf8, DC_CHATS_FOLDER)==0 || strcmp(folder->name_utf8, fallback_folder)==0) {
			chats_folder = dc_strdup(folder->name_to_select);
			break;
		}
		else if (folder->meaning==MEANING_SENT_OBJECTS) {
			sent_folder = dc_strdup(folder->name_to_select);
		}
		else if (folder->meaning==MEANING_NORMAL && normal_folder==NULL) {
			normal_folder = dc_strdup(folder->name_to_select);
		}
	}

	if (chats_folder==NULL && (imap->server_flags&DC_NO_MOVE_TO_CHATS)==0) {
		dc_log_info(imap->context, 0, "Creating IMAP-folder \"%s\"...", DC_CHATS_FOLDER);
		int r = mailimap_create(imap->etpan, DC_CHATS_FOLDER);
		if (is_error(imap, r)) {
			dc_log_warning(imap->context, 0, "Cannot create IMAP-folder, using trying INBOX subfolder.");
			r = mailimap_create(imap->etpan, fallback_folder);
			if (is_error(imap, r)) {
				/* continue on errors, we'll just use a different folder then */
				dc_log_warning(imap->context, 0, "Cannot create IMAP-folder, using default.");
			}
			else {
				chats_folder = dc_strdup(fallback_folder);
				dc_log_info(imap->context, 0, "IMAP-folder created (inbox subfolder).");
			}
		}
		else {
			chats_folder = dc_strdup(DC_CHATS_FOLDER);
			dc_log_info(imap->context, 0, "IMAP-folder created.");
		}
	}

	/* Subscribe to the created folder.  Otherwise, although a top-level folder, if clients use LSUB for listing, the created folder may be hidden.
	(we could also do this directly after creation, however, we forgot this in versions <v0.1.19 */
	if (chats_folder && imap->get_config(imap, "imap.subscribedToChats", NULL)==NULL) {
		mailimap_subscribe(imap->etpan, chats_folder);
		imap->set_config(imap, "imap.subscribedToChats", "1");
	}

	if (chats_folder) {
		imap->moveto_folder = dc_strdup(chats_folder);
		imap->sent_folder   = dc_strdup(chats_folder);
		success = 1;
	}
	else if (sent_folder) {
		imap->sent_folder = dc_strdup(sent_folder);
		success = 1;
	}
	else if (normal_folder) {
		imap->sent_folder = dc_strdup(normal_folder);
		success = 1;
	}

cleanup:
	free_folders(folder_list);
	free(chats_folder);
	free(sent_folder);
	free(normal_folder);
	return success;
}


static int select_folder(dc_imap_t* imap, const char* folder /*may be NULL*/)
{
	if (imap==NULL) {
		return 0;
	}

	if (imap->etpan==NULL) {
		imap->selected_folder[0] = 0;
		imap->selected_folder_needs_expunge = 0;
		return 0;
	}

	/* if there is a new folder and the new folder is equal to the selected one, there's nothing to do.
	if there is _no_ new folder, we continue as we might want to expunge below.  */
	if (folder && strcmp(imap->selected_folder, folder)==0) {
		return 1;
	}

	/* deselect existing folder, if needed (it's also done implicitly by SELECT, however, without EXPUNGE then) */
	if (imap->selected_folder_needs_expunge) {
		if (imap->selected_folder[0]) {
			dc_log_info(imap->context, 0, "Expunge messages in \"%s\".", imap->selected_folder);
			mailimap_close(imap->etpan); /* a CLOSE-SELECT is considerably faster than an EXPUNGE-SELECT, see https://tools.ietf.org/html/rfc3501#section-6.4.2 */
		}
		imap->selected_folder_needs_expunge = 0;
	}

	/* select new folder */
	if (folder) {
		int r = mailimap_select(imap->etpan, folder);
		if (is_error(imap, r) || imap->etpan->imap_selection_info==NULL) {
			imap->selected_folder[0] = 0;
			return 0;
		}
	}

	free(imap->selected_folder);
	imap->selected_folder = dc_strdup(folder);
	return 1;
}


static uint32_t search_uid(dc_imap_t* imap, const char* message_id)
{
	/* Search Message-ID in all folders.
	On success, the folder containing the message is selected and the UID is returned.
	On failure, 0 is returned and any or none folder is selected. */
	clist*                      folders = list_folders(imap);
	clist*                      search_result = NULL;
	clistiter*                  cur = NULL;
	clistiter*                  cur2 = NULL;
	struct mailimap_search_key* key = mailimap_search_key_new_header(strdup("Message-ID"), dc_mprintf("<%s>", message_id));
	uint32_t                    uid = 0;

	for (cur = clist_begin(folders); cur!=NULL ; cur = clist_next(cur))
	{
		dc_imapfolder_t* folder = (dc_imapfolder_t*)clist_content(cur);
		if (select_folder(imap, folder->name_to_select))
		{
			int r = mailimap_uid_search(imap->etpan, "utf-8", key, &search_result);
			if (!is_error(imap, r) && search_result) {
				if ((cur2=clist_begin(search_result))!=NULL) {
					uint32_t* ptr_uid = (uint32_t *)clist_content(cur2);
					if (ptr_uid) {
						uid = *ptr_uid;
					}
				}
				mailimap_search_result_free(search_result);
				search_result = NULL;
				if (uid) {
					goto cleanup;
				}
			}
		}
	}

cleanup:
	if (search_result) { mailimap_search_result_free(search_result); }
	if (key) { mailimap_search_key_free(key); }
	free_folders(folders);
	return uid;
}


/*******************************************************************************
 * Fetch Messages
 ******************************************************************************/


static uint32_t peek_uid(struct mailimap_msg_att* msg_att)
{
	/* search the UID in a list of attributes returned by a FETCH command */
	clistiter* iter1;
	for (iter1=clist_begin(msg_att->att_list); iter1!=NULL; iter1=clist_next(iter1))
	{
		struct mailimap_msg_att_item* item = (struct mailimap_msg_att_item*)clist_content(iter1);
		if (item)
		{
			if (item->att_type==MAILIMAP_MSG_ATT_ITEM_STATIC)
			{
				if (item->att_data.att_static->att_type==MAILIMAP_MSG_ATT_UID)
				{
					return item->att_data.att_static->att_data.att_uid;
				}
			}
		}
	}

	return 0;
}


static char* unquote_rfc724_mid(const char* in)
{
	/* remove < and > from the given message id */
	char* out = dc_strdup(in);
	int   out_len = strlen(out);
	if (out_len > 2) {
		if (out[0]=='<')         { out[0] = ' '; }
		if (out[out_len-1]=='>') { out[out_len-1] = ' '; }
		dc_trim(out);
	}
	return out;
}


static const char* peek_rfc724_mid(struct mailimap_msg_att* msg_att)
{
	if (msg_att==NULL) {
		return NULL;
	}

	/* search the UID in a list of attributes returned by a FETCH command */
	clistiter* iter1;
	for (iter1=clist_begin(msg_att->att_list); iter1!=NULL; iter1=clist_next(iter1))
	{
		struct mailimap_msg_att_item* item = (struct mailimap_msg_att_item*)clist_content(iter1);
		if (item)
		{
			if (item->att_type==MAILIMAP_MSG_ATT_ITEM_STATIC)
			{
				if (item->att_data.att_static->att_type==MAILIMAP_MSG_ATT_ENVELOPE)
				{
					struct mailimap_envelope* env = item->att_data.att_static->att_data.att_env;
					if (env && env->env_message_id) {
						return env->env_message_id;
					}
				}
			}
		}
	}

	return NULL;
}


static int peek_flag_keyword(struct mailimap_msg_att* msg_att, const char* flag_keyword)
{
	/* search $MDNSent in a list of attributes returned by a FETCH command */
	if (msg_att==NULL || msg_att->att_list==NULL || flag_keyword==NULL) {
		return 0;
	}

	clistiter *iter1, *iter2;
	for (iter1=clist_begin(msg_att->att_list); iter1!=NULL; iter1=clist_next(iter1))
	{
		struct mailimap_msg_att_item* item = (struct mailimap_msg_att_item*)clist_content(iter1);
		if (item)
		{
			if (item->att_type==MAILIMAP_MSG_ATT_ITEM_DYNAMIC)
			{
				if (item->att_data.att_dyn->att_list /*I've seen NULL here ...*/)
				{
					for (iter2=clist_begin(item->att_data.att_dyn->att_list); iter2!=NULL ; iter2=clist_next(iter2))
					{
						struct mailimap_flag_fetch* flag_fetch =(struct mailimap_flag_fetch*) clist_content(iter2);
						if (flag_fetch && flag_fetch->fl_type==MAILIMAP_FLAG_FETCH_OTHER)
						{
							struct mailimap_flag* flag = flag_fetch->fl_flag;
							if (flag)
							{
								if (flag->fl_type==MAILIMAP_FLAG_KEYWORD && flag->fl_data.fl_keyword!=NULL
								 && strcmp(flag->fl_data.fl_keyword, flag_keyword)==0) {
									return 1; /* flag found */
								}
							}
						}
					}
				}
			}
		}
	}
	return 0;
}


static void peek_body(struct mailimap_msg_att* msg_att, char** p_msg, size_t* p_msg_bytes, uint32_t* flags, int* deleted)
{
	if (msg_att==NULL) {
		return;
	}
	/* search body & Co. in a list of attributes returned by a FETCH command */
	clistiter *iter1, *iter2;
	for (iter1=clist_begin(msg_att->att_list); iter1!=NULL; iter1=clist_next(iter1))
	{
		struct mailimap_msg_att_item* item = (struct mailimap_msg_att_item*)clist_content(iter1);
		if (item)
		{
			if (item->att_type==MAILIMAP_MSG_ATT_ITEM_DYNAMIC)
			{
				if (item->att_data.att_dyn->att_list /*I've seen NULL here ...*/)
				{
					for (iter2=clist_begin(item->att_data.att_dyn->att_list); iter2!=NULL ; iter2=clist_next(iter2))
					{
						struct mailimap_flag_fetch* flag_fetch =(struct mailimap_flag_fetch*) clist_content(iter2);
						if (flag_fetch && flag_fetch->fl_type==MAILIMAP_FLAG_FETCH_OTHER)
						{
							struct mailimap_flag* flag = flag_fetch->fl_flag;
							if (flag)
							{
								if (flag->fl_type==MAILIMAP_FLAG_SEEN) {
									*flags |= DC_IMAP_SEEN;
								}
								else if (flag->fl_type==MAILIMAP_FLAG_DELETED) {
									*deleted = 1;
								}
							}
						}
					}
				}
			}
			else if (item->att_type==MAILIMAP_MSG_ATT_ITEM_STATIC)
			{
				if (item->att_data.att_static->att_type==MAILIMAP_MSG_ATT_BODY_SECTION)
				{
					*p_msg = item->att_data.att_static->att_data.att_body_section->sec_body_part;
					*p_msg_bytes = item->att_data.att_static->att_data.att_body_section->sec_length;
				}
			}
		}
	}
}


static int fetch_single_msg(dc_imap_t* imap, const char* folder, uint32_t server_uid)
{
	/* the function returns:
	    0  the caller should try over again later
	or  1  if the messages should be treated as received, the caller should not try to read the message again (even if no database entries are returned) */
	char*       msg_content = NULL;
	size_t      msg_bytes = 0;
	int         r = 0;
	int         retry_later = 0;
	int         deleted = 0;
	uint32_t    flags = 0;
	clist*      fetch_result = NULL;
	clistiter*  cur;

	if (imap==NULL) {
		goto cleanup;
	}

	if (imap->etpan==NULL) {
		goto cleanup;
	}


	{
		struct mailimap_set* set = mailimap_set_new_single(server_uid);
			r = mailimap_uid_fetch(imap->etpan, set, imap->fetch_type_body, &fetch_result);
		mailimap_set_free(set);
	}

	if (is_error(imap, r) || fetch_result==NULL) {
		fetch_result = NULL;
		dc_log_warning(imap->context, 0, "Error #%i on fetching message #%i from folder \"%s\"; retry=%i.", (int)r, (int)server_uid, folder, (int)imap->should_reconnect);
		if (imap->should_reconnect) {
			retry_later = 1; /* maybe we should also retry on other errors, however, we should check this carefully, as this may result in a dead lock! */
		}
		goto cleanup; /* this is an error that should be recovered; the caller should try over later to fetch the message again (if there is no such message, we simply get an empty result) */
	}

	if ((cur=clist_begin(fetch_result))==NULL) {
		dc_log_warning(imap->context, 0, "Message #%i does not exist in folder \"%s\".", (int)server_uid, folder);
		goto cleanup; /* server response is fine, however, there is no such message, do not try to fetch the message again */
	}

	struct mailimap_msg_att* msg_att = (struct mailimap_msg_att*)clist_content(cur);
	peek_body(msg_att, &msg_content, &msg_bytes, &flags, &deleted);
	if (msg_content==NULL  || msg_bytes <= 0 || deleted) {
		/* dc_log_warning(imap->context, 0, "Message #%i in folder \"%s\" is empty or deleted.", (int)server_uid, folder); -- this is a quite usual situation, do not print a warning */
		goto cleanup;
	}

	imap->receive_imf(imap, msg_content, msg_bytes, folder, server_uid, flags);

cleanup:

	if (fetch_result) {
		mailimap_fetch_list_free(fetch_result);
	}
	return retry_later? 0 : 1;
}


static int fetch_from_single_folder(dc_imap_t* imap, const char* folder)
{
	int                  r;
	uint32_t             uidvalidity = 0;
	uint32_t             lastseenuid = 0;
	uint32_t             new_lastseenuid = 0;
	clist*               fetch_result = NULL;
	size_t               read_cnt = 0;
	size_t               read_errors = 0;
	clistiter*           cur;
	struct mailimap_set* set;

	if (imap==NULL) {
		goto cleanup;
	}

	if (imap->etpan==NULL) {
		dc_log_info(imap->context, 0, "Cannot fetch from \"%s\" - not connected.", folder);
		goto cleanup;
	}

	if (select_folder(imap, folder)==0) {
		dc_log_warning(imap->context, 0, "Cannot select folder \"%s\".", folder);
		goto cleanup;
	}

	/* compare last seen UIDVALIDITY against the current one */
	get_config_lastseenuid(imap, folder, &uidvalidity, &lastseenuid);
	if (uidvalidity!=imap->etpan->imap_selection_info->sel_uidvalidity)
	{
		/* first time this folder is selected or UIDVALIDITY has changed, init lastseenuid and save it to config */
		if (imap->etpan->imap_selection_info->sel_uidvalidity <= 0) {
			dc_log_error(imap->context, 0, "Cannot get UIDVALIDITY for folder \"%s\".", folder);
			goto cleanup;
		}

		if (imap->etpan->imap_selection_info->sel_has_exists) {
			if (imap->etpan->imap_selection_info->sel_exists <= 0) {
				dc_log_info(imap->context, 0, "Folder \"%s\" is empty.", folder);
				goto cleanup;
			}
			/* `FETCH <message sequence number> (UID)` */
			set = mailimap_set_new_single(imap->etpan->imap_selection_info->sel_exists);
		}
		else {
			/* `FETCH * (UID)` - according to RFC 3501, `*` represents the largest message sequence number; if the mailbox is empty,
			an error resp. an empty list is returned. */
			dc_log_info(imap->context, 0, "EXISTS is missing for folder \"%s\", using fallback.", folder);
			set = mailimap_set_new_single(0);
		}
		r = mailimap_fetch(imap->etpan, set, imap->fetch_type_uid, &fetch_result);
		mailimap_set_free(set);

		if (is_error(imap, r) || fetch_result==NULL || (cur=clist_begin(fetch_result))==NULL) {
			dc_log_info(imap->context, 0, "Empty result returned for folder \"%s\".", folder);
			goto cleanup; /* this might happen if the mailbox is empty an EXISTS does not work */
		}

		struct mailimap_msg_att* msg_att = (struct mailimap_msg_att*)clist_content(cur);
		lastseenuid = peek_uid(msg_att);
		mailimap_fetch_list_free(fetch_result);
		fetch_result = NULL;
		if (lastseenuid <= 0) {
			dc_log_error(imap->context, 0, "Cannot get largest UID for folder \"%s\"", folder);
			goto cleanup;
		}

		/* if the UIDVALIDITY has _changed_, decrease lastseenuid by one to avoid gaps (well add 1 below) */
		if (uidvalidity > 0 && lastseenuid > 1) {
			lastseenuid -= 1;
		}

		/* store calculated uidvalidity/lastseenuid */
		uidvalidity = imap->etpan->imap_selection_info->sel_uidvalidity;
		set_config_lastseenuid(imap, folder, uidvalidity, lastseenuid);
	}

	/* fetch messages with larger UID than the last one seen (`UID FETCH lastseenuid+1:*)`, see RFC 4549 */
	set = mailimap_set_new_interval(lastseenuid+1, 0);
		r = mailimap_uid_fetch(imap->etpan, set, imap->fetch_type_uid, &fetch_result);
	mailimap_set_free(set);

	if (is_error(imap, r) || fetch_result==NULL)
	{
		fetch_result = NULL;
		if (r==MAILIMAP_ERROR_PROTOCOL) {
			dc_log_info(imap->context, 0, "Folder \"%s\" is empty", folder);
			goto cleanup; /* the folder is simply empty, this is no error */
		}
		dc_log_warning(imap->context, 0, "Cannot fetch message list from folder \"%s\".", folder);
		goto cleanup;
	}

	/* go through all mails in folder (this is typically _fast_ as we already have the whole list) */
	for (cur = clist_begin(fetch_result); cur!=NULL ; cur = clist_next(cur))
	{
		struct mailimap_msg_att* msg_att = (struct mailimap_msg_att*)clist_content(cur); /* mailimap_msg_att is a list of attributes: list is a list of message attributes */
		uint32_t cur_uid = peek_uid(msg_att);
		if (cur_uid > 0
		 && cur_uid!=lastseenuid /* `UID FETCH <lastseenuid+1>:*` may include lastseenuid if "*"==lastseenuid */)
		{
			read_cnt++;
			if (fetch_single_msg(imap, folder, cur_uid)==0/* 0=try again later*/) {
				read_errors++;
			}
			else if (cur_uid > new_lastseenuid) {
				new_lastseenuid = cur_uid;
			}

		}
	}

	if (!read_errors && new_lastseenuid > 0) {
		set_config_lastseenuid(imap, folder, uidvalidity, new_lastseenuid);
	}

	/* done */
cleanup:

	if (read_errors) {
		dc_log_warning(imap->context, 0, "%i mails read from \"%s\" with %i errors.", (int)read_cnt, folder, (int)read_errors);
	}
	else {
		dc_log_info(imap->context, 0, "%i mails read from \"%s\".", (int)read_cnt, folder);
	}

	if (fetch_result) {
		mailimap_fetch_list_free(fetch_result);
	}

	return read_cnt;
}


static int fetch_from_all_folders(dc_imap_t* imap)
{
	clist*     folder_list = NULL;
	clistiter* cur = NULL;
	int        total_cnt = 0;

		folder_list = list_folders(imap);

	/* first, read the INBOX, this looks much better on the initial load as the INBOX
	has the most recent mails.  Moreover, this is for speed reasons, as the other folders only have few new messages. */
	for (cur = clist_begin(folder_list); cur!=NULL ; cur = clist_next(cur))
	{
		dc_imapfolder_t* folder = (dc_imapfolder_t*)clist_content(cur);
		if (folder->meaning==MEANING_INBOX) {
			total_cnt += fetch_from_single_folder(imap, folder->name_to_select);
		}
	}

	for (cur = clist_begin(folder_list); cur!=NULL ; cur = clist_next(cur))
	{
		dc_imapfolder_t* folder = (dc_imapfolder_t*)clist_content(cur);
		if (folder->meaning==MEANING_IGNORE) {
			dc_log_info(imap->context, 0, "Ignoring \"%s\".", folder->name_utf8);
		}
		else if (folder->meaning!=MEANING_INBOX) {
			total_cnt += fetch_from_single_folder(imap, folder->name_to_select);
		}
	}

	free_folders(folder_list);

	return total_cnt;
}


/*******************************************************************************
 * Watch thread
 ******************************************************************************/


int dc_imap_fetch(dc_imap_t* imap)
{
	if (imap==NULL || !imap->connected) {
		return 0;
	}

	setup_handle_if_needed(imap);

	#define FULL_FETCH_EVERY_SECONDS (22*60)

	if (time(NULL) - imap->last_fullread_time > FULL_FETCH_EVERY_SECONDS) {
		fetch_from_all_folders(imap);
		imap->last_fullread_time = time(NULL);
	}

	// as during the fetch commands, new messages may arrive, we fetch until we do not
	// get any more. if IDLE is called directly after, there is only a small chance that
	// messages are missed and delayed until the next IDLE call
	while (fetch_from_single_folder(imap, "INBOX") > 0) {
		;
	}

	return 1;
}


static void fake_idle(dc_imap_t* imap)
{
	/* Idle using timeouts. This is also needed if we're not yet configured -
	in this case, we're waiting for a configure job */

	time_t fake_idle_start_time = time(NULL);
	time_t seconds_to_wait = 0;

	dc_log_info(imap->context, 0, "IMAP-fake-IDLEing...");

	int do_fake_idle = 1;
	while (do_fake_idle)
	{
		// wait a moment: every 5 seconds in the first 3 minutes after a new message, after that every 60 seconds
		seconds_to_wait = (time(NULL)-fake_idle_start_time < 3*60)? 5 : 60;
		pthread_mutex_lock(&imap->watch_condmutex);

			int r = 0;
			struct timespec wakeup_at;
			memset(&wakeup_at, 0, sizeof(wakeup_at));
			wakeup_at.tv_sec  = time(NULL)+seconds_to_wait;
			while (imap->watch_condflag==0 && r==0) {
				r = pthread_cond_timedwait(&imap->watch_cond, &imap->watch_condmutex, &wakeup_at); /* unlock mutex -> wait -> lock mutex */
				if (imap->watch_condflag) {
					do_fake_idle = 0;
				}
			}
			imap->watch_condflag = 0;

		pthread_mutex_unlock(&imap->watch_condmutex);

		if (do_fake_idle==0) {
			return;
		}

		// check for new messages. fetch_from_single_folder() has the side-effect that messages
		// are also downloaded, however, typically this would take place in the FETCH command
		// following IDLE otherwise, so this seems okay here.
		if (setup_handle_if_needed(imap)) { // the handle may not be set up if configure is not yet done
			if (fetch_from_single_folder(imap, "INBOX")) {
				do_fake_idle = 0;
			}
		}
		else {
			// if we cannot connect, set the starting time to a small value which will
			// result in larger timeouts (60 instead of 5 seconds) for re-checking the availablility of network.
			// to get the _exact_ moment of re-available network, the ui should call interrupt_idle()
			fake_idle_start_time = 0;
		}
	}
}


void dc_imap_idle(dc_imap_t* imap)
{
	int r = 0;
	int r2 = 0;

	if (imap->can_idle)
	{
		setup_handle_if_needed(imap);

		if (imap->idle_set_up==0 && imap->etpan && imap->etpan->imap_stream) {
			r = mailstream_setup_idle(imap->etpan->imap_stream);
			if (is_error(imap, r)) {
				dc_log_warning(imap->context, 0, "IMAP-IDLE: Cannot setup.");
				fake_idle(imap);
				return;
			}
			imap->idle_set_up = 1;
		}

		if (!imap->idle_set_up || !select_folder(imap, "INBOX")) {
			dc_log_warning(imap->context, 0, "IMAP-IDLE not setup.");
			fake_idle(imap);
			return;
		}

		r = mailimap_idle(imap->etpan);
		if (is_error(imap, r)) {
			dc_log_warning(imap->context, 0, "IMAP-IDLE: Cannot start.");
			fake_idle(imap);
			return;
		}

		// most servers do not allow more than ~28 minutes; stay clearly below that.
		// a good value is 23 minutes.  however, as we do all imap in the same thread,
		// we use a shorter delay to let failed jobs run again from time to time.
		#define IDLE_DELAY_SECONDS (1*60)

		r = mailstream_wait_idle(imap->etpan->imap_stream, IDLE_DELAY_SECONDS);
		r2 = mailimap_idle_done(imap->etpan);

		if (r==MAILSTREAM_IDLE_ERROR /*0*/ || r==MAILSTREAM_IDLE_CANCELLED /*4*/) {
			dc_log_info(imap->context, 0, "IMAP-IDLE wait cancelled, r=%i, r2=%i; we'll reconnect soon.", r, r2);
			imap->should_reconnect = 1;
		}
		else if (r==MAILSTREAM_IDLE_INTERRUPTED /*1*/) {
			dc_log_info(imap->context, 0, "IMAP-IDLE interrupted.");
		}
		else if (r== MAILSTREAM_IDLE_HASDATA /*2*/) {
			dc_log_info(imap->context, 0, "IMAP-IDLE has data.");
		}
		else if (r==MAILSTREAM_IDLE_TIMEOUT /*3*/) {
			dc_log_info(imap->context, 0, "IMAP-IDLE timeout.");
		}
		else {
			dc_log_warning(imap->context, 0, "IMAP-IDLE returns unknown value r=%i, r2=%i.", r, r2);
		}
	}
	else
	{
		fake_idle(imap);
	}
}


void dc_imap_interrupt_idle(dc_imap_t* imap)
{
	if (imap==NULL) {
		return;
	}

	if (imap->can_idle)
	{
		if (imap->etpan && imap->etpan->imap_stream) {
			mailstream_interrupt_idle(imap->etpan->imap_stream);
		}
	}

	// always signal the fake-idle as it may be used if the real-idle is not available for any reasons (no network ...)
	pthread_mutex_lock(&imap->watch_condmutex);
		imap->watch_condflag = 1;
		pthread_cond_signal(&imap->watch_cond);
	pthread_mutex_unlock(&imap->watch_condmutex);
}


/*******************************************************************************
 * Setup handle
 ******************************************************************************/


static int setup_handle_if_needed(dc_imap_t* imap)
{
	int r = 0;
	int success = 0;

	if (imap==NULL || imap->imap_server==NULL) {
		goto cleanup;
	}

    if (imap->should_reconnect) {
		unsetup_handle(imap);
    }

    if (imap->etpan) {
		success = 1;
		goto cleanup;
    }

	if (imap->context->cb(imap->context, DC_EVENT_IS_OFFLINE, 0, 0)!=0) {
		dc_log_error_if(&imap->log_connect_errors, imap->context, DC_ERROR_NO_NETWORK, NULL);
		goto cleanup;
	}

	imap->etpan = mailimap_new(0, NULL);

	mailimap_set_timeout(imap->etpan, DC_IMAP_TIMEOUT_SEC);

	if (imap->server_flags&(DC_LP_IMAP_SOCKET_STARTTLS|DC_LP_IMAP_SOCKET_PLAIN))
	{
		r = mailimap_socket_connect(imap->etpan, imap->imap_server, imap->imap_port);
		if (is_error(imap, r)) {
			dc_log_error_if(&imap->log_connect_errors, imap->context, 0, "Could not connect to IMAP-server %s:%i. (Error #%i)", imap->imap_server, (int)imap->imap_port, (int)r);
			goto cleanup;
		}

		if (imap->server_flags&DC_LP_IMAP_SOCKET_STARTTLS)
		{
			r = mailimap_socket_starttls(imap->etpan);
			if (is_error(imap, r)) {
				dc_log_error_if(&imap->log_connect_errors, imap->context, 0, "Could not connect to IMAP-server %s:%i using STARTTLS. (Error #%i)", imap->imap_server, (int)imap->imap_port, (int)r);
				goto cleanup;
			}
			dc_log_info(imap->context, 0, "IMAP-server %s:%i STARTTLS-connected.", imap->imap_server, (int)imap->imap_port);
		}
		else
		{
			dc_log_info(imap->context, 0, "IMAP-server %s:%i connected.", imap->imap_server, (int)imap->imap_port);
		}
	}
	else
	{
		r = mailimap_ssl_connect(imap->etpan, imap->imap_server, imap->imap_port);
		if (is_error(imap, r)) {
			dc_log_error_if(&imap->log_connect_errors, imap->context, 0, "Could not connect to IMAP-server %s:%i using SSL. (Error #%i)", imap->imap_server, (int)imap->imap_port, (int)r);
			goto cleanup;
		}
		dc_log_info(imap->context, 0, "IMAP-server %s:%i SSL-connected.", imap->imap_server, (int)imap->imap_port);
	}

		/* TODO: There are more authorisation types, see mailcore2/MCIMAPSession.cpp, however, I'm not sure of they are really all needed */
		/*if (imap->server_flags&DC_LP_AUTH_XOAUTH2)
		{
			//TODO: Support XOAUTH2, we "just" need to get the token someway. If we do so, there is no more need for the user to enable
			//https://www.google.com/settings/security/lesssecureapps - however, maybe this is also not needed if the user had enabled 2-factor-authorisation.
			if (mOAuth2Token==NULL) {
				r = MAILIMAP_ERROR_STREAM;
			}
			else {
				r = mailimap_oauth2_authenticate(imap->etpan, imap->imap_use, mOAuth2Token);
			}
		}
		else*/
		{
			/* DC_LP_AUTH_NORMAL or no auth flag set */
			r = mailimap_login(imap->etpan, imap->imap_user, imap->imap_pw);
		}

		if (is_error(imap, r)) {
			char* msg = get_error_msg(imap, "Cannot login", r);
			dc_log_error_if(&imap->log_connect_errors, imap->context, 0, "%s", msg);
			free(msg);
			goto cleanup;
		}

	dc_log_info(imap->context, 0, "IMAP-login as %s ok.", imap->imap_user);

	success = 1;

cleanup:
	if (success==0) {
		unsetup_handle(imap);
	}

	imap->should_reconnect = 0;
	return success;
}


static void unsetup_handle(dc_imap_t* imap)
{
	if (imap==NULL) {
		return;
	}

	if (imap->etpan)
	{
		if (imap->idle_set_up) {
			mailstream_unsetup_idle(imap->etpan->imap_stream);
			imap->idle_set_up = 0;
		}

		if (imap->etpan->imap_stream!=NULL) {
			mailstream_close(imap->etpan->imap_stream); /* not sure, if this is really needed, however, mailcore2 does the same */
			imap->etpan->imap_stream = NULL;
		}

		mailimap_free(imap->etpan);
		imap->etpan = NULL;

		dc_log_info(imap->context, 0, "IMAP disconnected.");
	}

	imap->selected_folder[0] = 0;

	/* we leave sent_folder set; normally this does not change in a normal reconnect; we'll update this folder if we get errors */
}


/*******************************************************************************
 * Connect/Disconnect
 ******************************************************************************/


static void free_connect_param(dc_imap_t* imap)
{
	free(imap->imap_server);
	imap->imap_server = NULL;

	free(imap->imap_user);
	imap->imap_user = NULL;

	free(imap->imap_pw);
	imap->imap_pw = NULL;

	imap->selected_folder[0] = 0;

	free(imap->moveto_folder);
	imap->moveto_folder = NULL;

	free(imap->sent_folder);
	imap->sent_folder = NULL;

	imap->imap_port = 0;
	imap->can_idle  = 0;
	imap->has_xlist = 0;
}


int dc_imap_connect(dc_imap_t* imap, const dc_loginparam_t* lp)
{
	int success = 0;

	if (imap==NULL || lp==NULL || lp->mail_server==NULL || lp->mail_user==NULL || lp->mail_pw==NULL) {
		return 0;
	}

	if (imap->connected) {
		success = 1;
		goto cleanup;
	}

	imap->imap_server  = dc_strdup(lp->mail_server);
	imap->imap_port    = lp->mail_port;
	imap->imap_user    = dc_strdup(lp->mail_user);
	imap->imap_pw      = dc_strdup(lp->mail_pw);
	imap->server_flags = lp->server_flags;

	if (!setup_handle_if_needed(imap)) {
		goto cleanup;
	}

	/* we set the following flags here and not in setup_handle_if_needed() as they must not change during connection */
	imap->can_idle = mailimap_has_idle(imap->etpan);
	imap->has_xlist = mailimap_has_xlist(imap->etpan);

	#ifdef __APPLE__
	imap->can_idle = 0; // HACK to force iOS not to work IMAP-IDLE which does not work for now, see also (*)
	#endif


	if (!imap->skip_log_capabilities
	 && imap->etpan->imap_connection_info && imap->etpan->imap_connection_info->imap_capability)
	{
		/* just log the whole capabilities list (the mailimap_has_*() function also use this list, so this is a good overview on problems) */
		imap->skip_log_capabilities = 1;
		dc_strbuilder_t capinfostr;
		dc_strbuilder_init(&capinfostr, 0);
		clist* list = imap->etpan->imap_connection_info->imap_capability->cap_list;
		if (list) {
			clistiter* cur;
			for(cur = clist_begin(list) ; cur!=NULL ; cur = clist_next(cur)) {
				struct mailimap_capability * cap = clist_content(cur);
				if (cap && cap->cap_type==MAILIMAP_CAPABILITY_NAME) {
					dc_strbuilder_cat(&capinfostr, " ");
					dc_strbuilder_cat(&capinfostr, cap->cap_data.cap_name);
				}
			}
		}
		dc_log_info(imap->context, 0, "IMAP-capabilities:%s", capinfostr.buf);
		free(capinfostr.buf);
	}

	imap->connected = 1;
	success = 1;

cleanup:
	if (success==0) {
		unsetup_handle(imap);
		free_connect_param(imap);
	}
	return success;
}


void dc_imap_disconnect(dc_imap_t* imap)
{
	if (imap==NULL) {
		return;
	}

	if (imap->connected)
	{
		unsetup_handle(imap);
		free_connect_param(imap);
		imap->connected = 0;
	}
}


int dc_imap_is_connected(const dc_imap_t* imap)
{
	return (imap && imap->connected); /* we do not use a LOCK - otherwise, the check may take seconds and is not sufficient for some GUI state updates. */
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


dc_imap_t* dc_imap_new(dc_get_config_t get_config, dc_set_config_t set_config, dc_receive_imf_t receive_imf, void* userData, dc_context_t* context)
{
	dc_imap_t* imap = NULL;

	if ((imap=calloc(1, sizeof(dc_imap_t)))==NULL) {
		exit(25); /* cannot allocate little memory, unrecoverable error */
	}

	imap->log_connect_errors = 1;

	imap->context        = context;
	imap->get_config     = get_config;
	imap->set_config     = set_config;
	imap->receive_imf    = receive_imf;
	imap->userData       = userData;

	pthread_mutex_init(&imap->watch_condmutex, NULL);
	pthread_cond_init(&imap->watch_cond, NULL);

	//imap->enter_watch_wait_time = 0;

	imap->selected_folder = calloc(1, 1);
	imap->moveto_folder   = NULL;
	imap->sent_folder     = NULL;

	/* create some useful objects */
	imap->fetch_type_uid = mailimap_fetch_type_new_fetch_att_list_empty(); /* object to fetch the ID */
	mailimap_fetch_type_new_fetch_att_list_add(imap->fetch_type_uid, mailimap_fetch_att_new_uid());

	imap->fetch_type_message_id = mailimap_fetch_type_new_fetch_att_list_empty();
	mailimap_fetch_type_new_fetch_att_list_add(imap->fetch_type_message_id, mailimap_fetch_att_new_envelope());

	imap->fetch_type_body = mailimap_fetch_type_new_fetch_att_list_empty(); /* object to fetch flags+body */
	mailimap_fetch_type_new_fetch_att_list_add(imap->fetch_type_body, mailimap_fetch_att_new_flags());
	mailimap_fetch_type_new_fetch_att_list_add(imap->fetch_type_body, mailimap_fetch_att_new_body_peek_section(mailimap_section_new(NULL)));

	imap->fetch_type_flags = mailimap_fetch_type_new_fetch_att_list_empty(); /* object to fetch flags only */
	mailimap_fetch_type_new_fetch_att_list_add(imap->fetch_type_flags, mailimap_fetch_att_new_flags());

    return imap;
}


void dc_imap_unref(dc_imap_t* imap)
{
	if (imap==NULL) {
		return;
	}

	dc_imap_disconnect(imap);

	pthread_cond_destroy(&imap->watch_cond);
	pthread_mutex_destroy(&imap->watch_condmutex);
	free(imap->selected_folder);
	if (imap->fetch_type_uid)        { mailimap_fetch_type_free(imap->fetch_type_uid); }
	if (imap->fetch_type_message_id) { mailimap_fetch_type_free(imap->fetch_type_message_id); }
	if (imap->fetch_type_body)       { mailimap_fetch_type_free(imap->fetch_type_body); }
	if (imap->fetch_type_flags)      { mailimap_fetch_type_free(imap->fetch_type_flags); }
	free(imap);
}


int dc_imap_append_msg(dc_imap_t* imap, time_t timestamp, const char* data_not_terminated, size_t data_bytes, char** ret_server_folder, uint32_t* ret_server_uid)
{
	int                        success = 0;
	int                        r  = 0;
	uint32_t                   ret_uidvalidity = 0;
	struct mailimap_flag_list* flag_list = NULL;
	struct mailimap_date_time* imap_date = NULL;

	*ret_server_folder = NULL;

	if (imap==NULL) {
		goto cleanup;
	}

	if (imap->etpan==NULL) {
		goto cleanup;
	}

	dc_log_info(imap->context, 0, "Appending message to IMAP-server...");

	if (!init_chat_folders(imap)) {
		dc_log_error_if(&imap->log_connect_errors, imap->context, 0, "Cannot find out IMAP-sent-folder.");
		goto cleanup;
	}

	if (!select_folder(imap, imap->sent_folder)) {
		dc_log_error_if(&imap->log_connect_errors, imap->context, 0, "Cannot select IMAP-folder \"%s\".", imap->sent_folder);
		imap->sent_folder[0] = 0; /* force re-init */
		goto cleanup;
	}

	flag_list = mailimap_flag_list_new_empty();
	mailimap_flag_list_add(flag_list, mailimap_flag_new_seen());

	imap_date = dc_timestamp_to_mailimap_date_time(timestamp);
	if (imap_date==NULL) {
		dc_log_error(imap->context, 0, "Bad date.");
		goto cleanup;
	}

	r = mailimap_uidplus_append(imap->etpan, imap->sent_folder, flag_list, imap_date, data_not_terminated, data_bytes, &ret_uidvalidity, ret_server_uid);
	if (is_error(imap, r)) {
		dc_log_error_if(&imap->log_connect_errors, imap->context, 0, "Cannot append message to \"%s\", error #%i.", imap->sent_folder, (int)r);
		goto cleanup;
	}

	*ret_server_folder = dc_strdup(imap->sent_folder);

	dc_log_info(imap->context, 0, "Message appended to \"%s\".", imap->sent_folder);

	success = 1;

cleanup:

    if (imap_date) {
        mailimap_date_time_free(imap_date);
    }

    if (flag_list) {
		mailimap_flag_list_free(flag_list);
    }

	return success;
}


static int add_flag(dc_imap_t* imap, uint32_t server_uid, struct mailimap_flag* flag)
{
	int                              r = 0;
	struct mailimap_flag_list*       flag_list = NULL;
	struct mailimap_store_att_flags* store_att_flags = NULL;
	struct mailimap_set*             set = mailimap_set_new_single(server_uid);

	if (imap==NULL || imap->etpan==NULL) {
		goto cleanup;
	}

	flag_list = mailimap_flag_list_new_empty();
	mailimap_flag_list_add(flag_list, flag);

	store_att_flags = mailimap_store_att_flags_new_add_flags(flag_list); /* FLAGS.SILENT does not return the new value */

	r = mailimap_uid_store(imap->etpan, set, store_att_flags);
	if (is_error(imap, r)) {
		goto cleanup;
	}

cleanup:
	if (store_att_flags) {
		mailimap_store_att_flags_free(store_att_flags);
	}
	if (set) {
		mailimap_set_free(set);
	}
	return imap->should_reconnect? 0 : 1; /* all non-connection states are treated as success - the mail may already be deleted or moved away on the server */
}


int dc_imap_markseen_msg(dc_imap_t* imap, const char* folder, uint32_t server_uid, int ms_flags,
                        char** ret_server_folder, uint32_t* ret_server_uid, int* ret_ms_flags)
{
	// when marking as seen, there is no real need to check against the rfc724_mid - in the worst case, when the UID validity or the mailbox has changed, we mark the wrong message as "seen" - as the very most messages are seen, this is no big thing.
	// command would be "STORE 123,456,678 +FLAGS (\Seen)"
	int                  r = 0;
	struct mailimap_set* set = NULL;

	if (imap==NULL || folder==NULL || server_uid==0 || ret_server_folder==NULL || ret_server_uid==NULL || ret_ms_flags==NULL
	 || *ret_server_folder!=NULL || *ret_server_uid!=0 || *ret_ms_flags!=0) {
		return 1; /* job done */
	}

	if ((set=mailimap_set_new_single(server_uid))==NULL) {
		goto cleanup;
	}

	if (imap->etpan==NULL) {
		goto cleanup;
	}

	dc_log_info(imap->context, 0, "Marking message %s/%i as seen...", folder, (int)server_uid);

	if (select_folder(imap, folder)==0) {
		dc_log_warning(imap->context, 0, "Cannot select folder.");
		goto cleanup;
	}

	if (add_flag(imap, server_uid, mailimap_flag_new_seen())==0) {
		dc_log_warning(imap->context, 0, "Cannot mark message as seen.");
		goto cleanup;
	}

	dc_log_info(imap->context, 0, "Message marked as seen.");

	if ((ms_flags&DC_MS_SET_MDNSent_FLAG)
	 && imap->etpan->imap_selection_info!=NULL && imap->etpan->imap_selection_info->sel_perm_flags!=NULL)
	{
		/* Check if the folder can handle the `$MDNSent` flag (see RFC 3503).  If so, and not set: set the flags and return this information.
		If the folder cannot handle the `$MDNSent` flag, we risk duplicated MDNs; it's up to the receiving MUA to handle this then (eg. Delta Chat has no problem with this). */
		int can_create_flag = 0;
		clistiter* iter;
		for (iter=clist_begin(imap->etpan->imap_selection_info->sel_perm_flags); iter!=NULL; iter=clist_next(iter))
		{
			struct mailimap_flag_perm* fp = (struct mailimap_flag_perm*)clist_content(iter);
			if (fp) {
				if (fp->fl_type==MAILIMAP_FLAG_PERM_ALL) {
					can_create_flag = 1;
					break;
				}
				else if (fp->fl_type==MAILIMAP_FLAG_PERM_FLAG && fp->fl_flag) {
					struct mailimap_flag* fl = (struct mailimap_flag*)fp->fl_flag;
					if (fl->fl_type==MAILIMAP_FLAG_KEYWORD && fl->fl_data.fl_keyword && strcmp(fl->fl_data.fl_keyword, "$MDNSent")==0) {
						can_create_flag = 1;
						break;
					}
				}
			}
		}

		if (can_create_flag)
		{
			clist* fetch_result = NULL;
			r = mailimap_uid_fetch(imap->etpan, set, imap->fetch_type_flags, &fetch_result);
			if (!is_error(imap, r) && fetch_result) {
				clistiter* cur=clist_begin(fetch_result);
				if (cur) {
					if (!peek_flag_keyword((struct mailimap_msg_att*)clist_content(cur), "$MDNSent")) {
						add_flag(imap, server_uid, mailimap_flag_new_flag_keyword(dc_strdup("$MDNSent")));
						*ret_ms_flags |= DC_MS_MDNSent_JUST_SET;
					}
				}
				mailimap_fetch_list_free(fetch_result);
			}
			dc_log_info(imap->context, 0, ((*ret_ms_flags)&DC_MS_MDNSent_JUST_SET)? "$MDNSent just set and MDN will be sent." : "$MDNSent already set and MDN already sent.");
		}
		else
		{
			*ret_ms_flags |= DC_MS_MDNSent_JUST_SET;
			dc_log_info(imap->context, 0, "Cannot store $MDNSent flags, risk sending duplicate MDN.");
		}
	}

	if ((ms_flags&DC_MS_ALSO_MOVE) && (imap->server_flags&DC_NO_MOVE_TO_CHATS)==0)
	{
		init_chat_folders(imap);
		if (imap->moveto_folder && strcmp(folder, imap->moveto_folder)==0)
		{
			dc_log_info(imap->context, 0, "Message %s/%i is already in %s...", folder, (int)server_uid, imap->moveto_folder);
			/* avoid deadlocks as moving messages in the same folder may be result in a new server_uid and the state "fresh" -
			we will catch these messages again on the next poll, try to move them away and so on, see also (***) in dc_receive_imf.c */
		}
		else if (imap->moveto_folder)
		{
			dc_log_info(imap->context, 0, "Moving message %s/%i to %s...", folder, (int)server_uid, imap->moveto_folder);

			/* TODO/TOCHECK: MOVE may not be supported on servers, if this is often the case, we should fallback to a COPY/DELETE implementation.
			Same for the UIDPLUS extension (if in doubt, we can find out the resulting UID using "imap_selection_info->sel_uidnext" then). */
			uint32_t             res_uid = 0;
			struct mailimap_set* res_setsrc = NULL;
			struct mailimap_set* res_setdest = NULL;
			r = mailimap_uidplus_uid_move(imap->etpan, set, imap->moveto_folder, &res_uid, &res_setsrc, &res_setdest); /* the correct folder is already selected in add_flag() above */
			if (is_error(imap, r)) {
								dc_log_info(imap->context, 0, "Cannot move message, fallback to COPY/DELETE %s/%i to %s...", folder, (int)server_uid, imap->moveto_folder);
								r = mailimap_uidplus_uid_copy(imap->etpan, set, imap->moveto_folder, &res_uid, &res_setsrc, &res_setdest);
								if (is_error(imap, r)) {
									dc_log_info(imap->context, 0, "Cannot copy message. Leaving in INBOX");
									goto cleanup;
								}
								else {
									dc_log_info(imap->context, 0, "Deleting msg ...");
									if (add_flag(imap, server_uid, mailimap_flag_new_deleted())==0) {
											dc_log_warning(imap->context, 0, "Cannot mark message as \"Deleted\".");/* maybe the message is already deleted */
									}

									/* force an EXPUNGE resp. CLOSE for the selected folder */
									imap->selected_folder_needs_expunge = 1;
								}

							}

			if (res_setsrc) {
				mailimap_set_free(res_setsrc);
			}

			if (res_setdest) {
				clistiter* cur = clist_begin(res_setdest->set_list);
				if (cur!=NULL) {
					struct mailimap_set_item* item;
					item = clist_content(cur);
					*ret_server_uid = item->set_first;
					*ret_server_folder = dc_strdup(imap->moveto_folder);
				}
				mailimap_set_free(res_setdest);
			}

			// TODO: If the new UID is equal to lastuid.Chats, we should increase lastuid.Chats by one
			// (otherwise, we'll download the mail in moment again from the chats folder ...)

			dc_log_info(imap->context, 0, "Message moved.");
		}
	}

cleanup:
	if (set) {
		mailimap_set_free(set);
	}
	return imap->should_reconnect? 0 : 1;
}


int dc_imap_delete_msg(dc_imap_t* imap, const char* rfc724_mid, const char* folder, uint32_t server_uid)
{
	int    success = 0;
	int    r = 0;
	clist* fetch_result = NULL;
	char*  is_rfc724_mid = NULL;
	char*  new_folder = NULL;

	if (imap==NULL || rfc724_mid==NULL || folder==NULL || folder[0]==0) {
		success = 1; /* job done, do not try over */
		goto cleanup;
	}

	dc_log_info(imap->context, 0, "Marking message \"%s\", %s/%i for deletion...", rfc724_mid, folder, (int)server_uid);

	if (select_folder(imap, folder)==0) {
		dc_log_warning(imap->context, 0, "Cannot select folder \"%s\".", folder); /* maybe the folder does no longer exist */
		goto cleanup;
	}

	/* check if Folder+UID matches the Message-ID (to detect if the messages
	was moved around by other MUAs and in place of an UIDVALIDITY check)
	(we also detect messages moved around when we do a fetch-all, see
	dc_update_server_uid() in receive_imf(), however this may take a while) */
	if (server_uid)
	{
		clistiter* cur = NULL;
		const char* is_quoted_rfc724_mid = NULL;

		struct mailimap_set* set = mailimap_set_new_single(server_uid);
			r = mailimap_uid_fetch(imap->etpan, set, imap->fetch_type_message_id, &fetch_result);
		mailimap_set_free(set);

		if (is_error(imap, r) || fetch_result==NULL
		 || (cur=clist_begin(fetch_result))==NULL
		 || (is_quoted_rfc724_mid=peek_rfc724_mid((struct mailimap_msg_att*)clist_content(cur)))==NULL
		 || (is_rfc724_mid=unquote_rfc724_mid(is_quoted_rfc724_mid))==NULL
		 || strcmp(is_rfc724_mid, rfc724_mid)!=0)
		{
			dc_log_warning(imap->context, 0, "UID not found in the given folder or does not match Message-ID.");
			server_uid = 0;
		}
	}

	/* server_uid is 0 now if it was not given or if it does not match the given message id;
	try to search for it in all folders (the message may be moved by another MUA to a folder we do not sync or the sync is a moment ago) */
	if (server_uid==0) {
		dc_log_info(imap->context, 0, "Searching UID by Message-ID \"%s\"...", rfc724_mid);
		if ((server_uid=search_uid(imap, rfc724_mid))==0) {
			dc_log_warning(imap->context, 0, "Message-ID \"%s\" not found in any folder, cannot delete message.", rfc724_mid);
			goto cleanup;
		}
		dc_log_info(imap->context, 0, "Message-ID \"%s\" found in %s/%i", rfc724_mid, imap->selected_folder, server_uid);
	}


	/* mark the message for deletion */
	if (add_flag(imap, server_uid, mailimap_flag_new_deleted())==0) {
		dc_log_warning(imap->context, 0, "Cannot mark message as \"Deleted\"."); /* maybe the message is already deleted */
		goto cleanup;
	}

	/* force an EXPUNGE resp. CLOSE for the selected folder */
	imap->selected_folder_needs_expunge = 1;

	success = 1;

cleanup:

	if (fetch_result) { mailimap_fetch_list_free(fetch_result); }
	free(is_rfc724_mid);
	free(new_folder);

	return success? 1 : dc_imap_is_connected(imap); /* only return 0 on connection problems; we should try later again in this case */

}

