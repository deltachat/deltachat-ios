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
#include "mrmimeparser.h"
#include "mrloginparam.h"
#include "mrpgp.h"
#include "mrapeerstate.h"
#include "mrtools.h"


/*******************************************************************************
 * Tools
 ******************************************************************************/


void mr_normalize_name(char* full_name)
{
	/* function ...
	- removes quotes (come from some bad MUA implementations)
	- converts names as "Petersen, Björn" to "Björn Petersen"
	- trims the resulting string
	- modifies the given buffer; so the resulting string must not be longer than the original string. */

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


char* mr_get_first_name(const char* full_name)
{
	/* check for the name before the first space */
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

	return first_name; /* the result must be free()'d */
}


int mrmailbox_real_contact_exists__(mrmailbox_t* mailbox, uint32_t contact_id)
{
	sqlite3_stmt* stmt;
	int           ret = 0;

	if( mailbox == NULL || mailbox->m_sql->m_cobj==NULL
	 || contact_id <= MR_CONTACT_ID_LAST_SPECIAL ) {
		return 0;
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_WHERE_id,
		"SELECT id FROM contacts WHERE id=?;");
	sqlite3_bind_int(stmt, 1, contact_id);

	if( sqlite3_step(stmt) == SQLITE_ROW ) {
		ret = 1;
	}

	return ret;
}


size_t mrmailbox_get_real_contact_cnt__(mrmailbox_t* mailbox)
{
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_sql->m_cobj==NULL ) {
		return 0;
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_contacts, "SELECT COUNT(*) FROM contacts WHERE id>?;");
	sqlite3_bind_int(stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


uint32_t mrmailbox_add_or_lookup_contact__( mrmailbox_t* mailbox,
                                           const char*  name /*can be NULL, the caller may use mr_normalize_name() before*/,
                                           const char*  addr__,
                                           int          origin,
                                           int*         sth_modified )
{
	sqlite3_stmt* stmt;
	uint32_t      row_id = 0;
	int           dummy;
	char*         addr = NULL;

	if( sth_modified == NULL ) {
		sth_modified = &dummy;
	}

	*sth_modified = 0;

	if( mailbox == NULL || addr__ == NULL || origin <= 0 ) {
		return 0;
	}

	/* normalize the email-address:
	- remove leading `mailto:` */
	addr = mr_normalize_addr(addr__);

	/* rough check if email-address is valid */
	if( strlen(addr) < 3 || strchr(addr, '@')==NULL || strchr(addr, '.')==NULL ) {
		mrmailbox_log_warning(mailbox, 0, "Bad address \"%s\" for contact \"%s\".", addr, name?name:"<unset>");
		goto cleanup;
	}

	/* insert email-address to database or modify the record with the given email-address.
	we treat all email-addresses case-insensitive. */
	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_inao_FROM_contacts_a,
		"SELECT id, name, addr, origin, authname FROM contacts WHERE addr=? COLLATE NOCASE;");
	sqlite3_bind_text(stmt, 1, (const char*)addr, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) == SQLITE_ROW )
	{
		const char  *row_name, *row_addr, *row_authname;
		int         row_origin, update_addr = 0, update_name = 0, update_authname = 0;

		row_id       = sqlite3_column_int(stmt, 0);
		row_name     = (const char*)sqlite3_column_text(stmt, 1); if( row_name == NULL ) { row_name = ""; }
		row_addr     = (const char*)sqlite3_column_text(stmt, 2); if( row_addr == NULL ) { row_addr = addr; }
		row_origin   = sqlite3_column_int(stmt, 3);
		row_authname = (const char*)sqlite3_column_text(stmt, 4); if( row_authname == NULL ) { row_authname = ""; }

		if( name && name[0] ) {
			if( row_name && row_name[0] ) {
				if( origin>=row_origin && strcmp(name, row_name)!=0 ) {
					update_name = 1;
				}
			}
			else {
				update_name = 1;
			}

			if( origin == MR_ORIGIN_INCOMING_UNKNOWN_FROM && strcmp(name, row_authname)!=0 ) {
				update_authname = 1;
			}
		}

		if( origin>=row_origin && strcmp(addr, row_addr)!=0 /*really compare case-sensitive here*/ ) {
			update_addr = 1;
		}

		if( update_name || update_authname || update_addr || origin>row_origin )
		{
			stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_contacts_nao_WHERE_i,
				"UPDATE contacts SET name=?, addr=?, origin=?, authname=? WHERE id=?;");
			sqlite3_bind_text(stmt, 1, update_name?       name   : row_name, -1, SQLITE_STATIC);
			sqlite3_bind_text(stmt, 2, update_addr?       addr   : row_addr, -1, SQLITE_STATIC);
			sqlite3_bind_int (stmt, 3, origin>row_origin? origin : row_origin);
			sqlite3_bind_text(stmt, 4, update_authname?   name   : row_authname, -1, SQLITE_STATIC);
			sqlite3_bind_int (stmt, 5, row_id);
			sqlite3_step     (stmt);

			if( update_name )
			{
				/* Update the contact name also if it is used as a group name.
				This is one of the few duplicated data, however, getting the chat list is much faster this way.*/
				stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_chats_SET_n_WHERE_c,
					"UPDATE chats SET name=? WHERE type=? AND id IN(SELECT chat_id FROM chats_contacts WHERE contact_id=?);");
				sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
				sqlite3_bind_int (stmt, 2, MR_CHAT_NORMAL);
				sqlite3_bind_int (stmt, 3, row_id);
				sqlite3_step     (stmt);
			}
		}

		*sth_modified = 1;
	}
	else
	{
		stmt = mrsqlite3_predefine__(mailbox->m_sql, INSERT_INTO_contacts_neo,
			"INSERT INTO contacts (name, addr, origin) VALUES(?, ?, ?);");
		sqlite3_bind_text(stmt, 1, name? name : "", -1, SQLITE_STATIC); /* avoid NULL-fields in column */
		sqlite3_bind_text(stmt, 2, addr,    -1, SQLITE_STATIC);
		sqlite3_bind_int (stmt, 3, origin);
		if( sqlite3_step(stmt) == SQLITE_DONE )
		{
			row_id = sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj);
			*sth_modified = 1;
		}
		else
		{
			mrmailbox_log_error(mailbox, 0, "Cannot add contact."); /* should not happen */
		}
	}

