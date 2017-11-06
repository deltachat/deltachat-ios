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
 * File:    mrcontact.h
 * Purpose: mrcontact_t represents a single contact - if in doubt a contact is
 *          every (email-)adresses the user has _send_ a mail to (only receiving
 *          is not sufficient).
 *          For the future, we plan to use the systems address books and/or a
 *          CardDAV server, too.
 *
 ******************************************************************************/


#ifndef __MRCONTACT_H__
#define __MRCONTACT_H__
#ifdef __cplusplus
extern "C" {
#endif


/* specical contact IDs */
#define MR_CONTACT_ID_SELF         1
#define MR_CONTACT_ID_SYSTEM       2
#define MR_CONTACT_ID_LAST_SPECIAL 9


/* contact origins */
#define MR_ORIGIN_UNSET                         0
#define MR_ORIGIN_INCOMING_UNKNOWN_FROM      0x10 /* From: of incoming messages of unknown sender */
#define MR_ORIGIN_INCOMING_UNKNOWN_CC        0x20 /* Cc: of incoming messages of unknown sender */
#define MR_ORIGIN_INCOMING_UNKNOWN_TO        0x40 /* To: of incoming messages of unknown sender */
#define MR_ORIGIN_INCOMING_REPLY_TO         0x100 /* Reply-To: of incoming message of known sender */
#define MR_ORIGIN_INCOMING_CC               0x200 /* Cc: of incoming message of known sender */
#define MR_ORIGIN_INCOMING_TO               0x400 /* additional To:'s of incoming message of known sender */
#define MR_ORIGIN_CREATE_CHAT               0x800 /* a chat was manually created for this user, but no message yet sent */
#define MR_ORIGIN_OUTGOING_BCC             0x1000 /* message send by us */
#define MR_ORIGIN_OUTGOING_CC              0x2000 /* message send by us */
#define MR_ORIGIN_OUTGOING_TO              0x4000 /* message send by us */
#define MR_ORIGIN_INTERNAL                0x40000 /* internal use */
#define MR_ORIGIN_ADRESS_BOOK             0x80000 /* address is in our address book */
#define MR_ORIGIN_MANUALLY_CREATED       0x100000 /* contact added by mrmailbox_create_contact() */

#define MR_ORIGIN_MIN_CONTACT_LIST    (MR_ORIGIN_INCOMING_REPLY_TO) /* contacts with at least this origin value are shown in the contact list */
#define MR_ORIGIN_MIN_VERIFIED        (MR_ORIGIN_INCOMING_REPLY_TO) /* contacts with at least this origin value are verified and known not to be spam */
#define MR_ORIGIN_MIN_START_NEW_NCHAT (0x7FFFFFFF)                  /* contacts with at least this origin value start a new "normal" chat, defaults to off */


typedef struct mrcontact_t
{
	uint32_t            m_magic;
	uint32_t            m_id;
	char*               m_name;    /* may be NULL or empty, this name should not be spreaded as it may be "Daddy" and so on; initially set to m_authname */
	char*               m_authname;/* may be NULL or empty, this is the name authorized by the sender, only this name may be speaded to others, eg. in To:-lists; for displaying in the app, use m_name */
	char*               m_addr;    /* may be NULL or empty */
	int                 m_origin;
	int                 m_blocked;
} mrcontact_t;


mrcontact_t* mrcontact_new             (); /* the returned pointer is ref'd and must be unref'd after usage */
void         mrcontact_unref           (mrcontact_t*);
void         mrcontact_empty           (mrcontact_t*);


/*** library-private **********************************************************/

int          mrcontact_load_from_db__         (mrcontact_t*, mrsqlite3_t*, uint32_t id);
size_t       mrmailbox_get_real_contact_cnt__ (mrmailbox_t*);
uint32_t     mrmailbox_add_or_lookup_contact__(mrmailbox_t*, const char* display_name /*can be NULL*/, const char* addr_spec, int origin, int* sth_modified);
int          mrmailbox_get_contact_origin__   (mrmailbox_t*, uint32_t id, int* ret_blocked);
int          mrmailbox_is_contact_blocked__   (mrmailbox_t*, uint32_t id);
int          mrmailbox_real_contact_exists__  (mrmailbox_t*, uint32_t id);
int          mrmailbox_contact_addr_equals__  (mrmailbox_t*, uint32_t contact_id, const char* other_addr);
void         mrmailbox_scaleup_contact_origin__(mrmailbox_t*, uint32_t contact_id, int origin);
void         mr_normalize_name                (char* full_name);
char*        mr_get_first_name                (const char* full_name); /* returns part before the space or after a comma; the result must be free()'d */


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCONTACT_H__ */

