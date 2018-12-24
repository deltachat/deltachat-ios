#include <assert.h>
#include "dc_context.h"
#include "dc_apeerstate.h"


/* This class wraps around SQLite.

We use a single handle for the database connections, mainly because
we do not know from which threads the UI calls the dc_*() functions.

As the open the Database in serialized mode explicitly, in general, this is
safe. However, there are some points to keep in mind:

1. Reading can be done at the same time from several threads, however, only
   one thread can write.  If a seconds thread tries to write, this thread
   is halted until the first has finished writing, at most the timespan set
   by sqlite3_busy_timeout().

2. Transactions are possible using `BEGIN IMMEDIATE` (this causes the first
   thread trying to write to block the others as described in 1.
   Transaction cannot be nested, we recommend to use them only in the
   top-level functions or not to use them.

3. Using sqlite3_last_insert_rowid() and sqlite3_changes() cause race conditions
   (between the query and the call another thread may insert or update a row.
   These functions MUST NOT be used;
   dc_sqlite3_get_rowid() provides an alternative. */


void dc_sqlite3_log_error(dc_sqlite3_t* sql, const char* msg_format, ...)
{
	char*       msg = NULL;
	const char* notSetUp = "SQLite object not set up.";
	va_list     va;
	va_start(va, msg_format);
		msg = sqlite3_vmprintf(msg_format, va); if (msg==NULL) { dc_log_error(sql->context, 0, "Bad log format string \"%s\".", msg_format); }
			dc_log_error(sql->context, 0, "%s SQLite says: %s", msg, sql->cobj? sqlite3_errmsg(sql->cobj) : notSetUp);
		sqlite3_free(msg);
	va_end(va);
}


sqlite3_stmt* dc_sqlite3_prepare(dc_sqlite3_t* sql, const char* querystr)
{
	sqlite3_stmt* stmt = NULL;

	if (sql==NULL || querystr==NULL || sql->cobj==NULL) {
		return NULL;
	}

	if (sqlite3_prepare_v2(sql->cobj,
	         querystr, -1 /*read `querystr` up to the first null-byte*/,
	         &stmt,
	         NULL /*tail not interesting, we use only single statements*/) != SQLITE_OK)
	{
		dc_sqlite3_log_error(sql, "Query failed: %s", querystr);
		return NULL;
	}

	/* success - the result must be freed using sqlite3_finalize() */
	return stmt;
}


int dc_sqlite3_execute(dc_sqlite3_t* sql, const char* querystr)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;
	int           sqlState = 0;

	stmt = dc_sqlite3_prepare(sql, querystr);
	if (stmt==NULL) {
		goto cleanup;
	}

	sqlState = sqlite3_step(stmt);
	if (sqlState != SQLITE_DONE && sqlState != SQLITE_ROW)  {
		dc_sqlite3_log_error(sql, "Cannot excecute \"%s\".", querystr);
		goto cleanup;
	}

	success = 1;

cleanup:
	if (stmt) {
		sqlite3_finalize(stmt);
	}
	return success;
}


uint32_t dc_sqlite3_get_rowid(dc_sqlite3_t* sql, const char* table, const char* field, const char* value)
{
	// alternative to sqlite3_last_insert_rowid() which MUST NOT be used due to race conditions, see comment above.
	// the ORDER BY ensures, this function always returns the most recent id,
	// eg. if a Message-ID is splitted into different messages.
	uint32_t id = 0;
	char* q3 = sqlite3_mprintf("SELECT id FROM %s WHERE %s=%Q ORDER BY id DESC;", table, field, value);
	sqlite3_stmt* stmt = dc_sqlite3_prepare(sql, q3);
	if (SQLITE_ROW==sqlite3_step(stmt)) {
		id = sqlite3_column_int(stmt, 0);
	}
	sqlite3_finalize(stmt);
	sqlite3_free(q3);
	return id;
}


