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


#include "dc_context.h"


#define DC_CHATLIST_MAGIC 0xc4a71157


/**
 * Create a chatlist object in memory.
 *
 * @private @memberof dc_chatlist_t
 * @param context The context that should be stored in the chatlist object.
 * @return New and empty chatlist object, must be freed using dc_chatlist_unref().
 */
dc_chatlist_t* dc_chatlist_new(dc_context_t* context)
{
	dc_chatlist_t* chatlist = NULL;

	if ((chatlist=calloc(1, sizeof(dc_chatlist_t)))==NULL) {
		exit(20);
	}

	chatlist->magic   = DC_CHATLIST_MAGIC;
	chatlist->context = context;
	if ((chatlist->chatNlastmsg_ids=dc_array_new(context, 128))==NULL) {
		exit(32);
	}

	return chatlist;
}


/**
 * Free a chatlist object.
 *
 * @memberof dc_chatlist_t
 * @param chatlist The chatlist object to free, created eg. by dc_get_chatlist(), dc_search_msgs().
 * @return None.
 */
void dc_chatlist_unref(dc_chatlist_t* chatlist)
{
	if (chatlist==NULL || chatlist->magic!=DC_CHATLIST_MAGIC) {
		return;
	}

	dc_chatlist_empty(chatlist);
	dc_array_unref(chatlist->chatNlastmsg_ids);
	chatlist->magic = 0;
	free(chatlist);
}


/**
 * Empty a chatlist object.
 *
 * @private @memberof dc_chatlist_t
 * @param chatlist The chatlist object to empty.
 * @return None.
 */
void dc_chatlist_empty(dc_chatlist_t* chatlist)
{
	if (chatlist==NULL || chatlist->magic!=DC_CHATLIST_MAGIC) {
		return;
	}

	chatlist->cnt = 0;
	dc_array_empty(chatlist->chatNlastmsg_ids);
}


/**
 * Find out the number of chats in a chatlist.
 *
 * @memberof dc_chatlist_t
 * @param chatlist The chatlist object as created eg. by dc_get_chatlist().
 * @return Returns the number of items in a dc_chatlist_t object. 0 on errors or if the list is empty.
 */
size_t dc_chatlist_get_cnt(const dc_chatlist_t* chatlist)
{
	if (chatlist==NULL || chatlist->magic!=DC_CHATLIST_MAGIC) {
		return 0;
	}

	return chatlist->cnt;
}


/**
 * Get a single chat ID of a chatlist.
 *
 * To get the message object from the message ID, use dc_get_chat().
 *
 * @memberof dc_chatlist_t
 * @param chatlist The chatlist object as created eg. by dc_get_chatlist().
 * @param index The index to get the chat ID for.
 * @return Returns the chat_id of the item at the given index.  Index must be between
 *     0 and dc_chatlist_get_cnt()-1.
 */
uint32_t dc_chatlist_get_chat_id(const dc_chatlist_t* chatlist, size_t index)
{
	if (chatlist==NULL || chatlist->magic!=DC_CHATLIST_MAGIC || chatlist->chatNlastmsg_ids==NULL || index>=chatlist->cnt) {
		return 0;
	}

	return dc_array_get_id(chatlist->chatNlastmsg_ids, index*DC_CHATLIST_IDS_PER_RESULT);
}


/**
 * Get a single message ID of a chatlist.
 *
 * To get the message object from the message ID, use dc_get_msg().
 *
 * @memberof dc_chatlist_t
 * @param chatlist The chatlist object as created eg. by dc_get_chatlist().
 * @param index The index to get the chat ID for.
 * @return Returns the message_id of the item at the given index.  Index must be between
 *     0 and dc_chatlist_get_cnt()-1.  If there is no message at the given index (eg. the chat may be empty), 0 is returned.
 */
uint32_t dc_chatlist_get_msg_id(const dc_chatlist_t* chatlist, size_t index)
{
	if (chatlist==NULL || chatlist->magic!=DC_CHATLIST_MAGIC || chatlist->chatNlastmsg_ids==NULL || index>=chatlist->cnt) {
		return 0;
	}

	return dc_array_get_id(chatlist->chatNlastmsg_ids, index*DC_CHATLIST_IDS_PER_RESULT+1);
}


