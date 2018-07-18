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


#include <stdarg.h>
#include <unistd.h>
#include "dc_context.h"
#include "dc_loginparam.h"
#include "dc_job.h"
#include "dc_imap.h"
#include "dc_smtp.h"
#include "dc_mimefactory.h"


/*******************************************************************************
 * IMAP-jobs
 ******************************************************************************/


static int connect_to_imap(dc_context_t* context, dc_job_t* job /*may be NULL if the function is called directly!*/)
{
	#define          NOT_CONNECTED     0
	#define          ALREADY_CONNECTED 1
	#define          JUST_CONNECTED    2
	int              ret_connected = NOT_CONNECTED;
	dc_loginparam_t* param = dc_loginparam_new();

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || context->imap==NULL) {
		dc_log_warning(context, 0, "Cannot connect to IMAP: Bad parameters.");
		goto cleanup;
	}

	if (dc_imap_is_connected(context->imap)) {
		ret_connected = ALREADY_CONNECTED;
		goto cleanup;
	}

	if (dc_sqlite3_get_config_int(context->sql, "configured", 0)==0) {
		dc_log_warning(context, 0, "Not configured, cannot connect."); // this is no error, connect() is called eg. when the screen is switched on, it's okay if the caller does not check all circumstances here
		goto cleanup;
	}

	dc_loginparam_read(param, context->sql, "configured_" /*the trailing underscore is correct*/);

	if (!dc_imap_connect(context->imap, param)) {
		dc_job_try_again_later(job, DC_STANDARD_DELAY, NULL);
		goto cleanup;
	}

	ret_connected = JUST_CONNECTED;

cleanup:
	dc_loginparam_unref(param);
	return ret_connected;
}


static void dc_job_do_DC_JOB_SEND_MSG_TO_IMAP(dc_context_t* context, dc_job_t* job)
{
	char*             server_folder = NULL;
	uint32_t          server_uid = 0;
	dc_mimefactory_t  mimefactory;
	dc_mimefactory_init(&mimefactory, context);

	/* connect to IMAP-server */
	if (!dc_imap_is_connected(context->imap)) {
		connect_to_imap(context, NULL);
		if (!dc_imap_is_connected(context->imap)) {
			dc_job_try_again_later(job, DC_STANDARD_DELAY, NULL);
			goto cleanup;
		}
	}

	/* create message */
	if (dc_mimefactory_load_msg(&mimefactory, job->foreign_id)==0
	 || mimefactory.from_addr==NULL) {
		goto cleanup; /* should not happen as we've sent the message to the SMTP server before */
	}

	if (!dc_mimefactory_render(&mimefactory)) {
		goto cleanup; /* should not happen as we've sent the message to the SMTP server before */
	}

	if (!dc_imap_append_msg(context->imap, mimefactory.msg->timestamp, mimefactory.out->str, mimefactory.out->len, &server_folder, &server_uid)) {
		dc_job_try_again_later(job, DC_AT_ONCE, NULL);
		goto cleanup;
	}
	else {
		dc_update_server_uid(context, mimefactory.msg->rfc724_mid, server_folder, server_uid);
	}

cleanup:
	dc_mimefactory_empty(&mimefactory);
	free(server_folder);
}


