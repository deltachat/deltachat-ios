#ifndef __DC_KEY_H__
#define __DC_KEY_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct sqlite3_stmt sqlite3_stmt;


#define DC_KEY_PUBLIC  0
#define DC_KEY_PRIVATE 1


/**
 * Library-internal.
 */
typedef struct dc_key_t
{
	void*          binary;
	int            bytes;
	int            type;

	/** @privatesection */
	int            _m_heap_refcnt; /* !=0 for objects created with dc_key_new(), 0 for stack objects  */
} dc_key_t;


dc_key_t* dc_key_new                      ();
dc_key_t* dc_key_ref                      (dc_key_t*);
void      dc_key_unref                    (dc_key_t*);

int       dc_key_set_from_binary          (dc_key_t*, const void* data, int bytes, int type);
int       dc_key_set_from_key             (dc_key_t*, const dc_key_t*);
int       dc_key_set_from_stmt            (dc_key_t*, sqlite3_stmt*, int index, int type);
int       dc_key_set_from_base64          (dc_key_t*, const char* base64, int type);
int       dc_key_set_from_file            (dc_key_t*, const char* file, dc_context_t*);

int       dc_key_equals                   (const dc_key_t*, const dc_key_t*);

int       dc_key_save_self_keypair        (const dc_key_t* public_key, const dc_key_t* private_key, const char* addr, int is_default, dc_sqlite3_t* sql);
int       dc_key_load_self_public         (dc_key_t*, const char* self_addr, dc_sqlite3_t* sql);
int       dc_key_load_self_private        (dc_key_t*, const char* self_addr, dc_sqlite3_t* sql);

char*     dc_render_base64                (const void* buf, size_t buf_bytes, int break_every, const char* break_chars, int add_checksum); /* the result must be freed */
char*     dc_key_render_base64            (const dc_key_t*, int break_every, const char* break_chars, int add_checksum); /* the result must be freed */
char*     dc_key_render_asc               (const dc_key_t*, const char* add_header_lines); /* each header line must be terminated by \r\n, the result must be freed */
int       dc_key_render_asc_to_file       (const dc_key_t*, const char* file, dc_context_t*);

char*     dc_format_fingerprint           (const char*);
char*     dc_normalize_fingerprint        (const char*);
char*     dc_key_get_fingerprint          (const dc_key_t*);
char*     dc_key_get_formatted_fingerprint(const dc_key_t*);

void      dc_wipe_secret_mem              (void* buf, size_t buf_bytes);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_KEY_H__ */

