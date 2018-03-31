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


typedef struct _mrmailbox mrmailbox_t;


/**
 * @class mrmsg_t
 *
 * An object representing a single message in memory.  The message
 * object is not updated.  If you want an update, you have to recreate the
 * object.
 */
typedef struct _mrmsg mrmsg_t;

#define         MR_MSG_ID_MARKER1       1
#define         MR_MSG_ID_DAYMARKER     9
#define         MR_MSG_ID_LAST_SPECIAL  9

#define         MR_MSG_UNDEFINED        0
#define         MR_MSG_TEXT            10
#define         MR_MSG_IMAGE           20 /* m_param may contain MRP_FILE, MRP_WIDTH, MRP_HEIGHT */
#define         MR_MSG_GIF             21 /*   - " -  */
#define         MR_MSG_AUDIO           40 /* m_param may contain MRP_FILE, MRP_DURATION */
#define         MR_MSG_VOICE           41 /*   - " -  */
#define         MR_MSG_VIDEO           50 /* m_param may contain MRP_FILE, MRP_WIDTH, MRP_HEIGHT, MRP_DURATION */
#define         MR_MSG_FILE            60 /* m_param may contain MRP_FILE  */

#define         MR_STATE_UNDEFINED      0
#define         MR_STATE_IN_FRESH      10
#define         MR_STATE_IN_NOTICED    13
#define         MR_STATE_IN_SEEN       16
#define         MR_STATE_OUT_PENDING   20
#define         MR_STATE_OUT_ERROR     24
#define         MR_STATE_OUT_DELIVERED 26 /* to check if a mail was sent, use mrmsg_is_sent() */
#define         MR_STATE_OUT_MDN_RCVD  28


#define         MR_MAX_GET_TEXT_LEN  30000 /* approx. max. lenght returned by mrmsg_get_text() */
#define         MR_MAX_GET_INFO_LEN 100000 /* approx. max. lenght returned by mrmailbox_get_msg_info() */


mrmsg_t*        mrmsg_new                   ();
void            mrmsg_unref                 (mrmsg_t*);
void            mrmsg_empty                 (mrmsg_t*);

uint32_t        mrmsg_get_id                (const mrmsg_t*);
uint32_t        mrmsg_get_from_id           (const mrmsg_t*);
uint32_t        mrmsg_get_chat_id           (const mrmsg_t*);
int             mrmsg_get_type              (const mrmsg_t*);
int             mrmsg_get_state             (const mrmsg_t*);
time_t          mrmsg_get_timestamp         (const mrmsg_t*);
char*           mrmsg_get_text              (const mrmsg_t*);
char*           mrmsg_get_file              (const mrmsg_t*);
char*           mrmsg_get_filename          (const mrmsg_t*);
char*           mrmsg_get_filemime          (const mrmsg_t*);
uint64_t        mrmsg_get_filebytes         (const mrmsg_t*);
mrlot_t*        mrmsg_get_mediainfo         (const mrmsg_t*);
int             mrmsg_get_width             (const mrmsg_t*);
int             mrmsg_get_height            (const mrmsg_t*);
int             mrmsg_get_duration          (const mrmsg_t*);
int             mrmsg_get_showpadlock       (const mrmsg_t*);
mrlot_t*        mrmsg_get_summary           (const mrmsg_t*, const mrchat_t*);
char*           mrmsg_get_summarytext       (const mrmsg_t*, int approx_characters);
int             mrmsg_is_sent               (const mrmsg_t*);
int             mrmsg_is_starred            (const mrmsg_t*);
int             mrmsg_is_forwarded          (const mrmsg_t*);
int             mrmsg_is_systemcmd          (const mrmsg_t*);
int             mrmsg_is_increation         (const mrmsg_t*);

int             mrmsg_is_setupmessage       (const mrmsg_t*);
char*           mrmsg_get_setupcodebegin    (const mrmsg_t*);

void            mrmsg_latefiling_mediasize  (mrmsg_t*, int width, int height, int duration);




#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRMSG_H__ */
