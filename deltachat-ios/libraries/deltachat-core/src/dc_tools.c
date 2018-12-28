#include <stdarg.h>
#include <ctype.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h> /* for getpid() */
#include <unistd.h>    /* for getpid() */
#include <openssl/rand.h>
#include <libetpan/libetpan.h>
#include <libetpan/mailimap_types.h>
#include "dc_context.h"


/*******************************************************************************
 * Math tools
 ******************************************************************************/


int dc_exactly_one_bit_set(int v)
{
	return (v && !(v & (v - 1))); /* via http://www.graphics.stanford.edu/~seander/bithacks.html#DetermineIfPowerOf2 */
}


/*******************************************************************************
 * String tools
 ******************************************************************************/


char* dc_strdup(const char* s) /* strdup(NULL) is undefined, save_strdup(NULL) returns an empty string in this case */
{
	char* ret = NULL;
	if (s) {
		if ((ret=strdup(s))==NULL) {
			exit(16); /* cannot allocate (little) memory, unrecoverable error */
		}
	}
	else {
		if ((ret=(char*)calloc(1, 1))==NULL) {
			exit(17); /* cannot allocate little memory, unrecoverable error */
		}
	}
	return ret;
}


char* dc_strdup_keep_null(const char* s) /* strdup(NULL) is undefined, safe_strdup_keep_null(NULL) returns NULL in this case */
{
	return s? dc_strdup(s) : NULL;
}


int dc_atoi_null_is_0(const char* s)
{
	return s? atoi(s) : 0;
}


void dc_ltrim(char* buf)
{
	size_t               len = 0;
	const unsigned char* cur = NULL;

	if (buf && *buf) {
		len = strlen(buf);
		cur = (const unsigned char*)buf;

		while (*cur && isspace(*cur)) {
			cur++; len--;
		}

		if ((const unsigned char*)buf!=cur) {
			memmove(buf, cur, len + 1);
		}
	}
}


void dc_rtrim(char* buf)
{
	size_t         len = 0;
	unsigned char* cur = NULL;

	if (buf && *buf) {
		len = strlen(buf);
		cur = (unsigned char*)buf + len - 1;

		while (cur!=(unsigned char*)buf && isspace(*cur)) {
			--cur, --len;
		}

		cur[isspace(*cur) ? 0 : 1] = '\0';
	}
}


void dc_trim(char* buf)
{
	dc_ltrim(buf);
	dc_rtrim(buf);
}


void dc_strlower_in_place(char* in)
{
	char* p = in;
	for ( ; *p; p++) {
		*p = tolower(*p);
	}
}


char* dc_strlower(const char* in) /* the result must be free()'d */
{
	char* out = dc_strdup(in);

	char* p = out;
	for ( ; *p; p++) {
		*p = tolower(*p);
	}

	return out;
}


/*
 * haystack may be realloc()'d, returns the number of replacements.
 */
int dc_str_replace(char** haystack, const char* needle, const char* replacement)
{
	int replacements = 0;
	int start_search_pos = 0;
	int needle_len = 0;
	int replacement_len = 0;

	if (haystack==NULL || *haystack==NULL || needle==NULL || needle[0]==0) {
		return 0;
	}

	needle_len = strlen(needle);
	replacement_len = replacement? strlen(replacement) : 0;
	while (1)
	{
		char* p2 = strstr((*haystack)+start_search_pos, needle);
		if (p2==NULL) { break; }
		start_search_pos = (p2-(*haystack))+replacement_len; /* avoid recursion and skip the replaced part */

		*p2 = 0;
		p2 += needle_len;
		char* new_string = dc_mprintf("%s%s%s", *haystack, replacement? replacement : "", p2);
		free(*haystack);
		*haystack = new_string;
		replacements++;
	}

	return replacements;
}


int dc_str_contains(const char* haystack, const char* needle)
{
	/* case-insensitive search of needle in haystack, return 1 if found, 0 if not */
	if (haystack==NULL || needle==NULL) {
		return 0;
	}

	if (strstr(haystack, needle)!=NULL) {
		return 1;
	}

	char* haystack_lower = dc_strlower(haystack);
	char* needle_lower = dc_strlower(needle);

		int ret = strstr(haystack_lower, needle_lower)? 1 : 0;

	free(haystack_lower);
	free(needle_lower);

	return ret;
}


/**
 * Creates a null-terminated string from a buffer.
 * Similar to strndup() but allows bad parameters and just halts the program
 * on memory allocation errors.
 *
 * @param in The start of the string.
 * @param bytes The number of bytes to take from the string.
 * @return The null-terminates string, must be free()'d by the caller.
 *     On memory-allocation errors, the program halts.
 *     On other errors, an empty string is returned.
 */
char* dc_null_terminate(const char* in, int bytes) /* the result must be free()'d */
{
	char* out = malloc(bytes+1);
	if (out==NULL) {
		exit(45);
	}

	if (in && bytes > 0) {
		strncpy(out, in, bytes);
	}
	out[bytes] = 0;
	return out;
}


/**
 * Converts a byte-buffer to a string with hexadecimal,
 * upper-case digits.
 *
 * This function is used eg. to create readable fingerprints, however, it may
 * be used for other purposes as well.
 *
 * @param buf The buffer to convert to an hexadecimal string. If this is NULL,
 *     the functions returns NULL.
 * @param bytes The number of bytes in buf. buf may or may not be null-terminated
 *     If this is <=0, the function returns NULL.
 * @return Returns a null-terminated string, must be free()'d when no longer
 *     needed. For errors, NULL is returned.
 */
char* dc_binary_to_uc_hex(const uint8_t* buf, size_t bytes)
{
	char* hex = NULL;
	int   i = 0;

	if (buf==NULL || bytes<=0) {
		goto cleanup;
	}

	if ((hex=calloc(sizeof(char), bytes*2+1))==NULL) {
		goto cleanup;
	}

	for (i = 0; i < bytes; i++) {
		snprintf(&hex[i*2], 3, "%02X", (int)buf[i]);
	}

cleanup:
	return hex;
}


