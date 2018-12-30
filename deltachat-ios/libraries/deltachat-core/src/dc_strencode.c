#include <ctype.h>
#include <libetpan/libetpan.h>
#include "dc_context.h"
#include "dc_strencode.h"


/*******************************************************************************
 * URL encoding and decoding, RFC 3986
 ******************************************************************************/


static char int_2_uppercase_hex(char code)
{
	static const char hex[] = "0123456789ABCDEF";
	return hex[code & 15];
}


static char hex_2_int(char ch)
{
	return isdigit(ch) ? ch - '0' : tolower(ch) - 'a' + 10;
}


/**
 * Url-encodes a string.
 * All characters but A-Z, a-z, 0-9 and -_. are encoded by a percent sign followed by two hexadecimal digits.
 *
 * The space in encoded as `+` - this is correct for parts in the url _after_ the `?` and saves some bytes when used in QR codes.
 * (in the URL _before_ the `?` or elsewhere, the space should be encoded as `%20`)
 *
 * Belongs to RFC 3986: https://tools.ietf.org/html/rfc3986#section-2
 *
 * Example: The string `Björn Petersen` will be encoded as `"Bj%C3%B6rn+Petersen`.
 *
 * @param to_encode Null-terminated UTF-8 string to encode.
 * @return Returns a null-terminated url-encoded strings. The result must be free()'d when no longer needed.
 *     On memory allocation errors the program halts.
 *     On other errors, an empty string is returned.
 */
char* dc_urlencode(const char *to_encode)
{
	const char *pstr = to_encode;

	if (to_encode==NULL) {
		return dc_strdup("");
	}

	char *buf = malloc(strlen(to_encode) * 3 + 1), *pbuf = buf;
	if (buf==NULL) {
		exit(46);
	}

	while (*pstr)
	{
		if (isalnum(*pstr) || *pstr=='-' || *pstr=='_' || *pstr=='.' || *pstr=='~') {
			*pbuf++ = *pstr;
		}
		else if (*pstr==' ') {
			*pbuf++ = '+';
		}
		else {
			*pbuf++ = '%', *pbuf++ = int_2_uppercase_hex(*pstr >> 4), *pbuf++ = int_2_uppercase_hex(*pstr & 15);
		}

		pstr++;
	}

	*pbuf = '\0';

	return buf;
}


/**
 * Returns a url-decoded version of the given string.
 * The string may be encoded eg. by dc_urlencode().
 * Belongs to RFC 3986: https://tools.ietf.org/html/rfc3986#section-2
 *
 * @param to_decode Null-terminated string to decode.
 * @return The function returns a null-terminated UTF-8 string.
 *     The return value must be free() when no longer used.
 *     On memory allocation errors the program halts.
 *     On other errors, an empty string is returned.
 */
char* dc_urldecode(const char* to_decode)
{
	const char *pstr = to_decode;

	if (to_decode==NULL) {
		return dc_strdup("");
	}

	char *buf = malloc(strlen(to_decode) + 1), *pbuf = buf;
	if (buf==NULL) {
		exit(50);
	}

	while (*pstr)
	{
		if (*pstr=='%') {
			if (pstr[1] && pstr[2]) {
				*pbuf++ = hex_2_int(pstr[1]) << 4 | hex_2_int(pstr[2]);
				pstr += 2;
			}
		}
		else if (*pstr=='+') {
			*pbuf++ = ' ';
		}
		else {
			*pbuf++ = *pstr;
		}

		pstr++;
	}

	*pbuf = '\0';

	return buf;
}


/*******************************************************************************
 * Encode/decode header words, RFC 2047
 ******************************************************************************/


#define DEF_INCOMING_CHARSET "iso-8859-1"
#define DEF_DISPLAY_CHARSET  "utf-8"
#define MAX_IMF_LINE         666 /* see comment below */


