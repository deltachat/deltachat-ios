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


#ifndef __DC_LOGINPARAM_H__
#define __DC_LOGINPARAM_H__
#ifdef __cplusplus
extern "C" {
#endif


/**
 * Library-internal.
 */
typedef struct dc_loginparam_t
{
	/**  @privatesection */

	/* IMAP/POP3 - all pointers may be NULL if unset, public read */
	char*         addr;
	char*         mail_server;
	char*         mail_user;
	char*         mail_pw;
	uint16_t      mail_port;

	/* SMTP - all pointers may be NULL if unset, public read */
	char*         send_server;
	char*         send_user;
	char*         send_pw;
	int           send_port;

	/* Server options*/
	#define       DC_LP_AUTH_XOAUTH2                 0x2
	#define       DC_LP_AUTH_NORMAL                  0x4
	#define       DC_LP_AUTH_FLAGS                  (DC_LP_AUTH_XOAUTH2|DC_LP_AUTH_NORMAL) /* if none of these flags are set, the default is choosen */

	#define       DC_LP_IMAP_SOCKET_STARTTLS       0x100
	#define       DC_LP_IMAP_SOCKET_SSL            0x200
	#define       DC_LP_IMAP_SOCKET_PLAIN          0x400
	#define       DC_LP_IMAP_SOCKET_FLAGS           (DC_LP_IMAP_SOCKET_STARTTLS|DC_LP_IMAP_SOCKET_SSL|DC_LP_IMAP_SOCKET_PLAIN) /* if none of these flags are set, the default is choosen */

	#define       DC_LP_SMTP_SOCKET_STARTTLS     0x10000
	#define       DC_LP_SMTP_SOCKET_SSL          0x20000
	#define       DC_LP_SMTP_SOCKET_PLAIN        0x40000
	#define       DC_LP_SMTP_SOCKET_FLAGS           (DC_LP_SMTP_SOCKET_STARTTLS|DC_LP_SMTP_SOCKET_SSL|DC_LP_SMTP_SOCKET_PLAIN) /* if none of these flags are set, the default is choosen */

	#define       DC_NO_EXTRA_IMAP_UPLOAD      0x2000000
	#define       DC_NO_MOVE_TO_CHATS          0x4000000

	int           server_flags;
} dc_loginparam_t;


dc_loginparam_t* dc_loginparam_new          ();
void             dc_loginparam_unref        (dc_loginparam_t*);
void             dc_loginparam_empty        (dc_loginparam_t*); /* clears all data and frees its memory. All pointers are NULL after this function is called. */
void             dc_loginparam_read         (dc_loginparam_t*, dc_sqlite3_t*, const char* prefix);
void             dc_loginparam_write        (const dc_loginparam_t*, dc_sqlite3_t*, const char* prefix);
char*            dc_loginparam_get_readable (const dc_loginparam_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_LOGINPARAM_H__ */

