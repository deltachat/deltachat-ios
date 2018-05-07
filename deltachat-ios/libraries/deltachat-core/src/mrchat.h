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


typedef struct _mrmailbox mrmailbox_t;


#define         MR_CHAT_ID_DEADDROP         1 /* virtual chat showing all messages belonging to chats flagged with chats.blocked=2 */
#define         MR_CHAT_ID_TRASH            3 /* messages that should be deleted get this chat_id; the messages are deleted from the working thread later then. This is also needed as rfc724_mid should be preset as long as the message is not deleted on the server (otherwise it is downloaded again) */
#define         MR_CHAT_ID_MSGS_IN_CREATION 4 /* a message is just in creation but not yet assigned to a chat (eg. we may need the message ID to set up blobs; this avoids unready message to be sent and shown) */
#define         MR_CHAT_ID_STARRED          5 /* virtual chat showing all messages flagged with msgs.starred=2 */
#define         MR_CHAT_ID_ARCHIVED_LINK    6 /* only an indicator in a chatlist */
#define         MR_CHAT_ID_LAST_SPECIAL     9 /* larger chat IDs are "real" chats, their messages are "real" messages. */


#define         MR_CHAT_TYPE_UNDEFINED        0
#define         MR_CHAT_TYPE_SINGLE         100
#define         MR_CHAT_TYPE_GROUP          120
#define         MR_CHAT_TYPE_VERIFIED_GROUP 130


/**
 * @class mrchat_t
 *
 * An object representing a single chat in memory. Chat objects are created using eg. mrmailbox_get_chat() and
 * are not updated on database changes;  if you want an update, you have to recreate the
 * object.
 */
typedef struct _mrchat mrchat_t;


mrchat_t*       mrchat_new                  (mrmailbox_t*);
void            mrchat_empty                (mrchat_t*);
void            mrchat_unref                (mrchat_t*);

uint32_t        mrchat_get_id               (mrchat_t*);
int             mrchat_get_type             (mrchat_t*);
char*           mrchat_get_name             (mrchat_t*);
char*           mrchat_get_subtitle         (mrchat_t*);
char*           mrchat_get_profile_image    (mrchat_t*);
char*           mrchat_get_draft            (mrchat_t*);
time_t          mrchat_get_draft_timestamp  (mrchat_t*);
int             mrchat_get_archived         (mrchat_t*);
int             mrchat_is_unpromoted        (mrchat_t*);
int             mrchat_is_self_talk         (mrchat_t*);
int             mrchat_is_verified          (mrchat_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCHAT_H__ */
