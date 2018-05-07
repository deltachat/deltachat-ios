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

#define MR_CHATLIST_MAGIC 0xc4a71157


/**
 * Create a chatlist object in memory.
 *
 * @private @memberof mrchatlist_t
 *
 * @param mailbox The mailbox object that should be stored in the chatlist object.
 *
 * @return New and empty chatlist object, must be freed using mrchatlist_unref().
 */
mrchatlist_t* mrchatlist_new(mrmailbox_t* mailbox)
{
	mrchatlist_t* ths = NULL;

	if( (ths=calloc(1, sizeof(mrchatlist_t)))==NULL ) {
		exit(20);
	}

	ths->m_magic   = MR_CHATLIST_MAGIC;
	ths->m_mailbox = mailbox;
	if( (ths->m_chatNlastmsg_ids=mrarray_new(mailbox, 128))==NULL ) {
		exit(32);
	}

	return ths;
}


/**
 * Free a chatlist object.
 *
 * @memberof mrchatlist_t
 *
 * @param chatlist The chatlist object to free, created eg. by mrmailbox_get_chatlist(), mrmailbox_search_msgs().
 *
 * @return None.
 *
 */
void mrchatlist_unref(mrchatlist_t* chatlist)
{
	if( chatlist==NULL || chatlist->m_magic != MR_CHATLIST_MAGIC ) {
		return;
	}

	mrchatlist_empty(chatlist);
	mrarray_unref(chatlist->m_chatNlastmsg_ids);
	chatlist->m_magic = 0;
	free(chatlist);
}


/**
 * Empty a chatlist object.
 *
 * @private @memberof mrchatlist_t
 *
 * @param chatlist The chatlist object to empty.
 *
 * @return None.
 */
void mrchatlist_empty(mrchatlist_t* chatlist)
{
	if( chatlist == NULL || chatlist->m_magic != MR_CHATLIST_MAGIC ) {
		return;
	}

	chatlist->m_cnt = 0;
	mrarray_empty(chatlist->m_chatNlastmsg_ids);
}


/**
 * Find out the number of chats in a chatlist.
 *
 * @memberof mrchatlist_t
 *
 * @param chatlist The chatlist object as created eg. by mrmailbox_get_chatlist().
 *
 * @return Returns the number of items in a mrchatlist_t object. 0 on errors or if the list is empty.
 */
size_t mrchatlist_get_cnt(mrchatlist_t* chatlist)
{
	if( chatlist == NULL || chatlist->m_magic != MR_CHATLIST_MAGIC ) {
		return 0;
	}

	return chatlist->m_cnt;
}


/**
 * Get a single chat ID of a chatlist.
 *
 * To get the message object from the message ID, use mrmailbox_get_chat().
 *
 * @memberof mrchatlist_t
 *
 * @param chatlist The chatlist object as created eg. by mrmailbox_get_chatlist().
 *
 * @param index The index to get the chat ID for.
 *
 * @return Returns the chat_id of the item at the given index.  Index must be between
 *     0 and mrchatlist_get_cnt()-1.
 */
uint32_t mrchatlist_get_chat_id(mrchatlist_t* chatlist, size_t index)
{
	if( chatlist == NULL || chatlist->m_magic != MR_CHATLIST_MAGIC || chatlist->m_chatNlastmsg_ids == NULL || index >= chatlist->m_cnt ) {
		return 0;
	}

	return mrarray_get_id(chatlist->m_chatNlastmsg_ids, index*MR_CHATLIST_IDS_PER_RESULT);
}


/**
 * Get a single message ID of a chatlist.
 *
 * To get the message object from the message ID, use mrmailbox_get_msg().
 *
 * @memberof mrchatlist_t
 *
 * @param chatlist The chatlist object as created eg. by mrmailbox_get_chatlist().
 *
 * @param index The index to get the chat ID for.
 *
 * @return Returns the message_id of the item at the given index.  Index must be between
 *     0 and mrchatlist_get_cnt()-1.  If there is no message at the given index (eg. the chat may be empty), 0 is returned.
 */