cleanup:
	free(addr);
	return row_id;
}


void mrmailbox_scaleup_contact_origin__(mrmailbox_t* mailbox, uint32_t contact_id, int origin)
{
	if( mailbox == NULL ) {
		return;
	}

	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_contacts_SET_origin_WHERE_id,
		"UPDATE contacts SET origin=? WHERE id=? AND origin<?;");
	sqlite3_bind_int(stmt, 1, origin);
	sqlite3_bind_int(stmt, 2, contact_id);
	sqlite3_bind_int(stmt, 3, origin);
	sqlite3_step(stmt);
}


int mrmailbox_is_contact_blocked__(mrmailbox_t* mailbox, uint32_t contact_id)
{
	int          is_blocked = 0;
	mrcontact_t* ths = mrcontact_new();

	if( mrcontact_load_from_db__(ths, mailbox->m_sql, contact_id) ) { /* we could optimize this by loading only the needed fields */
		if( ths->m_blocked ) {
			is_blocked = 1;
		}
	}

	mrcontact_unref(ths);
	return is_blocked;
}


int mrmailbox_get_contact_origin__(mrmailbox_t* mailbox, uint32_t contact_id, int* ret_blocked)
{
	int          ret = MR_ORIGIN_UNSET;
	int          dummy; if( ret_blocked==NULL ) { ret_blocked = &dummy; }
	mrcontact_t* ths = mrcontact_new();

	*ret_blocked = 0;

	if( !mrcontact_load_from_db__(ths, mailbox->m_sql, contact_id) ) { /* we could optimize this by loading only the needed fields */
		goto cleanup;
	}

	if( ths->m_blocked ) {
		*ret_blocked = 1;
		goto cleanup;
	}

	ret = ths->m_origin;

cleanup:
	mrcontact_unref(ths);
	return ret;
}


