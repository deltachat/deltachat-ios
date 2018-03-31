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


#ifndef __MRCHATLIST_H__
#define __MRCHATLIST_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct _mrmailbox   mrmailbox_t;
typedef struct _mrlot       mrlot_t;
typedef struct _mrchat      mrchat_t;


/**
 * @class mrchatlist_t
 *
 * An object representing a single chatlist in memory.
 * Chatlist objects contain chat IDs and, if possible, message IDs belonging to them.
 * Chatlist objects are created eg. using mrmailbox_get_chatlist().
 * The chatlist object is not updated.  If you want an update, you have to recreate
 * the object.
 */
typedef struct _mrchatlist mrchatlist_t;


mrchatlist_t*   mrchatlist_new              (mrmailbox_t*);
void            mrchatlist_empty            (mrchatlist_t*);
void            mrchatlist_unref            (mrchatlist_t*);
size_t          mrchatlist_get_cnt          (mrchatlist_t*);
uint32_t        mrchatlist_get_chat_id      (mrchatlist_t*, size_t index);
uint32_t        mrchatlist_get_msg_id       (mrchatlist_t*, size_t index);
mrlot_t*        mrchatlist_get_summary      (mrchatlist_t*, size_t index, mrchat_t*);
mrmailbox_t*    mrchatlist_get_mailbox      (mrchatlist_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCHATLIST_H__ */