dc_sqlite3_t* dc_sqlite3_new(dc_context_t* context)
{
	dc_sqlite3_t* sql = NULL;

	if ((sql=calloc(1, sizeof(dc_sqlite3_t)))==NULL) {
		exit(24); /* cannot allocate little memory, unrecoverable error */
	}

	sql->context          = context;

	return sql;
}


void dc_sqlite3_unref(dc_sqlite3_t* sql)
{
	if (sql==NULL) {
		return;
	}

	if (sql->cobj) {
		dc_sqlite3_close(sql);
	}

	free(sql);
}


int dc_sqlite3_open(dc_sqlite3_t* sql, const char* dbfile, int flags)
{
	if (dc_sqlite3_is_open(sql)) {
		return 0; // a cleanup would close the database
	}

	if (sql==NULL || dbfile==NULL) {
		goto cleanup;
	}

	if (sqlite3_threadsafe()==0) {
		dc_log_error(sql->context, 0, "Sqlite3 compiled thread-unsafe; this is not supported.");
		goto cleanup;
	}

	if (sql->cobj) {
		dc_log_error(sql->context, 0, "Cannot open, database \"%s\" already opened.", dbfile);
		goto cleanup;
	}

	// Force serialized mode (SQLITE_OPEN_FULLMUTEX) explicitly.
	// So, most of the explicit lock/unlocks on dc_sqlite3_t object are no longer needed.
	// However, locking is _also_ used for dc_context_t which _is_ still needed, so, we
	// should remove locks only if we're really sure.
	//
	// `PRAGMA cache_size` and `PRAGMA page_size`: As we save BLOBs in external
	// files, caching is not that important; we rely on the system defaults here
	// (normally 2 MB cache, 1 KB page size on sqlite < 3.12.0, 4 KB for newer
	// versions)
	if (sqlite3_open_v2(dbfile, &sql->cobj,
			SQLITE_OPEN_FULLMUTEX | ((flags&DC_OPEN_READONLY)? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)),
			NULL) != SQLITE_OK) {
		dc_sqlite3_log_error(sql, "Cannot open database \"%s\".", dbfile); /* ususally, even for errors, the pointer is set up (if not, this is also checked by dc_sqlite3_log_error()) */
		goto cleanup;
	}

	// let SQLite overwrite deleted content with zeros
	dc_sqlite3_execute(sql, "PRAGMA secure_delete=on;");

	// Only one process can make changes to the database at one time.
	// busy_timeout defines, that if a seconds process wants write access, this second process will wait some milliseconds
	// and try over until it gets write access or the given timeout is elapsed.
	// If the second process does not get write access within the given timeout, sqlite3_step() will return the error SQLITE_BUSY.
	// (without a busy_timeout, sqlite3_step() would return SQLITE_BUSY at once)
	sqlite3_busy_timeout(sql->cobj, 10*1000);

	if (!(flags&DC_OPEN_READONLY))
	{
		int dbversion_before_update = 0;

		/* Init tables to dbversion=0 */
		if (!dc_sqlite3_table_exists(sql, "config"))
		{
			dc_log_info(sql->context, 0, "First time init: creating tables in \"%s\".", dbfile);

			// the row with the type `INTEGER PRIMARY KEY` is an alias to the 64-bit-ROWID present in every table
			// we re-use this ID for our own purposes.
			// (the last inserted ROWID can be accessed using sqlite3_last_insert_rowid(), which, however, is
			// not recommended as not thread-safe, see above)
			dc_sqlite3_execute(sql, "CREATE TABLE config (id INTEGER PRIMARY KEY, keyname TEXT, value TEXT);");
			dc_sqlite3_execute(sql, "CREATE INDEX config_index1 ON config (keyname);");

			dc_sqlite3_execute(sql, "CREATE TABLE contacts (id INTEGER PRIMARY KEY,"
						" name TEXT DEFAULT '',"
						" addr TEXT DEFAULT '' COLLATE NOCASE,"
						" origin INTEGER DEFAULT 0,"
						" blocked INTEGER DEFAULT 0,"
						" last_seen INTEGER DEFAULT 0,"   /* last_seen is for future use */
						" param TEXT DEFAULT '');");      /* param is for future use, eg. for the status */
			dc_sqlite3_execute(sql, "CREATE INDEX contacts_index1 ON contacts (name COLLATE NOCASE);"); /* needed for query contacts */
			dc_sqlite3_execute(sql, "CREATE INDEX contacts_index2 ON contacts (addr COLLATE NOCASE);"); /* needed for query and on receiving mails */
			dc_sqlite3_execute(sql, "INSERT INTO contacts (id,name,origin) VALUES (1,'self',262144), (2,'device',262144), (3,'rsvd',262144), (4,'rsvd',262144), (5,'rsvd',262144), (6,'rsvd',262144), (7,'rsvd',262144), (8,'rsvd',262144), (9,'rsvd',262144);");
			#if !defined(DC_ORIGIN_INTERNAL) || DC_ORIGIN_INTERNAL!=262144
				#error
			#endif

			dc_sqlite3_execute(sql, "CREATE TABLE chats (id INTEGER PRIMARY KEY, "
						" type INTEGER DEFAULT 0,"
						" name TEXT DEFAULT '',"
						" draft_timestamp INTEGER DEFAULT 0,"
						" draft_txt TEXT DEFAULT '',"
						" blocked INTEGER DEFAULT 0,"
						" grpid TEXT DEFAULT '',"          /* contacts-global unique group-ID, see dc_chat.c for details */
						" param TEXT DEFAULT '');");
			dc_sqlite3_execute(sql, "CREATE INDEX chats_index1 ON chats (grpid);");
			dc_sqlite3_execute(sql, "CREATE TABLE chats_contacts (chat_id INTEGER, contact_id INTEGER);");
			dc_sqlite3_execute(sql, "CREATE INDEX chats_contacts_index1 ON chats_contacts (chat_id);");
			dc_sqlite3_execute(sql, "INSERT INTO chats (id,type,name) VALUES (1,120,'deaddrop'), (2,120,'rsvd'), (3,120,'trash'), (4,120,'msgs_in_creation'), (5,120,'starred'), (6,120,'archivedlink'), (7,100,'rsvd'), (8,100,'rsvd'), (9,100,'rsvd');");
			#if !defined(DC_CHAT_TYPE_SINGLE) || DC_CHAT_TYPE_SINGLE!=100 || DC_CHAT_TYPE_GROUP!=120 || \
			 DC_CHAT_ID_DEADDROP!=1 || DC_CHAT_ID_TRASH!=3 || \
			 DC_CHAT_ID_MSGS_IN_CREATION!=4 || DC_CHAT_ID_STARRED!=5 || DC_CHAT_ID_ARCHIVED_LINK!=6 || \
			 DC_CHAT_NOT_BLOCKED!=0  || DC_CHAT_MANUALLY_BLOCKED!=1 || DC_CHAT_DEADDROP_BLOCKED!=2
				#error
			#endif

			dc_sqlite3_execute(sql, "CREATE TABLE msgs (id INTEGER PRIMARY KEY,"
						" rfc724_mid TEXT DEFAULT '',"     /* forever-global-unique Message-ID-string, unfortunately, this cannot be easily used to communicate via IMAP */
						" server_folder TEXT DEFAULT '',"  /* folder as used on the server, the folder will change when messages are moved around. */
						" server_uid INTEGER DEFAULT 0,"   /* UID as used on the server, the UID will change when messages are moved around, unique together with validity, see RFC 3501; the validity may differ from folder to folder.  We use the server_uid for "markseen" and to delete messages as we check against the message-id, we ignore the validity for these commands. */
						" chat_id INTEGER DEFAULT 0,"
						" from_id INTEGER DEFAULT 0,"
						" to_id INTEGER DEFAULT 0,"        /* to_id is needed to allow moving messages eg. from "deaddrop" to a normal chat, may be unset */
						" timestamp INTEGER DEFAULT 0,"
						" type INTEGER DEFAULT 0,"
						" state INTEGER DEFAULT 0,"
						" msgrmsg INTEGER DEFAULT 1,"      /* does the message come from a messenger? (0=no, 1=yes, 2=no, but the message is a reply to a messenger message) */
						" bytes INTEGER DEFAULT 0,"        /* not used, added in ~ v0.1.12 */
						" txt TEXT DEFAULT '',"
						" txt_raw TEXT DEFAULT '',"
						" param TEXT DEFAULT '');");
			dc_sqlite3_execute(sql, "CREATE INDEX msgs_index1 ON msgs (rfc724_mid);");     /* in our database, one email may be split up to several messages (eg. one per image), so the email-Message-ID may be used for several records; id is always unique */
			dc_sqlite3_execute(sql, "CREATE INDEX msgs_index2 ON msgs (chat_id);");
			dc_sqlite3_execute(sql, "CREATE INDEX msgs_index3 ON msgs (timestamp);");      /* for sorting */
			dc_sqlite3_execute(sql, "CREATE INDEX msgs_index4 ON msgs (state);");          /* for selecting the count of fresh messages (as there are normally only few unread messages, an index over the chat_id is not required for _this_ purpose */
			dc_sqlite3_execute(sql, "INSERT INTO msgs (id,msgrmsg,txt) VALUES (1,0,'marker1'), (2,0,'rsvd'), (3,0,'rsvd'), (4,0,'rsvd'), (5,0,'rsvd'), (6,0,'rsvd'), (7,0,'rsvd'), (8,0,'rsvd'), (9,0,'daymarker');"); /* make sure, the reserved IDs are not used */

			dc_sqlite3_execute(sql, "CREATE TABLE jobs (id INTEGER PRIMARY KEY,"
						" added_timestamp INTEGER,"
						" desired_timestamp INTEGER DEFAULT 0,"
						" action INTEGER,"
						" foreign_id INTEGER,"
						" param TEXT DEFAULT '');");
			dc_sqlite3_execute(sql, "CREATE INDEX jobs_index1 ON jobs (desired_timestamp);");

			if (!dc_sqlite3_table_exists(sql, "config") || !dc_sqlite3_table_exists(sql, "contacts")
			 || !dc_sqlite3_table_exists(sql, "chats") || !dc_sqlite3_table_exists(sql, "chats_contacts")
			 || !dc_sqlite3_table_exists(sql, "msgs") || !dc_sqlite3_table_exists(sql, "jobs"))
			{
				dc_sqlite3_log_error(sql, "Cannot create tables in new database \"%s\".", dbfile);
				goto cleanup; /* cannot create the tables - maybe we cannot write? */
			}

			dc_sqlite3_set_config_int(sql, "dbversion", 0);
		}
		else
		{
			dbversion_before_update = dc_sqlite3_get_config_int(sql, "dbversion", 0);
		}

		// (1) update low-level database structure.
		// this should be done before updates that use high-level objects that
		// rely themselves on the low-level structure.
		// --------------------------------------------------------------------

		int dbversion = dbversion_before_update;
		int recalc_fingerprints = 0;
		int update_file_paths = 0;

		#define NEW_DB_VERSION 1
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "CREATE TABLE leftgrps ("
							" id INTEGER PRIMARY KEY,"
							" grpid TEXT DEFAULT '');");
				dc_sqlite3_execute(sql, "CREATE INDEX leftgrps_index1 ON leftgrps (grpid);");

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 2
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "ALTER TABLE contacts ADD COLUMN authname TEXT DEFAULT '';");

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 7
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "CREATE TABLE keypairs ("
							" id INTEGER PRIMARY KEY,"
							" addr TEXT DEFAULT '' COLLATE NOCASE,"
							" is_default INTEGER DEFAULT 0,"
							" private_key,"
							" public_key,"
							" created INTEGER DEFAULT 0);");

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 10
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "CREATE TABLE acpeerstates ("
							" id INTEGER PRIMARY KEY,"
							" addr TEXT DEFAULT '' COLLATE NOCASE,"    /* no UNIQUE here, Autocrypt: requires the index above mail+type (type however, is not used at the moment, but to be future-proof, we do not use an index. instead we just check ourself if there is a record or not)*/
							" last_seen INTEGER DEFAULT 0,"
							" last_seen_autocrypt INTEGER DEFAULT 0,"
							" public_key,"
							" prefer_encrypted INTEGER DEFAULT 0);");
				dc_sqlite3_execute(sql, "CREATE INDEX acpeerstates_index1 ON acpeerstates (addr);");

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 12
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "CREATE TABLE msgs_mdns ("
							" msg_id INTEGER, "
							" contact_id INTEGER);");
				dc_sqlite3_execute(sql, "CREATE INDEX msgs_mdns_index1 ON msgs_mdns (msg_id);");

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 17
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "ALTER TABLE chats ADD COLUMN archived INTEGER DEFAULT 0;");
				dc_sqlite3_execute(sql, "CREATE INDEX chats_index2 ON chats (archived);");
				dc_sqlite3_execute(sql, "ALTER TABLE msgs ADD COLUMN starred INTEGER DEFAULT 0;");
				dc_sqlite3_execute(sql, "CREATE INDEX msgs_index5 ON msgs (starred);");

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 18
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "ALTER TABLE acpeerstates ADD COLUMN gossip_timestamp INTEGER DEFAULT 0;");
				dc_sqlite3_execute(sql, "ALTER TABLE acpeerstates ADD COLUMN gossip_key;");

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 27
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "DELETE FROM msgs WHERE chat_id=1 OR chat_id=2;"); /* chat.id=1 and chat.id=2 are the old deaddrops, the current ones are defined by chats.blocked=2 */
				dc_sqlite3_execute(sql, "CREATE INDEX chats_contacts_index2 ON chats_contacts (contact_id);"); /* needed to find chat by contact list */
				dc_sqlite3_execute(sql, "ALTER TABLE msgs ADD COLUMN timestamp_sent INTEGER DEFAULT 0;");
				dc_sqlite3_execute(sql, "ALTER TABLE msgs ADD COLUMN timestamp_rcvd INTEGER DEFAULT 0;");

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 34
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "ALTER TABLE msgs ADD COLUMN hidden INTEGER DEFAULT 0;");
				dc_sqlite3_execute(sql, "ALTER TABLE msgs_mdns ADD COLUMN timestamp_sent INTEGER DEFAULT 0;");
				dc_sqlite3_execute(sql, "ALTER TABLE acpeerstates ADD COLUMN public_key_fingerprint TEXT DEFAULT '';"); /* do not add `COLLATE NOCASE` case-insensivity is not needed as we force uppercase on store - otoh case-sensivity may be neeed for other/upcoming fingerprint formats */
				dc_sqlite3_execute(sql, "ALTER TABLE acpeerstates ADD COLUMN gossip_key_fingerprint TEXT DEFAULT '';"); /* do not add `COLLATE NOCASE` case-insensivity is not needed as we force uppercase on store - otoh case-sensivity may be neeed for other/upcoming fingerprint formats */
				dc_sqlite3_execute(sql, "CREATE INDEX acpeerstates_index3 ON acpeerstates (public_key_fingerprint);");
				dc_sqlite3_execute(sql, "CREATE INDEX acpeerstates_index4 ON acpeerstates (gossip_key_fingerprint);");
				recalc_fingerprints = 1;

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 39
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "CREATE TABLE tokens ("
							" id INTEGER PRIMARY KEY,"
							" namespc INTEGER DEFAULT 0,"
							" foreign_id INTEGER DEFAULT 0,"
							" token TEXT DEFAULT '',"
							" timestamp INTEGER DEFAULT 0);");
				dc_sqlite3_execute(sql, "ALTER TABLE acpeerstates ADD COLUMN verified_key;");
				dc_sqlite3_execute(sql, "ALTER TABLE acpeerstates ADD COLUMN verified_key_fingerprint TEXT DEFAULT '';"); /* do not add `COLLATE NOCASE` case-insensivity is not needed as we force uppercase on store - otoh case-sensivity may be neeed for other/upcoming fingerprint formats */
				dc_sqlite3_execute(sql, "CREATE INDEX acpeerstates_index5 ON acpeerstates (verified_key_fingerprint);");

				if (dbversion_before_update==34)
				{
					// migrate database from the use of verified-flags to verified_key,
					// _only_ version 34 (0.17.0) has the fields public_key_verified and gossip_key_verified
					// this block can be deleted in half a year or so (created 5/2018)
					dc_sqlite3_execute(sql, "UPDATE acpeerstates SET verified_key=gossip_key, verified_key_fingerprint=gossip_key_fingerprint WHERE gossip_key_verified=2;");
					dc_sqlite3_execute(sql, "UPDATE acpeerstates SET verified_key=public_key, verified_key_fingerprint=public_key_fingerprint WHERE public_key_verified=2;");
				}

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 40
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "ALTER TABLE jobs ADD COLUMN thread INTEGER DEFAULT 0;");

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 41
			if (dbversion < NEW_DB_VERSION)
			{
				update_file_paths = 1;

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 42
			if (dbversion < NEW_DB_VERSION)
			{
				// older versions set the txt-field to the filenames, for debugging and fulltext search.
				// to allow text+attachment compound messages, we need to reset these fields.
				dc_sqlite3_execute(sql, "UPDATE msgs SET txt='' WHERE type!=" DC_STRINGIFY(DC_MSG_TEXT));

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 44
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "ALTER TABLE msgs ADD COLUMN mime_headers TEXT;");

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 46
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "ALTER TABLE msgs ADD COLUMN mime_in_reply_to TEXT;");
				dc_sqlite3_execute(sql, "ALTER TABLE msgs ADD COLUMN mime_references TEXT;");

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 47
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "ALTER TABLE jobs ADD COLUMN tries INTEGER DEFAULT 0;");

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 48
			if (dbversion < NEW_DB_VERSION)
			{
				dc_sqlite3_execute(sql, "ALTER TABLE msgs ADD COLUMN move_state INTEGER DEFAULT 1;");
				assert( DC_MOVE_STATE_UNDEFINED == 0 );
				assert( DC_MOVE_STATE_PENDING == 1 );
				assert( DC_MOVE_STATE_STAY == 2 );
				assert( DC_MOVE_STATE_MOVING == 3 );

				dbversion = NEW_DB_VERSION;
				dc_sqlite3_set_config_int(sql, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		// (2) updates that require high-level objects
		// (the structure is complete now and all objects are usable)
		// --------------------------------------------------------------------

		if (recalc_fingerprints)
		{
			sqlite3_stmt* stmt = dc_sqlite3_prepare(sql, "SELECT addr FROM acpeerstates;");
				while (sqlite3_step(stmt)==SQLITE_ROW) {
					dc_apeerstate_t* peerstate = dc_apeerstate_new(sql->context);
						if (dc_apeerstate_load_by_addr(peerstate, sql, (const char*)sqlite3_column_text(stmt, 0))
						 && dc_apeerstate_recalc_fingerprint(peerstate)) {
							dc_apeerstate_save_to_db(peerstate, sql, 0/*don't create*/);
						}
					dc_apeerstate_unref(peerstate);
				}
			sqlite3_finalize(stmt);
		}

		if (update_file_paths)
		{
			// versions before 2018-08 save the absolute paths in the database files at "param.f=";
			// for newer versions, we copy files always to the blob directory and store relative paths.
			// this snippet converts older databases and can be removed after some time.
			char* repl_from = dc_sqlite3_get_config(sql, "backup_for", sql->context->blobdir);
			dc_ensure_no_slash(repl_from);

			assert('f'==DC_PARAM_FILE);
			char* q3 = sqlite3_mprintf("UPDATE msgs SET param=replace(param, 'f=%q/', 'f=$BLOBDIR/');", repl_from);
			dc_sqlite3_execute(sql, q3);
			sqlite3_free(q3);

			assert('i'==DC_PARAM_PROFILE_IMAGE);
			q3 = sqlite3_mprintf("UPDATE chats SET param=replace(param, 'i=%q/', 'i=$BLOBDIR/');", repl_from);
			dc_sqlite3_execute(sql, q3);
			sqlite3_free(q3);

			free(repl_from);
			dc_sqlite3_set_config(sql, "backup_for", NULL);
		}
	}

	dc_log_info(sql->context, 0, "Opened \"%s\".", dbfile);
	return 1;

cleanup:
	dc_sqlite3_close(sql);
	return 0;
}


