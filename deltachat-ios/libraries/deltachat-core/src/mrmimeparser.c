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
#include "mrmimeparser.h"
#include "mrmimefactory.h"
#include "mruudecode.h"
#include "mrpgp.h"
#include "mrsimplify.h"


/*******************************************************************************
 * debug output
 ******************************************************************************/


#ifdef MR_USE_MIME_DEBUG

/* if you need this functionality, define MR_USE_MIME_DEBUG in the project,
eg. in Codeblocks at "Project / Build options / <project or target> / Compiler settings / #defines" */


static void display_mime_content(struct mailmime_content * content_type);

static void display_mime_data(struct mailmime_data * data)
{
  switch (data->dt_type) {
  case MAILMIME_DATA_TEXT:
    printf("data : %i bytes\n", (int) data->dt_data.dt_text.dt_length);
    break;
  case MAILMIME_DATA_FILE:
    printf("data (file) : %s\n", data->dt_data.dt_filename);
    break;
  }
}

static void display_mime_dsp_parm(struct mailmime_disposition_parm * param)
{
  switch (param->pa_type) {
  case MAILMIME_DISPOSITION_PARM_FILENAME:
    printf("filename: %s\n", param->pa_data.pa_filename);
    break;
  }
}

static void display_mime_disposition(struct mailmime_disposition * disposition)
{
  clistiter * cur;

  for(cur = clist_begin(disposition->dsp_parms) ;
    cur != NULL ; cur = clist_next(cur)) {
    struct mailmime_disposition_parm * param;

    param = (struct mailmime_disposition_parm*)clist_content(cur);
    display_mime_dsp_parm(param);
  }
}

static void display_mime_field(struct mailmime_field * field)
{
	switch (field->fld_type) {
		case MAILMIME_FIELD_VERSION:
			printf("MIME-Version: ...\n");
			break;

		case MAILMIME_FIELD_TYPE:
			printf("content-type: ");
			display_mime_content(field->fld_data.fld_content);
			printf("\n");
			break;

		case MAILMIME_FIELD_DISPOSITION:
			display_mime_disposition(field->fld_data.fld_disposition);
			break;
	}
}

static void display_mime_fields(struct mailmime_fields * fields)
{
	clistiter * cur;

	for(cur = clist_begin(fields->fld_list) ; cur != NULL ; cur = clist_next(cur)) {
		struct mailmime_field * field;

		field = (struct mailmime_field*)clist_content(cur);
		display_mime_field(field);
	}
}

static void display_date_time(struct mailimf_date_time * d)
{
  printf("%02i/%02i/%i %02i:%02i:%02i %+04i",
    d->dt_day, d->dt_month, d->dt_year,
    d->dt_hour, d->dt_min, d->dt_sec, d->dt_zone);
}

static void display_orig_date(struct mailimf_orig_date * orig_date)
{
  display_date_time(orig_date->dt_date_time);
}

static void display_mailbox(struct mailimf_mailbox * mb)
{
  if (mb->mb_display_name != NULL)
    printf("%s ", mb->mb_display_name);
  printf("<%s>", mb->mb_addr_spec);
}

static void display_mailbox_list(struct mailimf_mailbox_list * mb_list)
{
  clistiter * cur;

  for(cur = clist_begin(mb_list->mb_list) ; cur != NULL ;
    cur = clist_next(cur)) {
    struct mailimf_mailbox * mb;

    mb = (struct mailimf_mailbox*)clist_content(cur);

    display_mailbox(mb);
		if (clist_next(cur) != NULL) {
			printf(", ");
		}
  }
}

static void display_group(struct mailimf_group * group)
{
	clistiter * cur;

  printf("%s: ", group->grp_display_name);
  for(cur = clist_begin(group->grp_mb_list->mb_list) ; cur != NULL ; cur = clist_next(cur)) {
    struct mailimf_mailbox * mb;

    mb = (struct mailimf_mailbox*)clist_content(cur);
    display_mailbox(mb);
  }
	printf("; ");
}

static void display_address(struct mailimf_address * a)
{
  switch (a->ad_type) {
    case MAILIMF_ADDRESS_GROUP:
      display_group(a->ad_data.ad_group);
      break;

    case MAILIMF_ADDRESS_MAILBOX:
      display_mailbox(a->ad_data.ad_mailbox);
      break;
  }
}

static void display_address_list(struct mailimf_address_list * addr_list)
{
  clistiter * cur;

  for(cur = clist_begin(addr_list->ad_list) ; cur != NULL ;
    cur = clist_next(cur)) {
    struct mailimf_address * addr;

    addr = (struct mailimf_address*)clist_content(cur);

    display_address(addr);

		if (clist_next(cur) != NULL) {
			printf(", ");
		}
  }
}

static void display_from(struct mailimf_from * from)
{
  display_mailbox_list(from->frm_mb_list);
}

static void display_to(struct mailimf_to * to)
{
  display_address_list(to->to_addr_list);
}

static void display_cc(struct mailimf_cc * cc)
{
  display_address_list(cc->cc_addr_list);
}

static void display_subject(struct mailimf_subject * subject)
{
  printf("%s", subject->sbj_value);
}

static void display_field(struct mailimf_field * field)
{
  switch (field->fld_type)
  {
		case MAILIMF_FIELD_ORIG_DATE:
			printf("Date: ");
			display_orig_date(field->fld_data.fld_orig_date);
			printf("\n");
			break;

		case MAILIMF_FIELD_FROM:
			printf("From: ");
			display_from(field->fld_data.fld_from);
			printf("\n");
			break;

		case MAILIMF_FIELD_TO:
			printf("To: ");
			display_to(field->fld_data.fld_to);
			printf("\n");
			break;

		case MAILIMF_FIELD_CC:
			printf("Cc: ");
			display_cc(field->fld_data.fld_cc);
			printf("\n");
			break;

		case MAILIMF_FIELD_SUBJECT:
			printf("Subject: ");
			display_subject(field->fld_data.fld_subject);
			printf("\n");
			break;

		case MAILIMF_FIELD_MESSAGE_ID:
			printf("Message-ID: %s\n", field->fld_data.fld_message_id->mid_value);
			break;

		case MAILIMF_FIELD_OPTIONAL_FIELD:
			{
				struct mailimf_optional_field* of = field->fld_data.fld_optional_field;
				if( of ) {
					printf("%s: %s\n", of->fld_name? of->fld_name : "?", of->fld_value? of->fld_value : "?");
				}
			}
			break;

		default:
			printf("MAILIMF_FIELD_%i\n", (int)field->fld_type);
			break;
  }
}

static void display_fields(struct mailimf_fields * fields)
{
  clistiter * cur;

  for(cur = clist_begin(fields->fld_list) ; cur != NULL ;
    cur = clist_next(cur)) {
    struct mailimf_field * f;

    f = (struct mailimf_field*)clist_content(cur);

    display_field(f);
  }
}

static void display_mime_discrete_type(struct mailmime_discrete_type * discrete_type)
{
  switch (discrete_type->dt_type) {
  case MAILMIME_DISCRETE_TYPE_TEXT:
    printf("text");
    break;
  case MAILMIME_DISCRETE_TYPE_IMAGE:
    printf("image");
    break;
  case MAILMIME_DISCRETE_TYPE_AUDIO:
    printf("audio");
    break;
  case MAILMIME_DISCRETE_TYPE_VIDEO:
    printf("video");
    break;
  case MAILMIME_DISCRETE_TYPE_APPLICATION:
    printf("application");
    break;
  case MAILMIME_DISCRETE_TYPE_EXTENSION:
    printf("%s", discrete_type->dt_extension);
    break;
  }
}

static void display_mime_composite_type(struct mailmime_composite_type * ct)
{
  switch (ct->ct_type) {
  case MAILMIME_COMPOSITE_TYPE_MESSAGE:
    printf("message");
    break;
  case MAILMIME_COMPOSITE_TYPE_MULTIPART:
    printf("multipart");
    break;
  case MAILMIME_COMPOSITE_TYPE_EXTENSION:
    printf("%s", ct->ct_token);
    break;
  }
}

static void display_mime_type(struct mailmime_type * type)
{
  switch (type->tp_type) {
  case MAILMIME_TYPE_DISCRETE_TYPE:
    display_mime_discrete_type(type->tp_data.tp_discrete_type);
    break;
  case MAILMIME_TYPE_COMPOSITE_TYPE:
    display_mime_composite_type(type->tp_data.tp_composite_type);
    break;
  }
}

static void display_mime_content(struct mailmime_content * content_type)
{
  printf("type: ");
  display_mime_type(content_type->ct_type);
  printf("/%s\n", content_type->ct_subtype);
}

