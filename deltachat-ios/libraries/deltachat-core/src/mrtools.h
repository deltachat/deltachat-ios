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


/* Some tools and enhancements to the used libraries, there should be
no references to mrmailbox_t and other "larger" classes here. */


#ifndef __MRTOOLS_H__
#define __MRTOOLS_H__
#ifdef __cplusplus
extern "C" {
#endif


/*** library-private **********************************************************/

/* match tools */
int     mr_exactly_one_bit_set     (int v);

/* string tools */
char*   safe_strdup                (const char*); /* safe_strdup() returns empty string if NULL is given, never returns NULL (exists on errors) */
char*   strdup_keep_null           (const char*); /* strdup(NULL) is undefined, safe_strdup_keep_null(NULL) returns NULL in this case */
int     atoi_null_is_0             (const char*);
void    mr_ltrim                   (char*);
void    mr_rtrim                   (char*);
void    mr_trim                    (char*);
char*   mr_strlower                (const char*); /* the result must be free()'d */
void    mr_strlower_in_place       (char*);
int     mr_str_replace             (char** haystack, const char* needle, const char* replacement); /* haystack may be realloc()'d, returns the number of replacements */
char*   mr_null_terminate          (const char*, int bytes); /* the result must be free()'d */
char*   mr_mprintf                 (const char* format, ...); /* The result must be free()'d. */
void    mr_remove_cr_chars         (char*); /* remove all \r characters from string */
void    mr_replace_bad_utf8_chars  (char*); /* replace bad UTF-8 characters by sequences of `_` (to avoid problems in filenames, we do not use eg. `?`) the function is useful if strings are unexpectingly encoded eg. as ISO-8859-1 */
void    mr_truncate_n_unwrap_str   (char*, int approx_characters, int do_unwrap);
carray* mr_split_into_lines        (const char* buf_terminated); /* split string into lines*/
void    mr_free_splitted_lines     (carray* lines);
char*   mr_insert_breaks           (const char*, int break_every, const char* break_chars); /* insert a break every n characters, the return must be free()'d */
char*   mr_arr_to_string           (const uint32_t*, int cnt);
char*   mr_decode_header_string    (const char*); /* the result must be free()'d */
char*   mr_encode_header_string    (const char*); /* the result must be free()'d */
char*   imap_modified_utf7_to_utf8 (const char *mbox, int change_spaces);
char*   imap_utf8_to_modified_utf7 (const char *src, int change_spaces);
char*   mr_url_encode              (const char*); /* the result must be free()'d */
char*   encode_base64              (const char * in, int len); /* prototype, from libetpan/src/data-types/base64.h which cannot be included without adding libetpan/src/... to the include-search-paths, which would result in double-file-name-errors */

/* string builder */
typedef struct mrstrbuilder_t
{
	char* m_buf;
	int   m_allocated;
	int   m_free;
	char* m_eos;
} mrstrbuilder_t;
void  mrstrbuilder_init (mrstrbuilder_t* ths);
char* mrstrbuilder_cat  (mrstrbuilder_t* ths, const char* text);
void  mrstrbuilder_empty(mrstrbuilder_t* ths); /* set the string to a lenght of 0, does not free the buffer */


/* carray/clist tools */
int     carray_search              (carray*, void* needle, unsigned int* indx); /* returns 1/0 and the index if `indx` is not NULL */
void    clist_free_content         (const clist*); /* calls free() for each item content */
int     clist_search_string_nocase (const clist*, const char* str);

/* date/time tools */
#define                    MR_INVALID_TIMESTAMP               (-1)
time_t                     mr_timestamp_from_date             (struct mailimf_date_time * date_time); /* the result is UTC or MR_INVALID_TIMESTAMP */
char*                      mr_timestamp_to_str                (time_t); /* the return value must be free()'d */
struct mailimap_date_time* mr_timestamp_to_mailimap_date_time (time_t);
long                       mr_gm2local_offset                 (void);

/* timesmearing */
time_t mr_smeared_time__             (void);
time_t mr_create_smeared_timestamp__ (void);
time_t mr_create_smeared_timestamps__(int count);

/* Message-ID tools */
#define MR_VALID_ID_LEN 11
char* mr_create_id                         (void);
char* mr_create_dummy_references_mid       (void);
char* mr_create_incoming_rfc724_mid        (time_t message_timestamp, uint32_t contact_id_from, carray* contact_ids_to);
char* mr_create_outgoing_rfc724_mid        (const char* grpid, const char* addr);
char* mr_extract_grpid_from_rfc724_mid     (const char* rfc724_mid);
char* mr_extract_grpid_from_rfc724_mid_list(const clist* rfc724_mid_list);


/* file tools */
int     mr_file_exist              (const char* pathNfilename);
size_t  mr_get_filebytes           (const char* pathNfilename);
char*   mr_get_filename            (const char* pathNfilename); /* the return value must be free()'d */
int     mr_delete_file             (const char* pathNFilename, mrmailbox_t* log);
int     mr_copy_file               (const char* src_pathNFilename, const char* dest_pathNFilename, mrmailbox_t* log);
int     mr_create_folder           (const char* pathNfilename, mrmailbox_t* log);
int     mr_write_file              (const char* pathNfilename, const void* buf, size_t buf_bytes, mrmailbox_t* log);
int     mr_read_file               (const char* pathNfilename, void** buf, size_t* buf_bytes, mrmailbox_t* log);
char*   mr_get_filesuffix_lc       (const char* pathNfilename); /* the returned suffix is lower-case */
void    mr_split_filename          (const char* pathNfilename, char** ret_basename, char** ret_all_suffixes_incl_dot); /* the case of the suffix is preserved! */
int     mr_get_filemeta            (const void* buf, size_t buf_bytes, uint32_t* ret_width, uint32_t *ret_height);
char*   mr_get_fine_pathNfilename  (const char* folder, const char* desired_name);

/* macros */
#define MR_QUOTEHELPER(name) #name
#define MR_STRINGIFY(macro) MR_QUOTEHELPER(macro)
#define MR_MIN(X, Y) (((X) < (Y))? (X) : (Y))
#define MR_MAX(X, Y) (((X) > (Y))? (X) : (Y))


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRTOOLS_H__ */