char* dc_mprintf(const char* format, ...)
{
	char  testbuf[1];
	char* buf = NULL;
	int   char_cnt_without_zero = 0;

	va_list argp;
	va_list argp_copy;
	va_start(argp, format);
	va_copy(argp_copy, argp);

	char_cnt_without_zero = vsnprintf(testbuf, 0, format, argp);
	va_end(argp);
	if (char_cnt_without_zero < 0) {
		va_end(argp_copy);
		return dc_strdup("ErrFmt");
	}

	buf = malloc(char_cnt_without_zero+2 /* +1 would be enough, however, protect against off-by-one-errors */);
	if (buf==NULL) {
		va_end(argp_copy);
		return dc_strdup("ErrMem");
	}

	vsnprintf(buf, char_cnt_without_zero+1, format, argp_copy);
	va_end(argp_copy);
	return buf;

	#if 0 /* old implementation based upon sqlite3 */
	char *sqlite_str, *c_string;

	va_list argp;
	va_start(argp, format); /* expects the last non-variable argument as the second parameter */
		sqlite_str = sqlite3_vmprintf(format, argp);
	va_end(argp);

	if (sqlite_str==NULL) {
		return dc_strdup("ErrFmt"); /* error - the result must be free()'d */
	}

	/* as sqlite-strings must be freed using sqlite3_free() instead of a simple free(), convert it to a normal c-string */
	c_string = dc_strdup(sqlite_str); /* exists on errors */
	sqlite3_free(sqlite_str);
	return c_string; /* success - the result must be free()'d */
	#endif /* /old implementation based upon sqlite3 */
}


/**
 * Remove all `\r` characters from the given buffer.
 * This function will not convert anything else in the future, so it can be used
 * safely for marking thinks to remove by `\r` and call this function afterwards.
 *
 * @param buf The buffer to convert.
 * @return None.
 */
void dc_remove_cr_chars(char* buf)
{
	const char* p1 = buf; /* search for first `\r` */
	while (*p1) {
		if (*p1=='\r') {
			break;
		}
		p1++;
	}

	char* p2 = (char*)p1; /* p1 is `\r` or null-byte; start removing `\r` */
	while (*p1) {
		if (*p1!='\r') {
			*p2 = *p1;
			p2++;
		}
		p1++;
	}

	/* add trailing null-byte */
	*p2 = 0;
}


/**
 * Unify the lineends in the given null-terminated buffer to a simple `\n` (LF, ^J).
 * Carriage return characters (`\r`, CR, ^M) are removed.
 *
 * This function does _not_ convert only-CR linefeeds; AFAIK, they only came from
 * Mac OS 9 and before and should not be in use  for nearly 20 year, so maybe this
 * is no issue.  However, this could be easily added to the function as needed
 * by converting all `\r` to `\n` if there is no single `\n` in the original buffer.
 *
 * @param buf The buffer to convert.
 * @return None.
 */
void dc_unify_lineends(char* buf)
{
	// this function may be extended to do more linefeed unification, do not mess up
	// with dc_remove_cr_chars() which does only exactly removing CR.
	dc_remove_cr_chars(buf);
}


void dc_replace_bad_utf8_chars(char* buf)
{
	if (buf==NULL) {
		return;
	}

	unsigned char* p1 = (unsigned char*)buf; /* force unsigned - otherwise the `> ' '` comparison will fail */
	int            p1len = strlen(buf);
	int            c = 0;
	int            i = 0;
	int            ix = 0;
	int            n = 0;
	int            j = 0;

	for (i=0, ix=p1len; i < ix; i++)
	{
		c = p1[i];
		     if (c > 0 && c <= 0x7f)                            { n=0; }        /* 0bbbbbbb */
		else if ((c & 0xE0) == 0xC0)                            { n=1; }        /* 110bbbbb */
		else if (c==0xed && i<(ix-1) && (p1[i+1] & 0xa0)==0xa0) { goto error; } /* U+d800 to U+dfff */
		else if ((c & 0xF0) == 0xE0)                            { n=2; }        /* 1110bbbb */
		else if ((c & 0xF8) == 0xF0)                            { n=3; }        /* 11110bbb */
		//else if ((c & 0xFC) == 0xF8)                          { n=4; }        /* 111110bb - not valid in https://tools.ietf.org/html/rfc3629 */
		//else if ((c & 0xFE) == 0xFC)                          { n=5; }        /* 1111110b - not valid in https://tools.ietf.org/html/rfc3629 */
		else                                                    { goto error; }

		for (j = 0; j < n && i < ix; j++) { /* n bytes matching 10bbbbbb follow ? */
			if ((++i == ix) || (( p1[i] & 0xC0) != 0x80)) {
				goto error;
			}
		}
	}

    /* everything is fine */
    return;

error:
	/* there are errors in the string -> replace potential errors by the character `_`
	(to avoid problems in filenames, we do not use eg. `?`) */
	while (*p1) {
		if (*p1 > 0x7f) {
			*p1 = '_';
		}
		p1++;
	}
}


#if 0 /* not needed at the moment */
static size_t dc_utf8_strlen(const char* s)
{
	size_t i = 0;
	size_t j = 0;
	while (s[i]) {
		if ((s[i]&0xC0) != 0x80)
			j++;
		i++;
	}
	return j;
}
#endif


static size_t dc_utf8_strnlen(const char* s, size_t n)
{
	size_t i = 0;
	size_t j = 0;
	while (i < n) {
		if ((s[i]&0xC0) != 0x80)
			j++;
		i++;
	}
	return j;
}


