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
 * File:    mrpgp.c
 * Purpose: End-to-end-encryption and other cryptographic functions
 *          based upon OpenSSL and BSD's netpgp.
 *
 *******************************************************************************
 *
 * If we want to switch to other encryption engines, here are the functions to
 * be replaced.
 *
 * However, eg. GpgME cannot (easily) be used standalone and GnuPG's licence
 * would not allow the original creator of Delta Chat to release a proprietary
 * version, which, however, is required for the Apple store. (NB: the original
 * creator is the only person who could do this, a normal licensee is not
 * allowed to do so at all)
 *
 * So, we do not see a simple alternative - but everyone is welcome to implement
 * one :-)
 *
 ******************************************************************************/


#include <string.h>
#include <openssl/ssl.h>
#include <openssl/rand.h>
#include <openssl/rsa.h>
#include <openssl/evp.h>
#include <netpgp-extra.h>
#include "mrmailbox.h"
#include "mrkey.h"
#include "mrkeyring.h"
#include "mrpgp.h"
#include "mrtools.h"


static pgp_io_t s_io;


void mrpgp_init(mrmailbox_t* mailbox)
{
	SSL_library_init(); /* older, but more compatible function, simply defined as OPENSSL_init_ssl().
						SSL_library_init() should be called from the main thread before OpenSSL is called from other threads.
	                    libEtPan may call SSL_library_init() again later, however, this should be no problem.
	                    SSL_library_init() always returns "1", so it is safe to discard the return value */

	/* setup i/o structure */
	memset(&s_io, 0, sizeof(pgp_io_t));
	s_io.outs = stdout;
	s_io.errs = stderr;
	s_io.res  = stderr;
}


void mrpgp_exit(mrmailbox_t* mailbox)
{
}


void mrpgp_rand_seed(mrmailbox_t* mailbox, const void* buf, size_t bytes)
{
	if( buf == NULL || bytes <= 0 ) {
		return;
	}

	RAND_seed(buf, bytes);
}


/*******************************************************************************
 * Key generatation
 ******************************************************************************/


static unsigned add_key_prefs(pgp_create_sig_t *sig)
{
    /* similar to pgp_add_key_prefs(), Mimic of GPG default settings, limited to supported algos */
    return
        /* Symmetric algo prefs */
        pgp_write_ss_header(sig->output, 6, PGP_PTAG_SS_PREFERRED_SKA) &&
        pgp_write_scalar(sig->output, PGP_SA_AES_256, 1) &&
        pgp_write_scalar(sig->output, PGP_SA_AES_128, 1) &&
        pgp_write_scalar(sig->output, PGP_SA_CAST5, 1) &&
        pgp_write_scalar(sig->output, PGP_SA_TRIPLEDES, 1) &&
        pgp_write_scalar(sig->output, PGP_SA_IDEA, 1) &&

        /* Hash algo prefs, the first algo is the preferred algo */
        pgp_write_ss_header(sig->output, 6, PGP_PTAG_SS_PREFERRED_HASH) &&
        pgp_write_scalar(sig->output, PGP_HASH_SHA256, 1) &&
        pgp_write_scalar(sig->output, PGP_HASH_SHA384, 1) &&
        pgp_write_scalar(sig->output, PGP_HASH_SHA512, 1) &&
        pgp_write_scalar(sig->output, PGP_HASH_SHA224, 1) &&
        pgp_write_scalar(sig->output, PGP_HASH_SHA1, 1) && /* Edit for Autocrypt/Delta Chat: due to the weak SHA1, it should not be preferred */

        /* Compression algo prefs */
        pgp_write_ss_header(sig->output, 2/*1+number of following items*/, PGP_PTAG_SS_PREF_COMPRESS) &&
        pgp_write_scalar(sig->output, PGP_C_ZLIB, 1) /*&& -- not sure if Delta Chat will support bzip2 on all platforms, however, this is not that important as typical files are compressed themselves and text is not that big
        pgp_write_scalar(sig->output, PGP_C_BZIP2, 1) -- if you re-enable this, do not forget to modifiy the header count*/;
}


