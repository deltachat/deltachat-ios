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


#ifndef __MRCHAT_H__
#define __MRCHAT_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct mrmailbox_t mrmailbox_t;
typedef struct mrparam_t   mrparam_t;


/**
 * An object representing a single chat in memory. Chat objects are created using eg. mrmailbox_get_chat() and
 * are not updated on database changes;  if you want an update, you have to recreate the
 * object.
 */
typedef struct mrchat_t
{
	/**
	 * Chat ID under which the chat is filed in the database.
	 *
	 * Special IDs:
	 * - MR_CHAT_ID_DEADDROP         (1) - Messages send from unknown/unwanted users to us, chats_contacts is not set up. This group may be shown normally.
	 * - MR_CHAT_ID_STARRED          (5) - Virtual chat containing all starred messages-
	 * - MR_CHAT_ID_ARCHIVED_LINK    (6) - A link at the end of the chatlist, if present the UI should show the button "Archived chats"-
	 *
	 * "Normal" chat IDs are larger than these special IDs (larger than MR_CHAT_ID_LAST_SPECIAL).
	 */
	uint32_t        m_id;
	#define         MR_CHAT_ID_DEADDROP         1
	#define         MR_CHAT_ID_TO_DEADDROP      2 /* messages send from us to unknown/unwanted users (this may happen when deleting chats or when using CC: in the email-program) */
	#define         MR_CHAT_ID_TRASH            3 /* messages that should be deleted get this chat_id; the messages are deleted from the working thread later then. This is also needed as rfc724_mid should be preset as long as the message is not deleted on the server (otherwise it is downloaded again) */
	#define         MR_CHAT_ID_MSGS_IN_CREATION 4 /* a message is just in creation but not yet assigned to a chat (eg. we may need the message ID to set up blobs; this avoids unready message to be send and shown) */
	#define         MR_CHAT_ID_STARRED          5
	#define         MR_CHAT_ID_ARCHIVED_LINK    6
	#define         MR_CHAT_ID_LAST_SPECIAL     9 /* larger chat IDs are "real" chats, their messages are "real" messages. */


	/**
	 * Chat type.
	 *
	 * - MR_CHAT_TYPE_NORMAL (100) - a normal chat is a chat with a single contact, chats_contacts contains one record for the user, MR_CONTACT_ID_SELF (see mrcontact_t::m_id) is not added.
	 * - MR_CHAT_TYPE_GROUP  (120) - a group chat, chats_contacts conain all group members, incl. MR_CONTACT_ID_SELF
	 *
	 * If the chat type is not set, it is MR_CHAT_TYPE_UNDEFINED (0).
	 */
	int             m_type;
	#define         MR_CHAT_TYPE_UNDEFINED      0
	#define         MR_CHAT_TYPE_NORMAL       100
	#define         MR_CHAT_TYPE_GROUP        120


	/**
	 * Name of the chat.
	 *
	 * For one-to-one chats, this is the name of the contact.
	 * For group chats, this is the name given eg. to mrmailbox_create_group_chat() or
	 * received by a group-creation message.
	 *
	 * To change the name, use mrmailbox_set_chat_name()
	 *
	 * NULL if unset.
	 */
	char*           m_name;

	/**
	 * Timestamp of the draft.
	 *
	 * The draft itself is placed in mrchat_t::m_draft_text.
	 * To save a draft for a chat, use mrmailbox_set_draft()
	 *
	 * 0 if there is no draft.
	 */
	time_t          m_draft_timestamp;

	/**
	 * The draft text.
	 *
	 * The timetamp of the draft is placed in mrchat_t::m_draft_timestamp.
	 * To save a draft for a chat, use mrmailbox_set_draft()
	 *
	 * NULL if there is no draft.
	 */
	char*           m_draft_text;

	/**
	 * The mailbox object the chat belongs to. Never NULL.
	 */
	mrmailbox_t*    m_mailbox;

	/**
	 * Flag for the archived state.
	 *
	 * 1=chat archived, 0=chat not archived.
	 *
	 * To archive or unarchive chats, use mrmailbox_archive_chat().
	 * If chats are archived, this should be shown in the UI by a little icon or text,
	 * eg. the search will also return archived chats.
	 */
	int             m_archived;

	/**
	 * Additional parameters for the chat.
	 *
	 * To access the parameters, use mrparam_exists(), mrparam_get() for mrparam_get_int()
	 */
	mrparam_t*      m_param;

	/** @privatesection */
	char*           m_grpid;                      /* NULL if unset */
} mrchat_t;


mrchat_t*       mrchat_new                  (mrmailbox_t*);
void            mrchat_empty                (mrchat_t*);
void            mrchat_unref                (mrchat_t*);
char*           mrchat_get_subtitle         (mrchat_t*);

/* library-internal */
int             mrchat_load_from_db__       (mrchat_t*, uint32_t id);
int             mrchat_update_param__       (mrchat_t*);

#define         MR_CHAT_PREFIX              "Chat:"      /* you MUST NOT modify this or the following strings */
#define         MR_CHATS_FOLDER             "Chats"      /* if we want to support Gma'l-labels - "Chats" is a reserved word for Gma'l */


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCHAT_H__ */