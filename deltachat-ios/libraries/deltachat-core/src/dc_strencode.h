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


#ifndef __DC_STRENCODE_H__
#define __DC_STRENCODE_H__
#ifdef __cplusplus
extern "C" {
#endif


char*   dc_urlencode              (const char*);
char*   dc_urldecode              (const char*);

char*   dc_encode_header_words    (const char*);
char*   dc_decode_header_words    (const char*);

char*   dc_encode_modified_utf7   (const char*, int change_spaces);
char*   dc_decode_modified_utf7   (const char*, int change_spaces);

int     dc_needs_ext_header       (const char*);
char*   dc_encode_ext_header      (const char*);
char*   dc_decode_ext_header      (const char*);


#ifdef __cplusplus
} // /extern "C"
#endif
#endif // __DC_STRENCODE_H__

