/*-
 * Copyright (c) 2009 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Alistair Crooks (agc@NetBSD.org)
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
/*
 * Copyright (c) 2005-2008 Nominet UK (www.nic.uk)
 * All rights reserved.
 * Contributors: Ben Laurie, Rachel Willmer. The Contributors have asserted
 * their moral rights under the UK Copyright Design and Patents Act 1988 to
 * be recorded as the authors of this copyright work.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License.
 *
 * You may obtain a copy of the License at
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/** \file
 */
#include "netpgp/config-netpgp.h"

#ifdef HAVE_SYS_CDEFS_H
#include <sys/cdefs.h>
#endif

#if defined(__NetBSD__)
__COPYRIGHT("@(#) Copyright (c) 2009 The NetBSD Foundation, Inc. All rights reserved.");
__RCSID("$NetBSD$");
#endif

#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif

#include <regex.h>
#include <stdlib.h>
#include <string.h>

#ifdef HAVE_TERMIOS_H
#include <termios.h>
#endif

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#include "netpgp/types.h"
#include "netpgp/keyring.h"
#include "netpgp/packet-parse.h"
#include "netpgp/signature.h"
#include "netpgp/netpgpsdk.h"
#include "netpgp/readerwriter.h"
#include "netpgp/netpgpdefs.h"
#include "netpgp/packet.h"
#include "netpgp/crypto.h"
#include "netpgp/validate.h"
#include "netpgp/netpgpdefs.h"
#include "netpgp/netpgpdigest.h"



/**
   \ingroup HighLevel_Keyring

   \brief Creates a new pgp_key_t struct

   \return A new pgp_key_t struct, initialised to zero.

   \note The returned pgp_key_t struct must be freed after use with pgp_keydata_free.
*/

pgp_key_t  *
pgp_keydata_new(void)
{
	return calloc(1, sizeof(pgp_key_t));
}


/**
 \ingroup HighLevel_Keyring

 \brief Frees key's allocated memory

 \param keydata Key to be freed.

 \note This does not free the keydata itself, but any other memory alloc-ed by it.
*/
void
pgp_key_free(pgp_key_t *key)
{
	unsigned        n;

	if (key->type == PGP_PTAG_CT_PUBLIC_KEY) {
		pgp_pubkey_free(&key->key.pubkey);
	} else {
		pgp_seckey_free(&key->key.seckey);
	}

	for (n = 0; n < key->directsigc; ++n) {
        pgp_free_sig_info(&key->directsigs[n].siginfo);
		pgp_subpacket_free(&key->directsigs[n].packet);
	}
    FREE_ARRAY(key, directsig);

	for (n = 0; n < key->uidc; ++n) {
		pgp_userid_free(&key->uids[n]);
	}
    FREE_ARRAY(key, uid);

	for (n = 0; n < key->uidsigc; ++n) {
        pgp_free_sig_info(&key->uidsigs[n].siginfo);
		pgp_subpacket_free(&key->uidsigs[n].packet);
	}
    FREE_ARRAY(key, uidsig);

	for (n = 0; n < key->subkeyc; ++n) {
        if (key->type == PGP_PTAG_CT_PUBLIC_KEY) {
            pgp_pubkey_free(&key->subkeys[n].key.pubkey);
        } else {
            pgp_seckey_free(&key->subkeys[n].key.seckey);
        }
	}
    FREE_ARRAY(key, subkey);

	for (n = 0; n < key->subkeysigc; ++n) {
        pgp_free_sig_info(&key->subkeysigs[n].siginfo);
		pgp_subpacket_free(&key->subkeysigs[n].packet);
	}
    FREE_ARRAY(key, subkeysig);
}

/**
 \ingroup HighLevel_Keyring

 \brief Frees keydata and its memory

 \param keydata Key to be freed.

 \note This frees the keydata itself, as well as any other memory alloc-ed by it.
*/
void
pgp_keydata_free(pgp_key_t *keydata)
{
    pgp_key_free(keydata);
	free(keydata);
}

static unsigned siginfo_in_time(pgp_sig_info_t *siginfo){
	time_t	now;
	now = time(NULL);
    /* in sig validity time frame */
    return now >= siginfo->birthtime && (
            siginfo->key_expiry == 0 ||
            now < siginfo->birthtime +
                  siginfo->key_expiry);
}

const int32_t
pgp_key_find_uid_cond(
        const pgp_key_t *key,
        unsigned(*uidcond) ( uint8_t *, void *),
        void *uidcondarg,
        unsigned(*sigcond) ( const pgp_sig_info_t *, void *),
        void *sigcondarg,
        time_t *youngest,
        unsigned checkrevoke,
        unsigned checkexpiry)
{
    unsigned    	 	 uididx = 0;
    unsigned    	 	 uidsigidx = 0;
    int32_t    	 	 res = -1; /* Not found */
    int32_t    	 	 lastgood;
    uint8_t			**uidp;
    pgp_uidsig_t    *uidsigp;
    time_t           yngst = 0;

    /* If not maximum age given, take default */
    if(!youngest)
        youngest = &yngst;

    /* Loop over key's user ids*/
    uidp = key->uids;
    for (uididx = 0 ; uididx < key->uidc; uididx++, uidp++)
    {
        if(uidcond && !uidcond(*uidp, uidcondarg)) continue;

        lastgood = res;
        /* Loop over key's user ids sigs */
        uidsigp = key->uidsigs;
        for (uidsigidx = 0 ; uidsigidx < key->uidsigc; uidsigidx++, uidsigp++)
        {
            /* matching selected user id */
            if(uidsigp->uid == uididx)
            {
                /* if uid is revoked */
                /* revoke on secret keys has no effect*/
                if(uidsigp->siginfo.type == PGP_SIG_REV_CERT)
                {
                    /* ignore revocation if secret */
                    if(!checkrevoke)
                        continue;

                    /* revert to last good candidate */
                    res = lastgood;
                    break; /* jump to next uid */
                }

                /* in sig validity time frame */
                if(!checkexpiry || siginfo_in_time(&uidsigp->siginfo))
                {
                    /* sig cond is ok ? */
                    if(!sigcond || sigcond(&uidsigp->siginfo, sigcondarg))
                    {
                        /* youngest signature is deciding */
                        if(uidsigp->siginfo.birthtime > *youngest)
                        {
                            *youngest = uidsigp->siginfo.birthtime;
                            res = uididx;
                        }
                    }
                }
            }
        }
    }
	return res;
}