/**
 * Get a summary for a chatlist index.
 *
 * The summary is returned by a dc_lot_t object with the following fields:
 *
 * - dc_lot_t::text1: contains the username or the strings "Me", "Draft" and so on.
 *   The string may be colored by having a look at text1_meaning.
 *   If there is no such name or it should not be displayed, the element is NULL.
 *
 * - dc_lot_t::text1_meaning: one of DC_TEXT1_USERNAME, DC_TEXT1_SELF or DC_TEXT1_DRAFT.
 *   Typically used to show dc_lot_t::text1 with different colors. 0 if not applicable.
 *
 * - dc_lot_t::text2: contains an excerpt of the message text or strings as
 *   "No messages".  May be NULL of there is no such text (eg. for the archive link)
 *
 * - dc_lot_t::timestamp: the timestamp of the message.  0 if not applicable.
 *
 * - dc_lot_t::state: The state of the message as one of the DC_STATE_* constants (see #dc_msg_get_state()).  0 if not applicable.
 *
 * @memberof dc_chatlist_t
 * @param chatlist The chatlist to query as returned eg. from dc_get_chatlist().
 * @param index The index to query in the chatlist.
 * @param chat To speed up things, pass an already available chat object here.
 *     If the chat object is not yet available, it is faster to pass NULL.
 * @return The summary as an dc_lot_t object. Must be freed using dc_lot_unref().  NULL is never returned.
 */
dc_lot_t* dc_chatlist_get_summary(const dc_chatlist_t* chatlist, size_t index, dc_chat_t* chat /*may be NULL*/)
{
	/* The summary is created by the chat, not by the last message.
	This is because we may want to display drafts here or stuff as
	"is typing".
	Also, sth. as "No messages" would not work if the summary comes from a
	message. */

	dc_lot_t*      ret = dc_lot_new(); /* the function never returns NULL */
	uint32_t       lastmsg_id = 0;
	dc_msg_t*      lastmsg = NULL;
	dc_contact_t*  lastcontact = NULL;
	dc_chat_t*     chat_to_delete = NULL;

	if (chatlist==NULL || chatlist->magic!=DC_CHATLIST_MAGIC || index>=chatlist->cnt) {
		ret->text2 = dc_strdup("ErrBadChatlistIndex");
		goto cleanup;
	}

	lastmsg_id = dc_array_get_id(chatlist->chatNlastmsg_ids, index*DC_CHATLIST_IDS_PER_RESULT+1);

	if (chat==NULL) {
		chat = dc_chat_new(chatlist->context);
		chat_to_delete = chat;
		if (!dc_chat_load_from_db(chat, dc_array_get_id(chatlist->chatNlastmsg_ids, index*DC_CHATLIST_IDS_PER_RESULT))) {
			ret->text2 = dc_strdup("ErrCannotReadChat");
			goto cleanup;
		}
	}

	if (lastmsg_id)
	{
		lastmsg = dc_msg_new(chatlist->context);
		dc_msg_load_from_db(lastmsg, chatlist->context, lastmsg_id);

		if (lastmsg->from_id!=DC_CONTACT_ID_SELF  &&  DC_CHAT_TYPE_IS_MULTI(chat->type))
		{
			lastcontact = dc_contact_new(chatlist->context);
			dc_contact_load_from_db(lastcontact, chatlist->context->sql, lastmsg->from_id);
		}
	}

	if (chat->id==DC_CHAT_ID_ARCHIVED_LINK)
	{
		ret->text2 = dc_strdup(NULL);
	}
	else if (chat->draft_timestamp
	      && chat->draft_text
	      && (lastmsg==NULL || chat->draft_timestamp>lastmsg->timestamp))
	{
		/* show the draft as the last message */
		ret->text1 = dc_stock_str(chatlist->context, DC_STR_DRAFT);
		ret->text1_meaning = DC_TEXT1_DRAFT;

		ret->text2 = dc_strdup(chat->draft_text);
		dc_truncate_n_unwrap_str(ret->text2, DC_SUMMARY_CHARACTERS, 1/*unwrap*/);

		ret->timestamp = chat->draft_timestamp;
	}
	else if (lastmsg==NULL || lastmsg->from_id==0)
	{
		/* no messages */
		ret->text2 = dc_stock_str(chatlist->context, DC_STR_NOMESSAGES);
	}
	else
	{
		/* show the last message */
		dc_lot_fill(ret, lastmsg, chat, lastcontact, chatlist->context);
	}

cleanup:
	dc_msg_unref(lastmsg);
	dc_contact_unref(lastcontact);
	dc_chat_unref(chat_to_delete);
	return ret;
}


