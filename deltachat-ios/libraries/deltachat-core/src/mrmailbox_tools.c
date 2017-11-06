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
 * File:    mrmailbox_tools.c
 * Purpose: Database and other tools for a mrmailbox_t object.
 *
 ******************************************************************************/


#include <stdlib.h>
#include <string.h>
#include "mrmailbox.h"
#include "mrmimeparser.h"
#include "mrtools.h"


/*******************************************************************************
 * Add contacts to database on receiving messages
 ******************************************************************************/


static void add_or_lookup_contact_by_addr__(mrmailbox_t* ths, const char* display_name_enc, const char* addr_spec, int origin, carray* ids, int* check_self)
{
	/* is addr_spec equal to SELF? */
	int dummy;
	if( check_self == NULL ) { check_self = &dummy; }

	*check_self = 0;

	char* self_addr = mrsqlite3_get_config__(ths->m_sql, "configured_addr", "");
		if( strcasecmp(self_addr, addr_spec)==0 ) {
			*check_self = 1;
		}
	free(self_addr);

	if( *check_self ) {
		return;
	}

	/* add addr_spec if missing, update otherwise */
	char* display_name_dec = NULL;
	if( display_name_enc ) {
		display_name_dec = mr_decode_header_string(display_name_enc);
		mr_normalize_name(display_name_dec);
	}

	uint32_t row_id = mrmailbox_add_or_lookup_contact__(ths, display_name_dec /*can be NULL*/, addr_spec, origin, NULL);

	free(display_name_dec);

	if( row_id ) {
		if( !carray_search(ids, (void*)(uintptr_t)row_id, NULL) ) {
			carray_add(ids, (void*)(uintptr_t)row_id, NULL);
		}
	}
}


void mrmailbox_add_or_lookup_contacts_by_mailbox_list__(mrmailbox_t* ths, struct mailimf_mailbox_list* mb_list, int origin, carray* ids, int* check_self)
{
	clistiter* cur;
	for( cur = clist_begin(mb_list->mb_list); cur!=NULL ; cur=clist_next(cur) ) {
		struct mailimf_mailbox* mb = (struct mailimf_mailbox*)clist_content(cur);
		if( mb ) {
			add_or_lookup_contact_by_addr__(ths, mb->mb_display_name, mb->mb_addr_spec, origin, ids, check_self);
		}
	}
}


void mrmailbox_add_or_lookup_contacts_by_address_list__(mrmailbox_t* ths, struct mailimf_address_list* adr_list, int origin, carray* ids, int* check_self)
{
	clistiter* cur;
	for( cur = clist_begin(adr_list->ad_list); cur!=NULL ; cur=clist_next(cur) ) {
		struct mailimf_address* adr = (struct mailimf_address*)clist_content(cur);
		if( adr ) {
			if( adr->ad_type == MAILIMF_ADDRESS_MAILBOX ) {
				struct mailimf_mailbox* mb = adr->ad_data.ad_mailbox; /* can be NULL */
				if( mb ) {
					add_or_lookup_contact_by_addr__(ths, mb->mb_display_name, mb->mb_addr_spec, origin, ids, check_self);
				}
			}
			else if( adr->ad_type == MAILIMF_ADDRESS_GROUP ) {
				struct mailimf_group* group = adr->ad_data.ad_group; /* can be NULL */
				if( group && group->grp_mb_list /*can be NULL*/ ) {
					mrmailbox_add_or_lookup_contacts_by_mailbox_list__(ths, group->grp_mb_list, origin, ids, check_self);
				}
			}
		}
	}
}


/*******************************************************************************
 * Check if a message is a reply to a known message (messenger or non-messenger)
 ******************************************************************************/


static int is_known_rfc724_mid__(mrmailbox_t* mailbox, const char* rfc724_mid)
{
	if( rfc724_mid ) {
		sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_msgs_WHERE_cm,
			"SELECT id FROM msgs "
			" WHERE rfc724_mid=? "
			" AND chat_id!=" MR_STRINGIFY(MR_CHAT_ID_TRASH) /*eg. do not replies to our mailinglist messages as known*/
			" AND (chat_id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL) " OR from_id=" MR_STRINGIFY(MR_CONTACT_ID_SELF) ");");
		sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
		if( sqlite3_step(stmt) == SQLITE_ROW ) {
			return 1;
		}
	}
	return 0;
}


static int is_known_rfc724_mid_in_list__(mrmailbox_t* mailbox, const clist* mid_list)
{
	if( mid_list ) {
		clistiter* cur;
		for( cur = clist_begin(mid_list); cur!=NULL ; cur=clist_next(cur) ) {
			if( is_known_rfc724_mid__(mailbox, clist_content(cur)) ) {
				return 1;
			}
		}
	}

	return 0;
}


