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
 *******************************************************************************
 *
 * File:    mrchat.h
 * Purpose: mrchat_t represents a single chat - this is a conversation with
 *          a single user or a group
 *
 ******************************************************************************/


#ifndef __MRCHAT_H__
#define __MRCHAT_H__
#ifdef __cplusplus
extern "C" {
#endif


#include "mrmsg.h"
typedef struct mrjob_t mrjob_t;


/* chat type */
#define MR_CHAT_UNDEFINED    0
#define MR_CHAT_NORMAL     100 /* a normal chat is a chat with a single contact, chats_contacts contains one record for the user, MR_CONTACT_ID_SELF is not added. */
#define MR_CHAT_GROUP      120 /* a group chat, chats_contacts conain all group members, incl. MR_CONTACT_ID_SELF */


/* specical chat IDs */
#define MR_CHAT_ID_DEADDROP           1 /* messages send from unknown/unwanted users to us, chats_contacts is not set up. This group may be shown normally. */
#define MR_CHAT_ID_TO_DEADDROP        2 /* messages send from us to unknown/unwanted users (this may happen when deleting chats or when using CC: in the email-program) */
#define MR_CHAT_ID_TRASH              3 /* messages that should be deleted get this chat_id; the messages are deleted from the working thread later then. This is also needed as rfc724_mid should be preset as long as the message is not deleted on the server (otherwise it is downloaded again) */
#define MR_CHAT_ID_MSGS_IN_CREATION   4 /* a message is just in creation but not yet assigned to a chat (eg. we may need the message ID to set up blobs; this avoids unready message to be send and shown) */
#define MR_CHAT_ID_STARRED            5 /* virtual chat containing all starred messages */
#define MR_CHAT_ID_ARCHIVED_LINK      6 /* a link at the end of the chatlist, if present the UI should show the button "Archived chats" */
#define MR_CHAT_ID_LAST_SPECIAL       9 /* larger chat IDs are "real" chats, their messages are "real" messages. */


typedef struct mrchat_t
{
	uint32_t        m_id;
	int             m_type;
	char*           m_name;            /* NULL if unset */
	time_t          m_draft_timestamp; /* 0 if there is no draft */
	char*           m_draft_text;      /* NULL if unset */
	mrmailbox_t*    m_mailbox;         /* != NULL */
	char*           m_grpid;           /* NULL if unset */
	int             m_archived;        /* 1=chat archived, this state should always be shown the UI, eg. the search will also return archived chats */
	mrparam_t*      m_param;           /* != NULL */
} mrchat_t;


mrchat_t*     mrchat_new                   (mrmailbox_t*); /* result must be unref'd */
void          mrchat_empty                 (mrchat_t*);
void          mrchat_unref                 (mrchat_t*);
char*         mrchat_get_subtitle          (mrchat_t*); /* either the email-address or the number of group members, the result must be free()'d! */
int           mrchat_get_total_msg_count   (mrchat_t*);
int           mrchat_get_fresh_msg_count   (mrchat_t*);
int           mrchat_set_draft             (mrchat_t*, const char*); /* Save draft in object and, if changed, in database.  May result in "MR_EVENT_MSGS_UPDATED".  Returns true/false. */
uint32_t      mrchat_send_msg              (mrchat_t*, mrmsg_t*); /* save message in database and send it, the given message object is not unref'd by the function but some fields are set up! */


/*** library-private **********************************************************/

uint32_t      mrchat_send_msg__                      (mrchat_t*, const mrmsg_t*, time_t);
int           mrchat_load_from_db__                  (mrchat_t*, uint32_t id);
int           mrchat_update_param__                  (mrchat_t*);
void          mrmailbox_unarchive_chat__             (mrmailbox_t*, uint32_t chat_id);
size_t        mrmailbox_get_chat_cnt__               (mrmailbox_t*);
uint32_t      mrmailbox_create_or_lookup_nchat_by_contact_id__(mrmailbox_t*, uint32_t contact_id);
uint32_t      mrmailbox_lookup_real_nchat_by_contact_id__(mrmailbox_t*, uint32_t contact_id);
int           mrmailbox_get_total_msg_count__        (mrmailbox_t*, uint32_t chat_id);
int           mrmailbox_get_fresh_msg_count__        (mrmailbox_t*, uint32_t chat_id);
uint32_t      mrmailbox_get_last_deaddrop_fresh_msg__(mrmailbox_t*);
void          mrmailbox_send_msg_to_smtp             (mrmailbox_t*, mrjob_t*);
void          mrmailbox_send_msg_to_imap             (mrmailbox_t*, mrjob_t*);
int           mrmailbox_add_contact_to_chat__        (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int           mrmailbox_is_contact_in_chat__         (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int           mrmailbox_get_chat_contact_count__     (mrmailbox_t*, uint32_t chat_id);
int           mrmailbox_group_explicitly_left__      (mrmailbox_t*, const char* grpid);
void          mrmailbox_set_group_explicitly_left__  (mrmailbox_t*, const char* grpid);

#define APPROX_SUBJECT_CHARS 32  /* as we do not cut inside words, this results in about 32-42 characters.
								 Do not use too long subjects - we add a tag after the subject which gets truncated by the clients otherwise.
								 It should also be very clear, the subject is _not_ the whole message.
								 The value is also used for CC:-summaries */


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCHAT_H__ */
