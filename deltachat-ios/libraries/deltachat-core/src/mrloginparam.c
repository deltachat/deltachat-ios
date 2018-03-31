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


#include "mrmailbox_internal.h"
#include "mrloginparam.h"


/*******************************************************************************
 * Main interface
 ******************************************************************************/


mrloginparam_t* mrloginparam_new()
{
	mrloginparam_t* ths = NULL;

	if( (ths=calloc(1, sizeof(mrloginparam_t)))==NULL ) {
		exit(22); /* cannot allocate little memory, unrecoverable error */
	}

	return ths;
}


void mrloginparam_unref(mrloginparam_t* ths)
{
	if( ths==NULL ) {
		return;
	}

	mrloginparam_empty(ths);
	free(ths);
}


void mrloginparam_empty(mrloginparam_t* ths)
{
	if( ths == NULL ) {
		return; /* ok, but nothing to do */
	}

	free(ths->m_addr);        ths->m_addr        = NULL;
	free(ths->m_mail_server); ths->m_mail_server = NULL;
	                          ths->m_mail_port   = 0;
	free(ths->m_mail_user);   ths->m_mail_user   = NULL;
	free(ths->m_mail_pw);     ths->m_mail_pw     = NULL;
	free(ths->m_send_server); ths->m_send_server = NULL;
	                          ths->m_send_port   = 0;
	free(ths->m_send_user);   ths->m_send_user   = NULL;
	free(ths->m_send_pw);     ths->m_send_pw     = NULL;
	                          ths->m_server_flags= 0;
}


void mrloginparam_read__(mrloginparam_t* ths, mrsqlite3_t* sql, const char* prefix)
{
	char* key = NULL;
	#define MR_PREFIX(a) sqlite3_free(key); key=sqlite3_mprintf("%s%s", prefix, (a));

	mrloginparam_empty(ths);

	MR_PREFIX("addr");        ths->m_addr        = mrsqlite3_get_config__    (sql, key, NULL);

	MR_PREFIX("mail_server"); ths->m_mail_server = mrsqlite3_get_config__    (sql, key, NULL);
	MR_PREFIX("mail_port");   ths->m_mail_port   = mrsqlite3_get_config_int__(sql, key, 0);
	MR_PREFIX("mail_user");   ths->m_mail_user   = mrsqlite3_get_config__    (sql, key, NULL);
	MR_PREFIX("mail_pw");     ths->m_mail_pw     = mrsqlite3_get_config__    (sql, key, NULL);

	MR_PREFIX("send_server"); ths->m_send_server = mrsqlite3_get_config__    (sql, key, NULL);
	MR_PREFIX("send_port");   ths->m_send_port   = mrsqlite3_get_config_int__(sql, key, 0);
	MR_PREFIX("send_user");   ths->m_send_user   = mrsqlite3_get_config__    (sql, key, NULL);
	MR_PREFIX("send_pw");     ths->m_send_pw     = mrsqlite3_get_config__    (sql, key, NULL);

	MR_PREFIX("server_flags");ths->m_server_flags= mrsqlite3_get_config_int__(sql, key, 0);

	sqlite3_free(key);
}


void mrloginparam_write__(const mrloginparam_t* ths, mrsqlite3_t* sql, const char* prefix)
{
	char* key = NULL;

	MR_PREFIX("addr");         mrsqlite3_set_config__    (sql, key, ths->m_addr);

	MR_PREFIX("mail_server");  mrsqlite3_set_config__    (sql, key, ths->m_mail_server);
	MR_PREFIX("mail_port");    mrsqlite3_set_config_int__(sql, key, ths->m_mail_port);
	MR_PREFIX("mail_user");    mrsqlite3_set_config__    (sql, key, ths->m_mail_user);
	MR_PREFIX("mail_pw");      mrsqlite3_set_config__    (sql, key, ths->m_mail_pw);

	MR_PREFIX("send_server");  mrsqlite3_set_config__    (sql, key, ths->m_send_server);
	MR_PREFIX("send_port");    mrsqlite3_set_config_int__(sql, key, ths->m_send_port);
	MR_PREFIX("send_user");    mrsqlite3_set_config__    (sql, key, ths->m_send_user);
	MR_PREFIX("send_pw");      mrsqlite3_set_config__    (sql, key, ths->m_send_pw);

	MR_PREFIX("server_flags"); mrsqlite3_set_config_int__(sql, key, ths->m_server_flags);

	sqlite3_free(key);
}


static char* get_readable_flags(int flags)
{
	mrstrbuilder_t strbuilder;
	mrstrbuilder_init(&strbuilder, 0);
	#define CAT_FLAG(f, s) if( (1<<bit)==(f) ) { mrstrbuilder_cat(&strbuilder, (s)); flag_added = 1; }

	for( int bit = 0; bit <= 30; bit++ )
	{
		if( flags&(1<<bit) )
		{
			int flag_added = 0;

			CAT_FLAG(MR_AUTH_XOAUTH2,         "XOAUTH2 ");
			CAT_FLAG(MR_AUTH_NORMAL,          "AUTH_NORMAL ");

			CAT_FLAG(MR_IMAP_SOCKET_STARTTLS, "IMAP_STARTTLS ");
			CAT_FLAG(MR_IMAP_SOCKET_SSL,      "IMAP_SSL ");
			CAT_FLAG(MR_IMAP_SOCKET_PLAIN,    "IMAP_PLAIN ");

			CAT_FLAG(MR_SMTP_SOCKET_STARTTLS, "SMTP_STARTTLS ");
			CAT_FLAG(MR_SMTP_SOCKET_SSL,      "SMTP_SSL ");
			CAT_FLAG(MR_SMTP_SOCKET_PLAIN,    "SMTP_PLAIN ");

			CAT_FLAG(MR_NO_EXTRA_IMAP_UPLOAD, "NO_EXTRA_IMAP_UPLOAD ");
			CAT_FLAG(MR_NO_MOVE_TO_CHATS,     "NO_MOVE_TO_CHATS ");

			if( !flag_added ) {
				char* temp = mr_mprintf("0x%x ", 1<<bit); mrstrbuilder_cat(&strbuilder, temp); free(temp);
			}
		}
	}

	if( strbuilder.m_buf[0]==0 ) { mrstrbuilder_cat(&strbuilder, "0"); }
	mr_trim(strbuilder.m_buf);
	return strbuilder.m_buf;
}


char* mrloginparam_get_readable(const mrloginparam_t* ths)
{
	const char* unset = "0";
	const char* pw = "***";

	if( ths==NULL ) {
		return safe_strdup(NULL);
	}

	char* flags_readable = get_readable_flags(ths->m_server_flags);

	char* ret = mr_mprintf("%s %s:%s:%s:%i %s:%s:%s:%i %s",
		ths->m_addr? ths->m_addr : unset,

		ths->m_mail_user? ths->m_mail_user : unset,
		ths->m_mail_pw? pw : unset,
		ths->m_mail_server? ths->m_mail_server : unset,
		ths->m_mail_port,

		ths->m_send_user? ths->m_send_user : unset,
		ths->m_send_pw? pw : unset,
		ths->m_send_server? ths->m_send_server : unset,
		ths->m_send_port,

		flags_readable);

	free(flags_readable);
	return ret;
}

