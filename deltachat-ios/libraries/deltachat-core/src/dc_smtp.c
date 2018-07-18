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

#include <unistd.h>
#include <libetpan/libetpan.h>
#include "dc_context.h"
#include "dc_smtp.h"
#include "dc_job.h"


#ifndef DEBUG_SMTP
#define DEBUG_SMTP 0
#endif


dc_smtp_t* dc_smtp_new(dc_context_t* context)
{
	dc_smtp_t* smtp = NULL;

	if ((smtp=calloc(1, sizeof(dc_smtp_t)))==NULL) {
		exit(29);
	}

	smtp->log_connect_errors = 1;

	smtp->context = context; /* should be used for logging only */
	return smtp;
}


void dc_smtp_unref(dc_smtp_t* smtp)
{
	if (smtp==NULL) {
		return;
	}
	dc_smtp_disconnect(smtp);
	free(smtp->from);
	free(smtp->error);
	free(smtp);
}


static void log_error(dc_smtp_t* smtp, const char* what_failed, int r)
{
	char* error_msg = dc_mprintf("%s: %s: %s", what_failed, mailsmtp_strerror(r), smtp->etpan->response);
	dc_log_warning(smtp->context, 0, "%s", error_msg);
	free(smtp->error);
	smtp->error = error_msg;
	smtp->error_etpan = r;
}


