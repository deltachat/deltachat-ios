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


#ifndef __DC_STRBUILDER_H__
#define __DC_STRBUILDER_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct dc_strbuilder_t
{
	char* buf;
	int   allocated;
	int   free;
	char* eos;
} dc_strbuilder_t;


void  dc_strbuilder_init    (dc_strbuilder_t*, int init_bytes);
char* dc_strbuilder_cat     (dc_strbuilder_t*, const char* text);
void  dc_strbuilder_catf    (dc_strbuilder_t*, const char* format, ...);
void  dc_strbuilder_empty   (dc_strbuilder_t*);


#ifdef __cplusplus
} // /extern "C"
#endif
#endif // __DC_STRBUILDER_H__

