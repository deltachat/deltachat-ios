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


#ifndef __MRDEHTML_H__
#define __MRDEHTML_H__
#ifdef __cplusplus
extern "C" {
#endif


/*** library-private **********************************************************/

char* mr_dehtml(char* buf_terminated); /* mr_dehtml() returns way too many lineends; however, an optimisation on this issue is not needed as the lineends are typically remove in further processing by the caller */


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRDEHTML_H__ */

