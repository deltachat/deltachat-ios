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


/* Some functions that are called by the backend under certain
circumstances.  The frontents should create a copy of this file
and implement the functions as needed, eg. for attaching threads in JNI. */


#include <stdlib.h>
#include "mrmailbox.h"
#include "mrosnative.h"


int mrosnative_setup_thread(mrmailbox_t* mailbox)
{
	return 1;
}


void mrosnative_unsetup_thread(mrmailbox_t* mailbox)
{
}


