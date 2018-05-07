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
#include "mrapeerstate.h"
#include "mraheader.h"
#include "mrhash.h"


/*******************************************************************************
 * mrapeerstate_t represents the state of an Autocrypt peer - Load/save
 ******************************************************************************/


static void mrapeerstate_empty(mrapeerstate_t* ths)
{
	if( ths == NULL ) {
		return;
	}

	ths->m_last_seen           = 0;
	ths->m_last_seen_autocrypt = 0;
	ths->m_prefer_encrypt      = 0;
	ths->m_to_save             = 0;

	free(ths->m_addr);
	ths->m_addr = NULL;

	free(ths->m_public_key_fingerprint);
	ths->m_public_key_fingerprint = NULL;

	free(ths->m_gossip_key_fingerprint);
	ths->m_gossip_key_fingerprint = NULL;

	ths->m_public_key_verified = MRV_NOT_VERIFIED;
	ths->m_gossip_key_verified = MRV_NOT_VERIFIED;

	if( ths->m_public_key ) {
		mrkey_unref(ths->m_public_key);
		ths->m_public_key = NULL;
	}

	ths->m_gossip_timestamp = 0;

	if( ths->m_gossip_key ) {
		mrkey_unref(ths->m_gossip_key);
		ths->m_gossip_key = NULL;
	}

	ths->m_degrade_event = 0;
}


static void mrapeerstate_set_from_stmt__(mrapeerstate_t* peerstate, sqlite3_stmt* stmt)
{
	#define PEERSTATE_FIELDS "addr, last_seen, last_seen_autocrypt, prefer_encrypted, public_key, gossip_timestamp, gossip_key, public_key_fingerprint, gossip_key_fingerprint, public_key_verified, gossip_key_verified"
	peerstate->m_addr                = safe_strdup((char*)sqlite3_column_text  (stmt, 0));
	peerstate->m_last_seen           =                    sqlite3_column_int64 (stmt, 1);
	peerstate->m_last_seen_autocrypt =                    sqlite3_column_int64 (stmt, 2);
	peerstate->m_prefer_encrypt      =                    sqlite3_column_int   (stmt, 3);
	#define PUBLIC_KEY_COL                                                      4
	peerstate->m_gossip_timestamp    =                    sqlite3_column_int   (stmt, 5);
	#define GOSSIP_KEY_COL                                                      6
	peerstate->m_public_key_fingerprint = safe_strdup((char*)sqlite3_column_text  (stmt, 7));
	peerstate->m_gossip_key_fingerprint = safe_strdup((char*)sqlite3_column_text  (stmt, 8));
	peerstate->m_public_key_verified =                    sqlite3_column_int   (stmt, 9);
	peerstate->m_gossip_key_verified =                    sqlite3_column_int   (stmt,10);

	if( sqlite3_column_type(stmt, PUBLIC_KEY_COL)!=SQLITE_NULL ) {
		peerstate->m_public_key = mrkey_new();
		mrkey_set_from_stmt(peerstate->m_public_key, stmt, PUBLIC_KEY_COL, MR_PUBLIC);
	}

	if( sqlite3_column_type(stmt, GOSSIP_KEY_COL)!=SQLITE_NULL ) {
		peerstate->m_gossip_key = mrkey_new();
		mrkey_set_from_stmt(peerstate->m_gossip_key, stmt, GOSSIP_KEY_COL, MR_PUBLIC);
	}
}


int mrapeerstate_load_by_addr__(mrapeerstate_t* peerstate, mrsqlite3_t* sql, const char* addr)
{
	int           success = 0;
	sqlite3_stmt* stmt;

	if( peerstate==NULL || sql == NULL || addr == NULL ) {
		return 0;
	}

	mrapeerstate_empty(peerstate);

	stmt = mrsqlite3_predefine__(sql, SELECT_fields_FROM_acpeerstates_WHERE_addr,
		"SELECT " PEERSTATE_FIELDS
		 " FROM acpeerstates "
		 " WHERE addr=? COLLATE NOCASE;");
	sqlite3_bind_text(stmt, 1, addr, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		goto cleanup;
	}
	mrapeerstate_set_from_stmt__(peerstate, stmt);

	success = 1;

cleanup:
	return success;
}


