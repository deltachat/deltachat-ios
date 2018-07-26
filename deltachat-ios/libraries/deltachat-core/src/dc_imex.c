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


#include <assert.h>
#include <dirent.h>
#include <unistd.h> /* for sleep() */
#include <openssl/rand.h>
#include <libetpan/mmapstring.h>
#include <netpgp-extra.h>
#include "dc_context.h"
#include "dc_mimeparser.h"
#include "dc_loginparam.h"
#include "dc_aheader.h"
#include "dc_apeerstate.h"
#include "dc_pgp.h"
#include "dc_mimefactory.h"
#include "dc_job.h"


/**
 * @name Import/Export
 * @{
 */


/*******************************************************************************
 * Autocrypt Key Transfer
 ******************************************************************************/


/**
 * Create an Autocrypt Setup Message. A complete Autocrypt Setup Message looks
 * like the following:
 *
 *     To: me@mydomain.com
 *     From: me@mydomain.com
 *     Autocrypt-Setup-Message: v1
 *     Content-type: multipart/mixed; boundary="==break1=="
 *
 *     --==break1==
 *     Content-Type: text/plain
 *
 *     This is the Autocrypt setup message.
 *
 *     --==break1==
 *     Content-Type: application/autocrypt-setup
 *     Content-Disposition: attachment; filename="autocrypt-setup-message.html"
 *
 *     <html>
 *     <body>
 *     <p>
 *     	This is the Autocrypt Setup File used to transfer keys between clients.
 *     </p>
 *     <pre>
 *     -----BEGIN PGP MESSAGE-----
 *     Version: BCPG v1.53
 *     Passphrase-Format: numeric9x4
 *     Passphrase-Begin: 12
 *
 *     hQIMAxC7JraDy7DVAQ//SK1NltM+r6uRf2BJEg+rnpmiwfAEIiopU0LeOQ6ysmZ0
 *     CLlfUKAcryaxndj4sBsxLllXWzlNiFDHWw4OOUEZAZd8YRbOPfVq2I8+W4jO3Moe
 *     -----END PGP MESSAGE-----
 *     </pre>
 *     </body>
 *     </html>
 *     --==break1==--
 *
 * The encrypted message part contains:
 *
 *     -----BEGIN PGP PRIVATE KEY BLOCK-----
 *     Autocrypt-Prefer-Encrypt: mutual
 *
 *     xcLYBFke7/8BCAD0TTmX9WJm9elc7/xrT4/lyzUDMLbuAuUqRINtCoUQPT2P3Snfx/jou1YcmjDgwT
 *     Ny9ddjyLcdSKL/aR6qQ1UBvlC5xtriU/7hZV6OZEmW2ckF7UgGd6ajE+UEjUwJg2+eKxGWFGuZ1P7a
 *     4Av1NXLayZDsYa91RC5hCsj+umLN2s+68ps5pzLP3NoK2zIFGoCRncgGI/pTAVmYDirhVoKh14hCh5
 *     .....
 *     -----END PGP PRIVATE KEY BLOCK-----
 *
 * dc_render_setup_file() renders the body after the second
 * `-==break1==` in this example.
 *
 * @private @memberof dc_context_t
 * @param context The context object
 * @param passphrase The setup code that shall be used to encrypt the message.
 *     Typically created by dc_create_setup_code().
 * @return String with the HTML-code of the message on success, NULL on errors.
 *     The returned value must be free()'d
 */