int mrcontact_load_from_db__(mrcontact_t* ths, mrsqlite3_t* sql, uint32_t contact_id)
{
	int           success = 0;
	sqlite3_stmt* stmt;

	if( ths == NULL || sql == NULL ) {
		return 0;
	}

	mrcontact_empty(ths);

	stmt = mrsqlite3_predefine__(sql, SELECT_naob_FROM_contacts_i,
		"SELECT name, addr, origin, blocked, authname FROM contacts WHERE id=?;");
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

	/* success */
	success = 1;

	/* cleanup */
cleanup:
	return success;
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


uint32_t mrmailbox_create_contact(mrmailbox_t* mailbox, const char* name, const char* addr)
{
	uint32_t contact_id = 0;

	if( mailbox == NULL || addr == NULL || addr[0]==0 ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);

		contact_id = mrmailbox_add_or_lookup_contact__(mailbox, name, addr, MR_ORIGIN_MANUALLY_CREATED, NULL);

	mrsqlite3_unlock(mailbox->m_sql);

	mailbox->m_cb(mailbox, MR_EVENT_CONTACTS_CHANGED, 0, 0);

cleanup:
	return contact_id;
}


int mrmailbox_add_address_book(mrmailbox_t* ths, const char* adr_book) /* format: Name one\nAddress one\nName two\Address two */
{
	carray* lines = NULL;
	size_t  i, iCnt;
	int     sth_modified, modify_cnt = 0;

	if( ths == NULL || adr_book == NULL ) {
		goto cleanup;
	}

	if( (lines=mr_split_into_lines(adr_book))==NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(ths->m_sql);

		mrsqlite3_begin_transaction__(ths->m_sql);

		iCnt = carray_count(lines);
		for( i = 0; i+1 < iCnt; i += 2 ) {
			char* name = (char*)carray_get(lines, i);
			char* addr = (char*)carray_get(lines, i+1);
			mr_normalize_name(name);
			mrmailbox_add_or_lookup_contact__(ths, name, addr, MR_ORIGIN_ADRESS_BOOK, &sth_modified);
			if( sth_modified ) {
				modify_cnt++;
			}
		}

		mrsqlite3_commit__(ths->m_sql);

	mrsqlite3_unlock(ths->m_sql);

cleanup:
	mr_free_splitted_lines(lines);

	return modify_cnt;
}


carray* mrmailbox_get_known_contacts(mrmailbox_t* mailbox, const char* query)
{
	int           locked = 0;
	carray*       ret = carray_new(100);
	char*         s3strLikeCmd = NULL;
	sqlite3_stmt* stmt;

	if( mailbox == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( query ) {
			if( (s3strLikeCmd=sqlite3_mprintf("%%%s%%", query))==NULL ) {
				goto cleanup;
			}
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_WHERE_query_ORDER_BY,
				"SELECT id FROM contacts"
					" WHERE id>? AND origin>=? AND blocked=0 AND (name LIKE ? OR addr LIKE ?)" /* see comments in mrmailbox_search_msgs() about the LIKE operator */
					" ORDER BY LOWER(name||addr),id;");
			sqlite3_bind_int (stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
			sqlite3_bind_int (stmt, 2, MR_ORIGIN_MIN_CONTACT_LIST);
			sqlite3_bind_text(stmt, 3, s3strLikeCmd, -1, SQLITE_STATIC);
			sqlite3_bind_text(stmt, 4, s3strLikeCmd, -1, SQLITE_STATIC);
		}
		else {
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_ORDER_BY,
				"SELECT id FROM contacts"
					" WHERE id>? AND origin>=? AND blocked=0"
					" ORDER BY LOWER(name||addr),id;");
			sqlite3_bind_int(stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
			sqlite3_bind_int(stmt, 2, MR_ORIGIN_MIN_CONTACT_LIST);
		}

		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			carray_add(ret, (void*)(uintptr_t)sqlite3_column_int(stmt, 0), NULL);
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

cleanup:
	if( locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}
	if( s3strLikeCmd ) {
		sqlite3_free(s3strLikeCmd);
	}
	return ret;
}


carray* mrmailbox_get_blocked_contacts(mrmailbox_t* mailbox)
{
	carray*       ret = carray_new(100);
	sqlite3_stmt* stmt;

	if( mailbox == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_WHERE_blocked,
			"SELECT id FROM contacts"
				" WHERE id>? AND blocked!=0"
				" ORDER BY LOWER(name||addr),id;");
		sqlite3_bind_int(stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			carray_add(ret, (void*)(uintptr_t)sqlite3_column_int(stmt, 0), NULL);
		}

	mrsqlite3_unlock(mailbox->m_sql);

cleanup:
	return ret;
}


int mrmailbox_get_blocked_count(mrmailbox_t* mailbox)
{
	int           ret = 0, locked = 0;
	sqlite3_stmt* stmt;

	if( mailbox == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_contacts_WHERE_blocked,
			"SELECT COUNT(*) FROM contacts"
				" WHERE id>? AND blocked!=0");
		sqlite3_bind_int(stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
		if( sqlite3_step(stmt) != SQLITE_ROW ) {
			goto cleanup;
		}
		ret = sqlite3_column_int(stmt, 0);

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	return ret;
}


mrcontact_t* mrmailbox_get_contact(mrmailbox_t* ths, uint32_t contact_id)
{
	mrcontact_t* ret = mrcontact_new();

	mrsqlite3_lock(ths->m_sql);

		if( contact_id == MR_CONTACT_ID_SELF )
		{
			ret->m_id   = contact_id;
			ret->m_name = mrstock_str(MR_STR_SELF);
			ret->m_addr = mrsqlite3_get_config__(ths->m_sql, "configured_addr", NULL);
		}
		else
		{
			if( !mrcontact_load_from_db__(ret, ths->m_sql, contact_id) ) {
				mrcontact_unref(ret);
				ret = NULL;
			}
		}

	mrsqlite3_unlock(ths->m_sql);

	return ret; /* may be NULL */
}


static void marknoticed_contact__(mrmailbox_t* mailbox, uint32_t contact_id)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_state_WHERE_from_id_AND_state,
		"UPDATE msgs SET state=" MR_STRINGIFY(MR_STATE_IN_NOTICED) " WHERE from_id=? AND state=" MR_STRINGIFY(MR_STATE_IN_FRESH) ";");
	sqlite3_bind_int(stmt, 1, contact_id);
	sqlite3_step(stmt);
}


int mrmailbox_marknoticed_contact(mrmailbox_t* mailbox, uint32_t contact_id)
{
    if( mailbox == NULL ) {
		return 0;
    }
    mrsqlite3_lock(mailbox->m_sql);
		marknoticed_contact__(mailbox, contact_id);
    mrsqlite3_unlock(mailbox->m_sql);
    return 1;
}


int mrmailbox_block_contact(mrmailbox_t* mailbox, uint32_t contact_id, int new_blocking)
{
	int success = 0, locked = 0, send_event = 0, transaction_pending = 0;
	mrcontact_t*  contact = mrcontact_new();
	sqlite3_stmt* stmt;

	if( mailbox == NULL ) {
		return 0;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id)
		 && contact->m_blocked != new_blocking )
		{
			mrsqlite3_begin_transaction__(mailbox->m_sql);
			transaction_pending = 1;

				stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_contacts_SET_b_WHERE_i,
					"UPDATE contacts SET blocked=? WHERE id=?;");
				sqlite3_bind_int(stmt, 1, new_blocking);
				sqlite3_bind_int(stmt, 2, contact_id);
				if( sqlite3_step(stmt)!=SQLITE_DONE ) {
					goto cleanup;
				}

				/* also (un)block all chats with _only_ this contact - we do not delete them to allow a non-destructive blocking->unblocking.
				(Maybe, beside normal chats (type=100) we should also block group chats with only this user.
				However, I'm not sure about this point; it may be confusing if the user wants to add other people;
				this would result in recreating the same group...) */
				stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_chats_SET_blocked,
					"UPDATE chats SET blocked=? WHERE type=? AND id IN (SELECT chat_id FROM chats_contacts WHERE contact_id=?);");
				sqlite3_bind_int(stmt, 1, new_blocking);
				sqlite3_bind_int(stmt, 2, MR_CHAT_NORMAL);
				sqlite3_bind_int(stmt, 3, contact_id);
				if( sqlite3_step(stmt)!=SQLITE_DONE ) {
					goto cleanup;
				}

				/* mark all messages from the blocked contact as being noticed (this is to remove the deaddrop popup) */
				marknoticed_contact__(mailbox, contact_id);

			mrsqlite3_commit__(mailbox->m_sql);
			transaction_pending = 0;

			send_event = 1;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	if( send_event ) {
		mailbox->m_cb(mailbox, MR_EVENT_CONTACTS_CHANGED, 0, 0);
	}

	success = 1;

cleanup:
	if( transaction_pending ) {
		mrsqlite3_rollback__(mailbox->m_sql);
	}

	if( locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}

	mrcontact_unref(contact);
	return success;
}


