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
 * An object representing a single contact in memory.
 * The contact object is not updated.  If you want an update, you have to recreate
 * the object.
 */
typedef struct mrcontact_t
{
	/**
	 * The contact ID
	 *
	 * Special message IDs:
	 * - MR_CONTACT_ID_SELF (1) - this is the owner of the mailbox with the email-address set by mrmailbox_set_config() using "addr".
	 *
	 * Normal contact IDs are larger than these special ones (larger than MR_CONTACT_ID_LAST_SPECIAL).
	 */
	uint32_t        m_id;
	#define         MR_CONTACT_ID_SELF         1
	#define         MR_CONTACT_ID_LAST_SPECIAL 9

	char*           m_name;     /**< may be NULL or empty, this name should not be spreaded as it may be "Daddy" and so on; initially set to m_authname */
	char*           m_authname; /**< may be NULL or empty, this is the name authorized by the sender, only this name may be speaded to others, eg. in To:-lists; for displaying in the app, use m_name */
	char*           m_addr;     /**< may be NULL or empty */
	int             m_blocked;  /**< Blocked state. 1=contact is blocked, 0=contact is not blocked. */

	/** @privatesection */
	int             m_origin;   /**< The original of the contact. One of the MR_ORIGIN_* constants */
} mrcontact_t;


mrcontact_t* mrcontact_new                    (); /* the returned pointer is ref'd and must be unref'd after usage */
void         mrcontact_empty                  (mrcontact_t*);
void         mrcontact_unref                  (mrcontact_t*);


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


/* library-internal */
char*        mrcontact_get_first_name         (const char* full_name);
void         mrcontact_normalize_name         (char* full_name);
int          mrcontact_load_from_db__         (mrcontact_t*, mrsqlite3_t*, uint32_t contact_id);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCONTACT_H__ */
