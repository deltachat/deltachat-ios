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


#include "mrmailbox_internal.h"
#include <memory.h>
#include "mrkey.h"
#include "mrpgp.h"
#include "mrtools.h"


/*******************************************************************************
 * Main interface
 ******************************************************************************/


void mr_wipe_secret_mem(void* buf, size_t buf_bytes)
{
	/* wipe private keys or othere secrets with zeros so that secrets are no longer in RAM */
	if( buf == NULL || buf_bytes <= 0 ) {
		return;
	}

	memset(buf, 0x00, buf_bytes);
}


static void mrkey_empty(mrkey_t* ths) /* only use before calling setters; take care when using this function together with reference counting, prefer new objects instead */
{
	if( ths == NULL ) {
		return;
	}

	if( ths->m_type==MR_PRIVATE ) {
		mr_wipe_secret_mem(ths->m_binary, ths->m_bytes);
	}

	free(ths->m_binary);
	ths->m_binary = NULL;
	ths->m_bytes = 0;
	ths->m_type = MR_PUBLIC;
}


mrkey_t* mrkey_new()
{
	mrkey_t* ths;

	if( (ths=calloc(1, sizeof(mrkey_t)))==NULL ) {
		exit(44); /* cannot allocate little memory, unrecoverable error */
	}
	ths->_m_heap_refcnt = 1;
	return ths;
}


mrkey_t* mrkey_ref(mrkey_t* ths)
{
	if( ths==NULL ) {
		return NULL;
	}
	ths->_m_heap_refcnt++;
	return ths;
}


void mrkey_unref(mrkey_t* ths)
{
	if( ths==NULL ) {
		return;
	}

	ths->_m_heap_refcnt--;
	if( ths->_m_heap_refcnt != 0 ) {
		return;
	}

	mrkey_empty(ths);
	free(ths);
}


int mrkey_set_from_raw(mrkey_t* ths, const void* data, int bytes, int type)
{
    mrkey_empty(ths);
    if( ths==NULL || data==NULL || bytes <= 0 ) {
		return 0;
    }
    ths->m_binary = malloc(bytes);
    if( ths->m_binary == NULL ) {
		exit(40);
    }
    memcpy(ths->m_binary, data, bytes);
    ths->m_bytes = bytes;
    ths->m_type = type;
    return 1;
}


int mrkey_set_from_key(mrkey_t* ths, const mrkey_t* o)
{
	mrkey_empty(ths);
	if( ths==NULL || o==NULL ) {
		return 0;
	}
	return mrkey_set_from_raw(ths, o->m_binary, o->m_bytes, o->m_type);
}


int mrkey_set_from_stmt(mrkey_t* ths, sqlite3_stmt* stmt, int index, int type)
{
	mrkey_empty(ths);
	if( ths==NULL || stmt==NULL ) {
		return 0;
	}
	return mrkey_set_from_raw(ths, (unsigned char*)sqlite3_column_blob(stmt, index), sqlite3_column_bytes(stmt, index), type);
}


int mrkey_set_from_base64(mrkey_t* ths, const char* base64, int type)
{
	size_t indx = 0, result_len = 0;
	char* result = NULL;

	mrkey_empty(ths);

	if( ths==NULL || base64==NULL ) {
		return 0;
	}

	if( mailmime_base64_body_parse(base64, strlen(base64), &indx, &result/*must be freed using mmap_string_unref()*/, &result_len)!=MAILIMF_NO_ERROR
	 || result == NULL || result_len == 0 ) {
		return 0; /* bad key */
	}

	mrkey_set_from_raw(ths, result, result_len, type);
	mmap_string_unref(result);

	return 1;
}


