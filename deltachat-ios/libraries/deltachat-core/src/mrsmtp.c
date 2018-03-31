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


#include <libetpan/libetpan.h>
#include "mrmailbox_internal.h"
#include "mrsmtp.h"


#ifndef DEBUG_SMTP
#define DEBUG_SMTP 0
#endif


#define LOCK_SMTP   pthread_mutex_lock(&ths->m_mutex); smtp_locked = 1;
#define UNLOCK_SMTP if( smtp_locked ) { pthread_mutex_unlock(&ths->m_mutex); smtp_locked = 0; }


/*******************************************************************************
 * Main interface
 ******************************************************************************/


mrsmtp_t* mrsmtp_new(mrmailbox_t* mailbox)
{
	mrsmtp_t* ths;
	if( (ths=calloc(1, sizeof(mrsmtp_t)))==NULL ) {
		exit(29);
	}

	ths->m_log_connect_errors = 1;

	ths->m_mailbox = mailbox; /* should be used for logging only */
	pthread_mutex_init(&ths->m_mutex, NULL);
	return ths;
}


void mrsmtp_unref(mrsmtp_t* ths)
{
	if( ths == NULL ) {
		return;
	}
	mrsmtp_disconnect(ths);
	pthread_mutex_destroy(&ths->m_mutex);
	free(ths->m_from);
	free(ths);
}


/*******************************************************************************
 * Connect/Disconnect
 ******************************************************************************/


int mrsmtp_is_connected(const mrsmtp_t* ths)
{
	return (ths && ths->m_hEtpan)? 1 : 0;
}


static void body_progress(size_t current, size_t maximum, void* user_data)
{
	#if DEBUG_SMTP
	printf("body_progress called with current=%i, maximum=%i.", (int)current, (int)maximum);
	#endif
}


#if DEBUG_SMTP
static void logger(mailsmtp* smtp, int log_type, const char* buffer__, size_t size, void* user_data)
{
	char* buffer = malloc(size+1);
	memcpy(buffer, buffer__, size);
	buffer[size] = 0;
	printf("SMPT: %i: %s", log_type, buffer__);
}
#endif


int mrsmtp_connect(mrsmtp_t* ths, const mrloginparam_t* lp)
{
	int         success = 0, smtp_locked = 0;
	int         r, try_esmtp;

	if( ths == NULL || lp == NULL ) {
		return 0;
	}

	LOCK_SMTP

		if( ths->m_mailbox->m_cb(ths->m_mailbox, MR_EVENT_IS_OFFLINE, 0, 0)!=0 ) {
			mrmailbox_log_error_if(&ths->m_log_connect_errors, ths->m_mailbox, MR_ERR_NONETWORK, NULL);
			goto cleanup;
		}

		if( ths->m_hEtpan ) {
			mrmailbox_log_warning(ths->m_mailbox, 0, "Already connected to SMTP server.");
			success = 1; /* otherwise, the handle would get deleted */
			goto cleanup;
		}

		if( lp->m_addr == NULL || lp->m_send_server == NULL || lp->m_send_port == 0 ) {
			mrmailbox_log_error_if(&ths->m_log_connect_errors, ths->m_mailbox, 0, "Cannot connect to SMTP; bad parameters.");
			goto cleanup;
		}

		free(ths->m_from);
		ths->m_from = safe_strdup(lp->m_addr);

		ths->m_hEtpan = mailsmtp_new(0, NULL);
		if( ths->m_hEtpan == NULL ) {
			mrmailbox_log_error(ths->m_mailbox, 0, "SMTP-object creation failed.");
			goto cleanup;
		}
		mailsmtp_set_progress_callback(ths->m_hEtpan, body_progress, ths);
		#if DEBUG_SMTP
			mailsmtp_set_logger(ths->m_hEtpan, logger, ths);
		#endif

		/* connect to SMTP server */
		if( lp->m_server_flags&(MR_SMTP_SOCKET_STARTTLS|MR_SMTP_SOCKET_PLAIN) )
		{
			mrmailbox_log_info(ths->m_mailbox, 0, "Connecting to SMTP-server \"%s:%i\" via Socket...", lp->m_send_server, (int)lp->m_send_port);
			if( (r=mailsmtp_socket_connect(ths->m_hEtpan, lp->m_send_server, lp->m_send_port)) != MAILSMTP_NO_ERROR ) {
				mrmailbox_log_error_if(&ths->m_log_connect_errors, ths->m_mailbox, 0, "SMTP-Socket connection to %s:%i failed (%s)", lp->m_send_server, (int)lp->m_send_port, mailsmtp_strerror(r));
				goto cleanup;
			}
		}
		else
		{
			mrmailbox_log_info(ths->m_mailbox, 0, "Connecting to SMTP-server \"%s:%i\" via SSL...", lp->m_send_server, (int)lp->m_send_port);
			if( (r=mailsmtp_ssl_connect(ths->m_hEtpan, lp->m_send_server, lp->m_send_port)) != MAILSMTP_NO_ERROR ) {
				mrmailbox_log_error_if(&ths->m_log_connect_errors, ths->m_mailbox, 0, "SMPT-SSL connection to %s:%i failed (%s)", lp->m_send_server, (int)lp->m_send_port, mailsmtp_strerror(r));
				goto cleanup;
			}
		}

		try_esmtp = 1;
		ths->m_esmtp = 0;
		if( try_esmtp && (r=mailesmtp_ehlo(ths->m_hEtpan))==MAILSMTP_NO_ERROR ) {
			ths->m_esmtp = 1;
		}
		else if( !try_esmtp || r==MAILSMTP_ERROR_NOT_IMPLEMENTED ) {
			r = mailsmtp_helo(ths->m_hEtpan);
		}

		if( r != MAILSMTP_NO_ERROR ) {
			mrmailbox_log_error_if(&ths->m_log_connect_errors, ths->m_mailbox, 0, "SMTP-helo failed (%s)", mailsmtp_strerror(r));
			goto cleanup;
		}

		if( lp->m_server_flags&MR_SMTP_SOCKET_STARTTLS )
		{
			mrmailbox_log_info(ths->m_mailbox, 0, "Switching to SMTP-STARTTLS.");
			if( (r=mailsmtp_socket_starttls(ths->m_hEtpan)) != MAILSMTP_NO_ERROR ) {
				mrmailbox_log_error_if(&ths->m_log_connect_errors, ths->m_mailbox, 0, "SMTP-STARTTLS failed (%s)", mailsmtp_strerror(r));
				goto cleanup;
			}

			ths->m_esmtp = 0;
			if( try_esmtp && (r=mailesmtp_ehlo(ths->m_hEtpan))==MAILSMTP_NO_ERROR ) {
				ths->m_esmtp = 1;
			}
			else if( !try_esmtp || r==MAILSMTP_ERROR_NOT_IMPLEMENTED ) {
				r = mailsmtp_helo(ths->m_hEtpan);
			}

			if (r != MAILSMTP_NO_ERROR) {
				mrmailbox_log_error_if(&ths->m_log_connect_errors, ths->m_mailbox, 0, "SMTP-helo failed (%s)", mailsmtp_strerror(r));
				goto cleanup;
			}
		}
		mrmailbox_log_info(ths->m_mailbox, 0, "Connection to SMTP-server ok.");

		if( lp->m_send_user )
		{
			mrmailbox_log_info(ths->m_mailbox, 0, "Login to SMTP-server as \"%s\"...", lp->m_send_user);

				if((r=mailsmtp_auth(ths->m_hEtpan, lp->m_send_user, lp->m_send_pw))!=MAILSMTP_NO_ERROR ) {
					mrmailbox_log_error_if(&ths->m_log_connect_errors, ths->m_mailbox, 0, "SMTP-login failed for user %s (%s)", lp->m_send_user, mailsmtp_strerror(r));
					goto cleanup;
				}

			mrmailbox_log_info(ths->m_mailbox, 0, "SMTP-Login ok.");
		}

		success = 1;

cleanup:
		if( !success ) {
			if( ths->m_hEtpan ) {
				mailsmtp_free(ths->m_hEtpan);
				ths->m_hEtpan = NULL;
			}
		}

	UNLOCK_SMTP

	return success;
}