static void add_selfsigned_userid(pgp_key_t *skey, pgp_key_t *pkey, const uint8_t *userid, time_t key_expiry)
{
	/* similar to pgp_add_selfsigned_userid() which, however, uses different key flags */
	pgp_create_sig_t	*sig;
	pgp_subpacket_t	 sigpacket;
	pgp_memory_t		*mem_sig = NULL;
	pgp_output_t		*sigoutput = NULL;

	/* create sig for this pkt */
	sig = pgp_create_sig_new();
	pgp_sig_start_key_sig(sig, &skey->key.seckey.pubkey, NULL, userid, PGP_CERT_POSITIVE);

	pgp_add_creation_time(sig, time(NULL));
	pgp_add_key_expiration_time(sig, key_expiry);
	pgp_add_primary_userid(sig, 1);
	pgp_add_key_flags(sig, PGP_KEYFLAG_SIGN_DATA|PGP_KEYFLAG_CERT_KEYS);
	add_key_prefs(sig);
	pgp_add_key_features(sig); /* will add 0x01 - modification detection */

	pgp_end_hashed_subpkts(sig);

	pgp_add_issuer_keyid(sig, skey->pubkeyid); /* the issuer keyid is not hashed by definition */

	pgp_setup_memory_write(&sigoutput, &mem_sig, 128);
	pgp_write_sig(sigoutput, sig, &skey->key.seckey.pubkey, &skey->key.seckey);

	/* add this packet to key */
	sigpacket.length = pgp_mem_len(mem_sig);
	sigpacket.raw = pgp_mem_data(mem_sig);

	/* add user id and signature to key */
	pgp_update_userid(skey, userid, &sigpacket, &sig->sig.info);
	if(pkey) {
		pgp_update_userid(pkey, userid, &sigpacket, &sig->sig.info);
	}

	/* cleanup */
	pgp_create_sig_delete(sig);
	pgp_output_delete(sigoutput);
	pgp_memory_free(mem_sig);
}


static void add_subkey_binding_signature(pgp_subkeysig_t* p, pgp_key_t* primarykey, pgp_key_t* subkey, pgp_key_t* seckey)
{
	/*add "0x18: Subkey Binding Signature" packet, PGP_SIG_SUBKEY */
	pgp_create_sig_t* sig;
	pgp_output_t*     sigoutput = NULL;
	pgp_memory_t*     mem_sig = NULL;

	sig = pgp_create_sig_new();
	pgp_sig_start_key_sig(sig, &primarykey->key.pubkey, &subkey->key.pubkey, NULL, PGP_SIG_SUBKEY);

	pgp_add_creation_time(sig, time(NULL));
	pgp_add_key_expiration_time(sig, 0);
	pgp_add_key_flags(sig, PGP_KEYFLAG_ENC_STORAGE|PGP_KEYFLAG_ENC_COMM); /* NB: algo/hash/compression preferences are not added to subkeys */

	pgp_end_hashed_subpkts(sig);

	pgp_add_issuer_keyid(sig, seckey->pubkeyid); /* the issuer keyid is not hashed by definition */

	pgp_setup_memory_write(&sigoutput, &mem_sig, 128);
	pgp_write_sig(sigoutput, sig, &seckey->key.seckey.pubkey, &seckey->key.seckey);

	p->subkey         = primarykey->subkeyc-1; /* index of subkey in array */
	p->packet.length  = mem_sig->length;
	p->packet.raw     = mem_sig->buf; mem_sig->buf = NULL; /* move ownership to packet */
	copy_sig_info(&p->siginfo, &sig->sig.info); /* not sure, if this is okay, however, siginfo should be set up, otherwise we get "bad info-type" errors */

	pgp_create_sig_delete(sig);
	pgp_output_delete(sigoutput);
	free(mem_sig); /* do not use pgp_memory_free() as this would also free mem_sig->buf which is owned by the packet */
}


