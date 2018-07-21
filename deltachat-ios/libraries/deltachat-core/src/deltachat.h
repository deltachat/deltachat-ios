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


#ifndef __DELTACHAT_H__
#define __DELTACHAT_H__
#ifdef __cplusplus
extern "C" {
#endif


#ifndef PY_CFFI
#include <stdint.h>
#include <time.h>
#endif


#define DC_VERSION_STR "0.19.0"


/**
 * @mainpage Getting started
 *
 * This document describes how to handle the Delta Chat core library. For general
 * information about Delta Chat itself, see <https://delta.chat> and <https://github.com/deltachat>.
 *
 * Let's start.
 *
 * First of all, you have to **define an event-handler-function** that is called by the library on
 * specific events (eg. when the configuration is done or when fresh messages arrive).
 * With this function you can create a Delta Chat context then:
 *
 * ```
 * #include <deltachat.h>
 *
 * uintptr_t event_handler_func(dc_context_t* context, int event, uintptr_t data1, uintptr_t data2)
 * {
 *     return 0; // for unhandled events, it is always safe to return 0
 * }
 *
 * dc_context_t* context = dc_context_new(event_handler_func, NULL, NULL);
 * ```
 *
 * After that, you should make sure, sending and receiving jobs are processed as needed.
 * For this purpose, you have to **create two threads:**
 *
 * ```
 * #include <pthread.h>
 *
 * void* imap_thread_func(void* context)
 * {
 *     while (true) {
 *         dc_perform_imap_jobs(context);
 *         dc_perform_imap_fetch(context);
 *         dc_perform_imap_idle(context);
 *     }
 * }
 *
 * void* smtp_thread_func(void* context)
 * {
 *     while (true) {
 *         dc_perform_smtp_jobs(context);
 *         dc_perform_smtp_idle(context);
 *     }
 * }
 *
 * pthread_t imap_thread, smtp_thread;
 * pthread_create(&imap_thread, NULL, imap_thread_func, context);
 * pthread_create(&smtp_thread, NULL, smtp_thread_func, context);
 * ```
 *
 * The example above uses "pthreads", however, you can also use anything else for thread handling.
 * NB: The deltachat-core library itself does not create any threads on its own, however, functions,
 * unless stated otherwise, are thread-safe.
 *
 * After that you can  **define and open a database.** The database is a normal
 * sqlite-file and is created as needed:
 *
 * ```
 * dc_open(context, "example.db");
 * ```
 *
 * Now you can **configure the context:**
 *
 * ```
 * dc_set_config(context, "addr", "alice@example.org"); // use some real test credentials here
 * dc_set_config(context, "mail_pw", "***");
 * dc_configure(context);
 * ```
 *
 * dc_configure() returns immediately, the configuration itself may take a while and is done by a job
 * in the imap-thread you've defined above. Once done, the #DC_EVENT_CONFIGURE_PROGRESS reports
 * success to the event_handler_func() that is also defined above.
 * NB: The configuration result is saved in the database, on subsequent starts
 * it is not needed to call dc_configure() (you can check this using dc_is_configured()).
 *
 * Now you can **send the first message:**
 *
 * ```
 * uint32_t contact_id = dc_create_contact(context, NULL, "bob@example.org"); // use a real testing address here
 * uint32_t chat_id    = dc_create_chat_by_contact_id(context, contact_id);
 *
 * dc_send_text_msg(context, chat_id, "Hi, here is my first message!");
 * ```
 *
 * dc_send_text_msg() returns immediately and the sending itself is done by a job
 * in the smtp-thread you've defined above. If you check the testing address (bob) and you should have received a normal email.
 * Answer this email in any email program with "Got it!" and the imap-thread you've create above will **receive the message**.
 *
 * You can then **list all messages** of a chat as follow:
 *
 * ```
 * dc_array_t* msglist = dc_get_chat_msgs(context, chat_id, 0, 0);
 * for (int i = 0; i < dc_array_get_cnt(msglist); i++)
 * {
 *     uint32_t  msg_id = dc_array_get_id(msglist, i);
 *     dc_msg_t* msg    = dc_get_msg(context, msg_id);
 *     char*     text   = dc_msg_get_text(msg);
 *
 *     printf("Message %i: %s\n", i+1, text);
 *
 *     free(text);
 *     dc_msg_unref(msg);
 * }
 * dc_array_unref(msglist);
 * ```
 *
 * This will output the following two lines:
 *
 * ```
 * Message 1: Hi, here is my first message!
 * Message 2: Got it!
 * ```
 *
 *
 * ## Class reference
 *
 * For a class reference, see the "Classes" link atop.
 *
 *
 * ## Further hints
 *
 * Here are some additional, unsorted hints that may be useful.
 *
 * - For `get`-functions, you have to unref the return value in some way.
 *
 * - Strings in function arguments or return values are usually UTF-8 encoded.
 *
 * - The issue-tracker for the core library is here: <https://github.com/deltachat/deltachat-core/issues>
 *
 * The following points are important mainly for the authors of the library itself:
 *
 * - For indentation, use tabs.  Alignments that are not placed at the beginning
 *   of a line should be done with spaces.
 *
 * - For padding between functions, classes etc. use 2 empty lines
 *
 * - Source files are encoded as UTF-8 with Unix line endings
 *   (a simple `LF`, `0x0A` or `\n`)
 *
 * If you need any further assistance, please do not hesitate to contact us
 * through the channels shown at https://delta.chat
 *
 * Please keep in mind, that your derived work must be released under a
 * **GPL-compatible licence**.  For details, please have a look at the
 * [LICENSE file](https://github.com/deltachat/deltachat-core/blob/master/LICENSE)
 * accompanying the source code.
 *
 * See you.
 */


/**
 * @class dc_context_t
 *
 * An object representing a single account.
 *
 * Each account is linked to an IMAP/POP3 account and uses a separate
 * SQLite database for offline functionality and for account-related
 * settings.
 */
typedef struct _dc_context  dc_context_t;
typedef struct _dc_array    dc_array_t;
typedef struct _dc_chatlist dc_chatlist_t;
typedef struct _dc_chat     dc_chat_t;
typedef struct _dc_msg      dc_msg_t;
typedef struct _dc_contact  dc_contact_t;
typedef struct _dc_lot      dc_lot_t;


/**
 * Callback function that should be given to dc_context_new().
 *
 * @memberof dc_context_t
 * @param context The context object as returned by dc_context_new().
 * @param event one of the @ref DC_EVENT constants
 * @param data1 depends on the event parameter
 * @param data2 depends on the event parameter
 * @return return 0 unless stated otherwise in the event parameter documentation
 */
typedef uintptr_t (*dc_callback_t) (dc_context_t*, int event, uintptr_t data1, uintptr_t data2);


// create/open/config/information
dc_context_t*   dc_context_new               (dc_callback_t, void* userdata, const char* os_name);
void            dc_context_unref             (dc_context_t*);
void*           dc_get_userdata              (dc_context_t*);

int             dc_open                      (dc_context_t*, const char* dbfile, const char* blobdir);
void            dc_close                     (dc_context_t*);
int             dc_is_open                   (const dc_context_t*);
char*           dc_get_blobdir               (const dc_context_t*);

int             dc_set_config                (dc_context_t*, const char* key, const char* value);
char*           dc_get_config                (dc_context_t*, const char* key, const char* def);
int             dc_set_config_int            (dc_context_t*, const char* key, int32_t value);
int32_t         dc_get_config_int            (dc_context_t*, const char* key, int32_t def);
char*           dc_get_info                  (dc_context_t*);
char*           dc_get_version_str           (void);
void            dc_openssl_init_not_required (void);


// connect
void            dc_configure                 (dc_context_t*);
int             dc_is_configured             (const dc_context_t*);

void            dc_perform_imap_jobs         (dc_context_t*);
void            dc_perform_imap_fetch        (dc_context_t*);
void            dc_perform_imap_idle         (dc_context_t*);
void            dc_interrupt_imap_idle       (dc_context_t*);

void            dc_perform_smtp_jobs         (dc_context_t*);
void            dc_perform_smtp_idle         (dc_context_t*);
void            dc_interrupt_smtp_idle       (dc_context_t*);


// handle chatlists
#define         DC_GCL_ARCHIVED_ONLY         0x01
#define         DC_GCL_NO_SPECIALS           0x02
dc_chatlist_t*  dc_get_chatlist              (dc_context_t*, int flags, const char* query_str, uint32_t query_id);


// handle chats
uint32_t        dc_create_chat_by_msg_id     (dc_context_t*, uint32_t contact_id);
uint32_t        dc_create_chat_by_contact_id (dc_context_t*, uint32_t contact_id);
uint32_t        dc_get_chat_id_by_contact_id (dc_context_t*, uint32_t contact_id);

uint32_t        dc_send_msg                  (dc_context_t*, uint32_t chat_id, dc_msg_t*);
uint32_t        dc_send_text_msg             (dc_context_t*, uint32_t chat_id, const char* text_to_send);
uint32_t        dc_send_image_msg            (dc_context_t*, uint32_t chat_id, const char* file, const char* filemime, int width, int height);
uint32_t        dc_send_video_msg            (dc_context_t*, uint32_t chat_id, const char* file, const char* filemime, int width, int height, int duration);
uint32_t        dc_send_voice_msg            (dc_context_t*, uint32_t chat_id, const char* file, const char* filemime, int duration);
uint32_t        dc_send_audio_msg            (dc_context_t*, uint32_t chat_id, const char* file, const char* filemime, int duration, const char* author, const char* trackname);
uint32_t        dc_send_file_msg             (dc_context_t*, uint32_t chat_id, const char* file, const char* filemime);
uint32_t        dc_send_vcard_msg            (dc_context_t*, uint32_t chat_id, uint32_t contact_id);
void            dc_set_text_draft            (dc_context_t*, uint32_t chat_id, const char*);

#define         DC_GCM_ADDDAYMARKER          0x01
dc_array_t*     dc_get_chat_msgs             (dc_context_t*, uint32_t chat_id, uint32_t flags, uint32_t marker1before);
int             dc_get_msg_cnt               (dc_context_t*, uint32_t chat_id);
int             dc_get_fresh_msg_cnt         (dc_context_t*, uint32_t chat_id);
dc_array_t*     dc_get_fresh_msgs            (dc_context_t*);
void            dc_marknoticed_chat          (dc_context_t*, uint32_t chat_id);
dc_array_t*     dc_get_chat_media            (dc_context_t*, uint32_t chat_id, int msg_type, int or_msg_type);
uint32_t        dc_get_next_media            (dc_context_t*, uint32_t curr_msg_id, int dir);

void            dc_archive_chat              (dc_context_t*, uint32_t chat_id, int archive);
void            dc_delete_chat               (dc_context_t*, uint32_t chat_id);

dc_array_t*     dc_get_chat_contacts         (dc_context_t*, uint32_t chat_id);
dc_array_t*     dc_search_msgs               (dc_context_t*, uint32_t chat_id, const char* query);

dc_chat_t*      dc_get_chat                  (dc_context_t*, uint32_t chat_id);


// handle group chats
uint32_t        dc_create_group_chat         (dc_context_t*, int verified, const char* name);
int             dc_is_contact_in_chat        (dc_context_t*, uint32_t chat_id, uint32_t contact_id);
int             dc_add_contact_to_chat       (dc_context_t*, uint32_t chat_id, uint32_t contact_id);
int             dc_remove_contact_from_chat  (dc_context_t*, uint32_t chat_id, uint32_t contact_id);
int             dc_set_chat_name             (dc_context_t*, uint32_t chat_id, const char* name);
int             dc_set_chat_profile_image    (dc_context_t*, uint32_t chat_id, const char* image);


// handle messages
char*           dc_get_msg_info              (dc_context_t*, uint32_t msg_id);
void            dc_delete_msgs               (dc_context_t*, const uint32_t* msg_ids, int msg_cnt);
void            dc_forward_msgs              (dc_context_t*, const uint32_t* msg_ids, int msg_cnt, uint32_t chat_id);
void            dc_marknoticed_contact       (dc_context_t*, uint32_t contact_id);
void            dc_markseen_msgs             (dc_context_t*, const uint32_t* msg_ids, int msg_cnt);
void            dc_star_msgs                 (dc_context_t*, const uint32_t* msg_ids, int msg_cnt, int star);
dc_msg_t*       dc_get_msg                   (dc_context_t*, uint32_t msg_id);


// handle contacts
uint32_t        dc_create_contact            (dc_context_t*, const char* name, const char* addr);
int             dc_add_address_book          (dc_context_t*, const char*);

#define         DC_GCL_VERIFIED_ONLY         0x01
#define         DC_GCL_ADD_SELF              0x02
dc_array_t*     dc_get_contacts              (dc_context_t*, uint32_t flags, const char* query);

int             dc_get_blocked_cnt           (dc_context_t*);
dc_array_t*     dc_get_blocked_contacts      (dc_context_t*);
void            dc_block_contact             (dc_context_t*, uint32_t contact_id, int block);
char*           dc_get_contact_encrinfo      (dc_context_t*, uint32_t contact_id);
int             dc_delete_contact            (dc_context_t*, uint32_t contact_id);
dc_contact_t*   dc_get_contact               (dc_context_t*, uint32_t contact_id);


// import/export and tools
#define         DC_IMEX_EXPORT_SELF_KEYS      1 // param1 is a directory where the keys are written to
#define         DC_IMEX_IMPORT_SELF_KEYS      2 // param1 is a directory where the keys are searched in and read from
#define         DC_IMEX_EXPORT_BACKUP        11 // param1 is a directory where the backup is written to
#define         DC_IMEX_IMPORT_BACKUP        12 // param1 is the file with the backup to import
void            dc_imex                      (dc_context_t*, int what, const char* param1, const char* param2);
char*           dc_imex_has_backup           (dc_context_t*, const char* dir);
int             dc_check_password            (dc_context_t*, const char* pw);
char*           dc_initiate_key_transfer     (dc_context_t*);
int             dc_continue_key_transfer     (dc_context_t*, uint32_t msg_id, const char* setup_code);
void            dc_stop_ongoing_process      (dc_context_t*);


// out-of-band verification
#define         DC_QR_ASK_VERIFYCONTACT      200 // id=contact
#define         DC_QR_ASK_VERIFYGROUP        202 // text1=groupname
#define         DC_QR_FPR_OK                 210 // id=contact
#define         DC_QR_FPR_MISMATCH           220 // id=contact
#define         DC_QR_FPR_WITHOUT_ADDR       230 // test1=formatted fingerprint
#define         DC_QR_ADDR                   320 // id=contact
#define         DC_QR_TEXT                   330 // text1=text
#define         DC_QR_URL                    332 // text1=text
#define         DC_QR_ERROR                  400 // text1=error string
dc_lot_t*       dc_check_qr                  (dc_context_t*, const char* qr);
char*           dc_get_securejoin_qr         (dc_context_t*, uint32_t chat_id);
uint32_t        dc_join_securejoin           (dc_context_t*, const char* qr);


/**
 * @class dc_array_t
 *
 * An object containing a simple array.
 * This object is used in several placed where functions need to return an array.
 * The items of the array are typically IDs.
 * To free an array object, use dc_array_unref().
 */
typedef struct _dc_array dc_array_t;


dc_array_t*      dc_array_new                (dc_context_t*, size_t initsize);
void             dc_array_empty              (dc_array_t*);
void             dc_array_unref              (dc_array_t*);

void             dc_array_add_uint           (dc_array_t*, uintptr_t);
void             dc_array_add_id             (dc_array_t*, uint32_t);
void             dc_array_add_ptr            (dc_array_t*, void*);

size_t           dc_array_get_cnt            (const dc_array_t*);
uintptr_t        dc_array_get_uint           (const dc_array_t*, size_t index);
uint32_t         dc_array_get_id             (const dc_array_t*, size_t index);
void*            dc_array_get_ptr            (const dc_array_t*, size_t index);

int              dc_array_search_id          (const dc_array_t*, uint32_t needle, size_t* indx);
const uintptr_t* dc_array_get_raw            (const dc_array_t*);


/**
 * @class dc_chatlist_t
 *
 * An object representing a single chatlist in memory.
 * Chatlist objects contain chat IDs and, if possible, message IDs belonging to them.
 * Chatlist objects are created eg. using dc_get_chatlist().
 * The chatlist object is not updated.  If you want an update, you have to recreate
 * the object.
 */
typedef struct _dc_chatlist dc_chatlist_t;


dc_chatlist_t*   dc_chatlist_new             (dc_context_t*);
void             dc_chatlist_empty           (dc_chatlist_t*);
void             dc_chatlist_unref           (dc_chatlist_t*);
size_t           dc_chatlist_get_cnt         (const dc_chatlist_t*);
uint32_t         dc_chatlist_get_chat_id     (const dc_chatlist_t*, size_t index);
uint32_t         dc_chatlist_get_msg_id      (const dc_chatlist_t*, size_t index);
dc_lot_t*        dc_chatlist_get_summary     (const dc_chatlist_t*, size_t index, dc_chat_t*);
dc_context_t*    dc_chatlist_get_context     (dc_chatlist_t*);


/**
 * @class dc_chat_t
 *
 * An object representing a single chat in memory. Chat objects are created using eg. dc_get_chat() and
 * are not updated on database changes;  if you want an update, you have to recreate the
 * object.
 */
typedef struct _dc_chat dc_chat_t;


#define         DC_CHAT_ID_DEADDROP          1 // virtual chat showing all messages belonging to chats flagged with chats.blocked=2
#define         DC_CHAT_ID_TRASH             3 // messages that should be deleted get this chat_id; the messages are deleted from the working thread later then. This is also needed as rfc724_mid should be preset as long as the message is not deleted on the server (otherwise it is downloaded again)
#define         DC_CHAT_ID_MSGS_IN_CREATION  4 // a message is just in creation but not yet assigned to a chat (eg. we may need the message ID to set up blobs; this avoids unready message to be sent and shown)
#define         DC_CHAT_ID_STARRED           5 // virtual chat showing all messages flagged with msgs.starred=2
#define         DC_CHAT_ID_ARCHIVED_LINK     6 // only an indicator in a chatlist
#define         DC_CHAT_ID_LAST_SPECIAL      9 // larger chat IDs are "real" chats, their messages are "real" messages.


#define         DC_CHAT_TYPE_UNDEFINED       0
#define         DC_CHAT_TYPE_SINGLE          100
#define         DC_CHAT_TYPE_GROUP           120
#define         DC_CHAT_TYPE_VERIFIED_GROUP  130


dc_chat_t*      dc_chat_new                  (dc_context_t*);
void            dc_chat_empty                (dc_chat_t*);
void            dc_chat_unref                (dc_chat_t*);

uint32_t        dc_chat_get_id               (const dc_chat_t*);
int             dc_chat_get_type             (const dc_chat_t*);
char*           dc_chat_get_name             (const dc_chat_t*);
char*           dc_chat_get_subtitle         (const dc_chat_t*);
char*           dc_chat_get_profile_image    (const dc_chat_t*);
char*           dc_chat_get_text_draft       (const dc_chat_t*);
time_t          dc_chat_get_draft_timestamp  (const dc_chat_t*);
int             dc_chat_get_archived         (const dc_chat_t*);
int             dc_chat_is_unpromoted        (const dc_chat_t*);
int             dc_chat_is_self_talk         (const dc_chat_t*);
int             dc_chat_is_verified          (const dc_chat_t*);


/**
 * @class dc_msg_t
 *
 * An object representing a single message in memory.  The message
 * object is not updated.  If you want an update, you have to recreate the
 * object.
 */
typedef struct _dc_msg dc_msg_t;


#define         DC_MSG_ID_MARKER1            1
#define         DC_MSG_ID_DAYMARKER          9
#define         DC_MSG_ID_LAST_SPECIAL       9


#define         DC_MSG_UNDEFINED             0
#define         DC_MSG_TEXT                  10
#define         DC_MSG_IMAGE                 20 // param may contain FILE, WIDTH, HEIGHT
#define         DC_MSG_GIF                   21 //   - " -
#define         DC_MSG_AUDIO                 40 // param may contain FILE, DURATION
#define         DC_MSG_VOICE                 41 //   - " -
#define         DC_MSG_VIDEO                 50 // param may contain FILE, WIDTH, HEIGHT, DURATION
#define         DC_MSG_FILE                  60 // param may contain FILE


#define         DC_STATE_UNDEFINED           0
#define         DC_STATE_IN_FRESH            10
#define         DC_STATE_IN_NOTICED          13
#define         DC_STATE_IN_SEEN             16
#define         DC_STATE_OUT_PENDING         20
#define         DC_STATE_OUT_FAILED          24
#define         DC_STATE_OUT_DELIVERED       26 // to check if a mail was sent, use dc_msg_is_sent()
#define         DC_STATE_OUT_MDN_RCVD        28


#define         DC_MAX_GET_TEXT_LEN          30000 // approx. max. lenght returned by dc_msg_get_text()
#define         DC_MAX_GET_INFO_LEN          100000 // approx. max. lenght returned by dc_get_msg_info()


dc_msg_t*       dc_msg_new                   ();
void            dc_msg_unref                 (dc_msg_t*);
void            dc_msg_empty                 (dc_msg_t*);
uint32_t        dc_msg_get_id                (const dc_msg_t*);
uint32_t        dc_msg_get_from_id           (const dc_msg_t*);
uint32_t        dc_msg_get_chat_id           (const dc_msg_t*);
int             dc_msg_get_type              (const dc_msg_t*);
int             dc_msg_get_state             (const dc_msg_t*);
time_t          dc_msg_get_timestamp         (const dc_msg_t*);
char*           dc_msg_get_text              (const dc_msg_t*);
char*           dc_msg_get_file              (const dc_msg_t*);
char*           dc_msg_get_filename          (const dc_msg_t*);
char*           dc_msg_get_filemime          (const dc_msg_t*);
uint64_t        dc_msg_get_filebytes         (const dc_msg_t*);
dc_lot_t*       dc_msg_get_mediainfo         (const dc_msg_t*);
int             dc_msg_get_width             (const dc_msg_t*);
int             dc_msg_get_height            (const dc_msg_t*);
int             dc_msg_get_duration          (const dc_msg_t*);
int             dc_msg_get_showpadlock       (const dc_msg_t*);
dc_lot_t*       dc_msg_get_summary           (const dc_msg_t*, const dc_chat_t*);
char*           dc_msg_get_summarytext       (const dc_msg_t*, int approx_characters);
int             dc_msg_is_sent               (const dc_msg_t*);
int             dc_msg_is_starred            (const dc_msg_t*);
int             dc_msg_is_forwarded          (const dc_msg_t*);
int             dc_msg_is_info               (const dc_msg_t*);
int             dc_msg_is_increation         (const dc_msg_t*);
int             dc_msg_is_setupmessage       (const dc_msg_t*);
char*           dc_msg_get_setupcodebegin    (const dc_msg_t*);
void            dc_msg_set_type              (dc_msg_t*, int type);
void            dc_msg_set_text              (dc_msg_t*, const char* text);
void            dc_msg_set_file              (dc_msg_t*, const char* file, const char* filemime);
void            dc_msg_set_dimension         (dc_msg_t*, int width, int height);
void            dc_msg_set_duration          (dc_msg_t*, int duration);
void            dc_msg_set_mediainfo         (dc_msg_t*, const char* author, const char* trackname);
void            dc_msg_latefiling_mediasize  (dc_msg_t*, int width, int height, int duration);


/**
 * @class dc_contact_t
 *
 * An object representing a single contact in memory.
 * The contact object is not updated. If you want an update, you have to recreate the object.
 *
 * The library makes sure only to use names _authorized_ by the contact in `To:` or `Cc:`.
 * Given-names as "Daddy" or "Honey" are not used there.
 * For this purpose, internally, two names are tracked - autorized-name and given-name.
 * By default, these names are equal, but functions working with contact names
 * (eg. dc_contact_get_name(), dc_contact_get_display_name(), dc_contact_get_name_n_addr(),
 * dc_contact_get_first_name(), dc_create_contact() or dc_add_address_book()) only affect the given-name.
 */
typedef struct _dc_contact dc_contact_t;

#define         DC_CONTACT_ID_SELF           1
#define         DC_CONTACT_ID_DEVICE         2
#define         DC_CONTACT_ID_LAST_SPECIAL   9


dc_contact_t*   dc_contact_new               (dc_context_t*); /* the returned pointer is ref'd and must be unref'd after usage */
void            dc_contact_empty             (dc_contact_t*);
void            dc_contact_unref             (dc_contact_t*);
uint32_t        dc_contact_get_id            (const dc_contact_t*);
char*           dc_contact_get_addr          (const dc_contact_t*);
char*           dc_contact_get_name          (const dc_contact_t*);
char*           dc_contact_get_display_name  (const dc_contact_t*);
char*           dc_contact_get_name_n_addr   (const dc_contact_t*);
char*           dc_contact_get_first_name    (const dc_contact_t*);
int             dc_contact_is_blocked        (const dc_contact_t*);
int             dc_contact_is_verified       (dc_contact_t*);


/**
 * @class dc_lot_t
 *
 * An object containing a set of values.  The meaning of the values is defined by the function returning the set object.
 * Set objects are created eg. by dc_chatlist_get_summary(), dc_msg_get_summary() or by dc_msg_get_mediainfo().
 *
 * NB: _Lot_ is used in the meaning _heap_ here.
 */
typedef struct _dc_lot dc_lot_t;


#define         DC_TEXT1_DRAFT     1
#define         DC_TEXT1_USERNAME  2
#define         DC_TEXT1_SELF      3


dc_lot_t*       dc_lot_new               ();
void            dc_lot_empty             (dc_lot_t*);
void            dc_lot_unref             (dc_lot_t*);
char*           dc_lot_get_text1         (const dc_lot_t*);
char*           dc_lot_get_text2         (const dc_lot_t*);
int             dc_lot_get_text1_meaning (const dc_lot_t*);
int             dc_lot_get_state         (const dc_lot_t*);
uint32_t        dc_lot_get_id            (const dc_lot_t*);
time_t          dc_lot_get_timestamp     (const dc_lot_t*);


/**
 * @defgroup DC_EVENT DC_EVENT
 *
 * These constants are used as events reported to the callback given to dc_context_new().
 * If you do not want to handle an event, it is always safe to return 0, so there is no need to add a "case" for every event.
 *
 * @addtogroup DC_EVENT
 * @{
 */

/**
 * The library-user may write an informational string to the log.
 * Passed to the callback given to dc_context_new().
 *
 * This event should not be reported to the end-user using a popup or something like that.
 *
 * @param data1 0
 * @param data2 (const char*) Info string in english language.
 * @return 0
 */
#define DC_EVENT_INFO                     100


/**
 * The library-user should write a warning string to the log.
 * Passed to the callback given to dc_context_new().
 *
 * This event should not be reported to the end-user using a popup or something like that.
 *
 * @param data1 0
 * @param data2 (const char*) Warning string in english language.
 * @return 0
 */
#define DC_EVENT_WARNING                  300


/**
 * The library-user should report an error to the end-user.
 * Passed to the callback given to dc_context_new().
 *
 * As most things are asynchrounous, things may go wrong at any time and the user
 * should not be disturbed by a dialog or so.  Instead, use a bubble or so.
 *
 * However, for ongoing processes (eg. dc_configure())
 * or for functions that are expected to fail (eg. dc_continue_key_transfer())
 * it might be better to delay showing these events until the function has really
 * failed (returned false). It should be sufficient to report only the _last_ error
 * in a messasge box then.
 *
 * @param data1 (int) Error code, see @ref DC_ERROR for a list of constants.
 * @param data2 (const char*) Error string, always set, never NULL. Frequent error strings are
 *     localized using #DC_EVENT_GET_STRING, however, most error strings will be
 *     in english language.
 * @return 0
 */
#define DC_EVENT_ERROR                    400


/**
 * Messages or chats changed.  One or more messages or chats changed for various
 * reasons in the database:
 * - Messages sent, received or removed
 * - Chats created, deleted or archived
 * - A draft has been set
 *
 * @param data1 (int) chat_id for single added messages
 * @param data2 (int) msg_id for single added messages
 * @return 0
 */
#define DC_EVENT_MSGS_CHANGED             2000


/**
 * There is a fresh message. Typically, the user will show an notification
 * when receiving this message.
 *
 * There is no extra #DC_EVENT_MSGS_CHANGED event send together with this event.
 *
 * @param data1 (int) chat_id
 * @param data2 (int) msg_id
 * @return 0
 */
#define DC_EVENT_INCOMING_MSG             2005


/**
 * A single message is sent successfully. State changed from  DC_STATE_OUT_PENDING to
 * DC_STATE_OUT_DELIVERED, see dc_msg_get_state().
 *
 * @param data1 (int) chat_id
 * @param data2 (int) msg_id
 * @return 0
 */
#define DC_EVENT_MSG_DELIVERED            2010


/**
 * A single message could not be sent. State changed from DC_STATE_OUT_PENDING or DC_STATE_OUT_DELIVERED to
 * DC_STATE_OUT_FAILED, see dc_msg_get_state().
 *
 * @param data1 (int) chat_id
 * @param data2 (int) msg_id
 * @return 0
 */
#define DC_EVENT_MSG_FAILED               2012


/**
 * A single message is read by the receiver. State changed from DC_STATE_OUT_DELIVERED to
 * DC_STATE_OUT_MDN_RCVD, see dc_msg_get_state().
 *
 * @param data1 (int) chat_id
 * @param data2 (int) msg_id
 * @return 0
 */
#define DC_EVENT_MSG_READ                 2015


/**
 * Chat changed.  The name or the image of a chat group was changed or members were added or removed.
 * Or the verify state of a chat has changed.
 * See dc_set_chat_name(), dc_set_chat_profile_image(), dc_add_contact_to_chat()
 * and dc_remove_contact_from_chat().
 *
 * @param data1 (int) chat_id
 * @param data2 0
 * @return 0
 */
#define DC_EVENT_CHAT_MODIFIED            2020


/**
 * Contact(s) created, renamed, blocked or deleted.
 *
 * @param data1 (int) If not 0, this is the contact_id of an added contact that should be selected.
 * @param data2 0
 * @return 0
 */
#define DC_EVENT_CONTACTS_CHANGED         2030


/**
 * Inform about the configuration progress started by dc_configure().
 *
 * @param data1 (int) 0=error, 1-999=progress in permille, 1000=success and done
 * @param data2 0
 * @return 0
 */
#define DC_EVENT_CONFIGURE_PROGRESS       2041


/**
 * Inform about the import/export progress started by dc_imex().
 *
 * @param data1 (int) 0=error, 1-999=progress in permille, 1000=success and done
 * @param data2 0
 * @return 0
 */
#define DC_EVENT_IMEX_PROGRESS            2051


/**
 * A file has been exported. A file has been written by dc_imex().
 * This event may be sent multiple times by a single call to dc_imex().
 *
 * A typical purpose for a handler of this event may be to make the file public to some system
 * services.
 *
 * @param data1 (const char*) File name
 * @param data2 0
 * @return 0
 */
#define DC_EVENT_IMEX_FILE_WRITTEN        2052


/**
 * Progress information of a secure-join handshake from the view of the inviter
 * (Alice, the person who shows the QR code).
 *
 * These events are typically sent after a joiner has scanned the QR code
 * generated by dc_get_securejoin_qr().
 *
 * @param data1 (int) ID of the contact that wants to join.
 * @param data2 (int) Progress as:
 *     300=vg-/vc-request received, typically shown as "bob@addr joins".
 *     600=vg-/vc-request-with-auth received, vg-member-added/vc-contact-confirm sent, typically shown as "bob@addr verified".
 *     800=vg-member-added-received received, shown as "bob@addr securely joined GROUP", only sent for the verified-group-protocol.
 *     1000=Protocol finished for this contact.
 * @return 0
 */
#define DC_EVENT_SECUREJOIN_INVITER_PROGRESS      2060


/**
 * Progress information of a secure-join handshake from the view of the joiner
 * (Bob, the person who scans the QR code).
 *
 * The events are typically sent while dc_join_securejoin(), which
 * may take some time, is executed.
 *
 * @param data1 (int) ID of the inviting contact.
 * @param data2 (int) Progress as:
 *     400=vg-/vc-request-with-auth sent, typically shown as "alice@addr verified, introducing myself."
 *     (Bob has verified alice and waits until Alice does the same for him)
 * @return 0
 */
#define DC_EVENT_SECUREJOIN_JOINER_PROGRESS       2061


// the following events are functions that should be provided by the frontends

/**
 * Ask the frontend about the offline state.
 * This function may be provided by the frontend. If we already know, that we're
 * offline, eg. there is no need to try to connect and things will speed up.
 *
 * @param data1 0
 * @param data2 0
 * @return 0=online, 1=offline
 */
#define DC_EVENT_IS_OFFLINE               2081


/**
 * Requeste a localized string from the frontend.
 *
 * @param data1 (int) ID of the string to request, one of the DC_STR_* constants as defined in stock.h
 * @param data2 0
 * @return (const char*) Null-terminated UTF-8 string.  CAVE: The string will be free()'d by the core, so make
 *     sure it is allocated using malloc() or a compatible function.
 *     If you cannot provide the requested string, just return 0; the core will use a default string then.
 */
#define DC_EVENT_GET_STRING               2091


/**
 * Requeste a localized quantitiy string from the frontend.
 * Quantitiy strings may have eg. different plural forms and usually also include the count itself to the string.
 * Typical strings in this form are "1 Message" vs. "2 Messages".
 *
 * @param data1 (int) ID of the string to request, one of the DC_STR_* constants as defined in stock.h
 * @param data2 (int) The count. The frontend may return different strings on this value and normally also includes
 *     the value itself to the string.
 * @return (const char*) Null-terminated UTF-8 string.  CAVE: The string will be free()'d by the core, so make
 *     sure it is allocated using malloc() or a compatible function.
 *     If you cannot provide the requested string, just return 0; the core will use a default string then.
 */
#define DC_EVENT_GET_QUANTITY_STRING      2092


/**
 * Request a HTTP-file or HTTPS-file from the frontend.
 *
 * @param data1 (const char*) Null-terminated UTF-8 string containing the URL. The string starts with https:// or http://. Must not be free()'d or modified by the frontend.
 * @param data2 0
 * @return (const char*) The content of the requested file as a null-terminated UTF-8 string;
 *     Response headers, encodings etc. must be stripped, only the raw file, which may be binary, should be returned.
 *     CAVE: The string will be free()'d by the core,
 *     so make sure it is allocated using malloc() or a compatible function.
 *     If you cannot provide the content, just return 0.
 */
#define DC_EVENT_HTTP_GET                 2100

/**
 * @}
 */


#define DC_EVENT_DATA2_IS_STRING(e)  ((e)==DC_EVENT_INFO) || (e)==DC_EVENT_WARNING || (e)==DC_EVENT_ERROR))
#define DC_EVENT_RETURNS_INT         ((e)==DC_EVENT_IS_OFFLINE)
#define DC_EVENT_RETURNS_STRING(e)   ((e)==DC_EVENT_INFO) || (e)==DC_EVENT_GET_QUANTITY_STRING || (e)==DC_EVENT_GET_STRING))


/**
 * @defgroup DC_ERROR DC_ERROR
 *
 * These constants are used as error in the event
 * #DC_EVENT_ERROR and reported to the callback given to
 * dc_context_new().
 *
 * @addtogroup DC_ERROR
 * @{
 */

/**
 * Details about the error can be found in data2. Reported by #DC_EVENT_ERROR.
 */
#define DC_ERROR_SEE_STRING                 0


/**
 * The action cannot be performed because the user is not in the group.
 * Reported by #DC_EVENT_ERROR eg. after a call to dc_set_chat_name(), dc_set_chat_profile_image(),
 * dc_add_contact_to_chat(), dc_remove_contact_from_chat(), dc_send_text_msg() or another sending function.
 */
#define DC_ERROR_SELF_NOT_IN_GROUP          1


/**
 * Details about the error can be found in data2. Reported by #DC_EVENT_ERROR.
 */
#define DC_ERROR_NO_NETWORK                 2

/**
 * @}
 */


#ifdef __cplusplus
}
#endif
#endif // __DELTACHAT_H__

