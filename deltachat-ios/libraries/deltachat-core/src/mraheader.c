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
#include "mrmailbox_internal.h"
#include "mraheader.h"
#include "mrapeerstate.h"
#include "mrmimeparser.h"


/**
 * @private @memberof mraheader_t
 */
void mraheader_empty(mraheader_t* ths)
{
	if( ths == NULL ) {
		return;
	}

	ths->m_prefer_encrypt = 0;

	free(ths->m_addr);
	ths->m_addr = NULL;

	if( ths->m_public_key->m_binary ) {
		mrkey_unref(ths->m_public_key);
		ths->m_public_key = mrkey_new();
	}
}


/*******************************************************************************
 * Render Autocrypt Header
 ******************************************************************************/


/**
 * @memberof mraheader_t
 */
char* mraheader_render(const mraheader_t* ths)
{
	int            success = 0;
	char*          keybase64_wrapped = NULL;
	mrstrbuilder_t ret;
	mrstrbuilder_init(&ret);

	if( ths==NULL || ths->m_addr==NULL || ths->m_public_key->m_binary==NULL || ths->m_public_key->m_type!=MR_PUBLIC ) {
		goto cleanup;
	}

	mrstrbuilder_cat(&ret, "addr=");
	mrstrbuilder_cat(&ret, ths->m_addr);
	mrstrbuilder_cat(&ret, "; ");

	if( ths->m_prefer_encrypt==MRA_PE_MUTUAL ) {
		mrstrbuilder_cat(&ret, "prefer-encrypt=mutual; ");
	}

	mrstrbuilder_cat(&ret, "keydata= "); /* the trailing space together with mr_insert_breaks() allows a proper transport */

	/* adds a whitespace every 78 characters, this allows libEtPan to wrap the lines according to RFC 5322
	(which may insert a linebreak before every whitespace) */
	if( (keybase64_wrapped = mrkey_render_base64(ths->m_public_key, 78, " ", 0/*no checksum*/)) == NULL ) {
		goto cleanup;
	}

	mrstrbuilder_cat(&ret, keybase64_wrapped);

	success = 1;

cleanup:
	if( !success ) { free(ret.m_buf); ret.m_buf = NULL; }
	free(keybase64_wrapped);
	return ret.m_buf; /* NULL on errors, this may happen for various reasons */
}


/*******************************************************************************
 * Parse Autocrypt Header
 ******************************************************************************/


static int add_attribute(mraheader_t* ths, const char* name, const char* value /*may be NULL*/)
{
	/* returns 0 if the attribute will result in an invalid header, 1 if the attribute is okay */
	if( strcasecmp(name, "addr")==0 )
	{
		if( value == NULL
		 || strlen(value) < 3 || strchr(value, '@')==NULL || strchr(value, '.')==NULL /* rough check if email-address is valid */
		 || ths->m_addr /* email already given */ ) {
			return 0;
		}
		ths->m_addr = mr_normalize_addr(value);
		return 1;
	}
	#if 0 /* autoctypt 11/2017 no longer uses the type attribute and it will make the autocrypt header invalid */
	else if( strcasecmp(name, "type")==0 )
	{
		if( value == NULL ) {
			return 0; /* attribute with no value results in an invalid header */
		}
		if( strcasecmp(value, "1")==0 || strcasecmp(value, "0" /*deprecated*/)==0 || strcasecmp(value, "p" /*deprecated*/)==0 ) {
			return 1; /* PGP-type */
		}
		return 0; /* unknown types result in an invalid header */
	}
	#endif
	else if( strcasecmp(name, "prefer-encrypt")==0 )
	{
		if( value && strcasecmp(value, "mutual")==0 ) {
			ths->m_prefer_encrypt = MRA_PE_MUTUAL;
			return 1;
		}
		return 1; /* An Autocrypt level 0 client that sees the attribute with any other value (or that does not see the attribute at all) should interpret the value as nopreference.*/
	}
	else if( strcasecmp(name, "keydata")==0 )
	{
		if( value == NULL
		 || ths->m_public_key->m_binary || ths->m_public_key->m_bytes ) {
			return 0; /* there is already a k*/
		}
		return mrkey_set_from_base64(ths->m_public_key, value, MR_PUBLIC);
	}
	else if( name[0]=='_' )
	{
		/* Autocrypt-Level0: unknown attributes starting with an underscore can be safely ignored */
		return 1;
	}

	/* Autocrypt-Level0: unknown attribute, treat the header as invalid */
	return 0;
}


