#include "dc_context.h"
#include "dc_apeerstate.h"
#include "dc_aheader.h"
#include "dc_hash.h"


/*******************************************************************************
 * dc_apeerstate_t represents the state of an Autocrypt peer - Load/save
 ******************************************************************************/


static void dc_apeerstate_empty(dc_apeerstate_t* peerstate)
{
	if (peerstate==NULL) {
		return;
	}

	peerstate->last_seen           = 0;
	peerstate->last_seen_autocrypt = 0;
	peerstate->prefer_encrypt      = 0;
	peerstate->to_save             = 0;

	free(peerstate->addr);
	peerstate->addr = NULL;

	free(peerstate->public_key_fingerprint);
	peerstate->public_key_fingerprint = NULL;

	free(peerstate->gossip_key_fingerprint);
	peerstate->gossip_key_fingerprint = NULL;

	free(peerstate->verified_key_fingerprint);
	peerstate->verified_key_fingerprint = NULL;

	dc_key_unref(peerstate->public_key);
	peerstate->public_key = NULL;

	peerstate->gossip_timestamp = 0;

	dc_key_unref(peerstate->gossip_key);
	peerstate->gossip_key = NULL;

	dc_key_unref(peerstate->verified_key);
	peerstate->verified_key = NULL;

	peerstate->degrade_event = 0;
}


static void dc_apeerstate_set_from_stmt(dc_apeerstate_t* peerstate, sqlite3_stmt* stmt)
{
	#define PEERSTATE_FIELDS "addr, last_seen, last_seen_autocrypt, prefer_encrypted, public_key, gossip_timestamp, gossip_key, public_key_fingerprint, gossip_key_fingerprint, verified_key, verified_key_fingerprint"
	peerstate->addr                     = dc_strdup((char*)sqlite3_column_text  (stmt, 0));
	peerstate->last_seen                =                  sqlite3_column_int64 (stmt, 1);
	peerstate->last_seen_autocrypt      =                  sqlite3_column_int64 (stmt, 2);
	peerstate->prefer_encrypt           =                  sqlite3_column_int   (stmt, 3);
	#define PUBLIC_KEY_COL                                                               4
	peerstate->gossip_timestamp         =                  sqlite3_column_int   (stmt, 5);
	#define GOSSIP_KEY_COL                                                               6
	peerstate->public_key_fingerprint   = dc_strdup((char*)sqlite3_column_text  (stmt, 7));
	peerstate->gossip_key_fingerprint   = dc_strdup((char*)sqlite3_column_text  (stmt, 8));
	#define VERIFIED_KEY_COL                                                             9
	peerstate->verified_key_fingerprint = dc_strdup((char*)sqlite3_column_text(stmt, 10));

	if (sqlite3_column_type(stmt, PUBLIC_KEY_COL)!=SQLITE_NULL) {
		peerstate->public_key = dc_key_new();
		dc_key_set_from_stmt(peerstate->public_key, stmt, PUBLIC_KEY_COL, DC_KEY_PUBLIC);
	}

	if (sqlite3_column_type(stmt, GOSSIP_KEY_COL)!=SQLITE_NULL) {
		peerstate->gossip_key = dc_key_new();
		dc_key_set_from_stmt(peerstate->gossip_key, stmt, GOSSIP_KEY_COL, DC_KEY_PUBLIC);
	}

	if (sqlite3_column_type(stmt, VERIFIED_KEY_COL)!=SQLITE_NULL) {
		peerstate->verified_key = dc_key_new();
		dc_key_set_from_stmt(peerstate->verified_key, stmt, VERIFIED_KEY_COL, DC_KEY_PUBLIC);
	}
}


int dc_apeerstate_load_by_addr(dc_apeerstate_t* peerstate, dc_sqlite3_t* sql, const char* addr)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;

	if (peerstate==NULL || sql==NULL || addr==NULL) {
		goto cleanup;
	}

	dc_apeerstate_empty(peerstate);

	stmt = dc_sqlite3_prepare(sql,
		"SELECT " PEERSTATE_FIELDS
		 " FROM acpeerstates "
		 " WHERE addr=? COLLATE NOCASE;");
	sqlite3_bind_text(stmt, 1, addr, -1, SQLITE_STATIC);
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}
	dc_apeerstate_set_from_stmt(peerstate, stmt);

	success = 1;

cleanup:
	sqlite3_finalize(stmt);
	return success;
}


