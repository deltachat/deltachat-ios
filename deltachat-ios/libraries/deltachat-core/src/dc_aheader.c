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


#include <ctype.h>
#include "dc_context.h"
#include "dc_aheader.h"
#include "dc_apeerstate.h"
#include "dc_mimeparser.h"


/**
 * Empty an Autocrypt-header object and free all data associated with it.
 *
 * @private @memberof dc_aheader_t
 *
 * @param aheader The Autocrypt-header object. If you pass NULL here, the function does nothing.
 *
 * @return None
 */
void dc_aheader_empty(dc_aheader_t* aheader)
{
	if (aheader==NULL) {
		return;
	}

	aheader->prefer_encrypt = 0;

	free(aheader->addr);
	aheader->addr = NULL;

	if (aheader->public_key->binary) {
		dc_key_unref(aheader->public_key);
		aheader->public_key = dc_key_new();
	}
}


/*******************************************************************************
 * Render Autocrypt Header
 ******************************************************************************/


/**
 * @memberof dc_aheader_t
 */
char* dc_aheader_render(const dc_aheader_t* aheader)
{
	int             success = 0;
	char*           keybase64_wrapped = NULL;
	dc_strbuilder_t ret;
	dc_strbuilder_init(&ret, 0);

	if (aheader==NULL || aheader->addr==NULL || aheader->public_key->binary==NULL || aheader->public_key->type!=DC_KEY_PUBLIC) {
		goto cleanup;
	}

	dc_strbuilder_cat(&ret, "addr=");
	dc_strbuilder_cat(&ret, aheader->addr);
	dc_strbuilder_cat(&ret, "; ");

	if (aheader->prefer_encrypt==DC_PE_MUTUAL) {
		dc_strbuilder_cat(&ret, "prefer-encrypt=mutual; ");
	}

	dc_strbuilder_cat(&ret, "keydata= "); /* the trailing space together with dc_insert_breaks() allows a proper transport */

	/* adds a whitespace every 78 characters, this allows libEtPan to wrap the lines according to RFC 5322
	(which may insert a linebreak before every whitespace) */
	if ((keybase64_wrapped = dc_key_render_base64(aheader->public_key, 78, " ", 0/*no checksum*/))==NULL) {
		goto cleanup;
	}

	dc_strbuilder_cat(&ret, keybase64_wrapped);

	success = 1;

cleanup:
	if (!success) { free(ret.buf); ret.buf = NULL; }
	free(keybase64_wrapped);
	return ret.buf; /* NULL on errors, this may happen for various reasons */
}


/*******************************************************************************
 * Parse Autocrypt Header
 ******************************************************************************/


static int add_attribute(dc_aheader_t* aheader, const char* name, const char* value /*may be NULL*/)
{
	/* returns 0 if the attribute will result in an invalid header, 1 if the attribute is okay */
	if (strcasecmp(name, "addr")==0)
	{
		if (value==NULL
		 || strlen(value) < 3 || strchr(value, '@')==NULL || strchr(value, '.')==NULL /* rough check if email-address is valid */
		 || aheader->addr /* email already given */) {
			return 0;
		}
		aheader->addr = dc_addr_normalize(value);
		return 1;
	}
	#if 0 /* autocrypt 11/2017 no longer uses the type attribute and it will make the autocrypt header invalid */
	else if (strcasecmp(name, "type")==0)
	{
		if (value==NULL) {
			return 0; /* attribute with no value results in an invalid header */
		}
		if (strcasecmp(value, "1")==0 || strcasecmp(value, "0" /*deprecated*/)==0 || strcasecmp(value, "p" /*deprecated*/)==0) {
			return 1; /* PGP-type */
		}
		return 0; /* unknown types result in an invalid header */
	}
	#endif
	else if (strcasecmp(name, "prefer-encrypt")==0)
	{
		if (value && strcasecmp(value, "mutual")==0) {
			aheader->prefer_encrypt = DC_PE_MUTUAL;
			return 1;
		}
		return 1; /* An Autocrypt level 0 client that sees the attribute with any other value (or that does not see the attribute at all) should interpret the value as nopreference.*/
	}
	else if (strcasecmp(name, "keydata")==0)
	{
		if (value==NULL
		 || aheader->public_key->binary || aheader->public_key->bytes) {
			return 0; /* there is already a k*/
		}
		return dc_key_set_from_base64(aheader->public_key, value, DC_KEY_PUBLIC);
	}
	else if (name[0]=='_')
	{
		/* Autocrypt-Level0: unknown attributes starting with an underscore can be safely ignored */
		return 1;
	}

	/* Autocrypt-Level0: unknown attribute, treat the header as invalid */
	return 0;
}