static void print_mime(struct mailmime * mime)
{
	clistiter * cur;

	if( mime == NULL ) {
		printf("ERROR: NULL given to print_mime()\n");
		return;
	}

	switch (mime->mm_type) {
		case MAILMIME_SINGLE:
			printf("single part\n");
			break;
		case MAILMIME_MULTIPLE:
			printf("multipart\n");
			break;
		case MAILMIME_MESSAGE:
			printf("message\n");
			break;
	}

	if (mime->mm_mime_fields != NULL) {
		if (clist_begin(mime->mm_mime_fields->fld_list) != NULL) {
			printf("--------------------------------<mime-headers>--------------------------------\n");
			display_mime_fields(mime->mm_mime_fields);
			printf("--------------------------------</mime-headers>-------------------------------\n");
		}
	}

	display_mime_content(mime->mm_content_type);

	switch (mime->mm_type) {
		case MAILMIME_SINGLE:
			display_mime_data(mime->mm_data.mm_single);
			break;

		case MAILMIME_MULTIPLE:
			for(cur = clist_begin(mime->mm_data.mm_multipart.mm_mp_list) ; cur != NULL ; cur = clist_next(cur)) {
				printf("---------------------------<mime-part-of-multiple>----------------------------\n");
				print_mime((struct mailmime*)clist_content(cur));
				printf("---------------------------</mime-part-of-multiple>---------------------------\n");
			}
			break;

		case MAILMIME_MESSAGE:
			if (mime->mm_data.mm_message.mm_fields) {
				if (clist_begin(mime->mm_data.mm_message.mm_fields->fld_list) != NULL) {
					printf("-------------------------------<email-headers>--------------------------------\n");
					display_fields(mime->mm_data.mm_message.mm_fields);
					printf("-------------------------------</email-headers>-------------------------------\n");
				}

				if (mime->mm_data.mm_message.mm_msg_mime != NULL) {
					printf("----------------------------<mime-part-of-message>----------------------------\n");
					print_mime(mime->mm_data.mm_message.mm_msg_mime);
					printf("----------------------------</mime-part-of-message>---------------------------\n");
				}
			}
			break;
	}
}


void mailmime_print(struct mailmime* mime)
{
	printf("====================================<mime>====================================\n");
	print_mime(mime);
	printf("====================================</mime>===================================\n\n");
}


#endif /* DEBUG_MIME_OUTPUT */


/*******************************************************************************
 * low-level-tools for getting a list of all recipients
 ******************************************************************************/


static void mailimf_get_recipients__add_addr(mrhash_t* recipients, struct mailimf_mailbox* mb)
{
	/* only used internally by mailimf_get_recipients() */
	if( mb )  {
		char* addr_norm = mr_normalize_addr(mb->mb_addr_spec);
		mrhash_insert(recipients, addr_norm, strlen(addr_norm), (void*)1);
		free(addr_norm);
	}
}


mrhash_t* mailimf_get_recipients(struct mailimf_fields* imffields)
{
	/* the returned value must be mrhash_clear()'d and free()'d. returned addresses are normalized. */
	mrhash_t* recipients = malloc(sizeof(mrhash_t));
	mrhash_init(recipients, MRHASH_STRING, 1/*copy key*/);

	clistiter* cur1;
	for( cur1 = clist_begin(imffields->fld_list); cur1!=NULL ; cur1=clist_next(cur1) )
	{
		struct mailimf_field*        fld = (struct mailimf_field*)clist_content(cur1);
		struct mailimf_to*           fld_to;
		struct mailimf_cc*           fld_cc;
		struct mailimf_address_list* addr_list = NULL;
		switch( fld->fld_type )
		{
			case MAILIMF_FIELD_TO: fld_to = fld->fld_data.fld_to; if( fld_to ) { addr_list = fld_to->to_addr_list; } break;
			case MAILIMF_FIELD_CC: fld_cc = fld->fld_data.fld_cc; if( fld_cc ) { addr_list = fld_cc->cc_addr_list; } break;
		}

		if( addr_list ) {
			clistiter* cur2;
			for( cur2 = clist_begin(addr_list->ad_list); cur2!=NULL ; cur2=clist_next(cur2) ) {
				struct mailimf_address* adr = (struct mailimf_address*)clist_content(cur2);
				if( adr ) {
					if( adr->ad_type == MAILIMF_ADDRESS_MAILBOX ) {
						mailimf_get_recipients__add_addr(recipients, adr->ad_data.ad_mailbox);
					}
					else if( adr->ad_type == MAILIMF_ADDRESS_GROUP ) {
						struct mailimf_group* group = adr->ad_data.ad_group;
						if( group && group->grp_mb_list ) {
							clistiter* cur3;
							for( cur3 = clist_begin(group->grp_mb_list->mb_list); cur3!=NULL ; cur3=clist_next(cur3) ) {
								mailimf_get_recipients__add_addr(recipients, (struct mailimf_mailbox*)clist_content(cur3));
							}
						}
					}
				}
			}
		}
	}

	return recipients;
}


/*******************************************************************************
 * low-level-tools for working with mailmime structures directly
 ******************************************************************************/


struct mailmime_parameter* mailmime_find_ct_parameter(struct mailmime* mime, const char* name)
{
	/* find a parameter in `Content-Type: foo/bar; name=value;` */
	if( mime==NULL || name==NULL
	 || mime->mm_content_type==NULL || mime->mm_content_type->ct_parameters==NULL )
	{
		return NULL;
	}

	clistiter* cur;
	for( cur = clist_begin(mime->mm_content_type->ct_parameters); cur != NULL; cur = clist_next(cur) ) {
		struct mailmime_parameter* param = (struct mailmime_parameter*)clist_content(cur);
		if( param && param->pa_name ) {
			if( strcmp(param->pa_name, name)==0 ) {
				return param;
			}
		}
	}

	return NULL;
}