int dc_apeerstate_load_by_fingerprint(dc_apeerstate_t* peerstate, dc_sqlite3_t* sql, const char* fingerprint)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;

	if (peerstate==NULL || sql==NULL || fingerprint==NULL) {
		goto cleanup;
	}

	dc_apeerstate_empty(peerstate);

	stmt = dc_sqlite3_prepare(sql,
		"SELECT " PEERSTATE_FIELDS
		 " FROM acpeerstates "
		 " WHERE public_key_fingerprint=? COLLATE NOCASE "
		 "    OR gossip_key_fingerprint=? COLLATE NOCASE "
		 " ORDER BY public_key_fingerprint=? DESC;"); // if for, any reasons, different peers have the same key, prefer the peer with the correct public key. should not happen, however.
	sqlite3_bind_text(stmt, 1, fingerprint, -1, SQLITE_STATIC);
	sqlite3_bind_text(stmt, 2, fingerprint, -1, SQLITE_STATIC);
	sqlite3_bind_text(stmt, 3, fingerprint, -1, SQLITE_STATIC);
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}
	dc_apeerstate_set_from_stmt(peerstate, stmt);

	success = 1;

cleanup:
	sqlite3_finalize(stmt);
	return success;
}


int dc_apeerstate_save_to_db(const dc_apeerstate_t* peerstate, dc_sqlite3_t* sql, int create)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;

	if (peerstate==NULL || sql==NULL || peerstate->addr==NULL) {
		return 0;
	}

	if (create) {
		stmt = dc_sqlite3_prepare(sql, "INSERT INTO acpeerstates (addr) VALUES(?);");
		sqlite3_bind_text(stmt, 1, peerstate->addr, -1, SQLITE_STATIC);
		sqlite3_step(stmt);
		sqlite3_finalize(stmt);
		stmt = NULL;
	}

	if ((peerstate->to_save&DC_SAVE_ALL) || create)
	{
		stmt = dc_sqlite3_prepare(sql,
			"UPDATE acpeerstates "
			"   SET last_seen=?, last_seen_autocrypt=?, prefer_encrypted=?, "
			"       public_key=?, gossip_timestamp=?, gossip_key=?, public_key_fingerprint=?, gossip_key_fingerprint=?, verified_key=?, verified_key_fingerprint=? "
			" WHERE addr=?;");
		sqlite3_bind_int64(stmt, 1, peerstate->last_seen);
		sqlite3_bind_int64(stmt, 2, peerstate->last_seen_autocrypt);
		sqlite3_bind_int64(stmt, 3, peerstate->prefer_encrypt);
		sqlite3_bind_blob (stmt, 4, peerstate->public_key? peerstate->public_key->binary : NULL/*results in sqlite3_bind_null()*/, peerstate->public_key? peerstate->public_key->bytes : 0, SQLITE_STATIC);
		sqlite3_bind_int64(stmt, 5, peerstate->gossip_timestamp);
		sqlite3_bind_blob (stmt, 6, peerstate->gossip_key? peerstate->gossip_key->binary : NULL/*results in sqlite3_bind_null()*/, peerstate->gossip_key? peerstate->gossip_key->bytes : 0, SQLITE_STATIC);
		sqlite3_bind_text (stmt, 7, peerstate->public_key_fingerprint, -1, SQLITE_STATIC);
		sqlite3_bind_text (stmt, 8, peerstate->gossip_key_fingerprint, -1, SQLITE_STATIC);
		sqlite3_bind_blob (stmt, 9, peerstate->verified_key? peerstate->verified_key->binary : NULL/*results in sqlite3_bind_null()*/, peerstate->verified_key? peerstate->verified_key->bytes : 0, SQLITE_STATIC);
		sqlite3_bind_text (stmt,10, peerstate->verified_key_fingerprint, -1, SQLITE_STATIC);
		sqlite3_bind_text (stmt,11, peerstate->addr, -1, SQLITE_STATIC);
		if (sqlite3_step(stmt)!=SQLITE_DONE) {
			goto cleanup;
		}
		sqlite3_finalize(stmt);
		stmt = NULL;
	}
	else if (peerstate->to_save&DC_SAVE_TIMESTAMPS)
	{
		stmt = dc_sqlite3_prepare(sql,
			"UPDATE acpeerstates SET last_seen=?, last_seen_autocrypt=?, gossip_timestamp=? WHERE addr=?;");
		sqlite3_bind_int64(stmt, 1, peerstate->last_seen);
		sqlite3_bind_int64(stmt, 2, peerstate->last_seen_autocrypt);
		sqlite3_bind_int64(stmt, 3, peerstate->gossip_timestamp);
		sqlite3_bind_text (stmt, 4, peerstate->addr, -1, SQLITE_STATIC);
		if (sqlite3_step(stmt)!=SQLITE_DONE) {
			goto cleanup;
		}
		sqlite3_finalize(stmt);
		stmt = NULL;
	}

	success = 1;

