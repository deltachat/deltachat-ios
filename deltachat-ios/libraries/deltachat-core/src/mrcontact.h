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


#ifndef __MRCONTACT_H__
#define __MRCONTACT_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct mrsqlite3_t mrsqlite3_t;


/**
 * The contact object.
 * The contact object is not updated.  If you want an update, you have to recreate
 * the object.
 */
typedef struct mrcontact_t
{
	#define         MR_CONTACT_ID_SELF         1
	#define         MR_CONTACT_ID_SYSTEM       2
	#define         MR_CONTACT_ID_LAST_SPECIAL 9
	uint32_t        m_id;

	char*           m_name;     /* may be NULL or empty, this name should not be spreaded as it may be "Daddy" and so on; initially set to m_authname */
	char*           m_authname; /* may be NULL or empty, this is the name authorized by the sender, only this name may be speaded to others, eg. in To:-lists; for displaying in the app, use m_name */
	char*           m_addr;     /* may be NULL or empty */
	int             m_origin;
	int             m_blocked;
} mrcontact_t;


mrcontact_t* mrcontact_new                    (); /* the returned pointer is ref'd and must be unref'd after usage */
void         mrcontact_empty                  (mrcontact_t*);
void         mrcontact_unref                  (mrcontact_t*);
int          mrcontact_load_from_db__         (mrcontact_t*, mrsqlite3_t*, uint32_t contact_id);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCONTACT_H__ */
