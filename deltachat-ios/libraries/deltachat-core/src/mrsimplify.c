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
 *******************************************************************************
 *
 * File:    mrsimplify.c
 * Purpose: Simplify text, see header for details.
 *
 ******************************************************************************/


#include <stdlib.h>
#include <string.h>
#include "mrmailbox.h"
#include "mrsimplify.h"
#include "mrtools.h"
#include "mrdehtml.h"
#include "mrmimeparser.h"


/*******************************************************************************
 * Tools
 ******************************************************************************/


static int mr_is_empty_line(const char* buf)
{
	const unsigned char* p1 = (const unsigned char*)buf; /* force unsigned - otherwise the `> ' '` comparison will fail */
	while( *p1 ) {
		if( *p1 > ' ' ) {
			return 0; /* at least one character found - buffer is not empty */
		}
		p1++;
	}
	return 1; /* buffer is empty or contains only spaces, tabs, lineends etc. */
}


static int mr_is_plain_quote(const char* buf)
{
	if( buf[0] == '>' ) {
		return 1;
	}
	return 0;
}


static int mr_is_quoted_headline(const char* buf)
{
	/* This function may be called for the line _directly_ before a quote.
	The function checks if the line contains sth. like "On 01.02.2016, xy@z wrote:" in various languages.
	- Currently, we simply check if the last character is a ':'.
	- Checking for the existance of an email address may fail (headlines may show the user's name instead of the address) */

	int buf_len = strlen(buf);

	if( buf_len > 80 ) {
		return 0; /* the buffer is too long to be a quoted headline (some mailprograms (eg. "Mail" from Stock Android)
		          forget to insert a line break between the answer and the quoted headline ...)) */
	}

	if( buf_len > 0 && buf[buf_len-1] == ':' ) {
		return 1; /* the buffer is a quoting headline in the meaning described above) */
	}

	return 0;
}



/*******************************************************************************
 * Main interface
 ******************************************************************************/


mrsimplify_t* mrsimplify_new()
{
	mrsimplify_t* ths = NULL;

	if( (ths=calloc(1, sizeof(mrsimplify_t)))==NULL ) {
		exit(31);
	}

	return ths;
}


void mrsimplify_unref(mrsimplify_t* ths)
{
	if( ths == NULL ) {
		return;
	}

	free(ths);
}


/*******************************************************************************
 * Simplify Plain Text
 ******************************************************************************/