int mrapeerstate_load_by_fingerprint__(mrapeerstate_t* peerstate, mrsqlite3_t* sql, const char* fingerprint)
{
	int           success = 0;
	sqlite3_stmt* stmt;

	if( peerstate==NULL || sql == NULL || fingerprint == NULL ) {
		return 0;
	}

	mrapeerstate_empty(peerstate);

	stmt = mrsqlite3_predefine__(sql, SELECT_fields_FROM_acpeerstates_WHERE_fingerprint,
		"SELECT " PEERSTATE_FIELDS
		 " FROM acpeerstates "
		 " WHERE public_key_fingerprint=? COLLATE NOCASE "
		 "    OR gossip_key_fingerprint=? COLLATE NOCASE "
		 " ORDER BY public_key_fingerprint=? DESC;"); // if for, any reasons, different peers have the same key, prefer the peer with the correct public key. should not happen, however.
	sqlite3_bind_text(stmt, 1, fingerprint, -1, SQLITE_STATIC);
	sqlite3_bind_text(stmt, 2, fingerprint, -1, SQLITE_STATIC);
	sqlite3_bind_text(stmt, 3, fingerprint, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		goto cleanup;
	}
	mrapeerstate_set_from_stmt__(peerstate, stmt);

	success = 1;

cleanup:
	return success;
}


