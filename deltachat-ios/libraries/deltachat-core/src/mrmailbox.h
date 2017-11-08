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


#include <libetpan/libetpan.h> /* defines uint16_t etc. */

typedef struct mrmailbox_t mrmailbox_t;
typedef struct mrchatlist_t mrchatlist_t;
typedef struct mrchat_t mrchat_t;
typedef struct mrmsg_t mrmsg_t;
typedef struct mrcontact_t mrcontact_t;
typedef struct mrpoortext_t mrpoortext_t;
typedef struct mrimap_t mrimap_t;
typedef struct mrsmtp_t mrsmtp_t;
typedef struct mrmimeparser_t mrmimeparser_t;
typedef struct mrsqlite3_t mrsqlite3_t;
typedef struct mrparam_t mrparam_t;
typedef uintptr_t (*mrmailboxcb_t) (mrmailbox_t*, int event, uintptr_t data1, uintptr_t data2);


#define MR_VERSION_MAJOR    0
#define MR_VERSION_MINOR    9
#define MR_VERSION_REVISION 7


/* mrmailbox_t represents a single mailbox, normally, typically only one
instance of this class is present.
Each mailbox is linked to an IMAP/POP3 account and uses a separate
SQLite database for offline functionality and for mailbox-related
settings. */
typedef struct mrmailbox_t
{
	void*            m_userdata;

	/* the following members should be treated as library-private */
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


/* mrmailbox_new() creates a new mailbox object.  After creation it is usually
opened, connected and mails are fetched; see the corresponding functions below.
After usage, the object should be deleted using mrmailbox_unref().

The first parameter is a callback function that is called for events (update,
state changes etc.) and to get some information form the client (eg. translation
for a given string)
- The callback MAY be called from _any_ thread, not only the main/GUI thread!
- The callback MUST NOT call any mrmailbox_* and related functions unless stated otherwise!
- The callback SHOULD return _fast_, for GUI updates etc. you should
  post yourself an asynchronous message to your GUI thread, if needed.
- If not mentioned otherweise, the callback should return 0.

`userdata` can be used by the client for any purpuse.  He finds it
later in mailbox->m_userdata

`os_name` is only for decorative use and is shown eg. in the X-Mailer header
in the form "Delta Chat <version> for <osName>" */
mrmailbox_t*         mrmailbox_new                  (mrmailboxcb_t, void* userdata, const char* os_name);


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


/* Handle configurations as:
- addr
- mail_server, mail_user, mail_pw, mail_port,
- send_server, send_user, send_pw, send_port, server_flags */
int                  mrmailbox_set_config           (mrmailbox_t*, const char* key, const char* value);
char*                mrmailbox_get_config           (mrmailbox_t*, const char* key, const char* def);
int                  mrmailbox_set_config_int       (mrmailbox_t*, const char* key, int32_t value);
int32_t              mrmailbox_get_config_int       (mrmailbox_t*, const char* key, int32_t def);


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


/* multi-line output; the returned string must be free()'d, returns NULL on errors */
char*                mrmailbox_get_info             (mrmailbox_t*);


/* the return value must be free()'d */
char*                mrmailbox_get_version_str      (void);


/*******************************************************************************
 * Handle chatlists
 ******************************************************************************/


/* Get a list of chats. Handle chats.  The result must be unref'd */
#define              MR_GCL_ARCHIVED_ONLY 0x01
#define              MR_GCL_NO_SPECIALS   0x02 /* do not add deaddrop and archive link to list (may be used eg. for selecting chats on forwarding) */
mrchatlist_t*        mrmailbox_get_chatlist              (mrmailbox_t*, int flags, const char* query);


/* The chatlist object and some function for helping accessing it.
The chatlist object is not updated.  If you want an update, you have to recreate the object. */
typedef struct mrchatlist_t
{
	size_t           m_cnt;
	carray*          m_chatNlastmsg_ids;
	mrmailbox_t*     m_mailbox;
} mrchatlist_t;
void                 mrchatlist_unref                    (mrchatlist_t*);
size_t               mrchatlist_get_cnt                  (mrchatlist_t*);
uint32_t             mrchatlist_get_chat_id_by_index     (mrchatlist_t*, size_t index);
uint32_t             mrchatlist_get_msg_id_by_index      (mrchatlist_t*, size_t index);
mrchat_t*            mrchatlist_get_chat_by_index        (mrchatlist_t*, size_t index); /* deprecated - result must be unref'd */
mrmsg_t*             mrchatlist_get_msg_by_index         (mrchatlist_t*, size_t index); /* deprecated - result must be unref'd */


/* Get a summary for a chatlist index. The last parameter can be set to speed up
things if the chat object is already available; if not, it is faster to pass NULL
here.  The result must be freed using mrpoortext_unref().  The returned summary
has the following format:
- m_text1:         contains the username or the strings "Me", "Draft" and so on.
                   the string may be colored by having a look at m_text1_meaning.
                   If there is no such name, the element is NULL (eg. for "No messages")
- m_text1_meaning: one of the
- m_text2          contains an excerpt of the message text or strings as "No messages".
                   may be NULL of there is no such text (eg. for the archive)
- m_timestamp      the timestamp of the message.  May be 0 if there is no
                   message
- m_state          the state of the message as one of the MR_STATE_*
                   identifiers.  0 if there is no message.
*/
mrpoortext_t*        mrchatlist_get_summary_by_index     (mrchatlist_t*, size_t index, mrchat_t*);


/* the poortext object and some function accessing it.  A poortext object
contains some strings together with their meaning and some attributes.  The
object is mainly used for summary returns of chats and chatlists */
typedef struct mrpoortext_t
{
	#define          MR_TEXT1_NORMAL    0
	#define          MR_TEXT1_DRAFT     1
	#define          MR_TEXT1_USERNAME  2
	#define          MR_TEXT1_SELF      3
	int              m_text1_meaning;

	char*            m_text1;         /* may be NULL */
	char*            m_text2;         /* may be NULL */
	time_t           m_timestamp;     /* may be 0 */
	int              m_state;         /* may be 0 */
} mrpoortext_t;
void                 mrpoortext_unref                    (mrpoortext_t*);


/*******************************************************************************
 * Handle chats
 ******************************************************************************/


/* specical chat IDs */
#define MR_CHAT_ID_DEADDROP           1 /* messages send from unknown/unwanted users to us, chats_contacts is not set up. This group may be shown normally. */
#define MR_CHAT_ID_TO_DEADDROP        2 /* messages send from us to unknown/unwanted users (this may happen when deleting chats or when using CC: in the email-program) */
#define MR_CHAT_ID_TRASH              3 /* messages that should be deleted get this chat_id; the messages are deleted from the working thread later then. This is also needed as rfc724_mid should be preset as long as the message is not deleted on the server (otherwise it is downloaded again) */
#define MR_CHAT_ID_MSGS_IN_CREATION   4 /* a message is just in creation but not yet assigned to a chat (eg. we may need the message ID to set up blobs; this avoids unready message to be send and shown) */
#define MR_CHAT_ID_STARRED            5 /* virtual chat containing all starred messages */
#define MR_CHAT_ID_ARCHIVED_LINK      6 /* a link at the end of the chatlist, if present the UI should show the button "Archived chats" */
#define MR_CHAT_ID_LAST_SPECIAL       9 /* larger chat IDs are "real" chats, their messages are "real" messages. */


/* does a chat with a given single user exist? */
uint32_t             mrmailbox_get_chat_id_by_contact_id (mrmailbox_t*, uint32_t contact_id);


/* create a normal chat with a single user */
uint32_t             mrmailbox_create_chat_by_contact_id (mrmailbox_t*, uint32_t contact_id);


/* returns message IDs, the result must be carray_free()'d */
carray*              mrmailbox_get_chat_media            (mrmailbox_t*, uint32_t chat_id, int msg_type, int or_msg_type);


/* returns message IDs, typically used for implementing notification summaries, the result must be free()'d */
carray*              mrmailbox_get_fresh_msgs            (mrmailbox_t*);


/* Archived a chat, 1=archive, 0=unarchive
Archived chats are not returned in the default chatlist returned by mrmailbox_get_chatlist(0, NULL);
instead, if there are _any_ archived chats, the pseudo-chat with the chat_id MR_CHAT_ID_ARCHIVED_LINK will be returned by
mrmailbox_get_chatlist(0, NULL).  To get a list of archived chats, use mrmailbox_get_chatlist(MR_GCL_ARCHIVED_ONLY, NULL). */
int                  mrmailbox_archive_chat              (mrmailbox_t*, uint32_t chat_id, int archive);


/* Delete a chat:
- messages are deleted from the device and the chat database entry is deleted
- messages are _not_ deleted from the server
- the chat is not blocked, so new messages from the user/the group may appear
  and the user may create the chat again
	- this is also one of the reasons, why groups are _not left_ -  this would
	  be unexpected as deleting a normal chat also does not prevent new mails
	- moreover, there may be valid reasons only to leave a group and only to
	  delete a group
	- another argument is, that leaving a group requires sending a message to
	  all group members - esp. for groups not used for a longer time, this is
	  really unexpected
- to leave a chat, use the `function int mrmailbox_remove_contact_from_chat(mailbox, chat_id, MR_CONTACT_ID_SELF)` */
int                  mrmailbox_delete_chat               (mrmailbox_t*, uint32_t chat_id);


/* Get previous/next media of a given media message (imaging eg. a virtual playlist of all audio tracks in a chat).
If there is no previous/next media, 0 is returned. */
uint32_t             mrmailbox_get_next_media            (mrmailbox_t*, uint32_t curr_msg_id, int dir);


/* mrmailbox_get_chat_contacts() returns contact IDs, the result must be carray_free()'d.
- for normal chats, the function always returns exactly one contact MR_CONTACT_ID_SELF is _not_ returned.
- for group chats all members are returned, MR_CONTACT_ID_SELF is returned explicitly as it may happen that oneself gets removed from a still existing group
- for the deaddrop, all contacts are returned, MR_CONTACT_ID_SELF is not added */
carray*              mrmailbox_get_chat_contacts         (mrmailbox_t*, uint32_t chat_id);


/* mrmailbox_get_chat_msgs() returns a view on a chat.
The function returns an array of message IDs, which must be carray_free()'d by
the caller.  Optionally, some special markers added to the ID-array may help to
implement virtual lists:
- If you add the flag MR_GCM_ADD_DAY_MARKER, the marker MR_MSG_ID_DAYMARKER will
  be added before each day (regarding the local timezone)
- If you specify marker1before, the id MR_MSG_ID_MARKER1 will be added just
before the given ID.*/
#define MR_GCM_ADDDAYMARKER 0x01
carray*              mrmailbox_get_chat_msgs             (mrmailbox_t*, uint32_t chat_id, uint32_t flags, uint32_t marker1before);


/* Search messages containing the given query string.
Searching can be done globally (chat_id=0) or in a specified chat only (chat_id
set).
- The function returns an array of messages IDs which must be carray_free()'d
  by the caller.
- If nothing can be found, the function returns NULL.
Global chat results are typically displayed using mrmsg_get_summary(), chat
search results may just hilite the corresponding messages and present a
prev/next button. */
carray*              mrmailbox_search_msgs               (mrmailbox_t*, uint32_t chat_id, const char* query);


/* Get a chat object of type mrchat_t by a chat_id.
To access the mrchat_t object, see mrchat.h
The result must be unref'd using mrchat_unref(). */
mrchat_t*            mrmailbox_get_chat                  (mrmailbox_t*, uint32_t chat_id);


/* The chat object and some function for helping accessing it.
The chat object is not updated.  If you want an update, you have to recreate the object. */
typedef struct mrchat_t
{
	uint32_t          m_id;

	#define          MR_CHAT_UNDEFINED    0
	#define          MR_CHAT_NORMAL     100 /* a normal chat is a chat with a single contact, chats_contacts contains one record for the user, MR_CONTACT_ID_SELF is not added. */
	#define          MR_CHAT_GROUP      120 /* a group chat, chats_contacts conain all group members, incl. MR_CONTACT_ID_SELF */
	int              m_type;

	char*            m_name;            /* NULL if unset */
	time_t           m_draft_timestamp; /* 0 if there is no draft */
	char*            m_draft_text;      /* NULL if unset */
	mrmailbox_t*     m_mailbox;         /* != NULL */
	char*            m_grpid;           /* NULL if unset */
	int              m_archived;        /* 1=chat archived, this state should always be shown the UI, eg. the search will also return archived chats */
	mrparam_t*       m_param;           /* != NULL */
} mrchat_t;
void          mrchat_unref                 (mrchat_t*);
char*         mrchat_get_subtitle          (mrchat_t*); /* either the email-address or the number of group members, the result must be free()'d! */
int           mrchat_get_total_msg_count   (mrchat_t*);
int           mrchat_get_fresh_msg_count   (mrchat_t*);
int           mrchat_set_draft             (mrchat_t*, const char*); /* Save draft in object and, if changed, in database.  May result in "MR_EVENT_MSGS_UPDATED".  Returns true/false. */


/* save message in database and send it, the given message object is not unref'd by the function but some fields are set up! */
uint32_t      mrchat_send_msg              (mrchat_t*, mrmsg_t*);



/*******************************************************************************
 * Handle group chats
 ******************************************************************************/


/* Create a new group chat.  After creation, the groups has one member with the ID MR_CONTACT_ID_SELF. */
uint32_t             mrmailbox_create_group_chat         (mrmailbox_t*, const char* name);


/* Check of a given contact_id is a member of a group chat defined by chat_id.
Returns values: 1=contact is in chat, 0=contact is not in chat */
int                  mrmailbox_is_contact_in_chat        (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);


/* Add/remove a given contact_id to a  groupchat defined by chat_id. */
int                  mrmailbox_add_contact_to_chat       (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);
int                  mrmailbox_remove_contact_from_chat  (mrmailbox_t*, uint32_t chat_id, uint32_t contact_id);


/* Set the name of a group chat.  The name is changed locally _and_ for all members of the chat.
the latter is done by a special message send to all users. */
int                  mrmailbox_set_chat_name             (mrmailbox_t*, uint32_t chat_id, const char* name);


/* Set the group image of a group chat or delete it by passing NULL to the
`image` parameter.
The image is changed locally _and_ for all members of the chat.  The latter is
done by a special message send to all users. */
int                  mrmailbox_set_chat_image            (mrmailbox_t*, uint32_t chat_id, const char* image);


/* mrmailbox_marknoticed_chat() marks all message in a whole chat as NOTICED.
NOTICED messages are no longer FRESH and do not count as being unseen.  IMAP/MDNs is not done for noticed messages.
See also mrmailbox_marknoticed_contact() and mrmailbox_markseen_msgs() */
int                  mrmailbox_marknoticed_chat     (mrmailbox_t*, uint32_t chat_id);


/*******************************************************************************
 * Handle messages
 ******************************************************************************/


/* Get an informational text for a single message. the text is multiline and may contain eg. the raw text of the message.
The result must be unref'd using free(). */
char*                mrmailbox_get_msg_info         (mrmailbox_t*, uint32_t msg_id);


/* Delete a list of messages. The messages are deleted on the current device and on the IMAP server. */
int                  mrmailbox_delete_msgs          (mrmailbox_t*, const uint32_t* msg_ids, int msg_cnt);


/* Forward a list of messages to another chat. */
int                  mrmailbox_forward_msgs         (mrmailbox_t*, const uint32_t* msg_ids, int msg_cnt, uint32_t chat_id);


/* mrmailbox_marknoticed_contact() marks all messages send by the given contact as NOTICED.
See also mrmailbox_marknoticed_chat() and mrmailbox_markseen_msgs() */
int                  mrmailbox_marknoticed_contact  (mrmailbox_t*, uint32_t contact_id);


/* mrmailbox_markseen_msgs() marks a message as SEEN, updates the IMAP state and sends MDNs.
if the message is not in a real chat (eg. a contact request), the message is only marked as NOTICED and no IMAP/MDNs is done.
See also mrmailbox_marknoticed_chat() and mrmailbox_marknoticed_contact() */
int                  mrmailbox_markseen_msgs        (mrmailbox_t*, const uint32_t* msg_ids, int msg_cnt);


/* star/unstar messages */
int                  mrmailbox_star_msgs            (mrmailbox_t*, const uint32_t* msg_ids, int msg_cnt, int star);


/* Get a single message object of the type mrmsg_t - for a list, see mrmailbox_get_chatlist() */
mrmsg_t*             mrmailbox_get_msg              (mrmailbox_t*, uint32_t msg_id);


/* The message object and some function for helping accessing it.
The message object is not updated.  If you want an update, you have to recreate the object. */
typedef struct mrmsg_t
{
	#define          MR_MSG_ID_MARKER1      1 /* any user-defined marker */
	#define          MR_MSG_ID_DAYMARKER    9 /* in a list, the next message is on a new day, useful to show headlines */
	#define          MR_MSG_ID_LAST_SPECIAL 9
	uint32_t         m_id;

	uint32_t         m_from_id;               /* contact, 0=unset, 1=self .. >9=real contacts */
	uint32_t         m_to_id;                 /* contact, 0=unset, 1=self .. >9=real contacts */
	uint32_t         m_chat_id;               /* the chat, the message belongs to: 0=unset, 1=unknwon sender .. >9=real chats */
	time_t           m_timestamp;             /* unix time the message was sended */

	#define          MR_MSG_UNDEFINED       0
	#define          MR_MSG_TEXT           10
	#define          MR_MSG_IMAGE          20 /* param: MRP_FILE, MRP_WIDTH, MRP_HEIGHT */
	#define          MR_MSG_GIF            21 /* param: MRP_FILE, MRP_WIDTH, MRP_HEIGHT */
	#define          MR_MSG_AUDIO          40 /* param: MRP_FILE, MRP_DURATION */
	#define          MR_MSG_VOICE          41 /* param: MRP_FILE, MRP_DURATION */
	#define          MR_MSG_VIDEO          50 /* param: MRP_FILE, MRP_WIDTH, MRP_HEIGHT, MRP_DURATION */
	#define          MR_MSG_FILE           60 /* param: MRP_FILE */
	int              m_type;

	#define          MR_STATE_UNDEFINED      0
	#define          MR_STATE_IN_FRESH      10 /* incoming message, not noticed nor seen */
	#define          MR_STATE_IN_NOTICED    13 /* incoming message noticed (eg. chat opened but message not yet read - noticed messages are not counted as unread but did not marked as read nor resulted in MDNs) */
	#define          MR_STATE_IN_SEEN       16 /* incoming message marked as read on IMAP and MDN may be send */
	#define          MR_STATE_OUT_PENDING   20 /* hit "send" button - but the message is pending in some way, maybe we're offline (no checkmark) */
	#define          MR_STATE_OUT_ERROR     24 /* unrecoverable error (recoverable errors result in pending messages) */
	#define          MR_STATE_OUT_DELIVERED 26 /* outgoing message successfully delivered to server (one checkmark) */
	#define          MR_STATE_OUT_MDN_RCVD  28 /* outgoing message read (two checkmarks; this requires goodwill on the receiver's side) */
	int              m_state;

	char*            m_text;      /* message text or NULL if unset */
	mrparam_t*       m_param;     /* MRP_FILE, MRP_WIDTH, MRP_HEIGHT etc. depends on the type, != NULL */
	int              m_starred;
	int              m_is_msgrmsg;

	mrmailbox_t*     m_mailbox;   /* may be NULL, set on loading from database and on sending */
	char*            m_rfc724_mid;
	char*            m_server_folder;
	uint32_t         m_server_uid;
} mrmsg_t;
mrmsg_t*             mrmsg_new                    ();
void                 mrmsg_unref                  (mrmsg_t*); /* this also free()s all strings; so if you set up the object yourself, make sure to use strdup()! */
void                 mrmsg_empty                  (mrmsg_t*);


/* Get a summary for a message. The last parameter can be set to speed up
things if the chat object is already available; if not, it is faster to pass NULL
here.  The result must be freed using mrpoortext_unref().
Typically used to display a search result.
The returned summary is similar to mrchatlist_get_summary(), however, without
"draft", "no messages" and so on. */
mrpoortext_t*        mrmsg_get_summary            (mrmsg_t*, mrchat_t*);


/* Get a message summary as a single line of text.  Typically used for
notifications.  The returned value must be free()'d. */
char*                mrmsg_get_summarytext        (mrmsg_t*, int approx_characters);


/* Check if a padlock should be shown beside the message. */
int                  mrmsg_show_padlock           (mrmsg_t*);


/* Returns base file name without part, if appropriate.  The returned value must
be free()'d */
char*                mrmsg_get_filename           (mrmsg_t*);


/* Returns real author (as text1, this is not always the sender, NULL if
unknown) and title (text2, NULL if unknown) */
mrpoortext_t*        mrmsg_get_mediainfo          (mrmsg_t*);


/* check if a message is still in creation. */
int                  mrmsg_is_increation          (mrmsg_t*);


/* can be used to add some additional, persistent information to a messages record */
void                 mrmsg_save_param_to_disk     (mrmsg_t*);


/* Only sets the text field, MR_MSG_TEXT must be set additionally.
Previously texts are free()'d. */
void                 mrmsg_set_text               (mrmsg_t*, const char* text);


/*******************************************************************************
 * Handle contacts
 ******************************************************************************/


/* specical contact IDs */
#define MR_CONTACT_ID_SELF         1
#define MR_CONTACT_ID_SYSTEM       2
#define MR_CONTACT_ID_LAST_SPECIAL 9


/* returns known and unblocked contacts, the result must be carray_free()'d.
To get information about a single contact, see mrmailbox_get_contact() */
carray*              mrmailbox_get_known_contacts   (mrmailbox_t*, const char* query);


/* create a single contact and return the ID.
If the contact's email address already exists, the name is updated and the origin is increased to "manually created". */
uint32_t             mrmailbox_create_contact       (mrmailbox_t*, const char* name, const char* addr);


/* Contact blocking handling.
mrmailbox_block_contact() may result in a MR_EVENT_BLOCKING_CHANGED event. */
int                  mrmailbox_get_blocked_count    (mrmailbox_t*);
carray*              mrmailbox_get_blocked_contacts (mrmailbox_t*);
int                  mrmailbox_block_contact        (mrmailbox_t*, uint32_t contact_id, int block);


/* add a number of contacts in the format:
`Name one\nAddress one\nName two\Address two`
If the contact's email address already exists, the name is updated and the origin is increased to "manually created". */
int                  mrmailbox_add_address_book     (mrmailbox_t*, const char*);


/* get a multi-line encryption info, used to compare the fingerprints. */
char*                mrmailbox_get_contact_encrinfo (mrmailbox_t*, uint32_t contact_id);


/* delete a contact from the local device.  It may happen that this is not possible as the contact is used.
In this case, the contact can be blocked. */
int                  mrmailbox_delete_contact       (mrmailbox_t*, uint32_t contact_id);


/* Get a single contact object of the type mrcontact_t - for a list, see mrmailbox_get_known_contacts() */
mrcontact_t*         mrmailbox_get_contact          (mrmailbox_t*, uint32_t contact_id);


/* The contact object and some function for helping accessing it.
The contact object is not updated.  If you want an update, you have to recreate the object. */
typedef struct mrcontact_t
{
	uint32_t         m_magic;
	uint32_t         m_id;
	char*            m_name;    /* may be NULL or empty, this name should not be spreaded as it may be "Daddy" and so on; initially set to m_authname */
	char*            m_authname;/* may be NULL or empty, this is the name authorized by the sender, only this name may be speaded to others, eg. in To:-lists; for displaying in the app, use m_name */
	char*            m_addr;    /* may be NULL or empty */
	int              m_origin;
	int              m_blocked;
} mrcontact_t;
void                 mrcontact_unref           (mrcontact_t*);


/*******************************************************************************
 * Additional parameter handling
 ******************************************************************************/


/* The parameter object as used eg. by mrchat_t or mrmsg_t.
To access the single parameters use the setter and getter functions with an MRP_* contant */
typedef struct mrparam_t
{
	char*    m_packed;    /* != NULL */
} mrparam_t;
int           mrparam_exists       (mrparam_t*, int key);
char*         mrparam_get          (mrparam_t*, int key, const char* def); /* the value may be an empty string, "def" is returned only if the value unset.  The result must be free()'d in any case. */
int32_t       mrparam_get_int      (mrparam_t*, int key, int32_t def);
void          mrparam_set          (mrparam_t*, int key, const char* value);
void          mrparam_set_int      (mrparam_t*, int key, int32_t value);


/* Parameters availalble */
#define MRP_FILE              'f'  /* for msgs */
#define MRP_WIDTH             'w'  /* for msgs */
#define MRP_HEIGHT            'h'  /* for msgs */
#define MRP_DURATION          'd'  /* for msgs */
#define MRP_MIMETYPE          'm'  /* for msgs */
#define MRP_AUTHORNAME        'N'  /* for msgs: name of author or artist */
#define MRP_TRACKNAME         'n'  /* for msgs: name of author or artist */
#define MRP_GUARANTEE_E2EE    'c'  /* for msgs: 'c'rypted in original/guarantee E2EE or the message is not send */
#define MRP_ERRONEOUS_E2EE    'e'  /* for msgs: decrypted with validation errors or without mutual set, if neither 'c' nor 'e' are preset, the messages is only transport encrypted */
#define MRP_WANTS_MDN         'r'  /* for msgs: an incoming message which requestes a MDN (aka read receipt) */
#define MRP_FORWARDED         'a'  /* for msgs */
#define MRP_SYSTEM_CMD        'S'  /* for msgs */
#define MRP_SYSTEM_CMD_PARAM  'E'  /* for msgs */

#define MRP_SERVER_FOLDER     'Z'  /* for jobs */
#define MRP_SERVER_UID        'z'  /* for jobs */
#define MRP_TIMES             't'  /* for jobs: times a job was tried */
#define MRP_TIMES_INCREATION  'T'  /* for jobs: times a job was tried, used for increation */

#define MRP_REFERENCES        'R'  /* for groups and chats: References-header last used for a chat */
#define MRP_UNPROMOTED        'U'  /* for groups */
#define MRP_PROFILE_IMAGE     'i'  /* for groups and contacts */
#define MRP_DEL_AFTER_SEND    'P'  /* for groups and msgs: physically delete group after message sending if msg-value matches group-value */



/*******************************************************************************
 * Events
 ******************************************************************************/


/* The following events may be passed to the callback given to mrmailbox_new() */


/* Information, should not be reported, can be logged,
data1=0, data2=info string */
#define MR_EVENT_INFO                     100


/* Warning, should not be reported, should be logged
data1=0, data2=warning string */
#define MR_EVENT_WARNING                  300


/* Error, must be reported to the user by a non-disturbing bubble or so.
data1=error code MR_ERR_*, see below, data2=error string */
#define MR_EVENT_ERROR                    400


/* one or more messages changed for some reasons in the database - added or removed.
For added messages: data1=chat_id, data2=msg_id */
#define MR_EVENT_MSGS_CHANGED             2000


/* For fresh messages from the INBOX, MR_EVENT_INCOMING_MSG is send;
data1=chat_id, data2=msg_id */
#define MR_EVENT_INCOMING_MSG             2005


/* a single message is send successfully (state changed from PENDING/SENDING to DELIVERED);
data1=chat_id, data2=msg_id */
#define MR_EVENT_MSG_DELIVERED            2010


/* a single message is read by the receiver (state changed from DELIVERED to READ);
data1=chat_id, data2=msg_id */
#define MR_EVENT_MSG_READ                 2015


/* group name/image changed or members added/removed */
#define MR_EVENT_CHAT_MODIFIED            2020


/* contact(s) created, renamed, blocked or deleted */
#define MR_EVENT_CONTACTS_CHANGED         2030


/* connection state changed,
data1=0:failed-not-connected, 1:configured-and-connected */
#define MR_EVENT_CONFIGURE_ENDED          2040


/* data1=percent */
#define MR_EVENT_CONFIGURE_PROGRESS       2041


/* mrmailbox_imex() done:
data1=0:failed, 1=success */
#define MR_EVENT_IMEX_ENDED               2050


/* data1=permille */
#define MR_EVENT_IMEX_PROGRESS            2051


/* file written, event may be needed to make the file public to some system services
data1=file name, data2=mime type */
#define MR_EVENT_IMEX_FILE_WRITTEN        2052


/* The following events are functions that should be provided by the frontends */


/* check, if the system is online currently
ret=0: not online, ret=1: online */
#define MR_EVENT_IS_ONLINE                2080


/* get a string from the frontend, data1=MR_STR_*, ret=string which will be free()'d by the backend */
#define MR_EVENT_GET_STRING               2091


/* synchronous http/https(!) call, data1=url, ret=content which will be free()'d by the backend, 0 on errors */
#define MR_EVENT_GET_QUANTITY_STRING      2092


/* synchronous http/https(!) call, data1=url, ret=content which will be free()'d by the backend, 0 on errors */
#define MR_EVENT_HTTP_GET                 2100

/* acquire wakeLock (data1=1) or release it (data1=0), the backend does not make nested or unsynchronized calls */
#define MR_EVENT_WAKE_LOCK                2110


/* Error codes */
#define MR_ERR_SELF_NOT_IN_GROUP          1
#define MR_ERR_NONETWORK                  2


/* Strings requested by MR_EVENT_GET_STRING and MR_EVENT_GET_QUANTITY_STRING */
#define MR_STR_FREE_                      0
#define MR_STR_NOMESSAGES                 1
#define MR_STR_SELF                       2
#define MR_STR_DRAFT                      3
#define MR_STR_MEMBER                     4
#define MR_STR_CONTACT                    6
#define MR_STR_VOICEMESSAGE               7
#define MR_STR_DEADDROP                   8
#define MR_STR_IMAGE                      9
#define MR_STR_VIDEO                      10
#define MR_STR_AUDIO                      11
#define MR_STR_FILE                       12
#define MR_STR_STATUSLINE                 13
#define MR_STR_NEWGROUPDRAFT              14
#define MR_STR_MSGGRPNAME                 15
#define MR_STR_MSGGRPIMGCHANGED           16
#define MR_STR_MSGADDMEMBER               17
#define MR_STR_MSGDELMEMBER               18
#define MR_STR_MSGGROUPLEFT               19
#define MR_STR_ERROR                      20
#define MR_STR_SELFNOTINGRP               21
#define MR_STR_NONETWORK                  22
#define MR_STR_GIF                        23
#define MR_STR_ENCRYPTEDMSG               24
#define MR_STR_ENCR_E2E                   25
#define MR_STR_ENCR_TRANSP                27
#define MR_STR_ENCR_NONE                  28
#define MR_STR_FINGERPRINTS               30
#define MR_STR_READRCPT                   31
#define MR_STR_READRCPT_MAILBODY          32
#define MR_STR_MSGGRPIMGDELETED           33
#define MR_STR_E2E_FINE                   34
#define MR_STR_E2E_NO_AUTOCRYPT           35
#define MR_STR_E2E_DIS_BY_YOU             36
#define MR_STR_E2E_DIS_BY_RCPT            37
#define MR_STR_ARCHIVEDCHATS              40
#define MR_STR_STARREDMSGS                41


/*******************************************************************************
 * Import/export and Tools
 ******************************************************************************/


/* mrmailbox_imex() imports and exports export keys, backup etc.
Function, sends MR_EVENT_IMEX_* events.
To avoid double slashes, the given directory should not end with a slash.
_what_ to export is defined by a MR_IMEX_* constant */
#define MR_IMEX_CANCEL                      0
#define MR_IMEX_EXPORT_SELF_KEYS            1 /* param1 is a directory where the keys are written to */
#define MR_IMEX_IMPORT_SELF_KEYS            2 /* param1 is a directory where the keys are searched in and read from */
#define MR_IMEX_EXPORT_BACKUP              11 /* param1 is a directory where the backup is written to */
#define MR_IMEX_IMPORT_BACKUP              12 /* param1 is the file with the backup to import */
#define MR_IMEX_EXPORT_SETUP_MESSAGE       20 /* param1 is a directory where the setup file is written to */
#define MR_BAK_PREFIX                      "delta-chat"
#define MR_BAK_SUFFIX                      "bak"
void                 mrmailbox_imex                 (mrmailbox_t*, int what, const char* param1, const char* setup_code);


/* returns backup_file or NULL, may only be used on fresh installations (mrmailbox_is_configured() returns 0); returned strings must be free()'d */
char*                mrmailbox_imex_has_backup      (mrmailbox_t*, const char* dir);


/* Check if the user is authorized by the given password in some way. This is to promt for the password eg. before exporting keys/backup. */
int                  mrmailbox_check_password       (mrmailbox_t*, const char* pw);


/* should be written down by the user, forwareded to mrmailbox_imex() for encryption then, must be wiped and free()'d after usage */
char*                mrmailbox_create_setup_code    (mrmailbox_t*);


/* mainly for testing, import a folder with eml-files, a single eml-file, e-mail plus public key, ... NULL for the last command */
int                  mrmailbox_poke_spec            (mrmailbox_t*, const char* spec);


/* The library tries itself to stay alive. For this purpose there is an additional
"heartbeat" thread that checks if the IDLE-thread is up and working. This check is done about every minute.
However, depending on the operating system, this thread may be delayed or stopped, if this is the case you can
force additional checks manually by just calling mrmailbox_heartbeat() about every minute.
If in doubt, call this function too often, not too less :-) */
void                 mrmailbox_heartbeat            (mrmailbox_t*);


/* Execute a simple command.
- This function is not neeed for the normal program flow but only for debugging purposes
  to give users some special power to the database and to the connection.
- For security reasons, the first command must be `auth <password>`; once authorized, this is
  is valid for _all_ exising and future mailbox objects.  You can skip the authorisation process
  by calling mrmailbox_cmdline_skip_auth()
- The returned result may contain multiple lines  separated by `\n` and must be
  free()'d if no longer needed.
- some commands may use mrmailbox_log_info() for additional output.
- The command `help` gives an overview */
char*                mrmailbox_cmdline              (mrmailbox_t*, const char* cmd);


/* If the command line authorisation (see mrmailbox_cmdline()) is not desired, eg. for a command line client,
you can skip this using mrmailbox_cmdline_skip_auth().*/
void                 mrmailbox_cmdline_skip_auth    ();


/* carray tools, already defined are things as
unsigned unt carray_count() */
uint32_t             carray_get_uint32              (carray*, unsigned int index);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRMAILBOX_H__ */
