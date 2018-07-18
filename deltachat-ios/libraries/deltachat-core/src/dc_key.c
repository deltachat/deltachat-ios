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
#include <memory.h>
#include "dc_context.h"
#include "dc_key.h"
#include "dc_pgp.h"
#include "dc_tools.h"


/*******************************************************************************
 * Main interface
 ******************************************************************************/


void dc_wipe_secret_mem(void* buf, size_t buf_bytes)
{
	/* wipe private keys or othere secrets with zeros so that secrets are no longer in RAM */
	if (buf==NULL || buf_bytes <= 0) {
		return;
	}

	memset(buf, 0x00, buf_bytes);
}


static void dc_key_empty(dc_key_t* key) /* only use before calling setters; take care when using this function together with reference counting, prefer new objects instead */
{
	if (key==NULL) {
		return;
	}

	if (key->type==DC_KEY_PRIVATE) {
		dc_wipe_secret_mem(key->binary, key->bytes);
	}

	free(key->binary);
	key->binary = NULL;
	key->bytes = 0;
	key->type = DC_KEY_PUBLIC;
}


dc_key_t* dc_key_new()
{
	dc_key_t* key;

	if ((key=calloc(1, sizeof(dc_key_t)))==NULL) {
		exit(44); /* cannot allocate little memory, unrecoverable error */
	}
	key->_m_heap_refcnt = 1;
	return key;
}


dc_key_t* dc_key_ref(dc_key_t* key)
{
	if (key==NULL) {
		return NULL;
	}
	key->_m_heap_refcnt++;
	return key;
}


void dc_key_unref(dc_key_t* key)
{
	if (key==NULL) {
		return;
	}

	key->_m_heap_refcnt--;
	if (key->_m_heap_refcnt != 0) {
		return;
	}

	dc_key_empty(key);
	free(key);
}


int dc_key_set_from_binary(dc_key_t* key, const void* data, int bytes, int type)
{
    dc_key_empty(key);
    if (key==NULL || data==NULL || bytes <= 0) {
		return 0;
    }
    key->binary = malloc(bytes);
    if (key->binary==NULL) {
		exit(40);
    }
    memcpy(key->binary, data, bytes);
    key->bytes = bytes;
    key->type = type;
    return 1;
}


int dc_key_set_from_key(dc_key_t* key, const dc_key_t* o)
{
	dc_key_empty(key);
	if (key==NULL || o==NULL) {
		return 0;
	}
	return dc_key_set_from_binary(key, o->binary, o->bytes, o->type);
}


int dc_key_set_from_stmt(dc_key_t* key, sqlite3_stmt* stmt, int index, int type)
{
	dc_key_empty(key);
	if (key==NULL || stmt==NULL) {
		return 0;
	}
	return dc_key_set_from_binary(key, (unsigned char*)sqlite3_column_blob(stmt, index), sqlite3_column_bytes(stmt, index), type);
}


int dc_key_set_from_base64(dc_key_t* key, const char* base64, int type)
{
	size_t indx = 0, result_len = 0;
	char* result = NULL;

	dc_key_empty(key);

	if (key==NULL || base64==NULL) {
		return 0;
	}

	if (mailmime_base64_body_parse(base64, strlen(base64), &indx, &result/*must be freed using mmap_string_unref()*/, &result_len)!=MAILIMF_NO_ERROR
	 || result==NULL || result_len==0) {
		return 0; /* bad key */
	}

	dc_key_set_from_binary(key, result, result_len, type);
	mmap_string_unref(result);

	return 1;
}


int dc_key_set_from_file(dc_key_t* key, const char* pathNfilename, dc_context_t* context)
{
	char*       buf = NULL;
	const char* headerline = NULL; // just pointer inside buf, must not be freed
	const char* base64 = NULL;     //   - " -
	size_t      buf_bytes = 0;
	int         type = -1;
	int         success = 0;

	dc_key_empty(key);

	if (key==NULL || pathNfilename==NULL) {
		goto cleanup;
	}

	if (!dc_read_file(pathNfilename, (void**)&buf, &buf_bytes, context)
	 || buf_bytes < 50) {
		goto cleanup; /* error is already loged */
	}

	if (!dc_split_armored_data(buf, &headerline, NULL, NULL, &base64)
	 || headerline==NULL || base64==NULL) {
		goto cleanup;
	}

	if (strcmp(headerline, "-----BEGIN PGP PUBLIC KEY BLOCK-----")==0) {
		type = DC_KEY_PUBLIC;
	}
	else if (strcmp(headerline, "-----BEGIN PGP PRIVATE KEY BLOCK-----")==0) {
		type = DC_KEY_PRIVATE;
	}
	else {
		dc_log_warning(context, 0, "Header missing for key \"%s\".", pathNfilename);
		goto cleanup;
	}

	if (!dc_key_set_from_base64(key, base64, type)) {
		dc_log_warning(context, 0, "Bad data in key \"%s\".", pathNfilename);
		goto cleanup;
	}

	success = 1;

cleanup:
	free(buf);
	return success;
}