int mrkey_set_from_file(mrkey_t* ths, const char* pathNfilename, mrmailbox_t* mailbox)
{
	char*   buf = NULL;
	char    *p1, *p2; /* just pointers inside buf, must not be freed */
	size_t  buf_bytes;
	int     type = -1, success = 0;

	mrkey_empty(ths);

	if( ths==NULL || pathNfilename==NULL ) {
		goto cleanup;
	}

	if( !mr_read_file(pathNfilename, (void**)&buf, &buf_bytes, mailbox)
	 || buf_bytes < 50 ) {
		goto cleanup; /* error is already loged */
	}

	mr_remove_cr_chars(buf); /* make comparison easier */
	mr_trim(buf);

	if( strncmp(buf, "-----BEGIN PGP PUBLIC KEY BLOCK-----\n", 37)==0 ) {
		if( mr_str_replace(&buf, "-----END PGP PUBLIC KEY BLOCK-----", "")!=1 ) {
			mrmailbox_log_warning(mailbox, 0, "Bad header for key \"%s\".", pathNfilename);
			goto cleanup;
		}
		type = MR_PUBLIC;
		p1 = buf + 37; /* must be done after buf-pointer modification in mr_str_replace() */
	}
	else if( strncmp(buf, "-----BEGIN PGP PRIVATE KEY BLOCK-----\n", 38)==0 ) {
		if( mr_str_replace(&buf, "-----END PGP PRIVATE KEY BLOCK-----", "")!=1 ) {
			mrmailbox_log_warning(mailbox, 0, "Bad header for key \"%s\".", pathNfilename);
			goto cleanup;
		}
		type = MR_PRIVATE;
		p1 = buf + 38; /* must be done after buf-pointer modification in mr_str_replace() */
	}
	else {
		mrmailbox_log_warning(mailbox, 0, "Header missing for key \"%s\".", pathNfilename);
		goto cleanup;
	}

	/* base64 starts after first empty line, if any */
	p2 = strstr(p1, "\n\n"); /* `\r*  is already removed above */
	if( p2 ) {
		p1 = p2;
	}

	if( !mrkey_set_from_base64(ths, p1, type) ) {
		mrmailbox_log_warning(mailbox, 0, "Bad data in key \"%s\".", pathNfilename);
		goto cleanup;
	}

	success = 1;

cleanup:
	free(buf);
	return success;
}


int mrkey_equals(const mrkey_t* ths, const mrkey_t* o)
{
	if( ths==NULL || o==NULL
	 || ths->m_binary==NULL || ths->m_bytes<=0 || o->m_binary==NULL || o->m_bytes<=0 ) {
		return 0; /*error*/
	}

	if( ths->m_bytes != o->m_bytes ) {
		return 0; /*different size -> the keys cannot be equal*/
	}

	if( ths->m_type != o->m_type ) {
		return 0; /* cannot compare public with private keys */
	}

	return memcmp(ths->m_binary, o->m_binary, o->m_bytes)==0? 1 : 0;
}


/*******************************************************************************
 * Save/Load keys
 ******************************************************************************/


int mrkey_save_self_keypair__(const mrkey_t* public_key, const mrkey_t* private_key, const char* addr, int is_default, mrsqlite3_t* sql)
{
	sqlite3_stmt* stmt;

	if( public_key==NULL || private_key==NULL || addr==NULL || sql==NULL
	 || public_key->m_binary==NULL || private_key->m_binary==NULL ) {
		return 0;
	}

	stmt = mrsqlite3_predefine__(sql, INSERT_INTO_keypairs_aippc,
		"INSERT INTO keypairs (addr, is_default, public_key, private_key, created) VALUES (?,?,?,?,?);");
	sqlite3_bind_text (stmt, 1, addr, -1, SQLITE_STATIC);
	sqlite3_bind_int  (stmt, 2, is_default);
	sqlite3_bind_blob (stmt, 3, public_key->m_binary, public_key->m_bytes, SQLITE_STATIC);
	sqlite3_bind_blob (stmt, 4, private_key->m_binary, private_key->m_bytes, SQLITE_STATIC);
	sqlite3_bind_int64(stmt, 5, time(NULL));
	if( sqlite3_step(stmt) != SQLITE_DONE ) {
		return 0;
	}

	return 1;
}


int mrkey_load_self_public__(mrkey_t* ths, const char* self_addr, mrsqlite3_t* sql)
{
	sqlite3_stmt* stmt;

	if( ths==NULL || self_addr==NULL || sql==NULL ) {
		return 0;
	}

	mrkey_empty(ths);
	stmt = mrsqlite3_predefine__(sql, SELECT_public_key_FROM_keypairs_WHERE_default,
		"SELECT public_key FROM keypairs WHERE addr=? AND is_default=1;");
	sqlite3_bind_text (stmt, 1, self_addr, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}
	mrkey_set_from_stmt(ths, stmt, 0, MR_PUBLIC);
	return 1;
}


int mrkey_load_self_private__(mrkey_t* ths, const char* self_addr, mrsqlite3_t* sql)
{
	sqlite3_stmt* stmt;

	if( ths==NULL || self_addr==NULL || sql==NULL ) {
		return 0;
	}

	mrkey_empty(ths);
	stmt = mrsqlite3_predefine__(sql, SELECT_private_key_FROM_keypairs_WHERE_default,
		"SELECT private_key FROM keypairs WHERE addr=? AND is_default=1;");
	sqlite3_bind_text (stmt, 1, self_addr, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}
	mrkey_set_from_stmt(ths, stmt, 0, MR_PRIVATE);
	return 1;
}


/*******************************************************************************
 * Render keys
 ******************************************************************************/


