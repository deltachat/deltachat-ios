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


#ifndef __MRLOT_PRIVATE_H__
#define __MRLOT_PRIVATE_H__
#ifdef __cplusplus
extern "C" {
#endif


/** Structure behind mrlot_t */
struct _mrlot
{
	/** @privatesection */
	uint32_t        m_magic;           /**< The magic is used to avoid passing structures of different types. */
	int             m_text1_meaning;   /**< The meaning of this value is defined by the creator of the object. 0 if not applicable. */
	char*           m_text1;           /**< The meaning of this string is defined by the creator of the object. The string is freed with mrlot_unref(). NULL if not applicable. */
	char*           m_text2;           /**< The meaning of this string is defined by the creator of the object. The string is freed with mrlot_unref(). NULL if not applicable. */
	time_t          m_timestamp;       /**< The meaning of this value is defined by the creator of the object. 0 if not applicable. */
	int             m_state;           /**< The meaning of this value is defined by the creator of the object. 0 if not applicable. */

	uint32_t        m_id;              /**< The meaning of this value is defined by the creator of the object. 0 if not applicable. */

	char*           m_fingerprint;     /**< used for qr code scanning only */
	char*           m_invitenumber;    /**< used for qr code scanning only */
	char*           m_auth;            /**< used for qr code scanning only */
};


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRLOT_PRIVATE_H__ */