char* dc_render_setup_file(dc_context_t* context, const char* passphrase)
{
	sqlite3_stmt*          stmt = NULL;
	char*                  self_addr = NULL;
	dc_key_t*              curr_private_key = dc_key_new();

	char                   passphrase_begin[8];
	uint8_t                salt[PGP_SALT_SIZE];
	pgp_crypt_t            crypt_info;
	uint8_t*               key = NULL;

	pgp_output_t*          payload_output = NULL;
	pgp_memory_t*          payload_mem = NULL;

	pgp_output_t*          encr_output = NULL;
	pgp_memory_t*          encr_mem = NULL;
	char*                  encr_string = NULL;

	char*                  ret_setupfilecontent = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || passphrase==NULL
	 || strlen(passphrase)<2 || curr_private_key==NULL) {
		goto cleanup;
	}

	strncpy(passphrase_begin, passphrase, 2);
	passphrase_begin[2] = 0;

	/* create the payload */

	if (!dc_ensure_secret_key_exists(context)) {
		goto cleanup;
	}

	{
			self_addr = dc_sqlite3_get_config(context->sql, "configured_addr", NULL);
			dc_key_load_self_private(curr_private_key, self_addr, context->sql);

			char* payload_key_asc = dc_key_render_asc(curr_private_key, context->e2ee_enabled? "Autocrypt-Prefer-Encrypt: mutual\r\n" : NULL);
			if (payload_key_asc==NULL) {
				goto cleanup;
			}

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
	#define SYMM_ALGO PGP_SA_AES_128
	if (!pgp_crypt_any(&crypt_info, SYMM_ALGO)) {
		goto cleanup;
	}

	int s2k_spec = PGP_S2KS_ITERATED_AND_SALTED; // 0=simple, 1=salted, 3=salted+iterated
	int s2k_iter_id = 96; // 0=1024 iterations, 96=65536 iterations
	#define HASH_ALG  PGP_HASH_SHA256
	if ((key = pgp_s2k_do(passphrase, crypt_info.keysize, s2k_spec, HASH_ALG, salt, s2k_iter_id))==NULL) {
		goto cleanup;
	}

	/* encrypt the payload using the key using AES-128 and put it into
	OpenPGP's "Symmetric-Key Encrypted Session Key" (Tag 3, https://tools.ietf.org/html/rfc4880#section-5.3) followed by
	OpenPGP's "Symmetrically Encrypted Data Packet" (Tag 18, https://tools.ietf.org/html/rfc4880#section-5.13 , better than Tag 9) */

	pgp_setup_memory_write(&encr_output, &encr_mem, 128);
	pgp_writer_push_armor_msg(encr_output);

	/* Tag 3 - PGP_PTAG_CT_SK_SESSION_KEY */
	pgp_write_ptag     (encr_output, PGP_PTAG_CT_SK_SESSION_KEY);
	pgp_write_length   (encr_output, 1/*version*/
	                               + 1/*symm. algo*/
	                               + 1/*s2k_spec*/
	                               + 1/*S2 hash algo*/
	                               + ((s2k_spec==PGP_S2KS_SALTED || s2k_spec==PGP_S2KS_ITERATED_AND_SALTED)? PGP_SALT_SIZE : 0)/*the salt*/
	                               + ((s2k_spec==PGP_S2KS_ITERATED_AND_SALTED)? 1 : 0)/*number of iterations*/);

	pgp_write_scalar   (encr_output, 4, 1);                  // 1 octet: version
	pgp_write_scalar   (encr_output, SYMM_ALGO, 1);          // 1 octet: symm. algo

	pgp_write_scalar   (encr_output, s2k_spec, 1);           // 1 octet: s2k_spec
	pgp_write_scalar   (encr_output, HASH_ALG, 1);           // 1 octet: S2 hash algo
	if (s2k_spec==PGP_S2KS_SALTED || s2k_spec==PGP_S2KS_ITERATED_AND_SALTED) {
	  pgp_write        (encr_output, salt, PGP_SALT_SIZE);   // 8 octets: the salt
	}
	if (s2k_spec==PGP_S2KS_ITERATED_AND_SALTED) {
	  pgp_write_scalar (encr_output, s2k_iter_id, 1);        // 1 octet: number of iterations
	}

	// for(int j=0; j<AES_KEY_LENGTH; j++) { printf("%02x", key[j]); } printf("\n----------------\n");

	/* Tag 18 - PGP_PTAG_CT_SE_IP_DATA */
	//pgp_write_symm_enc_data((const uint8_t*)payload_mem->buf, payload_mem->length, PGP_SA_AES_128, key, encr_output); //-- would generate Tag 9
	{
		uint8_t* iv = calloc(1, crypt_info.blocksize); if (iv==NULL) { goto cleanup; }
		crypt_info.set_iv(&crypt_info, iv);
		free(iv);

		crypt_info.set_crypt_key(&crypt_info, &key[0]);
		pgp_encrypt_init(&crypt_info);

		pgp_write_se_ip_pktset(encr_output, payload_mem->buf, payload_mem->length, &crypt_info);

		crypt_info.decrypt_finish(&crypt_info);
	}

	/* done with symmetric key block */
	pgp_writer_close(encr_output);
	encr_string = dc_null_terminate((const char*)encr_mem->buf, encr_mem->length);

	//printf("\n~~~~~~~~~~~~~~~~~~~~SYMMETRICALLY ENCRYPTED~~~~~~~~~~~~~~~~~~~~\n%s~~~~~~~~~~~~~~~~~~~~/SYMMETRICALLY ENCRYPTED~~~~~~~~~~~~~~~~~~~~\n",encr_string); // DEBUG OUTPUT


	/* add additional header to armored block */

	#define LINEEND "\r\n" /* use the same lineends as the PGP armored data */
	{
		char* replacement = dc_mprintf("-----BEGIN PGP MESSAGE-----" LINEEND
		                               "Passphrase-Format: numeric9x4" LINEEND
		                               "Passphrase-Begin: %s", passphrase_begin);
		dc_str_replace(&encr_string, "-----BEGIN PGP MESSAGE-----", replacement);
		free(replacement);
	}

	/* wrap HTML-commands with instructions around the encrypted payload */

	{
		char* setup_message_title = dc_stock_str(context, DC_STR_AC_SETUP_MSG_SUBJECT);
		char* setup_message_body = dc_stock_str(context, DC_STR_AC_SETUP_MSG_BODY);

		dc_str_replace(&setup_message_body, "\r", NULL);
		dc_str_replace(&setup_message_body, "\n", "<br>");

		ret_setupfilecontent = dc_mprintf(
			"<!DOCTYPE html>" LINEEND
			"<html>" LINEEND
				"<head>" LINEEND
					"<title>%s</title>" LINEEND
				"</head>" LINEEND
				"<body>" LINEEND
					"<h1>%s</h1>" LINEEND
					"<p>%s</p>" LINEEND
					"<pre>" LINEEND
					"%s" LINEEND
					"</pre>" LINEEND
				"</body>" LINEEND
			"</html>" LINEEND,
			setup_message_title,
			setup_message_title,
			setup_message_body,
			encr_string);

		free(setup_message_title);
		free(setup_message_body);
	}

cleanup:
	sqlite3_finalize(stmt);

	if (payload_output) { pgp_output_delete(payload_output); }
	if (payload_mem) { pgp_memory_free(payload_mem); }

	if (encr_output) { pgp_output_delete(encr_output); }
	if (encr_mem) { pgp_memory_free(encr_mem); }

	dc_key_unref(curr_private_key);
	free(encr_string);
	free(self_addr);

	free(key);

	return ret_setupfilecontent;
}


/**
 * Parse the given file content and extract the private key.
 *
 * @private @memberof dc_context_t
 * @param context The context object
 * @param passphrase The setup code that shall be used to decrypt the message.
 *     May be created by dc_create_setup_code() on another device or by
 *     a completely different app as Thunderbird/Enigmail or K-9.
 * @param filecontent The file content of the setup message, may be HTML.
 *     May be created by dc_render_setup_code() on another device or by
 *     a completely different app as Thunderbird/Enigmail or K-9.
 * @return The decrypted private key as armored-ascii-data or NULL on errors.
 *     Must be dc_key_unref()'d.
 */
char* dc_decrypt_setup_file(dc_context_t* context, const char* passphrase, const char* filecontent)
{
	char*         fc_buf = NULL;
	const char*   fc_headerline = NULL;
	const char*   fc_base64 = NULL;
	char*         binary = NULL;
	size_t        binary_bytes = 0;
	size_t        indx = 0;
	pgp_io_t      io;
	pgp_memory_t* outmem = NULL;
	char*         payload = NULL;

	/* extract base64 from filecontent */
	fc_buf = dc_strdup(filecontent);
	if (!dc_split_armored_data(fc_buf, &fc_headerline, NULL, NULL, &fc_base64)
	 || fc_headerline==NULL || strcmp(fc_headerline, "-----BEGIN PGP MESSAGE-----")!=0 || fc_base64==NULL) {
		goto cleanup;
	}

	/* convert base64 to binary */
	if (mailmime_base64_body_parse(fc_base64, strlen(fc_base64), &indx, &binary/*must be freed using mmap_string_unref()*/, &binary_bytes)!=MAILIMF_NO_ERROR
	 || binary==NULL || binary_bytes==0) {
		goto cleanup;
	}

	/* decrypt symmetrically */
	memset(&io, 0, sizeof(pgp_io_t));
	io.outs = stdout;
	io.errs = stderr;
	io.res  = stderr;
	if ((outmem=pgp_decrypt_buf(&io, binary, binary_bytes, NULL, NULL, 0, 0, passphrase))==NULL) {
		goto cleanup;
	}
	payload = strndup((const char*)outmem->buf, outmem->length);

cleanup:
	free(fc_buf);
	if (binary) { mmap_string_unref(binary); }
	if (outmem) { pgp_memory_free(outmem); }
	return payload;
}


