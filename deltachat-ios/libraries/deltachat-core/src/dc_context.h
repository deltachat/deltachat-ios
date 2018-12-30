#ifndef __DC_CONTEXT_H__
#define __DC_CONTEXT_H__
#ifdef __cplusplus
extern "C" {
#endif


/* Includes that are used frequently.  This file may also be used to create predefined headers. */
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <libetpan/libetpan.h>
#include "deltachat.h"
#include "dc_sqlite3.h"
#include "dc_tools.h"
#include "dc_strbuilder.h"
#include "dc_strencode.h"
#include "dc_param.h"
#include "dc_stock.h"
#include "dc_array.h"
#include "dc_chat.h"
#include "dc_chatlist.h"
#include "dc_lot.h"
#include "dc_msg.h"
#include "dc_contact.h"
#include "dc_jobthread.h"


typedef struct dc_imap_t       dc_imap_t;
typedef struct dc_smtp_t       dc_smtp_t;
typedef struct dc_sqlite3_t    dc_sqlite3_t;
typedef struct dc_job_t        dc_job_t;
typedef struct dc_mimeparser_t dc_mimeparser_t;
typedef struct dc_hash_t       dc_hash_t;


/** Structure behind dc_context_t */
struct _dc_context
{
	/** @privatesection */
	#define          DC_CONTEXT_MAGIC         0x11a11807
	uint32_t         magic;                 /**< @private */

	void*            userdata;              /**< Use data, may be used for any purpose. The same pointer as given to dc_context_new(), may be used by the caller for any purpose. */

	char*            dbfile;                /**< The database file. This is the file given to dc_context_new(). */
	char*            blobdir;               /**< Full path of the blob directory. This is the directory given to dc_context_new() or a directory in the same directory as dc_context_t::dbfile. */

	dc_sqlite3_t*    sql;                   /**< Internal SQL object, never NULL */

	dc_imap_t*       inbox;                 /**< primary IMAP object watching the inbox, never NULL */
	pthread_mutex_t  inboxidle_condmutex;
	int              perform_inbox_jobs_needed;
	int              probe_imap_network;    /**< if this flag is set, the imap-job timeouts are bypassed and messages are sent until they fail */

	dc_jobthread_t   sentbox_thread;
	dc_jobthread_t   mvbox_thread;

	dc_smtp_t*       smtp;                  /**< Internal SMTP object, never NULL */
	pthread_cond_t   smtpidle_cond;
	pthread_mutex_t  smtpidle_condmutex;
	int              smtpidle_condflag;
	int              smtp_suspended;
	int              smtp_doing_jobs;
	#define          DC_JOBS_NEEDED_AT_ONCE   1
	#define          DC_JOBS_NEEDED_AVOID_DOS 2
	int              perform_smtp_jobs_needed;
	int              probe_smtp_network;   /**< if this flag is set, the smtp-job timeouts are bypassed and messages are sent until they fail */

	dc_callback_t    cb;                    /**< Internal */

	char*            os_name;               /**< Internal, may be NULL */

	uint32_t         cmdline_sel_chat_id;   /**< Internal */

	// QR code scanning (view from Bob, the joiner)
	#define          DC_VC_AUTH_REQUIRED     2
	#define          DC_VC_CONTACT_CONFIRM   6
	int              bob_expects;
	#define          DC_BOB_ERROR       0
	#define          DC_BOB_SUCCESS     1
	int              bobs_status;
	dc_lot_t*        bobs_qr_scan;
	pthread_mutex_t  bobs_qr_critical;

	// time smearing - to keep messages in order, we may modify the time by some seconds
	time_t           last_smeared_timestamp;
	pthread_mutex_t  smear_critical;

	// handling ongoing processes initiated by the user
	int              ongoing_running;
	int              shall_stop_ongoing;
};

void            dc_log_event         (dc_context_t*, int event_code, int data1, const char* msg, ...);
void            dc_log_event_seq     (dc_context_t*, int event_code, int* sequence_start, const char* msg, ...);
void            dc_log_error         (dc_context_t*, int data1, const char* msg, ...);
void            dc_log_warning       (dc_context_t*, int data1, const char* msg, ...);
void            dc_log_info          (dc_context_t*, int data1, const char* msg, ...);

void            dc_receive_imf       (dc_context_t*, const char* imf_raw_not_terminated, size_t imf_raw_bytes, const char* server_folder, uint32_t server_uid, uint32_t flags);

#define         DC_NOT_CONNECTED     0
#define         DC_ALREADY_CONNECTED 1
#define         DC_JUST_CONNECTED    2
int             dc_connect_to_configured_imap (dc_context_t*, dc_imap_t*);

#define         DC_CREATE_MVBOX      0x01
#define         DC_FOLDERS_CONFIGURED_VERSION 3
void            dc_configure_folders (dc_context_t*, dc_imap_t*, int flags);


void            dc_do_heuristics_moves(dc_context_t*, const char* folder, uint32_t msg_id);


int             dc_is_inbox          (dc_context_t*, const char* folder);
int             dc_is_sentbox        (dc_context_t*, const char* folder);
int             dc_is_mvbox          (dc_context_t*, const char* folder);

#define         DC_BAK_PREFIX                "delta-chat"
#define         DC_BAK_SUFFIX                "bak"


// attachments of 25 mb brutto should work on the majority of providers
// (brutto examples: web.de=50, 1&1=40, t-online.de=32, gmail=25, posteo=50, yahoo=25, all-inkl=100).
// as an upper limit, we double the size; the core won't send messages larger than this
// to get the netto sizes, we substract 1 mb header-overhead and the base64-overhead.
#define DC_MSGSIZE_MAX_RECOMMENDED  ((24*1024*1024)/4*3)
#define DC_MSGSIZE_UPPER_LIMIT      ((49*1024*1024)/4*3)


// some defaults
#define DC_E2EE_DEFAULT_ENABLED   1
#define DC_MDNS_DEFAULT_ENABLED   1
#define DC_INBOX_WATCH_DEFAULT    1
#define DC_SENTBOX_WATCH_DEFAULT  0
#define DC_MVBOX_WATCH_DEFAULT    0
#define DC_MVBOX_MOVE_DEFAULT     0


/* library private: end-to-end-encryption */
typedef struct dc_e2ee_helper_t {
	// encryption
	int        encryption_successfull;
	void*      cdata_to_free;

	// decryption
	int        encrypted;  // encrypted without problems
	dc_hash_t* signatures; // fingerprints of valid signatures
	dc_hash_t* gossipped_addr;

} dc_e2ee_helper_t;

void            dc_e2ee_encrypt      (dc_context_t*, const clist* recipients_addr, int force_plaintext, int e2ee_guaranteed, int min_verified, struct mailmime* in_out_message, dc_e2ee_helper_t*);
void            dc_e2ee_decrypt      (dc_context_t*, struct mailmime* in_out_message, dc_e2ee_helper_t*); /* returns 1 if sth. was decrypted, 0 in other cases */
void            dc_e2ee_thanks       (dc_e2ee_helper_t*); /* frees data referenced by "mailmime" but not freed by mailmime_free(). After calling this function, in_out_message cannot be used any longer! */
int             dc_ensure_secret_key_exists (dc_context_t*); /* makes sure, the private key exists, needed only for exporting keys and the case no message was sent before */
char*           dc_create_setup_code (dc_context_t*);
char*           dc_normalize_setup_code(dc_context_t*, const char* passphrase);
char*           dc_render_setup_file (dc_context_t*, const char* passphrase);
char*           dc_decrypt_setup_file(dc_context_t*, const char* passphrase, const char* filecontent);

extern int      dc_shall_stop_ongoing;
int             dc_has_ongoing       (dc_context_t*);
int             dc_alloc_ongoing     (dc_context_t*);
void            dc_free_ongoing      (dc_context_t*);

/* library private: secure-join */
#define         DC_HANDSHAKE_CONTINUE_NORMAL_PROCESSING 0x01
#define         DC_HANDSHAKE_STOP_NORMAL_PROCESSING     0x02
#define         DC_HANDSHAKE_ADD_DELETE_JOB             0x04
int             dc_handle_securejoin_handshake(dc_context_t*, dc_mimeparser_t*, uint32_t contact_id);
void            dc_handle_degrade_event       (dc_context_t*, dc_apeerstate_t*);


#define DC_OPENPGP4FPR_SCHEME "OPENPGP4FPR:" /* yes: uppercase */


/* library private: key-history */
void            dc_add_to_keyhistory(dc_context_t*, const char* rfc724_mid, time_t, const char* addr, const char* fingerprint);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_CONTEXT_H__ */