int dc_smtp_is_connected(const dc_smtp_t* smtp)
{
	return (smtp && smtp->etpan)? 1 : 0;
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


int dc_smtp_connect(dc_smtp_t* smtp, const dc_loginparam_t* lp)
{
	int success = 0;
	int r = 0;
	int try_esmtp = 0;

	if (smtp==NULL || lp==NULL) {
		return 0;
	}

	if (smtp->context->cb(smtp->context, DC_EVENT_IS_OFFLINE, 0, 0)!=0) {
		dc_log_error_if(&smtp->log_connect_errors, smtp->context, DC_ERROR_NO_NETWORK, NULL);
		goto cleanup;
	}

	if (smtp->etpan) {
		dc_log_warning(smtp->context, 0, "SMTP already connected.");
		success = 1; /* otherwise, the handle would get deleted */
		goto cleanup;
	}

	if (lp->addr==NULL || lp->send_server==NULL || lp->send_port==0) {
		dc_log_error_if(&smtp->log_connect_errors, smtp->context, 0, "SMTP bad parameters.");
		goto cleanup;
	}

	free(smtp->from);
	smtp->from = dc_strdup(lp->addr);

	smtp->etpan = mailsmtp_new(0, NULL);
	if (smtp->etpan==NULL) {
		dc_log_error(smtp->context, 0, "SMTP-object creation failed.");
		goto cleanup;
	}
	mailsmtp_set_timeout(smtp->etpan, DC_SMTP_TIMEOUT_SEC);
	mailsmtp_set_progress_callback(smtp->etpan, body_progress, smtp);
	#if DEBUG_SMTP
		mailsmtp_set_logger(smtp->etpan, logger, smtp);
	#endif

	/* connect to SMTP server */
	if (lp->server_flags&(DC_LP_SMTP_SOCKET_STARTTLS|DC_LP_SMTP_SOCKET_PLAIN))
	{
		if ((r=mailsmtp_socket_connect(smtp->etpan, lp->send_server, lp->send_port)) != MAILSMTP_NO_ERROR) {
			dc_log_error_if(&smtp->log_connect_errors, smtp->context, 0, "SMTP-Socket connection to %s:%i failed (%s)", lp->send_server, (int)lp->send_port, mailsmtp_strerror(r));
			goto cleanup;
		}
	}
	else
	{
		if ((r=mailsmtp_ssl_connect(smtp->etpan, lp->send_server, lp->send_port)) != MAILSMTP_NO_ERROR) {
			dc_log_error_if(&smtp->log_connect_errors, smtp->context, 0, "SMPT-SSL connection to %s:%i failed (%s)", lp->send_server, (int)lp->send_port, mailsmtp_strerror(r));
			goto cleanup;
		}
	}

	try_esmtp = 1;
	smtp->esmtp = 0;
	if (try_esmtp && (r=mailesmtp_ehlo(smtp->etpan))==MAILSMTP_NO_ERROR) {
		smtp->esmtp = 1;
	}
	else if (!try_esmtp || r==MAILSMTP_ERROR_NOT_IMPLEMENTED) {
		r = mailsmtp_helo(smtp->etpan);
	}

	if (r != MAILSMTP_NO_ERROR) {
		dc_log_error_if(&smtp->log_connect_errors, smtp->context, 0, "SMTP-helo failed (%s)", mailsmtp_strerror(r));
		goto cleanup;
	}

	if (lp->server_flags&DC_LP_SMTP_SOCKET_STARTTLS)
	{
		if ((r=mailsmtp_socket_starttls(smtp->etpan)) != MAILSMTP_NO_ERROR) {
			dc_log_error_if(&smtp->log_connect_errors, smtp->context, 0, "SMTP-STARTTLS failed (%s)", mailsmtp_strerror(r));
			goto cleanup;
		}

		smtp->esmtp = 0;
		if (try_esmtp && (r=mailesmtp_ehlo(smtp->etpan))==MAILSMTP_NO_ERROR) {
			smtp->esmtp = 1;
		}
		else if (!try_esmtp || r==MAILSMTP_ERROR_NOT_IMPLEMENTED) {
			r = mailsmtp_helo(smtp->etpan);
		}

		if (r != MAILSMTP_NO_ERROR) {
			dc_log_error_if(&smtp->log_connect_errors, smtp->context, 0, "SMTP-helo failed (%s)", mailsmtp_strerror(r));
			goto cleanup;
		}
		dc_log_info(smtp->context, 0, "SMTP-server %s:%i STARTTLS-connected.", lp->send_server, (int)lp->send_port);
	}
	else if (lp->server_flags&DC_LP_SMTP_SOCKET_PLAIN)
	{
		dc_log_info(smtp->context, 0, "SMTP-server %s:%i connected.", lp->send_server, (int)lp->send_port);
	}
	else
	{
		dc_log_info(smtp->context, 0, "SMTP-server %s:%i SSL-connected.", lp->send_server, (int)lp->send_port);
	}

	if (lp->send_user)
	{
		if((r=mailsmtp_auth(smtp->etpan, lp->send_user, lp->send_pw))!=MAILSMTP_NO_ERROR) {
			/*
			 * There are some Mailservers which do not correclty implement PLAIN auth (hMail)
			 * So here we try a workaround. See https://github.com/deltachat/deltachat-android/issues/67
			 */
			if (smtp->etpan->auth & MAILSMTP_AUTH_PLAIN) {
				dc_log_info(smtp->context, 0, "Trying SMTP-Login workaround \"%s\"...", lp->send_user);
				int err;
				char hostname[513];

				err = gethostname(hostname, sizeof(hostname));
				if (err < 0) {
					dc_log_error(smtp->context, 0, "SMTP-Login: Cannot get hostname.");
					goto cleanup;
				}
				r = mailesmtp_auth_sasl(smtp->etpan, "PLAIN", hostname, NULL, NULL, NULL, lp->send_user, lp->send_pw, NULL);
			}
			if (r != MAILSMTP_NO_ERROR)
			{
				dc_log_error_if(&smtp->log_connect_errors, smtp->context, 0, "SMTP-login failed for user %s (%s)", lp->send_user, mailsmtp_strerror(r));
				goto cleanup;
			}
		}

		dc_log_info(smtp->context, 0, "SMTP-login as %s ok.", lp->send_user);
	}

	success = 1;

cleanup:
	if (!success) {
		if (smtp->etpan) {
			mailsmtp_free(smtp->etpan);
			smtp->etpan = NULL;
		}
	}

	return success;
}


void dc_smtp_disconnect(dc_smtp_t* smtp)
{
	if (smtp==NULL) {
		return;
	}

	if (smtp->etpan) {
		//mailsmtp_quit(smtp->etpan); -- ?
		mailsmtp_free(smtp->etpan);
		smtp->etpan = NULL;
	}
}


/*******************************************************************************
 * Send a message
 ******************************************************************************/


int dc_smtp_send_msg(dc_smtp_t* smtp, const clist* recipients, const char* data_not_terminated, size_t data_bytes)
{
	int        success = 0;
	int        r = 0;
	clistiter* iter = NULL;

	if (smtp==NULL) {
		goto cleanup;
	}

	if (recipients==NULL || clist_count(recipients)==0 || data_not_terminated==NULL || data_bytes==0) {
		success = 1;
		goto cleanup; // "null message" send
	}

	if (smtp->etpan==NULL) {
		goto cleanup;
	}

	// set source
	// the `etPanSMTPTest` is the ENVID from RFC 3461 (SMTP DSNs), we should probably replace it by a random value
	if ((r=(smtp->esmtp?
			mailesmtp_mail(smtp->etpan, smtp->from, 1, "etPanSMTPTest") :
			 mailsmtp_mail(smtp->etpan, smtp->from))) != MAILSMTP_NO_ERROR)
	{
		// this error is very usual - we've simply lost the server connection and reconnect as soon as possible.
		// log_error() does log the error as a warning in the first place, the caller will log the error later if it is not recovered.
		log_error(smtp, "SMTP failed to start message", r);
		goto cleanup;
	}

	// set recipients
	// if the recipient is on the same server, this may fail at once.
	// TODO: question is what to do if one recipient in a group fails
	for (iter=clist_begin(recipients); iter!=NULL; iter=clist_next(iter)) {
		const char* rcpt = clist_content(iter);
		if ((r = (smtp->esmtp?
				 mailesmtp_rcpt(smtp->etpan, rcpt, MAILSMTP_DSN_NOTIFY_FAILURE|MAILSMTP_DSN_NOTIFY_DELAY, NULL) :
				  mailsmtp_rcpt(smtp->etpan, rcpt))) != MAILSMTP_NO_ERROR) {
			log_error(smtp, "SMTP failed to add recipient", r);
			goto cleanup;
		}
	}

	// message
	if ((r = mailsmtp_data(smtp->etpan)) != MAILSMTP_NO_ERROR) {
		log_error(smtp, "SMTP failed to set data", r);
		goto cleanup;
	}

	if ((r = mailsmtp_data_message(smtp->etpan, data_not_terminated, data_bytes)) != MAILSMTP_NO_ERROR) {
		log_error(smtp, "SMTP failed to send message", r);
		goto cleanup;
	}

	success = 1;

cleanup:
	return success;
}
