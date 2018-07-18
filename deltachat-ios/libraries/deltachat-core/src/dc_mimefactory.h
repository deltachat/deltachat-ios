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


#ifndef __DC_MIMEFACTORY_H__
#define __DC_MIMEFACTORY_H__
#ifdef __cplusplus
extern "C" {
#endif



#define DC_CMD_GROUPNAME_CHANGED           2
#define DC_CMD_GROUPIMAGE_CHANGED          3
#define DC_CMD_MEMBER_ADDED_TO_GROUP       4
#define DC_CMD_MEMBER_REMOVED_FROM_GROUP   5
#define DC_CMD_AUTOCRYPT_SETUP_MESSAGE     6
#define DC_CMD_SECUREJOIN_MESSAGE          7


typedef enum {
	DC_MF_NOTHING_LOADED = 0,
	DC_MF_MSG_LOADED,
	DC_MF_MDN_LOADED
} dc_mimefactory_loaded_t;


/**
 * Library-internal.
 */
typedef struct dc_mimefactory_t {

	/** @privatesection */

	/* in: parameters, set eg. by dc_mimefactory_load_msg() */
	char*         from_addr;
	char*         from_displayname;
	char*         selfstatus;
	clist*        recipients_names;
	clist*        recipients_addr;
	time_t        timestamp;
	char*         rfc724_mid;

	/* what is loaded? */
	dc_mimefactory_loaded_t loaded;

	dc_msg_t*     msg;
	dc_chat_t*    chat;
	int           increation;
	char*         predecessor;
	char*         references;
	int           req_mdn;

	// out: after a call to dc_mimefactory_render(), here's the data or the error
	MMAPString*   out;
	int           out_encrypted;
	char*         error;

	/* private */
	dc_context_t* context;

} dc_mimefactory_t;


void        dc_mimefactory_init              (dc_mimefactory_t*, dc_context_t*);
void        dc_mimefactory_empty             (dc_mimefactory_t*);
int         dc_mimefactory_load_msg          (dc_mimefactory_t*, uint32_t msg_id);
int         dc_mimefactory_load_mdn          (dc_mimefactory_t*, uint32_t msg_id);
int         dc_mimefactory_render            (dc_mimefactory_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_MIMEFACTORY_H__ */

