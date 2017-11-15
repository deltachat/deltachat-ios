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
#include "mrapeerstate.h"
#include "mrjob.h"
#include "mrsmtp.h"
#include "mrimap.h"
#include "mrmimefactory.h"


/**
 * Create a chat object in memory.
 *
 * @private @memberof mrchat_t
 *
 * @param mailbox The mailbox object that should be stored in the chat object.
 *
 * @return New and empty chat object, must be freed using mrchat_unref().
 */
mrchat_t* mrchat_new(mrmailbox_t* mailbox)
{
	mrchat_t* ths = NULL;

	if( mailbox == NULL || (ths=calloc(1, sizeof(mrchat_t)))==NULL ) {
		exit(14); /* cannot allocate little memory, unrecoverable error */
	}

	ths->m_mailbox  = mailbox;
	ths->m_type     = MR_CHAT_TYPE_UNDEFINED;
	ths->m_param    = mrparam_new();

    return ths;
}


/**
 * Free a chat object.
 *
 * @memberof mrchat_t
 *
 * @param chat Chat object are returned eg. by mrmailbox_get_chat() or mrchat_new().
 *
 * @return None.
 */
void mrchat_unref(mrchat_t* chat)
{
	if( chat==NULL ) {
		return;
	}

	mrchat_empty(chat);
	mrparam_unref(chat->m_param);
	free(chat);
}


/**
 * Empty a chat object.
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object to empty.
 *
 * @return None.
 */
void mrchat_empty(mrchat_t* chat)
{
	if( chat == NULL ) {
		return;
	}

	free(chat->m_name);
	chat->m_name = NULL;

	chat->m_draft_timestamp = 0;

	free(chat->m_draft_text);
	chat->m_draft_text = NULL;

	chat->m_type = MR_CHAT_TYPE_UNDEFINED;
	chat->m_id   = 0;

	free(chat->m_grpid);
	chat->m_grpid = NULL;

	mrparam_set_packed(chat->m_param, NULL);
}


/**
 * Get a subtitle for a chat.  The sibtitle is eg. the email-address or the
 * number of group members.
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object to calulate the subtitle for.
 *
 * @return Subtitle as a string. Must be free()'d after usage.
 */
char* mrchat_get_subtitle(mrchat_t* chat)
{
	/* returns either the address or the number of chat members */
	char* ret = NULL;
	sqlite3_stmt* stmt;

	if( chat == NULL ) {
		return safe_strdup("Err");
	}

	if( chat->m_type == MR_CHAT_TYPE_NORMAL )
	{
		int r;
		mrsqlite3_lock(chat->m_mailbox->m_sql);

			stmt = mrsqlite3_predefine__(chat->m_mailbox->m_sql, SELECT_a_FROM_chats_contacts_WHERE_i,
				"SELECT c.addr FROM chats_contacts cc "
					" LEFT JOIN contacts c ON c.id=cc.contact_id "
					" WHERE cc.chat_id=?;");
			sqlite3_bind_int(stmt, 1, chat->m_id);

			r = sqlite3_step(stmt);
			if( r == SQLITE_ROW ) {
				ret = safe_strdup((const char*)sqlite3_column_text(stmt, 0));
			}

		mrsqlite3_unlock(chat->m_mailbox->m_sql);
	}
	else if( chat->m_type == MR_CHAT_TYPE_GROUP )
	{
		int cnt = 0;
		if( chat->m_id == MR_CHAT_ID_DEADDROP )
		{
			mrsqlite3_lock(chat->m_mailbox->m_sql);

				stmt = mrsqlite3_predefine__(chat->m_mailbox->m_sql, SELECT_COUNT_DISTINCT_f_FROM_msgs_WHERE_c,
					"SELECT COUNT(DISTINCT from_id) FROM msgs WHERE chat_id=?;");
				sqlite3_bind_int(stmt, 1, chat->m_id);
				if( sqlite3_step(stmt) == SQLITE_ROW ) {
					cnt = sqlite3_column_int(stmt, 0);
					ret = mrstock_str_repl_pl(MR_STR_CONTACT, cnt);
				}

			mrsqlite3_unlock(chat->m_mailbox->m_sql);
		}
		else
		{
			mrsqlite3_lock(chat->m_mailbox->m_sql);

				cnt = mrmailbox_get_chat_contact_count__(chat->m_mailbox, chat->m_id);
				ret = mrstock_str_repl_pl(MR_STR_MEMBER, cnt /*SELF is included in group chats (if not removed)*/);

			mrsqlite3_unlock(chat->m_mailbox->m_sql);
		}
	}

	return ret? ret : safe_strdup("Err");
}


