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
 * File:    mrmailbox_imex.c - Import and Export things
 *
 ******************************************************************************/


#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <openssl/rand.h>
#include <libetpan/mmapstring.h>
#include <netpgp-extra.h>
#include "mrmailbox.h"
#include "mrmimeparser.h"
#include "mrosnative.h"
#include "mrloginparam.h"
#include "mraheader.h"
#include "mrapeerstate.h"
#include "mrtools.h"
#include "mrpgp.h"

static int s_imex_do_exit = 1; /* the value 1 avoids MR_IMEX_CANCEL from stopping already stopped threads */


/*******************************************************************************
 * Import
 ******************************************************************************/


static int poke_public_key(mrmailbox_t* mailbox, const char* addr, const char* public_key_file)
{
	/* mainly for testing: if the partner does not support Autocrypt,
	encryption is disabled as soon as the first messages comes from the partner */
	mraheader_t*    header = mraheader_new();
	mrapeerstate_t* peerstate = mrapeerstate_new();
	int             locked = 0, success = 0;

	if( addr==NULL || public_key_file==NULL || peerstate==NULL || header==NULL ) {
		goto cleanup;
	}

	/* create a fake autocrypt header */
	header->m_addr             = safe_strdup(addr);
	header->m_prefer_encrypt   = MRA_PE_MUTUAL;
	if( !mrkey_set_from_file(header->m_public_key, public_key_file, mailbox)
	 || !mrpgp_is_valid_key(mailbox, header->m_public_key) ) {
		mrmailbox_log_warning(mailbox, 0, "No valid key found in \"%s\".", public_key_file);
		goto cleanup;
	}

	/* update/create peerstate */
	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( mrapeerstate_load_from_db__(peerstate, mailbox->m_sql, addr) ) {
			mrapeerstate_apply_header(peerstate, header, time(NULL));
			mrapeerstate_save_to_db__(peerstate, mailbox->m_sql, 0);
		}
		else {
			mrapeerstate_init_from_header(peerstate, header, time(NULL));
			mrapeerstate_save_to_db__(peerstate, mailbox->m_sql, 1);
		}

		success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrapeerstate_unref(peerstate);
	mraheader_unref(header);
	return success;
}


int mrmailbox_poke_spec(mrmailbox_t* mailbox, const char* spec__) /* spec is a file, a directory or NULL for the last import */
{
	int            success = 0;
	char*          spec = NULL;
	char*          suffix = NULL;
	DIR*           dir = NULL;
	struct dirent* dir_entry;
	int            read_cnt = 0;
	char*          name;

	if( mailbox == NULL ) {
		return 0;
	}

	if( !mrsqlite3_is_open(mailbox->m_sql) ) {
        mrmailbox_log_error(mailbox, 0, "Import: Database not opened.");
		goto cleanup;
	}

	/* if `spec` is given, remember it for later usage; if it is not given, try to use the last one */
	if( spec__ )
	{
		spec = safe_strdup(spec__);
		mrsqlite3_lock(mailbox->m_sql);
			mrsqlite3_set_config__(mailbox->m_sql, "import_spec", spec);
		mrsqlite3_unlock(mailbox->m_sql);
	}
	else {
		mrsqlite3_lock(mailbox->m_sql);
			spec = mrsqlite3_get_config__(mailbox->m_sql, "import_spec", NULL); /* may still NULL */
		mrsqlite3_unlock(mailbox->m_sql);
		if( spec == NULL ) {
			mrmailbox_log_error(mailbox, 0, "Import: No file or folder given.");
			goto cleanup;
		}
	}

	suffix = mr_get_filesuffix_lc(spec);
	if( suffix && strcmp(suffix, "eml")==0 ) {
		/* import a single file */
		if( mrmailbox_poke_eml_file(mailbox, spec) ) { /* errors are logged in any case */
			read_cnt++;
		}
	}
	else if( suffix && (strcmp(suffix, "pem")==0||strcmp(suffix, "asc")==0) ) {
		/* import a publix key */
		char* separator = strchr(spec, ' ');
		if( separator==NULL ) {
			mrmailbox_log_error(mailbox, 0, "Import: Key files must be specified as \"<addr> <key-file>\".");
			goto cleanup;
		}
		*separator = 0;
		if( poke_public_key(mailbox, spec, separator+1) ) {
			read_cnt++;
		}
		*separator = ' ';
	}
	else {
		/* import a directory */
		if( (dir=opendir(spec))==NULL ) {
			mrmailbox_log_error(mailbox, 0, "Import: Cannot open directory \"%s\".", spec);
			goto cleanup;
		}

		while( (dir_entry=readdir(dir))!=NULL ) {
			name = dir_entry->d_name; /* name without path; may also be `.` or `..` */
			if( strlen(name)>=4 && strcmp(&name[strlen(name)-4], ".eml")==0 ) {
				char* path_plus_name = mr_mprintf("%s/%s", spec, name);
				mrmailbox_log_info(mailbox, 0, "Import: %s", path_plus_name);
				if( mrmailbox_poke_eml_file(mailbox, path_plus_name) ) { /* no abort on single errors errors are logged in any case */
					read_cnt++;
				}
				free(path_plus_name);
            }
		}
	}

	mrmailbox_log_info(mailbox, 0, "Import: %i items read from \"%s\".", read_cnt, spec);
	if( read_cnt > 0 ) {
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0); /* even if read_cnt>0, the number of messages added to the database may be 0. While we regard this issue using IMAP, we ignore it here. */
	}

	/* success */
	success = 1;

	/* cleanup */
cleanup:
	if( dir ) {
		closedir(dir);
	}
	free(spec);
	free(suffix);
	return success;
}


