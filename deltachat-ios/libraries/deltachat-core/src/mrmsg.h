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
 * File:    mrmsg.h
 * Purpose: mrmsg_t represents a single message in a chat.  One email can
 *          result in different messages!
 *
 ******************************************************************************/


#ifndef __MRMSG_H__
#define __MRMSG_H__
#ifdef __cplusplus
extern "C" {
#endif


#include "mrparam.h"
typedef struct mrjob_t mrjob_t;
typedef struct mrpoortext_t mrpoortext_t;
typedef struct mrchat_t mrchat_t;


/* message types */
#define MR_MSG_UNDEFINED   0
#define MR_MSG_TEXT        10
#define MR_MSG_IMAGE       20 /* param: MRP_FILE, MRP_WIDTH, MRP_HEIGHT */
#define MR_MSG_GIF         21 /* param: MRP_FILE, MRP_WIDTH, MRP_HEIGHT */
#define MR_MSG_AUDIO       40 /* param: MRP_FILE, MRP_DURATION */
#define MR_MSG_VOICE       41 /* param: MRP_FILE, MRP_DURATION */
#define MR_MSG_VIDEO       50 /* param: MRP_FILE, MRP_WIDTH, MRP_HEIGHT, MRP_DURATION */
#define MR_MSG_FILE        60 /* param: MRP_FILE */

#define MR_MSG_NEEDS_ATTACHMENT(a)         ((a)==MR_MSG_IMAGE || (a)==MR_MSG_GIF || (a)==MR_MSG_AUDIO || (a)==MR_MSG_VOICE || (a)==MR_MSG_VIDEO || (a)==MR_MSG_FILE)
#define MR_MSG_MAKE_FILENAME_SEARCHABLE(a) ((a)==MR_MSG_AUDIO || (a)==MR_MSG_FILE || (a)==MR_MSG_VIDEO ) /* add filename.ext (without path) to m_text? this is needed for the fulltext search. The extension is useful to get all PDF, all MP3 etc. */
#define MR_MSG_MAKE_SUFFIX_SEARCHABLE(a)   ((a)==MR_MSG_IMAGE || (a)==MR_MSG_GIF || (a)==MR_MSG_VOICE)


/* message states */
#define MR_STATE_UNDEFINED  0
#define MR_IN_FRESH        10 /* incoming message, not noticed nor seen */
#define MR_IN_NOTICED      13 /* incoming message noticed (eg. chat opened but message not yet read - noticed messages are not counted as unread but did not marked as read nor resulted in MDNs) */
#define MR_IN_SEEN         16 /* incoming message marked as read on IMAP and MDN may be send */
#define MR_OUT_PENDING     20 /* hit "send" button - but the message is pending in some way, maybe we're offline (no checkmark) */
#define MR_OUT_ERROR       24 /* unrecoverable error (recoverable errors result in pending messages) */
#define MR_OUT_DELIVERED   26 /* outgoing message successfully delivered to server (one checkmark) */
#define MR_OUT_MDN_RCVD    28 /* outgoing message read (two checkmarks; this requires goodwill on the receiver's side) */


/* special message IDs (only returned if requested) */
#define MR_MSG_ID_MARKER1      1 /* any user-defined marker */
#define MR_MSG_ID_DAYMARKER    9 /* in a list, the next message is on a new day, useful to show headlines */
#define MR_MSG_ID_LAST_SPECIAL 9


typedef struct mrmsg_t
{
	uint32_t      m_id;
	char*         m_rfc724_mid;
	char*         m_server_folder;
	uint32_t      m_server_uid;
	uint32_t      m_from_id;   /* contact, 0=unset, 1=self .. >9=real contacts */
	uint32_t      m_to_id;     /* contact, 0=unset, 1=self .. >9=real contacts */
	uint32_t      m_chat_id;   /* the chat, the message belongs to: 0=unset, 1=unknwon sender .. >9=real chats */
	time_t        m_timestamp; /* unix time the message was sended */

	int           m_type;      /* MR_MSG_* */
	int           m_state;     /* MR_STATE_* etc. */
	int           m_is_msgrmsg;
	char*         m_text;      /* message text or NULL if unset */
	mrparam_t*    m_param;     /* MRP_FILE, MRP_WIDTH, MRP_HEIGHT etc. depends on the type, != NULL */
	int           m_starred;

	mrmailbox_t*  m_mailbox;   /* may be NULL, set on loading from database and on sending */

} mrmsg_t;


mrmsg_t*      mrmsg_new                    ();
void          mrmsg_unref                  (mrmsg_t*); /* this also free()s all strings; so if you set up the object yourself, make sure to use strdup()! */
void          mrmsg_empty                  (mrmsg_t*);
mrpoortext_t* mrmsg_get_summary            (mrmsg_t*, const mrchat_t*);
char*         mrmsg_get_summarytext        (mrmsg_t*, int approx_characters); /* the returned value must be free()'d */
int           mrmsg_show_padlock           (mrmsg_t*); /* a padlock should be shown if the message is e2ee _and_ e2ee is enabled for sending. */
char*         mrmsg_get_filename           (mrmsg_t*); /* returns base file name without part, if appropriate, the returned value must be free()'d */
mrpoortext_t* mrmsg_get_mediainfo          (mrmsg_t*); /* returns real author (as text1, this is not always the sender, NULL if unknown) and title (text2, NULL if unknown) */
int           mrmsg_is_increation          (mrmsg_t*);
void          mrmsg_save_param_to_disk     (mrmsg_t*); /* can be used to add some additional, persistent information to a messages record */
void          mrmsg_set_text               (mrmsg_t*, const char* text);


/*** library-private **********************************************************/

#define      MR_MSG_FIELDS                    " m.id,rfc724_mid,m.server_folder,m.server_uid,m.chat_id, m.from_id,m.to_id,m.timestamp, m.type,m.state,m.msgrmsg,m.txt, m.param,m.starred "
int          mrmsg_set_from_stmt__            (mrmsg_t*, sqlite3_stmt* row, int row_offset); /* row order is MR_MSG_FIELDS */
int          mrmsg_load_from_db__             (mrmsg_t*, mrmailbox_t*, uint32_t id);
void         mr_guess_msgtype_from_suffix     (const char* pathNfilename, int* ret_msgtype, char** ret_mime);
size_t       mrmailbox_get_real_msg_cnt__     (mrmailbox_t*); /* the number of messages assigned to real chat (!=deaddrop, !=trash) */
size_t       mrmailbox_get_deaddrop_msg_cnt__ (mrmailbox_t*);
int          mrmailbox_rfc724_mid_cnt__       (mrmailbox_t*, const char* rfc724_mid);
int          mrmailbox_rfc724_mid_exists__    (mrmailbox_t*, const char* rfc724_mid, char** ret_server_folder, uint32_t* ret_server_uid);
void         mrmailbox_update_server_uid__    (mrmailbox_t*, const char* rfc724_mid, const char* server_folder, uint32_t server_uid);
void         mrmailbox_update_msg_chat_id__   (mrmailbox_t*, uint32_t msg_id, uint32_t chat_id);
void         mrmailbox_update_msg_state__     (mrmailbox_t*, uint32_t msg_id, int state);
void         mrmailbox_delete_msg_on_imap     (mrmailbox_t* mailbox, mrjob_t* job);
int          mrmailbox_mdn_from_ext__         (mrmailbox_t*, uint32_t from_id, const char* rfc724_mid, uint32_t* ret_chat_id, uint32_t* ret_msg_id); /* returns 1 if an event should be send */
void         mrmailbox_send_mdn               (mrmailbox_t*, mrjob_t* job);
void         mrmailbox_markseen_msg_on_imap   (mrmailbox_t* mailbox, mrjob_t* job);
void         mrmailbox_markseen_mdn_on_imap   (mrmailbox_t* mailbox, mrjob_t* job);
char*        mrmsg_get_summarytext_by_raw     (int type, const char* text, mrparam_t*, int approx_bytes); /* the returned value must be free()'d */
int          mrmsg_is_increation__            (const mrmsg_t*);
void         mrmsg_save_param_to_disk__       (mrmsg_t*);
void         mr_get_authorNtitle_from_filename(const char* pathNfilename, char** ret_author, char** ret_title);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRMSG_H__ */