static int to_be_quoted(const char * word, size_t size)
{
	const char* cur = word;
	size_t      i = 0;

	for (i = 0; i < size; i++)
	{
		switch (*cur)
		{
			case ',':
			case ':':
			case '!':
			case '"':
			case '#':
			case '$':
			case '@':
			case '[':
			case '\\':
			case ']':
			case '^':
			case '`':
			case '{':
			case '|':
			case '}':
			case '~':
			case '=':
			case '?':
			case '_':
				return 1;

			default:
				if (((unsigned char)*cur) >= 128) {
					return 1;
				}
				break;
		}

		cur++;
	}

	return 0;
}


static int quote_word(const char* display_charset, MMAPString* mmapstr, const char* word, size_t size)
{
	const char* cur = NULL;
	size_t      i = 0;
	char        hex[4];
	int         col = 0;

	if (mmap_string_append(mmapstr, "=?")==NULL) {
		return 0;
	}

	if (mmap_string_append(mmapstr, display_charset)==NULL) {
		return 0;
	}

	if (mmap_string_append(mmapstr, "?Q?")==NULL) {
		return 0;
	}

	col = mmapstr->len;

	cur = word;
	for(i = 0 ; i < size ; i ++)
	{
		int do_quote_char;

		#if MAX_IMF_LINE != 666
		if (col + 2 /* size of "?=" */
			+ 3 /* max size of newly added character */
			+ 1 /* minimum column of string in a
				   folded header */ >= MAX_IMF_LINE)
		{
			/* adds a concatened encoded word */
			int old_pos;

			if (mmap_string_append(mmapstr, "?=")==NULL) {
				return 0;
			}

			if (mmap_string_append(mmapstr, " ")==NULL) {
				return 0;
			}

			old_pos = mmapstr->len;

			if (mmap_string_append(mmapstr, "=?")==NULL) {
				return 0;
			}

			if (mmap_string_append(mmapstr, display_charset)==NULL) {
				return 0;
			}

			if (mmap_string_append(mmapstr, "?Q?")==NULL) {
				return 0;
			}

			col = mmapstr->len - old_pos;
		}
		#endif

		do_quote_char = 0;
		switch (*cur)
		{
			case ',':
			case ':':
			case '!':
			case '"':
			case '#':
			case '$':
			case '@':
			case '[':
			case '\\':
			case ']':
			case '^':
			case '`':
			case '{':
			case '|':
			case '}':
			case '~':
			case '=':
			case '?':
			case '_':
				do_quote_char = 1;
				break;

			default:
				if (((unsigned char) * cur) >= 128) {
					do_quote_char = 1;
				}
				break;
		}

		if (do_quote_char)
		{
			snprintf(hex, 4, "=%2.2X", (unsigned char) * cur);
			if (mmap_string_append(mmapstr, hex)==NULL) {
				return 0;
			}
			col += 3;
		}
		else
		{
			if (* cur==' ') {
				if (mmap_string_append_c(mmapstr, '_')==NULL) {
					return 0;
				}
			}
			else {
				if (mmap_string_append_c(mmapstr, * cur)==NULL) {
					return 0;
				}
			}
			col += 3;
		}

		cur++;
	}

	if (mmap_string_append(mmapstr, "?=")==NULL) {
		return 0;
	}

	return 1;
}


static void get_word(const char* begin, const char** pend, int* pto_be_quoted)
{
	const char* cur = begin;

	while ((* cur != ' ') && (* cur != '\t') && (* cur != '\0')) {
		cur ++;
	}

	#if MAX_IMF_LINE != 666
	if (cur - begin +
      1  /* minimum column of string in a
            folded header */ > MAX_IMF_LINE)
		*pto_be_quoted = 1;
	else
	#endif
		*pto_be_quoted = to_be_quoted(begin, cur - begin);

	*pend = cur;
}