static void dc_job_do_DC_JOB_DELETE_MSG_ON_IMAP(dc_context_t* context, dc_job_t* job)
{
	int           delete_from_server = 1;
	dc_msg_t*     msg = dc_msg_new(context);
	sqlite3_stmt* stmt = NULL;

	if (!dc_msg_load_from_db(msg, context, job->foreign_id)
	 || msg->rfc724_mid==NULL || msg->rfc724_mid[0]==0 /* eg. device messages have no Message-ID */) {
		goto cleanup;
	}

	if (dc_rfc724_mid_cnt(context, msg->rfc724_mid)!=1) {
		dc_log_info(context, 0, "The message is deleted from the server when all parts are deleted.");
		delete_from_server = 0;
	}

	/* if this is the last existing part of the message, we delete the message from the server */
	if (delete_from_server)
	{
		if (!dc_imap_is_connected(context->imap)) {
			connect_to_imap(context, NULL);
			if (!dc_imap_is_connected(context->imap)) {
				dc_job_try_again_later(job, DC_STANDARD_DELAY, NULL);
				goto cleanup;
			}
		}

		if (!dc_imap_delete_msg(context->imap, msg->rfc724_mid, msg->server_folder, msg->server_uid))
		{
			dc_job_try_again_later(job, DC_AT_ONCE, NULL);
			goto cleanup;
		}
	}

	/* we delete the database entry ...
	- if the message is successfully removed from the server
	- or if there are other parts of the message in the database (in this case we have not deleted if from the server)
	(As long as the message is not removed from the IMAP-server, we need at least one database entry to avoid a re-download) */
	stmt = dc_sqlite3_prepare(context->sql,
		"DELETE FROM msgs WHERE id=?;");
	sqlite3_bind_int(stmt, 1, msg->id);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
	stmt = NULL;

	stmt = dc_sqlite3_prepare(context->sql,
		"DELETE FROM msgs_mdns WHERE msg_id=?;");
	sqlite3_bind_int(stmt, 1, msg->id);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
	stmt = NULL;

	char* pathNfilename = dc_param_get(msg->param, DC_PARAM_FILE, NULL);
	if (pathNfilename) {
		if (strncmp(context->blobdir, pathNfilename, strlen(context->blobdir))==0)
		{
			char* strLikeFilename = dc_mprintf("%%f=%s%%", pathNfilename);
			stmt = dc_sqlite3_prepare(context->sql,
				"SELECT id FROM msgs WHERE type!=? AND param LIKE ?;"); /* if this gets too slow, an index over "type" should help. */
			sqlite3_bind_int (stmt, 1, DC_MSG_TEXT);
			sqlite3_bind_text(stmt, 2, strLikeFilename, -1, SQLITE_STATIC);
			int file_used_by_other_msgs = (sqlite3_step(stmt)==SQLITE_ROW)? 1 : 0;
			free(strLikeFilename);
			sqlite3_finalize(stmt);
			stmt = NULL;

			if (!file_used_by_other_msgs)
			{
				dc_delete_file(pathNfilename, context);

				char* increation_file = dc_mprintf("%s.increation", pathNfilename);
				dc_delete_file(increation_file, context);
				free(increation_file);

				char* filenameOnly = dc_get_filename(pathNfilename);
				if (msg->type==DC_MSG_VOICE) {
					char* waveform_file = dc_mprintf("%s/%s.waveform", context->blobdir, filenameOnly);
					dc_delete_file(waveform_file, context);
					free(waveform_file);
				}
				else if (msg->type==DC_MSG_VIDEO) {
					char* preview_file = dc_mprintf("%s/%s-preview.jpg", context->blobdir, filenameOnly);
					dc_delete_file(preview_file, context);
					free(preview_file);
				}
				free(filenameOnly);
			}
		}
		free(pathNfilename);
	}

cleanup:
	sqlite3_finalize(stmt);
	dc_msg_unref(msg);
}


static void dc_job_do_DC_JOB_MARKSEEN_MSG_ON_IMAP(dc_context_t* context, dc_job_t* job)
{
	dc_msg_t* msg = dc_msg_new(context);
	char*     new_server_folder = NULL;
	uint32_t  new_server_uid = 0;
	int       in_ms_flags = 0;
	int       out_ms_flags = 0;

	if (!dc_imap_is_connected(context->imap)) {
		connect_to_imap(context, NULL);
		if (!dc_imap_is_connected(context->imap)) {
			dc_job_try_again_later(job, DC_STANDARD_DELAY, NULL);
			goto cleanup;
		}
	}

	if (!dc_msg_load_from_db(msg, context, job->foreign_id)) {
		goto cleanup;
	}

	/* add an additional job for sending the MDN (here in a thread for fast ui resonses) (an extra job as the MDN has a lower priority) */
	if (dc_param_get_int(msg->param, DC_PARAM_WANTS_MDN, 0) /* DC_PARAM_WANTS_MDN is set only for one part of a multipart-message */
	 && dc_sqlite3_get_config_int(context->sql, "mdns_enabled", DC_MDNS_DEFAULT_ENABLED)) {
		in_ms_flags |= DC_MS_SET_MDNSent_FLAG;
	}

	if (msg->is_msgrmsg) {
		in_ms_flags |= DC_MS_ALSO_MOVE;
	}

	if (dc_imap_markseen_msg(context->imap, msg->server_folder, msg->server_uid,
		   in_ms_flags, &new_server_folder, &new_server_uid, &out_ms_flags)!=0)
	{
		if ((new_server_folder && new_server_uid) || out_ms_flags&DC_MS_MDNSent_JUST_SET)
		{
			if (new_server_folder && new_server_uid)
			{
				dc_update_server_uid(context, msg->rfc724_mid, new_server_folder, new_server_uid);
			}

			if (out_ms_flags&DC_MS_MDNSent_JUST_SET)
			{
				dc_job_add(context, DC_JOB_SEND_MDN, msg->id, NULL, 0);
			}
		}
	}
	else
	{
		dc_job_try_again_later(job, DC_AT_ONCE, NULL);
	}

cleanup:
	dc_msg_unref(msg);
	free(new_server_folder);
}


