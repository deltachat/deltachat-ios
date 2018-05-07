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


#ifndef __MRMAILBOX_PRIVATE_H__
#define __MRMAILBOX_PRIVATE_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct mrimap_t       mrimap_t;
typedef struct mrsmtp_t       mrsmtp_t;
typedef struct mrsqlite3_t    mrsqlite3_t;
typedef struct mrjob_t        mrjob_t;
typedef struct mrmimeparser_t mrmimeparser_t;
typedef struct mrhash_t       mrhash_t;


/** Structure behind mrmailbox_t */
struct _mrmailbox
{
	/** @privatesection */
	#define          MR_MAILBOX_MAGIC         0x11a11807
	uint32_t         m_magic;                 /**< @private */

	void*            m_userdata;              /**< Use data, may be used for any purpose. The same pointer as given to mrmailbox_new(), may be used by the caller for any purpose. */

	char*            m_dbfile;                /**< The database file. This is the file given to mrmailbox_new(). */
	char*            m_blobdir;               /**< Full path of the blob directory. This is the directory given to mrmailbox_new() or a directory in the same directory as mrmailbox_t::m_dbfile. */

	mrsqlite3_t*     m_sql;                   /**< Internal SQL object, never NULL */
	mrimap_t*        m_imap;                  /**< Internal IMAP object, never NULL */
	mrsmtp_t*        m_smtp;                  /**< Internal SMTP object, never NULL */

	pthread_t        m_job_thread;            /**< Internal */
	pthread_cond_t   m_job_cond;              /**< Internal */
	pthread_mutex_t  m_job_condmutex;         /**< Internal */
	int              m_job_condflag;          /**< Internal */
	int              m_job_do_exit;           /**< Internal */

	mrmailboxcb_t    m_cb;                    /**< Internal */

	char*            m_os_name;               /**< Internal, may be NULL */

	uint32_t         m_cmdline_sel_chat_id;   /**< Internal */

	int              m_wake_lock;             /**< Internal */
	pthread_mutex_t  m_wake_lock_critical;    /**< Internal */

	int              m_e2ee_enabled;          /**< Internal */

	#define          MR_LOG_RINGBUF_SIZE 200
	pthread_mutex_t  m_log_ringbuf_critical;  /**< Internal */
	char*            m_log_ringbuf[MR_LOG_RINGBUF_SIZE];
	                                          /**< Internal */
	time_t           m_log_ringbuf_times[MR_LOG_RINGBUF_SIZE];
	                                          /**< Internal */
	int              m_log_ringbuf_pos;       /**< Internal. The oldest position resp. the position that is overwritten next */

};


/* logging and error handling */
void            mrmailbox_log_error         (mrmailbox_t*, int code, const char* msg, ...);
void            mrmailbox_log_error_if      (int* condition, mrmailbox_t*, int code, const char* msg, ...);
void            mrmailbox_log_warning       (mrmailbox_t*, int code, const char* msg, ...);
void            mrmailbox_log_info          (mrmailbox_t*, int code, const char* msg, ...);