/**
 * Encode non-ascii-strings as `=?UTF-8?Q?Bj=c3=b6rn_Petersen?=`.
 * Belongs to RFC 2047: https://tools.ietf.org/html/rfc2047
 *
 * We do not fold at position 72; this would result in empty words as `=?utf-8?Q??=` which are correct,
 * but cannot be displayed by some mail programs (eg. Android Stock Mail).
 * however, this is not needed, as long as _one_ word is not longer than 72 characters.
 * _if_ it is, the display may get weird.  This affects the subject only.
 * the best solution wor all this would be if libetpan encodes the line as only libetpan knowns when a header line is full.
 *
 * @param to_encode Null-terminated UTF-8-string to encode.
 * @return Returns the encoded string which must be free()'d when no longed needed.
 *     On errors, NULL is returned.
 */
char* dc_encode_header_words(const char* to_encode)
{
	char*       ret_str = NULL;
	const char* cur = to_encode;
	MMAPString* mmapstr = mmap_string_new("");

	if (to_encode==NULL || mmapstr==NULL) {
		goto cleanup;
	}

	while (* cur != '\0')
	{
		const char * begin;
		const char * end;
		int do_quote;
		int quote_words;

		begin = cur;
		end = begin;
		quote_words = 0;
		do_quote = 1;

		while (* cur != '\0')
		{
			get_word(cur, &cur, &do_quote);
			if (do_quote) {
				quote_words = 1;
				end = cur;
			}
			else {
				break;
			}

			if (* cur != '\0') {
				cur ++;
			}
		}

		if (quote_words)
		{
			if ( !quote_word(DEF_DISPLAY_CHARSET, mmapstr, begin, end - begin)) {
				goto cleanup;
			}

			if ((* end==' ') || (* end=='\t')) {
				if (mmap_string_append_c(mmapstr, * end)==0) {
					goto cleanup;
				}
				end ++;
			}

			if (* end != '\0') {
				if (mmap_string_append_len(mmapstr, end, cur - end)==NULL) {
					goto cleanup;
				}
			}
		}
		else
		{
			if (mmap_string_append_len(mmapstr, begin, cur - begin)==NULL) {
				goto cleanup;
			}
		}

		if ((* cur==' ') || (* cur=='\t')) {
			if (mmap_string_append_c(mmapstr, * cur)==0) {
				goto cleanup;
			}
			cur ++;
		}
	}

	ret_str = strdup(mmapstr->str);

cleanup:
	if (mmapstr) {
		mmap_string_free(mmapstr);
	}
	return ret_str;
}


/**
 * Decode non-ascii-strings as `=?UTF-8?Q?Bj=c3=b6rn_Petersen?=`.
 * Belongs to RFC 2047: https://tools.ietf.org/html/rfc2047
 *
 * @param in String to decode.
 * @return Returns the null-terminated decoded string as UTF-8. Must be free()'d when no longed needed.
 *     On errors, NULL is returned.
 */
char* dc_decode_header_words(const char* in)
{
	/* decode strings as. `=?UTF-8?Q?Bj=c3=b6rn_Petersen?=`)
	if `in` is NULL, `out` is NULL as well; also returns NULL on errors */

	if (in==NULL) {
		return NULL; /* no string given */
	}

	char* out = NULL;
	size_t cur_token = 0;
	int r = mailmime_encoded_phrase_parse(DEF_INCOMING_CHARSET, in, strlen(in), &cur_token, DEF_DISPLAY_CHARSET, &out);
	if (r != MAILIMF_NO_ERROR || out==NULL) {
		out = dc_strdup(in); /* error, make a copy of the original string (as we free it later) */
	}

	return out; /* must be free()'d by the caller */
}


/*******************************************************************************
 * Encode/decode modified UTF-7 as needed for IMAP, see RFC 2192
 ******************************************************************************/


// UTF7 modified base64 alphabet
static const char base64chars[] =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+,";


/**
 * Convert an UTF-8 string to a modified UTF-7 string
 * that is needed eg. for IMAP mailbox names.
 *
 * Example: `Björn Petersen` gets encoded to `Bj&APY-rn_Petersen`
 *
 * @param to_encode Null-terminated UTF-8 string to encode
 * @param change_spaces If set, spaces are encoded using the underscore character.
 * @return Null-terminated encoded string. Must be free()'d after usage.
 *     Halts the program on memory allocation errors,
 *     for all other errors, an empty string is returned.
 *     NULL is never returned.
 */
