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

#ifndef KEYRING_H_
#define KEYRING_H_

#include "packet.h"
#include "packet-parse.h"
#include "memory.h"

enum {
	MAX_ID_LENGTH		= 128,
	MAX_PASSPHRASE_LENGTH	= 256
};

typedef struct pgp_key_t	pgp_key_t;

/** \struct pgp_keyring_t
 * A keyring
 */
typedef struct pgp_keyring_t {
	DYNARRAY(pgp_key_t,	key);
	pgp_hash_alg_t	hashtype;
} pgp_keyring_t;

pgp_key_t *pgp_getkeybyid(pgp_io_t *,
					const pgp_keyring_t *,
					const uint8_t *,
					unsigned *,
                    pgp_pubkey_t **,
					pgp_seckey_t **,
                    unsigned checkrevoke,
                    unsigned checkexpiry);
unsigned pgp_deletekeybyid(pgp_io_t *, 
                    pgp_keyring_t *,
			        const uint8_t *);
pgp_key_t *pgp_getkeybyfpr(pgp_io_t *,
					const pgp_keyring_t *,
			        const uint8_t *fpr,
                    size_t length,
                    unsigned *from,
                    pgp_pubkey_t **,
                    unsigned checkrevoke,
                    unsigned checkexpiry);
unsigned pgp_deletekeybyfpr(pgp_io_t *,
                    pgp_keyring_t *,
			        const uint8_t *fpr,
                    size_t length);
const pgp_key_t *pgp_getkeybyname(pgp_io_t *,
					const pgp_keyring_t *,
					const char *);
const pgp_key_t *pgp_getnextkeybyname(pgp_io_t *,
					const pgp_keyring_t *,
					const char *,
					unsigned *);
void pgp_key_free(pgp_key_t *);
void pgp_keydata_free(pgp_key_t *);
void pgp_keyring_free(pgp_keyring_t *);
void pgp_keyring_purge(pgp_keyring_t *);
void pgp_dump_keyring(const pgp_keyring_t *);
pgp_pubkey_t *pgp_key_get_pubkey(pgp_key_t *);
unsigned   pgp_is_key_secret(pgp_key_t *);
pgp_seckey_t *pgp_get_seckey(pgp_key_t *);
pgp_seckey_t *pgp_get_writable_seckey(pgp_key_t *);
// pgp_seckey_t *pgp_decrypt_seckey(const pgp_key_t *, void *);

unsigned 
pgp_keyring_fileread(pgp_io_t *io,
            pgp_keyring_t *pubring,
            pgp_keyring_t *secring,
			const unsigned armour,
			const char *filename);

#if 0 //////
unsigned
pgp_keyring_read_from_mem(pgp_io_t *io,
            pgp_keyring_t *pubring,
            pgp_keyring_t *secring,
            const unsigned armour,
            pgp_memory_t *mem);
#endif //////

int pgp_keyring_list(pgp_io_t *, const pgp_keyring_t *, const int);

void pgp_forget(void *, unsigned);

// uint8_t *pgp_add_userid(pgp_key_t *, const uint8_t *);
unsigned pgp_update_userid(
        pgp_key_t *key,
        const uint8_t *userid,
        const pgp_subpacket_t *sigpkt,
        pgp_sig_info_t *siginfo);

// pgp_subpacket_t *pgp_add_subpacket(pgp_key_t *,
// 						const pgp_subpacket_t *);
// pgp_subpacket_t *pgp_replace_subpacket(pgp_key_t *,
//                                        const pgp_subpacket_t *,
//                                        unsigned );

unsigned pgp_add_selfsigned_userid(pgp_key_t *skey, pgp_key_t *pkey, const uint8_t *userid, time_t duration);

pgp_key_t  *pgp_keydata_new(void);
void pgp_keydata_init(pgp_key_t *, const pgp_content_enum);

char *pgp_export_key(pgp_io_t *, const pgp_key_t *, uint8_t *);

int pgp_keyring_add(pgp_keyring_t *, const pgp_key_t *);
// int pgp_add_to_pubring(pgp_keyring_t *, const pgp_pubkey_t *, pgp_content_enum tag);
pgp_key_t *pgp_ensure_pubkey(
        pgp_keyring_t *,
        pgp_pubkey_t *,
        uint8_t *);
pgp_key_t *pgp_ensure_seckey(
        pgp_keyring_t *keyring,
        pgp_seckey_t *seckey,
        uint8_t *pubkeyid);
unsigned pgp_add_directsig(
        pgp_key_t *key,
        const pgp_subpacket_t *sigpkt,
        pgp_sig_info_t *siginfo);
unsigned pgp_update_subkey(
        pgp_key_t *key,
	    pgp_content_enum subkeytype,
        pgp_keydata_key_t *subkey,
        const pgp_subpacket_t *sigpkt,
        pgp_sig_info_t *siginfo);
// int pgp_add_to_secring(pgp_keyring_t *, const pgp_seckey_t *);

int pgp_append_keyring(pgp_keyring_t *, pgp_keyring_t *);

pgp_subpacket_t * pgp_copy_packet(pgp_subpacket_t *, const pgp_subpacket_t *);
uint8_t * pgp_copy_userid(uint8_t **dst, const uint8_t *src);

const int32_t pgp_key_get_uid0(pgp_key_t *keydata);
const uint8_t *pgp_key_get_primary_userid(pgp_key_t *key);


pgp_pubkey_t * pgp_key_get_sigkey(pgp_key_t *key);
pgp_seckey_t * pgp_key_get_certkey(pgp_key_t *key);
pgp_pubkey_t * pgp_key_get_enckey(pgp_key_t *key, const uint8_t **id);
pgp_seckey_t * pgp_key_get_deckey(pgp_key_t *key, const uint8_t **id);

const int32_t
pgp_key_find_uid_cond(
        const pgp_key_t *key,
        unsigned(*uidcond) ( uint8_t *, void *),
        void *uidcondarg,
        unsigned(*sigcond) ( const pgp_sig_info_t *, void *),
        void *sigcondarg,
        time_t *youngest,
        unsigned checkrevoke,
        unsigned checkexpiry);

const pgp_key_rating_t pgp_key_get_rating(pgp_key_t *key);

unsigned 
pgp_key_revoke(pgp_key_t *skey, pgp_key_t *pkey, uint8_t code, const char *reason);

#endif /* KEYRING_H_ */
