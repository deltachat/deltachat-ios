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


#ifndef __DC_CHATLIST_H__
#define __DC_CHATLIST_H__
#ifdef __cplusplus
extern "C" {
#endif


/** the structure behind dc_chatlist_t */
struct _dc_chatlist
{
	/** @privatesection */
	uint32_t        magic;
	dc_context_t*   context; /**< The context, the chatlist belongs to */
	#define         DC_CHATLIST_IDS_PER_RESULT 2
	size_t          cnt;
	dc_array_t*     chatNlastmsg_ids;
};

int             dc_chatlist_load_from_db   (dc_chatlist_t*, int listflags, const char* query, uint32_t query_contact_id);


// Context functions to work with chatlist
int             dc_get_archived_cnt        (dc_context_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_CHATLIST_H__ */
