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
#include "netpgp/config-netpgp.h"

#ifdef HAVE_SYS_CDEFS_H
#include <sys/cdefs.h>
#endif

#if defined(__NetBSD__)
__COPYRIGHT("@(#) Copyright (c) 2009 The NetBSD Foundation, Inc. All rights reserved.");
__RCSID("$NetBSD$");
#endif

#include <sys/types.h>
#include <sys/param.h>
#include <sys/stat.h>

#include <string.h>
#include <stdio.h>

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif

#include "netpgp/packet-parse.h"
#include "netpgp/packet-show.h"
#include "netpgp/keyring.h"
#include "netpgp/signature.h"
#include "netpgp/netpgpsdk.h"
#include "netpgp/readerwriter.h"
#include "netpgp/netpgpdefs.h"
#include "netpgp/memory.h"
#include "netpgp/packet.h"
#include "netpgp/crypto.h"
#include "netpgp/validate.h"

#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif

#if defined(ANDROID) || defined(__ANDROID__)
char* getpass (const char *prompt)
{
	return strdup("");
}
#endif

// FIXME to support seckey decryption again.
//
// static int
// keydata_reader(pgp_stream_t *stream, void *dest, size_t length, pgp_error_t **errors,
// 	       pgp_reader_t *readinfo,
// 	       pgp_cbdata_t *cbinfo)
// {
// 	validate_reader_t *reader = pgp_reader_get_arg(readinfo);
//
// 	__PGP_USED(stream);
// 	__PGP_USED(errors);
// 	__PGP_USED(cbinfo);
// 	if (reader->offset == reader->key->packets[reader->packet].length) {
// 		reader->packet += 1;
// 		reader->offset = 0;
// 	}
// 	if (reader->packet == reader->key->packetc) {
// 		return 0;
// 	}
//
// 	/*
// 	 * we should never be asked to cross a packet boundary in a single
// 	 * read
// 	 */
// 	if (reader->key->packets[reader->packet].length <
// 			reader->offset + length) {
// 		(void) fprintf(stderr, "keydata_reader: weird length\n");
// 		return 0;
// 	}
//
// 	(void) memcpy(dest,
// 		&reader->key->packets[reader->packet].raw[reader->offset],
// 		length);
// 	reader->offset += (unsigned)length;
//
// 	return (int)length;
// }

static void
free_sig_info(pgp_sig_info_t *sig)
{
    pgp_free_sig_info(sig);
	free(sig);
}


static int
add_sig_to_list(const pgp_sig_info_t *sig, pgp_sig_info_t **sigs,
			unsigned *count)
{
	pgp_sig_info_t	*newsigs;

	if (*count == 0) {
		newsigs = calloc(*count + 1, sizeof(pgp_sig_info_t));
	} else {
		newsigs = realloc(*sigs,
				(*count + 1) * sizeof(pgp_sig_info_t));
	}
	if (newsigs == NULL) {
		(void) fprintf(stderr, "add_sig_to_list: alloc failure\n");
		return 0;
	}
	*sigs = newsigs;
	copy_sig_info(&(*sigs)[*count], sig);
	*count += 1;
	return 1;
}

/*
The hash value is calculated by the following method:
+ hash the data using the given digest algorithm
+ hash the hash value onto the end
+ hash the trailer - 6 bytes
  [PGP_V4][0xff][len >> 24][len >> 16][len >> 8][len & 0xff]
to give the final hash value that is checked against the one in the signature
*/

/* Does the signed hash match the given hash? */
static unsigned
check_binary_sig(const uint8_t *data,
		const unsigned len,
		const pgp_sig_t *sig,
		const pgp_pubkey_t *signer)
{
	unsigned    hashedlen;
	pgp_hash_t	hash;
	unsigned	n;
	uint8_t		hashout[PGP_MAX_HASH_SIZE];
	uint8_t		trailer[6];

	pgp_hash_any(&hash, sig->info.hash_alg);
	if (!hash.init(&hash)) {
		(void) fprintf(stderr, "check_binary_sig: bad hash init\n");
		return 0;
	}
	hash.add(&hash, data, len);
	switch (sig->info.version) {
	case PGP_V3:
		trailer[0] = sig->info.type;
		trailer[1] = (unsigned)(sig->info.birthtime) >> 24;
		trailer[2] = (unsigned)(sig->info.birthtime) >> 16;
		trailer[3] = (unsigned)(sig->info.birthtime) >> 8;
		trailer[4] = (uint8_t)(sig->info.birthtime);
		hash.add(&hash, trailer, 5);
		break;

	case PGP_V4:
		if (pgp_get_debug_level(__FILE__)) {
			hexdump(stderr, "v4 hash", sig->info.v4_hashed,
					sig->info.v4_hashlen);
		}
		hash.add(&hash, sig->info.v4_hashed, (unsigned)sig->info.v4_hashlen);
		trailer[0] = 0x04;	/* version */
		trailer[1] = 0xFF;
		hashedlen = (unsigned)sig->info.v4_hashlen;
		trailer[2] = (uint8_t)(hashedlen >> 24);
		trailer[3] = (uint8_t)(hashedlen >> 16);
		trailer[4] = (uint8_t)(hashedlen >> 8);
		trailer[5] = (uint8_t)(hashedlen);
		hash.add(&hash, trailer, 6);
		break;

	default:
		(void) fprintf(stderr, "Invalid signature version %d\n",
				sig->info.version);
		return 0;
	}

	n = hash.finish(&hash, hashout);
	if (pgp_get_debug_level(__FILE__)) {
		hexdump(stdout, "hash out", hashout, n);
	}
	return pgp_check_sig(hashout, n, sig, signer);
}

