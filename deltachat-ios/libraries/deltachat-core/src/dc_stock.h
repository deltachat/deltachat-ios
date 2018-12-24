#ifndef __DC_STOCK_H__
#define __DC_STOCK_H__
#ifdef __cplusplus
extern "C" {
#endif


#include <stdlib.h>
#include <string.h>


/* Return the string with the given ID by calling DC_EVENT_GET_STRING.
The result must be free()'d! */
char* dc_stock_str (dc_context_t*, int id);


/* Replaces the first `%1$s` in the given String-ID by the given value.
The result must be free()'d! */
char* dc_stock_str_repl_string (dc_context_t*, int id, const char* value);
char* dc_stock_str_repl_int    (dc_context_t*, int id, int value);


/* Replaces the first `%1$s` and `%2$s` in the given String-ID by the two given strings.
The result must be free()'d! */
char* dc_stock_str_repl_string2 (dc_context_t*, int id, const char*, const char*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_STOCK_H__ */