/*
 *  Returns :
 *   -2 not found
 *   -1 match is priamary key
 *   >=0 index of matching valid subkey
 * */
const int32_t
pgp_key_find_key_conds(
        pgp_key_t *key,
        unsigned(*keycond) ( const pgp_pubkey_t *, const uint8_t *, void*),
        void *keycondarg,
        unsigned(*sigcond) ( const pgp_sig_info_t *, void*),
        void *sigcondarg,
        unsigned checkrevoke,
        unsigned checkexpiry)
{
    unsigned    	 	 subkeyidx = 0;
    unsigned    	 	 subkeysigidx = 0;
    unsigned    	 	 directsigidx = 0;
    int32_t    	 	 res = -2; /* Not found */
    int32_t    	 	 lastgood;
    pgp_subkey_t	*subkeyp;
    pgp_subkeysig_t    *subkeysigp;
    pgp_directsig_t    *directsigp;
    time_t	youngest;

	youngest = 0;

    /* check pubkey first */
    if(!keycond || keycond(pgp_key_get_pubkey(key),
                           key->pubkeyid, keycondarg)){

        int32_t uidres;

        /* Loop over key's direct sigs */
        directsigp = key->directsigs;

        for (directsigidx = 0 ; directsigidx < key->directsigc;
                directsigidx++, directsigp++)
        {
            /* if direct is revoked */
            if(directsigp->siginfo.type == PGP_SIG_REV_KEY)
            {
                /* ignore revocation if secret */
                if(!checkrevoke)
                    continue;

                return -2; /* Key is globally revoked, no result */
            }

            /* in sig validity time frame */
            if(!checkexpiry || siginfo_in_time(&directsigp->siginfo))
            {
                /* condition on sig is ok */
                if(!sigcond || sigcond(&directsigp->siginfo, sigcondarg))
                {
                    /* youngest signature is deciding */
                    if(directsigp->siginfo.birthtime > youngest)
                    {
                        youngest = directsigp->siginfo.birthtime;
                        res = -1; /* Primary key is a candidate */
                    }
                }
            }
        }

        uidres = pgp_key_find_uid_cond(
                key, NULL, NULL, sigcond, sigcondarg, &youngest,
                checkrevoke, checkexpiry);

        /* if matching uid sig, then primary is matching key */
        if(uidres != -1){
            res = -1;
        }
    }

    /* Loop over key's subkeys */
    subkeyp = key->subkeys;
    for (subkeyidx = 0 ; subkeyidx < key->subkeyc; subkeyidx++, subkeyp++)
    {
        lastgood = res;

        subkeysigp = key->subkeysigs;

        /* Skip this subkey if key condition not met */
        if(keycond && !keycond(&subkeyp->key.pubkey, subkeyp->id, keycondarg))
            continue;

        /* Loop over key's subkeys sigs */
        for (subkeysigidx = 0 ; subkeysigidx < key->subkeysigc;
                subkeysigidx++, subkeysigp++)
        {
            /* matching selected subkey */
            if(subkeysigp->subkey == subkeyidx)
            {
                /* if subkey is revoked */
                if(subkeysigp->siginfo.type == PGP_SIG_REV_SUBKEY)
                {
                    /* ignore revocation if secret */
                    if(!checkrevoke)
                        continue;

                    /* revert to last good candidate */
                    res = lastgood;
                    break; /* jump to next subkey */
                }

                /* in sig validity time frame */
                if(!checkexpiry || siginfo_in_time(&subkeysigp->siginfo))
                {
                    /* subkey sig condition is ok */
                    if(!sigcond || sigcond(&subkeysigp->siginfo, sigcondarg))
                    {
                        /* youngest signature is deciding */
                        if(subkeysigp->siginfo.birthtime > youngest)
                        {
                            youngest = subkeysigp->siginfo.birthtime;
                            res = subkeyidx;
                        }
                    }
                }
            }
        }
    }
	return res;
}

/**
 \ingroup HighLevel_KeyGeneral

 \brief Returns the public key in the given keydata.
 \param keydata

  \return Pointer to public key

  \note This is not a copy, do not free it after use.
*/

pgp_pubkey_t *
pgp_key_get_pubkey(pgp_key_t *keydata)
{
	return (keydata->type == PGP_PTAG_CT_PUBLIC_KEY) ?
				&keydata->key.pubkey :
				&keydata->key.seckey.pubkey;
}

pgp_pubkey_t *
pgp_key_get_subpubkey(pgp_key_t *key, int32_t subkeyidx)
{
	return (key->type == PGP_PTAG_CT_PUBLIC_KEY) ?
				&key->subkeys[subkeyidx].key.pubkey :
				&key->subkeys[subkeyidx].key.seckey.pubkey;
}

pgp_seckey_t *
pgp_key_get_subseckey(pgp_key_t *key, int32_t subkeyidx)
{
	return (key->type == PGP_PTAG_CT_SECRET_KEY) ?
				&key->subkeys[subkeyidx].key.seckey :
				NULL;
}
static pgp_pubkey_t *
key_get_pubkey_from_subidx(
        pgp_key_t *key,
        const uint8_t **id,
        int32_t subkeyidx)
{
    if(subkeyidx == -2){
        return NULL;
    }

    if(subkeyidx != -1)
    {
        if(id)
            *id = key->subkeys[subkeyidx].id;

	    return pgp_key_get_subpubkey(key, subkeyidx);

    }

    if(id)
        *id = key->pubkeyid;

	return pgp_key_get_pubkey(key);
}

static pgp_seckey_t *
key_get_seckey_from_subidx(
        pgp_key_t *key,
        const uint8_t **id,
        int32_t subkeyidx)
{
    if(subkeyidx == -2){
        return NULL;
    }

    if(subkeyidx != -1)
    {
        if(id)
            *id = key->subkeys[subkeyidx].id;

	    return pgp_key_get_subseckey(key, subkeyidx);

    }

    if(id)
        *id = key->pubkeyid;

	return pgp_get_seckey(key);
}

static unsigned is_signing_role(const pgp_sig_info_t *siginfo, void *arg)
{
    return siginfo->key_flags & PGP_KEYFLAG_SIGN_DATA;
}

