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


#include "dc_context.h"
#include "dc_contact.h"
#include "dc_apeerstate.h"
#include "dc_loginparam.h"
#include "dc_pgp.h"


#define DC_CONTACT_MAGIC 0x0c047ac7


/**
 * Create a new contact object in memory.
 * Typically the user does not call this function directly but gets contact
 * objects using dc_get_contact().
 *
 * @private @memberof dc_contact_t
 * @return The contact object. Must be freed using dc_contact_unref() when done.
 */
dc_contact_t* dc_contact_new(dc_context_t* context)
{
	dc_contact_t* contact = NULL;

	if ((contact=calloc(1, sizeof(dc_contact_t)))==NULL) {
		exit(19); /* cannot allocate little memory, unrecoverable error */
	}

	contact->magic   = DC_CONTACT_MAGIC;
	contact->context = context;

	return contact;
}


/**
 * Free a contact object.
 *
 * @memberof dc_contact_t
 * @param contact The contact object as created eg. by dc_get_contact().
 * @return None.
 */
void dc_contact_unref(dc_contact_t* contact)
{
	if (contact==NULL || contact->magic!=DC_CONTACT_MAGIC) {
		return;
	}

	dc_contact_empty(contact);
	contact->magic = 0;
	free(contact);
}


/**
 * Empty a contact object.
 * Typically not needed by the user of the library. To free a contact object,
 * use dc_contact_unref().
 *
 * @private @memberof dc_contact_t
 * @param contact The contact object to free.
 * @return None.
 */
void dc_contact_empty(dc_contact_t* contact)
{
	if (contact==NULL || contact->magic!=DC_CONTACT_MAGIC) {
		return;
	}

	contact->id = 0;

	free(contact->name); /* it is safe to call free(NULL) */
	contact->name = NULL;

	free(contact->authname);
	contact->authname = NULL;

	free(contact->addr);
	contact->addr = NULL;

	contact->origin = 0;
	contact->blocked = 0;
}


/**
 * Get the ID of the contact.
 *
 * @memberof dc_contact_t
 * @param contact The contact object.
 * @return the ID of the contact, 0 on errors.
 */
uint32_t dc_contact_get_id(const dc_contact_t* contact)
{
	if (contact==NULL || contact->magic!=DC_CONTACT_MAGIC) {
		return 0;
	}
	return contact->id;
}


/**
 * Get email address.  The email address is always set for a contact.
 *
 * @memberof dc_contact_t
 * @param contact The contact object.
 * @return String with the email address, must be free()'d. Never returns NULL.
 */
char* dc_contact_get_addr(const dc_contact_t* contact)
{
	if (contact==NULL || contact->magic!=DC_CONTACT_MAGIC) {
		return dc_strdup(NULL);
	}

	return dc_strdup(contact->addr);
}


/**
 * Get name. This is the name as defined by the contact himself or
 * modified by the user.  May be an empty string.
 *
 * This name is typically used in a form where the user can edit the name of a contact.
 * To get a fine name to display in lists etc., use dc_contact_get_display_name() or dc_contact_get_name_n_addr().
 *
 * @memberof dc_contact_t
 * @param contact The contact object.
 * @return String with the name to display, must be free()'d. Empty string if unset, never returns NULL.
 */
char* dc_contact_get_name(const dc_contact_t* contact)
{
	if (contact==NULL || contact->magic!=DC_CONTACT_MAGIC) {
		return dc_strdup(NULL);
	}

	return dc_strdup(contact->name);
}


/**
 * Get display name. This is the name as defined by the contact himself,
 * modified by the user or, if both are unset, the email address.
 *
 * This name is typically used in lists.
 * To get the name editable in a formular, use dc_contact_get_name().
 *
 * @memberof dc_contact_t
 * @param contact The contact object.
 * @return String with the name to display, must be free()'d. Never returns NULL.
 */
