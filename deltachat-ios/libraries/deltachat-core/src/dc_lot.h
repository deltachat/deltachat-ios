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


#ifndef __DC_LOT_H__
#define __DC_LOT_H__
#ifdef __cplusplus
extern "C" {
#endif


/** Structure behind dc_lot_t */
struct _dc_lot
{
	/** @privatesection */
	uint32_t        magic;           /**< The magic is used to avoid passing structures of different types. */
	int             text1_meaning;   /**< The meaning of this value is defined by the creator of the object. 0 if not applicable. */
	char*           text1;           /**< The meaning of this string is defined by the creator of the object. The string is freed with dc_lot_unref(). NULL if not applicable. */
	char*           text2;           /**< The meaning of this string is defined by the creator of the object. The string is freed with dc_lot_unref(). NULL if not applicable. */
	time_t          timestamp;       /**< The meaning of this value is defined by the creator of the object. 0 if not applicable. */
	int             state;           /**< The meaning of this value is defined by the creator of the object. 0 if not applicable. */

	uint32_t        id;              /**< The meaning of this value is defined by the creator of the object. 0 if not applicable. */

	char*           fingerprint;     /**< used for qr code scanning only */
	char*           invitenumber;    /**< used for qr code scanning only */
	char*           auth;            /**< used for qr code scanning only */
};


/* library-internal */
#define DC_SUMMARY_CHARACTERS 160 /* in practice, the user additionally cuts the string himself pixel-accurate */
void            dc_lot_fill      (dc_lot_t*, const dc_msg_t*, const dc_chat_t*, const dc_contact_t*, dc_context_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_LOT_H__ */