int mrchat_update_param__(mrchat_t* ths)
{
	int success = 0;
	sqlite3_stmt* stmt = mrsqlite3_prepare_v2_(ths->m_mailbox->m_sql, "UPDATE chats SET param=? WHERE id=?");
	sqlite3_bind_text(stmt, 1, ths->m_param->m_packed, -1, SQLITE_STATIC);
	sqlite3_bind_int (stmt, 2, ths->m_id);
	success = sqlite3_step(stmt)==SQLITE_DONE? 1 : 0;
	sqlite3_finalize(stmt);
	return success;
}


static int mrchat_set_from_stmt__(mrchat_t* ths, sqlite3_stmt* row)
{
	int row_offset = 0;
	const char* draft_text;

	if( ths == NULL || row == NULL ) {
		return 0;
	}

	mrchat_empty(ths);

	#define MR_CHAT_FIELDS " c.id,c.type,c.name, c.draft_timestamp,c.draft_txt,c.grpid,c.param,c.archived "
	ths->m_id              =                    sqlite3_column_int  (row, row_offset++); /* the columns are defined in MR_CHAT_FIELDS */
	ths->m_type            =                    sqlite3_column_int  (row, row_offset++);
	ths->m_name            = safe_strdup((char*)sqlite3_column_text (row, row_offset++));
	ths->m_draft_timestamp =                    sqlite3_column_int64(row, row_offset++);
	draft_text             =       (const char*)sqlite3_column_text (row, row_offset++);
	ths->m_grpid           = safe_strdup((char*)sqlite3_column_text (row, row_offset++));
	mrparam_set_packed(ths->m_param,     (char*)sqlite3_column_text (row, row_offset++));
	ths->m_archived        =                    sqlite3_column_int  (row, row_offset++);

	/* We leave a NULL-pointer for the very usual situation of "no draft".
	Also make sure, m_draft_text and m_draft_timestamp are set together */
	if( ths->m_draft_timestamp && draft_text && draft_text[0] ) {
		ths->m_draft_text = safe_strdup(draft_text);
	}
	else {
		ths->m_draft_timestamp = 0;
	}

	/* correct the title of some special groups */
	if( ths->m_id == MR_CHAT_ID_DEADDROP ) {
		free(ths->m_name);
		ths->m_name = mrstock_str(MR_STR_DEADDROP);
	}
	else if( ths->m_id == MR_CHAT_ID_ARCHIVED_LINK ) {
		free(ths->m_name);
		char* tempname = mrstock_str(MR_STR_ARCHIVEDCHATS);
			ths->m_name = mr_mprintf("%s (%i)", tempname, mrmailbox_get_archived_count__(ths->m_mailbox));
		free(tempname);
	}
	else if( ths->m_id == MR_CHAT_ID_STARRED ) {
		free(ths->m_name);
		ths->m_name = mrstock_str(MR_STR_STARREDMSGS);
	}

	return row_offset; /* success, return the next row offset */
}


/**
 * Library-internal.
 *
 * Calling this function is not thread-safe, locking is up to the caller.
 *
 * @private @memberof mrchat_t
 *
 * @param chat The chat object that should be filled with the data from the database.
 *     Existing data are free()'d before using mrchat_empty().
 *
 * @param chat_id Chat ID that should be loaded from the database.
 *
 * @return 1=success, 0=error.
 */
int mrchat_load_from_db__(mrchat_t* chat, uint32_t chat_id)
{
	sqlite3_stmt* stmt;

	if( chat==NULL ) {
		return 0;
	}

	mrchat_empty(chat);

	stmt = mrsqlite3_predefine__(chat->m_mailbox->m_sql, SELECT_itndd_FROM_chats_WHERE_i,
		"SELECT " MR_CHAT_FIELDS " FROM chats c WHERE c.id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);

	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	if( !mrchat_set_from_stmt__(chat, stmt) ) {
		return 0;
	}

	return 1;
}