static void validate_key_cb_free (validate_key_cb_t *vdata){

    /* Free according to previous allocated type */
    if (vdata->type == PGP_PTAG_CT_PUBLIC_KEY) {
        pgp_pubkey_free(&vdata->key.pubkey);
        pgp_pubkey_free(&vdata->subkey.pubkey);
    } else if (vdata->type == PGP_PTAG_CT_SECRET_KEY) {
        pgp_seckey_free(&vdata->key.seckey);
        if(vdata->subkey.seckey.pubkey.alg)
            pgp_seckey_free(&vdata->subkey.seckey);
    }
    memset(&vdata->key, 0, sizeof(vdata->key));
    memset(&vdata->subkey, 0, sizeof(vdata->subkey));
	vdata->type = PGP_PTAG_CT_RESERVED; /* 0 */

	pgp_userid_free(&vdata->userid);
	pgp_data_free(&vdata->userattr);

	if(vdata->valid_sig_info.key_alg) {
        pgp_free_sig_info(&vdata->valid_sig_info);
    }
}

static pgp_cb_ret_t
pgp_validate_key_cb(const pgp_packet_t *pkt, pgp_cbdata_t *cbinfo)
{
	const pgp_contents_t	 *content = &pkt->u;
	validate_key_cb_t	 *vdata;
	pgp_error_t		**errors;
	pgp_io_t		 *io;
	unsigned		  valid = 0;

	io = cbinfo->io;
	if (pgp_get_debug_level(__FILE__)) {
		(void) fprintf(io->errs, "%s\n",
				pgp_show_packet_tag(pkt->tag));
	}
	vdata = pgp_callback_arg(cbinfo);
	errors = pgp_callback_errors(cbinfo);

    vdata->sig_is_valid &= pkt->tag == PGP_PARSER_PACKET_END;

	switch (pkt->tag) {
	case PGP_PTAG_CT_PUBLIC_KEY:
        validate_key_cb_free(vdata);
		vdata->key.pubkey = content->pubkey;
	    pgp_keyid(vdata->pubkeyid, PGP_KEY_ID_SIZE,
                  &vdata->key.pubkey, PGP_HASH_SHA1); /* TODO v3*/

		vdata->last_seen = LS_PRIMARY;
	    vdata->type = PGP_PTAG_CT_PUBLIC_KEY;
        vdata->not_commited = 1;
		return PGP_KEEP_MEMORY;

	case PGP_PTAG_CT_SECRET_KEY:
        /* check pubkey seckey consistency  */
        validate_key_cb_free(vdata);
        vdata->key.seckey = content->seckey;
        pgp_keyid(vdata->pubkeyid, PGP_KEY_ID_SIZE,
                  &vdata->key.seckey.pubkey, PGP_HASH_SHA1); /* TODO v3*/
        vdata->last_seen = LS_PRIMARY;
        vdata->type = PGP_PTAG_CT_SECRET_KEY;
        vdata->not_commited = 1;
		return PGP_KEEP_MEMORY;

	case PGP_PTAG_CT_PUBLIC_SUBKEY:
		if(vdata->type == PGP_PTAG_CT_PUBLIC_KEY && (
		       vdata->last_seen == LS_SUBKEY || /* eg. K-9 has keys with multipe subkeys */
               vdata->last_seen == LS_ID ||
               vdata->last_seen == LS_ATTRIBUTE)){
            pgp_pubkey_free(&vdata->subkey.pubkey);
            vdata->subkey.pubkey = content->pubkey;
            vdata->last_seen = LS_SUBKEY;
            return PGP_KEEP_MEMORY;
        }else{
            (void) fprintf(io->errs,
                "pgp_validate_key_cb: unexpected public subkey packet");
            vdata->last_seen = LS_UNKNOWN;
			return PGP_RELEASE_MEMORY;
        }

	case PGP_PTAG_CT_SECRET_SUBKEY:
        /* check pubkey seckey consistency */
		if(vdata->type == PGP_PTAG_CT_SECRET_KEY && (
               vdata->last_seen == LS_ID ||
               vdata->last_seen == LS_ATTRIBUTE)){
	        if(vdata->subkey.seckey.pubkey.alg)
                pgp_seckey_free(&vdata->subkey.seckey);
            vdata->subkey.seckey = content->seckey;
            vdata->last_seen = LS_SUBKEY;
            return PGP_KEEP_MEMORY;
        }else{
            (void) fprintf(io->errs,
                "pgp_validate_key_cb: unexpected secret subkey packet");
            vdata->last_seen = LS_UNKNOWN;
			return PGP_RELEASE_MEMORY;
        }

	case PGP_PTAG_CT_USER_ID:
		if(vdata->last_seen == LS_PRIMARY ||
           vdata->last_seen == LS_ATTRIBUTE ||
           vdata->last_seen == LS_ID){
            if (vdata->userid) {
                pgp_userid_free(&vdata->userid);
            }
            vdata->userid = content->userid;
            vdata->last_seen = LS_ID;
            return PGP_KEEP_MEMORY;
        }else{
            (void) fprintf(io->errs,
                "pgp_validate_key_cb: unexpected userID packet");
            vdata->last_seen = LS_UNKNOWN;
			return PGP_RELEASE_MEMORY;
        }

	case PGP_PTAG_CT_USER_ATTR:
		if(vdata->last_seen == LS_PRIMARY ||
           vdata->last_seen == LS_ATTRIBUTE ||
           vdata->last_seen == LS_ID){
            if (content->userattr.len == 0) {
                (void) fprintf(io->errs,
                    "pgp_validate_key_cb: user attribute length 0");
                vdata->last_seen = LS_UNKNOWN;
			    return PGP_RELEASE_MEMORY;
            }
            (void) fprintf(io->outs, "user attribute, length=%d\n",
                (int) content->userattr.len);
            if (vdata->userattr.len) {
                pgp_data_free(&vdata->userattr);
            }
            vdata->userattr = content->userattr;
            vdata->last_seen = LS_ATTRIBUTE;
            return PGP_KEEP_MEMORY;
        }else{
			(void) fprintf(io->errs,
				"pgp_validate_key_cb: unexpected user attribute\n");
            vdata->last_seen = LS_UNKNOWN;
			return PGP_RELEASE_MEMORY;
        }
	case PGP_PTAG_CT_SIGNATURE:	/* V3 sigs */
	case PGP_PTAG_CT_SIGNATURE_FOOTER:{	/* V4 sigs */
        pgp_pubkey_t *sigkey = NULL;
        pgp_pubkey_t *primary_pubkey;

		if(vdata->last_seen == LS_UNKNOWN)
            break;

        primary_pubkey =
                   (vdata->type == PGP_PTAG_CT_PUBLIC_KEY) ?
                       &vdata->key.pubkey:
                       &vdata->key.seckey.pubkey;

        if(vdata->keyring){
            unsigned		  from;
            from = 0;
            /* Returned key ignored, care about ID-targeted pubkey only */
            pgp_getkeybyid(io, vdata->keyring,
                         content->sig.info.signer_id,
                         &from, &sigkey, NULL,
                         1, 0); /* reject revoked, accept expired */
        } else {
            /* If no keyring is given to check against
             * then this is a self certification check.
             * First ensure signature issuer ID is pubkey's ID*/
            if(memcmp(vdata->pubkeyid,
                      content->sig.info.signer_id,
                      PGP_KEY_ID_SIZE) == 0){
                sigkey = primary_pubkey;
            }
        }
        if (!sigkey) {
            if (vdata->result && !add_sig_to_list(&content->sig.info,
                &vdata->result->unknown_sigs,
                &vdata->result->unknownc)) {
                    (void) fprintf(io->errs,
                    "pgp_validate_key_cb: out of memory");
                    return PGP_FINISHED;
            }
            break;
        }
		switch (content->sig.info.type) {
		case PGP_CERT_GENERIC:
		case PGP_CERT_PERSONA:
		case PGP_CERT_CASUAL:
		case PGP_CERT_POSITIVE:
		case PGP_SIG_REV_CERT:
			if(vdata->last_seen == LS_ID){
			    valid = pgp_check_useridcert_sig(
                    primary_pubkey,
					vdata->userid,
					&content->sig,
					sigkey);
            } else if(vdata->last_seen == LS_ATTRIBUTE) {
			    valid = pgp_check_userattrcert_sig(
                    primary_pubkey,
					&vdata->userattr,
					&content->sig,
                    sigkey);
            }
			break;

		case PGP_SIG_REV_SUBKEY:
		case PGP_SIG_SUBKEY:
			/*
			 * we ensure that the signing key is the
			 * primary key we are validating, "vdata->pubkey".
			 */
			if(vdata->last_seen == LS_SUBKEY &&
               memcmp(vdata->pubkeyid,
                      content->sig.info.signer_id,
                      PGP_KEY_ID_SIZE) == 0 )
            {
                valid = pgp_check_subkey_sig(
                    primary_pubkey,
                    (vdata->type == PGP_PTAG_CT_PUBLIC_KEY) ?
                        &vdata->subkey.pubkey:
                        &vdata->subkey.seckey.pubkey,
                    &content->sig,
                    primary_pubkey);
            }
			break;

		case PGP_SIG_REV_KEY:
		case PGP_SIG_DIRECT:
			if(vdata->last_seen == LS_PRIMARY){
                valid = pgp_check_direct_sig(
                    primary_pubkey,
                    &content->sig,
                    sigkey);
            }
			break;

		case PGP_SIG_STANDALONE:
		case PGP_SIG_PRIMARY:
		case PGP_SIG_TIMESTAMP:
		case PGP_SIG_3RD_PARTY:
            if (vdata->result){
                PGP_ERROR_1(errors, PGP_E_UNIMPLEMENTED,
                    "Sig Verification type 0x%02x not done yet\n",
                    content->sig.info.type);
                break;
            }

		default:
            if (vdata->result){
                PGP_ERROR_1(errors, PGP_E_UNIMPLEMENTED,
                        "Unexpected signature type 0x%02x\n",
                            content->sig.info.type);
            }
		}

		if (valid) {
			if (vdata->result && !add_sig_to_list(&content->sig.info,
				&vdata->result->valid_sigs,
				&vdata->result->validc)) {
				PGP_ERROR_1(errors, PGP_E_UNIMPLEMENTED, "%s",
				    "Can't add valid sig to list\n");
			}
	        vdata->sig_is_valid = 1;
            copy_sig_info(&vdata->valid_sig_info,
                          &content->sig.info);
		} else if (vdata->result){
			PGP_ERROR_1(errors, PGP_E_V_BAD_SIGNATURE, "%s",
			    "Bad Sig");
			if (!add_sig_to_list(&content->sig.info,
				&vdata->result->invalid_sigs,
				&vdata->result->invalidc)) {
				PGP_ERROR_1(errors, PGP_E_UNIMPLEMENTED, "%s",
				    "Can't add invalid sig to list\n");
			}
		}
		break;
    }
	case PGP_PARSER_PACKET_END:
        if(vdata->sig_is_valid){
            pgp_cb_ret_t ret = PGP_RELEASE_MEMORY;
            if(vdata->on_valid){
                ret = vdata->on_valid(vdata, &content->packet);
            }
	        vdata->sig_is_valid = 0;
            vdata->not_commited = 0;
            return ret;
        }
        return PGP_RELEASE_MEMORY;

	/* ignore these */
	case PGP_PARSER_PTAG:
	case PGP_PTAG_CT_SIGNATURE_HEADER:
	case PGP_PTAG_CT_TRUST:
		break;

	// case PGP_GET_PASSPHRASE:
	// 	if (vdata->getpassphrase) {
	// 		return vdata->getpassphrase(pkt, cbinfo);
	// 	}
	// 	break;

	default:
		// (void) fprintf(stderr, "unexpected tag=0x%x\n", pkt->tag);
	    return PGP_RELEASE_MEMORY;
	}
	return PGP_RELEASE_MEMORY;
}

