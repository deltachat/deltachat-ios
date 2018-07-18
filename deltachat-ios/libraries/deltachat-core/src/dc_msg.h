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


#ifndef __DC_MSG_H__
#define __DC_MSG_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct dc_param_t   dc_param_t;
typedef struct sqlite3_stmt sqlite3_stmt;


/** the structure behind dc_msg_t */
struct _dc_msg
{
	/** @privatesection */

	uint32_t        magic;

	/**
	 * Message ID.  Never 0.
	 */
	uint32_t        id;


	/**
	 * Contact ID of the sender.  Never 0. See dc_contact_t::id for special IDs.
	 * Use dc_get_contact() to load details about this contact.
	 */
	uint32_t        from_id;


	/**
	 * Contact ID of the recipient. Never 0. See dc_contact_t::id for special IDs.
	 * Use dc_get_contact() to load details about this contact.
	 */
	uint32_t        to_id;


	/**
	 * Chat ID the message belongs to. Never 0. See dc_chat_t::id for special IDs.
	 * Use dc_get_chat() to load details about the chat.
	 */
	uint32_t        chat_id;


	int             type;                   /**< Message type. It is recommended to use dc_msg_set_type() and dc_msg_get_type() to access this field. */

	int             state;                  /**< Message state. It is recommended to use dc_msg_get_state() to access this field. */

	int             hidden;                 /**< Used eg. for handshaking messages. */

	time_t          timestamp;              /**< Unix time for sorting. 0 if unset. */
	time_t          timestamp_sent;         /**< Unix time the message was sent. 0 if unset. */
	time_t          timestamp_rcvd;         /**< Unix time the message was recveived. 0 if unset. */

	char*           text;                   /**< Message text.  NULL if unset.  It is recommended to use dc_msg_set_text() and dc_msg_get_text() to access this field. */

	dc_context_t*   context;                /**< may be NULL, set on loading from database and on sending */
	char*           rfc724_mid;             /**< The RFC-742 Message-ID */
	char*           server_folder;          /**< Folder where the message was last seen on the server */
	uint32_t        server_uid;             /**< UID last seen on the server for this message */
	int             is_msgrmsg;             /**< Set to 1 if the message was sent by another messenger. 0 otherwise. */
	int             starred;                /**< Starred-state of the message. 0=no, 1=yes. */
	int             chat_blocked;           /**< Internal */
	dc_param_t*     param;                  /**< Additional paramter for the message. Never a NULL-pointer. It is recommended to use setters and getters instead of accessing this field directly. */
};


int             dc_msg_load_from_db                   (dc_msg_t*, dc_context_t*, uint32_t id);
int             dc_msg_is_increation                  (const dc_msg_t*);
char*           dc_msg_get_summarytext_by_raw         (int type, const char* text, dc_param_t*, int approx_bytes, dc_context_t*); /* the returned value must be free()'d */
void            dc_msg_save_param_to_disk             (dc_msg_t*);
void            dc_msg_guess_msgtype_from_suffix      (const char* pathNfilename, int* ret_msgtype, char** ret_mime);
void            dc_msg_get_authorNtitle_from_filename (const char* pathNfilename, char** ret_author, char** ret_title);

#define DC_MSG_NEEDS_ATTACHMENT(a)         ((a)==DC_MSG_IMAGE || (a)==DC_MSG_GIF || (a)==DC_MSG_AUDIO || (a)==DC_MSG_VOICE || (a)==DC_MSG_VIDEO || (a)==DC_MSG_FILE)
#define DC_MSG_MAKE_FILENAME_SEARCHABLE(a) ((a)==DC_MSG_AUDIO || (a)==DC_MSG_FILE || (a)==DC_MSG_VIDEO) /* add filename.ext (without path) to text? this is needed for the fulltext search. The extension is useful to get all PDF, all MP3 etc. */
#define DC_MSG_MAKE_SUFFIX_SEARCHABLE(a)   ((a)==DC_MSG_IMAGE || (a)==DC_MSG_GIF || (a)==DC_MSG_VOICE)


/* as we do not cut inside words, this results in about 32-42 characters.
Do not use too long subjects - we add a tag after the subject which gets truncated by the clients otherwise.
It should also be very clear, the subject is _not_ the whole message.
The value is also used for CC:-summaries */
#define DC_APPROX_SUBJECT_CHARS 32


// Context functions to work with messages
void            dc_update_msg_chat_id                      (dc_context_t*, uint32_t msg_id, uint32_t chat_id);
void            dc_update_msg_state                        (dc_context_t*, uint32_t msg_id, int state);
void            dc_set_msg_failed                          (dc_context_t*, uint32_t msg_id, const char* error);
int             dc_mdn_from_ext                            (dc_context_t*, uint32_t from_id, const char* rfc724_mid, time_t, uint32_t* ret_chat_id, uint32_t* ret_msg_id); /* returns 1 if an event should be send */
size_t          dc_get_real_msg_cnt                        (dc_context_t*); /* the number of messages assigned to real chat (!=deaddrop, !=trash) */
size_t          dc_get_deaddrop_msg_cnt                    (dc_context_t*);
int             dc_rfc724_mid_cnt                          (dc_context_t*, const char* rfc724_mid);
uint32_t        dc_rfc724_mid_exists                       (dc_context_t*, const char* rfc724_mid, char** ret_server_folder, uint32_t* ret_server_uid);
void            dc_update_server_uid                       (dc_context_t*, const char* rfc724_mid, const char* server_folder, uint32_t server_uid);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_MSG_H__ */
