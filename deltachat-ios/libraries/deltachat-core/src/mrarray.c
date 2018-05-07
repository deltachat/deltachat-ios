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


#include "mrmailbox_internal.h"
#include "mrarray-private.h"

#define MR_ARRAY_MAGIC 0x000a11aa


/**
 * Create an array object in memory.
 *
 * @private @memberof mrarray_t
 *
 * @param mailbox The mailbox object that should be stored in the array object. May be NULL.
 * @param initsize Initial maximal size of the array. If you add more items, the internal data pointer is reallocated.
 *
 * @return New array object of the requested size, the data should be set directly.
 */
mrarray_t* mrarray_new(mrmailbox_t* mailbox, size_t initsize)
{
	mrarray_t* array;

	array = (mrarray_t*) malloc(sizeof(mrarray_t));
	if( array==NULL ) {
		exit(47);
	}

	array->m_magic     = MR_ARRAY_MAGIC;
	array->m_mailbox   = mailbox;
	array->m_count     = 0;
	array->m_allocated = initsize < 1? 1 : initsize;
	array->m_array     = malloc(array->m_allocated * sizeof(uintptr_t));
	if( array->m_array==NULL ) {
		exit(48);
	}

	return array;
}


/**
 * Free an array object. Does not free any data items.
 *
 * @memberof mrarray_t
 *
 * @param array The array object to free, created eg. by mrmailbox_get_chatlist(), mrmailbox_get_contacts() and so on.
 *
 * @return None.
 *
 */
void mrarray_unref(mrarray_t* array)
{
	if( array==NULL || array->m_magic != MR_ARRAY_MAGIC ) {
		return;
	}

	free(array->m_array);
	array->m_magic = 0;
	free(array);
}


/**
 * Calls free() for each item and sets the item to 0 afterwards.
 * The array object itself is not deleted and the size of the array stays the same.
 *
 * @private @memberof mrarray_t
 *
 * @param array The array object.
 *
 * @return None.
 *
 */
void mrarray_free_ptr(mrarray_t* array)
{
	size_t i;

	if( array==NULL || array->m_magic != MR_ARRAY_MAGIC ) {
		return;
	}

	for( i = 0; i < array->m_count; i++ ) {
		free((void*)array->m_array[i]);
		array->m_array[i] = 0;
	}
}


/**
 * Duplicates the array, take care if the array contains pointers to objects, take care to free them only once afterwards!
 * If the array only contains integers, you are always save.
 *
 * @private @memberof mrarray_t
 *
 * @param array The array object.
 *
 * @return The duplicated array.
 *
 */
mrarray_t* mrarray_duplicate(const mrarray_t* array)
{
	mrarray_t* ret = NULL;

	if( array==NULL || array->m_magic != MR_ARRAY_MAGIC ) {
		return NULL;
	}

	ret = mrarray_new(array->m_mailbox, array->m_allocated);
	ret->m_count = array->m_count;
	memcpy(ret->m_array, array->m_array, array->m_count * sizeof(uintptr_t));

	return ret;
}


static int cmp_intptr_t(const void* p1, const void* p2)
{
	uintptr_t v1 = *(uintptr_t*)p1, v2 = *(uintptr_t*)p2;
	return (v1<v2)? -1 : ((v1>v2)? 1 : 0); /* CAVE: do not use v1-v2 as the uintptr_t may be 64bit and the return value may be 32bit only... */
}


/**
 * Sort the array, assuming it contains unsigned integers.
 *
 * @private @memberof mrarray_t
 *
 * @param array The array object.
 *
 * @return The duplicated array.
 *
 */
void mrarray_sort_ids(mrarray_t* array)
{
	if( array == NULL || array->m_magic != MR_ARRAY_MAGIC || array->m_count <= 1 ) {
		return;
	}
	qsort(array->m_array, array->m_count, sizeof(uintptr_t), cmp_intptr_t);
}


static int cmp_strings_t(const void* p1, const void* p2)
{
    const char* v1 = *(const char **)p1;
    const char* v2 = *(const char **)p2;
    return strcmp(v1, v2);
}


/**
 * Sort the array, assuming it contains pointers to strings.
 *
 * @private @memberof mrarray_t
 *
 * @param array The array object.
 *
 * @return The duplicated array.
 *
 */
void mrarray_sort_strings(mrarray_t* array)
{
	if( array == NULL || array->m_magic != MR_ARRAY_MAGIC || array->m_count <= 1 ) {
		return;
	}
	qsort(array->m_array, array->m_count, sizeof(char*), cmp_strings_t);
}


/**
 * Empty an array object. Allocated data is not freed by this function, only the count is set to null.
 *
 * @private @memberof mrarray_t
 *
 * @param array The array object to empty.
 *
 * @return None.
 */
void mrarray_empty(mrarray_t* array)
{
	if( array == NULL || array->m_magic != MR_ARRAY_MAGIC ) {
		return;
	}

	array->m_count = 0;
}


/**
 * Add an unsigned integer to the array.
 * After calling this function the size of the array grows by one.
 * It is okay to add the ID 0, event in this case, the array grows by one.
 *
 * @param array The array to add the item to.
 *
 * @param item The item to add.
 *
 * @return None.
 */
void mrarray_add_uint(mrarray_t* array, uintptr_t item)
{
	if( array == NULL || array->m_magic != MR_ARRAY_MAGIC ) {
		return;
	}

	if( array->m_count == array->m_allocated ) {
		int newsize = (array->m_allocated * 2) + 10;
		if( (array->m_array=realloc(array->m_array, newsize*sizeof(uintptr_t)))==NULL ) {
			exit(49);
		}
		array->m_allocated = newsize;
	}

	array->m_array[array->m_count] = item;
	array->m_count++;
}


