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
#include "mrpgp.h"
#include "mrapeerstate.h"
#include "mraheader.h"
#include "mrkeyring.h"
#include "mrmimeparser.h"


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

  /*if (filename != NULL) {
    strncpy(basename_buf, filename, PATH_MAX);
    libetpan_basename(basename_buf);
  }*/

  encoding = NULL;

  /* default content-type */
  if (default_content_type == NULL)
    content_type_str = "application/octet-stream";
  else
    content_type_str = default_content_type;

  content = mailmime_content_new_with_str(content_type_str);
  if (content == NULL) {
    goto free_content;
  }

  do_encoding = 1;
  if (content->ct_type->tp_type == MAILMIME_TYPE_COMPOSITE_TYPE) {
    struct mailmime_composite_type * composite;

    composite = content->ct_type->tp_data.tp_composite_type;

    switch (composite->ct_type) {
    case MAILMIME_COMPOSITE_TYPE_MESSAGE:
      if (strcasecmp(content->ct_subtype, "rfc822") == 0)
        do_encoding = 0;
      break;

    case MAILMIME_COMPOSITE_TYPE_MULTIPART:
      do_encoding = 0;
      break;
    }
  }

  if (do_encoding) {
    if (default_encoding == -1)
      encoding_type = MAILMIME_MECHANISM_BASE64;
    else
      encoding_type = default_encoding;

    /* default Content-Transfer-Encoding */
    encoding = mailmime_mechanism_new(encoding_type, NULL);
    if (encoding == NULL) {
      goto free_content;
    }
  }

  mime_fields = mailmime_fields_new_with_data(encoding,
      NULL, NULL, NULL, NULL);
  if (mime_fields == NULL) {
    goto free_content;
  }

  mime = mailmime_new_empty(content, mime_fields);
  if (mime == NULL) {
    goto free_mime_fields;
  }

  /*if ((filename != NULL) && (mime->mm_type == MAILMIME_SINGLE)) {
    // duplicates the file so that the file can be deleted when
    // the MIME part is done
    dup_filename = dup_file(privacy, filename);
    if (dup_filename == NULL) {
      goto free_mime;
    }

    r = mailmime_set_body_file(mime, dup_filename);
    if (r != MAILIMF_NO_ERROR) {
      free(dup_filename);
      goto free_mime;
    }
  }*/
  if( data!=NULL && data_bytes>0 && mime->mm_type == MAILMIME_SINGLE ) {
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
  if (encoding != NULL)
    mailmime_mechanism_free(encoding);
  if (content != NULL)
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
 *
 * @param mime The mime struture to check
 *
 * @return 1=multipart/report found in MIME, 0=no multipart/report found
 */
static int contains_report(struct mailmime* mime)
{
	if( mime->mm_type == MAILMIME_MULTIPLE )
	{
		if( mime->mm_content_type->ct_type->tp_type==MAILMIME_TYPE_COMPOSITE_TYPE
		 && mime->mm_content_type->ct_type->tp_data.tp_composite_type->ct_type == MAILMIME_COMPOSITE_TYPE_MULTIPART
		 && strcmp(mime->mm_content_type->ct_subtype, "report")==0 ) {
			return 1;
		}

		clistiter* cur;
		for( cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list); cur!=NULL; cur=clist_next(cur)) {
			if( contains_report((struct mailmime*)clist_content(cur)) ) {
				return 1;
			}
		}
	}
	else if( mime->mm_type == MAILMIME_MESSAGE )
	{
		if( contains_report(mime->mm_data.mm_message.mm_msg_mime) ) {
			return 1;
		}
	}

	return 0;
}

/*******************************************************************************
 * Generate Keypairs
 ******************************************************************************/