static void dc_job_do_DC_JOB_MARKSEEN_MDN_ON_IMAP(dc_context_t* context, dc_job_t* job)
{
	char*    server_folder = dc_param_get(job->param, DC_PARAM_SERVER_FOLDER, NULL);
	uint32_t server_uid = dc_param_get_int(job->param, DC_PARAM_SERVER_UID, 0);
	char*    new_server_folder = NULL;
	uint32_t new_server_uid = 0;
	int      out_ms_flags = 0;

	if (!dc_imap_is_connected(context->imap)) {
		connect_to_imap(context, NULL);
		if (!dc_imap_is_connected(context->imap)) {
			dc_job_try_again_later(job, DC_STANDARD_DELAY, NULL);
			goto cleanup;
		}
	}

	if (dc_imap_markseen_msg(context->imap, server_folder, server_uid, DC_MS_ALSO_MOVE, &new_server_folder, &new_server_uid, &out_ms_flags)==0) {
		dc_job_try_again_later(job, DC_AT_ONCE, NULL);
	}

cleanup:
	free(server_folder);
	free(new_server_folder);
}


/*******************************************************************************
 * SMTP-jobs
 ******************************************************************************/


static void dc_job_do_DC_JOB_SEND_MSG_TO_SMTP(dc_context_t* context, dc_job_t* job)
{
	dc_mimefactory_t mimefactory;
	dc_mimefactory_init(&mimefactory, context);

	/* connect to SMTP server, if not yet done */
	if (!dc_smtp_is_connected(context->smtp)) {
		dc_loginparam_t* loginparam = dc_loginparam_new();
			dc_loginparam_read(loginparam, context->sql, "configured_");
			int connected = dc_smtp_connect(context->smtp, loginparam);
		dc_loginparam_unref(loginparam);
		if (!connected) {
			dc_job_try_again_later(job, DC_STANDARD_DELAY, NULL);
			goto cleanup;
		}
	}

	/* load message data */
	if (!dc_mimefactory_load_msg(&mimefactory, job->foreign_id)
	 || mimefactory.from_addr==NULL) {
		dc_log_warning(context, 0, "Cannot load data to send, maybe the message is deleted in between.");
		goto cleanup; // no redo, no IMAP. moreover, as the data does not exist, there is no need in calling mark_as_error()
	}

	/* check if the message is ready (normally, only video files may be delayed this way) */
	if (mimefactory.increation) {
		dc_log_info(context, 0, "File is in creation, retrying later.");
		dc_job_try_again_later(job, DC_INCREATION_POLL, NULL);
		goto cleanup;
	}

	/* send message - it's okay if there are no recipients, this is a group with only OURSELF; we only upload to IMAP in this case */
	if (clist_count(mimefactory.recipients_addr) > 0)
	{
		if (!dc_mimefactory_render(&mimefactory)) {
			dc_set_msg_failed(context, job->foreign_id, mimefactory.error);
			goto cleanup; // no redo, no IMAP - this will also fail next time
		}

		/* have we guaranteed encryption but cannot fulfill it for any reason? Do not send the message then.*/
		if (dc_param_get_int(mimefactory.msg->param, DC_PARAM_GUARANTEE_E2EE, 0) && !mimefactory.out_encrypted) {
			dc_set_msg_failed(context, job->foreign_id, "End-to-end-encryption unavailable unexpectedly.");
			goto cleanup; /* unrecoverable */
		}

		if (!dc_smtp_send_msg(context->smtp, mimefactory.recipients_addr, mimefactory.out->str, mimefactory.out->len)) {
			if (MAILSMTP_ERROR_EXCEED_STORAGE_ALLOCATION==context->smtp->error_etpan
			 || MAILSMTP_ERROR_INSUFFICIENT_SYSTEM_STORAGE==context->smtp->error_etpan) {
				dc_set_msg_failed(context, job->foreign_id, context->smtp->error);
			}
			else {
				dc_smtp_disconnect(context->smtp);
				dc_job_try_again_later(job, DC_AT_ONCE, context->smtp->error);
			}
			goto cleanup;
		}
	}

	/* done */
	dc_sqlite3_begin_transaction(context->sql);

		/* debug print? */
		if (dc_sqlite3_get_config_int(context->sql, "save_eml", 0)) {
			char* emlname = dc_mprintf("%s/to-smtp-%i.eml", context->blobdir, (int)mimefactory.msg->id);
			FILE* emlfileob = fopen(emlname, "w");
			if (emlfileob) {
				if (mimefactory.out) {
					fwrite(mimefactory.out->str, 1, mimefactory.out->len, emlfileob);
				}
				fclose(emlfileob);
			}
			free(emlname);
		}

		dc_update_msg_state(context, mimefactory.msg->id, DC_STATE_OUT_DELIVERED);
		if (mimefactory.out_encrypted && dc_param_get_int(mimefactory.msg->param, DC_PARAM_GUARANTEE_E2EE, 0)==0) {
			dc_param_set_int(mimefactory.msg->param, DC_PARAM_GUARANTEE_E2EE, 1); /* can upgrade to E2EE - fine! */
			dc_msg_save_param_to_disk(mimefactory.msg);
		}

		if ((context->imap->server_flags&DC_NO_EXTRA_IMAP_UPLOAD)==0
		 && dc_param_get(mimefactory.chat->param, DC_PARAM_SELFTALK, 0)==0
		 && dc_param_get_int(mimefactory.msg->param, DC_PARAM_CMD, 0)!=DC_CMD_SECUREJOIN_MESSAGE) {
			dc_job_add(context, DC_JOB_SEND_MSG_TO_IMAP, mimefactory.msg->id, NULL, 0); /* send message to IMAP in another job */
		}

		// TODO: add to keyhistory
		dc_add_to_keyhistory(context, NULL, 0, NULL, NULL);

	dc_sqlite3_commit(context->sql);

	context->cb(context, DC_EVENT_MSG_DELIVERED, mimefactory.msg->chat_id, mimefactory.msg->id);

cleanup:
	dc_mimefactory_empty(&mimefactory);
}