uint32_t mrchatlist_get_msg_id(mrchatlist_t* chatlist, size_t index)
{
	if( chatlist == NULL || chatlist->m_magic != MR_CHATLIST_MAGIC || chatlist->m_chatNlastmsg_ids == NULL || index >= chatlist->m_cnt ) {
		return 0;
	}

	return mrarray_get_id(chatlist->m_chatNlastmsg_ids, index*MR_CHATLIST_IDS_PER_RESULT+1);
}


/**
 * Get a summary for a chatlist index.
 *
 * The summary is returned by a mrlot_t object with the following fields:
 *
 * - mrlot_t::m_text1: contains the username or the strings "Me", "Draft" and so on.
 *   The string may be colored by having a look at m_text1_meaning.
 *   If there is no such name or it should not be displayed, the element is NULL.
 *
 * - mrlot_t::m_text1_meaning: one of MR_TEXT1_USERNAME, MR_TEXT1_SELF or MR_TEXT1_DRAFT.
 *   Typically used to show mrlot_t::m_text1 with different colors. 0 if not applicable.
 *
 * - mrlot_t::m_text2: contains an excerpt of the message text or strings as
 *   "No messages".  May be NULL of there is no such text (eg. for the archive link)
 *
 * - mrlot_t::m_timestamp: the timestamp of the message.  0 if not applicable.
 *
 * - mrlot_t::m_state: The state of the message as one of the MR_STATE_* constants (see #mrmsg_get_state()).  0 if not applicable.
 *
 * @memberof mrchatlist_t
 *
 * @param chatlist The chatlist to query as returned eg. from mrmailbox_get_chatlist().
 * @param index The index to query in the chatlist.
 * @param chat To speed up things, pass an already available chat object here.
 *     If the chat object is not yet available, it is faster to pass NULL.
 *
 * @return The summary as an mrlot_t object. Must be freed using mrlot_unref().  NULL is never returned.
 */
