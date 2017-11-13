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
#include "mrimap.h"
#include "mrsmtp.h"
#include "mrjob.h"
#include "mrpgp.h"
#include "mrmimefactory.h"


/**
 * Foobar
 */


/*******************************************************************************
 * Tools
 ******************************************************************************/


int mrmsg_set_from_stmt__(mrmsg_t* ths, sqlite3_stmt* row, int row_offset) /* field order must be MR_MSG_FIELDS */
{
	mrmsg_empty(ths);

	ths->m_id           =           (uint32_t)sqlite3_column_int  (row, row_offset++);
	ths->m_rfc724_mid   =  safe_strdup((char*)sqlite3_column_text (row, row_offset++));
	ths->m_server_folder=  safe_strdup((char*)sqlite3_column_text (row, row_offset++));
	ths->m_server_uid   =           (uint32_t)sqlite3_column_int  (row, row_offset++);
	ths->m_chat_id      =           (uint32_t)sqlite3_column_int  (row, row_offset++);

	ths->m_from_id      =           (uint32_t)sqlite3_column_int  (row, row_offset++);
	ths->m_to_id        =           (uint32_t)sqlite3_column_int  (row, row_offset++);
	ths->m_timestamp    =             (time_t)sqlite3_column_int64(row, row_offset++);

	ths->m_type         =                     sqlite3_column_int  (row, row_offset++);
	ths->m_state        =                     sqlite3_column_int  (row, row_offset++);
	ths->m_is_msgrmsg   =                     sqlite3_column_int  (row, row_offset++);
	ths->m_text         =  safe_strdup((char*)sqlite3_column_text (row, row_offset++));

	mrparam_set_packed(  ths->m_param, (char*)sqlite3_column_text (row, row_offset++));
	ths->m_starred      =                     sqlite3_column_int  (row, row_offset++);

	if( ths->m_chat_id == MR_CHAT_ID_DEADDROP ) {
		mr_truncate_n_unwrap_str(ths->m_text, 256, 0); /* 256 characters is about a half screen on a 5" smartphone display */
	}

	return 1;
}


int mrmsg_load_from_db__(mrmsg_t* ths, mrmailbox_t* mailbox, uint32_t id)
{
	sqlite3_stmt* stmt;

	if( ths==NULL || mailbox==NULL || mailbox->m_sql==NULL ) {
		return 0;
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_ircftttstpb_FROM_msg_WHERE_i,
		"SELECT " MR_MSG_FIELDS " FROM msgs m WHERE m.id=?;");
	sqlite3_bind_int(stmt, 1, id);

	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	if( !mrmsg_set_from_stmt__(ths, stmt, 0) ) { /* also calls mrmsg_empty() */
		return 0;
	}

	ths->m_mailbox = mailbox;

	return 1;
}


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