char* dc_contact_get_display_name(const dc_contact_t* contact)
{
	if (contact==NULL || contact->magic!=DC_CONTACT_MAGIC) {
		return dc_strdup(NULL);
	}

	if (contact->name && contact->name[0]) {
		return dc_strdup(contact->name);
	}

	return dc_strdup(contact->addr);
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
 * @memberof dc_contact_t
 * @param contact The contact object.
 * @return Summary string, must be free()'d. Never returns NULL.
 */
char* dc_contact_get_name_n_addr(const dc_contact_t* contact)
{
	if (contact==NULL || contact->magic!=DC_CONTACT_MAGIC) {
		return dc_strdup(NULL);
	}

	if (contact->name && contact->name[0]) {
		return dc_mprintf("%s (%s)", contact->name, contact->addr);
	}

	return dc_strdup(contact->addr);
}


/**
 * Get the part of the name before the first space. In most languages, this seems to be
 * the prename. If there is no space, the full display name is returned.
 * If the display name is not set, the e-mail address is returned.
 *
 * @memberof dc_contact_t
 * @param contact The contact object.
 * @return String with the name to display, must be free()'d. Never returns NULL.
 */
char* dc_contact_get_first_name(const dc_contact_t* contact)
{
	if (contact==NULL || contact->magic!=DC_CONTACT_MAGIC) {
		return dc_strdup(NULL);
	}

	if (contact->name && contact->name[0]) {
		return dc_get_first_name(contact->name);
	}

	return dc_strdup(contact->addr);
}


/**
 * Check if a contact is blocked.
 *
 * To block or unblock a contact, use dc_block_contact().
 *
 * @memberof dc_contact_t
 * @param contact The contact object.
 * @return 1=contact is blocked, 0=contact is not blocked.
 */
int dc_contact_is_blocked(const dc_contact_t* contact)
{
	if (contact==NULL || contact->magic!=DC_CONTACT_MAGIC) {
		return 0;
	}
	return contact->blocked;
}


/**
 * Same as dc_contact_is_verified() but allows speeding up things
 * by adding the peerstate belonging to the contact.
 * If you do not have the peerstate available, it is loaded automatically.
 *
 * @private @memberof dc_context_t
 */
int dc_contact_is_verified_ex(dc_contact_t* contact, const dc_apeerstate_t* peerstate)
{
	int              contact_verified = DC_NOT_VERIFIED;
	dc_apeerstate_t* peerstate_to_delete = NULL;

	if (contact==NULL || contact->magic!=DC_CONTACT_MAGIC) {
		goto cleanup;
	}

	if (contact->id==DC_CONTACT_ID_SELF) {
		contact_verified = DC_BIDIRECT_VERIFIED;
		goto cleanup; // we're always sort of secured-verified as we could verify the key on this device any time with the key on this device
	}

	if (peerstate==NULL) {
		peerstate_to_delete = dc_apeerstate_new(contact->context);
		if (!dc_apeerstate_load_by_addr(peerstate_to_delete, contact->context->sql, contact->addr)) {
			goto cleanup;
		}
		peerstate = peerstate_to_delete;
	}

	contact_verified = peerstate->verified_key? DC_BIDIRECT_VERIFIED : 0;

cleanup:
	dc_apeerstate_unref(peerstate_to_delete);
	return contact_verified;
}


/**
 * Check if a contact was verified eg. by a secure-join QR code scan
 * and if the key has not changed since this verification.
 *
 * The UI may draw a checkbox or sth. like that beside verified contacts.
 *
 * @memberof dc_contact_t
 * @param contact The contact object.
 * @return 0: contact is not verified.
 *    2: SELF and contact have verified their fingerprints in both directions; in the UI typically checkmarks are shown.
 */
int dc_contact_is_verified(dc_contact_t* contact)
{
	return dc_contact_is_verified_ex(contact, NULL);
}


/**
 * Load a contact from the database to the contact object.
 *
 * @private @memberof dc_contact_t
 */
int dc_contact_load_from_db(dc_contact_t* contact, dc_sqlite3_t* sql, uint32_t contact_id)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;

	if (contact==NULL || contact->magic!=DC_CONTACT_MAGIC || sql==NULL) {
		goto cleanup;
	}

	dc_contact_empty(contact);

	if (contact_id==DC_CONTACT_ID_SELF)
	{
		contact->id   = contact_id;
		contact->name = dc_stock_str(contact->context, DC_STR_SELF);
		contact->addr = dc_sqlite3_get_config(sql, "configured_addr", "");
	}
	else
	{
		stmt = dc_sqlite3_prepare(sql,
			"SELECT c.name, c.addr, c.origin, c.blocked, c.authname "
			" FROM contacts c "
			" WHERE c.id=?;");
		sqlite3_bind_int(stmt, 1, contact_id);
		if (sqlite3_step(stmt)!=SQLITE_ROW) {
			goto cleanup;
		}

		contact->id               = contact_id;
		contact->name             = dc_strdup((char*)sqlite3_column_text (stmt, 0));
		contact->addr             = dc_strdup((char*)sqlite3_column_text (stmt, 1));
		contact->origin           =                  sqlite3_column_int  (stmt, 2);
		contact->blocked          =                  sqlite3_column_int  (stmt, 3);
		contact->authname         = dc_strdup((char*)sqlite3_column_text (stmt, 4));
	}

	success = 1;

cleanup:
	sqlite3_finalize(stmt);
	return success;
}


/*******************************************************************************
 * Working with names
 ******************************************************************************/


/**
 * Get the first name.
 *
 * In a string, get the part before the first space.
 * If there is no space in the string, the whole string is returned.
 *
 * @private @memberof dc_contact_t
 * @param full_name Full name of the contact.
 * @return String with the first name, must be free()'d after usage.
 */
char* dc_get_first_name(const char* full_name)
{
	char* first_name = dc_strdup(full_name);
	char* p1 = strchr(first_name, ' ');
	if (p1) {
		*p1 = 0;
		dc_rtrim(first_name);
		if (first_name[0]==0) { /*empty result? use the original string in this case */
			free(first_name);
			first_name = dc_strdup(full_name);
		}
	}

	return first_name;
}


/**
 * Normalize a name in-place.
 *
 * - Remove quotes (come from some bad MUA implementations)
 * - Convert names as "Petersen, Björn" to "Björn Petersen"
 * - Trims the resulting string
 *
 * Typically, this function is not needed as it is called implicitly by dc_add_address_book()
 *
 * @private @memberof dc_contact_t
 * @param full_name Buffer with the name, is modified during processing; the
 *     resulting string may be shorter but never longer.
 * @return None. But the given buffer may be modified.
 */