static int import_self_keys(mrmailbox_t* mailbox, const char* dir_name)
{
	/* hint: even if we switch to import Autocrypt Setup files, we should leave the possibility to import
	plain ASC keys, at least keys without a password, if we do not want to implement a password entry function.
	Importing ASC keys is useful to use keys in Delta Chat used by any other non-Autocrypt-PGP implementation.

	Maybe we should make the "default" key handlong also a little bit smarter
	(currently, the last imported key is the standard key unless it contains the string "legacy" in its name) */

	int            imported_count = 0, locked = 0;
	DIR*           dir_handle = NULL;
	struct dirent* dir_entry = NULL;
	char*          suffix = NULL;
	char*          path_plus_name = NULL;
	mrkey_t*       private_key = mrkey_new();
	mrkey_t*       public_key = mrkey_new();
	sqlite3_stmt*  stmt = NULL;
	char*          self_addr = NULL;
	int            set_default = 0;

	if( mailbox==NULL || dir_name==NULL ) {
		goto cleanup;
	}

	if( (dir_handle=opendir(dir_name))==NULL ) {
		mrmailbox_log_error(mailbox, 0, "Import: Cannot open directory \"%s\".", dir_name);
		goto cleanup;
	}

	while( (dir_entry=readdir(dir_handle))!=NULL )
	{
		free(suffix);
		suffix = mr_get_filesuffix_lc(dir_entry->d_name);
		if( suffix==NULL || strcmp(suffix, "asc")!=0 ) {
			continue;
		}

		free(path_plus_name);
		path_plus_name = mr_mprintf("%s/%s", dir_name, dir_entry->d_name/* name without path; may also be `.` or `..` */);
		mrmailbox_log_info(mailbox, 0, "Checking: %s", path_plus_name);
		if( !mrkey_set_from_file(private_key, path_plus_name, mailbox) ) {
			mrmailbox_log_error(mailbox, 0, "Cannot read key from \"%s\".", path_plus_name);
			continue;
		}

		if( private_key->m_type!=MR_PRIVATE ) {
			continue; /* this is no error but quite normal as we always export the public keys together with the private ones */
		}

		if( !mrpgp_is_valid_key(mailbox, private_key) ) {
			mrmailbox_log_error(mailbox, 0, "\"%s\" is no valid key.", path_plus_name);
			continue;
		}

		if( !mrpgp_split_key(mailbox, private_key, public_key) ) {
			mrmailbox_log_error(mailbox, 0, "\"%s\" seems not to contain a private key.", path_plus_name);
			continue;
		}

		set_default = 1;
		if( strstr(dir_entry->d_name, "legacy")!=NULL ) {
			set_default = 0; /* a key with "legacy" in its name is not made default; this may result in a keychain with _no_ default, however, this is no problem, as this will create a default key later */
		}

		/* add keypair as default; before this, delete other keypairs with the same binary key and reset defaults */
		mrsqlite3_lock(mailbox->m_sql);
		locked = 1;

			stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "DELETE FROM keypairs WHERE public_key=? OR private_key=?;");
			sqlite3_bind_blob (stmt, 1, public_key->m_binary, public_key->m_bytes, SQLITE_STATIC);
			sqlite3_bind_blob (stmt, 2, private_key->m_binary, private_key->m_bytes, SQLITE_STATIC);
			sqlite3_step(stmt);
			sqlite3_finalize(stmt);
			stmt = NULL;

			if( set_default ) {
				mrsqlite3_execute__(mailbox->m_sql, "UPDATE keypairs SET is_default=0;"); /* if the new key should be the default key, all other should not */
			}

			free(self_addr);
			self_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", NULL);
			if( !mrkey_save_self_keypair__(public_key, private_key, self_addr, set_default, mailbox->m_sql) ) {
				mrmailbox_log_error(mailbox, 0, "Cannot save keypair.");
				goto cleanup;
			}

			imported_count++;

		mrsqlite3_unlock(mailbox->m_sql);
		locked = 0;
	}

	if( imported_count == 0 ) {
		mrmailbox_log_error(mailbox, 0, "No private keys found in \"%s\".", dir_name);
		goto cleanup;
	}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( dir_handle ) { closedir(dir_handle); }
	free(suffix);
	free(path_plus_name);
	mrkey_unref(private_key);
	mrkey_unref(public_key);
	if( stmt ) { sqlite3_finalize(stmt); }
	free(self_addr);
	return imported_count;
}


/*******************************************************************************
 * Export keys
 ******************************************************************************/


static void export_key_to_asc_file(mrmailbox_t* mailbox, const char* dir, int id, const mrkey_t* key, int is_default)
{
	char* file_content = mrkey_render_asc(key, NULL);
	char* file_name;
	if( is_default ) {
		file_name = mr_mprintf("%s/%s-key-default.asc", dir, key->m_type==MR_PUBLIC? "public" : "private");
	}
	else {
		file_name = mr_mprintf("%s/%s-key-%i.asc", dir, key->m_type==MR_PUBLIC? "public" : "private", id);
	}
	mrmailbox_log_info(mailbox, 0, "Exporting key %s", file_name);
	mr_delete_file(file_name, mailbox);
	if( !mr_write_file(file_name, file_content, strlen(file_content), mailbox) ) {
		mrmailbox_log_error(mailbox, 0, "Cannot write key to %s", file_name);
	}
	else {
		mailbox->m_cb(mailbox, MR_EVENT_IMEX_FILE_WRITTEN, (uintptr_t)file_name, (uintptr_t)"application/pgp-keys");
	}
	free(file_content);
	free(file_name);
}