pgp_cb_ret_t
validate_data_cb(const pgp_packet_t *pkt, pgp_cbdata_t *cbinfo)
{
	const pgp_contents_t	 *content = &pkt->u;
    pgp_key_t	 *signer;
	validate_data_cb_t	 *data;
	pgp_pubkey_t		 *sigkey;
	pgp_error_t		**errors;
	pgp_io_t		 *io;
	unsigned		  from;
	unsigned		  valid = 0;

	io = cbinfo->io;
	if (pgp_get_debug_level(__FILE__)) {
		(void) fprintf(io->errs, "validate_data_cb: %s\n",
				pgp_show_packet_tag(pkt->tag));
	}
	data = pgp_callback_arg(cbinfo);
	errors = pgp_callback_errors(cbinfo);
	switch (pkt->tag) {
	case PGP_PTAG_CT_SIGNED_CLEARTEXT_HEADER:
		/*
		 * ignore - this gives us the "Armor Header" line "Hash:
		 * SHA1" or similar
		 */
		break;

	case PGP_PTAG_CT_LITDATA_HEADER:
		/* ignore */
		break;

	case PGP_PTAG_CT_LITDATA_BODY:
		data->data.litdata_body = content->litdata_body;
		data->type = LITDATA;
		pgp_memory_add(data->mem, data->data.litdata_body.data,
				       data->data.litdata_body.length);
		return PGP_KEEP_MEMORY;

	case PGP_PTAG_CT_SIGNED_CLEARTEXT_BODY:
		data->data.cleartext_body = content->cleartext_body;
		data->type = SIGNED_CLEARTEXT;
		pgp_memory_add(data->mem, data->data.cleartext_body.data,
			       data->data.cleartext_body.length);
		return PGP_KEEP_MEMORY;

	case PGP_PTAG_CT_SIGNED_CLEARTEXT_TRAILER:
		/* this gives us an pgp_hash_t struct */
		break;

	case PGP_PTAG_CT_SIGNATURE:	/* V3 sigs */
	case PGP_PTAG_CT_SIGNATURE_FOOTER:	/* V4 sigs */
		if (pgp_get_debug_level(__FILE__)) {
			hexdump(io->outs, "hashed data", content->sig.info.v4_hashed,
					content->sig.info.v4_hashlen);
			hexdump(io->outs, "signer id", content->sig.info.signer_id,
				sizeof(content->sig.info.signer_id));
		}
		from = 0;
        sigkey = NULL;
		signer = pgp_getkeybyid(io, data->keyring,
					 content->sig.info.signer_id, &from, &sigkey, NULL,
                     0, 0); /* check neither revocation nor expiry */
		if (!signer || !sigkey) {
			PGP_ERROR_1(errors, PGP_E_V_UNKNOWN_SIGNER,
			    "%s", "Unknown Signer");
			if (!add_sig_to_list(&content->sig.info,
					&data->result->unknown_sigs,
					&data->result->unknownc)) {
				PGP_ERROR_1(errors, PGP_E_V_UNKNOWN_SIGNER,
				    "%s", "Can't add unknown sig to list");
			}
			break;
		}
		if (content->sig.info.birthtime_set) {
			data->result->birthtime = content->sig.info.birthtime;
		}
		if (content->sig.info.duration_set) {
			data->result->duration = content->sig.info.duration;
		}
		switch (content->sig.info.type) {
		case PGP_SIG_BINARY:
		case PGP_SIG_TEXT:
			if (pgp_mem_len(data->mem) == 0){
               if(data->detachname) {
				/* check we have seen some data */
				/* if not, need to read from detached name */
				(void) fprintf(io->errs,
				"netpgp: assuming signed data in \"%s\"\n",
					data->detachname);
				data->mem = pgp_memory_new();
				pgp_mem_readfile(data->mem, data->detachname);
               }
            }
			if (pgp_get_debug_level(__FILE__)) {
				hexdump(stderr, "sig dump", (const uint8_t *)(const void *)&content->sig,
					sizeof(content->sig));
			}
			valid = check_binary_sig(pgp_mem_data(data->mem),
					(const unsigned)pgp_mem_len(data->mem),
					&content->sig,
					sigkey);
			break;

		default:
			PGP_ERROR_1(errors, PGP_E_UNIMPLEMENTED,
				    "No Sig Verification type 0x%02x yet\n",
				    content->sig.info.type);
			break;

		}

		if (valid) {
			if (!add_sig_to_list(&content->sig.info,
					&data->result->valid_sigs,
					&data->result->validc)) {
				PGP_ERROR_1(errors, PGP_E_V_BAD_SIGNATURE,
				    "%s", "Can't add good sig to list");
			}
		} else {
			PGP_ERROR_1(errors, PGP_E_V_BAD_SIGNATURE,
			    "%s", "Bad Signature");
			if (!add_sig_to_list(&content->sig.info,
					&data->result->invalid_sigs,
					&data->result->invalidc)) {
				PGP_ERROR_1(errors, PGP_E_V_BAD_SIGNATURE, "%s",
					"Can't add good sig to list");
			}
		}
		break;

		/* ignore these */
	case PGP_PARSER_PTAG:
	case PGP_PTAG_CT_SIGNATURE_HEADER:
	case PGP_PTAG_CT_ARMOUR_HEADER:
	case PGP_PTAG_CT_ARMOUR_TRAILER:
	case PGP_PTAG_CT_1_PASS_SIG:
		break;

	case PGP_PARSER_PACKET_END:
		break;

	default:
		PGP_ERROR_1(errors, PGP_E_V_NO_SIGNATURE, "%s", "No signature");
		break;
	}
	return PGP_RELEASE_MEMORY;
}

