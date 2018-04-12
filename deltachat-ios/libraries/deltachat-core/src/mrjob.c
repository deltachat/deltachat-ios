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
#include "mrjob.h"
#include "mrosnative.h"


/*******************************************************************************
 * The job thread
 ******************************************************************************/


static int get_wait_seconds(mrmailbox_t* mailbox) // >0: wait seconds, =0: do not wait, <0: wait until signal
{
	int           ret = -1;
	sqlite3_stmt* stmt;

	mrsqlite3_lock(mailbox->m_sql);
		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_MIN_d_FROM_jobs, "SELECT MIN(desired_timestamp) FROM jobs;");
		if( stmt && sqlite3_step(stmt) == SQLITE_ROW )
		{
			if( sqlite3_column_type(stmt, 0)!=SQLITE_NULL )
			{
				time_t min_desired_timestamp = (time_t)sqlite3_column_int64(stmt, 0);
				time_t now = time(NULL);
				if( min_desired_timestamp <= now ) {
					ret = 0;
				}
				else {
					ret = (int)(min_desired_timestamp-now) + 1 /*wait a second longer, pthread_cond_timedwait() is not _that_ exact and we want to be sure to catch the jobs in the first try*/;
				}
			}
		}
	mrsqlite3_unlock(mailbox->m_sql);

	return ret;
}


static void* job_thread_entry_point(void* entry_arg)
{
	mrmailbox_t*  mailbox = (mrmailbox_t*)entry_arg;
	mrosnative_setup_thread(mailbox); /* must be very first */

	sqlite3_stmt* stmt;
	mrjob_t       job;
	int           seconds_to_wait;

	memset(&job, 0, sizeof(mrjob_t));
	job.m_param = mrparam_new();

	/* init thread */
	mrmailbox_log_info(mailbox, 0, "Job thread entered.");

	while( 1 )
	{
		/* wait for condition */
		pthread_mutex_lock(&mailbox->m_job_condmutex);
			seconds_to_wait = get_wait_seconds(mailbox);
			if( seconds_to_wait > 0 ) {
				mrmailbox_log_info(mailbox, 0, "Job thread waiting for %i seconds or signal...", seconds_to_wait);
				if( mailbox->m_job_condflag == 0 ) {
					struct timespec timeToWait;
					timeToWait.tv_sec  = time(NULL)+seconds_to_wait;
					timeToWait.tv_nsec = 0;
					pthread_cond_timedwait(&mailbox->m_job_cond, &mailbox->m_job_condmutex, &timeToWait);
				}
			}
			else if( seconds_to_wait < 0 ) {
				mrmailbox_log_info(mailbox, 0, "Job thread waiting for signal...");
				while( mailbox->m_job_condflag == 0 ) {
					pthread_cond_wait(&mailbox->m_job_cond, &mailbox->m_job_condmutex); /* wait unlocks the mutex and waits for signal; if it returns, the mutex is locked again */
				}
			}
			mailbox->m_job_condflag = 0;
		pthread_mutex_unlock(&mailbox->m_job_condmutex);

		/* do all waiting jobs */
		mrmailbox_log_info(mailbox, 0, "Job thread checks for pending jobs...");
		while( 1 )
		{
			pthread_mutex_lock(&mailbox->m_job_condmutex);
				if( mailbox->m_job_do_exit ) {
					pthread_mutex_unlock(&mailbox->m_job_condmutex);
					goto exit_;
				}
			pthread_mutex_unlock(&mailbox->m_job_condmutex);

			/* get next waiting job */
			job.m_job_id = 0;
			mrsqlite3_lock(mailbox->m_sql);
				stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_iafp_FROM_jobs,
					"SELECT id, action, foreign_id, param FROM jobs WHERE desired_timestamp<=? ORDER BY action DESC, id LIMIT 1;");
				sqlite3_bind_int64(stmt, 1, time(NULL));
				if( sqlite3_step(stmt) == SQLITE_ROW ) {
					job.m_job_id                         = sqlite3_column_int (stmt, 0);
					job.m_action                         = sqlite3_column_int (stmt, 1);
					job.m_foreign_id                     = sqlite3_column_int (stmt, 2);
					mrparam_set_packed(job.m_param, (char*)sqlite3_column_text(stmt, 3));
				}
			mrsqlite3_unlock(mailbox->m_sql);

			if( job.m_job_id == 0 ) {
				break;
			}

			/* execute job */
			mrmailbox_log_info(mailbox, 0, "Executing job #%i, action %i...", (int)job.m_job_id, (int)job.m_action);
			job.m_start_again_at = 0;
			switch( job.m_action ) {
				case MRJ_CONNECT_TO_IMAP:      mrmailbox_connect_to_imap      (mailbox, &job); break;
                case MRJ_SEND_MSG_TO_SMTP:     mrmailbox_send_msg_to_smtp     (mailbox, &job); break;
                case MRJ_SEND_MSG_TO_IMAP:     mrmailbox_send_msg_to_imap     (mailbox, &job); break;
                case MRJ_DELETE_MSG_ON_IMAP:   mrmailbox_delete_msg_on_imap   (mailbox, &job); break;
                case MRJ_MARKSEEN_MSG_ON_IMAP: mrmailbox_markseen_msg_on_imap (mailbox, &job); break;
                case MRJ_MARKSEEN_MDN_ON_IMAP: mrmailbox_markseen_mdn_on_imap (mailbox, &job); break;
                case MRJ_SEND_MDN:             mrmailbox_send_mdn             (mailbox, &job); break;
			}

			/* delete job or execute job later again */
			if( job.m_start_again_at ) {
				mrsqlite3_lock(mailbox->m_sql);
					stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_jobs_SET_dp_WHERE_id,
						"UPDATE jobs SET desired_timestamp=?, param=? WHERE id=?;");
					sqlite3_bind_int64(stmt, 1, job.m_start_again_at);
					sqlite3_bind_text (stmt, 2, job.m_param->m_packed, -1, SQLITE_STATIC);
					sqlite3_bind_int  (stmt, 3, job.m_job_id);
					sqlite3_step(stmt);
				mrsqlite3_unlock(mailbox->m_sql);
				mrmailbox_log_info(mailbox, 0, "Job #%i delayed for %i seconds", (int)job.m_job_id, (int)(job.m_start_again_at-time(NULL)));
			}
			else {
				mrsqlite3_lock(mailbox->m_sql);
					stmt = mrsqlite3_predefine__(mailbox->m_sql, DELETE_FROM_jobs_WHERE_id,
						"DELETE FROM jobs WHERE id=?;");
					sqlite3_bind_int(stmt, 1, job.m_job_id);
					sqlite3_step(stmt);
				mrsqlite3_unlock(mailbox->m_sql);
				mrmailbox_log_info(mailbox, 0, "Job #%i done and deleted from database", (int)job.m_job_id);
			}
		}

	}

	/* exit thread */