void dc_truncate_n_unwrap_str(char* buf, int approx_characters, int do_unwrap)
{
	/* Function unwraps the given string and removes unnecessary whitespace.
	Function stops processing after approx_characters are processed.
	(as we're using UTF-8, for simplicity, we cut the string only at whitespaces). */
	const char* ellipse_utf8 = do_unwrap? " ..." : " " DC_EDITORIAL_ELLIPSE; /* a single line is truncated `...` instead of `[...]` (the former is typically also used by the UI to fit strings in a rectangle) */
	int lastIsCharacter = 0;
	unsigned char* p1 = (unsigned char*)buf; /* force unsigned - otherwise the `> ' '` comparison will fail */
	while (*p1) {
		if (*p1 > ' ') {
			lastIsCharacter = 1;
		}
		else {
			if (lastIsCharacter) {
				size_t used_bytes = (size_t)((uintptr_t)p1 - (uintptr_t)buf);
				if (dc_utf8_strnlen(buf, used_bytes) >= approx_characters) {
					size_t      buf_bytes = strlen(buf);
					if (buf_bytes-used_bytes >= strlen(ellipse_utf8) /* check if we have room for the ellipse */) {
						strcpy((char*)p1, ellipse_utf8);
					}
					break;
				}
				lastIsCharacter = 0;
				if (do_unwrap) {
					*p1 = ' ';
				}
			}
			else {
				if (do_unwrap) {
					*p1 = '\r'; /* removed below */
				}
			}
		}

		p1++;
	}

	if (do_unwrap) {
		dc_remove_cr_chars(buf);
	}
}


void dc_truncate_str(char* buf, int approx_chars)
{
	if (approx_chars > 0 && strlen(buf) > approx_chars+strlen(DC_EDITORIAL_ELLIPSE))
	{
		char* p = &buf[approx_chars]; /* null-terminate string at the desired length */
		*p = 0;

		if (strchr(buf, ' ')!=NULL) {
			while (p[-1]!=' ' && p[-1]!='\n') { /* rewind to the previous space, avoid half utf-8 characters */
				p--;
				*p = 0;
			}
		}

		strcat(p, DC_EDITORIAL_ELLIPSE);
	}
}


carray* dc_split_into_lines(const char* buf_terminated)
{
	carray*      lines = carray_new(1024);
	size_t       line_chars = 0;
	const char*  p1 = buf_terminated;
	const char*  line_start = p1;
	unsigned int l_indx = 0;

	while (*p1) {
		if (*p1=='\n') {
			carray_add(lines, (void*)strndup(line_start, line_chars), &l_indx);
			p1++;
			line_start = p1;
			line_chars = 0;
		}
		else {
			p1++;
			line_chars++;
		}
	}
	carray_add(lines, (void*)strndup(line_start, line_chars), &l_indx);

	return lines; /* should be freed using dc_free_splitted_lines() */
}


void dc_free_splitted_lines(carray* lines)
{
	if (lines) {
		int i, cnt = carray_count(lines);
		for (i = 0; i < cnt; i++) {
			free(carray_get(lines, i));
		}
		carray_free(lines);
	}
}


char* dc_insert_breaks(const char* in, int break_every, const char* break_chars)
{
	/* insert a space every n characters, the return must be free()'d.
	this is useful to allow lines being wrapped according to RFC 5322 (adds linebreaks before spaces) */

	if (in==NULL || break_every<=0 || break_chars==NULL) {
		return dc_strdup(in);
	}

	int out_len = strlen(in);
	int chars_added = 0;
	int break_chars_len = strlen(break_chars);

	out_len += (out_len/break_every+1)*break_chars_len + 1/*nullbyte*/;

	char* out = malloc(out_len);
	if (out==NULL) { return NULL; }

	const char* i = in;
	char* o = out;
	while (*i) {
		*o++ = *i++;
		chars_added++;
		if (chars_added==break_every && *i) {
			strcpy(o, break_chars);
			o+=break_chars_len;
			chars_added = 0;
		}
	}
	*o = 0;
	return out;
}


// Join clist element to a string.
char* dc_str_from_clist(const clist* list, const char* delimiter)
{
	dc_strbuilder_t str;
	dc_strbuilder_init(&str, 256);

	if (list) {
		for (clistiter* cur = clist_begin(list); cur!=NULL ; cur=clist_next(cur)) {
			const char* rfc724_mid = clist_content(cur);
			if (rfc724_mid) {
				if (str.buf[0] && delimiter) {
					dc_strbuilder_cat(&str, delimiter);
				}
				dc_strbuilder_cat(&str, rfc724_mid);
			}
		}
	}

	return str.buf;
}


// Split a string by a character.
// If the string is empty or NULL, an empty list is returned.
// The returned clist must be freed using clist_free_content()+clist_free()
// or given eg. to libetpan objects.
clist* dc_str_to_clist(const char* str, const char* delimiter)
{
	clist* list = clist_new();
	if (list==NULL) {
		exit(54);
	}

	if (str && delimiter && strlen(delimiter)>=1) {
		const char* p1 = str;
		while (1) {
			const char* p2 = strstr(p1, delimiter);
			if (p2==NULL) {
				clist_append(list,  (void*)strdup(p1));
				break;
			}
			else {
				clist_append(list, (void*)strndup(p1, p2-p1));
				p1 = p2+strlen(delimiter);
			}
		}
	}

	return list;
}


int dc_str_to_color(const char* str)
{
	char* str_lower = dc_strlower(str);

	static uint32_t colors[] = {
		0xe56555,
		0xf28c48,
		0x8e85ee,
		0x76c84d,
		0x5bb6cc,
		0x549cdd,
		0xd25c99,
		0xb37800
	};

	int checksum = 0;
	int str_len = strlen(str_lower);
	for (int i = 0; i < str_len; i++) {
		checksum += (i+1)*str_lower[i];
		checksum %= 0x00FFFFFF;
	}

	int color_index = checksum % (sizeof(colors)/sizeof(uint32_t));

	free(str_lower);
	return colors[color_index];
}


/*******************************************************************************
 * clist tools
 ******************************************************************************/


void clist_free_content(const clist* haystack)
{
	for (clistiter* iter=clist_begin(haystack); iter!=NULL; iter=clist_next(iter)) {
		free(iter->data);
		iter->data = NULL;
	}
}