mrlot_t* mrchatlist_get_summary(mrchatlist_t* chatlist, size_t index, mrchat_t* chat /*may be NULL*/)
{
	/* The summary is created by the chat, not by the last message.
	This is because we may want to display drafts here or stuff as
	"is typing".
	Also, sth. as "No messages" would not work if the summary comes from a
	message. */

	mrlot_t*      ret = mrlot_new(); /* the function never returns NULL */
	int           locked = 0;
	uint32_t      lastmsg_id = 0;
	mrmsg_t*      lastmsg = NULL;
	mrcontact_t*  lastcontact = NULL;
	mrchat_t*     chat_to_delete = NULL;

	if( chatlist == NULL || chatlist->m_magic != MR_CHATLIST_MAGIC || index >= chatlist->m_cnt ) {
		ret->m_text2 = safe_strdup("ErrBadChatlistIndex");
		goto cleanup;
	}

	lastmsg_id = mrarray_get_id(chatlist->m_chatNlastmsg_ids, index*MR_CHATLIST_IDS_PER_RESULT+1);

	/* load data from database */
	mrsqlite3_lock(chatlist->m_mailbox->m_sql);
	locked = 1;

		if( chat==NULL ) {
			chat = mrchat_new(chatlist->m_mailbox);
			chat_to_delete = chat;
			if( !mrchat_load_from_db__(chat, mrarray_get_id(chatlist->m_chatNlastmsg_ids, index*MR_CHATLIST_IDS_PER_RESULT)) ) {
				ret->m_text2 = safe_strdup("ErrCannotReadChat");
				goto cleanup;
			}
		}

		if( lastmsg_id )
		{

			lastmsg = mrmsg_new();
			mrmsg_load_from_db__(lastmsg, chatlist->m_mailbox, lastmsg_id);

			if( lastmsg->m_from_id != MR_CONTACT_ID_SELF  &&  MR_CHAT_TYPE_IS_MULTI(chat->m_type) )
			{
				lastcontact = mrcontact_new(chatlist->m_mailbox);
				mrcontact_load_from_db__(lastcontact, chatlist->m_mailbox->m_sql, lastmsg->m_from_id);
			}

		}

	mrsqlite3_unlock(chatlist->m_mailbox->m_sql);
	locked = 0;

	if( chat->m_id == MR_CHAT_ID_ARCHIVED_LINK )
	{
		ret->m_text2 = safe_strdup(NULL);
	}
	else if( chat->m_draft_timestamp
	      && chat->m_draft_text
	      && (lastmsg==NULL || chat->m_draft_timestamp>lastmsg->m_timestamp) )
	{
		/* show the draft as the last message */
		ret->m_text1 = mrstock_str(MR_STR_DRAFT);
		ret->m_text1_meaning = MR_TEXT1_DRAFT;

		ret->m_text2 = safe_strdup(chat->m_draft_text);
		mr_truncate_n_unwrap_str(ret->m_text2, MR_SUMMARY_CHARACTERS, 1/*unwrap*/);

		ret->m_timestamp = chat->m_draft_timestamp;
	}
	else if( lastmsg == NULL || lastmsg->m_from_id == 0 )
	{
		/* no messages */
		ret->m_text2 = mrstock_str(MR_STR_NOMESSAGES);
	}
	else
	{
		/* show the last message */
		mrlot_fill(ret, lastmsg, chat, lastcontact);
	}

cleanup:
	if( locked ) { mrsqlite3_unlock(chatlist->m_mailbox->m_sql); }
	mrmsg_unref(lastmsg);
	mrcontact_unref(lastcontact);
	mrchat_unref(chat_to_delete);
	return ret;
}


/**
 * Helper function to get the associated mailbox object.
 *
 * @memberof mrchatlist_t
 *
 * @param chatlist The chatlist object to empty.
 *
 * @return Mailbox object associated with the chatlist. NULL if none or on errors.
 */
mrmailbox_t* mrchatlist_get_mailbox(mrchatlist_t* chatlist)
{
	if( chatlist == NULL || chatlist->m_magic != MR_CHATLIST_MAGIC ) {
		return NULL;
	}
	return chatlist->m_mailbox;
}


/**
 * Library-internal.
 *
 * Calling this function is not thread-safe, locking is up to the caller.
 *
 * @private @memberof mrchatlist_t
 */
