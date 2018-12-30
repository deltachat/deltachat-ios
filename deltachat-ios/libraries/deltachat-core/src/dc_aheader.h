#ifndef __DC_AHEADER_H__
#define __DC_AHEADER_H__
#ifdef __cplusplus
extern "C" {
#endif


#include "dc_key.h"


/**
 * Library-internal. Parse and create [Autocrypt-headers](https://autocrypt.org/en/latest/level1.html#the-autocrypt-header).
 */
typedef struct dc_aheader_t
{
	char*          addr;
	dc_key_t*      public_key; /* != NULL */
	int            prefer_encrypt; /* YES, NO or NOPREFERENCE if attribute is missing */
} dc_aheader_t;


dc_aheader_t* dc_aheader_new               (); /* the returned pointer is ref'd and must be unref'd after usage */
dc_aheader_t* dc_aheader_new_from_imffields(const char* wanted_from, const struct mailimf_fields* mime);
void          dc_aheader_empty             (dc_aheader_t*);
void          dc_aheader_unref             (dc_aheader_t*);

int           dc_aheader_set_from_string   (dc_aheader_t*, const char* header_str);

char*         dc_aheader_render            (const dc_aheader_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_AHEADER_H__ */
