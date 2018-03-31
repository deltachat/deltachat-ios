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


#ifndef __MRCHATLIST_PRIVATE_H__
#define __MRCHATLIST_PRIVATE_H__
#ifdef __cplusplus
extern "C" {
#endif


/** the structure behind mrchatlist_t */
struct _mrchatlist
{
	/** @privatesection */
	uint32_t        m_magic;
	mrmailbox_t*    m_mailbox; /**< The mailbox, the chatlist belongs to */
	#define         MR_CHATLIST_IDS_PER_RESULT 2
	size_t          m_cnt;
	mrarray_t*      m_chatNlastmsg_ids;
};


int             mrchatlist_load_from_db__   (mrchatlist_t*, int listflags, const char* query);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCHATLIST_PRIVATE_H__ */