#if 0 //////
static char *
fmtsecs(int64_t n, char *buf, size_t size)
{
	if (n > 365 * 24 * 60 * 60) {
		n /= (365 * 24 * 60 * 60);
		(void) snprintf(buf, size, "%" PRId64 " year%s", n, (n == 1) ? "" : "s");
		return buf;
	}
	if (n > 30 * 24 * 60 * 60) {
		n /= (30 * 24 * 60 * 60);
		(void) snprintf(buf, size, "%" PRId64 " month%s", n, (n == 1) ? "" : "s");
		return buf;
	}
	if (n > 24 * 60 * 60) {
		n /= (24 * 60 * 60);
		(void) snprintf(buf, size, "%" PRId64 " day%s", n, (n == 1) ? "" : "s");
		return buf;
	}
	if (n > 60 * 60) {
		n /= (60 * 60);
		(void) snprintf(buf, size, "%" PRId64 " hour%s", n, (n == 1) ? "" : "s");
		return buf;
	}
	if (n > 60) {
		n /= 60;
		(void) snprintf(buf, size, "%" PRId64 " minute%s", n, (n == 1) ? "" : "s");
		return buf;
	}
	(void) snprintf(buf, size, "%" PRId64 " second%s", n, (n == 1) ? "" : "s");
	return buf;
}
#endif //////

