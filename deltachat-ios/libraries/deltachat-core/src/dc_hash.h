#ifndef __DC_HASH_H__
#define __DC_HASH_H__
#ifdef __cplusplus
extern "C"
{
#endif


/* Forward declarations of structures.
 */
typedef struct dc_hashelem_t   dc_hashelem_t;


/* A complete hash table is an instance of the following structure.
 * The internals of this structure are intended to be opaque -- client
 * code should not attempt to access or modify the fields of this structure
 * directly.  Change this structure only by using the routines below.
 * However, many of the "procedures" and "functions" for modifying and
 * accessing this structure are really macros, so we can't really make
 * this structure opaque.
 */
typedef struct dc_hash_t
{
	char              keyClass;       /* SJHASH_INT, _POINTER, _STRING, _BINARY */
	char              copyKey;        /* True if copy of key made on insert */
	int               count;          /* Number of entries in this table */
	dc_hashelem_t     *first;         /* The first element of the array */
	int               htsize;         /* Number of buckets in the hash table */
	struct _ht
	{	/* the hash table */
		int           count;          /* Number of entries with this hash */
		dc_hashelem_t *chain;         /* Pointer to first entry with this hash */
	} *ht;
} dc_hash_t;


/* Each element in the hash table is an instance of the following
 * structure.  All elements are stored on a single doubly-linked list.
 *
 * Again, this structure is intended to be opaque, but it can't really
 * be opaque because it is used by macros.
 */
typedef struct dc_hashelem_t
{
	dc_hashelem_t     *next, *prev;   /* Next and previous elements in the table */
	void*             data;           /* Data associated with this element */
	void*             pKey;           /* Key associated with this element */
	int               nKey;           /* Key associated with this element */
} dc_hashelem_t;


/*
 * There are 4 different modes of operation for a hash table:
 *
 *   DC_HASH_INT         nKey is used as the key and pKey is ignored.
 *
 *   DC_HASH_POINTER     pKey is used as the key and nKey is ignored.
 *
 *   DC_HASH_STRING      pKey points to a string that is nKey bytes long
 *                      (including the null-terminator, if any).  Case
 *                      is ignored in comparisons.
 *
 *   DC_HASH_BINARY      pKey points to binary data nKey bytes long.
 *                      memcmp() is used to compare keys.
 *
 * A copy of the key is made for DC_HASH_STRING and DC_HASH_BINARY
 * if the copyKey parameter to dc_hash_init() is 1.
 */
#define DC_HASH_INT       1
#define DC_HASH_POINTER   2
#define DC_HASH_STRING    3
#define DC_HASH_BINARY    4


/*
 * Just to make the last parameter of dc_hash_init() more readable.
 */
#define DC_HASH_COPY_KEY  1


/*
 * Access routines.  To delete an element, insert a NULL pointer.
 */
void    dc_hash_init     (dc_hash_t*, int keytype, int copyKey);
void*   dc_hash_insert   (dc_hash_t*, const void *pKey, int nKey, void *pData);
void*   dc_hash_find     (const dc_hash_t*, const void *pKey, int nKey);
void    dc_hash_clear    (dc_hash_t*);

#define dc_hash_find_str(H, s) dc_hash_find((H), (s), strlen((s)))
#define dc_hash_insert_str(H, s, d) dc_hash_insert((H), (s), strlen((s)), (d))


/*
 * Macros for looping over all elements of a hash table.  The idiom is
 * like this:
 *
 *   SjHash h;
 *   SjHashElem *p;
 *   ...
 *   for(p=dc_hash_first(&h); p; p=dc_hash_next(p)){
 *     SomeStructure *pData = dc_hash_data(p);
 *     // do something with pData
 *   }
 */
#define dc_hash_first(H)      ((H)->first)
#define dc_hash_next(E)       ((E)->next)
#define dc_hash_data(E)       ((E)->data)
#define dc_hash_key(E)        ((E)->pKey)
#define dc_hash_keysize(E)    ((E)->nKey)


/*
 * Number of entries in a hash table
 */
#define dc_hash_cnt(H)        ((H)->count)


#ifdef __cplusplus
};  /* /extern "C" */
#endif
#endif /* __DC_HASH_H__ */
