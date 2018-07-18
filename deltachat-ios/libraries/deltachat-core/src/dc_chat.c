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


#include <assert.h>
#include "dc_context.h"
#include "dc_job.h"
#include "dc_smtp.h"
#include "dc_imap.h"
#include "dc_mimefactory.h"
#include "dc_apeerstate.h"


#define DC_CHAT_MAGIC 0xc4a7c4a7


/**
 * Create a chat object in memory.
 *
 * @private @memberof dc_chat_t
 * @param context The context that should be stored in the chat object.
 * @return New and empty chat object, must be freed using dc_chat_unref().
 */
dc_chat_t* dc_chat_new(dc_context_t* context)
{
	dc_chat_t* chat = NULL;

	if (context==NULL || (chat=calloc(1, sizeof(dc_chat_t)))==NULL) {
		exit(14); /* cannot allocate little memory, unrecoverable error */
	}

	chat->magic    = DC_CHAT_MAGIC;
	chat->context  = context;
	chat->type     = DC_CHAT_TYPE_UNDEFINED;
	chat->param    = dc_param_new();

    return chat;
}


/**
 * Free a chat object.
 *
 * @memberof dc_chat_t
 * @param chat Chat object are returned eg. by dc_get_chat().
 * @return None.
 */
void dc_chat_unref(dc_chat_t* chat)
{
	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return;
	}

	dc_chat_empty(chat);
	dc_param_unref(chat->param);
	chat->magic = 0;
	free(chat);
}


/**
 * Empty a chat object.
 *
 * @private @memberof dc_chat_t
 * @param chat The chat object to empty.
 * @return None.
 */
void dc_chat_empty(dc_chat_t* chat)
{
	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return;
	}

	free(chat->name);
	chat->name = NULL;

	chat->draft_timestamp = 0;

	free(chat->draft_text);
	chat->draft_text = NULL;

	chat->type = DC_CHAT_TYPE_UNDEFINED;
	chat->id   = 0;

	free(chat->grpid);
	chat->grpid = NULL;

	chat->blocked = 0;

	dc_param_set_packed(chat->param, NULL);
}


/**
 * Get chat ID. The chat ID is the ID under which the chat is filed in the database.
 *
 * Special IDs:
 * - DC_CHAT_ID_DEADDROP         (1) - Virtual chat containing messages which senders are not confirmed by the user.
 * - DC_CHAT_ID_STARRED          (5) - Virtual chat containing all starred messages-
 * - DC_CHAT_ID_ARCHIVED_LINK    (6) - A link at the end of the chatlist, if present the UI should show the button "Archived chats"-
 *
 * "Normal" chat IDs are larger than these special IDs (larger than DC_CHAT_ID_LAST_SPECIAL).
 *
 * @memberof dc_chat_t
 * @param chat The chat object.
 * @return Chat ID. 0 on errors.
 */
uint32_t dc_chat_get_id(const dc_chat_t* chat)
{
	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return 0;
	}

	return chat->id;
}


/**
 * Get chat type.
 *
 * Currently, there are two chat types:
 *
 * - DC_CHAT_TYPE_SINGLE (100) - a normal chat is a chat with a single contact,
 *   chats_contacts contains one record for the user.  DC_CONTACT_ID_SELF
 *   (see dc_contact_t::id) is added _only_ for a self talk.
 *
 * - DC_CHAT_TYPE_GROUP  (120) - a group chat, chats_contacts conain all group
 *   members, incl. DC_CONTACT_ID_SELF
 *
 * - DC_CHAT_TYPE_VERIFIED_GROUP  (130) - a verified group chat. In verified groups,
 *   all members are verified and encryption is always active and cannot be disabled.
 *
 * @memberof dc_chat_t
 * @param chat The chat object.
 * @return Chat type.
 */
int dc_chat_get_type(const dc_chat_t* chat)
{
	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return DC_CHAT_TYPE_UNDEFINED;
	}
	return chat->type;
}


/**
 * Get name of a chat. For one-to-one chats, this is the name of the contact.
 * For group chats, this is the name given eg. to dc_create_group_chat() or
 * received by a group-creation message.
 *
 * To change the name, use dc_set_chat_name()
 *
 * See also: dc_chat_get_subtitle()
 *
 * @memberof dc_chat_t
 * @param chat The chat object.
 * @return Chat name as a string. Must be free()'d after usage. Never NULL.
 */
char* dc_chat_get_name(const dc_chat_t* chat)
{
	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return dc_strdup("Err");
	}

	return dc_strdup(chat->name);
}


/**
 * Get a subtitle for a chat.  The subtitle is eg. the email-address or the
 * number of group members.
 *
 * See also: dc_chat_get_name()
 *
 * @memberof dc_chat_t
 * @param chat The chat object to calulate the subtitle for.
 * @return Subtitle as a string. Must be free()'d after usage. Never NULL.
 */
char* dc_chat_get_subtitle(const dc_chat_t* chat)
{
	/* returns either the address or the number of chat members */
	char*         ret = NULL;

	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return dc_strdup("Err");
	}

	if (chat->type==DC_CHAT_TYPE_SINGLE && dc_param_exists(chat->param, DC_PARAM_SELFTALK))
	{
		ret = dc_stock_str(chat->context, DC_STR_SELFTALK_SUBTITLE);
	}
	else if (chat->type==DC_CHAT_TYPE_SINGLE)
	{
		int r;
		sqlite3_stmt* stmt = dc_sqlite3_prepare(chat->context->sql,
			"SELECT c.addr FROM chats_contacts cc "
			" LEFT JOIN contacts c ON c.id=cc.contact_id "
			" WHERE cc.chat_id=?;");
		sqlite3_bind_int(stmt, 1, chat->id);

		r = sqlite3_step(stmt);
		if (r==SQLITE_ROW) {
			ret = dc_strdup((const char*)sqlite3_column_text(stmt, 0));
		}

		sqlite3_finalize(stmt);
	}
	else if (DC_CHAT_TYPE_IS_MULTI(chat->type))
	{
		int cnt = 0;
		if (chat->id==DC_CHAT_ID_DEADDROP)
		{
			ret = dc_stock_str(chat->context, DC_STR_DEADDROP); /* typically, the subtitle for the deaddropn is not displayed at all */
		}
		else
		{
			cnt = dc_get_chat_contact_cnt(chat->context, chat->id);
			ret = dc_stock_str_repl_pl(chat->context, DC_STR_MEMBER, cnt /*SELF is included in group chats (if not removed)*/);
		}
	}

	return ret? ret : dc_strdup("Err");
}


/**
 * Get the chat's profile image.
 * The profile image is set using dc_set_chat_profile_image() for groups.
 * For normal chats, the profile image is set using dc_set_contact_profile_image() (not yet implemented).
 *
 * @memberof dc_chat_t
 * @param chat The chat object.
 * @return Path and file if the profile image, if any.  NULL otherwise.
 *     Must be free()'d after usage.
 */
char* dc_chat_get_profile_image(const dc_chat_t* chat)
{
	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return NULL;
	}

	return dc_param_get(chat->param, DC_PARAM_PROFILE_IMAGE, NULL);
}


/**
 * Get draft for the chat, if any. A draft is a message that the user started to
 * compose but that is not sent yet. You can save a draft for a chat using dc_set_text_draft().
 *
 * Drafts are considered when sorting messages and are also returned eg.
 * by dc_chatlist_get_summary().
 *
 * @memberof dc_chat_t
 * @param chat The chat object.
 * @return Draft text, must be free()'d. Returns NULL if there is no draft.
 */
char* dc_chat_get_text_draft(const dc_chat_t* chat)
{
	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return NULL;
	}
	return dc_strdup_keep_null(chat->draft_text); /* may be NULL */
}



/**
 * Get timestamp of the draft.
 * The draft itself can be get using dc_chat_get_text_draft().
 *
 * @memberof dc_chat_t
 * @param chat The chat object.
 * @return Timestamp of the draft. 0 if there is no draft.
 */
time_t dc_chat_get_draft_timestamp(const dc_chat_t* chat)
{
	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return 0;
	}
	return chat->draft_timestamp;
}


/**
 * Get archived state.
 *
 * - 0 = normal chat, not archived, not sticky.
 * - 1 = chat archived
 * - 2 = chat sticky (reserved for future use, if you do not support this value, just treat the chat as a normal one)
 *
 * To archive or unarchive chats, use dc_archive_chat().
 * If chats are archived, this should be shown in the UI by a little icon or text,
 * eg. the search will also return archived chats.
 *
 * @memberof dc_chat_t
 * @param chat The chat object.
 * @return Archived state.
 */
int dc_chat_get_archived(const dc_chat_t* chat)
{
	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return 0;
	}
	return chat->archived;
}


/**
 * Check if a chat is still unpromoted.  Chats are unpromoted until the first
 * message is sent.  With unpromoted chats, members can be sent, settings can be
 * modified without the need of special status messages being sent.
 *
 * After the creation with dc_create_group_chat() the chat is usuall  unpromoted
 * until the first call to dc_send_text_msg() or another sending function.
 *
 * @memberof dc_chat_t
 * @param chat The chat object.
 * @return 1=chat is still unpromoted, no message was ever send to the chat,
 *     0=chat is not unpromoted, messages were send and/or received
 */
int dc_chat_is_unpromoted(const dc_chat_t* chat)
{
	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return 0;
	}
	return dc_param_get_int(chat->param, DC_PARAM_UNPROMOTED, 0);
}


/**
 * Check if a chat is verified.  Verified chats contain only verified members
 * and encryption is alwasy enabled.  Verified chats are created using
 * dc_create_group_chat() by setting the 'verified' parameter to true.
 *
 * @memberof dc_chat_t
 * @param chat The chat object.
 * @return 1=chat verified, 0=chat is not verified
 */
int dc_chat_is_verified(const dc_chat_t* chat)
{
	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return 0;
	}
	return (chat->type==DC_CHAT_TYPE_VERIFIED_GROUP);
}


/**
 * Check if a chat is a self talk.  Self talks are normal chats with
 * the only contact DC_CONTACT_ID_SELF.
 *
 * @memberof dc_chat_t
 * @param chat The chat object.
 * @return 1=chat is self talk, 0=chat is no self talk
 */
int dc_chat_is_self_talk(const dc_chat_t* chat)
{
	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		return 0;
	}
	return dc_param_exists(chat->param, DC_PARAM_SELFTALK);
}


int dc_chat_update_param(dc_chat_t* chat)
{
	int success = 0;
	sqlite3_stmt* stmt = dc_sqlite3_prepare(chat->context->sql,
		"UPDATE chats SET param=? WHERE id=?");
	sqlite3_bind_text(stmt, 1, chat->param->packed, -1, SQLITE_STATIC);
	sqlite3_bind_int (stmt, 2, chat->id);
	success = (sqlite3_step(stmt)==SQLITE_DONE)? 1 : 0;
	sqlite3_finalize(stmt);
	return success;
}