/**
 * \ingroup HighLevel_Verify
 * \brief Indicicates whether any errors were found
 * \param result Validation result to check
 * \return 0 if any invalid signatures or unknown signers
 	or no valid signatures; else 1
 */
#if 0 //////
static unsigned
validate_result_status(FILE *errs, const char *f, pgp_validation_t *val)
{
	time_t	now;
	time_t	t;
	char	buf[128];

	now = time(NULL);
	if (now < val->birthtime) {
		/* signature is not valid yet! */
		if (f) {
			(void) fprintf(errs, "\"%s\": ", f);
		} else {
			(void) fprintf(errs, "memory ");
		}
		(void) fprintf(errs,
			"signature not valid until %.24s (%s)\n",
			ctime(&val->birthtime),
			fmtsecs((int64_t)(val->birthtime - now), buf, sizeof(buf)));
		return 0;
	}
	if (val->duration != 0 && now > val->birthtime + val->duration) {
		/* signature has expired */
		t = val->duration + val->birthtime;
		if (f) {
			(void) fprintf(errs, "\"%s\": ", f);
		} else {
			(void) fprintf(errs, "memory ");
		}
		(void) fprintf(errs,
			"signature not valid after %.24s (%s ago)\n",
			ctime(&t),
			fmtsecs((int64_t)(now - t), buf, sizeof(buf)));
		return 0;
	}
	return val->validc && !val->invalidc && !val->unknownc;
}
#endif //////