char* dc_encode_modified_utf7(const char* to_encode, int change_spaces)
{
	#define UTF16MASK       0x03FFUL
	#define UTF16SHIFT      10
	#define UTF16BASE       0x10000UL
	#define UTF16HIGHSTART  0xD800UL
	#define UTF16HIGHEND    0xDBFFUL
	#define UTF16LOSTART    0xDC00UL
	#define UTF16LOEND      0xDFFFUL
	#define UNDEFINED       64

	unsigned int  utf8pos = 0;
	unsigned int  utf8total = 0;
	unsigned int  c = 0;
	unsigned int  utf7mode = 0;
	unsigned int  bitstogo = 0;
	unsigned int  utf16flag = 0;
	unsigned long ucs4 = 0;
	unsigned long bitbuf = 0;
	char*         dst = NULL;
	char*         res = NULL;

	if (!to_encode) {
		return dc_strdup("");
	}

	res = (char*)malloc(2*strlen(to_encode)+1);
	dst = res;
	if(!dst) {
		exit(51);
	}

	utf7mode = 0;
	utf8total = 0;
	bitstogo = 0;
	utf8pos = 0;
	while ((c = (unsigned char)*to_encode) != '\0')
	{
		++to_encode;
		// normal character?
		if (c >= ' ' && c <= '~' && (c != '_' || !change_spaces)) {
			// switch out of UTF-7 mode
			if (utf7mode) {
				if (bitstogo) {
					*dst++ = base64chars[(bitbuf << (6 - bitstogo)) & 0x3F];
				}
				*dst++ = '-';
				utf7mode = 0;
				utf8pos  = 0;
				bitstogo = 0;
				utf8total= 0;
			}
			if (change_spaces && c==' ') {
				*dst++ = '_';
			}
			else {
				*dst++ = c;
			}

			// encode '&' as '&-'
			if (c=='&') {
				*dst++ = '-';
			}
			continue;
		}

		// switch to UTF-7 mode
		if (!utf7mode) {
			*dst++ = '&';
			utf7mode = 1;
		}
		// encode ascii characters as themselves
		if (c < 0x80) {
			ucs4 = c;
		}
		else if (utf8total) {
			// save UTF8 bits into UCS4
			ucs4 = (ucs4 << 6) | (c & 0x3FUL);
			if (++utf8pos < utf8total) {
				continue;
			}
		}
		else {
			utf8pos = 1;
			if (c < 0xE0) {
				utf8total = 2;
				ucs4 = c & 0x1F;
			}
			else if (c < 0xF0) {
				utf8total = 3;
				ucs4 = c & 0x0F;
			}
			else {
				// NOTE: cannot convert UTF8 sequences longer than 4
				utf8total = 4;
				ucs4 = c & 0x03;
			}
			continue;
		}

		// loop to split ucs4 into two utf16 chars if necessary
		utf8total = 0;
		do {
		  if (ucs4 >= UTF16BASE) {
			ucs4 -= UTF16BASE;
			bitbuf = (bitbuf << 16) | ((ucs4 >> UTF16SHIFT)
									   + UTF16HIGHSTART);
			ucs4 = (ucs4 & UTF16MASK) + UTF16LOSTART;
			utf16flag = 1;
		  } else {
			bitbuf = (bitbuf << 16) | ucs4;
			utf16flag = 0;
		  }
		  bitstogo += 16;
		  /* spew out base64 */
		  while (bitstogo >= 6) {
			bitstogo -= 6;
			*dst++ = base64chars[(bitstogo ? (bitbuf >> bitstogo)
								  : bitbuf)
								 & 0x3F];
		  }
		} while (utf16flag);
	}

	// if in UTF-7 mode, finish in ASCII
	if (utf7mode) {
		if (bitstogo) {
		  *dst++ = base64chars[(bitbuf << (6 - bitstogo)) & 0x3F];
		}
		*dst++ = '-';
	}

	*dst = '\0';
	return res;
}