static long crc_octets(const unsigned char *octets, size_t len)
{
	#define CRC24_INIT 0xB704CEL
	#define CRC24_POLY 0x1864CFBL
	long crc = CRC24_INIT;
	int i;
	while (len--) {
		crc ^= (*octets++) << 16;
		for (i = 0; i < 8; i++) {
			crc <<= 1;
			if (crc & 0x1000000)
			crc ^= CRC24_POLY;
		}
	}
	return crc & 0xFFFFFFL;
}


char* mr_render_base64(const void* buf, size_t buf_bytes, int break_every, const char* break_chars,
                       int add_checksum /*0=no checksum, 1=add without break, 2=add with break_chars*/)
{
	char* ret = NULL;

	if( buf==NULL || buf_bytes<=0 ) {
		goto cleanup;
	}

	if( (ret = encode_base64((const char*)buf, buf_bytes))==NULL ) {
		goto cleanup;
	}

	#if 0
	if( add_checksum == 1/*appended checksum*/ ) {
		long checksum = crc_octets(buf, buf_bytes);
		uint8_t c[3];
		c[0] = (uint8_t)((checksum >> 16)&0xFF);
		c[1] = (uint8_t)((checksum >> 8)&0xFF);
		c[2] = (uint8_t)((checksum)&0xFF);
		char* c64 = encode_base64((const char*)c, 3);
			char* temp = ret;
				ret = mr_mprintf("%s=%s", temp, c64);
			free(temp);
		free(c64);
	}
	#endif

	if( break_every>0 ) {
		char* temp = ret;
			ret = mr_insert_breaks(temp, break_every, break_chars);
		free(temp);
	}

	if( add_checksum == 2/*checksum with break character*/ ) {
		long checksum = crc_octets(buf, buf_bytes);
		uint8_t c[3];
		c[0] = (uint8_t)((checksum >> 16)&0xFF);
		c[1] = (uint8_t)((checksum >> 8)&0xFF);
		c[2] = (uint8_t)((checksum)&0xFF);
		char* c64 = encode_base64((const char*)c, 3);
			char* temp = ret;
				ret = mr_mprintf("%s%s=%s", temp, break_chars, c64);
			free(temp);
		free(c64);
	}

cleanup:
	return ret;
}


char* mrkey_render_base64(const mrkey_t* ths, int break_every, const char* break_chars, int add_checksum)
{
	if( ths==NULL ) {
		return NULL;
	}
	return mr_render_base64(ths->m_binary, ths->m_bytes, break_every, break_chars, add_checksum);
}


char* mrkey_render_asc(const mrkey_t* ths, const char* add_header_lines /*must be terminated by \r\n*/)
{
	/* see RFC 4880, 6.2.  Forming ASCII Armor, https://tools.ietf.org/html/rfc4880#section-6.2 */
	char *base64 = NULL, *ret = NULL;

	if( ths==NULL ) {
		goto cleanup;
	}

	if( (base64=mrkey_render_base64(ths, 76, "\r\n", 2/*checksum in new line*/))==NULL ) { /* RFC: The encoded output stream must be represented in lines of no more than 76 characters each. */
		goto cleanup;
	}

	ret = mr_mprintf("-----BEGIN PGP %s KEY BLOCK-----\r\n%s\r\n%s\r\n-----END PGP %s KEY BLOCK-----\r\n",
		ths->m_type==MR_PUBLIC? "PUBLIC" : "PRIVATE",
		add_header_lines? add_header_lines : "",
		base64,
		ths->m_type==MR_PUBLIC? "PUBLIC" : "PRIVATE");

cleanup:
	free(base64);
	return ret;
}


char* mr_render_fingerprint(const uint8_t* data, size_t bytes)
{
	int i;
	char* temp;

	if( data ==NULL || bytes <= 0 ) {
		return safe_strdup("ErrFingerprint2");
	}

	char* ret = malloc(bytes*4+1); if( ret==NULL ) { exit(46); }
	ret[0] = 0;

	for( i = 0; i < bytes; i++ ) {
		temp = mr_mprintf("%02X%s", (int)data[i], (i==6||i==13)?"\n":" ");
		strcat(ret, temp);
		free(temp);
	}

	return ret;
}


char* mrkey_render_fingerprint(const mrkey_t* key, mrmailbox_t* mailbox)
{
	uint8_t* fingerprint_buf = NULL;
	size_t   fingerprint_bytes = 0;

	if( key==NULL || mailbox == NULL ) {
		return safe_strdup("ErrFingerprint0");
	}

	if( !mrpgp_calc_fingerprint(mailbox, key, &fingerprint_buf, &fingerprint_bytes) ) {
		return safe_strdup("ErrFingerprint1");
	}

	char* fingerprint_str = mr_render_fingerprint(fingerprint_buf, fingerprint_bytes);
	free(fingerprint_buf);
	return fingerprint_str;
}

