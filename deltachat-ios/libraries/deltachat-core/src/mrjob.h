/*******************************************************************************
 *
 *                              Delta Chat Core
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


#ifndef __MRJOB_H__
#define __MRJOB_H__
#ifdef __cplusplus
extern "C" {
#endif


/*** library-private **********************************************************/

#define MRJ_DELETE_MSG_ON_IMAP     100    /* low priority ... */
#define MRJ_MARKSEEN_MDN_ON_IMAP   102
#define MRJ_SEND_MDN               105
#define MRJ_MARKSEEN_MSG_ON_IMAP   110
#define MRJ_SEND_MSG_TO_IMAP       700
#define MRJ_SEND_MSG_TO_SMTP       800
#define MRJ_CONNECT_TO_IMAP        900    /* ... high priority*/

typedef struct mrjob_t {
	uint32_t   m_job_id;
	int        m_action;
	uint32_t   m_foreign_id;
	mrparam_t* m_param;
	/* the following fields are set by the execution routines, m_param may also be modified */
	time_t     m_start_again_at; /* 1=on next loop, >1=on timestamp, 0=delete job (default) */
} mrjob_t;

void     mrjob_init_thread     (mrmailbox_t*);
void     mrjob_exit_thread     (mrmailbox_t*);
uint32_t mrjob_add__           (mrmailbox_t*, int action, int foreign_id, const char* param); /* returns the job_id or 0 on errors. the job may or may not be done if the function returns. */
void     mrjob_kill_action__   (mrmailbox_t*, int action); /* delete all pending jobs with the given action */

#define  MR_AT_ONCE            0
#define  MR_INCREATION_POLL    2 /* this value does not increase the number of tries */
#define  MR_STANDARD_DELAY     3
void     mrjob_try_again_later (mrjob_t*, int initial_delay_seconds);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRJOB_H__ */