static int export_self_keys(mrmailbox_t* mailbox, const char* dir)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;
	int           id = 0, is_default = 0;
	mrkey_t*      public_key = mrkey_new();
	mrkey_t*      private_key = mrkey_new();
	int           locked = 0;

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( (stmt=mrsqlite3_prepare_v2_(mailbox->m_sql, "SELECT id, public_key, private_key, is_default FROM keypairs;"))==NULL ) {
			goto cleanup;
		}

		while( sqlite3_step(stmt)==SQLITE_ROW ) {
			id = sqlite3_column_int(         stmt, 0  );
			mrkey_set_from_stmt(public_key,  stmt, 1, MR_PUBLIC);
			mrkey_set_from_stmt(private_key, stmt, 2, MR_PRIVATE);
			is_default = sqlite3_column_int( stmt, 3  );
			export_key_to_asc_file(mailbox, dir, id, public_key,  is_default);
			export_key_to_asc_file(mailbox, dir, id, private_key, is_default);
		}

		success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( stmt ) { sqlite3_finalize(stmt); }
	mrkey_unref(public_key);
	mrkey_unref(private_key);
	return success;
}



/*******************************************************************************
 * Export setup file
 ******************************************************************************/


/* a complete Autocrypt Setup Message looks like the following

To: me@mydomain.com
From: me@mydomain.com
Autocrypt-Setup-Message: v1
Content-type: multipart/mixed; boundary="==break1=="

	--==break1==
	Content-Type: text/plain

	This is the Autocrypt setup message.

	--==break1==
	Content-Type: application/autocrypt-key-backup
	Content-Disposition: attachment; filename="autocrypt-key-backup.html"

	<html>
	<body>
	<p>
		This is the Autocrypt setup file used to transfer keys between clients.
	</p>
	<pre>
	-----BEGIN PGP MESSAGE-----
	Version: BCPG v1.53
	Passphrase-Format: numeric9x4
	Passphrase-Begin: 12

	hQIMAxC7JraDy7DVAQ//SK1NltM+r6uRf2BJEg+rnpmiwfAEIiopU0LeOQ6ysmZ0
	CLlfUKAcryaxndj4sBsxLllXWzlNiFDHWw4OOUEZAZd8YRbOPfVq2I8+W4jO3Moe
	-----END PGP MESSAGE-----
	</pre>
	</body>
	</html>
	--==break1==--

The encrypted message part contains:

	-----BEGIN PGP PRIVATE KEY BLOCK-----
	Autocrypt-Prefer-Encrypt: mutual

	xcLYBFke7/8BCAD0TTmX9WJm9elc7/xrT4/lyzUDMLbuAuUqRINtCoUQPT2P3Snfx/jou1YcmjDgwT
	Ny9ddjyLcdSKL/aR6qQ1UBvlC5xtriU/7hZV6OZEmW2ckF7UgGd6ajE+UEjUwJg2+eKxGWFGuZ1P7a
	4Av1NXLayZDsYa91RC5hCsj+umLN2s+68ps5pzLP3NoK2zIFGoCRncgGI/pTAVmYDirhVoKh14hCh5
	.....
	-----END PGP PRIVATE KEY BLOCK-----

mrmailbox_render_keys_to_html() renders the part after the second `-==break1==` part in this example. */
int mrmailbox_render_keys_to_html(mrmailbox_t* mailbox, const char* passphrase, char** ret_msg)
{
	int                    success = 0, locked = 0;
	sqlite3_stmt*          stmt = NULL;
	char*                  self_addr = NULL;
	mrkey_t*               curr_private_key = mrkey_new();

	char                   passphrase_begin[8];
	uint8_t                salt[PGP_SALT_SIZE];
	#define                AES_KEY_LENGTH 16
	uint8_t                key[AES_KEY_LENGTH];

	pgp_output_t*          payload_output = NULL;
	pgp_memory_t*          payload_mem = NULL;

	pgp_output_t*          encr_output = NULL;
	pgp_memory_t*          encr_mem = NULL;
	char*                  encr_string = NULL;


	if( mailbox==NULL || passphrase==NULL || ret_msg==NULL
	 || strlen(passphrase)<2 || *ret_msg!=NULL || curr_private_key==NULL ) {
		goto cleanup;
	}

	strncpy(passphrase_begin, passphrase, 2);
	passphrase_begin[2] = 0;

	/* create the payload */

	{
		mrsqlite3_lock(mailbox->m_sql);
		locked = 1;

			self_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", NULL);
			mrkey_load_self_private__(curr_private_key, self_addr, mailbox->m_sql);

			char* payload_key_asc = mrkey_render_asc(curr_private_key, mailbox->m_e2ee_enabled? "Autocrypt-Prefer-Encrypt: mutual\r\n" : NULL);
			if( payload_key_asc == NULL ) {
				goto cleanup;
			}

		mrsqlite3_unlock(mailbox->m_sql);
		locked = 0;

		//printf("\n~~~~~~~~~~~~~~~~~~~~SETUP-PAYLOAD~~~~~~~~~~~~~~~~~~~~\n%s~~~~~~~~~~~~~~~~~~~~/SETUP-PAYLOAD~~~~~~~~~~~~~~~~~~~~\n",key_asc); // DEBUG OUTPUT


		/* put the payload into a literal data packet which will be encrypted then, see RFC 4880, 5.7 :
		"When it has been decrypted, it contains other packets (usually a literal data packet or compressed data
		packet, but in theory other Symmetrically Encrypted Data packets or sequences of packets that form whole OpenPGP messages)" */

		pgp_setup_memory_write(&payload_output, &payload_mem, 128);
		pgp_write_litdata(payload_output, (const uint8_t*)payload_key_asc, strlen(payload_key_asc), PGP_LDT_BINARY);

		free(payload_key_asc);
	}


	/* create salt for the key */
	pgp_random(salt, PGP_SALT_SIZE);

	/* S2K */

	int s2k_spec = PGP_S2KS_SIMPLE; // 0=simple, 1=salted, 3=salted+iterated
	int s2k_iter_id = 0; // ~1000 iterations

	/* create key from setup-code using OpenPGP's salted+iterated S2K (String-to-key)
	(from netpgp/create.c) */

	{
		unsigned	done = 0;
		unsigned	i = 0;
		int         passphrase_len = strlen(passphrase);
		pgp_hash_t    hash;
		for (done = 0, i = 0; done < AES_KEY_LENGTH; i++) {
			unsigned 	hashsize;
			unsigned 	j;
			unsigned	needed;
			unsigned	size;
			uint8_t		zero = 0;
			uint8_t		*hashed;

			/* Hard-coded SHA1 for session key */
			pgp_hash_any(&hash, PGP_HASH_SHA1);
			hashsize = pgp_hash_size(PGP_HASH_SHA1);
			needed = AES_KEY_LENGTH - done;
			size = MR_MIN(needed, hashsize);
			if ((hashed = calloc(1, hashsize)) == NULL) {
				(void) fprintf(stderr, "write_seckey_body: bad alloc\n");
				return 0;
			}
			if (!hash.init(&hash)) {
				(void) fprintf(stderr, "write_seckey_body: bad alloc\n");
				free(hashed);
				return 0;
			}

			/* preload if iterating  */
			for (j = 0; j < i; j++) {
				/*
				 * Coverity shows a DEADCODE error on this
				 * line. This is expected since the hardcoded
				 * use of SHA1 and CAST5 means that it will
				 * not used. This will change however when
				 * other algorithms are supported.
				 */
				hash.add(&hash, &zero, 1);
			}

			if (s2k_spec & PGP_S2KS_SALTED) {
				hash.add(&hash, salt, PGP_SALT_SIZE);
			}

			hash.add(&hash, (uint8_t*)passphrase, (unsigned)passphrase_len);
			hash.finish(&hash, hashed);

			/*
			 * if more in hash than is needed by session key, use
			 * the leftmost octets
			 */
			(void) memcpy(&key[i * hashsize], hashed, (unsigned)size);
			done += (unsigned)size;
			free(hashed);
			if (done > AES_KEY_LENGTH) {
				(void) fprintf(stderr,
					"write_seckey_body: short add\n");
				return 0;
			}
		}
	}

	/* encrypt the payload using the key using AES-128 and put it into
	OpenPGP's "Symmetric-Key Encrypted Session Key" (Tag 3, https://tools.ietf.org/html/rfc4880#section-5.3 ) followed by
	OpenPGP's "Symmetrically Encrypted Data Packet" (Tag 9, https://tools.ietf.org/html/rfc4880#section-5.7 ) */

	pgp_setup_memory_write(&encr_output, &encr_mem, 128);
	pgp_writer_push_armor_msg(encr_output);

	/* Tag 3 */
	pgp_write_ptag     (encr_output, PGP_PTAG_CT_SK_SESSION_KEY);
	pgp_write_length   (encr_output, 1/*version*/ + 1/*algo*/ + /*S2K*/1+1+((s2k_spec&PGP_S2KS_SALTED)?PGP_SALT_SIZE:0)+((s2k_spec==PGP_S2KS_ITERATED_AND_SALTED)?1:0) );

	pgp_write_scalar   (encr_output, 4, 1);                  // 1 octet: version
	pgp_write_scalar   (encr_output, PGP_SA_AES_128, 1);     // 1 octet: symm. algo

	pgp_write_scalar   (encr_output, s2k_spec, 1);           // 1 octet
	pgp_write_scalar   (encr_output, PGP_HASH_SHA1, 1);      // 1 octet: S2 hash algo
	if( s2k_spec&PGP_S2KS_SALTED ) {
	  pgp_write        (encr_output, salt, PGP_SALT_SIZE);   // 8 octets: salt
	}
	if( s2k_spec==PGP_S2KS_ITERATED_AND_SALTED ) {
	  pgp_write_scalar (encr_output, s2k_iter_id, 1);  // 1 octets
	}

	for(int j=0; j<AES_KEY_LENGTH; j++) {
		printf("%02x", key[j]);
	}
		printf("\n----------------\n");

	/* Tag 18 */
	pgp_write_symm_enc_data((const uint8_t*)payload_mem->buf, payload_mem->length, PGP_SA_AES_128, key, encr_output);

	/* done with symmetric key block */
	pgp_writer_close(encr_output);
	encr_string = mr_null_terminate((const char*)encr_mem->buf, encr_mem->length);

	//printf("\n~~~~~~~~~~~~~~~~~~~~SYMMETRICALLY ENCRYPTED~~~~~~~~~~~~~~~~~~~~\n%s~~~~~~~~~~~~~~~~~~~~/SYMMETRICALLY ENCRYPTED~~~~~~~~~~~~~~~~~~~~\n",encr_string); // DEBUG OUTPUT


	/* add additional header to armored block */

	#define LINEEND "\r\n" /* use the same lineends as the PGP armored data */
	{
		char* replacement = mr_mprintf("-----BEGIN PGP MESSAGE-----" LINEEND
		                               "Passphrase-Format: numeric9x4" LINEEND
		                               "Passphrase-Begin: %s", passphrase_begin);
		mr_str_replace(&encr_string, "-----BEGIN PGP MESSAGE-----", replacement);
		free(replacement);
	}

	/* wrap HTML-commands with instructions around the encrypted payload */

	*ret_msg = mr_mprintf(
		"<!DOCTYPE html>" LINEEND
		"<html>" LINEEND
			"<head>" LINEEND
				"<title>Autocrypt setup file</title>" LINEEND
			"</head>" LINEEND
			"<body>" LINEEND
				"<h1>Autocrypt setup file</h1>" LINEEND
				"<p>This is the <a href=\"https://autocrypt.org\">Autocrypt</a> setup file used to transfer your secret key between clients.</p>" LINEEND
                "<p>To decrypt the key, you need the setup code that was shown to you when this file was created. Hint: The setup code starts with: <em>%s</em></p>" LINEEND
				"<h2>Encrypted key</h2>" LINEEND
				"<pre>" LINEEND
				"%s" LINEEND
				"</pre>" LINEEND
			"</body>" LINEEND
		"</html>" LINEEND,
		passphrase_begin,
		encr_string);

	success = 1;

cleanup:
	if( stmt ) { sqlite3_finalize(stmt); }
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }

	if( payload_output ) { pgp_output_delete(payload_output); }
	if( payload_mem ) { pgp_memory_free(payload_mem); }

	if( encr_output ) { pgp_output_delete(encr_output); }
	if( encr_mem ) { pgp_memory_free(encr_mem); }
	free(encr_string);
	free(self_addr);
	return success;
}