/**
 * Create random setup code.
 *
 * The created "Autocrypt Level 1" setup code has the form `1234-1234-1234-1234-1234-1234-1234-1234-1234`.
 * Linebreaks and spaces are not added to the setup code, but the `-` are.
 * The setup code is typically given to dc_render_setup_file().
 *
 * A higher-level function to initiate the key transfer is dc_initiate_key_transfer().
 *
 * @private @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @return Setup code, must be free()'d after usage. NULL on errors.
 */
char* dc_create_setup_code(dc_context_t* context)
{
	#define         CODE_ELEMS 9
	uint16_t        random_val = 0;
	int             i = 0;
	dc_strbuilder_t ret;
	dc_strbuilder_init(&ret, 0);

	for (i = 0; i < CODE_ELEMS; i++)
	{
		do
		{
			if (!RAND_bytes((unsigned char*)&random_val, sizeof(uint16_t))) {
				dc_log_warning(context, 0, "Falling back to pseudo-number generation for the setup code.");
				RAND_pseudo_bytes((unsigned char*)&random_val, sizeof(uint16_t));
			}
		}
		while (random_val > 60000); /* make sure the modulo below does not reduce entropy (range is 0..65535, a module 10000 would make appearing values <=535 one time more often than other values) */

		random_val = random_val % 10000; /* force all blocks into the range 0..9999 */

		dc_strbuilder_catf(&ret, "%s%04i", i?"-":"", (int)random_val);
	}

	return ret.buf;
}


/* Function remove all special characters from the given code and brings it to the 9x4 form */
char* dc_normalize_setup_code(dc_context_t* context, const char* in)
{
	if (in==NULL) {
		return NULL;
	}

	dc_strbuilder_t out;
	dc_strbuilder_init(&out, 0);
	int outlen = 0;

	const char* p1 = in;
	while (*p1) {
		if (*p1 >= '0' && *p1 <= '9') {
			dc_strbuilder_catf(&out, "%c", *p1);
			outlen = strlen(out.buf);
			if (outlen==4 || outlen==9 || outlen==14 || outlen==19 || outlen==24 || outlen==29 || outlen==34 || outlen==39) {
				dc_strbuilder_cat(&out, "-");
			}
		}
		p1++;
	}

	return out.buf;
}


/**
 * Initiate Autocrypt Setup Transfer.
 * Before starting the setup transfer with this function, the user should be asked:
 *
 * ```
 * "An 'Autocrypt Setup Message' securely shares your end-to-end setup with other Autocrypt-compliant apps.
 * The setup will be encrypted by a setup code which is displayed here and must be typed on the other device.
 * ```
 *
 * After that, this function should be called to send the Autocrypt Setup Message.
 * The function creates the setup message and waits until it is really sent.
 * As this may take a while, it is recommended to start the function in a separate thread;
 * to interrupt it, you can use dc_stop_ongoing_process().
 *
 * After everything succeeded, the required setup code is returned in the following format:
 *
 * ```
 * 1234-1234-1234-1234-1234-1234-1234-1234-1234
 * ```
 *
 * The setup code should be shown to the user then:
 *
 * ```
 * "Your key has been sent to yourself. Switch to the other device and
 * open the setup message. You should be prompted for a setup code. Type
 * the following digits into the prompt:
 *
 * 1234 - 1234 - 1234 -
 * 1234 - 1234 - 1234 -
 * 1234 - 1234 - 1234
 *
 * Once you're done, your other device will be ready to use Autocrypt."
 * ```
 *
 * On the _other device_ you will call dc_continue_key_transfer() then
 * for setup messages identified by dc_msg_is_setupmessage().
 *
 * For more details about the Autocrypt setup process, please refer to
 * https://autocrypt.org/en/latest/level1.html#autocrypt-setup-message
 *
 * @memberof dc_context_t
 * @param context The context object.
 * @return The setup code. Must be free()'d after usage.
 *     On errors, eg. if the message could not be sent, NULL is returned.
 */
char* dc_initiate_key_transfer(dc_context_t* context)
{
	int       success = 0;
	char*     setup_code = NULL;
	char*     setup_file_content = NULL;
	char*     setup_file_name = NULL;
	uint32_t  chat_id = 0;
	dc_msg_t* msg = NULL;
	uint32_t  msg_id = 0;

	if (!dc_alloc_ongoing(context)) {
		return 0; /* no cleanup as this would call dc_free_ongoing() */
	}
	#define CHECK_EXIT if (context->shall_stop_ongoing) { goto cleanup; }

	if ((setup_code=dc_create_setup_code(context))==NULL) { /* this may require a keypair to be created. this may take a second ... */
		goto cleanup;
	}

	CHECK_EXIT

	if ((setup_file_content=dc_render_setup_file(context, setup_code))==NULL) { /* encrypting may also take a while ... */
		goto cleanup;
	}

	CHECK_EXIT

	if ((setup_file_name=dc_get_fine_pathNfilename(context->blobdir, "autocrypt-setup-message.html"))==NULL
	 || !dc_write_file(setup_file_name, setup_file_content, strlen(setup_file_content), context)) {
		goto cleanup;
	}

	if ((chat_id=dc_create_chat_by_contact_id(context, DC_CONTACT_ID_SELF))==0) {
		goto cleanup;
	}

	msg = dc_msg_new(context);
	msg->type = DC_MSG_FILE;
	dc_param_set    (msg->param, DC_PARAM_FILE,              setup_file_name);
	dc_param_set    (msg->param, DC_PARAM_MIMETYPE,          "application/autocrypt-setup");
	dc_param_set_int(msg->param, DC_PARAM_CMD,               DC_CMD_AUTOCRYPT_SETUP_MESSAGE);
	dc_param_set_int(msg->param, DC_PARAM_FORCE_PLAINTEXT,   DC_FP_NO_AUTOCRYPT_HEADER);

	CHECK_EXIT

	if ((msg_id = dc_send_msg(context, chat_id, msg))==0) {
		goto cleanup;
	}

	dc_msg_unref(msg);
	msg = NULL;

	/* wait until the message is really sent */
	dc_log_info(context, 0, "Wait for setup message being sent ...");

	while (1)
	{
		CHECK_EXIT

		sleep(1);

		msg = dc_get_msg(context, msg_id);
		if (dc_msg_is_sent(msg)) {
			break;
		}
		dc_msg_unref(msg);
		msg = NULL;
	}

	dc_log_info(context, 0, "... setup message sent.");

	success = 1;

cleanup:
	if (!success) { free(setup_code); setup_code = NULL; }
	free(setup_file_name);
	free(setup_file_content);
	dc_msg_unref(msg);
	dc_free_ongoing(context);
	return setup_code;
}


