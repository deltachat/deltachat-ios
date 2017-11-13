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


#ifndef __MRMSG_H__
#define __MRMSG_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct mrmailbox_t mrmailbox_t;
typedef struct mrparam_t   mrparam_t;


/**
 * The message object and some function for helping accessing it.  The message
 * object is not updated.  If you want an update, you have to recreate the
 * object.
 */
typedef struct mrmsg_t
{
	#define         MR_MSG_ID_MARKER1       1 /**< any user-defined marker */
	#define         MR_MSG_ID_DAYMARKER     9 /**< in a list, the next message is on a new day, useful to show headlines */
	#define         MR_MSG_ID_LAST_SPECIAL  9
	uint32_t        m_id;

	uint32_t        m_from_id;                /**< contact, 0=unset, 1=self .. >9=real contacts */
	uint32_t        m_to_id;                  /**< contact, 0=unset, 1=self .. >9=real contacts */
	uint32_t        m_chat_id;                /**< the chat, the message belongs to: 0=unset, 1=unknwon sender .. >9=real chats */
	time_t          m_timestamp;              /**< unix time the message was sended */

	#define         MR_MSG_UNDEFINED        0
	#define         MR_MSG_TEXT            10
	#define         MR_MSG_IMAGE           20 /**< param: MRP_FILE, MRP_WIDTH, MRP_HEIGHT */
	#define         MR_MSG_GIF             21 /**< param: MRP_FILE, MRP_WIDTH, MRP_HEIGHT */
	#define         MR_MSG_AUDIO           40 /**< param: MRP_FILE, MRP_DURATION */
	#define         MR_MSG_VOICE           41 /**< param: MRP_FILE, MRP_DURATION */
	#define         MR_MSG_VIDEO           50 /**< param: MRP_FILE, MRP_WIDTH, MRP_HEIGHT, MRP_DURATION */
	#define         MR_MSG_FILE            60 /**< param: MRP_FILE */
	int             m_type;

	#define         MR_STATE_UNDEFINED      0
	#define         MR_STATE_IN_FRESH      10 /**< incoming message, not noticed nor seen */
	#define         MR_STATE_IN_NOTICED    13 /**< incoming message noticed (eg. chat opened but message not yet read - noticed messages are not counted as unread but did not marked as read nor resulted in MDNs) */
	#define         MR_STATE_IN_SEEN       16 /**< incoming message marked as read on IMAP and MDN may be send */
	#define         MR_STATE_OUT_PENDING   20 /**< hit "send" button - but the message is pending in some way, maybe we're offline (no checkmark) */
	#define         MR_STATE_OUT_ERROR     24 /**< unrecoverable error (recoverable errors result in pending messages) */
	#define         MR_STATE_OUT_DELIVERED 26 /**< outgoing message successfully delivered to server (one checkmark) */
	#define         MR_STATE_OUT_MDN_RCVD  28 /**< outgoing message read (two checkmarks; this requires goodwill on the receiver's side) */
	int             m_state;

	char*           m_text;                   /**< message text or NULL if unset */
	mrparam_t*      m_param;                  /**< MRP_FILE, MRP_WIDTH, MRP_HEIGHT etc. depends on the type, != NULL */
	int             m_starred;

	/** @privatesection */
	int             m_is_msgrmsg;
	mrmailbox_t*    m_mailbox;                /* may be NULL, set on loading from database and on sending */
	char*           m_rfc724_mid;
	char*           m_server_folder;
	uint32_t        m_server_uid;
} mrmsg_t;


mrmsg_t*        mrmsg_new                   ();
void            mrmsg_unref                 (mrmsg_t*);
void            mrmsg_empty                 (mrmsg_t*);
mrpoortext_t*   mrmsg_get_summary           (mrmsg_t*, mrchat_t*);
char*           mrmsg_get_summarytext       (mrmsg_t*, int approx_characters);
int             mrmsg_show_padlock          (mrmsg_t*);
char*           mrmsg_get_fullpath          (mrmsg_t*);
char*           mrmsg_get_filename          (mrmsg_t*);
mrpoortext_t*   mrmsg_get_mediainfo         (mrmsg_t*);
int             mrmsg_is_increation         (mrmsg_t*);
void            mrmsg_save_param_to_disk    (mrmsg_t*);
void            mrmsg_set_text              (mrmsg_t*, const char* text);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRMSG_H__ */
