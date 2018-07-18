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


/* Parse MIME body; this is the text part of an IMF, see https://tools.ietf.org/html/rfc5322
dc_mimeparser_t has no deep dependencies to dc_context_t or to the database
(dc_context_t is used for logging only). */


#ifndef __DC_MIMEPARSER_H__
#define __DC_MIMEPARSER_H__
#ifdef __cplusplus
extern "C" {
#endif


#include "dc_hash.h"
#include "dc_param.h"


typedef struct dc_e2ee_helper_t dc_e2ee_helper_t;


typedef struct dc_mimepart_t
{
	/** @privatesection */
	int                 type; /*one of DC_MSG_* */
	int                 is_meta; /*meta parts contain eg. profile or group images and are only present if there is at least one "normal" part*/
	int                 int_mimetype;
	char*               msg;
	char*               msg_raw;
	int                 bytes;
	dc_param_t*          param;

} dc_mimepart_t;


typedef struct dc_mimeparser_t
{
	/** @privatesection */

	/* data, read-only, must not be free()'d (it is free()'d when the dc_mimeparser_t object gets destructed) */
	carray*                parts;             /* array of dc_mimepart_t objects */
	struct mailmime*       mimeroot;

	dc_hash_t              header;            /* memoryhole-compliant header */
	struct mailimf_fields* header_root;       /* must NOT be freed, do not use for query, merged into header, a pointer somewhere to the MIME data*/
	struct mailimf_fields* header_protected;  /* MUST be freed, do not use for query, merged into header  */

	char*                  subject;
	int                    is_send_by_messenger;

	int                    decrypting_failed; /* set, if there are multipart/encrypted parts left after decryption */

	dc_e2ee_helper_t*      e2ee_helper;

	const char*            blobdir;

	int                    is_forwarded;

	dc_context_t*          context;

	carray*                reports;           /* array of mailmime objects */

	int                    is_system_message;

} dc_mimeparser_t;


dc_mimeparser_t*  dc_mimeparser_new                    (const char* blobdir, dc_context_t*);
void             dc_mimeparser_unref                  (dc_mimeparser_t*);
void             dc_mimeparser_empty                  (dc_mimeparser_t*);

void             dc_mimeparser_parse                  (dc_mimeparser_t*, const char* body_not_terminated, size_t body_bytes);


/* the following functions can be used only after a call to dc_mimeparser_parse() */
struct mailimf_field*          dc_mimeparser_lookup_field           (dc_mimeparser_t*, const char* field_name);
struct mailimf_optional_field* dc_mimeparser_lookup_optional_field  (dc_mimeparser_t*, const char* field_name);
struct mailimf_optional_field* dc_mimeparser_lookup_optional_field2 (dc_mimeparser_t*, const char* field_name, const char* or_field_name);
dc_mimepart_t*                 dc_mimeparser_get_last_nonmeta       (dc_mimeparser_t*);
#define                        dc_mimeparser_has_nonmeta(a)         (dc_mimeparser_get_last_nonmeta((a))!=NULL)
int                            dc_mimeparser_is_mailinglist_message (dc_mimeparser_t*);
int                            dc_mimeparser_sender_equals_recipient(dc_mimeparser_t*);



/* low-level-tools for working with mailmime structures directly */
#ifdef DC_USE_MIME_DEBUG
void                           mailmime_print                (struct mailmime*);
#endif
struct mailmime_parameter*     mailmime_find_ct_parameter    (struct mailmime*, const char* name);
int                            mailmime_transfer_decode      (struct mailmime*, const char** ret_decoded_data, size_t* ret_decoded_data_bytes, char** ret_to_mmap_string_unref);
struct mailimf_fields*         mailmime_find_mailimf_fields  (struct mailmime*); /*the result is a pointer to mime, must not be freed*/
char*                          mailimf_find_first_addr       (const struct mailimf_mailbox_list*); /*the result must be freed*/
struct mailimf_field*          mailimf_find_field            (struct mailimf_fields*, int wanted_fld_type); /*the result is a pointer to mime, must not be freed*/
struct mailimf_optional_field* mailimf_find_optional_field   (struct mailimf_fields*, const char* wanted_fld_name);
dc_hash_t*                      mailimf_get_recipients        (struct mailimf_fields*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_MIMEPARSER_H__ */