int mailmime_transfer_decode(struct mailmime* mime, const char** ret_decoded_data, size_t* ret_decoded_data_bytes, char** ret_to_mmap_string_unref)
{
	int                   mime_transfer_encoding = MAILMIME_MECHANISM_BINARY;
	struct mailmime_data* mime_data = NULL;
	const char*           decoded_data = NULL; /* must not be free()'d */
	size_t                decoded_data_bytes = 0;
	char*                 transfer_decoding_buffer = NULL; /* mmap_string_unref()'d if set */

	if( mime == NULL || ret_decoded_data == NULL || ret_decoded_data_bytes == NULL || ret_to_mmap_string_unref == NULL
	 || *ret_decoded_data != NULL || *ret_decoded_data_bytes != 0 || *ret_to_mmap_string_unref != NULL ) {
		return 0;
	}

	mime_data = mime->mm_data.mm_single;

	if( mime->mm_mime_fields != NULL ) {
		clistiter* cur;
		for( cur = clist_begin(mime->mm_mime_fields->fld_list); cur != NULL; cur = clist_next(cur) ) {
			struct mailmime_field* field = (struct mailmime_field*)clist_content(cur);
			if( field && field->fld_type == MAILMIME_FIELD_TRANSFER_ENCODING && field->fld_data.fld_encoding ) {
				mime_transfer_encoding = field->fld_data.fld_encoding->enc_type;
				break;
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
			return 0; /* no error - but no data */
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
			return 0;
		}
		decoded_data = transfer_decoding_buffer;
	}

	*ret_decoded_data         = decoded_data;
	*ret_decoded_data_bytes   = decoded_data_bytes;
	*ret_to_mmap_string_unref = transfer_decoding_buffer;
	return 1;
}


struct mailimf_fields* mailmime_find_mailimf_fields(struct mailmime* mime)
{
	if( mime == NULL ) {
		return NULL;
	}

	clistiter* cur;
	switch (mime->mm_type) {
		case MAILMIME_MULTIPLE:
			for(cur = clist_begin(mime->mm_data.mm_multipart.mm_mp_list) ; cur != NULL ; cur = clist_next(cur)) {
				struct mailimf_fields* header = mailmime_find_mailimf_fields(clist_content(cur));
				if( header ) {
					return header;
				}
			}
			break;

		case MAILMIME_MESSAGE:
			return mime->mm_data.mm_message.mm_fields;
	}

	return NULL;
}

char* mailimf_find_first_addr(const struct mailimf_mailbox_list* mb_list)
{
	clistiter* cur;

	if( mb_list == NULL ) {
		return NULL;
	}

	for( cur = clist_begin(mb_list->mb_list); cur!=NULL ; cur=clist_next(cur) ) {
		struct mailimf_mailbox* mb = (struct mailimf_mailbox*)clist_content(cur);
		if( mb && mb->mb_addr_spec ) {
			return mr_normalize_addr(mb->mb_addr_spec);
		}
	}
	return NULL;
}


struct mailimf_field* mailimf_find_field(struct mailimf_fields* header, int wanted_fld_type)
{
	if( header == NULL || header->fld_list == NULL ) {
		return NULL;
	}

	clistiter* cur1;
	for( cur1 = clist_begin(header->fld_list); cur1!=NULL ; cur1=clist_next(cur1) )
	{
		struct mailimf_field* field = (struct mailimf_field*)clist_content(cur1);
		if( field )
		{
			if( field->fld_type == wanted_fld_type ) {
				return field;
			}
		}
	}

	return NULL;
}


struct mailimf_optional_field* mailimf_find_optional_field(struct mailimf_fields* header, const char* wanted_fld_name)
{
	/* Note: the function does not return fields with no value set! */
	if( header == NULL || header->fld_list == NULL ) {
		return NULL;
	}

	clistiter* cur1;
	for( cur1 = clist_begin(header->fld_list); cur1!=NULL ; cur1=clist_next(cur1) )
	{
		struct mailimf_field* field = (struct mailimf_field*)clist_content(cur1);
		if( field && field->fld_type == MAILIMF_FIELD_OPTIONAL_FIELD )
		{
			struct mailimf_optional_field* optional_field = field->fld_data.fld_optional_field;
			if( optional_field && optional_field->fld_name && optional_field->fld_value && strcasecmp(optional_field->fld_name, wanted_fld_name)==0 ) {
				return optional_field;
			}
		}
	}

	return NULL;
}


static int mailmime_is_attachment_disposition(struct mailmime* mime)
{
	if( mime->mm_mime_fields != NULL ) {
		clistiter* cur;
		for( cur = clist_begin(mime->mm_mime_fields->fld_list); cur != NULL; cur = clist_next(cur) ) {
			struct mailmime_field* field = (struct mailmime_field*)clist_content(cur);
			if( field && field->fld_type == MAILMIME_FIELD_DISPOSITION && field->fld_data.fld_disposition ) {
				if( field->fld_data.fld_disposition->dsp_type
				 && field->fld_data.fld_disposition->dsp_type->dsp_type==MAILMIME_DISPOSITION_TYPE_ATTACHMENT )
				{
					return 1;
				}
			}
		}
	}
	return 0;
}


static int mailmime_get_mime_type(struct mailmime* mime, int* msg_type)
{
	#define MR_MIMETYPE_MP_ALTERNATIVE      10
	#define MR_MIMETYPE_MP_RELATED          20
	#define MR_MIMETYPE_MP_MIXED            30
	#define MR_MIMETYPE_MP_NOT_DECRYPTABLE  40
	#define MR_MIMETYPE_MP_REPORT           45
	#define MR_MIMETYPE_MP_SIGNED           46
	#define MR_MIMETYPE_MP_OTHER            50
	#define MR_MIMETYPE_TEXT_PLAIN          60
	#define MR_MIMETYPE_TEXT_HTML           70
	#define MR_MIMETYPE_IMAGE               80
	#define MR_MIMETYPE_AUDIO               90
	#define MR_MIMETYPE_VIDEO              100
	#define MR_MIMETYPE_FILE               110
	#define MR_MIMETYPE_AC_SETUP_FILE      111

	struct mailmime_content* c = mime->mm_content_type;
	int dummy; if( msg_type == NULL ) { msg_type = &dummy; }
	*msg_type = MR_MSG_UNDEFINED;

	if( c == NULL || c->ct_type == NULL ) {
		return 0;
	}

	switch( c->ct_type->tp_type )
	{
		case MAILMIME_TYPE_DISCRETE_TYPE:
			switch( c->ct_type->tp_data.tp_discrete_type->dt_type )
			{
				case MAILMIME_DISCRETE_TYPE_TEXT:
					if( mailmime_is_attachment_disposition(mime) ) {
						; /* MR_MIMETYPE_FILE is returned below - we leave text attachments as attachments as they may be too large to display as a normal message, eg. complete books. */
					}
					else if( strcmp(c->ct_subtype, "plain")==0 ) {
						*msg_type = MR_MSG_TEXT;
						return MR_MIMETYPE_TEXT_PLAIN;
                    }
					else if( strcmp(c->ct_subtype, "html")==0 ) {
						*msg_type = MR_MSG_TEXT;
						return MR_MIMETYPE_TEXT_HTML;
                    }
					*msg_type = MR_MSG_FILE;
					return MR_MIMETYPE_FILE;

				case MAILMIME_DISCRETE_TYPE_IMAGE:
					if( strcmp(c->ct_subtype, "gif")==0 ) {
						*msg_type = MR_MSG_GIF;
					}
					else if( strcmp(c->ct_subtype, "svg+xml")==0 ) {
						*msg_type = MR_MSG_FILE;
						return MR_MIMETYPE_FILE;
					}
					else {
						*msg_type = MR_MSG_IMAGE;
					}
					return MR_MIMETYPE_IMAGE;

				case MAILMIME_DISCRETE_TYPE_AUDIO:
					*msg_type = MR_MSG_AUDIO; /* we correct this later to MR_MSG_VOICE, currently, this is not possible as we do not know the main header */
					return MR_MIMETYPE_AUDIO;

				case MAILMIME_DISCRETE_TYPE_VIDEO:
					*msg_type = MR_MSG_VIDEO;
					return MR_MIMETYPE_VIDEO;

				default:
					*msg_type = MR_MSG_FILE;
					if( c->ct_type->tp_data.tp_discrete_type->dt_type == MAILMIME_DISCRETE_TYPE_APPLICATION
					 && strcmp(c->ct_subtype, "autocrypt-setup")==0 ) {
						return MR_MIMETYPE_AC_SETUP_FILE; /* application/autocrypt-setup */
					}
					return MR_MIMETYPE_FILE;
			}
			break;

		case MAILMIME_TYPE_COMPOSITE_TYPE:
			if( c->ct_type->tp_data.tp_composite_type->ct_type == MAILMIME_COMPOSITE_TYPE_MULTIPART )
			{
				if( strcmp(c->ct_subtype, "alternative")==0 ) {
					return MR_MIMETYPE_MP_ALTERNATIVE;
				}
				else if( strcmp(c->ct_subtype, "related")==0 ) {
					return MR_MIMETYPE_MP_RELATED;
				}
				else if( strcmp(c->ct_subtype, "encrypted")==0 ) {
					return MR_MIMETYPE_MP_NOT_DECRYPTABLE; /* decryptable parts are already converted to other mime parts in mre2ee_decrypt()  */
				}
				else if( strcmp(c->ct_subtype, "signed")==0 ) {
					return MR_MIMETYPE_MP_SIGNED;
				}
				else if( strcmp(c->ct_subtype, "mixed")==0 ) {
					return MR_MIMETYPE_MP_MIXED;
				}
				else if( strcmp(c->ct_subtype, "report")==0 ) {
					return MR_MIMETYPE_MP_REPORT;
				}
				else {
					return MR_MIMETYPE_MP_OTHER;
				}
			}
			else if( c->ct_type->tp_data.tp_composite_type->ct_type == MAILMIME_COMPOSITE_TYPE_MESSAGE )
			{
				/* Enacapsulated messages, see https://www.w3.org/Protocols/rfc1341/7_3_Message.html
				Also used as part "message/disposition-notification" of "multipart/report", which, however, will be handled separatedly.
				I've not seen any messages using this, so we do not attach these parts (maybe they're used to attach replies, which are unwanted at all).

				For now, we skip these parts at all; if desired, we could return MR_MIMETYPE_FILE/MR_MSG_FILE for selected and known subparts. */
				return 0;
			}
			break;

		default:
			break;
	}

	return 0; /* unknown */
}


/*******************************************************************************
 * a MIME part
 ******************************************************************************/


static mrmimepart_t* mrmimepart_new(void)
{
	mrmimepart_t* ths = NULL;

	if( (ths=calloc(1, sizeof(mrmimepart_t)))==NULL ) {
		exit(33);
	}

	ths->m_type    = MR_MSG_UNDEFINED;
	ths->m_param   = mrparam_new();

	return ths;
}


static void mrmimepart_unref(mrmimepart_t* ths)
{
	if( ths == NULL ) {
		return;
	}

	if( ths->m_msg ) {
		free(ths->m_msg);
		ths->m_msg = NULL;
	}

	if( ths->m_msg_raw ) {
		free(ths->m_msg_raw);
		ths->m_msg_raw = NULL;
	}

	mrparam_unref(ths->m_param);
	free(ths);
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


/**
 * Create a new mime parser object.
 *
 * @private @memberof mrmimeparser_t
 *
 * @param blobdir Directrory to write attachments to.
 * @param mailbox Mailbox object, used for logging only.
 *
 * @return The MIME-parser object.
 */
mrmimeparser_t* mrmimeparser_new(const char* blobdir, mrmailbox_t* mailbox)
{
	mrmimeparser_t* ths = NULL;

	if( (ths=calloc(1, sizeof(mrmimeparser_t)))==NULL ) {
		exit(30);
	}

	ths->m_mailbox = mailbox;
	ths->m_parts   = carray_new(16);
	ths->m_blobdir = blobdir; /* no need to copy the string at the moment */
	ths->m_reports = carray_new(16);
	ths->m_e2ee_helper = calloc(1, sizeof(mrmailbox_e2ee_helper_t));

	mrhash_init(&ths->m_header, MRHASH_STRING, 0/* do not copy key */);

	return ths;
}


/**
 * Free a MIME-parser object.
 *
 * Esp. all data allocated by mrmimeparser_parse() will be free()'d.
 *
 * @private @memberof mrmimeparser_t
 *
 * @param ths The MIME-parser object.
 *
 * @return None.
 */
void mrmimeparser_unref(mrmimeparser_t* ths)
{
	if( ths == NULL ) {
		return;
	}

	mrmimeparser_empty(ths);
	if( ths->m_parts )   { carray_free(ths->m_parts); }
	if( ths->m_reports ) { carray_free(ths->m_reports); }
	free(ths->m_e2ee_helper);
	free(ths);
}


/**
 * Empty all data in a MIME-parser object.
 *
 * This function is called implicitly by mrmimeparser_parse() to free
 * previously allocated data.
 *
 * @private @memberof mrmimeparser_t
 *
 * @param ths The MIME-parser object.
 *
 * @return None.
 */
void mrmimeparser_empty(mrmimeparser_t* ths)
{
	if( ths == NULL ) {
		return;
	}

	if( ths->m_parts )
	{
		int i, cnt = carray_count(ths->m_parts);
		for( i = 0; i < cnt; i++ ) {
			mrmimepart_t* part = (mrmimepart_t*)carray_get(ths->m_parts, i);
			if( part ) {
				mrmimepart_unref(part);
			}
		}
		carray_set_size(ths->m_parts, 0);
	}

	ths->m_header_root  = NULL; /* a pointer somewhere to the MIME data, must NOT be freed */
	mrhash_clear(&ths->m_header);

	if( ths->m_header_protected ) {
		mailimf_fields_free(ths->m_header_protected); /* allocated as needed, MUST be freed */
		ths->m_header_protected = NULL;
	}

	ths->m_is_send_by_messenger  = 0;
	ths->m_is_system_message = 0;

	free(ths->m_subject);
	ths->m_subject = NULL;

	if( ths->m_mimeroot )
	{
		mailmime_free(ths->m_mimeroot);
		ths->m_mimeroot = NULL;
	}

	ths->m_is_forwarded = 0;

	if( ths->m_reports ) {
		carray_set_size(ths->m_reports, 0);
	}

	ths->m_decrypting_failed = 0;

	mrmailbox_e2ee_thanks(ths->m_e2ee_helper);
}


static void do_add_single_part(mrmimeparser_t* parser, mrmimepart_t* part)
{
	/* add a single part to the list of parts, the parser takes the ownership of the part, so you MUST NOT unref it after calling this function. */
	if( parser->m_e2ee_helper->m_encrypted && mrhash_count(parser->m_e2ee_helper->m_signatures)>0 ) {
		mrparam_set_int(part->m_param, MRP_GUARANTEE_E2EE, 1);
	}
	else if( parser->m_e2ee_helper->m_encrypted ) {
		mrparam_set_int(part->m_param, MRP_ERRONEOUS_E2EE, MRE2EE_NO_VALID_SIGNATURE);
	}
	carray_add(parser->m_parts, (void*)part, NULL);
}


static void do_add_single_file_part(mrmimeparser_t* parser, int msg_type, int mime_type,
                                    const char* decoded_data, size_t decoded_data_bytes,
                                    const char* desired_filename)
{
	mrmimepart_t* part = NULL;
	char*         pathNfilename = NULL;

	/* create a free file name to use */
	if( (pathNfilename=mr_get_fine_pathNfilename(parser->m_blobdir, desired_filename)) == NULL ) {
		goto cleanup;
	}

	/* copy data to file */
	if( mr_write_file(pathNfilename, decoded_data, decoded_data_bytes, parser->m_mailbox)==0 ) {
		goto cleanup;
	}

	part = mrmimepart_new();
	part->m_type  = msg_type;
	part->m_int_mimetype = mime_type;
	part->m_bytes = decoded_data_bytes;
	mrparam_set(part->m_param, MRP_FILE, pathNfilename);
	if( MR_MSG_MAKE_FILENAME_SEARCHABLE(msg_type) ) {
		part->m_msg = mr_get_filename(pathNfilename);
	}
	else if( MR_MSG_MAKE_SUFFIX_SEARCHABLE(msg_type) ) {
		part->m_msg = mr_get_filesuffix_lc(pathNfilename);
	}

	if( mime_type == MR_MIMETYPE_IMAGE ) {
		uint32_t w = 0, h = 0;
		if( mr_get_filemeta(decoded_data, decoded_data_bytes, &w, &h) ) {
			mrparam_set_int(part->m_param, MRP_WIDTH, w);
			mrparam_set_int(part->m_param, MRP_HEIGHT, h);
		}
	}

	/* split author/title from the original filename (if we do it from the real filename, we'll also get numbers appended by mr_get_fine_pathNfilename()) */
	if( msg_type == MR_MSG_AUDIO ) {
		char* author = NULL, *title = NULL;
		mrmsg_get_authorNtitle_from_filename(desired_filename, &author, &title);
		mrparam_set(part->m_param, MRP_AUTHORNAME, author);
		mrparam_set(part->m_param, MRP_TRACKNAME, title);
		free(author);
		free(title);
	}

	do_add_single_part(parser, part);
	part = NULL;

cleanup:
	free(pathNfilename);
	mrmimepart_unref(part);
}


static int mrmimeparser_add_single_part_if_known(mrmimeparser_t* ths, struct mailmime* mime)
{
	mrmimepart_t*                part = NULL;
	int                          old_part_count = carray_count(ths->m_parts);

	int                          mime_type;
	struct mailmime_data*        mime_data;
	char*                        file_suffix = NULL, *desired_filename = NULL;
	int                          msg_type;

	char*                        transfer_decoding_buffer = NULL; /* mmap_string_unref()'d if set */
	char*                        charset_buffer = NULL; /* charconv_buffer_free()'d if set (just calls mmap_string_unref()) */
	const char*                  decoded_data = NULL; /* must not be free()'d */
	size_t                       decoded_data_bytes = 0;
	mrsimplify_t*                simplifier = NULL;

	if( mime == NULL || mime->mm_data.mm_single == NULL ) {
		goto cleanup;
	}

	/* get mime type from `mime` */
	mime_type = mailmime_get_mime_type(mime, &msg_type);

	/* get data pointer from `mime` */
	mime_data = mime->mm_data.mm_single;
	if( mime_data->dt_type != MAILMIME_DATA_TEXT   /* MAILMIME_DATA_FILE indicates, the data is in a file; AFAIK this is not used on parsing */
	 || mime_data->dt_data.dt_text.dt_data == NULL
	 || mime_data->dt_data.dt_text.dt_length <= 0 ) {
		goto cleanup;
	}


	/* regard `Content-Transfer-Encoding:` */
	if( !mailmime_transfer_decode(mime, &decoded_data, &decoded_data_bytes, &transfer_decoding_buffer) ) {
		goto cleanup; /* no always error - but no data */
	}

	switch( mime_type )
	{
		case MR_MIMETYPE_TEXT_PLAIN:
		case MR_MIMETYPE_TEXT_HTML:
			{
				if( simplifier==NULL ) {
					simplifier = mrsimplify_new();
					if( simplifier==NULL ) {
						goto cleanup;
					}
				}

				const char* charset = mailmime_content_charset_get(mime->mm_content_type); /* get from `Content-Type: text/...; charset=utf-8`; must not be free()'d */
				if( charset!=NULL && strcmp(charset, "utf-8")!=0 && strcmp(charset, "UTF-8")!=0 ) {
					size_t ret_bytes = 0;
					int r = charconv_buffer("utf-8", charset, decoded_data, decoded_data_bytes, &charset_buffer, &ret_bytes);
					if( r != MAIL_CHARCONV_NO_ERROR ) {
						mrmailbox_log_warning(ths->m_mailbox, 0, "Cannot convert %i bytes from \"%s\" to \"utf-8\"; errorcode is %i.", /* if this warning comes up for usual character sets, maybe libetpan is compiled without iconv? */
							(int)decoded_data_bytes, charset, (int)r); /* continue, however */
					}
					else if( charset_buffer==NULL || ret_bytes <= 0 ) {
						goto cleanup; /* no error - but nothing to add */
					}
					else  {
						decoded_data = charset_buffer;
						decoded_data_bytes = ret_bytes;
					}
				}

				// add uuencoded stuff as MR_MSG_FILE/MR_MSG_IMAGE/etc. parts
				char* txt = strndup(decoded_data, decoded_data_bytes);
				{
					char*  uu_blob = NULL, *uu_filename = NULL, *new_txt = NULL;
					size_t uu_blob_bytes = 0;
					int    uu_msg_type = 0, added_uu_parts = 0;
					while( (new_txt=mruudecode_do(txt, &uu_blob, &uu_blob_bytes, &uu_filename)) != NULL )
					{
						mrmsg_guess_msgtype_from_suffix(uu_filename, &uu_msg_type, NULL);
						if( uu_msg_type == 0 ) {
							uu_msg_type = MR_MSG_FILE;
						}

						do_add_single_file_part(ths, uu_msg_type, 0, uu_blob, uu_blob_bytes, uu_filename);

						free(txt);         txt = new_txt; new_txt = NULL;
						free(uu_blob);     uu_blob = NULL; uu_blob_bytes = 0; uu_msg_type = 0;
						free(uu_filename); uu_filename = NULL;

						added_uu_parts++;
						if( added_uu_parts > 50/*fence against endless loops*/ ) {
							break;
						}
					}
				}

				// add text as MR_MSG_TEXT part
				char* simplified_txt = mrsimplify_simplify(simplifier, txt, strlen(txt), mime_type==MR_MIMETYPE_TEXT_HTML? 1 : 0);
				free(txt);
				txt = NULL;
				if( simplified_txt && simplified_txt[0] )
				{
					part = mrmimepart_new();
					part->m_type = MR_MSG_TEXT;
					part->m_int_mimetype = mime_type;
					part->m_msg = simplified_txt;
					part->m_msg_raw = strndup(decoded_data, decoded_data_bytes);
					do_add_single_part(ths, part);
					part = NULL;
				}
				else
				{
					free(simplified_txt);
				}

				if( simplifier->m_is_forwarded ) {
					ths->m_is_forwarded = 1;
				}
			}
			break;

		case MR_MIMETYPE_IMAGE:
		case MR_MIMETYPE_AUDIO:
		case MR_MIMETYPE_VIDEO:
		case MR_MIMETYPE_FILE:
		case MR_MIMETYPE_AC_SETUP_FILE:
			{
				/* get desired file name */
				struct mailmime_disposition* file_disposition = NULL; /* must not be free()'d */
				clistiter* cur;
				for( cur = clist_begin(mime->mm_mime_fields->fld_list); cur != NULL; cur = clist_next(cur) ) {
					struct mailmime_field* field = (struct mailmime_field*)clist_content(cur);
					if( field && field->fld_type == MAILMIME_FIELD_DISPOSITION && field->fld_data.fld_disposition ) {
						file_disposition = field->fld_data.fld_disposition;
						break;
					}
				}

				if( file_disposition ) {
					for( cur = clist_begin(file_disposition->dsp_parms); cur != NULL; cur = clist_next(cur) ) {
						struct mailmime_disposition_parm* dsp_param = (struct mailmime_disposition_parm*)clist_content(cur);
						if( dsp_param ) {
							if( dsp_param->pa_type==MAILMIME_DISPOSITION_PARM_FILENAME ) {
								desired_filename = safe_strdup(dsp_param->pa_data.pa_filename);
							}
						}
					}
				}

				if( desired_filename==NULL ) {
					struct mailmime_parameter* param = mailmime_find_ct_parameter(mime, "name");
					if( param && param->pa_value && param->pa_value[0] ) {
						desired_filename = safe_strdup(param->pa_value);
					}
				}

				if( desired_filename==NULL ) {
					if( mime->mm_content_type && mime->mm_content_type->ct_subtype ) {
						desired_filename = mr_mprintf("file.%s", mime->mm_content_type->ct_subtype);
					}
					else {
						goto cleanup;
					}
				}

				mr_replace_bad_utf8_chars(desired_filename);

				do_add_single_file_part(ths, msg_type, mime_type, decoded_data, decoded_data_bytes, desired_filename);
			}
			break;

		default:
			break;
	}

	/* add object? (we do not add all objetcs, eg. signatures etc. are ignored) */
cleanup:
	mrsimplify_unref(simplifier);
	if( charset_buffer ) { charconv_buffer_free(charset_buffer); }
	if( transfer_decoding_buffer ) { mmap_string_unref(transfer_decoding_buffer); }
	free(file_suffix);
	free(desired_filename);
	mrmimepart_unref(part);

	return carray_count(ths->m_parts)>old_part_count? 1 : 0; /* any part added? */
}


static int mrmimeparser_parse_mime_recursive(mrmimeparser_t* ths, struct mailmime* mime)
{
	int        any_part_added = 0;
	clistiter* cur;

	if( ths == NULL || mime == NULL ) {
		return 0;
	}

	if( mailmime_find_ct_parameter(mime, "protected-headers") )
	{
		if( mime->mm_type==MAILMIME_SINGLE
		 && mime->mm_content_type->ct_type->tp_type==MAILMIME_TYPE_DISCRETE_TYPE
		 && mime->mm_content_type->ct_type->tp_data.tp_discrete_type->dt_type==MAILMIME_DISCRETE_TYPE_TEXT
		 && mime->mm_content_type->ct_subtype
		 && strcmp(mime->mm_content_type->ct_subtype, "rfc822-headers")==0 ) {
			mrmailbox_log_info(ths->m_mailbox, 0, "Protected headers found in text/rfc822-headers attachment: Will be ignored."); /* we want the protected headers in the normal header of the payload */
			return 0;
		}

		if( ths->m_header_protected==NULL ) { /* use the most outer protected header - this is typically created in sync with the normal, unprotected header */
			size_t dummy = 0;
			if( mailimf_envelope_and_optional_fields_parse(mime->mm_mime_start, mime->mm_length, &dummy, &ths->m_header_protected)==MAILIMF_NO_ERROR // what is the difference between mailimf_envelope_and_optional_fields_parse() mailimf_fields_parse()
			 && ths->m_header_protected!=NULL ) {
				mrmailbox_log_info(ths->m_mailbox, 0, "Protected headers found in MIME header: Will be used.");
			}
		}
		else {
			mrmailbox_log_info(ths->m_mailbox, 0, "Protected headers found in MIME header: Will be ignored as we already found an outer one.");
		}
	}

	switch( mime->mm_type )
	{
		case MAILMIME_SINGLE:
			any_part_added = mrmimeparser_add_single_part_if_known(ths, mime);
			break;

		case MAILMIME_MULTIPLE:
			switch( mailmime_get_mime_type(mime, NULL) )
			{
				case MR_MIMETYPE_MP_ALTERNATIVE: /* add "best" part */
					/* Most times, mutlipart/alternative contains true alternatives as text/plain and text/html.
					If we find a multipart/mixed inside mutlipart/alternative, we use this (happens eg in apple mail: "plaintext" as an alternative to "html+PDF attachment") */
					for( cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list); cur!=NULL; cur=clist_next(cur)) {
						struct mailmime* childmime = (struct mailmime*)clist_content(cur);
						if( mailmime_get_mime_type(childmime, NULL) == MR_MIMETYPE_MP_MIXED ) {
							any_part_added = mrmimeparser_parse_mime_recursive(ths, childmime);
							break;
						}
					}


					if( !any_part_added ) {
						/* search for text/plain and add this */
						for( cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list); cur!=NULL; cur=clist_next(cur)) {
							struct mailmime* childmime = (struct mailmime*)clist_content(cur);
							if( mailmime_get_mime_type(childmime, NULL) == MR_MIMETYPE_TEXT_PLAIN ) {
								any_part_added = mrmimeparser_parse_mime_recursive(ths, childmime);
								break;
							}
						}
					}

					if( !any_part_added ) { /* `text/plain` not found - use the first part */
						for( cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list); cur!=NULL; cur=clist_next(cur)) {
							if( mrmimeparser_parse_mime_recursive(ths, (struct mailmime*)clist_content(cur)) ) {
								any_part_added = 1;
								break; /* out of for() */
							}
						}
					}
					break;

				case MR_MIMETYPE_MP_RELATED: /* add the "root part" - the other parts may be referenced which is not interesting for us (eg. embedded images) */
				                             /* we assume he "root part" being the first one, which may not be always true ... however, most times it seems okay. */
					cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list);
					if( cur ) {
						any_part_added = mrmimeparser_parse_mime_recursive(ths, (struct mailmime*)clist_content(cur));
					}
					break;

				case MR_MIMETYPE_MP_NOT_DECRYPTABLE:
					{
						mrmimepart_t* part = mrmimepart_new();
						part->m_type = MR_MSG_TEXT;

						char* msg_body = mrstock_str(MR_STR_CANTDECRYPT_MSG_BODY);
						part->m_msg = mr_mprintf(MR_EDITORIAL_OPEN "%s" MR_EDITORIAL_CLOSE, msg_body);
						free(msg_body);

						carray_add(ths->m_parts, (void*)part, NULL);
						any_part_added = 1;
						ths->m_decrypting_failed = 1;
					}
					break;

				case MR_MIMETYPE_MP_SIGNED:
					/* RFC 1847: "The multipart/signed content type contains exactly two body parts.
					The first body part is the body part over which the digital signature was created [...]
					The second body part contains the control information necessary to verify the digital signature."
					We simpliy take the first body part and skip the rest.
					(see https://k9mail.github.io/2016/11/24/OpenPGP-Considerations-Part-I.html for background information why we use encrypted+signed) */
					if( (cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list)) != NULL )
					{
						any_part_added = mrmimeparser_parse_mime_recursive(ths, (struct mailmime*)clist_content(cur));
					}
					break;

				case MR_MIMETYPE_MP_REPORT:
					if( clist_count(mime->mm_data.mm_multipart.mm_mp_list) >= 2 ) /* RFC 6522: the first part is for humans, the second for machines */
					{
						struct mailmime_parameter* report_type = mailmime_find_ct_parameter(mime, "report-type");
						if( report_type && report_type->pa_value
						 && strcmp(report_type->pa_value, "disposition-notification") == 0 )
						{
							carray_add(ths->m_reports, (void*)mime, NULL);
						}
						else
						{
							/* eg. `report-type=delivery-status`; maybe we should show them as a little error icon */
							any_part_added = mrmimeparser_parse_mime_recursive(ths, (struct mailmime*)clist_content(clist_begin(mime->mm_data.mm_multipart.mm_mp_list)));
						}
					}
					break;

				default: /* eg. MR_MIME_MP_MIXED - add all parts (in fact, AddSinglePartIfKnown() later check if the parts are really supported) */
					{
						/* HACK: the following lines are a hack for clients who use multipart/mixed instead of multipart/alternative for
						combined text/html messages (eg. Stock Android "Mail" does so).  So, if I detect such a message below, I skip the HTML part.
						However, I'm not sure, if there are useful situations to use plain+html in multipart/mixed - if so, we should disable the hack. */
						struct mailmime* skip_part = NULL;
						{
							struct mailmime* html_part = NULL;
							int plain_cnt = 0, html_cnt = 0;
							for( cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list); cur!=NULL; cur=clist_next(cur)) {
								struct mailmime* childmime = (struct mailmime*)clist_content(cur);
								if( mailmime_get_mime_type(childmime, NULL) == MR_MIMETYPE_TEXT_PLAIN ) {
									plain_cnt++;
								}
								else if( mailmime_get_mime_type(childmime, NULL) == MR_MIMETYPE_TEXT_HTML ) {
									html_part = childmime;
									html_cnt++;
								}
							}
							if( plain_cnt==1 && html_cnt==1 )  {
								mrmailbox_log_warning(ths->m_mailbox, 0, "HACK: multipart/mixed message found with PLAIN and HTML, we'll skip the HTML part as this seems to be unwanted.");
								skip_part = html_part;
							}
						}
						/* /HACK */

						for( cur=clist_begin(mime->mm_data.mm_multipart.mm_mp_list); cur!=NULL; cur=clist_next(cur)) {
							struct mailmime* childmime = (struct mailmime*)clist_content(cur);
							if( childmime != skip_part ) {
								if( mrmimeparser_parse_mime_recursive(ths, childmime) ) {
									any_part_added = 1;
								}
							}
						}
					}
					break;
			}
			break;

		case MAILMIME_MESSAGE:
			if( ths->m_header_root == NULL )
			{
				ths->m_header_root = mime->mm_data.mm_message.mm_fields;
			}

			if( mime->mm_data.mm_message.mm_msg_mime )
			{
				any_part_added = mrmimeparser_parse_mime_recursive(ths, mime->mm_data.mm_message.mm_msg_mime);
			}
			break;
	}

	return any_part_added;
}


