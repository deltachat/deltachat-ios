#ifndef __DC_ARRAY_H__
#define __DC_ARRAY_H__
#ifdef __cplusplus
extern "C" {
#endif


/** the structure behind dc_array_t */
struct _dc_array
{
	/** @privatesection */

	uint32_t        magic;
	dc_context_t*   context;     /**< The context the array belongs to. May be NULL when NULL is given to dc_array_new(). */
	size_t          allocated;   /**< The number of allocated items. Initially ~ 200. */
	size_t          count;       /**< The number of used items. Initially 0. */
	uintptr_t*      array;       /**< The data items, can be used between data[0] and data[cnt-1]. Never NULL. */
};


void             dc_array_free_ptr            (dc_array_t*);
dc_array_t*      dc_array_duplicate           (const dc_array_t*);
void             dc_array_sort_ids            (dc_array_t*);
void             dc_array_sort_strings        (dc_array_t*);
char*            dc_array_get_string          (const dc_array_t*, const char* sep);
char*            dc_arr_to_string             (const uint32_t* arr, int cnt);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_ARRAY_H__ */