/**
 * @memberof mraheader_t
 */
int mraheader_set_from_string(mraheader_t* ths, const char* header_str__)
{
	/* according to RFC 5322 (Internet Message Format), the given string may contain `\r\n` before any whitespace.
	we can ignore this issue as
	(a) no key or value is expected to contain spaces,
	(b) for the key, non-base64-characters are ignored and
	(c) for parsing, we ignore `\r\n` as well as tabs for spaces */
	#define AHEADER_WS "\t\r\n "
	char    *header_str = NULL;
	char    *p, *beg_attr_name, *after_attr_name, *beg_attr_value;
	int     success = 0;

	mraheader_empty(ths);
	ths->m_prefer_encrypt = MRA_PE_NOPREFERENCE; /* value to use if the prefer-encrypted header is missing */

	if( ths == NULL || header_str__ == NULL ) {
		goto cleanup;
	}

	header_str = safe_strdup(header_str__);
	p = header_str;
	while( *p )
	{
		p += strspn(p, AHEADER_WS "=;"); /* forward to first attribute name beginning */
		beg_attr_name = p;
		beg_attr_value = NULL;
		p += strcspn(p, AHEADER_WS "=;"); /* get end of attribute name (an attribute may have no value) */
		if( p != beg_attr_name )
		{
			/* attribute found */
			after_attr_name = p;
			p += strspn(p, AHEADER_WS); /* skip whitespace between attribute name and possible `=` */
			if( *p == '=' )
			{
				p += strspn(p, AHEADER_WS "="); /* skip spaces and equal signs */

				/* read unquoted attribute value until the first semicolon */
				beg_attr_value = p;
				p += strcspn(p, ";");
				if( *p != '\0' ) {
					*p = '\0';
					p++;
				}
				mr_trim(beg_attr_value);
			}
			else
			{
				p += strspn(p, AHEADER_WS ";");
			}
			*after_attr_name = '\0';
			if( !add_attribute(ths, beg_attr_name, beg_attr_value) ) {
				goto cleanup; /* a bad attribute makes the whole header invalid */
			}
		}
	}

	/* all needed data found? */
	if( ths->m_addr && ths->m_public_key->m_binary ) {
		success = 1;
	}

cleanup:
	free(header_str);
	if( !success ) { mraheader_empty(ths); }
	return success;
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


/**
 * @memberof mraheader_t
 */
mraheader_t* mraheader_new()
{
	mraheader_t* ths = NULL;

	if( (ths=calloc(1, sizeof(mraheader_t)))==NULL ) {
		exit(37); /* cannot allocate little memory, unrecoverable error */
	}

	ths->m_public_key = mrkey_new();

	return ths;
}


/**
 * @memberof mraheader_t
 */
void mraheader_unref(mraheader_t* ths)
{
	if( ths==NULL ) {
		return;
	}

	free(ths->m_addr);
	mrkey_unref(ths->m_public_key);
	free(ths);
}


/**
 * @memberof mraheader_t
 */
mraheader_t* mraheader_new_from_imffields(const char* wanted_from, const struct mailimf_fields* header)
{
	clistiter*   cur;
	mraheader_t* fine_header = NULL;

	if( wanted_from == NULL || header == NULL ) {
		return 0;
	}

	for( cur = clist_begin(header->fld_list); cur!=NULL ; cur=clist_next(cur) )
	{
		struct mailimf_field* field = (struct mailimf_field*)clist_content(cur);
		if( field && field->fld_type == MAILIMF_FIELD_OPTIONAL_FIELD )
		{
			struct mailimf_optional_field* optional_field = field->fld_data.fld_optional_field;
			if( optional_field && optional_field->fld_name && strcasecmp(optional_field->fld_name, "Autocrypt")==0 )
			{
				/* header found, check if it is valid and matched the wanted address */
				mraheader_t* test = mraheader_new();
				if( !mraheader_set_from_string(test, optional_field->fld_value)
				 || strcasecmp(test->m_addr, wanted_from)!=0 ) {
					mraheader_unref(test);
					test = NULL;
				}

				if( fine_header == NULL ) {
					fine_header = test; /* may still be NULL */
				}
				else if( test ) {
					mraheader_unref(fine_header);
					mraheader_unref(test);
					return NULL; /* more than one valid header for the same address results in an error, see Autocrypt Level 1 */
				}
			}
		}
	}

	return fine_header; /* may be NULL */
}

