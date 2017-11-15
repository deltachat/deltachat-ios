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


#ifndef __MRMIMEFACTORY_H__
#define __MRMIMEFACTORY_H__
#ifdef __cplusplus
extern "C" {
#endif




typedef struct mrmsg_t mrmsg_t;
typedef struct mrchat_t mrchat_t;
typedef struct mrmailbox_t mrmailbox_t;


#define MR_SYSTEM_GROUPNAME_CHANGED           2
#define MR_SYSTEM_GROUPIMAGE_CHANGED          3
#define MR_SYSTEM_MEMBER_ADDED_TO_GROUP       4
#define MR_SYSTEM_MEMBER_REMOVED_FROM_GROUP   5


typedef enum {
	MR_MF_NOTHING_LOADED = 0,
	MR_MF_MSG_LOADED,
	MR_MF_MDN_LOADED
} mrmimefactory_loaded_t;


/**
 * Library-internal.
 */
typedef struct mrmimefactory_t {

	/** @privatesection */

	/* in: parameters, set eg. by mrmimefactory_load_msg() */
	char*        m_from_addr;
	char*        m_from_displayname;
	char*        m_selfstatus;
	clist*       m_recipients_names;
	clist*       m_recipients_addr;
	time_t       m_timestamp;
	char*        m_rfc724_mid;

	/* what is loaded? */
	mrmimefactory_loaded_t m_loaded;

	mrmsg_t*     m_msg;
	mrchat_t*    m_chat;
	int          m_increation;
	char*        m_predecessor;
	char*        m_references;
	int          m_req_mdn;

	/* out: after a successfull mrmimefactory_create_mime(), here's the data */
	MMAPString*  m_out;
	int          m_out_encrypted;

	/* private */
	mrmailbox_t* m_mailbox;

} mrmimefactory_t;


void        mrmimefactory_init              (mrmimefactory_t*, mrmailbox_t*);
void        mrmimefactory_empty             (mrmimefactory_t*);
int         mrmimefactory_load_msg          (mrmimefactory_t*, uint32_t msg_id);
int         mrmimefactory_load_mdn          (mrmimefactory_t*, uint32_t msg_id);
int         mrmimefactory_render            (mrmimefactory_t*, int encrypt_to_self);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRMIMEFACTORY_H__ */