void dc_normalize_name(char* full_name)
{
	if (full_name==NULL) {
		return; /* error, however, this can be treated as documented behaviour */
	}

	dc_trim(full_name); /* remove spaces around possible quotes */
	int len = strlen(full_name);
	if (len > 0) {
		char firstchar = full_name[0], lastchar = full_name[len-1];
		if ((firstchar=='\'' && lastchar=='\'')
		 || (firstchar=='"'  && lastchar=='"')
		 || (firstchar=='<'  && lastchar=='>')) {
			full_name[0]     = ' ';
			full_name[len-1] = ' '; /* the string is trimmed later again */
		}
	}

	char* p1 = strchr(full_name, ',');
	if (p1) {
		*p1 = 0;
		char* last_name  = dc_strdup(full_name);
		char* first_name = dc_strdup(p1+1);
		dc_trim(last_name);
		dc_trim(first_name);
		strcpy(full_name, first_name);
		strcat(full_name, " ");
		strcat(full_name, last_name);
		free(last_name);
		free(first_name);
	}
	else {
		dc_trim(full_name);
	}
}


/*******************************************************************************
 * Working with e-mail-addresses
 ******************************************************************************/


/**
 * Normalize an email address.
 *
 * Normalization includes:
 * - Trimming
 * - removing `mailto:` prefix
 *
 * Not sure if we should also unifiy international characters before the @,
 * see also https://autocrypt.readthedocs.io/en/latest/address-canonicalization.html
 *
 * @private @memberof dc_contact_t
 * @param addr The email address to normalize.
 * @return The normalized email address, must be free()'d. NULL is never returned.
 */
char* dc_addr_normalize(const char* addr)
{
	char* addr_normalized = dc_strdup(addr);
	dc_trim(addr_normalized);
	if (strncmp(addr_normalized, "mailto:", 7)==0) {
		char* old = addr_normalized;
		addr_normalized = dc_strdup(&old[7]);
		free(old);
		dc_trim(addr_normalized);
	}
	return addr_normalized;
}


/**
 * Compare two e-mail-addresses.
 * The adresses will be normalized before compare and the comparison is case-insensitive.
 *
 * @private @memberof dc_contact_t
 * @return 0: addresses are equal, >0: addr1 is larger than addr2, <0: addr1 is smaller than addr2
 */
int dc_addr_cmp(const char* addr1, const char* addr2)
{
	char* norm1 = dc_addr_normalize(addr1);
	char* norm2 = dc_addr_normalize(addr2);
	int ret = strcasecmp(addr1, addr2);
	free(norm1);
	free(norm2);
	return ret;
}


/**
 * Check if a given e-mail-address is equal to the configured-self-address.
 *
 * @private @memberof dc_contact_t
 */
int dc_addr_equals_self(dc_context_t* context, const char* addr)
{
	int   ret             = 0;
	char* normalized_addr = NULL;
	char* self_addr       = NULL;

	if (context==NULL || addr==NULL) {
		goto cleanup;
	}

	normalized_addr = dc_addr_normalize(addr);

	if (NULL==(self_addr=dc_sqlite3_get_config(context->sql, "configured_addr", NULL))) {
		goto cleanup;
	}

	ret = strcasecmp(normalized_addr, self_addr)==0? 1 : 0;

cleanup:
	free(self_addr);
	free(normalized_addr);
	return ret;
}


int dc_addr_equals_contact(dc_context_t* context, const char* addr, uint32_t contact_id)
{
	int addr_are_equal = 0;
	if (addr) {
		dc_contact_t* contact = dc_contact_new(context);
		if (dc_contact_load_from_db(contact, context->sql, contact_id)) {
			if (contact->addr) {
				char* normalized_addr = dc_addr_normalize(addr);
				if (strcasecmp(contact->addr, normalized_addr)==0) {
					addr_are_equal = 1;
				}
				free(normalized_addr);
			}
		}
		dc_contact_unref(contact);
	}
	return addr_are_equal;
}


/*******************************************************************************
 * Context functions to work with contacts
 ******************************************************************************/


int dc_real_contact_exists(dc_context_t* context, uint32_t contact_id)
{
	sqlite3_stmt* stmt = NULL;
	int           ret = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || context->sql->cobj==NULL
	 || contact_id<=DC_CONTACT_ID_LAST_SPECIAL) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT id FROM contacts WHERE id=?;");
	sqlite3_bind_int(stmt, 1, contact_id);

	if (sqlite3_step(stmt)==SQLITE_ROW) {
		ret = 1;
	}

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


size_t dc_get_real_contact_cnt(dc_context_t* context)
{
	size_t        ret = 0;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || context->sql->cobj==NULL) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql, "SELECT COUNT(*) FROM contacts WHERE id>?;");
	sqlite3_bind_int(stmt, 1, DC_CONTACT_ID_LAST_SPECIAL);
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}

	ret = sqlite3_column_int(stmt, 0);

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


