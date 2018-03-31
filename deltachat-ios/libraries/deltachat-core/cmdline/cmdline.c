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


#include <dirent.h>
#include "../src/mrmailbox_internal.h"
#include "../src/mraheader.h"
#include "../src/mrapeerstate.h"
#include "../src/mrkey.h"
#include "../src/mrpgp.h"


/*
 * Reset database tables. This function is called from Core cmdline.
 *
 * Argument is a bitmask, executing single or multiple actions in one call.
 *
 * e.g. bitmask 7 triggers actions definded with bits 1, 2 and 4.
 */
int mrmailbox_reset_tables(mrmailbox_t* ths, int bits)
{
	if( ths == NULL || ths->m_magic != MR_MAILBOX_MAGIC ) {
		return 0;
	}

	mrmailbox_log_info(ths, 0, "Resetting tables (%i)...", bits);

	mrsqlite3_lock(ths->m_sql);

		if( bits & 1 ) {
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM jobs;");
			mrmailbox_log_info(ths, 0, "(1) Jobs reset.");
		}

		if( bits & 2 ) {
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM acpeerstates;");
			mrmailbox_log_info(ths, 0, "(2) Peerstates reset.");
		}

		if( bits & 4 ) {
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM keypairs;");
			mrmailbox_log_info(ths, 0, "(4) Private keypairs reset.");
		}

		if( bits & 8 ) {
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM contacts WHERE id>" MR_STRINGIFY(MR_CONTACT_ID_LAST_SPECIAL) ";"); /* the other IDs are reserved - leave these rows to make sure, the IDs are not used by normal contacts*/
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM chats WHERE id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL) ";");
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM chats_contacts;");
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM msgs WHERE id>" MR_STRINGIFY(MR_MSG_ID_LAST_SPECIAL) ";");
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM config WHERE keyname LIKE 'imap.%' OR keyname LIKE 'configured%';");
			mrsqlite3_execute__(ths->m_sql, "DELETE FROM leftgrps;");
			mrmailbox_log_info(ths, 0, "(8) Rest but server config reset.");
		}

	mrsqlite3_unlock(ths->m_sql);

	ths->m_cb(ths, MR_EVENT_MSGS_CHANGED, 0, 0);

	return 1;
}


/*
 * Clean up the contacts table. This function is called from Core cmdline.
 *
 * All contacts not involved in a chat, not blocked and not being a deaddrop
 * are removed.
 *
 * Deleted contacts from the OS address book normally stay in the contacts
 * database. With this cleanup, they are also removed, as well as all
 * auto-added contacts, unless they are used in a chat or for blocking purpose.
 */
static int mrmailbox_cleanup_contacts(mrmailbox_t* ths)
{
	if( ths == NULL || ths->m_magic != MR_MAILBOX_MAGIC ) {
		return 0;
	}

	mrmailbox_log_info(ths, 0, "Cleaning up contacts ...");

	mrsqlite3_lock(ths->m_sql);

		mrsqlite3_execute__(ths->m_sql, "DELETE FROM contacts WHERE id>" MR_STRINGIFY(MR_CONTACT_ID_LAST_SPECIAL) " AND blocked=0 AND NOT EXISTS (SELECT contact_id FROM chats_contacts where contacts.id = chats_contacts.contact_id) AND NOT EXISTS (select from_id from msgs WHERE msgs.from_id = contacts.id);");

	mrsqlite3_unlock(ths->m_sql);

	return 1;
}

