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


#ifndef __MRCHAT_PRIVATE_H__
#define __MRCHAT_PRIVATE_H__
#ifdef __cplusplus
extern "C" {
#endif


/* values for the chats.blocked database field */
#define         MR_CHAT_NOT_BLOCKED       0
#define         MR_CHAT_MANUALLY_BLOCKED  1
#define         MR_CHAT_DEADDROP_BLOCKED  2


/** the structure behind mrchat_t */
struct _mrchat
{
	/** @privatesection */
	uint32_t        m_magic;
	uint32_t        m_id;
	int             m_type;             /**< Chat type. Use mrchat_get_type() to access this field. */
	char*           m_name;             /**< Name of the chat. Use mrchat_get_name() to access this field. NULL if unset. */
	char*           m_draft_text;	    /**< Draft text. NULL if there is no draft. */
	time_t          m_draft_timestamp;  /**< Timestamp of the draft. 0 if there is no draft. */
	int             m_archived;         /**< Archived state. Better use mrchat_get_archived() to access this object. */
	mrmailbox_t*    m_mailbox;          /**< The mailbox object the chat belongs to. */
	char*           m_grpid;            /**< Group ID that is used by all clients. Only used if the chat is a group. NULL if unset */
	int             m_blocked;          /**< One of MR_CHAT_*_BLOCKED */
	mrparam_t*      m_param;            /**< Additional parameters for a chat. Should not be used directly. */
};


int             mrchat_load_from_db__             (mrchat_t*, uint32_t id);
int             mrchat_update_param__             (mrchat_t*);
int             mrchat_are_all_members_verified__ (mrchat_t*);


#define         MR_CHAT_TYPE_IS_MULTI(a)   ((a)==MR_CHAT_TYPE_GROUP || (a)==MR_CHAT_TYPE_VERIFIED_GROUP)
#define         MR_CHAT_TYPE_CAN_SEND(a)   ((a)==MR_CHAT_TYPE_SINGLE || (a)==MR_CHAT_TYPE_GROUP || (a)==MR_CHAT_TYPE_VERIFIED_GROUP)


#define         MR_CHAT_PREFIX              "Chat:"      /* you MUST NOT modify this or the following strings */
#define         MR_CHATS_FOLDER             "Chats"      /* if we want to support Gma'l-labels - "Chats" is a reserved word for Gma'l */


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCHAT_PRIVATE_H__ */
