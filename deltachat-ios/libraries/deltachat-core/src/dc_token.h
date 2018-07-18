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


#ifndef __DC_TOKEN_H__
#define __DC_TOKEN_H__
#ifdef __cplusplus
extern "C" {
#endif


// Token namespaces
typedef enum {
	DC_TOKEN_INVITENUMBER = 100,
	DC_TOKEN_AUTH = 110
} dc_tokennamespc_t;


// Functions to read/write token from/to the database. A token is any string associated with a key.
void     dc_token_save                   (dc_context_t*, dc_tokennamespc_t, uint32_t foreign_id, const char* token);
char*    dc_token_lookup                 (dc_context_t*, dc_tokennamespc_t, uint32_t foreign_id);
int      dc_token_exists                 (dc_context_t*, dc_tokennamespc_t, const char* token);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_TOKEN_H__ */

