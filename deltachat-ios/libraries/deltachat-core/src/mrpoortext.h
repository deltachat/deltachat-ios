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


#ifndef __MRPOORTEXT_H__
#define __MRPOORTEXT_H__
#ifdef __cplusplus
extern "C" {
#endif


/**
 * An object representing text with some attributes.  A poortext object
 * contains some strings together with their meaning and some attributes.
 * Poortext objects are returned eg. from mrchatlist_get_summary() or mrmsg_get_summary().
 */
typedef struct mrpoortext_t
{
	/** Defines the meaning of the m_text1 string.
	 * - MR_TEXT1_NORMAL (0) = m_text1 is a normal text field.
	 * - MR_TEXT1_DRAFT = m_text1 is the string "Draft", typically, this is shown in another color.
	 * - MR_TEXT1_USERNAME = m_text1 is a username, typically, this is shown in another color.
	 * - MR_TEXT1_SELF = m_text1 is the string "Me", typically, this is shown in another color.
	 */
	int             m_text1_meaning;

	char*           m_text1;           /**< The meaning is defined by m_text1_meaning and by the creator of the object. May be NULL. */
	char*           m_text2;           /**< The meaning is defined by the creator of the object. May be NULL. */
	time_t          m_timestamp;       /**< Typically a message timestamp.  The concrete meaning is defined by the creator of the object. May be 0. */
	int             m_state;           /**< Typically a MR_MSG_STATE_* constant. May be 0. */
} mrpoortext_t;


#define         MR_TEXT1_NORMAL    0
#define         MR_TEXT1_DRAFT     1
#define         MR_TEXT1_USERNAME  2
#define         MR_TEXT1_SELF      3


mrpoortext_t*   mrpoortext_new       ();
void            mrpoortext_empty     (mrpoortext_t*);
void            mrpoortext_unref     (mrpoortext_t*);


#define MR_SUMMARY_CHARACTERS 160 /**< @private in practice, the user additionally cuts the string himself pixel-accurate */
void            mrpoortext_fill      (mrpoortext_t*, const mrmsg_t*, const mrchat_t*, const mrcontact_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRPOORTEXT_H__ */