static void cat_fingerprint(mrstrbuilder_t* ret, const char* addr, const char* fingerprint_str)
{
	mrstrbuilder_cat(ret, addr);
	mrstrbuilder_cat(ret, ":\n");
	mrstrbuilder_cat(ret, fingerprint_str);
	mrstrbuilder_cat(ret, "\n\n");
}


char* mrmailbox_get_contact_encrinfo(mrmailbox_t* mailbox, uint32_t contact_id)
{
	int             locked = 0;
	int             e2ee_enabled = 0;
	int             explain_id = 0;
	mrloginparam_t* loginparam = mrloginparam_new();
	mrcontact_t*    contact = mrcontact_new();
	mrapeerstate_t* peerstate = mrapeerstate_new();
	int             peerstate_ok = 0;
	mrkey_t*        self_key = mrkey_new();
	char*           fingerprint_str_self = NULL;
	char*           fingerprint_str_other = NULL;
	char*           p;

	mrstrbuilder_t  ret;
	mrstrbuilder_init(&ret);

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( !mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id) ) {
			goto cleanup;
		}
		peerstate_ok = mrapeerstate_load_from_db__(peerstate, mailbox->m_sql, contact->m_addr);
		mrloginparam_read__(loginparam, mailbox->m_sql, "configured_");
		e2ee_enabled = mailbox->m_e2ee_enabled;

		mrkey_load_self_public__(self_key, loginparam->m_addr, mailbox->m_sql);

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* show the encryption that would be used for the next outgoing message */
	if( e2ee_enabled
	 && peerstate_ok
	 && peerstate->m_prefer_encrypt==MRA_PE_MUTUAL
	 && peerstate->m_public_key->m_binary!=NULL )
	{
		/* e2e fine and used */
		p = mrstock_str(MR_STR_ENCR_E2E); mrstrbuilder_cat(&ret, p); free(p);
		explain_id = MR_STR_E2E_FINE;
	}
	else
	{
		/* e2e not used ... first, show status quo ... */
		if( !(loginparam->m_server_flags&MR_IMAP_SOCKET_PLAIN)
		 && !(loginparam->m_server_flags&MR_SMTP_SOCKET_PLAIN) )
		{
			p = mrstock_str(MR_STR_ENCR_TRANSP); mrstrbuilder_cat(&ret, p); free(p);
		}
		else
		{
			p = mrstock_str(MR_STR_ENCR_NONE); mrstrbuilder_cat(&ret, p); free(p);
		}

		/* ... and then explain why we cannot use e2e */
		if( peerstate_ok && peerstate->m_public_key->m_binary!=NULL && peerstate->m_prefer_encrypt!=MRA_PE_MUTUAL ) {
			explain_id = MR_STR_E2E_DIS_BY_RCPT;
		}
		else if( !e2ee_enabled ) {
			explain_id = MR_STR_E2E_DIS_BY_YOU;
		}
		else {
			explain_id = MR_STR_E2E_NO_AUTOCRYPT;
		}
	}

	/* show fingerprints for comparison (sorted by email-address to make a device-side-by-side comparison easier) */
	if( peerstate_ok
	 && peerstate->m_public_key->m_binary!=NULL )
	{
		if( self_key->m_binary == NULL ) {
			mrpgp_rand_seed(mailbox, peerstate->m_addr, strlen(peerstate->m_addr) /*just some random data*/);
			mrmailbox_ensure_secret_key_exists(mailbox);
			mrsqlite3_lock(mailbox->m_sql);
			locked = 1;
				mrkey_load_self_public__(self_key, loginparam->m_addr, mailbox->m_sql);
			mrsqlite3_unlock(mailbox->m_sql);
			locked = 0;
		}

		mrstrbuilder_cat(&ret, " ");
		p = mrstock_str(MR_STR_FINGERPRINTS); mrstrbuilder_cat(&ret, p); free(p);
		mrstrbuilder_cat(&ret, ":\n\n");

		fingerprint_str_self = mrkey_render_fingerprint(self_key, mailbox);
		fingerprint_str_other = mrkey_render_fingerprint(peerstate->m_public_key, mailbox);

		if( strcmp(loginparam->m_addr, peerstate->m_addr)<0 ) {
			cat_fingerprint(&ret, loginparam->m_addr, fingerprint_str_self);
			cat_fingerprint(&ret, peerstate->m_addr, fingerprint_str_other);
		}
		else {
			cat_fingerprint(&ret, peerstate->m_addr, fingerprint_str_other);
			cat_fingerprint(&ret, loginparam->m_addr, fingerprint_str_self);
		}
	}
	else
	{
		mrstrbuilder_cat(&ret, "\n\n");
	}

	p = mrstock_str(explain_id); mrstrbuilder_cat(&ret, p); free(p);

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrapeerstate_unref(peerstate);
	mrcontact_unref(contact);
	mrloginparam_unref(loginparam);
	mrkey_unref(self_key);
	free(fingerprint_str_self);
	free(fingerprint_str_other);
	return ret.m_buf;
}