static int export_setup_file(mrmailbox_t* mailbox, const char* dir, const char* setup_code)
{
	int           success = 0;
	char*         file_content = NULL;
	char*         file_name = mr_mprintf("%s/autocrypt-key-backup.html", dir);

	if( !mrmailbox_render_keys_to_html(mailbox, setup_code, &file_content) || file_content==NULL ) {
		mrmailbox_log_error(mailbox, 0, "Cannot generate Autocrypt setup file in %s", file_name);
		goto cleanup;
	}

	if( !mr_write_file(file_name, file_content, strlen(file_content), mailbox) ) {
		mrmailbox_log_error(mailbox, 0, "Cannot write keys to %s", file_name);
	}
	else {
		mailbox->m_cb(mailbox, MR_EVENT_IMEX_FILE_WRITTEN, (uintptr_t)file_name, (uintptr_t)"application/autocrypt-key-backup");
	}

	success = 1;

cleanup:
	free(file_content);
	free(file_name);
	return success;
}



/*******************************************************************************
 * Export backup
 ******************************************************************************/


/* the FILE_PROGRESS macro calls the callback with the permille of files processed.
The macro avoids weird values of 0% or 100% while still working. */
#define FILE_PROGRESS \
	processed_files_count++; \
	int permille = (processed_files_count*1000)/total_files_count; \
	if( permille <  10 ) { permille =  10; } \
	if( permille > 990 ) { permille = 990; } \
	mailbox->m_cb(mailbox, MR_EVENT_IMEX_PROGRESS, permille, 0);