void mrsmtp_disconnect(mrsmtp_t* ths)
{
	int smtp_locked = 0;

	if( ths == NULL ) {
		return;
	}

	LOCK_SMTP

		if( ths->m_hEtpan ) {
			//mailsmtp_quit(ths->m_hEtpan); -- ?
			mailsmtp_free(ths->m_hEtpan);
			ths->m_hEtpan = NULL;
		}

	UNLOCK_SMTP
}


/*******************************************************************************
 * Send a message
 ******************************************************************************/


int mrsmtp_send_msg(mrsmtp_t* ths, const clist* recipients, const char* data_not_terminated, size_t data_bytes)
{
	int           success = 0, r, smtp_locked = 0;
	clistiter*    iter;

	if( ths == NULL ) {
		return 0;
	}

	if( recipients == NULL || clist_count(recipients)==0 || data_not_terminated == NULL || data_bytes == 0 ) {
		return 1; /* "null message" send */
	}

	LOCK_SMTP

		if( ths->m_hEtpan==NULL ) {
			goto cleanup;
		}

		/* set source */
		if( (r=(ths->m_esmtp?
				mailesmtp_mail(ths->m_hEtpan, ths->m_from, 1, "etPanSMTPTest") :
				 mailsmtp_mail(ths->m_hEtpan, ths->m_from))) != MAILSMTP_NO_ERROR )
		{
			// this error is very usual - we've simply lost the server connection and reconnect as soon as possible.
			// so, we do not log the first time this happens
			mrmailbox_log_error_if(&ths->m_log_usual_error, ths->m_mailbox, 0, "mailsmtp_mail: %s, %s (%i)", ths->m_from, mailsmtp_strerror(r), (int)r);
			ths->m_log_usual_error = 1;
			goto cleanup;
		}

		ths->m_log_usual_error = 0;

		/* set recipients */
		for( iter=clist_begin(recipients); iter!=NULL; iter=clist_next(iter)) {
			const char* rcpt = clist_content(iter);
			if( (r = (ths->m_esmtp?
					 mailesmtp_rcpt(ths->m_hEtpan, rcpt, MAILSMTP_DSN_NOTIFY_FAILURE|MAILSMTP_DSN_NOTIFY_DELAY, NULL) :
					  mailsmtp_rcpt(ths->m_hEtpan, rcpt))) != MAILSMTP_NO_ERROR) {
				mrmailbox_log_error_if(&ths->m_log_connect_errors, ths->m_mailbox, 0, "mailsmtp_rcpt: %s: %s", rcpt, mailsmtp_strerror(r));
				goto cleanup;
			}
		}

		/* message */
		if ((r = mailsmtp_data(ths->m_hEtpan)) != MAILSMTP_NO_ERROR) {
			fprintf(stderr, "mailsmtp_data: %s\n", mailsmtp_strerror(r));
			goto cleanup;
		}

		if ((r = mailsmtp_data_message(ths->m_hEtpan, data_not_terminated, data_bytes)) != MAILSMTP_NO_ERROR) {
			fprintf(stderr, "mailsmtp_data_message: %s\n", mailsmtp_strerror(r));
			goto cleanup;
		}

		success = 1;

cleanup:

	UNLOCK_SMTP

	return success;
}