/* Get a pub key to check signature */
pgp_pubkey_t *
pgp_key_get_sigkey(pgp_key_t *key)
{
    int32_t subkeyidx =
        pgp_key_find_key_conds(key, NULL, NULL, &is_signing_role, NULL, 0, 0);
    return key_get_pubkey_from_subidx(key, NULL, subkeyidx);
}

/* Get a sec key to write a signature */
pgp_seckey_t *
pgp_key_get_certkey(pgp_key_t *key)
{
    int32_t subkeyidx =
        pgp_key_find_key_conds(key, NULL, NULL, &is_signing_role, NULL, 1, 0);
    return key_get_seckey_from_subidx(key, NULL, subkeyidx);
}

static unsigned is_encryption_role(const pgp_sig_info_t *siginfo, void *arg)
{
    return siginfo->key_flags & PGP_KEYFLAG_ENC_COMM;
}

pgp_pubkey_t *
pgp_key_get_enckey(pgp_key_t *key, const uint8_t **id)
{
    int32_t subkeyidx =
        pgp_key_find_key_conds(key, NULL, NULL, &is_encryption_role, NULL, 1, 0);

    return key_get_pubkey_from_subidx(key, id, subkeyidx);
}

pgp_seckey_t *
pgp_key_get_deckey(pgp_key_t *key, const uint8_t **id)
{
    int32_t subkeyidx =
        pgp_key_find_key_conds(key, NULL, NULL, &is_encryption_role, NULL, 0, 0);

    return key_get_seckey_from_subidx(key, id, subkeyidx);
}

static unsigned primary_uid_sigcond(const pgp_sig_info_t *siginfo, void *arg)
{
    return siginfo->primary_userid;
}

const int32_t pgp_key_get_uid0(pgp_key_t *key)
{
    int32_t res =
        pgp_key_find_uid_cond(key, NULL, NULL, &primary_uid_sigcond, NULL, NULL, 1, 0);

    /* arbitrarily use youngest uid if no primary is found */
    return res == -1 ?
        pgp_key_find_uid_cond(key, NULL, NULL, NULL, NULL, NULL, 1, 0):
        res;
}

const uint8_t *pgp_key_get_primary_userid(pgp_key_t *key)
{
    const int32_t uid0 = pgp_key_get_uid0(key);
    if( uid0 >= 0 && key->uids && key->uidc > uid0)
    {
        return key->uids[uid0];
    }
    return NULL;
}

unsigned key_bit_len(const pgp_pubkey_t *key)
{
	switch (key->alg) {
	case PGP_PKA_DSA:
		return BN_num_bits(key->key.dsa.p);

	case PGP_PKA_RSA:
		return BN_num_bits(key->key.rsa.n);

	case PGP_PKA_ELGAMAL:
		return BN_num_bits(key->key.elgamal.p);

	default:
        return 0;
	}
}

unsigned key_is_weak(
        const pgp_pubkey_t *key,
        const uint8_t *keyid,
        void *arg)
{
    unsigned kbl;
    pgp_key_rating_t *res;

    res = (pgp_key_rating_t*)arg;
    kbl = key_bit_len(key);

    if(kbl == 0)
    {
        *res = PGP_INVALID;
    }
    else if(kbl < 1024)
    {
        *res = PGP_TOOSHORT;
    }
    else if(kbl == 1024 && key->alg == PGP_PKA_RSA)
    {
        *res = PGP_WEAK;
    }

    return 0;
}

const pgp_key_rating_t pgp_key_get_rating(pgp_key_t *key)
{
    /* keys exist in rings only if valid */
    pgp_key_rating_t res = PGP_VALID;

    pgp_key_find_key_conds(key, &key_is_weak, (void*)&res, NULL, NULL, 0, 0);

    if(res == PGP_VALID)
    {
        if(pgp_key_find_key_conds(
                    key, NULL, NULL, NULL, NULL, 1, 0) == -2)
        {
            return PGP_REVOKED;
        }
        if(pgp_key_find_key_conds(
                    key, NULL, NULL, NULL, NULL, 0, 1) == -2)
        {
            return PGP_EXPIRED;
        }
    }

    return res;
}
/**
\ingroup HighLevel_KeyGeneral

\brief Check whether this is a secret key or not.
*/

unsigned
pgp_is_key_secret(pgp_key_t *data)
{
	return data->type != PGP_PTAG_CT_PUBLIC_KEY;
}

/**
 \ingroup HighLevel_KeyGeneral

 \brief Returns the secret key in the given keydata.

 \note This is not a copy, do not free it after use.

 \note This returns a const.  If you need to be able to write to this
 pointer, use pgp_get_writable_seckey
*/

pgp_seckey_t *
pgp_get_seckey(pgp_key_t *data)
{
	return (data->type == PGP_PTAG_CT_SECRET_KEY) ?
				&data->key.seckey : NULL;
}

/**
 \ingroup HighLevel_KeyGeneral

  \brief Returns the secret key in the given keydata.

  \note This is not a copy, do not free it after use.

  \note If you do not need to be able to modify this key, there is an
  equivalent read-only function pgp_get_seckey.
*/

pgp_seckey_t *
pgp_get_writable_seckey(pgp_key_t *data)
{
	return (data->type == PGP_PTAG_CT_SECRET_KEY) ?
				&data->key.seckey : NULL;
}

/* utility function to zero out memory */
void
pgp_forget(void *vp, unsigned size)
{
	(void) memset(vp, 0x0, size);
}

typedef struct {
	FILE			*passfp;
	const pgp_key_t	*key;
	char			*passphrase;
	pgp_seckey_t		*seckey;
} decrypt_t;

