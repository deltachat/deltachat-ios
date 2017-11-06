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
 *
 * Creates printable text strings from packet contents
 *
 */
#include "netpgp/config-netpgp.h"

#ifdef HAVE_SYS_CDEFS_H
#include <sys/cdefs.h>
#endif

#if defined(__NetBSD__)
__COPYRIGHT("@(#) Copyright (c) 2009 The NetBSD Foundation, Inc. All rights reserved.");
__RCSID("$NetBSD$");
#endif

#include <stdlib.h>
#include <string.h>

#include "netpgp/packet-show.h"

#include "netpgp/netpgpsdk.h"
#include "netpgp/netpgpdefs.h"


/*
 * Arrays of value->text maps
 */

static pgp_map_t packet_tag_map[] =
{
	{PGP_PTAG_CT_RESERVED, "Reserved"},
	{PGP_PTAG_CT_PK_SESSION_KEY, "Public-Key Encrypted Session Key"},
	{PGP_PTAG_CT_SIGNATURE, "Signature"},
	{PGP_PTAG_CT_SK_SESSION_KEY, "Symmetric-Key Encrypted Session Key"},
	{PGP_PTAG_CT_1_PASS_SIG, "One-Pass Signature"},
	{PGP_PTAG_CT_SECRET_KEY, "Secret Key"},
	{PGP_PTAG_CT_PUBLIC_KEY, "Public Key"},
	{PGP_PTAG_CT_SECRET_SUBKEY, "Secret Subkey"},
	{PGP_PTAG_CT_COMPRESSED, "Compressed Data"},
	{PGP_PTAG_CT_SE_DATA, "Symmetrically Encrypted Data"},
	{PGP_PTAG_CT_MARKER, "Marker"},
	{PGP_PTAG_CT_LITDATA, "Literal Data"},
	{PGP_PTAG_CT_TRUST, "Trust"},
	{PGP_PTAG_CT_USER_ID, "User ID"},
	{PGP_PTAG_CT_PUBLIC_SUBKEY, "Public Subkey"},
	{PGP_PTAG_CT_RESERVED2, "reserved2"},
	{PGP_PTAG_CT_RESERVED3, "reserved3"},
	{PGP_PTAG_CT_USER_ATTR, "User Attribute"},
	{PGP_PTAG_CT_SE_IP_DATA,
		"Symmetric Encrypted and Integrity Protected Data"},
	{PGP_PTAG_CT_MDC, "Modification Detection Code"},
	{PGP_PARSER_PTAG, "PGP_PARSER_PTAG"},
	{PGP_PTAG_RAW_SS, "PGP_PTAG_RAW_SS"},
	{PGP_PTAG_SS_ALL, "PGP_PTAG_SS_ALL"},
	{PGP_PARSER_PACKET_END, "PGP_PARSER_PACKET_END"},
	{PGP_PTAG_SIG_SUBPKT_BASE, "PGP_PTAG_SIG_SUBPKT_BASE"},
	{PGP_PTAG_SS_CREATION_TIME, "SS: Signature Creation Time"},
	{PGP_PTAG_SS_EXPIRATION_TIME, "SS: Signature Expiration Time"},
	{PGP_PTAG_SS_EXPORT_CERT, "SS: Exportable Certification"},
	{PGP_PTAG_SS_TRUST, "SS: Trust Signature"},
	{PGP_PTAG_SS_REGEXP, "SS: Regular Expression"},
	{PGP_PTAG_SS_REVOCABLE, "SS: Revocable"},
	{PGP_PTAG_SS_KEY_EXPIRY, "SS: Key Expiration Time"},
	{PGP_PTAG_SS_RESERVED, "SS: Reserved"},
	{PGP_PTAG_SS_PREFERRED_SKA, "SS: Preferred Secret Key Algorithm"},
	{PGP_PTAG_SS_REVOCATION_KEY, "SS: Revocation Key"},
	{PGP_PTAG_SS_ISSUER_KEY_ID, "SS: Issuer Key Id"},
	{PGP_PTAG_SS_NOTATION_DATA, "SS: Notation Data"},
	{PGP_PTAG_SS_PREFERRED_HASH, "SS: Preferred Hash Algorithm"},
	{PGP_PTAG_SS_PREF_COMPRESS, "SS: Preferred Compression Algorithm"},
	{PGP_PTAG_SS_KEYSERV_PREFS, "SS: Key Server Preferences"},
	{PGP_PTAG_SS_PREF_KEYSERV, "SS: Preferred Key Server"},
	{PGP_PTAG_SS_PRIMARY_USER_ID, "SS: Primary User ID"},
	{PGP_PTAG_SS_POLICY_URI, "SS: Policy URI"},
	{PGP_PTAG_SS_KEY_FLAGS, "SS: Key Flags"},
	{PGP_PTAG_SS_SIGNERS_USER_ID, "SS: Signer's User ID"},
	{PGP_PTAG_SS_REVOCATION_REASON, "SS: Reason for Revocation"},
	{PGP_PTAG_SS_FEATURES, "SS: Features"},
	{PGP_PTAG_SS_SIGNATURE_TARGET, "SS: Signature Target"},
	{PGP_PTAG_SS_EMBEDDED_SIGNATURE, "SS: Embedded Signature"},

	{PGP_PTAG_CT_LITDATA_HEADER, "CT: Literal Data Header"},
	{PGP_PTAG_CT_LITDATA_BODY, "CT: Literal Data Body"},
	{PGP_PTAG_CT_SIGNATURE_HEADER, "CT: Signature Header"},
	{PGP_PTAG_CT_SIGNATURE_FOOTER, "CT: Signature Footer"},
	{PGP_PTAG_CT_ARMOUR_HEADER, "CT: Armour Header"},
	{PGP_PTAG_CT_ARMOUR_TRAILER, "CT: Armour Trailer"},
	{PGP_PTAG_CT_SIGNED_CLEARTEXT_HEADER, "CT: Signed Cleartext Header"},
	{PGP_PTAG_CT_SIGNED_CLEARTEXT_BODY, "CT: Signed Cleartext Body"},
	{PGP_PTAG_CT_SIGNED_CLEARTEXT_TRAILER, "CT: Signed Cleartext Trailer"},
	{PGP_PTAG_CT_UNARMOURED_TEXT, "CT: Unarmoured Text"},
	{PGP_PTAG_CT_ENCRYPTED_SECRET_KEY, "CT: Encrypted Secret Key"},
	{PGP_PTAG_CT_SE_DATA_HEADER, "CT: Sym Encrypted Data Header"},
	{PGP_PTAG_CT_SE_DATA_BODY, "CT: Sym Encrypted Data Body"},
	{PGP_PTAG_CT_SE_IP_DATA_HEADER, "CT: Sym Encrypted IP Data Header"},
	{PGP_PTAG_CT_SE_IP_DATA_BODY, "CT: Sym Encrypted IP Data Body"},
	{PGP_PTAG_CT_ENCRYPTED_PK_SESSION_KEY, "CT: Encrypted PK Session Key"},
	{PGP_GET_PASSPHRASE, "CMD: Get Secret Key Passphrase"},
	{PGP_GET_SECKEY, "CMD: Get Secret Key"},
	{PGP_PARSER_ERROR, "PGP_PARSER_ERROR"},
	{PGP_PARSER_ERRCODE, "PGP_PARSER_ERRCODE"},

	{0x00, NULL},		/* this is the end-of-array marker */
};