static int set_from_stmt(dc_chat_t* chat, sqlite3_stmt* row)
{
	int         row_offset = 0;
	const char* draft_text = NULL;

	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC || row==NULL) {
		return 0;
	}

	dc_chat_empty(chat);

	#define CHAT_FIELDS " c.id,c.type,c.name, c.draft_timestamp,c.draft_txt,c.grpid,c.param,c.archived, c.blocked "
	chat->id              =                    sqlite3_column_int  (row, row_offset++); /* the columns are defined in CHAT_FIELDS */
	chat->type            =                    sqlite3_column_int  (row, row_offset++);
	chat->name            =   dc_strdup((char*)sqlite3_column_text (row, row_offset++));
	chat->draft_timestamp =                    sqlite3_column_int64(row, row_offset++);
	draft_text            =       (const char*)sqlite3_column_text (row, row_offset++);
	chat->grpid           =   dc_strdup((char*)sqlite3_column_text (row, row_offset++));
	dc_param_set_packed(chat->param,    (char*)sqlite3_column_text (row, row_offset++));
	chat->archived        =                    sqlite3_column_int  (row, row_offset++);
	chat->blocked         =                    sqlite3_column_int  (row, row_offset++);

	/* We leave a NULL-pointer for the very usual situation of "no draft".
	Also make sure, draft_text and draft_timestamp are set together */
	if (chat->draft_timestamp && draft_text && draft_text[0]) {
		chat->draft_text = dc_strdup(draft_text);
	}
	else {
		chat->draft_timestamp = 0;
	}

	/* correct the title of some special groups */
	if (chat->id==DC_CHAT_ID_DEADDROP) {
		free(chat->name);
		chat->name = dc_stock_str(chat->context, DC_STR_DEADDROP);
	}
	else if (chat->id==DC_CHAT_ID_ARCHIVED_LINK) {
		free(chat->name);
		char* tempname = dc_stock_str(chat->context, DC_STR_ARCHIVEDCHATS);
			chat->name = dc_mprintf("%s (%i)", tempname, dc_get_archived_cnt(chat->context));
		free(tempname);
	}
	else if (chat->id==DC_CHAT_ID_STARRED) {
		free(chat->name);
		chat->name = dc_stock_str(chat->context, DC_STR_STARREDMSGS);
	}
	else if (dc_param_exists(chat->param, DC_PARAM_SELFTALK)) {
		free(chat->name);
		chat->name = dc_stock_str(chat->context, DC_STR_SELF);
	}

	return row_offset; /* success, return the next row offset */
}


/**
 * Load a chat from the database to the chat object.
 *
 * @private @memberof dc_chat_t
 * @param chat The chat object that should be filled with the data from the database.
 *     Existing data are free()'d before using dc_chat_empty().
 * @param chat_id Chat ID that should be loaded from the database.
 * @return 1=success, 0=error.
 */
int dc_chat_load_from_db(dc_chat_t* chat, uint32_t chat_id)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;

	if (chat==NULL || chat->magic!=DC_CHAT_MAGIC) {
		goto cleanup;
	}

	dc_chat_empty(chat);

	stmt = dc_sqlite3_prepare(chat->context->sql,
		"SELECT " CHAT_FIELDS " FROM chats c WHERE c.id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);

	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}

	if (!set_from_stmt(chat, stmt)) {
		goto cleanup;
	}

	success = 1;

cleanup:
	sqlite3_finalize(stmt);
	return success;
}


/*******************************************************************************
 * Context functions to work with chats
 ******************************************************************************/


size_t dc_get_chat_cnt(dc_context_t* context)
{
	size_t        ret = 0;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || context->sql->cobj==NULL) {
		goto cleanup; /* no database, no chats - this is no error (needed eg. for information) */
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT COUNT(*) FROM chats WHERE id>" DC_STRINGIFY(DC_CHAT_ID_LAST_SPECIAL) " AND blocked=0;");
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}

	ret = sqlite3_column_int(stmt, 0);

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


int dc_add_to_chat_contacts_table(dc_context_t* context, uint32_t chat_id, uint32_t contact_id)
{
	/* add a contact to a chat; the function does not check the type or if any of the record exist or are already added to the chat! */
	int ret = 0;
	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
		"INSERT INTO chats_contacts (chat_id, contact_id) VALUES(?, ?)");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, contact_id);
	ret = (sqlite3_step(stmt)==SQLITE_DONE)? 1 : 0;
	sqlite3_finalize(stmt);
	return ret;
}


/**
 * Get chat object by a chat ID.
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id The ID of the chat to get the chat object for.
 * @return A chat object of the type dc_chat_t, must be freed using dc_chat_unref() when done.
 */
dc_chat_t* dc_get_chat(dc_context_t* context, uint32_t chat_id)
{
	int        success = 0;
	dc_chat_t* obj = dc_chat_new(context);

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	if (!dc_chat_load_from_db(obj, chat_id)) {
		goto cleanup;
	}

	success = 1;

cleanup:
	if (success) {
		return obj;
	}
	else {
		dc_chat_unref(obj);
		return NULL;
	}
}


/**
 * Mark all messages in a chat as _noticed_.
 * _Noticed_ messages are no longer _fresh_ and do not count as being unseen.
 * IMAP/MDNs is not done for noticed messages.  See also dc_marknoticed_contact()
 * and dc_markseen_msgs()
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id The chat ID of which all messages should be marked as being noticed.
 * @return None.
 */
void dc_marknoticed_chat(dc_context_t* context, uint32_t chat_id)
{
	/* marking a chat as "seen" is done by marking all fresh chat messages as "noticed" -
	"noticed" messages are not counted as being unread but are still waiting for being marked as "seen" using dc_markseen_msgs() */
	sqlite3_stmt* stmt;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"UPDATE msgs SET state=" DC_STRINGIFY(DC_STATE_IN_NOTICED) " WHERE chat_id=? AND state=" DC_STRINGIFY(DC_STATE_IN_FRESH) ";");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
}


/**
 * Check, if there is a normal chat with a given contact.
 * To get the chat messages, use dc_get_chat_msgs().
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param contact_id The contact ID to check.
 * @return If there is a normal chat with the given contact_id, this chat_id is
 *     returned.  If there is no normal chat with the contact_id, the function
 *     returns 0.
 */
uint32_t dc_get_chat_id_by_contact_id(dc_context_t* context, uint32_t contact_id)
{
	uint32_t chat_id = 0;
	int      chat_id_blocked = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return 0;
	}

	dc_lookup_real_nchat_by_contact_id(context, contact_id, &chat_id, &chat_id_blocked);

	return chat_id_blocked? 0 : chat_id; /* from outside view, chats only existing in the deaddrop do not exist */
}


uint32_t dc_get_chat_id_by_grpid(dc_context_t* context, const char* grpid, int* ret_blocked, int* ret_verified)
{
	uint32_t      chat_id = 0;
	sqlite3_stmt* stmt = NULL;

	if(ret_blocked)  { *ret_blocked = 0;  }
	if(ret_verified) { *ret_verified = 0; }

	if (context==NULL || grpid==NULL) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT id, blocked, type FROM chats WHERE grpid=?;");
	sqlite3_bind_text (stmt, 1, grpid, -1, SQLITE_STATIC);
	if (sqlite3_step(stmt)==SQLITE_ROW) {
		                    chat_id      =  sqlite3_column_int(stmt, 0);
		if(ret_blocked)  { *ret_blocked  =  sqlite3_column_int(stmt, 1); }
		if(ret_verified) { *ret_verified = (sqlite3_column_int(stmt, 2)==DC_CHAT_TYPE_VERIFIED_GROUP); }
	}

cleanup:
	sqlite3_finalize(stmt);
	return chat_id;
}


/**
 * Create a normal chat with a single user.  To create group chats,
 * see dc_create_group_chat().
 *
 * If there is already an exitant chat, this ID is returned and no new chat is
 * crated.  If there is no existant chat with the user, a new chat is created;
 * this new chat may already contain messages, eg. from the deaddrop, to get the
 * chat messages, use dc_get_chat_msgs().
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param contact_id The contact ID to create the chat for.  If there is already
 *     a chat with this contact, the already existing ID is returned.
 * @return The created or reused chat ID on success. 0 on errors.
 */
uint32_t dc_create_chat_by_contact_id(dc_context_t* context, uint32_t contact_id)
{
	uint32_t      chat_id = 0;
	int           chat_blocked = 0;
	int           send_event = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return 0;
	}

	dc_lookup_real_nchat_by_contact_id(context, contact_id, &chat_id, &chat_blocked);
	if (chat_id) {
		if (chat_blocked) {
			dc_unblock_chat(context, chat_id); /* unblock chat (typically move it from the deaddrop to view) */
			send_event = 1;
		}
		goto cleanup; /* success */
	}

	if (0==dc_real_contact_exists(context, contact_id) && contact_id!=DC_CONTACT_ID_SELF) {
		dc_log_warning(context, 0, "Cannot create chat, contact %i does not exist.", (int)contact_id);
		goto cleanup;
	}

	dc_create_or_lookup_nchat_by_contact_id(context, contact_id, DC_CHAT_NOT_BLOCKED, &chat_id, NULL);
	if (chat_id) {
		send_event = 1;
	}

	dc_scaleup_contact_origin(context, contact_id, DC_ORIGIN_CREATE_CHAT);

cleanup:
	if (send_event) {
		context->cb(context, DC_EVENT_MSGS_CHANGED, 0, 0);
	}

	return chat_id;
}


/**
 * Create a normal chat or a group chat by a messages ID that comes typically
 * from the deaddrop, DC_CHAT_ID_DEADDROP (1).
 *
 * If the given message ID already belongs to a normal chat or to a group chat,
 * the chat ID of this chat is returned and no new chat is created.
 * If a new chat is created, the given message ID is moved to this chat, however,
 * there may be more messages moved to the chat from the deaddrop. To get the
 * chat messages, use dc_get_chat_msgs().
 *
 * If the user is asked before creation, he should be
 * asked whether he wants to chat with the _contact_ belonging to the message;
 * the group names may be really weired when take from the subject of implicit
 * groups and this may look confusing.
 *
 * Moreover, this function also scales up the origin of the contact belonging
 * to the message and, depending on the contacts origin, messages from the
 * same group may be shown or not - so, all in all, it is fine to show the
 * contact name only.
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param msg_id The message ID to create the chat for.
 * @return The created or reused chat ID on success. 0 on errors.
 */
uint32_t dc_create_chat_by_msg_id(dc_context_t* context, uint32_t msg_id)
{
	uint32_t   chat_id  = 0;
	int        send_event = 0;
	dc_msg_t*  msg = dc_msg_new(context);
	dc_chat_t* chat = dc_chat_new(context);

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	if (!dc_msg_load_from_db(msg, context, msg_id)
	 || !dc_chat_load_from_db(chat, msg->chat_id)
	 || chat->id<=DC_CHAT_ID_LAST_SPECIAL) {
		goto cleanup;
	}

	chat_id = chat->id;

	if (chat->blocked) {
		dc_unblock_chat(context, chat->id);
		send_event = 1;
	}

	dc_scaleup_contact_origin(context, msg->from_id, DC_ORIGIN_CREATE_CHAT);

cleanup:
	dc_msg_unref(msg);
	dc_chat_unref(chat);
	if (send_event) {
		context->cb(context, DC_EVENT_MSGS_CHANGED, 0, 0);
	}
	return chat_id;
}