// FIXME : support encrypted seckeys again
// static pgp_cb_ret_t
// decrypt_cb(const pgp_packet_t *pkt, pgp_cbdata_t *cbinfo)
// {
// 	const pgp_contents_t	*content = &pkt->u;
// 	decrypt_t		*decrypt;
// 	char			 pass[MAX_PASSPHRASE_LENGTH];
//
// 	decrypt = pgp_callback_arg(cbinfo);
// 	switch (pkt->tag) {
// 	case PGP_PARSER_PTAG:
// 	case PGP_PTAG_CT_USER_ID:
// 	case PGP_PTAG_CT_SIGNATURE:
// 	case PGP_PTAG_CT_SIGNATURE_HEADER:
// 	case PGP_PTAG_CT_SIGNATURE_FOOTER:
// 	case PGP_PTAG_CT_TRUST:
// 		break;
//
// 	case PGP_GET_PASSPHRASE:
// 		(void) pgp_getpassphrase(decrypt->passfp, pass, sizeof(pass));
// 		*content->skey_passphrase.passphrase = netpgp_strdup(pass);
// 		pgp_forget(pass, (unsigned)sizeof(pass));
// 		return PGP_KEEP_MEMORY;
//
// 	case PGP_PARSER_ERRCODE:
// 		switch (content->errcode.errcode) {
// 		case PGP_E_P_MPI_FORMAT_ERROR:
// 			/* Generally this means a bad passphrase */
// 			fprintf(stderr, "Bad passphrase!\n");
// 			return PGP_RELEASE_MEMORY;
//
// 		case PGP_E_P_PACKET_CONSUMED:
// 			/* And this is because of an error we've accepted */
// 			return PGP_RELEASE_MEMORY;
// 		default:
// 			break;
// 		}
// 		(void) fprintf(stderr, "parse error: %s\n",
// 				pgp_errcode(content->errcode.errcode));
// 		return PGP_FINISHED;
//
// 	case PGP_PARSER_ERROR:
// 		fprintf(stderr, "parse error: %s\n", content->error);
// 		return PGP_FINISHED;
//
// 	case PGP_PTAG_CT_SECRET_KEY:
// 		if ((decrypt->seckey = calloc(1, sizeof(*decrypt->seckey))) == NULL) {
// 			(void) fprintf(stderr, "decrypt_cb: bad alloc\n");
// 			return PGP_FINISHED;
// 		}
// 		decrypt->seckey->checkhash = calloc(1, PGP_CHECKHASH_SIZE);
// 		*decrypt->seckey = content->seckey; /* XXX WTF ? */
// 		return PGP_KEEP_MEMORY;
//
// 	case PGP_PARSER_PACKET_END:
// 		/* nothing to do */
// 		break;
//
// 	default:
// 		fprintf(stderr, "Unexpected tag %d (0x%x)\n", pkt->tag,
// 			pkt->tag);
// 		return PGP_FINISHED;
// 	}
//
// 	return PGP_RELEASE_MEMORY;
// }

// FIXME : support encrypted seckeys again
// /**
// \ingroup Core_Keys
// \brief Decrypts secret key from given keydata with given passphrase
// \param key Key from which to get secret key
// \param passphrase Passphrase to use to decrypt secret key
// \return secret key
// */
// pgp_seckey_t *
// pgp_decrypt_seckey(const pgp_key_t *key, void *passfp)
// {
// 	pgp_stream_t	*stream;
// 	const int	 printerrors = 1;
// 	decrypt_t	 decrypt;
//
// 	(void) memset(&decrypt, 0x0, sizeof(decrypt));
// 	decrypt.key = key;
// 	decrypt.passfp = passfp;
// 	stream = pgp_new(sizeof(*stream));
// 	pgp_keydata_reader_set(stream, key);
// 	pgp_set_callback(stream, decrypt_cb, &decrypt);
// 	stream->readinfo.accumulate = 1;
// 	pgp_parse(stream, !printerrors);
// 	return decrypt.seckey;
// }

/* \todo check where userid pointers are copied */
/**
\ingroup Core_Keys
\brief Copy user id, including contents
\param dst Destination User ID
\param src Source User ID
\note If dst already has a userid, it will be freed.
*/
uint8_t *
pgp_copy_userid(uint8_t **dst, const uint8_t *src)
{
	size_t          len;

	len = strlen((const char *) src);
	if (*dst) {
		free(*dst);
	}
	if ((*dst = calloc(1, len + 1)) == NULL) {
		(void) fprintf(stderr, "pgp_copy_userid: bad alloc\n");
	} else {
		(void) memcpy(*dst, src, len);
	}
	return *dst;
}

/* \todo check where pkt pointers are copied */
/**
\ingroup Core_Keys
\brief Copy packet, including contents
\param dst Destination packet
\param src Source packet
\note If dst already has a packet, it will be freed.
*/
pgp_subpacket_t *
pgp_copy_packet(pgp_subpacket_t *dst, const pgp_subpacket_t *src)
{
	if (dst->raw) {
		free(dst->raw);
	}
	if ((dst->raw = calloc(1, src->length)) == NULL) {
		(void) fprintf(stderr, "pgp_copy_packet: bad alloc\n");
	} else {
		dst->length = src->length;
		(void) memcpy(dst->raw, src->raw, src->length);
	}

	return dst;
}

#if 0
/**
\ingroup Core_Keys
\brief Add User ID to key
\param key Key to which to add User ID
\param userid User ID to add
\return Pointer to new User ID
*/
uint8_t  *
pgp_add_userid(pgp_key_t *key, const uint8_t *userid)
{
	uint8_t  **uidp;

	EXPAND_ARRAY(key, uid);
	/* initialise new entry in array */
	uidp = &key->uids[key->uidc++];
	*uidp = NULL;
	/* now copy it */
	return pgp_copy_userid(uidp, userid);
}
#endif

void print_packet_hex(const pgp_subpacket_t *pkt);

/**
\ingroup Core_Keys
\brief Add selfsigned User ID to key
\param keydata Key to which to add user ID
\param userid Self-signed User ID to add
\return 1 if OK; else 0
*/
#if 0 //////
unsigned
pgp_add_selfsigned_userid(pgp_key_t *skey, pgp_key_t *pkey, const uint8_t *userid, time_t key_expiry)
{
	pgp_create_sig_t	*sig;
	pgp_subpacket_t	 sigpacket;
	pgp_memory_t		*mem_sig = NULL;
	pgp_output_t		*sigoutput = NULL;

	/*
     * create signature packet for this userid
     */

	/* create sig for this pkt */
	sig = pgp_create_sig_new();
	pgp_sig_start_key_sig(sig, &skey->key.seckey.pubkey, userid, PGP_CERT_POSITIVE);

	pgp_add_creation_time(sig, time(NULL));
	pgp_add_key_expiration_time(sig, key_expiry);
	pgp_add_issuer_keyid(sig, skey->pubkeyid);
	pgp_add_primary_userid(sig, 1);
    pgp_add_key_flags(sig, PGP_KEYFLAG_SIGN_DATA|PGP_KEYFLAG_ENC_COMM);
    pgp_add_key_prefs(sig);
    pgp_add_key_features(sig);

	pgp_end_hashed_subpkts(sig);

	pgp_setup_memory_write(&sigoutput, &mem_sig, 128);
	pgp_write_sig(sigoutput, sig, &skey->key.seckey.pubkey, &skey->key.seckey);

	/* add this packet to key */
	sigpacket.length = pgp_mem_len(mem_sig);
	sigpacket.raw = pgp_mem_data(mem_sig);

	/* add user id and signature to key */
    pgp_update_userid(skey, userid, &sigpacket, &sig->sig.info);
    if(pkey)
        pgp_update_userid(pkey, userid, &sigpacket, &sig->sig.info);

	/* cleanup */
	pgp_create_sig_delete(sig);
	pgp_output_delete(sigoutput);
	pgp_memory_free(mem_sig);

	return 1;
}
#endif //////