static int mrmailbox_poke_eml_file(mrmailbox_t* ths, const char* filename)
{
	/* mainly for testing, may be called by mrmailbox_import_spec() */
	int     success = 0;
	char*   data = NULL;
	size_t  data_bytes;

	if( ths == NULL || ths->m_magic != MR_MAILBOX_MAGIC ) {
		return 0;
	}

	if( mr_read_file(filename, (void**)&data, &data_bytes, ths) == 0 ) {
		goto cleanup;
	}

	mrmailbox_receive_imf(ths, data, data_bytes, "import", 0, 0); /* this static function is the reason why this function is not moved to mrmailbox_imex.c */
	success = 1;

cleanup:
	free(data);

	return success;
}


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

		if( mrapeerstate_load_by_addr__(peerstate, mailbox->m_sql, addr) ) {
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


/*
 * Import a file to the database.
 * For testing, import a folder with eml-files, a single eml-file, e-mail plus public key and so on.
 * For normal importing, use mrmailbox_imex().
 *
 * @private @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 *
 * @param spec The file or directory to import. NULL for the last command.
 *
 * @return 1=success, 0=error.
 */
static int poke_spec(mrmailbox_t* mailbox, const char* spec)
{
	int            success = 0;
	char*          real_spec = NULL;
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
	if( spec )
	{
		real_spec = safe_strdup(spec);
		mrsqlite3_lock(mailbox->m_sql);
			mrsqlite3_set_config__(mailbox->m_sql, "import_spec", real_spec);
		mrsqlite3_unlock(mailbox->m_sql);
	}
	else {
		mrsqlite3_lock(mailbox->m_sql);
			real_spec = mrsqlite3_get_config__(mailbox->m_sql, "import_spec", NULL); /* may still NULL */
		mrsqlite3_unlock(mailbox->m_sql);
		if( real_spec == NULL ) {
			mrmailbox_log_error(mailbox, 0, "Import: No file or folder given.");
			goto cleanup;
		}
	}

	suffix = mr_get_filesuffix_lc(real_spec);
	if( suffix && strcmp(suffix, "eml")==0 ) {
		/* import a single file */
		if( mrmailbox_poke_eml_file(mailbox, real_spec) ) { /* errors are logged in any case */
			read_cnt++;
		}
	}
	else if( suffix && (strcmp(suffix, "pem")==0||strcmp(suffix, "asc")==0) ) {
		/* import a publix key */
		char* separator = strchr(real_spec, ' ');
		if( separator==NULL ) {
			mrmailbox_log_error(mailbox, 0, "Import: Key files must be specified as \"<addr> <key-file>\".");
			goto cleanup;
		}
		*separator = 0;
		if( poke_public_key(mailbox, real_spec, separator+1) ) {
			read_cnt++;
		}
		*separator = ' ';
	}
	else {
		/* import a directory */
		if( (dir=opendir(real_spec))==NULL ) {
			mrmailbox_log_error(mailbox, 0, "Import: Cannot open directory \"%s\".", real_spec);
			goto cleanup;
		}

		while( (dir_entry=readdir(dir))!=NULL ) {
			name = dir_entry->d_name; /* name without path; may also be `.` or `..` */
			if( strlen(name)>=4 && strcmp(&name[strlen(name)-4], ".eml")==0 ) {
				char* path_plus_name = mr_mprintf("%s/%s", real_spec, name);
				mrmailbox_log_info(mailbox, 0, "Import: %s", path_plus_name);
				if( mrmailbox_poke_eml_file(mailbox, path_plus_name) ) { /* no abort on single errors errors are logged in any case */
					read_cnt++;
				}
				free(path_plus_name);
            }
		}
	}

	mrmailbox_log_info(mailbox, 0, "Import: %i items read from \"%s\".", read_cnt, real_spec);
	if( read_cnt > 0 ) {
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0); /* even if read_cnt>0, the number of messages added to the database may be 0. While we regard this issue using IMAP, we ignore it here. */
	}

	success = 1;

cleanup:
	if( dir ) { closedir(dir); }
	free(real_spec);
	free(suffix);
	return success;
}