static int set_self_key(dc_context_t* context, const char* armored, int set_default)
{
	int            success = 0;
	char*          buf = NULL;
	const char*    buf_headerline = NULL;    // pointer inside buf, MUST NOT be free()'d
	const char*    buf_preferencrypt = NULL; //   - " -
	const char*    buf_base64 = NULL;        //   - " -
	dc_key_t*      private_key = dc_key_new();
	dc_key_t*      public_key = dc_key_new();
	sqlite3_stmt*  stmt = NULL;
	char*          self_addr = NULL;

	buf = dc_strdup(armored);
	if (!dc_split_armored_data(buf, &buf_headerline, NULL, &buf_preferencrypt, &buf_base64)
	 || strcmp(buf_headerline, "-----BEGIN PGP PRIVATE KEY BLOCK-----")!=0 || buf_base64==NULL) {
		dc_log_warning(context, 0, "File does not contain a private key."); /* do not log as error - this is quite normal after entering the bad setup code */
		goto cleanup;
	}

	if (!dc_key_set_from_base64(private_key, buf_base64, DC_KEY_PRIVATE)
	 || !dc_pgp_is_valid_key(context, private_key)
	 || !dc_pgp_split_key(context, private_key, public_key)) {
		dc_log_error(context, 0, "File does not contain a valid private key.");
		goto cleanup;
	}

	/* add keypair; before this, delete other keypairs with the same binary key and reset defaults */
	stmt = dc_sqlite3_prepare(context->sql, "DELETE FROM keypairs WHERE public_key=? OR private_key=?;");
	sqlite3_bind_blob (stmt, 1, public_key->binary, public_key->bytes, SQLITE_STATIC);
	sqlite3_bind_blob (stmt, 2, private_key->binary, private_key->bytes, SQLITE_STATIC);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
	stmt = NULL;

	if (set_default) {
		dc_sqlite3_execute(context->sql, "UPDATE keypairs SET is_default=0;"); /* if the new key should be the default key, all other should not */
	}

	self_addr = dc_sqlite3_get_config(context->sql, "configured_addr", NULL);
	if (!dc_key_save_self_keypair(public_key, private_key, self_addr, set_default, context->sql)) {
		dc_log_error(context, 0, "Cannot save keypair.");
		goto cleanup;
	}

	/* if we also received an Autocrypt-Prefer-Encrypt header, handle this */
	if (buf_preferencrypt) {
		if (strcmp(buf_preferencrypt, "nopreference")==0) {
			dc_set_config_int(context, "e2ee_enabled", 0); /* use the top-level function as this also resets cached values */
		}
		else if (strcmp(buf_preferencrypt, "mutual")==0) {
			dc_set_config_int(context, "e2ee_enabled", 1); /* use the top-level function as this also resets cached values */
		}
	}

	success = 1;

cleanup:
	sqlite3_finalize(stmt);
	free(buf);
	free(self_addr);
	dc_key_unref(private_key);
	dc_key_unref(public_key);
	return success;
}


/**
 * Continue the Autocrypt Key Transfer on another device.
 *
 * If you have started the key transfer on another device using dc_initiate_key_transfer()
 * and you've detected a setup message with dc_msg_is_setupmessage(), you should prompt the
 * user for the setup code and call this function then.
 *
 * You can use dc_msg_get_setupcodebegin() to give the user a hint about the code (useful if the user
 * has created several messages and should not enter the wrong code).
 *
 * @memberof dc_context_t
 * @param context The context object.
 * @param msg_id ID of the setup message to decrypt.
 * @param setup_code Setup code entered by the user. This is the same setup code as returned from
 *     dc_initiate_key_transfer() on the other device.
 *     There is no need to format the string correctly, the function will remove all spaces and other characters and
 *     insert the `-` characters at the correct places.
 * @return 1=key successfully decrypted and imported; both devices will use the same key now;
 *     0=key transfer failed eg. due to a bad setup code.
 */
int dc_continue_key_transfer(dc_context_t* context, uint32_t msg_id, const char* setup_code)
{
	int       success = 0;
	dc_msg_t* msg = NULL;
	char*     filename = NULL;
	char*     filecontent = NULL;
	size_t    filebytes = 0;
	char*     armored_key = NULL;
	char*     norm_sc = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || msg_id <= DC_MSG_ID_LAST_SPECIAL || setup_code==NULL) {
		goto cleanup;
	}

	if ((msg=dc_get_msg(context, msg_id))==NULL || !dc_msg_is_setupmessage(msg)
	 || (filename=dc_msg_get_file(msg))==NULL || filename[0]==0) {
		dc_log_error(context, 0, "Message is no Autocrypt Setup Message.");
		goto cleanup;
	}

	if (!dc_read_file(filename, (void**)&filecontent, &filebytes, msg->context) || filecontent==NULL || filebytes <= 0) {
		dc_log_error(context, 0, "Cannot read Autocrypt Setup Message file.");
		goto cleanup;
	}

	if ((norm_sc = dc_normalize_setup_code(context, setup_code))==NULL) {
		dc_log_warning(context, 0, "Cannot normalize Setup Code.");
		goto cleanup;
	}

	if ((armored_key=dc_decrypt_setup_file(context, norm_sc, filecontent))==NULL) {
		dc_log_warning(context, 0, "Cannot decrypt Autocrypt Setup Message."); /* do not log as error - this is quite normal after entering the bad setup code */
		goto cleanup;
	}

	if (!set_self_key(context, armored_key, 1/*set default*/)) {
		goto cleanup; /* error already logged */
	}

	success = 1;

cleanup:
	free(armored_key);
	free(filecontent);
	free(filename);
	dc_msg_unref(msg);
	free(norm_sc);
	return success;
}


/*******************************************************************************
 * Classic key export
 ******************************************************************************/


static void export_key_to_asc_file(dc_context_t* context, const char* dir, int id, const dc_key_t* key, int is_default)
{
	char* file_name;
	if (is_default) {
		file_name = dc_mprintf("%s/%s-key-default.asc", dir, key->type==DC_KEY_PUBLIC? "public" : "private");
	}
	else {
		file_name = dc_mprintf("%s/%s-key-%i.asc", dir, key->type==DC_KEY_PUBLIC? "public" : "private", id);
	}
	dc_log_info(context, 0, "Exporting key %s", file_name);
	dc_delete_file(file_name, context);
	if (dc_key_render_asc_to_file(key, file_name, context)) {
		context->cb(context, DC_EVENT_IMEX_FILE_WRITTEN, (uintptr_t)file_name, 0);
		dc_log_error(context, 0, "Cannot write key to %s", file_name);
	}
	free(file_name);
}


