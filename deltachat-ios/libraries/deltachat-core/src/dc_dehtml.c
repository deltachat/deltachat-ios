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
#include "dc_context.h"
#include "dc_dehtml.h"
#include "dc_saxparser.h"
#include "dc_tools.h"
#include "dc_strbuilder.h"



typedef struct dehtml_t
{
    dc_strbuilder_t strbuilder;

    #define         DO_NOT_ADD               0
    #define         DO_ADD_REMOVE_LINEENDS   1
    #define         DO_ADD_PRESERVE_LINEENDS 2
    int             add_text;

    char*           last_href;

} dehtml_t;


static void dehtml_starttag_cb(void* userdata, const char* tag, char** attr)
{
	dehtml_t* dehtml = (dehtml_t*)userdata;

	if (strcmp(tag, "p")==0 || strcmp(tag, "div")==0 || strcmp(tag, "table")==0 || strcmp(tag, "td")==0)
	{
		dc_strbuilder_cat(&dehtml->strbuilder, "\n\n");
		dehtml->add_text = DO_ADD_REMOVE_LINEENDS;
	}
	else if (strcmp(tag, "br")==0)
	{
		dc_strbuilder_cat(&dehtml->strbuilder, "\n");
		dehtml->add_text = DO_ADD_REMOVE_LINEENDS;
	}
	else if (strcmp(tag, "style")==0 || strcmp(tag, "script")==0 || strcmp(tag, "title")==0)
	{
		dehtml->add_text = DO_NOT_ADD;
	}
	else if (strcmp(tag, "pre")==0)
	{
		dc_strbuilder_cat(&dehtml->strbuilder, "\n\n");
		dehtml->add_text = DO_ADD_PRESERVE_LINEENDS;
	}
	else if (strcmp(tag, "a")==0)
	{
		free(dehtml->last_href);
		dehtml->last_href = dc_strdup_keep_null(dc_attr_find(attr, "href"));
		if (dehtml->last_href) {
			dc_strbuilder_cat(&dehtml->strbuilder, "[");
		}
	}
	else if (strcmp(tag, "b")==0 || strcmp(tag, "strong")==0)
	{
		dc_strbuilder_cat(&dehtml->strbuilder, "*");
	}
	else if (strcmp(tag, "i")==0 || strcmp(tag, "em")==0)
	{
		dc_strbuilder_cat(&dehtml->strbuilder, "_");
	}
}


static void dehtml_text_cb(void* userdata, const char* text, int len)
{
	dehtml_t* dehtml = (dehtml_t*)userdata;

	if (dehtml->add_text != DO_NOT_ADD)
	{
		char* last_added = dc_strbuilder_cat(&dehtml->strbuilder, text);

		if (dehtml->add_text==DO_ADD_REMOVE_LINEENDS)
		{
			unsigned char* p = (unsigned char*)last_added;
			while (*p) {
				if (*p=='\n') {
					int last_is_lineend = 1; /* avoid converting `text1<br>\ntext2` to `text1\n text2` (`\r` is removed later) */
					const unsigned char* p2 = p-1;
					while (p2>=(const unsigned char*)dehtml->strbuilder.buf) {
						if (*p2=='\r') {
						}
						else if (*p2=='\n') {
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

	if (strcmp(tag, "p")==0 || strcmp(tag, "div")==0 || strcmp(tag, "table")==0 || strcmp(tag, "td")==0
	 || strcmp(tag, "style")==0 || strcmp(tag, "script")==0 || strcmp(tag, "title")==0
	 || strcmp(tag, "pre")==0)
	{
		dc_strbuilder_cat(&dehtml->strbuilder, "\n\n"); /* do not expect an starting block element (which, of course, should come right now) */
		dehtml->add_text = DO_ADD_REMOVE_LINEENDS;
	}
	else if (strcmp(tag, "a")==0)
	{
		if (dehtml->last_href) {
			dc_strbuilder_cat(&dehtml->strbuilder, "](");
			dc_strbuilder_cat(&dehtml->strbuilder, dehtml->last_href);
			dc_strbuilder_cat(&dehtml->strbuilder, ")");
			free(dehtml->last_href);
			dehtml->last_href = NULL;
		}
	}
	else if (strcmp(tag, "b")==0 || strcmp(tag, "strong")==0)
	{
		dc_strbuilder_cat(&dehtml->strbuilder, "*");
	}
	else if (strcmp(tag, "i")==0 || strcmp(tag, "em")==0)
	{
		dc_strbuilder_cat(&dehtml->strbuilder, "_");
	}
}


char* dc_dehtml(char* buf_terminated)
{
	dc_trim(buf_terminated);
	if (buf_terminated[0]==0) {
		return dc_strdup(""); /* support at least empty HTML-messages; for empty messages, we'll replace the message by the subject later */
	}
	else {
		dehtml_t       dehtml;
		dc_saxparser_t saxparser;

		memset(&dehtml, 0, sizeof(dehtml_t));
		dehtml.add_text   = DO_ADD_REMOVE_LINEENDS;
		dc_strbuilder_init(&dehtml.strbuilder, strlen(buf_terminated));

		dc_saxparser_init(&saxparser, &dehtml);
		dc_saxparser_set_tag_handler(&saxparser, dehtml_starttag_cb, dehtml_endtag_cb);
		dc_saxparser_set_text_handler(&saxparser, dehtml_text_cb);
		dc_saxparser_parse(&saxparser, buf_terminated);

		free(dehtml.last_href);
		return dehtml.strbuilder.buf;
	}
}