uint32_t dc_add_or_lookup_contact( dc_context_t* context,
                                   const char*   name /*can be NULL, the caller may use dc_normalize_name() before*/,
                                   const char*   addr__,
                                   int           origin,
                                   int*          sth_modified )
{
	#define       CONTACT_MODIFIED 1
	#define       CONTACT_CREATED  2
	sqlite3_stmt* stmt = NULL;
	uint32_t      row_id = 0;
	int           dummy = 0;
	char*         addr = NULL;
	char*         row_name = NULL;
	char*         row_addr = NULL;
	char*         row_authname = NULL;

	if (sth_modified==NULL) {
		sth_modified = &dummy;
	}

	*sth_modified = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || addr__==NULL || origin<=0) {
		goto cleanup;
	}

	/* normalize the email-address:
	- remove leading `mailto:` */
	addr = dc_addr_normalize(addr__);

	/* rough check if email-address is valid */
	if (strlen(addr) < 3 || strchr(addr, '@')==NULL || strchr(addr, '.')==NULL) {
		dc_log_warning(context, 0, "Bad address \"%s\" for contact \"%s\".", addr, name?name:"<unset>");
		goto cleanup;
	}

	/* insert email-address to database or modify the record with the given email-address.
	we treat all email-addresses case-insensitive. */
	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT id, name, addr, origin, authname FROM contacts WHERE addr=? COLLATE NOCASE;");
	sqlite3_bind_text(stmt, 1, (const char*)addr, -1, SQLITE_STATIC);
	if (sqlite3_step(stmt)==SQLITE_ROW)
	{

		int         row_origin, update_addr = 0, update_name = 0, update_authname = 0;

		row_id       = sqlite3_column_int(stmt, 0);
		row_name     = dc_strdup((char*)sqlite3_column_text(stmt, 1));
		row_addr     = dc_strdup((char*)sqlite3_column_text(stmt, 2));
		row_origin   = sqlite3_column_int(stmt, 3);
		row_authname = dc_strdup((char*)sqlite3_column_text(stmt, 4));
		sqlite3_finalize (stmt);
		stmt = NULL;

		if (name && name[0]) {
			if (row_name[0]) {
				if (origin>=row_origin && strcmp(name, row_name)!=0) {
					update_name = 1;
				}
			}
			else {
				update_name = 1;
			}

			if (origin==DC_ORIGIN_INCOMING_UNKNOWN_FROM && strcmp(name, row_authname)!=0) {
				update_authname = 1;
			}
		}

		if (origin>=row_origin && strcmp(addr, row_addr)!=0 /*really compare case-sensitive here*/) {
			update_addr = 1;
		}

		if (update_name || update_authname || update_addr || origin>row_origin)
		{
			stmt = dc_sqlite3_prepare(context->sql,
				"UPDATE contacts SET name=?, addr=?, origin=?, authname=? WHERE id=?;");
			sqlite3_bind_text(stmt, 1, update_name?       name   : row_name, -1, SQLITE_STATIC);
			sqlite3_bind_text(stmt, 2, update_addr?       addr   : row_addr, -1, SQLITE_STATIC);
			sqlite3_bind_int (stmt, 3, origin>row_origin? origin : row_origin);
			sqlite3_bind_text(stmt, 4, update_authname?   name   : row_authname, -1, SQLITE_STATIC);
			sqlite3_bind_int (stmt, 5, row_id);
			sqlite3_step     (stmt);
			sqlite3_finalize (stmt);
			stmt = NULL;

			if (update_name)
			{
				/* Update the contact name also if it is used as a group name.
				This is one of the few duplicated data, however, getting the chat list is easier this way.*/
				stmt = dc_sqlite3_prepare(context->sql,
					"UPDATE chats SET name=? WHERE type=? AND id IN(SELECT chat_id FROM chats_contacts WHERE contact_id=?);");
				sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
				sqlite3_bind_int (stmt, 2, DC_CHAT_TYPE_SINGLE);
				sqlite3_bind_int (stmt, 3, row_id);
				sqlite3_step     (stmt);
			}

			*sth_modified = CONTACT_MODIFIED;
		}
	}
	else
	{
		sqlite3_finalize (stmt);
		stmt = NULL;

		stmt = dc_sqlite3_prepare(context->sql,
			"INSERT INTO contacts (name, addr, origin) VALUES(?, ?, ?);");
		sqlite3_bind_text(stmt, 1, name? name : "", -1, SQLITE_STATIC); /* avoid NULL-fields in column */
		sqlite3_bind_text(stmt, 2, addr,    -1, SQLITE_STATIC);
		sqlite3_bind_int (stmt, 3, origin);
		if (sqlite3_step(stmt)==SQLITE_DONE)
		{
			row_id = dc_sqlite3_get_rowid(context->sql, "contacts", "addr", addr);
			*sth_modified = CONTACT_CREATED;
		}
		else
		{
			dc_log_error(context, 0, "Cannot add contact."); /* should not happen */
		}
	}

cleanup:
	free(addr);
	free(row_addr);
	free(row_name);
	free(row_authname);
	sqlite3_finalize(stmt);
	return row_id;
}