/* misc.*/
void            mrmailbox_receive_imf                             (mrmailbox_t*, const char* imf_raw_not_terminated, size_t imf_raw_bytes, const char* server_folder, uint32_t server_uid, uint32_t flags);
uint32_t        mrmailbox_send_msg_object                         (mrmailbox_t*, uint32_t chat_id, mrmsg_t*);
void            mrmailbox_connect_to_imap                         (mrmailbox_t*, mrjob_t*);
void            mrmailbox_wake_lock                               (mrmailbox_t*);
void            mrmailbox_wake_unlock                             (mrmailbox_t*);
int             mrmailbox_get_archived_count__                    (mrmailbox_t*);
size_t          mrmailbox_get_real_contact_cnt__                  (mrmailbox_t*);
uint32_t        mrmailbox_add_or_lookup_contact__                 (mrmailbox_t*, const char* display_name /*can be NULL*/, const char* addr_spec, int origin, int* sth_modified);
int             mrmailbox_get_contact_origin__                    (mrmailbox_t*, uint32_t id, int* ret_blocked);
int             mrmailbox_is_contact_blocked__                    (mrmailbox_t*, uint32_t id);
int             mrmailbox_real_contact_exists__                   (mrmailbox_t*, uint32_t id);
int             mrmailbox_contact_addr_equals__                   (mrmailbox_t*, uint32_t contact_id, const char* other_addr);
void            mrmailbox_scaleup_contact_origin__                (mrmailbox_t*, uint32_t contact_id, int origin);
void            mrmailbox_unarchive_chat__                        (mrmailbox_t*, uint32_t chat_id);
size_t          mrmailbox_get_chat_cnt__                          (mrmailbox_t*);
void            mrmailbox_block_chat__                            (mrmailbox_t*, uint32_t chat_id, int new_blocking);
void            mrmailbox_unblock_chat__                          (mrmailbox_t*, uint32_t chat_id);
void            mrmailbox_create_or_lookup_nchat_by_contact_id__  (mrmailbox_t*, uint32_t contact_id, int create_blocked, uint32_t* ret_chat_id, int* ret_chat_blocked);
void            mrmailbox_lookup_real_nchat_by_contact_id__       (mrmailbox_t*, uint32_t contact_id, uint32_t* ret_chat_id, int* ret_chat_blocked);
int             mrmailbox_get_total_msg_count__                   (mrmailbox_t*, uint32_t chat_id);
int             mrmailbox_get_fresh_msg_count__                   (mrmailbox_t*, uint32_t chat_id);
uint32_t        mrmailbox_get_last_deaddrop_fresh_msg__           (mrmailbox_t*);
void            mrmailbox_send_msg_to_smtp                        (mrmailbox_t*, mrjob_t*);
void            mrmailbox_send_msg_to_imap                        (mrmailbox_t*, mrjob_t*);
int             mrmailbox_add_to_chat_contacts_table__            (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int             mrmailbox_is_contact_in_chat__                    (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int             mrmailbox_get_chat_contact_count__                (mrmailbox_t*, uint32_t chat_id);
int             mrmailbox_is_group_explicitly_left__              (mrmailbox_t*, const char* grpid);
void            mrmailbox_set_group_explicitly_left__             (mrmailbox_t*, const char* grpid);
size_t          mrmailbox_get_real_msg_cnt__                      (mrmailbox_t*); /* the number of messages assigned to real chat (!=deaddrop, !=trash) */
size_t          mrmailbox_get_deaddrop_msg_cnt__                  (mrmailbox_t*);
int             mrmailbox_rfc724_mid_cnt__                        (mrmailbox_t*, const char* rfc724_mid);
uint32_t        mrmailbox_rfc724_mid_exists__                     (mrmailbox_t*, const char* rfc724_mid, char** ret_server_folder, uint32_t* ret_server_uid);
void            mrmailbox_update_server_uid__                     (mrmailbox_t*, const char* rfc724_mid, const char* server_folder, uint32_t server_uid);
void            mrmailbox_update_msg_chat_id__                    (mrmailbox_t*, uint32_t msg_id, uint32_t chat_id);
void            mrmailbox_update_msg_state__                      (mrmailbox_t*, uint32_t msg_id, int state);
void            mrmailbox_delete_msg_on_imap                      (mrmailbox_t* mailbox, mrjob_t* job);
int             mrmailbox_mdn_from_ext__                          (mrmailbox_t*, uint32_t from_id, const char* rfc724_mid, time_t, uint32_t* ret_chat_id, uint32_t* ret_msg_id); /* returns 1 if an event should be send */
void            mrmailbox_send_mdn                                (mrmailbox_t*, mrjob_t* job);
void            mrmailbox_markseen_msg_on_imap                    (mrmailbox_t* mailbox, mrjob_t* job);
void            mrmailbox_markseen_mdn_on_imap                    (mrmailbox_t* mailbox, mrjob_t* job);
int             mrmailbox_get_thread_index                        (void);
uint32_t        mrmailbox_add_device_msg                          (mrmailbox_t*, uint32_t chat_id, const char* text);
uint32_t        mrmailbox_add_device_msg__                        (mrmailbox_t*, uint32_t chat_id, const char* text, time_t timestamp);
int             mrmailbox_add_contact_to_chat4                    (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id, int from_handshake);
uint32_t        mrmailbox_get_chat_id_by_grpid__                  (mrmailbox_t*, const char* grpid, int* ret_blocked, int* ret_verified);


/* library private: end-to-end-encryption */
#define MR_E2EE_DEFAULT_ENABLED  1
#define MR_MDNS_DEFAULT_ENABLED  1

typedef struct mrmailbox_e2ee_helper_t {
	// encryption
	int   m_encryption_successfull;
	void* m_cdata_to_free;

	// decryption
	int       m_encrypted;  // encrypted without problems
	mrhash_t* m_signatures; // fingerprints of valid signatures
	mrhash_t* m_gossipped_addr;

} mrmailbox_e2ee_helper_t;

void            mrmailbox_e2ee_encrypt      (mrmailbox_t*, const clist* recipients_addr, int force_plaintext, int e2ee_guaranteed, int min_verified, struct mailmime* in_out_message, mrmailbox_e2ee_helper_t*);
void            mrmailbox_e2ee_decrypt      (mrmailbox_t*, struct mailmime* in_out_message, mrmailbox_e2ee_helper_t*); /* returns 1 if sth. was decrypted, 0 in other cases */
void            mrmailbox_e2ee_thanks       (mrmailbox_e2ee_helper_t*); /* frees data referenced by "mailmime" but not freed by mailmime_free(). After calling mre2ee_unhelp(), in_out_message cannot be used any longer! */
int             mrmailbox_ensure_secret_key_exists (mrmailbox_t*); /* makes sure, the private key exists, needed only for exporting keys and the case no message was sent before */
char*           mrmailbox_create_setup_code (mrmailbox_t*);
char*           mrmailbox_normalize_setup_code(mrmailbox_t*, const char* passphrase);
char*           mrmailbox_render_setup_file (mrmailbox_t*, const char* passphrase);
char*           mrmailbox_decrypt_setup_file(mrmailbox_t*, const char* passphrase, const char* filecontent);

extern int      mr_shall_stop_ongoing;
int             mrmailbox_alloc_ongoing     (mrmailbox_t*);
void            mrmailbox_free_ongoing      (mrmailbox_t*);


/* library private: secure-join */
#define         MR_IS_HANDSHAKE_CONTINUE_NORMAL_PROCESSING 1
#define         MR_IS_HANDSHAKE_STOP_NORMAL_PROCESSING     2
int             mrmailbox_handle_securejoin_handshake(mrmailbox_t*, mrmimeparser_t*, uint32_t contact_id);
void            mrmailbox_handle_degrade_event       (mrmailbox_t*, mrapeerstate_t*);


#define OPENPGP4FPR_SCHEME "OPENPGP4FPR:" /* yes: uppercase */


/* library private: key-history */
void            mrmailbox_add_to_keyhistory__(mrmailbox_t*, const char* rfc724_mid, time_t, const char* addr, const char* fingerprint);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRMAILBOX_PRIVATE_H__ */
