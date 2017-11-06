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
 * File:    mrpoortext.h
 * Purpose: A line of text that describes eg. the last chat state as
 *          "Draft: Foo" or "Me: Foobar" (not really _richtext_, therefore
 *          _poortext_)
 *
 ******************************************************************************/


#ifndef __MRPOORTEXT_H__
#define __MRPOORTEXT_H__
#ifdef __cplusplus
extern "C" {
#endif


/* additional, emphasized text */
#define MR_TEXT1_NORMAL    0
#define MR_TEXT1_DRAFT     1 /* the values must not be changes as used directly in the frontend */
#define MR_TEXT1_USERNAME  2
#define MR_TEXT1_SELF      3


typedef struct mrpoortext_t
{
	char*    m_text1;         /* may be NULL */
	int      m_text1_meaning; /* one of MR_TEXT1_* */
	char*    m_text2;         /* may be NULL */
	time_t   m_timestamp;     /* may be 0 */
	int      m_state;         /* may be 0 */
} mrpoortext_t;


mrpoortext_t* mrpoortext_new       ();
void          mrpoortext_unref     (mrpoortext_t*);

void          mrpoortext_empty     (mrpoortext_t*);


/*** library-private **********************************************************/


#define MR_SUMMARY_CHARACTERS 160 /* in practice, the user additinally cuts the string himself pixel-accurate */
void mrpoortext_fill(mrpoortext_t*, const mrmsg_t*, const mrchat_t*, const mrcontact_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRPOORTEXT_H__ */

