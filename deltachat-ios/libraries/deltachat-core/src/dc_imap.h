/* Purpose: Reading from IMAP servers with no dependencies to the database.
dc_context_t is only used for logging and to get information about
the online state. */


#ifndef __DC_IMAP_H__
#define __DC_IMAP_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct dc_loginparam_t dc_loginparam_t;
typedef struct dc_imap_t dc_imap_t;


typedef char*    (*dc_get_config_t)    (dc_imap_t*, const char*, const char*);
typedef void     (*dc_set_config_t)    (dc_imap_t*, const char*, const char*);

typedef int      (*dc_precheck_imf_t)  (dc_imap_t*, const char* rfc724_mid,
                                        const char* server_folder,
                                        uint32_t server_uid);

#define DC_IMAP_SEEN 0x0001L
typedef void     (*dc_receive_imf_t)   (dc_imap_t*, const char* imf_raw_not_terminated, size_t imf_raw_bytes, const char* server_folder, uint32_t server_uid, uint32_t flags);


/**
 * Library-internal.
 */
typedef struct dc_imap_t
{
	/** @privatesection */

	char*                 imap_server;
	int                   imap_port;
	char*                 imap_user;
	char*                 imap_pw;
	int                   server_flags;

	int                   connected;
	mailimap*             etpan;   /* normally, if connected, etpan is also set; however, if a reconnection is required, we may lost this handle */

	int                   idle_set_up;
	char*                 selected_folder;
	int                   selected_folder_needs_expunge;
	int                   should_reconnect;

	int                   can_idle;
	int                   has_xlist;
	char                  imap_delimiter;/* IMAP Path separator. Set as a side-effect during configure() */

	char*                 watch_folder;
	pthread_cond_t        watch_cond;
	pthread_mutex_t       watch_condmutex;
	int                   watch_condflag;

	struct mailimap_fetch_type* fetch_type_prefetch;
	struct mailimap_fetch_type* fetch_type_body;
	struct mailimap_fetch_type* fetch_type_flags;

	dc_get_config_t       get_config;
	dc_set_config_t       set_config;
	dc_precheck_imf_t     precheck_imf;
	dc_receive_imf_t      receive_imf;
	void*                 userData;
	dc_context_t*         context;

	int                   log_connect_errors;
	int                   skip_log_capabilities;

} dc_imap_t;


typedef enum {
	 DC_FAILED       = 0
	,DC_RETRY_LATER  = 1
	,DC_ALREADY_DONE = 2
	,DC_SUCCESS      = 3
} dc_imap_res;


dc_imap_t* dc_imap_new               (dc_get_config_t, dc_set_config_t,
                                      dc_precheck_imf_t, dc_receive_imf_t,
                                      void* userData, dc_context_t*);
void       dc_imap_unref             (dc_imap_t*);

int        dc_imap_connect           (dc_imap_t*, const dc_loginparam_t*);
void       dc_imap_set_watch_folder  (dc_imap_t*, const char* watch_folder);
void       dc_imap_disconnect        (dc_imap_t*);
int        dc_imap_is_connected      (const dc_imap_t*);
int        dc_imap_fetch             (dc_imap_t*);

void       dc_imap_idle              (dc_imap_t*);
void       dc_imap_interrupt_idle    (dc_imap_t*);

dc_imap_res dc_imap_move         (dc_imap_t*, const char* folder, uint32_t uid,
                                  const char* dest_folder, uint32_t* dest_uid);
dc_imap_res dc_imap_set_seen     (dc_imap_t*, const char* folder, uint32_t uid);
dc_imap_res dc_imap_set_mdnsent  (dc_imap_t*, const char* folder, uint32_t uid);

int        dc_imap_delete_msg        (dc_imap_t*, const char* rfc724_mid, const char* folder, uint32_t server_uid); /* only returns 0 on connection problems; we should try later again in this case */

int        dc_imap_is_error          (dc_imap_t* imap, int code);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif // __DC_IMAP_H__

