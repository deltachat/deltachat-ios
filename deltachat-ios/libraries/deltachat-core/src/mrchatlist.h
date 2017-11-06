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
 * File:    mrchatlist.h
 * Purpose: list of chats
 *
 ******************************************************************************/


#ifndef __MRCHATLIST_H__
#define __MRCHATLIST_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct mrpoortext_t mrpoortext_t;


typedef struct mrchatlist_t
{
	size_t       m_cnt;
	carray*      m_chatNlastmsg_ids;
	mrmailbox_t* m_mailbox;
} mrchatlist_t;


mrchatlist_t* mrchatlist_new                 (mrmailbox_t*);
void          mrchatlist_unref               (mrchatlist_t*);
void          mrchatlist_empty               (mrchatlist_t*);
size_t        mrchatlist_get_cnt             (mrchatlist_t*);
mrchat_t*     mrchatlist_get_chat_by_index   (mrchatlist_t*, size_t index); /* result must be unref'd */
mrmsg_t*      mrchatlist_get_msg_by_index    (mrchatlist_t*, size_t index); /* result must be unref'd */
mrpoortext_t* mrchatlist_get_summary_by_index(mrchatlist_t*, size_t index, mrchat_t*); /* result must be unref'd, the 3rd parameter is only to speed up things */


/*** library-private **********************************************************/

int           mrchatlist_load_from_db__    (mrchatlist_t*, int listflags, const char* query);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCHATLIST_H__ */