static void mrsimplify_simplify_plain_text(mrsimplify_t* ths, char* buf_terminated)
{
	/* This function ...
	... removes all text after the line `-- ` (footer mark)
	... removes full quotes at the beginning and at the end of the text -
	    these are all lines starting with the character `>`
	... remove a non-empty line before the removed quote (contains sth. like "On 2.9.2016, Bjoern wrote:" in different formats and lanugages) */

	/* TODO: If we know, the mail is from another Messenger, we could skip most of this stuff */

	/* split the given buffer into lines */
	carray* lines = mr_split_into_lines(buf_terminated);
	int l, l_first = 0, l_last = carray_count(lines)-1; /* if l_last is -1, there are no lines */
	char* line;

	/* search for the line `-- ` and ignore this and all following lines
	If the line contains more characters, it is _not_ treated as the footer start mark (hi, Thorsten) */
	for( l = l_first; l <= l_last; l++ )
	{
		line = (char*)carray_get(lines, l);
		if( strcmp(line, "-- ")==0
		 || strcmp(line, "--  ")==0 /* quoted-printable may encode `-- ` to `-- =20` which is converted back to `--  ` ... */
		 || strcmp(line, "--")==0   /* this is not documented, but occurs frequently; however, if we get problems with this, skip this HACK */
		 || strcmp(line, "---")==0  /*       - " -                                                                                          */
		 || strcmp(line, "----")==0 /*       - " -                                                                                          */ )
		{
			l_last = l - 1; /* if l_last is -1, there are no lines */
			break; /* done */
		}
	}

	/* check for "forwarding header" */
	if( (l_last-l_first+1) >= 3 ) {
		char* line0 = (char*)carray_get(lines, l_first);
		char* line1 = (char*)carray_get(lines, l_first+1);
		char* line2 = (char*)carray_get(lines, l_first+2);
		if( strcmp(line0, "---------- Forwarded message ----------")==0 /* do not chage this! sent exactly in this form in mrchat.c! */
		 && strncmp(line1, "From: ", 6)==0
		 && line2[0] == 0 )
		{
            ths->m_is_forwarded = 1;
            l_first += 3;
		}
	}

	/* remove lines that typically introduce a full quote (eg. `----- Original message -----` - as we do not parse the text 100%, we may
	also loose forwarded messages, however, the user has always the option to show the full mail text. */
	for( l = l_first; l <= l_last; l++ )
	{
		line = (char*)carray_get(lines, l);
		if( strncmp(line, "-----", 5)==0
		 || strncmp(line, "_____", 5)==0
		 || strncmp(line, "=====", 5)==0
		 || strncmp(line, "*****", 5)==0
		 || strncmp(line, "~~~~~", 5)==0 )
		{
			l_last = l - 1; /* if l_last is -1, there are no lines */
			break; /* done */
		}
	}

	/* remove full quotes at the end of the text */
	{
		int l_lastQuotedLine = -1;

		for( l = l_last; l >= l_first; l-- ) {
			line = (char*)carray_get(lines, l);
			if( mr_is_plain_quote(line) ) {
				l_lastQuotedLine = l;
			}
			else if( !mr_is_empty_line(line) ) {
				break;
			}
		}

		if( l_lastQuotedLine != -1 )
		{
			l_last = l_lastQuotedLine-1; /* if l_last is -1, there are no lines */

			if( l_last > 0 ) {
				if( mr_is_empty_line((char*)carray_get(lines, l_last)) ) { /* allow one empty line between quote and quote headline (eg. mails from Jürgen) */
					l_last--;
				}
			}

			if( l_last > 0 ) {
				line = (char*)carray_get(lines, l_last);
				if( mr_is_quoted_headline(line) ) {
					l_last--;
				}
			}
		}
	}

	/* remove full quotes at the beginning of the text */
	{
		int l_lastQuotedLine = -1;
		int hasQuotedHeadline = 0;

		for( l = l_first; l <= l_last; l++ ) {
			line = (char*)carray_get(lines, l);
			if( mr_is_plain_quote(line) ) {
				l_lastQuotedLine = l;
			}
			else if( !mr_is_empty_line(line) ) {
				if( mr_is_quoted_headline(line) && !hasQuotedHeadline && l_lastQuotedLine == -1 ) {
					hasQuotedHeadline = 1; /* continue, the line may be a headline */
				}
				else {
					break; /* non-quoting line found */
				}
			}
		}

		if( l_lastQuotedLine != -1 )
		{
			l_first = l_lastQuotedLine + 1;
		}
	}

	/* re-create buffer from the remaining lines */
	char* p1 = buf_terminated;
	*p1 = 0; /* make sure, the string is terminated if there are no lines (l_last==-1) */

	int add_nl = 0; /* we write empty lines only in case and non-empty line follows */

	for( l = l_first; l <= l_last; l++ )
	{
		line = (char*)carray_get(lines, l);

		if( mr_is_empty_line(line) )
		{
			add_nl++;
		}
		else
		{
			if( p1 != buf_terminated ) /* flush empty lines - except if we're at the start of the buffer */
			{
				if( add_nl > 2 ) { add_nl = 2; } /* ignore more than one empty line (however, regard normal line ends) */
				while( add_nl ) {
					*p1 = '\n';
					p1++;
					add_nl--;
				}
			}

			size_t line_len = strlen(line);

			strcpy(p1, line);

			p1 = &p1[line_len]; /* points to the current terminating nullcharacters which is overwritten with the next line */
			add_nl = 1;
		}
	}

	mr_free_splitted_lines(lines);
}


/*******************************************************************************
 * Simplify Entry Point
 ******************************************************************************/


char* mrsimplify_simplify(mrsimplify_t* ths, const char* in_unterminated, int in_bytes, int is_html)
{
	/* create a copy of the given buffer */
	char* out = NULL;

	if( in_unterminated == NULL || in_bytes <= 0 ) {
		return safe_strdup("");
	}

	out = strndup((char*)in_unterminated, in_bytes); /* strndup() makes sure, the string is null-terminated */
	if( out == NULL ) {
		return safe_strdup("");
	}

	/* convert HTML to text, if needed */
	if( is_html ) {
		char* temp = mr_dehtml(out); /* mr_dehtml() returns way too much lineends, however they're removed in the simplification below */
		if( temp ) {
			free(out);
			out = temp;
		}
	}

	/* simplify the text in the buffer (characters to remove may be marked by `\r`) */
	mr_remove_cr_chars(out); /* make comparisons easier, eg. for line `-- ` */
	mrsimplify_simplify_plain_text(ths, out);

	/* remove all `\r` from string */
	mr_remove_cr_chars(out);

	return out;
}
