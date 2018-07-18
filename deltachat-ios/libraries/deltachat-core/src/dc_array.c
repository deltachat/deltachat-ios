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


#include "dc_context.h"
#include "dc_array.h"

#define DC_ARRAY_MAGIC 0x000a11aa


/**
 * Create an array object in memory.
 *
 * @private @memberof dc_array_t
 * @param context The context object that should be stored in the array object. May be NULL.
 * @param initsize Initial maximal size of the array. If you add more items, the internal data pointer is reallocated.
 * @return New array object of the requested size, the data should be set directly.
 */
dc_array_t* dc_array_new(dc_context_t* context, size_t initsize)
{
	dc_array_t* array = NULL;

	array = (dc_array_t*) malloc(sizeof(dc_array_t));
	if (array==NULL) {
		exit(47);
	}

	array->magic     = DC_ARRAY_MAGIC;
	array->context   = context;
	array->count     = 0;
	array->allocated = initsize<1? 1 : initsize;
	array->array     = malloc(array->allocated * sizeof(uintptr_t));
	if (array->array==NULL) {
		exit(48);
	}

	return array;
}


/**
 * Free an array object. Does not free any data items.
 *
 * @memberof dc_array_t
 * @param array The array object to free, created eg. by dc_get_chatlist(), dc_get_contacts() and so on.
 * @return None.
 */
void dc_array_unref(dc_array_t* array)
{
	if (array==NULL || array->magic!=DC_ARRAY_MAGIC) {
		return;
	}

	free(array->array);
	array->magic = 0;
	free(array);
}


/**
 * Calls free() for each item and sets the item to 0 afterwards.
 * The array object itself is not deleted and the size of the array stays the same.
 *
 * @private @memberof dc_array_t
 * @param array The array object.
 * @return None.
 */
void dc_array_free_ptr(dc_array_t* array)
{
	if (array==NULL || array->magic!=DC_ARRAY_MAGIC) {
		return;
	}

	for (size_t i = 0; i<array->count; i++) {
		free((void*)array->array[i]);
		array->array[i] = 0;
	}
}


/**
 * Duplicates the array, take care if the array contains pointers to objects, take care to free them only once afterwards!
 * If the array only contains integers, you are always save.
 *
 * @private @memberof dc_array_t
 * @param array The array object.
 * @return The duplicated array.
 */
dc_array_t* dc_array_duplicate(const dc_array_t* array)
{
	dc_array_t* ret = NULL;

	if (array==NULL || array->magic!=DC_ARRAY_MAGIC) {
		return NULL;
	}

	ret = dc_array_new(array->context, array->allocated);
	ret->count = array->count;
	memcpy(ret->array, array->array, array->count * sizeof(uintptr_t));

	return ret;
}


static int cmp_intptr_t(const void* p1, const void* p2)
{
	uintptr_t v1 = *(uintptr_t*)p1;
	uintptr_t v2 = *(uintptr_t*)p2;
	return (v1<v2)? -1 : ((v1>v2)? 1 : 0); /* CAVE: do not use v1-v2 as the uintptr_t may be 64bit and the return value may be 32bit only... */
}


/**
 * Sort the array, assuming it contains unsigned integers.
 *
 * @private @memberof dc_array_t
 * @param array The array object.
 * @return The duplicated array.
 */
