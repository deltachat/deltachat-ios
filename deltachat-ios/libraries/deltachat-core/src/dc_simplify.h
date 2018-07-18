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


#ifndef __DC_SIMPLIFY_H__
#define __DC_SIMPLIFY_H__
#ifdef __cplusplus
extern "C" {
#endif


/*** library-private **********************************************************/

typedef struct dc_simplify_t
{
	int is_forwarded;
	int is_cut_at_begin;
	int is_cut_at_end;
} dc_simplify_t;


dc_simplify_t* dc_simplify_new           ();
void           dc_simplify_unref         (dc_simplify_t*);

/* Simplify and normalise text: Remove quotes, signatures, unnecessary
lineends etc.
The data returned from Simplify() must be free()'d when no longer used, private */
char*          dc_simplify_simplify      (dc_simplify_t*, const char* txt_unterminated, int txt_bytes, int is_html);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_SIMPLIFY_H__ */