/**
 * Returns all message IDs of the given types in a chat.  Typically used to show
 * a gallery.  The result must be dc_array_unref()'d
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id The chat ID to get all messages with media from.
 * @param msg_type Specify a message type to query here, one of the DC_MSG_* constats.
 * @param or_msg_type Another message type to return, one of the DC_MSG_* constats.
 *     The function will return both types then.  0 if you need only one.
 * @return An array with messages from the given chat ID that have the wanted message types.
 */
dc_array_t* dc_get_chat_media(dc_context_t* context, uint32_t chat_id, int msg_type, int or_msg_type)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return NULL;
	}

	dc_array_t* ret = dc_array_new(context, 100);

	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
		"SELECT id FROM msgs WHERE chat_id=? AND (type=? OR type=?) ORDER BY timestamp, id;");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, msg_type);
	sqlite3_bind_int(stmt, 3, or_msg_type>0? or_msg_type : msg_type);
	while (sqlite3_step(stmt)==SQLITE_ROW) {
		dc_array_add_id(ret, sqlite3_column_int(stmt, 0));
	}
	sqlite3_finalize(stmt);

	return ret;
}


/**
 * Get next/previous message of the same type.
 * Typically used to implement the "next" and "previous" buttons on a media
 * player playing eg. voice messages.
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param curr_msg_id  This is the current (image) message displayed.
 * @param dir 1=get the next (image) message, -1=get the previous one.
 * @return Returns the message ID that should be played next. The
 *     returned message is in the same chat as the given one and has the same type.
 *     Typically, this result is passed again to dc_get_next_media()
 *     later on the next swipe. If there is not next/previous message, the function returns 0.
 */
uint32_t dc_get_next_media(dc_context_t* context, uint32_t curr_msg_id, int dir)
{
	uint32_t    ret_msg_id = 0;
	dc_msg_t*   msg = dc_msg_new(context);
	dc_array_t* list = NULL;
	int         i = 0;
	int         cnt = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	if (!dc_msg_load_from_db(msg, context, curr_msg_id)) {
		goto cleanup;
	}

	if ((list=dc_get_chat_media(context, msg->chat_id, msg->type, 0))==NULL) {
		goto cleanup;
	}

	cnt = dc_array_get_cnt(list);
	for (i = 0; i < cnt; i++) {
		if (curr_msg_id==dc_array_get_id(list, i))
		{
			if (dir > 0) {
				/* get the next message from the current position */
				if (i+1 < cnt) {
					ret_msg_id = dc_array_get_id(list, i+1);
				}
			}
			else if (dir < 0) {
				/* get the previous message from the current position */
				if (i-1 >= 0) {
					ret_msg_id = dc_array_get_id(list, i-1);
				}
			}
			break;
		}
	}


cleanup:
	dc_array_unref(list);
	dc_msg_unref(msg);
	return ret_msg_id;
}


/**
 * Get contact IDs belonging to a chat.
 *
 * - for normal chats, the function always returns exactly one contact,
 *   DC_CONTACT_ID_SELF is _not_ returned.
 *
 * - for group chats all members are returned, DC_CONTACT_ID_SELF is returned
 *   explicitly as it may happen that oneself gets removed from a still existing
 *   group
 *
 * - for the deaddrop, all contacts are returned, DC_CONTACT_ID_SELF is not
 *   added
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id Chat ID to get the belonging contact IDs for.
 * @return an array of contact IDs belonging to the chat; must be freed using dc_array_unref() when done.
 */
dc_array_t* dc_get_chat_contacts(dc_context_t* context, uint32_t chat_id)
{
	/* Normal chats do not include SELF.  Group chats do (as it may happen that one is deleted from a
	groupchat but the chats stays visible, moreover, this makes displaying lists easier) */
	dc_array_t*   ret = dc_array_new(context, 100);
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	if (chat_id==DC_CHAT_ID_DEADDROP) {
		goto cleanup; /* we could also create a list for all contacts in the deaddrop by searching contacts belonging to chats with chats.blocked=2, however, currently this is not needed */
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT cc.contact_id FROM chats_contacts cc"
			" LEFT JOIN contacts c ON c.id=cc.contact_id"
			" WHERE cc.chat_id=?"
			" ORDER BY c.id=1, LOWER(c.name||c.addr), c.id;");
	sqlite3_bind_int(stmt, 1, chat_id);
	while (sqlite3_step(stmt)==SQLITE_ROW) {
		dc_array_add_id(ret, sqlite3_column_int(stmt, 0));
	}

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


/**
 * Get all message IDs belonging to a chat.
 * Optionally, some special markers added to the ID-array may help to
 * implement virtual lists.
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id The chat ID of which the messages IDs should be queried.
 * @param flags If set to DC_GCM_ADD_DAY_MARKER, the marker DC_MSG_ID_DAYMARKER will
 *     be added before each day (regarding the local timezone).  Set this to 0 if you do not want this behaviour.
 * @param marker1before An optional message ID.  If set, the id DC_MSG_ID_MARKER1 will be added just
 *   before the given ID in the returned array.  Set this to 0 if you do not want this behaviour.
 * @return Array of message IDs, must be dc_array_unref()'d when no longer used.
 */
dc_array_t* dc_get_chat_msgs(dc_context_t* context, uint32_t chat_id, uint32_t flags, uint32_t marker1before)
{
	//clock_t       start = clock();

	int           success = 0;
	dc_array_t*   ret = dc_array_new(context, 512);
	sqlite3_stmt* stmt = NULL;

	uint32_t      curr_id;
	time_t        curr_local_timestamp;
	int           curr_day, last_day = 0;
	long          cnv_to_local = dc_gm2local_offset();
	#define       SECONDS_PER_DAY 86400

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || ret==NULL) {
		goto cleanup;
	}

	if (chat_id==DC_CHAT_ID_DEADDROP)
	{
		stmt = dc_sqlite3_prepare(context->sql,
			"SELECT m.id, m.timestamp"
				" FROM msgs m"
				" LEFT JOIN chats ON m.chat_id=chats.id"
				" LEFT JOIN contacts ON m.from_id=contacts.id"
				" WHERE m.from_id!=" DC_STRINGIFY(DC_CONTACT_ID_SELF)
				"   AND m.hidden=0 "
				"   AND chats.blocked=" DC_STRINGIFY(DC_CHAT_DEADDROP_BLOCKED)
				"   AND contacts.blocked=0"
				" ORDER BY m.timestamp,m.id;"); /* the list starts with the oldest message*/
	}
	else if (chat_id==DC_CHAT_ID_STARRED)
	{
		stmt = dc_sqlite3_prepare(context->sql,
			"SELECT m.id, m.timestamp"
				" FROM msgs m"
				" LEFT JOIN contacts ct ON m.from_id=ct.id"
				" WHERE m.starred=1 "
				"   AND m.hidden=0 "
				"   AND ct.blocked=0"
				" ORDER BY m.timestamp,m.id;"); /* the list starts with the oldest message*/
	}
	else
	{
		stmt = dc_sqlite3_prepare(context->sql,
			"SELECT m.id, m.timestamp"
				" FROM msgs m"
				//" LEFT JOIN contacts ct ON m.from_id=ct.id"
				" WHERE m.chat_id=? "
				"   AND m.hidden=0 "
				//"   AND ct.blocked=0" -- we hide blocked-contacts from starred and deaddrop, but we have to show them in groups (otherwise it may be hard to follow conversation, wa and tg do the same. however, maybe this needs discussion some time :)
				" ORDER BY m.timestamp,m.id;"); /* the list starts with the oldest message*/
		sqlite3_bind_int(stmt, 1, chat_id);
	}

	while (sqlite3_step(stmt)==SQLITE_ROW)
	{
		curr_id = sqlite3_column_int(stmt, 0);

		/* add user marker */
		if (curr_id==marker1before) {
			dc_array_add_id(ret, DC_MSG_ID_MARKER1);
		}

		/* add daymarker, if needed */
		if (flags&DC_GCM_ADDDAYMARKER) {
			curr_local_timestamp = (time_t)sqlite3_column_int64(stmt, 1) + cnv_to_local;
			curr_day = curr_local_timestamp/SECONDS_PER_DAY;
			if (curr_day!=last_day) {
				dc_array_add_id(ret, DC_MSG_ID_DAYMARKER);
				last_day = curr_day;
			}
		}

		dc_array_add_id(ret, curr_id);
	}

	success = 1;

cleanup:
	sqlite3_finalize(stmt);

	//dc_log_info(context, 0, "Message list for chat #%i created in %.3f ms.", chat_id, (double)(clock()-start)*1000.0/CLOCKS_PER_SEC);

	if (success) {
		return ret;
	}
	else {
		if (ret) {
			dc_array_unref(ret);
		}
		return NULL;
	}
}


/**
 * Save a draft for a chat in the database.
 * If the draft was modified, an #DC_EVENT_MSGS_CHANGED will be sent that you
 * can use to update your dc_chat_t-objects.
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @param chat_id The chat ID to save the draft for.
 * @param msg The message text to save as a draft.
 * @return None.
 */
void dc_set_text_draft(dc_context_t* context, uint32_t chat_id, const char* msg)
{
	sqlite3_stmt* stmt = NULL;
	dc_chat_t*    chat = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	if ((chat=dc_get_chat(context, chat_id))==NULL) {
		goto cleanup;
	}

	if (msg && msg[0]==0) {
		msg = NULL; // an empty draft is no draft
	}

	if (chat->draft_text==NULL && msg==NULL
	 && chat->draft_timestamp==0) {
		goto cleanup; // nothing to do - there is no old and no new draft
	}

	if (chat->draft_timestamp && chat->draft_text && msg && strcmp(chat->draft_text, msg)==0) {
		goto cleanup; // for equal texts, we do not update the timestamp
	}

	// save draft in object - NULL or empty: clear draft
	free(chat->draft_text);
	chat->draft_text      = msg? dc_strdup(msg) : NULL;
	chat->draft_timestamp = msg? time(NULL) : 0;

	// save draft in database
	stmt = dc_sqlite3_prepare(context->sql,
		"UPDATE chats SET draft_timestamp=?, draft_txt=? WHERE id=?;");
	sqlite3_bind_int64(stmt, 1, chat->draft_timestamp);
	sqlite3_bind_text (stmt, 2, chat->draft_text? chat->draft_text : "", -1, SQLITE_STATIC);
	sqlite3_bind_int  (stmt, 3, chat->id);
	sqlite3_step(stmt);

	context->cb(context, DC_EVENT_MSGS_CHANGED, chat_id, 0);

cleanup:
	sqlite3_finalize(stmt);
	dc_chat_unref(chat);
}