int mrpgp_create_keypair(mrmailbox_t* mailbox, const char* addr, mrkey_t* ret_public_key, mrkey_t* ret_private_key)
{
	int              success = 0;
	pgp_key_t        seckey, pubkey, subkey;
	uint8_t          subkeyid[PGP_KEY_ID_SIZE];
	uint8_t*         user_id = NULL;
	pgp_memory_t     *pubmem = pgp_memory_new(), *secmem = pgp_memory_new();
	pgp_output_t     *pubout = pgp_output_new(), *secout = pgp_output_new();

	memset(&seckey, 0, sizeof(pgp_key_t));
	memset(&pubkey, 0, sizeof(pgp_key_t));
	memset(&subkey, 0, sizeof(pgp_key_t));

	if( mailbox==NULL || addr==NULL || ret_public_key==NULL || ret_private_key==NULL
	 || pubmem==NULL || secmem==NULL || pubout==NULL || secout==NULL ) {
		goto cleanup;
	}

	/* Generate User ID.  For convention, use the same address as given in `Autocrypt: to=...` in angle brackets
	(RFC 2822 grammar angle-addr, see also https://autocrypt.org/en/latest/level0.html#type-p-openpgp-based-key-data )
	We do not add the name to the ID for the following reasons:
	- privacy
	- the name may be changed
	- shorter keys
	- the name is already taken from From:
	- not Autocrypt:-standard */
	user_id = (uint8_t*)mr_mprintf("<%s>", addr);

	/* generate two keypairs */
	if( !pgp_rsa_generate_keypair(&seckey, 3072/*bits*/, 65537UL/*e*/, NULL, NULL, NULL, 0)
	 || !pgp_rsa_generate_keypair(&subkey, 3072/*bits*/, 65537UL/*e*/, NULL, NULL, NULL, 0) ) {
		goto cleanup;
	}


	/* Create public key, bind public subkey to public key
	------------------------------------------------------------------------ */

	pubkey.type = PGP_PTAG_CT_PUBLIC_KEY;
	pgp_pubkey_dup(&pubkey.key.pubkey, &seckey.key.pubkey);
	memcpy(pubkey.pubkeyid, seckey.pubkeyid, PGP_KEY_ID_SIZE);
	pgp_fingerprint(&pubkey.pubkeyfpr, &seckey.key.pubkey, 0);
	add_selfsigned_userid(&seckey, &pubkey, (const uint8_t*)user_id, 0/*never expire*/);

	EXPAND_ARRAY((&pubkey), subkey);
	{
		pgp_subkey_t* p = &pubkey.subkeys[pubkey.subkeyc++];
		pgp_pubkey_dup(&p->key.pubkey, &subkey.key.pubkey);
		pgp_keyid(subkeyid, PGP_KEY_ID_SIZE, &pubkey.key.pubkey, PGP_HASH_SHA1);
		memcpy(p->id, subkeyid, PGP_KEY_ID_SIZE);
	}

	EXPAND_ARRAY((&pubkey), subkeysig);
	add_subkey_binding_signature(&pubkey.subkeysigs[pubkey.subkeysigc++], &pubkey, &subkey, &seckey);


	/* Create secret key, bind secret subkey to secret key
	------------------------------------------------------------------------ */

	EXPAND_ARRAY((&seckey), subkey);
	{
		pgp_subkey_t* p = &seckey.subkeys[seckey.subkeyc++];
		pgp_seckey_dup(&p->key.seckey, &subkey.key.seckey);
		pgp_keyid(subkeyid, PGP_KEY_ID_SIZE, &seckey.key.pubkey, PGP_HASH_SHA1);
		memcpy(p->id, subkeyid, PGP_KEY_ID_SIZE);
	}

	EXPAND_ARRAY((&seckey), subkeysig);
	add_subkey_binding_signature(&seckey.subkeysigs[seckey.subkeysigc++], &seckey, &subkey, &seckey);


	/* Done with key generation, write binary keys to memory
	------------------------------------------------------------------------ */

	pgp_writer_set_memory(pubout, pubmem);
	if( !pgp_write_xfer_key(pubout, &pubkey, 0/*armored*/)
	 || pubmem->buf == NULL || pubmem->length <= 0 ) {
		goto cleanup;
	}

	pgp_writer_set_memory(secout, secmem);
	if( !pgp_write_xfer_key(secout, &seckey, 0/*armored*/)
	 || secmem->buf == NULL || secmem->length <= 0 ) {
		goto cleanup;
	}

	mrkey_set_from_raw(ret_public_key, pubmem->buf, pubmem->length, MR_PUBLIC);
	mrkey_set_from_raw(ret_private_key, secmem->buf, secmem->length, MR_PRIVATE);

	success = 1;

cleanup:
	if( pubout ) { pgp_output_delete(pubout); }
	if( secout ) { pgp_output_delete(secout); }
	if( pubmem ) { pgp_memory_free(pubmem); }
	if( secmem ) { pgp_memory_free(secmem); }
	pgp_key_free(&seckey); /* not: pgp_keydata_free() which will also free the pointer itself (we created it on the stack) */
	pgp_key_free(&pubkey);
	pgp_key_free(&subkey);
	free(user_id);
	return success;
}


