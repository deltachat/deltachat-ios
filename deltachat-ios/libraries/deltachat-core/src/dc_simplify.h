#ifndef __DC_SIMPLIFY_H__
#define __DC_SIMPLIFY_H__
#ifdef __cplusplus
extern "C" {
#endif


/*** library-private **********************************************************/

typedef struct dc_simplify_t
{
	int is_forwarded;
	int is_cut_at_begin;
	int is_cut_at_end;
} dc_simplify_t;


dc_simplify_t* dc_simplify_new           ();
void           dc_simplify_unref         (dc_simplify_t*);

/* Simplify and normalise text: Remove quotes, signatures, unnecessary
lineends etc.
The data returned from Simplify() must be free()'d when no longer used, private */
char*          dc_simplify_simplify      (dc_simplify_t*, const char* txt_unterminated, int txt_bytes, int is_html);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_SIMPLIFY_H__ */