void mr_guess_msgtype_from_suffix(const char* pathNfilename, int* ret_msgtype, char** ret_mime)
{
	if( pathNfilename == NULL || ret_msgtype == NULL || ret_mime == NULL) {
		return;
	}

	*ret_msgtype = MR_MSG_UNDEFINED;
	*ret_mime = NULL;

	char* s = mr_get_filesuffix_lc(pathNfilename);
	if( s == NULL ) {
		goto cleanup;
	}

	if( strcmp(s, "mp3")==0 ) {
		*ret_msgtype = MR_MSG_AUDIO;
		*ret_mime = safe_strdup("audio/mpeg");
	}
	else if( strcmp(s, "mp4")==0 ) {
		*ret_msgtype = MR_MSG_VIDEO;
		*ret_mime = safe_strdup("video/mp4");
	}
	else if( strcmp(s, "jpg")==0 || strcmp(s, "jpeg")==0 ) {
		*ret_msgtype = MR_MSG_IMAGE;
		*ret_mime = safe_strdup("image/jpeg");
	}
	else if( strcmp(s, "png")==0 ) {
		*ret_msgtype = MR_MSG_IMAGE;
		*ret_mime = safe_strdup("image/png");
	}
	else if( strcmp(s, "gif")==0 ) {
		*ret_msgtype = MR_MSG_GIF;
		*ret_mime = safe_strdup("image/gif");
	}

cleanup:
	free(s);
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


 /**
 * Create new mrmsg_t object as needed for sending messages using
 * mrmailbox_send_msg().
 *
 * @memberof mrmsg_t
 */
mrmsg_t* mrmsg_new()
{
	mrmsg_t* ths = NULL;

	if( (ths=calloc(1, sizeof(mrmsg_t)))==NULL ) {
		exit(15); /* cannot allocate little memory, unrecoverable error */
	}

	ths->m_type      = MR_MSG_UNDEFINED;
	ths->m_state     = MR_STATE_UNDEFINED;
	ths->m_param     = mrparam_new();

	return ths;
}


/**
 * Free an mrmsg_t object created eg. by mrmsg_new() or mrmailbox_get_msg().
 * This also free()s all strings; so if you set up the object yourself, make sure
 * to use strdup()!
 *
 * @memberof mrmsg_t
 *
 * @param msg The message object to free.
 */
void mrmsg_unref(mrmsg_t* ths)
{
	if( ths==NULL ) {
		return;
	}

	mrmsg_empty(ths);
	mrparam_unref(ths->m_param);
	free(ths);
}


void mrmsg_empty(mrmsg_t* ths)
{
	if( ths == NULL ) {
		return;
	}

	free(ths->m_text);
	ths->m_text = NULL;

	free(ths->m_rfc724_mid);
	ths->m_rfc724_mid = NULL;

	free(ths->m_server_folder);
	ths->m_server_folder = NULL;

	mrparam_set_packed(ths->m_param, NULL);

	ths->m_mailbox = NULL;
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


void mrmsg_set_text(mrmsg_t* msg, const char* text)
{
	if( msg==NULL || text==NULL ) {
		return;
	}

	free(msg->m_text);
	msg->m_text = safe_strdup(text);
}


/**
 * Get an informational text for a single message. the text is multiline and may
 * contain eg. the raw text of the message.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new()
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
 * Get a summary for a message. The last parameter can be set to speed up
 * things if the chat object is already available; if not, it is faster to pass
 * NULL here.  The result must be freed using mrpoortext_unref().
 * Typically used to display a search result.
 *
 * @memberof mrmsg_t
 *
 * @return  The returned summary is similar to mrchatlist_get_summary(), however, without
 *     "draft", "no messages" and so on.
 */
mrpoortext_t* mrmsg_get_summary(mrmsg_t* msg, mrchat_t* chat)
{
	mrpoortext_t* ret = mrpoortext_new();
	mrcontact_t*  contact = NULL;
	mrchat_t*     chat_to_delete = NULL;

	if( msg==NULL ) {
		goto cleanup;
	}

	if( chat == NULL ) {
		if( (chat=mrmailbox_get_chat(msg->m_mailbox, msg->m_chat_id)) == NULL ) {
			goto cleanup;
		}
		chat_to_delete = chat;
	}

	if( msg->m_from_id != MR_CONTACT_ID_SELF  &&  chat->m_type == MR_CHAT_TYPE_GROUP ) {
		contact = mrmailbox_get_contact(chat->m_mailbox, msg->m_from_id);
	}

	mrpoortext_fill(ret, msg, chat, contact);

cleanup:
	mrcontact_unref(contact);
	mrchat_unref(chat_to_delete);
	return ret;
}

/**
 * Check if a padlock should be shown beside the message.
 *
 * @memberof mrmsg_t
 */
int mrmsg_show_padlock(mrmsg_t* msg)
{
	/* a padlock guarantees that the message is e2ee _and_ answers will be as well */
	if( msg != NULL ) {
		if( msg->m_mailbox && msg->m_mailbox->m_e2ee_enabled ) {
			if( mrparam_get_int(msg->m_param, MRP_GUARANTEE_E2EE, 0) != 0 ) {
				return 1;
			}
		}
	}
	return 0;
}


void mr_get_authorNtitle_from_filename(const char* pathNfilename, char** ret_author, char** ret_title)
{
	/* function extracts AUTHOR and TITLE from a path given as `/path/other folder/AUTHOR - TITLE.mp3`
	if the mark ` - ` is not preset, the whole name (without suffix) is used as the title and the author is NULL. */
	char *author = NULL, *title = NULL, *p;
	mr_split_filename(pathNfilename, &title, NULL);
	p = strstr(title, " - ");
	if( p ) {
		*p = 0;
		author = title;
		title  = safe_strdup(&p[3]);
	}

	if( ret_author ) { *ret_author = author; } else { free(author); }
	if( ret_title  ) { *ret_title  = title;  } else { free(title);  }
}


/**
 * Get a message summary as a single line of text.  Typically used for
 * notifications.  The returned value must be free()'d.
 *
 * @memberof mrmsg_t
 */
char* mrmsg_get_summarytext(mrmsg_t* msg, int approx_characters)
{
	if( msg==NULL ) {
		return safe_strdup(NULL);
	}

	return mrmsg_get_summarytext_by_raw(msg->m_type, msg->m_text, msg->m_param, approx_characters);
}


char* mrmsg_get_summarytext_by_raw(int type, const char* text, mrparam_t* param, int approx_characters)
{
	char* ret = NULL;
	char* pathNfilename = NULL, *label = NULL, *value = NULL;

	switch( type ) {
		case MR_MSG_IMAGE:
			ret = mrstock_str(MR_STR_IMAGE);
			break;

		case MR_MSG_GIF:
			ret = mrstock_str(MR_STR_GIF);
			break;

		case MR_MSG_VIDEO:
			ret = mrstock_str(MR_STR_VIDEO);
			break;

		case MR_MSG_VOICE:
			ret = mrstock_str(MR_STR_VOICEMESSAGE);
			break;

		case MR_MSG_AUDIO:
			if( (value=mrparam_get(param, MRP_TRACKNAME, NULL))==NULL ) { /* although we send files with "author - title" in the filename, existing files may follow other conventions, so this lookup is neccessary */
				pathNfilename = mrparam_get(param, MRP_FILE, "ErrFilename");
				mr_get_authorNtitle_from_filename(pathNfilename, NULL, &value);
			}
			label = mrstock_str(MR_STR_AUDIO);
			ret = mr_mprintf("%s: %s", label, value);
			break;

		case MR_MSG_FILE:
			pathNfilename = mrparam_get(param, MRP_FILE, "ErrFilename");
			value = mr_get_filename(pathNfilename);
			label = mrstock_str(MR_STR_FILE);
			ret = mr_mprintf("%s: %s", label, value);
			break;

		default:
			if( text ) {
				ret = safe_strdup(text);
				mr_truncate_n_unwrap_str(ret, approx_characters, 1);
			}
			break;
	}

	/* cleanup */
	free(pathNfilename);
	free(label);
	free(value);
	if( ret == NULL ) {
		ret = safe_strdup(NULL);
	}
	return ret;
}


/**
 * Find out full path, file name and extension of the file associated with a
 * message.
 *
 * @param msg the message object
 *
 * @return full path, file name and extension of the file associated with the
 *     message.  If there is no file associated with the message, an emtpy
 *     string is returned.  The returned value must be free()'d.
 */
char* mrmsg_get_fullpath(mrmsg_t* msg)
{
	char* ret = NULL;

	if( msg == NULL ) {
		goto cleanup;
	}

	ret = mrparam_get(msg->m_param, MRP_FILE, NULL);

cleanup:
	return ret? ret : safe_strdup(NULL);
}


/**
 * Find out the base file name and extension of the file associated with a
 * message.
 *
 * @param msg the message object
 *
 * @return base file name plus extension without part.  If there is no file
 *     associated with the message, an empty string is returned.  The returned
 *     value must be free()'d.
 */
char* mrmsg_get_filename(mrmsg_t* msg)
{
	char* ret = NULL, *pathNfilename = NULL;

	if( msg == NULL ) {
		goto cleanup;
	}

	pathNfilename = mrparam_get(msg->m_param, MRP_FILE, NULL);
	if( pathNfilename == NULL ) {
		goto cleanup;
	}

	ret = mr_get_filename(pathNfilename);

cleanup:
	free(pathNfilename);
	return ret? ret : safe_strdup(NULL);
}


/**
 * Returns real author (as return.text1, this is not always the sender, NULL if
 * unknown) and title (return.text2, NULL if unknown) of a message.
 *
 * For voice messages, the author the sender and the trackname is the sending time
 * For music messages, we read the information from the filename
 * We do not read ID3 and such at this stage, the needed libraries may be buggy
 * and the whole stuff is way to complicated.
 * However, this is not a great disadvantage, as the sender usually sets the filename in a way we expect it -
 * if not, we simply print the whole filename as we do it for documents.  All fine in any case :-)
 *
 * @param msg the message object
 *
 * @return poortext object that must be unref'd using mrpoortext_unref() when no longer used.
 */
mrpoortext_t* mrmsg_get_mediainfo(mrmsg_t* msg)
{
	mrpoortext_t* ret = mrpoortext_new();
	char *pathNfilename = NULL;
	mrcontact_t* contact = NULL;

	if( msg == NULL || msg->m_mailbox == NULL ) {
		goto cleanup;
	}

	if( msg->m_type == MR_MSG_VOICE )
	{
		if( (contact = mrmailbox_get_contact(msg->m_mailbox, msg->m_from_id))==NULL ) {
			goto cleanup;
		}
		ret->m_text1 = safe_strdup((contact->m_name&&contact->m_name[0])? contact->m_name : contact->m_addr);
		ret->m_text2 = mrstock_str(MR_STR_VOICEMESSAGE);
	}
	else
	{
		ret->m_text1 = mrparam_get(msg->m_param, MRP_AUTHORNAME, NULL);
		ret->m_text2 = mrparam_get(msg->m_param, MRP_TRACKNAME, NULL);
		if( ret->m_text1 && ret->m_text1[0] && ret->m_text2 && ret->m_text2[0] ) {
			goto cleanup;
		}
		free(ret->m_text1); ret->m_text1 = NULL;
		free(ret->m_text2); ret->m_text2 = NULL;

		pathNfilename = mrparam_get(msg->m_param, MRP_FILE, NULL);
		if( pathNfilename == NULL ) {
			goto cleanup;
		}
		mr_get_authorNtitle_from_filename(pathNfilename, &ret->m_text1, &ret->m_text2);
		if( ret->m_text1 == NULL && ret->m_text2 != NULL ) {
			ret->m_text1 = mrstock_str(MR_STR_AUDIO);
		}
	}

cleanup:
	free(pathNfilename);
	mrcontact_unref(contact);
	return ret;
}


int mrmsg_is_increation__(const mrmsg_t* msg)
{
	int is_increation = 0;
	if( MR_MSG_NEEDS_ATTACHMENT(msg->m_type) )
	{
		char* pathNfilename = mrparam_get(msg->m_param, MRP_FILE, NULL);
		if( pathNfilename ) {
			char* totest = mr_mprintf("%s.increation", pathNfilename);
			if( mr_file_exist(totest) ) {
				is_increation = 1;
			}
			free(totest);
			free(pathNfilename);
		}
	}
	return is_increation;
}


/**
 * Check if a message is still in creation.  The user can mark files as being
 * in creation by simply creating a file `<filename>.increation`. If
 * `<filename>` is created then, the user should just delete
 * `<filename>.increation`
 *
 * @param msg the message object
 *
 * @return 1=message is still in creation (`<filename>.increation` exists),
 *     0=message no longer in creation
 */
int mrmsg_is_increation(mrmsg_t* msg)
{
	/* surrounds mrmsg_is_increation__() with locking and error checking */
	int is_increation = 0;
	if( msg && msg->m_mailbox && MR_MSG_NEEDS_ATTACHMENT(msg->m_type) /*additional check for speed reasons*/ )
	{
		mrsqlite3_lock(msg->m_mailbox->m_sql);
			is_increation = mrmsg_is_increation__(msg);
		mrsqlite3_unlock(msg->m_mailbox->m_sql);
	}
	return is_increation;
}


/* Internal function similar to mrmsg_save_param_to_disk() but without locking. */
void mrmsg_save_param_to_disk__(mrmsg_t* msg)
{
	if( msg == NULL || msg->m_mailbox == NULL || msg->m_mailbox->m_sql == NULL ) {
		return;
	}

	sqlite3_stmt* stmt = mrsqlite3_predefine__(msg->m_mailbox->m_sql, UPDATE_msgs_SET_param_WHERE_id,
		"UPDATE msgs SET param=? WHERE id=?;");
	sqlite3_bind_text(stmt, 1, msg->m_param->m_packed, -1, SQLITE_STATIC);
	sqlite3_bind_int (stmt, 2, msg->m_id);
	sqlite3_step(stmt);
}


/**
 * can be used to add some additional, persistent information to a messages
 * record.
 *
 * @memberof mrmsg_t
 */
void mrmsg_save_param_to_disk(mrmsg_t* msg)
{
	if( msg == NULL || msg->m_mailbox == NULL || msg->m_mailbox->m_sql == NULL ) {
		return;
	}

	mrsqlite3_lock(msg->m_mailbox->m_sql);
		mrmsg_save_param_to_disk__(msg);
	mrsqlite3_unlock(msg->m_mailbox->m_sql);
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
void mrmailbox_delete_msgs(mrmailbox_t* ths, const uint32_t* msg_ids, int msg_cnt)
{
	int i;

	if( ths == NULL || msg_ids == NULL || msg_cnt <= 0 ) {
		return;
	}

	mrsqlite3_lock(ths->m_sql);
	mrsqlite3_begin_transaction__(ths->m_sql);

		for( i = 0; i < msg_cnt; i++ )
		{
			mrmailbox_update_msg_chat_id__(ths, msg_ids[i], MR_CHAT_ID_TRASH);
			mrjob_add__(ths, MRJ_DELETE_MSG_ON_IMAP, msg_ids[i], NULL); /* results in a call to mrmailbox_delete_msg_on_imap() */
		}

	mrsqlite3_commit__(ths->m_sql);
	mrsqlite3_unlock(ths->m_sql);
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
 * @return none
 */
void mrmailbox_forward_msgs(mrmailbox_t* mailbox, const uint32_t* msg_ids_unsorted, int msg_cnt, uint32_t chat_id)
{
	mrmsg_t*      msg = mrmsg_new();
	mrchat_t*     chat = mrchat_new(mailbox);
	mrcontact_t*  contact = mrcontact_new();
	int           locked = 0, transaction_pending = 0;
	carray*       created_db_entries = carray_new(16);
	char*         idsstr = NULL, *q3 = NULL;
	sqlite3_stmt* stmt = NULL;
	time_t        curr_timestamp;

	if( mailbox == NULL || msg_ids_unsorted==NULL || msg_cnt <= 0 || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
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

		idsstr = mr_arr_to_string(msg_ids_unsorted, msg_cnt);
		q3 = sqlite3_mprintf("SELECT id FROM msgs WHERE id IN(%s) ORDER BY timestamp,id", idsstr);
		stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, q3);
		while( sqlite3_step(stmt)==SQLITE_ROW )
		{
			int src_msg_id = sqlite3_column_int(stmt, 0);
			if( !mrmsg_load_from_db__(msg, mailbox, src_msg_id) ) {
				goto cleanup;
			}

			mrparam_set_int(msg->m_param, MRP_FORWARDED, 1);

			uint32_t new_msg_id = mrchat_send_msg__(chat, msg, curr_timestamp++);
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
 * @param msg_ids an array of uint32_t containing all the messages IDs that should be marked as seen
 *
 * @param msg_cnt the number of message IDs in msg_ids
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