unsigned
pgp_key_revoke(pgp_key_t *skey, pgp_key_t *pkey, uint8_t code, const char *reason)
{
	pgp_create_sig_t	*sig;
	pgp_subpacket_t	 sigpacket;
	pgp_memory_t		*mem_sig = NULL;
	pgp_output_t		*sigoutput = NULL;

	sig = pgp_create_sig_new();
	pgp_sig_start_key_rev(
            sig, &skey->key.seckey.pubkey,
            PGP_SIG_REV_KEY);

	pgp_add_creation_time(sig, time(NULL));
	pgp_add_issuer_keyid(sig, skey->pubkeyid);
    pgp_add_revocation_reason(sig, code, reason);
	pgp_end_hashed_subpkts(sig);

	pgp_setup_memory_write(&sigoutput, &mem_sig, 128);
	pgp_write_sig(sigoutput, sig, &skey->key.seckey.pubkey, &skey->key.seckey);

	sigpacket.length = pgp_mem_len(mem_sig);
	sigpacket.raw = pgp_mem_data(mem_sig);

    pgp_add_directsig(skey, &sigpacket, &sig->sig.info);
    pgp_add_directsig(pkey, &sigpacket, &sig->sig.info);

	/* cleanup */
	pgp_create_sig_delete(sig);
	pgp_output_delete(sigoutput);
	pgp_memory_free(mem_sig);

	return 1;
}

/**
\ingroup Core_Keys
\brief Initialise pgp_key_t
\param keydata Keydata to initialise
\param type PGP_PTAG_CT_PUBLIC_KEY or PGP_PTAG_CT_SECRET_KEY
*/
void
pgp_keydata_init(pgp_key_t *keydata, const pgp_content_enum type)
{
	if (keydata->type != PGP_PTAG_CT_RESERVED) {
		(void) fprintf(stderr,
			"pgp_keydata_init: wrong keydata type\n");
	} else if (type != PGP_PTAG_CT_PUBLIC_KEY &&
		   type != PGP_PTAG_CT_SECRET_KEY) {
		(void) fprintf(stderr, "pgp_keydata_init: wrong type\n");
	} else {
		keydata->type = type;
	}
}

/**
   \ingroup HighLevel_KeyringRead

   \brief Reads a keyring from a file

   \param keyring Pointer to an existing pgp_keyring_t struct
   \param armour 1 if file is armoured; else 0
   \param filename Filename of keyring to be read

   \return pgp 1 if OK; 0 on error

   \note Keyring struct must already exist.

   \note Can be used with either a public or secret keyring.

   \note You must call pgp_keyring_free() after usage to free alloc-ed memory.

   \note If you call this twice on the same keyring struct, without calling
   pgp_keyring_free() between these calls, you will introduce a memory leak.

   \sa pgp_keyring_read_from_mem()
   \sa pgp_keyring_free()

*/
#if 0 //////
unsigned
pgp_keyring_fileread(pgp_io_t *io,
            pgp_keyring_t *pubring,
            pgp_keyring_t *secring,
			const unsigned armour,
			const char *filename)
{
    return pgp_filter_keys_fileread(
                io,
                pubring,
                secring,
                NULL /*certring -> self cert */,
                armour,
                filename);
}
#endif //////

/**
   \ingroup HighLevel_KeyringRead

   \brief Reads a keyring from memory

   \param keyring Pointer to existing pgp_keyring_t struct
   \param armour 1 if file is armoured; else 0
   \param mem Pointer to a pgp_memory_t struct containing keyring to be read

   \return pgp 1 if OK; 0 on error

   \note Keyring struct must already exist.

   \note Can be used with either a public or secret keyring.

   \note You must call pgp_keyring_free() after usage to free alloc-ed memory.

   \note If you call this twice on the same keyring struct, without calling
   pgp_keyring_free() between these calls, you will introduce a memory leak.

   \sa pgp_keyring_fileread
   \sa pgp_keyring_free
*/
#if 0 //////
unsigned
pgp_keyring_read_from_mem(pgp_io_t *io,
            pgp_keyring_t *pubring,
            pgp_keyring_t *secring,
            const unsigned armour,
            pgp_memory_t *mem)
{
   return pgp_filter_keys_from_mem(io,
                pubring,
                secring,
                NULL /* certring -> self certification */,
                armour,
                mem);
}
#endif //////

/**
   \ingroup HighLevel_KeyringRead

   \brief Frees keyring's contents (but not keyring itself)

   \param keyring Keyring whose data is to be freed

   \note This does not free keyring itself, just the memory alloc-ed in it.
 */
void
pgp_keyring_free(pgp_keyring_t *keyring)
{
	(void)free(keyring->keys);
	keyring->keys = NULL;
	keyring->keyc = keyring->keyvsize = 0;
}

void
pgp_keyring_purge(pgp_keyring_t *keyring)
{
	pgp_key_t *keyp;
    unsigned c = 0;
	for (keyp = keyring->keys; c < keyring->keyc; c++, keyp++) {
        pgp_key_free(keyp);
    }
    pgp_keyring_free(keyring);
}

