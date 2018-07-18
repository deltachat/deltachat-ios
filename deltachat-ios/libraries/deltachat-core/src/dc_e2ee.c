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


#include "dc_context.h"
#include "dc_pgp.h"
#include "dc_aheader.h"
#include "dc_keyring.h"
#include "dc_mimeparser.h"
#include "dc_apeerstate.h"


/*******************************************************************************
 * Tools
 ******************************************************************************/


static struct mailmime* new_data_part(void* data, size_t data_bytes, char* default_content_type, int default_encoding)
{
  //char basename_buf[PATH_MAX];
  struct mailmime_mechanism * encoding;
  struct mailmime_content * content;
  struct mailmime * mime;
  //int r;
  //char * dup_filename;
  struct mailmime_fields * mime_fields;
  int encoding_type;
  char * content_type_str;
  int do_encoding;

  /*if (filename!=NULL) {
    strncpy(basename_buf, filename, PATH_MAX);
    libetpan_basename(basename_buf);
  }*/

  encoding = NULL;

  /* default content-type */
  if (default_content_type==NULL)
    content_type_str = "application/octet-stream";
  else
    content_type_str = default_content_type;

  content = mailmime_content_new_with_str(content_type_str);
  if (content==NULL) {
    goto free_content;
  }

  do_encoding = 1;
  if (content->ct_type->tp_type==MAILMIME_TYPE_COMPOSITE_TYPE) {
    struct mailmime_composite_type * composite;

    composite = content->ct_type->tp_data.tp_composite_type;

    switch (composite->ct_type) {
    case MAILMIME_COMPOSITE_TYPE_MESSAGE:
      if (strcasecmp(content->ct_subtype, "rfc822")==0)
        do_encoding = 0;
      break;

    case MAILMIME_COMPOSITE_TYPE_MULTIPART:
      do_encoding = 0;
      break;
    }
  }

  if (do_encoding) {
    if (default_encoding==-1)
      encoding_type = MAILMIME_MECHANISM_BASE64;
    else
      encoding_type = default_encoding;

    /* default Content-Transfer-Encoding */
    encoding = mailmime_mechanism_new(encoding_type, NULL);
    if (encoding==NULL) {
      goto free_content;
    }
  }

  mime_fields = mailmime_fields_new_with_data(encoding,
      NULL, NULL, NULL, NULL);
  if (mime_fields==NULL) {
    goto free_content;
  }

  mime = mailmime_new_empty(content, mime_fields);
  if (mime==NULL) {
    goto free_mime_fields;
  }

  /*if ((filename!=NULL) && (mime->mm_type==MAILMIME_SINGLE)) {
    // duplicates the file so that the file can be deleted when
    // the MIME part is done
    dup_filename = dup_file(privacy, filename);
    if (dup_filename==NULL) {
      goto free_mime;
    }

    r = mailmime_set_body_file(mime, dup_filename);
    if (r!=MAILIMF_NO_ERROR) {
      free(dup_filename);
      goto free_mime;
    }
  }*/
  if (data!=NULL && data_bytes>0 && mime->mm_type==MAILMIME_SINGLE) {
	mailmime_set_body_text(mime, data, data_bytes);
  }

  return mime;

// free_mime:
  //mailmime_free(mime);
  goto err;
 free_mime_fields:
  mailmime_fields_free(mime_fields);
  mailmime_content_free(content);
  goto err;
 free_content:
  if (encoding!=NULL)
    mailmime_mechanism_free(encoding);
  if (content!=NULL)
    mailmime_content_free(content);
 err:
  return NULL;
}


/**
 * Check if a MIME structure contains a multipart/report part.
 *
 * As reports are often unencrypted, we do not reset the Autocrypt header in
 * this case.
 *
 * However, Delta Chat itself has no problem with encrypted multipart/report
 * parts and MUAs should be encouraged to encrpyt multipart/reports as well so
 * that we could use the normal Autocrypt processing.
 *
 * @private
 * @param mime The mime struture to check
 * @return 1=multipart/report found in MIME, 0=no multipart/report found
 */
static int contains_report(struct mailmime* mime)
{
	if (mime->mm_type==MAILMIME_MULTIPLE)
	{
		if (mime->mm_content_type->ct_type->tp_type==MAILMIME_TYPE_COMPOSITE_TYPE
		 && mime->mm_content_type->ct_type->tp_data.tp_composite_type->ct_type==MAILMIME_COMPOSITE_TYPE_MULTIPART
		 && strcmp(mime->mm_content_type->ct_subtype, "report")==0) {
			return 1;
		}

		clistiter* cur;
		for (cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list); cur!=NULL; cur=clist_next(cur)) {
			if (contains_report((struct mailmime*)clist_content(cur))) {
				return 1;
			}
		}
	}
	else if (mime->mm_type==MAILMIME_MESSAGE)
	{
		if (contains_report(mime->mm_data.mm_message.mm_msg_mime)) {
			return 1;
		}
	}

	return 0;
}

