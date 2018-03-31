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


#ifndef __MRARRAY_H__
#define __MRARRAY_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct _mrmailbox mrmailbox_t;


/**
 * @class mrarray_t
 *
 * An object containing a simple array.
 * This object is used in several placed where functions need to return an array.
 * The items of the array are typically IDs.
 * To free an array object, use mrarray_unref().
 */
typedef struct _mrarray mrarray_t;


mrarray_t*       mrarray_new                 (mrmailbox_t*, size_t initsize);
void             mrarray_empty               (mrarray_t*);
void             mrarray_unref               (mrarray_t*);

void             mrarray_add_uint            (mrarray_t*, uintptr_t);
void             mrarray_add_id              (mrarray_t*, uint32_t);
void             mrarray_add_ptr             (mrarray_t*, void*);

size_t           mrarray_get_cnt             (const mrarray_t*);
uintptr_t        mrarray_get_uint            (const mrarray_t*, size_t index);
uint32_t         mrarray_get_id              (const mrarray_t*, size_t index);
void*            mrarray_get_ptr             (const mrarray_t*, size_t index);

int              mrarray_search_id           (const mrarray_t*, uint32_t needle, size_t* indx);
const uintptr_t* mrarray_get_raw             (const mrarray_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRARRAY_H__ */

