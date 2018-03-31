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


#ifndef __MRARRAY_PRIVATE_H__
#define __MRARRAY_PRIVATE_H__
#ifdef __cplusplus
extern "C" {
#endif


/** the structure behind mrarray_t */
struct _mrarray
{
	/** @privatesection */

	uint32_t        m_magic;
	mrmailbox_t*    m_mailbox;     /**< The mailbox the array belongs to. May be NULL when NULL is given to mrarray_new(). */
	size_t          m_allocated;   /**< The number of allocated items. Initially ~ 200. */
	size_t          m_count;       /**< The number of used items. Initially 0. */
	uintptr_t*      m_array;       /**< The data items, can be used between m_data[0] and m_data[m_cnt-1]. Never NULL. */
};


void             mrarray_free_ptr            (mrarray_t*);
mrarray_t*       mrarray_duplicate           (const mrarray_t*);
void             mrarray_sort_ids            (mrarray_t*);
void             mrarray_sort_strings        (mrarray_t*);
char*            mrarray_get_string          (const mrarray_t*, const char* sep);
char*            mr_arr_to_string            (const uint32_t* arr, int cnt);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRARRAY_PRIVATE_H__ */
