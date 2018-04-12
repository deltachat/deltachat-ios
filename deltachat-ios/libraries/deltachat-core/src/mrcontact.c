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


#include "mrmailbox_internal.h"
#include "mrcontact.h"
#include "mrapeerstate.h"

#define MR_CONTACT_MAGIC 0x0c047ac7


/**
 * Create a new contact object in memory.
 * Typically the user does not call this function directly but gets contact
 * objects using mrmailbox_get_contact().
 *
 * @private @memberof mrcontact_t
 *
 * @return The contact object. Must be freed using mrcontact_unref() when done.
 */
mrcontact_t* mrcontact_new(mrmailbox_t* mailbox)
{
	mrcontact_t* ths = NULL;

	if( (ths=calloc(1, sizeof(mrcontact_t)))==NULL ) {
		exit(19); /* cannot allocate little memory, unrecoverable error */
	}

	ths->m_magic   = MR_CONTACT_MAGIC;
	ths->m_mailbox = mailbox;

	return ths;
}


/**
 * Free a contact object.
 *
 * @memberof mrcontact_t
 *
 * @param contact The contact object as created eg. by mrmailbox_get_contact().
 *
 * @return None.
 */
void mrcontact_unref(mrcontact_t* contact)
{
	if( contact==NULL || contact->m_magic != MR_CONTACT_MAGIC ) {
		return;
	}

	mrcontact_empty(contact);
	contact->m_magic = 0;
	free(contact);
}


/**
 * Empty a contact object.
 * Typically not needed by the user of the library. To free a contact object,
 * use mrcontact_unref().
 *
 * @private @memberof mrcontact_t
 *
 * @param contact The contact object to free.
 *
 * @return None.
 */
void mrcontact_empty(mrcontact_t* contact)
{
	if( contact == NULL || contact->m_magic != MR_CONTACT_MAGIC ) {
		return;
	}

	contact->m_id = 0;

	free(contact->m_name); /* it is safe to call free(NULL) */
	contact->m_name = NULL;

	free(contact->m_authname);
	contact->m_authname = NULL;

	free(contact->m_addr);
	contact->m_addr = NULL;

	contact->m_origin = 0;
	contact->m_blocked = 0;
}


/*******************************************************************************
 * Getters
 ******************************************************************************/


/**
 * Get the ID of the contact.
 *
 * @memberof mrcontact_t
 *
 * @param contact The contact object.
 *
 * @return the ID of the contact, 0 on errors.
 */
uint32_t mrcontact_get_id(mrcontact_t* contact)
{
	if( contact == NULL || contact->m_magic != MR_CONTACT_MAGIC ) {
		return 0;
	}
	return contact->m_id;
}


/**
 * Get email address.  The email address is always set for a contact.
 *
 * @memberof mrcontact_t
 *
 * @param contact The contact object.
 *
 * @return String with the email address, must be free()'d. Never returns NULL.
 */
char* mrcontact_get_addr(mrcontact_t* contact)
{
	if( contact == NULL || contact->m_magic != MR_CONTACT_MAGIC ) {
		return safe_strdup(NULL);
	}

	return safe_strdup(contact->m_addr);
}


/**
 * Get name. This is the name as defined the the contact himself or
 * modified by the user.  May be an empty string.
 *
 * This name is typically used in a form where the user can edit the name of a contact.
 * This name must not be spreaded via mail (To:, CC: ...) as it as it may be sth. like "Daddy".
 * To get a fine name to display in lists etc., use mrcontact_get_display_name() or mrcontact_get_name_n_addr().
 *
 * @memberof mrcontact_t
 *
 * @param contact The contact object.
 *
 * @return String with the name to display, must be free()'d. Empty string if unset, never returns NULL.
 */
char* mrcontact_get_name(mrcontact_t* contact)
{
	if( contact == NULL || contact->m_magic != MR_CONTACT_MAGIC ) {
		return safe_strdup(NULL);
	}

	return safe_strdup(contact->m_name);
}


/**
 * Get display name. This is the name as defined the the contact himself,
 * modified by the user or, if both are unset, the email address.
 *
 * This name is typically used in lists and must not be speaded via mail (To:, CC: ...).
 * To get the name editable in a formular, use mrcontact_get_edit_name().
 *
 * @memberof mrcontact_t
 *
 * @param contact The contact object.
 *
 * @return String with the name to display, must be free()'d. Never returns NULL.
 */