static void log_msglist(mrmailbox_t* mailbox, mrarray_t* msglist)
{
	int i, cnt = mrarray_get_cnt(msglist), lines_out = 0;
	for( i = 0; i < cnt; i++ )
	{
		uint32_t msg_id = mrarray_get_id(msglist, i);
		if( msg_id == MR_MSG_ID_DAYMARKER ) {
			mrmailbox_log_info(mailbox, 0, "--------------------------------------------------------------------------------"); lines_out++;
		}
		else if( msg_id > 0 ) {
			if( lines_out==0 ) { mrmailbox_log_info(mailbox, 0, "--------------------------------------------------------------------------------"); lines_out++; }

			mrmsg_t* msg = mrmailbox_get_msg(mailbox, msg_id);
			mrcontact_t* contact = mrmailbox_get_contact(mailbox, mrmsg_get_from_id(msg));
			char* contact_name = mrcontact_get_name(contact);
			int contact_id = mrcontact_get_id(contact);

			const char* statestr = "";
			switch( mrmsg_get_state(msg) ) {
				case MR_STATE_OUT_PENDING:   statestr = " o";   break;
				case MR_STATE_OUT_DELIVERED: statestr = " √";   break;
				case MR_STATE_OUT_MDN_RCVD:  statestr = " √√";  break;
				case MR_STATE_OUT_ERROR:     statestr = " ERR"; break;
			}

			char* temp2 = mr_timestamp_to_str(mrmsg_get_timestamp(msg));
			char* msgtext = mrmsg_get_text(msg);
				mrmailbox_log_info(mailbox, 0, "Msg#%i%s: %s (Contact#%i): %s %s%s%s%s [%s]",
					(int)mrmsg_get_id(msg),
					mrmsg_get_showpadlock(msg)? "\xF0\x9F\x94\x92" : "",
					contact_name,
					contact_id,
					msgtext,
					mrmsg_is_starred(msg)? " \xE2\x98\x85" : "",
					mrmsg_get_from_id(msg)==1? "" : (mrmsg_get_state(msg)==MR_STATE_IN_SEEN? "[SEEN]" : (mrmsg_get_state(msg)==MR_STATE_IN_NOTICED? "[NOTICED]":"[FRESH]")),
					mrmsg_is_systemcmd(msg)? "[SYSTEM]" : "",
					statestr,
					temp2);
			free(msgtext);
			free(temp2);
			free(contact_name);

			mrcontact_unref(contact);
			mrmsg_unref(msg);
		}
	}

	if( lines_out > 0 ) { mrmailbox_log_info(mailbox, 0, "--------------------------------------------------------------------------------"); }
}


