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


/* Stress some functions for testing; if used as a lib, this file is obsolete.
For memory checking, use eg.
$ valgrind --leak-check=full --tool=memcheck ./deltachat-core <db>
*/


#include <ctype.h>
#include <assert.h>
#include "mrmailbox_internal.h"
#include "mrsimplify.h"
#include "mrmimeparser.h"
#include "mrmimefactory.h"
#include "mrpgp.h"
#include "mrapeerstate.h"
#include "mraheader.h"
#include "mrkeyring.h"


void stress_functions(mrmailbox_t* mailbox)
{
	/* test mrsimplify and mrsaxparser (indirectly used by mrsimplify)
	 **************************************************************************/

	{
		mrsimplify_t* simplify = mrsimplify_new();

		const char* html = "\r\r\nline1<br>\r\n\r\n\r\rline2\n\r"; /* check, that `<br>\ntext` does not result in `\n text` */
		char* plain = mrsimplify_simplify(simplify, html, strlen(html), 1);
		assert( strcmp(plain, "line1\nline2")==0 );
		free(plain);

		html = "<a href=url>text</a"; /* check unquoted attribute and unclosed end-tag */
		plain = mrsimplify_simplify(simplify, html, strlen(html), 1);
		assert( strcmp(plain, "[text](url)")==0 );
		free(plain);

		html = "<!DOCTYPE name [<!DOCTYPE ...>]><!-- comment -->text <b><?php echo ... ?>bold</b><![CDATA[<>]]>";
		plain = mrsimplify_simplify(simplify, html, strlen(html), 1);
		assert( strcmp(plain, "text *bold*<>")==0 );
		free(plain);

		html = "&lt;&gt;&quot;&apos;&amp; &auml;&Auml;&ouml;&Ouml;&uuml;&Uuml;&szlig; foo&AElig;&ccedil;&Ccedil; &diams;&noent;&lrm;&rlm;&zwnj;&zwj;";
		plain = mrsimplify_simplify(simplify, html, strlen(html), 1);
		assert( strcmp(plain, "<>\"'& äÄöÖüÜß fooÆçÇ ♦&noent;")==0 );
		free(plain);

		mrsimplify_unref(simplify);
	}

	/* test mime
	**************************************************************************/

	{
		const char* txt =  "FieldA: ValueA\nFieldB: ValueB\n";
		struct mailmime* mime = NULL;
		size_t dummy = 0;
		assert( mailmime_parse(txt, strlen(txt), &dummy, &mime) == MAIL_NO_ERROR );
		assert( mime != NULL );

		struct mailimf_fields* fields = mr_find_mailimf_fields(mime);
		assert( fields != NULL );

		struct mailimf_optional_field* of_a = mr_find_mailimf_field2(fields, "fielda");
		assert( of_a && of_a->fld_value );
		assert( strcmp(of_a->fld_name, "FieldA")==0 );
		assert( strcmp(of_a->fld_value, "ValueA")==0 );

		of_a = mr_find_mailimf_field2(fields, "FIELDA");
		assert( of_a && of_a->fld_value );
		assert( strcmp(of_a->fld_name, "FieldA")==0 );
		assert( strcmp(of_a->fld_value, "ValueA")==0 );

		struct mailimf_optional_field* of_b = mr_find_mailimf_field2(fields, "FieldB");
		assert( of_b && of_b->fld_value );
		assert( strcmp(of_b->fld_value, "ValueB")==0 );




		mailmime_free(mime);
	}

	/* test some string functions
	 **************************************************************************/

	{
		char* str = strdup("aaa");
		int replacements = mr_str_replace(&str, "a", "ab"); /* no endless recursion here! */
		assert( strcmp(str, "ababab")==0 );
		assert( replacements == 3 );
		free(str);

		str = mr_insert_breaks("just1234test", 4, " ");
		assert( strcmp(str, "just 1234 test")==0 );
		free(str);

		str = mr_insert_breaks("just1234tes", 4, "--");
		assert( strcmp(str, "just--1234--tes")==0 );
		free(str);

		str = mr_insert_breaks("just1234t", 4, "");
		assert( strcmp(str, "just1234t")==0 );
		free(str);

		str = mr_insert_breaks("", 4, "---");
		assert( strcmp(str, "")==0 );
		free(str);

		str = mr_null_terminate("abcxyz", 3);
		assert( strcmp(str, "abc")==0 );
		free(str);

		str = mr_null_terminate("abcxyz", 0);
		assert( strcmp(str, "")==0 );
		free(str);

		str = mr_null_terminate(NULL, 0);
		assert( strcmp(str, "")==0 );
		free(str);

        assert( strcmp("fresh="     MR_STRINGIFY(MR_STATE_IN_FRESH),      "fresh=10")==0 ); /* these asserts check the values, the existance of the macros and also MR_STRINGIFY() */
        assert( strcmp("noticed="   MR_STRINGIFY(MR_STATE_IN_NOTICED),    "noticed=13")==0 );
        assert( strcmp("seen="      MR_STRINGIFY(MR_STATE_IN_SEEN),       "seen=16")==0 );
        assert( strcmp("pending="   MR_STRINGIFY(MR_STATE_OUT_PENDING),   "pending=20")==0 );
        assert( strcmp("error="     MR_STRINGIFY(MR_STATE_OUT_ERROR),     "error=24")==0 );
        assert( strcmp("delivered=" MR_STRINGIFY(MR_STATE_OUT_DELIVERED), "delivered=26")==0 );
        assert( strcmp("mdn_rcvd="  MR_STRINGIFY(MR_STATE_OUT_MDN_RCVD),  "mdn_rcvd=28")==0 );

        assert( strcmp("deaddrop="     MR_STRINGIFY(MR_CHAT_ID_DEADDROP),         "deaddrop=1")==0 );
        assert( strcmp("to_deaddrop="  MR_STRINGIFY(MR_CHAT_ID_TO_DEADDROP),      "to_deaddrop=2")==0 );
        assert( strcmp("trash="        MR_STRINGIFY(MR_CHAT_ID_TRASH),            "trash=3")==0 );
        assert( strcmp("in_creation="  MR_STRINGIFY(MR_CHAT_ID_MSGS_IN_CREATION), "in_creation=4")==0 );
        assert( strcmp("starred="      MR_STRINGIFY(MR_CHAT_ID_STARRED),          "starred=5")==0 );
        assert( strcmp("archivedlink=" MR_STRINGIFY(MR_CHAT_ID_ARCHIVED_LINK),    "archivedlink=6")==0 );
        assert( strcmp("spcl_chat="    MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL),     "spcl_chat=9")==0 );

        assert( strcmp("self="         MR_STRINGIFY(MR_CONTACT_ID_SELF),          "self=1")==0 );
        assert( strcmp("system="       MR_STRINGIFY(MR_CONTACT_ID_SYSTEM),        "system=2")==0 );
        assert( strcmp("spcl_contact=" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL),     "spcl_contact=9")==0 );

        assert( strcmp("grpimg="    MR_STRINGIFY(MR_SYSTEM_GROUPIMAGE_CHANGED), "grpimg=3")==0 );

        assert( MRP_FILE == 'f' );
        assert( MRP_WIDTH == 'w' );
        assert( MRP_HEIGHT == 'h' );
        assert( MRP_DURATION == 'd' );
        assert( MRP_MIMETYPE == 'm' );
        assert( MRP_AUTHORNAME == 'N' );
        assert( MRP_TRACKNAME == 'n' );
        assert( MRP_FORWARDED == 'a' );
        assert( MRP_UNPROMOTED == 'U' );

        char* buf1 = strdup("ol\xc3\xa1 mundo <>\"'& äÄöÖüÜß fooÆçÇ ♦&noent;"); char* buf2 = strdup(buf1);
        mr_replace_bad_utf8_chars(buf2);
        assert( strcmp(buf1, buf2)==0 );
        free(buf1); free(buf2);

        buf1 = strdup("ISO-String with Ae: \xC4"); buf2 = strdup(buf1);
        mr_replace_bad_utf8_chars(buf2);
        assert( strcmp("ISO-String with Ae: _", buf2)==0 );
        free(buf1); free(buf2);

        buf1 = strdup(""); buf2 = strdup(buf1);
        mr_replace_bad_utf8_chars(buf2);
        assert( buf2[0]==0 );
        free(buf1); free(buf2);

        mr_replace_bad_utf8_chars(NULL); /* should do nothing */
	}

	/* test mrparam
	 **************************************************************************/

	{
		mrparam_t* p1 = mrparam_new();

		mrparam_set_packed(p1, "\r\n\r\na=1\nb=2\n\nc = 3 ");

		assert( mrparam_get_int(p1, 'a', 0)==1 );
		assert( mrparam_get_int(p1, 'b', 0)==2 );
		assert( mrparam_get_int(p1, 'c', 0)==0 ); /* c is not accepted, spaces and weird characters are not allowed in param, were very strict there */
		assert( mrparam_exists (p1, 'c')==0 );

		mrparam_set_int(p1, 'd', 4);
		assert( mrparam_get_int(p1, 'd', 0)==4 );

		mrparam_empty(p1);
		mrparam_set    (p1, 'a', "foo");
		mrparam_set_int(p1, 'b', 2);
		mrparam_set    (p1, 'c', NULL);
		mrparam_set_int(p1, 'd', 4);
		assert( strcmp(p1->m_packed, "a=foo\nb=2\nd=4")==0 );

		mrparam_set    (p1, 'b', NULL);
		assert( strcmp(p1->m_packed, "a=foo\nd=4")==0 );

		mrparam_set    (p1, 'a', NULL);
		mrparam_set    (p1, 'd', NULL);
		assert( strcmp(p1->m_packed, "")==0 );

		mrparam_unref(p1);
	}

	/* test Autocrypt header parsing functions
	 **************************************************************************/

	{
		mraheader_t* ah = mraheader_new();
		char*        rendered = NULL;
		int          ah_ok;

		ah_ok = mraheader_set_from_string(ah, "addr=a@b.example.org; prefer-encrypt=mutual; keydata=RGVsdGEgQ2hhdA==");
		assert( ah_ok == 1 );
		assert( ah->m_addr && strcmp(ah->m_addr, "a@b.example.org")==0 );
		assert( ah->m_public_key->m_bytes==10 && strncmp((char*)ah->m_public_key->m_binary, "Delta Chat", 10)==0 );
		assert( ah->m_prefer_encrypt==MRA_PE_MUTUAL );

		rendered = mraheader_render(ah);
		assert( rendered && strcmp(rendered, "addr=a@b.example.org; prefer-encrypt=mutual; keydata= RGVsdGEgQ2hhdA==")==0 );

		ah_ok = mraheader_set_from_string(ah, " _foo; __FOO=BAR ;;; addr = a@b.example.org ;\r\n   prefer-encrypt = mutual ; keydata = RG VsdGEgQ\r\n2hhdA==");
		assert( ah_ok == 1 );
		assert( ah->m_addr && strcmp(ah->m_addr, "a@b.example.org")==0 );
		assert( ah->m_public_key->m_bytes==10 && strncmp((char*)ah->m_public_key->m_binary, "Delta Chat", 10)==0 );
		assert( ah->m_prefer_encrypt==MRA_PE_MUTUAL );

		ah_ok = mraheader_set_from_string(ah, "addr=a@b.example.org; prefer-encrypt=ignoreUnknownValues; keydata=RGVsdGEgQ2hhdA==");
		assert( ah_ok == 1 ); /* only "yes" or "no" are valid for prefer-encrypt ... */

		ah_ok = mraheader_set_from_string(ah, "addr=a@b.example.org; keydata=RGVsdGEgQ2hhdA==");
		assert( ah_ok == 1 && ah->m_prefer_encrypt==MRA_PE_NOPREFERENCE ); /* ... "nopreference" is use if the attribute is missing (see Autocrypt-Level0) */

		ah_ok = mraheader_set_from_string(ah, "");
		assert( ah_ok == 0 );

		ah_ok = mraheader_set_from_string(ah, ";");
		assert( ah_ok == 0 );

		ah_ok = mraheader_set_from_string(ah, "foo");
		assert( ah_ok == 0 );

		ah_ok = mraheader_set_from_string(ah, "\n\n\n");
		assert( ah_ok == 0 );

		ah_ok = mraheader_set_from_string(ah, " ;;");
		assert( ah_ok == 0 );

		ah_ok = mraheader_set_from_string(ah, "addr=a@t.de; unknwon=1; keydata=jau"); /* unknwon non-underscore attributes result in invalid headers */
		assert( ah_ok == 0 );

		mraheader_unref(ah);
		free(rendered);
	}


	/* test end-to-end-encryption
	 **************************************************************************/

	{
		mrkey_t *public_key = mrkey_new(), *private_key = mrkey_new();
		mrpgp_create_keypair(mailbox, "foo@bar.de", public_key, private_key);
		assert( mrpgp_is_valid_key(mailbox, public_key) );
		assert( mrpgp_is_valid_key(mailbox, private_key) );
		//{char *t1=mrkey_render_asc(public_key); printf("%s",t1);mr_write_file("/home/bpetersen/temp/stress-public.asc", t1,strlen(t1),mailbox);mr_write_file("/home/bpetersen/temp/stress-public.der", public_key->m_binary, public_key->m_bytes, mailbox);free(t1);}
		//{char *t1=mrkey_render_asc(private_key);printf("%s",t1);mr_write_file("/home/bpetersen/temp/stress-private.asc",t1,strlen(t1),mailbox);mr_write_file("/home/bpetersen/temp/stress-private.der",private_key->m_binary,private_key->m_bytes,mailbox);free(t1);}

		{
			mrkey_t *test_key = mrkey_new();
			assert( mrpgp_split_key(mailbox, private_key, test_key) );
			assert( mrkey_equals(public_key, test_key) );
			mrkey_unref(test_key);
		}

		mrkey_t *public_key2 = mrkey_new(), *private_key2 = mrkey_new();
		mrpgp_create_keypair(mailbox, "two@zwo.de", public_key2, private_key2);

		assert( !mrkey_equals(public_key, public_key2) );

		const char* original_text = "This is a test";
		void *ctext_signed = NULL, *ctext_unsigned = NULL;
		size_t ctext_signed_bytes = 0, ctext_unsigned_bytes, plain_bytes = 0;

		{
			mrkeyring_t* keyring = mrkeyring_new();
			mrkeyring_add(keyring, public_key);
			mrkeyring_add(keyring, public_key2);
				int ok = mrpgp_pk_encrypt(mailbox, original_text, strlen(original_text), keyring, private_key, 1, (void**)&ctext_signed, &ctext_signed_bytes);
				assert( ok && ctext_signed && ctext_signed_bytes>0 );
				assert( strncmp((char*)ctext_signed, "-----BEGIN PGP MESSAGE-----", 27)==0 );
				assert( ((char*)ctext_signed)[ctext_signed_bytes-1]!=0 ); /*armored strings are not null-terminated!*/
				//{char* t3 = mr_null_terminate((char*)ctext,ctext_bytes);printf("\n%i ENCRYPTED BYTES: {\n%s\n}\n",(int)ctext_bytes,t3);free(t3);}

				ok = mrpgp_pk_encrypt(mailbox, original_text, strlen(original_text), keyring, NULL, 1, (void**)&ctext_unsigned, &ctext_unsigned_bytes);
				assert( ok && ctext_unsigned && ctext_unsigned_bytes>0 );
				assert( strncmp((char*)ctext_unsigned, "-----BEGIN PGP MESSAGE-----", 27)==0 );
				assert( ctext_unsigned_bytes < ctext_signed_bytes );

			mrkeyring_unref(keyring);
		}

		{
			mrkeyring_t* keyring = mrkeyring_new();
			mrkeyring_add(keyring, private_key);
			void* plain = NULL;
			int validation_errors = 0, ok;

			ok = mrpgp_pk_decrypt(mailbox, ctext_signed, ctext_signed_bytes, keyring, public_key/*for validate*/, 1, &plain, &plain_bytes, &validation_errors);
			assert( ok && plain && plain_bytes>0 );
			assert( strncmp((char*)plain, original_text, strlen(original_text))==0 );
			assert( validation_errors == 0 );
			free(plain); plain = NULL;

			ok = mrpgp_pk_decrypt(mailbox, ctext_signed, ctext_signed_bytes, keyring, NULL/*for validate*/, 1, &plain, &plain_bytes, &validation_errors);
			assert( ok && plain && plain_bytes>0 );
			assert( strncmp((char*)plain, original_text, strlen(original_text))==0 );
			assert( validation_errors == MR_VALIDATE_UNKNOWN_SIGNATURE );
			free(plain); plain = NULL;

			ok = mrpgp_pk_decrypt(mailbox, ctext_signed, ctext_signed_bytes, keyring, public_key2/*for validate*/, 1, &plain, &plain_bytes, &validation_errors);
			assert( ok && plain && plain_bytes>0 );
			assert( strncmp((char*)plain, original_text, strlen(original_text))==0 );
			assert( validation_errors == MR_VALIDATE_UNKNOWN_SIGNATURE );
			free(plain); plain = NULL;

			ok = mrpgp_pk_decrypt(mailbox, ctext_unsigned, ctext_unsigned_bytes, keyring, public_key/*for validate*/, 1, &plain, &plain_bytes, &validation_errors);
			assert( ok && plain && plain_bytes>0 );
			assert( strncmp((char*)plain, original_text, strlen(original_text))==0 );
			assert( validation_errors == MR_VALIDATE_NO_SIGNATURE );
			free(plain); plain = NULL;

			mrkeyring_unref(keyring);
		}

		{
			mrkeyring_t* keyring = mrkeyring_new();
			mrkeyring_add(keyring, private_key2);
			void* plain = NULL;
			int validation_errors = 0;
			int ok = mrpgp_pk_decrypt(mailbox, ctext_signed, ctext_signed_bytes, keyring, public_key/*for validate*/, 1, &plain, &plain_bytes, &validation_errors);
			assert( ok && plain && plain_bytes>0 );
			assert( strcmp(plain, original_text)==0 );
			mrkeyring_unref(keyring);
			free(plain);
		}

		free(ctext_signed);
		free(ctext_unsigned);
		mrkey_unref(public_key2);
		mrkey_unref(private_key2);
		mrkey_unref(public_key);
		mrkey_unref(private_key);
	}
}