static void hash_header(mrhash_t* out, const struct mailimf_fields* in, mrmailbox_t* mailbox)
{
	if( in == NULL ) {
		return;
	}

	clistiter* cur1;
	for( cur1 = clist_begin(in->fld_list); cur1!=NULL ; cur1=clist_next(cur1) )
	{
		struct mailimf_field* field = (struct mailimf_field*)clist_content(cur1);
		const char *key = NULL;
		switch( field->fld_type )
		{
			case MAILIMF_FIELD_RETURN_PATH: key = "Return-Path"; break;
			case MAILIMF_FIELD_ORIG_DATE:   key = "Date";        break;
			case MAILIMF_FIELD_FROM:        key = "From";        break;
			case MAILIMF_FIELD_SENDER:      key = "Sender";      break;
			case MAILIMF_FIELD_REPLY_TO:    key = "Reply-To";    break;
			case MAILIMF_FIELD_TO:          key = "To";          break;
			case MAILIMF_FIELD_CC:          key = "Cc";          break;
			case MAILIMF_FIELD_BCC:         key = "Bcc";         break;
			case MAILIMF_FIELD_MESSAGE_ID:  key = "Message-ID";  break;
			case MAILIMF_FIELD_IN_REPLY_TO: key = "In-Reply-To"; break;
			case MAILIMF_FIELD_REFERENCES:  key = "References";  break;
			case MAILIMF_FIELD_SUBJECT:     key = "Subject";     break;
			case MAILIMF_FIELD_OPTIONAL_FIELD:
				{
					const struct mailimf_optional_field* optional_field = field->fld_data.fld_optional_field;
					if( optional_field ) {
						key = optional_field->fld_name;
					}
				}
				break;
		}

		if( key )
		{
			int key_len = strlen(key);

			if( mrhash_find(out, key, key_len) )
			{
				/* key already in hash, do only overwrite known types */
				if( field->fld_type!=MAILIMF_FIELD_OPTIONAL_FIELD
				 || (key_len>5 && strncasecmp(key, "Chat-", 5)==0) )
				{
					mrmailbox_log_info(mailbox, 0, "Protected headers: Overwriting \"%s\".", key);
					mrhash_insert(out, key, key_len, field);
				}
			}
			else
			{
				/* key not hashed before */
				mrhash_insert(out, key, key_len, field);
			}
		}
	}
}


