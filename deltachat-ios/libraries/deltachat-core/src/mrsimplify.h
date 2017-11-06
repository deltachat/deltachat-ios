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
 *******************************************************************************
 *
 * File:    mrsimplify.h
 * Purpose: Simplify and normalise text: Remove quotes, signatures, unnecessary
 *          lineends etc.
 *
 ******************************************************************************/


#ifndef __MRSIMPLIFY_H__
#define __MRSIMPLIFY_H__
#ifdef __cplusplus
extern "C" {
#endif


/*** library-private **********************************************************/

typedef struct mrsimplify_t
{
	int m_is_forwarded;
} mrsimplify_t;


mrsimplify_t* mrsimplify_new           ();
void          mrsimplify_unref         (mrsimplify_t*);

/* The data returned from Simplify() must be free()'d when no longer used, private */
char*         mrsimplify_simplify      (mrsimplify_t*, const char* txt_unterminated, int txt_bytes, int is_html);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRSIMPLIFY_H__ */

