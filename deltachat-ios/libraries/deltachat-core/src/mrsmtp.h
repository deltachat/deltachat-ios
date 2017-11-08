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


#ifndef __MRSMTP_H__
#define __MRSMTP_H__
#ifdef __cplusplus
extern "C" {
#endif


#include "mrloginparam.h"


/*** library-private **********************************************************/

typedef struct mrsmtp_t
{
	mailsmtp*       m_hEtpan;
	char*           m_from;
	int             m_esmtp;
	pthread_mutex_t m_mutex;

	int             m_log_connect_errors;
	int             m_log_usual_error;

	mrmailbox_t*    m_mailbox; /* only for logging! */
} mrsmtp_t;

mrsmtp_t*    mrsmtp_new          (mrmailbox_t*);
void         mrsmtp_unref        (mrsmtp_t*);
int          mrsmtp_is_connected (const mrsmtp_t*);
int          mrsmtp_connect      (mrsmtp_t*, const mrloginparam_t*);
void         mrsmtp_disconnect   (mrsmtp_t*);
int          mrsmtp_send_msg     (mrsmtp_t*, const clist* recipients, const char* data, size_t data_bytes);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRPARAM_H__ */