/**
 * Parse raw MIME-data into a MIME-object.
 *
 * You may call this function several times on the same object; old data are cleared using
 * mrmimeparser_empty() before parsing is started.
 *
 * After mrmimeparser_parse() is called successfully, all the functions to get information about the
 * MIME-structure will work.
 *
 * @private @memberof mrmimeparser_t
 *
 * @param ths The MIME-parser object.
 * @param body_not_terminated Plain text, no need to be null-terminated.
 * @param body_bytes The number of bytes to read from body_not_terminated.
 *     body_not_terminated is null-terminated, use strlen(body_not_terminated) here.
 *
 * @return None.
 */
void mrmimeparser_parse(mrmimeparser_t* ths, const char* body_not_terminated, size_t body_bytes)
{
	int r;
	size_t index = 0;

	mrmimeparser_empty(ths);

	/* parse body */
	r = mailmime_parse(body_not_terminated, body_bytes, &index, &ths->m_mimeroot);
	if(r != MAILIMF_NO_ERROR || ths->m_mimeroot == NULL ) {
		goto cleanup;
	}

	//printf("before decryption:\n"); mailmime_print(ths->m_mimeroot);

	/* decrypt, if possible; handle Autocrypt:-header
	(decryption may modifiy the given object) */
	mrmailbox_e2ee_decrypt(ths->m_mailbox, ths->m_mimeroot, ths->m_e2ee_helper);

	//printf("after decryption:\n"); mailmime_print(ths->m_mimeroot);

	/* recursively check, whats parsed, this also sets up m_header_old */
	mrmimeparser_parse_mime_recursive(ths, ths->m_mimeroot);

	// TOCHECK: text parts may be moved to the beginning of the list - either here or in do_add_single_part()
	//       usecase: eg. the Buchungsbestätigungen of Deutsch Bahn have the PDF before the explaining text.
	//       may also be handy for extracting binaries from uuencoded text and just add the rest text after the binaries.

	/* setup header */
	hash_header(&ths->m_header, ths->m_header_root, ths->m_mailbox);
	hash_header(&ths->m_header, ths->m_header_protected, ths->m_mailbox); /* overwrite the original header with the protected one */

	/* set some basic data */
	{
		struct mailimf_field* field = mrmimeparser_lookup_field(ths, "Subject");
		if( field && field->fld_type == MAILIMF_FIELD_SUBJECT ) {
			ths->m_subject = mr_decode_header_string(field->fld_data.fld_subject->sbj_value);
		}
	}

	if( mrmimeparser_lookup_optional_field2(ths, "Chat-Version", "X-MrMsg") ) {
		ths->m_is_send_by_messenger = 1;
	}

	if( mrmimeparser_lookup_field(ths, "Autocrypt-Setup-Message") ) {
		/* Autocrypt-Setup-Message header found - check if there is an application/autocrypt-setup part */
		int i, has_setup_file = 0;
		for( i = 0; i < carray_count(ths->m_parts); i++ ) {
			mrmimepart_t* part = (mrmimepart_t*)carray_get(ths->m_parts, i);
			if( part->m_int_mimetype==MR_MIMETYPE_AC_SETUP_FILE ) {
				has_setup_file = 1;
			}
		}
		if( has_setup_file ) {
			/* delete all parts but the application/autocrypt-setup part */
			ths->m_is_system_message = MR_CMD_AUTOCRYPT_SETUP_MESSAGE;
			for( i = 0; i < carray_count(ths->m_parts); i++ ) {
				mrmimepart_t* part = (mrmimepart_t*)carray_get(ths->m_parts, i);
				if( part->m_int_mimetype!=MR_MIMETYPE_AC_SETUP_FILE ) {
					mrmimepart_unref(part);
					carray_delete_slow(ths->m_parts, i);
					i--; /* start over with the same index */
				}
			}
		}
		ths->m_is_send_by_messenger = 0; /* do not treat a setup message as a messenger message (eg. do not move setup messages to the Chats-folder; there may be a 3rd device that wants to handle it) */
	}

	/* prepend subject to message? */
	if( ths->m_subject )
	{
		int prepend_subject = 1;
		if( !ths->m_decrypting_failed /* if decryption has failed, we always prepend the subject as this may contain cleartext hints from non-Delta MUAs. */ )
		{
			char* p = strchr(ths->m_subject, ':');
			if( (p-ths->m_subject) == 2 /*Re: etc.*/
			 || (p-ths->m_subject) == 3 /*Fwd: etc.*/
			 || ths->m_is_send_by_messenger
			 || strstr(ths->m_subject, MR_CHAT_PREFIX)!=NULL ) {
				prepend_subject = 0;
			}
		}

		if( prepend_subject )
		{
			char* subj = safe_strdup(ths->m_subject);
			char* p = strchr(subj, '['); /* do not add any tags as "[checked by XYZ]" */
			if( p ) {
				*p = 0;
			}
			mr_trim(subj);
			if( subj[0] ) {
				int i, icnt = carray_count(ths->m_parts); /* should be at least one - maybe empty - part */
				for( i = 0; i < icnt; i++ ) {
					mrmimepart_t* part = (mrmimepart_t*)carray_get(ths->m_parts, i);
					if( part->m_type == MR_MSG_TEXT ) {
						#define MR_NDASH "\xE2\x80\x93"
						char* new_txt = mr_mprintf("%s " MR_NDASH " %s", subj, part->m_msg);
						free(part->m_msg);
						part->m_msg = new_txt;
						break;
					}
				}
			}
			free(subj);
		}
	}

	/* add forward information to every part */
	if( ths->m_is_forwarded ) {
		int i, icnt = carray_count(ths->m_parts); /* should be at least one - maybe empty - part */
		for( i = 0; i < icnt; i++ ) {
			mrmimepart_t* part = (mrmimepart_t*)carray_get(ths->m_parts, i);
			mrparam_set_int(part->m_param, MRP_FORWARDED, 1);
		}
	}

	if( carray_count(ths->m_parts)==1 )
	{
		/* mark audio as voice message, if appropriate (we have to do this on global level as we do not know the global header in the recursice parse).
		and read some additional parameters */
		mrmimepart_t* part = (mrmimepart_t*)carray_get(ths->m_parts, 0);
		if( part->m_type == MR_MSG_AUDIO ) {
			if( mrmimeparser_lookup_optional_field2(ths, "Chat-Voice-Message", "X-MrVoiceMessage") ) {
				free(part->m_msg);
				part->m_msg = strdup("ogg"); /* MR_MSG_AUDIO adds sets the whole filename which is useless. however, the extension is useful. */
				part->m_type = MR_MSG_VOICE;
				mrparam_set(part->m_param, MRP_AUTHORNAME, NULL); /* remove unneeded information */
				mrparam_set(part->m_param, MRP_TRACKNAME, NULL);
			}
		}

		if( part->m_type == MR_MSG_AUDIO || part->m_type == MR_MSG_VOICE || part->m_type == MR_MSG_VIDEO ) {
			const struct mailimf_optional_field* field = mrmimeparser_lookup_optional_field2(ths, "Chat-Duration", "X-MrDurationMs");
			if( field ) {
				int duration_ms = atoi(field->fld_value);
				if( duration_ms > 0 && duration_ms < 24*60*60*1000 ) {
					mrparam_set_int(part->m_param, MRP_DURATION, duration_ms);
				}
			}
		}
	}

	/* some special system message? */
	if( mrmimeparser_lookup_field(ths, "Chat-Group-Image")
	 && carray_count(ths->m_parts)>=1 ) {
		mrmimepart_t* textpart = (mrmimepart_t*)carray_get(ths->m_parts, 0);
		if( textpart->m_type == MR_MSG_TEXT ) {
			mrparam_set_int(textpart->m_param, MRP_CMD, MR_CMD_GROUPIMAGE_CHANGED);
			if( carray_count(ths->m_parts)>=2 ) {
				mrmimepart_t* imgpart = (mrmimepart_t*)carray_get(ths->m_parts, 1);
				if( imgpart->m_type == MR_MSG_IMAGE ) {
					imgpart->m_is_meta = 1;
				}
			}
		}
	}

	/* check, if the message asks for a MDN */
	if( !ths->m_decrypting_failed )
	{
		const struct mailimf_optional_field* dn_field = mrmimeparser_lookup_optional_field(ths, "Chat-Disposition-Notification-To"); /* we use "Chat-Disposition-Notification-To" as replies to "Disposition-Notification-To" are weired in many cases, are just freetext and/or do not follow any standard. */
		if( dn_field && mrmimeparser_get_last_nonmeta(ths)/*just check if the mail is not empty*/ )
		{
			struct mailimf_mailbox_list* mb_list = NULL;
			size_t index = 0;
			if( mailimf_mailbox_list_parse(dn_field->fld_value, strlen(dn_field->fld_value), &index, &mb_list)==MAILIMF_NO_ERROR && mb_list )
			{
				char* dn_to_addr = mailimf_find_first_addr(mb_list);
				if( dn_to_addr )
				{
					struct mailimf_field* from_field = mrmimeparser_lookup_field(ths, "From"); /* we need From: as this MUST match Disposition-Notification-To: */
					if( from_field && from_field->fld_type==MAILIMF_FIELD_FROM && from_field->fld_data.fld_from )
					{
						char* from_addr = mailimf_find_first_addr(from_field->fld_data.fld_from->frm_mb_list);
						if( from_addr )
						{
							if( strcmp(from_addr, dn_to_addr)==0 )
							{
								/* we mark _only_ the _last_ part to send a MDN
								(this avoids trouble with multi-part-messages who should send only one MDN.
								Moreover the last one is handy as it is the one typically displayed if the message is larger) */
								mrmimepart_t* part = mrmimeparser_get_last_nonmeta(ths);
								if( part ) {
									mrparam_set_int(part->m_param, MRP_WANTS_MDN, 1);
								}
							}
							free(from_addr);
						}
					}
					free(dn_to_addr);
				}
				mailimf_mailbox_list_free(mb_list);
			}
		}
	}

	/* Cleanup - and try to create at least an empty part if there are no parts yet */
cleanup:
	if( !mrmimeparser_has_nonmeta(ths) && carray_count(ths->m_reports)==0 ) {
		mrmimepart_t* part = mrmimepart_new();
		part->m_type = MR_MSG_TEXT;
		part->m_msg = safe_strdup(ths->m_subject? ths->m_subject : "Empty message");
		carray_add(ths->m_parts, (void*)part, NULL);
	}
}