/*******************************************************************************
 * Generate Keypairs
 ******************************************************************************/


static int load_or_generate_self_public_key(dc_context_t* context, dc_key_t* public_key, const char* self_addr,
                                              struct mailmime* random_data_mime /*for an extra-seed of the random generator. For speed reasons, only give _available_ pointers here, do not create any data - in very most cases, the key is not generated!*/)
{
	static int s_in_key_creation = 0; /* avoid double creation (we unlock the database during creation) */
	int        key_created = 0;
	int        success = 0, key_creation_here = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || public_key==NULL) {
		goto cleanup;
	}

	if (!dc_key_load_self_public(public_key, self_addr, context->sql))
	{
		/* create the keypair - this may take a moment, however, as this is in a thread, this is no big deal */
		if (s_in_key_creation) { goto cleanup; }
		key_creation_here = 1;
		s_in_key_creation = 1;

		/* seed the random generator */
		{
			uintptr_t seed[4];
			seed[0] = (uintptr_t)time(NULL);     /* time */
			seed[1] = (uintptr_t)seed;           /* stack */
			seed[2] = (uintptr_t)public_key;     /* heap */
			seed[3] = (uintptr_t)pthread_self(); /* thread ID */
			dc_pgp_rand_seed(context, seed, sizeof(seed));

			if (random_data_mime) {
				MMAPString* random_data_mmap = NULL;
				int col = 0;
				if ((random_data_mmap=mmap_string_new(""))==NULL) {
					goto cleanup;
				}
				mailmime_write_mem(random_data_mmap, &col, random_data_mime);
				dc_pgp_rand_seed(context, random_data_mmap->str, random_data_mmap->len);
				mmap_string_free(random_data_mmap);
			}
		}

		{
			dc_key_t* private_key = dc_key_new();

			dc_log_info(context, 0, "Generating keypair ...");

				/* The public key must contain the following:
				- a signing-capable primary key Kp
				- a user id
				- a self signature
				- an encryption-capable subkey Ke
				- a binding signature over Ke by Kp
				(see https://autocrypt.readthedocs.io/en/latest/level0.html#type-p-openpgp-based-key-data)*/
				key_created = dc_pgp_create_keypair(context, self_addr, public_key, private_key);

			if (!key_created) {
				dc_log_warning(context, 0, "Cannot create keypair.");
				goto cleanup;
			}

			if (!dc_pgp_is_valid_key(context, public_key)
			 || !dc_pgp_is_valid_key(context, private_key)) {
				dc_log_warning(context, 0, "Generated keys are not valid.");
				goto cleanup;
			}

			if (!dc_key_save_self_keypair(public_key, private_key, self_addr, 1/*set default*/, context->sql)) {
				dc_log_warning(context, 0, "Cannot save keypair.");
				goto cleanup;
			}

			dc_log_info(context, 0, "Keypair generated.");

			dc_key_unref(private_key);
		}
	}

	success = 1;

cleanup:
	if (key_creation_here) { s_in_key_creation = 0; }
	return success;
}


int dc_ensure_secret_key_exists(dc_context_t* context)
{
	/* normally, the key is generated as soon as the first mail is send
	(this is to gain some extra-random-seed by the message content and the timespan between program start and message sending) */
	int       success = 0;
	dc_key_t* public_key = dc_key_new();
	char*     self_addr = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || public_key==NULL) {
		goto cleanup;
	}

	if ((self_addr=dc_sqlite3_get_config(context->sql, "configured_addr", NULL))==NULL) {
		dc_log_warning(context, 0, "Cannot ensure secret key if context is not configured.");
		goto cleanup;
	}

	if (!load_or_generate_self_public_key(context, public_key, self_addr, NULL/*no random text data for seeding available*/)) {
		goto cleanup;
	}

	success = 1;

cleanup:
	dc_key_unref(public_key);
	free(self_addr);
	return success;
}


/*******************************************************************************
 * Encrypt
 ******************************************************************************/


