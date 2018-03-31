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


#include <stdlib.h>
#include <string.h>
#include "mrmailbox.h"
#include "mrdehtml.h"
#include "mrsaxparser.h"
#include "mrtools.h"



typedef struct dehtml_t
{
    mrstrbuilder_t m_strbuilder;

    #define DO_NOT_ADD               0
    #define DO_ADD_REMOVE_LINEENDS   1
    #define DO_ADD_PRESERVE_LINEENDS 2
    int     m_add_text;
    char*   m_last_href;

} dehtml_t;


static void dehtml_starttag_cb(void* userdata, const char* tag, char** attr)
{
	dehtml_t* dehtml = (dehtml_t*)userdata;

	if( strcmp(tag, "p")==0 || strcmp(tag, "div")==0 || strcmp(tag, "table")==0 || strcmp(tag, "td")==0 )
	{
		mrstrbuilder_cat(&dehtml->m_strbuilder, "\n\n");
		dehtml->m_add_text = DO_ADD_REMOVE_LINEENDS;
	}
	else if( strcmp(tag, "br")==0 )
	{
		mrstrbuilder_cat(&dehtml->m_strbuilder, "\n");
		dehtml->m_add_text = DO_ADD_REMOVE_LINEENDS;
	}
	else if( strcmp(tag, "style")==0 || strcmp(tag, "script")==0 || strcmp(tag, "title")==0 )
	{
		dehtml->m_add_text = DO_NOT_ADD;
	}
	else if( strcmp(tag, "pre")==0 )
	{
		mrstrbuilder_cat(&dehtml->m_strbuilder, "\n\n");
		dehtml->m_add_text = DO_ADD_PRESERVE_LINEENDS;
	}
	else if( strcmp(tag, "a")==0 )
	{
		free(dehtml->m_last_href);
		dehtml->m_last_href = strdup_keep_null(mrattr_find(attr, "href"));
		if( dehtml->m_last_href ) {
			mrstrbuilder_cat(&dehtml->m_strbuilder, "[");
		}
	}
	else if( strcmp(tag, "b")==0 || strcmp(tag, "strong")==0 )
	{
		mrstrbuilder_cat(&dehtml->m_strbuilder, "*");
	}
	else if( strcmp(tag, "i")==0 || strcmp(tag, "em")==0 )
	{
		mrstrbuilder_cat(&dehtml->m_strbuilder, "_");
	}
}


static void dehtml_text_cb(void* userdata, const char* text, int len)
{
	dehtml_t* dehtml = (dehtml_t*)userdata;

	if( dehtml->m_add_text != DO_NOT_ADD )
	{
		char* last_added = mrstrbuilder_cat(&dehtml->m_strbuilder, text);

		if( dehtml->m_add_text==DO_ADD_REMOVE_LINEENDS )
		{
			unsigned char* p = (unsigned char*)last_added;
			while( *p ) {
				if( *p=='\n' ) {
					int last_is_lineend = 1; /* avoid converting `text1<br>\ntext2` to `text1\n text2` (`\r` is removed later) */
					const unsigned char* p2 = p-1;
					while( p2>=(const unsigned char*)dehtml->m_strbuilder.m_buf ) {
						if( *p2 == '\r' ) {
						}
						else if( *p2 == '\n' ) {
							break;
						}
						else {
							last_is_lineend = 0;
							break;
						}
						p2--;
					}
					*p = last_is_lineend? '\r' : ' ';
				}
				p++;
			}
		}
	}
}


static void dehtml_endtag_cb(void* userdata, const char* tag)
{
	dehtml_t* dehtml = (dehtml_t*)userdata;

	if( strcmp(tag, "p")==0 || strcmp(tag, "div")==0 || strcmp(tag, "table")==0 || strcmp(tag, "td")==0
	 || strcmp(tag, "style")==0 || strcmp(tag, "script")==0 || strcmp(tag, "title")==0
	 || strcmp(tag, "pre")==0 )
	{
		mrstrbuilder_cat(&dehtml->m_strbuilder, "\n\n"); /* do not expect an starting block element (which, of course, should come right now) */
		dehtml->m_add_text = DO_ADD_REMOVE_LINEENDS;
	}
	else if( strcmp(tag, "a")==0 )
	{
		if( dehtml->m_last_href ) {
			mrstrbuilder_cat(&dehtml->m_strbuilder, "](");
			mrstrbuilder_cat(&dehtml->m_strbuilder, dehtml->m_last_href);
			mrstrbuilder_cat(&dehtml->m_strbuilder, ")");
			free(dehtml->m_last_href);
			dehtml->m_last_href = NULL;
		}
	}
	else if( strcmp(tag, "b")==0 || strcmp(tag, "strong")==0 )
	{
		mrstrbuilder_cat(&dehtml->m_strbuilder, "*");
	}
	else if( strcmp(tag, "i")==0 || strcmp(tag, "em")==0 )
	{
		mrstrbuilder_cat(&dehtml->m_strbuilder, "_");
	}
}


char* mr_dehtml(char* buf_terminated)
{
	mr_trim(buf_terminated);
	if( buf_terminated[0] == 0 ) {
		return safe_strdup(""); /* support at least empty HTML-messages; for empty messages, we'll replace the message by the subject later */
	}
	else {
		dehtml_t      dehtml;
		mrsaxparser_t saxparser;

		memset(&dehtml, 0, sizeof(dehtml_t));
		dehtml.m_add_text   = DO_ADD_REMOVE_LINEENDS;
		mrstrbuilder_init(&dehtml.m_strbuilder, strlen(buf_terminated));

		mrsaxparser_init(&saxparser, &dehtml);
		mrsaxparser_set_tag_handler(&saxparser, dehtml_starttag_cb, dehtml_endtag_cb);
		mrsaxparser_set_text_handler(&saxparser, dehtml_text_cb);
		mrsaxparser_parse(&saxparser, buf_terminated);

		free(dehtml.m_last_href);
		return dehtml.m_strbuilder.m_buf;
	}
}