void dc_scaleup_contact_origin(dc_context_t* context, uint32_t contact_id, int origin)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return;
	}

	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
		"UPDATE contacts SET origin=? WHERE id=? AND origin<?;");
	sqlite3_bind_int(stmt, 1, origin);
	sqlite3_bind_int(stmt, 2, contact_id);
	sqlite3_bind_int(stmt, 3, origin);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
}


int dc_is_contact_blocked(dc_context_t* context, uint32_t contact_id)
{
	int           is_blocked = 0;
	dc_contact_t* contact = dc_contact_new(context);

	if (dc_contact_load_from_db(contact, context->sql, contact_id)) {
		if (contact->blocked) {
			is_blocked = 1;
		}
	}

	dc_contact_unref(contact);
	return is_blocked;
}


int dc_get_contact_origin(dc_context_t* context, uint32_t contact_id, int* ret_blocked)
{
	int           ret = 0;
	int           dummy = 0; if (ret_blocked==NULL) { ret_blocked = &dummy; }
	dc_contact_t* contact = dc_contact_new(context);

	*ret_blocked = 0;

	if (!dc_contact_load_from_db(contact, context->sql, contact_id)) { /* we could optimize this by loading only the needed fields */
		goto cleanup;
	}

	if (contact->blocked) {
		*ret_blocked = 1;
		goto cleanup;
	}

	ret = contact->origin;

cleanup:
	dc_contact_unref(contact);
	return ret;
}


/**
 * Add a single contact as a result of an _explicit_ user action.
 *
 * We assume, the contact name, if any, is entered by the user and is used "as is" therefore,
 * normalize() is _not_ called for the name. If the contact is blocked, it is unblocked.
 *
 * To add a number of contacts, see dc_add_address_book() which is much faster for adding
 * a bunch of addresses.
 *
 * May result in a #DC_EVENT_CONTACTS_CHANGED event.
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new().
 * @param name Name of the contact to add. If you do not know the name belonging
 *     to the address, you can give NULL here.
 * @param addr E-mail-address of the contact to add. If the email address
 *     already exists, the name is updated and the origin is increased to
 *     "manually created".
 * @return Contact ID of the created or reused contact.
 */
uint32_t dc_create_contact(dc_context_t* context, const char* name, const char* addr)
{
	uint32_t contact_id = 0;
	int      sth_modified = 0;
	int      blocked = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || addr==NULL || addr[0]==0) {
		goto cleanup;
	}

	contact_id = dc_add_or_lookup_contact(context, name, addr, DC_ORIGIN_MANUALLY_CREATED, &sth_modified);

	blocked = dc_is_contact_blocked(context, contact_id);

	context->cb(context, DC_EVENT_CONTACTS_CHANGED, sth_modified==CONTACT_CREATED? contact_id : 0, 0);

	if (blocked) {
		dc_block_contact(context, contact_id, 0);
	}

cleanup:
	return contact_id;
}


/**
 * Add a number of contacts.
 *
 * Typically used to add the whole address book from the OS. As names here are typically not
 * well formatted, we call normalize() for each name given.
 *
 * To add a single contact entered by the user, you should prefer dc_create_contact(),
 * however, for adding a bunch of addresses, this function is _much_ faster.
 *
 * @memberof dc_context_t
 * @param context the context object as created by dc_context_new().
 * @param adr_book A multi-line string in the format
 *     `Name one\nAddress one\nName two\nAddress two`.
 *      If an email address already exists, the name is updated
 *      unless it was edited manually by dc_create_contact() before.
 * @return The number of modified or added contacts.
 */
int dc_add_address_book(dc_context_t* context, const char* adr_book)
{
	carray* lines = NULL;
	size_t  i = 0;
	size_t  iCnt = 0;
	int     sth_modified = 0;
	int     modify_cnt = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || adr_book==NULL) {
		goto cleanup;
	}

	if ((lines=dc_split_into_lines(adr_book))==NULL) {
		goto cleanup;
	}

	dc_sqlite3_begin_transaction(context->sql);

		iCnt = carray_count(lines);
		for (i = 0; i+1 < iCnt; i += 2) {
			char* name = (char*)carray_get(lines, i);
			char* addr = (char*)carray_get(lines, i+1);
			dc_normalize_name(name);
			dc_add_or_lookup_contact(context, name, addr, DC_ORIGIN_ADRESS_BOOK, &sth_modified);
			if (sth_modified) {
				modify_cnt++;
			}
		}

	dc_sqlite3_commit(context->sql);

cleanup:
	dc_free_splitted_lines(lines);

	return modify_cnt;
}


/**
 * Returns known and unblocked contacts.
 *
 * To get information about a single contact, see dc_get_contact().
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new().
 * @param listflags A combination of flags:
 *     - if the flag DC_GCL_ADD_SELF is set, SELF is added to the list unless filtered by other parameters
 *     - if the flag DC_GCL_VERIFIED_ONLY is set, only verified contacts are returned.
 *       if DC_GCL_VERIFIED_ONLY is not set, verified and unverified contacts are returned.
 * @param query A string to filter the list.  Typically used to implement an
 *     incremental search.  NULL for no filtering.
 * @return An array containing all contact IDs.  Must be dc_array_unref()'d
 *     after usage.
 */