/**
 * Helper function to get the associated context object.
 *
 * @memberof dc_chatlist_t
 * @param chatlist The chatlist object to empty.
 * @return Context object associated with the chatlist. NULL if none or on errors.
 */
dc_context_t* dc_chatlist_get_context(dc_chatlist_t* chatlist)
{
	if (chatlist==NULL || chatlist->magic!=DC_CHATLIST_MAGIC) {
		return NULL;
	}
	return chatlist->context;
}


static uint32_t get_last_deaddrop_fresh_msg(dc_context_t* context)
{
	uint32_t      ret = 0;
	sqlite3_stmt* stmt = NULL;

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT m.id "
		" FROM msgs m "
		" LEFT JOIN chats c ON c.id=m.chat_id "
		" WHERE m.state=" DC_STRINGIFY(DC_STATE_IN_FRESH)
		"   AND m.hidden=0 "
		"   AND c.blocked=" DC_STRINGIFY(DC_CHAT_DEADDROP_BLOCKED)
		" ORDER BY m.timestamp DESC, m.id DESC;"); /* we have an index over the state-column, this should be sufficient as there are typically only few fresh messages */

	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}

	ret = sqlite3_column_int(stmt, 0);

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


/**
 * Load a chatlist from the database to the chatlist object.
 *
 * @private @memberof dc_chatlist_t
 */
int dc_chatlist_load_from_db(dc_chatlist_t* chatlist, int listflags, const char* query__, uint32_t query_contact_id)
{
	//clock_t       start = clock();

	int           success = 0;
	int           add_archived_link_item = 0;
	sqlite3_stmt* stmt = NULL;
	char*         strLikeCmd = NULL;
	char*         query = NULL;

	if (chatlist==NULL || chatlist->magic!=DC_CHATLIST_MAGIC || chatlist->context==NULL) {
		goto cleanup;
	}

	dc_chatlist_empty(chatlist);

	/* select example with left join and minimum: http://stackoverflow.com/questions/7588142/mysql-left-join-min */
	#define QUR1 "SELECT c.id, m.id FROM chats c " \
	                " LEFT JOIN msgs m ON (c.id=m.chat_id AND m.hidden=0 AND m.timestamp=(SELECT MAX(timestamp) FROM msgs WHERE chat_id=c.id AND hidden=0)) " /* not: `m.hidden` which would refer the outer select and takes lot of time*/ \
	                " WHERE c.id>" DC_STRINGIFY(DC_CHAT_ID_LAST_SPECIAL) " AND c.blocked=0"
	#define QUR2    " GROUP BY c.id " /* GROUP BY is needed as there may be several messages with the same timestamp */ \
	                " ORDER BY MAX(c.draft_timestamp, IFNULL(m.timestamp,0)) DESC,m.id DESC;" /* the list starts with the newest chats */

	// nb: the query currently shows messages from blocked contacts in groups.
	// however, for normal-groups, this is okay as the message is also returned by dc_get_chat_msgs()
	// (otherwise it would be hard to follow conversations, wa and tg do the same)
	// for the deaddrop, however, they should really be hidden, however, _currently_ the deaddrop is not
	// shown at all permanent in the chatlist.

	if (query_contact_id)
	{
		// show chats shared with a given contact
		stmt = dc_sqlite3_prepare(chatlist->context->sql,
			QUR1 " AND c.id IN(SELECT chat_id FROM chats_contacts WHERE contact_id=?) " QUR2);
		sqlite3_bind_int(stmt, 1, query_contact_id);
	}
	else if (listflags & DC_GCL_ARCHIVED_ONLY)
	{
		/* show archived chats */
		stmt = dc_sqlite3_prepare(chatlist->context->sql,
			QUR1 " AND c.archived=1 " QUR2);
	}
	else if (query__==NULL)
	{
		/* show normal chatlist  */
		if (!(listflags & DC_GCL_NO_SPECIALS)) {
			uint32_t last_deaddrop_fresh_msg_id = get_last_deaddrop_fresh_msg(chatlist->context);
			if (last_deaddrop_fresh_msg_id > 0) {
				dc_array_add_id(chatlist->chatNlastmsg_ids, DC_CHAT_ID_DEADDROP); /* show deaddrop with the last fresh message */
				dc_array_add_id(chatlist->chatNlastmsg_ids, last_deaddrop_fresh_msg_id);
			}
			add_archived_link_item = 1;
		}

		stmt = dc_sqlite3_prepare(chatlist->context->sql,
			QUR1 " AND c.archived=0 " QUR2);
	}
	else
	{
		/* show chatlist filtered by a search string, this includes archived and unarchived */
		query = dc_strdup(query__);
		dc_trim(query);
		if (query[0]==0) {
			success = 1; /*empty result*/
			goto cleanup;
		}
		strLikeCmd = dc_mprintf("%%%s%%", query);
		stmt = dc_sqlite3_prepare(chatlist->context->sql,
			QUR1 " AND c.name LIKE ? " QUR2);
		sqlite3_bind_text(stmt, 1, strLikeCmd, -1, SQLITE_STATIC);
	}

    while (sqlite3_step(stmt)==SQLITE_ROW)
    {
		dc_array_add_id(chatlist->chatNlastmsg_ids, sqlite3_column_int(stmt, 0));
		dc_array_add_id(chatlist->chatNlastmsg_ids, sqlite3_column_int(stmt, 1));
    }

    if (add_archived_link_item && dc_get_archived_cnt(chatlist->context)>0)
    {
		dc_array_add_id(chatlist->chatNlastmsg_ids, DC_CHAT_ID_ARCHIVED_LINK);
		dc_array_add_id(chatlist->chatNlastmsg_ids, 0);
    }

	chatlist->cnt = dc_array_get_cnt(chatlist->chatNlastmsg_ids)/DC_CHATLIST_IDS_PER_RESULT;
	success = 1;

cleanup:
	//dc_log_info(chatlist->context, 0, "Chatlist for search \"%s\" created in %.3f ms.", query__?query__:"", (double)(clock()-start)*1000.0/CLOCKS_PER_SEC);
	sqlite3_finalize(stmt);
	free(query);
	free(strLikeCmd);
	return success;
}