void dc_e2ee_encrypt(dc_context_t* context, const clist* recipients_addr,
                    int force_unencrypted,
                    int e2ee_guaranteed, /*set if e2ee was possible on sending time; we should not degrade to transport*/
                    int min_verified,
                    struct mailmime* in_out_message, dc_e2ee_helper_t* helper)
{
	int                     col = 0;
	int                     do_encrypt = 0;
	dc_aheader_t*           autocryptheader = dc_aheader_new();
	struct mailimf_fields*  imffields_unprotected = NULL; /*just a pointer into mailmime structure, must not be freed*/
	dc_keyring_t*           keyring = dc_keyring_new();
	dc_key_t*               sign_key = dc_key_new();
	MMAPString*             plain = mmap_string_new("");
	char*                   ctext = NULL;
	size_t                  ctext_bytes = 0;
	dc_array_t*             peerstates = dc_array_new(NULL, 10);

	if (helper) { memset(helper, 0, sizeof(dc_e2ee_helper_t)); }

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || recipients_addr==NULL || in_out_message==NULL
	 || in_out_message->mm_parent /* libEtPan's pgp_encrypt_mime() takes the parent as the new root. We just expect the root as being given to this function. */
	 || autocryptheader==NULL || keyring==NULL || sign_key==NULL || plain==NULL || helper==NULL) {
		goto cleanup;
	}

		/* init autocrypt header from db */
		autocryptheader->prefer_encrypt = DC_PE_NOPREFERENCE;
		if (context->e2ee_enabled) {
			autocryptheader->prefer_encrypt = DC_PE_MUTUAL;
		}

		autocryptheader->addr = dc_sqlite3_get_config(context->sql, "configured_addr", NULL);
		if (autocryptheader->addr==NULL) {
			goto cleanup;
		}

		if (!load_or_generate_self_public_key(context, autocryptheader->public_key, autocryptheader->addr, in_out_message/*only for random-seed*/)) {
			goto cleanup;
		}

		/* load peerstate information etc. */
		if (autocryptheader->prefer_encrypt==DC_PE_MUTUAL || e2ee_guaranteed)
		{
			do_encrypt = 1;
			clistiter*      iter1;
			for (iter1 = clist_begin(recipients_addr); iter1!=NULL ; iter1=clist_next(iter1)) {
				const char* recipient_addr = clist_content(iter1);
				dc_apeerstate_t* peerstate = dc_apeerstate_new(context);
				dc_key_t* key_to_use = NULL;
				if (strcasecmp(recipient_addr, autocryptheader->addr)==0)
				{
					; // encrypt to SELF, this key is added below
				}
				else if (dc_apeerstate_load_by_addr(peerstate, context->sql, recipient_addr)
				      && (key_to_use=dc_apeerstate_peek_key(peerstate, min_verified))!=NULL
				      && (peerstate->prefer_encrypt==DC_PE_MUTUAL || e2ee_guaranteed))
				{
					dc_keyring_add(keyring, key_to_use); /* we always add all recipients (even on IMAP upload) as otherwise forwarding may fail */
					dc_array_add_ptr(peerstates, peerstate);
				}
				else
				{
					dc_apeerstate_unref(peerstate);
					do_encrypt = 0;
					break; /* if we cannot encrypt to a single recipient, we cannot encrypt the message at all */
				}
			}
		}

		if (do_encrypt) {
			dc_keyring_add(keyring, autocryptheader->public_key); /* we always add ourself as otherwise forwarded messages are not readable */
			if (!dc_key_load_self_private(sign_key, autocryptheader->addr, context->sql)) {
				do_encrypt = 0;
			}
		}

		if (force_unencrypted) {
			do_encrypt = 0;
		}

	if ((imffields_unprotected=mailmime_find_mailimf_fields(in_out_message))==NULL) {
		goto cleanup;
	}

	/* encrypt message, if possible */
	if (do_encrypt)
	{
		/* prepare part to encrypt */
		mailprivacy_prepare_mime(in_out_message); /* encode quoted printable all text parts */

		struct mailmime* part_to_encrypt = in_out_message->mm_data.mm_message.mm_msg_mime;
		part_to_encrypt->mm_parent = NULL;
		struct mailimf_fields* imffields_encrypted = mailimf_fields_new_empty();
		struct mailmime* message_to_encrypt = mailmime_new(MAILMIME_MESSAGE, NULL, 0, mailmime_fields_new_empty(), /* mailmime_new_message_data() calls mailmime_fields_new_with_version() which would add the unwanted MIME-Version:-header */
			mailmime_get_content_message(), NULL, NULL, NULL, NULL, imffields_encrypted, part_to_encrypt);

		/* gossip keys */
		int iCnt = dc_array_get_cnt(peerstates);
		if (iCnt > 1) {
			for (int i = 0; i < iCnt; i++) {
				char* p = dc_apeerstate_render_gossip_header((dc_apeerstate_t*)dc_array_get_ptr(peerstates, i), min_verified);
				if (p) {
					mailimf_fields_add(imffields_encrypted, mailimf_field_new_custom(strdup("Autocrypt-Gossip"), p/*takes ownership*/));
				}
			}
		}

		/* memoryhole headers */
		clistiter* cur = clist_begin(imffields_unprotected->fld_list);
		while (cur!=NULL) {
			int move_to_encrypted = 0;

			struct mailimf_field* field = (struct mailimf_field*)clist_content(cur);
			if (field) {
				if (field->fld_type==MAILIMF_FIELD_SUBJECT) {
					move_to_encrypted = 1;
				}
				else if (field->fld_type==MAILIMF_FIELD_OPTIONAL_FIELD) {
					struct mailimf_optional_field* opt_field = field->fld_data.fld_optional_field;
					if (opt_field && opt_field->fld_name) {
						if ( strncmp(opt_field->fld_name, "Secure-Join", 11)==0
						 || (strncmp(opt_field->fld_name, "Chat-", 5)==0 && strcmp(opt_field->fld_name, "Chat-Version")!=0)/*Chat-Version may be used for filtering and is not added to the encrypted part, however, this is subject to change*/) {
							move_to_encrypted = 1;
						}
					}
				}
			}

			if (move_to_encrypted) {
				mailimf_fields_add(imffields_encrypted, field);
				cur = clist_delete(imffields_unprotected->fld_list, cur);
			}
			else {
				cur = clist_next(cur);
			}
		}

		char* e = dc_stock_str(context, DC_STR_ENCRYPTEDMSG); char* subject_str = dc_mprintf(DC_CHAT_PREFIX " %s", e); free(e);
		struct mailimf_subject* subject = mailimf_subject_new(dc_encode_header_words(subject_str));
		mailimf_fields_add(imffields_unprotected, mailimf_field_new(MAILIMF_FIELD_SUBJECT, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, subject, NULL, NULL, NULL));
		free(subject_str);

		clist_append(part_to_encrypt->mm_content_type->ct_parameters, mailmime_param_new_with_data("protected-headers", "v1"));

		/* convert part to encrypt to plain text */
		mailmime_write_mem(plain, &col, message_to_encrypt);
		if (plain->str==NULL || plain->len<=0) {
			goto cleanup;
		}
		//char* t1=dc_null_terminate(plain->str,plain->len);printf("PLAIN:\n%s\n",t1);free(t1); // DEBUG OUTPUT

		if (!dc_pgp_pk_encrypt(context, plain->str, plain->len, keyring, sign_key, 1/*use_armor*/, (void**)&ctext, &ctext_bytes)) {
			goto cleanup;
		}
		helper->cdata_to_free = ctext;
		//char* t2=dc_null_terminate(ctext,ctext_bytes);printf("ENCRYPTED:\n%s\n",t2);free(t2); // DEBUG OUTPUT

		/* create MIME-structure that will contain the encrypted text */
		struct mailmime* encrypted_part = new_data_part(NULL, 0, "multipart/encrypted", -1);

		struct mailmime_content* content = encrypted_part->mm_content_type;
		clist_append(content->ct_parameters, mailmime_param_new_with_data("protocol", "application/pgp-encrypted"));

		static char version_content[] = "Version: 1\r\n";
		struct mailmime* version_mime = new_data_part(version_content, strlen(version_content), "application/pgp-encrypted", MAILMIME_MECHANISM_7BIT);
		mailmime_smart_add_part(encrypted_part, version_mime);

		struct mailmime* ctext_part = new_data_part(ctext, ctext_bytes, "application/octet-stream", MAILMIME_MECHANISM_7BIT);
		mailmime_smart_add_part(encrypted_part, ctext_part);

		/* replace the original MIME-structure by the encrypted MIME-structure */
		in_out_message->mm_data.mm_message.mm_msg_mime = encrypted_part;
		encrypted_part->mm_parent = in_out_message;
		mailmime_free(message_to_encrypt);
		//MMAPString* t3=mmap_string_new("");mailmime_write_mem(t3,&col,in_out_message);char* t4=dc_null_terminate(t3->str,t3->len); printf("ENCRYPTED+MIME_ENCODED:\n%s\n",t4);free(t4);mmap_string_free(t3); // DEBUG OUTPUT

		helper->encryption_successfull = 1;
	}

	char* p = dc_aheader_render(autocryptheader);
	if (p==NULL) {
		goto cleanup;
	}
	mailimf_fields_add(imffields_unprotected, mailimf_field_new_custom(strdup("Autocrypt"), p/*takes ownership of pointer*/));

