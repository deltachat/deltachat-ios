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
 *******************************************************************************
 *
 * File:    mrmailbox.h
 * Purpose: mrmailbox_t represents a single mailbox, normally, typically only
 *          one instance of this class is present.
 *          Each mailbox is linked to an IMAP/POP3 account and uses a separate
 *          SQLite database for offline functionality and for mailbox-related
 *          settings.
 *
 *******************************************************************************
 *
 * NB: Objects returned by mrmailbox_t (or other classes) typically reflect
 * the state of the system when the objects are _created_ - treat them as if
 * they're strings. Eg. mrmsg_get_state() does _always_ return the state of the
 * time the objects is created.
 * If you want an _updated state_, you have to recreate the object reflecting
 * the message - or use methods that explicitly force reloading.
 *
 ******************************************************************************/


#ifndef __MRMAILBOX_H__
#define __MRMAILBOX_H__
#ifdef __cplusplus
extern "C" {
#endif


#include <libetpan/libetpan.h> /* defines uint16_t etc. */
#include "mrsqlite3.h"
#include "mrchat.h"
#include "mrchatlist.h"
#include "mrmsg.h"
#include "mrcontact.h"
#include "mrpoortext.h"
#include "mrstock.h"
typedef struct mrmailbox_t mrmailbox_t;
typedef struct mrimap_t mrimap_t;
typedef struct mrsmtp_t mrsmtp_t;
typedef struct mrmimeparser_t mrmimeparser_t;


#define MR_VERSION_MAJOR    0
#define MR_VERSION_MINOR    9
#define MR_VERSION_REVISION 7


/* Callback function that is called on updates, state changes etc. with one of the MR_EVENT_* codes
- The callback MAY be called from _any_ thread, not only the main/GUI thread!
- The callback MUST NOT call any mrmailbox_* and related functions unless stated otherwise!
- The callback SHOULD return _fast_, for GUI updates etc. you should
  post yourself an asynchronous message to your GUI thread.
- If not mentioned otherweise, the callback should return 0. */
typedef uintptr_t (*mrmailboxcb_t) (mrmailbox_t*, int event, uintptr_t data1, uintptr_t data2);

#define MR_EVENT_INFO                     100  /* Information, should not be reported, can be logged */
#define MR_EVENT_WARNING                  300  /* Warning, should not be reported, should be logged */
#define MR_EVENT_ERROR                    400  /* Error, must be reported to the user by a non-disturbing bubble or so. */

#define MR_EVENT_MSGS_CHANGED             2000 /* one or more messages changed for some reasons in the database - added or removed.  For added messages: data1=chat_id, data2=msg_id */
#define MR_EVENT_INCOMING_MSG             2005 /* For fresh messages from the INBOX, MR_EVENT_INCOMING_MSG is send; data1=chat_id, data2=msg_id */
#define MR_EVENT_MSG_DELIVERED            2010 /* a single message is send successfully (state changed from PENDING/SENDING to DELIVERED); data1=chat_id, data2=msg_id */
#define MR_EVENT_MSG_READ                 2015 /* a single message is read by the receiver (state changed from DELIVERED to READ); data1=chat_id, data2=msg_id */

#define MR_EVENT_CHAT_MODIFIED            2020 /* group name/image changed or members added/removed */

#define MR_EVENT_CONTACTS_CHANGED         2030 /* contact(s) created, renamed, blocked or deleted */

#define MR_EVENT_CONFIGURE_ENDED          2040 /* connection state changed, data1=0:failed-not-connected, 1:configured-and-connected */
#define MR_EVENT_CONFIGURE_PROGRESS       2041 /* data1=percent */

#define MR_EVENT_IMEX_ENDED               2050 /* mrmailbox_imex() done: data1=0:failed, 1=success */
#define MR_EVENT_IMEX_PROGRESS            2051 /* data1=permille */
#define MR_EVENT_IMEX_FILE_WRITTEN        2052 /* file written, event may be needed to make the file public to some system services, data1=file name, data2=mime type */

/* Functions that should be provided by the frontends */
#define MR_EVENT_IS_ONLINE                2080
#define MR_EVENT_GET_STRING               2091 /* get a string from the frontend, data1=MR_STR_*, ret=string which will be free()'d by the backend */
#define MR_EVENT_GET_QUANTITY_STRING      2092 /* get a string from the frontend, data1=MR_STR_*, data2=quantity, ret=string which will free()'d by the backend */
#define MR_EVENT_HTTP_GET                 2100 /* synchronous http/https(!) call, data1=url, ret=content which will be free()'d by the backend, 0 on errors */
#define MR_EVENT_WAKE_LOCK                2110 /* acquire wakeLock (data1=1) or release it (data1=0), the backend does not make nested or unsynchronized calls */

/* Error codes */
#define MR_ERR_SELF_NOT_IN_GROUP  1
#define MR_ERR_NONETWORK          2


typedef struct mrmailbox_t
{
	/* the following members should be treated as library private */
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
	void*            m_userdata;

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


/* mrmailbox_new() creates a new mailbox object.  After creation it is usually
opened, connected and mails are fetched; see the corresponding functions below.
The os name is only for decorative use and is shown eg. in the X-Mailer header
in the form "Delta Chat <version> for <osName>" */
mrmailbox_t*         mrmailbox_new                  (mrmailboxcb_t, void* userData, const char* osName);

/* After usage, the mailbox object must be freed using mrmailbox_unref().
If app runs can only be terminated by a forced kill, this may be superfluous. */
void                 mrmailbox_unref                (mrmailbox_t*);


/* Open/close a mailbox database, if the given file does not exist, it is created
and can be set up using mrmailbox_set_config() afterwards.
sth. like "~/file" won't work on all systems, if in doubt, use absolute paths for dbfile.
for blobdir: the trailing slash is added by us, so if you want to avoid double slashes, do not add one.
If you give NULL as blobdir, "dbfile-blobs" is used. */
int                  mrmailbox_open                 (mrmailbox_t*, const char* dbfile, const char* blobdir);
void                 mrmailbox_close                (mrmailbox_t*);
int                  mrmailbox_is_open              (const mrmailbox_t*);


/* mrmailbox_configure_and_connect() configures and connects a mailbox.
- Before your call this function, you should set at least `addr` and `mail_pw`
  using mrmailbox_set_config().
- mrmailbox_configure_and_connect() returns immediately, configuration is done
  in another thread; when done, the event MR_EVENT_CONFIGURE_ENDED ist posted
- There is no need to call this every program start, the result is saved in the
  database.
- mrmailbox_configure_and_connect() should be called after any settings change. */
void                 mrmailbox_configure_and_connect(mrmailbox_t*);
void                 mrmailbox_configure_cancel     (mrmailbox_t*);
int                  mrmailbox_is_configured        (mrmailbox_t*);


/* Connect to the mailbox using the configured settings. normally, there is no
need to call mrmailbox_fetch() manually as we get push events from the IMAP server;
if this fails, we fallback to a smart pull-mode. */
void                 mrmailbox_connect              (mrmailbox_t*);
void                 mrmailbox_disconnect           (mrmailbox_t*);
int                  mrmailbox_fetch                (mrmailbox_t*);


/* restore old data from the IMAP server, not really implemented. */
int                  mrmailbox_restore              (mrmailbox_t*, time_t seconds_to_restore);


/* Get a list of chats. Handle chats.  The result must be unref'd */
#define              MR_GCL_ARCHIVED_ONLY 0x01
#define              MR_GCL_NO_SPECIALS   0x02 /* do not add deaddrop and archive link to list (may be used eg. for selecting chats on forwarding) */
mrchatlist_t*        mrmailbox_get_chatlist              (mrmailbox_t*, int flags, const char* query);

/* Handle chats. */
mrchat_t*            mrmailbox_get_chat                  (mrmailbox_t*, uint32_t chat_id); /* the result must be unref'd */
uint32_t             mrmailbox_get_chat_id_by_contact_id (mrmailbox_t*, uint32_t contact_id); /* does a chat with a given single user exist? */
uint32_t             mrmailbox_create_chat_by_contact_id (mrmailbox_t*, uint32_t contact_id); /* create a normal chat with a single user */
carray*              mrmailbox_get_chat_media            (mrmailbox_t*, uint32_t chat_id, int msg_type, int or_msg_type); /* returns message IDs, the result must be carray_free()'d */
carray*              mrmailbox_get_fresh_msgs            (mrmailbox_t*); /* returns message IDs, typically used for implementing notification summaries, the result must be free()'d */
int                  mrmailbox_archive_chat              (mrmailbox_t*, uint32_t chat_id, int archive); /* 1=archive, 0=unarchive */


/* Delete a chat:
- messages are deleted from the device and the chat database entry is deleted
- messages are _not_ deleted from the server
- the chat is not blocked, so new messages from the user/the group may appear and the user may create the chat again
	- this is also one of the reasons, why groups are _not left_ -  this would be unexpected as deleting a normal chat also does not prevent new mails
	- moreover, there may be valid reasons only to leave a group and only to delete a group
	- another argument is, that leaving a group requires sending a message to all group members - esp. for groups not used for a longer time, this is really unexpected
- to leave a chat, use the `function int mrmailbox_remove_contact_from_chat(mailbox, chat_id, MR_CONTACT_ID_SELF)`
*/
int                  mrmailbox_delete_chat               (mrmailbox_t*, uint32_t chat_id);


/* Get previous/next media of a given media message (imaging eg. a virtual playlist of all audio tracks in a chat).
If there is no previous/next media, 0 is returned. */
uint32_t             mrmailbox_get_next_media            (mrmailbox_t*, uint32_t curr_msg_id, int dir);


/* mrmailbox_get_chat_contacts() returns contact IDs, the result must be carray_free()'d.
- for normal chats, the function always returns exactly one contact MR_CONTACT_ID_SELF is _not_ returned.
- for group chats all members are returned, MR_CONTACT_ID_SELF is returned explicitly as it may happen that oneself gets removed from a still existing group
- for the deaddrop, all contacts are returned, MR_CONTACT_ID_SELF is not added */
carray*              mrmailbox_get_chat_contacts         (mrmailbox_t*, uint32_t chat_id);


/* Handle group chats. */
uint32_t             mrmailbox_create_group_chat         (mrmailbox_t*, const char* name);
int                  mrmailbox_is_contact_in_chat        (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int                  mrmailbox_add_contact_to_chat       (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int                  mrmailbox_remove_contact_from_chat  (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int                  mrmailbox_set_chat_name             (mrmailbox_t*, uint32_t chat_id, const char* name);
int                  mrmailbox_set_chat_image            (mrmailbox_t*, uint32_t chat_id, const char* image); /* set image to NULL to remove it */


/* mrmailbox_get_chat_msgs() returns a view on a chat.
The function returns an array of message IDs, which must be carray_free()'d by the caller.
Optionally, some special markers added to the ID-array may help to implement virtual lists:
- If you add the flag MR_GCM_ADD_DAY_MARKER, the marker MR_MSG_ID_DAYMARKER will be added before each day (regarding the local timezone)
- If you specify marker1before, the id MR_MSG_ID_MARKER1 will be added just before the given ID.*/
#define MR_GCM_ADDDAYMARKER 0x01
carray* mrmailbox_get_chat_msgs (mrmailbox_t*, uint32_t chat_id, uint32_t flags, uint32_t marker1before);


/* Search messages containing the given query string.
Searching can be done globally (chat_id=0) or in a specified chat only (chat_id set).
- The function returns an array of messages IDs which must be carray_free()'d by the caller.
- If nothing can be found, the function returns NULL.  */
carray*  mrmailbox_search_msgs (mrmailbox_t*, uint32_t chat_id, const char* query);


/* Get messages - for a list, see mrmailbox_get_chatlist() */
mrmsg_t*             mrmailbox_get_msg              (mrmailbox_t*, uint32_t msg_id); /* the result must be unref'd */
char*                mrmailbox_get_msg_info         (mrmailbox_t*, uint32_t msg_id); /* the result must be free()'d */
int                  mrmailbox_delete_msgs          (mrmailbox_t*, const uint32_t* msg_ids, int msg_cnt);
int                  mrmailbox_forward_msgs         (mrmailbox_t*, const uint32_t* msg_ids, int msg_cnt, uint32_t chat_id);


/* mrmailbox_marknoticed_chat() marks all message in a whole chat as NOTICED.
NOTICED messages are no longer FRESH and do not count as being unseen.  IMAP/MDNs is not done for noticed messages. */
int                  mrmailbox_marknoticed_chat     (mrmailbox_t*, uint32_t chat_id);


/* mrmailbox_marknoticed_contact() marks all messages send by the given contact as NOTICED. */
int                  mrmailbox_marknoticed_contact  (mrmailbox_t*, uint32_t contact_id);


/* mrmailbox_markseen_msgs() marks a message as SEEN, updates the IMAP state and sends MDNs.
if the message is not in a real chat (eg. a contact request), the message is only marked as NOTICED and no IMAP/MDNs is done. */
int                  mrmailbox_markseen_msgs        (mrmailbox_t*, const uint32_t* msg_ids, int msg_cnt);


/* star/unstar messages */
int                  mrmailbox_star_msgs            (mrmailbox_t*, const uint32_t* msg_ids, int msg_cnt, int star);


/* handle contacts. */
carray*              mrmailbox_get_known_contacts   (mrmailbox_t*, const char* query); /* returns known and unblocked contacts, the result must be carray_free()'d */
mrcontact_t*         mrmailbox_get_contact          (mrmailbox_t*, uint32_t contact_id);
uint32_t             mrmailbox_create_contact       (mrmailbox_t*, const char* name, const char* addr);
int                  mrmailbox_get_blocked_count    (mrmailbox_t*);
carray*              mrmailbox_get_blocked_contacts (mrmailbox_t*);
int                  mrmailbox_block_contact        (mrmailbox_t*, uint32_t contact_id, int block); /* may or may not result in a MR_EVENT_BLOCKING_CHANGED event */
char*                mrmailbox_get_contact_encrinfo (mrmailbox_t*, uint32_t contact_id);
int                  mrmailbox_delete_contact       (mrmailbox_t*, uint32_t contact_id);


/* Handle configurations as:
- addr
- mail_server, mail_user, mail_pw, mail_port,
- send_server, send_user, send_pw, send_port, server_flags */
int                  mrmailbox_set_config           (mrmailbox_t*, const char* key, const char* value);
char*                mrmailbox_get_config           (mrmailbox_t*, const char* key, const char* def);
int                  mrmailbox_set_config_int       (mrmailbox_t*, const char* key, int32_t value);
int32_t              mrmailbox_get_config_int       (mrmailbox_t*, const char* key, int32_t def);


/* Import/export keys, backup etc.
To avoid double slashes, the given directory should not end with a slash. */
#define MR_IMEX_CANCEL                      0
#define MR_IMEX_EXPORT_SELF_KEYS            1 /* param1 is a directory where the keys are written to */
#define MR_IMEX_IMPORT_SELF_KEYS            2 /* param1 is a directory where the keys are searched in and read from */
#define MR_IMEX_EXPORT_BACKUP              11 /* param1 is a directory where the backup is written to */
#define MR_IMEX_IMPORT_BACKUP              12 /* param1 is the file with the backup to import */
#define MR_IMEX_EXPORT_SETUP_MESSAGE       20 /* param1 is a directory where the setup file is written to */
#define MR_BAK_PREFIX             "delta-chat"
#define MR_BAK_SUFFIX             "bak"
void                 mrmailbox_imex                 (mrmailbox_t*, int what, const char* param1, const char* setup_code); /* user import/export function, sends MR_EVENT_IMEX_* events */
char*                mrmailbox_imex_has_backup      (mrmailbox_t*, const char* dir); /* returns backup_file or NULL, may only be used on fresh installations (mrmailbox_is_configured() returns 0); returned strings must be free()'d */
int                  mrmailbox_check_password       (mrmailbox_t*, const char* pw); /* Check if the user is authorized by the given password in some way. This is to promt for the password eg. before exporting keys/backup. */
char*                mrmailbox_create_setup_code    (mrmailbox_t*); /* should be written down by the user, forwareded to mrmailbox_imex() for encryption then, must be wiped and free()'d after usage */
int                  mrmailbox_poke_spec            (mrmailbox_t*, const char* spec);          /* mainly for testing, import a folder with eml-files, a single eml-file, e-mail plus public key, ... NULL for the last command */


/* Misc. */
char*                mrmailbox_get_info             (mrmailbox_t*); /* multi-line output; the returned string must be free()'d, returns NULL on errors */
int                  mrmailbox_add_address_book     (mrmailbox_t*, const char*); /* format: Name one\nAddress one\nName two\Address two */
char*                mrmailbox_get_version_str      (void); /* the return value must be free()'d */
int                  mrmailbox_reset_tables         (mrmailbox_t*, int bits); /* reset tables but leaves server configuration, 1=jobs, 2=e2ee, 8=rest but server config */


/* The library tries itself to stay alive. For this purpose there is an additional
"heartbeat" thread that checks if the IDLE-thread is up and working. This check is done about every minute.
However, depending on the operating system, this thread may be delayed or stopped, if this is the case you can
force additional checks manually by just calling mrmailbox_heartbeat() about every minute.
If in doubt, call this function too often, not too less :-) */
void                 mrmailbox_heartbeat            (mrmailbox_t*);


/*** library-private **********************************************************/

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


/* misc. tools */
int    mrmailbox_poke_eml_file                           (mrmailbox_t*, const char* file);
int    mrmailbox_is_reply_to_known_message__             (mrmailbox_t* mailbox, mrmimeparser_t* mime_parser);
int    mrmailbox_is_reply_to_messenger_message__         (mrmailbox_t* mailbox, mrmimeparser_t* mime_parser);
time_t mrmailbox_correct_bad_timestamp__                 (mrmailbox_t* ths, uint32_t chat_id, uint32_t from_id, time_t desired_timestamp, int is_fresh_msg);
void   mrmailbox_add_or_lookup_contacts_by_mailbox_list__(mrmailbox_t* ths, struct mailimf_mailbox_list* mb_list, int origin, carray* ids, int* check_self);
void   mrmailbox_add_or_lookup_contacts_by_address_list__(mrmailbox_t* ths, struct mailimf_address_list* adr_list, int origin, carray* ids, int* check_self);
int    mrmailbox_get_archived_count__                    (mrmailbox_t*);

#define MR_CHAT_PREFIX      "Chat:"      /* you MUST NOT modify this or the following strings */
#define MR_CHATS_FOLDER     "Chats"      /* if we want to support Gma'l-labels - "Chats" is a reserved word for Gma'l */


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRMAILBOX_H__ */