static void dc_job_do_DC_JOB_SEND_MDN(dc_context_t* context, dc_job_t* job)
{
	dc_mimefactory_t mimefactory;
	dc_mimefactory_init(&mimefactory, context);

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || job==NULL) {
		return;
	}

	/* connect to SMTP server, if not yet done */
	if (!dc_smtp_is_connected(context->smtp))
	{
		dc_loginparam_t* loginparam = dc_loginparam_new();
			dc_loginparam_read(loginparam, context->sql, "configured_");
			int connected = dc_smtp_connect(context->smtp, loginparam);
		dc_loginparam_unref(loginparam);
		if (!connected) {
			dc_job_try_again_later(job, DC_STANDARD_DELAY, NULL);
			goto cleanup;
		}
	}

    if (!dc_mimefactory_load_mdn(&mimefactory, job->foreign_id)
     || !dc_mimefactory_render(&mimefactory)) {
		goto cleanup;
    }

	//char* t1=dc_null_terminate(mimefactory.out->str,mimefactory.out->len);printf("~~~~~MDN~~~~~\n%s\n~~~~~/MDN~~~~~",t1);free(t1); // DEBUG OUTPUT

	if (!dc_smtp_send_msg(context->smtp, mimefactory.recipients_addr, mimefactory.out->str, mimefactory.out->len)) {
		dc_smtp_disconnect(context->smtp);
		dc_job_try_again_later(job, DC_AT_ONCE, NULL);
		goto cleanup;
	}

cleanup:
	dc_mimefactory_empty(&mimefactory);
}


static void dc_suspend_smtp_thread(dc_context_t* context, int suspend)
{
	pthread_mutex_lock(&context->smtpidle_condmutex);
		context->smtpidle_suspend = suspend;
	pthread_mutex_unlock(&context->smtpidle_condmutex);

	// the smtp-thread may be in perform_jobs() when this function is called,
	// wait until we arrive in idle(). for simplicity, we do this by polling a variable
	// (in fact, this is only needed when calling configure() is called)
	if (suspend)
	{
		while (1) {
			pthread_mutex_lock(&context->smtpidle_condmutex);
				if (context->smtpidle_in_idleing) {
					context->perform_smtp_jobs_needed = 0;
					pthread_mutex_unlock(&context->smtpidle_condmutex);
					return;
				}
			pthread_mutex_unlock(&context->smtpidle_condmutex);
			usleep(300*1000);
		}
	}
}