cleanup:
	dc_aheader_unref(autocryptheader);
	dc_keyring_unref(keyring);
	dc_key_unref(sign_key);
	if (plain) { mmap_string_free(plain); }

	for (int i=dc_array_get_cnt(peerstates)-1; i>=0; i--) { dc_apeerstate_unref((dc_apeerstate_t*)dc_array_get_ptr(peerstates, i)); }
	dc_array_unref(peerstates);
}


void dc_e2ee_thanks(dc_e2ee_helper_t* helper)
{
	if (helper==NULL) {
		return;
	}

	free(helper->cdata_to_free);
	helper->cdata_to_free = NULL;

	if (helper->gossipped_addr)
	{
		dc_hash_clear(helper->gossipped_addr);
		free(helper->gossipped_addr);
		helper->gossipped_addr = NULL;
	}

	if (helper->signatures)
	{
		dc_hash_clear(helper->signatures);
		free(helper->signatures);
		helper->signatures = NULL;
	}
}


/*******************************************************************************
 * Decrypt
 ******************************************************************************/


static int has_decrypted_pgp_armor(const char* str__, int str_bytes)
{
	const unsigned char* str_end = (const unsigned char*)str__+str_bytes;
	const unsigned char* p=(const unsigned char*)str__;
	while (p < str_end) {
		if (*p > ' ') {
			break;
		}
		p++;
		str_bytes--;
	}
	if (str_bytes>27 && strncmp((const char*)p, "-----BEGIN PGP MESSAGE-----", 27)==0) {
		return 1;
	}
	return 0;
}