void dc_lookup_real_nchat_by_contact_id(dc_context_t* context, uint32_t contact_id, uint32_t* ret_chat_id, int* ret_chat_blocked)
{
	/* checks for "real" chats or self-chat */
	sqlite3_stmt* stmt = NULL;

	if (ret_chat_id)      { *ret_chat_id = 0;      }
	if (ret_chat_blocked) { *ret_chat_blocked = 0; }

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || context->sql->cobj==NULL) {
		return; /* no database, no chats - this is no error (needed eg. for information) */
	}

	stmt = dc_sqlite3_prepare(context->sql,
			"SELECT c.id, c.blocked"
			" FROM chats c"
			" INNER JOIN chats_contacts j ON c.id=j.chat_id"
			" WHERE c.type=" DC_STRINGIFY(DC_CHAT_TYPE_SINGLE) " AND c.id>" DC_STRINGIFY(DC_CHAT_ID_LAST_SPECIAL) " AND j.contact_id=?;");
	sqlite3_bind_int(stmt, 1, contact_id);
	if (sqlite3_step(stmt)==SQLITE_ROW) {
		if (ret_chat_id)      { *ret_chat_id      = sqlite3_column_int(stmt, 0); }
		if (ret_chat_blocked) { *ret_chat_blocked = sqlite3_column_int(stmt, 1); }
	}
	sqlite3_finalize(stmt);
}


void dc_create_or_lookup_nchat_by_contact_id(dc_context_t* context, uint32_t contact_id, int create_blocked, uint32_t* ret_chat_id, int* ret_chat_blocked)
{
	uint32_t      chat_id = 0;
	int           chat_blocked = 0;
	dc_contact_t* contact = NULL;
	char*         chat_name = NULL;
	char*         q = NULL;
	sqlite3_stmt* stmt = NULL;

	if (ret_chat_id)      { *ret_chat_id = 0;      }
	if (ret_chat_blocked) { *ret_chat_blocked = 0; }

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || context->sql->cobj==NULL) {
		return; /* database not opened - error */
	}

	if (contact_id==0) {
		return;
	}

	dc_lookup_real_nchat_by_contact_id(context, contact_id, &chat_id, &chat_blocked);
	if (chat_id!=0) {
		if (ret_chat_id)      { *ret_chat_id      = chat_id;      }
		if (ret_chat_blocked) { *ret_chat_blocked = chat_blocked; }
		return; /* soon success */
	}

	/* get fine chat name */
	contact = dc_contact_new(context);
	if (!dc_contact_load_from_db(contact, context->sql, contact_id)) {
		goto cleanup;
	}

	chat_name = (contact->name&&contact->name[0])? contact->name : contact->addr;

	/* create chat record; the grpid is only used to make dc_sqlite3_get_rowid() work (we cannot use last_insert_id() due multi-threading) */
	q = sqlite3_mprintf("INSERT INTO chats (type, name, param, blocked, grpid) VALUES(%i, %Q, %Q, %i, %Q)", DC_CHAT_TYPE_SINGLE, chat_name,
		contact_id==DC_CONTACT_ID_SELF? "K=1" : "", create_blocked, contact->addr);
	assert( DC_PARAM_SELFTALK=='K');
	stmt = dc_sqlite3_prepare(context->sql, q);
	if (stmt==NULL) {
		goto cleanup;
	}

    if (sqlite3_step(stmt)!=SQLITE_DONE) {
		goto cleanup;
    }

    chat_id = dc_sqlite3_get_rowid(context->sql, "chats", "grpid", contact->addr);

	sqlite3_free(q);
	q = NULL;
	sqlite3_finalize(stmt);
	stmt = NULL;

	/* add contact IDs to the new chat record (may be replaced by dc_add_to_chat_contacts_table()) */
	q = sqlite3_mprintf("INSERT INTO chats_contacts (chat_id, contact_id) VALUES(%i, %i)", chat_id, contact_id);
	stmt = dc_sqlite3_prepare(context->sql, q);

	if (sqlite3_step(stmt)!=SQLITE_DONE) {
		goto cleanup;
	}

	sqlite3_free(q);
	q = NULL;
	sqlite3_finalize(stmt);
	stmt = NULL;

cleanup:
	sqlite3_free(q);
	sqlite3_finalize(stmt);
	dc_contact_unref(contact);

	if (ret_chat_id)      { *ret_chat_id      = chat_id; }
	if (ret_chat_blocked) { *ret_chat_blocked = create_blocked; }
}


/**
 * Get the total number of messages in a chat.
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id The ID of the chat to count the messages for.
 * @return Number of total messages in the given chat. 0 for errors or empty chats.
 */
int dc_get_msg_cnt(dc_context_t* context, uint32_t chat_id)
{
	int           ret = 0;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT COUNT(*) FROM msgs WHERE chat_id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}

	ret = sqlite3_column_int(stmt, 0);

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


void dc_unarchive_chat(dc_context_t* context, uint32_t chat_id)
{
	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
	    "UPDATE chats SET archived=0 WHERE id=?");
	sqlite3_bind_int (stmt, 1, chat_id);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
}


/**
 * Get the number of _fresh_ messages in a chat.  Typically used to implement
 * a badge with a number in the chatlist.
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id The ID of the chat to count the messages for.
 * @return Number of fresh messages in the given chat. 0 for errors or if there are no fresh messages.
 */
int dc_get_fresh_msg_cnt(dc_context_t* context, uint32_t chat_id)
{
	int           ret = 0;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT COUNT(*) FROM msgs "
		" WHERE state=" DC_STRINGIFY(DC_STATE_IN_FRESH)
		"   AND hidden=0 "
		"   AND chat_id=?;"); /* we have an index over the state-column, this should be sufficient as there are typically only few fresh messages */
	sqlite3_bind_int(stmt, 1, chat_id);

	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}

	ret = sqlite3_column_int(stmt, 0);

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


/**
 * Archive or unarchive a chat.
 *
 * Archived chats are not included in the default chatlist returned
 * by dc_get_chatlist().  Instead, if there are _any_ archived chats,
 * the pseudo-chat with the chat_id DC_CHAT_ID_ARCHIVED_LINK will be added the the
 * end of the chatlist.
 *
 * - To get a list of archived chats, use dc_get_chatlist() with the flag DC_GCL_ARCHIVED_ONLY.
 * - To find out the archived state of a given chat, use dc_chat_get_archived()
 * - Calling this function usually results in the event #DC_EVENT_MSGS_CHANGED
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id The ID of the chat to archive or unarchive.
 * @param archive 1=archive chat, 0=unarchive chat, all other values are reserved for future use
 * @return None
 */
void dc_archive_chat(dc_context_t* context, uint32_t chat_id, int archive)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || chat_id<=DC_CHAT_ID_LAST_SPECIAL || (archive!=0 && archive!=1)) {
		return;
	}

	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
		"UPDATE chats SET archived=? WHERE id=?;");
	sqlite3_bind_int  (stmt, 1, archive);
	sqlite3_bind_int  (stmt, 2, chat_id);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);

	context->cb(context, DC_EVENT_MSGS_CHANGED, 0, 0);
}


void dc_block_chat(dc_context_t* context, uint32_t chat_id, int new_blocking)
{
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"UPDATE chats SET blocked=? WHERE id=?;");
	sqlite3_bind_int(stmt, 1, new_blocking);
	sqlite3_bind_int(stmt, 2, chat_id);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
}


void dc_unblock_chat(dc_context_t* context, uint32_t chat_id)
{
	dc_block_chat(context, chat_id, DC_CHAT_NOT_BLOCKED);
}


/**
 * Delete a chat.
 *
 * Messages are deleted from the device and the chat database entry is deleted.
 * After that, the event #DC_EVENT_MSGS_CHANGED is posted.
 *
 * Things that are _not_ done implicitly:
 *
 * - Messages are **not deleted from the server**.
 * - The chat or the contact is **not blocked**, so new messages from the user/the group may appear
 *   and the user may create the chat again.
 * - **Groups are not left** - this would
 *   be unexpected as (1) deleting a normal chat also does not prevent new mails
 *   from arriving, (2) leaving a group requires sending a message to
 *   all group members - esp. for groups not used for a longer time, this is
 *   really unexpected when deletion results in contacting all members again,
 *   (3) only leaving groups is also a valid usecase.
 *
 * To leave a chat explicitly, use dc_remove_contact_from_chat() with
 * chat_id=DC_CONTACT_ID_SELF)
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id The ID of the chat to delete.
 * @return None
 */
void dc_delete_chat(dc_context_t* context, uint32_t chat_id)
{
	/* Up to 2017-11-02 deleting a group also implied leaving it, see above why we have changed this. */
	int        pending_transaction = 0;
	dc_chat_t* obj = dc_chat_new(context);
	char*      q3 = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || chat_id<=DC_CHAT_ID_LAST_SPECIAL) {
		goto cleanup;
	}

	if (!dc_chat_load_from_db(obj, chat_id)) {
		goto cleanup;
	}

	dc_sqlite3_begin_transaction(context->sql);
	pending_transaction = 1;

		q3 = sqlite3_mprintf("DELETE FROM msgs_mdns WHERE msg_id IN (SELECT id FROM msgs WHERE chat_id=%i);", chat_id);
		if (!dc_sqlite3_execute(context->sql, q3)) {
			goto cleanup;
		}
		sqlite3_free(q3);
		q3 = NULL;

		q3 = sqlite3_mprintf("DELETE FROM msgs WHERE chat_id=%i;", chat_id);
		if (!dc_sqlite3_execute(context->sql, q3)) {
			goto cleanup;
		}
		sqlite3_free(q3);
		q3 = NULL;

		q3 = sqlite3_mprintf("DELETE FROM chats_contacts WHERE chat_id=%i;", chat_id);
		if (!dc_sqlite3_execute(context->sql, q3)) {
			goto cleanup;
		}
		sqlite3_free(q3);
		q3 = NULL;

		q3 = sqlite3_mprintf("DELETE FROM chats WHERE id=%i;", chat_id);
		if (!dc_sqlite3_execute(context->sql, q3)) {
			goto cleanup;
		}
		sqlite3_free(q3);
		q3 = NULL;

	dc_sqlite3_commit(context->sql);
	pending_transaction = 0;

	context->cb(context, DC_EVENT_MSGS_CHANGED, 0, 0);

cleanup:
	if (pending_transaction) { dc_sqlite3_rollback(context->sql); }
	dc_chat_unref(obj);
	sqlite3_free(q3);
}


/*******************************************************************************
 * Handle Group Chats
 ******************************************************************************/


#define IS_SELF_IN_GROUP     (dc_is_contact_in_chat(context, chat_id, DC_CONTACT_ID_SELF)==1)
#define DO_SEND_STATUS_MAILS (dc_param_get_int(chat->param, DC_PARAM_UNPROMOTED, 0)==0)


int dc_is_group_explicitly_left(dc_context_t* context, const char* grpid)
{
	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql, "SELECT id FROM leftgrps WHERE grpid=?;");
	sqlite3_bind_text (stmt, 1, grpid, -1, SQLITE_STATIC);
	int ret = (sqlite3_step(stmt)==SQLITE_ROW);
	sqlite3_finalize(stmt);
	return ret;
}