cleanup:
	sqlite3_finalize(stmt);
	return success;
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


dc_apeerstate_t* dc_apeerstate_new(dc_context_t* context)
{
	dc_apeerstate_t* peerstate = NULL;

	if ((peerstate=calloc(1, sizeof(dc_apeerstate_t)))==NULL) {
		exit(43); /* cannot allocate little memory, unrecoverable error */
	}

	peerstate->context = context;

	return peerstate;
}


void dc_apeerstate_unref(dc_apeerstate_t* peerstate)
{
	dc_apeerstate_empty(peerstate);
	free(peerstate);
}


/**
 * Render an Autocrypt-Gossip header value.  The contained key is either
 * public_key or gossip_key if public_key is NULL.
 *
 * @memberof dc_apeerstate_t
 * @param peerstate The peerstate object.
 * @return String that can be be used directly in an `Autocrypt-Gossip:` statement,
 *     `Autocrypt-Gossip:` is _not_ included in the returned string. If there
 *     is not key for the peer that can be gossiped, NULL is returned.
 */
char* dc_apeerstate_render_gossip_header(const dc_apeerstate_t* peerstate, int min_verified)
{
	char*         ret = NULL;
	dc_aheader_t* autocryptheader = dc_aheader_new();

	if (peerstate==NULL || peerstate->addr==NULL) {
		goto cleanup;
	}

	autocryptheader->prefer_encrypt = DC_PE_NOPREFERENCE; /* the spec says, we SHOULD NOT gossip this flag */
	autocryptheader->addr           = dc_strdup(peerstate->addr);
	autocryptheader->public_key     = dc_key_ref(dc_apeerstate_peek_key(peerstate, min_verified)); /* may be NULL */

	ret = dc_aheader_render(autocryptheader);

cleanup:
	dc_aheader_unref(autocryptheader);
	return ret;
}


/**
 * Return either public_key or gossip_key if public_key is null or not verified.
 * The function does not check if the keys are valid but the caller can assume
 * the returned key has data.
 *
 * This function does not do the Autocrypt encryption recommendation; it just
 * returns a key that can be used.
 *
 * @memberof dc_apeerstate_t
 * @param peerstate The peerstate object.
 * @param min_verified The minimal verification criterion the key should match.
 *     Typically either DC_NOT_VERIFIED (0) if there is no need for the key being verified
 *     or DC_BIDIRECT_VERIFIED (2) for bidirectional verification requirement.
 * @return public_key or gossip_key, NULL if nothing is available.
 *     the returned pointer MUST NOT be unref()'d.
 */
dc_key_t* dc_apeerstate_peek_key(const dc_apeerstate_t* peerstate, int min_verified)
{
	if ( peerstate==NULL
	 || (peerstate->public_key && (peerstate->public_key->binary==NULL || peerstate->public_key->bytes<=0))
	 || (peerstate->gossip_key && (peerstate->gossip_key->binary==NULL || peerstate->gossip_key->bytes<=0))
	 || (peerstate->verified_key && (peerstate->verified_key->binary==NULL || peerstate->verified_key->bytes<=0))) {
		return NULL;
	}

	if (min_verified)
	{
		return peerstate->verified_key;
	}

	if (peerstate->public_key)
	{
		return peerstate->public_key;
	}

	return peerstate->gossip_key;
}


/*******************************************************************************
 * Change state
 ******************************************************************************/


int dc_apeerstate_init_from_header(dc_apeerstate_t* peerstate, const dc_aheader_t* header, time_t message_time)
{
	if (peerstate==NULL || header==NULL) {
		return 0;
	}

	dc_apeerstate_empty(peerstate);
	peerstate->addr                = dc_strdup(header->addr);
	peerstate->last_seen           = message_time;
	peerstate->last_seen_autocrypt = message_time;
	peerstate->to_save             = DC_SAVE_ALL;
	peerstate->prefer_encrypt      = header->prefer_encrypt;

	peerstate->public_key = dc_key_new();
	dc_key_set_from_key(peerstate->public_key, header->public_key);
	dc_apeerstate_recalc_fingerprint(peerstate);

	return 1;
}