static pgp_map_t ss_type_map[] =
{
	{PGP_PTAG_SS_CREATION_TIME, "Signature Creation Time"},
	{PGP_PTAG_SS_EXPIRATION_TIME, "Signature Expiration Time"},
	{PGP_PTAG_SS_TRUST, "Trust Signature"},
	{PGP_PTAG_SS_REGEXP, "Regular Expression"},
	{PGP_PTAG_SS_REVOCABLE, "Revocable"},
	{PGP_PTAG_SS_KEY_EXPIRY, "Key Expiration Time"},
	{PGP_PTAG_SS_PREFERRED_SKA, "Preferred Symmetric Algorithms"},
	{PGP_PTAG_SS_REVOCATION_KEY, "Revocation Key"},
	{PGP_PTAG_SS_ISSUER_KEY_ID, "Issuer key ID"},
	{PGP_PTAG_SS_NOTATION_DATA, "Notation Data"},
	{PGP_PTAG_SS_PREFERRED_HASH, "Preferred Hash Algorithms"},
	{PGP_PTAG_SS_PREF_COMPRESS, "Preferred Compression Algorithms"},
	{PGP_PTAG_SS_KEYSERV_PREFS, "Key Server Preferences"},
	{PGP_PTAG_SS_PREF_KEYSERV, "Preferred Key Server"},
	{PGP_PTAG_SS_PRIMARY_USER_ID, "Primary User ID"},
	{PGP_PTAG_SS_POLICY_URI, "Policy URI"},
	{PGP_PTAG_SS_KEY_FLAGS, "Key Flags"},
	{PGP_PTAG_SS_REVOCATION_REASON, "Reason for Revocation"},
	{PGP_PTAG_SS_FEATURES, "Features"},
	{0x00, NULL},		/* this is the end-of-array marker */
};