void dc_sqlite3_close(dc_sqlite3_t* sql)
{
	if (sql==NULL) {
		return;
	}

	if (sql->cobj)
	{
		sqlite3_close(sql->cobj);
		sql->cobj = NULL;
	}

	dc_log_info(sql->context, 0, "Database closed."); /* We log the information even if not real closing took place; this is to detect logic errors. */
}


int dc_sqlite3_is_open(const dc_sqlite3_t* sql)
{
	if (sql==NULL || sql->cobj==NULL) {
		return 0;
	}
	return 1;
}


int dc_sqlite3_table_exists(dc_sqlite3_t* sql, const char* name)
{
	int           ret = 0;
	char*         querystr = NULL;
	sqlite3_stmt* stmt = NULL;
	int           sqlState = 0;

	if ((querystr=sqlite3_mprintf("PRAGMA table_info(%s)", name))==NULL) { /* this statement cannot be used with binded variables */
		dc_log_error(sql->context, 0, "dc_sqlite3_table_exists_(): Out of memory.");
		goto cleanup;
	}

	if ((stmt=dc_sqlite3_prepare(sql, querystr))==NULL) {
		goto cleanup;
	}

	sqlState = sqlite3_step(stmt);
	if (sqlState==SQLITE_ROW) {
		ret = 1; /* the table exists. Other states are SQLITE_DONE or SQLITE_ERROR in both cases we return 0. */
	}

	/* success - fall through to free allocated objects */
	;

	/* error/cleanup */
cleanup:
	if (stmt) {
		sqlite3_finalize(stmt);
	}

	if (querystr) {
		sqlite3_free(querystr);
	}

	return ret;
}