typedef struct key_filter_cb_t{
	pgp_keyring_t *destpubring;
	pgp_keyring_t *destsecring;
    pgp_key_t *pubkey;
    pgp_key_t *seckey;
} key_filter_cb_t;

static pgp_cb_ret_t key_filter_cb (
    validate_key_cb_t *vdata,
    const pgp_subpacket_t *sigpkt)
{
    pgp_key_t		*pubkey = NULL;
    pgp_key_t		*seckey = NULL;
    key_filter_cb_t *filter = vdata->on_valid_args;

    if(vdata->not_commited){

        if((filter->pubkey = pgp_ensure_pubkey(filter->destpubring,
                (vdata->type == PGP_PTAG_CT_PUBLIC_KEY) ?
                    &vdata->key.pubkey :
                    &vdata->key.seckey.pubkey,
                vdata->pubkeyid))==NULL){
            return PGP_RELEASE_MEMORY;
        }

        filter->seckey = NULL;
	    if (vdata->type == PGP_PTAG_CT_SECRET_KEY && filter->destsecring) {
            if((filter->seckey = pgp_ensure_seckey(
                            filter->destsecring,
                            &vdata->key.seckey,
                            vdata->pubkeyid))==NULL){
                return PGP_RELEASE_MEMORY;
            }
        }
        /* TODO get seckey by ID id even if given key is public
         *      in order to update uids an attributes from pubkey */
    }

    pubkey = filter->pubkey;
    if(pubkey == NULL)
        return PGP_RELEASE_MEMORY;

    if (vdata->type == PGP_PTAG_CT_SECRET_KEY) {
        seckey = filter->seckey;
    }

    switch(vdata->last_seen){
    case LS_PRIMARY:

        pgp_add_directsig(pubkey, sigpkt, &vdata->valid_sig_info);

	    if (seckey) {
            pgp_add_directsig(seckey, sigpkt, &vdata->valid_sig_info);
        }
        break;
    case LS_ID:

        pgp_update_userid(pubkey, vdata->userid, sigpkt, &vdata->valid_sig_info);
	    if (seckey) {
            pgp_update_userid(seckey, vdata->userid, sigpkt, &vdata->valid_sig_info);
        }

        break;
    case LS_ATTRIBUTE:
        /* TODO */
        break;
    case LS_SUBKEY:
        pgp_update_subkey(pubkey,
                vdata->type, &vdata->subkey,
                sigpkt, &vdata->valid_sig_info);
	    if (seckey) {
            pgp_update_subkey(seckey,
                    vdata->type, &vdata->subkey,
                    sigpkt, &vdata->valid_sig_info);
        }

        break;
    default:
        break;
    }
	return PGP_RELEASE_MEMORY;
}

#if 0 //////
unsigned
pgp_filter_keys_fileread(
            pgp_io_t *io,
            pgp_keyring_t *destpubring,
            pgp_keyring_t *destsecring,
            pgp_keyring_t *certring,
			const unsigned armour,
			const char *filename)
{
	pgp_stream_t	*stream;
	validate_key_cb_t vdata;
    key_filter_cb_t filter;
	unsigned	 res = 1;
	int		 fd;

	(void) memset(&vdata, 0x0, sizeof(vdata));
	vdata.result = NULL;
	vdata.getpassphrase = NULL;

	(void) memset(&filter, 0x0, sizeof(filter));
    filter.destpubring = destpubring;
    filter.destsecring = destsecring;

    fd = pgp_setup_file_read(io,
			&stream,filename,
			&vdata,
            pgp_validate_key_cb,
			1);

	if (fd < 0) {
		perror(filename);
		return 0;
	}

	pgp_parse_options(stream, PGP_PTAG_SS_ALL, PGP_PARSE_PARSED);

	if (armour) {
		pgp_reader_push_dearmour(stream);
	}

	vdata.keyring = certring;

	vdata.on_valid = &key_filter_cb;
	vdata.on_valid_args = &filter;

	res = pgp_parse(stream, 0);

    validate_key_cb_free(&vdata);

	if (armour) {
		pgp_reader_pop_dearmour(stream);
	}

	(void)close(fd);

	pgp_stream_delete(stream);

	return res;
}
#endif

