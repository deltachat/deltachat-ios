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


#ifndef __DC_SAXPARSER_H__
#define __DC_SAXPARSER_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef void (*dc_saxparser_starttag_cb_t) (void* userdata, const char* tag, char** attr);
typedef void (*dc_saxparser_endtag_cb_t)   (void* userdata, const char* tag);
typedef void (*dc_saxparser_text_cb_t)     (void* userdata, const char* text, int len); /* len is only informational, text is already null-terminated */


typedef struct dc_saxparser_t
{
	dc_saxparser_starttag_cb_t starttag_cb;
	dc_saxparser_endtag_cb_t   endtag_cb;
	dc_saxparser_text_cb_t     text_cb;
	void*                      userdata;
} dc_saxparser_t;


void           dc_saxparser_init             (dc_saxparser_t*, void* userData);
void           dc_saxparser_set_tag_handler  (dc_saxparser_t*, dc_saxparser_starttag_cb_t, dc_saxparser_endtag_cb_t);
void           dc_saxparser_set_text_handler (dc_saxparser_t*, dc_saxparser_text_cb_t);

void           dc_saxparser_parse            (dc_saxparser_t*, const char* text);

const char*    dc_attr_find                  (char** attr, const char* key);


/*** library-private **********************************************************/


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_SAXPARSER_H__ */