/*******************************************************************************
 * Tools
 ******************************************************************************/


void dc_job_add(dc_context_t* context, int action, int foreign_id, const char* param, int delay_seconds)
{
	time_t        timestamp = time(NULL);
	sqlite3_stmt* stmt = NULL;
	int           thread = 0;

	if (action >= DC_IMAP_THREAD && action < DC_IMAP_THREAD+1000) {
		thread = DC_IMAP_THREAD;
	}
	else if (action >= DC_SMTP_THREAD && action < DC_SMTP_THREAD+1000) {
		thread = DC_SMTP_THREAD;
	}
	else {
		return;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"INSERT INTO jobs (added_timestamp, thread, action, foreign_id, param, desired_timestamp) VALUES (?,?,?,?,?,?);");
	sqlite3_bind_int64(stmt, 1, timestamp);
	sqlite3_bind_int  (stmt, 2, thread);
	sqlite3_bind_int  (stmt, 3, action);
	sqlite3_bind_int  (stmt, 4, foreign_id);
	sqlite3_bind_text (stmt, 5, param? param : "",  -1, SQLITE_STATIC);
	sqlite3_bind_int64(stmt, 6, delay_seconds>0? (timestamp+delay_seconds) : 0);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);

	if (thread==DC_IMAP_THREAD) {
		dc_interrupt_imap_idle(context);
	}
	else {
		dc_interrupt_smtp_idle(context);
	}
}


static void dc_job_update(dc_context_t* context, const dc_job_t* job)
{
	sqlite3_stmt* update_stmt = dc_sqlite3_prepare(context->sql,
		"UPDATE jobs SET desired_timestamp=0, param=? WHERE id=?;");
	sqlite3_bind_text (update_stmt, 1, job->param->packed, -1, SQLITE_STATIC);
	sqlite3_bind_int  (update_stmt, 2, job->job_id);
	sqlite3_step(update_stmt);
	sqlite3_finalize(update_stmt);
}


static void dc_job_delete(dc_context_t* context, const dc_job_t* job)
{
	sqlite3_stmt* delete_stmt = dc_sqlite3_prepare(context->sql,
		"DELETE FROM jobs WHERE id=?;");
	sqlite3_bind_int(delete_stmt, 1, job->job_id);
	sqlite3_step(delete_stmt);
	sqlite3_finalize(delete_stmt);
}


void dc_job_try_again_later(dc_job_t* job, int try_again, const char* pending_error)
{
	if (job==NULL) {
		return;
	}

	job->try_again = try_again;

	free(job->pending_error);
	job->pending_error = dc_strdup_keep_null(pending_error);
}


void dc_job_kill_actions(dc_context_t* context, int action1, int action2)
{
	if (context==NULL) {
		return;
	}

	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
		"DELETE FROM jobs WHERE action=? OR action=?;");
	sqlite3_bind_int(stmt, 1, action1);
	sqlite3_bind_int(stmt, 2, action2);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
}


