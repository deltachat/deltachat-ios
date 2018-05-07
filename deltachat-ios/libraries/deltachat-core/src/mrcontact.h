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


/**
 * @class mrcontact_t
 *
 * An object representing a single contact in memory.
 * The contact object is not updated.  If you want an update, you have to recreate
 * the object.
 */
typedef struct _mrcontact mrcontact_t;

#define         MR_CONTACT_ID_SELF         1
#define         MR_CONTACT_ID_DEVICE       2
#define         MR_CONTACT_ID_LAST_SPECIAL 9


mrcontact_t* mrcontact_new                    (mrmailbox_t*); /* the returned pointer is ref'd and must be unref'd after usage */
void         mrcontact_empty                  (mrcontact_t*);
void         mrcontact_unref                  (mrcontact_t*);

uint32_t     mrcontact_get_id                 (const mrcontact_t*);
char*        mrcontact_get_addr               (const mrcontact_t*);
char*        mrcontact_get_name               (const mrcontact_t*);
char*        mrcontact_get_display_name       (const mrcontact_t*);
char*        mrcontact_get_name_n_addr        (const mrcontact_t*);
char*        mrcontact_get_first_name         (const mrcontact_t*);
int          mrcontact_is_blocked             (const mrcontact_t*);
int          mrcontact_is_verified            (const mrcontact_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCONTACT_H__ */