void dc_set_group_explicitly_left(dc_context_t* context, const char* grpid)
{
	if (!dc_is_group_explicitly_left(context, grpid))
	{
		sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql, "INSERT INTO leftgrps (grpid) VALUES(?);");
		sqlite3_bind_text (stmt, 1, grpid, -1, SQLITE_STATIC);
		sqlite3_step(stmt);
		sqlite3_finalize(stmt);
	}
}


static int real_group_exists(dc_context_t* context, uint32_t chat_id)
{
	// check if a group or a verified group exists under the given ID
	sqlite3_stmt* stmt = NULL;
	int           ret = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || context->sql->cobj==NULL
	 || chat_id<=DC_CHAT_ID_LAST_SPECIAL) {
		return 0;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT id FROM chats "
		" WHERE id=? "
		"   AND (type=" DC_STRINGIFY(DC_CHAT_TYPE_GROUP) " OR type=" DC_STRINGIFY(DC_CHAT_TYPE_VERIFIED_GROUP) ");");
	sqlite3_bind_int(stmt, 1, chat_id);
	if (sqlite3_step(stmt)==SQLITE_ROW) {
		ret = 1;
	}
	sqlite3_finalize(stmt);

	return ret;
}


/**
 * Create a new group chat.
 *
 * After creation, the group has one member with the
 * ID DC_CONTACT_ID_SELF and is in _unpromoted_ state.  This means, you can
 * add or remove members, change the name, the group image and so on without
 * messages being sent to all group members.
 *
 * This changes as soon as the first message is sent to the group members and
 * the group becomes _promoted_.  After that, all changes are synced with all
 * group members by sending status message.
 *
 * To check, if a chat is still unpromoted, you dc_chat_is_unpromoted()
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @param verified If set to 1 the function creates a secure verfied group.
 *     Only secure-verified members are allowd in these groups and end-to-end-encryption is always enabled.
 * @param chat_name The name of the group chat to create.
 *     The name may be changed later using dc_set_chat_name().
 *     To find out the name of a group later, see dc_chat_get_name()
 * @return The chat ID of the new group chat, 0 on errors.
 */
uint32_t dc_create_group_chat(dc_context_t* context, int verified, const char* chat_name)
{
	uint32_t      chat_id = 0;
	char*         draft_txt = NULL;
	char*         grpid = NULL;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || chat_name==NULL || chat_name[0]==0) {
		return 0;
	}

	draft_txt = dc_stock_str_repl_string(context, DC_STR_NEWGROUPDRAFT, chat_name);
	grpid = dc_create_id();

	stmt = dc_sqlite3_prepare(context->sql,
		"INSERT INTO chats (type, name, draft_timestamp, draft_txt, grpid, param) VALUES(?, ?, ?, ?, ?, 'U=1');" /*U=DC_PARAM_UNPROMOTED*/);
	sqlite3_bind_int  (stmt, 1, verified? DC_CHAT_TYPE_VERIFIED_GROUP : DC_CHAT_TYPE_GROUP);
	sqlite3_bind_text (stmt, 2, chat_name, -1, SQLITE_STATIC);
	sqlite3_bind_int64(stmt, 3, time(NULL));
	sqlite3_bind_text (stmt, 4, draft_txt, -1, SQLITE_STATIC);
	sqlite3_bind_text (stmt, 5, grpid, -1, SQLITE_STATIC);
	if ( sqlite3_step(stmt)!=SQLITE_DONE) {
		goto cleanup;
	}

	if ((chat_id=dc_sqlite3_get_rowid(context->sql, "chats", "grpid", grpid))==0) {
		goto cleanup;
	}

	if (dc_add_to_chat_contacts_table(context, chat_id, DC_CONTACT_ID_SELF)) {
		goto cleanup;
	}

cleanup:
	sqlite3_finalize(stmt);
	free(draft_txt);
	free(grpid);

	if (chat_id) {
		context->cb(context, DC_EVENT_MSGS_CHANGED, 0, 0);
	}

	return chat_id;
}


/**
 * Set group name.
 *
 * If the group is already _promoted_ (any message was sent to the group),
 * all group members are informed by a special status message that is sent automatically by this function.
 *
 * Sends out #DC_EVENT_CHAT_MODIFIED and #DC_EVENT_MSGS_CHANGED if a status message was sent.
 *
 * @memberof dc_context_t
 * @param chat_id The chat ID to set the name for.  Must be a group chat.
 * @param new_name New name of the group.
 * @param context The context as created by dc_context_new().
 * @return 1=success, 0=error
 */
int dc_set_chat_name(dc_context_t* context, uint32_t chat_id, const char* new_name)
{
	/* the function only sets the names of group chats; normal chats get their names from the contacts */
	int        success = 0;
	dc_chat_t* chat = dc_chat_new(context);
	dc_msg_t*  msg = dc_msg_new(context);
	char*      q3 = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || new_name==NULL || new_name[0]==0 || chat_id<=DC_CHAT_ID_LAST_SPECIAL) {
		goto cleanup;
	}

	if (0==real_group_exists(context, chat_id)
	 || 0==dc_chat_load_from_db(chat, chat_id)) {
		goto cleanup;
	}

	if (strcmp(chat->name, new_name)==0) {
		success = 1;
		goto cleanup; /* name not modified */
	}

	if (!IS_SELF_IN_GROUP) {
		dc_log_error(context, DC_ERROR_SELF_NOT_IN_GROUP, NULL);
		goto cleanup; /* we shoud respect this - whatever we send to the group, it gets discarded anyway! */
	}

	q3 = sqlite3_mprintf("UPDATE chats SET name=%Q WHERE id=%i;", new_name, chat_id);
	if (!dc_sqlite3_execute(context->sql, q3)) {
		goto cleanup;
	}

	/* send a status mail to all group members, also needed for outself to allow multi-client */
	if (DO_SEND_STATUS_MAILS)
	{
		msg->type = DC_MSG_TEXT;
		msg->text = dc_stock_str_repl_string2(context, DC_STR_MSGGRPNAME, chat->name, new_name);
		dc_param_set_int(msg->param, DC_PARAM_CMD, DC_CMD_GROUPNAME_CHANGED);
		msg->id = dc_send_msg(context, chat_id, msg);
		context->cb(context, DC_EVENT_MSGS_CHANGED, chat_id, msg->id);
	}
	context->cb(context, DC_EVENT_CHAT_MODIFIED, chat_id, 0);

	success = 1;

cleanup:
	sqlite3_free(q3);
	dc_chat_unref(chat);
	dc_msg_unref(msg);
	return success;
}


/**
 * Set group profile image.
 *
 * If the group is already _promoted_ (any message was sent to the group),
 * all group members are informed by a special status message that is sent automatically by this function.
 *
 * Sends out #DC_EVENT_CHAT_MODIFIED and #DC_EVENT_MSGS_CHANGED if a status message was sent.
 *
 * To find out the profile image of a chat, use dc_chat_get_profile_image()
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @param chat_id The chat ID to set the image for.
 * @param new_image Full path of the image to use as the group image.  If you pass NULL here,
 *     the group image is deleted (for promoted groups, all members are informed about this change anyway).
 * @return 1=success, 0=error
 */
int dc_set_chat_profile_image(dc_context_t* context, uint32_t chat_id, const char* new_image /*NULL=remove image*/)
{
	int        success = 0;
	dc_chat_t* chat = dc_chat_new(context);
	dc_msg_t*  msg = dc_msg_new(context);

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || chat_id<=DC_CHAT_ID_LAST_SPECIAL) {
		goto cleanup;
	}

	if (0==real_group_exists(context, chat_id)
	 || 0==dc_chat_load_from_db(chat, chat_id)) {
		goto cleanup;
	}

	if (!IS_SELF_IN_GROUP) {
		dc_log_error(context, DC_ERROR_SELF_NOT_IN_GROUP, NULL);
		goto cleanup; /* we shoud respect this - whatever we send to the group, it gets discarded anyway! */
	}

	dc_param_set(chat->param, DC_PARAM_PROFILE_IMAGE, new_image/*may be NULL*/);
	if (!dc_chat_update_param(chat)) {
		goto cleanup;
	}

	/* send a status mail to all group members, also needed for outself to allow multi-client */
	if (DO_SEND_STATUS_MAILS)
	{
		dc_param_set_int(msg->param, DC_PARAM_CMD,     DC_CMD_GROUPIMAGE_CHANGED);
		dc_param_set    (msg->param, DC_PARAM_CMD_ARG, new_image);
		msg->type = DC_MSG_TEXT;
		msg->text = dc_stock_str(context, new_image? DC_STR_MSGGRPIMGCHANGED : DC_STR_MSGGRPIMGDELETED);
		msg->id = dc_send_msg(context, chat_id, msg);
		context->cb(context, DC_EVENT_MSGS_CHANGED, chat_id, msg->id);
	}
	context->cb(context, DC_EVENT_CHAT_MODIFIED, chat_id, 0);

	success = 1;

cleanup:
	dc_chat_unref(chat);
	dc_msg_unref(msg);
	return success;
}


int dc_get_chat_contact_cnt(dc_context_t* context, uint32_t chat_id)
{
	int ret = 0;
	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
		"SELECT COUNT(*) FROM chats_contacts WHERE chat_id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);
	if (sqlite3_step(stmt)==SQLITE_ROW) {
		ret = sqlite3_column_int(stmt, 0);
	}
	sqlite3_finalize(stmt);
	return ret;
}


/**
 * Check if a given contact ID is a member of a group chat.
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @param chat_id The chat ID to check.
 * @param contact_id The contact ID to check.  To check if yourself is member
 *     of the chat, pass DC_CONTACT_ID_SELF (1) here.
 * @return 1=contact ID is member of chat ID, 0=contact is not in chat
 */
int dc_is_contact_in_chat(dc_context_t* context, uint32_t chat_id, uint32_t contact_id)
{
	/* this function works for group and for normal chats, however, it is more useful for group chats.
	DC_CONTACT_ID_SELF may be used to check, if the user itself is in a group chat (DC_CONTACT_ID_SELF is not added to normal chats) */
	int           ret = 0;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT contact_id FROM chats_contacts WHERE chat_id=? AND contact_id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, contact_id);
	ret = (sqlite3_step(stmt)==SQLITE_ROW)? 1 : 0;

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


