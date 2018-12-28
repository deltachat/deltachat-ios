#include <stdlib.h>
#include <string.h>
#include "dc_context.h"
#include "dc_simplify.h"
#include "dc_tools.h"
#include "dc_dehtml.h"
#include "dc_mimeparser.h"
#include "dc_strbuilder.h"


/*******************************************************************************
 * Tools
 ******************************************************************************/


static int is_empty_line(const char* buf)
{
	const unsigned char* p1 = (const unsigned char*)buf; /* force unsigned - otherwise the `> ' '` comparison will fail */
	while (*p1) {
		if (*p1 > ' ') {
			return 0; /* at least one character found - buffer is not empty */
		}
		p1++;
	}
	return 1; /* buffer is empty or contains only spaces, tabs, lineends etc. */
}


static int is_plain_quote(const char* buf)
{
	if (buf[0]=='>') {
		return 1;
	}
	return 0;
}


static int is_quoted_headline(const char* buf)
{
	/* This function may be called for the line _directly_ before a quote.
	The function checks if the line contains sth. like "On 01.02.2016, xy@z wrote:" in various languages.
	- Currently, we simply check if the last character is a ':'.
	- Checking for the existance of an email address may fail (headlines may show the user's name instead of the address) */

	int buf_len = strlen(buf);

	if (buf_len > 80) {
		return 0; /* the buffer is too long to be a quoted headline (some mailprograms (eg. "Mail" from Stock Android)
		          forget to insert a line break between the answer and the quoted headline ...)) */
	}

	if (buf_len > 0 && buf[buf_len-1]==':') {
		return 1; /* the buffer is a quoting headline in the meaning described above) */
	}

	return 0;
}



/*******************************************************************************
 * Main interface
 ******************************************************************************/


dc_simplify_t* dc_simplify_new()
{
	dc_simplify_t* simplify = NULL;

	if ((simplify=calloc(1, sizeof(dc_simplify_t)))==NULL) {
		exit(31);
	}

	return simplify;
}


void dc_simplify_unref(dc_simplify_t* simplify)
{
	if (simplify==NULL) {
		return;
	}

	free(simplify);
}


/*******************************************************************************
 * Simplify Plain Text
 ******************************************************************************/