/*******************************************************************************
 * Check keys
 ******************************************************************************/


int mrpgp_is_valid_key(mrmailbox_t* mailbox, const mrkey_t* raw_key)
{
	int             key_is_valid = 0;
	pgp_keyring_t*  public_keys = calloc(1, sizeof(pgp_keyring_t));
	pgp_keyring_t*  private_keys = calloc(1, sizeof(pgp_keyring_t));
	pgp_memory_t*   keysmem = pgp_memory_new();

	if( mailbox==NULL || raw_key==NULL
	 || raw_key->m_binary == NULL || raw_key->m_bytes <= 0
	 || public_keys==NULL || private_keys==NULL || keysmem==NULL ) {
		goto cleanup;
	}

	pgp_memory_add(keysmem, raw_key->m_binary, raw_key->m_bytes);

	pgp_filter_keys_from_mem(&s_io, public_keys, private_keys, NULL, 0, keysmem); /* function returns 0 on any error in any packet - this does not mean, we cannot use the key. We check the details below therefore. */

	if( raw_key->m_type == MR_PUBLIC && public_keys->keyc >= 1 ) {
		key_is_valid = 1;
	}
	else if( raw_key->m_type == MR_PRIVATE && private_keys->keyc >= 1 ) {
		key_is_valid = 1;
	}

cleanup:
	if( keysmem )      { pgp_memory_free(keysmem); }
	if( public_keys )  { pgp_keyring_purge(public_keys); free(public_keys); } /*pgp_keyring_free() frees the content, not the pointer itself*/
	if( private_keys ) { pgp_keyring_purge(private_keys); free(private_keys); }
	return key_is_valid;
}


int mrpgp_calc_fingerprint(mrmailbox_t* mailbox, const mrkey_t* raw_key, uint8_t** ret_fingerprint, size_t* ret_fingerprint_bytes)
{
	int             success = 0;
	pgp_keyring_t*  public_keys = calloc(1, sizeof(pgp_keyring_t));
	pgp_keyring_t*  private_keys = calloc(1, sizeof(pgp_keyring_t));
	pgp_memory_t*   keysmem = pgp_memory_new();

	if( mailbox==NULL || raw_key==NULL || ret_fingerprint==NULL || *ret_fingerprint!=NULL || ret_fingerprint_bytes==NULL || *ret_fingerprint_bytes!=0
	 || raw_key->m_binary == NULL || raw_key->m_bytes <= 0
	 || public_keys==NULL || private_keys==NULL || keysmem==NULL ) {
		goto cleanup;
	}

	pgp_memory_add(keysmem, raw_key->m_binary, raw_key->m_bytes);

	pgp_filter_keys_from_mem(&s_io, public_keys, private_keys, NULL, 0, keysmem);

	if( raw_key->m_type != MR_PUBLIC || public_keys->keyc <= 0 ) {
		goto cleanup;
	}

	pgp_key_t* key0 = &public_keys->keys[0];
	pgp_pubkey_t* pubkey0 = &key0->key.pubkey;
	if( !pgp_fingerprint(&key0->pubkeyfpr, pubkey0, 0) ) {
		goto cleanup;
	}

	*ret_fingerprint_bytes = key0->pubkeyfpr.length;
    *ret_fingerprint = malloc(*ret_fingerprint_bytes);
	memcpy(*ret_fingerprint, key0->pubkeyfpr.fingerprint, *ret_fingerprint_bytes);

	success = 1;

cleanup:
	if( keysmem )      { pgp_memory_free(keysmem); }
	if( public_keys )  { pgp_keyring_purge(public_keys); free(public_keys); } /*pgp_keyring_free() frees the content, not the pointer itself*/
	if( private_keys ) { pgp_keyring_purge(private_keys); free(private_keys); }
	return success;
}