int dc_add_contact_to_chat_ex(dc_context_t* context, uint32_t chat_id, uint32_t contact_id, int flags)
{
	int              success = 0;
	dc_contact_t*    contact = dc_get_contact(context, contact_id);
	dc_chat_t*       chat = dc_chat_new(context);
	dc_msg_t*        msg = dc_msg_new(context);
	char*            self_addr = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || contact==NULL || chat_id<=DC_CHAT_ID_LAST_SPECIAL) {
		goto cleanup;
	}

	if (0==real_group_exists(context, chat_id) /*this also makes sure, not contacts are added to special or normal chats*/
	 || (0==dc_real_contact_exists(context, contact_id) && contact_id!=DC_CONTACT_ID_SELF)
	 || 0==dc_chat_load_from_db(chat, chat_id)) {
		goto cleanup;
	}

	if (!IS_SELF_IN_GROUP) {
		dc_log_error(context, DC_ERROR_SELF_NOT_IN_GROUP, NULL);
		goto cleanup; /* we shoud respect this - whatever we send to the group, it gets discarded anyway! */
	}

	if ((flags&DC_FROM_HANDSHAKE) && dc_param_get_int(chat->param, DC_PARAM_UNPROMOTED, 0)==1) {
		// after a handshake, force sending the `Chat-Group-Member-Added` message
		dc_param_set(chat->param, DC_PARAM_UNPROMOTED, NULL);
		dc_chat_update_param(chat);
	}

	self_addr = dc_sqlite3_get_config(context->sql, "configured_addr", "");
	if (strcasecmp(contact->addr, self_addr)==0) {
		goto cleanup; /* ourself is added using DC_CONTACT_ID_SELF, do not add it explicitly. if SELF is not in the group, members cannot be added at all. */
	}

	if (dc_is_contact_in_chat(context, chat_id, contact_id))
	{
		if (!(flags&DC_FROM_HANDSHAKE)) {
			success = 1;
			goto cleanup;
		}
		// else continue and send status mail
	}
	else
	{
		if (chat->type==DC_CHAT_TYPE_VERIFIED_GROUP)
		{
			if (dc_contact_is_verified(contact)!=DC_BIDIRECT_VERIFIED) {
				dc_log_error(context, 0, "Only bidirectional verified contacts can be added to verfied groups.");
				goto cleanup;
			}
		}

		if (0==dc_add_to_chat_contacts_table(context, chat_id, contact_id)) {
			goto cleanup;
		}
	}

	/* send a status mail to all group members */
	if (DO_SEND_STATUS_MAILS)
	{
		msg->type = DC_MSG_TEXT;
		msg->text = dc_stock_str_repl_string(context, DC_STR_MSGADDMEMBER, (contact->authname&&contact->authname[0])? contact->authname : contact->addr);
		dc_param_set_int(msg->param, DC_PARAM_CMD,      DC_CMD_MEMBER_ADDED_TO_GROUP);
		dc_param_set    (msg->param, DC_PARAM_CMD_ARG,  contact->addr);
		dc_param_set_int(msg->param, DC_PARAM_CMD_ARG2, flags); // combine the Secure-Join protocol headers with the Chat-Group-Member-Added header
		msg->id = dc_send_msg(context, chat_id, msg);
		context->cb(context, DC_EVENT_MSGS_CHANGED, chat_id, msg->id);
	}
	context->cb(context, DC_EVENT_CHAT_MODIFIED, chat_id, 0);

	success = 1;

cleanup:
	dc_chat_unref(chat);
	dc_contact_unref(contact);
	dc_msg_unref(msg);
	free(self_addr);
	return success;
}


/**
 * Add a member to a group.
 *
 * If the group is already _promoted_ (any message was sent to the group),
 * all group members are informed by a special status message that is sent automatically by this function.
 *
 * If the group is a verified group, only verified contacts can be added to the group.
 *
 * Sends out #DC_EVENT_CHAT_MODIFIED and #DC_EVENT_MSGS_CHANGED if a status message was sent.
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @param chat_id The chat ID to add the contact to.  Must be a group chat.
 * @param contact_id The contact ID to add to the chat.
 * @return 1=member added to group, 0=error
 */
int dc_add_contact_to_chat(dc_context_t* context, uint32_t chat_id, uint32_t contact_id /*may be DC_CONTACT_ID_SELF*/)
{
	return dc_add_contact_to_chat_ex(context, chat_id, contact_id, 0);
}


/**
 * Remove a member from a group.
 *
 * If the group is already _promoted_ (any message was sent to the group),
 * all group members are informed by a special status message that is sent automatically by this function.
 *
 * Sends out #DC_EVENT_CHAT_MODIFIED and #DC_EVENT_MSGS_CHANGED if a status message was sent.
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @param chat_id The chat ID to remove the contact from.  Must be a group chat.
 * @param contact_id The contact ID to remove from the chat.
 * @return 1=member removed from group, 0=error
 */
int dc_remove_contact_from_chat(dc_context_t* context, uint32_t chat_id, uint32_t contact_id /*may be DC_CONTACT_ID_SELF*/)
{
	int           success = 0;
	dc_contact_t* contact = dc_get_contact(context, contact_id);
	dc_chat_t*    chat = dc_chat_new(context);
	dc_msg_t*     msg = dc_msg_new(context);
	char*         q3 = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || chat_id<=DC_CHAT_ID_LAST_SPECIAL || (contact_id<=DC_CONTACT_ID_LAST_SPECIAL && contact_id!=DC_CONTACT_ID_SELF)) {
		goto cleanup; /* we do not check if "contact_id" exists but just delete all records with the id from chats_contacts */
	}                 /* this allows to delete pending references to deleted contacts.  Of course, this should _not_ happen. */

	if (0==real_group_exists(context, chat_id)
	 || 0==dc_chat_load_from_db(chat, chat_id)) {
		goto cleanup;
	}

	if (!IS_SELF_IN_GROUP) {
		dc_log_error(context, DC_ERROR_SELF_NOT_IN_GROUP, NULL);
		goto cleanup; /* we shoud respect this - whatever we send to the group, it gets discarded anyway! */
	}

	/* send a status mail to all group members - we need to do this before we update the database -
	otherwise the !IS_SELF_IN_GROUP__-check in dc_chat_send_msg() will fail. */
	if (contact)
	{
		if (DO_SEND_STATUS_MAILS)
		{
			msg->type = DC_MSG_TEXT;
			if (contact->id==DC_CONTACT_ID_SELF) {
				dc_set_group_explicitly_left(context, chat->grpid);
				msg->text = dc_stock_str(context, DC_STR_MSGGROUPLEFT);
			}
			else {
				msg->text = dc_stock_str_repl_string(context, DC_STR_MSGDELMEMBER, (contact->authname&&contact->authname[0])? contact->authname : contact->addr);
			}
			dc_param_set_int(msg->param, DC_PARAM_CMD,       DC_CMD_MEMBER_REMOVED_FROM_GROUP);
			dc_param_set    (msg->param, DC_PARAM_CMD_ARG, contact->addr);
			msg->id = dc_send_msg(context, chat_id, msg);
			context->cb(context, DC_EVENT_MSGS_CHANGED, chat_id, msg->id);
		}
	}

	q3 = sqlite3_mprintf("DELETE FROM chats_contacts WHERE chat_id=%i AND contact_id=%i;", chat_id, contact_id);
	if (!dc_sqlite3_execute(context->sql, q3)) {
		goto cleanup;
	}

	context->cb(context, DC_EVENT_CHAT_MODIFIED, chat_id, 0);

	success = 1;

cleanup:
	sqlite3_free(q3);
	dc_chat_unref(chat);
	dc_contact_unref(contact);
	dc_msg_unref(msg);
	return success;
}


/*******************************************************************************
 * Sending messages
 ******************************************************************************/


static int last_msg_in_chat_encrypted(dc_sqlite3_t* sql, uint32_t chat_id)
{
	int last_is_encrypted = 0;
	sqlite3_stmt* stmt = dc_sqlite3_prepare(sql,
		"SELECT param "
		" FROM msgs "
		" WHERE timestamp=(SELECT MAX(timestamp) FROM msgs WHERE chat_id=?) "
		" ORDER BY id DESC;");
	sqlite3_bind_int(stmt, 1, chat_id);
	if (sqlite3_step(stmt)==SQLITE_ROW) {
		dc_param_t* msg_param = dc_param_new();
		dc_param_set_packed(msg_param, (char*)sqlite3_column_text(stmt, 0));
		if (dc_param_exists(msg_param, DC_PARAM_GUARANTEE_E2EE)) {
			last_is_encrypted = 1;
		}
		dc_param_unref(msg_param);
	}
	sqlite3_finalize(stmt);
	return last_is_encrypted;
}