/*******************************************************************************
 * Handle configuration
 ******************************************************************************/


int dc_sqlite3_set_config(dc_sqlite3_t* sql, const char* key, const char* value)
{
	int           state = 0;
	sqlite3_stmt* stmt = NULL;

	if (key==NULL) {
		dc_log_error(sql->context, 0, "dc_sqlite3_set_config(): Bad parameter.");
		return 0;
	}

	if (!dc_sqlite3_is_open(sql)) {
		dc_log_error(sql->context, 0, "dc_sqlite3_set_config(): Database not ready.");
		return 0;
	}

	if (value)
	{
		/* insert/update key=value */
		#define SELECT_v_FROM_config_k_STATEMENT "SELECT value FROM config WHERE keyname=?;"
		stmt = dc_sqlite3_prepare(sql, SELECT_v_FROM_config_k_STATEMENT);
		sqlite3_bind_text (stmt, 1, key, -1, SQLITE_STATIC);
		state = sqlite3_step(stmt);
		sqlite3_finalize(stmt);

		if (state==SQLITE_DONE) {
			stmt = dc_sqlite3_prepare(sql, "INSERT INTO config (keyname, value) VALUES (?, ?);");
			sqlite3_bind_text (stmt, 1, key,   -1, SQLITE_STATIC);
			sqlite3_bind_text (stmt, 2, value, -1, SQLITE_STATIC);
			state = sqlite3_step(stmt);
			sqlite3_finalize(stmt);
		}
		else if (state==SQLITE_ROW) {
			stmt = dc_sqlite3_prepare(sql, "UPDATE config SET value=? WHERE keyname=?;");
			sqlite3_bind_text (stmt, 1, value, -1, SQLITE_STATIC);
			sqlite3_bind_text (stmt, 2, key,   -1, SQLITE_STATIC);
			state = sqlite3_step(stmt);
			sqlite3_finalize(stmt);
		}
		else {
			dc_log_error(sql->context, 0, "dc_sqlite3_set_config(): Cannot read value.");
			return 0;
		}
	}
	else
	{
		/* delete key */
		stmt = dc_sqlite3_prepare(sql, "DELETE FROM config WHERE keyname=?;");
		sqlite3_bind_text (stmt, 1, key,   -1, SQLITE_STATIC);
		state = sqlite3_step(stmt);
		sqlite3_finalize(stmt);
	}

	if (state != SQLITE_DONE)  {
		dc_log_error(sql->context, 0, "dc_sqlite3_set_config(): Cannot change value.");
		return 0;
	}

	return 1;
}