int clist_search_string_nocase(const clist* haystack, const char* needle)
{
	for (clistiter* iter=clist_begin(haystack); iter!=NULL; iter=clist_next(iter)) {
		if (strcasecmp((const char*)iter->data, needle)==0) {
			return 1;
		}
	}
	return 0;
}


/*******************************************************************************
 * date/time tools
 ******************************************************************************/


static int tmcomp(struct tm * atmp, struct tm * btmp) /* from mailcore2 */
{
    int result = 0;

    if ((result = (atmp->tm_year - btmp->tm_year))==0 &&
        (result = (atmp->tm_mon - btmp->tm_mon))==0 &&
        (result = (atmp->tm_mday - btmp->tm_mday))==0 &&
        (result = (atmp->tm_hour - btmp->tm_hour))==0 &&
        (result = (atmp->tm_min - btmp->tm_min))==0)
        result = atmp->tm_sec - btmp->tm_sec;
    return result;
}


static time_t mkgmtime(struct tm * tmp) /* from mailcore2 */
{
    int       dir = 0;
    int       bits = 0;
    int       saved_seconds = 0;
    time_t    t = 0;
    struct tm yourtm;
    struct tm mytm;

    yourtm = *tmp;
    saved_seconds = yourtm.tm_sec;
    yourtm.tm_sec = 0;
    /*
     ** Calculate the number of magnitude bits in a time_t
     ** (this works regardless of whether time_t is
     ** signed or unsigned, though lint complains if unsigned).
     */
    for (bits = 0, t = 1; t > 0; ++bits, t <<= 1)
        ;
    /*
     ** If time_t is signed, then 0 is the median value,
     ** if time_t is unsigned, then 1 << bits is median.
     */
    if(bits > 40) bits = 40;
    t = (t < 0) ? 0 : ((time_t) 1 << bits);
    for ( ; ;) {
        gmtime_r(&t, &mytm);
        dir = tmcomp(&mytm, &yourtm);
        if (dir!=0) {
            if (bits-- < 0) {
                return DC_INVALID_TIMESTAMP;
            }
            if (bits < 0)
                --t;
            else if (dir > 0)
                t -= (time_t) 1 << bits;
            else    t += (time_t) 1 << bits;
            continue;
        }
        break;
    }
    t += saved_seconds;
    return t;
}


time_t dc_timestamp_from_date(struct mailimf_date_time * date_time) /* from mailcore2 */
{
    struct tm tmval;
    time_t    timeval = 0;
    int       zone_min = 0;
    int       zone_hour = 0;

    tmval.tm_sec  = date_time->dt_sec;
    tmval.tm_min  = date_time->dt_min;
    tmval.tm_hour = date_time->dt_hour;
    tmval.tm_mday = date_time->dt_day;
    tmval.tm_mon  = date_time->dt_month - 1;
    if (date_time->dt_year < 1000) {
        /* workaround when century is not given in year */
        tmval.tm_year = date_time->dt_year + 2000 - 1900;
    }
    else {
        tmval.tm_year = date_time->dt_year - 1900;
    }

    timeval = mkgmtime(&tmval);

    if (date_time->dt_zone >= 0) {
        zone_hour = date_time->dt_zone / 100;
        zone_min = date_time->dt_zone % 100;
    }
    else {
        zone_hour = -((- date_time->dt_zone) / 100);
        zone_min = -((- date_time->dt_zone) % 100);
    }
    timeval -= zone_hour * 3600 + zone_min * 60;

    return timeval;
}


long dc_gm2local_offset(void)
{
	/* returns the offset that must be _added_ to an UTC/GMT-time to create the localtime.
	the function may return nagative values. */
	time_t    gmtime = time(NULL);
	struct tm timeinfo = {0};
	localtime_r(&gmtime, &timeinfo);
    return timeinfo.tm_gmtoff;
}


char* dc_timestamp_to_str(time_t wanted)
{
	struct tm wanted_struct;
	memcpy(&wanted_struct, localtime(&wanted), sizeof(struct tm));

	/* if you need the current time for relative dates, use the following lines:
	time_t curr;
	struct tm curr_struct;
	time(&curr);
	memcpy(&curr_struct, localtime(&curr), sizeof(struct tm));
	*/

	return dc_mprintf("%02i.%02i.%04i %02i:%02i:%02i",
		(int)wanted_struct.tm_mday, (int)wanted_struct.tm_mon+1, (int)wanted_struct.tm_year+1900,
		(int)wanted_struct.tm_hour, (int)wanted_struct.tm_min, (int)wanted_struct.tm_sec);
}


struct mailimap_date_time* dc_timestamp_to_mailimap_date_time(time_t timeval)
{
    struct tm                  gmt;
    struct tm                  lt;
    int                        off = 0;
    struct mailimap_date_time* date_time;
    int                        sign = 0;
    int                        hour = 0;
    int                        min = 0;

    gmtime_r(&timeval, &gmt);
    localtime_r(&timeval, &lt);

    off = (int) ((mkgmtime(&lt) - mkgmtime(&gmt)) / 60);
    if (off < 0) {
        sign = -1;
    }
    else {
        sign = 1;
    }
    off = off * sign;
    min = off % 60;
    hour = off / 60;
    off = hour * 100 + min;
    off = off * sign;

    date_time = mailimap_date_time_new(lt.tm_mday, lt.tm_mon + 1,
                                       lt.tm_year + 1900,
                                       lt.tm_hour, lt.tm_min, lt.tm_sec,
                                       off);

    return date_time;
}


/*******************************************************************************
 * Time smearing
 ******************************************************************************/


#define DC_MAX_SECONDS_TO_LEND_FROM_FUTURE   5


#define SMEAR_LOCK   { pthread_mutex_lock(&context->smear_critical); }
#define SMEAR_UNLOCK { pthread_mutex_unlock(&context->smear_critical); }