static unsigned
deletekey( pgp_keyring_t *keyring, pgp_key_t *key, unsigned from)
{
    /* 'from' is index of key to delete */

    /* free key internals */
    pgp_key_free(key);

    /* decrement key count, vsize stays the same so no realloc needed */
    keyring->keyc--;

    /* Move following keys to fill the gap */
	for ( ; keyring && from < keyring->keyc; from += 1) {
		memcpy(&keyring->keys[from], &keyring->keys[from+1],
               sizeof(pgp_key_t));
	}

	return 1;
}

unsigned key_id_match(const pgp_pubkey_t *key, const uint8_t *keyid, void *refidarg)
{
    uint8_t *refid = refidarg;
    return (memcmp(keyid, refid, PGP_KEY_ID_SIZE) == 0);
}
/**
   \ingroup HighLevel_KeyringFind

   \brief Finds key in keyring from its Key ID

   \param keyring Keyring to be searched
   \param keyid ID of required key

   \return Pointer to key, if found; NULL, if not found

   \note This returns a pointer to the key inside the given keyring,
   not a copy.  Do not free it after use.

*/
pgp_key_t *
pgp_getkeybyid(pgp_io_t *io, const pgp_keyring_t *keyring,
			   const uint8_t *keyid, unsigned *from,
               pgp_pubkey_t **pubkey,
               pgp_seckey_t **seckey,
               unsigned checkrevoke,
               unsigned checkexpiry)
{
	uint8_t	nullid[PGP_KEY_ID_SIZE];

	(void) memset(nullid, 0x0, sizeof(nullid));
	for ( ; keyring && *from < keyring->keyc; *from += 1) {
        pgp_key_t *key = &keyring->keys[*from];
        int32_t subkeyidx;
		if (pgp_get_debug_level(__FILE__)) {
			hexdump(io->errs, "keyring keyid", key->pubkeyid, PGP_KEY_ID_SIZE);
			hexdump(io->errs, "keyid", keyid, PGP_KEY_ID_SIZE);
		}

        subkeyidx = pgp_key_find_key_conds(key, &key_id_match,
                                           (void*)keyid, NULL, NULL,
                                           checkrevoke, checkexpiry);

		if (subkeyidx != -2) {
			if (pubkey) {
				*pubkey = key_get_pubkey_from_subidx(key, NULL, subkeyidx);
			}
			if (seckey) {
				*seckey = key_get_seckey_from_subidx(key, NULL, subkeyidx);
			}
			return key;
		}
	}
	return NULL;
}

unsigned
pgp_deletekeybyid(pgp_io_t *io, pgp_keyring_t *keyring,
			   const uint8_t *keyid)
{
    unsigned from = 0;
	pgp_key_t *key;

	if ((key = (pgp_key_t *)pgp_getkeybyid(io, keyring, keyid,
                                           &from, NULL, NULL, 0, 0)) == NULL) {
		return 0;
	}
    /* 'from' is now index of key to delete */

    deletekey(keyring, key, from);

	return 1;
}

/**
   \ingroup HighLevel_KeyringFind

   \brief Finds key in keyring from its Key Fingerprint

   \param keyring Keyring to be searched
   \param fpr fingerprint of required key
   \param fpr length of required key

   \return Pointer to key, if found; NULL, if not found

   \note This returns a pointer to the key inside the given keyring,
   not a copy.  Do not free it after use.

*/

pgp_key_t *
pgp_getkeybyfpr(pgp_io_t *io, const pgp_keyring_t *keyring,
			    const uint8_t *fpr, size_t length,
                unsigned *from,
                pgp_pubkey_t **pubkey,
                unsigned checkrevoke,
                unsigned checkexpiry)
{

	for ( ; keyring && *from < keyring->keyc; *from += 1) {
        pgp_key_t *key = &keyring->keys[*from];

        pgp_fingerprint_t *kfp = &key->pubkeyfpr;

		if (kfp->length == length &&
            memcmp(kfp->fingerprint, fpr, length) == 0) {

            if(checkrevoke || checkexpiry){
                int32_t subkeyidx;

                subkeyidx = pgp_key_find_key_conds(key,
                                                   NULL, NULL,
                                                   NULL, NULL,
                                                   checkrevoke, checkexpiry);

                if (subkeyidx == -2) return NULL;
            }
			if (pubkey) {
				*pubkey = &key->key.pubkey;
			}
			return key;
		}
	}
	return NULL;
}

unsigned
pgp_deletekeybyfpr(pgp_io_t *io, pgp_keyring_t *keyring,
			      const uint8_t *fpr, size_t length)
{
    unsigned from = 0;
	pgp_key_t *key;

	if ((key = (pgp_key_t *)pgp_getkeybyfpr(io, keyring, fpr, length,
                                           &from, NULL,0,0)) == NULL) {
		return 0;
	}
    /* 'from' is now index of key to delete */

    deletekey(keyring, key, from);

	return 1;
}

#if 0
/* convert a string keyid into a binary keyid */
static void
str2keyid(const char *userid, uint8_t *keyid, size_t len)
{
	static const char	*uppers = "0123456789ABCDEF";
	static const char	*lowers = "0123456789abcdef";
	const char		*hi;
	const char		*lo;
	uint8_t			 hichar;
	uint8_t			 lochar;
	size_t			 j;
	int			 i;

	for (i = 0, j = 0 ; j < len && userid[i] && userid[i + 1] ; i += 2, j++) {
		if ((hi = strchr(uppers, userid[i])) == NULL) {
			if ((hi = strchr(lowers, userid[i])) == NULL) {
				break;
			}
			hichar = (uint8_t)(hi - lowers);
		} else {
			hichar = (uint8_t)(hi - uppers);
		}
		if ((lo = strchr(uppers, userid[i + 1])) == NULL) {
			if ((lo = strchr(lowers, userid[i + 1])) == NULL) {
				break;
			}
			lochar = (uint8_t)(lo - lowers);
		} else {
			lochar = (uint8_t)(lo - uppers);
		}
		keyid[j] = (hichar << 4) | (lochar);
	}
	keyid[j] = 0x0;
}
#endif