static int decrypt_part(dc_context_t*       context,
                        struct mailmime*    mime,
                        const dc_keyring_t* private_keyring,
                        const dc_keyring_t* public_keyring_for_validate, /*may be NULL*/
                        dc_hash_t*          ret_valid_signatures,
                        struct mailmime**   ret_decrypted_mime)
{
	struct mailmime_data*        mime_data = NULL;
	int                          mime_transfer_encoding = MAILMIME_MECHANISM_BINARY;
	char*                        transfer_decoding_buffer = NULL; /* mmap_string_unref()'d if set */
	const char*                  decoded_data = NULL; /* must not be free()'d */
	size_t                       decoded_data_bytes = 0;
	void*                        plain_buf = NULL;
	size_t                       plain_bytes = 0;
	int                          sth_decrypted = 0;

	*ret_decrypted_mime = NULL;

	/* get data pointer from `mime` */
	mime_data = mime->mm_data.mm_single;
	if (mime_data->dt_type!=MAILMIME_DATA_TEXT   /* MAILMIME_DATA_FILE indicates, the data is in a file; AFAIK this is not used on parsing */
	 || mime_data->dt_data.dt_text.dt_data==NULL
	 || mime_data->dt_data.dt_text.dt_length <= 0) {
		goto cleanup;
	}

	/* check headers in `mime` */
	if (mime->mm_mime_fields!=NULL) {
		clistiter* cur;
		for (cur = clist_begin(mime->mm_mime_fields->fld_list); cur!=NULL; cur = clist_next(cur)) {
			struct mailmime_field* field = (struct mailmime_field*)clist_content(cur);
			if (field) {
				if (field->fld_type==MAILMIME_FIELD_TRANSFER_ENCODING && field->fld_data.fld_encoding) {
					mime_transfer_encoding = field->fld_data.fld_encoding->enc_type;
				}
			}
		}
	}

	/* regard `Content-Transfer-Encoding:` */
	if (mime_transfer_encoding==MAILMIME_MECHANISM_7BIT
	 || mime_transfer_encoding==MAILMIME_MECHANISM_8BIT
	 || mime_transfer_encoding==MAILMIME_MECHANISM_BINARY)
	{
		decoded_data       = mime_data->dt_data.dt_text.dt_data;
		decoded_data_bytes = mime_data->dt_data.dt_text.dt_length;
		if (decoded_data==NULL || decoded_data_bytes <= 0) {
			goto cleanup; /* no error - but no data */
		}
	}
	else
	{
		int r;
		size_t current_index = 0;
		r = mailmime_part_parse(mime_data->dt_data.dt_text.dt_data, mime_data->dt_data.dt_text.dt_length,
			&current_index, mime_transfer_encoding,
			&transfer_decoding_buffer, &decoded_data_bytes);
		if (r!=MAILIMF_NO_ERROR || transfer_decoding_buffer==NULL || decoded_data_bytes <= 0) {
			goto cleanup;
		}
		decoded_data = transfer_decoding_buffer;
	}