int dc_key_equals(const dc_key_t* key, const dc_key_t* o)
{
	if (key==NULL || o==NULL
	 || key->binary==NULL || key->bytes<=0 || o->binary==NULL || o->bytes<=0) {
		return 0; /*error*/
	}

	if (key->bytes != o->bytes) {
		return 0; /*different size -> the keys cannot be equal*/
	}

	if (key->type != o->type) {
		return 0; /* cannot compare public with private keys */
	}

	return memcmp(key->binary, o->binary, o->bytes)==0? 1 : 0;
}


/*******************************************************************************
 * Save/Load keys
 ******************************************************************************/


int dc_key_save_self_keypair(const dc_key_t* public_key, const dc_key_t* private_key, const char* addr, int is_default, dc_sqlite3_t* sql)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;

	if (public_key==NULL || private_key==NULL || addr==NULL || sql==NULL
	 || public_key->binary==NULL || private_key->binary==NULL) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(sql,
		"INSERT INTO keypairs (addr, is_default, public_key, private_key, created) VALUES (?,?,?,?,?);");
	sqlite3_bind_text (stmt, 1, addr, -1, SQLITE_STATIC);
	sqlite3_bind_int  (stmt, 2, is_default);
	sqlite3_bind_blob (stmt, 3, public_key->binary, public_key->bytes, SQLITE_STATIC);
	sqlite3_bind_blob (stmt, 4, private_key->binary, private_key->bytes, SQLITE_STATIC);
	sqlite3_bind_int64(stmt, 5, time(NULL));
	if (sqlite3_step(stmt)!=SQLITE_DONE) {
		goto cleanup;
	}

	success = 1;

cleanup:
	sqlite3_finalize(stmt);
	return success;
}


int dc_key_load_self_public(dc_key_t* key, const char* self_addr, dc_sqlite3_t* sql)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;

	if (key==NULL || self_addr==NULL || sql==NULL) {
		goto cleanup;
	}

	dc_key_empty(key);
	stmt = dc_sqlite3_prepare(sql,
		"SELECT public_key FROM keypairs WHERE addr=? AND is_default=1;");
	sqlite3_bind_text (stmt, 1, self_addr, -1, SQLITE_STATIC);
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}
	dc_key_set_from_stmt(key, stmt, 0, DC_KEY_PUBLIC);
	success = 1;

cleanup:
	sqlite3_finalize(stmt);
	return success;
}


int dc_key_load_self_private(dc_key_t* key, const char* self_addr, dc_sqlite3_t* sql)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;

	if (key==NULL || self_addr==NULL || sql==NULL) {
		goto cleanup;
	}

	dc_key_empty(key);
	stmt = dc_sqlite3_prepare(sql,
		"SELECT private_key FROM keypairs WHERE addr=? AND is_default=1;");
	sqlite3_bind_text (stmt, 1, self_addr, -1, SQLITE_STATIC);
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}
	dc_key_set_from_stmt(key, stmt, 0, DC_KEY_PRIVATE);
	success = 1;

cleanup:
	sqlite3_finalize(stmt);
	return success;
}


/*******************************************************************************
 * Render keys
 ******************************************************************************/


static long crc_octets(const unsigned char *octets, size_t len)
{
	#define CRC24_INIT 0xB704CEL
	#define CRC24_POLY 0x1864CFBL
	long crc = CRC24_INIT;
	while (len--) {
		crc ^= (*octets++) << 16;
		for (int i = 0; i < 8; i++) {
			crc <<= 1;
			if (crc & 0x1000000)
			crc ^= CRC24_POLY;
		}
	}
	return crc & 0xFFFFFFL;
}


char* dc_render_base64(const void* buf, size_t buf_bytes, int break_every, const char* break_chars,
                       int add_checksum /*0=no checksum, 1=add without break, 2=add with break_chars*/)
{
	char* ret = NULL;

	if (buf==NULL || buf_bytes<=0) {
		goto cleanup;
	}

	if ((ret = encode_base64((const char*)buf, buf_bytes))==NULL) {
		goto cleanup;
	}

	#if 0
	if (add_checksum==1/*appended checksum*/) {
		long checksum = crc_octets(buf, buf_bytes);
		uint8_t c[3];
		c[0] = (uint8_t)((checksum >> 16)&0xFF);
		c[1] = (uint8_t)((checksum >> 8)&0xFF);
		c[2] = (uint8_t)((checksum)&0xFF);
		char* c64 = encode_base64((const char*)c, 3);
			char* temp = ret;
				ret = dc_mprintf("%s=%s", temp, c64);
			free(temp);
		free(c64);
	}
	#endif

	if (break_every>0) {
		char* temp = ret;
			ret = dc_insert_breaks(temp, break_every, break_chars);
		free(temp);
	}

	if (add_checksum==2/*checksum with break character*/) {
		long checksum = crc_octets(buf, buf_bytes);
		uint8_t c[3];
		c[0] = (uint8_t)((checksum >> 16)&0xFF);
		c[1] = (uint8_t)((checksum >> 8)&0xFF);
		c[2] = (uint8_t)((checksum)&0xFF);
		char* c64 = encode_base64((const char*)c, 3);
			char* temp = ret;
				ret = dc_mprintf("%s%s=%s", temp, break_chars, c64);
			free(temp);
		free(c64);
	}

cleanup:
	return ret;
}