/**
 * Lookup the given field name.
 *
 * Typical names are `From`, `To`, `Subject` and so on.
 *
 * @private @memberof mrmimeparser_t
 *
 * @param mimparser The MIME-parser object.
 * @param field_name The name of the field to look for.
 *
 * @return A pointer to a mailimf_field structure. Must not be freed!
 *     Before accessing the mailimf_field::fld_data, please always have a look at mailimf_field::fld_type!
 *     If field_name could not be found, NULL is returned.
 */
struct mailimf_field* mrmimeparser_lookup_field(mrmimeparser_t* mimeparser, const char* field_name)
{
	return (struct mailimf_field*)mrhash_find_str(&mimeparser->m_header, field_name);
}


/**
 * Lookup the given field name.
 *
 * In addition to mrmimeparser_lookup_field, this function also checks the mailimf_field::fld_type
 * for being MAILIMF_FIELD_OPTIONAL_FIELD.
 *
 * @private @memberof mrmimeparser_t
 *
 * @param mimparser The MIME-parser object.
 * @param field_name The name of the field to look for.
 *
 * @return A pointer to a mailimf_optional_field structure. Must not be freed!
 *     If field_name could not be found or has another type, NULL is returned.
 */
struct mailimf_optional_field* mrmimeparser_lookup_optional_field(mrmimeparser_t* mimeparser, const char* field_name)
{
	struct mailimf_field* field = mrhash_find_str(&mimeparser->m_header, field_name);
	if( field && field->fld_type == MAILIMF_FIELD_OPTIONAL_FIELD ) {
		return field->fld_data.fld_optional_field;
	}
	return NULL;
}


