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

#define MR_CHAT_MAGIC 0xc4a7c4a7


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

	ths->m_magic    = MR_CHAT_MAGIC;
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
 * @param chat Chat object are returned eg. by mrmailbox_get_chat().
 *
 * @return None.
 */
void mrchat_unref(mrchat_t* chat)
{
	if( chat==NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		return;
	}

	mrchat_empty(chat);
	mrparam_unref(chat->m_param);
	chat->m_magic = 0;
	free(chat);
}


/**
 * Empty a chat object.
 *
 * @private @memberof mrchat_t
 *
 * @param chat The chat object to empty.
 *
 * @return None.
 */
void mrchat_empty(mrchat_t* chat)
{
	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
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

	chat->m_blocked = 0;

	mrparam_set_packed(chat->m_param, NULL);
}


/*******************************************************************************
 * Getters
 ******************************************************************************/


/**
 * Get chat ID. The chat ID is the ID under which the chat is filed in the database.
 *
 * Special IDs:
 * - MR_CHAT_ID_DEADDROP         (1) - Virtual chat containing messages which senders are not confirmed by the user.
 * - MR_CHAT_ID_STARRED          (5) - Virtual chat containing all starred messages-
 * - MR_CHAT_ID_ARCHIVED_LINK    (6) - A link at the end of the chatlist, if present the UI should show the button "Archived chats"-
 *
 * "Normal" chat IDs are larger than these special IDs (larger than MR_CHAT_ID_LAST_SPECIAL).
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object.
 *
 * @return Chat ID. 0 on errors.
 */
uint32_t mrchat_get_id(mrchat_t* chat)
{
	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		return 0;
	}

	return chat->m_id;
}


/**
 * Get chat type.
 *
 * Currently, there are two chat types:
 *
 * - MR_CHAT_TYPE_SINGLE (100) - a normal chat is a chat with a single contact,
 *   chats_contacts contains one record for the user.  MR_CONTACT_ID_SELF
 *   (see mrcontact_t::m_id) is added _only_ for a self talk; in addition to
 *   this, for self talks also the flag MRP_SELFTALK is set.
 *
 * - MR_CHAT_TYPE_GROUP  (120) - a group chat, chats_contacts conain all group
 *   members, incl. MR_CONTACT_ID_SELF
 *
 * - MR_CHAT_TYPE_VERIFIED_GROUP  (130) - a verified group chat. In verified groups,
 *   all members are verified and encryption is always active and cannot be disabled.
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object.
 *
 * @return Chat type.
 */
int mrchat_get_type(mrchat_t* chat)
{
	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		return MR_CHAT_TYPE_UNDEFINED;
	}
	return chat->m_type;
}


/**
 * Get name of a chat. For one-to-one chats, this is the name of the contact.
 * For group chats, this is the name given eg. to mrmailbox_create_group_chat() or
 * received by a group-creation message.
 *
 * To change the name, use mrmailbox_set_chat_name()
 *
 * See also: mrchat_get_subtitle()
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object.
 *
 * @return Chat name as a string. Must be free()'d after usage. Never NULL.
 */
char* mrchat_get_name(mrchat_t* chat)
{
	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		return safe_strdup("Err");
	}

	return safe_strdup(chat->m_name);
}


/**
 * Get a subtitle for a chat.  The subtitle is eg. the email-address or the
 * number of group members.
 *
 * See also: mrchat_get_name()
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object to calulate the subtitle for.
 *
 * @return Subtitle as a string. Must be free()'d after usage. Never NULL.
 */
char* mrchat_get_subtitle(mrchat_t* chat)
{
	/* returns either the address or the number of chat members */
	char* ret = NULL;
	sqlite3_stmt* stmt;

	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		return safe_strdup("Err");
	}

	if( chat->m_type == MR_CHAT_TYPE_SINGLE && mrparam_exists(chat->m_param, MRP_SELFTALK) )
	{
		ret = mrstock_str(MR_STR_SELFTALK_SUBTITLE);
	}
	else if( chat->m_type == MR_CHAT_TYPE_SINGLE )
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
	else if( MR_CHAT_TYPE_IS_MULTI(chat->m_type) )
	{
		int cnt = 0;
		if( chat->m_id == MR_CHAT_ID_DEADDROP )
		{
			ret = mrstock_str(MR_STR_DEADDROP); /* typically, the subtitle for the deaddropn is not displayed at all */
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


/**
 * Get the chat's profile image.
 * The profile image is set using mrmailbox_set_chat_profile_image() for groups.
 * For normal chats, the profile image is set using mrmailbox_set_contact_profile_image() (not yet implemented).
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object.
 *
 * @return Path and file if the profile image, if any.  NULL otherwise.
 *     Must be free()'d after usage.
 */
char* mrchat_get_profile_image(mrchat_t* chat)
{
	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		return NULL;
	}

	return mrparam_get(chat->m_param, MRP_PROFILE_IMAGE, NULL);
}


/**
 * Get draft for the chat, if any. A draft is a message that the user started to
 * compose but that is not sent yet. You can save a draft for a chat using mrmailbox_set_draft().
 *
 * Drafts are considered when sorting messages and are also returned eg.
 * by mrchatlist_get_summary().
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object.
 *
 * @return Draft text, must be free()'d. Returns NULL if there is no draft.
 */
char* mrchat_get_draft(mrchat_t* chat)
{
	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		return NULL;
	}
	return strdup_keep_null(chat->m_draft_text); /* may be NULL */
}



/**
 * Get timestamp of the draft.
 *
 * The draft itself can be get using mrchat_get_draft().
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object.
 *
 * @return Timestamp of the draft. 0 if there is no draft.
 */