char* mrcontact_get_display_name(mrcontact_t* contact)
{
	if( contact == NULL || contact->m_magic != MR_CONTACT_MAGIC ) {
		return safe_strdup(NULL);
	}

	if( contact->m_name && contact->m_name[0] ) {
		return safe_strdup(contact->m_name);
	}

	return safe_strdup(contact->m_addr);
}


/**
 * Get a summary of name and address.
 *
 * The returned string is either "Name (email@domain.com)" or just
 * "email@domain.com" if the name is unset.
 *
 * The summary is typically used when asking the user something about the contact.
 * The attached email address makes the question unique, eg. "Chat with Alan Miller (am@uniquedomain.com)?"
 *
 * The summary must not be spreaded via mail (To:, CC: ...) as it as it may contain sth. like "Daddy".
 *
 * @memberof mrcontact_t
 *
 * @param contact The contact object.
 *
 * @return Summary string, must be free()'d. Never returns NULL.
 */
char* mrcontact_get_name_n_addr(mrcontact_t* contact)
{
	if( contact == NULL || contact->m_magic != MR_CONTACT_MAGIC ) {
		return safe_strdup(NULL);
	}

	if( contact->m_name && contact->m_name[0] ) {
		return mr_mprintf("%s (%s)", contact->m_name, contact->m_addr);
	}

	return safe_strdup(contact->m_addr);
}


/**
 * Check if a contact is blocked.
 *
 * To block or unblock a contact, use mrmailbox_block_contact().
 *
 * @memberof mrcontact_t
 *
 * @param contact The contact object.
 *
 * @return 1=contact is blocked, 0=contact is not blocked.
 */
int mrcontact_is_blocked(mrcontact_t* contact)
{
	if( contact == NULL || contact->m_magic != MR_CONTACT_MAGIC ) {
		return 0;
	}
	return contact->m_blocked;
}


/**
 * Check if a contact was verified eg. by a secure-join QR code scan
 * and if the key has not changed since this verification.
 *
 * The UI may draw a checkbox or sth. like that beside verified contacts.
 *
 * @memberof mrcontact_t
 *
 * @param contact The contact object.
 *
 * @return 1=contact is verified, 0=contact is not verified.
 */
int mrcontact_is_verified(mrcontact_t* contact)
{
	// if you change the algorithm here, you may also want to adapt mrchat_is_verfied()

	int             contact_verified = 0;
	mrapeerstate_t* peerstate        = mrapeerstate_new(contact->m_mailbox);

	if( contact == NULL || contact->m_magic != MR_CONTACT_MAGIC ) {
		goto cleanup;
	}

	if( contact->m_id == MR_CONTACT_ID_SELF ) {
		contact_verified = 1;
		goto cleanup; // we're always sort of secured-verified as we could verify the key on this device any time with the key on this device
	}

	if( !mrapeerstate_load_by_addr__(peerstate, contact->m_mailbox->m_sql, contact->m_addr) ) {
		goto cleanup;
	}

	if( peerstate->m_verified==0 || peerstate->m_prefer_encrypt!=MRA_PE_MUTUAL ) {
		goto cleanup;
	}

	contact_verified = 1;

cleanup:
	mrapeerstate_unref(peerstate);
	return contact_verified;
}


/**
 * Get the first name.
 *
 * In a string, get the part before the first space.
 * If there is no space in the string, the whole string is returned.
 *
 * @private @memberof mrcontact_t
 *
 * @param full_name Full name of the contact.
 *
 * @return String with the first name, must be free()'d after usage.
 */
char* mr_get_first_name(const char* full_name)
{
	char* first_name = safe_strdup(full_name);
	char* p1 = strchr(first_name, ' ');
	if( p1 ) {
		*p1 = 0;
		mr_rtrim(first_name);
		if( first_name[0]  == 0 ) { /*empty result? use the original string in this case */
			free(first_name);
			first_name = safe_strdup(full_name);
		}
	}

	return first_name;
}


/*******************************************************************************
 * Misc.
 ******************************************************************************/