/*
 * Lookup the first name and return, if found.
 * If not, try to lookup the second name.
 */
struct mailimf_optional_field* mrmimeparser_lookup_optional_field2(mrmimeparser_t* mimeparser, const char* field_name, const char* or_field_name)
{
	struct mailimf_optional_field* of = mrmimeparser_lookup_optional_field(mimeparser, field_name);
	return of? of : mrmimeparser_lookup_optional_field(mimeparser, or_field_name);
}


/**
 * Gets the _last_ part _not_ flagged with m_is_meta.
 *
 * If you just want to check if there is a non-meta part preset, you can also
 * use the macro mrmimeparser_has_nonmeta().
 *
 * @private @memberof mrmimeparser_t
 *
 * @param ths The MIME-parser object.
 *
 * @return The last part that is not flagged with m_is_meta. The returned value
 *     must not be freed.  If there is no such part, NULL is returned.
 */
mrmimepart_t* mrmimeparser_get_last_nonmeta(mrmimeparser_t* ths)
{
	if( ths && ths->m_parts ) {
		int i, icnt = carray_count(ths->m_parts);
		for( i = icnt-1; i >= 0; i-- ) {
			mrmimepart_t* part = (mrmimepart_t*)carray_get(ths->m_parts, i);
			if( part && !part->m_is_meta ) {
				return part;
			}
		}
	}
	return NULL;
}