/*******************************************************************************
 * Context functions to work with chatlists
 ******************************************************************************/


int dc_get_archived_cnt(dc_context_t* context)
{
	int ret = 0;
	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
		"SELECT COUNT(*) FROM chats WHERE blocked=0 AND archived=1;");
	if (sqlite3_step(stmt)==SQLITE_ROW) {
		ret = sqlite3_column_int(stmt, 0);
	}
	sqlite3_finalize(stmt);
	return ret;
}


/**
 * Get a list of chats. The list can be filtered by query parameters.
 * To get the chat messages, use dc_get_chat_msgs().
 *
 * @memberof dc_context_t
 * @param context The context object as returned by dc_context_new()
 * @param listflags A combination of flags:
 *     - if the flag DC_GCL_ARCHIVED_ONLY is set, only archived chats are returned.
 *       if DC_GCL_ARCHIVED_ONLY is not set, only unarchived chats are returned and
 *       the pseudo-chat DC_CHAT_ID_ARCHIVED_LINK is added if there are _any_ archived
 *       chats
 *     - if the flag DC_GCL_NO_SPECIALS is set, deaddrop and archive link are not added
 *       to the list (may be used eg. for selecting chats on forwarding, the flag is
 *       not needed when DC_GCL_ARCHIVED_ONLY is already set)
 * @param query_str An optional query for filtering the list.  Only chats matching this query
 *     are returned.  Give NULL for no filtering.
 * @param query_id An optional contact ID for filtering the list.  Only chats including this contact ID
 *     are returned.  Give 0 for no filtering.
 * @return A chatlist as an dc_chatlist_t object. Must be freed using
 *     dc_chatlist_unref() when no longer used
 */
dc_chatlist_t* dc_get_chatlist(dc_context_t* context, int listflags, const char* query_str, uint32_t query_id)
{
	int            success = 0;
	dc_chatlist_t* obj = dc_chatlist_new(context);

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	if (!dc_chatlist_load_from_db(obj, listflags, query_str, query_id)) {
		goto cleanup;
	}

	success = 1;

cleanup:
	if (success) {
		return obj;
	}
	else {
		dc_chatlist_unref(obj);
		return NULL;
	}
}