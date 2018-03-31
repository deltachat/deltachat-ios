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


#ifndef __MRHASH_H__
#define __MRHASH_H__
#ifdef __cplusplus
extern "C"
{
#endif


/* Forward declarations of structures.
 */
typedef struct mrhashelem_t   mrhashelem_t;


/* A complete hash table is an instance of the following structure.
 * The internals of this structure are intended to be opaque -- client
 * code should not attempt to access or modify the fields of this structure
 * directly.  Change this structure only by using the routines below.
 * However, many of the "procedures" and "functions" for modifying and
 * accessing this structure are really macros, so we can't really make
 * this structure opaque.
 */
typedef struct mrhash_t
{
	char              keyClass;       /* SJHASH_INT, _POINTER, _STRING, _BINARY */
	char              copyKey;        /* True if copy of key made on insert */
	int               count;          /* Number of entries in this table */
	mrhashelem_t*     first;          /* The first element of the array */
	int               htsize;         /* Number of buckets in the hash table */
	struct _ht
	{	/* the hash table */
		int           count;          /* Number of entries with this hash */
		mrhashelem_t* chain;          /* Pointer to first entry with this hash */
	} *ht;
} mrhash_t;


/* Each element in the hash table is an instance of the following
 * structure.  All elements are stored on a single doubly-linked list.
 *
 * Again, this structure is intended to be opaque, but it can't really
 * be opaque because it is used by macros.
 */
typedef struct mrhashelem_t
{
	mrhashelem_t      *next, *prev;   /* Next and previous elements in the table */
	void*             data;           /* Data associated with this element */
	void*             pKey;           /* Key associated with this element */
	int               nKey;           /* Key associated with this element */
} mrhashelem_t;


/*
 * There are 4 different modes of operation for a hash table:
 *
 *   MRHASH_INT         nKey is used as the key and pKey is ignored.
 *
 *   MRHASH_POINTER     pKey is used as the key and nKey is ignored.
 *
 *   MRHASH_STRING      pKey points to a string that is nKey bytes long
 *                      (including the null-terminator, if any).  Case
 *                      is ignored in comparisons.
 *
 *   MRHASH_BINARY      pKey points to binary data nKey bytes long.
 *                      memcmp() is used to compare keys.
 *
 * A copy of the key is made for MRHASH_STRING and MRHASH_BINARY
 * if the copyKey parameter to mrhash_init() is 1.
 */
#define MRHASH_INT       1
#define MRHASH_POINTER   2
#define MRHASH_STRING    3
#define MRHASH_BINARY    4


/*
 * Access routines.  To delete an element, insert a NULL pointer.
 */
void    mrhash_init     (mrhash_t*, int keytype, int copyKey);
void*   mrhash_insert   (mrhash_t*, const void *pKey, int nKey, void *pData);
void*   mrhash_find     (const mrhash_t*, const void *pKey, int nKey);
void    mrhash_clear    (mrhash_t*);


/*
 * Macros for looping over all elements of a hash table.  The idiom is
 * like this:
 *
 *   SjHash h;
 *   SjHashElem *p;
 *   ...
 *   for(p=mrhash_first(&h); p; p=mrhash_next(p)){
 *     SomeStructure *pData = mrhash_data(p);
 *     // do something with pData
 *   }
 */
#define mrhash_first(H)      ((H)->first)
#define mrhash_next(E)       ((E)->next)
#define mrhash_data(E)       ((E)->data)
#define mrhash_key(E)        ((E)->pKey)
#define mrhash_keysize(E)    ((E)->nKey)


/*
 * Number of entries in a hash table
 */
#define mrhash_count(H)      ((H)->count)


#ifdef __cplusplus
};  /* /extern "C" */
#endif
#endif /* __MRHASH_H__ */
