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


typedef struct mrmailbox_t  mrmailbox_t;
typedef struct mrpoortext_t mrpoortext_t;
typedef struct mrchat_t     mrchat_t;


/**
 * An object representing a single chatlist in memory.
 * Chatlist objects contain chat IDs and, if possible, message IDs belonging to them.
 * Chatlist objects are created eg. using mrmailbox_get_chatlist().
 * The chatlist object is not updated.  If you want an update, you have to recreate
 * the object.
 */
typedef struct mrchatlist_t
{
	mrmailbox_t*    m_mailbox; /**< The mailbox, the chatlist belongs to */

	/** @privatesection */
	#define         MR_CHATLIST_IDS_PER_RESULT 2
	size_t          m_cnt;
	carray*         m_chatNlastmsg_ids;
} mrchatlist_t;


mrchatlist_t*   mrchatlist_new              (mrmailbox_t*);
void            mrchatlist_empty            (mrchatlist_t*);
void            mrchatlist_unref            (mrchatlist_t*);
size_t          mrchatlist_get_cnt          (mrchatlist_t*);
uint32_t        mrchatlist_get_chat_id      (mrchatlist_t*, size_t index);
uint32_t        mrchatlist_get_msg_id       (mrchatlist_t*, size_t index);
mrpoortext_t*   mrchatlist_get_summary      (mrchatlist_t*, size_t index, mrchat_t*);

/* library-internal */
int             mrchatlist_load_from_db__   (mrchatlist_t*, int listflags, const char* query);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCHATLIST_H__ */