unsigned
pgp_filter_keys_from_mem(
            pgp_io_t *io,
            pgp_keyring_t *destpubring,
            pgp_keyring_t *destsecring,
            pgp_keyring_t *certring,
            const unsigned armour,
            pgp_memory_t *mem)
{
	pgp_stream_t *stream;
	validate_key_cb_t vdata;
    key_filter_cb_t filter;
	unsigned res;

	(void) memset(&vdata, 0x0, sizeof(vdata));

	(void) memset(&filter, 0x0, sizeof(filter));
    filter.destpubring = destpubring;
    filter.destsecring = destsecring;

	//stream = pgp_new(sizeof(*stream)); -- Memory leak fixed by Delta Chat: not needed, stream is overwritten in pgp_setup_memory_read()
	pgp_setup_memory_read(io, &stream, mem, &vdata, pgp_validate_key_cb, 1);
	//pgp_parse_options(stream, PGP_PTAG_SS_ALL, PGP_PARSE_PARSED); // the original code does not set PGP_PARSE_PARSED, however this seems to be a bug as this function was called before pgp_setup_memory_read() - as pgp_filter_keys_fileread() uses the same callback, I assume, PGP_PARSE_PARSED is the expected behaviour.

	if (armour) {
		pgp_reader_push_dearmour(stream);
	}

	vdata.keyring = certring;

	vdata.on_valid = &key_filter_cb;
	vdata.on_valid_args = &filter;

	res = pgp_parse(stream, 0);

    validate_key_cb_free(&vdata);

	if (armour) {
		pgp_reader_pop_dearmour(stream);
	}

	/* don't call teardown_memory_read because memory was passed in */
	pgp_stream_delete(stream);
	return res;
}

/**
   \ingroup HighLevel_Verify
   \brief Frees validation result and associated memory
   \param result Struct to be freed
   \note Must be called after validation functions
*/
void
pgp_validate_result_free(pgp_validation_t *result)
{
	if (result != NULL) {
		if (result->valid_sigs) {
			free_sig_info(result->valid_sigs);
		}
		if (result->invalid_sigs) {
			free_sig_info(result->invalid_sigs);
		}
		if (result->unknown_sigs) {
			free_sig_info(result->unknown_sigs);
		}
		free(result);
		/* result = NULL; - XXX unnecessary */
	}
}

/**
   \ingroup HighLevel_Verify
   \brief Verifies the signatures in a signed file
   \param result Where to put the result
   \param filename Name of file to be validated
   \param armoured Treat file as armoured, if set
   \param keyring Keyring to use
   \return 1 if signatures validate successfully;
   	0 if signatures fail or there are no signatures
   \note After verification, result holds the details of all keys which
   have passed, failed and not been recognised.
   \note It is the caller's responsiblity to call
   	pgp_validate_result_free(result) after use.
*/
#if 0 ///////
unsigned
pgp_validate_file(pgp_io_t *io,
			pgp_validation_t *result,
			const char *infile,
			const char *outfile,
			const int user_says_armoured,
			const pgp_keyring_t *keyring)
{
	validate_data_cb_t	 validation;
	pgp_stream_t		*parse = NULL;
	struct stat		 st;
	const char		*signame;
	const int		 printerrors = 1;
	unsigned		 ret;
	char			 f[MAXPATHLEN];
	char			*dataname;
	int			 realarmour;
	int			 outfd = 0;
	int			 infd;
	int			 cc;

	if (stat(infile, &st) < 0) {
		(void) fprintf(io->errs,
			"pgp_validate_file: can't open '%s'\n", infile);
		return 0;
	}
	realarmour = user_says_armoured;
	dataname = NULL;
	signame = NULL;
	cc = snprintf(f, sizeof(f), "%s", infile);
	if (strcmp(&f[cc - 4], ".sig") == 0) {
		/* we've been given a sigfile as infile */
		f[cc - 4] = 0x0;
		/* set dataname to name of file which was signed */
		dataname = f;
		signame = infile;
	} else if (strcmp(&f[cc - 4], ".asc") == 0) {
		/* we've been given an armored sigfile as infile */
		f[cc - 4] = 0x0;
		/* set dataname to name of file which was signed */
		dataname = f;
		signame = infile;
		realarmour = 1;
	} else {
		signame = infile;
	}
	(void) memset(&validation, 0x0, sizeof(validation));
	infd = pgp_setup_file_read(io, &parse, signame, &validation,
				validate_data_cb, 1);
	if (infd < 0) {
		return 0;
	}

	if (dataname) {
		validation.detachname = netpgp_strdup(dataname);
	}

	/* Set verification reader and handling options */
	validation.result = result;
	validation.keyring = keyring;
	validation.mem = pgp_memory_new();
	pgp_memory_init(validation.mem, 128);

	if (realarmour) {
		pgp_reader_push_dearmour(parse);
	}

	/* Do the verification */
	pgp_parse(parse, !printerrors);

	/* Tidy up */
	if (realarmour) {
		pgp_reader_pop_dearmour(parse);
	}
	pgp_teardown_file_read(parse, infd);

	ret = validate_result_status(io->errs, infile, result);

	/* this is triggered only for --cat output */
	if (outfile) {
		/* need to send validated output somewhere */
		if (strcmp(outfile, "-") == 0) {
			outfd = STDOUT_FILENO;
		} else {
			outfd = open(outfile, O_WRONLY | O_CREAT, 0666);
		}
		if (outfd < 0) {
			/* even if the signature was good, we can't
			* write the file, so send back a bad return
			* code */
			ret = 0;
		} else if (validate_result_status(io->errs, infile, result)) {
			unsigned	 len;
			char		*cp;
			int		 i;

			len = (unsigned)pgp_mem_len(validation.mem);
			cp = pgp_mem_data(validation.mem);
			for (i = 0 ; i < (int)len ; i += cc) {
				cc = (int)write(outfd, &cp[i], (unsigned)(len - i));
				if (cc < 0) {
					(void) fprintf(io->errs,
						"netpgp: short write\n");
					ret = 0;
					break;
				}
			}
			if (strcmp(outfile, "-") != 0) {
				(void) close(outfd);
			}
		}
	}
	pgp_memory_free(validation.mem);
	return ret;
}
#endif //////