void dc_array_sort_ids(dc_array_t* array)
{
	if (array==NULL || array->magic!=DC_ARRAY_MAGIC || array->count <= 1) {
		return;
	}
	qsort(array->array, array->count, sizeof(uintptr_t), cmp_intptr_t);
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
 * @private @memberof dc_array_t
 * @param array The array object.
 * @return The duplicated array.
 */
void dc_array_sort_strings(dc_array_t* array)
{
	if (array==NULL || array->magic!=DC_ARRAY_MAGIC || array->count <= 1) {
		return;
	}
	qsort(array->array, array->count, sizeof(char*), cmp_strings_t);
}


/**
 * Empty an array object. Allocated data is not freed by this function, only the count is set to null.
 *
 * @private @memberof dc_array_t
 * @param array The array object to empty.
 * @return None.
 */
void dc_array_empty(dc_array_t* array)
{
	if (array==NULL || array->magic!=DC_ARRAY_MAGIC) {
		return;
	}

	array->count = 0;
}


/**
 * Add an unsigned integer to the array.
 * After calling this function the size of the array grows by one.
 * It is okay to add the ID 0, event in this case, the array grows by one.
 *
 * @param array The array to add the item to.
 * @param item The item to add.
 * @return None.
 */
void dc_array_add_uint(dc_array_t* array, uintptr_t item)
{
	if (array==NULL || array->magic!=DC_ARRAY_MAGIC) {
		return;
	}

	if (array->count==array->allocated) {
		int newsize = (array->allocated * 2) + 10;
		if ((array->array=realloc(array->array, newsize*sizeof(uintptr_t)))==NULL) {
			exit(49);
		}
		array->allocated = newsize;
	}

	array->array[array->count] = item;
	array->count++;
}


/**
 * Add an ID to the array.
 * After calling this function the size of the array grows by one.
 * It is okay to add the ID 0, event in this case, the array grows by one.
 *
 * @param array The array to add the item to.
 * @param item The item to add.
 * @return None.
 */
void dc_array_add_id(dc_array_t* array, uint32_t item)
{
	dc_array_add_uint(array, item);
}


/**
 * Add an pointer to the array.
 * After calling this function the size of the array grows by one.
 * It is okay to add the ID 0, event in this case, the array grows by one.
 *
 * @param array The array to add the item to.
 * @param item The item to add.
 * @return None.
 */
void dc_array_add_ptr(dc_array_t* array, void* item)
{
	dc_array_add_uint(array, (uintptr_t)item);
}


/**
 * Find out the number of items in an array.
 *
 * @memberof dc_array_t
 * @param array The array object.
 * @return Returns the number of items in a dc_array_t object. 0 on errors or if the array is empty.
 */
size_t dc_array_get_cnt(const dc_array_t* array)
{
	if (array==NULL || array->magic!=DC_ARRAY_MAGIC) {
		return 0;
	}

	return array->count;
}


/**
 * Get the item at the given index as an unsigned integer.
 * The size of the integer is always larget enough to hold a pointer.
 *
 * @memberof dc_array_t
 * @param array The array object.
 * @param index Index of the item to get. Must be between 0 and dc_array_get_cnt()-1.
 * @return Returns the item at the given index. Returns 0 on errors or if the array is empty.
 */
uintptr_t dc_array_get_uint(const dc_array_t* array, size_t index)
{
	if (array==NULL || array->magic!=DC_ARRAY_MAGIC || index<0 || index>=array->count) {
		return 0;
	}

	return array->array[index];
}


/**
 * Get the item at the given index as an ID.
 *
 * @memberof dc_array_t
 * @param array The array object.
 * @param index Index of the item to get. Must be between 0 and dc_array_get_cnt()-1.
 * @return Returns the item at the given index. Returns 0 on errors or if the array is empty.
 */
uint32_t dc_array_get_id(const dc_array_t* array, size_t index)
{
	if (array==NULL || array->magic!=DC_ARRAY_MAGIC || index<0 || index>=array->count) {
		return 0;
	}

	return (uint32_t)array->array[index];
}


/**
 * Get the item at the given index as an ID.
 *
 * @memberof dc_array_t
 * @param array The array object.
 * @param index Index of the item to get. Must be between 0 and dc_array_get_cnt()-1.
 * @return Returns the item at the given index. Returns 0 on errors or if the array is empty.
 */
void* dc_array_get_ptr(const dc_array_t* array, size_t index)
{
	if (array==NULL || array->magic!=DC_ARRAY_MAGIC || index<0 || index>=array->count) {
		return 0;
	}

	return (void*)array->array[index];
}


/**
 * Check if a given ID is present in an array.
 *
 * @private @memberof dc_array_t
 * @param array The array object to search in.
 * @param needle The ID to search for.
 * @param[out] ret_index If set, this will receive the index. Set to NULL if you're not interested in the index.
 * @return 1=ID is present in array, 0=ID not found.
 */
int dc_array_search_id(const dc_array_t* array, uint32_t needle, size_t* ret_index)
{
	if (array==NULL || array->magic!=DC_ARRAY_MAGIC) {
		return 0;
	}

	uintptr_t* data = array->array;
	size_t i, cnt = array->count;
	for (i=0; i<cnt; i++)
	{
		if (data[i]==needle) {
			if (ret_index) {
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
 * @private @memberof dc_array_t
 * @param array The array object.
 * @return Raw pointer to the array. You MUST NOT free the data. You MUST NOT access the data beyond the current item count.
 *     It is not possible to enlarge the array this way.  Calling any other dc_array-function may discard the returned pointer.
 */
const uintptr_t* dc_array_get_raw(const dc_array_t* array)
{
	if (array==NULL || array->magic!=DC_ARRAY_MAGIC) {
		return NULL;
	}
	return array->array;
}


char* dc_arr_to_string(const uint32_t* arr, int cnt)
{
	/* return comma-separated value-string from integer array */
	char*       ret = NULL;
	const char* sep = ",";

	if (arr==NULL || cnt <= 0) {
		return dc_strdup("");
	}

	/* use a macro to allow using integers of different bitwidths */
	#define INT_ARR_TO_STR(a, c) { \
		int i; \
		ret = malloc((c)*(11+strlen(sep))/*sign,10 digits,sep*/+1/*terminating zero*/); \
		if (ret==NULL) { exit(35); } \
		ret[0] = 0; \
		for (i=0; i<(c); i++) { \
			if (i) { \
				strcat(ret, sep); \
			} \
			sprintf(&ret[strlen(ret)], "%lu", (unsigned long)(a)[i]); \
		} \
	}

	INT_ARR_TO_STR(arr, cnt);

	return ret;
}


char* dc_array_get_string(const dc_array_t* array, const char* sep)
{
	char* ret = NULL;

	if (array==NULL || array->magic!=DC_ARRAY_MAGIC || sep==NULL) {
		return dc_strdup("");
	}

	INT_ARR_TO_STR(array->array, array->count);

	return ret;
}