static pgp_map_t ss_rr_code_map[] =
{
	{0x00, "No reason specified"},
	{0x01, "Key is superseded"},
	{0x02, "Key material has been compromised"},
	{0x03, "Key is retired and no longer used"},
	{0x20, "User ID information is no longer valid"},
	{0x00, NULL},		/* this is the end-of-array marker */
};

static pgp_map_t sig_type_map[] =
{
	{PGP_SIG_BINARY, "Signature of a binary document"},
	{PGP_SIG_TEXT, "Signature of a canonical text document"},
	{PGP_SIG_STANDALONE, "Standalone signature"},
	{PGP_CERT_GENERIC, "Generic certification of a User ID and Public Key packet"},
	{PGP_CERT_PERSONA, "Personal certification of a User ID and Public Key packet"},
	{PGP_CERT_CASUAL, "Casual certification of a User ID and Public Key packet"},
	{PGP_CERT_POSITIVE, "Positive certification of a User ID and Public Key packet"},
	{PGP_SIG_SUBKEY, "Subkey Binding Signature"},
	{PGP_SIG_PRIMARY, "Primary Key Binding Signature"},
	{PGP_SIG_DIRECT, "Signature directly on a key"},
	{PGP_SIG_REV_KEY, "Key revocation signature"},
	{PGP_SIG_REV_SUBKEY, "Subkey revocation signature"},
	{PGP_SIG_REV_CERT, "Certification revocation signature"},
	{PGP_SIG_TIMESTAMP, "Timestamp signature"},
	{PGP_SIG_3RD_PARTY, "Third-Party Confirmation signature"},
	{0x00, NULL},		/* this is the end-of-array marker */
};

