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


/* If you do not want to use mrmailbox_cmdline(), this file MAY NOT included to
your library */


#include "mrmailbox_internal.h"
#include "mrapeerstate.h"
#include "mrkey.h"


static void log_msglist(mrmailbox_t* mailbox, carray* msglist)
{
	int i, cnt = carray_count(msglist), lines_out = 0;
	for( i = 0; i < cnt; i++ )
	{
		uint32_t msg_id = (uint32_t)(uintptr_t)carray_get(msglist, i);
		if( msg_id == MR_MSG_ID_DAYMARKER ) {
			mrmailbox_log_info(mailbox, 0, "--------------------------------------------------------------------------------"); lines_out++;
		}
		else if( msg_id > 0 ) {
			if( lines_out==0 ) { mrmailbox_log_info(mailbox, 0, "--------------------------------------------------------------------------------"); lines_out++; }

			mrmsg_t* msg = mrmailbox_get_msg(mailbox, msg_id);
			mrcontact_t* contact = mrmailbox_get_contact(mailbox, msg->m_from_id);
			const char* contact_name = (contact && contact->m_name)? contact->m_name : "ErrName";
			int contact_id = contact? contact->m_id : 0;

			const char* statestr = "";
			switch( msg->m_state ) {
				case MR_STATE_OUT_PENDING:   statestr = " o";   break;
				case MR_STATE_OUT_DELIVERED: statestr = " √";   break;
				case MR_STATE_OUT_MDN_RCVD:  statestr = " √√";  break;
				case MR_STATE_OUT_ERROR:     statestr = " ERR"; break;
			}

			char* temp2 = mr_timestamp_to_str(msg->m_timestamp);
				mrmailbox_log_info(mailbox, 0, "Msg#%i: %s (Contact#%i): %s %s%s%s%s%s [%s]",
					(int)msg->m_id,
					contact_name,
					contact_id,
					msg->m_text,
					mrmsg_show_padlock(msg)? "\xF0\x9F\x94\x92" : "",
					msg->m_starred? " \xE2\x98\x85" : "",
					msg->m_from_id==1? "" : (msg->m_state==MR_STATE_IN_SEEN? "[SEEN]" : (msg->m_state==MR_STATE_IN_NOTICED? "[NOTICED]":"[FRESH]")),
					mrparam_get_int(msg->m_param, MRP_SYSTEM_CMD, 0)? "[SYSTEM]" : "",
					statestr,
					temp2);
			free(temp2);

			mrcontact_unref(contact);
			mrmsg_unref(msg);
		}
	}

	if( lines_out > 0 ) { mrmailbox_log_info(mailbox, 0, "--------------------------------------------------------------------------------"); }
}


static void log_contactlist(mrmailbox_t* mailbox, carray* contacts)
{
	int             i, cnt = carray_count(contacts);
	mrcontact_t*    contact = mrcontact_new();
	mrapeerstate_t* peerstate = mrapeerstate_new();

	mrsqlite3_lock(mailbox->m_sql);
		for( i = 0; i < cnt; i++ ) {
			uint32_t contact_id = (uint32_t)(uintptr_t)carray_get(contacts, i);
			char* line = NULL;
			char* line2 = NULL;
			if( mrcontact_load_from_db__(contact, mailbox->m_sql, (uint32_t)(uintptr_t)carray_get(contacts, i)) ) {
				line = mr_mprintf("%s, %s", (contact->m_name&&contact->m_name[0])? contact->m_name : "<name unset>", (contact->m_addr&&contact->m_addr[0])? contact->m_addr : "<addr unset>");
				if( mrapeerstate_load_from_db__(peerstate, mailbox->m_sql, contact->m_addr) ) {
					char* pe = NULL;
					switch( peerstate->m_prefer_encrypt ) {
						case MRA_PE_MUTUAL:       pe = safe_strdup("mutual");                                         break;
						case MRA_PE_NOPREFERENCE: pe = safe_strdup("no-preference");                                  break;
						case MRA_PE_RESET:        pe = safe_strdup("reset");                                          break;
						default:                  pe = mr_mprintf("unknown-value (%i)", peerstate->m_prefer_encrypt); break;
					}
					line2 = mr_mprintf(", prefer-encrypt=%s, key-bytes=%i", pe, peerstate->m_public_key->m_bytes);
					free(pe);
				}
			}
			else {
				line = safe_strdup("Read error.");
			}
			mrmailbox_log_info(mailbox, 0, "Contact#%i: %s%s", (int)contact_id, line, line2? line2:"");
			free(line);
			free(line2);
		}
	mrsqlite3_unlock(mailbox->m_sql);

	mrapeerstate_unref(peerstate);
	mrcontact_unref(contact);
}


