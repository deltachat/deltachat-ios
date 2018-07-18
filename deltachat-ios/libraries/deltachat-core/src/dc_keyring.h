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


#ifndef __DC_KEYRING_H__
#define __DC_KEYRING_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct dc_key_t dc_key_t;


/**
 * Library-internal.
 */
typedef struct dc_keyring_t
{
	/** @privatesection */

	dc_key_t** keys; /**< Keys in the keyring. Only pointers to keys, the caller is responsible for freeing them and should make sure, the pointers are valid as long as the keyring is valid. */
	int        count;
	int        allocated;
} dc_keyring_t;

dc_keyring_t* dc_keyring_new  ();
void          dc_keyring_unref();

void          dc_keyring_add  (dc_keyring_t*, dc_key_t*); /* the reference counter of the key is increased by one */

int           dc_keyring_load_self_private_for_decrypting(dc_keyring_t*, const char* self_addr, dc_sqlite3_t* sql);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_KEYRING_H__ */

