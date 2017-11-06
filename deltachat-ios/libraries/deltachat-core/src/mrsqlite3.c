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
 * File:    mrsqlite3.c
 * Purpose: MrSqlite3 wraps around SQLite
 *
 *******************************************************************************
 *
 * Some hints to the underlying database:
 *
 * - `PRAGMA cache_size` and `PRAGMA page_size`: As we save BLOBs in external
 *   files, caching is not that important; we rely on the system defaults here
 *   (normally 2 MB cache, 1 KB page size on sqlite < 3.12.0, 4 KB for newer
 *   versions)
 *
 * - We use `sqlite3_last_insert_rowid()` to find out created records - for this
 *   purpose, the primary ID has to be marked using `INTEGER PRIMARY KEY`, see
 *   https://www.sqlite.org/c3ref/last_insert_rowid.html
 *
 * - Some words to the "param" fields:  These fields contains a string with
 *   additonal, named parameters which must not be accessed by a search and/or
 *   are very seldomly used. Moreover, this allows smart minor database updates.
 *
 ******************************************************************************/


#include <stdlib.h>
#include <string.h>
#include "mrmailbox.h"
#include "mrsqlite3.h"
#include "mrtools.h"
#include "mrchat.h"
#include "mrcontact.h"


/*******************************************************************************
 * Tools
 ******************************************************************************/


void mrsqlite3_log_error(mrsqlite3_t* ths, const char* msg_format, ...)
{
	char*       msg;
	const char* notSetUp = "SQLite object not set up.";
	va_list     va;

	va_start(va, msg_format);
		msg = sqlite3_vmprintf(msg_format, va); if( msg == NULL ) { mrmailbox_log_error(ths->m_mailbox, 0, "Bad log format string \"%s\".", msg_format); }
			mrmailbox_log_error(ths->m_mailbox, 0, "%s SQLite says: %s", msg, ths->m_cobj? sqlite3_errmsg(ths->m_cobj) : notSetUp);
		sqlite3_free(msg);
	va_end(va);
}


sqlite3_stmt* mrsqlite3_prepare_v2_(mrsqlite3_t* ths, const char* querystr)
{
	sqlite3_stmt* retStmt = NULL;

	if( ths == NULL || querystr == NULL || ths->m_cobj == NULL ) {
		return NULL;
	}

	if( sqlite3_prepare_v2(ths->m_cobj,
	         querystr, -1 /*read `sql` up to the first null-byte*/,
	         &retStmt,
	         NULL /*tail not interesing, we use only single statements*/) != SQLITE_OK )
	{
		mrsqlite3_log_error(ths, "Query failed: %s", querystr);
		return NULL;
	}

	/* success - the result mus be freed using sqlite3_finalize() */
	return retStmt;
}


int mrsqlite3_execute__(mrsqlite3_t* ths, const char* querystr)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;
	int           sqlState;

	stmt = mrsqlite3_prepare_v2_(ths, querystr);
	if( stmt == NULL ) {
		goto cleanup;
	}

	sqlState = sqlite3_step(stmt);
	if( sqlState != SQLITE_DONE && sqlState != SQLITE_ROW )  {
		mrsqlite3_log_error(ths, "Cannot excecute \"%s\".", querystr);
		goto cleanup;
	}

	success = 1;

cleanup:
	if( stmt ) {
		sqlite3_finalize(stmt);
	}
	return success;
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


mrsqlite3_t* mrsqlite3_new(mrmailbox_t* mailbox)
{
	mrsqlite3_t* ths = NULL;
	int          i;

	if( (ths=calloc(1, sizeof(mrsqlite3_t)))==NULL ) {
		exit(24); /* cannot allocate little memory, unrecoverable error */
	}

	ths->m_mailbox          = mailbox;

	for( i = 0; i < PREDEFINED_CNT; i++ ) {
		ths->m_pd[i] = NULL;
	}

	pthread_mutex_init(&ths->m_critical_, NULL);

	return ths;
}


