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
 * Create and access chat objects. Chat objects are created using eg. mrmailbox_get_chat() and
 * are not updated on database changes;  if you want an update, you have to recreate the
 * object.
 */
typedef struct mrchat_t
{
	#define         MR_CHAT_ID_DEADDROP         1 /* messages send from unknown/unwanted users to us, chats_contacts is not set up. This group may be shown normally. */
	#define         MR_CHAT_ID_TO_DEADDROP      2 /* messages send from us to unknown/unwanted users (this may happen when deleting chats or when using CC: in the email-program) */
	#define         MR_CHAT_ID_TRASH            3 /* messages that should be deleted get this chat_id; the messages are deleted from the working thread later then. This is also needed as rfc724_mid should be preset as long as the message is not deleted on the server (otherwise it is downloaded again) */
	#define         MR_CHAT_ID_MSGS_IN_CREATION 4 /* a message is just in creation but not yet assigned to a chat (eg. we may need the message ID to set up blobs; this avoids unready message to be send and shown) */
	#define         MR_CHAT_ID_STARRED          5 /* virtual chat containing all starred messages */
	#define         MR_CHAT_ID_ARCHIVED_LINK    6 /* a link at the end of the chatlist, if present the UI should show the button "Archived chats" */
	#define         MR_CHAT_ID_LAST_SPECIAL     9 /* larger chat IDs are "real" chats, their messages are "real" messages. */
	uint32_t        m_id;

	#define         MR_CHAT_TYPE_UNDEFINED      0
	#define         MR_CHAT_TYPE_NORMAL       100 /* a normal chat is a chat with a single contact, chats_contacts contains one record for the user, MR_CONTACT_ID_SELF is not added. */
	#define         MR_CHAT_TYPE_GROUP        120 /* a group chat, chats_contacts conain all group members, incl. MR_CONTACT_ID_SELF */
	int             m_type;

	char*           m_name;                       /**< NULL if unset */
	time_t          m_draft_timestamp;            /**< 0 if there is no draft */
	char*           m_draft_text;                 /**< NULL if unset */
	mrmailbox_t*    m_mailbox;                    /**< != NULL */
	int             m_archived;                   /**< 1=chat archived, this state should always be shown the UI, eg. the search will also return archived chats */
	mrparam_t*      m_param;                      /**< != NULL */

	/** @privatesection */
	char*           m_grpid;                      /* NULL if unset */
} mrchat_t;


void            mrchat_unref                (mrchat_t*);
char*           mrchat_get_subtitle         (mrchat_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCHAT_H__ */