	/* encrypted, decoded data in decoded_data now ... */
	if (!has_decrypted_pgp_armor(decoded_data, decoded_data_bytes)) {
		goto cleanup;
	}

	dc_hash_t* add_signatures = dc_hash_cnt(ret_valid_signatures)<=0?
		ret_valid_signatures : NULL; /*if we already have fingerprints, do not add more; this ensures, only the fingerprints from the outer-most part are collected */

	if (!dc_pgp_pk_decrypt(context, decoded_data, decoded_data_bytes, private_keyring, public_keyring_for_validate, 1, &plain_buf, &plain_bytes, add_signatures)
	 || plain_buf==NULL || plain_bytes<=0) {
		goto cleanup;
	}

	//{char* t1=dc_null_terminate(plain_buf,plain_bytes);printf("\n**********\n%s\n**********\n",t1);free(t1);}

	{
		size_t index = 0;
		struct mailmime* decrypted_mime = NULL;
		if (mailmime_parse(plain_buf, plain_bytes, &index, &decrypted_mime)!=MAIL_NO_ERROR
		 || decrypted_mime==NULL) {
			if(decrypted_mime) {mailmime_free(decrypted_mime);}
			goto cleanup;
		}

		//mailmime_print(decrypted_mime);

		*ret_decrypted_mime = decrypted_mime;
		sth_decrypted = 1;
	}

	//mailmime_substitute(mime, new_mime);
	//s. mailprivacy_gnupg.c::pgp_decrypt()

cleanup:
	if (transfer_decoding_buffer) {
		mmap_string_unref(transfer_decoding_buffer);
	}
	return sth_decrypted;
}


static int decrypt_recursive(dc_context_t*           context,
                             struct mailmime*        mime,
                             const dc_keyring_t*     private_keyring,
                             const dc_keyring_t*     public_keyring_for_validate,
                             dc_hash_t*              ret_valid_signatures,
                             struct mailimf_fields** ret_gossip_headers,
                             int*                    ret_has_unencrypted_parts)
{
	struct mailmime_content* ct = NULL;
	clistiter*               cur = NULL;

	if (context==NULL || mime==NULL) {
		return 0;
	}

	if (mime->mm_type==MAILMIME_MULTIPLE)
	{
		ct = mime->mm_content_type;
		if (ct && ct->ct_subtype && strcmp(ct->ct_subtype, "encrypted")==0) {
			/* decrypt "multipart/encrypted" -- child parts are eg. "application/pgp-encrypted" (uninteresting, version only),
			"application/octet-stream" (the interesting data part) and optional, unencrypted help files */
			for (cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list); cur!=NULL; cur=clist_next(cur)) {
				struct mailmime* decrypted_mime = NULL;
				if (decrypt_part(context, (struct mailmime*)clist_content(cur), private_keyring, public_keyring_for_validate, ret_valid_signatures, &decrypted_mime))
				{
					/* remember the header containing potentially Autocrypt-Gossip */
					if (*ret_gossip_headers==NULL /* use the outermost decrypted part */
					 && dc_hash_cnt(ret_valid_signatures) > 0 /* do not trust the gossipped keys when the message cannot be validated eg. due to a bad signature */)
					{
						size_t dummy = 0;
						struct mailimf_fields* test = NULL;
						if (mailimf_envelope_and_optional_fields_parse(decrypted_mime->mm_mime_start, decrypted_mime->mm_length, &dummy, &test)==MAILIMF_NO_ERROR
						 && test) {
							*ret_gossip_headers = test;
						}
					}

					/* replace encrypted mime structure by decrypted one */
					mailmime_substitute(mime, decrypted_mime);
					mailmime_free(mime);
					return 1; /* sth. decrypted, start over from root searching for encrypted parts */
				}
			}
			*ret_has_unencrypted_parts = 1; // there is a part that could not be decrypted
		}
		else {
			for (cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list); cur!=NULL; cur=clist_next(cur)) {
				if (decrypt_recursive(context, (struct mailmime*)clist_content(cur), private_keyring, public_keyring_for_validate, ret_valid_signatures, ret_gossip_headers, ret_has_unencrypted_parts)) {
					return 1; /* sth. decrypted, start over from root searching for encrypted parts */
				}
			}
		}
	}
	else if (mime->mm_type==MAILMIME_MESSAGE)
	{
		if (decrypt_recursive(context, mime->mm_data.mm_message.mm_msg_mime, private_keyring, public_keyring_for_validate, ret_valid_signatures, ret_gossip_headers, ret_has_unencrypted_parts)) {
			return 1; /* sth. decrypted, start over from root searching for encrypted parts */
		}
	}
	else
	{
		*ret_has_unencrypted_parts = 1; // there is a part that was not encrypted at all. in combination with otherwise encrypted mails, this is a problem.
	}

	return 0;
}


