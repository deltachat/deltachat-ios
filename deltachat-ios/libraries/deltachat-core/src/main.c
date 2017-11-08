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


/* This is a CLI program and a little testing frame.  This file must not be
included when using Delta Chat Core as a library.

Usage:  messenger-backend <databasefile>
(for "Code::Blocks, use Project / Set programs' arguments")
all further options can be set using the set-command (type ? for help). */


#include <string.h>
#include "mrmailbox.h"
#include "mrmailbox_internal.h"
#include "stress.h"


static char* read_cmd(void)
{
	printf("> ");
	static char cmdbuffer[1024];
	fgets(cmdbuffer, 1000, stdin);

	while( strlen(cmdbuffer)>0
	 && (cmdbuffer[strlen(cmdbuffer)-1]=='\n' || cmdbuffer[strlen(cmdbuffer)-1]==' ') )
	{
		cmdbuffer[strlen(cmdbuffer)-1] = '\0';
	}

	return cmdbuffer;
}


static uintptr_t receive_event(mrmailbox_t* mailbox, int event, uintptr_t data1, uintptr_t data2)
{
	switch( event ) {
		case MR_EVENT_GET_STRING:
		case MR_EVENT_GET_QUANTITY_STRING:
		case MR_EVENT_WAKE_LOCK:
			break; /* do not show the event as this would fill the screen */

		case MR_EVENT_IS_ONLINE:
			return 1;

		case MR_EVENT_INFO:
			printf("%s\n", (char*)data2);
			break;

		case MR_EVENT_WARNING:
			printf("[Warning] %s\n", (char*)data2);
			break;

		case MR_EVENT_ERROR:
			printf("[ERROR #%i] %s\n", (int)data1, (char*)data2);
			break;

		case MR_EVENT_HTTP_GET:
			{
				char* ret = NULL;
				char* tempFile = mr_get_fine_pathNfilename(mailbox->m_blobdir, "curl.result");
				char* cmd = mr_mprintf("curl --silent --location --fail %s > %s", (char*)data1, tempFile); /* --location = follow redirects */
				int error = system(cmd);
				if( error == 0 ) { /* -1=system() error, !0=curl errors forced by -f, 0=curl success */
					size_t bytes = 0;
					mr_read_file(tempFile, (void**)&ret, &bytes, mailbox);
				}
				free(cmd);
				free(tempFile);
				return (uintptr_t)ret;
			}

		case MR_EVENT_IMEX_FILE_WRITTEN:
			printf("{{Received event MR_EVENT_IMEX_FILE_WRITTEN (%s, %s)}}\n", (char*)data1, (char*)data2);
			break;

		default:
			printf("{{Received event #%i (%i, %i)}}\n", (int)event, (int)data1, (int)data2);
			break;
	}
	return 0;
}


int main(int argc, char ** argv)
{
	mrmailbox_t* mailbox = mrmailbox_new(receive_event, NULL, "CLI");

	mrmailbox_cmdline_skip_auth(mailbox); /* disable the need to enter the command `auth <password>` for all mailboxes. */

	printf("Delta Chat Core is awaiting your commands.\n"); /* use neutral speach here, the Delta Chat Core is not directly related to any front end or end-product. */

	/* open database from the commandline (if omitted, it can be opened using the `open`-command) */
	if( argc == 2 ) {
		if( !mrmailbox_open(mailbox, argv[1], NULL) ) {
			printf("ERROR: Cannot open mailbox.\n");
		}
	}
	else if( argc != 1 ) {
		printf("ERROR: Bad arguments\n");
	}

	stress_functions(mailbox);

	/* wait for command */
	while(1)
	{
		/* read command */
		const char* cmd = read_cmd();

		if( strcmp(cmd, "clear")==0 )
		{
			printf("\n\n\n\n"); /* insert some blank lines to visualize the break in the buffer */
			printf("\e[1;1H\e[2J"); /* should work on ANSI terminals and on Windows 10. If not, well, then not. */
		}
		else if( strcmp(cmd, "exit")==0 )
		{
			break;
		}
		else if( cmd[0] == 0 )
		{
			; /* nothing typed */
		}
		else
		{
			char* execute_result = mrmailbox_cmdline(mailbox, cmd);
			if( execute_result ) {
				printf("%s\n", execute_result);
				free(execute_result);
			}
		}
	}

	mrmailbox_close(mailbox);
	mrmailbox_unref(mailbox);
	mailbox = NULL;
	return 0;
}