static uint32_t send_msg_raw(dc_context_t* context, dc_chat_t* chat, const dc_msg_t* msg, time_t timestamp)
{
	char*         rfc724_mid = NULL;
	sqlite3_stmt* stmt = NULL;
	uint32_t      msg_id = 0;
	uint32_t      to_id = 0;

	if (!DC_CHAT_TYPE_CAN_SEND(chat->type)) {
		dc_log_error(context, 0, "Cannot send to chat type #%i.", chat->type);
		goto cleanup;
	}

	if (DC_CHAT_TYPE_IS_MULTI(chat->type) && !dc_is_contact_in_chat(context, chat->id, DC_CONTACT_ID_SELF)) {
		dc_log_error(context, DC_ERROR_SELF_NOT_IN_GROUP, NULL);
		goto cleanup;
	}

	{
		char* from = dc_sqlite3_get_config(context->sql, "configured_addr", NULL);
		if (from==NULL) {
			dc_log_error(context, 0, "Cannot send message, not configured.");
			goto cleanup;
		}
		rfc724_mid = dc_create_outgoing_rfc724_mid(DC_CHAT_TYPE_IS_MULTI(chat->type)? chat->grpid : NULL, from);
		free(from);
	}

	if (chat->type==DC_CHAT_TYPE_SINGLE)
	{
		stmt = dc_sqlite3_prepare(context->sql,
			"SELECT contact_id FROM chats_contacts WHERE chat_id=?;");
		sqlite3_bind_int(stmt, 1, chat->id);
		if (sqlite3_step(stmt)!=SQLITE_ROW) {
			dc_log_error(context, 0, "Cannot send message, contact for chat #%i not found.", chat->id);
			goto cleanup;
		}
		to_id = sqlite3_column_int(stmt, 0);
		sqlite3_finalize(stmt);
		stmt = NULL;
	}
	else if (DC_CHAT_TYPE_IS_MULTI(chat->type))
	{
		if (dc_param_get_int(chat->param, DC_PARAM_UNPROMOTED, 0)==1) {
			/* mark group as being no longer unpromoted */
			dc_param_set(chat->param, DC_PARAM_UNPROMOTED, NULL);
			dc_chat_update_param(chat);
		}
	}

	/* check if we can guarantee E2EE for this message.  If we can, we won't send the message without E2EE later (because of a reset, changed settings etc. - messages may be delayed significally if there is no network present) */
	int do_guarantee_e2ee = 0;
	if (context->e2ee_enabled && dc_param_get_int(msg->param, DC_PARAM_FORCE_PLAINTEXT, 0)==0)
	{
		int can_encrypt = 1, all_mutual = 1; /* be optimistic */
		stmt = dc_sqlite3_prepare(context->sql,
			"SELECT ps.prefer_encrypted "
			 " FROM chats_contacts cc "
			 " LEFT JOIN contacts c ON cc.contact_id=c.id "
			 " LEFT JOIN acpeerstates ps ON c.addr=ps.addr "
			 " WHERE cc.chat_id=? "                                               /* take care that this statement returns NULL rows if there is no peerstates for a chat member! */
			 " AND cc.contact_id>" DC_STRINGIFY(DC_CONTACT_ID_LAST_SPECIAL) ";"); /* for DC_PARAM_SELFTALK this statement does not return any row */
		sqlite3_bind_int(stmt, 1, chat->id);
		while (sqlite3_step(stmt)==SQLITE_ROW)
		{
			if (sqlite3_column_type(stmt, 0)==SQLITE_NULL) {
				can_encrypt = 0;
				all_mutual = 0;
			}
			else {
				/* the peerstate exist, so we have either public_key or gossip_key and can encrypt potentially */
				int prefer_encrypted = sqlite3_column_int(stmt, 0);
				if (prefer_encrypted!=DC_PE_MUTUAL) {
					all_mutual = 0;
				}
			}
		}
		sqlite3_finalize(stmt);
		stmt = NULL;

		if (can_encrypt)
		{
			if (all_mutual) {
				do_guarantee_e2ee = 1;
			}
			else {
				if (last_msg_in_chat_encrypted(context->sql, chat->id)) {
					do_guarantee_e2ee = 1;
				}
			}
		}
	}

	if (do_guarantee_e2ee) {
		dc_param_set_int(msg->param, DC_PARAM_GUARANTEE_E2EE, 1);
	}
	dc_param_set(msg->param, DC_PARAM_ERRONEOUS_E2EE, NULL); /* reset eg. on forwarding */

	/* add message to the database */
	stmt = dc_sqlite3_prepare(context->sql,
		"INSERT INTO msgs (rfc724_mid,chat_id,from_id,to_id, timestamp,type,state, txt,param,hidden) VALUES (?,?,?,?, ?,?,?, ?,?,?);");
	sqlite3_bind_text (stmt,  1, rfc724_mid, -1, SQLITE_STATIC);
	sqlite3_bind_int  (stmt,  2, chat->id);
	sqlite3_bind_int  (stmt,  3, DC_CONTACT_ID_SELF);
	sqlite3_bind_int  (stmt,  4, to_id);
	sqlite3_bind_int64(stmt,  5, timestamp);
	sqlite3_bind_int  (stmt,  6, msg->type);
	sqlite3_bind_int  (stmt,  7, DC_STATE_OUT_PENDING);
	sqlite3_bind_text (stmt,  8, msg->text? msg->text : "",  -1, SQLITE_STATIC);
	sqlite3_bind_text (stmt,  9, msg->param->packed, -1, SQLITE_STATIC);
	sqlite3_bind_int  (stmt, 10, msg->hidden);
	if (sqlite3_step(stmt)!=SQLITE_DONE) {
		dc_log_error(context, 0, "Cannot send message, cannot insert to database.", chat->id);
		goto cleanup;
	}

	msg_id = dc_sqlite3_get_rowid(context->sql, "msgs", "rfc724_mid", rfc724_mid);
	dc_job_add(context, DC_JOB_SEND_MSG_TO_SMTP, msg_id, NULL, 0);

cleanup:
	free(rfc724_mid);
	sqlite3_finalize(stmt);
	return msg_id;
}


/**
 * Send a message of any type to a chat. The given message object is not unref'd
 * by the function but some fields are set up.
 *
 * Sends the event #DC_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * To send a simple text message, you can also use dc_send_text_msg()
 * which is easier to use.
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id Chat ID to send the message to.
 * @param msg Message object to send to the chat defined by the chat ID.
 *     The function does not take ownership of the object, so you have to
 *     free it using dc_msg_unref() as usual.
 * @return The ID of the message that is about being sent.
 */
uint32_t dc_send_msg(dc_context_t* context, uint32_t chat_id, dc_msg_t* msg)
{
	char*      pathNfilename = NULL;
	dc_chat_t* chat = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || msg==NULL || chat_id<=DC_CHAT_ID_LAST_SPECIAL) {
		return 0;
	}

	msg->id      = 0;
	msg->context = context;

	if (msg->type==DC_MSG_TEXT)
	{
		; /* the caller should check if the message text is empty */
	}
	else if (DC_MSG_NEEDS_ATTACHMENT(msg->type))
	{
		pathNfilename = dc_param_get(msg->param, DC_PARAM_FILE, NULL);
		if (pathNfilename)
		{
			/* Got an attachment. Take care, the file may not be ready in this moment!
			This is useful eg. if a video should be sent and already shown as "being processed" in the chat.
			In this case, the user should create an `.increation`; when the file is deleted later on, the message is sent.
			(we do not use a state in the database as this would make eg. forwarding such messages much more complicated) */

			if (msg->type==DC_MSG_FILE || msg->type==DC_MSG_IMAGE)
			{
				/* Correct the type, take care not to correct already very special formats as GIF or VOICE.
				Typical conversions:
				- from FILE to AUDIO/VIDEO/IMAGE
				- from FILE/IMAGE to GIF */
				int   better_type = 0;
				char* better_mime = NULL;
				dc_msg_guess_msgtype_from_suffix(pathNfilename, &better_type, &better_mime);
				if (better_type) {
					msg->type = better_type;
					dc_param_set(msg->param, DC_PARAM_MIMETYPE, better_mime);
				}
				free(better_mime);
			}

			if ((msg->type==DC_MSG_IMAGE || msg->type==DC_MSG_GIF)
			 && (dc_param_get_int(msg->param, DC_PARAM_WIDTH, 0)<=0 || dc_param_get_int(msg->param, DC_PARAM_HEIGHT, 0)<=0)) {
				/* set width/height of images, if not yet done */
				unsigned char* buf = NULL; size_t buf_bytes; uint32_t w, h;
				if (dc_read_file(pathNfilename, (void**)&buf, &buf_bytes, msg->context)) {
					if (dc_get_filemeta(buf, buf_bytes, &w, &h)) {
						dc_param_set_int(msg->param, DC_PARAM_WIDTH, w);
						dc_param_set_int(msg->param, DC_PARAM_HEIGHT, h);
					}
				}
				free(buf);
			}

			dc_log_info(context, 0, "Attaching \"%s\" for message type #%i.", pathNfilename, (int)msg->type);

			if (msg->text) { free(msg->text); }
			if (msg->type==DC_MSG_AUDIO) {
				char* filename = dc_get_filename(pathNfilename);
				char* author = dc_param_get(msg->param, DC_PARAM_AUTHORNAME, "");
				char* title = dc_param_get(msg->param, DC_PARAM_TRACKNAME, "");
				msg->text = dc_mprintf("%s %s %s", filename, author, title); /* for outgoing messages, also add the mediainfo. For incoming messages, this is not needed as the filename is build from these information */
				free(filename);
				free(author);
				free(title);
			}
			else if (DC_MSG_MAKE_FILENAME_SEARCHABLE(msg->type)) {
				msg->text = dc_get_filename(pathNfilename);
			}
			else if (DC_MSG_MAKE_SUFFIX_SEARCHABLE(msg->type)) {
				msg->text = dc_get_filesuffix_lc(pathNfilename);
			}
		}
		else
		{
			dc_log_error(context, 0, "Attachment missing for message of type #%i.", (int)msg->type); /* should not happen */
			goto cleanup;
		}
	}
	else
	{
		dc_log_error(context, 0, "Cannot send messages of type #%i.", (int)msg->type); /* should not happen */
		goto cleanup;
	}

	dc_unarchive_chat(context, chat_id);

	context->smtp->log_connect_errors = 1;

	chat = dc_chat_new(context);
	if (dc_chat_load_from_db(chat, chat_id)) {
		msg->id = send_msg_raw(context, chat, msg, dc_create_smeared_timestamp(context));
		if (msg ->id==0) {
			goto cleanup; /* error already logged */
		}
	}

	context->cb(context, DC_EVENT_MSGS_CHANGED, chat_id, msg->id);

cleanup:
	dc_chat_unref(chat);
	free(pathNfilename);
	return msg->id;
}


/**
 * Send a simple text message a given chat.
 *
 * Sends the event #DC_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * See also dc_send_image_msg().
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id Chat ID to send the text message to.
 * @param text_to_send Text to send to the chat defined by the chat ID.
 * @return The ID of the message that is about being sent.
 */
uint32_t dc_send_text_msg(dc_context_t* context, uint32_t chat_id, const char* text_to_send)
{
	dc_msg_t* msg = dc_msg_new(context);
	uint32_t  ret = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || chat_id<=DC_CHAT_ID_LAST_SPECIAL || text_to_send==NULL) {
		goto cleanup;
	}

	msg->type = DC_MSG_TEXT;
	msg->text = dc_strdup(text_to_send);

	ret = dc_send_msg(context, chat_id, msg);

cleanup:
	dc_msg_unref(msg);
	return ret;
}


/**
 * Send an image to a chat.
 *
 * Sends the event #DC_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * See also dc_send_text_msg().
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id Chat ID to send the image to.
 * @param file Full path of the image file to send. The core may make a copy of the file.
 * @param filemime Mime type of the file to send. NULL if you don't know or don't care.
 * @param width Width in pixel of the file. 0 if you don't know or don't care.
 * @param height Width in pixel of the file. 0 if you don't know or don't care.
 * @return The ID of the message that is about being sent.
 */
uint32_t dc_send_image_msg(dc_context_t* context, uint32_t chat_id, const char* file, const char* filemime, int width, int height)
{
	dc_msg_t* msg = dc_msg_new(context);
	uint32_t  ret = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || chat_id<=DC_CHAT_ID_LAST_SPECIAL || file==NULL) {
		goto cleanup;
	}

	msg->type = DC_MSG_IMAGE;
	dc_param_set    (msg->param, DC_PARAM_FILE,   file);
	dc_param_set_int(msg->param, DC_PARAM_WIDTH,  width);  /* set in sending job, if 0 */
	dc_param_set_int(msg->param, DC_PARAM_HEIGHT, height); /* set in sending job, if 0 */

	ret = dc_send_msg(context, chat_id, msg);

cleanup:
	dc_msg_unref(msg);
	return ret;

}


/**
 * Send a video to a chat.
 *
 * Sends the event #DC_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * See also dc_send_image_msg().
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id Chat ID to send the video to.
 * @param file Full path of the video file to send. The core may make a copy of the file.
 * @param filemime Mime type of the file to send. NULL if you don't know or don't care.
 * @param width Width in video of the file, if known. 0 if you don't know or don't care.
 * @param height Height in video of the file, if known. 0 if you don't know or don't care.
 * @param duration Length of the video in milliseconds. 0 if you don't know or don't care.
 * @return The ID of the message that is about being sent.
 */