/**
 * @memberof dc_aheader_t
 */
int dc_aheader_set_from_string(dc_aheader_t* aheader, const char* header_str__)
{
	/* according to RFC 5322 (Internet Message Format), the given string may contain `\r\n` before any whitespace.
	we can ignore this issue as
	(a) no key or value is expected to contain spaces,
	(b) for the key, non-base64-characters are ignored and
	(c) for parsing, we ignore `\r\n` as well as tabs for spaces */
	#define AHEADER_WS "\t\r\n "
	char*   header_str = NULL;
	char*   p = NULL;
	char*   beg_attr_name = NULL;
	char*   after_attr_name = NULL;
	char*   beg_attr_value = NULL;
	int     success = 0;

	dc_aheader_empty(aheader);

	if (aheader==NULL || header_str__==NULL) {
		goto cleanup;
	}

	aheader->prefer_encrypt = DC_PE_NOPREFERENCE; /* value to use if the prefer-encrypted header is missing */

	header_str = dc_strdup(header_str__);
	p = header_str;
	while (*p)
	{
		p += strspn(p, AHEADER_WS "=;"); /* forward to first attribute name beginning */
		beg_attr_name = p;
		beg_attr_value = NULL;
		p += strcspn(p, AHEADER_WS "=;"); /* get end of attribute name (an attribute may have no value) */
		if (p!=beg_attr_name)
		{
			/* attribute found */
			after_attr_name = p;
			p += strspn(p, AHEADER_WS); /* skip whitespace between attribute name and possible `=` */
			if (*p=='=')
			{
				p += strspn(p, AHEADER_WS "="); /* skip spaces and equal signs */

				/* read unquoted attribute value until the first semicolon */
				beg_attr_value = p;
				p += strcspn(p, ";");
				if (*p!='\0') {
					*p = '\0';
					p++;
				}
				dc_trim(beg_attr_value);
			}
			else
			{
				p += strspn(p, AHEADER_WS ";");
			}
			*after_attr_name = '\0';
			if (!add_attribute(aheader, beg_attr_name, beg_attr_value)) {
				goto cleanup; /* a bad attribute makes the whole header invalid */
			}
		}
	}

	/* all needed data found? */
	if (aheader->addr && aheader->public_key->binary) {
		success = 1;
	}

cleanup:
	free(header_str);
	if (!success) { dc_aheader_empty(aheader); }
	return success;
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


/**
 * @memberof dc_aheader_t
 */
dc_aheader_t* dc_aheader_new()
{
	dc_aheader_t* aheader = NULL;

	if ((aheader=calloc(1, sizeof(dc_aheader_t)))==NULL) {
		exit(37); /* cannot allocate little memory, unrecoverable error */
	}

	aheader->public_key = dc_key_new();

	return aheader;
}


/**
 * @memberof dc_aheader_t
 */
void dc_aheader_unref(dc_aheader_t* aheader)
{
	if (aheader==NULL) {
		return;
	}

	free(aheader->addr);
	dc_key_unref(aheader->public_key);
	free(aheader);
}


/**
 * @memberof dc_aheader_t
 */
dc_aheader_t* dc_aheader_new_from_imffields(const char* wanted_from, const struct mailimf_fields* header)
{
	clistiter*    cur = NULL;
	dc_aheader_t* fine_header = NULL;

	if (wanted_from==NULL || header==NULL) {
		return 0;
	}

	for (cur = clist_begin(header->fld_list); cur!=NULL ; cur=clist_next(cur))
	{
		struct mailimf_field* field = (struct mailimf_field*)clist_content(cur);
		if (field && field->fld_type==MAILIMF_FIELD_OPTIONAL_FIELD)
		{
			struct mailimf_optional_field* optional_field = field->fld_data.fld_optional_field;
			if (optional_field && optional_field->fld_name && strcasecmp(optional_field->fld_name, "Autocrypt")==0)
			{
				/* header found, check if it is valid and matched the wanted address */
				dc_aheader_t* test = dc_aheader_new();
				if (!dc_aheader_set_from_string(test, optional_field->fld_value)
				 || dc_addr_cmp(test->addr, wanted_from)!=0) {
					dc_aheader_unref(test);
					test = NULL;
				}

				if (fine_header==NULL) {
					fine_header = test; /* may still be NULL */
				}
				else if (test) {
					dc_aheader_unref(fine_header);
					dc_aheader_unref(test);
					return NULL; /* more than one valid header for the same address results in an error, see Autocrypt Level 1 */
				}
			}
		}
	}

	return fine_header; /* may be NULL */
}