int mrmailbox_is_reply_to_known_message__(mrmailbox_t* mailbox, mrmimeparser_t* mime_parser)
{
	/* check if the message is a reply to a known message; the replies are identified by the Message-ID from
	`In-Reply-To`/`References:` (to support non-Delta-Clients) or from `X-MrPredecessor:` (Delta clients, see comment in mrchat.c) */
	clistiter* cur;
	for( cur = clist_begin(mime_parser->m_header->fld_list); cur!=NULL ; cur=clist_next(cur) )
	{
		struct mailimf_field* field = (struct mailimf_field*)clist_content(cur);
		if( field )
		{
			if( field->fld_type == MAILIMF_FIELD_OPTIONAL_FIELD )
			{
				struct mailimf_optional_field* optional_field = field->fld_data.fld_optional_field;
				if( optional_field && optional_field->fld_name ) {
					if( strcasecmp(optional_field->fld_name, "X-MrPredecessor")==0 || strcasecmp(optional_field->fld_name, "Chat-Predecessor")==0 ) { /* see comment in mrchat.c */
						if( is_known_rfc724_mid__(mailbox, optional_field->fld_value) ) {
							return 1;
						}
					}
				}
			}
			else if( field->fld_type == MAILIMF_FIELD_IN_REPLY_TO )
			{
				struct mailimf_in_reply_to* fld_in_reply_to = field->fld_data.fld_in_reply_to;
				if( fld_in_reply_to ) {
					if( is_known_rfc724_mid_in_list__(mailbox, field->fld_data.fld_in_reply_to->mid_list) ) {
						return 1;
					}
				}
			}
			else if( field->fld_type == MAILIMF_FIELD_REFERENCES )
			{
				struct mailimf_references* fld_references = field->fld_data.fld_references;
				if( fld_references ) {
					if( is_known_rfc724_mid_in_list__(mailbox, field->fld_data.fld_references->mid_list) ) {
						return 1;
					}
				}
			}

		}
	}

	return 0;
}


/*******************************************************************************
 * Check if a message is a reply to any messenger message
 ******************************************************************************/


static int is_msgrmsg_rfc724_mid__(mrmailbox_t* mailbox, const char* rfc724_mid)
{
	if( rfc724_mid ) {
		sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_msgs_WHERE_mcm,
			"SELECT id FROM msgs "
			" WHERE rfc724_mid=? "
			" AND msgrmsg!=0 "
			" AND chat_id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL) ";");
		sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
		if( sqlite3_step(stmt) == SQLITE_ROW ) {
			return 1;
		}
	}
	return 0;
}


static int is_msgrmsg_rfc724_mid_in_list__(mrmailbox_t* mailbox, const clist* mid_list)
{
	if( mid_list ) {
		clistiter* cur;
		for( cur = clist_begin(mid_list); cur!=NULL ; cur=clist_next(cur) ) {
			if( is_msgrmsg_rfc724_mid__(mailbox, clist_content(cur)) ) {
				return 1;
			}
		}
	}

	return 0;
}


int mrmailbox_is_reply_to_messenger_message__(mrmailbox_t* mailbox, mrmimeparser_t* mime_parser)
{
	/* function checks, if the message defined by mime_parser references a message send by us from Delta Chat.

	This is similar to is_reply_to_known_message__() but
	- checks also if any of the referenced IDs are send by a messenger
	- it is okay, if the referenced messages are moved to trash here
	- no check for the Chat-* headers (function is only called if it is no messenger message itself) */
	clistiter* cur;
	for( cur = clist_begin(mime_parser->m_header->fld_list); cur!=NULL ; cur=clist_next(cur) )
	{
		struct mailimf_field* field = (struct mailimf_field*)clist_content(cur);
		if( field )
		{
			if( field->fld_type == MAILIMF_FIELD_IN_REPLY_TO )
			{
				struct mailimf_in_reply_to* fld_in_reply_to = field->fld_data.fld_in_reply_to;
				if( fld_in_reply_to ) {
					if( is_msgrmsg_rfc724_mid_in_list__(mailbox, field->fld_data.fld_in_reply_to->mid_list) ) {
						return 1;
					}
				}
			}
			else if( field->fld_type == MAILIMF_FIELD_REFERENCES )
			{
				struct mailimf_references* fld_references = field->fld_data.fld_references;
				if( fld_references ) {
					if( is_msgrmsg_rfc724_mid_in_list__(mailbox, field->fld_data.fld_references->mid_list) ) {
						return 1;
					}
				}
			}

		}
	}
	return 0;
}


/*******************************************************************************
 * Misc.
 ******************************************************************************/


time_t mrmailbox_correct_bad_timestamp__(mrmailbox_t* ths, uint32_t chat_id, uint32_t from_id, time_t desired_timestamp, int is_fresh_msg)
{
	/* used for correcting timestamps of _received_ messages.
	use the last message from another user (including SELF) as the MINIMUM
	(we do this check only for fresh messages, other messages may pop up whereever, this may happen eg. when restoring old messages or synchronizing different clients) */
	if( is_fresh_msg )
	{
		sqlite3_stmt* stmt = mrsqlite3_predefine__(ths->m_sql, SELECT_timestamp_FROM_msgs_WHERE_timestamp,
			"SELECT MAX(timestamp) FROM msgs WHERE chat_id=? and from_id!=? AND timestamp>=?");
		sqlite3_bind_int  (stmt,  1, chat_id);
		sqlite3_bind_int  (stmt,  2, from_id);
		sqlite3_bind_int64(stmt,  3, desired_timestamp);
		if( sqlite3_step(stmt)==SQLITE_ROW )
		{
			time_t last_msg_time = sqlite3_column_int64(stmt, 0);
			if( last_msg_time > 0 /* may happen as we do not check against sqlite3_column_type()!=SQLITE_NULL */ ) {
				if( desired_timestamp <= last_msg_time ) {
					desired_timestamp = last_msg_time+1; /* this may result in several incoming messages having the same
					                                     one-second-after-the-last-other-message-timestamp.  however, this is no big deal
					                                     as we do not try to recrete the order of bad-date-messages and as we always order by ID as second criterion */
				}
			}
		}
	}

	/* use the (smeared) current time as the MAXIMUM */
	if( desired_timestamp >= mr_smeared_time__() )
	{
		desired_timestamp = mr_create_smeared_timestamp__();
	}

	return desired_timestamp;
}