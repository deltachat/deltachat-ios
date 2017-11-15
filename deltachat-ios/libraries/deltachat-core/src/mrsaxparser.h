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


#ifndef __MRSAXPARSER_H__
#define __MRSAXPARSER_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef void (*mrsaxparser_starttag_cb_t) (void* userdata, const char* tag, char** attr);
typedef void (*mrsaxparser_endtag_cb_t)   (void* userdata, const char* tag);
typedef void (*mrsaxparser_text_cb_t)     (void* userdata, const char* text, int len); /* len is only informational, text is already null-terminated */


typedef struct mrsaxparser_t
{
	mrsaxparser_starttag_cb_t m_starttag_cb;
	mrsaxparser_endtag_cb_t   m_endtag_cb;
	mrsaxparser_text_cb_t     m_text_cb;
	void*                     m_userdata;
} mrsaxparser_t;


void           mrsaxparser_init             (mrsaxparser_t*, void* userData);
void           mrsaxparser_set_tag_handler  (mrsaxparser_t*, mrsaxparser_starttag_cb_t, mrsaxparser_endtag_cb_t);
void           mrsaxparser_set_text_handler (mrsaxparser_t*, mrsaxparser_text_cb_t);

void           mrsaxparser_parse            (mrsaxparser_t*, const char* text);

const char*    mrattr_find                  (char** attr, const char* key);


/*** library-private **********************************************************/


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRSAXPARSER_H__ */