static int export_self_keys(dc_context_t* context, const char* dir)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;
	int           id = 0;
	int           is_default = 0;
	dc_key_t*     public_key = dc_key_new();
	dc_key_t*     private_key = dc_key_new();

		if ((stmt=dc_sqlite3_prepare(context->sql, "SELECT id, public_key, private_key, is_default FROM keypairs;"))==NULL) {
			goto cleanup;
		}

		while (sqlite3_step(stmt)==SQLITE_ROW) {
			id = sqlite3_column_int(         stmt, 0 );
			dc_key_set_from_stmt(public_key,  stmt, 1, DC_KEY_PUBLIC);
			dc_key_set_from_stmt(private_key, stmt, 2, DC_KEY_PRIVATE);
			is_default = sqlite3_column_int( stmt, 3 );
			export_key_to_asc_file(context, dir, id, public_key,  is_default);
			export_key_to_asc_file(context, dir, id, private_key, is_default);
		}

		success = 1;

cleanup:
	sqlite3_finalize(stmt);
	dc_key_unref(public_key);
	dc_key_unref(private_key);
	return success;
}


/*******************************************************************************
 * Classic key import
 ******************************************************************************/


static int import_self_keys(dc_context_t* context, const char* dir_name)
{
	/* hint: even if we switch to import Autocrypt Setup Files, we should leave the possibility to import
	plain ASC keys, at least keys without a password, if we do not want to implement a password entry function.
	Importing ASC keys is useful to use keys in Delta Chat used by any other non-Autocrypt-PGP implementation.

	Maybe we should make the "default" key handlong also a little bit smarter
	(currently, the last imported key is the standard key unless it contains the string "legacy" in its name) */

	int            imported_cnt = 0;
	DIR*           dir_handle = NULL;
	struct dirent* dir_entry = NULL;
	char*          suffix = NULL;
	char*          path_plus_name = NULL;
	int            set_default = 0;
	char*          buf = NULL;
	size_t         buf_bytes = 0;
	const char*    private_key = NULL; // a pointer inside buf, MUST NOT be free()'d
	char*          buf2 = NULL;
	const char*    buf2_headerline = NULL; // a pointer inside buf2, MUST NOT be free()'d

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || dir_name==NULL) {
		goto cleanup;
	}
	if ((dir_handle=opendir(dir_name))==NULL) {
		dc_log_error(context, 0, "Import: Cannot open directory \"%s\".", dir_name);
		goto cleanup;
	}

	while ((dir_entry=readdir(dir_handle))!=NULL)
	{
		free(suffix);
		suffix = dc_get_filesuffix_lc(dir_entry->d_name);
		if (suffix==NULL || strcmp(suffix, "asc")!=0) {
			continue;
		}

		free(path_plus_name);
		path_plus_name = dc_mprintf("%s/%s", dir_name, dir_entry->d_name/* name without path; may also be `.` or `..` */);
		dc_log_info(context, 0, "Checking: %s", path_plus_name);

		free(buf);
		buf = NULL;
		if (!dc_read_file(path_plus_name, (void**)&buf, &buf_bytes, context)
		 || buf_bytes < 50) {
			continue;
		}
		private_key = buf;

		free(buf2);
		buf2 = dc_strdup(buf);
		if (dc_split_armored_data(buf2, &buf2_headerline, NULL, NULL, NULL)
		 && strcmp(buf2_headerline, "-----BEGIN PGP PUBLIC KEY BLOCK-----")==0) {
			/* This file starts with a Public Key.
			 * However some programs (Thunderbird/Enigmail) put public and private key
			 * in the same file, so we check if there is a private key following */
			private_key = strstr(buf, "-----BEGIN PGP PRIVATE KEY BLOCK");
			if (private_key==NULL) {
				continue; /* this is no error but quite normal as we always export the public keys together with the private ones */
			}
		}

		set_default = 1;
		if (strstr(dir_entry->d_name, "legacy")!=NULL) {
			dc_log_info(context, 0, "Treating \"%s\" as a legacy private key.", path_plus_name);
			set_default = 0; /* a key with "legacy" in its name is not made default; this may result in a keychain with _no_ default, however, this is no problem, as this will create a default key later */
		}

		if (!set_self_key(context, private_key, set_default)) {
			continue;
		}

		imported_cnt++;
	}

	if (imported_cnt==0) {
		dc_log_error(context, 0, "No private keys found in \"%s\".", dir_name);
		goto cleanup;
	}

cleanup:
	if (dir_handle) { closedir(dir_handle); }
	free(suffix);
	free(path_plus_name);
	free(buf);
	free(buf2);
	return imported_cnt;
}


/*******************************************************************************
 * Export backup
 ******************************************************************************/


/* the FILE_PROGRESS macro calls the callback with the permille of files processed.
The macro avoids weird values of 0% or 100% while still working. */
#define FILE_PROGRESS \
	processed_files_cnt++; \
	int permille = (processed_files_cnt*1000)/total_files_cnt; \
	if (permille <  10) { permille =  10; } \
	if (permille > 990) { permille = 990; } \
	context->cb(context, DC_EVENT_IMEX_PROGRESS, permille, 0);