/**
 * Checks, if the header of the mail looks as if it is a message from a mailing list.
 *
 * @private @memberof mrmimeparser_t
 *
 * @param ths The MIME-parser object.
 *
 * @return 1=the message is probably from a mailing list,
 *     0=the message is a normal messsage
 *
 * Some statistics:
 *
 * **Sorted out** by `List-ID`-header:
 * - Mailman mailing list messages      - OK, mass messages
 * - Xing forum/event notifications     - OK, mass messages
 * - Xing welcome-back, contact-request - Hm, but it _has_ the List-ID header
 *
 * **Sorted out** by `Precedence`-header:
 * - Majordomo mailing list messages    - OK, mass messages
 *
 * **Not** sorted out:
 * - Pingdom notifications              - OK, individual message
 * - Paypal notifications               - OK, individual message
 * - Linked in visits, do-you-know      - OK, individual message
 * - Share-It notifications             - OK, individual message
 * - Transifex, Github notifications    - OK, individual message
 *
 * Current state of mailing list handling:
 *
 * As we currently do not have an extra handling for mailing list messages, the
 * best is to ignore them completely.
 *
 * - if we know the sender, we should show them in the normal chat of the sender as this will lose the
 *   context of the mail
 *
 * - for unknown senders, mailing list messages are often replies to known messages (see is_reply_to_known_message__()) -
 *   which gives the sender some trust. this should not happen for mailing list messages.
 *   this may result in unwanted messages and contacts added to the address book that are not known.
 *
 * - of course, all this can be fixed, however, this may be a lot of work.
 *   moreover, if we allow answering to mailing lists, it might not be easy to follow the conventions used in typical mailing list,
 *   eg threads.
 *
 * "Mailing lists messages" in this sense are messages marked by List-Id or Precedence headers.
 * For the future, we might want to show mailing lists as groups.
 * (NB: typical mailing list header: `From: sender@gmx.net To: list@address.net)
 *
 */
int mrmimeparser_is_mailinglist_message(mrmimeparser_t* ths)
{
	if( ths == NULL ) {
		return 0;
	}

	if( mrmimeparser_lookup_field(ths, "List-Id") != NULL ) {
		return 1; /* mailing list identified by the presence of `List-ID` from RFC 2919 */
	}

	struct mailimf_optional_field* precedence = mrmimeparser_lookup_optional_field(ths, "Precedence");
	if( precedence != NULL ) {
		if( strcasecmp(precedence->fld_value, "list")==0
		 || strcasecmp(precedence->fld_value, "bulk")==0 ) {
			return 1; /* mailing list identified by the presence of `Precedence: bulk` or `Precedence: list` from RFC 3834 */
		}
	}

	return 0;
}


/**
 * Checks, if there is only one recipient address and if the recipient address
 * matches the sender address.  The function does _not_ check, if this address
 * matches the address configured for a special account.
 *
 * The function searches in the outer MIME header, not in possibly protected
 * memoryhole headers (if needed, we can change this; the reason for this is
 * only that mailimf_get_recipients() was already there - and does not respect
 * memoryhole as used on a lower level before memoryhole is calculated)
 *
 * @private @memberof mrmimeparser_t
 *
 * @param mimeparser The MIME-parser object.
 *
 * @return 1=Sender matches recipient
 *     0=Sender does not match recipient or there are more than one recipients
 */
int mrmimeparser_sender_equals_recipient(mrmimeparser_t* mimeparser)
{
	int                         sender_equals_recipient = 0;
	const struct mailimf_field* fld;
	const struct mailimf_from*  fld_from;
	struct mailimf_mailbox*     mb;
	char*                       from_addr_norm;
	mrhash_t*                   recipients   = NULL;

	if( mimeparser == NULL || mimeparser->m_header_root == NULL ) {
		goto cleanup;
	}

	/* get From: and check there is exactly one sender */
	if( (fld=mailimf_find_field(mimeparser->m_header_root, MAILIMF_FIELD_FROM)) == NULL
	 || (fld_from=fld->fld_data.fld_from) == NULL
	 || fld_from->frm_mb_list == NULL
	 || fld_from->frm_mb_list->mb_list == NULL
	 || clist_count(fld_from->frm_mb_list->mb_list) != 1 ) {
		goto cleanup;
	}

	mb = (struct mailimf_mailbox*)clist_content(clist_begin(fld_from->frm_mb_list->mb_list));
	if( mb == NULL ) {
		goto cleanup;
	}

	from_addr_norm = mr_normalize_addr(mb->mb_addr_spec);

	/* get To:/Cc: and check there is exactly one recipent */
	recipients = mailimf_get_recipients(mimeparser->m_header_root);
	if( mrhash_count(recipients) != 1 ) {
		goto cleanup;
	}

	/* check if From: == To:/Cc: */
	if( mrhash_find_str(recipients, from_addr_norm) ) {
		sender_equals_recipient = 1;
	}

cleanup:
	mrhash_clear(recipients);
	free(recipients);
	free(from_addr_norm);
	return sender_equals_recipient;
}

