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


#ifndef __MRMAILBOX_INTERNAL_H__
#define __MRMAILBOX_INTERNAL_H__
#ifdef __cplusplus
extern "C" {
#endif


/*** library-private **********************************************************/

#include "mrmailbox.h"
#include <stdlib.h>
#include <string.h>
#include "mrsqlite3.h"
#include "mrtools.h"

typedef struct mrjob_t mrjob_t;
typedef struct mrimap_t mrimap_t;
typedef struct mrsmtp_t mrsmtp_t;
typedef struct mrmimeparser_t mrmimeparser_t;
typedef struct mrsqlite3_t mrsqlite3_t;


/*******************************************************************************
 * Internal mailbox handling
 ******************************************************************************/


/* mrmailbox_t represents a single mailbox, normally, typically only one
instance of this class is present.
Each mailbox is linked to an IMAP/POP3 account and uses a separate
SQLite database for offline functionality and for mailbox-related
settings. */
typedef struct mrmailbox_t
{
	void*            m_userdata;

	mrsqlite3_t*     m_sql;      /* != NULL */
	char*            m_dbfile;
	char*            m_blobdir;

	mrimap_t*        m_imap;     /* != NULL */
	mrsmtp_t*        m_smtp;     /* != NULL */

	pthread_t        m_job_thread;
	pthread_cond_t   m_job_cond;
	pthread_mutex_t  m_job_condmutex;
	int              m_job_condflag;
	int              m_job_do_exit;

	mrmailboxcb_t    m_cb;

	char*            m_os_name;

	uint32_t         m_cmdline_sel_chat_id;

	int              m_wake_lock;
	pthread_mutex_t  m_wake_lock_critical;

	int              m_e2ee_enabled;

	#define          MR_LOG_RINGBUF_SIZE 200
	pthread_mutex_t  m_log_ringbuf_critical;
	char*            m_log_ringbuf[MR_LOG_RINGBUF_SIZE];
	time_t           m_log_ringbuf_times[MR_LOG_RINGBUF_SIZE];
	int              m_log_ringbuf_pos; /* the oldest position resp. the position that is overwritten next */

} mrmailbox_t;


#define MR_E2EE_DEFAULT_ENABLED  1
#define MR_MDNS_DEFAULT_ENABLED  1

void                 mrmailbox_connect_to_imap      (mrmailbox_t*, mrjob_t*);
void                 mrmailbox_wake_lock            (mrmailbox_t*);
void                 mrmailbox_wake_unlock          (mrmailbox_t*);


/* end-to-end-encryption */
typedef struct mrmailbox_e2ee_helper_t {
	int   m_encryption_successfull;
	void* m_cdata_to_free;
} mrmailbox_e2ee_helper_t;

void mrmailbox_e2ee_encrypt             (mrmailbox_t*, const clist* recipients_addr, int e2ee_guaranteed, int encrypt_to_self, struct mailmime* in_out_message, mrmailbox_e2ee_helper_t*);
int  mrmailbox_e2ee_decrypt             (mrmailbox_t*, struct mailmime* in_out_message, int* ret_validation_errors); /* returns 1 if sth. was decrypted, 0 in other cases */
void mrmailbox_e2ee_thanks              (mrmailbox_e2ee_helper_t*); /* frees data referenced by "mailmime" but not freed by mailmime_free(). After calling mre2ee_unhelp(), in_out_message cannot be used any longer! */
int  mrmailbox_ensure_secret_key_exists (mrmailbox_t*); /* makes sure, the private key exists, needed only for exporting keys and the case no message was sent before */


/* logging */
void mrmailbox_log_error           (mrmailbox_t*, int code, const char* msg, ...);
void mrmailbox_log_error_if        (int* condition, mrmailbox_t*, int code, const char* msg, ...);
void mrmailbox_log_warning         (mrmailbox_t*, int code, const char* msg, ...);
void mrmailbox_log_info            (mrmailbox_t*, int code, const char* msg, ...);
void mrmailbox_log_vprintf         (mrmailbox_t*, int event, int code, const char* msg, va_list);
int  mrmailbox_get_thread_index    (void);

/* reset tables but leaves server configuration, 1=jobs, 2=e2ee, 8=rest but server config */
int                  mrmailbox_reset_tables         (mrmailbox_t*, int bits);

/* misc. tools */
int    mrmailbox_poke_eml_file                           (mrmailbox_t*, const char* file);
int    mrmailbox_is_reply_to_known_message__             (mrmailbox_t*, mrmimeparser_t*);
int    mrmailbox_is_reply_to_messenger_message__         (mrmailbox_t*, mrmimeparser_t*);
time_t mrmailbox_correct_bad_timestamp__                 (mrmailbox_t* ths, uint32_t chat_id, uint32_t from_id, time_t desired_timestamp, int is_fresh_msg);
void   mrmailbox_add_or_lookup_contacts_by_mailbox_list__(mrmailbox_t* ths, struct mailimf_mailbox_list* mb_list, int origin, carray* ids, int* check_self);
void   mrmailbox_add_or_lookup_contacts_by_address_list__(mrmailbox_t* ths, struct mailimf_address_list* adr_list, int origin, carray* ids, int* check_self);
int    mrmailbox_get_archived_count__                    (mrmailbox_t*);

#define MR_CHAT_PREFIX      "Chat:"      /* you MUST NOT modify this or the following strings */
#define MR_CHATS_FOLDER     "Chats"      /* if we want to support Gma'l-labels - "Chats" is a reserved word for Gma'l */


/*******************************************************************************
 * Internal chatlist handling
 ******************************************************************************/


/* The chatlist object and some function for helping accessing it.
The chatlist object is not updated.  If you want an update, you have to recreate
the object. */
typedef struct mrchatlist_t
{
	size_t          m_cnt;
	carray*         m_chatNlastmsg_ids;
	mrmailbox_t*    m_mailbox;
} mrchatlist_t;


mrchatlist_t* mrchatlist_new                 (mrmailbox_t*);
void          mrchatlist_empty               (mrchatlist_t*);
int           mrchatlist_load_from_db__    (mrchatlist_t*, int listflags, const char* query);


/*******************************************************************************
 * Internal chat handling
 ******************************************************************************/


#define MR_MSG_NEEDS_ATTACHMENT(a)         ((a)==MR_MSG_IMAGE || (a)==MR_MSG_GIF || (a)==MR_MSG_AUDIO || (a)==MR_MSG_VOICE || (a)==MR_MSG_VIDEO || (a)==MR_MSG_FILE)
#define MR_MSG_MAKE_FILENAME_SEARCHABLE(a) ((a)==MR_MSG_AUDIO || (a)==MR_MSG_FILE || (a)==MR_MSG_VIDEO ) /* add filename.ext (without path) to m_text? this is needed for the fulltext search. The extension is useful to get all PDF, all MP3 etc. */
#define MR_MSG_MAKE_SUFFIX_SEARCHABLE(a)   ((a)==MR_MSG_IMAGE || (a)==MR_MSG_GIF || (a)==MR_MSG_VOICE)

mrchat_t*     mrchat_new                   (mrmailbox_t*); /* result must be unref'd */
void          mrchat_empty                 (mrchat_t*);
uint32_t      mrchat_send_msg__                      (mrchat_t*, const mrmsg_t*, time_t);
int           mrchat_load_from_db__                  (mrchat_t*, uint32_t id);
int           mrchat_update_param__                  (mrchat_t*);
void          mrmailbox_unarchive_chat__             (mrmailbox_t*, uint32_t chat_id);
size_t        mrmailbox_get_chat_cnt__               (mrmailbox_t*);
uint32_t      mrmailbox_create_or_lookup_nchat_by_contact_id__(mrmailbox_t*, uint32_t contact_id);
uint32_t      mrmailbox_lookup_real_nchat_by_contact_id__(mrmailbox_t*, uint32_t contact_id);
int           mrmailbox_get_total_msg_count__        (mrmailbox_t*, uint32_t chat_id);
int           mrmailbox_get_fresh_msg_count__        (mrmailbox_t*, uint32_t chat_id);
uint32_t      mrmailbox_get_last_deaddrop_fresh_msg__(mrmailbox_t*);
void          mrmailbox_send_msg_to_smtp             (mrmailbox_t*, mrjob_t*);
void          mrmailbox_send_msg_to_imap             (mrmailbox_t*, mrjob_t*);
int           mrmailbox_add_contact_to_chat__        (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int           mrmailbox_is_contact_in_chat__         (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int           mrmailbox_get_chat_contact_count__     (mrmailbox_t*, uint32_t chat_id);
int           mrmailbox_group_explicitly_left__      (mrmailbox_t*, const char* grpid);
void          mrmailbox_set_group_explicitly_left__  (mrmailbox_t*, const char* grpid);

#define APPROX_SUBJECT_CHARS 32  /* as we do not cut inside words, this results in about 32-42 characters.
								 Do not use too long subjects - we add a tag after the subject which gets truncated by the clients otherwise.
								 It should also be very clear, the subject is _not_ the whole message.
								 The value is also used for CC:-summaries */


/*******************************************************************************
 * Internal message handling
 ******************************************************************************/


#define      MR_MSG_FIELDS                    " m.id,rfc724_mid,m.server_folder,m.server_uid,m.chat_id, m.from_id,m.to_id,m.timestamp, m.type,m.state,m.msgrmsg,m.txt, m.param,m.starred "
int          mrmsg_set_from_stmt__            (mrmsg_t*, sqlite3_stmt* row, int row_offset); /* row order is MR_MSG_FIELDS */
int          mrmsg_load_from_db__             (mrmsg_t*, mrmailbox_t*, uint32_t id);
void         mr_guess_msgtype_from_suffix     (const char* pathNfilename, int* ret_msgtype, char** ret_mime);
size_t       mrmailbox_get_real_msg_cnt__     (mrmailbox_t*); /* the number of messages assigned to real chat (!=deaddrop, !=trash) */
size_t       mrmailbox_get_deaddrop_msg_cnt__ (mrmailbox_t*);
int          mrmailbox_rfc724_mid_cnt__       (mrmailbox_t*, const char* rfc724_mid);
int          mrmailbox_rfc724_mid_exists__    (mrmailbox_t*, const char* rfc724_mid, char** ret_server_folder, uint32_t* ret_server_uid);
void         mrmailbox_update_server_uid__    (mrmailbox_t*, const char* rfc724_mid, const char* server_folder, uint32_t server_uid);
void         mrmailbox_update_msg_chat_id__   (mrmailbox_t*, uint32_t msg_id, uint32_t chat_id);
void         mrmailbox_update_msg_state__     (mrmailbox_t*, uint32_t msg_id, int state);
void         mrmailbox_delete_msg_on_imap     (mrmailbox_t* mailbox, mrjob_t* job);
int          mrmailbox_mdn_from_ext__         (mrmailbox_t*, uint32_t from_id, const char* rfc724_mid, uint32_t* ret_chat_id, uint32_t* ret_msg_id); /* returns 1 if an event should be send */
void         mrmailbox_send_mdn               (mrmailbox_t*, mrjob_t* job);
void         mrmailbox_markseen_msg_on_imap   (mrmailbox_t* mailbox, mrjob_t* job);
void         mrmailbox_markseen_mdn_on_imap   (mrmailbox_t* mailbox, mrjob_t* job);
char*        mrmsg_get_summarytext_by_raw     (int type, const char* text, mrparam_t*, int approx_bytes); /* the returned value must be free()'d */
int          mrmsg_is_increation__            (const mrmsg_t*);
void         mrmsg_save_param_to_disk__       (mrmsg_t*);
void         mr_get_authorNtitle_from_filename(const char* pathNfilename, char** ret_author, char** ret_title);


/*******************************************************************************
 * Internal contact handling
 ******************************************************************************/


/* contact origins */
#define MR_ORIGIN_UNSET                         0
#define MR_ORIGIN_INCOMING_UNKNOWN_FROM      0x10 /* From: of incoming messages of unknown sender */
#define MR_ORIGIN_INCOMING_UNKNOWN_CC        0x20 /* Cc: of incoming messages of unknown sender */
#define MR_ORIGIN_INCOMING_UNKNOWN_TO        0x40 /* To: of incoming messages of unknown sender */
#define MR_ORIGIN_INCOMING_REPLY_TO         0x100 /* Reply-To: of incoming message of known sender */
#define MR_ORIGIN_INCOMING_CC               0x200 /* Cc: of incoming message of known sender */
#define MR_ORIGIN_INCOMING_TO               0x400 /* additional To:'s of incoming message of known sender */
#define MR_ORIGIN_CREATE_CHAT               0x800 /* a chat was manually created for this user, but no message yet sent */
#define MR_ORIGIN_OUTGOING_BCC             0x1000 /* message send by us */
#define MR_ORIGIN_OUTGOING_CC              0x2000 /* message send by us */
#define MR_ORIGIN_OUTGOING_TO              0x4000 /* message send by us */
#define MR_ORIGIN_INTERNAL                0x40000 /* internal use */
#define MR_ORIGIN_ADRESS_BOOK             0x80000 /* address is in our address book */
#define MR_ORIGIN_MANUALLY_CREATED       0x100000 /* contact added by mrmailbox_create_contact() */

#define MR_ORIGIN_MIN_CONTACT_LIST    (MR_ORIGIN_INCOMING_REPLY_TO) /* contacts with at least this origin value are shown in the contact list */
#define MR_ORIGIN_MIN_VERIFIED        (MR_ORIGIN_INCOMING_REPLY_TO) /* contacts with at least this origin value are verified and known not to be spam */
#define MR_ORIGIN_MIN_START_NEW_NCHAT (0x7FFFFFFF)                  /* contacts with at least this origin value start a new "normal" chat, defaults to off */

mrcontact_t* mrcontact_new                    (); /* the returned pointer is ref'd and must be unref'd after usage */
void         mrcontact_empty                  (mrcontact_t*);
int          mrcontact_load_from_db__         (mrcontact_t*, mrsqlite3_t*, uint32_t id);
size_t       mrmailbox_get_real_contact_cnt__ (mrmailbox_t*);
uint32_t     mrmailbox_add_or_lookup_contact__(mrmailbox_t*, const char* display_name /*can be NULL*/, const char* addr_spec, int origin, int* sth_modified);
int          mrmailbox_get_contact_origin__   (mrmailbox_t*, uint32_t id, int* ret_blocked);
int          mrmailbox_is_contact_blocked__   (mrmailbox_t*, uint32_t id);
int          mrmailbox_real_contact_exists__  (mrmailbox_t*, uint32_t id);
int          mrmailbox_contact_addr_equals__  (mrmailbox_t*, uint32_t contact_id, const char* other_addr);
void         mrmailbox_scaleup_contact_origin__(mrmailbox_t*, uint32_t contact_id, int origin);
void         mr_normalize_name                (char* full_name);
char*        mr_get_first_name                (const char* full_name); /* returns part before the space or after a comma; the result must be free()'d */


/*******************************************************************************
 * Internal poortext handling
 ******************************************************************************/


mrpoortext_t* mrpoortext_new       ();
void          mrpoortext_empty     (mrpoortext_t*);

#define MR_SUMMARY_CHARACTERS 160 /* in practice, the user additinally cuts the string himself pixel-accurate */
void mrpoortext_fill(mrpoortext_t*, const mrmsg_t*, const mrchat_t*, const mrcontact_t*);


/*******************************************************************************
 * Internal additional parameter handling
 ******************************************************************************/


/* The parameter object as used eg. by mrchat_t or mrmsg_t.
To access the single parameters use the setter and getter functions with an
MRP_* contant */
typedef struct mrparam_t
{
	char*           m_packed;    /* != NULL */
} mrparam_t;


mrparam_t*    mrparam_new          ();
void          mrparam_empty        (mrparam_t*);
void          mrparam_unref        (mrparam_t*);
void          mrparam_set_packed   (mrparam_t*, const char*); /* overwrites all existing parameters */


/*******************************************************************************
 * Internal stock string handling
 ******************************************************************************/


/* should be set up by mrmailbox_new() */
extern mrmailbox_t* s_localize_mb_obj;


/* Return the string with the given ID by calling MR_EVENT_GET_STRING.
The result must be free()'d! */
char* mrstock_str (int id);


/* Replaces the first `%1$s` in the given String-ID by the given value.
The result must be free()'d! */
char* mrstock_str_repl_string (int id, const char* value);
char* mrstock_str_repl_int    (int id, int value);


/* Replaces the first `%1$s` and `%2$s` in the given String-ID by the two given strings.
The result must be free()'d! */
char* mrstock_str_repl_string2 (int id, const char*, const char*);


/* Return a string with a correct plural form by callint MR_EVENT_GET_QUANTITY_STRING.
The result must be free()'d! */
char* mrstock_str_repl_pl (int id, int cnt);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRMAILBOX_INTERNAL_H__ */