dc_array_t* dc_get_contacts(dc_context_t* context, uint32_t listflags, const char* query)
{
	char*         self_addr = NULL;
	char*         self_name = NULL;
	char*         self_name2 = NULL;
	int           add_self = 0;
	dc_array_t*   ret = dc_array_new(context, 100);
	char*         s3strLikeCmd = NULL;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	self_addr = dc_sqlite3_get_config(context->sql, "configured_addr", ""); /* we add DC_CONTACT_ID_SELF explicitly; so avoid doubles if the address is present as a normal entry for some case */

	if ((listflags&DC_GCL_VERIFIED_ONLY) || query)
	{
		if ((s3strLikeCmd=sqlite3_mprintf("%%%s%%", query? query : ""))==NULL) {
			goto cleanup;
		}
		stmt = dc_sqlite3_prepare(context->sql,
			"SELECT c.id FROM contacts c"
				" LEFT JOIN acpeerstates ps ON c.addr=ps.addr "
				" WHERE c.addr!=? AND c.id>" DC_STRINGIFY(DC_CONTACT_ID_LAST_SPECIAL) " AND c.origin>=" DC_STRINGIFY(DC_ORIGIN_MIN_CONTACT_LIST) " AND c.blocked=0 AND (c.name LIKE ? OR c.addr LIKE ?)" /* see comments in dc_search_msgs() about the LIKE operator */
				" AND (1=? OR LENGTH(ps.verified_key_fingerprint)!=0) "
				" ORDER BY LOWER(c.name||c.addr),c.id;");
		sqlite3_bind_text(stmt, 1, self_addr, -1, SQLITE_STATIC);
		sqlite3_bind_text(stmt, 2, s3strLikeCmd, -1, SQLITE_STATIC);
		sqlite3_bind_text(stmt, 3, s3strLikeCmd, -1, SQLITE_STATIC);
		sqlite3_bind_int (stmt, 4, (listflags&DC_GCL_VERIFIED_ONLY)? 0/*force checking for verified_key*/ : 1/*force statement being always true*/);

		self_name  = dc_sqlite3_get_config(context->sql, "displayname", "");
		self_name2 = dc_stock_str(context, DC_STR_SELF);
		if (query==NULL || dc_str_contains(self_addr, query) || dc_str_contains(self_name, query) || dc_str_contains(self_name2, query)) {
			add_self = 1;
		}
	}
	else
	{
		stmt = dc_sqlite3_prepare(context->sql,
			"SELECT id FROM contacts"
				" WHERE addr!=? AND id>" DC_STRINGIFY(DC_CONTACT_ID_LAST_SPECIAL) " AND origin>=" DC_STRINGIFY(DC_ORIGIN_MIN_CONTACT_LIST) " AND blocked=0"
				" ORDER BY LOWER(name||addr),id;");
		sqlite3_bind_text(stmt, 1, self_addr, -1, SQLITE_STATIC);

		add_self = 1;
	}

	while (sqlite3_step(stmt)==SQLITE_ROW) {
		dc_array_add_id(ret, sqlite3_column_int(stmt, 0));
	}

	/* to the end of the list, add self - this is to be in sync with member lists and to allow the user to start a self talk */
	if ((listflags&DC_GCL_ADD_SELF) && add_self) {
		dc_array_add_id(ret, DC_CONTACT_ID_SELF);
	}

cleanup:
	sqlite3_finalize(stmt);
	sqlite3_free(s3strLikeCmd);
	free(self_addr);
	free(self_name);
	free(self_name2);
	return ret;
}


/**
 * Get blocked contacts.
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new().
 * @return An array containing all blocked contact IDs.  Must be dc_array_unref()'d
 *     after usage.
 */
dc_array_t* dc_get_blocked_contacts(dc_context_t* context)
{
	dc_array_t*   ret = dc_array_new(context, 100);
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT id FROM contacts"
			" WHERE id>? AND blocked!=0"
			" ORDER BY LOWER(name||addr),id;");
	sqlite3_bind_int(stmt, 1, DC_CONTACT_ID_LAST_SPECIAL);
	while (sqlite3_step(stmt)==SQLITE_ROW) {
		dc_array_add_id(ret, sqlite3_column_int(stmt, 0));
	}

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


/**
 * Get a single contact object.  For a list, see eg. dc_get_contacts().
 *
 * For contact DC_CONTACT_ID_SELF (1), the function returns sth.
 * like "Me" in the selected language and the email address
 * defined by dc_set_config().
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new().
 * @param contact_id ID of the contact to get the object for.
 * @return The contact object, must be freed using dc_contact_unref() when no
 *     longer used.  NULL on errors.
 */
dc_contact_t* dc_get_contact(dc_context_t* context, uint32_t contact_id)
{
	dc_contact_t* ret = dc_contact_new(context);

	if (!dc_contact_load_from_db(ret, context->sql, contact_id)) {
		dc_contact_unref(ret);
		ret = NULL;
	}

	return ret; /* may be NULL */
}