uint32_t dc_send_video_msg(dc_context_t* context, uint32_t chat_id, const char* file, const char* filemime, int width, int height, int duration)
{
	dc_msg_t* msg = dc_msg_new(context);
	uint32_t  ret = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || chat_id<=DC_CHAT_ID_LAST_SPECIAL || file==NULL) {
		goto cleanup;
	}

	msg->type = DC_MSG_VIDEO;
	dc_param_set    (msg->param, DC_PARAM_FILE,     file);
	dc_param_set    (msg->param, DC_PARAM_MIMETYPE, filemime);
	dc_param_set_int(msg->param, DC_PARAM_WIDTH,    width);
	dc_param_set_int(msg->param, DC_PARAM_HEIGHT,   height);
	dc_param_set_int(msg->param, DC_PARAM_DURATION, duration);

	ret = dc_send_msg(context, chat_id, msg);

cleanup:
	dc_msg_unref(msg);
	return ret;

}


/**
 * Send a voice message to a chat.  Voice messages are messages just recorded though the device microphone.
 * For sending music or other audio data, use dc_send_audio_msg().
 *
 * Sends the event #DC_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id Chat ID to send the voice message to.
 * @param file Full path of the file to send. The core may make a copy of the file.
 * @param filemime Mime type of the file to send. NULL if you don't know or don't care.
 * @param duration Length of the voice message in milliseconds. 0 if you don't know or don't care.
 * @return The ID of the message that is about being sent.
 */
uint32_t dc_send_voice_msg(dc_context_t* context, uint32_t chat_id, const char* file, const char* filemime, int duration)
{
	dc_msg_t* msg = dc_msg_new(context);
	uint32_t  ret = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || chat_id<=DC_CHAT_ID_LAST_SPECIAL || file==NULL) {
		goto cleanup;
	}

	msg->type = DC_MSG_VOICE;
	dc_param_set    (msg->param, DC_PARAM_FILE,     file);
	dc_param_set    (msg->param, DC_PARAM_MIMETYPE, filemime);
	dc_param_set_int(msg->param, DC_PARAM_DURATION, duration);

	ret = dc_send_msg(context, chat_id, msg);

cleanup:
	dc_msg_unref(msg);
	return ret;
}


/**
 * Send an audio file to a chat.  Audio messages are eg. music tracks.
 * For voice messages just recorded though the device microphone, use dc_send_voice_msg().
 *
 * Sends the event #DC_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id Chat ID to send the audio to.
 * @param file Full path of the file to send. The core may make a copy of the file.
 * @param filemime Mime type of the file to send. NULL if you don't know or don't care.
 * @param duration Length of the audio in milliseconds. 0 if you don't know or don't care.
 * @param author Author or artist of the file. NULL if you don't know or don't care.
 * @param trackname Trackname or title of the file. NULL if you don't know or don't care.
 * @return The ID of the message that is about being sent.
 */
uint32_t dc_send_audio_msg(dc_context_t* context, uint32_t chat_id, const char* file, const char* filemime, int duration, const char* author, const char* trackname)
{
	dc_msg_t* msg = dc_msg_new(context);
	uint32_t ret = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || chat_id<=DC_CHAT_ID_LAST_SPECIAL || file==NULL) {
		goto cleanup;
	}

	msg->type = DC_MSG_AUDIO;
	dc_param_set    (msg->param, DC_PARAM_FILE,       file);
	dc_param_set    (msg->param, DC_PARAM_MIMETYPE,   filemime);
	dc_param_set_int(msg->param, DC_PARAM_DURATION,   duration);
	dc_param_set    (msg->param, DC_PARAM_AUTHORNAME, author);
	dc_param_set    (msg->param, DC_PARAM_TRACKNAME,  trackname);

	ret = dc_send_msg(context, chat_id, msg);

cleanup:
	dc_msg_unref(msg);
	return ret;
}


/**
 * Send a document to a chat. Use this function to send any document or file to
 * a chat.
 *
 * Sends the event #DC_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id Chat ID to send the document to.
 * @param file Full path of the file to send. The core may make a copy of the file.
 * @param filemime Mime type of the file to send. NULL if you don't know or don't care.
 * @return The ID of the message that is about being sent.
 */
uint32_t dc_send_file_msg(dc_context_t* context, uint32_t chat_id, const char* file, const char* filemime)
{
	dc_msg_t* msg = dc_msg_new(context);
	uint32_t  ret = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || chat_id<=DC_CHAT_ID_LAST_SPECIAL || file==NULL) {
		goto cleanup;
	}

	msg->type = DC_MSG_FILE;
	dc_param_set(msg->param, DC_PARAM_FILE,     file);
	dc_param_set(msg->param, DC_PARAM_MIMETYPE, filemime);

	ret = dc_send_msg(context, chat_id, msg);

cleanup:
	dc_msg_unref(msg);
	return ret;
}


/**
 * Send foreign contact data to a chat.
 *
 * Sends the name and the email address of another contact to a chat.
 * The contact this may or may not be a member of the chat.
 *
 * Typically used to share a contact to another member or to a group of members.
 *
 * Internally, the function just creates an appropriate text message and sends it
 * using dc_send_text_msg().
 *
 * NB: The "vcard" in the function name is just an abbreviation of "visiting card" and
 * is not related to the VCARD data format.
 *
 * @memberof dc_context_t
 * @param context The context object.
 * @param chat_id The chat to send the message to.
 * @param contact_id The contact whichs data should be shared to the chat.
 * @return Returns the ID of the message sent.
 */
uint32_t dc_send_vcard_msg(dc_context_t* context, uint32_t chat_id, uint32_t contact_id)
{
	uint32_t      ret = 0;
	dc_msg_t*     msg = dc_msg_new(context);
	dc_contact_t* contact = NULL;
	char*         text_to_send = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || chat_id<=DC_CHAT_ID_LAST_SPECIAL) {
		goto cleanup;
	}

	if ((contact=dc_get_contact(context, contact_id))==NULL) {
		goto cleanup;
	}

	if (contact->authname && contact->authname[0]) {
		text_to_send = dc_mprintf("%s: %s", contact->authname, contact->addr);
	}
	else {
		text_to_send = dc_strdup(contact->addr);
	}

	ret = dc_send_text_msg(context, chat_id, text_to_send);

cleanup:
	dc_msg_unref(msg);
	dc_contact_unref(contact);
	free(text_to_send);
	return ret;
}


/*
 * Log a device message.
 * Such a message is typically shown in the "middle" of the chat, the user can check this using dc_msg_is_info().
 * Texts are typically "Alice has added Bob to the group" or "Alice fingerprint verified."
 */
void dc_add_device_msg(dc_context_t* context, uint32_t chat_id, const char* text)
{
	uint32_t      msg_id = 0;
	sqlite3_stmt* stmt = NULL;
	char*         rfc724_mid = dc_create_outgoing_rfc724_mid(NULL, "@device");

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || text==NULL) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"INSERT INTO msgs (chat_id,from_id,to_id, timestamp,type,state, txt,rfc724_mid) VALUES (?,?,?, ?,?,?, ?,?);");
	sqlite3_bind_int  (stmt,  1, chat_id);
	sqlite3_bind_int  (stmt,  2, DC_CONTACT_ID_DEVICE);
	sqlite3_bind_int  (stmt,  3, DC_CONTACT_ID_DEVICE);
	sqlite3_bind_int64(stmt,  4, dc_create_smeared_timestamp(context));
	sqlite3_bind_int  (stmt,  5, DC_MSG_TEXT);
	sqlite3_bind_int  (stmt,  6, DC_STATE_IN_NOTICED);
	sqlite3_bind_text (stmt,  7, text,  -1, SQLITE_STATIC);
	sqlite3_bind_text (stmt,  8, rfc724_mid,  -1, SQLITE_STATIC);
	if (sqlite3_step(stmt)!=SQLITE_DONE) {
		goto cleanup;
	}
	msg_id = dc_sqlite3_get_rowid(context->sql, "msgs", "rfc724_mid", rfc724_mid);
	context->cb(context, DC_EVENT_MSGS_CHANGED, chat_id, msg_id);

cleanup:
	free(rfc724_mid);
	sqlite3_finalize(stmt);
}


/**
 * Forward messages to another chat.
 *
 * @memberof dc_context_t
 * @param context the context object as created by dc_context_new()
 * @param msg_ids an array of uint32_t containing all message IDs that should be forwarded
 * @param msg_cnt the number of messages IDs in the msg_ids array
 * @param chat_id The destination chat ID.
 * @return none
 */
void dc_forward_msgs(dc_context_t* context, const uint32_t* msg_ids, int msg_cnt, uint32_t chat_id)
{
	dc_msg_t*      msg = dc_msg_new(context);
	dc_chat_t*     chat = dc_chat_new(context);
	dc_contact_t*  contact = dc_contact_new(context);
	int            transaction_pending = 0;
	carray*        created_db_entries = carray_new(16);
	char*          idsstr = NULL;
	char*          q3 = NULL;
	sqlite3_stmt*  stmt = NULL;
	time_t         curr_timestamp = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || msg_ids==NULL || msg_cnt<=0 || chat_id<=DC_CHAT_ID_LAST_SPECIAL) {
		goto cleanup;
	}

	dc_sqlite3_begin_transaction(context->sql);
	transaction_pending = 1;

		dc_unarchive_chat(context, chat_id);

		context->smtp->log_connect_errors = 1;

		if (!dc_chat_load_from_db(chat, chat_id)) {
			goto cleanup;
		}

		curr_timestamp = dc_create_smeared_timestamps(context, msg_cnt);

		idsstr = dc_arr_to_string(msg_ids, msg_cnt);
		q3 = sqlite3_mprintf("SELECT id FROM msgs WHERE id IN(%s) ORDER BY timestamp,id", idsstr);
		stmt = dc_sqlite3_prepare(context->sql, q3);
		while (sqlite3_step(stmt)==SQLITE_ROW)
		{
			int src_msg_id = sqlite3_column_int(stmt, 0);
			if (!dc_msg_load_from_db(msg, context, src_msg_id)) {
				goto cleanup;
			}

			dc_param_set_int(msg->param, DC_PARAM_FORWARDED, 1);
			dc_param_set    (msg->param, DC_PARAM_GUARANTEE_E2EE, NULL);
			dc_param_set    (msg->param, DC_PARAM_FORCE_PLAINTEXT, NULL);

			uint32_t new_msg_id = send_msg_raw(context, chat, msg, curr_timestamp++);
			carray_add(created_db_entries, (void*)(uintptr_t)chat_id, NULL);
			carray_add(created_db_entries, (void*)(uintptr_t)new_msg_id, NULL);
		}

	dc_sqlite3_commit(context->sql);
	transaction_pending = 0;

cleanup:
	if (transaction_pending) { dc_sqlite3_rollback(context->sql); }
	if (created_db_entries) {
		size_t i, icnt = carray_count(created_db_entries);
		for (i = 0; i < icnt; i += 2) {
			context->cb(context, DC_EVENT_MSGS_CHANGED, (uintptr_t)carray_get(created_db_entries, i), (uintptr_t)carray_get(created_db_entries, i+1));
		}
		carray_free(created_db_entries);
	}
	dc_contact_unref(contact);
	dc_msg_unref(msg);
	dc_chat_unref(chat);
	sqlite3_finalize(stmt);
	free(idsstr);
	sqlite3_free(q3);
}