int mrpgp_split_key(mrmailbox_t* mailbox, const mrkey_t* private_in, mrkey_t* ret_public_key)
{
	int             success = 0;
	pgp_keyring_t*  public_keys = calloc(1, sizeof(pgp_keyring_t));
	pgp_keyring_t*  private_keys = calloc(1, sizeof(pgp_keyring_t));
	pgp_memory_t*   keysmem = pgp_memory_new();
	pgp_memory_t*   pubmem = pgp_memory_new();
	pgp_output_t*   pubout = pgp_output_new();

	if( mailbox == NULL || private_in==NULL || ret_public_key==NULL
	 || public_keys==NULL || private_keys==NULL || keysmem==NULL || pubmem==NULL || pubout==NULL ) {
		goto cleanup;
	}

	pgp_memory_add(keysmem, private_in->m_binary, private_in->m_bytes);
	pgp_filter_keys_from_mem(&s_io, public_keys, private_keys, NULL, 0, keysmem);

	if( private_in->m_type!=MR_PRIVATE || private_keys->keyc <= 0 ) {
		mrmailbox_log_warning(mailbox, 0, "Split key: Given key is no private key.");
		goto cleanup;
	}

	if( public_keys->keyc <= 0 ) {
		mrmailbox_log_warning(mailbox, 0, "Split key: Given key does not contain a public key.");
		goto cleanup;
	}

	pgp_writer_set_memory(pubout, pubmem);
	if( !pgp_write_xfer_key(pubout, &public_keys->keys[0], 0/*armored*/)
	 || pubmem->buf == NULL || pubmem->length <= 0 ) {
		goto cleanup;
	}

	mrkey_set_from_raw(ret_public_key, pubmem->buf, pubmem->length, MR_PUBLIC);

	success = 1;

cleanup:
	if( pubout ) { pgp_output_delete(pubout); }
	if( pubmem ) { pgp_memory_free(pubmem); }
	if( keysmem )      { pgp_memory_free(keysmem); }
	if( public_keys )  { pgp_keyring_purge(public_keys); free(public_keys); } /*pgp_keyring_free() frees the content, not the pointer itself*/
	if( private_keys ) { pgp_keyring_purge(private_keys); free(private_keys); }
	return success;
}


/*******************************************************************************
 * Public key encrypt/decrypt
 ******************************************************************************/