/**
 * Normalize a name in-place.
 *
 * - Remove quotes (come from some bad MUA implementations)
 * - Convert names as "Petersen, Björn" to "Björn Petersen"
 * - Trims the resulting string
 *
 * Typically, this function is not needed as it is called implicitly by mrmailbox_add_address_book()
 *
 * @private @memberof mrcontact_t
 *
 * @param full_name Buffer with the name, is modified during processing; the
 *     resulting string may be shorter but never longer.
 *
 * @return None. But the given buffer may be modified.
 */
void mr_normalize_name(char* full_name)
{
	if( full_name == NULL ) {
		return; /* error, however, this can be treated as documented behaviour */
	}

	mr_trim(full_name); /* remove spaces around possible quotes */
	int len = strlen(full_name);
	if( len > 0 ) {
		char firstchar = full_name[0], lastchar = full_name[len-1];
		if( (firstchar=='\'' && lastchar=='\'')
		 || (firstchar=='"'  && lastchar=='"' )
		 || (firstchar=='<'  && lastchar=='>' ) ) {
			full_name[0]     = ' ';
			full_name[len-1] = ' '; /* the string is trimmed later again */
		}
	}

	char* p1 = strchr(full_name, ',');
	if( p1 ) {
		*p1 = 0;
		char* last_name  = safe_strdup(full_name);
		char* first_name = safe_strdup(p1+1);
		mr_trim(last_name);
		mr_trim(first_name);
		strcpy(full_name, first_name);
		strcat(full_name, " ");
		strcat(full_name, last_name);
		free(last_name);
		free(first_name);
	}
	else {
		mr_trim(full_name);
	}
}


/**
 * Normalize an email address.
 *
 * Normalization includes:
 * - removing `mailto:` prefix
 *
 * Not sure if we should also unifiy international characters before the @,
 * see also https://autocrypt.readthedocs.io/en/latest/address-canonicalization.html
 *
 * @private @memberof mrcontact_t
 *
 * @param email_addr__ The email address to normalize.
 *
 * @return The normalized email address, must be free()'d. NULL is never returned.
 */
char* mr_normalize_addr(const char* email_addr__)
{
	char* addr = safe_strdup(email_addr__);
	mr_trim(addr);
	if( strncmp(addr, "mailto:", 7)==0 ) {
		char* old = addr;
		addr = safe_strdup(&old[7]);
		free(old);
		mr_trim(addr);
	}
	return addr;
}


/**
 * Library-internal.
 *
 * Calling this function is not thread-safe, locking is up to the caller.
 *
 * @private @memberof mrcontact_t
 */
int mrcontact_load_from_db__(mrcontact_t* ths, mrsqlite3_t* sql, uint32_t contact_id)
{
	int           success = 0;
	sqlite3_stmt* stmt;

	if( ths == NULL || ths->m_magic != MR_CONTACT_MAGIC || sql == NULL ) {
		return 0;
	}

	mrcontact_empty(ths);

	if( contact_id == MR_CONTACT_ID_SELF )
	{
		ths->m_id   = contact_id;
		ths->m_name = mrstock_str(MR_STR_SELF);
		ths->m_addr = mrsqlite3_get_config__(sql, "configured_addr", "");
	}
	else
	{
		stmt = mrsqlite3_predefine__(sql, SELECT_naob_FROM_contacts_i,
			"SELECT c.name, c.addr, c.origin, c.blocked, c.authname "
			" FROM contacts c "
			" WHERE c.id=?;");
		sqlite3_bind_int(stmt, 1, contact_id);
		if( sqlite3_step(stmt) != SQLITE_ROW ) {
			goto cleanup;
		}

		ths->m_id               = contact_id;
		ths->m_name             = safe_strdup((char*)sqlite3_column_text (stmt, 0));
		ths->m_addr             = safe_strdup((char*)sqlite3_column_text (stmt, 1));
		ths->m_origin           =                    sqlite3_column_int  (stmt, 2);
		ths->m_blocked          =                    sqlite3_column_int  (stmt, 3);
		ths->m_authname         = safe_strdup((char*)sqlite3_column_text (stmt, 4));
	}

	success = 1;

cleanup:
	return success;
}