char* dc_sqlite3_get_config(dc_sqlite3_t* sql, const char* key, const char* def) /* the returned string must be free()'d, NULL is only returned if def is NULL */
{
	sqlite3_stmt* stmt = NULL;

	if (!dc_sqlite3_is_open(sql) || key==NULL) {
		return dc_strdup_keep_null(def);
	}

	stmt = dc_sqlite3_prepare(sql, SELECT_v_FROM_config_k_STATEMENT);
	sqlite3_bind_text(stmt, 1, key, -1, SQLITE_STATIC);
	if (sqlite3_step(stmt)==SQLITE_ROW)
	{
		const unsigned char* ptr = sqlite3_column_text(stmt, 0); /* Do not pass the pointers returned from sqlite3_column_text(), etc. into sqlite3_free(). */
		if (ptr)
		{
			/* success, fall through below to free objects */
			char* ret = dc_strdup((const char*)ptr);
			sqlite3_finalize(stmt);
			return ret;
		}
	}

	/* return the default value */
	sqlite3_finalize(stmt);
	return dc_strdup_keep_null(def);
}


int32_t dc_sqlite3_get_config_int(dc_sqlite3_t* sql, const char* key, int32_t def)
{
    char* str = dc_sqlite3_get_config(sql, key, NULL);
    if (str==NULL) {
		return def;
    }
    int32_t ret = atol(str);
    free(str);
    return ret;
}