static char* dc_simplify_simplify_plain_text(dc_simplify_t* simplify, const char* buf_terminated)
{
	/* This function ...
	... removes all text after the line `-- ` (footer mark)
	... removes full quotes at the beginning and at the end of the text -
	    these are all lines starting with the character `>`
	... remove a non-empty line before the removed quote (contains sth. like "On 2.9.2016, Bjoern wrote:" in different formats and lanugages) */

	/* we could skip some of this stuff if we know that the mail is from another messenger,
	however, this adds some additional complexity and seems not to be needed currently */

	/* split the given buffer into lines */
	carray* lines = dc_split_into_lines(buf_terminated);
	int     l = 0;
	int     l_first = 0;
	int     l_last = carray_count(lines)-1; /* if l_last is -1, there are no lines */
	char*   line = NULL;

	/* search for the line `-- ` and ignore this and all following lines
	If the line contains more characters, it is _not_ treated as the footer start mark (hi, Thorsten) */
	{
		int footer_mark = 0;
		for (l = l_first; l <= l_last; l++)
		{
			/* hide standard footer, "-- " - we do not set is_cut_at_end if we find this mark */
			line = (char*)carray_get(lines, l);
			if (strcmp(line, "-- ")==0
			 || strcmp(line, "--  ")==0) { /* quoted-printable may encode `-- ` to `-- =20` which is converted back to `--  ` ... */
				footer_mark = 1;
			}

			/* also hide some non-standard footers - they got is_cut_at_end set, however  */
			if (strcmp(line, "--")==0
			 || strcmp(line, "---")==0
			 || strcmp(line, "----")==0) {
				footer_mark = 1;
				simplify->is_cut_at_end = 1;
			}

			if (footer_mark) {
				l_last = l - 1; /* if l_last is -1, there are no lines */
				break; /* done */
			}
		}
	}

	/* check for "forwarding header" */
	if ((l_last-l_first+1) >= 3) {
		char* line0 = (char*)carray_get(lines, l_first);
		char* line1 = (char*)carray_get(lines, l_first+1);
		char* line2 = (char*)carray_get(lines, l_first+2);
		if (strcmp(line0, "---------- Forwarded message ----------")==0 /* do not chage this! sent exactly in this form in dc_chat.c! */
		 && strncmp(line1, "From: ", 6)==0
		 && line2[0]==0)
		{
            simplify->is_forwarded = 1; /* nothing is cutted, the forward state should displayed explicitly in the ui */
            l_first += 3;
		}
	}

	/* remove lines that typically introduce a full quote (eg. `----- Original message -----` - as we do not parse the text 100%, we may
	also loose forwarded messages, however, the user has always the option to show the full mail text. */
	for (l = l_first; l <= l_last; l++)
	{
		line = (char*)carray_get(lines, l);
		if (strncmp(line, "-----", 5)==0
		 || strncmp(line, "_____", 5)==0
		 || strncmp(line, "=====", 5)==0
		 || strncmp(line, "*****", 5)==0
		 || strncmp(line, "~~~~~", 5)==0)
		{
			l_last = l - 1; /* if l_last is -1, there are no lines */
			simplify->is_cut_at_end = 1;
			break; /* done */
		}
	}

	/* remove full quotes at the end of the text */
	{
		int l_lastQuotedLine = -1;

		for (l = l_last; l >= l_first; l--) {
			line = (char*)carray_get(lines, l);
			if (is_plain_quote(line)) {
				l_lastQuotedLine = l;
			}
			else if (!is_empty_line(line)) {
				break;
			}
		}

		if (l_lastQuotedLine != -1)
		{
			l_last = l_lastQuotedLine-1; /* if l_last is -1, there are no lines */
			simplify->is_cut_at_end = 1;

			if (l_last > 0) {
				if (is_empty_line((char*)carray_get(lines, l_last))) { /* allow one empty line between quote and quote headline (eg. mails from Jürgen) */
					l_last--;
				}
			}

			if (l_last > 0) {
				line = (char*)carray_get(lines, l_last);
				if (is_quoted_headline(line)) {
					l_last--;
				}
			}
		}
	}

	/* remove full quotes at the beginning of the text */
	{
		int l_lastQuotedLine = -1;
		int hasQuotedHeadline = 0;

		for (l = l_first; l <= l_last; l++) {
			line = (char*)carray_get(lines, l);
			if (is_plain_quote(line)) {
				l_lastQuotedLine = l;
			}
			else if (!is_empty_line(line)) {
				if (is_quoted_headline(line) && !hasQuotedHeadline && l_lastQuotedLine==-1) {
					hasQuotedHeadline = 1; /* continue, the line may be a headline */
				}
				else {
					break; /* non-quoting line found */
				}
			}
		}

		if (l_lastQuotedLine != -1)
		{
			l_first = l_lastQuotedLine + 1;
			simplify->is_cut_at_begin = 1;
		}
	}

	/* re-create buffer from the remaining lines */
	dc_strbuilder_t ret;
	dc_strbuilder_init(&ret, strlen(buf_terminated));

	if (simplify->is_cut_at_begin) {
		dc_strbuilder_cat(&ret, DC_EDITORIAL_ELLIPSE " ");
	}

	int pending_linebreaks = 0; /* we write empty lines only in case and non-empty line follows */
	int content_lines_added = 0;

	for (l = l_first; l <= l_last; l++)
	{
		line = (char*)carray_get(lines, l);

		if (is_empty_line(line))
		{
			pending_linebreaks++;
		}
		else
		{
			if (content_lines_added) /* flush empty lines - except if we're at the start of the buffer */
			{
				if (pending_linebreaks > 2) { pending_linebreaks = 2; } /* ignore more than one empty line (however, regard normal line ends) */
				while (pending_linebreaks) {
					dc_strbuilder_cat(&ret, "\n");
					pending_linebreaks--;
				}
			}

			dc_strbuilder_cat(&ret, line);
			content_lines_added++;
			pending_linebreaks = 1;
		}
	}

	if (simplify->is_cut_at_end
	 && (!simplify->is_cut_at_begin || content_lines_added) /* avoid two `[...]` without content */) {
		dc_strbuilder_cat(&ret, " " DC_EDITORIAL_ELLIPSE);
	}

	dc_free_splitted_lines(lines);

	return ret.buf;
}


/*******************************************************************************
 * Simplify Entry Point
 ******************************************************************************/


char* dc_simplify_simplify(dc_simplify_t* simplify, const char* in_unterminated, int in_bytes, int is_html)
{
	/* create a copy of the given buffer */
	char* out = NULL;
	char* temp = NULL;

	if (simplify==NULL || in_unterminated==NULL || in_bytes <= 0) {
		return dc_strdup("");
	}

	simplify->is_forwarded    = 0;
	simplify->is_cut_at_begin = 0;
	simplify->is_cut_at_end   = 0;

	out = strndup((char*)in_unterminated, in_bytes); /* strndup() makes sure, the string is null-terminated */
	if (out==NULL) {
		return dc_strdup("");
	}

	/* convert HTML to text, if needed */
	if (is_html) {
		if ((temp = dc_dehtml(out)) != NULL) { /* dc_dehtml() returns way too much lineends, however they're removed in the simplification below */
			free(out);
			out = temp;
		}
	}

	/* simplify the text in the buffer (characters to remove may be marked by `\r`) */
	dc_remove_cr_chars(out); /* make comparisons easier, eg. for line `-- ` */
	if ((temp = dc_simplify_simplify_plain_text(simplify, out)) != NULL) {
		free(out);
		out = temp;
	}

	/* remove all `\r` from string */
	dc_remove_cr_chars(out);

	return out;
}