static int export_backup(mrmailbox_t* mailbox, const char* dir)
{
	int            success = 0, locked = 0, closed = 0;
	char*          dest_pathNfilename = NULL;
	mrsqlite3_t*   dest_sql = NULL;
	time_t         now = time(NULL);
	DIR*           dir_handle = NULL;
	struct dirent* dir_entry;
	int            prefix_len = strlen(MR_BAK_PREFIX);
	int            suffix_len = strlen(MR_BAK_SUFFIX);
	char*          curr_pathNfilename = NULL;
	void*          buf = NULL;
	size_t         buf_bytes = 0;
	sqlite3_stmt*  stmt = NULL;
	int            total_files_count = 0, processed_files_count = 0;
	int            delete_dest_file = 0;

	/* get a fine backup file name (the name includes the date so that multiple backup instances are possible) */
	{
		struct tm* timeinfo;
		char buffer[256];
		timeinfo = localtime(&now);
		strftime(buffer, 256, MR_BAK_PREFIX "-%Y-%m-%d." MR_BAK_SUFFIX, timeinfo);
		if( (dest_pathNfilename=mr_get_fine_pathNfilename(dir, buffer))==NULL ) {
			mrmailbox_log_error(mailbox, 0, "Cannot get backup file name.");
			goto cleanup;
		}
	}

	/* temporary lock and close the source (we just make a copy of the whole file, this is the fastest and easiest approach) */
	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;
	mrsqlite3_close__(mailbox->m_sql);
	closed = 1;

	/* copy file to backup directory */
	mrmailbox_log_info(mailbox, 0, "Backup \"%s\" to \"%s\".", mailbox->m_dbfile, dest_pathNfilename);
	if( !mr_copy_file(mailbox->m_dbfile, dest_pathNfilename, mailbox) ) {
		goto cleanup; /* error already logged */
	}

	/* unlock and re-open the source and make it availabe again for the normal use */
	mrsqlite3_open__(mailbox->m_sql, mailbox->m_dbfile, 0);
	closed = 0;
	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* add all files as blobs to the database copy (this does not require the source to be locked, neigher the destination as it is used only here) */
	if( (dest_sql=mrsqlite3_new(mailbox/*for logging only*/))==NULL
	 || !mrsqlite3_open__(dest_sql, dest_pathNfilename, 0) ) {
		goto cleanup; /* error already logged */
	}

	if( !mrsqlite3_table_exists__(dest_sql, "backup_blobs") ) {
		if( !mrsqlite3_execute__(dest_sql, "CREATE TABLE backup_blobs (id INTEGER PRIMARY KEY, file_name, file_content);") ) {
			goto cleanup; /* error already logged */
		}
	}

	/* scan directory, pass 1: collect file info */
	total_files_count = 0;
	if( (dir_handle=opendir(mailbox->m_blobdir))==NULL ) {
		mrmailbox_log_error(mailbox, 0, "Backup: Cannot get info for blob-directory \"%s\".", mailbox->m_blobdir);
		goto cleanup;
	}

	while( (dir_entry=readdir(dir_handle))!=NULL ) {
		total_files_count++;
	}

	closedir(dir_handle);
	dir_handle = NULL;

	if( total_files_count>0 )
	{
		/* scan directory, pass 2: copy files */
		if( (dir_handle=opendir(mailbox->m_blobdir))==NULL ) {
			mrmailbox_log_error(mailbox, 0, "Backup: Cannot copy from blob-directory \"%s\".", mailbox->m_blobdir);
			goto cleanup;
		}

		stmt = mrsqlite3_prepare_v2_(dest_sql, "INSERT INTO backup_blobs (file_name, file_content) VALUES (?, ?);");
		while( (dir_entry=readdir(dir_handle))!=NULL )
		{
			if( s_imex_do_exit ) {
				delete_dest_file = 1;
				goto cleanup;
			}

			FILE_PROGRESS

			char* name = dir_entry->d_name; /* name without path; may also be `.` or `..` */
			int name_len = strlen(name);
			if( (name_len==1 && name[0]=='.')
			 || (name_len==2 && name[0]=='.' && name[1]=='.')
			 || (name_len > prefix_len && strncmp(name, MR_BAK_PREFIX, prefix_len)==0 && name_len > suffix_len && strncmp(&name[name_len-suffix_len-1], "." MR_BAK_SUFFIX, suffix_len)==0) ) {
				//mrmailbox_log_info(mailbox, 0, "Backup: Skipping \"%s\".", name);
				continue;
			}

			//mrmailbox_log_info(mailbox, 0, "Backup \"%s\".", name);
			free(curr_pathNfilename);
			curr_pathNfilename = mr_mprintf("%s/%s", mailbox->m_blobdir, name);
			free(buf);
			if( !mr_read_file(curr_pathNfilename, &buf, &buf_bytes, mailbox) || buf==NULL || buf_bytes<=0 ) {
				continue;
			}

			sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
			sqlite3_bind_blob(stmt, 2, buf, buf_bytes, SQLITE_STATIC);
			if( sqlite3_step(stmt)!=SQLITE_DONE ) {
				mrmailbox_log_error(mailbox, 0, "Disk full? Cannot add file \"%s\" to backup.", curr_pathNfilename);
				goto cleanup; /* this is not recoverable! writing to the sqlite database should work! */
			}
			sqlite3_reset(stmt);
		}
	}
	else
	{
		mrmailbox_log_info(mailbox, 0, "Backup: No files to copy.", mailbox->m_blobdir);
	}

	/* done - set some special config values (do this last to avoid importing crashed backups) */
	mrsqlite3_set_config_int__(dest_sql, "backup_time", now);
	mrsqlite3_set_config__    (dest_sql, "backup_for", mailbox->m_blobdir);

	mailbox->m_cb(mailbox, MR_EVENT_IMEX_FILE_WRITTEN, (uintptr_t)dest_pathNfilename, (uintptr_t)"application/octet-stream");
	success = 1;

cleanup:
	if( dir_handle ) { closedir(dir_handle); }
	if( closed ) { mrsqlite3_open__(mailbox->m_sql, mailbox->m_dbfile, 0); }
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }

	if( stmt ) { sqlite3_finalize(stmt); }
	mrsqlite3_close__(dest_sql);
	mrsqlite3_unref(dest_sql);
	if( delete_dest_file ) { mr_delete_file(dest_pathNfilename, mailbox); }
	free(dest_pathNfilename);

	free(curr_pathNfilename);
	free(buf);
	return success;
}