static pgp_map_t pubkey_alg_map[] =
{
	{PGP_PKA_RSA, "RSA (Encrypt or Sign)"},
	{PGP_PKA_RSA_ENCRYPT_ONLY, "RSA Encrypt-Only"},
	{PGP_PKA_RSA_SIGN_ONLY, "RSA Sign-Only"},
	{PGP_PKA_ELGAMAL, "Elgamal (Encrypt-Only)"},
	{PGP_PKA_DSA, "DSA"},
	{PGP_PKA_RESERVED_ELLIPTIC_CURVE, "Reserved for Elliptic Curve"},
	{PGP_PKA_RESERVED_ECDSA, "Reserved for ECDSA"},
	{PGP_PKA_ELGAMAL_ENCRYPT_OR_SIGN, "Reserved (formerly Elgamal Encrypt or Sign"},
	{PGP_PKA_RESERVED_DH, "Reserved for Diffie-Hellman (X9.42)"},
	{PGP_PKA_PRIVATE00, "Private/Experimental"},
	{PGP_PKA_PRIVATE01, "Private/Experimental"},
	{PGP_PKA_PRIVATE02, "Private/Experimental"},
	{PGP_PKA_PRIVATE03, "Private/Experimental"},
	{PGP_PKA_PRIVATE04, "Private/Experimental"},
	{PGP_PKA_PRIVATE05, "Private/Experimental"},
	{PGP_PKA_PRIVATE06, "Private/Experimental"},
	{PGP_PKA_PRIVATE07, "Private/Experimental"},
	{PGP_PKA_PRIVATE08, "Private/Experimental"},
	{PGP_PKA_PRIVATE09, "Private/Experimental"},
	{PGP_PKA_PRIVATE10, "Private/Experimental"},
	{0x00, NULL},		/* this is the end-of-array marker */
};

static pgp_map_t symm_alg_map[] =
{
	{PGP_SA_PLAINTEXT, "Plaintext or unencrypted data"},
	{PGP_SA_IDEA, "IDEA"},
	{PGP_SA_TRIPLEDES, "TripleDES"},
	{PGP_SA_CAST5, "CAST5"},
	{PGP_SA_BLOWFISH, "Blowfish"},
	{PGP_SA_AES_128, "AES (128-bit key)"},
	{PGP_SA_AES_192, "AES (192-bit key)"},
	{PGP_SA_AES_256, "AES (256-bit key)"},
	{PGP_SA_TWOFISH, "Twofish(256-bit key)"},
	{PGP_SA_CAMELLIA_128, "Camellia (128-bit key)"},
	{PGP_SA_CAMELLIA_192, "Camellia (192-bit key)"},
	{PGP_SA_CAMELLIA_256, "Camellia (256-bit key)"},
	{0x00, NULL},		/* this is the end-of-array marker */
};

static pgp_map_t hash_alg_map[] =
{
	{PGP_HASH_MD5, "MD5"},
	{PGP_HASH_SHA1, "SHA1"},
	{PGP_HASH_RIPEMD, "RIPEMD160"},
	{PGP_HASH_SHA256, "SHA256"},
	{PGP_HASH_SHA384, "SHA384"},
	{PGP_HASH_SHA512, "SHA512"},
	{PGP_HASH_SHA224, "SHA224"},
	{0x00, NULL},		/* this is the end-of-array marker */
};

static pgp_map_t compression_alg_map[] =
{
	{PGP_C_NONE, "Uncompressed"},
	{PGP_C_ZIP, "ZIP(RFC1951)"},
	{PGP_C_ZLIB, "ZLIB(RFC1950)"},
	{PGP_C_BZIP2, "Bzip2(BZ2)"},
	{0x00, NULL},		/* this is the end-of-array marker */
};

/*
 * Private functions
 */

static void
list_init(pgp_list_t *list)
{
	list->size = 0;
	list->used = 0;
	list->strings = NULL;
}

static void
list_free_strings(pgp_list_t *list)
{
	unsigned        i;

	for (i = 0; i < list->used; i++) {
		free(list->strings[i]);
		list->strings[i] = NULL;
	}
}

static void
list_free(pgp_list_t *list)
{
	if (list->strings)
		free(list->strings);
	list_init(list);
}

/* find a bitfield in a map - serial search */
static const char *
find_bitfield(pgp_bit_map_t *map, uint8_t octet)
{
	pgp_bit_map_t  *row;

	for (row = map; row->string != NULL && row->mask != octet ; row++) {
	}
	return (row->string) ? row->string : "Unknown";
}

/* ! generic function to initialise pgp_text_t structure */
void
pgp_text_init(pgp_text_t *text)
{
	list_init(&text->known);
	list_init(&text->unknown);
}