time_t mrchat_get_draft_timestamp(mrchat_t* chat)
{
	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		return 0;
	}
	return chat->m_draft_timestamp;
}


/**
 * Get archived state.
 *
 * - 0 = normal chat, not archived, not sticky.
 * - 1 = chat archived
 * - 2 = chat sticky (reserved for future use, if you do not support this value, just treat the chat as a normal one)
 *
 * To archive or unarchive chats, use mrmailbox_archive_chat().
 * If chats are archived, this should be shown in the UI by a little icon or text,
 * eg. the search will also return archived chats.
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object.
 *
 * @return Archived state.
 */
int mrchat_get_archived(mrchat_t* chat)
{
	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		return 0;
	}
	return chat->m_archived;
}


/**
 * Check if a chat is still unpromoted.  Chats are unpromoted until the first
 * message is sent.  With unpromoted chats, members can be sent, settings can be
 * modified without the need of special status messages being sent.
 *
 * After the creation with mrmailbox_create_group_chat() the chat is usuall  unpromoted
 * until the first call to mrmailbox_send_msg() or mrmailbox_send_text_msg().
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object.
 *
 * @return 1=chat is still unpromoted, no message was ever send to the chat,
 *     0=chat is not unpromoted, messages were send and/or received
 */
int mrchat_is_unpromoted(mrchat_t* chat)
{
	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		return 0;
	}
	return mrparam_get_int(chat->m_param, MRP_UNPROMOTED, 0);
}


/**
 * Check if a chat is verified.  Verified chats contain only verified members
 * and encryption is alwasy enabled.  Verified chats are created using
 * mrmailbox_create_group_chat() by setting the 'verified' parameter to true.
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object.
 *
 * @return 1=chat verified, 0=chat is not verified
 */
int mrchat_is_verified(mrchat_t* chat)
{
	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		return 0;
	}
	return (chat->m_type==MR_CHAT_TYPE_VERIFIED_GROUP);
}


int mrchat_are_all_members_verified__(mrchat_t* chat)
{
	int           chat_verified = 0;
	sqlite3_stmt* stmt;

	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		goto cleanup;
	}

	if( chat->m_id == MR_CHAT_ID_DEADDROP || chat->m_id == MR_CHAT_ID_STARRED ) {
		goto cleanup; // deaddrop & co. are never verified
	}

	stmt = mrsqlite3_predefine__(chat->m_mailbox->m_sql, SELECT_verified_FROM_chats_contacts_WHERE_chat_id,
		"SELECT c.id, ps.public_key_verified, ps.gossip_key_verified "
		" FROM chats_contacts cc"
		" LEFT JOIN contacts c ON c.id=cc.contact_id"
		" LEFT JOIN acpeerstates ps ON c.addr=ps.addr "
		" WHERE cc.chat_id=?;");
	sqlite3_bind_int(stmt, 1, chat->m_id);
	while( sqlite3_step(stmt) == SQLITE_ROW )
	{
		uint32_t contact_id          = sqlite3_column_int(stmt, 0);
		int      public_key_verified = sqlite3_column_int(stmt, 1);
		int      gossip_key_verified = sqlite3_column_int(stmt, 2);
		if( contact_id != MR_CONTACT_ID_SELF
		 && public_key_verified != MRV_BIDIRECTIONAL
		 && gossip_key_verified != MRV_BIDIRECTIONAL )
		{
			goto cleanup; // a single unverified contact results in an unverified chat
		}
	}

	chat_verified = 1;

cleanup:
	return chat_verified;
}


/**
 * Check if a chat is a self talk.  Self talks are normal chats with
 * the only contact MR_CONTACT_ID_SELF.
 *
 * @memberof mrchat_t
 *
 * @param chat The chat object.
 *
 * @return 1=chat is self talk, 0=chat is no self talk
 */
int mrchat_is_self_talk(mrchat_t* chat)
{
	if( chat == NULL || chat->m_magic != MR_CHAT_MAGIC ) {
		return 0;
	}
	return mrparam_exists(chat->m_param, MRP_SELFTALK);
}


/*******************************************************************************
 * Misc.
 ******************************************************************************/


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

	if( ths == NULL || ths->m_magic != MR_CHAT_MAGIC || row == NULL ) {
		return 0;
	}

	mrchat_empty(ths);

	#define MR_CHAT_FIELDS " c.id,c.type,c.name, c.draft_timestamp,c.draft_txt,c.grpid,c.param,c.archived, c.blocked "
	ths->m_id              =                    sqlite3_column_int  (row, row_offset++); /* the columns are defined in MR_CHAT_FIELDS */
	ths->m_type            =                    sqlite3_column_int  (row, row_offset++);
	ths->m_name            = safe_strdup((char*)sqlite3_column_text (row, row_offset++));
	ths->m_draft_timestamp =                    sqlite3_column_int64(row, row_offset++);
	draft_text             =       (const char*)sqlite3_column_text (row, row_offset++);
	ths->m_grpid           = safe_strdup((char*)sqlite3_column_text (row, row_offset++));
	mrparam_set_packed(ths->m_param,     (char*)sqlite3_column_text (row, row_offset++));
	ths->m_archived        =                    sqlite3_column_int  (row, row_offset++);
	ths->m_blocked         =                    sqlite3_column_int  (row, row_offset++);

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
	else if( mrparam_exists(ths->m_param, MRP_SELFTALK) ) {
		free(ths->m_name);
		ths->m_name = mrstock_str(MR_STR_SELF);
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

	if( chat==NULL || chat->m_magic != MR_CHAT_MAGIC ) {
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