static int export_backup(dc_context_t* context, const char* dir)
{
	int            success = 0;
	int            closed = 0;
	char*          dest_pathNfilename = NULL;
	dc_sqlite3_t*  dest_sql = NULL;
	time_t         now = time(NULL);
	DIR*           dir_handle = NULL;
	struct dirent* dir_entry = NULL;
	int            prefix_len = strlen(DC_BAK_PREFIX);
	int            suffix_len = strlen(DC_BAK_SUFFIX);
	char*          curr_pathNfilename = NULL;
	void*          buf = NULL;
	size_t         buf_bytes = 0;
	sqlite3_stmt*  stmt = NULL;
	int            total_files_cnt = 0;
	int            processed_files_cnt = 0;
	int            delete_dest_file = 0;

	/* get a fine backup file name (the name includes the date so that multiple backup instances are possible)
	FIXME: we should write to a temporary file first and rename it on success. this would guarantee the backup is complete. however, currently it is not clear it the import exists in the long run (may be replaced by a restore-from-imap)*/
	{
		struct tm* timeinfo;
		char buffer[256];
		timeinfo = localtime(&now);
		strftime(buffer, 256, DC_BAK_PREFIX "-%Y-%m-%d." DC_BAK_SUFFIX, timeinfo);
		if ((dest_pathNfilename=dc_get_fine_pathNfilename(dir, buffer))==NULL) {
			dc_log_error(context, 0, "Cannot get backup file name.");
			goto cleanup;
		}
	}

	/* temporary lock and close the source (we just make a copy of the whole file, this is the fastest and easiest approach) */
	dc_sqlite3_close(context->sql);
	closed = 1;

		dc_log_info(context, 0, "Backup \"%s\" to \"%s\".", context->dbfile, dest_pathNfilename);
		if (!dc_copy_file(context->dbfile, dest_pathNfilename, context)) {
			goto cleanup; /* error already logged */
		}

	dc_sqlite3_open(context->sql, context->dbfile, 0);
	closed = 0;

	/* add all files as blobs to the database copy (this does not require the source to be locked, neigher the destination as it is used only here) */
	if ((dest_sql=dc_sqlite3_new(context/*for logging only*/))==NULL
	 || !dc_sqlite3_open(dest_sql, dest_pathNfilename, 0)) {
		goto cleanup; /* error already logged */
	}

	if (!dc_sqlite3_table_exists(dest_sql, "backup_blobs")) {
		if (!dc_sqlite3_execute(dest_sql, "CREATE TABLE backup_blobs (id INTEGER PRIMARY KEY, file_name, file_content);")) {
			goto cleanup; /* error already logged */
		}
	}

	/* scan directory, pass 1: collect file info */
	total_files_cnt = 0;
	if ((dir_handle=opendir(context->blobdir))==NULL) {
		dc_log_error(context, 0, "Backup: Cannot get info for blob-directory \"%s\".", context->blobdir);
		goto cleanup;
	}

	while ((dir_entry=readdir(dir_handle))!=NULL) {
		total_files_cnt++;
	}

	closedir(dir_handle);
	dir_handle = NULL;

	if (total_files_cnt>0)
	{
		/* scan directory, pass 2: copy files */
		if ((dir_handle=opendir(context->blobdir))==NULL) {
			dc_log_error(context, 0, "Backup: Cannot copy from blob-directory \"%s\".", context->blobdir);
			goto cleanup;
		}

		stmt = dc_sqlite3_prepare(dest_sql, "INSERT INTO backup_blobs (file_name, file_content) VALUES (?, ?);");
		while ((dir_entry=readdir(dir_handle))!=NULL)
		{
			if (context->shall_stop_ongoing) {
				delete_dest_file = 1;
				goto cleanup;
			}

			FILE_PROGRESS

			char* name = dir_entry->d_name; /* name without path; may also be `.` or `..` */
			int name_len = strlen(name);
			if ((name_len==1 && name[0]=='.')
			 || (name_len==2 && name[0]=='.' && name[1]=='.')
			 || (name_len > prefix_len && strncmp(name, DC_BAK_PREFIX, prefix_len)==0 && name_len > suffix_len && strncmp(&name[name_len-suffix_len-1], "." DC_BAK_SUFFIX, suffix_len)==0)) {
				//dc_log_info(context, 0, "Backup: Skipping \"%s\".", name);
				continue;
			}

			//dc_log_info(context, 0, "Backup \"%s\".", name);
			free(curr_pathNfilename);
			curr_pathNfilename = dc_mprintf("%s/%s", context->blobdir, name);
			free(buf);
			if (!dc_read_file(curr_pathNfilename, &buf, &buf_bytes, context) || buf==NULL || buf_bytes<=0) {
				continue;
			}

			sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
			sqlite3_bind_blob(stmt, 2, buf, buf_bytes, SQLITE_STATIC);
			if (sqlite3_step(stmt)!=SQLITE_DONE) {
				dc_log_error(context, 0, "Disk full? Cannot add file \"%s\" to backup.", curr_pathNfilename);
				goto cleanup; /* this is not recoverable! writing to the sqlite database should work! */
			}
			sqlite3_reset(stmt);
		}
	}
	else
	{
		dc_log_info(context, 0, "Backup: No files to copy.", context->blobdir);
	}

	/* done - set some special config values (do this last to avoid importing crashed backups) */
	dc_sqlite3_set_config_int(dest_sql, "backup_time", now);
	dc_sqlite3_set_config    (dest_sql, "backup_for", context->blobdir);

	context->cb(context, DC_EVENT_IMEX_FILE_WRITTEN, (uintptr_t)dest_pathNfilename, 0);
	success = 1;

cleanup:
	if (dir_handle) { closedir(dir_handle); }
	if (closed) { dc_sqlite3_open(context->sql, context->dbfile, 0); }

	sqlite3_finalize(stmt);
	dc_sqlite3_close(dest_sql);
	dc_sqlite3_unref(dest_sql);
	if (delete_dest_file) { dc_delete_file(dest_pathNfilename, context); }
	free(dest_pathNfilename);

	free(curr_pathNfilename);
	free(buf);
	return success;
}


/*******************************************************************************
 * Import backup
 ******************************************************************************/


static void ensure_no_slash(char* path)
{
	int path_len = strlen(path);
	if (path_len > 0) {
		if (path[path_len-1]=='/'
		 || path[path_len-1]=='\\') {
			path[path_len-1] = 0;
		}
	}
}