/*******************************************************************************
 * Import backup
 ******************************************************************************/


char* mrmailbox_imex_has_backup(mrmailbox_t* mailbox, const char* dir_name)
{
	char*          ret = NULL;
	time_t         ret_backup_time = 0;
	DIR*           dir_handle = NULL;
	struct dirent* dir_entry;
	int            prefix_len = strlen(MR_BAK_PREFIX);
	int            suffix_len = strlen(MR_BAK_SUFFIX);
	char*          curr_pathNfilename = NULL;
	mrsqlite3_t*   test_sql = NULL;

	if( mailbox == NULL ) {
		return NULL;
	}

	if( (dir_handle=opendir(dir_name))==NULL ) {
		mrmailbox_log_info(mailbox, 0, "Backup check: Cannot open directory \"%s\".", dir_name); /* this is not an error - eg. the directory may not exist or the user has not given us access to read data from the storage */
		goto cleanup;
	}

	while( (dir_entry=readdir(dir_handle))!=NULL ) {
		const char* name = dir_entry->d_name; /* name without path; may also be `.` or `..` */
		int name_len = strlen(name);
		if( name_len > prefix_len && strncmp(name, MR_BAK_PREFIX, prefix_len)==0
		 && name_len > suffix_len && strncmp(&name[name_len-suffix_len-1], "." MR_BAK_SUFFIX, suffix_len)==0 )
		{
			free(curr_pathNfilename);
			curr_pathNfilename = mr_mprintf("%s/%s", dir_name, name);

			mrsqlite3_unref(test_sql);
			if( (test_sql=mrsqlite3_new(mailbox/*for logging only*/))!=NULL
			 && mrsqlite3_open__(test_sql, curr_pathNfilename, MR_OPEN_READONLY) )
			{
				time_t curr_backup_time = mrsqlite3_get_config_int__(test_sql, "backup_time", 0); /* reading the backup time also checks if the database is readable and the table `config` exists */
				if( curr_backup_time > 0
				 && curr_backup_time > ret_backup_time/*use the newest if there are multiple backup*/ )
				{
					/* set return value to the tested database name */
					free(ret);
					ret = curr_pathNfilename;
					ret_backup_time = curr_backup_time;
					curr_pathNfilename = NULL;
				}
			}
		}
	}

cleanup:
	if( dir_handle ) { closedir(dir_handle); }
	free(curr_pathNfilename);
	mrsqlite3_unref(test_sql);
	return ret;
}