time_t dc_create_smeared_timestamp(dc_context_t* context)
{
	time_t now = time(NULL);
	time_t ret = now;
	SMEAR_LOCK
		if (ret <= context->last_smeared_timestamp) {
			ret = context->last_smeared_timestamp+1;
			if ((ret-now) > DC_MAX_SECONDS_TO_LEND_FROM_FUTURE) {
				ret = now + DC_MAX_SECONDS_TO_LEND_FROM_FUTURE;
			}
		}
		context->last_smeared_timestamp = ret;
	SMEAR_UNLOCK
	return ret;
}


time_t dc_create_smeared_timestamps(dc_context_t* context, int count)
{
	/* get a range to timestamps that can be used uniquely */
	time_t now = time(NULL);
	time_t start = now + DC_MIN(count, DC_MAX_SECONDS_TO_LEND_FROM_FUTURE) - count;
	SMEAR_LOCK
		start = DC_MAX(context->last_smeared_timestamp+1, start);
		context->last_smeared_timestamp = start+(count-1);
	SMEAR_UNLOCK
	return start;
}


time_t dc_smeared_time(dc_context_t* context)
{
	/* function returns a corrected time(NULL) */
	time_t now = time(NULL);
	SMEAR_LOCK
		if (context->last_smeared_timestamp >= now) {
			now = context->last_smeared_timestamp+1;
		}
	SMEAR_UNLOCK
	return now;
}


/*******************************************************************************
 * generate Message-IDs
 ******************************************************************************/