static int import_backup(dc_context_t* context, const char* backup_to_import)
{
	/* command for testing eg.
	imex import-backup /home/bpetersen/temp/delta-chat-2017-11-14.bak
	*/

	int           success = 0;
	int           processed_files_cnt = 0;
	int           total_files_cnt = 0;
	sqlite3_stmt* stmt = NULL;
	char*         pathNfilename = NULL;
	char*         repl_from = NULL;
	char*         repl_to = NULL;

	dc_log_info(context, 0, "Import \"%s\" to \"%s\".", backup_to_import, context->dbfile);

	if (dc_is_configured(context)) {
		dc_log_error(context, 0, "Cannot import backups to accounts in use.");
		goto cleanup;
	}

	/* close and delete the original file - FIXME: we should import to a .bak file and rename it on success. however, currently it is not clear it the import exists in the long run (may be replaced by a restore-from-imap) */

//dc_sqlite3_lock(context->sql);  // TODO: check if this works while threads running
//locked = 1;

	if (dc_sqlite3_is_open(context->sql)) {
		dc_sqlite3_close(context->sql);
	}

	dc_delete_file(context->dbfile, context);

	if (dc_file_exist(context->dbfile)) {
		dc_log_error(context, 0, "Cannot import backups: Cannot delete the old file.");
		goto cleanup;
	}

	/* copy the database file */
	if (!dc_copy_file(backup_to_import, context->dbfile, context)) {
		goto cleanup; /* error already logged */
	}

	/* re-open copied database file */
	if (!dc_sqlite3_open(context->sql, context->dbfile, 0)) {
		goto cleanup;
	}

	/* copy all blobs to files */
	stmt = dc_sqlite3_prepare(context->sql, "SELECT COUNT(*) FROM backup_blobs;");
	sqlite3_step(stmt);
	total_files_cnt = sqlite3_column_int(stmt, 0);
	sqlite3_finalize(stmt);
	stmt = NULL;

	stmt = dc_sqlite3_prepare(context->sql, "SELECT file_name, file_content FROM backup_blobs ORDER BY id;");
	while (sqlite3_step(stmt)==SQLITE_ROW)
	{
		if (context->shall_stop_ongoing) {
			goto cleanup;
		}

        FILE_PROGRESS

        const char* file_name    = (const char*)sqlite3_column_text (stmt, 0);
        int         file_bytes   = sqlite3_column_bytes(stmt, 1);
        const void* file_content = sqlite3_column_blob (stmt, 1);

        if (file_bytes > 0 && file_content) {
			free(pathNfilename);
			pathNfilename = dc_mprintf("%s/%s", context->blobdir, file_name);
			if (!dc_write_file(pathNfilename, file_content, file_bytes, context)) {
				dc_log_error(context, 0, "Storage full? Cannot write file %s with %i bytes.", pathNfilename, file_bytes);
				goto cleanup; /* otherwise the user may believe the stuff is imported correctly, but there are files missing ... */
			}
		}
	}

	/* finalize/reset all statements - otherwise the table cannot be DROPped below */
	sqlite3_finalize(stmt);
	stmt = 0;

	dc_sqlite3_execute(context->sql, "DROP TABLE backup_blobs;");
	dc_sqlite3_execute(context->sql, "VACUUM;");

	/* rewrite references to the blobs */
	repl_from = dc_sqlite3_get_config(context->sql, "backup_for", NULL);
	if (repl_from && strlen(repl_from)>1 && context->blobdir && strlen(context->blobdir)>1)
	{
		ensure_no_slash(repl_from);
		repl_to = dc_strdup(context->blobdir);
		ensure_no_slash(repl_to);

		dc_log_info(context, 0, "Rewriting paths from '%s' to '%s' ...", repl_from, repl_to);

		assert( 'f'==DC_PARAM_FILE);
		assert( 'i'==DC_PARAM_PROFILE_IMAGE);

		char* q3 = sqlite3_mprintf("UPDATE msgs SET param=replace(param, 'f=%q/', 'f=%q/');", repl_from, repl_to); /* cannot use dc_mprintf() because of "%q" */
			dc_sqlite3_execute(context->sql, q3);
		sqlite3_free(q3);

		q3 = sqlite3_mprintf("UPDATE chats SET param=replace(param, 'i=%q/', 'i=%q/');", repl_from, repl_to);
			dc_sqlite3_execute(context->sql, q3);
		sqlite3_free(q3);

		q3 = sqlite3_mprintf("UPDATE contacts SET param=replace(param, 'i=%q/', 'i=%q/');", repl_from, repl_to);
			dc_sqlite3_execute(context->sql, q3);
		sqlite3_free(q3);
	}

	success = 1;

cleanup:
	free(pathNfilename);
	free(repl_from);
	free(repl_to);
	sqlite3_finalize(stmt);

// if (locked) { dc_sqlite3_unlock(context->sql); }  // TODO: check if this works while threads running

	return success;
}


/*******************************************************************************
 * Import/Export Thread and Main Interface
 ******************************************************************************/


/**
 * Import/export things.
 * For this purpose, the function creates a job that is executed in the IMAP-thread then;
 * this requires to call dc_perform_imap_jobs() regulary.
 *
 * What to do is defined by the _what_ parameter which may be one of the following:
 *
 * - **DC_IMEX_EXPORT_BACKUP** (11) - Export a backup to the directory given as `param1`.
 *   The backup contains all contacts, chats, images and other data and device independent settings.
 *   The backup does not contain device dependent settings as ringtones or LED notification settings.
 *   The name of the backup is typically `delta-chat.<day>.bak`, if more than one backup is create on a day,
 *   the format is `delta-chat.<day>-<number>.bak`
 *
 * - **DC_IMEX_IMPORT_BACKUP** (12) - `param1` is the file (not: directory) to import. The file is normally
 *   created by DC_IMEX_EXPORT_BACKUP and detected by dc_imex_has_backup(). Importing a backup
 *   is only possible as long as the context is not configured or used in another way.
 *
 * - **DC_IMEX_EXPORT_SELF_KEYS** (1) - Export all private keys and all public keys of the user to the
 *   directory given as `param1`.  The default key is written to the files `public-key-default.asc`
 *   and `private-key-default.asc`, if there are more keys, they are written to files as
 *   `public-key-<id>.asc` and `private-key-<id>.asc`
 *
 * - **DC_IMEX_IMPORT_SELF_KEYS** (2) - Import private keys found in the directory given as `param1`.
 *   The last imported key is made the default keys unless its name contains the string `legacy`.  Public keys are not imported.
 *
 * While dc_imex() returns immediately, the started job may take a while,
 * you can stop it using dc_stop_ongoing_process(). During execution of the job,
 * some events are sent out:
 *
 * - A number of #DC_EVENT_IMEX_PROGRESS events are sent and may be used to create
 *   a progress bar or stuff like that. Moreover, you'll be informed when the imex-job is done.
 *
 * - For each file written on export, the function sends #DC_EVENT_IMEX_FILE_WRITTEN
 *
 * Only one import-/export-progress can run at the same time.
 * To cancel an import-/export-progress, use dc_stop_ongoing_process().
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @param what One of the DC_IMEX_* constants.
 * @param param1 Meaning depends on the DC_IMEX_* constants. If this parameter is a directory, it should not end with
 *     a slash (otherwise you'll get double slashes when receiving #DC_EVENT_IMEX_FILE_WRITTEN). Set to NULL if not used.
 * @param param2 Meaning depends on the DC_IMEX_* constants. Set to NULL if not used.
 * @return None.
 */
void dc_imex(dc_context_t* context, int what, const char* param1, const char* param2)
{
	dc_param_t* param = dc_param_new();

	dc_param_set_int(param, DC_PARAM_CMD,      what);
	dc_param_set    (param, DC_PARAM_CMD_ARG,  param1);
	dc_param_set    (param, DC_PARAM_CMD_ARG2, param2);

	dc_job_kill_actions(context, DC_JOB_IMEX_IMAP, 0);
	dc_job_add(context, DC_JOB_IMEX_IMAP, 0, param->packed, 0); // results in a call to dc_job_do_DC_JOB_IMEX_IMAP()

	dc_param_unref(param);
}


