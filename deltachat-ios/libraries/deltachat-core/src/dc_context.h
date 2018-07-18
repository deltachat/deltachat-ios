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

	dc_imap_t*       imap;                  /**< Internal IMAP object, never NULL */
	pthread_mutex_t  imapidle_condmutex;
	int              perform_imap_jobs_needed;

	dc_smtp_t*       smtp;                  /**< Internal SMTP object, never NULL */
	pthread_cond_t   smtpidle_cond;
	pthread_mutex_t  smtpidle_condmutex;
	int              smtpidle_condflag;
	int              smtpidle_suspend;
	int              smtpidle_in_idleing;
	#define          DC_JOBS_NEEDED_AT_ONCE   1
	#define          DC_JOBS_NEEDED_AVOID_DOS 2
	int              perform_smtp_jobs_needed;

	dc_callback_t    cb;                    /**< Internal */

	char*            os_name;               /**< Internal, may be NULL */

	uint32_t         cmdline_sel_chat_id;   /**< Internal */

	int              e2ee_enabled;          /**< Internal */

	#define          DC_LOG_RINGBUF_SIZE 200
	pthread_mutex_t  log_ringbuf_critical;  /**< Internal */
	char*            log_ringbuf[DC_LOG_RINGBUF_SIZE];
	                                          /**< Internal */
	time_t           log_ringbuf_times[DC_LOG_RINGBUF_SIZE];
	                                          /**< Internal */
	int              log_ringbuf_pos;       /**< Internal. The oldest position resp. the position that is overwritten next */

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

void            dc_log_error         (dc_context_t*, int code, const char* msg, ...);
void            dc_log_error_if      (int* condition, dc_context_t*, int code, const char* msg, ...);
void            dc_log_warning       (dc_context_t*, int code, const char* msg, ...);
void            dc_log_info          (dc_context_t*, int code, const char* msg, ...);
void            dc_receive_imf                             (dc_context_t*, const char* imf_raw_not_terminated, size_t imf_raw_bytes, const char* server_folder, uint32_t server_uid, uint32_t flags);

#define         DC_BAK_PREFIX                "delta-chat"
#define         DC_BAK_SUFFIX                "bak"


// attachments of 25 mb brutto should work on the majority of providers
// (brutto examples: web.de=50, 1&1=40, t-online.de=32, gmail=25, posteo=50, yahoo=25, all-inkl=100).
// as an upper limit, we double the size; the core won't send messages larger than this
// to get the netto sizes, we substract 1 mb header-overhead and the base64-overhead.
#define DC_MSGSIZE_MAX_RECOMMENDED  ((24*1024*1024)/4*3)
#define DC_MSGSIZE_UPPER_LIMIT      ((49*1024*1024)/4*3)


/* library private: end-to-end-encryption */
#define DC_E2EE_DEFAULT_ENABLED  1
#define DC_MDNS_DEFAULT_ENABLED  1

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
int             dc_alloc_ongoing     (dc_context_t*);
void            dc_free_ongoing      (dc_context_t*);

#define         dc_is_online(m)             ((m)->cb((m), DC_EVENT_IS_OFFLINE, 0, 0)==0)
#define         dc_is_offline(m)            ((m)->cb((m), DC_EVENT_IS_OFFLINE, 0, 0)!=0)


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