/**
 * Convert an modified UTF-7 encoded string to an UTF-8 string.
 * Modified UTF-7 strings are used eg. in IMAP mailbox names.
 *
 * @param to_decode Null-terminated, modified UTF-7 string to decode.
 * @param change_spaces If set, the underscore character `_` is converted to
 *     a space.
 * @return Null-terminated UTF-8 string. Must be free()'d after usage.
 *     Halts the program on memory allocation errors,
 *     for all other errors, an empty string is returned.
 *     NULL is never returned.
 */
char* dc_decode_modified_utf7(const char *to_decode, int change_spaces)
{
	unsigned      c = 0;
	unsigned      i = 0;
	unsigned      bitcount = 0;
	unsigned long ucs4 = 0;
	unsigned long utf16 = 0;
	unsigned long bitbuf = 0;
	unsigned char base64[256];
	const char*   src = NULL;
	char*         dst = NULL;
	char*         res = NULL;

	if (to_decode==NULL) {
		return dc_strdup("");
	}

	res  = (char*)malloc(4*strlen(to_decode)+1);
	dst = res;
	src = to_decode;
	if(!dst) {
		exit(52);
	}

	memset(base64, UNDEFINED, sizeof (base64));
	for (i = 0; i < sizeof (base64chars); ++i) {
		base64[(unsigned)base64chars[i]] = i;
	}

	while (*src != '\0')
	{
		c = *src++;
		// deal with literal characters and &-
		if (c != '&' || *src=='-') {
			// encode literally
			if (change_spaces && c=='_') {
				*dst++ = ' ';
			}
			else {
				*dst++ = c;
			}
			// skip over the '-' if this is an &- sequence
			if (c=='&') ++src;
		}
		else {
			// convert modified UTF-7 -> UTF-16 -> UCS-4 -> UTF-8 -> HEX
			bitbuf = 0;
			bitcount = 0;
			ucs4 = 0;
			while ((c = base64[(unsigned char) *src]) != UNDEFINED) {
				++src;
				bitbuf = (bitbuf << 6) | c;
				bitcount += 6;

				// enough bits for a UTF-16 character?
				if (bitcount >= 16)
				{
					bitcount -= 16;
					utf16 = (bitcount ? bitbuf >> bitcount : bitbuf) & 0xffff;

					// convert UTF16 to UCS4
					if (utf16 >= UTF16HIGHSTART && utf16 <= UTF16HIGHEND) {
						ucs4 = (utf16 - UTF16HIGHSTART) << UTF16SHIFT;
						continue;
					}
					else if (utf16 >= UTF16LOSTART && utf16 <= UTF16LOEND) {
						ucs4 += utf16 - UTF16LOSTART + UTF16BASE;
					}
					else {
						ucs4 = utf16;
					}

					// convert UTF-16 range of UCS4 to UTF-8
					if (ucs4 <= 0x7fUL) {
						dst[0] = ucs4;
						dst += 1;
					}
					else if (ucs4 <= 0x7ffUL) {
						dst[0] = 0xc0 | (ucs4 >> 6);
						dst[1] = 0x80 | (ucs4 & 0x3f);
						dst += 2;
					}
					else if (ucs4 <= 0xffffUL) {
						dst[0] = 0xe0 | (ucs4 >> 12);
						dst[1] = 0x80 | ((ucs4 >> 6) & 0x3f);
						dst[2] = 0x80 | (ucs4 & 0x3f);
						dst += 3;
					}
					else {
						dst[0] = 0xf0 | (ucs4 >> 18);
						dst[1] = 0x80 | ((ucs4 >> 12) & 0x3f);
						dst[2] = 0x80 | ((ucs4 >> 6) & 0x3f);
						dst[3] = 0x80 | (ucs4 & 0x3f);
						dst += 4;
					}
				}
			}

			// skip over trailing '-' in modified UTF-7 encoding
			if (*src=='-') {
				++src;
			}
		}
	}

	*dst = '\0';
	return res;
}


