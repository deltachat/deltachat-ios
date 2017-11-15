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
 * Create new message object. Message objects are needed eg. for sending messages using
 * mrmailbox_send_msg().  Moreover, they are returned eg. from mrmailbox_get_msg(),
 * set up with the current state of a message. The message object is not updated;
 * to achieve this, you have to recreate it.
 *
 * @memberof mrmsg_t
 *
 * @return The created message object.
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
void mrmsg_unref(mrmsg_t* msg)
{
	if( msg==NULL ) {
		return;
	}

	mrmsg_empty(msg);
	mrparam_unref(msg->m_param);
	free(msg);
}


/**
 * Empty a message object.
 *
 * @memberof mrmsg_t
 *
 * @param msg The message object to empty.
 *
 * @return None.
 */
void mrmsg_empty(mrmsg_t* msg)
{
	if( msg == NULL ) {
		return;
	}

	free(msg->m_text);
	msg->m_text = NULL;

	free(msg->m_rfc724_mid);
	msg->m_rfc724_mid = NULL;

	free(msg->m_server_folder);
	msg->m_server_folder = NULL;

	mrparam_set_packed(msg->m_param, NULL);

	msg->m_mailbox = NULL;
}


/**
 * Set the text of a message object.
 *
 * The text is _not_ modified in the database, this function is only a helper to
 * set up a message object to be sent afterwards. The type of the message object
 * is not changed implicitly to MR_MSG_TEXT when using this function. Previously
 * set texts are free()'d.
 *
 * @memberof mrmsg_t
 *
 * @param msg Message to set the text for.
 *
 * @param text Text to set.  The function creates a copy of the given text so
 *     that it can be free()'d just after this function is called.
 *
 * @return None.
 */
void mrmsg_set_text(mrmsg_t* msg, const char* text)
{
	if( msg==NULL || text==NULL ) {
		return;
	}

	free(msg->m_text);
	msg->m_text = safe_strdup(text);
}


/**
 * Guess message type from suffix.
 *
 * @private @memberof mrmsg_t
 *
 * @param pathNfilename Path and filename of the file to guess the type for.
 *
 * @param[out] ret_msgtype Guessed message type is copied here as one of the MR_MSG_* constants.
 *
 * @param[out] ret_mime The pointer to a string buffer is set to the guessed MIME-type. May be NULL. Must be free()'d by the caller.
 *
 * @return None. But there are output parameters.
 */
void mrmsg_guess_msgtype_from_suffix(const char* pathNfilename, int* ret_msgtype, char** ret_mime)
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


/**
 * Library-internal.
 *
 * Calling this function is not thread-safe, locking is up to the caller.
 *
 * @private @memberof mrmsg_t
 */
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
 *
 * @param msg The message object.
 *
 * @return 1=padlock should be shown beside message, 0=do not show a padlock beside the message.
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


void mrmsg_get_authorNtitle_from_filename(const char* pathNfilename, char** ret_author, char** ret_title)
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
				mrmsg_get_authorNtitle_from_filename(pathNfilename, NULL, &value);
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
 * Get real author and title. (as return.text1, this is not always the sender, NULL if
 * unknown) and title (return.text2, NULL if unknown) of a message.
 *
 * For voice messages, the author the sender and the trackname is the sending time
 * For music messages, we read the information from the filename
 * We do not read ID3 and such at this stage, the needed libraries may be buggy
 * and the whole stuff is way to complicated.
 * However, this is not a great disadvantage, as the sender usually sets the filename in a way we expect it -
 * if not, we simply print the whole filename as we do it for documents.  All fine in any case :-)
 *
 * @memberof mrmsg_t
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
		mrmsg_get_authorNtitle_from_filename(pathNfilename, &ret->m_text1, &ret->m_text2);
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