int dc_sqlite3_set_config_int(dc_sqlite3_t* sql, const char* key, int32_t value)
{
    char* value_str = dc_mprintf("%i", (int)value);
    if (value_str==NULL) {
		return 0;
    }
    int ret = dc_sqlite3_set_config(sql, key, value_str);
    free(value_str);
    return ret;
}


/*******************************************************************************
 * Transactions
 ******************************************************************************/


#undef USE_TRANSACTIONS


void dc_sqlite3_begin_transaction(dc_sqlite3_t* sql)
{
#ifdef USE_TRANSACTIONS
	// `BEGIN IMMEDIATE` ensures, only one thread may write.
	// all other calls to `BEGIN IMMEDIATE` will try over until sqlite3_busy_timeout() is reached.
	// CAVE: This also implies that transactions MUST NOT be nested.
	sqlite3_stmt* stmt = dc_sqlite3_prepare(sql, "BEGIN IMMEDIATE;");
	if (sqlite3_step(stmt) != SQLITE_DONE) {
		dc_sqlite3_log_error(sql, "Cannot begin transaction.");
	}
	sqlite3_finalize(stmt);
#endif
}


void dc_sqlite3_rollback(dc_sqlite3_t* sql)
{
#ifdef USE_TRANSACTIONS
	sqlite3_stmt* stmt = dc_sqlite3_prepare(sql, "ROLLBACK;");
	if (sqlite3_step(stmt) != SQLITE_DONE) {
		dc_sqlite3_log_error(sql, "Cannot rollback transaction.");
	}
	sqlite3_finalize(stmt);
#endif
}


void dc_sqlite3_commit(dc_sqlite3_t* sql)
{
#ifdef USE_TRANSACTIONS
	sqlite3_stmt* stmt = dc_sqlite3_prepare(sql, "COMMIT;");
	if (sqlite3_step(stmt) != SQLITE_DONE) {
		dc_sqlite3_log_error(sql, "Cannot commit transaction.");
	}
	sqlite3_finalize(stmt);
#endif
}