static void log_contactlist(mrmailbox_t* mailbox, mrarray_t* contacts)
{
	int             i, cnt = mrarray_get_cnt(contacts);
	mrcontact_t*    contact = NULL;
	mrapeerstate_t* peerstate = mrapeerstate_new();

	for( i = 0; i < cnt; i++ ) {
		uint32_t contact_id = mrarray_get_id(contacts, i);
		char* line = NULL;
		char* line2 = NULL;
		if( (contact=mrmailbox_get_contact(mailbox, contact_id))!=NULL ) {
			char* name = mrcontact_get_name(contact);
			char* addr = mrcontact_get_addr(contact);
			line = mr_mprintf("%s, %s", (name&&name[0])? name : "<name unset>", (addr&&addr[0])? addr : "<addr unset>");
			mrsqlite3_lock(mailbox->m_sql);
				int peerstate_ok = mrapeerstate_load_by_addr__(peerstate, mailbox->m_sql, addr);
			mrsqlite3_unlock(mailbox->m_sql);
			if( peerstate_ok && contact_id != MR_CONTACT_ID_SELF ) {
				char* pe = NULL;
				switch( peerstate->m_prefer_encrypt ) {
					case MRA_PE_MUTUAL:       pe = safe_strdup("mutual");                                         break;
					case MRA_PE_NOPREFERENCE: pe = safe_strdup("no-preference");                                  break;
					case MRA_PE_RESET:        pe = safe_strdup("reset");                                          break;
					default:                  pe = mr_mprintf("unknown-value (%i)", peerstate->m_prefer_encrypt); break;
				}
				line2 = mr_mprintf(", prefer-encrypt=%s", pe);
				free(pe);
			}
			mrcontact_unref(contact);
			free(name);
			free(addr);
		}
		else {
			line = safe_strdup("Read error.");
		}
		mrmailbox_log_info(mailbox, 0, "Contact#%i: %s%s", (int)contact_id, line, line2? line2:"");
		free(line);
		free(line2);
	}

	mrapeerstate_unref(peerstate);
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
		if( arg1 && strcmp(arg1, "imex")==0 )
		{
			ret = safe_strdup(
				"====================Import/Export commands==\n"
				"initiate-key-transfer\n"
				"get-setupcodebegin <msg-id>\n"
				"continue-key-transfer <msg-id> <setup-code>\n"
				"has-backup\n"
				"export-backup\n"
				"import-backup <backup-file>\n"
				"export-keys\n"
				"import-keys\n"
				"export-setup\n"
				"poke [<eml-file>|<folder>|<addr> <key-file>]\n"
				"reset <flags>\n"
				"============================================="
			);
		}
		else
		{
			ret = safe_strdup(
				"==========================Database commands==\n"
				"info\n"
				"open <file to open or create>\n"
				"close\n"
				"set <configuration-key> [<value>]\n"
				"get <configuration-key>\n"
				"configure\n"
				"connect\n"
				"disconnect\n"
				"help imex (Import/Export)\n"
				"==============================Chat commands==\n"
				"listchats [<query>]\n"
				"listarchived\n"
				"chat [<chat-id>|0]\n"
				"createchat <contact-id>\n"
				"createchatbymsg <msg-id>\n"
				"creategroup <name>\n"
				"addmember <contact-id>\n"
				"removemember <contact-id>\n"
				"groupname <name>\n"
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
				"===========================Message commands==\n"
				"listmsgs <query>\n"
				"msginfo <msg-id>\n"
				"listfresh\n"
				"forward <msg-id> <chat-id>\n"
				"markseen <msg-id>\n"
				"star <msg-id>\n"
				"unstar <msg-id>\n"
				"delmsg <msg-id>\n"
				"===========================Contact commands==\n"
				"listcontacts [<query>]\n"
				"addcontact [<name>] <addr>\n"
				"contactinfo <contact-id>\n"
				"delcontact <contact-id>\n"
				"cleanupcontacts\n"
				"======================================Misc.==\n"
				"getqr\n"
				"getbadqr\n"
				"checkqr <qr-contenct>\n"
				"event <event-id to test>\n"
				"fileinfo <file>\n"
				"heartbeat\n"
				"clear -- clear screen\n" /* must be implemented by  the caller */
				"exit\n" /* must be implemented by  the caller */
				"============================================="
			);
		}
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
	else if( strcmp(cmd, "initiate-key-transfer")==0 )
	{
		char* setup_code = mrmailbox_initiate_key_transfer(mailbox);
			ret = setup_code? mr_mprintf("Setup code for the transferred setup message: %s", setup_code) : COMMAND_FAILED;
		free(setup_code);
	}
	else if( strcmp(cmd, "get-setupcodebegin")==0 )
	{
		if( arg1 ) {
			uint32_t msg_id = (uint32_t)atoi(arg1);
			mrmsg_t* msg = mrmailbox_get_msg(mailbox, msg_id);
			if( mrmsg_is_setupmessage(msg) ) {
				char* setupcodebegin = mrmsg_get_setupcodebegin(msg);
					ret = mr_mprintf("The setup code for setup message Msg#%i starts with: %s", msg_id, setupcodebegin);
				free(setupcodebegin);
			}
			else {
				ret = mr_mprintf("ERROR: Msg#%i is no setup message.", msg_id);
			}
			mrmsg_unref(msg);
		}
		else {
			ret = safe_strdup("ERROR: Argument <msg-id> missing.");
		}
	}
	else if( strcmp(cmd, "continue-key-transfer")==0 )
	{
		char* arg2 = NULL;
		if( arg1 ) { arg2 = strrchr(arg1, ' '); }
		if( arg1 && arg2 ) {
			*arg2 = 0; arg2++;
			ret = mrmailbox_continue_key_transfer(mailbox, atoi(arg1), arg2)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Arguments <msg-id> <setup-code> expected.");
		}
	}
	else if( strcmp(cmd, "has-backup")==0 )
	{
		ret = mrmailbox_imex_has_backup(mailbox, mailbox->m_blobdir);
		if( ret == NULL ) {
			ret = safe_strdup("No backup found.");
		}
	}
	else if( strcmp(cmd, "export-backup")==0 )
	{
		ret = mrmailbox_imex(mailbox, MR_IMEX_EXPORT_BACKUP, mailbox->m_blobdir, NULL)? COMMAND_SUCCEEDED : COMMAND_FAILED;
	}
	else if( strcmp(cmd, "import-backup")==0 )
	{
		if( arg1 ) {
			ret = mrmailbox_imex(mailbox, MR_IMEX_IMPORT_BACKUP, arg1, NULL)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <backup-file> missing.");
		}
	}
	else if( strcmp(cmd, "export-keys")==0 )
	{
		ret = mrmailbox_imex(mailbox, MR_IMEX_EXPORT_SELF_KEYS, mailbox->m_blobdir, NULL)? COMMAND_SUCCEEDED : COMMAND_FAILED;
	}
	else if( strcmp(cmd, "import-keys")==0 )
	{
		ret = mrmailbox_imex(mailbox, MR_IMEX_IMPORT_SELF_KEYS, mailbox->m_blobdir, NULL)? COMMAND_SUCCEEDED : COMMAND_FAILED;
	}
	else if( strcmp(cmd, "export-setup")==0 )
	{
		char* setup_code = mrmailbox_create_setup_code(mailbox);
		char* file_name = mr_mprintf("%s/autocrypt-setup-message.html", mailbox->m_blobdir);
		char* file_content = NULL;
			if( (file_content=mrmailbox_render_setup_file(mailbox, setup_code)) != NULL
			 && mr_write_file(file_name, file_content, strlen(file_content), mailbox) ) {
				ret = mr_mprintf("Setup message written to: %s\nSetup code: %s", file_name, setup_code);
			}
			else {
				ret = COMMAND_FAILED;
			}
		free(file_content);
		free(file_name);
		free(setup_code);
	}
	else if( strcmp(cmd, "poke")==0 )
	{
		ret = poke_spec(mailbox, arg1)? COMMAND_SUCCEEDED : COMMAND_FAILED;
	}
	else if( strcmp(cmd, "reset")==0 )
	{
		if( arg1 ) {
			int bits = atoi(arg1);
			if( bits > 15 ) {
				ret = safe_strdup("ERROR: <bits> must be lower than 16.");
			}
			else {
				ret = mrmailbox_reset_tables(mailbox, bits)? COMMAND_SUCCEEDED : COMMAND_FAILED;
			}
		}
		else {
			ret = safe_strdup("ERROR: Argument <bits> missing: 1=jobs, 2=peerstates, 4=private keys, 8=rest but server config");
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
		ret = mrmailbox_configure_and_connect(mailbox)? COMMAND_SUCCEEDED : COMMAND_FAILED;
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
					mrchat_t* chat = mrmailbox_get_chat(mailbox, mrchatlist_get_chat_id(chatlist, i));

					char* temp_subtitle = mrchat_get_subtitle(chat);
					char* temp_name = mrchat_get_name(chat);
						mrmailbox_log_info(mailbox, 0, "%s#%i: %s [%s] [%i fresh]", mrchat_get_type(chat)==MR_CHAT_TYPE_GROUP? "Groupchat" : "Chat",
							(int)mrchat_get_id(chat), temp_name, temp_subtitle, (int)mrmailbox_get_fresh_msg_count(mailbox, mrchat_get_id(chat)));
					free(temp_subtitle);
					free(temp_name);

					mrpoortext_t* poortext = mrchatlist_get_summary(chatlist, i, chat);

						const char* statestr = "";
						if( mrchat_get_archived(chat) ) {
							statestr = " [Archived]";
						}
						else switch( mrlot_get_state(poortext) ) {
							case MR_STATE_OUT_PENDING:   statestr = " o";   break;
							case MR_STATE_OUT_DELIVERED: statestr = " √";   break;
							case MR_STATE_OUT_MDN_RCVD:  statestr = " √√";  break;
							case MR_STATE_OUT_ERROR:     statestr = " ERR"; break;
						}

						char* timestr = mr_timestamp_to_str(mrlot_get_timestamp(poortext));
						char* text1 = mrlot_get_text1(poortext);
						char* text2 = mrlot_get_text2(poortext);
							mrmailbox_log_info(mailbox, 0, "%s%s%s%s [%s]",
								text1? text1 : "",
								text1? ": " : "",
								text2? text2 : "",
								statestr, timestr
								);
						free(text1);
						free(text2);
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
			mrarray_t* msglist = mrmailbox_get_chat_msgs(mailbox, mrchat_get_id(sel_chat), MR_GCM_ADDDAYMARKER, 0);
			char* temp2 = mrchat_get_subtitle(sel_chat);
			char* temp_name = mrchat_get_name(sel_chat);
				mrmailbox_log_info(mailbox, 0, "Chat#%i: %s [%s]", mrchat_get_id(sel_chat), temp_name, temp2);
			free(temp_name);
			free(temp2);
			if( msglist ) {
				log_msglist(mailbox, msglist);
				mrarray_unref(msglist);
			}
			if( mrchat_get_draft_timestamp(sel_chat) ) {
				char* timestr = mr_timestamp_to_str(mrchat_get_draft_timestamp(sel_chat));
				char* drafttext = mrchat_get_draft(sel_chat);
					mrmailbox_log_info(mailbox, 0, "Draft: %s [%s]", drafttext, timestr);
				free(drafttext);
				free(timestr);
			}
			ret = mr_mprintf("%i messages.", mrmailbox_get_total_msg_count(mailbox, mrchat_get_id(sel_chat)));
			mrmailbox_marknoticed_chat(mailbox, mrchat_get_id(sel_chat));
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
	else if( strcmp(cmd, "createchatbymsg")==0 )
	{
		if( arg1 ) {
			int msg_id = atoi(arg1);
			int chat_id = mrmailbox_create_chat_by_msg_id(mailbox, msg_id);
			ret = chat_id!=0? mr_mprintf("Chat#%lu created successfully.", chat_id) : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <msg-id> missing.");
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
				if( mrmailbox_add_contact_to_chat(mailbox, mrchat_get_id(sel_chat), contact_id) ) {
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
				if( mrmailbox_remove_contact_from_chat(mailbox, mrchat_get_id(sel_chat), contact_id) ) {
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
	else if( strcmp(cmd, "groupname")==0 )
	{
		if( sel_chat ) {
			if( arg1 && arg1[0] ) {
				ret = mrmailbox_set_chat_name(mailbox, mrchat_get_id(sel_chat), arg1)? COMMAND_SUCCEEDED : COMMAND_FAILED;
			}
			else {
				ret = safe_strdup("ERROR: Argument <name> missing.");
			}
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "groupimage")==0 )
	{
		if( sel_chat ) {
			ret = mrmailbox_set_chat_profile_image(mailbox, mrchat_get_id(sel_chat), (arg1&&arg1[0])?arg1:NULL)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "chatinfo")==0 )
	{
		if( sel_chat ) {
			mrarray_t* contacts = mrmailbox_get_chat_contacts(mailbox, mrchat_get_id(sel_chat));
			if( contacts ) {
				mrmailbox_log_info(mailbox, 0, "Memberlist:");
				log_contactlist(mailbox, contacts);
				ret = mr_mprintf("%i contacts.", (int)mrarray_get_cnt(contacts));
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
				if( mrmailbox_send_text_msg(mailbox, mrchat_get_id(sel_chat), arg1) ) {
					ret = safe_strdup("Message sent.");
				}
				else {
					ret = safe_strdup("ERROR: Sending failed.");
				}
			}
			else {
				ret = safe_strdup("ERROR: No message text given.");
			}
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "sendimage")==0 )
	{
		if( sel_chat ) {
			if( arg1 && arg1[0] ) {
				if( mrmailbox_send_image_msg(mailbox, mrchat_get_id(sel_chat), arg1, NULL, 0, 0) ) {
					ret = safe_strdup("Image sent.");
				}
				else {
					ret = safe_strdup("ERROR: Sending image failed.");
				}
			}
			else {
				ret = safe_strdup("ERROR: No image given.");
			}
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "sendfile")==0 )
	{
		if( sel_chat ) {
			if( arg1 && arg1[0] ) {
				if( mrmailbox_send_file_msg(mailbox, mrchat_get_id(sel_chat), arg1, NULL) ) {
					ret = safe_strdup("File sent.");
				}
				else {
					ret = safe_strdup("ERROR: Sending file failed.");
				}
			}
			else {
				ret = safe_strdup("ERROR: No file given.");
			}
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "listmsgs")==0 )
	{
		if( arg1 ) {
			mrarray_t* msglist = mrmailbox_search_msgs(mailbox, sel_chat? mrchat_get_id(sel_chat) : 0, arg1);
			if( msglist ) {
				log_msglist(mailbox, msglist);
				ret = mr_mprintf("%i messages.", (int)mrarray_get_cnt(msglist));
				mrarray_unref(msglist);
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
				mrmailbox_set_draft(mailbox, mrchat_get_id(sel_chat), arg1);
				ret = safe_strdup("Draft saved.");
			}
			else {
				mrmailbox_set_draft(mailbox, mrchat_get_id(sel_chat), NULL);
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
			mrarray_t* images = mrmailbox_get_chat_media(mailbox, mrchat_get_id(sel_chat), MR_MSG_IMAGE, MR_MSG_VIDEO);
			int i, icnt = mrarray_get_cnt(images);
			ret = mr_mprintf("%i images or videos: ", icnt);
			for( i = 0; i < icnt; i++ ) {
				char* temp = mr_mprintf("%s%sMsg#%i", i? ", ":"", ret, (int)mrarray_get_id(images, i));
				free(ret);
				ret = temp;
			}
			mrarray_unref(images);
		}
		else {
			ret = safe_strdup("No chat selected.");
		}
	}
	else if( strcmp(cmd, "archive")==0 || strcmp(cmd, "unarchive")==0 )
	{
		if( arg1 ) {
			int chat_id = atoi(arg1);
			mrmailbox_archive_chat(mailbox, chat_id, strcmp(cmd, "archive")==0? 1 : 0);
			ret = COMMAND_SUCCEEDED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <chat-id> missing.");
		}
	}
	else if( strcmp(cmd, "delchat")==0 )
	{
		if( arg1 ) {
			int chat_id = atoi(arg1);
			mrmailbox_delete_chat(mailbox, chat_id);
			ret = COMMAND_SUCCEEDED;
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
		mrarray_t* msglist = mrmailbox_get_fresh_msgs(mailbox);
		if( msglist ) {
			log_msglist(mailbox, msglist);
			ret = mr_mprintf("%i fresh messages.", (int)mrarray_get_cnt(msglist));
			mrarray_unref(msglist);
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
			mrmailbox_forward_msgs(mailbox, msg_ids, 1, chat_id);
			ret = COMMAND_SUCCEEDED;
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
			mrmailbox_markseen_msgs(mailbox, msg_ids, 1);
			ret = COMMAND_SUCCEEDED;
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
			mrmailbox_star_msgs(mailbox, msg_ids, 1, strcmp(cmd, "star")==0? 1 : 0);
			ret = COMMAND_SUCCEEDED;
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
			mrmailbox_delete_msgs(mailbox, ids, 1);
			ret = COMMAND_SUCCEEDED;
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
		mrarray_t* contacts = mrmailbox_get_known_contacts(mailbox, arg1);
		if( contacts ) {
			log_contactlist(mailbox, contacts);
			ret = mr_mprintf("%i contacts.", (int)mrarray_get_cnt(contacts));
			mrarray_unref(contacts);
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
		else if( arg1 ) {
			ret = mrmailbox_create_contact(mailbox, NULL, arg1)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Arguments [<name>] <addr> expected.");
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
	else if( strcmp(cmd, "delcontact")==0 )
	{
		if( arg1 ) {
			ret = mrmailbox_delete_contact(mailbox, atoi(arg1))? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <contact-id> missing.");
		}
	}
	else if( strcmp(cmd, "cleanupcontacts")==0 )
	{
		ret = mrmailbox_cleanup_contacts(mailbox)? COMMAND_SUCCEEDED : COMMAND_FAILED;
	}

	/*******************************************************************************
	 * Misc.
	 ******************************************************************************/

	else if( strcmp(cmd, "getqr")==0 )
	{
		ret = mrmailbox_oob_get_qr(mailbox);
	}
	else if( strcmp(cmd, "checkqr")==0 )
	{
		if( arg1 ) {
			mrlot_t* res = mrmailbox_check_qr(mailbox, arg1);
				ret = mr_mprintf("state=%i, id=%i, text1=%s, text2=%s", (int)res->m_state, res->m_id, res->m_text1? res->m_text1:"", res->m_text2? res->m_text2:"");
			mrlot_unref(res);
		}
		else {
			ret = safe_strdup("ERROR: Argument <qr-content> missing.");
		}
	}
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