/**
 * \ingroup Core_Print
 *
 * pgp_text_free() frees the memory used by an pgp_text_t structure
 *
 * \param text Pointer to a previously allocated structure. This structure and its contents will be freed.
 */
void
pgp_text_free(pgp_text_t *text)
{
	/* Strings in "known" array will be constants, so don't free them */
	list_free(&text->known);

	/*
	 * Strings in "unknown" array will be dynamically allocated, so do
	 * free them
	 */
	list_free_strings(&text->unknown);
	list_free(&text->unknown);

	free(text);
}

/*
 * Public Functions
 */

/**
 * \ingroup Core_Print
 * returns description of the Packet Tag
 * \param packet_tag
 * \return string or "Unknown"
*/
const char     *
pgp_show_packet_tag(pgp_content_enum packet_tag)
{
	const char     *ret;

	ret = pgp_str_from_map(packet_tag, packet_tag_map);
	if (!ret) {
		ret = "Unknown Tag";
	}
	return ret;
}

/**
 * \ingroup Core_Print
 *
 * returns description of the Signature Sub-Packet type
 * \param ss_type Signature Sub-Packet type
 * \return string or "Unknown"
 */
const char     *
pgp_show_ss_type(pgp_content_enum ss_type)
{
	return pgp_str_from_map(ss_type, ss_type_map);
}

/**
 * \ingroup Core_Print
 *
 * returns description of the Revocation Reason code
 * \param ss_rr_code Revocation Reason code
 * \return string or "Unknown"
 */
const char     *
pgp_show_ss_rr_code(pgp_ss_rr_code_t ss_rr_code)
{
	return pgp_str_from_map(ss_rr_code, ss_rr_code_map);
}

/**
 * \ingroup Core_Print
 *
 * returns description of the given Signature type
 * \param sig_type Signature type
 * \return string or "Unknown"
 */
const char     *
pgp_show_sig_type(pgp_sig_type_t sig_type)
{
	return pgp_str_from_map(sig_type, sig_type_map);
}

/**
 * \ingroup Core_Print
 *
 * returns description of the given Public Key Algorithm
 * \param pka Public Key Algorithm type
 * \return string or "Unknown"
 */
const char     *
pgp_show_pka(pgp_pubkey_alg_t pka)
{
	return pgp_str_from_map(pka, pubkey_alg_map);
}

/**
 * \ingroup Core_Print
 * returns description of the Preferred Compression
 * \param octet Preferred Compression
 * \return string or "Unknown"
*/
const char     *
pgp_show_ss_zpref(uint8_t octet)
{
	return pgp_str_from_map(octet, compression_alg_map);
}

/**
 * \ingroup Core_Print
 *
 * returns description of the Hash Algorithm type
 * \param hash Hash Algorithm type
 * \return string or "Unknown"
 */
const char     *
pgp_show_hash_alg(uint8_t hash)
{
	return pgp_str_from_map(hash, hash_alg_map);
}

const char     *
pgp_show_symm_alg(uint8_t hash)
{
	return pgp_str_from_map(hash, symm_alg_map);
}

/**
 * \ingroup Core_Print
 * returns description of the given Preferred Symmetric Key Algorithm
 * \param octet
 * \return string or "Unknown"
*/
const char     *
pgp_show_ss_skapref(uint8_t octet)
{
	return pgp_str_from_map(octet, symm_alg_map);
}

/**
 * \ingroup Core_Print
 * returns description of SS Key Flag
 * \param octet
 * \param map
 * \return
*/
const char     *
pgp_show_ss_key_flag(uint8_t octet, pgp_bit_map_t *map)
{
	return find_bitfield(map, octet);
}

/**
 * \ingroup Core_Print
 *
 * returns description of one given Key Server Preference
 *
 * \param prefs Byte containing bitfield of preferences
 * \param map
 * \return string or "Unknown"
 */
const char     *
pgp_show_keyserv_pref(uint8_t prefs, pgp_bit_map_t *map)
{
	return find_bitfield(map, prefs);
}