/* return the next key which matches, starting searching at *from */
#if 0 //////
static const pgp_key_t *
getkeybyname(pgp_io_t *io,
			const pgp_keyring_t *keyring,
			const char *name,
			unsigned *from)
{
	//const pgp_key_t	*kp;
	uint8_t			**uidp;
	unsigned    	 	 i = 0;
	pgp_key_t		*keyp;
	// unsigned		 savedstart;
	regex_t			 r;
	//uint8_t		 	 keyid[PGP_KEY_ID_SIZE + 1];
	size_t          	 len;

	if (!keyring || !name || !from) {
		return NULL;
	}
	len = strlen(name);
	if (pgp_get_debug_level(__FILE__)) {
		(void) fprintf(io->outs, "[%u] name '%s', len %zu\n",
			*from, name, len);
	}

    /* first try name as a keyid */
	// (void) memset(keyid, 0x0, sizeof(keyid));
	// str2keyid(name, keyid, sizeof(keyid));
	// if (pgp_get_debug_level(__FILE__)) {
	// 	hexdump(io->outs, "keyid", keyid, 4);
	// }
	// savedstart = *from;
	// if ((kp = pgp_getkeybyid(io, keyring, keyid, from,
    //                          NULL, NULL, 0, 0)) != NULL) {
	// 	return kp;
	// }
	// *from = savedstart;

    if (pgp_get_debug_level(__FILE__) && name != NULL) {
		(void) fprintf(io->outs, "regex match '%s' from %u\n",
			name, *from);
	}
	/* match on full name or email address as a
        - NOSUB only success/failure, no match content
        - LITERAL ignore special chars in given string
        - ICASE ignore case
     */
    if (name != NULL) {
        (void) regcomp(&r, name, REG_NOSUB | REG_LITERAL | REG_ICASE);
    }
    if(keyring->keys != NULL)
      for (keyp = &keyring->keys[*from]; *from < keyring->keyc; *from += 1, keyp++) {
		uidp = keyp->uids;
        if (name == NULL) {
            return keyp;
        } else {
            for (i = 0 ; i < keyp->uidc; i++, uidp++) {
                if (regexec(&r, (char *)*uidp, 0, NULL, 0) == 0) {
                    if (pgp_get_debug_level(__FILE__)) {
                        (void) fprintf(io->outs,
                            "MATCHED keyid \"%s\" len %" PRIsize "u\n",
                               (char *) *uidp, len);
                    }
                    regfree(&r);
                    return keyp;
                }
            }
        }
	}
	regfree(&r);
	return NULL;
}
#endif //////

/**
   \ingroup HighLevel_KeyringFind

   \brief Finds key from its User ID

   \param keyring Keyring to be searched
   \param userid User ID of required key

   \return Pointer to Key, if found; NULL, if not found

   \note This returns a pointer to the key inside the keyring, not a
   copy.  Do not free it.

*/
#if 0 //////
const pgp_key_t *
pgp_getkeybyname(pgp_io_t *io,
			const pgp_keyring_t *keyring,
			const char *name)
{
	unsigned	from;

	from = 0;
	return getkeybyname(io, keyring, name, &from);
}
#endif //////

#if 0 //////
const pgp_key_t *
pgp_getnextkeybyname(pgp_io_t *io,
			const pgp_keyring_t *keyring,
			const char *name,
			unsigned *n)
{
	return getkeybyname(io, keyring, name, n);
}
#endif //////

/* this interface isn't right - hook into callback for getting passphrase */
#if 0 //////
char *
pgp_export_key(pgp_io_t *io, const pgp_key_t *keydata, uint8_t *passphrase)
{
	pgp_output_t	*output;
	pgp_memory_t	*mem;
	char		*cp;

	__PGP_USED(io);
	pgp_setup_memory_write(&output, &mem, 128);
    pgp_write_xfer_key(output, keydata, 1);

	/* TODO deal with passphrase again
		pgp_write_xfer_seckey(output, keydata, passphrase,
					strlen((char *)passphrase), 1);
    */
	cp = netpgp_strdup(pgp_mem_data(mem));
	pgp_teardown_memory_write(output, mem);
	return cp;
}
#endif //////

/* lowlevel add to keyring */
int
pgp_keyring_add(pgp_keyring_t *dst, const pgp_key_t *src)
{
	pgp_key_t	*key;

    EXPAND_ARRAY(dst, key);
    key = &dst->keys[dst->keyc++];
	memcpy(key, src, sizeof(*key));
    return 1;
}

pgp_key_t *pgp_ensure_pubkey(
        pgp_keyring_t *keyring,
        pgp_pubkey_t *pubkey,
        uint8_t *pubkeyid)
{
    pgp_key_t *key;
    unsigned c;

    if(keyring == NULL) return NULL;

    /* try to find key in keyring */
	for (c = 0; c < keyring->keyc; c += 1) {
		if (memcmp(keyring->keys[c].pubkeyid,
                   pubkeyid, PGP_KEY_ID_SIZE) == 0) {
			return &keyring->keys[c];
		}
    }

    /* if key doesn't already exist in keyring, create it */
    EXPAND_ARRAY(keyring, key);
    key = &keyring->keys[keyring->keyc++];
    (void) memset(key, 0x0, sizeof(*key));

    /* fill in what we already know */
    key->type = PGP_PTAG_CT_PUBLIC_KEY;
    pgp_pubkey_dup(&key->key.pubkey, pubkey);
    (void) memcpy(&key->pubkeyid, pubkeyid, PGP_KEY_ID_SIZE);
    pgp_fingerprint(&key->pubkeyfpr, pubkey, keyring->hashtype);

    return key;
}

pgp_key_t *pgp_ensure_seckey(
        pgp_keyring_t *keyring,
        pgp_seckey_t *seckey,
        uint8_t *pubkeyid)
{
    pgp_key_t *key;
    unsigned c;

    if (keyring == NULL) return NULL;

    /* try to find key in keyring */
	for (c = 0; c < keyring->keyc; c += 1) {
		if (memcmp(keyring->keys[c].pubkeyid,
                   pubkeyid, PGP_KEY_ID_SIZE) == 0) {
			return &keyring->keys[c];
		}
    }

    /* if key doesn't already exist in keyring, create it */
    EXPAND_ARRAY(keyring, key);
    key = &keyring->keys[keyring->keyc++];
    (void) memset(key, 0x0, sizeof(*key));

    /* fill in what we already know */
    key->type = PGP_PTAG_CT_SECRET_KEY;
    pgp_seckey_dup(&key->key.seckey, seckey);
    (void) memcpy(&key->pubkeyid, pubkeyid, PGP_KEY_ID_SIZE);
    pgp_fingerprint(&key->pubkeyfpr, &seckey->pubkey, keyring->hashtype);

    return key;
}

