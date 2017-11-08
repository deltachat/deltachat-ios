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


/*** library-private **********************************************************/


typedef struct mrmimepart_t
{
	int                 m_type; /*one of MR_MSG_* */
	int                 m_is_meta; /*meta parts contain eg. profile or group images and are only present if there is at least one "normal" part*/
	char*               m_msg;
	char*               m_msg_raw;
	int                 m_bytes;
	mrparam_t*          m_param;
} mrmimepart_t;


typedef struct mrmimeparser_t
{
	/* data, read-only, must not be free()'d (it is free()'d when the MrMimeParser object gets destructed) */
	carray*                m_parts;    /*array of mrmimepart_t objects*/
	struct mailmime*       m_mimeroot;
	struct mailimf_fields* m_header;   /* a pointer somewhere to the MIME data, must not be freed */
	char*                  m_subject;
	int                    m_is_send_by_messenger;
	int                    m_decrypted_and_validated;
	int                    m_decrypted_with_validation_errors;
	int                    m_decrypting_failed; /* set, if there are multipart/encrypted parts left after decryption */
	const char*            m_blobdir;

	int                    m_is_forwarded;

	mrmailbox_t*           m_mailbox;

	carray*                m_reports; /* array of mailmime objects */

	int                    m_is_system_message;

} mrmimeparser_t;


mrmimeparser_t*       mrmimeparser_new            (const char* blobdir, mrmailbox_t*);
void                  mrmimeparser_unref          (mrmimeparser_t*);
void                  mrmimeparser_empty          (mrmimeparser_t*);

/* The data returned from Parse() must not be freed (it is free()'d when the MrMimeParser object gets destructed)
Unless memory-allocation-errors occur, Parse() returns at least one empty part.
(this is because we want to add even these message to our database to avoid reading them several times.
of course, these empty messages are not added to any chat) */
void                  mrmimeparser_parse          (mrmimeparser_t*, const char* body_not_terminated, size_t body_bytes);

/* mrmimeparser_get_last_nonmeta() gets the _last_ part _not_ flagged with m_is_meta. */
mrmimepart_t*   mrmimeparser_get_last_nonmeta  (mrmimeparser_t*);
#define         mrmimeparser_has_nonmeta(a)    (mrmimeparser_get_last_nonmeta((a))!=NULL)

/* mrmimeparser_is_mailinglist_message() just checks if there is a `List-ID`-header. */
int                   mrmimeparser_is_mailinglist_message (mrmimeparser_t*);

/* low-level-tools for working with mailmime structures directly */
char*                          mr_find_first_addr    (const struct mailimf_mailbox_list*); /*the result must be freed*/
char*                          mr_normalize_addr     (const char*); /*the result must be freed*/
struct mailimf_fields*         mr_find_mailimf_fields(struct mailmime*); /*the result is a pointer to mime, must not be freed*/
struct mailimf_field*          mr_find_mailimf_field (struct mailimf_fields*, int wanted_fld_type); /*the result is a pointer to mime, must not be freed*/
struct mailimf_optional_field* mr_find_mailimf_field2(struct mailimf_fields*, const char* wanted_fld_name);
struct mailmime_parameter*     mr_find_ct_parameter  (struct mailmime*, const char* name);
int                            mr_mime_transfer_decode(struct mailmime*, const char** ret_decoded_data, size_t* ret_decoded_data_bytes, char** ret_to_mmap_string_unref);


#ifdef MR_USE_MIME_DEBUG
void mr_print_mime(struct mailmime * mime);
#endif


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRMIMEPARSER_H__ */