/**
 * Add an ID to the array.
 * After calling this function the size of the array grows by one.
 * It is okay to add the ID 0, event in this case, the array grows by one.
 *
 * @param array The array to add the item to.
 *
 * @param item The item to add.
 *
 * @return None.
 */
void mrarray_add_id(mrarray_t* array, uint32_t item)
{
	mrarray_add_uint(array, item);
}


/**
 * Add an pointer to the array.
 * After calling this function the size of the array grows by one.
 * It is okay to add the ID 0, event in this case, the array grows by one.
 *
 * @param array The array to add the item to.
 *
 * @param item The item to add.
 *
 * @return None.
 */
void mrarray_add_ptr(mrarray_t* array, void* item)
{
	mrarray_add_uint(array, (uintptr_t)item);
}


/**
 * Find out the number of items in an array.
 *
 * @memberof mrarray_t
 *
 * @param array The array object.
 *
 * @return Returns the number of items in a mrarray_t object. 0 on errors or if the array is empty.
 */
size_t mrarray_get_cnt(const mrarray_t* array)
{
	if( array == NULL || array->m_magic != MR_ARRAY_MAGIC ) {
		return 0;
	}

	return array->m_count;
}


/**
 * Get the item at the given index as an unsigned integer.
 * The size of the integer is always larget enough to hold a pointer.
 *
 * @memberof mrarray_t
 *
 * @param array The array object.
 * @param index Index of the item to get. Must be between 0 and mrarray_get_cnt()-1.
 *
 * @return Returns the item at the given index. Returns 0 on errors or if the array is empty.
 */
uintptr_t mrarray_get_uint(const mrarray_t* array, size_t index)
{
	if( array == NULL || array->m_magic != MR_ARRAY_MAGIC || index < 0 || index >= array->m_count ) {
		return 0;
	}

	return array->m_array[index];
}


/**
 * Get the item at the given index as an ID.
 *
 * @memberof mrarray_t
 *
 * @param array The array object.
 * @param index Index of the item to get. Must be between 0 and mrarray_get_cnt()-1.
 *
 * @return Returns the item at the given index. Returns 0 on errors or if the array is empty.
 */
uint32_t mrarray_get_id(const mrarray_t* array, size_t index)
{
	if( array == NULL || array->m_magic != MR_ARRAY_MAGIC || index < 0 || index >= array->m_count ) {
		return 0;
	}

	return (uint32_t)array->m_array[index];
}


/**
 * Get the item at the given index as an ID.
 *
 * @memberof mrarray_t
 *
 * @param array The array object.
 * @param index Index of the item to get. Must be between 0 and mrarray_get_cnt()-1.
 *
 * @return Returns the item at the given index. Returns 0 on errors or if the array is empty.
 */
void* mrarray_get_ptr(const mrarray_t* array, size_t index)
{
	if( array == NULL || array->m_magic != MR_ARRAY_MAGIC || index < 0 || index >= array->m_count ) {
		return 0;
	}

	return (void*)array->m_array[index];
}


/**
 * Check if a given ID is present in an array.
 *
 * @private @memberof mrarray_t
 *
 * @param array The array object to search in.
 * @param needle The ID to search for.
 * @param ret_index If set, this will receive the index. Set to NULL if you're not interested in the index.
 *
 * @return 1=ID is present in array, 0=ID not found.
 */
int mrarray_search_id(const mrarray_t* array, uint32_t needle, size_t* ret_index)
{
	if( array == NULL || array->m_magic != MR_ARRAY_MAGIC ) {
		return 0;
	}

	uintptr_t* data = array->m_array;
	size_t i, cnt = array->m_count;
	for( i=0; i<cnt; i++ )
	{
		if( data[i] == needle ) {
			if( ret_index ) {
				*ret_index = i;
			}
			return 1;
		}
	}

	return 0;
}


/**
 * Get raw pointer to the data.
 *
 * @private @memberof mrarray_t
 *
 * @param array The array object.
 *
 * @return Raw pointer to the array. You MUST NOT free the data. You MUST NOT access the data beyond the current item count.
 *     It is not possible to enlarge the array this way.  Calling any other mrarray-function may discard the returned pointer.
 */
const uintptr_t* mrarray_get_raw(const mrarray_t* array)
{
	if( array == NULL || array->m_magic != MR_ARRAY_MAGIC ) {
		return NULL;
	}
	return array->m_array;
}


char* mr_arr_to_string(const uint32_t* arr, int cnt)
{
	/* return comma-separated value-string from integer array */
	char*       ret = NULL;
	const char* sep = ",";

	if( arr==NULL || cnt <= 0 ) {
		return safe_strdup("");
	}

	/* use a macro to allow using integers of different bitwidths */
	#define INT_ARR_TO_STR(a, c) { \
		int i; \
		ret = malloc((c)*(11+strlen(sep))/*sign,10 digits,sep*/+1/*terminating zero*/); \
		if( ret == NULL ) { exit(35); } \
		ret[0] = 0; \
		for( i=0; i<(c); i++ ) { \
			if( i ) { \
				strcat(ret, sep); \
			} \
			sprintf(&ret[strlen(ret)], "%lu", (unsigned long)(a)[i]); \
		} \
	}

	INT_ARR_TO_STR(arr, cnt);

	return ret;
}


char* mrarray_get_string(const mrarray_t* array, const char* sep)
{
	char* ret = NULL;

	if( array == NULL || array->m_magic != MR_ARRAY_MAGIC || sep==NULL ) {
		return safe_strdup("");
	}

	INT_ARR_TO_STR(array->m_array, array->m_count);

	return ret;
}

