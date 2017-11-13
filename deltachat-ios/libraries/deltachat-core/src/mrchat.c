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


/*******************************************************************************
 * Tools
 ******************************************************************************/


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


void mrmailbox_unarchive_chat__(mrmailbox_t* mailbox, uint32_t chat_id)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_chats_SET_unarchived, "UPDATE chats SET archived=0 WHERE id=?");
	sqlite3_bind_int (stmt, 1, chat_id);
	sqlite3_step(stmt);
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


int mrchat_load_from_db__(mrchat_t* ths, uint32_t id)
{
	sqlite3_stmt* stmt;

	if( ths==NULL ) {
		return 0;
	}

	mrchat_empty(ths);

	stmt = mrsqlite3_predefine__(ths->m_mailbox->m_sql, SELECT_itndd_FROM_chats_WHERE_i,
		"SELECT " MR_CHAT_FIELDS " FROM chats c WHERE c.id=?;");
	sqlite3_bind_int(stmt, 1, id);

	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	if( !mrchat_set_from_stmt__(ths, stmt) ) {
		return 0;
	}

	return 1;
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


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
 * Get a chat object of type mrchat_t by a chat_id.
 * To access the mrchat_t object, see mrchat.h
 * The result must be unref'd using mrchat_unref().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The ID of the chat to get the chat object for.
 *
 * @return A chat object, must be freed using mrchat_unref() when done.
 */
mrchat_t* mrmailbox_get_chat(mrmailbox_t* ths, uint32_t chat_id)
{
	int success = 0;
	int db_locked = 0;
	mrchat_t* obj = mrchat_new(ths);

	mrsqlite3_lock(ths->m_sql);
	db_locked = 1;

	if( !mrchat_load_from_db__(obj, chat_id) ) {
		goto cleanup;
	}

	/* success */
	success = 1;

	/* cleanup */
cleanup:
	if( db_locked ) {
		mrsqlite3_unlock(ths->m_sql);
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
 * mrmailbox_marknoticed_chat() marks all message in a whole chat as NOTICED.
 * NOTICED messages are no longer FRESH and do not count as being unseen.
 * IMAP/MDNs is not done for noticed messages.  See also mrmailbox_marknoticed_contact()
 * and mrmailbox_markseen_msgs()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 */
int mrmailbox_marknoticed_chat(mrmailbox_t* ths, uint32_t chat_id)
{
	/* marking a chat as "seen" is done by marking all fresh chat messages as "noticed" -
	"noticed" messages are not counted as being unread but are still waiting for being marked as "seen" using mrmailbox_markseen_msgs() */
	sqlite3_stmt* stmt;

	if( ths == NULL ) {
		return 0;
	}

	mrsqlite3_lock(ths->m_sql);

		stmt = mrsqlite3_predefine__(ths->m_sql, UPDATE_msgs_SET_state_WHERE_chat_id_AND_state,
			"UPDATE msgs SET state=" MR_STRINGIFY(MR_STATE_IN_NOTICED) " WHERE chat_id=? AND state=" MR_STRINGIFY(MR_STATE_IN_FRESH) ";");
		sqlite3_bind_int(stmt, 1, chat_id);
		sqlite3_step(stmt);

	mrsqlite3_unlock(ths->m_sql);

	return 1;
}


/**
 * If there is a normal chat with the given contact_id, this chat_id is
 * retunred.  If there is no normal chat with the contact_id, the function
 * returns 0
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
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
 */
uint32_t mrmailbox_create_chat_by_contact_id(mrmailbox_t* ths, uint32_t contact_id)
{
	uint32_t      chat_id = 0;
	int           send_event = 0, locked = 0;

	if( ths == NULL ) {
		return 0;
	}

	mrsqlite3_lock(ths->m_sql);
	locked = 1;

		chat_id = mrmailbox_lookup_real_nchat_by_contact_id__(ths, contact_id);
		if( chat_id ) {
			mrmailbox_log_warning(ths, 0, "Chat with contact %i already exists.", (int)contact_id);
			goto cleanup;
		}

        if( 0==mrmailbox_real_contact_exists__(ths, contact_id) ) {
			mrmailbox_log_warning(ths, 0, "Cannot create chat, contact %i does not exist.", (int)contact_id);
			goto cleanup;
        }

		chat_id = mrmailbox_create_or_lookup_nchat_by_contact_id__(ths, contact_id);
		if( chat_id ) {
			send_event = 1;
		}

		mrmailbox_scaleup_contact_origin__(ths, contact_id, MR_ORIGIN_CREATE_CHAT);

	mrsqlite3_unlock(ths->m_sql);
	locked = 0;

cleanup:
	if( locked ) {
		mrsqlite3_unlock(ths->m_sql);
	}

	if( send_event ) {
		ths->m_cb(ths, MR_EVENT_MSGS_CHANGED, 0, 0);
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
 * mrmailbox_get_chat_contacts() returns contact IDs, the result must be
 * carray_free()'d.
 *
 * - for normal chats, the function always returns exactly one contact
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
 * Frees a mrchat_t object created eg. by mrmailbox_get_chat().
 *
 * @memberof mrchat_t
 */
void mrchat_unref(mrchat_t* ths)
{
	if( ths==NULL ) {
		return;
	}

	mrchat_empty(ths);
	mrparam_unref(ths->m_param);
	free(ths);
}


void mrchat_empty(mrchat_t* ths)
{
	if( ths == NULL ) {
		return;
	}

	free(ths->m_name);
	ths->m_name = NULL;

	ths->m_draft_timestamp = 0;

	free(ths->m_draft_text);
	ths->m_draft_text = NULL;

	ths->m_type = MR_CHAT_TYPE_UNDEFINED;
	ths->m_id   = 0;

	free(ths->m_grpid);
	ths->m_grpid = NULL;

	mrparam_set_packed(ths->m_param, NULL);
}


/**
 * Returns message IDs of fresh messages, Typically used for implementing
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
 * mrmailbox_get_chat_msgs() returns a view on a chat.
 * The function returns an array of message IDs, which must be carray_free()'d by
 * the caller.  Optionally, some special markers added to the ID-array may help to
 * implement virtual lists:
 *
 * - If you add the flag MR_GCM_ADD_DAY_MARKER, the marker MR_MSG_ID_DAYMARKER will
 *   be added before each day (regarding the local timezone)
 *
 * - If you specify marker1before, the id MR_MSG_ID_MARKER1 will be added just
 *   before the given ID.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
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
 * - The function returns an array of messages IDs which must be carray_free()'d
 *   by the caller.
 *
 * - If nothing can be found, the function returns NULL.
 *
 * Global chat results are typically displayed using mrmsg_get_summary(), chat
 * search results may just hilite the corresponding messages and present a
 * prev/next button.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 */
carray* mrmailbox_search_msgs(mrmailbox_t* mailbox, uint32_t chat_id, const char* query__)
{
	int           success = 0, locked = 0;
	carray*       ret = carray_new(100);
	char*         strLikeInText = NULL, *strLikeBeg=NULL, *query = NULL;
	sqlite3_stmt* stmt = NULL;

	if( mailbox==NULL || ret == NULL || query__ == NULL ) {
		goto cleanup;
	}

	query = safe_strdup(query__);
	mr_trim(query);
	if( query[0]==0 ) {
		success = 1; /*empty result*/
		goto cleanup;
	}

	strLikeInText = mr_mprintf("%%%s%%", query);
	strLikeBeg = mr_mprintf("%s%%", query); /*for the name search, we use "Name%" which is fast as it can use the index ("%Name%" could not). */

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
	free(query);
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
 * save message in database and send it, the given message object is not unref'd
 * by the function but some fields are set up! Sends the event
 * MR_EVENT_MSGS_CHANGED on succcess.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
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


/**
 * either the email-address or the number of group members, the result must be
 * free()'d!
 *
 * @memberof mrchat_t
 */
char* mrchat_get_subtitle(mrchat_t* ths)
{
	/* returns either the address or the number of chat members */
	char* ret = NULL;
	sqlite3_stmt* stmt;

	if( ths == NULL ) {
		return safe_strdup("Err");
	}

	if( ths->m_type == MR_CHAT_TYPE_NORMAL )
	{
		int r;
		mrsqlite3_lock(ths->m_mailbox->m_sql);

			stmt = mrsqlite3_predefine__(ths->m_mailbox->m_sql, SELECT_a_FROM_chats_contacts_WHERE_i,
				"SELECT c.addr FROM chats_contacts cc "
					" LEFT JOIN contacts c ON c.id=cc.contact_id "
					" WHERE cc.chat_id=?;");
			sqlite3_bind_int(stmt, 1, ths->m_id);

			r = sqlite3_step(stmt);
			if( r == SQLITE_ROW ) {
				ret = safe_strdup((const char*)sqlite3_column_text(stmt, 0));
			}

		mrsqlite3_unlock(ths->m_mailbox->m_sql);
	}
	else if( ths->m_type == MR_CHAT_TYPE_GROUP )
	{
		int cnt = 0;
		if( ths->m_id == MR_CHAT_ID_DEADDROP )
		{
			mrsqlite3_lock(ths->m_mailbox->m_sql);

				stmt = mrsqlite3_predefine__(ths->m_mailbox->m_sql, SELECT_COUNT_DISTINCT_f_FROM_msgs_WHERE_c,
					"SELECT COUNT(DISTINCT from_id) FROM msgs WHERE chat_id=?;");
				sqlite3_bind_int(stmt, 1, ths->m_id);
				if( sqlite3_step(stmt) == SQLITE_ROW ) {
					cnt = sqlite3_column_int(stmt, 0);
					ret = mrstock_str_repl_pl(MR_STR_CONTACT, cnt);
				}

			mrsqlite3_unlock(ths->m_mailbox->m_sql);
		}
		else
		{
			mrsqlite3_lock(ths->m_mailbox->m_sql);

				cnt = mrmailbox_get_chat_contact_count__(ths->m_mailbox, ths->m_id);
				ret = mrstock_str_repl_pl(MR_STR_MEMBER, cnt /*SELF is included in group chats (if not removed)*/);

			mrsqlite3_unlock(ths->m_mailbox->m_sql);
		}
	}

	return ret? ret : safe_strdup("Err");
}


/**
 * Returns the total number of messages in a chat.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
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
 * Returns the number of fresh messages in a chat.  Typically used to implement
 * a badge with a number in the chatlist.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
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
 * Archiv or unarchive a chat by setting the last paramter to 0 (unarchive) or
 * 1 (archive).  Archived chats are not returned in the default chatlist returned
 * by mrmailbox_get_chatlist(0, NULL).  Instead, if there are _any_ archived chats,
 * the pseudo-chat with the chat_id MR_CHAT_ID_ARCHIVED_LINK will be added the the
 * end of the chatlist.
 * To get a list of archived chats, use mrmailbox_get_chatlist(MR_GCL_ARCHIVED_ONLY, NULL).
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


uint32_t mrchat_send_msg__(mrchat_t* ths, const mrmsg_t* msg, time_t timestamp)
{
	char*         rfc724_mid = NULL;
	sqlite3_stmt* stmt;
	uint32_t      msg_id = 0, to_id = 0;

	if( ths->m_type==MR_CHAT_TYPE_GROUP && !mrmailbox_is_contact_in_chat__(ths->m_mailbox, ths->m_id, MR_CONTACT_ID_SELF) ) {
		mrmailbox_log_error(ths->m_mailbox, MR_ERR_SELF_NOT_IN_GROUP, NULL);
		goto cleanup;
	}

	{
		char* from = mrsqlite3_get_config__(ths->m_mailbox->m_sql, "configured_addr", NULL);
		if( from == NULL ) { goto cleanup; }
			rfc724_mid = mr_create_outgoing_rfc724_mid(ths->m_type==MR_CHAT_TYPE_GROUP? ths->m_grpid : NULL, from);
		free(from);
	}

	if( ths->m_type == MR_CHAT_TYPE_NORMAL )
	{
		stmt = mrsqlite3_predefine__(ths->m_mailbox->m_sql, SELECT_c_FROM_chats_contacts_WHERE_c,
			"SELECT contact_id FROM chats_contacts WHERE chat_id=?;");
		sqlite3_bind_int(stmt, 1, ths->m_id);
		if( sqlite3_step(stmt) != SQLITE_ROW ) {
			goto cleanup;
		}
		to_id = sqlite3_column_int(stmt, 0);
	}
	else if( ths->m_type == MR_CHAT_TYPE_GROUP )
	{
		if( mrparam_get_int(ths->m_param, MRP_UNPROMOTED, 0)==1 ) {
			/* mark group as being no longer unpromoted */
			mrparam_set(ths->m_param, MRP_UNPROMOTED, NULL);
			mrchat_update_param__(ths);
		}
	}

	/* check if we can guarantee E2EE for this message.  If we can, we won't send the message without E2EE later (because of a reset, changed settings etc. - messages may be delayed significally if there is no network present) */
	int can_guarantee_e2ee = 0;
	if( ths->m_mailbox->m_e2ee_enabled ) {
		can_guarantee_e2ee = 1;
		sqlite3_stmt* stmt = mrsqlite3_predefine__(ths->m_mailbox->m_sql, SELECT_p_FROM_chats_contacs_JOIN_contacts_peerstates_WHERE_cc,
			"SELECT ps.prefer_encrypted "
			 " FROM chats_contacts cc "
			 " LEFT JOIN contacts c ON cc.contact_id=c.id "
			 " LEFT JOIN acpeerstates ps ON c.addr=ps.addr "
			 " WHERE cc.chat_id=? AND cc.contact_id>?;");
		sqlite3_bind_int(stmt, 1, ths->m_id);
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
	stmt = mrsqlite3_predefine__(ths->m_mailbox->m_sql, INSERT_INTO_msgs_mcftttstpb,
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

	msg_id = sqlite3_last_insert_rowid(ths->m_mailbox->m_sql->m_cobj);

	/* finalize message object on database, we set the chat ID late as we don't know it sooner */
	mrmailbox_update_msg_chat_id__(ths->m_mailbox, msg_id, ths->m_id);
	mrjob_add__(ths->m_mailbox, MRJ_SEND_MSG_TO_SMTP, msg_id, NULL); /* resuts on an asynchronous call to mrmailbox_send_msg_to_smtp()  */

cleanup:
	free(rfc724_mid);
	return msg_id;
}


/**
 * send a simple text message to the given chat.
 * Sends the event MR_EVENT_MSGS_CHANGED on succcess
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
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
 * by the function but some fields are set up! Sends the event
 * MR_EVENT_MSGS_CHANGED on succcess.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
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
				mr_guess_msgtype_from_suffix(pathNfilename, &better_type, &better_mime);
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
				msg->m_id = mrchat_send_msg__(chat, msg, mr_create_smeared_timestamp__());
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
