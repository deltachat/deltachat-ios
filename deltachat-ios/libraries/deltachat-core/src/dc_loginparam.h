#ifndef __DC_LOGINPARAM_H__
#define __DC_LOGINPARAM_H__
#ifdef __cplusplus
extern "C" {
#endif


/**
 * Library-internal.
 */
typedef struct dc_loginparam_t
{
	/**  @privatesection */

	/* IMAP - all pointers may be NULL if unset, public read */
	char*         addr;
	char*         mail_server;
	char*         mail_user;
	char*         mail_pw;
	uint16_t      mail_port;

	/* SMTP - all pointers may be NULL if unset, public read */
	char*         send_server;
	char*         send_user;
	char*         send_pw;
	int           send_port;

	/* Server options as DC_LP_* flags */
	int           server_flags;
} dc_loginparam_t;


dc_loginparam_t* dc_loginparam_new          ();
void             dc_loginparam_unref        (dc_loginparam_t*);
void             dc_loginparam_empty        (dc_loginparam_t*); /* clears all data and frees its memory. All pointers are NULL after this function is called. */
void             dc_loginparam_read         (dc_loginparam_t*, dc_sqlite3_t*, const char* prefix);
void             dc_loginparam_write        (const dc_loginparam_t*, dc_sqlite3_t*, const char* prefix);
char*            dc_loginparam_get_readable (const dc_loginparam_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_LOGINPARAM_H__ */