/**
 * Mark all messages sent by the given contact
 * as _noticed_.  See also dc_marknoticed_chat() and
 * dc_markseen_msgs()
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new()
 * @param contact_id The contact ID of which all messages should be marked as noticed.
 * @return none
 */
void dc_marknoticed_contact(dc_context_t* context, uint32_t contact_id)
{
    if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return;
    }

	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
		"UPDATE msgs SET state=" DC_STRINGIFY(DC_STATE_IN_NOTICED) " WHERE from_id=? AND state=" DC_STRINGIFY(DC_STATE_IN_FRESH) ";");
	sqlite3_bind_int(stmt, 1, contact_id);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
}


/**
 * Get the number of blocked contacts.
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new().
 * @return The number of blocked contacts.
 */
int dc_get_blocked_cnt(dc_context_t* context)
{
	int           ret = 0;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT COUNT(*) FROM contacts"
			" WHERE id>? AND blocked!=0");
	sqlite3_bind_int(stmt, 1, DC_CONTACT_ID_LAST_SPECIAL);
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}
	ret = sqlite3_column_int(stmt, 0);

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


/**
 * Block or unblock a contact.
 * May result in a #DC_EVENT_CONTACTS_CHANGED event.
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new().
 * @param contact_id The ID of the contact to block or unblock.
 * @param new_blocking 1=block contact, 0=unblock contact
 * @return None.
 */
void dc_block_contact(dc_context_t* context, uint32_t contact_id, int new_blocking)
{
	int           send_event = 0;
	dc_contact_t* contact = dc_contact_new(context);
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || contact_id<=DC_CONTACT_ID_LAST_SPECIAL) {
		goto cleanup;
	}

		if (dc_contact_load_from_db(contact, context->sql, contact_id)
		 && contact->blocked!=new_blocking)
		{
			stmt = dc_sqlite3_prepare(context->sql,
				"UPDATE contacts SET blocked=? WHERE id=?;");
			sqlite3_bind_int(stmt, 1, new_blocking);
			sqlite3_bind_int(stmt, 2, contact_id);
			if (sqlite3_step(stmt)!=SQLITE_DONE) {
				goto cleanup;
			}
			sqlite3_finalize(stmt);
			stmt = NULL;

			/* also (un)block all chats with _only_ this contact - we do not delete them to allow a non-destructive blocking->unblocking.
			(Maybe, beside normal chats (type=100) we should also block group chats with only this user.
			However, I'm not sure about this point; it may be confusing if the user wants to add other people;
			this would result in recreating the same group...) */
			stmt = dc_sqlite3_prepare(context->sql,
				"UPDATE chats SET blocked=? WHERE type=? AND id IN (SELECT chat_id FROM chats_contacts WHERE contact_id=?);");
			sqlite3_bind_int(stmt, 1, new_blocking);
			sqlite3_bind_int(stmt, 2, DC_CHAT_TYPE_SINGLE);
			sqlite3_bind_int(stmt, 3, contact_id);
			if (sqlite3_step(stmt)!=SQLITE_DONE) {
				goto cleanup;
			}

			/* mark all messages from the blocked contact as being noticed (this is to remove the deaddrop popup) */
			dc_marknoticed_contact(context, contact_id);

			send_event = 1;
		}

	if (send_event) {
		context->cb(context, DC_EVENT_CONTACTS_CHANGED, 0, 0);
	}

cleanup:
	sqlite3_finalize(stmt);
	dc_contact_unref(contact);
}


static void cat_fingerprint(dc_strbuilder_t* ret, const char* addr, const char* fingerprint_verified, const char* fingerprint_unverified)
{
	dc_strbuilder_cat(ret, "\n\n");
	dc_strbuilder_cat(ret, addr);
	dc_strbuilder_cat(ret, ":\n");
	dc_strbuilder_cat(ret, (fingerprint_verified&&fingerprint_verified[0])? fingerprint_verified : fingerprint_unverified);

	if (fingerprint_verified && fingerprint_verified[0]
	 && fingerprint_unverified && fingerprint_unverified[0]
	 && strcmp(fingerprint_verified, fingerprint_unverified)!=0) {
		// might be that for verified chats the - older - verified gossiped key is used
		// and for normal chats the - newer - unverified key :/
		dc_strbuilder_cat(ret, "\n\n");
		dc_strbuilder_cat(ret, addr);
		dc_strbuilder_cat(ret, " (alternative):\n");
		dc_strbuilder_cat(ret, fingerprint_unverified);
	}
}


/**
 * Get encryption info for a contact.
 * Get a multi-line encryption info, containing your fingerprint and the
 * fingerprint of the contact, used eg. to compare the fingerprints for a simple out-of-band verification.
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new().
 * @param contact_id ID of the contact to get the encryption info for.
 * @return multi-line text, must be free()'d after usage.
 */