static int load_or_generate_self_public_key__(mrmailbox_t* mailbox, mrkey_t* public_key, const char* self_addr,
                                              struct mailmime* random_data_mime /*for an extra-seed of the random generator. For speed reasons, only give _available_ pointers here, do not create any data - in very most cases, the key is not generated!*/)
{
	static int s_in_key_creation = 0; /* avoid double creation (we unlock the database during creation) */
	int        key_created = 0;
	int        success = 0, key_creation_here = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || public_key == NULL ) {
		goto cleanup;
	}

	if( !mrkey_load_self_public__(public_key, self_addr, mailbox->m_sql) )
	{
		/* create the keypair - this may take a moment, however, as this is in a thread, this is no big deal */
		if( s_in_key_creation ) { goto cleanup; }
		key_creation_here = 1;
		s_in_key_creation = 1;

		/* seed the random generator */
		{
			uintptr_t seed[4];
			seed[0] = (uintptr_t)time(NULL);     /* time */
			seed[1] = (uintptr_t)seed;           /* stack */
			seed[2] = (uintptr_t)public_key;     /* heap */
			seed[3] = (uintptr_t)pthread_self(); /* thread ID */
			mrpgp_rand_seed(mailbox, seed, sizeof(seed));

			if( random_data_mime ) {
				MMAPString* random_data_mmap = NULL;
				int col = 0;
				if( (random_data_mmap=mmap_string_new(""))==NULL ) {
					goto cleanup;
				}
				mailmime_write_mem(random_data_mmap, &col, random_data_mime);
				mrpgp_rand_seed(mailbox, random_data_mmap->str, random_data_mmap->len);
				mmap_string_free(random_data_mmap);
			}
		}

		{
			mrkey_t* private_key = mrkey_new();

			mrmailbox_log_info(mailbox, 0, "Generating keypair ...");

			mrsqlite3_unlock(mailbox->m_sql); /* SIC! unlock database during creation - otherwise the GUI may hang */

				/* The public key must contain the following:
				- a signing-capable primary key Kp
				- a user id
				- a self signature
				- an encryption-capable subkey Ke
				- a binding signature over Ke by Kp
				(see https://autocrypt.readthedocs.io/en/latest/level0.html#type-p-openpgp-based-key-data )*/
				key_created = mrpgp_create_keypair(mailbox, self_addr, public_key, private_key);

			mrsqlite3_lock(mailbox->m_sql);

			if( !key_created ) {
				mrmailbox_log_warning(mailbox, 0, "Cannot create keypair.");
				goto cleanup;
			}

			if( !mrpgp_is_valid_key(mailbox, public_key)
			 || !mrpgp_is_valid_key(mailbox, private_key) ) {
				mrmailbox_log_warning(mailbox, 0, "Generated keys are not valid.");
				goto cleanup;
			}

			if( !mrkey_save_self_keypair__(public_key, private_key, self_addr, 1/*set default*/, mailbox->m_sql) ) {
				mrmailbox_log_warning(mailbox, 0, "Cannot save keypair.");
				goto cleanup;
			}

			mrmailbox_log_info(mailbox, 0, "Keypair generated.");

			mrkey_unref(private_key);
		}
	}

	success = 1;

cleanup:
	if( key_creation_here ) { s_in_key_creation = 0; }
	return success;
}