void dc_job_do_DC_JOB_IMEX_IMAP(dc_context_t* context, dc_job_t* job)
{
	int   success = 0;
	int   ongoing_allocated_here = 0;
	int   what = 0;
	char* param1 = NULL;
	char* param2 = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || context->sql==NULL) {
		goto cleanup;
	}

	if (!dc_alloc_ongoing(context)) {
		goto cleanup;
	}
	ongoing_allocated_here = 1;

	what   = dc_param_get_int(job->param, DC_PARAM_CMD,      0);
	param1 = dc_param_get    (job->param, DC_PARAM_CMD_ARG,  NULL);
	param2 = dc_param_get    (job->param, DC_PARAM_CMD_ARG2, NULL);

	if (param1==NULL) {
		dc_log_error(context, 0, "No Import/export dir/file given.");
		goto cleanup;
	}

	dc_log_info(context, 0, "Import/export process started.");
	context->cb(context, DC_EVENT_IMEX_PROGRESS, 10, 0);

	if (!dc_sqlite3_is_open(context->sql)) {
		dc_log_error(context, 0, "Import/export: Database not opened.");
		goto cleanup;
	}

	if (what==DC_IMEX_EXPORT_SELF_KEYS || what==DC_IMEX_EXPORT_BACKUP) {
		/* before we export anything, make sure the private key exists */
		if (!dc_ensure_secret_key_exists(context)) {
			dc_log_error(context, 0, "Import/export: Cannot create private key or private key not available.");
			goto cleanup;
		}
		/* also make sure, the directory for exporting exists */
		dc_create_folder(param1, context);
	}

	switch (what)
	{
		case DC_IMEX_EXPORT_SELF_KEYS:
			if (!export_self_keys(context, param1)) {
				goto cleanup;
			}
			break;

		case DC_IMEX_IMPORT_SELF_KEYS:
			if (!import_self_keys(context, param1)) {
				goto cleanup;
			}
			break;

		case DC_IMEX_EXPORT_BACKUP:
			if (!export_backup(context, param1)) {
				goto cleanup;
			}
			break;

		case DC_IMEX_IMPORT_BACKUP:
			if (!import_backup(context, param1)) {
				goto cleanup;
			}
			break;

		default:
			goto cleanup;
	}

	dc_log_info(context, 0, "Import/export completed.");

	success = 1;

cleanup:
	free(param1);
	free(param2);

	if (ongoing_allocated_here) { dc_free_ongoing(context); }

	context->cb(context, DC_EVENT_IMEX_PROGRESS, success? 1000 : 0, 0);
}


/**
 * Check if there is a backup file.
 * May only be used on fresh installations (eg. dc_is_configured() returns 0).
 *
 * Example:
 *
 * ```
 * char dir[] = "/dir/to/search/backups/in";
 *
 * void ask_user_for_credentials()
 * {
 *     // - ask the user for email and password
 *     // - save them using dc_set_config()
 * }
 *
 * int ask_user_whether_to_import()
 * {
 *     // - inform the user that we've found a backup
 *     // - ask if he want to import it
 *     // - return 1 to import, 0 to skip
 *     return 1;
 * }
 *
 * if (!dc_is_configured(context))
 * {
 *     char* file = NULL;
 *     if ((file=dc_imex_has_backup(context, dir))!=NULL && ask_user_whether_to_import())
 *     {
 *         dc_imex(context, DC_IMEX_IMPORT_BACKUP, file, NULL);
 *         // connect
 *     }
 *     else
 *     {
 *         do {
 *             ask_user_for_credentials();
 *         }
 *         while (!configure_succeeded())
 *     }
 *     free(file);
 * }
 * ```
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @param dir_name Directory to search backups in.
 * @return String with the backup file, typically given to dc_imex(), returned strings must be free()'d.
 *     The function returns NULL if no backup was found.
 */
char* dc_imex_has_backup(dc_context_t* context, const char* dir_name)
{
	char*          ret = NULL;
	time_t         ret_backup_time = 0;
	DIR*           dir_handle = NULL;
	struct dirent* dir_entry = NULL;
	int            prefix_len = strlen(DC_BAK_PREFIX);
	int            suffix_len = strlen(DC_BAK_SUFFIX);
	char*          curr_pathNfilename = NULL;
	dc_sqlite3_t*  test_sql = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return NULL;
	}

	if ((dir_handle=opendir(dir_name))==NULL) {
		dc_log_info(context, 0, "Backup check: Cannot open directory \"%s\".", dir_name); /* this is not an error - eg. the directory may not exist or the user has not given us access to read data from the storage */
		goto cleanup;
	}

	while ((dir_entry=readdir(dir_handle))!=NULL) {
		const char* name = dir_entry->d_name; /* name without path; may also be `.` or `..` */
		int name_len = strlen(name);
		if (name_len > prefix_len && strncmp(name, DC_BAK_PREFIX, prefix_len)==0
		 && name_len > suffix_len && strncmp(&name[name_len-suffix_len-1], "." DC_BAK_SUFFIX, suffix_len)==0)
		{
			free(curr_pathNfilename);
			curr_pathNfilename = dc_mprintf("%s/%s", dir_name, name);

			dc_sqlite3_unref(test_sql);
			if ((test_sql=dc_sqlite3_new(context/*for logging only*/))!=NULL
			 && dc_sqlite3_open(test_sql, curr_pathNfilename, DC_OPEN_READONLY))
			{
				time_t curr_backup_time = dc_sqlite3_get_config_int(test_sql, "backup_time", 0); /* reading the backup time also checks if the database is readable and the table `config` exists */
				if (curr_backup_time > 0
				 && curr_backup_time > ret_backup_time/*use the newest if there are multiple backup*/)
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
	if (dir_handle) { closedir(dir_handle); }
	free(curr_pathNfilename);
	dc_sqlite3_unref(test_sql);
	return ret;
}


/**
 * Check if the user is authorized by the given password in some way.
 * This is to promt for the password eg. before exporting keys/backup.
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @param test_pw Password to check.
 * @return 1=user is authorized, 0=user is not authorized.
 */
int dc_check_password(dc_context_t* context, const char* test_pw)
{
	/* Check if the given password matches the configured mail_pw.
	This is to prompt the user before starting eg. an export; this is mainly to avoid doing people bad thinkgs if they have short access to the device.
	When we start supporting OAuth some day, we should think this over, maybe force the user to re-authenticate himself with the Android password. */
	dc_loginparam_t* loginparam = dc_loginparam_new();
	int              success = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	dc_loginparam_read(loginparam, context->sql, "configured_");

	if ((loginparam->mail_pw==NULL || loginparam->mail_pw[0]==0) && (test_pw==NULL || test_pw[0]==0)) {
		/* both empty or unset */
		success = 1;
	}
	else if (loginparam->mail_pw==NULL || test_pw==NULL) {
		/* one set, the other not */
		success = 0;
	}
	else if (strcmp(loginparam->mail_pw, test_pw)==0) {
		/* string-compared passwords are equal */
		success = 1;
	}

cleanup:
	dc_loginparam_unref(loginparam);
	return success;
}


/**
 * @}
 */
