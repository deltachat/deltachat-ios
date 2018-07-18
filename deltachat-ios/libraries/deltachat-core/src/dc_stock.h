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


#ifndef __DC_STOCK_H__
#define __DC_STOCK_H__
#ifdef __cplusplus
extern "C" {
#endif


#include <stdlib.h>
#include <string.h>


/* Strings requested by DC_EVENT_GET_STRING and DC_EVENT_GET_QUANTITY_STRING */
#define DC_STR_FREE_                      0
#define DC_STR_NOMESSAGES                 1
#define DC_STR_SELF                       2
#define DC_STR_DRAFT                      3
#define DC_STR_MEMBER                     4
#define DC_STR_CONTACT                    6
#define DC_STR_VOICEMESSAGE               7
#define DC_STR_DEADDROP                   8
#define DC_STR_IMAGE                      9
#define DC_STR_VIDEO                      10
#define DC_STR_AUDIO                      11
#define DC_STR_FILE                       12
#define DC_STR_STATUSLINE                 13
#define DC_STR_NEWGROUPDRAFT              14
#define DC_STR_MSGGRPNAME                 15
#define DC_STR_MSGGRPIMGCHANGED           16
#define DC_STR_MSGADDMEMBER               17
#define DC_STR_MSGDELMEMBER               18
#define DC_STR_MSGGROUPLEFT               19
#define DC_STR_SELFNOTINGRP               21
#define DC_STR_NONETWORK                  22
#define DC_STR_GIF                        23
#define DC_STR_ENCRYPTEDMSG               24
#define DC_STR_E2E_AVAILABLE              25
#define DC_STR_ENCR_TRANSP                27
#define DC_STR_ENCR_NONE                  28
#define DC_STR_CANTDECRYPT_MSG_BODY       29
#define DC_STR_FINGERPRINTS               30
#define DC_STR_READRCPT                   31
#define DC_STR_READRCPT_MAILBODY          32
#define DC_STR_MSGGRPIMGDELETED           33
#define DC_STR_E2E_PREFERRED              34
#define DC_STR_ARCHIVEDCHATS              40
#define DC_STR_STARREDMSGS                41
#define DC_STR_AC_SETUP_MSG_SUBJECT       42
#define DC_STR_AC_SETUP_MSG_BODY          43
#define DC_STR_SELFTALK_SUBTITLE          50
#define DC_STR_CANNOT_LOGIN               60
#define DC_STR_SERVER_RESPONSE            61


/* Return the string with the given ID by calling DC_EVENT_GET_STRING.
The result must be free()'d! */
char* dc_stock_str (dc_context_t*, int id);


/* Replaces the first `%1$s` in the given String-ID by the given value.
The result must be free()'d! */
char* dc_stock_str_repl_string (dc_context_t*, int id, const char* value);
char* dc_stock_str_repl_int    (dc_context_t*, int id, int value);


/* Replaces the first `%1$s` and `%2$s` in the given String-ID by the two given strings.
The result must be free()'d! */
char* dc_stock_str_repl_string2 (dc_context_t*, int id, const char*, const char*);


/* Return a string with a correct plural form by callint DC_EVENT_GET_QUANTITY_STRING.
The result must be free()'d! */
char* dc_stock_str_repl_pl (dc_context_t*, int id, int cnt);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_STOCK_H__ */

