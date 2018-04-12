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


/* Asynchronous "Thread-errors" are reported by the mrmailbox_log_error()
function.  These errors must be shown to the user by a bubble or so.

"Normal" errors are usually returned by a special value (null or so) and are
usually not reported using mrmailbox_log_error() - its up to the caller to
decide, what should be reported or done.  However, these "Normal" errors
are usually logged by mrmailbox_log_warning(). */


#include <stdarg.h>
#include <memory.h>
#include "mrmailbox_internal.h"


/*******************************************************************************
 * Get a unique thread ID to recognize log output from different threads
 ******************************************************************************/


int mrmailbox_get_thread_index(void)
{
	#define          MR_MAX_THREADS 32 /* if more threads are started, the full ID is printed (this may happen eg. on many failed connections so that we try to start a working thread several times) */
	static pthread_t s_threadIds[MR_MAX_THREADS];
	static int       s_threadIdsCnt = 0;

	int       i;
	pthread_t self = pthread_self();

	if( s_threadIdsCnt==0 ) {
		for( i = 0; i < MR_MAX_THREADS; i++ ) {
			s_threadIds[i] = 0;
		}
	}

	for( i = 0; i < s_threadIdsCnt; i++ ) {
		if( s_threadIds[i] == self ) {
			return i+1;
		}
	}

	if( s_threadIdsCnt >= MR_MAX_THREADS ) {
		return (int)(self); /* Fallback, this may happen, see comment above */
	}

	s_threadIds[s_threadIdsCnt] = self;
	s_threadIdsCnt++;
	return s_threadIdsCnt;
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


static void mrmailbox_log_vprintf(mrmailbox_t* mailbox, int event, int code, const char* msg_format, va_list va)
{
	char* msg = NULL;

	if( mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
	}

	/* format message from variable parameters or translate very comming errors */
	if( code == MR_ERR_SELF_NOT_IN_GROUP )
	{
		msg = mrstock_str(MR_STR_SELFNOTINGRP);
	}
	else if( code == MR_ERR_NONETWORK )
	{
		msg = mrstock_str(MR_STR_NONETWORK);
	}
	else if( msg_format )
	{
		#define BUFSIZE 1024
		char tempbuf[BUFSIZE+1];
		vsnprintf(tempbuf, BUFSIZE, msg_format, va);
		msg = safe_strdup(tempbuf);
	}

	/* if we have still no message, create one based upon  the code */
	if( msg == NULL ) {
		     if( event == MR_EVENT_INFO )    { msg = mr_mprintf("Info: %i",    (int)code); }
		else if( event == MR_EVENT_WARNING ) { msg = mr_mprintf("Warning: %i", (int)code); }
		else                                 { msg = mr_mprintf("Error: %i",   (int)code); }
	}

	/* prefix the message by the thread-id? we do this for non-errros that are normally only logged (for the few errros, the thread should be clear (enough)) */
	if( event != MR_EVENT_ERROR ) {
		char* temp = msg;
		msg = mr_mprintf("T%i: %s", (int)mrmailbox_get_thread_index(), temp);
		free(temp);
	}

	/* finally, log */
	mailbox->m_cb(mailbox, event, (uintptr_t)code, (uintptr_t)msg);

	/* remember the last N log entries */
	pthread_mutex_lock(&mailbox->m_log_ringbuf_critical);
		free(mailbox->m_log_ringbuf[mailbox->m_log_ringbuf_pos]);
		mailbox->m_log_ringbuf[mailbox->m_log_ringbuf_pos] = msg;
		mailbox->m_log_ringbuf_times[mailbox->m_log_ringbuf_pos] = time(NULL);
		mailbox->m_log_ringbuf_pos = (mailbox->m_log_ringbuf_pos+1) % MR_LOG_RINGBUF_SIZE;
	pthread_mutex_unlock(&mailbox->m_log_ringbuf_critical);
}


void mrmailbox_log_info(mrmailbox_t* mailbox, int code, const char* msg, ...)
{
	va_list va;
	va_start(va, msg); /* va_start() expects the last non-variable argument as the second parameter */
		mrmailbox_log_vprintf(mailbox, MR_EVENT_INFO, code, msg, va);
	va_end(va);
}



void mrmailbox_log_warning(mrmailbox_t* mailbox, int code, const char* msg, ...)
{
	va_list va;
	va_start(va, msg);
		mrmailbox_log_vprintf(mailbox, MR_EVENT_WARNING, code, msg, va);
	va_end(va);
}


void mrmailbox_log_error(mrmailbox_t* mailbox, int code, const char* msg, ...)
{
	va_list va;
	va_start(va, msg);
		mrmailbox_log_vprintf(mailbox, MR_EVENT_ERROR, code, msg, va);
	va_end(va);
}


void mrmailbox_log_error_if(int* condition, mrmailbox_t* mailbox, int code, const char* msg, ...)
{
	if( condition == NULL || mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
	}

	va_list va;
	va_start(va, msg);
		if( *condition ) {
			/* pop-up error, if we're offline, force a "not connected" error (the function is not used for other cases) */
			if( mailbox->m_cb(mailbox, MR_EVENT_IS_OFFLINE, 0, 0)!=0 ) {
				mrmailbox_log_vprintf(mailbox, MR_EVENT_ERROR, MR_ERR_NONETWORK, NULL, va);
			}
			else {
				mrmailbox_log_vprintf(mailbox, MR_EVENT_ERROR, code, msg, va);
			}
			*condition = 0;
		}
		else {
			/* log a warning only (eg. for subsequent connection errors) */
			mrmailbox_log_vprintf(mailbox, MR_EVENT_WARNING, code, msg, va);
		}
	va_end(va);
}


