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
mrmimeparser_t has no deep dependencies to mrmailbox_t or to the database
(mrmailbox_t is used for logging only). */


#ifndef __MRMIMEPARSER_H__
#define __MRMIMEPARSER_H__
#ifdef __cplusplus
extern "C" {
#endif


#include "mrhash.h"
#include "mrparam.h"


typedef struct mrmailbox_e2ee_helper_t mrmailbox_e2ee_helper_t;


typedef struct mrmimepart_t
{
	/** @privatesection */
	int                 m_type; /*one of MR_MSG_* */
	int                 m_is_meta; /*meta parts contain eg. profile or group images and are only present if there is at least one "normal" part*/
	int                 m_int_mimetype;
	char*               m_msg;
	char*               m_msg_raw;
	int                 m_bytes;
	mrparam_t*          m_param;

} mrmimepart_t;


typedef struct mrmimeparser_t
{
	/** @privatesection */

	/* data, read-only, must not be free()'d (it is free()'d when the mrmimeparser_t object gets destructed) */
	carray*                m_parts;             /* array of mrmimepart_t objects */
	struct mailmime*       m_mimeroot;

	mrhash_t               m_header;            /* memoryhole-compliant header */
	struct mailimf_fields* m_header_root;       /* must NOT be freed, do not use for query, merged into m_header, a pointer somewhere to the MIME data*/
	struct mailimf_fields* m_header_protected;  /* MUST be freed, do not use for query, merged into m_header  */

	char*                  m_subject;
	int                    m_is_send_by_messenger;

	int                    m_decrypting_failed; /* set, if there are multipart/encrypted parts left after decryption */

	mrmailbox_e2ee_helper_t* m_e2ee_helper;

	const char*            m_blobdir;

	int                    m_is_forwarded;

	mrmailbox_t*           m_mailbox;

	carray*                m_reports;           /* array of mailmime objects */

	int                    m_is_system_message;

} mrmimeparser_t;


mrmimeparser_t*  mrmimeparser_new                    (const char* blobdir, mrmailbox_t*);
void             mrmimeparser_unref                  (mrmimeparser_t*);
void             mrmimeparser_empty                  (mrmimeparser_t*);

void             mrmimeparser_parse                  (mrmimeparser_t*, const char* body_not_terminated, size_t body_bytes);


/* the following functions can be used only after a call to mrmimeparser_parse() */
struct mailimf_field*          mrmimeparser_lookup_field           (mrmimeparser_t*, const char* field_name);
struct mailimf_optional_field* mrmimeparser_lookup_optional_field  (mrmimeparser_t*, const char* field_name);
struct mailimf_optional_field* mrmimeparser_lookup_optional_field2 (mrmimeparser_t*, const char* field_name, const char* or_field_name);
mrmimepart_t*                  mrmimeparser_get_last_nonmeta       (mrmimeparser_t*);
#define                        mrmimeparser_has_nonmeta(a)         (mrmimeparser_get_last_nonmeta((a))!=NULL)
int                            mrmimeparser_is_mailinglist_message (mrmimeparser_t*);
int                            mrmimeparser_sender_equals_recipient(mrmimeparser_t*);



/* low-level-tools for working with mailmime structures directly */
#ifdef MR_USE_MIME_DEBUG
void                           mailmime_print                (struct mailmime*);
#endif
struct mailmime_parameter*     mailmime_find_ct_parameter    (struct mailmime*, const char* name);
int                            mailmime_transfer_decode      (struct mailmime*, const char** ret_decoded_data, size_t* ret_decoded_data_bytes, char** ret_to_mmap_string_unref);
struct mailimf_fields*         mailmime_find_mailimf_fields  (struct mailmime*); /*the result is a pointer to mime, must not be freed*/
char*                          mailimf_find_first_addr       (const struct mailimf_mailbox_list*); /*the result must be freed*/
struct mailimf_field*          mailimf_find_field            (struct mailimf_fields*, int wanted_fld_type); /*the result is a pointer to mime, must not be freed*/
struct mailimf_optional_field* mailimf_find_optional_field   (struct mailimf_fields*, const char* wanted_fld_name);
mrhash_t*                      mailimf_get_recipients        (struct mailimf_fields*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRMIMEPARSER_H__ */