int mrmailbox_delete_contact(mrmailbox_t* mailbox, uint32_t contact_id)
{
	int           locked = 0, success = 0;
	sqlite3_stmt* stmt;

	if( mailbox == NULL || contact_id <= MR_CONTACT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		/* we can only delete contacts that are not in use anywhere; this function is mainly for the user who has just
		created an contact manually and wants to delete it a moment later */
		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_chats_contacts_WHERE_contact_id,
			"SELECT COUNT(*) FROM chats_contacts WHERE contact_id=?;");
		sqlite3_bind_int(stmt, 1, contact_id);
		if( sqlite3_step(stmt) != SQLITE_ROW || sqlite3_column_int(stmt, 0) >= 1 ) {
			goto cleanup;
		}

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_ft,
			"SELECT COUNT(*) FROM msgs WHERE from_id=? OR to_id=?;");
		sqlite3_bind_int(stmt, 1, contact_id);
		sqlite3_bind_int(stmt, 2, contact_id);
		if( sqlite3_step(stmt) != SQLITE_ROW || sqlite3_column_int(stmt, 0) >= 1 ) {
			goto cleanup;
		}

		stmt = mrsqlite3_predefine__(mailbox->m_sql, DELETE_FROM_contacts_WHERE_id,
			"DELETE FROM contacts WHERE id=?;");
		sqlite3_bind_int(stmt, 1, contact_id);
		if( sqlite3_step(stmt) != SQLITE_DONE ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	mailbox->m_cb(mailbox, MR_EVENT_CONTACTS_CHANGED, 0, 0);

	success = 1;

cleanup:
	if( locked ) {
		mrsqlite3_unlock(mailbox->m_sql);
	}
	return success;
}