int mrchatlist_load_from_db__(mrchatlist_t* ths, int listflags, const char* query__, uint32_t query_contact_id)
{
	clock_t       start = clock();

	int           success = 0;
	int           add_archived_link_item = 0;
	sqlite3_stmt* stmt = NULL;
	char*         strLikeCmd = NULL, *query = NULL;

	if( ths == NULL || ths->m_magic != MR_CHATLIST_MAGIC || ths->m_mailbox == NULL ) {
		goto cleanup;
	}

	mrchatlist_empty(ths);

	/* select example with left join and minimum: http://stackoverflow.com/questions/7588142/mysql-left-join-min */
	#define QUR1 "SELECT c.id, m.id FROM chats c " \
	                " LEFT JOIN msgs m ON (c.id=m.chat_id AND m.hidden=0 AND m.timestamp=(SELECT MAX(timestamp) FROM msgs WHERE chat_id=c.id AND hidden=0)) " /* not: `m.hidden` which would refer the outer select and takes lot of time*/ \
	                " WHERE c.id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL) " AND c.blocked=0"
	#define QUR2    " GROUP BY c.id " /* GROUP BY is needed as there may be several messages with the same timestamp */ \
	                " ORDER BY MAX(c.draft_timestamp, IFNULL(m.timestamp,0)) DESC,m.id DESC;" /* the list starts with the newest chats */

	// nb: the query currently shows messages from blocked contacts in groups.
	// however, for normal-groups, this is okay as the message is also returned by mrmailbox_get_chat_msgs()
	// (otherwise it would be hard to follow conversations, wa and tg do the same)
	// for the deaddrop, however, they should really be hidden, however, _currently_ the deaddrop is not
	// shown at all permanent in the chatlist.

	if( query_contact_id )
	{
		// show chats shared with a given contact
		stmt = mrsqlite3_predefine__(ths->m_mailbox->m_sql, SELECT_ii_FROM_chats_LEFT_JOIN_msgs_WHERE_contact_id,
			QUR1 " AND c.id IN(SELECT chat_id FROM chats_contacts WHERE contact_id=?) " QUR2);
		sqlite3_bind_int(stmt, 1, query_contact_id);
	}
	else if( listflags & MR_GCL_ARCHIVED_ONLY )
	{
		/* show archived chats */
		stmt = mrsqlite3_predefine__(ths->m_mailbox->m_sql, SELECT_ii_FROM_chats_LEFT_JOIN_msgs_WHERE_archived,
			QUR1 " AND c.archived=1 " QUR2);
	}
	else if( query__==NULL )
	{
		/* show normal chatlist  */
		if( !(listflags & MR_GCL_NO_SPECIALS) ) {
			uint32_t last_deaddrop_fresh_msg_id = mrmailbox_get_last_deaddrop_fresh_msg__(ths->m_mailbox);
			if( last_deaddrop_fresh_msg_id > 0 ) {
				mrarray_add_id(ths->m_chatNlastmsg_ids, MR_CHAT_ID_DEADDROP); /* show deaddrop with the last fresh message */
				mrarray_add_id(ths->m_chatNlastmsg_ids, last_deaddrop_fresh_msg_id);
			}
			add_archived_link_item = 1;
		}

		stmt = mrsqlite3_predefine__(ths->m_mailbox->m_sql, SELECT_ii_FROM_chats_LEFT_JOIN_msgs_WHERE_unarchived,
			QUR1 " AND c.archived=0 " QUR2);
	}
	else
	{
		/* show chatlist filtered by a search string, this includes archived and unarchived */
		query = safe_strdup(query__);
		mr_trim(query);
		if( query[0]==0 ) {
			success = 1; /*empty result*/
			goto cleanup;
		}
		strLikeCmd = mr_mprintf("%%%s%%", query);
		stmt = mrsqlite3_predefine__(ths->m_mailbox->m_sql, SELECT_ii_FROM_chats_LEFT_JOIN_msgs_WHERE_query,
			QUR1 " AND c.name LIKE ? " QUR2);
		sqlite3_bind_text(stmt, 1, strLikeCmd, -1, SQLITE_STATIC);
	}

    while( sqlite3_step(stmt) == SQLITE_ROW )
    {
		mrarray_add_id(ths->m_chatNlastmsg_ids, sqlite3_column_int(stmt, 0));
		mrarray_add_id(ths->m_chatNlastmsg_ids, sqlite3_column_int(stmt, 1));
    }

    if( add_archived_link_item && mrmailbox_get_archived_count__(ths->m_mailbox)>0 )
    {
		mrarray_add_id(ths->m_chatNlastmsg_ids, MR_CHAT_ID_ARCHIVED_LINK);
		mrarray_add_id(ths->m_chatNlastmsg_ids, 0);
    }

	ths->m_cnt = mrarray_get_cnt(ths->m_chatNlastmsg_ids)/MR_CHATLIST_IDS_PER_RESULT;
	success = 1;

cleanup:
	mrmailbox_log_info(ths->m_mailbox, 0, "Chatlist for search \"%s\" created in %.3f ms.", query__?query__:"", (double)(clock()-start)*1000.0/CLOCKS_PER_SEC);

	free(query);
	free(strLikeCmd);
	return success;
}
