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

	time_t                last_fullread_time;

	int                   idle_set_up;
	char*                 selected_folder;
	int                   selected_folder_needs_expunge;
	int                   should_reconnect;

	int                   can_idle;
	int                   has_xlist;
	char*                 moveto_folder;// Folder, where reveived chat messages should go to.  Normally DC_CHATS_FOLDER, may be NULL to leave them in the INBOX
	char*                 sent_folder;  // Folder, where send messages should go to.  Normally DC_CHATS_FOLDER.
	char                  imap_delimiter;/* IMAP Path separator. Set as a side-effect in list_folders__ */

	pthread_cond_t        watch_cond;
	pthread_mutex_t       watch_condmutex;
	int                   watch_condflag;

	struct mailimap_fetch_type* fetch_type_uid;
	struct mailimap_fetch_type* fetch_type_message_id;
	struct mailimap_fetch_type* fetch_type_body;
	struct mailimap_fetch_type* fetch_type_flags;

	dc_get_config_t       get_config;
	dc_set_config_t       set_config;
	dc_receive_imf_t      receive_imf;
	void*                 userData;
	dc_context_t*         context;

	int                   log_connect_errors;
	int                   skip_log_capabilities;

} dc_imap_t;


dc_imap_t* dc_imap_new               (dc_get_config_t, dc_set_config_t, dc_receive_imf_t, void* userData, dc_context_t*);
void       dc_imap_unref             (dc_imap_t*);

int        dc_imap_connect           (dc_imap_t*, const dc_loginparam_t*);
void       dc_imap_disconnect        (dc_imap_t*);
int        dc_imap_is_connected      (const dc_imap_t*);
int        dc_imap_fetch             (dc_imap_t*);

void       dc_imap_idle              (dc_imap_t*);
void       dc_imap_interrupt_idle    (dc_imap_t*);

int        dc_imap_append_msg        (dc_imap_t*, time_t timestamp, const char* data_not_terminated, size_t data_bytes, char** ret_server_folder, uint32_t* ret_server_uid);

#define    DC_MS_ALSO_MOVE          0x01
#define    DC_MS_SET_MDNSent_FLAG   0x02
#define    DC_MS_MDNSent_JUST_SET   0x10
int        dc_imap_markseen_msg      (dc_imap_t*, const char* folder, uint32_t server_uid, int ms_flags, char** ret_server_folder, uint32_t* ret_server_uid, int* ret_ms_flags); /* only returns 0 on connection problems; we should try later again in this case */

int        dc_imap_delete_msg        (dc_imap_t*, const char* rfc724_mid, const char* folder, uint32_t server_uid); /* only returns 0 on connection problems; we should try later again in this case */


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif // __DC_IMAP_H__

