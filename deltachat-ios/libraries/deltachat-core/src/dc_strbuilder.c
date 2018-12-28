#include "dc_context.h"


/**
 * Init a string-builder-object.
 * A string-builder-object is placed typically on the stack and contains a string-buffer
 * which is initially empty.
 *
 * You can add data to the string-buffer using eg. dc_strbuilder_cat() or
 * dc_strbuilder_catf() - the buffer is reallocated as needed.
 *
 * When you're done with string building, the ready-to-use, null-terminates
 * string can be found at dc_strbuilder_t::buf, you can do whatever you like
 * with this buffer, however, never forget to call free() when done.
 *
 * @param strbuilder The object to initialze.
 * @param init_bytes The number of bytes to reserve for the string. If you have an
 *     idea about how long the resulting string will be, you can give this as a hint here;
 *     this avoids some reallocations; if the string gets longer, reallocation is done.
 *     If you do not know how larget the string will be, give 0 here.
 * @return None.
 */
void dc_strbuilder_init(dc_strbuilder_t* strbuilder, int init_bytes)
{
	if (strbuilder==NULL) {
		return;
	}

	strbuilder->allocated    = DC_MAX(init_bytes, 128); /* use a small default minimum, we may use _many_ of these objects at the same time */
	strbuilder->buf          = malloc(strbuilder->allocated);

    if (strbuilder->buf==NULL) {
		exit(38);
	}

	strbuilder->buf[0]       = 0;
	strbuilder->free         = strbuilder->allocated - 1 /*the nullbyte! */;
	strbuilder->eos          = strbuilder->buf;
}


/**
 * Add a string to the end of the current string in a string-builder-object.
 * The internal buffer is reallocated as needed.
 * If reallocation fails, the program halts.
 *
 * @param strbuilder The object to initialze. Must be initialized with
 *      dc_strbuilder_init().
 * @param text Null-terminated string to add to the end of the string-builder-string.
 * @return Returns a pointer to the copy of the given text.
 *     The returned pointer is a pointer inside dc_strbuilder_t::buf and MUST NOT
 *     be freed.  If the string-builder was empty before, the returned
 *     pointer is equal to dc_strbuilder_t::buf.
 *     If the given text is NULL, NULL is returned and the string-builder-object is not modified.
 */
char* dc_strbuilder_cat(dc_strbuilder_t* strbuilder, const char* text)
{
	// this function MUST NOT call logging functions as it is used to output the log
	if (strbuilder==NULL || text==NULL) {
		return NULL;
	}

	int len = strlen(text);

	if (len > strbuilder->free) {
		int add_bytes  = DC_MAX(len, strbuilder->allocated);
		int old_offset = (int)(strbuilder->eos - strbuilder->buf);

		strbuilder->allocated = strbuilder->allocated + add_bytes;
		strbuilder->buf       = realloc(strbuilder->buf, strbuilder->allocated+add_bytes);

        if (strbuilder->buf==NULL) {
			exit(39);
		}

		strbuilder->free      = strbuilder->free + add_bytes;
		strbuilder->eos       = strbuilder->buf + old_offset;
	}

	char* ret = strbuilder->eos;

	strcpy(strbuilder->eos, text);
	strbuilder->eos += len;
	strbuilder->free -= len;

	return ret;
}


/**
 * Add a formatted string to a string-builder-object.
 * This function is similar to dc_strbuilder_cat() but allows the same
 * formatting options as eg. printf()
 *
 * @param strbuilder The object to initialze. Must be initialized with
 *      dc_strbuilder_init().
 * @param format The formatting string to add to the string-builder-object.
 *      This parameter may be followed by data to be inserted into the
 *      formatting string, see eg. printf()
 * @return None.
 */
void dc_strbuilder_catf(dc_strbuilder_t* strbuilder, const char* format, ...)
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
		dc_strbuilder_cat(strbuilder, "ErrFmt");
		return;
	}

	buf = malloc(char_cnt_without_zero+2 /* +1 would be enough, however, protect against off-by-one-errors */);
	if (buf==NULL) {
		va_end(argp_copy);
		dc_strbuilder_cat(strbuilder, "ErrMem");
		return;
	}

	vsnprintf(buf, char_cnt_without_zero+1, format, argp_copy);
	va_end(argp_copy);

	dc_strbuilder_cat(strbuilder, buf);
	free(buf);
}


/**
 * Set the string to a lenght of 0. This does not free the buffer;
 * if you want to free the buffer, you have to call free() on dc_strbuilder_t::buf.
 *
 * @param strbuilder The object to initialze. Must be initialized with
 *      dc_strbuilder_init().
 * @return None.
 */
void dc_strbuilder_empty(dc_strbuilder_t* strbuilder)
{
	strbuilder->buf[0] = 0;
	strbuilder->free   = strbuilder->allocated - 1 /*the nullbyte! */;
	strbuilder->eos    = strbuilder->buf;
}