static int import_backup(mrmailbox_t* mailbox, const char* backup_to_import)
{
	/* command for testing eg.
	imex import-backup /home/bpetersen/temp/delta-chat-2017-10-05.bak
	*/

	int           success = 0;
	int           locked = 0;
	int           processed_files_count = 0, total_files_count = 0;
	sqlite3_stmt* stmt = NULL;
	char*         pathNfilename = NULL;

	mrmailbox_log_info(mailbox, 0, "Import \"%s\" to \"%s\".", backup_to_import, mailbox->m_dbfile);

	if( mrmailbox_is_configured(mailbox) ) {
		mrmailbox_log_error(mailbox, 0, "Cannot import backups to mailboxes in use.");
		goto cleanup;
	}

	/* close and delete the original file */
	mrmailbox_disconnect(mailbox);

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

	if( mrsqlite3_is_open(mailbox->m_sql) ) {
		mrsqlite3_close__(mailbox->m_sql);
	}

	mr_delete_file(mailbox->m_dbfile, mailbox);

	if( mr_file_exist(mailbox->m_dbfile) ) {
		mrmailbox_log_error(mailbox, 0, "Cannot import backups: Cannot delete the old file.");
		goto cleanup;
	}

	/* copy the database file */
	if( !mr_copy_file(backup_to_import, mailbox->m_dbfile, mailbox) ) {
		goto cleanup; /* error already logged */
	}

	/* re-open copied database file */
	if( !mrsqlite3_open__(mailbox->m_sql, mailbox->m_dbfile, 0) ) {
		goto cleanup;
	}

	/* copy all blobs to files */
	stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "SELECT COUNT(*) FROM backup_blobs;");
	sqlite3_step(stmt);
	total_files_count = sqlite3_column_int(stmt, 0);
	sqlite3_finalize(stmt);
	stmt = NULL;

	stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "SELECT file_name, file_content FROM backup_blobs ORDER BY id;");
	while( sqlite3_step(stmt) == SQLITE_ROW )
	{
		if( s_imex_do_exit ) {
			goto cleanup;
		}

        FILE_PROGRESS

        const char* file_name    = (const char*)sqlite3_column_text (stmt, 0);
        int         file_bytes   = sqlite3_column_bytes(stmt, 1);
        const void* file_content = sqlite3_column_blob (stmt, 1);

        if( file_bytes > 0 && file_content ) {
			free(pathNfilename);
			pathNfilename = mr_mprintf("%s/%s", mailbox->m_blobdir, file_name);
			if( !mr_write_file(pathNfilename, file_content, file_bytes, mailbox) ) {
				mrmailbox_log_error(mailbox, 0, "Storage full? Cannot write file %s with %i bytes.", pathNfilename, file_bytes);
				goto cleanup; /* otherwise the user may believe the stuff is imported correctly, but there are files missing ... */
			}
		}
	}

	/* finalize/reset all statements - otherwise the table cannot be DROPped below */
	sqlite3_finalize(stmt);
	stmt = 0;
	mrsqlite3_reset_all_predefinitions(mailbox->m_sql);

	mrsqlite3_execute__(mailbox->m_sql, "DROP TABLE backup_blobs;");
	mrsqlite3_execute__(mailbox->m_sql, "VACUUM;");

	success = 1;

cleanup:
	free(pathNfilename);
	if( stmt )  { sqlite3_finalize(stmt); }
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	return success;
}


/*******************************************************************************
 * Import/Export Thread and Main Interface
 ******************************************************************************/


typedef struct mrimexthreadparam_t
{
	mrmailbox_t* m_mailbox;
	int          m_what;
	char*        m_param1; /* meaning depends on m_what */
	char*        m_setup_code;
} mrimexthreadparam_t;


static pthread_t s_imex_thread;
static int       s_imex_thread_created = 0;