static int s_is_auth = 0;


void mrmailbox_cmdline_skip_auth()
{
	s_is_auth = 1;
}


char* mrmailbox_cmdline(mrmailbox_t* mailbox, const char* cmdline)
{
	#define      COMMAND_FAILED    ((char*)1)
	#define      COMMAND_SUCCEEDED ((char*)2)
	#define      COMMAND_UNKNOWN   ((char*)3)
	char*        cmd = NULL, *arg1 = NULL, *ret = COMMAND_FAILED;
	mrchat_t*    sel_chat = NULL;


	if( mailbox == NULL || cmdline == NULL || cmdline[0]==0 ) {
		goto cleanup;
	}

	if( mailbox->m_cmdline_sel_chat_id ) {
		sel_chat = mrmailbox_get_chat(mailbox, mailbox->m_cmdline_sel_chat_id);
	}

	/* split commandline into command and first argument
	(the first argument may contain spaces, if this is undesired we split further arguments form if below. */
	cmd = safe_strdup(cmdline);
	arg1 = strchr(cmd, ' ');
	if( arg1 ) { *arg1 = 0; arg1++; }

	/* execute command */
	if( strcmp(cmd, "help")==0 || strcmp(cmd, "?")==0 )
	{
		ret = safe_strdup(
			"Database commands:\n"
			"info\n"
			"open <file to open or create>\n"
			"close\n"
			"reset <flags>\n"
			"imex export-keys|import-keys|export-backup|import-backup|cancel\n"
			"export-setup\n"
			"hasbackup\n"
			"poke [<eml-file>|<folder>|<addr> <key-file>]\n"
			"set <configuration-key> [<value>]\n"
			"get <configuration-key>\n"
			"configure\n"
			"configurecancel\n"
			"connect\n"
			"disconnect\n"
			"fetch\n"
			"restore <days>\n"

			"\nChat commands:\n"
			"listchats [<query>]\n"
			"listarchived\n"
			"chat [<chat-id>|0]\n"
			"createchat <contact-id>\n"
			"creategroup <name>\n"
			"addmember <contact-id>\n"
			"removemember <contact-id>\n"
			"groupimage [<file>]\n"
			"chatinfo\n"
			"send <text>\n"
			"sendimage <file>\n"
			"sendfile <file>\n"
			"draft [<text>]\n"
			"listmedia\n"
			"archive <chat-id>\n"
			"unarchive <chat-id>\n"
			"delchat <chat-id>\n"

			"\nMessage commands:\n"
			"listmsgs <query>\n"
			"msginfo <msg-id>\n"
			"listfresh\n"
			"forward <msg-id> <chat-id>\n"
			"markseen <msg-id>\n"
			"star <msg-id>\n"
			"unstar <msg-id>\n"
			"delmsg <msg-id>\n"

			"\nContact commands:\n"
			"listcontacts [<query>]\n"
			"addcontact <name> <addr>\n"
			"contactinfo <contact-id>\n"

			"\nMisc.:\n"
			"event <event-id to test>\n"
			"fileinfo <file>\n"
			"heartbeat\n"
			"clear -- clear screen\n" /* must be implemented by  the caller */
			"exit" /* must be implemented by  the caller */
		);
	}
	else if( !s_is_auth )
	{
		if( strcmp(cmd, "auth")==0 ) {
			char* is_pw = mrmailbox_get_config(mailbox, "mail_pw", "");
			if( strcmp(arg1, is_pw)==0 ) {
				s_is_auth = 1;
				ret = COMMAND_SUCCEEDED;
			}
			else {
				ret = "Bad password.";
			}
		}
		else {
			ret = safe_strdup("Please authorize yourself using: auth <password>");
		}
	}
	else if( strcmp(cmd, "auth")==0 )
	{
		ret = safe_strdup("Already authorized.");
	}


	/*******************************************************************************
	 * Database commands
	 ******************************************************************************/

	else if( strcmp(cmd, "open")==0 )
	{
		if( arg1 ) {
			mrmailbox_close(mailbox);
			ret = mrmailbox_open(mailbox, arg1, NULL)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <file> missing.");
		}
	}
	else if( strcmp(cmd, "close")==0 )
	{
		mrmailbox_close(mailbox);
		ret = COMMAND_SUCCEEDED;
	}
	else if( strcmp(cmd, "reset")==0 )
	{
		if( arg1 ) {
			int bits = atoi(arg1);
			ret = mrmailbox_reset_tables(mailbox, bits)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <bits> missing: 1=jobs, 2=peerstates, 4=private keys, 8=rest but server config");
		}
	}
	else if( strcmp(cmd, "poke")==0 )
	{
		ret = mrmailbox_poke_spec(mailbox, arg1)? COMMAND_SUCCEEDED : COMMAND_FAILED;
	}
	else if( strcmp(cmd, "export-setup")==0 )
	{
		char* setup_code = mrmailbox_create_setup_code(mailbox);
			ret = mr_mprintf("Setup code for the exported setup: %s", setup_code);
			mrmailbox_imex(mailbox, MR_IMEX_EXPORT_SETUP_MESSAGE, mailbox->m_blobdir, setup_code);
		free(setup_code);
	}
	else if( strcmp(cmd, "imex")==0 )
	{
		if( arg1 ) {
			char* arg2 = strchr(arg1, ' ');
			if( arg2 ) { *arg2 = 0; arg2++; }

			if( strcmp(arg1, "export-keys")==0 && arg2==NULL ) {
				mrmailbox_imex(mailbox, MR_IMEX_EXPORT_SELF_KEYS, mailbox->m_blobdir, NULL);
				ret = COMMAND_SUCCEEDED;
			}
			else if( strcmp(arg1, "import-keys")==0 ) {
				mrmailbox_imex(mailbox, MR_IMEX_IMPORT_SELF_KEYS, mailbox->m_blobdir, NULL);
				ret = COMMAND_SUCCEEDED;
			}
			else if( strcmp(arg1, "export-backup")==0 && arg2==NULL ) {
				mrmailbox_imex(mailbox, MR_IMEX_EXPORT_BACKUP, mailbox->m_blobdir, NULL);
				ret = COMMAND_SUCCEEDED;
			}
			else if( strcmp(arg1, "import-backup")==0 && arg2!=NULL ) {
				mrmailbox_imex(mailbox, MR_IMEX_IMPORT_BACKUP, arg2, NULL);
				ret = COMMAND_SUCCEEDED;
			}
			else if( strcmp(arg1, "cancel")==0 ) {
				mrmailbox_imex(mailbox, 0, NULL, NULL);
				ret = COMMAND_SUCCEEDED;
			}
			else {
				ret = COMMAND_FAILED;
			}
		}
		else {
			ret = safe_strdup("ERROR: Argument <what> missing.");
		}
	}
	else if( strcmp(cmd, "hasbackup")==0 )
	{
		ret = mrmailbox_imex_has_backup(mailbox, mailbox->m_blobdir);
		if( ret == NULL ) {
			ret = safe_strdup("No backup found.");
		}
	}
	else if( strcmp(cmd, "set")==0 )
	{
		if( arg1 ) {
			char* arg2 = strchr(arg1, ' ');
			if( arg2 ) {
				*arg2 = 0;
				arg2++;
			}
			ret = mrmailbox_set_config(mailbox, arg1, arg2)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <key> missing.");
		}
	}
	else if( strcmp(cmd, "get")==0 )
	{
		if( arg1 ) {
			char* val = mrmailbox_get_config(mailbox, arg1, "<unset>");
			if( val ) {
				ret = mr_mprintf("%s=%s", arg1, val);
				free(val);
			}
			else {
				ret = COMMAND_FAILED;
			}
		}
		else {
			ret = safe_strdup("ERROR: Argument <key> missing.");
		}
	}
	else if( strcmp(cmd, "configure")==0 )
	{
		mrmailbox_configure_and_connect(mailbox);
		ret = COMMAND_SUCCEEDED;
	}
	else if( strcmp(cmd, "configurecancel")==0 )
	{
		mrmailbox_configure_cancel(mailbox);
		ret = COMMAND_SUCCEEDED;
	}
	else if( strcmp(cmd, "connect")==0 )
	{
		mrmailbox_connect(mailbox);
		ret = COMMAND_SUCCEEDED;
	}
	else if( strcmp(cmd, "disconnect")==0 )
	{
		mrmailbox_disconnect(mailbox);
		ret = COMMAND_SUCCEEDED;
	}
	else if( strcmp(cmd, "fetch")==0 )
	{
		ret = mrmailbox_fetch(mailbox)? COMMAND_SUCCEEDED : COMMAND_FAILED;
	}
	else if( strcmp(cmd, "restore")==0 )
	{
		if( arg1 ) {
			int days = atoi(arg1);
			ret = mrmailbox_restore(mailbox, days*24*60*60)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <days> missing.");
		}
	}
	else if( strcmp(cmd, "info")==0 )
	{
		ret = mrmailbox_get_info(mailbox);
		if( ret == NULL ) {
			ret = COMMAND_FAILED;
		}
	}

	/*******************************************************************************
	 * Chat commands
	 ******************************************************************************/

	else if( strcmp(cmd, "listchats")==0 || strcmp(cmd, "listarchived")==0 || strcmp(cmd, "chats")==0 )
	{
		int listflags = strcmp(cmd, "listarchived")==0? MR_GCL_ARCHIVED_ONLY : 0;
		mrchatlist_t* chatlist = mrmailbox_get_chatlist(mailbox, listflags, arg1);
		if( chatlist ) {
			int i, cnt = mrchatlist_get_cnt(chatlist);
			if( cnt>0 ) {
				mrmailbox_log_info(mailbox, 0, "================================================================================");
				for( i = cnt-1; i >= 0; i-- )
				{
					mrchat_t* chat = mrchatlist_get_chat_by_index(chatlist, i);
					char *temp;

					temp = mrchat_get_subtitle(chat);
						mrmailbox_log_info(mailbox, 0, "%s#%i: %s [%s] [%i fresh]", chat->m_type==MR_CHAT_GROUP? "Groupchat" : "Chat",
							(int)chat->m_id, chat->m_name, temp, (int)mrchat_get_fresh_msg_count(chat));
					free(temp);

					mrpoortext_t* poortext = mrchatlist_get_summary_by_index(chatlist, i, chat);

						const char* statestr = "";
						if( chat->m_archived ) {
							statestr = " [Archived]";
						}
						else switch( poortext->m_state ) {
							case MR_STATE_OUT_PENDING:   statestr = " o";   break;
							case MR_STATE_OUT_DELIVERED: statestr = " √";   break;
							case MR_STATE_OUT_MDN_RCVD:  statestr = " √√";  break;
							case MR_STATE_OUT_ERROR:     statestr = " ERR"; break;
						}

						char* timestr = mr_timestamp_to_str(poortext->m_timestamp);
							mrmailbox_log_info(mailbox, 0, "%s%s%s%s [%s]",
								poortext->m_text1? poortext->m_text1 : "",
								poortext->m_text1? ": " : "",
								poortext->m_text2? poortext->m_text2 : NULL,
								statestr, timestr
								);
						free(timestr);

					mrpoortext_unref(poortext);

					mrchat_unref(chat);

					mrmailbox_log_info(mailbox, 0, "================================================================================");
				}
			}
			ret = mr_mprintf("%i chats.", (int)cnt);
			mrchatlist_unref(chatlist);
		}
		else {
			ret = COMMAND_FAILED;
		}
	}
	else if( strcmp(cmd, "chat")==0 )
	{
		if( arg1 && arg1[0] ) {
			/* select a chat (argument 1 = ID of chat to select) */
			if( sel_chat ) { mrchat_unref(sel_chat); sel_chat = NULL; }
			mailbox->m_cmdline_sel_chat_id = atoi(arg1);
			sel_chat = mrmailbox_get_chat(mailbox, mailbox->m_cmdline_sel_chat_id); /* may be NULL */
			if( sel_chat==NULL ) {
				mailbox->m_cmdline_sel_chat_id = 0;
			}
		}

		/* show chat */
		if( sel_chat ) {
			carray* msglist = mrmailbox_get_chat_msgs(mailbox, sel_chat->m_id, MR_GCM_ADDDAYMARKER, 0);
			char* temp2 = mrchat_get_subtitle(sel_chat);
				mrmailbox_log_info(mailbox, 0, "Chat#%i: %s [%s]", sel_chat->m_id, sel_chat->m_name, temp2);
			free(temp2);
			if( msglist ) {
				log_msglist(mailbox, msglist);
				carray_free(msglist);
			}
			if( sel_chat->m_draft_timestamp ) {
				char* timestr = mr_timestamp_to_str(sel_chat->m_draft_timestamp);
					mrmailbox_log_info(mailbox, 0, "Draft: %s [%s]", sel_chat->m_draft_text, timestr);
				free(timestr);
			}
			ret = mr_mprintf("%i messages.", mrchat_get_total_msg_count(sel_chat));
			mrmailbox_marknoticed_chat(mailbox, sel_chat->m_id);
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "createchat")==0 )
	{
		if( arg1 ) {
			int contact_id = atoi(arg1);
			int chat_id = mrmailbox_create_chat_by_contact_id(mailbox, contact_id);
			ret = chat_id!=0? mr_mprintf("Chat#%lu created successfully.", chat_id) : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <contact-id> missing.");
		}
	}
	else if( strcmp(cmd, "creategroup")==0 )
	{
		if( arg1 ) {
			int chat_id = mrmailbox_create_group_chat(mailbox, arg1);
			ret = chat_id!=0? mr_mprintf("Groupchat#%lu created successfully.", chat_id) : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <name> missing.");
		}
	}
	else if( strcmp(cmd, "addmember")==0 )
	{
		if( sel_chat ) {
			if( arg1 ) {
				int contact_id = atoi(arg1);
				if( mrmailbox_add_contact_to_chat(mailbox, sel_chat->m_id, contact_id) ) {
					ret = safe_strdup("Contact added to chat.");
				}
				else {
					ret = safe_strdup("ERROR: Cannot add contact to chat.");
				}
			}
			else {
				ret = safe_strdup("ERROR: Argument <contact-id> missing.");
			}
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "removemember")==0 )
	{
		if( sel_chat ) {
			if( arg1 ) {
				int contact_id = atoi(arg1);
				if( mrmailbox_remove_contact_from_chat(mailbox, sel_chat->m_id, contact_id) ) {
					ret = safe_strdup("Contact added to chat.");
				}
				else {
					ret = safe_strdup("ERROR: Cannot remove member from chat.");
				}
			}
			else {
				ret = safe_strdup("ERROR: Argument <contact-id> missing.");
			}
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "groupimage")==0 )
	{
		if( sel_chat ) {
			ret = mrmailbox_set_chat_image(mailbox, sel_chat->m_id, (arg1&&arg1[0])?arg1:NULL)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "chatinfo")==0 )
	{
		if( sel_chat ) {
			carray* contacts = mrmailbox_get_chat_contacts(mailbox, sel_chat->m_id);
			if( contacts ) {
				mrmailbox_log_info(mailbox, 0, "Memberlist:");
				log_contactlist(mailbox, contacts);
				ret = mr_mprintf("%i contacts.", (int)carray_count(contacts));
			}
			else {
				ret = COMMAND_FAILED;
			}
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "send")==0 )
	{
		if( sel_chat ) {
			if( arg1 && arg1[0] ) {
				mrmsg_t* msg = mrmsg_new();
					msg->m_type = MR_MSG_TEXT;
					mrmsg_set_text(msg, arg1);
					if( mrchat_send_msg(sel_chat, msg) ) {
						ret = safe_strdup("Message sent.");
					}
					else {
						ret = safe_strdup("ERROR: Sending failed.");
					}
				mrmsg_unref(msg);
			}
			else {
				ret = safe_strdup("ERROR: No message text given.");
			}
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "sendimage")==0 || strcmp(cmd, "sendfile")==0 )
	{
		if( sel_chat ) {
			if( arg1 && arg1[0] ) {
				mrmsg_t* msg = mrmsg_new();
					msg->m_type = strcmp(cmd, "sendimage")==0? MR_MSG_IMAGE : MR_MSG_FILE;
					mrparam_set(msg->m_param, MRP_FILE, arg1);
					if( mrchat_send_msg(sel_chat, msg) ) {
						ret = safe_strdup("File sent.");
					}
					else {
						ret = safe_strdup("ERROR: Sending failed.");
					}
				mrmsg_unref(msg);
			}
			else {
				ret = safe_strdup("ERROR: No message text given.");
			}
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "listmsgs")==0 )
	{
		if( arg1 ) {
			carray* msglist = mrmailbox_search_msgs(mailbox, sel_chat? sel_chat->m_id : 0, arg1);
			if( msglist ) {
				log_msglist(mailbox, msglist);
				ret = mr_mprintf("%i messages.", (int)carray_count(msglist));
				carray_free(msglist);
			}
		}
		else {
			ret = safe_strdup("ERROR: Argument <query> missing.");
		}
	}
	else if( strcmp(cmd, "draft")==0 )
	{
		if( sel_chat ) {
			if( arg1 && arg1[0] ) {
				mrchat_set_draft(sel_chat, arg1);
				ret = safe_strdup("Draft saved.");
			}
			else {
				mrchat_set_draft(sel_chat, NULL);
				ret = safe_strdup("Draft deleted.");
			}
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "listmedia")==0 )
	{
		if( sel_chat ) {
			carray* images = mrmailbox_get_chat_media(mailbox, sel_chat->m_id, MR_MSG_IMAGE, MR_MSG_VIDEO);
			int i, icnt = carray_count(images);
			ret = mr_mprintf("%i images or videos: ", icnt);
			for( i = 0; i < icnt; i++ ) {
				char* temp = mr_mprintf("%s%sMsg#%i", i? ", ":"", ret, (int)(uintptr_t)carray_get(images, i));
				free(ret);
				ret = temp;
			}
			carray_free(images);
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "archive")==0 || strcmp(cmd, "unarchive")==0 )
	{
		if( arg1 ) {
			int chat_id = atoi(arg1);
			ret = mrmailbox_archive_chat(mailbox, chat_id, strcmp(cmd, "archive")==0? 1 : 0)!=0? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <chat-id> missing.");
		}
	}
	else if( strcmp(cmd, "delchat")==0 )
	{
		if( arg1 ) {
			int chat_id = atoi(arg1);
			ret = mrmailbox_delete_chat(mailbox, chat_id)!=0? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <chat-id> missing.");
		}
	}


	/*******************************************************************************
	 * Message commands
	 ******************************************************************************/

	else if( strcmp(cmd, "msginfo")==0 )
	{
		if( arg1 ) {
			int id = atoi(arg1);
			ret = mrmailbox_get_msg_info(mailbox, id);
		}
		else {
			ret = safe_strdup("ERROR: Argument <msg-id> missing.");
		}
	}
	else if( strcmp(cmd, "listfresh")==0 )
	{
		carray* msglist = mrmailbox_get_fresh_msgs(mailbox);
		if( msglist ) {
			log_msglist(mailbox, msglist);
			ret = mr_mprintf("%i fresh messages.", (int)carray_count(msglist));
			carray_free(msglist);
		}
	}
	else if( strcmp(cmd, "forward")==0 )
	{
		char* arg2 = NULL;
		if( arg1 ) { arg2 = strrchr(arg1, ' '); }
		if( arg1 && arg2 ) {
			*arg2 = 0; arg2++;
			uint32_t msg_ids[1], chat_id = atoi(arg2);
			msg_ids[0] = atoi(arg1);
			ret = mrmailbox_forward_msgs(mailbox, msg_ids, 1, chat_id)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Arguments <msg-id> <chat-id> expected.");
		}
	}
	else if( strcmp(cmd, "markseen")==0 )
	{
		if( arg1 ) {
			uint32_t msg_ids[1];
			msg_ids[0] = atoi(arg1);
			ret = mrmailbox_markseen_msgs(mailbox, msg_ids, 1)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <msg-id> missing.");
		}
	}
	else if( strcmp(cmd, "star")==0 || strcmp(cmd, "unstar")==0 )
	{
		if( arg1 ) {
			uint32_t msg_ids[1];
			msg_ids[0] = atoi(arg1);
			ret = mrmailbox_star_msgs(mailbox, msg_ids, 1, strcmp(cmd, "star")==0? 1 : 0)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <msg-id> missing.");
		}
	}
	else if( strcmp(cmd, "delmsg")==0 )
	{
		if( arg1 ) {
			uint32_t ids[1];
			ids[0] = atoi(arg1);
			ret = mrmailbox_delete_msgs(mailbox, ids, 1)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <msg-id> missing.");
		}
	}


	/*******************************************************************************
	 * Contact commands
	 ******************************************************************************/

	else if( strcmp(cmd, "listcontacts")==0 || strcmp(cmd, "contacts")==0 )
	{
		carray* contacts = mrmailbox_get_known_contacts(mailbox, arg1);
		if( contacts ) {
			log_contactlist(mailbox, contacts);
			ret = mr_mprintf("%i contacts.", (int)carray_count(contacts));
			carray_free(contacts);
		}
		else {
			ret = COMMAND_FAILED;
		}
	}
	else if( strcmp(cmd, "addcontact")==0 )
	{
		char* arg2 = NULL;
		if( arg1 ) { arg2 = strrchr(arg1, ' '); }
		if( arg1 && arg2 ) {
			*arg2 = 0; arg2++;
			char* book = mr_mprintf("%s\n%s", arg1, arg2);
				mrmailbox_add_address_book(mailbox, book);
				ret = COMMAND_SUCCEEDED;
			free(book);
		}
		else {
			ret = safe_strdup("ERROR: Arguments <name> <addr> expected.");
		}
	}
	else if( strcmp(cmd, "contactinfo")==0 )
	{
		if( arg1 ) {
			int contact_id = atoi(arg1);
			ret = mrmailbox_get_contact_encrinfo(mailbox, contact_id);
		}
		else {
			ret = safe_strdup("ERROR: Argument <contact-id> missing.");
		}
	}

	/*******************************************************************************
	 * Misc.
	 ******************************************************************************/

	else if( strcmp(cmd, "event")==0 )
	{
		if( arg1 ) {
			int event = atoi(arg1);
			uintptr_t r = mailbox->m_cb(mailbox, event, 0, 0);
			ret = mr_mprintf("Sending event %i, received value %i.", (int)event, (int)r);
		}
		else {
			ret = safe_strdup("ERROR: Argument <id> missing.");
		}
	}
	else if( strcmp(cmd, "fileinfo")==0 )
	{
		if( arg1 ) {
			unsigned char* buf = NULL; size_t buf_bytes; uint32_t w, h;
			if( mr_read_file(arg1, (void**)&buf, &buf_bytes, mailbox) ) {
				mr_get_filemeta(buf, buf_bytes, &w, &h);
				ret = mr_mprintf("width=%i, height=%i", (int)w, (int)h);
			}
			else {
				ret = safe_strdup("ERROR: Command failed.");
			}
			free(buf);
		}
		else {
			ret = safe_strdup("ERROR: Argument <file> missing.");
		}
	}
	else if( strcmp(cmd, "heartbeat")==0 )
	{
		mrmailbox_heartbeat(mailbox);
		ret = COMMAND_SUCCEEDED;
	}
	else
	{
		ret = COMMAND_UNKNOWN;
	}

cleanup:
	if( ret == COMMAND_SUCCEEDED ) {
		ret = safe_strdup("Command executed successfully.");
	}
	else if( ret == COMMAND_FAILED ) {
		ret = safe_strdup("ERROR: Command failed.");
	}
	else if( ret == COMMAND_UNKNOWN ) {
		ret = mr_mprintf("ERROR: Unknown command \"%s\", type ? for help.", cmd);
	}
	if( sel_chat ) { mrchat_unref(sel_chat); sel_chat = NULL; }
	free(cmd);
	return ret;
}