char* dc_get_contact_encrinfo(dc_context_t* context, uint32_t contact_id)
{
	dc_loginparam_t* loginparam = dc_loginparam_new();
	dc_contact_t*    contact = dc_contact_new(context);
	dc_apeerstate_t* peerstate = dc_apeerstate_new(context);
	dc_key_t*        self_key = dc_key_new();
	char*            fingerprint_self = NULL;
	char*            fingerprint_other_verified = NULL;
	char*            fingerprint_other_unverified = NULL;
	char*            p = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	dc_strbuilder_t  ret;
	dc_strbuilder_init(&ret, 0);

	if (!dc_contact_load_from_db(contact, context->sql, contact_id)) {
		goto cleanup;
	}
	dc_apeerstate_load_by_addr(peerstate, context->sql, contact->addr);
	dc_loginparam_read(loginparam, context->sql, "configured_");

	dc_key_load_self_public(self_key, loginparam->addr, context->sql);

	if (dc_apeerstate_peek_key(peerstate, DC_NOT_VERIFIED))
	{
		// E2E available :)
		p = dc_stock_str(context, peerstate->prefer_encrypt==DC_PE_MUTUAL? DC_STR_E2E_PREFERRED : DC_STR_E2E_AVAILABLE); dc_strbuilder_cat(&ret, p); free(p);

		if (self_key->binary==NULL) {
			dc_pgp_rand_seed(context, peerstate->addr, strlen(peerstate->addr) /*just some random data*/);
			dc_ensure_secret_key_exists(context);
			dc_key_load_self_public(self_key, loginparam->addr, context->sql);
		}

		dc_strbuilder_cat(&ret, " ");
		p = dc_stock_str(context, DC_STR_FINGERPRINTS); dc_strbuilder_cat(&ret, p); free(p);
		dc_strbuilder_cat(&ret, ":");

		fingerprint_self = dc_key_get_formatted_fingerprint(self_key);
		fingerprint_other_verified = dc_key_get_formatted_fingerprint(dc_apeerstate_peek_key(peerstate, DC_BIDIRECT_VERIFIED));
		fingerprint_other_unverified = dc_key_get_formatted_fingerprint(dc_apeerstate_peek_key(peerstate, DC_NOT_VERIFIED));

		if (strcmp(loginparam->addr, peerstate->addr)<0) {
			cat_fingerprint(&ret, loginparam->addr, fingerprint_self, NULL);
			cat_fingerprint(&ret, peerstate->addr, fingerprint_other_verified, fingerprint_other_unverified);
		}
		else {
			cat_fingerprint(&ret, peerstate->addr, fingerprint_other_verified, fingerprint_other_unverified);
			cat_fingerprint(&ret, loginparam->addr, fingerprint_self, NULL);
		}
	}
	else
	{
		// No E2E available
		if (!(loginparam->server_flags&DC_LP_IMAP_SOCKET_PLAIN)
		 && !(loginparam->server_flags&DC_LP_SMTP_SOCKET_PLAIN))
		{
			p = dc_stock_str(context, DC_STR_ENCR_TRANSP); dc_strbuilder_cat(&ret, p); free(p);
		}
		else
		{
			p = dc_stock_str(context, DC_STR_ENCR_NONE); dc_strbuilder_cat(&ret, p); free(p);
		}
	}

cleanup:
	dc_apeerstate_unref(peerstate);
	dc_contact_unref(contact);
	dc_loginparam_unref(loginparam);
	dc_key_unref(self_key);
	free(fingerprint_self);
	free(fingerprint_other_verified);
	free(fingerprint_other_unverified);
	return ret.buf;
}


/**
 * Delete a contact.  The contact is deleted from the local device.  It may happen that this is not
 * possible as the contact is in use.  In this case, the contact can be blocked.
 *
 * May result in a #DC_EVENT_CONTACTS_CHANGED event.
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new().
 * @param contact_id ID of the contact to delete.
 * @return 1=success, 0=error
 */
int dc_delete_contact(dc_context_t* context, uint32_t contact_id)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || contact_id<=DC_CONTACT_ID_LAST_SPECIAL) {
		goto cleanup;
	}

	/* we can only delete contacts that are not in use anywhere; this function is mainly for the user who has just
	created an contact manually and wants to delete it a moment later */
	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT COUNT(*) FROM chats_contacts WHERE contact_id=?;");
	sqlite3_bind_int(stmt, 1, contact_id);
	if (sqlite3_step(stmt)!=SQLITE_ROW || sqlite3_column_int(stmt, 0) >= 1) {
		goto cleanup;
	}
	sqlite3_finalize(stmt);
	stmt = NULL;

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT COUNT(*) FROM msgs WHERE from_id=? OR to_id=?;");
	sqlite3_bind_int(stmt, 1, contact_id);
	sqlite3_bind_int(stmt, 2, contact_id);
	if (sqlite3_step(stmt)!=SQLITE_ROW || sqlite3_column_int(stmt, 0) >= 1) {
		goto cleanup;
	}
	sqlite3_finalize(stmt);
	stmt = NULL;

	stmt = dc_sqlite3_prepare(context->sql,
		"DELETE FROM contacts WHERE id=?;");
	sqlite3_bind_int(stmt, 1, contact_id);
	if (sqlite3_step(stmt)!=SQLITE_DONE) {
		goto cleanup;
	}

	context->cb(context, DC_EVENT_CONTACTS_CHANGED, 0, 0);

	success = 1;

cleanup:
	sqlite3_finalize(stmt);
	return success;
}