static void dc_job_perform(dc_context_t* context, int thread)
{
	sqlite3_stmt* select_stmt = NULL;
	dc_job_t      job;
	#define       THREAD_STR (thread==DC_IMAP_THREAD? "IMAP" : "SMTP")
	#define       IS_EXCLUSIVE_JOB (DC_JOB_CONFIGURE_IMAP==job.action || DC_JOB_IMEX_IMAP==job.action)

	memset(&job, 0, sizeof(dc_job_t));
	job.param = dc_param_new();

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	select_stmt = dc_sqlite3_prepare(context->sql,
		"SELECT id, action, foreign_id, param FROM jobs WHERE thread=? AND desired_timestamp<=? ORDER BY action DESC, added_timestamp;");
	sqlite3_bind_int64(select_stmt, 1, thread);
	sqlite3_bind_int64(select_stmt, 2, time(NULL));
	while (sqlite3_step(select_stmt)==SQLITE_ROW)
	{
		job.job_id                          = sqlite3_column_int (select_stmt, 0);
		job.action                          = sqlite3_column_int (select_stmt, 1);
		job.foreign_id                      = sqlite3_column_int (select_stmt, 2);
		dc_param_set_packed(job.param, (char*)sqlite3_column_text(select_stmt, 3));

		dc_log_info(context, 0, "%s-job #%i, action %i started...", THREAD_STR, (int)job.job_id, (int)job.action);

		// some configuration jobs are "exclusive":
		// - they are always executed in the imap-thread and the smtp-thread is suspended during execution
		// - they may change the database handle change the database handle; we do not keep old pointers therefore
		// - they can be re-executed one time AT_ONCE, but they are not save in the database for later execution
		if (IS_EXCLUSIVE_JOB) {
			dc_job_kill_actions(context, job.action, 0);
			sqlite3_finalize(select_stmt);
			select_stmt = NULL;
			dc_suspend_smtp_thread(context, 1);
		}

		for (int tries = 0; tries <= 1; tries++)
		{
			job.try_again = DC_DONT_TRY_AGAIN; // this can be modified by a job using dc_job_try_again_later()

			switch (job.action) {
				case DC_JOB_SEND_MSG_TO_SMTP:     dc_job_do_DC_JOB_SEND_MSG_TO_SMTP     (context, &job); break;
				case DC_JOB_SEND_MSG_TO_IMAP:     dc_job_do_DC_JOB_SEND_MSG_TO_IMAP     (context, &job); break;
				case DC_JOB_DELETE_MSG_ON_IMAP:   dc_job_do_DC_JOB_DELETE_MSG_ON_IMAP   (context, &job); break;
				case DC_JOB_MARKSEEN_MSG_ON_IMAP: dc_job_do_DC_JOB_MARKSEEN_MSG_ON_IMAP (context, &job); break;
				case DC_JOB_MARKSEEN_MDN_ON_IMAP: dc_job_do_DC_JOB_MARKSEEN_MDN_ON_IMAP (context, &job); break;
				case DC_JOB_SEND_MDN:             dc_job_do_DC_JOB_SEND_MDN             (context, &job); break;
				case DC_JOB_CONFIGURE_IMAP:       dc_job_do_DC_JOB_CONFIGURE_IMAP       (context, &job); break;
				case DC_JOB_IMEX_IMAP:            dc_job_do_DC_JOB_IMEX_IMAP            (context, &job); break;
			}

			if (job.try_again!=DC_AT_ONCE) {
				break;
			}
		}

		if (IS_EXCLUSIVE_JOB) {
			dc_suspend_smtp_thread(context, 0);
			goto cleanup;
		}
		else if (job.try_again==DC_INCREATION_POLL)
		{
			// just try over next loop unconditionally, the ui typically interrupts idle when the file (video) is ready
			dc_log_info(context, 0, "%s-job #%i not yet ready and will be delayed.", THREAD_STR, (int)job.job_id);
		}
		else if (job.try_again==DC_AT_ONCE || job.try_again==DC_STANDARD_DELAY)
		{
			// Define the number of job-retries, each retry may result in 2 tries (for fast network-failure-recover).
			// The first job-retries are done asap, the last retry is delayed about a minute.
			// Network errors do not count as failed tries.
			#define JOB_RETRIES 3

			int is_online = dc_is_online(context)? 1 : 0;
			int tries_while_online = dc_param_get_int(job.param, DC_PARAM_TIMES, 0) + is_online;

			if( tries_while_online < JOB_RETRIES ) {
				dc_param_set_int(job.param, DC_PARAM_TIMES, tries_while_online);
				dc_job_update(context, &job);
				dc_log_info(context, 0, "%s-job #%i not succeeded on try #%i.", THREAD_STR, (int)job.job_id, tries_while_online);

				if (thread==DC_SMTP_THREAD && is_online && tries_while_online<(JOB_RETRIES-1)) {
					pthread_mutex_lock(&context->smtpidle_condmutex);
						context->perform_smtp_jobs_needed = DC_JOBS_NEEDED_AVOID_DOS;
					pthread_mutex_unlock(&context->smtpidle_condmutex);
				}
			}
			else {
				if (job.action==DC_JOB_SEND_MSG_TO_SMTP) { // in all other cases, the messages is already sent
					dc_set_msg_failed(context, job.foreign_id, job.pending_error);
				}
				dc_job_delete(context, &job);
			}
		}
		else
		{
			dc_job_delete(context, &job);
		}
	}

cleanup:
	dc_param_unref(job.param);
	free(job.pending_error);
	sqlite3_finalize(select_stmt);
}


/*******************************************************************************
 * User-functions handle IMAP-jobs from the IMAP-thread
 ******************************************************************************/


/**
 * Execute pending imap-jobs.
 * This function and dc_perform_imap_fetch() and dc_perform_imap_idle() must be called from the same thread,
 * typically in a loop.
 *
 * See dc_interrupt_imap_idle() for an example.
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @return None
 */