int mrapeerstate_save_to_db__(const mrapeerstate_t* ths, mrsqlite3_t* sql, int create)
{
	int           success = 0;
	sqlite3_stmt* stmt;

	if( ths==NULL || sql==NULL || ths->m_addr==NULL ) {
		return 0;
	}

	if( create ) {
		stmt = mrsqlite3_predefine__(sql, INSERT_INTO_acpeerstates_a, "INSERT INTO acpeerstates (addr) VALUES(?);");
		sqlite3_bind_text(stmt, 1, ths->m_addr, -1, SQLITE_STATIC);
		sqlite3_step(stmt);
	}

	if( (ths->m_to_save&MRA_SAVE_ALL) || create )
	{
		stmt = mrsqlite3_predefine__(sql, UPDATE_acpeerstates_SET_lcpp_WHERE_a,
			"UPDATE acpeerstates "
			"   SET last_seen=?, last_seen_autocrypt=?, prefer_encrypted=?, "
			"       public_key=?, gossip_timestamp=?, gossip_key=?, public_key_fingerprint=?, gossip_key_fingerprint=?, public_key_verified=?, gossip_key_verified=? "
			" WHERE addr=?;");
		sqlite3_bind_int64(stmt, 1, ths->m_last_seen);
		sqlite3_bind_int64(stmt, 2, ths->m_last_seen_autocrypt);
		sqlite3_bind_int64(stmt, 3, ths->m_prefer_encrypt);
		sqlite3_bind_blob (stmt, 4, ths->m_public_key? ths->m_public_key->m_binary : NULL/*results in sqlite3_bind_null()*/, ths->m_public_key? ths->m_public_key->m_bytes : 0, SQLITE_STATIC);
		sqlite3_bind_int64(stmt, 5, ths->m_gossip_timestamp);
		sqlite3_bind_blob (stmt, 6, ths->m_gossip_key? ths->m_gossip_key->m_binary : NULL/*results in sqlite3_bind_null()*/, ths->m_gossip_key? ths->m_gossip_key->m_bytes : 0, SQLITE_STATIC);
		sqlite3_bind_text (stmt, 7, ths->m_public_key_fingerprint, -1, SQLITE_STATIC);
		sqlite3_bind_text (stmt, 8, ths->m_gossip_key_fingerprint, -1, SQLITE_STATIC);
		sqlite3_bind_int  (stmt, 9, ths->m_public_key_verified);
		sqlite3_bind_int  (stmt,10, ths->m_gossip_key_verified);
		sqlite3_bind_text (stmt,11, ths->m_addr, -1, SQLITE_STATIC);
		if( sqlite3_step(stmt) != SQLITE_DONE ) {
			goto cleanup;
		}
	}
	else if( ths->m_to_save&MRA_SAVE_TIMESTAMPS )
	{
		stmt = mrsqlite3_predefine__(sql, UPDATE_acpeerstates_SET_l_WHERE_a,
			"UPDATE acpeerstates SET last_seen=?, last_seen_autocrypt=?, gossip_timestamp=? WHERE addr=?;");
		sqlite3_bind_int64(stmt, 1, ths->m_last_seen);
		sqlite3_bind_int64(stmt, 2, ths->m_last_seen_autocrypt);
		sqlite3_bind_int64(stmt, 3, ths->m_gossip_timestamp);
		sqlite3_bind_text (stmt, 4, ths->m_addr, -1, SQLITE_STATIC);
		if( sqlite3_step(stmt) != SQLITE_DONE ) {
			goto cleanup;
		}
	}

	success = 1;

cleanup:
	return success;
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


mrapeerstate_t* mrapeerstate_new(mrmailbox_t* mailbox)
{
	mrapeerstate_t* ths = NULL;

	if( (ths=calloc(1, sizeof(mrapeerstate_t)))==NULL ) {
		exit(43); /* cannot allocate little memory, unrecoverable error */
	}

	ths->m_mailbox = mailbox;

	return ths;
}


void mrapeerstate_unref(mrapeerstate_t* ths)
{
	if( ths==NULL ) {
		return;
	}

	free(ths->m_addr);
	mrkey_unref(ths->m_public_key);
	mrkey_unref(ths->m_gossip_key);
	free(ths);
}


/**
 * Render an Autocrypt-Gossip header value.  The contained key is either
 * m_public_key or m_gossip_key if m_public_key is NULL.
 *
 * @memberof mrapeerstate_t
 *
 * @param peerstate The peerstate object.
 *
 * @return String that can be be used directly in an `Autocrypt-Gossip:` statement,
 *     `Autocrypt-Gossip:` is _not_ included in the returned string. If there
 *     is not key for the peer that can be gossiped, NULL is returned.
 */
char* mrapeerstate_render_gossip_header(const mrapeerstate_t* peerstate, int min_verified)
{
	char*        ret = NULL;
	mraheader_t* autocryptheader = mraheader_new();

	if( peerstate == NULL || peerstate->m_addr == NULL ) {
		goto cleanup;
	}

	autocryptheader->m_prefer_encrypt = MRA_PE_NOPREFERENCE; /* the spec says, we SHOULD NOT gossip this flag */
	autocryptheader->m_addr           = safe_strdup(peerstate->m_addr);
	autocryptheader->m_public_key     = mrkey_ref(mrapeerstate_peek_key(peerstate, min_verified)); /* may be NULL */

	ret = mraheader_render(autocryptheader);

cleanup:
	mraheader_unref(autocryptheader);
	return ret;
}


/**
 * Return either m_public_key or m_gossip_key if m_public_key is null or not verified.
 * The function does not check if the keys are valid but the caller can assume
 * the returned key has data.
 *
 * This function does not do the Autocrypt encryption recommendation; it just
 * returns a key that can be used.
 *
 * @memberof mrapeerstate_t
 *
 * @param peerstate The peerstate object.
 * @param min_verified The minimal verification criterion the key should match.
 *     Typically either MRV_NOT_VERIFIED (0) if there is no need for the key being verified
 *     or MRV_BIDIRECTIONAL (2) for bidirectional verification requirement.
 *
 * @return m_public_key or m_gossip_key, NULL if nothing is available.
 *     the returned pointer MUST NOT be unref()'d.
 */
mrkey_t* mrapeerstate_peek_key(const mrapeerstate_t* peerstate, int min_verified)
{
	if(  peerstate == NULL
	 || (peerstate->m_public_key && (peerstate->m_public_key->m_binary==NULL || peerstate->m_public_key->m_bytes<=0))
	 || (peerstate->m_gossip_key && (peerstate->m_gossip_key->m_binary==NULL || peerstate->m_gossip_key->m_bytes<=0)) ) {
		return NULL;
	}

	if( min_verified == MRV_BIDIRECTIONAL
	 && peerstate->m_public_key_verified == MRV_BIDIRECTIONAL
	 && peerstate->m_gossip_key_verified == MRV_BIDIRECTIONAL  )
	{
		// have two verified keys, use the key that is newer
		return peerstate->m_gossip_timestamp > peerstate->m_last_seen_autocrypt?
			peerstate->m_gossip_key : peerstate->m_public_key;
	}

	if( peerstate->m_public_key && peerstate->m_public_key_verified>=min_verified )
	{
		return peerstate->m_public_key;
	}

	if( peerstate->m_gossip_key && peerstate->m_gossip_key_verified>=min_verified )
	{
		return peerstate->m_gossip_key;
	}

	return NULL; // no key with the desired verification available
}


/*******************************************************************************
 * Change state
 ******************************************************************************/


int mrapeerstate_init_from_header(mrapeerstate_t* ths, const mraheader_t* header, time_t message_time)
{
	if( ths == NULL || header == NULL ) {
		return 0;
	}

	mrapeerstate_empty(ths);
	ths->m_addr                = safe_strdup(header->m_addr);
	ths->m_last_seen           = message_time;
	ths->m_last_seen_autocrypt = message_time;
	ths->m_to_save             = MRA_SAVE_ALL;
	ths->m_prefer_encrypt      = header->m_prefer_encrypt;

	ths->m_public_key = mrkey_new();
	mrkey_set_from_key(ths->m_public_key, header->m_public_key);
	mrapeerstate_recalc_fingerprint(ths);

	return 1;
}


int mrapeerstate_init_from_gossip(mrapeerstate_t* peerstate, const mraheader_t* gossip_header, time_t message_time)
{
	if( peerstate == NULL || gossip_header == NULL ) {
		return 0;
	}

	mrapeerstate_empty(peerstate);
	peerstate->m_addr                = safe_strdup(gossip_header->m_addr);
	peerstate->m_gossip_timestamp    = message_time;
	peerstate->m_to_save             = MRA_SAVE_ALL;

	peerstate->m_gossip_key = mrkey_new();
	mrkey_set_from_key(peerstate->m_gossip_key, gossip_header->m_public_key);
	mrapeerstate_recalc_fingerprint(peerstate);

	return 1;
}


int mrapeerstate_degrade_encryption(mrapeerstate_t* ths, time_t message_time)
{
	if( ths==NULL ) {
		return 0;
	}

	if( ths->m_prefer_encrypt == MRA_PE_MUTUAL ) {
		ths->m_degrade_event |= MRA_DE_ENCRYPTION_PAUSED;
	}

	ths->m_prefer_encrypt = MRA_PE_RESET;
	ths->m_last_seen      = message_time; /*last_seen_autocrypt is not updated as there was not Autocrypt:-header seen*/
	ths->m_to_save        = MRA_SAVE_ALL;

	return 1;
}


void mrapeerstate_apply_header(mrapeerstate_t* ths, const mraheader_t* header, time_t message_time)
{
	if( ths==NULL || header==NULL
	 || ths->m_addr==NULL
	 || header->m_addr==NULL || header->m_public_key->m_binary==NULL
	 || strcasecmp(ths->m_addr, header->m_addr)!=0 ) {
		return;
	}

	if( message_time > ths->m_last_seen_autocrypt )
	{
		ths->m_last_seen           = message_time;
		ths->m_last_seen_autocrypt = message_time;
		ths->m_to_save             |= MRA_SAVE_TIMESTAMPS;

		if( (header->m_prefer_encrypt==MRA_PE_MUTUAL || header->m_prefer_encrypt==MRA_PE_NOPREFERENCE) /*this also switches from MRA_PE_RESET to MRA_PE_NOPREFERENCE, which is just fine as the function is only called _if_ the Autocrypt:-header is preset at all */
		 &&  header->m_prefer_encrypt != ths->m_prefer_encrypt )
		{
			if( ths->m_prefer_encrypt == MRA_PE_MUTUAL && header->m_prefer_encrypt != MRA_PE_MUTUAL ) {
				ths->m_degrade_event |= MRA_DE_ENCRYPTION_PAUSED;
			}

			ths->m_prefer_encrypt = header->m_prefer_encrypt;
			ths->m_to_save |= MRA_SAVE_ALL;
		}

		if( ths->m_public_key == NULL ) {
			ths->m_public_key = mrkey_new();
		}

		if( !mrkey_equals(ths->m_public_key, header->m_public_key) )
		{
			mrkey_set_from_key(ths->m_public_key, header->m_public_key);
			mrapeerstate_recalc_fingerprint(ths);
			ths->m_to_save |= MRA_SAVE_ALL;
		}
	}
}


void mrapeerstate_apply_gossip(mrapeerstate_t* peerstate, const mraheader_t* gossip_header, time_t message_time)
{
	if( peerstate==NULL || gossip_header==NULL
	 || peerstate->m_addr==NULL
	 || gossip_header->m_addr==NULL || gossip_header->m_public_key->m_binary==NULL
	 || strcasecmp(peerstate->m_addr, gossip_header->m_addr)!=0 ) {
		return;
	}

	if( message_time > peerstate->m_gossip_timestamp )
	{
		peerstate->m_gossip_timestamp    = message_time;
		peerstate->m_to_save             |= MRA_SAVE_TIMESTAMPS;

		if( peerstate->m_gossip_key == NULL ) {
			peerstate->m_gossip_key = mrkey_new();
		}

		if( !mrkey_equals(peerstate->m_gossip_key, gossip_header->m_public_key) )
		{
			mrkey_set_from_key(peerstate->m_gossip_key, gossip_header->m_public_key);
			mrapeerstate_recalc_fingerprint(peerstate);
			peerstate->m_to_save |= MRA_SAVE_ALL;
		}
	}
}


/*
 * Recalculate the fingerprints for the keys.
 *
 * If the fingerprint has changed, the verified-state is reset.
 *
 * An explicit call to this function from outside this class is only needed
 * for database updates; the mrapeerstate_init_*() and mrapeerstate_apply_*()
 * functions update the fingerprint automatically as needed.
 */
int mrapeerstate_recalc_fingerprint(mrapeerstate_t* peerstate)
{
	int            success = 0;
	char*          old_public_fingerprint = NULL, *old_gossip_fingerprint = NULL;
	int            has_old_verified_key = (mrapeerstate_peek_key(peerstate, MRV_BIDIRECTIONAL)!=NULL);

	if( peerstate == NULL ) {
		goto cleanup;
	}

	if( peerstate->m_public_key )
	{
		old_public_fingerprint = peerstate->m_public_key_fingerprint;
		peerstate->m_public_key_fingerprint = mrkey_get_fingerprint(peerstate->m_public_key); /* returns the empty string for errors, however, this should be saved as well as it represents an erroneous key */

		if( old_public_fingerprint == NULL
		 || old_public_fingerprint[0] == 0
		 || peerstate->m_public_key_fingerprint == NULL
		 || peerstate->m_public_key_fingerprint[0] == 0
		 || strcasecmp(old_public_fingerprint, peerstate->m_public_key_fingerprint) != 0 )
		{
			peerstate->m_to_save  |= MRA_SAVE_ALL;

			peerstate->m_public_key_verified = MRV_NOT_VERIFIED;

			if( old_public_fingerprint && old_public_fingerprint[0] ) { // no degrade event when we recveive just the initial fingerprint
				peerstate->m_degrade_event |= MRA_DE_FINGERPRINT_CHANGED;
			}
		}
	}

	if( peerstate->m_gossip_key )
	{
		old_gossip_fingerprint = peerstate->m_gossip_key_fingerprint;
		peerstate->m_gossip_key_fingerprint = mrkey_get_fingerprint(peerstate->m_gossip_key); /* returns the empty string for errors, however, this should be saved as well as it represents an erroneous key */

		if( old_gossip_fingerprint == NULL
		 || old_gossip_fingerprint[0] == 0
		 || peerstate->m_gossip_key_fingerprint == NULL
		 || peerstate->m_gossip_key_fingerprint[0] == 0
		 || strcasecmp(old_gossip_fingerprint, peerstate->m_gossip_key_fingerprint) != 0 )
		{
			peerstate->m_to_save  |= MRA_SAVE_ALL;

			peerstate->m_gossip_key_verified = MRV_NOT_VERIFIED;

			if( old_gossip_fingerprint && old_gossip_fingerprint[0] ) { // no degrade event when we recveive just the initial fingerprint
				peerstate->m_degrade_event |= MRA_DE_FINGERPRINT_CHANGED;
			}
		}
	}

	if( has_old_verified_key
	 && (mrapeerstate_peek_key(peerstate, MRV_BIDIRECTIONAL)==NULL) ) {
		peerstate->m_degrade_event |= MRA_DE_VERIFICATION_LOST;
	}

	success = 1;

cleanup:
	free(old_public_fingerprint);
	free(old_gossip_fingerprint);
	return success;
}


/**
 * If the fingerprint of the peerstate equals the given fingerprint, the
 * peerstate is marked as being verified.
 *
 * The given fingerprint is present only to ensure the peer has not changed
 * between fingerprint comparison and calling this function.
 *
 * @memberof mrapeerstate_t
 *
 * @param peerstate The peerstate object.
 * @param which_key Which key should be marked as being verified? MRA_GOSSIP_KEY (1) or MRA_PUBLIC_KEY (2)
 * @param fingerprint Fingerprint expected in the object
 * @param verified MRV_SIMPLE (1): we verified the contact, MRV_BIDIRECTIONAL (2): contact verfied in both directions
 *
 * @return 1=the given fingerprint is equal to the peer's fingerprint and
 *     the verified-state is set; you should call mrapeerstate_save_to_db__()
 *     to permanently store this state.
 *     0=the given fingerprint is not eqial to the peer's fingerprint,
 *     verified-state not changed.
 */
int mrapeerstate_set_verified(mrapeerstate_t* peerstate, int which_key, const char* fingerprint, int verified)
{
	int success = 0;

	if( peerstate == NULL
	 || (which_key!=MRA_GOSSIP_KEY && which_key!=MRA_PUBLIC_KEY)
	 || (verified!=MRV_SIMPLE && verified!=MRV_BIDIRECTIONAL) ) {
		goto cleanup;
	}

	if( which_key == MRA_PUBLIC_KEY
	 && peerstate->m_public_key_fingerprint != NULL
	 && peerstate->m_public_key_fingerprint[0] != 0
	 && fingerprint[0] != 0
	 && strcasecmp(peerstate->m_public_key_fingerprint, fingerprint) == 0 )
	{
		peerstate->m_to_save            |= MRA_SAVE_ALL;
		peerstate->m_public_key_verified = verified;
		success                          = 1;
	}

	if( which_key == MRA_GOSSIP_KEY
	 && peerstate->m_gossip_key_fingerprint != NULL
	 && peerstate->m_gossip_key_fingerprint[0] != 0
	 && fingerprint[0] != 0
	 && strcasecmp(peerstate->m_gossip_key_fingerprint, fingerprint) == 0 )
	{
		peerstate->m_to_save            |= MRA_SAVE_ALL;
		peerstate->m_gossip_key_verified = verified;
		success                          = 1;
	}

cleanup:
	return success;
}


int mrapeerstate_has_verified_key(const mrapeerstate_t* peerstate, const mrhash_t* fingerprints)
{
	if( peerstate == NULL || fingerprints == NULL ) {
		return 0;
	}

	if( peerstate->m_public_key_verified >= MRV_BIDIRECTIONAL
	 && peerstate->m_public_key_fingerprint
	 && mrhash_find_str(fingerprints, peerstate->m_public_key_fingerprint) ) {
		return 1;
	}

	if( peerstate->m_gossip_key_verified >= MRV_BIDIRECTIONAL
	 && peerstate->m_gossip_key_fingerprint
	 && mrhash_find_str(fingerprints, peerstate->m_gossip_key_fingerprint) ) {
		return 1;
	}

	return 0;
}