int mrmailbox_ensure_secret_key_exists(mrmailbox_t* mailbox)
{
	/* normally, the key is generated as soon as the first mail is send
	(this is to gain some extra-random-seed by the message content and the timespan between program start and message sending) */
	int      success = 0, locked = 0;
	mrkey_t* public_key = mrkey_new();
	char*    self_addr = NULL;

	if( mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || public_key==NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( (self_addr=mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", NULL))==NULL ) {
			mrmailbox_log_warning(mailbox, 0, "Cannot ensure secret key if mailbox is not configured.");
			goto cleanup;
		}

		if( !load_or_generate_self_public_key__(mailbox, public_key, self_addr, NULL/*no random text data for seeding available*/) ) {
			goto cleanup;
		}

		success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrkey_unref(public_key);
	free(self_addr);
	return success;
}


/*******************************************************************************
 * Encrypt
 ******************************************************************************/


void mrmailbox_e2ee_encrypt(mrmailbox_t* mailbox, const clist* recipients_addr,
                    int force_unencrypted,
                    int e2ee_guaranteed, /*set if e2ee was possible on sending time; we should not degrade to transport*/
                    struct mailmime* in_out_message, mrmailbox_e2ee_helper_t* helper)
{
	int                    locked = 0, col = 0, do_encrypt = 0;
	mraheader_t*           autocryptheader = mraheader_new();
	struct mailimf_fields* imffields_unprotected = NULL; /*just a pointer into mailmime structure, must not be freed*/
	mrkeyring_t*           keyring = mrkeyring_new();
	mrkey_t*               sign_key = mrkey_new();
	MMAPString*            plain = mmap_string_new("");
	char*                  ctext = NULL;
	size_t                 ctext_bytes = 0;
	mrarray_t*             peerstates = mrarray_new(NULL, 10);

	if( helper ) { memset(helper, 0, sizeof(mrmailbox_e2ee_helper_t)); }

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || recipients_addr == NULL || in_out_message == NULL
	 || in_out_message->mm_parent /* libEtPan's pgp_encrypt_mime() takes the parent as the new root. We just expect the root as being given to this function. */
	 || autocryptheader == NULL || keyring==NULL || sign_key==NULL || plain == NULL || helper == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		/* init autocrypt header from db */
		autocryptheader->m_prefer_encrypt = MRA_PE_NOPREFERENCE;
		if( mailbox->m_e2ee_enabled ) {
			autocryptheader->m_prefer_encrypt = MRA_PE_MUTUAL;
		}

		autocryptheader->m_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", NULL);
		if( autocryptheader->m_addr == NULL ) {
			goto cleanup;
		}

		if( !load_or_generate_self_public_key__(mailbox, autocryptheader->m_public_key, autocryptheader->m_addr, in_out_message/*only for random-seed*/) ) {
			goto cleanup;
		}

		/* load peerstate information etc. */
		if( autocryptheader->m_prefer_encrypt==MRA_PE_MUTUAL || e2ee_guaranteed )
		{
			do_encrypt = 1;
			clistiter*      iter1;
			for( iter1 = clist_begin(recipients_addr); iter1!=NULL ; iter1=clist_next(iter1) ) {
				const char* recipient_addr = clist_content(iter1);
				mrapeerstate_t* peerstate = mrapeerstate_new(mailbox);
				if( mrapeerstate_load_by_addr__(peerstate, mailbox->m_sql, recipient_addr)
				 && mrapeerstate_peek_key(peerstate)
				 && (peerstate->m_prefer_encrypt==MRA_PE_MUTUAL || e2ee_guaranteed) )
				{
					mrkeyring_add(keyring, mrapeerstate_peek_key(peerstate)); /* we always add all recipients (even on IMAP upload) as otherwise forwarding may fail */
					mrarray_add_ptr(peerstates, peerstate);
				}
				else {
					mrapeerstate_unref(peerstate);
					do_encrypt = 0;
					break; /* if we cannot encrypt to a single recipient, we cannot encrypt the message at all */
				}
			}
		}

		if( do_encrypt ) {
			mrkeyring_add(keyring, autocryptheader->m_public_key); /* we always add ourself as otherwise forwarded messages are not readable */
			if( !mrkey_load_self_private__(sign_key, autocryptheader->m_addr, mailbox->m_sql) ) {
				do_encrypt = 0;
			}
		}

		if( force_unencrypted ) {
			do_encrypt = 0;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	if( (imffields_unprotected=mailmime_find_mailimf_fields(in_out_message))==NULL ) {
		goto cleanup;
	}

	/* encrypt message, if possible */
	if( do_encrypt )
	{
		/* prepare part to encrypt */
		mailprivacy_prepare_mime(in_out_message); /* encode quoted printable all text parts */

		struct mailmime* part_to_encrypt = in_out_message->mm_data.mm_message.mm_msg_mime;
		part_to_encrypt->mm_parent = NULL;
		struct mailimf_fields* imffields_encrypted = mailimf_fields_new_empty();
		struct mailmime* message_to_encrypt = mailmime_new(MAILMIME_MESSAGE, NULL, 0, mailmime_fields_new_empty(), /* mailmime_new_message_data() calls mailmime_fields_new_with_version() which would add the unwanted MIME-Version:-header */
			mailmime_get_content_message(), NULL, NULL, NULL, NULL, imffields_encrypted, part_to_encrypt);

		/* gossip keys */
		int iCnt = mrarray_get_cnt(peerstates);
		if( iCnt > 1 ) {
			for( int i = 0; i < iCnt; i++ ) {
				char* p = mrapeerstate_render_gossip_header((mrapeerstate_t*)mrarray_get_ptr(peerstates, i));
				if( p ) {
					mailimf_fields_add(imffields_encrypted, mailimf_field_new_custom(strdup("Autocrypt-Gossip"), p/*takes ownership*/));
				}
			}
		}

		/* memoryhole headers */
		clistiter* cur = clist_begin(imffields_unprotected->fld_list);
		while( cur!=NULL ) {
			int move_to_encrypted = 0;

			struct mailimf_field* field = (struct mailimf_field*)clist_content(cur);
			if( field ) {
				if( field->fld_type == MAILIMF_FIELD_SUBJECT ) {
					move_to_encrypted = 1;
				}
				else if( field->fld_type == MAILIMF_FIELD_OPTIONAL_FIELD ) {
					struct mailimf_optional_field* opt_field = field->fld_data.fld_optional_field;
					if( opt_field && opt_field->fld_name ) {
						if(  strncmp(opt_field->fld_name, "Secure-Join", 11)==0
						 || (strncmp(opt_field->fld_name, "Chat-", 5)==0 && strcmp(opt_field->fld_name, "Chat-Version")!=0)/*Chat-Version may be used for filtering, however, this is subject to cha*/ ) {
							move_to_encrypted = 1;
						}
					}
				}
			}

			if( move_to_encrypted ) {
				mailimf_fields_add(imffields_encrypted, field);
				cur = clist_delete(imffields_unprotected->fld_list, cur);
			}
			else {
				cur = clist_next(cur);
			}
		}

		char* e = mrstock_str(MR_STR_ENCRYPTEDMSG); char* subject_str = mr_mprintf(MR_CHAT_PREFIX " %s", e); free(e);
		struct mailimf_subject* subject = mailimf_subject_new(mr_encode_header_string(subject_str));
		mailimf_fields_add(imffields_unprotected, mailimf_field_new(MAILIMF_FIELD_SUBJECT, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, subject, NULL, NULL, NULL));
		free(subject_str);

		clist_append(part_to_encrypt->mm_content_type->ct_parameters, mailmime_param_new_with_data("protected-headers", "v1"));

		/* convert part to encrypt to plain text */
		mailmime_write_mem(plain, &col, message_to_encrypt);
		if( plain->str == NULL || plain->len<=0 ) {
			goto cleanup;
		}
		//char* t1=mr_null_terminate(plain->str,plain->len);printf("PLAIN:\n%s\n",t1);free(t1); // DEBUG OUTPUT

		if( !mrpgp_pk_encrypt(mailbox, plain->str, plain->len, keyring, sign_key, 1/*use_armor*/, (void**)&ctext, &ctext_bytes) ) {
			goto cleanup;
		}
		helper->m_cdata_to_free = ctext;
		//char* t2=mr_null_terminate(ctext,ctext_bytes);printf("ENCRYPTED:\n%s\n",t2);free(t2); // DEBUG OUTPUT

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
		//MMAPString* t3=mmap_string_new("");mailmime_write_mem(t3,&col,in_out_message);char* t4=mr_null_terminate(t3->str,t3->len); printf("ENCRYPTED+MIME_ENCODED:\n%s\n",t4);free(t4);mmap_string_free(t3); // DEBUG OUTPUT

		helper->m_encryption_successfull = 1;
	}

	char* p = mraheader_render(autocryptheader);
	if( p == NULL ) {
		goto cleanup;
	}
	mailimf_fields_add(imffields_unprotected, mailimf_field_new_custom(strdup("Autocrypt"), p/*takes ownership of pointer*/));

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mraheader_unref(autocryptheader);
	mrkeyring_unref(keyring);
	mrkey_unref(sign_key);
	if( plain ) { mmap_string_free(plain); }

	for( int i=mrarray_get_cnt(peerstates)-1; i>=0; i-- ) { mrapeerstate_unref((mrapeerstate_t*)mrarray_get_ptr(peerstates, i)); }
	mrarray_unref(peerstates);
}


void mrmailbox_e2ee_thanks(mrmailbox_e2ee_helper_t* helper)
{
	if( helper == NULL ) {
		return;
	}

	free(helper->m_cdata_to_free);
	helper->m_cdata_to_free = NULL;
}


/*******************************************************************************
 * Decrypt
 ******************************************************************************/


static int has_decrypted_pgp_armor(const char* str__, int str_bytes)
{
	const unsigned char *str_end = (const unsigned char*)str__+str_bytes, *p=(const unsigned char*)str__;
	while( p < str_end ) {
		if( *p > ' ' ) {
			break;
		}
		p++;
		str_bytes--;
	}
	if( str_bytes>27 && strncmp((const char*)p, "-----BEGIN PGP MESSAGE-----", 27)==0 ) {
		return 1;
	}
	return 0;
}


static int decrypt_part(mrmailbox_t*       mailbox,
                        struct mailmime*   mime,
                        const mrkeyring_t* private_keyring,
                        const mrkey_t*     public_key_for_validate, /*may be NULL*/
                        int*               ret_validation_errors,
                        struct mailmime**  ret_decrypted_mime)
{
	struct mailmime_data*        mime_data;
	int                          mime_transfer_encoding = MAILMIME_MECHANISM_BINARY;
	char*                        transfer_decoding_buffer = NULL; /* mmap_string_unref()'d if set */
	const char*                  decoded_data = NULL; /* must not be free()'d */
	size_t                       decoded_data_bytes = 0;
	void*                        plain_buf = NULL;
	size_t                       plain_bytes = 0;
	int                          part_validation_errors = 0;
	int                          sth_decrypted = 0;

	*ret_decrypted_mime = NULL;

	/* get data pointer from `mime` */
	mime_data = mime->mm_data.mm_single;
	if( mime_data->dt_type != MAILMIME_DATA_TEXT   /* MAILMIME_DATA_FILE indicates, the data is in a file; AFAIK this is not used on parsing */
	 || mime_data->dt_data.dt_text.dt_data == NULL
	 || mime_data->dt_data.dt_text.dt_length <= 0 ) {
		goto cleanup;
	}

	/* check headers in `mime` */
	if( mime->mm_mime_fields != NULL ) {
		clistiter* cur;
		for( cur = clist_begin(mime->mm_mime_fields->fld_list); cur != NULL; cur = clist_next(cur) ) {
			struct mailmime_field* field = (struct mailmime_field*)clist_content(cur);
			if( field ) {
				if( field->fld_type == MAILMIME_FIELD_TRANSFER_ENCODING && field->fld_data.fld_encoding ) {
					mime_transfer_encoding = field->fld_data.fld_encoding->enc_type;
				}
			}
		}
	}

	/* regard `Content-Transfer-Encoding:` */
	if( mime_transfer_encoding == MAILMIME_MECHANISM_7BIT
	 || mime_transfer_encoding == MAILMIME_MECHANISM_8BIT
	 || mime_transfer_encoding == MAILMIME_MECHANISM_BINARY )
	{
		decoded_data       = mime_data->dt_data.dt_text.dt_data;
		decoded_data_bytes = mime_data->dt_data.dt_text.dt_length;
		if( decoded_data == NULL || decoded_data_bytes <= 0 ) {
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
		if( r != MAILIMF_NO_ERROR || transfer_decoding_buffer == NULL || decoded_data_bytes <= 0 ) {
			goto cleanup;
		}
		decoded_data = transfer_decoding_buffer;
	}

	/* encrypted, decoded data in decoded_data now ... */
	if( !has_decrypted_pgp_armor(decoded_data, decoded_data_bytes) ) {
		goto cleanup;
	}

	if( !mrpgp_pk_decrypt(mailbox, decoded_data, decoded_data_bytes, private_keyring, public_key_for_validate, 1, &plain_buf, &plain_bytes, &part_validation_errors)
	 || plain_buf==NULL || plain_bytes<=0 ) {
		goto cleanup;
	}

	if( part_validation_errors ) {
		(*ret_validation_errors) |= part_validation_errors;
	}

	//{char* t1=mr_null_terminate(plain_buf,plain_bytes);printf("\n**********\n%s\n**********\n",t1);free(t1);}

	{
		size_t index = 0;
		struct mailmime* decrypted_mime = NULL;
		if( mailmime_parse(plain_buf, plain_bytes, &index, &decrypted_mime)!=MAIL_NO_ERROR
		 || decrypted_mime == NULL ) {
			if(decrypted_mime) {mailmime_free(decrypted_mime);}
			goto cleanup;
		}

		//mailmime_print(new_mime);

		*ret_decrypted_mime = decrypted_mime;
		sth_decrypted = 1;
	}

	//mailmime_substitute(mime, new_mime);
	//s. mailprivacy_gnupg.c::pgp_decrypt()

cleanup:
	if( transfer_decoding_buffer ) {
		mmap_string_unref(transfer_decoding_buffer);
	}
	return sth_decrypted;
}


static int decrypt_recursive(mrmailbox_t*            mailbox,
                             struct mailmime*        mime,
                             const mrkeyring_t*      private_keyring,
                             const mrkey_t*          public_key_for_validate,
                             int*                    ret_validation_errors,
                             struct mailimf_fields** ret_gossip_headers )
{
	struct mailmime_content* ct;
	clistiter*               cur;

	if( mailbox == NULL || mime == NULL ) {
		return 0;
	}

	if( mime->mm_type == MAILMIME_MULTIPLE )
	{
		ct = mime->mm_content_type;
		if( ct && ct->ct_subtype && strcmp(ct->ct_subtype, "encrypted")==0 ) {
			/* decrypt "multipart/encrypted" -- child parts are eg. "application/pgp-encrypted" (uninteresting, version only),
			"application/octet-stream" (the interesting data part) and optional, unencrypted help files */
			for( cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list); cur!=NULL; cur=clist_next(cur)) {
				struct mailmime* decrypted_mime = NULL;
				if( decrypt_part(mailbox, (struct mailmime*)clist_content(cur), private_keyring, public_key_for_validate, ret_validation_errors, &decrypted_mime) )
				{
					/* remember the header containing potentially Autocrypt-Gossip */
					if( *ret_gossip_headers == NULL /* use the outermost decrypted part */
					 && (*ret_validation_errors) == 0 /* do not trust the gossipped keys when the message cannot be validated eg. due to a bad signature */ )
					{
						size_t dummy = 0;
						struct mailimf_fields* test = NULL;
						if( mailimf_envelope_and_optional_fields_parse(decrypted_mime->mm_mime_start, decrypted_mime->mm_length, &dummy, &test)==MAILIMF_NO_ERROR
						 && test ) {
							*ret_gossip_headers = test;
						}
					}

					/* replace encrypted mime structure by decrypted one */
					mailmime_substitute(mime, decrypted_mime);
					mailmime_free(mime);
					return 1; /* sth. decrypted, start over from root searching for encrypted parts */
				}
			}
		}
		else {
			for( cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list); cur!=NULL; cur=clist_next(cur)) {
				if( decrypt_recursive(mailbox, (struct mailmime*)clist_content(cur), private_keyring, public_key_for_validate, ret_validation_errors, ret_gossip_headers) ) {
					return 1; /* sth. decrypted, start over from root searching for encrypted parts */
				}
			}
		}
	}
	else if( mime->mm_type == MAILMIME_MESSAGE )
	{
		if( decrypt_recursive(mailbox, mime->mm_data.mm_message.mm_msg_mime, private_keyring, public_key_for_validate, ret_validation_errors, ret_gossip_headers) ) {
			return 1; /* sth. decrypted, start over from root searching for encrypted parts */
		}
	}

	return 0;
}


static void update_gossip_peerstates(mrmailbox_t* mailbox, time_t message_time, struct mailimf_fields* imffields, const struct mailimf_fields* gossip_headers)
{
	clistiter* cur1;
	mrhash_t*  recipients = NULL;

	for( cur1 = clist_begin(gossip_headers->fld_list); cur1!=NULL ; cur1=clist_next(cur1) )
	{
		struct mailimf_field* field = (struct mailimf_field*)clist_content(cur1);
		if( field->fld_type == MAILIMF_FIELD_OPTIONAL_FIELD )
		{
			const struct mailimf_optional_field* optional_field = field->fld_data.fld_optional_field;
			if( optional_field && optional_field->fld_name && strcasecmp(optional_field->fld_name, "Autocrypt-Gossip")==0 )
			{
				mraheader_t* gossip_header = mraheader_new();
				if( mraheader_set_from_string(gossip_header, optional_field->fld_value)
				 && mrpgp_is_valid_key(mailbox, gossip_header->m_public_key) )
				{
					/* found an Autocrypt-Gossip entry, create recipents list and check if addr matches */
					if( recipients == NULL ) {
						recipients = mailimf_get_recipients(imffields);
					}

					if( mrhash_find(recipients, gossip_header->m_addr, strlen(gossip_header->m_addr)) )
					{
						/* valid recipient: update peerstate */
						mrapeerstate_t* peerstate = mrapeerstate_new(mailbox);
						if( !mrapeerstate_load_by_addr__(peerstate, mailbox->m_sql, gossip_header->m_addr) ) {
							mrapeerstate_init_from_gossip(peerstate, gossip_header, message_time);
							mrapeerstate_save_to_db__(peerstate, mailbox->m_sql, 1/*create*/);
						}
						else {
							mrapeerstate_apply_gossip(peerstate, gossip_header, message_time);
							mrapeerstate_save_to_db__(peerstate, mailbox->m_sql, 0/*do not create*/);
						}
						mrapeerstate_unref(peerstate);
					}
					else
					{
						mrmailbox_log_info(mailbox, 0, "Ignoring gossipped \"%s\" as the address is not in To/Cc list.", gossip_header->m_addr);
					}
				}
				mraheader_unref(gossip_header);
			}
		}
	}

	if( recipients ) {
		mrhash_clear(recipients);
		free(recipients);
	}
}


int mrmailbox_e2ee_decrypt(mrmailbox_t* mailbox, struct mailmime* in_out_message, int* ret_validation_errors, int* ret_degrade_event)
{
	/* return values: 0=nothing to decrypt/cannot decrypt, 1=sth. decrypted
	(to detect parts that could not be decrypted, simply look for left "multipart/encrypted" MIME types */
	struct mailimf_fields* imffields = mailmime_find_mailimf_fields(in_out_message); /*just a pointer into mailmime structure, must not be freed*/
	mraheader_t*           autocryptheader = NULL;
	time_t                 message_time = 0;
	mrapeerstate_t*        peerstate = mrapeerstate_new(mailbox);
	int                    locked = 0;
	char*                  from = NULL, *self_addr = NULL;
	mrkeyring_t*           private_keyring = mrkeyring_new();
	int                    sth_decrypted = 0;
	struct mailimf_fields* gossip_headers = NULL;

	if( ret_degrade_event ) {
		*ret_degrade_event = 0;
	}

	if( mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || in_out_message==NULL || ret_validation_errors==NULL
	 || imffields==NULL || peerstate==NULL || private_keyring==NULL ) {
		goto cleanup;
	}

	/* Autocrypt preparations:
	- Set message_time and from (both may be unset)
	- Get the autocrypt header, if any.
	- Do not abort on errors - we should try at last the decyption below */
	if( imffields )
	{
		struct mailimf_field* field = mailimf_find_field(imffields, MAILIMF_FIELD_FROM);
		if( field && field->fld_data.fld_from ) {
			from = mailimf_find_first_addr(field->fld_data.fld_from->frm_mb_list);
		}

		field = mailimf_find_field(imffields, MAILIMF_FIELD_ORIG_DATE);
		if( field && field->fld_data.fld_orig_date ) {
			struct mailimf_orig_date* orig_date = field->fld_data.fld_orig_date;
			if( orig_date ) {
				message_time = mr_timestamp_from_date(orig_date->dt_date_time); /* is not yet checked against bad times! */
				if( message_time != MR_INVALID_TIMESTAMP && message_time > time(NULL) ) {
					message_time = time(NULL);
				}
			}
		}
	}

	autocryptheader = mraheader_new_from_imffields(from, imffields);
	if( autocryptheader ) {
		if( !mrpgp_is_valid_key(mailbox, autocryptheader->m_public_key) ) {
			mraheader_unref(autocryptheader);
			autocryptheader = NULL;
		}
	}

	/* modify the peerstate (eg. if there is a peer but not autocrypt header, stop encryption) */
	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		/* apply Autocrypt:-header */
		if( message_time > 0
		 && from )
		{
			if( mrapeerstate_load_by_addr__(peerstate, mailbox->m_sql, from) ) {
				if( autocryptheader ) {
					mrapeerstate_apply_header(peerstate, autocryptheader, message_time);
					mrapeerstate_save_to_db__(peerstate, mailbox->m_sql, 0/*no not create*/);
				}
				else {
					if( message_time > peerstate->m_last_seen_autocrypt
					 && !contains_report(in_out_message) /*reports are ususally not encrpyted; do not degrade decryption then*/ ){
						mrapeerstate_degrade_encryption(peerstate, message_time);
						mrapeerstate_save_to_db__(peerstate, mailbox->m_sql, 0/*no not create*/);
					}
				}
			}
			else if( autocryptheader ) {
				mrapeerstate_init_from_header(peerstate, autocryptheader, message_time);
				mrapeerstate_save_to_db__(peerstate, mailbox->m_sql, 1/*create*/);
			}
		}

		if( ret_degrade_event ) {
			*ret_degrade_event = peerstate->m_degrade_event;
		}

		/* load private key for decryption */
		if( (self_addr=mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", NULL))==NULL ) {
			goto cleanup;
		}

		if( !mrkeyring_load_self_private_for_decrypting__(private_keyring, self_addr, mailbox->m_sql) ) {
			goto cleanup;
		}

		/* if not yet done, load peer with public key for verification (should be last as the peer may be modified above) */
		if( peerstate->m_last_seen == 0 ) {
			mrapeerstate_load_by_addr__(peerstate, mailbox->m_sql, from);
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* finally, decrypt.  If sth. was decrypted, decrypt_recursive() returns "true" and we start over to decrypt maybe just added parts. */
	*ret_validation_errors = 0;
	int avoid_deadlock = 10;
	while( avoid_deadlock > 0 ) {
		if( !decrypt_recursive(mailbox, in_out_message, private_keyring,
		        peerstate->m_public_key, /* never use gossip_key for validation - if we get a mail to validate from the user, we normally also have the public_key */
		        ret_validation_errors, &gossip_headers) ) {
			break;
		}
		sth_decrypted = 1;
		avoid_deadlock--;
	}

	/* check for Autocrypt-Gossip (NB: maybe we should use this header also for mrmimeparser_t::m_header_protected)  */
	if( gossip_headers ) {
		update_gossip_peerstates(mailbox, message_time, imffields, gossip_headers);
	}

	//mailmime_print(in_out_message);

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( gossip_headers ) { mailimf_fields_free(gossip_headers); }
	mraheader_unref(autocryptheader);
	mrapeerstate_unref(peerstate);
	mrkeyring_unref(private_keyring);
	free(from);
	free(self_addr);
	return sth_decrypted;
}