int dc_apeerstate_init_from_gossip(dc_apeerstate_t* peerstate, const dc_aheader_t* gossip_header, time_t message_time)
{
	if (peerstate==NULL || gossip_header==NULL) {
		return 0;
	}

	dc_apeerstate_empty(peerstate);
	peerstate->addr                = dc_strdup(gossip_header->addr);
	peerstate->gossip_timestamp    = message_time;
	peerstate->to_save             = DC_SAVE_ALL;

	peerstate->gossip_key = dc_key_new();
	dc_key_set_from_key(peerstate->gossip_key, gossip_header->public_key);
	dc_apeerstate_recalc_fingerprint(peerstate);

	return 1;
}


int dc_apeerstate_degrade_encryption(dc_apeerstate_t* peerstate, time_t message_time)
{
	if (peerstate==NULL) {
		return 0;
	}

	if (peerstate->prefer_encrypt==DC_PE_MUTUAL) {
		peerstate->degrade_event |= DC_DE_ENCRYPTION_PAUSED;
	}

	peerstate->prefer_encrypt = DC_PE_RESET;
	peerstate->last_seen      = message_time; /*last_seen_autocrypt is not updated as there was not Autocrypt:-header seen*/
	peerstate->to_save        = DC_SAVE_ALL;

	return 1;
}


void dc_apeerstate_apply_header(dc_apeerstate_t* peerstate, const dc_aheader_t* header, time_t message_time)
{
	if (peerstate==NULL || header==NULL
	 || peerstate->addr==NULL
	 || header->addr==NULL || header->public_key->binary==NULL
	 || strcasecmp(peerstate->addr, header->addr)!=0) {
		return;
	}

	if (message_time > peerstate->last_seen_autocrypt)
	{
		peerstate->last_seen           = message_time;
		peerstate->last_seen_autocrypt = message_time;
		peerstate->to_save             |= DC_SAVE_TIMESTAMPS;

		if ((header->prefer_encrypt==DC_PE_MUTUAL || header->prefer_encrypt==DC_PE_NOPREFERENCE) /*this also switches from DC_PE_RESET to DC_PE_NOPREFERENCE, which is just fine as the function is only called _if_ the Autocrypt:-header is preset at all */
		 &&  header->prefer_encrypt!=peerstate->prefer_encrypt)
		{
			if (peerstate->prefer_encrypt==DC_PE_MUTUAL && header->prefer_encrypt!=DC_PE_MUTUAL) {
				peerstate->degrade_event |= DC_DE_ENCRYPTION_PAUSED;
			}

			peerstate->prefer_encrypt = header->prefer_encrypt;
			peerstate->to_save |= DC_SAVE_ALL;
		}

		if (peerstate->public_key==NULL) {
			peerstate->public_key = dc_key_new();
		}

		if (!dc_key_equals(peerstate->public_key, header->public_key))
		{
			dc_key_set_from_key(peerstate->public_key, header->public_key);
			dc_apeerstate_recalc_fingerprint(peerstate);
			peerstate->to_save |= DC_SAVE_ALL;
		}
	}
}


void dc_apeerstate_apply_gossip(dc_apeerstate_t* peerstate, const dc_aheader_t* gossip_header, time_t message_time)
{
	if (peerstate==NULL || gossip_header==NULL
	 || peerstate->addr==NULL
	 || gossip_header->addr==NULL || gossip_header->public_key->binary==NULL
	 || strcasecmp(peerstate->addr, gossip_header->addr)!=0) {
		return;
	}

	if (message_time > peerstate->gossip_timestamp)
	{
		peerstate->gossip_timestamp    = message_time;
		peerstate->to_save             |= DC_SAVE_TIMESTAMPS;

		if (peerstate->gossip_key==NULL) {
			peerstate->gossip_key = dc_key_new();
		}

		if (!dc_key_equals(peerstate->gossip_key, gossip_header->public_key))
		{
			dc_key_set_from_key(peerstate->gossip_key, gossip_header->public_key);
			dc_apeerstate_recalc_fingerprint(peerstate);
			peerstate->to_save |= DC_SAVE_ALL;
		}
	}
}


/**
 * Recalculate the fingerprints for the keys.
 *
 * If the fingerprint has changed, the verified-state is reset.
 *
 * An explicit call to this function from outside this class is only needed
 * for database updates; the dc_apeerstate_init_*() and dc_apeerstate_apply_*()
 * functions update the fingerprint automatically as needed.
 *
 * @memberof dc_apeerstate_t
 */