int mrpgp_pk_encrypt(  mrmailbox_t*       mailbox,
                       const void*        plain_text,
                       size_t             plain_bytes,
                       const mrkeyring_t* raw_public_keys_for_encryption,
                       const mrkey_t*     raw_private_key_for_signing,
                       int                use_armor,
                       void**             ret_ctext,
                       size_t*            ret_ctext_bytes)
{
	pgp_keyring_t*  public_keys = calloc(1, sizeof(pgp_keyring_t));
	pgp_keyring_t*  private_keys = calloc(1, sizeof(pgp_keyring_t));
	pgp_keyring_t*  dummy_keys = calloc(1, sizeof(pgp_keyring_t));
	pgp_memory_t*   keysmem = pgp_memory_new();
	pgp_memory_t*   signedmem = NULL;
	int             i, success = 0;

	if( mailbox==NULL || plain_text==NULL || plain_bytes==0 || ret_ctext==NULL || ret_ctext_bytes==NULL
	 || raw_public_keys_for_encryption==NULL || raw_public_keys_for_encryption->m_count<=0
	 || keysmem==NULL || public_keys==NULL || private_keys==NULL || dummy_keys==NULL ) {
		goto cleanup;
	}

	*ret_ctext       = NULL;
	*ret_ctext_bytes = 0;

	/* setup keys (the keys may come from pgp_filter_keys_fileread(), see also pgp_keyring_add(rcpts, key)) */
	for( i = 0; i < raw_public_keys_for_encryption->m_count; i++ ) {
		pgp_memory_add(keysmem, raw_public_keys_for_encryption->m_keys[i]->m_binary, raw_public_keys_for_encryption->m_keys[i]->m_bytes);
	}

	pgp_filter_keys_from_mem(&s_io, public_keys, private_keys/*should stay empty*/, NULL, 0, keysmem);
	if( public_keys->keyc <=0 || private_keys->keyc!=0 ) {
		mrmailbox_log_warning(mailbox, 0, "Encryption-keyring contains unexpected data (%i/%i)", public_keys->keyc, private_keys->keyc);
		goto cleanup;
	}

	/* encrypt */
	{
		const void* signed_text = NULL;
		size_t      signed_bytes = 0;
		int         encrypt_raw_packet = 0;

		if( raw_private_key_for_signing ) {
			pgp_memory_clear(keysmem);
			pgp_memory_add(keysmem, raw_private_key_for_signing->m_binary, raw_private_key_for_signing->m_bytes);
			pgp_filter_keys_from_mem(&s_io, dummy_keys, private_keys, NULL, 0, keysmem);
			if( private_keys->keyc <= 0 ) {
				mrmailbox_log_warning(mailbox, 0, "No key for signing found.");
				goto cleanup;
			}

			pgp_key_t* sk0 = &private_keys->keys[0];
			signedmem = pgp_sign_buf(&s_io, plain_text, plain_bytes, &sk0->key.seckey, time(NULL)/*birthtime*/, 0/*duration*/, "sha1", 0/*armored*/, 0/*cleartext*/);
			if( signedmem == NULL ) {
				mrmailbox_log_warning(mailbox, 0, "Signing failed.");
				goto cleanup;
			}
			signed_text        = signedmem->buf;
			signed_bytes       = signedmem->length;
			encrypt_raw_packet = 1;
		}
		else {
			signed_text        = plain_text;
			signed_bytes       = plain_bytes;
			encrypt_raw_packet = 0;
		}

		pgp_memory_t* outmem = pgp_encrypt_buf(&s_io, signed_text, signed_bytes, public_keys, use_armor, NULL/*cipher*/, encrypt_raw_packet);
		if( outmem == NULL ) {
			mrmailbox_log_warning(mailbox, 0, "Encryption failed.");
			goto cleanup;
		}
		*ret_ctext       = outmem->buf;
		*ret_ctext_bytes = outmem->length;
		free(outmem); /* do not use pgp_memory_free() as we took ownership of the buffer */
	}

	success = 1;

cleanup:
	if( keysmem )      { pgp_memory_free(keysmem); }
	if( signedmem )    { pgp_memory_free(signedmem); }
	if( public_keys )  { pgp_keyring_purge(public_keys); free(public_keys); } /*pgp_keyring_free() frees the content, not the pointer itself*/
	if( private_keys ) { pgp_keyring_purge(private_keys); free(private_keys); }
	if( dummy_keys )   { pgp_keyring_purge(dummy_keys); free(dummy_keys); }
	return success;
}