void mrsqlite3_unref(mrsqlite3_t* ths)
{
	if( ths == NULL ) {
		return;
	}

	if( ths->m_cobj ) {
		pthread_mutex_lock(&ths->m_critical_); /* as a very exeception, we do the locking inside the mrsqlite3-class - normally, this should be done by the caller! */
			mrsqlite3_close__(ths);
		pthread_mutex_unlock(&ths->m_critical_);
	}

	pthread_mutex_destroy(&ths->m_critical_);
	free(ths);
}


int mrsqlite3_open__(mrsqlite3_t* ths, const char* dbfile, int flags)
{
	if( ths == NULL || dbfile == NULL ) {
		goto cleanup;
	}

	if( ths->m_cobj ) {
		mrmailbox_log_error(ths->m_mailbox, 0, "Cannot open, database \"%s\" already opend.", dbfile);
		goto cleanup;
	}

	if( sqlite3_open(dbfile, &ths->m_cobj) != SQLITE_OK ) {
		mrsqlite3_log_error(ths, "Cannot open database \"%s\".", dbfile); /* ususally, even for errors, the pointer is set up (if not, this is also checked by mrsqlite3_log_error()) */
		goto cleanup;
	}

	if( !(flags&MR_OPEN_READONLY) )
	{
		/* Init tables to dbversion=0 */
		if( !mrsqlite3_table_exists__(ths, "config") )
		{
			mrmailbox_log_info(ths->m_mailbox, 0, "First time init: creating tables in \"%s\".", dbfile);

			mrsqlite3_execute__(ths, "CREATE TABLE config (id INTEGER PRIMARY KEY, keyname TEXT, value TEXT);");
			mrsqlite3_execute__(ths, "CREATE INDEX config_index1 ON config (keyname);");

			mrsqlite3_execute__(ths, "CREATE TABLE contacts (id INTEGER PRIMARY KEY,"
						" name TEXT DEFAULT '',"
						" addr TEXT DEFAULT '' COLLATE NOCASE,"
						" origin INTEGER DEFAULT 0,"
						" blocked INTEGER DEFAULT 0,"
						" last_seen INTEGER DEFAULT 0,"   /* last_seen is for future use */
						" param TEXT DEFAULT '');");      /* param is for future use, eg. for the status */
			mrsqlite3_execute__(ths, "CREATE INDEX contacts_index1 ON contacts (name COLLATE NOCASE);"); /* needed for query contacts */
			mrsqlite3_execute__(ths, "CREATE INDEX contacts_index2 ON contacts (addr COLLATE NOCASE);"); /* needed for query and on receiving mails */
			mrsqlite3_execute__(ths, "INSERT INTO contacts (id,name,origin) VALUES (1,'self',262144), (2,'system',262144), (3,'rsvd',262144), (4,'rsvd',262144), (5,'rsvd',262144), (6,'rsvd',262144), (7,'rsvd',262144), (8,'rsvd',262144), (9,'rsvd',262144);");
			#if !defined(MR_ORIGIN_INTERNAL) || MR_ORIGIN_INTERNAL!=262144
				#error
			#endif

			mrsqlite3_execute__(ths, "CREATE TABLE chats (id INTEGER PRIMARY KEY, "
						" type INTEGER DEFAULT 0,"
						" name TEXT DEFAULT '',"
						" draft_timestamp INTEGER DEFAULT 0,"
						" draft_txt TEXT DEFAULT '',"
						" blocked INTEGER DEFAULT 0,"
						" grpid TEXT DEFAULT '',"          /* contacts-global unique group-ID, see mrchat.c for details */
						" param TEXT DEFAULT '');");
			mrsqlite3_execute__(ths, "CREATE INDEX chats_index1 ON chats (grpid);");
			mrsqlite3_execute__(ths, "CREATE TABLE chats_contacts (chat_id INTEGER, contact_id INTEGER);");
			mrsqlite3_execute__(ths, "CREATE INDEX chats_contacts_index1 ON chats_contacts (chat_id);"); /* the other way round, an index on contact_id is only needed for blocking users */
			mrsqlite3_execute__(ths, "INSERT INTO chats (id,type,name) VALUES (1,120,'deaddrop'), (2,120,'to_deaddrop'), (3,120,'trash'), (4,120,'msgs_in_creation'), (5,120,'starred'), (6,120,'archivedlink'), (7,100,'rsvd'), (8,100,'rsvd'), (9,100,'rsvd');");
			#if !defined(MR_CHAT_NORMAL) || MR_CHAT_NORMAL!=100 || MR_CHAT_GROUP!=120 || MR_CHAT_ID_DEADDROP!=1 || MR_CHAT_ID_TO_DEADDROP!=2 || MR_CHAT_ID_TRASH!=3 || MR_CHAT_ID_MSGS_IN_CREATION!=4 || MR_CHAT_ID_STARRED!=5 || MR_CHAT_ID_ARCHIVED_LINK!=6
				#error
			#endif

			mrsqlite3_execute__(ths, "CREATE TABLE msgs (id INTEGER PRIMARY KEY,"
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
						" txt TEXT DEFAULT '',"            /* as this is also used for (fulltext) searching, nothing but normal, plain text should go here */
						" txt_raw TEXT DEFAULT '',"
						" param TEXT DEFAULT '');");
			mrsqlite3_execute__(ths, "CREATE INDEX msgs_index1 ON msgs (rfc724_mid);");     /* in our database, one email may be split up to several messages (eg. one per image), so the email-Message-ID may be used for several records; id is always unique */
			mrsqlite3_execute__(ths, "CREATE INDEX msgs_index2 ON msgs (chat_id);");
			mrsqlite3_execute__(ths, "CREATE INDEX msgs_index3 ON msgs (timestamp);");      /* for sorting */
			mrsqlite3_execute__(ths, "CREATE INDEX msgs_index4 ON msgs (state);");          /* for selecting the count of fresh messages (as there are normally only few unread messages, an index over the chat_id is not required for _this_ purpose */
			mrsqlite3_execute__(ths, "INSERT INTO msgs (id,msgrmsg,txt) VALUES (1,0,'marker1'), (2,0,'rsvd'), (3,0,'rsvd'), (4,0,'rsvd'), (5,0,'rsvd'), (6,0,'rsvd'), (7,0,'rsvd'), (8,0,'rsvd'), (9,0,'daymarker');"); /* make sure, the reserved IDs are not used */

			mrsqlite3_execute__(ths, "CREATE TABLE jobs (id INTEGER PRIMARY KEY,"
						" added_timestamp INTEGER,"
						" desired_timestamp INTEGER DEFAULT 0,"
						" action INTEGER,"
						" foreign_id INTEGER,"
						" param TEXT DEFAULT '');");
			mrsqlite3_execute__(ths, "CREATE INDEX jobs_index1 ON jobs (desired_timestamp);");

			if( !mrsqlite3_table_exists__(ths, "config") || !mrsqlite3_table_exists__(ths, "contacts")
			 || !mrsqlite3_table_exists__(ths, "chats") || !mrsqlite3_table_exists__(ths, "chats_contacts")
			 || !mrsqlite3_table_exists__(ths, "msgs") || !mrsqlite3_table_exists__(ths, "jobs") )
			{
				mrsqlite3_log_error(ths, "Cannot create tables in new database \"%s\".", dbfile);
				goto cleanup; /* cannot create the tables - maybe we cannot write? */
			}

			mrsqlite3_set_config_int__(ths, "dbversion", 0);
		}

		/* Update database */
		int dbversion = mrsqlite3_get_config_int__(ths, "dbversion", 0);
		#define NEW_DB_VERSION 1
			if( dbversion < NEW_DB_VERSION )
			{
				mrsqlite3_execute__(ths, "CREATE TABLE leftgrps ("
							" id INTEGER PRIMARY KEY,"
							" grpid TEXT DEFAULT '');");
				mrsqlite3_execute__(ths, "CREATE INDEX leftgrps_index1 ON leftgrps (grpid);");

				dbversion = NEW_DB_VERSION;
				mrsqlite3_set_config_int__(ths, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 2
			if( dbversion < NEW_DB_VERSION )
			{
				mrsqlite3_execute__(ths, "ALTER TABLE contacts ADD COLUMN authname TEXT DEFAULT '';");

				dbversion = NEW_DB_VERSION;
				mrsqlite3_set_config_int__(ths, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 7
			if( dbversion < NEW_DB_VERSION )
			{
				mrsqlite3_execute__(ths, "CREATE TABLE keypairs ("
							" id INTEGER PRIMARY KEY,"
							" addr TEXT DEFAULT '' COLLATE NOCASE,"
							" is_default INTEGER DEFAULT 0,"
							" private_key,"
							" public_key,"
							" created INTEGER DEFAULT 0);");

				dbversion = NEW_DB_VERSION;
				mrsqlite3_set_config_int__(ths, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 10
			if( dbversion < NEW_DB_VERSION )
			{
				mrsqlite3_execute__(ths, "CREATE TABLE acpeerstates ("
							" id INTEGER PRIMARY KEY,"
							" addr TEXT DEFAULT '' COLLATE NOCASE,"    /* no UNIQUE here, Autocrypt: requires the index above mail+type (type however, is not used at the moment, but to be future-proof, we do not use an index. instead we just check ourself if there is a record or not)*/
							" last_seen INTEGER DEFAULT 0,"
							" last_seen_autocrypt INTEGER DEFAULT 0,"
							" public_key,"
							" prefer_encrypted INTEGER DEFAULT 0);");
				mrsqlite3_execute__(ths, "CREATE INDEX acpeerstates_index1 ON acpeerstates (addr);");

				dbversion = NEW_DB_VERSION;
				mrsqlite3_set_config_int__(ths, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 12
			if( dbversion < NEW_DB_VERSION )
			{
				mrsqlite3_execute__(ths, "CREATE TABLE msgs_mdns ("
							" msg_id INTEGER, "
							" contact_id INTEGER);");
				mrsqlite3_execute__(ths, "CREATE INDEX msgs_mdns_index1 ON msgs_mdns (msg_id);");

				dbversion = NEW_DB_VERSION;
				mrsqlite3_set_config_int__(ths, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION

		#define NEW_DB_VERSION 17
			if( dbversion < NEW_DB_VERSION )
			{
				mrsqlite3_execute__(ths, "ALTER TABLE chats ADD COLUMN archived INTEGER DEFAULT 0;");
				mrsqlite3_execute__(ths, "CREATE INDEX chats_index2 ON chats (archived);");
				mrsqlite3_execute__(ths, "ALTER TABLE msgs ADD COLUMN starred INTEGER DEFAULT 0;");
				mrsqlite3_execute__(ths, "CREATE INDEX msgs_index5 ON msgs (starred);");

				dbversion = NEW_DB_VERSION;
				mrsqlite3_set_config_int__(ths, "dbversion", NEW_DB_VERSION);
			}
		#undef NEW_DB_VERSION
	}

	mrmailbox_log_info(ths->m_mailbox, 0, "Opened \"%s\" successfully.", dbfile);
	return 1;

cleanup:
	mrsqlite3_close__(ths);
	return 0;
}


void mrsqlite3_close__(mrsqlite3_t* ths)
{
	int i;

	if( ths == NULL ) {
		return;
	}

	if( ths->m_cobj )
	{
		for( i = 0; i < PREDEFINED_CNT; i++ ) {
			if( ths->m_pd[i] ) {
				sqlite3_finalize(ths->m_pd[i]);
				ths->m_pd[i] = NULL;
			}
		}

		sqlite3_close(ths->m_cobj);
		ths->m_cobj = NULL;
	}

	mrmailbox_log_info(ths->m_mailbox, 0, "Database closed."); /* We log the information even if not real closing took place; this is to detect logic errors. */
}


int mrsqlite3_is_open(const mrsqlite3_t* ths)
{
	if( ths == NULL || ths->m_cobj == NULL ) {
		return 0;
	}
	return 1;
}


sqlite3_stmt* mrsqlite3_predefine__(mrsqlite3_t* ths, size_t idx, const char* querystr)
{
	/* predefines a statement or resets and reuses a statment.
	Subsequent call may ommit the querystring.
	CAVE: you must not call this function with different strings for the same index! */

	if( ths == NULL || ths->m_cobj == NULL || idx >= PREDEFINED_CNT ) {
		return NULL;
	}

	if( ths->m_pd[idx] ) {
		sqlite3_reset(ths->m_pd[idx]);
		return ths->m_pd[idx]; /* fine, already prepared before */
	}

	/*prepare for the first time - this requires the querystring*/
	if( querystr == NULL ) {
		return NULL;
	}

	if( sqlite3_prepare_v2(ths->m_cobj,
	         querystr, -1 /*read `sql` up to the first null-byte*/,
	         &ths->m_pd[idx],
	         NULL /*tail not interesing, we use only single statements*/) != SQLITE_OK )
	{
		mrsqlite3_log_error(ths, "Preparing statement \"%s\" failed.", querystr);
		return NULL;
	}

	return ths->m_pd[idx];
}


void mrsqlite3_reset_all_predefinitions(mrsqlite3_t* ths)
{
	int i;
	for( i = 0; i < PREDEFINED_CNT; i++ ) {
		if( ths->m_pd[i] ) {
			sqlite3_reset(ths->m_pd[i]);
		}
	}
}


int mrsqlite3_table_exists__(mrsqlite3_t* ths, const char* name)
{
	int           ret = 0;
	char*         querystr = NULL;
	sqlite3_stmt* stmt = NULL;
	int           sqlState;

	if( (querystr=sqlite3_mprintf("PRAGMA table_info(%s)", name)) == NULL ) { /* this statement cannot be used with binded variables */
		mrmailbox_log_error(ths->m_mailbox, 0, "mrsqlite3_table_exists_(): Out of memory.");
		goto cleanup;
	}

	if( (stmt=mrsqlite3_prepare_v2_(ths, querystr)) == NULL ) {
		goto cleanup;
	}

	sqlState = sqlite3_step(stmt);
	if( sqlState == SQLITE_ROW ) {
		ret = 1; /* the table exists. Other states are SQLITE_DONE or SQLITE_ERROR in both cases we return 0. */
	}

	/* success - fall through to free allocated objects */
	;

	/* error/cleanup */
cleanup:
	if( stmt ) {
		sqlite3_finalize(stmt);
	}

	if( querystr ) {
		sqlite3_free(querystr);
	}

	return ret;
}


/*******************************************************************************
 * Handle configuration
 ******************************************************************************/


int mrsqlite3_set_config__(mrsqlite3_t* ths, const char* key, const char* value)
{
	int           state;
	sqlite3_stmt* stmt;

	if( key == NULL ) {
		mrmailbox_log_error(ths->m_mailbox, 0, "mrsqlite3_set_config(): Bad parameter.");
		return 0;
	}

	if( !mrsqlite3_is_open(ths) ) {
		mrmailbox_log_error(ths->m_mailbox, 0, "mrsqlite3_set_config(): Database not ready.");
		return 0;
	}

	if( value )
	{
		/* insert/update key=value */
		#define SELECT_v_FROM_config_k_STATEMENT "SELECT value FROM config WHERE keyname=?;"
		stmt = mrsqlite3_predefine__(ths, SELECT_v_FROM_config_k, SELECT_v_FROM_config_k_STATEMENT);
		sqlite3_bind_text (stmt, 1, key, -1, SQLITE_STATIC);
		state=sqlite3_step(stmt);
		if( state == SQLITE_DONE ) {
			stmt = mrsqlite3_predefine__(ths, INSERT_INTO_config_kv, "INSERT INTO config (keyname, value) VALUES (?, ?);");
			sqlite3_bind_text (stmt, 1, key,   -1, SQLITE_STATIC);
			sqlite3_bind_text (stmt, 2, value, -1, SQLITE_STATIC);
			state=sqlite3_step(stmt);

		}
		else if( state == SQLITE_ROW ) {
			stmt = mrsqlite3_predefine__(ths, UPDATE_config_vk, "UPDATE config SET value=? WHERE keyname=?;");
			sqlite3_bind_text (stmt, 1, value, -1, SQLITE_STATIC);
			sqlite3_bind_text (stmt, 2, key,   -1, SQLITE_STATIC);
			state=sqlite3_step(stmt);
		}
		else {
			mrmailbox_log_error(ths->m_mailbox, 0, "mrsqlite3_set_config(): Cannot read value.");
			return 0;
		}
	}
	else
	{
		/* delete key */
		stmt = mrsqlite3_predefine__(ths, DELETE_FROM_config_k, "DELETE FROM config WHERE keyname=?;");
		sqlite3_bind_text (stmt, 1, key,   -1, SQLITE_STATIC);
		state=sqlite3_step(stmt);
	}

	if( state != SQLITE_DONE )  {
		mrmailbox_log_error(ths->m_mailbox, 0, "mrsqlite3_set_config(): Cannot change value.");
		return 0;
	}

	return 1;
}


char* mrsqlite3_get_config__(mrsqlite3_t* ths, const char* key, const char* def) /* the returned string must be free()'d, NULL is only returned if def is NULL */
{
	sqlite3_stmt* stmt;

	if( !mrsqlite3_is_open(ths) || key == NULL ) {
		return strdup_keep_null(def);
	}

	stmt = mrsqlite3_predefine__(ths, SELECT_v_FROM_config_k, SELECT_v_FROM_config_k_STATEMENT);
	sqlite3_bind_text(stmt, 1, key, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) == SQLITE_ROW )
	{
		const unsigned char* ptr = sqlite3_column_text(stmt, 0); /* Do not pass the pointers returned from sqlite3_column_text(), etc. into sqlite3_free(). */
		if( ptr )
		{
			/* success, fall through below to free objects */
			return safe_strdup((const char*)ptr);
		}
	}

	/* return the default value */
	return strdup_keep_null(def);
}


int32_t mrsqlite3_get_config_int__(mrsqlite3_t* ths, const char* key, int32_t def)
{
    char* str = mrsqlite3_get_config__(ths, key, NULL);
    if( str == NULL ) {
		return def;
    }
    int32_t ret = atol(str);
    free(str);
    return ret;
}


int mrsqlite3_set_config_int__(mrsqlite3_t* ths, const char* key, int32_t value)
{
    char* value_str = mr_mprintf("%i", (int)value);
    if( value_str == NULL ) {
		return 0;
    }
    int ret = mrsqlite3_set_config__(ths, key, value_str);
    free(value_str);
    return ret;
}


/*******************************************************************************
 * Locking
 ******************************************************************************/


void mrsqlite3_lock(mrsqlite3_t* ths) /* wait and lock */
{
	pthread_mutex_lock(&ths->m_critical_);

	mrmailbox_wake_lock(ths->m_mailbox);
}


void mrsqlite3_unlock(mrsqlite3_t* ths)
{
	mrmailbox_wake_unlock(ths->m_mailbox);

	pthread_mutex_unlock(&ths->m_critical_);
}


/*******************************************************************************
 * Transactions
 ******************************************************************************/


void mrsqlite3_begin_transaction__(mrsqlite3_t* ths)
{
	sqlite3_stmt* stmt;

	ths->m_transactionCount++; /* this is safe, as the database should be locked when using a transaction */

	if( ths->m_transactionCount == 1 )
	{
		stmt = mrsqlite3_predefine__(ths, BEGIN_transaction, "BEGIN;");
		if( sqlite3_step(stmt) != SQLITE_DONE ) {
			mrsqlite3_log_error(ths, "Cannot begin transaction.");
		}
	}
}


void mrsqlite3_rollback__(mrsqlite3_t* ths)
{
	sqlite3_stmt* stmt;

	if( ths->m_transactionCount >= 1 )
	{
		if( ths->m_transactionCount == 1 )
		{
			stmt = mrsqlite3_predefine__(ths, ROLLBACK_transaction, "ROLLBACK;");
			if( sqlite3_step(stmt) != SQLITE_DONE ) {
				mrsqlite3_log_error(ths, "Cannot rollback transaction.");
			}
		}

		ths->m_transactionCount--;
	}
}


void mrsqlite3_commit__(mrsqlite3_t* ths)
{
	sqlite3_stmt* stmt;

	if( ths->m_transactionCount >= 1 )
	{
		if( ths->m_transactionCount == 1 )
		{
			stmt = mrsqlite3_predefine__(ths, COMMIT_transaction, "COMMIT;");
			if( sqlite3_step(stmt) != SQLITE_DONE ) {
				mrsqlite3_log_error(ths, "Cannot commit transaction.");
			}
		}

		ths->m_transactionCount--;
	}
}