static char* encode_66bits_as_base64(uint32_t v1, uint32_t v2, uint32_t fill /*only the lower 2 bits are used*/)
{
	/* encode 66 bits as a base64 string. This is useful for ID generating with short strings as
	we save 5 character in each id compared to 64 bit hex encoding, for a typical group ID, these are 10 characters (grpid+msgid):
	hex:    64 bit, 4 bits/character, length = 64/4 = 16 characters
	base64: 64 bit, 6 bits/character, length = 64/6 = 11 characters (plus 2 additional bits) */
	char* ret = malloc(12); if (ret==NULL) { exit(34); }
	static const char chars[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
	ret[ 0] = chars[   (v1>>26) & 0x3F  ];
	ret[ 1] = chars[   (v1>>20) & 0x3F  ];
	ret[ 2] = chars[   (v1>>14) & 0x3F  ];
	ret[ 3] = chars[   (v1>> 8) & 0x3F  ];
	ret[ 4] = chars[   (v1>> 2) & 0x3F  ];
	ret[ 5] = chars[ ( (v1<< 4) & 0x30) | ( (v2>>28) & 0x0F) ];
	ret[ 6] = chars[                         (v2>>22) & 0x3F   ];
	ret[ 7] = chars[                         (v2>>16) & 0x3F   ];
	ret[ 8] = chars[                         (v2>>10) & 0x3F   ];
	ret[ 9] = chars[                         (v2>> 4) & 0x3F   ];
	ret[10] = chars[                       ( (v2<< 2) & 0x3C) | (fill & 0x03) ];
	ret[11] = 0;
	return ret;
}


char* dc_create_id(void)
{
	/* generate an id. the generated ID should be as short and as unique as possible:
	- short, because it may also used as part of Message-ID headers or in QR codes
	- unique as two IDs generated on two devices should not be the same. However, collisions are not world-wide but only by the few contacts.
	IDs generated by this function are 66 bit wide and are returned as 11 base64 characters.
	If possible, RNG of OpenSSL is used.

	Additional information when used as a message-id or group-id:
	- for OUTGOING messages this ID is written to the header as `Chat-Group-ID:` and is added to the message ID as Gr.<grpid>.<random>@<random>
	- for INCOMING messages, the ID is taken from the Chat-Group-ID-header or from the Message-ID in the In-Reply-To: or References:-Header
	- the group-id should be a string with the characters [a-zA-Z0-9\-_] */
	uint32_t buf[3];
	if (!RAND_bytes((unsigned char*)&buf, sizeof(uint32_t)*3)) {
		RAND_pseudo_bytes((unsigned char*)&buf, sizeof(uint32_t)*3);
	}
	return encode_66bits_as_base64(buf[0], buf[1], buf[2]/*only the lower 2 bits are taken from this value*/);
}


char* dc_create_outgoing_rfc724_mid(const char* grpid, const char* from_addr)
{
	/* Function generates a Message-ID that can be used for a new outgoing message.
	- this function is called for all outgoing messages.
	- the message ID should be globally unique
	- do not add a counter or any private data as as this may give unneeded information to the receiver	*/

	char*       rand1 = NULL;
	char*       rand2 = dc_create_id();
	char*       ret = NULL;
	const char* at_hostname = strchr(from_addr, '@');

	if (at_hostname==NULL) {
		at_hostname = "@nohost";
	}

	if (grpid) {
		ret = dc_mprintf("Gr.%s.%s%s", grpid, rand2, at_hostname);
		               /* ^^^ `Gr.` must never change as this is used to identify group messages in normal-clients-replies. The dot is choosen as this is normally not used for random ID creation. */
	}
	else {
		rand1 = dc_create_id();
		ret = dc_mprintf("Mr.%s.%s%s", rand1, rand2, at_hostname);
		               /* ^^^ `Mr.` is currently not used, however, this may change in future */
	}

	free(rand1);
	free(rand2);
	return ret;
}


char* dc_create_incoming_rfc724_mid(time_t message_timestamp, uint32_t contact_id_from, dc_array_t* contact_ids_to)
{
	/* Function generates a Message-ID for incoming messages that lacks one.
	- normally, this function is not needed as incoming messages already have an ID
	- the generated ID is only for internal use; it should be database-unique
	- when fetching the same message again, this function should generate the same Message-ID
	*/

	if (contact_ids_to==NULL || dc_array_get_cnt(contact_ids_to)==0) {
		return NULL;
	}

	/* find out the largest receiver ID (we could also take the smallest, but it should be unique) */
	size_t   i = 0;
	size_t   icnt = dc_array_get_cnt(contact_ids_to);
	uint32_t largest_id_to = 0;

	for (i = 0; i < icnt; i++) {
		uint32_t cur_id = dc_array_get_id(contact_ids_to, i);
		if (cur_id > largest_id_to) {
			largest_id_to = cur_id;
		}
	}

	/* build a more or less unique string based on the timestamp and one receiver -
	for our purposes, this seems "good enough" for the moment, esp. as clients normally set Message-ID on sent. */
	return dc_mprintf("%lu-%lu-%lu@stub", (unsigned long)message_timestamp, (unsigned long)contact_id_from, (unsigned long)largest_id_to);
}


char* dc_extract_grpid_from_rfc724_mid(const char* mid)
{
	/* extract our group ID from Message-IDs as `Gr.12345678901.morerandom@domain.de`; "12345678901" is the wanted ID in this example. */
	int   success = 0;
	char* grpid = NULL;
	char* p1 = NULL;
	int   grpid_len = 0;

	if (mid==NULL || strlen(mid)<8 || mid[0]!='G' || mid[1]!='r' || mid[2]!='.') {
		goto cleanup;
	}

	grpid = dc_strdup(&mid[3]);

	p1 = strchr(grpid, '.');
	if (p1==NULL) {
		goto cleanup;
	}
	*p1 = 0;

	#define DC_ALSO_VALID_ID_LEN  16 /* length returned by create_adhoc_grp_id() */
	grpid_len = strlen(grpid);
	if (grpid_len!=DC_CREATE_ID_LEN && grpid_len!=DC_ALSO_VALID_ID_LEN) { /* strict length comparison, the 'Gr.' magic is weak enough */
		goto cleanup;
	}

	success = 1;

cleanup:
	if (success==0) { free(grpid); grpid = NULL; }
	return success? grpid : NULL;
}


char* dc_extract_grpid_from_rfc724_mid_list(const clist* list)
{
	if (list) {
		for (clistiter* cur = clist_begin(list); cur!=NULL ; cur=clist_next(cur)) {
			const char* mid = clist_content(cur);
			char* grpid = dc_extract_grpid_from_rfc724_mid(mid);
			if (grpid) {
				return grpid;
			}
		}
	}
	return NULL;
}



/*******************************************************************************
 * file tools
 ******************************************************************************/


/*
 * removes trailing slash from given path.
 */
void dc_ensure_no_slash(char* pathNfilename)
{
	int path_len = strlen(pathNfilename);
	if (path_len > 0) {
		if (pathNfilename[path_len-1]=='/'
		 || pathNfilename[path_len-1]=='\\') {
			pathNfilename[path_len-1] = 0;
		}
	}
}


void dc_validate_filename(char* filename)
{
	/* function modifies the given buffer and replaces all characters not valid in filenames by a "-" */
	char* p1 = filename;
	while (*p1) {
		if (*p1=='/' || *p1=='\\' || *p1==':') {
			*p1 = '-';
		}
		p1++;
	}
}


char* dc_get_filename(const char* pathNfilename)
{
	const char* p = strrchr(pathNfilename, '/');
	if (p==NULL) {
		p = strrchr(pathNfilename, '\\');
	}

	if (p) {
		p++;
		return dc_strdup(p);
	}
	else {
		return dc_strdup(pathNfilename);
	}
}


void dc_split_filename(const char* pathNfilename, char** ret_basename, char** ret_all_suffixes_incl_dot)
{
	/* splits a filename into basename and all suffixes, eg. "/path/foo.tar.gz" is split into "foo.tar" and ".gz",
	(we use the _last_ dot which allows the usage inside the filename which are very usual;
	maybe the detection could be more intelligent, however, for the moment, it is just file)
	- if there is no suffix, the returned suffix string is empty, eg. "/path/foobar" is split into "foobar" and ""
	- the case of the returned suffix is preserved; this is to allow reconstruction of (similar) names */
	char* basename = dc_get_filename(pathNfilename);
	char* suffix = NULL;
	char* p1 = strrchr(basename, '.');

	if (p1) {
		suffix = dc_strdup(p1);
		*p1 = 0;
	}
	else {
		suffix = dc_strdup(NULL);
	}

	/* return the given values */
	if (ret_basename            ) { *ret_basename              = basename; } else { free(basename); }
	if (ret_all_suffixes_incl_dot) { *ret_all_suffixes_incl_dot = suffix;   } else { free(suffix);   }
}


char* dc_get_filesuffix_lc(const char* pathNfilename)
{
	if (pathNfilename) {
		const char* p = strrchr(pathNfilename, '.'); /* use the last point, we're interesting the "main" type */
		if (p) {
			p++;
			return dc_strlower(p); /* in contrast to dc_split_filename() we return the lowercase suffix */
		}
	}
	return NULL;
}


int dc_get_filemeta(const void* buf_start, size_t buf_bytes, uint32_t* ret_width, uint32_t *ret_height)
{
	/* Strategy:
	reading GIF dimensions requires the first 10 bytes of the file
	reading PNG dimensions requires the first 24 bytes of the file
	reading JPEG dimensions requires scanning through jpeg chunks
	In all formats, the file is at least 24 bytes big, so we'll read that always
	inspired by http://www.cplusplus.com/forum/beginner/45217/ */
	const unsigned char* buf = buf_start;
	if (buf_bytes<24) {
		return 0;
	}

	/* For JPEGs, we need to check the first bytes of each DCT chunk. */
	if (buf[0]==0xFF && buf[1]==0xD8 && buf[2]==0xFF)
	{
		long pos = 2;
		while (buf[pos]==0xFF)
		{
			if (buf[pos+1]==0xC0 || buf[pos+1]==0xC1 || buf[pos+1]==0xC2 || buf[pos+1]==0xC3 || buf[pos+1]==0xC9 || buf[pos+1]==0xCA || buf[pos+1]==0xCB) {
				*ret_height = (buf[pos+5]<<8) + buf[pos+6]; /* sic! height is first */
				*ret_width  = (buf[pos+7]<<8) + buf[pos+8];
				return 1;
			}
			pos += 2+(buf[pos+2]<<8)+buf[pos+3];
			if (pos+12>buf_bytes) { break; }
		}
	}

	/* GIF: first three bytes say "GIF", next three give version number. Then dimensions */
	if (buf[0]=='G' && buf[1]=='I' && buf[2]=='F')
	{
		*ret_width  = buf[6] + (buf[7]<<8);
		*ret_height = buf[8] + (buf[9]<<8);
		return 1;
	}

	/* PNG: the first frame is by definition an IHDR frame, which gives dimensions */
	if (buf[0]==0x89 && buf[1]=='P' && buf[2]=='N' && buf[3]=='G' && buf[4]==0x0D && buf[5]==0x0A && buf[6]==0x1A && buf[7]==0x0A
	 && buf[12]=='I' && buf[13]=='H' && buf[14]=='D' && buf[15]=='R')
	{
		*ret_width  = (buf[16]<<24) + (buf[17]<<16) + (buf[18]<<8) + (buf[19]<<0);
		*ret_height = (buf[20]<<24) + (buf[21]<<16) + (buf[22]<<8) + (buf[23]<<0);
		return 1;
	}

	return 0;
}


char* dc_get_abs_path(dc_context_t* context, const char* pathNfilename)
{
	int   success           = 0;
	char* pathNfilename_abs = NULL;

	if (context==NULL || pathNfilename==NULL) {
		goto cleanup;
	}

	pathNfilename_abs = dc_strdup(pathNfilename);

	if (strncmp(pathNfilename_abs, "$BLOBDIR", 8)==0) {
		if (context->blobdir==NULL) {
			goto cleanup;
		}
		dc_str_replace(&pathNfilename_abs, "$BLOBDIR", context->blobdir);
	}

	success = 1;

cleanup:
	if (!success) {
		free(pathNfilename_abs);
		pathNfilename_abs = NULL;
	}
	return pathNfilename_abs;
}


int dc_file_exist(dc_context_t* context, const char* pathNfilename)
{
	int   exist = 0;
	char* pathNfilename_abs = NULL;

	if ((pathNfilename_abs=dc_get_abs_path(context, pathNfilename))==NULL) {
		goto cleanup;
	}

	struct stat st;
	if (stat(pathNfilename_abs, &st)==0) {
		exist = 1; // the size, however, may be 0
	}

cleanup:
	free(pathNfilename_abs);
	return exist;
}


uint64_t dc_get_filebytes(dc_context_t* context, const char* pathNfilename)
{
	uint64_t filebytes = 0;
	char*    pathNfilename_abs = NULL;

	if ((pathNfilename_abs=dc_get_abs_path(context, pathNfilename))==NULL) {
		goto cleanup;
	}

	struct stat st;
	if (stat(pathNfilename_abs, &st)==0) {
		filebytes = (uint64_t)st.st_size;
	}

cleanup:
	free(pathNfilename_abs);
	return filebytes;
}


int dc_delete_file(dc_context_t* context, const char* pathNfilename)
{
	int   success = 0;
	char* pathNfilename_abs = NULL;

	if ((pathNfilename_abs=dc_get_abs_path(context, pathNfilename))==NULL) {
		goto cleanup;
	}

	if (remove(pathNfilename_abs)!=0) {
		dc_log_warning(context, 0, "Cannot delete \"%s\".", pathNfilename);
		goto cleanup;
	}

	success = 1;

cleanup:
	free(pathNfilename_abs);
	return success;
}


int dc_copy_file(dc_context_t* context, const char* src, const char* dest)
{
    int     success = 0;
    char*   src_abs = NULL;
    char*   dest_abs = NULL;
    int     fd_src = -1;
    int     fd_dest = -1;
    #define DC_COPY_BUF_SIZE 4096
    char    buf[DC_COPY_BUF_SIZE];
    size_t  bytes_read = 0;
    int     anything_copied = 0;

	if ((src_abs=dc_get_abs_path(context, src))==NULL
	 || (dest_abs=dc_get_abs_path(context, dest))==NULL) {
		goto cleanup;
	}

	if ((fd_src=open(src_abs, O_RDONLY)) < 0) {
		dc_log_error(context, 0, "Cannot open source file \"%s\".", src);
		goto cleanup;
	}

	if ((fd_dest=open(dest_abs, O_WRONLY|O_CREAT|O_EXCL, 0666)) < 0) {
		dc_log_error(context, 0, "Cannot open destination file \"%s\".", dest);
		goto cleanup;
	}

    while ((bytes_read=read(fd_src, buf, DC_COPY_BUF_SIZE)) > 0) {
        if (write(fd_dest, buf, bytes_read)!=bytes_read) {
            dc_log_error(context, 0, "Cannot write %i bytes to \"%s\".", bytes_read, dest);
		}
		anything_copied = 1;
    }

    if (!anything_copied) {
		/* not a single byte copied -> check if the source is empty, too */
		close(fd_src);
		fd_src = -1;
		if (dc_get_filebytes(context, src)!=0) {
			dc_log_error(context, 0, "Different size information for \"%s\".", bytes_read, dest);
			goto cleanup;
		}
    }

    success = 1;

cleanup:
	if (fd_src >= 0) { close(fd_src); }
	if (fd_dest >= 0) { close(fd_dest); }
	free(src_abs);
	free(dest_abs);
	return success;
}


int dc_create_folder(dc_context_t* context, const char* pathNfilename)
{
	int   success = 0;
	char* pathNfilename_abs = NULL;

	if ((pathNfilename_abs=dc_get_abs_path(context, pathNfilename))==NULL) {
		goto cleanup;
	}

	struct stat st;
	if (stat(pathNfilename_abs, &st)==-1) {
		if (mkdir(pathNfilename_abs, 0755)!=0) {
			dc_log_warning(context, 0, "Cannot create directory \"%s\".", pathNfilename);
			goto cleanup;
		}
	}

	success = 1;

cleanup:
	free(pathNfilename_abs);
	return success;
}


int dc_write_file(dc_context_t* context, const char* pathNfilename, const void* buf, size_t buf_bytes)
{
	int   success = 0;
	char* pathNfilename_abs = NULL;

	if ((pathNfilename_abs=dc_get_abs_path(context, pathNfilename))==NULL) {
		goto cleanup;
	}

	FILE* f = fopen(pathNfilename_abs, "wb");
	if (f) {
		if (fwrite(buf, 1, buf_bytes, f)==buf_bytes) {
			success = 1;
		}
		else {
			dc_log_warning(context, 0, "Cannot write %lu bytes to \"%s\".", (unsigned long)buf_bytes, pathNfilename);
		}
		fclose(f);
	}
	else {
		dc_log_warning(context, 0, "Cannot open \"%s\" for writing.", pathNfilename);
	}

cleanup:
	free(pathNfilename_abs);
	return success;
}


int dc_read_file(dc_context_t* context, const char* pathNfilename, void** buf, size_t* buf_bytes)
{
	int   success = 0;
	char* pathNfilename_abs = NULL;

	if (pathNfilename==NULL || buf==NULL || buf_bytes==NULL) {
		return 0; /* do not go to cleanup as this would dereference "buf" and "buf_bytes" */
	}

	*buf = NULL;
	*buf_bytes = 0;

	if ((pathNfilename_abs=dc_get_abs_path(context, pathNfilename))==NULL) {
		goto cleanup;
	}

	FILE* f = fopen(pathNfilename_abs, "rb");
	if (f==NULL) { goto cleanup; }

	fseek(f, 0, SEEK_END);
	*buf_bytes = ftell(f);
	fseek(f, 0, SEEK_SET);
	if (*buf_bytes<=0) { goto cleanup; }

	*buf = malloc( (*buf_bytes) + 1 /*be pragmatic and terminate all files by a null - fine for texts and does not hurt for the rest */);
	if (*buf==NULL) { goto cleanup; }

	((char*)*buf)[*buf_bytes /*we allocated one extra byte above*/] = 0;

	if (fread(*buf, 1, *buf_bytes, f)!=*buf_bytes) { goto cleanup; }

	success = 1;

cleanup:
	if (f) {
		fclose(f);
	}
	if (success==0) {
		free(*buf);
		*buf = NULL;
		*buf_bytes = 0;
		dc_log_warning(context, 0, "Cannot read \"%s\" or file is empty.", pathNfilename);
	}
	free(pathNfilename_abs);
	return success; /* buf must be free()'d by the caller */
}


char* dc_get_fine_pathNfilename(dc_context_t* context, const char* pathNfolder, const char* desired_filenameNsuffix__)
{
	char*  ret = NULL;
	char*  pathNfolder_wo_slash = NULL;
	char*  filenameNsuffix = NULL;
	char*  basename = NULL;
	char*  dotNSuffix = NULL;
	time_t now = time(NULL);
	int    i = 0;

	pathNfolder_wo_slash = dc_strdup(pathNfolder);
	dc_ensure_no_slash(pathNfolder_wo_slash);

	filenameNsuffix = dc_strdup(desired_filenameNsuffix__);
	dc_validate_filename(filenameNsuffix);
	dc_split_filename(filenameNsuffix, &basename, &dotNSuffix);

	for (i = 0; i < 1000 /*no deadlocks, please*/; i++) {
		if (i) {
			time_t idx = i<100? i : now+i;
			ret = dc_mprintf("%s/%s-%lu%s", pathNfolder_wo_slash, basename, (unsigned long)idx, dotNSuffix);
		}
		else {
			ret = dc_mprintf("%s/%s%s", pathNfolder_wo_slash, basename, dotNSuffix);
		}
		if (!dc_file_exist(context, ret)) {
			goto cleanup; /* fine filename found */
		}
		free(ret); /* try over with the next index */
		ret = NULL;
	}

cleanup:
	free(filenameNsuffix);
	free(basename);
	free(dotNSuffix);
	free(pathNfolder_wo_slash);
	return ret;
}


void dc_make_rel_path(dc_context_t* context, char** path)
{
	if (context==NULL || path==NULL || *path==NULL) {
		return;
	}

	if (strncmp(*path, context->blobdir, strlen(context->blobdir))==0) {
		dc_str_replace(path, context->blobdir, "$BLOBDIR");
	}
}


/**
 * Check if a path describes a file in the blob directory.
 * The path can be absolute or relative (starting with `$BLOBDIR`).
 * The function does not check if the file really exists.
 */
int dc_is_blobdir_path(dc_context_t* context, const char* path)
{
	if ((strncmp(path, context->blobdir, strlen(context->blobdir))==0)
	 || (strncmp(path, "$BLOBDIR", 8)==0)) {
		return 1;
	}
	return 0;
}


/**
 * Copy a file to the blob directory, if needed.
 *
 * @param context The context object as returned from dc_context_new().
 * @param[in,out] path The path, may be modified to a relative path
 *     starting with `$BLOBDIR`.
 * @return 1=success file may or may not be copied, 0=error
 */
int dc_make_rel_and_copy(dc_context_t* context, char** path)
{
	int   success = 0;
	char* filename = NULL;
	char* blobdir_path = NULL;

	if (context==NULL || path==NULL || *path==NULL) {
		goto cleanup;
	}

	if (dc_is_blobdir_path(context, *path)) {
		dc_make_rel_path(context, path);
		success = 1; // file is already in blobdir
		goto cleanup;
	}

	if ((filename=dc_get_filename(*path))==NULL
	 || (blobdir_path=dc_get_fine_pathNfilename(context, "$BLOBDIR", filename))==NULL
	 || !dc_copy_file(context, *path, blobdir_path)) {
		goto cleanup;
	}

	free(*path);
	*path = blobdir_path;
	blobdir_path = NULL;
	dc_make_rel_path(context, path);
    success = 1;

cleanup:
	free(blobdir_path);
	free(filename);
	return success;
}