static void* imex_thread_entry_point(void* entry_arg)
{
	int                  success = 0;
	mrimexthreadparam_t* thread_param = (mrimexthreadparam_t*)entry_arg;
	mrmailbox_t*         mailbox = thread_param->m_mailbox; /*keep a local pointer as we free thread_param sooner or later */

	mrosnative_setup_thread(mailbox); /* must be first */
	mrmailbox_log_info(mailbox, 0, "Import/export thread started.");

	if( !mrsqlite3_is_open(thread_param->m_mailbox->m_sql) ) {
        mrmailbox_log_error(mailbox, 0, "Import/export: Database not opened.");
		goto cleanup;
	}

	if( thread_param->m_what==MR_IMEX_EXPORT_SELF_KEYS || thread_param->m_what==MR_IMEX_EXPORT_BACKUP ) {
		/* before we export anything, make sure the private key exists */
		if( !mrmailbox_ensure_secret_key_exists(mailbox) ) {
			mrmailbox_log_error(mailbox, 0, "Import/export: Cannot create private key or private key not available.");
			goto cleanup;
		}
		/* also make sure, the directory for exporting exists */
		mr_create_folder(thread_param->m_param1, mailbox);
	}

	switch( thread_param->m_what )
	{
		case MR_IMEX_EXPORT_SELF_KEYS:
			if( !export_self_keys(mailbox, thread_param->m_param1) ) {
				goto cleanup;
			}
			break;

		case MR_IMEX_IMPORT_SELF_KEYS:
			if( !import_self_keys(mailbox, thread_param->m_param1) ) {
				goto cleanup;
			}
			break;

		case MR_IMEX_EXPORT_BACKUP:
			if( !export_backup(mailbox, thread_param->m_param1) ) {
				goto cleanup;
			}
			break;

		case MR_IMEX_IMPORT_BACKUP:
			if( !import_backup(mailbox, thread_param->m_param1) ) {
				goto cleanup;
			}
			break;

		case MR_IMEX_EXPORT_SETUP_MESSAGE:
			if( !export_setup_file(mailbox, thread_param->m_param1, thread_param->m_setup_code) ) {
				goto cleanup;
			}
			break;
	}

	success = 1;

cleanup:
	mrmailbox_log_info(mailbox, 0, "Import/export thread ended.");
	s_imex_do_exit = 1; /* set this before sending MR_EVENT_EXPORT_ENDED, avoids MR_IMEX_CANCEL to stop the thread */
	mailbox->m_cb(mailbox, MR_EVENT_IMEX_ENDED, success, 0);
	s_imex_thread_created = 0;
	free(thread_param->m_param1);
	free(thread_param->m_setup_code);
	free(thread_param);
	mrosnative_unsetup_thread(mailbox); /* must be very last (here we really new the local copy of the pointer) */
	return NULL;
}


void mrmailbox_imex(mrmailbox_t* mailbox, int what, const char* param1, const char* setup_code)
{
	mrimexthreadparam_t* thread_param;

	if( mailbox==NULL || mailbox->m_sql==NULL ) {
		return;
	}

	if( what == MR_IMEX_CANCEL ) {
		/* cancel an running export */
		if( s_imex_thread_created && s_imex_do_exit==0 ) {
			mrmailbox_log_info(mailbox, 0, "Stopping import/export thread...");
				s_imex_do_exit = 1;
				pthread_join(s_imex_thread, NULL);
			mrmailbox_log_info(mailbox, 0, "Import/export thread stopped.");
		}
		return;
	}

	if( param1 == NULL ) {
		mrmailbox_log_error(mailbox, 0, "No Import/export dir/file given.");
		return;
	}

	if( s_imex_thread_created || s_imex_do_exit==0 ) {
		mrmailbox_log_warning(mailbox, 0, "Already importing/exporting.");
		return;
	}
	s_imex_thread_created = 1;
	s_imex_do_exit = 0;

	memset(&s_imex_thread, 0, sizeof(pthread_t));
	thread_param = calloc(1, sizeof(mrimexthreadparam_t));
	thread_param->m_mailbox    = mailbox;
	thread_param->m_what       = what;
	thread_param->m_param1     = safe_strdup(param1);
	thread_param->m_setup_code = safe_strdup(setup_code);
	pthread_create(&s_imex_thread, NULL, imex_thread_entry_point, thread_param);
}


int mrmailbox_check_password(mrmailbox_t* mailbox, const char* test_pw)
{
	/* Check if the given password matches the configured mail_pw.
	This is to prompt the user before starting eg. an export; this is mainly to avoid doing people bad thinkgs if they have short access to the device.
	When we start supporting OAuth some day, we should think this over, maybe force the user to re-authenticate hinself with the Android password. */
	mrloginparam_t* loginparam = mrloginparam_new();
	int             success = 0;

	if( mailbox==NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);

		mrloginparam_read__(loginparam, mailbox->m_sql, "configured_");

	mrsqlite3_unlock(mailbox->m_sql);

	if( (loginparam->m_mail_pw==NULL || loginparam->m_mail_pw[0]==0) && (test_pw==NULL || test_pw[0]==0) ) {
		/* both empty or unset */
		success = 1;
	}
	else if( loginparam->m_mail_pw==NULL || test_pw==NULL ) {
		/* one set, the other not */
		success = 0;
	}
	else if( strcmp(loginparam->m_mail_pw, test_pw)==0 ) {
		/* string-compared passwords are equal */
		success = 1;
	}

cleanup:
	mrloginparam_unref(loginparam);
	return success;
}


/* create an "Autocrypt Level 1" setup code in the form
1234-1234-1234-
1234-1234-1234-
1234-1234-1234
Linebreaks and spaces MUST NOT be added to the setup code, but the "-" are. */
char* mrmailbox_create_setup_code(mrmailbox_t* mailbox)
{
	#define   CODE_ELEMS 9
	#define   BUF_BYTES  (CODE_ELEMS*sizeof(uint16_t))
	uint16_t  buf[CODE_ELEMS];
	int       i;

	if( !RAND_bytes((unsigned char*)buf, BUF_BYTES) ) {
		mrmailbox_log_warning(mailbox, 0, "Falling back to pseudo-number generation for the setup code.");
		RAND_pseudo_bytes((unsigned char*)buf, BUF_BYTES);
	}

	for( i = 0; i < CODE_ELEMS; i++ ) {
		buf[i] = buf[i] % 10000; /* force all blocks into the range 0..9999 */
	}

	return mr_mprintf("%04i-%04i-%04i-"
	                  "%04i-%04i-%04i-"
	                  "%04i-%04i-%04i",
		(int)buf[0], (int)buf[1], (int)buf[2],
		(int)buf[3], (int)buf[4], (int)buf[5],
		(int)buf[6], (int)buf[7], (int)buf[8]);
}