char* dc_key_render_base64(const dc_key_t* key, int break_every, const char* break_chars, int add_checksum)
{
	if (key==NULL) {
		return NULL;
	}
	return dc_render_base64(key->binary, key->bytes, break_every, break_chars, add_checksum);
}


char* dc_key_render_asc(const dc_key_t* key, const char* add_header_lines /*must be terminated by \r\n*/)
{
	/* see RFC 4880, 6.2.  Forming ASCII Armor, https://tools.ietf.org/html/rfc4880#section-6.2 */
	char* base64 = NULL;
	char* ret = NULL;

	if (key==NULL) {
		goto cleanup;
	}

	if ((base64=dc_key_render_base64(key, 76, "\r\n", 2/*checksum in new line*/))==NULL) { /* RFC: The encoded output stream must be represented in lines of no more than 76 characters each. */
		goto cleanup;
	}

	ret = dc_mprintf("-----BEGIN PGP %s KEY BLOCK-----\r\n%s\r\n%s\r\n-----END PGP %s KEY BLOCK-----\r\n",
		key->type==DC_KEY_PUBLIC? "PUBLIC" : "PRIVATE",
		add_header_lines? add_header_lines : "",
		base64,
		key->type==DC_KEY_PUBLIC? "PUBLIC" : "PRIVATE");

cleanup:
	free(base64);
	return ret;
}


int dc_key_render_asc_to_file(const dc_key_t* key, const char* file, dc_context_t* context /* for logging only */)
{
	int   success = 0;
	char* file_content = NULL;

	if (key==NULL || file==NULL || context==NULL) {
		goto cleanup;
	}

	file_content = dc_key_render_asc(key, NULL);
	if (file_content==NULL) {
		goto cleanup;
	}

	if (!dc_write_file(file, file_content, strlen(file_content), context)) {
		dc_log_error(context, 0, "Cannot write key to %s", file);
		goto cleanup;
	}

cleanup:
	free(file_content);
	return success;
}


/* make a fingerprint human-readable */
char* dc_format_fingerprint(const char* fingerprint)
{
	int             i = 0;
	int             fingerprint_len = strlen(fingerprint);
	dc_strbuilder_t ret;
	dc_strbuilder_init(&ret, 0);

    while (fingerprint[i]) {
		dc_strbuilder_catf(&ret, "%c", fingerprint[i]);
		i++;
		if (i!=fingerprint_len) {
			if (i%20==0) {
				dc_strbuilder_cat(&ret, "\n");
			}
			else if (i%4==0) {
				dc_strbuilder_cat(&ret, " ");
			}
		}
    }

	return ret.buf;
}


/* bring a human-readable or otherwise formatted fingerprint back to the
40-characters-uppercase-hex format */
char* dc_normalize_fingerprint(const char* in)
{
	if (in==NULL) {
		return NULL;
	}

	dc_strbuilder_t out;
	dc_strbuilder_init(&out, 0);

	const char* p1 = in;
	while (*p1) {
		if ((*p1 >= '0' && *p1 <= '9') || (*p1 >= 'A' && *p1 <= 'F') || (*p1 >= 'a' && *p1 <= 'f')) {
			dc_strbuilder_catf(&out, "%c", toupper(*p1)); /* make uppercase which is needed as we do not search case-insensitive, see comment in dc_sqlite3.c */
		}
		p1++;
	}

	return out.buf;
}


char* dc_key_get_fingerprint(const dc_key_t* key)
{
	uint8_t* fingerprint_buf = NULL;
	size_t   fingerprint_bytes = 0;
	char*    fingerprint_hex = NULL;

	if (key==NULL) {
		goto cleanup;
	}

	if (!dc_pgp_calc_fingerprint(key, &fingerprint_buf, &fingerprint_bytes)) {
		goto cleanup;
	}

	fingerprint_hex = dc_binary_to_uc_hex(fingerprint_buf, fingerprint_bytes);

cleanup:
	free(fingerprint_buf);
	return fingerprint_hex? fingerprint_hex : dc_strdup(NULL);
}


char* dc_key_get_formatted_fingerprint(const dc_key_t* key)
{
	char* rawhex = dc_key_get_fingerprint(key);
	char* formatted = dc_format_fingerprint(rawhex);
	free(rawhex);
	return formatted;
}