unsigned pgp_add_directsig(
        pgp_key_t *key,
        const pgp_subpacket_t *sigpkt,
        pgp_sig_info_t *siginfo)
{
    pgp_directsig_t *directsigp;
    unsigned directsigidx;

    /* Detect duplicate direct sig */
    directsigp = key->directsigs;
    for (directsigidx = 0 ; directsigidx < key->directsigc;
            directsigidx++, directsigp++)
    {
        if( directsigp->packet.length == sigpkt->length &&
            memcmp(directsigp->packet.raw, sigpkt->raw, sigpkt->length) == 0)
        {
            /* signature already exist */
            return 1;
        }
    }


    EXPAND_ARRAY(key, directsig);
    directsigp = &key->directsigs[key->directsigc++];

    copy_sig_info(&directsigp->siginfo,
                  siginfo);
    pgp_copy_packet(&directsigp->packet, sigpkt);

    return 0;
}

unsigned pgp_update_userid(
        pgp_key_t *key,
        const uint8_t *userid,
        const pgp_subpacket_t *sigpkt,
        pgp_sig_info_t *siginfo)
{
	    unsigned    	 	 uididx = 0;
        unsigned    	 	 uidsigidx = 0;
        uint8_t			**uidp;
        pgp_uidsig_t    *uidsigp;

        /* Try to find identical userID */
		uidp = key->uids;
		for (uididx = 0 ; uididx < key->uidc; uididx++, uidp++)
        {
			if (strcmp((char *)*uidp, (char *)userid) == 0)
            {
                /* Found one. check for duplicate uidsig */
                uidsigp = key->uidsigs;
                for (uidsigidx = 0 ; uidsigidx < key->uidsigc;
                     uidsigidx++, uidsigp++)
                {
                    if(uidsigp->uid == uididx &&
                       uidsigp->packet.length == sigpkt->length &&
                       memcmp(uidsigp->packet.raw, sigpkt->raw,
                              sigpkt->length) == 0)
                    {
                            /* signature already exists */
                            return 1;
                    }
                }
				break;
			}
		}

        /* Add a new one if none found */
        if(uididx==key->uidc){
            EXPAND_ARRAY(key, uid);
            uidp = &key->uids[key->uidc++];
            *uidp = NULL;
            pgp_copy_userid(uidp, userid);
        }

        /* Add uid sig info, pointing to that uid */
		EXPAND_ARRAY(key, uidsig);
        uidsigp = &key->uidsigs[key->uidsigc++];
		uidsigp->uid = uididx;

        /* store sig info and packet */
        copy_sig_info(&uidsigp->siginfo, siginfo);
        pgp_copy_packet(&uidsigp->packet, sigpkt);

        return 0;
}

unsigned pgp_update_subkey(
        pgp_key_t *key,
	    pgp_content_enum subkeytype,
        pgp_keydata_key_t *subkey,
        const pgp_subpacket_t *sigpkt,
        pgp_sig_info_t *siginfo)
{
	    unsigned    	 	 subkeyidx = 0;
        unsigned    	 	 subkeysigidx = 0;
        pgp_subkey_t	 *subkeyp;
        pgp_subkeysig_t    *subkeysigp;
        uint8_t subkeyid[PGP_KEY_ID_SIZE];

        pgp_keyid(subkeyid, PGP_KEY_ID_SIZE,
                  (subkeytype == PGP_PTAG_CT_PUBLIC_KEY) ?
                  &subkey->pubkey:
                  &subkey->seckey.pubkey, PGP_HASH_SHA1);

        /* Try to find identical subkey ID */
		subkeyp = key->subkeys;
		for (subkeyidx = 0 ; subkeyidx < key->subkeyc; subkeyidx++, subkeyp++)
        {
            if(memcmp(subkeyid, subkeyp->id, PGP_KEY_ID_SIZE) == 0 )
            {
                /* Found same subkey. Detect duplicate sig */
                subkeysigp = key->subkeysigs;
                for (subkeysigidx = 0 ; subkeysigidx < key->subkeysigc;
                        subkeysigidx++, subkeysigp++)
                {
                    if(subkeysigp->subkey == subkeyidx &&
                       subkeysigp->packet.length == sigpkt->length &&
                       memcmp(subkeysigp->packet.raw, sigpkt->raw,
                              sigpkt->length) == 0)
                    {
                            /* signature already exists */
                            return 1;
                    }
                }

				break;
			}
		}
        /* Add a new one if none found */
        if(subkeyidx==key->subkeyc){
            if(subkeytype == PGP_PTAG_CT_PUBLIC_KEY &&
               key->type != PGP_PTAG_CT_PUBLIC_KEY){
                /* cannot create secret subkey from public */
                /* and may not insert public subkey in seckey */
                return 1;
            }

            EXPAND_ARRAY(key, subkey);
            subkeyp = &key->subkeys[key->subkeyc++];
            /* copy subkey material */
            if(key->type == PGP_PTAG_CT_PUBLIC_KEY) {
                pgp_pubkey_dup(&subkeyp->key.pubkey,
                  (subkeytype == PGP_PTAG_CT_PUBLIC_KEY) ?
                  &subkey->pubkey:
                  &subkey->seckey.pubkey);
            } else {
                pgp_seckey_dup(&subkeyp->key.seckey, &subkey->seckey);
            }
            /* copy subkeyID */
            memcpy(subkeyp->id, subkeyid, PGP_KEY_ID_SIZE);
        }

        /* Add subkey sig info, pointing to that subkey */
		EXPAND_ARRAY(key, subkeysig);
        subkeysigp = &key->subkeysigs[key->subkeysigc++];
		subkeysigp->subkey = subkeyidx;

        /* store sig info and packet */
        copy_sig_info(&subkeysigp->siginfo,
                      siginfo);
        pgp_copy_packet(&subkeysigp->packet, sigpkt);

        return 0;
}

/* append one keyring to another */
int
pgp_append_keyring(pgp_keyring_t *keyring, pgp_keyring_t *newring)
{
	unsigned	i;

	for (i = 0 ; i < newring->keyc ; i++) {
		EXPAND_ARRAY(keyring, key);
		(void) memcpy(&keyring->keys[keyring->keyc], &newring->keys[i],
				sizeof(newring->keys[i]));
		keyring->keyc += 1;
	}
	return 1;
}