static dc_hash_t* update_gossip_peerstates(dc_context_t* context, time_t message_time, struct mailimf_fields* imffields, const struct mailimf_fields* gossip_headers)
{
	clistiter*  cur1 = NULL;
	dc_hash_t*  recipients = NULL;
	dc_hash_t*  gossipped_addr = NULL;

	for (cur1 = clist_begin(gossip_headers->fld_list); cur1!=NULL ; cur1=clist_next(cur1))
	{
		struct mailimf_field* field = (struct mailimf_field*)clist_content(cur1);
		if (field->fld_type==MAILIMF_FIELD_OPTIONAL_FIELD)
		{
			const struct mailimf_optional_field* optional_field = field->fld_data.fld_optional_field;
			if (optional_field && optional_field->fld_name && strcasecmp(optional_field->fld_name, "Autocrypt-Gossip")==0)
			{
				dc_aheader_t* gossip_header = dc_aheader_new();
				if (dc_aheader_set_from_string(gossip_header, optional_field->fld_value)
				 && dc_pgp_is_valid_key(context, gossip_header->public_key))
				{
					/* found an Autocrypt-Gossip entry, create recipents list and check if addr matches */
					if (recipients==NULL) {
						recipients = mailimf_get_recipients(imffields);
					}

					if (dc_hash_find(recipients, gossip_header->addr, strlen(gossip_header->addr)))
					{
						/* valid recipient: update peerstate */
						dc_apeerstate_t* peerstate = dc_apeerstate_new(context);
						if (!dc_apeerstate_load_by_addr(peerstate, context->sql, gossip_header->addr)) {
							dc_apeerstate_init_from_gossip(peerstate, gossip_header, message_time);
							dc_apeerstate_save_to_db(peerstate, context->sql, 1/*create*/);
						}
						else {
							dc_apeerstate_apply_gossip(peerstate, gossip_header, message_time);
							dc_apeerstate_save_to_db(peerstate, context->sql, 0/*do not create*/);
						}

						if (peerstate->degrade_event) {
							dc_handle_degrade_event(context, peerstate);
						}

						dc_apeerstate_unref(peerstate);

						// collect all gossipped addresses; we need them later to mark them as being
						// verified when used in a verified group by a verified sender
						if (gossipped_addr==NULL) {
							gossipped_addr = malloc(sizeof(dc_hash_t));
							dc_hash_init(gossipped_addr, DC_HASH_STRING, 1/*copy key*/);
						}
						dc_hash_insert(gossipped_addr, gossip_header->addr, strlen(gossip_header->addr), (void*)1);
					}
					else
					{
						dc_log_info(context, 0, "Ignoring gossipped \"%s\" as the address is not in To/Cc list.", gossip_header->addr);
					}
				}
				dc_aheader_unref(gossip_header);
			}
		}
	}

	if (recipients) {
		dc_hash_clear(recipients);
		free(recipients);
	}

	return gossipped_addr;
}