/**
   \ingroup HighLevel_Verify
   \brief Verifies the signatures in a pgp_memory_t struct
   \param result Where to put the result
   \param mem Memory to be validated
   \param user_says_armoured Treat data as armoured, if set
   \param keyring Keyring to use
   \param detachmem detached memory (free done in this call if provided)
   \return 1 if signature validates successfully; 0 if not
   \note After verification, result holds the details of all keys which
   have passed, failed and not been recognised.
   \note It is the caller's responsiblity to call
   	pgp_validate_result_free(result) after use.
*/
#if 0 //////
static inline unsigned
_pgp_validate_mem(pgp_io_t *io,
			pgp_validation_t *result,
			pgp_memory_t *mem,
			pgp_memory_t **cat,
			const int user_says_armoured,
			const pgp_keyring_t *keyring,
			pgp_memory_t *detachmem)
{
	validate_data_cb_t	 validation;
	pgp_stream_t		*stream = NULL;
	const int		 printerrors = 1;
	int			 realarmour;

	pgp_setup_memory_read(io, &stream, mem, &validation, validate_data_cb, 1);

	/* Set verification reader and handling options */
	(void) memset(&validation, 0x0, sizeof(validation));
	validation.result = result;
	validation.keyring = keyring;
	if (detachmem) {
        validation.mem = detachmem;
    }else{
        validation.mem = pgp_memory_new();
        pgp_memory_init(validation.mem, 128);
    }

	if ((realarmour = user_says_armoured) != 0 ||
	    strncmp(pgp_mem_data(mem),
	    		"-----BEGIN PGP MESSAGE-----", 27) == 0) {
		realarmour = 1;
	}
	if (realarmour) {
		pgp_reader_push_dearmour(stream);
	}

	/* Do the verification */
	pgp_parse(stream, !printerrors);

	/* Tidy up */
	if (realarmour) {
		pgp_reader_pop_dearmour(stream);
	}
	pgp_teardown_memory_read(stream, mem);

	/* this is triggered only for --cat output */
	if (cat) {
		/* need to send validated output somewhere */
		*cat = validation.mem;
	} else {
        pgp_memory_free(validation.mem);
	}

	return validate_result_status(io->errs, NULL, result);
}
#endif //////

#if 0 //////
unsigned
pgp_validate_mem(pgp_io_t *io,
			pgp_validation_t *result,
			pgp_memory_t *mem,
			pgp_memory_t **cat,
			const int user_says_armoured,
			const pgp_keyring_t *keyring)
{
    return _pgp_validate_mem(io,
			result,
			mem,
			cat,
			user_says_armoured,
			keyring,
	        NULL);
}
#endif //////

#if 0 //////
unsigned
pgp_validate_mem_detached(pgp_io_t *io,
			pgp_validation_t *result,
			pgp_memory_t *mem,
			pgp_memory_t **cat,
			const int user_says_armoured,
			const pgp_keyring_t *keyring,
			pgp_memory_t *detachmem)
{
    return _pgp_validate_mem(io,
			result,
			mem,
			cat,
			user_says_armoured,
			keyring,
	        detachmem);
}
#endif //////

