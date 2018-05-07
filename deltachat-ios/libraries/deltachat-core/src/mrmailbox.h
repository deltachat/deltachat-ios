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


#ifndef __MRMAILBOX_H__
#define __MRMAILBOX_H__
#ifdef __cplusplus
extern "C" {
#endif


#define MR_VERSION_MAJOR    0
#define MR_VERSION_MINOR    17
#define MR_VERSION_REVISION 0


/**
 * @mainpage Getting started
 *
 * This document describes how to handle the Delta Chat core library.
 * For general information about Delta Chat itself, see <https://delta.chat> and <https://github.com/deltachat>.
 *
 * Let's start.
 *
 * First of all, you have to define a function that is called by the library on
 * specific events (eg. when the configuration is done or when fresh messages arrive).
 * Your function should look like the following:
 *
 * ```
 * #include <mrmailbox.h>
 *
 * uintptr_t my_delta_handler(mrmailbox_t* mailbox, int event, uintptr_t data1, uintptr_t data2)
 * {
 *     return 0; // for unhandled events, it is always safe to return 0
 * }
 * ```
 *
 * After that, you can create and configure a mrmailbox_t object easily as follows:
 *
 * ```
 * mrmailbox_t* mailbox = mrmailbox_new(my_delta_handler, NULL, NULL);
 *
 * mrmailbox_set_config(mailbox, "addr",    "alice@delta.chat"); // use some real test credentials here
 * mrmailbox_set_config(mailbox, "mail_pw", "***");
 *
 * mrmailbox_configure_and_connect(mailbox);
 * ```
 *
 * mrmailbox_configure_and_connect() may take a while and saves the result in
 * the database. On subsequent starts, you can call mrmailbox_connect() instead
 * if mrmailbox_is_configured() returns true.
 *
 * However, now you can send your first message:
 *
 * ```
 * uint32_t contact_id = mrmailbox_create_contact(mailbox, NULL, "bob@delta.chat"); // use a real testing address here
 * uint32_t chat_id    = mrmailbox_create_chat_by_contact_id(mailbox, contact_id);
 *
 * mrmailbox_send_text_msg(mailbox, chat_id, "Hi, here is my first message!");
 * ```
 *
 * Now, go to the testing address (bob) and you should have received a normal email.
 * Answer this email in any email program with "Got it!" and you will get the message from delta as follows:
 *
 * ```
 * mrarray_t* msglist = mrmailbox_get_chat_msgs(mailbox, chat_id, 0, 0);
 * for( size_t i = 0; i < mrarray_get_cnt(msglist); i++ )
 * {
 *     uint32_t msg_id = mrarray_get_id(msglist, i);
 *     mrmsg_t* msg    = mrmailbox_get_msg(mailbox, msg_id);
 *     char*    text   = mrmsg_get_text(msg);
 *
 *     printf("message %i: %s\n", i+1, text);
 *
 *     free(text);
 *     mrmsg_unref(msg);
 * }
 * mrarray_unref(msglist);
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
 * If you need any further assistance, please do not hesitate to contact us at <r10s@b44t.com>.
 *
 * - Two underscores at the end of a function-name may be a _hint_, that this
 *   function does no resource locking. Such functions must not be used.
 *
 * - For objects, C-structures are used.  If not mentioned otherwise, you can
 *   read the members here directly.
 *
 * - For `get`-functions, you have to unref the return value in some way.
 *
 * - Strings in function arguments or return values are usually UTF-8 encoded
 *
 * - Threads are implemented using POSIX threads (`pthread_*` functions)
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
 * - Source files are encoded as UTF-8 with Unix line endings (a simple `LF`, `0x0A` or
 *   `\n`)
 *
 * Please keep in mind, that your derived work must be released under a
 * **GPL-compatible licence**.  For details, please have a look at the [LICENSE file](https://github.com/deltachat/deltachat-core/blob/master/LICENSE) accompanying the source code.
 *
 * See you.
 */


#ifndef PY_CFFI
#include <pthread.h>
#include <libetpan/libetpan.h> /* defines uint16_t */
#endif

#include "mrarray.h"
#include "mrchatlist.h"
#include "mrchat.h"
#include "mrmsg.h"
#include "mrcontact.h"
#include "mrlot.h"
#include "mrevent.h"
#include "mrerror.h"


/**
 * @class mrmailbox_t
 *
 * An object representing a single mailbox.
 *
 * Each mailbox is linked to an IMAP/POP3 account and uses a separate
 * SQLite database for offline functionality and for mailbox-related
 * settings.
 */
typedef struct _mrmailbox mrmailbox_t;


/**
 * Callback function that should be given to mrmailbox_new().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as returned by mrmailbox_new().
 *
 * @param event one of the MR_EVENT_* constants as defined in mrevent.h
 *
 * @param data1 depends on the event parameter
 *
 * @param data2 depends on the event parameter
 *
 * @return return 0 unless stated otherwise in the event parameter documentation
 */
typedef uintptr_t (*mrmailboxcb_t) (mrmailbox_t*, int event, uintptr_t data1, uintptr_t data2);




/* create/open/connect */
mrmailbox_t*    mrmailbox_new               (mrmailboxcb_t, void* userdata, const char* os_name);
void            mrmailbox_unref             (mrmailbox_t*);
void*           mrmailbox_get_userdata      (mrmailbox_t*);

int             mrmailbox_open              (mrmailbox_t*, const char* dbfile, const char* blobdir);
void            mrmailbox_close             (mrmailbox_t*);
int             mrmailbox_is_open           (const mrmailbox_t*);
char*           mrmailbox_get_blobdir       (mrmailbox_t*);

int             mrmailbox_set_config        (mrmailbox_t*, const char* key, const char* value);
char*           mrmailbox_get_config        (mrmailbox_t*, const char* key, const char* def);
int             mrmailbox_set_config_int    (mrmailbox_t*, const char* key, int32_t value);
int32_t         mrmailbox_get_config_int    (mrmailbox_t*, const char* key, int32_t def);
char*           mrmailbox_get_version_str   (void);

int             mrmailbox_configure_and_connect(mrmailbox_t*);
void            mrmailbox_stop_ongoing_process(mrmailbox_t*);
int             mrmailbox_is_configured     (mrmailbox_t*);

void            mrmailbox_connect           (mrmailbox_t*);
void            mrmailbox_disconnect        (mrmailbox_t*);

char*           mrmailbox_get_info          (mrmailbox_t*);


/* Handle chatlists */
#define         MR_GCL_ARCHIVED_ONLY        0x01
#define         MR_GCL_NO_SPECIALS          0x02
mrchatlist_t*   mrmailbox_get_chatlist      (mrmailbox_t*, int flags, const char* query_str, uint32_t query_id);


/* Handle chats */
uint32_t        mrmailbox_create_chat_by_msg_id     (mrmailbox_t*, uint32_t contact_id);
uint32_t        mrmailbox_create_chat_by_contact_id (mrmailbox_t*, uint32_t contact_id);
uint32_t        mrmailbox_get_chat_id_by_contact_id (mrmailbox_t*, uint32_t contact_id);

uint32_t        mrmailbox_send_text_msg     (mrmailbox_t*, uint32_t chat_id, const char* text_to_send);
uint32_t        mrmailbox_send_image_msg    (mrmailbox_t*, uint32_t chat_id, const char* file, const char* filemime, int width, int height);
uint32_t        mrmailbox_send_video_msg    (mrmailbox_t*, uint32_t chat_id, const char* file, const char* filemime, int width, int height, int duration);
uint32_t        mrmailbox_send_voice_msg    (mrmailbox_t*, uint32_t chat_id, const char* file, const char* filemime, int duration);
uint32_t        mrmailbox_send_audio_msg    (mrmailbox_t*, uint32_t chat_id, const char* file, const char* filemime, int duration, const char* author, const char* trackname);
uint32_t        mrmailbox_send_file_msg     (mrmailbox_t*, uint32_t chat_id, const char* file, const char* filemime);
uint32_t        mrmailbox_send_vcard_msg    (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
void            mrmailbox_set_draft         (mrmailbox_t*, uint32_t chat_id, const char*);

#define         MR_GCM_ADDDAYMARKER         0x01
mrarray_t*      mrmailbox_get_chat_msgs     (mrmailbox_t*, uint32_t chat_id, uint32_t flags, uint32_t marker1before);
int             mrmailbox_get_total_msg_count (mrmailbox_t*, uint32_t chat_id);
int             mrmailbox_get_fresh_msg_count (mrmailbox_t*, uint32_t chat_id);
mrarray_t*      mrmailbox_get_fresh_msgs    (mrmailbox_t*);
void            mrmailbox_marknoticed_chat  (mrmailbox_t*, uint32_t chat_id);
mrarray_t*      mrmailbox_get_chat_media    (mrmailbox_t*, uint32_t chat_id, int msg_type, int or_msg_type);
uint32_t        mrmailbox_get_next_media    (mrmailbox_t*, uint32_t curr_msg_id, int dir);

void            mrmailbox_archive_chat      (mrmailbox_t*, uint32_t chat_id, int archive);
void            mrmailbox_delete_chat       (mrmailbox_t*, uint32_t chat_id);

mrarray_t*      mrmailbox_get_chat_contacts (mrmailbox_t*, uint32_t chat_id);
mrarray_t*      mrmailbox_search_msgs       (mrmailbox_t*, uint32_t chat_id, const char* query);

mrchat_t*       mrmailbox_get_chat          (mrmailbox_t*, uint32_t chat_id);


/* Handle group chats */
uint32_t        mrmailbox_create_group_chat        (mrmailbox_t*, int verified, const char* name);
int             mrmailbox_is_contact_in_chat       (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int             mrmailbox_add_contact_to_chat      (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int             mrmailbox_remove_contact_from_chat (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int             mrmailbox_set_chat_name            (mrmailbox_t*, uint32_t chat_id, const char* name);
int             mrmailbox_set_chat_profile_image   (mrmailbox_t*, uint32_t chat_id, const char* image);


/* Handle messages */
char*           mrmailbox_get_msg_info      (mrmailbox_t*, uint32_t msg_id);
void            mrmailbox_delete_msgs       (mrmailbox_t*, const uint32_t* msg_ids, int msg_cnt);
void            mrmailbox_forward_msgs      (mrmailbox_t*, const uint32_t* msg_ids, int msg_cnt, uint32_t chat_id);
void            mrmailbox_marknoticed_contact (mrmailbox_t*, uint32_t contact_id);
void            mrmailbox_markseen_msgs     (mrmailbox_t*, const uint32_t* msg_ids, int msg_cnt);
void            mrmailbox_star_msgs         (mrmailbox_t*, const uint32_t* msg_ids, int msg_cnt, int star);
mrmsg_t*        mrmailbox_get_msg           (mrmailbox_t*, uint32_t msg_id);


/* Handle contacts */
uint32_t        mrmailbox_create_contact    (mrmailbox_t*, const char* name, const char* addr);
int             mrmailbox_add_address_book  (mrmailbox_t*, const char*);

#define         MR_GCL_VERIFIED_ONLY 0x01
#define         MR_GCL_ADD_SELF      0x02
mrarray_t*      mrmailbox_get_contacts      (mrmailbox_t*, uint32_t flags, const char* query);

int             mrmailbox_get_blocked_count (mrmailbox_t*);
mrarray_t*      mrmailbox_get_blocked_contacts (mrmailbox_t*);
void            mrmailbox_block_contact     (mrmailbox_t*, uint32_t contact_id, int block);
char*           mrmailbox_get_contact_encrinfo (mrmailbox_t*, uint32_t contact_id);
int             mrmailbox_delete_contact    (mrmailbox_t*, uint32_t contact_id);
mrcontact_t*    mrmailbox_get_contact       (mrmailbox_t*, uint32_t contact_id);


/* Import/export and Tools */
#define         MR_IMEX_EXPORT_SELF_KEYS      1 /* param1 is a directory where the keys are written to */
#define         MR_IMEX_IMPORT_SELF_KEYS      2 /* param1 is a directory where the keys are searched in and read from */
#define         MR_IMEX_EXPORT_BACKUP        11 /* param1 is a directory where the backup is written to */
#define         MR_IMEX_IMPORT_BACKUP        12 /* param1 is the file with the backup to import */
#define         MR_BAK_PREFIX                "delta-chat"
#define         MR_BAK_SUFFIX                "bak"
int             mrmailbox_imex              (mrmailbox_t*, int what, const char* param1, const char* param2);
char*           mrmailbox_imex_has_backup   (mrmailbox_t*, const char* dir);
int             mrmailbox_check_password    (mrmailbox_t*, const char* pw);
char*           mrmailbox_initiate_key_transfer(mrmailbox_t*);
int             mrmailbox_continue_key_transfer(mrmailbox_t*, uint32_t msg_id, const char* setup_code);
void            mrmailbox_heartbeat         (mrmailbox_t*);


/* out-of-band verification */
#define         MR_QR_ASK_VERIFYCONTACT     200 /* id=contact */
#define         MR_QR_ASK_VERIFYGROUP       202 /* text1=groupname */
#define         MR_QR_FPR_OK                210 /* id=contact */
#define         MR_QR_FPR_MISMATCH          220 /* id=contact */
#define         MR_QR_FPR_WITHOUT_ADDR      230 /* test1=formatted fingerprint */
#define         MR_QR_ADDR                  320 /* id=contact */
#define         MR_QR_TEXT                  330 /* text1=text */
#define         MR_QR_URL                   332 /* text1=text */
#define         MR_QR_ERROR                 400 /* text1=error string */
mrlot_t*        mrmailbox_check_qr          (mrmailbox_t*, const char* qr);
char*           mrmailbox_get_securejoin_qr (mrmailbox_t*, uint32_t chat_id);
uint32_t        mrmailbox_join_securejoin   (mrmailbox_t*, const char* qr);


/* deprecated functions */
int             mrchat_set_draft            (mrchat_t*, const char* msg);   /* deprecated - use mrmailbox_set_draft() instead */
#define         mrpoortext_t                mrlot_t
#define         mrpoortext_unref            mrlot_unref
#define         mrmailbox_imex_cancel       mrmailbox_stop_ongoing_process
#define         mrmailbox_configure_cancel  mrmailbox_stop_ongoing_process


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRMAILBOX_H__ */