void dc_e2ee_decrypt(dc_context_t* context, struct mailmime* in_out_message,
                           dc_e2ee_helper_t* helper)
{
	/* return values: 0=nothing to decrypt/cannot decrypt, 1=sth. decrypted
	(to detect parts that could not be decrypted, simply look for left "multipart/encrypted" MIME types */
	struct mailimf_fields* imffields = mailmime_find_mailimf_fields(in_out_message); /*just a pointer into mailmime structure, must not be freed*/
	dc_aheader_t*          autocryptheader = NULL;
	time_t                 message_time = 0;
	dc_apeerstate_t*       peerstate = dc_apeerstate_new(context);
	char*                  from = NULL;
	char*                  self_addr = NULL;
	dc_keyring_t*          private_keyring = dc_keyring_new();
	dc_keyring_t*          public_keyring_for_validate = dc_keyring_new();
	struct mailimf_fields* gossip_headers = NULL;

	if (helper) { memset(helper, 0, sizeof(dc_e2ee_helper_t)); }

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || in_out_message==NULL
	 || helper==NULL || imffields==NULL) {
		goto cleanup;
	}

	/* Autocrypt preparations:
	- Set message_time and from (both may be unset)
	- Get the autocrypt header, if any.
	- Do not abort on errors - we should try at last the decyption below */
	if (imffields)
	{
		struct mailimf_field* field = mailimf_find_field(imffields, MAILIMF_FIELD_FROM);
		if (field && field->fld_data.fld_from) {
			from = mailimf_find_first_addr(field->fld_data.fld_from->frm_mb_list);
		}

		field = mailimf_find_field(imffields, MAILIMF_FIELD_ORIG_DATE);
		if (field && field->fld_data.fld_orig_date) {
			struct mailimf_orig_date* orig_date = field->fld_data.fld_orig_date;
			if (orig_date) {
				message_time = dc_timestamp_from_date(orig_date->dt_date_time); /* is not yet checked against bad times! */
				if (message_time!=DC_INVALID_TIMESTAMP && message_time > time(NULL)) {
					message_time = time(NULL);
				}
			}
		}
	}

	autocryptheader = dc_aheader_new_from_imffields(from, imffields);
	if (autocryptheader) {
		if (!dc_pgp_is_valid_key(context, autocryptheader->public_key)) {
			dc_aheader_unref(autocryptheader);
			autocryptheader = NULL;
		}
	}

	/* modify the peerstate (eg. if there is a peer but not autocrypt header, stop encryption) */

	/* apply Autocrypt:-header */
	if (message_time > 0
	 && from)
	{
		if (dc_apeerstate_load_by_addr(peerstate, context->sql, from)) {
			if (autocryptheader) {
				dc_apeerstate_apply_header(peerstate, autocryptheader, message_time);
				dc_apeerstate_save_to_db(peerstate, context->sql, 0/*no not create*/);
			}
			else {
				if (message_time > peerstate->last_seen_autocrypt
				 && !contains_report(in_out_message) /*reports are ususally not encrpyted; do not degrade decryption then*/){
					dc_apeerstate_degrade_encryption(peerstate, message_time);
					dc_apeerstate_save_to_db(peerstate, context->sql, 0/*no not create*/);
				}
			}
		}
		else if (autocryptheader) {
			dc_apeerstate_init_from_header(peerstate, autocryptheader, message_time);
			dc_apeerstate_save_to_db(peerstate, context->sql, 1/*create*/);
		}
	}

	/* load private key for decryption */
	if ((self_addr=dc_sqlite3_get_config(context->sql, "configured_addr", NULL))==NULL) {
		goto cleanup;
	}

	if (!dc_keyring_load_self_private_for_decrypting(private_keyring, self_addr, context->sql)) {
		goto cleanup;
	}

	/* if not yet done, load peer with public key for verification (should be last as the peer may be modified above) */
	if (peerstate->last_seen==0) {
		dc_apeerstate_load_by_addr(peerstate, context->sql, from);
	}

	if (peerstate->degrade_event) {
		dc_handle_degrade_event(context, peerstate);
	}

	// offer both, gossip and public, for signature validation.
	// the caller may check the signature fingerprints as needed later.
	dc_keyring_add(public_keyring_for_validate, peerstate->gossip_key);
	dc_keyring_add(public_keyring_for_validate, peerstate->public_key);

	/* finally, decrypt.  If sth. was decrypted, decrypt_recursive() returns "true" and we start over to decrypt maybe just added parts. */
	helper->signatures = malloc(sizeof(dc_hash_t));
	dc_hash_init(helper->signatures, DC_HASH_STRING, 1/*copy key*/);

	int iterations = 0;
	while (iterations < 10) {
		int has_unencrypted_parts = 0;
		if (!decrypt_recursive(context, in_out_message, private_keyring,
		        public_keyring_for_validate,
		        helper->signatures, &gossip_headers, &has_unencrypted_parts)) {
			break;
		}

		// if we're here, sth. was encrypted. if we're on top-level, and there are no
		// additional unencrypted parts in the message the encryption was fine
		// (signature is handled separately and returned as `signatures`)
		if (iterations==0
		 && !has_unencrypted_parts) {
			helper->encrypted = 1;
		}

		iterations++;
	}

	/* check for Autocrypt-Gossip */
	if (gossip_headers) {
		helper->gossipped_addr = update_gossip_peerstates(context, message_time, imffields, gossip_headers);
	}

	//mailmime_print(in_out_message);

cleanup:
	if (gossip_headers) { mailimf_fields_free(gossip_headers); }
	dc_aheader_unref(autocryptheader);
	dc_apeerstate_unref(peerstate);
	dc_keyring_unref(private_keyring);
	dc_keyring_unref(public_keyring_for_validate);
	free(from);
	free(self_addr);
}