int mrpgp_pk_decrypt(  mrmailbox_t*       mailbox,
                       const void*        ctext,
                       size_t             ctext_bytes,
                       const mrkeyring_t* raw_private_keys_for_decryption,
                       const mrkey_t*     raw_public_key_for_validation,
                       int                use_armor,
                       void**             ret_plain,
                       size_t*            ret_plain_bytes,
                       int*               ret_validation_errors)
{
	pgp_keyring_t*    public_keys = calloc(1, sizeof(pgp_keyring_t)); /*should be 0 after parsing*/
	pgp_keyring_t*    private_keys = calloc(1, sizeof(pgp_keyring_t));
	pgp_keyring_t*    dummy_keys = calloc(1, sizeof(pgp_keyring_t));
	pgp_validation_t* vresult = calloc(1, sizeof(pgp_validation_t));
	key_id_t*         recipients_key_ids = NULL;
	unsigned          recipients_count = 0;
	pgp_memory_t*     keysmem = pgp_memory_new();
	int               i, success = 0;

	if( mailbox==NULL || ctext==NULL || ctext_bytes==0 || ret_plain==NULL || ret_plain_bytes==NULL || ret_validation_errors==NULL
	 || raw_private_keys_for_decryption==NULL || raw_private_keys_for_decryption->m_count<=0
	 || vresult==NULL || keysmem==NULL || public_keys==NULL || private_keys==NULL ) {
		goto cleanup;
	}

	*ret_plain             = NULL;
	*ret_plain_bytes       = 0;

	/* setup keys (the keys may come from pgp_filter_keys_fileread(), see also pgp_keyring_add(rcpts, key)) */
	for( i = 0; i < raw_private_keys_for_decryption->m_count; i++ ) {
		pgp_memory_add(keysmem, raw_private_keys_for_decryption->m_keys[i]->m_binary, raw_private_keys_for_decryption->m_keys[i]->m_bytes);
	}

	pgp_filter_keys_from_mem(&s_io, dummy_keys/*should stay empty*/, private_keys, NULL, 0, keysmem);
	if( private_keys->keyc<=0 ) {
		mrmailbox_log_warning(mailbox, 0, "Decryption-keyring contains unexpected data (%i/%i)", public_keys->keyc, private_keys->keyc);
		goto cleanup;
	}

	if( raw_public_key_for_validation ) {
		pgp_memory_clear(keysmem);
		pgp_memory_add(keysmem, raw_public_key_for_validation->m_binary, raw_public_key_for_validation->m_bytes);
		pgp_filter_keys_from_mem(&s_io, public_keys, dummy_keys/*should stay empty*/, NULL, 0, keysmem);
	}

	/* decrypt */
	{
		pgp_memory_t* outmem = pgp_decrypt_and_validate_buf(&s_io, vresult, ctext, ctext_bytes, private_keys, public_keys,
			use_armor, &recipients_key_ids, &recipients_count);
		if( outmem == NULL ) {
			mrmailbox_log_warning(mailbox, 0, "Decryption failed.");
			goto cleanup;
		}
		*ret_plain       = outmem->buf;
		*ret_plain_bytes = outmem->length;
		free(outmem); /* do not use pgp_memory_free() as we took ownership of the buffer */

		/* validate */
		*ret_validation_errors = 0;
		if( vresult->validc <= 0 && vresult->invalidc <= 0 && vresult->unknownc <= 0 )
		{
			/* no valid nor invalid signatures found */
			*ret_validation_errors = MR_VALIDATE_NO_SIGNATURE;
		}
		else if( raw_public_key_for_validation==NULL || vresult->unknownc > 0 )
		{
			/* at least one valid or invalid signature found, but no key for verification */
			*ret_validation_errors = MR_VALIDATE_UNKNOWN_SIGNATURE;
		}
		else if( vresult->invalidc > 0 )
		{
			/* at least one invalid signature found */
			*ret_validation_errors = MR_VALIDATE_BAD_SIGNATURE;
		}
		else
		{
			/* only valid signatures found */
			;
		}
	}

	success = 1;

cleanup:
	if( keysmem )            { pgp_memory_free(keysmem); }
	if( public_keys )        { pgp_keyring_purge(public_keys); free(public_keys); } /*pgp_keyring_free() frees the content, not the pointer itself*/
	if( private_keys )       { pgp_keyring_purge(private_keys); free(private_keys); }
	if( dummy_keys )         { pgp_keyring_purge(dummy_keys); free(dummy_keys); }
	if( vresult )            { pgp_validate_result_free(vresult); }
	if( recipients_key_ids ) { free(recipients_key_ids); }
	return success;
}
