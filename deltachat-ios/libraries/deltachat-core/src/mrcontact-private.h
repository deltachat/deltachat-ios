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


#ifndef __MRCONTACT_PRIVATE_H__
#define __MRCONTACT_PRIVATE_H__
#ifdef __cplusplus
extern "C" {
#endif


typedef struct mrsqlite3_t mrsqlite3_t;


/** the structure behind mrcontact_t */
struct _mrcontact
{
	/** @privatesection */

	uint32_t        m_magic;

	/**
	 * The contact ID.
	 *
	 * Special message IDs:
	 * - MR_CONTACT_ID_SELF (1) - this is the owner of the mailbox with the email-address set by mrmailbox_set_config() using "addr".
	 *
	 * Normal contact IDs are larger than these special ones (larger than MR_CONTACT_ID_LAST_SPECIAL).
	 */
	uint32_t        m_id;
	char*           m_name;     /**< Contact name.  It is recommended to use mrcontact_get_name(), mrcontact_get_display_name() or mrcontact_get_name_n_addr() to access this field. May be NULL or empty, initially set to #m_authname. */
	char*           m_authname; /**< Name authorized by the contact himself. Only this name may be spread to others, e.g. in To:-lists. May be NULL or empty. It is recommended to use mrcontact_get_name(),  mrcontact_get_display_name() or mrcontact_get_name_n_addr() to access this field. */
	char*           m_addr;     /**< E-Mail-Address of the contact. It is recommended to use mrcontact_get_addr() to access this field. May be NULL. */
	int             m_blocked;  /**< Blocked state. Use mrcontact_is_blocked() to access this field. */
	int             m_origin;   /**< The origin/source of the contact. One of the MR_ORIGIN_* constants. */
};


/* library-internal */
#define MR_ORIGIN_INCOMING_UNKNOWN_FROM      0x10 /* From: of incoming messages of unknown sender */
#define MR_ORIGIN_INCOMING_UNKNOWN_CC        0x20 /* Cc: of incoming messages of unknown sender */
#define MR_ORIGIN_INCOMING_UNKNOWN_TO        0x40 /* To: of incoming messages of unknown sender */
#define MR_ORIGIN_UNHANDLED_QR_SCAN          0x80 /* address scanned but not verified */
#define MR_ORIGIN_INCOMING_REPLY_TO         0x100 /* Reply-To: of incoming message of known sender */
#define MR_ORIGIN_INCOMING_CC               0x200 /* Cc: of incoming message of known sender */
#define MR_ORIGIN_INCOMING_TO               0x400 /* additional To:'s of incoming message of known sender */
#define MR_ORIGIN_CREATE_CHAT               0x800 /* a chat was manually created for this user, but no message yet sent */
#define MR_ORIGIN_OUTGOING_BCC             0x1000 /* message sent by us */
#define MR_ORIGIN_OUTGOING_CC              0x2000 /* message sent by us */
#define MR_ORIGIN_OUTGOING_TO              0x4000 /* message sent by us */
#define MR_ORIGIN_INTERNAL                0x40000 /* internal use */
#define MR_ORIGIN_ADRESS_BOOK             0x80000 /* address is in our address book */
#define MR_ORIGIN_MANUALLY_CREATED       0x100000 /* contact added by mrmailbox_create_contact() */
#define MR_ORIGIN_SECURE_INVITED        0x1000000 /* set on Alice's side for contacts like Bob that have scanned the QR code offered by her */
#define MR_ORIGIN_SECURE_JOINED         0x2000000 /* set on Bob's side for contacts scanned and verified from a QR code */

#define MR_ORIGIN_MIN_CONTACT_LIST    (MR_ORIGIN_INCOMING_REPLY_TO) /* contacts with at least this origin value are shown in the contact list */
#define MR_ORIGIN_MIN_VERIFIED        (MR_ORIGIN_INCOMING_REPLY_TO) /* contacts with at least this origin value are verified and known not to be spam */
#define MR_ORIGIN_MIN_START_NEW_NCHAT (0x7FFFFFFF)                  /* contacts with at least this origin value start a new "normal" chat, defaults to off */

int          mrcontact_load_from_db__         (mrcontact_t*, mrsqlite3_t*, uint32_t contact_id);
void         mr_normalize_name                (char* full_name);
char*        mr_normalize_addr                (const char* email_addr);
char*        mr_get_first_name                (const char* full_name);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRCONTACT_PRIVATE_H__ */