int dc_apeerstate_recalc_fingerprint(dc_apeerstate_t* peerstate)
{
	int            success = 0;
	char*          old_public_fingerprint = NULL;
	char*          old_gossip_fingerprint = NULL;

	if (peerstate==NULL) {
		goto cleanup;
	}

	if (peerstate->public_key)
	{
		old_public_fingerprint = peerstate->public_key_fingerprint;
		peerstate->public_key_fingerprint = dc_key_get_fingerprint(peerstate->public_key); /* returns the empty string for errors, however, this should be saved as well as it represents an erroneous key */

		if (old_public_fingerprint==NULL
		 || old_public_fingerprint[0]==0
		 || peerstate->public_key_fingerprint==NULL
		 || peerstate->public_key_fingerprint[0]==0
		 || strcasecmp(old_public_fingerprint, peerstate->public_key_fingerprint)!=0)
		{
			peerstate->to_save  |= DC_SAVE_ALL;

			if (old_public_fingerprint && old_public_fingerprint[0]) { // no degrade event when we recveive just the initial fingerprint
				peerstate->degrade_event |= DC_DE_FINGERPRINT_CHANGED;
			}
		}
	}

	if (peerstate->gossip_key)
	{
		old_gossip_fingerprint = peerstate->gossip_key_fingerprint;
		peerstate->gossip_key_fingerprint = dc_key_get_fingerprint(peerstate->gossip_key); /* returns the empty string for errors, however, this should be saved as well as it represents an erroneous key */

		if (old_gossip_fingerprint==NULL
		 || old_gossip_fingerprint[0]==0
		 || peerstate->gossip_key_fingerprint==NULL
		 || peerstate->gossip_key_fingerprint[0]==0
		 || strcasecmp(old_gossip_fingerprint, peerstate->gossip_key_fingerprint)!=0)
		{
			peerstate->to_save  |= DC_SAVE_ALL;

			if (old_gossip_fingerprint && old_gossip_fingerprint[0]) { // no degrade event when we recveive just the initial fingerprint
				peerstate->degrade_event |= DC_DE_FINGERPRINT_CHANGED;
			}
		}
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
 * @memberof dc_apeerstate_t
 * @param peerstate The peerstate object.
 * @param which_key Which key should be marked as being verified? DC_PS_GOSSIP_KEY (1) or DC_PS_PUBLIC_KEY (2)
 * @param fingerprint Fingerprint expected in the object
 * @param verified DC_BIDIRECT_VERIFIED (2): contact verified in both directions
 * @return 1=the given fingerprint is equal to the peer's fingerprint and
 *     the verified-state is set; you should call dc_apeerstate_save_to_db()
 *     to permanently store this state.
 *     0=the given fingerprint is not eqial to the peer's fingerprint,
 *     verified-state not changed.
 */
int dc_apeerstate_set_verified(dc_apeerstate_t* peerstate, int which_key, const char* fingerprint, int verified)
{
	int success = 0;

	if (peerstate==NULL
	 || (which_key!=DC_PS_GOSSIP_KEY && which_key!=DC_PS_PUBLIC_KEY)
	 || (verified!=DC_BIDIRECT_VERIFIED)) {
		goto cleanup;
	}

	if (which_key==DC_PS_PUBLIC_KEY
	 && peerstate->public_key_fingerprint!=NULL
	 && peerstate->public_key_fingerprint[0]!=0
	 && fingerprint[0]!=0
	 && strcasecmp(peerstate->public_key_fingerprint, fingerprint)==0)
	{
		peerstate->to_save                 |= DC_SAVE_ALL;
		peerstate->verified_key             = dc_key_ref(peerstate->public_key);
		peerstate->verified_key_fingerprint = dc_strdup(peerstate->public_key_fingerprint);
		success                             = 1;
	}

	if (which_key==DC_PS_GOSSIP_KEY
	 && peerstate->gossip_key_fingerprint!=NULL
	 && peerstate->gossip_key_fingerprint[0]!=0
	 && fingerprint[0]!=0
	 && strcasecmp(peerstate->gossip_key_fingerprint, fingerprint)==0)
	{
		peerstate->to_save                 |= DC_SAVE_ALL;
		peerstate->verified_key             = dc_key_ref(peerstate->gossip_key);
		peerstate->verified_key_fingerprint = dc_strdup(peerstate->gossip_key_fingerprint);
		success                             = 1;
	}

cleanup:
	return success;
}


int dc_apeerstate_has_verified_key(const dc_apeerstate_t* peerstate, const dc_hash_t* fingerprints)
{
	if (peerstate==NULL || fingerprints==NULL) {
		return 0;
	}

	if (peerstate->verified_key
	 && peerstate->verified_key_fingerprint
	 && dc_hash_find_str(fingerprints, peerstate->verified_key_fingerprint)) {
		return 1;
	}

	return 0;
}
