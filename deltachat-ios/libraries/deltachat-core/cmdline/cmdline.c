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


/* If you do not want to use dc_cmdline(), this file MAY NOT included to
your library */


#include <dirent.h>
#include "../src/dc_context.h"
#include "../src/dc_aheader.h"
#include "../src/dc_apeerstate.h"
#include "../src/dc_key.h"
#include "../src/dc_pgp.h"



/*
 * Reset database tables. This function is called from Core cmdline.
 *
 * Argument is a bitmask, executing single or multiple actions in one call.
 *
 * e.g. bitmask 7 triggers actions definded with bits 1, 2 and 4.
 */
int dc_reset_tables(dc_context_t* context, int bits)
{
	if (context == NULL || context->magic != DC_CONTEXT_MAGIC) {
		return 0;
	}

	dc_log_info(context, 0, "Resetting tables (%i)...", bits);

	if (bits & 1) {
		dc_sqlite3_execute(context->sql, "DELETE FROM jobs;");
		dc_log_info(context, 0, "(1) Jobs reset.");
	}

	if (bits & 2) {
		dc_sqlite3_execute(context->sql, "DELETE FROM acpeerstates;");
		dc_log_info(context, 0, "(2) Peerstates reset.");
	}

	if (bits & 4) {
		dc_sqlite3_execute(context->sql, "DELETE FROM keypairs;");
		dc_log_info(context, 0, "(4) Private keypairs reset.");
	}

	if (bits & 8) {
		dc_sqlite3_execute(context->sql, "DELETE FROM contacts WHERE id>" DC_STRINGIFY(DC_CONTACT_ID_LAST_SPECIAL) ";"); /* the other IDs are reserved - leave these rows to make sure, the IDs are not used by normal contacts*/
		dc_sqlite3_execute(context->sql, "DELETE FROM chats WHERE id>" DC_STRINGIFY(DC_CHAT_ID_LAST_SPECIAL) ";");
		dc_sqlite3_execute(context->sql, "DELETE FROM chats_contacts;");
		dc_sqlite3_execute(context->sql, "DELETE FROM msgs WHERE id>" DC_STRINGIFY(DC_MSG_ID_LAST_SPECIAL) ";");
		dc_sqlite3_execute(context->sql, "DELETE FROM config WHERE keyname LIKE 'imap.%' OR keyname LIKE 'configured%';");
		dc_sqlite3_execute(context->sql, "DELETE FROM leftgrps;");
		dc_log_info(context, 0, "(8) Rest but server config reset.");
	}

	context->cb(context, DC_EVENT_MSGS_CHANGED, 0, 0);

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
static int dc_cleanup_contacts(dc_context_t* context)
{
	if (context == NULL || context->magic != DC_CONTEXT_MAGIC) {
		return 0;
	}

	dc_log_info(context, 0, "Cleaning up contacts ...");

	dc_sqlite3_execute(context->sql, "DELETE FROM contacts WHERE id>" DC_STRINGIFY(DC_CONTACT_ID_LAST_SPECIAL) " AND blocked=0 AND NOT EXISTS (SELECT contact_id FROM chats_contacts where contacts.id = chats_contacts.contact_id) AND NOT EXISTS (select from_id from msgs WHERE msgs.from_id = contacts.id);");

	return 1;
}

static int dc_poke_eml_file(dc_context_t* context, const char* filename)
{
	/* mainly for testing, may be called by dc_import_spec() */
	int     success = 0;
	char*   data = NULL;
	size_t  data_bytes;

	if (context == NULL || context->magic != DC_CONTEXT_MAGIC) {
		return 0;
	}

	if (dc_read_file(filename, (void**)&data, &data_bytes, context) == 0) {
		goto cleanup;
	}

	dc_receive_imf(context, data, data_bytes, "import", 0, 0); /* this static function is the reason why this function is not moved to dc_imex.c */
	success = 1;

cleanup:
	free(data);

	return success;
}


static int poke_public_key(dc_context_t* context, const char* addr, const char* public_key_file)
{
	/* mainly for testing: if the partner does not support Autocrypt,
	encryption is disabled as soon as the first messages comes from the partner */
	dc_aheader_t*    header = dc_aheader_new();
	dc_apeerstate_t* peerstate = dc_apeerstate_new(context);
	int              success = 0;

	if (addr==NULL || public_key_file==NULL || peerstate==NULL || header==NULL) {
		goto cleanup;
	}

	/* create a fake autocrypt header */
	header->addr             = dc_strdup(addr);
	header->prefer_encrypt   = DC_PE_MUTUAL;
	if (!dc_key_set_from_file(header->public_key, public_key_file, context)
	 || !dc_pgp_is_valid_key(context, header->public_key)) {
		dc_log_warning(context, 0, "No valid key found in \"%s\".", public_key_file);
		goto cleanup;
	}

	/* update/create peerstate */
	if (dc_apeerstate_load_by_addr(peerstate, context->sql, addr)) {
		dc_apeerstate_apply_header(peerstate, header, time(NULL));
		dc_apeerstate_save_to_db(peerstate, context->sql, 0);
	}
	else {
		dc_apeerstate_init_from_header(peerstate, header, time(NULL));
		dc_apeerstate_save_to_db(peerstate, context->sql, 1);
	}

	success = 1;

cleanup:
	dc_apeerstate_unref(peerstate);
	dc_aheader_unref(header);
	return success;
}


/**
 * Import a file to the database.
 * For testing, import a folder with eml-files, a single eml-file, e-mail plus public key and so on.
 * For normal importing, use dc_imex().
 *
 * @private @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @param spec The file or directory to import. NULL for the last command.
 * @return 1=success, 0=error.
 */
static int poke_spec(dc_context_t* context, const char* spec)
{
	int            success = 0;
	char*          real_spec = NULL;
	char*          suffix = NULL;
	DIR*           dir = NULL;
	struct dirent* dir_entry;
	int            read_cnt = 0;
	char*          name;

	if (context == NULL) {
		return 0;
	}

	if (!dc_sqlite3_is_open(context->sql)) {
        dc_log_error(context, 0, "Import: Database not opened.");
		goto cleanup;
	}

	/* if `spec` is given, remember it for later usage; if it is not given, try to use the last one */
	if (spec)
	{
		real_spec = dc_strdup(spec);
		dc_sqlite3_set_config(context->sql, "import_spec", real_spec);
	}
	else {
		real_spec = dc_sqlite3_get_config(context->sql, "import_spec", NULL); /* may still NULL */
		if (real_spec == NULL) {
			dc_log_error(context, 0, "Import: No file or folder given.");
			goto cleanup;
		}
	}

	suffix = dc_get_filesuffix_lc(real_spec);
	if (suffix && strcmp(suffix, "eml")==0) {
		/* import a single file */
		if (dc_poke_eml_file(context, real_spec)) { /* errors are logged in any case */
			read_cnt++;
		}
	}
	else if (suffix && (strcmp(suffix, "pem")==0||strcmp(suffix, "asc")==0)) {
		/* import a publix key */
		char* separator = strchr(real_spec, ' ');
		if (separator==NULL) {
			dc_log_error(context, 0, "Import: Key files must be specified as \"<addr> <key-file>\".");
			goto cleanup;
		}
		*separator = 0;
		if (poke_public_key(context, real_spec, separator+1)) {
			read_cnt++;
		}
		*separator = ' ';
	}
	else {
		/* import a directory */
		if ((dir=opendir(real_spec))==NULL) {
			dc_log_error(context, 0, "Import: Cannot open directory \"%s\".", real_spec);
			goto cleanup;
		}

		while ((dir_entry=readdir(dir))!=NULL) {
			name = dir_entry->d_name; /* name without path; may also be `.` or `..` */
			if (strlen(name)>=4 && strcmp(&name[strlen(name)-4], ".eml")==0) {
				char* path_plus_name = dc_mprintf("%s/%s", real_spec, name);
				dc_log_info(context, 0, "Import: %s", path_plus_name);
				if (dc_poke_eml_file(context, path_plus_name)) { /* no abort on single errors errors are logged in any case */
					read_cnt++;
				}
				free(path_plus_name);
            }
		}
	}

	dc_log_info(context, 0, "Import: %i items read from \"%s\".", read_cnt, real_spec);
	if (read_cnt > 0) {
		context->cb(context, DC_EVENT_MSGS_CHANGED, 0, 0); /* even if read_cnt>0, the number of messages added to the database may be 0. While we regard this issue using IMAP, we ignore it here. */
	}

	success = 1;

cleanup:
	if (dir) { closedir(dir); }
	free(real_spec);
	free(suffix);
	return success;
}


static void log_msglist(dc_context_t* context, dc_array_t* msglist)
{
	int i, cnt = dc_array_get_cnt(msglist), lines_out = 0;
	for (i = 0; i < cnt; i++)
	{
		uint32_t msg_id = dc_array_get_id(msglist, i);
		if (msg_id == DC_MSG_ID_DAYMARKER) {
			dc_log_info(context, 0, "--------------------------------------------------------------------------------"); lines_out++;
		}
		else if (msg_id > 0) {
			if (lines_out==0) { dc_log_info(context, 0, "--------------------------------------------------------------------------------"); lines_out++; }

			dc_msg_t* msg = dc_get_msg(context, msg_id);
			dc_contact_t* contact = dc_get_contact(context, dc_msg_get_from_id(msg));
			char* contact_name = dc_contact_get_name(contact);
			int contact_id = dc_contact_get_id(contact);

			const char* statestr = "";
			switch (dc_msg_get_state(msg)) {
				case DC_STATE_OUT_PENDING:   statestr = " o";   break;
				case DC_STATE_OUT_DELIVERED: statestr = " √";   break;
				case DC_STATE_OUT_MDN_RCVD:  statestr = " √√";  break;
				case DC_STATE_OUT_FAILED:    statestr = " !!";  break;
			}

			char* temp2 = dc_timestamp_to_str(dc_msg_get_timestamp(msg));
			char* msgtext = dc_msg_get_text(msg);
				dc_log_info(context, 0, "Msg#%i%s: %s (Contact#%i): %s %s%s%s%s [%s]",
					(int)dc_msg_get_id(msg),
					dc_msg_get_showpadlock(msg)? "\xF0\x9F\x94\x92" : "",
					contact_name,
					contact_id,
					msgtext,
					dc_msg_is_starred(msg)? " \xE2\x98\x85" : "",
					dc_msg_get_from_id(msg)==1? "" : (dc_msg_get_state(msg)==DC_STATE_IN_SEEN? "[SEEN]" : (dc_msg_get_state(msg)==DC_STATE_IN_NOTICED? "[NOTICED]":"[FRESH]")),
					dc_msg_is_info(msg)? "[INFO]" : "",
					statestr,
					temp2);
			free(msgtext);
			free(temp2);
			free(contact_name);

			dc_contact_unref(contact);
			dc_msg_unref(msg);
		}
	}

	if (lines_out > 0) { dc_log_info(context, 0, "--------------------------------------------------------------------------------"); }
}


static void log_contactlist(dc_context_t* context, dc_array_t* contacts)
{
	int              i, cnt = dc_array_get_cnt(contacts);
	dc_contact_t*    contact = NULL;
	dc_apeerstate_t* peerstate = dc_apeerstate_new(context);

	for (i = 0; i < cnt; i++) {
		uint32_t contact_id = dc_array_get_id(contacts, i);
		char* line = NULL;
		char* line2 = NULL;
		if ((contact=dc_get_contact(context, contact_id))!=NULL) {
			char* name = dc_contact_get_name(contact);
			char* addr = dc_contact_get_addr(contact);
			int verified_state = dc_contact_is_verified(contact);
			const char* verified_str = verified_state? (verified_state==2? " √√":" √"): "";
			line = dc_mprintf("%s%s <%s>", (name&&name[0])? name : "<name unset>", verified_str, (addr&&addr[0])? addr : "addr unset");
			int peerstate_ok = dc_apeerstate_load_by_addr(peerstate, context->sql, addr);
			if (peerstate_ok && contact_id != DC_CONTACT_ID_SELF) {
				char* pe = NULL;
				switch (peerstate->prefer_encrypt) {
					case DC_PE_MUTUAL:       pe = dc_strdup("mutual");                                         break;
					case DC_PE_NOPREFERENCE: pe = dc_strdup("no-preference");                                  break;
					case DC_PE_RESET:        pe = dc_strdup("reset");                                          break;
					default:                 pe = dc_mprintf("unknown-value (%i)", peerstate->prefer_encrypt); break;
				}
				line2 = dc_mprintf(", prefer-encrypt=%s", pe);
				free(pe);
			}
			dc_contact_unref(contact);
			free(name);
			free(addr);
		}
		else {
			line = dc_strdup("Read error.");
		}
		dc_log_info(context, 0, "Contact#%i: %s%s", (int)contact_id, line, line2? line2:"");
		free(line);
		free(line2);
	}

	dc_apeerstate_unref(peerstate);
}


static int s_is_auth = 0;


void dc_cmdline_skip_auth()
{
	s_is_auth = 1;
}


static const char* chat_prefix(const dc_chat_t* chat)
{
	     if (chat->type == DC_CHAT_TYPE_GROUP) { return "Group"; }
	else if (chat->type == DC_CHAT_TYPE_VERIFIED_GROUP) { return "VerifiedGroup"; }
	else { return "Single"; }
}


char* dc_cmdline(dc_context_t* context, const char* cmdline)
{
	#define      COMMAND_FAILED    ((char*)1)
	#define      COMMAND_SUCCEEDED ((char*)2)
	#define      COMMAND_UNKNOWN   ((char*)3)
	char*        cmd = NULL, *arg1 = NULL, *ret = COMMAND_FAILED;
	dc_chat_t*   sel_chat = NULL;


	if (context == NULL || cmdline == NULL || cmdline[0]==0) {
		goto cleanup;
	}

	if (context->cmdline_sel_chat_id) {
		sel_chat = dc_get_chat(context, context->cmdline_sel_chat_id);
	}

	/* split commandline into command and first argument
	(the first argument may contain spaces, if this is undesired we split further arguments form if below. */
	cmd = dc_strdup(cmdline);
	arg1 = strchr(cmd, ' ');
	if (arg1) { *arg1 = 0; arg1++; }

	/* execute command */
	if (strcmp(cmd, "help")==0 || strcmp(cmd, "?")==0)
	{
		if (arg1 && strcmp(arg1, "imex")==0)
		{
			ret = dc_strdup(
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
			ret = dc_strdup(
				"==========================Database commands==\n"
				"info\n"
				"open <file to open or create>\n"
				"close\n"
				"set <configuration-key> [<value>]\n"
				"get <configuration-key>\n"
				"configure\n"
				"connect\n"
				"disconnect\n"
				"poll\n"
				"help imex (Import/Export)\n"
				"==============================Chat commands==\n"
				"listchats [<query>]\n"
				"listarchived\n"
				"chat [<chat-id>|0]\n"
				"createchat <contact-id>\n"
				"createchatbymsg <msg-id>\n"
				"creategroup <name>\n"
				"createverified <name>\n"
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
				"listverified [<query>]\n"
				"addcontact [<name>] <addr>\n"
				"contactinfo <contact-id>\n"
				"delcontact <contact-id>\n"
				"cleanupcontacts\n"
				"======================================Misc.==\n"
				"getqr [<chat-id>]\n"
				"getbadqr\n"
				"checkqr <qr-content>\n"
				"event <event-id to test>\n"
				"fileinfo <file>\n"
				"clear -- clear screen\n" /* must be implemented by  the caller */
				"exit\n" /* must be implemented by  the caller */
				"============================================="
			);
		}
	}
	else if (!s_is_auth)
	{
		if (strcmp(cmd, "auth")==0) {
			char* is_pw = dc_get_config(context, "mail_pw", "");
			if (strcmp(arg1, is_pw)==0) {
				s_is_auth = 1;
				ret = COMMAND_SUCCEEDED;
			}
			else {
				ret = "Bad password.";
			}
		}
		else {
			ret = dc_strdup("Please authorize yourself using: auth <password>");
		}
	}
	else if (strcmp(cmd, "auth")==0)
	{
		ret = dc_strdup("Already authorized.");
	}


	/*******************************************************************************
	 * Database commands
	 ******************************************************************************/

	else if (strcmp(cmd, "open")==0)
	{
		if (arg1) {
			dc_close(context);
			ret = dc_open(context, arg1, NULL)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = dc_strdup("ERROR: Argument <file> missing.");
		}
	}
	else if (strcmp(cmd, "close")==0)
	{
		dc_close(context);
		ret = COMMAND_SUCCEEDED;
	}
	else if (strcmp(cmd, "initiate-key-transfer")==0)
	{
		char* setup_code = dc_initiate_key_transfer(context);
			ret = setup_code? dc_mprintf("Setup code for the transferred setup message: %s", setup_code) : COMMAND_FAILED;
		free(setup_code);
	}
	else if (strcmp(cmd, "get-setupcodebegin")==0)
	{
		if (arg1) {
			uint32_t  msg_id = (uint32_t)atoi(arg1);
			dc_msg_t* msg = dc_get_msg(context, msg_id);
			if (dc_msg_is_setupmessage(msg)) {
				char* setupcodebegin = dc_msg_get_setupcodebegin(msg);
					ret = dc_mprintf("The setup code for setup message Msg#%i starts with: %s", msg_id, setupcodebegin);
				free(setupcodebegin);
			}
			else {
				ret = dc_mprintf("ERROR: Msg#%i is no setup message.", msg_id);
			}
			dc_msg_unref(msg);
		}
		else {
			ret = dc_strdup("ERROR: Argument <msg-id> missing.");
		}
	}
	else if (strcmp(cmd, "continue-key-transfer")==0)
	{
		char* arg2 = NULL;
		if (arg1) { arg2 = strrchr(arg1, ' '); }
		if (arg1 && arg2) {
			*arg2 = 0; arg2++;
			ret = dc_continue_key_transfer(context, atoi(arg1), arg2)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = dc_strdup("ERROR: Arguments <msg-id> <setup-code> expected.");
		}
	}
	else if (strcmp(cmd, "has-backup")==0)
	{
		ret = dc_imex_has_backup(context, context->blobdir);
		if (ret == NULL) {
			ret = dc_strdup("No backup found.");
		}
	}
	else if (strcmp(cmd, "export-backup")==0)
	{
		dc_imex(context, DC_IMEX_EXPORT_BACKUP, context->blobdir, NULL);
		ret = COMMAND_SUCCEEDED;
	}
	else if (strcmp(cmd, "import-backup")==0)
	{
		if (arg1) {
			dc_imex(context, DC_IMEX_IMPORT_BACKUP, arg1, NULL);
			ret = COMMAND_SUCCEEDED;
		}
		else {
			ret = dc_strdup("ERROR: Argument <backup-file> missing.");
		}
	}
	else if (strcmp(cmd, "export-keys")==0)
	{
		dc_imex(context, DC_IMEX_EXPORT_SELF_KEYS, context->blobdir, NULL);
		ret = COMMAND_SUCCEEDED;
	}
	else if (strcmp(cmd, "import-keys")==0)
	{
		dc_imex(context, DC_IMEX_IMPORT_SELF_KEYS, context->blobdir, NULL);
		ret = COMMAND_SUCCEEDED;
	}
	else if (strcmp(cmd, "export-setup")==0)
	{
		char* setup_code = dc_create_setup_code(context);
		char* file_name = dc_mprintf("%s/autocrypt-setup-message.html", context->blobdir);
		char* file_content = NULL;
			if ((file_content=dc_render_setup_file(context, setup_code)) != NULL
			 && dc_write_file(file_name, file_content, strlen(file_content), context)) {
				ret = dc_mprintf("Setup message written to: %s\nSetup code: %s", file_name, setup_code);
			}
			else {
				ret = COMMAND_FAILED;
			}
		free(file_content);
		free(file_name);
		free(setup_code);
	}
	else if (strcmp(cmd, "poke")==0)
	{
		ret = poke_spec(context, arg1)? COMMAND_SUCCEEDED : COMMAND_FAILED;
	}
	else if (strcmp(cmd, "reset")==0)
	{
		if (arg1) {
			int bits = atoi(arg1);
			if (bits > 15) {
				ret = dc_strdup("ERROR: <bits> must be lower than 16.");
			}
			else {
				ret = dc_reset_tables(context, bits)? COMMAND_SUCCEEDED : COMMAND_FAILED;
			}
		}
		else {
			ret = dc_strdup("ERROR: Argument <bits> missing: 1=jobs, 2=peerstates, 4=private keys, 8=rest but server config");
		}
	}
	else if (strcmp(cmd, "set")==0)
	{
		if (arg1) {
			char* arg2 = strchr(arg1, ' ');
			if (arg2) {
				*arg2 = 0;
				arg2++;
			}
			ret = dc_set_config(context, arg1, arg2)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = dc_strdup("ERROR: Argument <key> missing.");
		}
	}
	else if (strcmp(cmd, "get")==0)
	{
		if (arg1) {
			char* val = dc_get_config(context, arg1, "<unset>");
			if (val) {
				ret = dc_mprintf("%s=%s", arg1, val);
				free(val);
			}
			else {
				ret = COMMAND_FAILED;
			}
		}
		else {
			ret = dc_strdup("ERROR: Argument <key> missing.");
		}
	}
	else if (strcmp(cmd, "info")==0)
	{
		ret = dc_get_info(context);
		if (ret == NULL) {
			ret = COMMAND_FAILED;
		}
	}

	/*******************************************************************************
	 * Chat commands
	 ******************************************************************************/

	else if (strcmp(cmd, "listchats")==0 || strcmp(cmd, "listarchived")==0 || strcmp(cmd, "chats")==0)
	{
		int listflags = strcmp(cmd, "listarchived")==0? DC_GCL_ARCHIVED_ONLY : 0;
		dc_chatlist_t* chatlist = dc_get_chatlist(context, listflags, arg1, 0);
		if (chatlist) {
			int i, cnt = dc_chatlist_get_cnt(chatlist);
			if (cnt>0) {
				dc_log_info(context, 0, "================================================================================");
				for (i = cnt-1; i >= 0; i--)
				{
					dc_chat_t* chat = dc_get_chat(context, dc_chatlist_get_chat_id(chatlist, i));

					char* temp_subtitle = dc_chat_get_subtitle(chat);
					char* temp_name = dc_chat_get_name(chat);
						dc_log_info(context, 0, "%s#%i: %s [%s] [%i fresh]",
							chat_prefix(chat),
							(int)dc_chat_get_id(chat), temp_name, temp_subtitle, (int)dc_get_fresh_msg_cnt(context, dc_chat_get_id(chat)));
					free(temp_subtitle);
					free(temp_name);

					dc_lot_t* lot = dc_chatlist_get_summary(chatlist, i, chat);

						const char* statestr = "";
						if (dc_chat_get_archived(chat)) {
							statestr = " [Archived]";
						}
						else switch (dc_lot_get_state(lot)) {
							case DC_STATE_OUT_PENDING:   statestr = " o";   break;
							case DC_STATE_OUT_DELIVERED: statestr = " √";   break;
							case DC_STATE_OUT_MDN_RCVD:  statestr = " √√";  break;
							case DC_STATE_OUT_FAILED:    statestr = " !!";  break;
						}

						char* timestr = dc_timestamp_to_str(dc_lot_get_timestamp(lot));
						char* text1 = dc_lot_get_text1(lot);
						char* text2 = dc_lot_get_text2(lot);
							dc_log_info(context, 0, "%s%s%s%s [%s]",
								text1? text1 : "",
								text1? ": " : "",
								text2? text2 : "",
								statestr, timestr
								);
						free(text1);
						free(text2);
						free(timestr);

					dc_lot_unref(lot);

					dc_chat_unref(chat);

					dc_log_info(context, 0, "================================================================================");
				}
			}
			ret = dc_mprintf("%i chats.", (int)cnt);
			dc_chatlist_unref(chatlist);
		}
		else {
			ret = COMMAND_FAILED;
		}
	}
	else if (strcmp(cmd, "chat")==0)
	{
		if (arg1 && arg1[0]) {
			/* select a chat (argument 1 = ID of chat to select) */
			if (sel_chat) { dc_chat_unref(sel_chat); sel_chat = NULL; }
			context->cmdline_sel_chat_id = atoi(arg1);
			sel_chat = dc_get_chat(context, context->cmdline_sel_chat_id); /* may be NULL */
			if (sel_chat==NULL) {
				context->cmdline_sel_chat_id = 0;
			}
		}

		/* show chat */
		if (sel_chat) {
			dc_array_t* msglist = dc_get_chat_msgs(context, dc_chat_get_id(sel_chat), DC_GCM_ADDDAYMARKER, 0);
			char* temp2 = dc_chat_get_subtitle(sel_chat);
			char* temp_name = dc_chat_get_name(sel_chat);
				dc_log_info(context, 0, "%s#%i: %s [%s]", chat_prefix(sel_chat), dc_chat_get_id(sel_chat), temp_name, temp2);
			free(temp_name);
			free(temp2);
			if (msglist) {
				log_msglist(context, msglist);
				dc_array_unref(msglist);
			}
			if (dc_chat_get_draft_timestamp(sel_chat)) {
				char* timestr = dc_timestamp_to_str(dc_chat_get_draft_timestamp(sel_chat));
				char* drafttext = dc_chat_get_text_draft(sel_chat);
					dc_log_info(context, 0, "Draft: %s [%s]", drafttext, timestr);
				free(drafttext);
				free(timestr);
			}
			ret = dc_mprintf("%i messages.", dc_get_msg_cnt(context, dc_chat_get_id(sel_chat)));
			dc_marknoticed_chat(context, dc_chat_get_id(sel_chat));
		}
		else {
			ret = dc_strdup("No chat selected.");
		}
	}
	else if (strcmp(cmd, "createchat")==0)
	{
		if (arg1) {
			int contact_id = atoi(arg1);
			int chat_id = dc_create_chat_by_contact_id(context, contact_id);
			ret = chat_id!=0? dc_mprintf("Single#%lu created successfully.", chat_id) : COMMAND_FAILED;
		}
		else {
			ret = dc_strdup("ERROR: Argument <contact-id> missing.");
		}
	}
	else if (strcmp(cmd, "createchatbymsg")==0)
	{
		if (arg1) {
			int msg_id = atoi(arg1);
			int chat_id = dc_create_chat_by_msg_id(context, msg_id);
			if (chat_id != 0) {
				dc_chat_t* chat = dc_get_chat(context, chat_id);
					ret = dc_mprintf("%s#%lu created successfully.", chat_prefix(chat), chat_id);
				dc_chat_unref(chat);
			}
			else {
				ret = COMMAND_FAILED;
			}
		}
		else {
			ret = dc_strdup("ERROR: Argument <msg-id> missing.");
		}
	}
	else if (strcmp(cmd, "creategroup")==0)
	{
		if (arg1) {
			int chat_id = dc_create_group_chat(context, 0, arg1);
			ret = chat_id!=0? dc_mprintf("Group#%lu created successfully.", chat_id) : COMMAND_FAILED;
		}
		else {
			ret = dc_strdup("ERROR: Argument <name> missing.");
		}
	}
	else if (strcmp(cmd, "createverified")==0)
	{
		if (arg1) {
			int chat_id = dc_create_group_chat(context, 1, arg1);
			ret = chat_id!=0? dc_mprintf("VerifiedGroup#%lu created successfully.", chat_id) : COMMAND_FAILED;
		}
		else {
			ret = dc_strdup("ERROR: Argument <name> missing.");
		}
	}
	else if (strcmp(cmd, "addmember")==0)
	{
		if (sel_chat) {
			if (arg1) {
				int contact_id = atoi(arg1);
				if (dc_add_contact_to_chat(context, dc_chat_get_id(sel_chat), contact_id)) {
					ret = dc_strdup("Contact added to chat.");
				}
				else {
					ret = dc_strdup("ERROR: Cannot add contact to chat.");
				}
			}
			else {
				ret = dc_strdup("ERROR: Argument <contact-id> missing.");
			}
		}
		else {
			ret = dc_strdup("No chat selected.");
		}
	}
	else if (strcmp(cmd, "removemember")==0)
	{
		if (sel_chat) {
			if (arg1) {
				int contact_id = atoi(arg1);
				if (dc_remove_contact_from_chat(context, dc_chat_get_id(sel_chat), contact_id)) {
					ret = dc_strdup("Contact added to chat.");
				}
				else {
					ret = dc_strdup("ERROR: Cannot remove member from chat.");
				}
			}
			else {
				ret = dc_strdup("ERROR: Argument <contact-id> missing.");
			}
		}
		else {
			ret = dc_strdup("No chat selected.");
		}
	}
	else if (strcmp(cmd, "groupname")==0)
	{
		if (sel_chat) {
			if (arg1 && arg1[0]) {
				ret = dc_set_chat_name(context, dc_chat_get_id(sel_chat), arg1)? COMMAND_SUCCEEDED : COMMAND_FAILED;
			}
			else {
				ret = dc_strdup("ERROR: Argument <name> missing.");
			}
		}
		else {
			ret = dc_strdup("No chat selected.");
		}
	}
	else if (strcmp(cmd, "groupimage")==0)
	{
		if (sel_chat) {
			ret = dc_set_chat_profile_image(context, dc_chat_get_id(sel_chat), (arg1&&arg1[0])?arg1:NULL)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = dc_strdup("No chat selected.");
		}
	}
	else if (strcmp(cmd, "chatinfo")==0)
	{
		if (sel_chat) {
			dc_array_t* contacts = dc_get_chat_contacts(context, dc_chat_get_id(sel_chat));
			if (contacts) {
				dc_log_info(context, 0, "Memberlist:");
				log_contactlist(context, contacts);
				ret = dc_mprintf("%i contacts.", (int)dc_array_get_cnt(contacts));
			}
			else {
				ret = COMMAND_FAILED;
			}
		}
		else {
			ret = dc_strdup("No chat selected.");
		}
	}
	else if (strcmp(cmd, "send")==0)
	{
		if (sel_chat) {
			if (arg1 && arg1[0]) {
				if (dc_send_text_msg(context, dc_chat_get_id(sel_chat), arg1)) {
					ret = dc_strdup("Message sent.");
				}
				else {
					ret = dc_strdup("ERROR: Sending failed.");
				}
			}
			else {
				ret = dc_strdup("ERROR: No message text given.");
			}
		}
		else {
			ret = dc_strdup("No chat selected.");
		}
	}
	else if (strcmp(cmd, "sendimage")==0)
	{
		if (sel_chat) {
			if (arg1 && arg1[0]) {
				if (dc_send_image_msg(context, dc_chat_get_id(sel_chat), arg1, NULL, 0, 0)) {
					ret = dc_strdup("Image sent.");
				}
				else {
					ret = dc_strdup("ERROR: Sending image failed.");
				}
			}
			else {
				ret = dc_strdup("ERROR: No image given.");
			}
		}
		else {
			ret = dc_strdup("No chat selected.");
		}
	}
	else if (strcmp(cmd, "sendfile")==0)
	{
		if (sel_chat) {
			if (arg1 && arg1[0]) {
				if (dc_send_file_msg(context, dc_chat_get_id(sel_chat), arg1, NULL)) {
					ret = dc_strdup("File sent.");
				}
				else {
					ret = dc_strdup("ERROR: Sending file failed.");
				}
			}
			else {
				ret = dc_strdup("ERROR: No file given.");
			}
		}
		else {
			ret = dc_strdup("No chat selected.");
		}
	}
	else if (strcmp(cmd, "listmsgs")==0)
	{
		if (arg1) {
			dc_array_t* msglist = dc_search_msgs(context, sel_chat? dc_chat_get_id(sel_chat) : 0, arg1);
			if (msglist) {
				log_msglist(context, msglist);
				ret = dc_mprintf("%i messages.", (int)dc_array_get_cnt(msglist));
				dc_array_unref(msglist);
			}
		}
		else {
			ret = dc_strdup("ERROR: Argument <query> missing.");
		}
	}
	else if (strcmp(cmd, "draft")==0)
	{
		if (sel_chat) {
			if (arg1 && arg1[0]) {
				dc_set_text_draft(context, dc_chat_get_id(sel_chat), arg1);
				ret = dc_strdup("Draft saved.");
			}
			else {
				dc_set_text_draft(context, dc_chat_get_id(sel_chat), NULL);
				ret = dc_strdup("Draft deleted.");
			}
		}
		else {
			ret = dc_strdup("No chat selected.");
		}
	}
	else if (strcmp(cmd, "listmedia")==0)
	{
		if (sel_chat) {
			dc_array_t* images = dc_get_chat_media(context, dc_chat_get_id(sel_chat), DC_MSG_IMAGE, DC_MSG_VIDEO);
			int i, icnt = dc_array_get_cnt(images);
			ret = dc_mprintf("%i images or videos: ", icnt);
			for (i = 0; i < icnt; i++) {
				char* temp = dc_mprintf("%s%sMsg#%i", i? ", ":"", ret, (int)dc_array_get_id(images, i));
				free(ret);
				ret = temp;
			}
			dc_array_unref(images);
		}
		else {
			ret = dc_strdup("No chat selected.");
		}
	}
	else if (strcmp(cmd, "archive")==0 || strcmp(cmd, "unarchive")==0)
	{
		if (arg1) {
			int chat_id = atoi(arg1);
			dc_archive_chat(context, chat_id, strcmp(cmd, "archive")==0? 1 : 0);
			ret = COMMAND_SUCCEEDED;
		}
		else {
			ret = dc_strdup("ERROR: Argument <chat-id> missing.");
		}
	}
	else if (strcmp(cmd, "delchat")==0)
	{
		if (arg1) {
			int chat_id = atoi(arg1);
			dc_delete_chat(context, chat_id);
			ret = COMMAND_SUCCEEDED;
		}
		else {
			ret = dc_strdup("ERROR: Argument <chat-id> missing.");
		}
	}


	/*******************************************************************************
	 * Message commands
	 ******************************************************************************/

	else if (strcmp(cmd, "msginfo")==0)
	{
		if (arg1) {
			int id = atoi(arg1);
			ret = dc_get_msg_info(context, id);
		}
		else {
			ret = dc_strdup("ERROR: Argument <msg-id> missing.");
		}
	}
	else if (strcmp(cmd, "listfresh")==0)
	{
		dc_array_t* msglist = dc_get_fresh_msgs(context);
		if (msglist) {
			log_msglist(context, msglist);
			ret = dc_mprintf("%i fresh messages.", (int)dc_array_get_cnt(msglist));
			dc_array_unref(msglist);
		}
	}
	else if (strcmp(cmd, "forward")==0)
	{
		char* arg2 = NULL;
		if (arg1) { arg2 = strrchr(arg1, ' '); }
		if (arg1 && arg2) {
			*arg2 = 0; arg2++;
			uint32_t msg_ids[1], chat_id = atoi(arg2);
			msg_ids[0] = atoi(arg1);
			dc_forward_msgs(context, msg_ids, 1, chat_id);
			ret = COMMAND_SUCCEEDED;
		}
		else {
			ret = dc_strdup("ERROR: Arguments <msg-id> <chat-id> expected.");
		}
	}
	else if (strcmp(cmd, "markseen")==0)
	{
		if (arg1) {
			uint32_t msg_ids[1];
			msg_ids[0] = atoi(arg1);
			dc_markseen_msgs(context, msg_ids, 1);
			ret = COMMAND_SUCCEEDED;
		}
		else {
			ret = dc_strdup("ERROR: Argument <msg-id> missing.");
		}
	}
	else if (strcmp(cmd, "star")==0 || strcmp(cmd, "unstar")==0)
	{
		if (arg1) {
			uint32_t msg_ids[1];
			msg_ids[0] = atoi(arg1);
			dc_star_msgs(context, msg_ids, 1, strcmp(cmd, "star")==0? 1 : 0);
			ret = COMMAND_SUCCEEDED;
		}
		else {
			ret = dc_strdup("ERROR: Argument <msg-id> missing.");
		}
	}
	else if (strcmp(cmd, "delmsg")==0)
	{
		if (arg1) {
			uint32_t ids[1];
			ids[0] = atoi(arg1);
			dc_delete_msgs(context, ids, 1);
			ret = COMMAND_SUCCEEDED;
		}
		else {
			ret = dc_strdup("ERROR: Argument <msg-id> missing.");
		}
	}


	/*******************************************************************************
	 * Contact commands
	 ******************************************************************************/

	else if (strcmp(cmd, "listcontacts")==0 || strcmp(cmd, "contacts")==0 || strcmp(cmd, "listverified")==0)
	{
		dc_array_t* contacts = dc_get_contacts(context, strcmp(cmd, "listverified")==0? DC_GCL_VERIFIED_ONLY|DC_GCL_ADD_SELF : DC_GCL_ADD_SELF, arg1);
		if (contacts) {
			log_contactlist(context, contacts);
			ret = dc_mprintf("%i contacts.", (int)dc_array_get_cnt(contacts));
			dc_array_unref(contacts);
		}
		else {
			ret = COMMAND_FAILED;
		}
	}
	else if (strcmp(cmd, "addcontact")==0)
	{
		char* arg2 = NULL;
		if (arg1) { arg2 = strrchr(arg1, ' '); }
		if (arg1 && arg2) {
			*arg2 = 0; arg2++;
			char* book = dc_mprintf("%s\n%s", arg1, arg2);
				dc_add_address_book(context, book);
				ret = COMMAND_SUCCEEDED;
			free(book);
		}
		else if (arg1) {
			ret = dc_create_contact(context, NULL, arg1)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = dc_strdup("ERROR: Arguments [<name>] <addr> expected.");
		}
	}
	else if (strcmp(cmd, "contactinfo")==0)
	{
		if (arg1) {
			int contact_id = atoi(arg1);
			dc_strbuilder_t strbuilder;
			dc_strbuilder_init(&strbuilder, 0);

			dc_contact_t* contact = dc_get_contact(context, contact_id);
			char* nameNaddr = dc_contact_get_name_n_addr(contact);
			dc_strbuilder_catf(&strbuilder, "Contact info for: %s:\n\n", nameNaddr);
			free(nameNaddr);
			dc_contact_unref(contact);

			char* encrinfo = dc_get_contact_encrinfo(context, contact_id);
			dc_strbuilder_cat(&strbuilder, encrinfo);
			free(encrinfo);

			dc_chatlist_t* chatlist = dc_get_chatlist(context, 0, NULL, contact_id);
			int chatlist_cnt = dc_chatlist_get_cnt(chatlist);
			if (chatlist_cnt > 0) {
				dc_strbuilder_catf(&strbuilder, "\n\n%i chats shared with Contact#%i: ", chatlist_cnt, contact_id);
				for (int i = 0; i < chatlist_cnt; i++) {
					if (i) { dc_strbuilder_cat(&strbuilder, ", ");  }

					dc_chat_t* chat = dc_get_chat(context, dc_chatlist_get_chat_id(chatlist, i));
						dc_strbuilder_catf(&strbuilder, "%s#%i", chat_prefix(chat), dc_chat_get_id(chat));
					dc_chat_unref(chat);
				}
			}
			dc_chatlist_unref(chatlist);

			ret = strbuilder.buf;
		}
		else {
			ret = dc_strdup("ERROR: Argument <contact-id> missing.");
		}
	}
	else if (strcmp(cmd, "delcontact")==0)
	{
		if (arg1) {
			ret = dc_delete_contact(context, atoi(arg1))? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = dc_strdup("ERROR: Argument <contact-id> missing.");
		}
	}
	else if (strcmp(cmd, "cleanupcontacts")==0)
	{
		ret = dc_cleanup_contacts(context)? COMMAND_SUCCEEDED : COMMAND_FAILED;
	}

	/*******************************************************************************
	 * Misc.
	 ******************************************************************************/

	else if (strcmp(cmd, "getqr")==0)
	{
		ret = dc_get_securejoin_qr(context, arg1? atoi(arg1) : 0);
		if (ret == NULL || ret[0]==0) { free(ret); ret = COMMAND_FAILED; }
	}
	else if (strcmp(cmd, "checkqr")==0)
	{
		if (arg1) {
			dc_lot_t* res = dc_check_qr(context, arg1);
				ret = dc_mprintf("state=%i, id=%i, text1=%s, text2=%s", (int)res->state, res->id, res->text1? res->text1:"", res->text2? res->text2:"");
			dc_lot_unref(res);
		}
		else {
			ret = dc_strdup("ERROR: Argument <qr-content> missing.");
		}
	}
	else if ( strcmp(cmd, "event")==0)
	{
		if (arg1) {
			int event = atoi(arg1);
			uintptr_t r = context->cb(context, event, 0, 0);
			ret = dc_mprintf("Sending event %i, received value %i.", (int)event, (int)r);
		}
		else {
			ret = dc_strdup("ERROR: Argument <id> missing.");
		}
	}
	else if (strcmp(cmd, "fileinfo")==0)
	{
		if (arg1) {
			unsigned char* buf = NULL; size_t buf_bytes; uint32_t w, h;
			if (dc_read_file(arg1, (void**)&buf, &buf_bytes, context)) {
				dc_get_filemeta(buf, buf_bytes, &w, &h);
				ret = dc_mprintf("width=%i, height=%i", (int)w, (int)h);
			}
			else {
				ret = dc_strdup("ERROR: Command failed.");
			}
			free(buf);
		}
		else {
			ret = dc_strdup("ERROR: Argument <file> missing.");
		}
	}
	else
	{
		ret = COMMAND_UNKNOWN;
	}

cleanup:
	if (ret == COMMAND_SUCCEEDED) {
		ret = dc_strdup("Command executed successfully.");
	}
	else if (ret == COMMAND_FAILED) {
		ret = dc_strdup("ERROR: Command failed.");
	}
	else if (ret == COMMAND_UNKNOWN) {
		ret = dc_mprintf("ERROR: Unknown command \"%s\", type ? for help.", cmd);
	}
	if (sel_chat) { dc_chat_unref(sel_chat); sel_chat = NULL; }
	free(cmd);
	return ret;
}