exit_:
	mrparam_unref(job.m_param);
	mrmailbox_log_info(mailbox, 0, "Exit job thread.");
	mrosnative_unsetup_thread(mailbox); /* must be very last */
	return NULL;
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


void mrjob_init_thread(mrmailbox_t* mailbox)
{
	pthread_mutex_init(&mailbox->m_job_condmutex, NULL);
    pthread_cond_init(&mailbox->m_job_cond, NULL);
    pthread_create(&mailbox->m_job_thread, NULL, job_thread_entry_point, mailbox);
}


void mrjob_exit_thread(mrmailbox_t* mailbox)
{
	pthread_mutex_lock(&mailbox->m_job_condmutex);
		mailbox->m_job_condflag = 1;
		mailbox->m_job_do_exit = 1;
		pthread_cond_signal(&mailbox->m_job_cond);
	pthread_mutex_unlock(&mailbox->m_job_condmutex);

	pthread_join(mailbox->m_job_thread, NULL);
	pthread_cond_destroy(&mailbox->m_job_cond);
	pthread_mutex_destroy(&mailbox->m_job_condmutex);
}


uint32_t mrjob_add__(mrmailbox_t* mailbox, int action, int foreign_id, const char* param, int delay_seconds)
{
	time_t        timestamp = time(NULL);
	sqlite3_stmt* stmt;
	uint32_t      job_id = 0;

	stmt = mrsqlite3_predefine__(mailbox->m_sql, INSERT_INTO_jobs_aafp,
		"INSERT INTO jobs (added_timestamp, action, foreign_id, param, desired_timestamp) VALUES (?,?,?,?,?);");
	sqlite3_bind_int64(stmt, 1, timestamp);
	sqlite3_bind_int  (stmt, 2, action);
	sqlite3_bind_int  (stmt, 3, foreign_id);
	sqlite3_bind_text (stmt, 4, param? param : "",  -1, SQLITE_STATIC);
	sqlite3_bind_int64(stmt, 5, delay_seconds>0? (timestamp+delay_seconds) : 0);
	if( sqlite3_step(stmt) != SQLITE_DONE ) {
		return 0;
	}

	job_id = sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj);

	pthread_mutex_lock(&mailbox->m_job_condmutex);
		if( !mailbox->m_job_do_exit ) {
			mrmailbox_log_info(mailbox, 0, "Signal job thread to wake up...");
			mailbox->m_job_condflag = 1;
			pthread_cond_signal(&mailbox->m_job_cond);
		}
	pthread_mutex_unlock(&mailbox->m_job_condmutex);

	return job_id;
}


void mrjob_try_again_later(mrjob_t* ths, int initial_delay_seconds)
{
	if( ths == NULL ) { /* may be NULL if called eg. from mrmailbox_connect_to_imap() */
		return;
	}

	if( initial_delay_seconds == MR_INCREATION_POLL )
	{
		int tries = mrparam_get_int(ths->m_param, MRP_TIMES_INCREATION, 0) + 1;
		mrparam_set_int(ths->m_param, MRP_TIMES_INCREATION, tries);

		if( tries < 120/MR_INCREATION_POLL ) {
			ths->m_start_again_at = time(NULL)+MR_INCREATION_POLL;
		}
		else {
			ths->m_start_again_at = time(NULL)+10; /* after two minutes of waiting, try less often */
		}
	}
	else
	{
		int tries = mrparam_get_int(ths->m_param, MRP_TIMES, 0) + 1;
		mrparam_set_int(ths->m_param, MRP_TIMES, tries);

		if( tries == 1 ) {
			ths->m_start_again_at = time(NULL)+initial_delay_seconds;
		}
		else if( tries < 5 ) {
			ths->m_start_again_at = time(NULL)+60;
		}
		else {
			ths->m_start_again_at = time(NULL)+600;
		}
	}
}


void mrjob_kill_action__(mrmailbox_t* mailbox, int action)
{
	if( mailbox == NULL ) {
		return;
	}

	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, DELETE_FROM_jobs_WHERE_action,
		"DELETE FROM jobs WHERE action=?;");
	sqlite3_bind_int(stmt, 1, action);
	sqlite3_step(stmt);
}