int mrmailbox_contact_addr_equals__(mrmailbox_t* mailbox, uint32_t contact_id, const char* other_addr)
{
	int addr_are_equal = 0;
	if( other_addr ) {
		mrcontact_t* contact = mrcontact_new();
		if( mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id) ) {
			if( contact->m_addr ) {
				if( strcasecmp(contact->m_addr, other_addr)==0 ) {
					addr_are_equal = 1;
				}
			}
		}
		mrcontact_unref(contact);
	}
	return addr_are_equal;
}


mrcontact_t* mrcontact_new()
{
	mrcontact_t* ths = NULL;

	if( (ths=calloc(1, sizeof(mrcontact_t)))==NULL ) {
		exit(19); /* cannot allocate little memory, unrecoverable error */
	}

	return ths;
}


void mrcontact_unref(mrcontact_t* ths)
{
	if( ths==NULL ) {
		return;
	}

	mrcontact_empty(ths);
	free(ths);
}


void mrcontact_empty(mrcontact_t* ths)
{
	if( ths == NULL ) {
		return;
	}

	ths->m_id = 0;

	free(ths->m_name); /* it is safe to call free(NULL) */
	ths->m_name = NULL;

	free(ths->m_authname);
	ths->m_authname = NULL;

	free(ths->m_addr);
	ths->m_addr = NULL;

	ths->m_origin = 0;
	ths->m_blocked = 0;
}