/*******************************************************************************
 * Encode/decode extended header, RFC 2231, RFC 5987
 ******************************************************************************/


/**
 * Check if extended header format is needed for a given string.
 *
 * @param to_check Null-terminated UTF-8 string to check.
 * @return 0=extended header encoding is not needed,
 *     1=extended header encoding is needed,
 *     use dc_encode_ext_header() for this purpose.
 */
int dc_needs_ext_header(const char* to_check)
{
	if (to_check) {
		while (*to_check)
		{
			if (!isalnum(*to_check) && *to_check!='-' && *to_check!='_' && *to_check!='.' && *to_check!='~') {
				return 1;
			}
			to_check++;
		}
	}

	return 0;
}


/**
 * Encode an UTF-8 string to the extended header format.
 *
 * Example: `Björn Petersen` gets encoded to `utf-8''Bj%C3%B6rn%20Petersen`
 *
 * @param to_encode Null-terminated UTF-8 string to encode.
 * @return Null-terminated encoded string. Must be free()'d after usage.
 *     Halts the program on memory allocation errors,
 *     for all other errors, an empty string is returned or just the given string is returned.
 *     NULL is never returned.
 */
char* dc_encode_ext_header(const char* to_encode)
{
	#define PREFIX "utf-8''"
	const char *pstr = to_encode;

	if (to_encode==NULL) {
		return dc_strdup(PREFIX);
	}

	char *buf = malloc(strlen(PREFIX) + strlen(to_encode) * 3 + 1);
	if (buf==NULL) {
		exit(46);
	}

	char* pbuf = buf;
	strcpy(pbuf, PREFIX);
	pbuf += strlen(pbuf);

	while (*pstr)
	{
		if (isalnum(*pstr) || *pstr=='-' || *pstr=='_' || *pstr=='.' || *pstr=='~') {
			*pbuf++ = *pstr;
		}
		else {
			*pbuf++ = '%', *pbuf++ = int_2_uppercase_hex(*pstr >> 4), *pbuf++ = int_2_uppercase_hex(*pstr & 15);
		}

		pstr++;
	}

	*pbuf = '\0';

	return buf;
}


/**
 * Decode an extended-header-format strings to UTF-8.
 *
 * @param to_decode Null-terminated string to decode
 * @return Null-terminated decoded UTF-8 string. Must be free()'d after usage.
 *     Halts the program on memory allocation errors,
 *     for all other errors, an empty string is returned or just the given string is returned.
 *     NULL is never returned.
 */
char* dc_decode_ext_header(const char* to_decode)
{
	char*       decoded = NULL;
	char*       charset = NULL;
	const char* p2 = NULL;

	if (to_decode==NULL) {
		goto cleanup;
	}

	// get char set
	if ((p2=strchr(to_decode, '\''))==NULL
	 || (p2==to_decode) /*no empty charset allowed*/) {
		goto cleanup;
	}

	charset = dc_null_terminate(to_decode, p2-to_decode);
	p2++;

	// skip language
	if ((p2=strchr(p2, '\''))==NULL) {
		goto cleanup;
	}

	p2++;

	// decode text
	decoded = dc_urldecode(p2);

	if (charset!=NULL && strcmp(charset, "utf-8")!=0 && strcmp(charset, "UTF-8")!=0) {
		char* converted = NULL;
		int r = charconv("utf-8", charset, decoded, strlen(decoded), &converted);
		if (r==MAIL_CHARCONV_NO_ERROR && converted != NULL) {
			free(decoded);
			decoded = converted;
		}
		else {
			free(converted);
		}
	}

cleanup:
	free(charset);
	return decoded? decoded : dc_strdup(to_decode);
}