void dc_perform_imap_jobs(dc_context_t* context)
{
	dc_log_info(context, 0, "IMAP-jobs started...");

	pthread_mutex_lock(&context->imapidle_condmutex);
		context->perform_imap_jobs_needed = 0;
	pthread_mutex_unlock(&context->imapidle_condmutex);

	dc_job_perform(context, DC_IMAP_THREAD);

	dc_log_info(context, 0, "IMAP-jobs ended.");
}


/**
 * Fetch new messages, if any.
 * This function and dc_perform_imap_jobs() and dc_perform_imap_idle() must be called from the same thread,
 * typically in a loop.
 *
 * See dc_interrupt_imap_idle() for an example.
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @return None.
 */
void dc_perform_imap_fetch(dc_context_t* context)
{
	clock_t start = clock();

	if (!connect_to_imap(context, NULL)) {
		return;
	}

	dc_log_info(context, 0, "IMAP-fetch started...");

	dc_imap_fetch(context->imap);

	if (context->imap->should_reconnect
	 && context->cb(context, DC_EVENT_IS_OFFLINE, 0, 0)==0)
	{
		dc_log_info(context, 0, "IMAP-fetch aborted, starting over...");
		dc_imap_fetch(context->imap);
	}

	dc_log_info(context, 0, "IMAP-fetch done in %.0f ms.", (double)(clock()-start)*1000.0/CLOCKS_PER_SEC);
}


/**
 * Wait for messages or jobs.
 * This function and dc_perform_imap_jobs() and dc_perform_imap_fetch() must be called from the same thread,
 * typically in a loop.
 *
 * You should call this function directly after calling dc_perform_imap_fetch().
 *
 * See dc_interrupt_imap_idle() for an example.
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @return None.
 */
void dc_perform_imap_idle(dc_context_t* context)
{
	connect_to_imap(context, NULL); // also idle if connection fails because of not-configured, no-network, whatever. dc_imap_idle() will handle this by the fake-idle and log a warning

	pthread_mutex_lock(&context->imapidle_condmutex);
		if (context->perform_imap_jobs_needed) {
			dc_log_info(context, 0, "IMAP-IDLE will not be started because of waiting jobs.");
			pthread_mutex_unlock(&context->imapidle_condmutex);
			return;
		}
	pthread_mutex_unlock(&context->imapidle_condmutex);

	dc_log_info(context, 0, "IMAP-IDLE started...");

	dc_imap_idle(context->imap);

	dc_log_info(context, 0, "IMAP-IDLE ended.");
}


/**
 * Interrupt waiting for imap-jobs.
 * If dc_perform_imap_jobs(), dc_perform_imap_fetch() and dc_perform_imap_idle() are called in a loop,
 * calling this function causes imap-jobs to be executed and messages to be fetched.
 *
 * Internally, this function is called whenever a imap-jobs should be processed (delete message, markseen etc.),
 * for the UI view it may make sense to call the function eg. on network changes to fetch messages immediately.
 *
 * Example:
 *
 *     void* imap_thread_func(void* context)
 *     {
 *         while (true) {
 *             dc_perform_imap_jobs(context);
 *             dc_perform_imap_fetch(context);
 *             dc_perform_imap_idle(context);
 *         }
 *     }
 *
 *     // start imap-thread that runs forever
 *     pthread_t imap_thread;
 *     pthread_create(&imap_thread, NULL, imap_thread_func, context);
 *
 *     ... program runs ...
 *
 *     // network becomes available again - the interrupt causes
 *     // dc_perform_imap_idle() in the thread to return so that jobs are executed
 *     // and messages are fetched.
 *     dc_interrupt_imap_idle(context);
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @return None
 */
void dc_interrupt_imap_idle(dc_context_t* context)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || context->imap==NULL) {
		dc_log_warning(context, 0, "Interrupt IMAP-IDLE: Bad parameters.");
		return;
	}

	dc_log_info(context, 0, "Interrupting IMAP-IDLE...");

	pthread_mutex_lock(&context->imapidle_condmutex);
		// when this function is called, it might be that the idle-thread is in
		// perform_idle_jobs() instead of idle(). if so, added jobs will be performed after the _next_ idle-jobs loop.
		// setting the flag perform_imap_jobs_needed makes sure, idle() returns immediately in this case.
		context->perform_imap_jobs_needed = 1;
	pthread_mutex_unlock(&context->imapidle_condmutex);

	dc_imap_interrupt_idle(context->imap);
}


/*******************************************************************************
 * User-functions handle SMTP-jobs from the SMTP-thread
 ******************************************************************************/


/**
 * Execute pending smtp-jobs.
 * This function and dc_perform_smtp_idle() must be called from the same thread,
 * typically in a loop.
 *
 * See dc_interrupt_smtp_idle() for an example.
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @return None
 */
void dc_perform_smtp_jobs(dc_context_t* context)
{
	dc_log_info(context, 0, "SMTP-jobs started...");

	pthread_mutex_lock(&context->smtpidle_condmutex);
		context->perform_smtp_jobs_needed = 0;
	pthread_mutex_unlock(&context->smtpidle_condmutex);

	dc_job_perform(context, DC_SMTP_THREAD);

	dc_log_info(context, 0, "SMTP-jobs ended.");
}


/**
 * Wait for smtp-jobs.
 * This function and dc_perform_smtp_jobs() must be called from the same thread,
 * typically in a loop.
 *
 * See dc_interrupt_smtp_idle() for an example.
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @return None
 */
void dc_perform_smtp_idle(dc_context_t* context)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		dc_log_warning(context, 0, "Cannot perform SMTP-idle: Bad parameters.");
		return;
	}

	dc_log_info(context, 0, "SMTP-idle started...");

	pthread_mutex_lock(&context->smtpidle_condmutex);

		if (context->perform_smtp_jobs_needed==DC_JOBS_NEEDED_AT_ONCE)
		{
			dc_log_info(context, 0, "SMTP-idle will not be started because of waiting jobs.");
		}
		else
		{
			context->smtpidle_in_idleing = 1; // checked in suspend(), for idle-interruption the pthread-condition below is used

				do {
					int r = 0;
					struct timespec wakeup_at;
					memset(&wakeup_at, 0, sizeof(wakeup_at));
					wakeup_at.tv_sec  = time(NULL) + ((context->perform_smtp_jobs_needed==DC_JOBS_NEEDED_AVOID_DOS)? 2 : DC_SMTP_IDLE_SEC);
					while (context->smtpidle_condflag==0 && r==0) {
						r = pthread_cond_timedwait(&context->smtpidle_cond, &context->smtpidle_condmutex, &wakeup_at); // unlock mutex -> wait -> lock mutex
					}
				} while (context->smtpidle_suspend);
				context->smtpidle_condflag = 0;

			context->smtpidle_in_idleing = 0;
		}

	pthread_mutex_unlock(&context->smtpidle_condmutex);

	dc_log_info(context, 0, "SMTP-idle ended.");
}


/**
 * Interrupt waiting for smtp-jobs.
 * If dc_perform_smtp_jobs() and dc_perform_smtp_idle() are called in a loop,
 * calling this function causes jobs to be executed.
 *
 * Internally, this function is called whenever a message is to be send,
 * for the UI view it may make sense to call the function eg. on network changes.
 *
 * Example:
 *
 *     void* smtp_thread_func(void* context)
 *     {
 *         while (true) {
 *             dc_perform_smtp_jobs(context);
 *             dc_perform_smtp_idle(context);
 *         }
 *     }
 *
 *     // start smtp-thread that runs forever
 *     pthread_t smtp_thread;
 *     pthread_create(&smtp_thread, NULL, smtp_thread_func, context);
 *
 *     ... program runs ...
 *
 *     // network becomes available again - the interrupt causes
 *     // dc_perform_smtp_idle() in the thread to return so that jobs are executed
 *     dc_interrupt_smtp_idle(context);
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @return None
 */
void dc_interrupt_smtp_idle(dc_context_t* context)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		dc_log_warning(context, 0, "Interrupt SMTP-idle: Bad parameters.");
		return;
	}

	dc_log_info(context, 0, "Interrupting SMTP-idle...");

	pthread_mutex_lock(&context->smtpidle_condmutex);

		// when this function is called, it might be that the smtp-thread is in
		// perform_smtp_jobs(). if so, added jobs will be performed after the _next_ idle-jobs loop.
		// setting the flag perform_smtp_jobs_needed makes sure, idle() returns immediately in this case.
		context->perform_smtp_jobs_needed = DC_JOBS_NEEDED_AT_ONCE;

		context->smtpidle_condflag = 1;
		pthread_cond_signal(&context->smtpidle_cond);

	pthread_mutex_unlock(&context->smtpidle_condmutex);
}
