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


#include <sys/stat.h>
#include <sys/types.h> /* for getpid() */
#include <unistd.h>    /* for getpid() */
#include <openssl/opensslv.h>
#include <assert.h>
#include "mrmailbox_internal.h"
#include "mrimap.h"
#include "mrsmtp.h"
#include "mrmimefactory.h"
#include "mrtools.h"
#include "mrjob.h"
#include "mrloginparam.h"
#include "mrkey.h"
#include "mrpgp.h"
#include "mrapeerstate.h"


/*******************************************************************************
 * Main interface
 ******************************************************************************/


static uintptr_t cb_dummy(mrmailbox_t* mailbox, int event, uintptr_t data1, uintptr_t data2)
{
	return 0;
}
static char* cb_get_config(mrimap_t* imap, const char* key, const char* def)
{
	mrmailbox_t* mailbox = (mrmailbox_t*)imap->m_userData;
	mrsqlite3_lock(mailbox->m_sql);
		char* ret = mrsqlite3_get_config__(mailbox->m_sql, key, def);
	mrsqlite3_unlock(mailbox->m_sql);
	return ret;
}
static void cb_set_config(mrimap_t* imap, const char* key, const char* value)
{
	mrmailbox_t* mailbox = (mrmailbox_t*)imap->m_userData;
	mrsqlite3_lock(mailbox->m_sql);
		mrsqlite3_set_config__(mailbox->m_sql, key, value);
	mrsqlite3_unlock(mailbox->m_sql);
}
static void cb_receive_imf(mrimap_t* imap, const char* imf_raw_not_terminated, size_t imf_raw_bytes, const char* server_folder, uint32_t server_uid, uint32_t flags)
{
	mrmailbox_t* mailbox = (mrmailbox_t*)imap->m_userData;
	mrmailbox_receive_imf(mailbox, imf_raw_not_terminated, imf_raw_bytes, server_folder, server_uid, flags);
}


/**
 * Create a new mailbox object.  After creation it is usually
 * opened, connected and mails are fetched.
 * After usage, the object should be deleted using mrmailbox_unref().
 *
 * @memberof mrmailbox_t
 *
 * @param cb a callback function that is called for events (update,
 *     state changes etc.) and to get some information form the client (eg. translation
 *     for a given string).
 *     See mrevent.h for a list of possible events that may be passed to the callback.
 *     - The callback MAY be called from _any_ thread, not only the main/GUI thread!
 *     - The callback MUST NOT call any mrmailbox_* and related functions unless stated
 *       otherwise!
 *     - The callback SHOULD return _fast_, for GUI updates etc. you should
 *       post yourself an asynchronous message to your GUI thread, if needed.
 *     - If not mentioned otherweise, the callback should return 0.
 *
 * @param userdata can be used by the client for any purpuse.  He finds it
 *     later in mrmailbox_get_userdata().
 *
 * @param os_name is only for decorative use and is shown eg. in the `X-Mailer:` header
 *     in the form "Delta Chat <version> for <os_name>".
 *     You can give the name of the operating system and/or the used environment here.
 *     It is okay to give NULL, in this case `X-Mailer:` header is set to "Delta Chat <version>".
 *
 * @return a mailbox object with some public members the object must be passed to the other mailbox functions
 *     and the object must be freed using mrmailbox_unref() after usage.
 */
mrmailbox_t* mrmailbox_new(mrmailboxcb_t cb, void* userdata, const char* os_name)
{
	mrmailbox_get_thread_index(); /* make sure, the main thread has the index #1, only for a nicer look of the logs */

	mrmailbox_t* ths = NULL;

	if( (ths=calloc(1, sizeof(mrmailbox_t)))==NULL ) {
		exit(23); /* cannot allocate little memory, unrecoverable error */
	}

	pthread_mutex_init(&ths->m_log_ringbuf_critical, NULL);

	pthread_mutex_init(&ths->m_wake_lock_critical, NULL);

	ths->m_magic    = MR_MAILBOX_MAGIC;
	ths->m_sql      = mrsqlite3_new(ths);
	ths->m_cb       = cb? cb : cb_dummy;
	ths->m_userdata = userdata;
	ths->m_imap     = mrimap_new(cb_get_config, cb_set_config, cb_receive_imf, (void*)ths, ths);
	ths->m_smtp     = mrsmtp_new(ths);
	ths->m_os_name  = strdup_keep_null(os_name);

	mrjob_init_thread(ths);

	mrpgp_init(ths);

	/* Random-seed.  An additional seed with more random data is done just before key generation
	(the timespan between this call and the key generation time is typically random.
	Moreover, later, we add a hash of the first message data to the random-seed
	(it would be okay to seed with even more sensible data, the seed values cannot be recovered from the PRNG output, see OpenSSL's RAND_seed() ) */
	{
	uintptr_t seed[5];
	seed[0] = (uintptr_t)time(NULL);     /* time */
	seed[1] = (uintptr_t)seed;           /* stack */
	seed[2] = (uintptr_t)ths;            /* heap */
	seed[3] = (uintptr_t)pthread_self(); /* thread ID */
	seed[4] = (uintptr_t)getpid();       /* process ID */
	mrpgp_rand_seed(ths, seed, sizeof(seed));
	}

	if( s_localize_mb_obj==NULL ) {
		s_localize_mb_obj = ths;
	}

	return ths;
}


/**
 * Free a mailbox object.
 * If app runs can only be terminated by a forced kill, this may be superfluous.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new().
 *
 * @return none
 */
void mrmailbox_unref(mrmailbox_t* mailbox)
{
	if( mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
	}

	mrpgp_exit(mailbox);

	mrjob_exit_thread(mailbox);

	if( mrmailbox_is_open(mailbox) ) {
		mrmailbox_close(mailbox);
	}

	mrimap_unref(mailbox->m_imap);
	mrsmtp_unref(mailbox->m_smtp);
	mrsqlite3_unref(mailbox->m_sql);
	pthread_mutex_destroy(&mailbox->m_wake_lock_critical);

	pthread_mutex_destroy(&mailbox->m_log_ringbuf_critical);
	for( int i = 0; i < MR_LOG_RINGBUF_SIZE; i++ ) {
		free(mailbox->m_log_ringbuf[i]);
	}

	free(mailbox->m_os_name);
	mailbox->m_magic = 0;
	free(mailbox);

	if( s_localize_mb_obj==mailbox ) {
		s_localize_mb_obj = NULL;
	}
}


/**
 * Get user data associated with a mailbox object.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new().
 *
 * @return User data, this is the second parameter given to mrmailbox_new().
 */
void* mrmailbox_get_userdata(mrmailbox_t* mailbox)
{
	if( mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return NULL;
	}
	return mailbox->m_userdata;
}


static void update_config_cache__(mrmailbox_t* ths, const char* key)
{
	if( key==NULL || strcmp(key, "e2ee_enabled")==0 ) {
		ths->m_e2ee_enabled = mrsqlite3_get_config_int__(ths->m_sql, "e2ee_enabled", MR_E2EE_DEFAULT_ENABLED);
	}
}


/**
 * Open mailbox database.  If the given file does not exist, it is
 * created and can be set up using mrmailbox_set_config() afterwards.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox: the mailbox object as created by mrmailbox_new
 *
 * @param dbfile the file to use to store the database, sth. like "~/file" won't
 *     work on all systems, if in doubt, use absolute paths.
 *     You can find the file path later in mrmailbox_t::m_dbfile
 *
 * @param blobdir a directory to store the blobs in, the trailing slash is added
 *     by us, so if you want to avoid double slashes, do not add one. If you
 *     give NULL as blobdir, `dbfile-blobs` is used in the same directory as
 *     _dbfile_ will be created in.
 *     You can find the path to the blob direcrory later in mrmailbox_t::m_blobdir
 *
 * @return 1 on success, 0 on failure
 */
int mrmailbox_open(mrmailbox_t* mailbox, const char* dbfile, const char* blobdir)
{
	int success = 0;
	int db_locked = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || dbfile == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	db_locked = 1;

		/* Open() sets up the object and connects to the given database
		from which all configuration is read/written to. */

		/* Create/open sqlite database */
		if( !mrsqlite3_open__(mailbox->m_sql, dbfile, 0) ) {
			goto cleanup;
		}
		mrjob_kill_action__(mailbox, MRJ_CONNECT_TO_IMAP);

		/* backup dbfile name */
		mailbox->m_dbfile = safe_strdup(dbfile);

		/* set blob-directory
		(to avoid double slashed, the given directory should not end with an slash) */
		if( blobdir && blobdir[0] ) {
			mailbox->m_blobdir = safe_strdup(blobdir);
		}
		else {
			mailbox->m_blobdir = mr_mprintf("%s-blobs", dbfile);
			mr_create_folder(mailbox->m_blobdir, mailbox);
		}

		update_config_cache__(mailbox, NULL);

		success = 1;

cleanup:
		if( !success ) {
			if( mrsqlite3_is_open(mailbox->m_sql) ) {
				mrsqlite3_close__(mailbox->m_sql);
			}
		}

	if( db_locked ) { mrsqlite3_unlock(mailbox->m_sql); }

	return success;
}


/**
 * Close mailbox database.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new()
 *
 * @return none
 */
void mrmailbox_close(mrmailbox_t* mailbox)
{
	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
	}

	mrimap_disconnect(mailbox->m_imap);
	mrsmtp_disconnect(mailbox->m_smtp);

	mrsqlite3_lock(mailbox->m_sql);

		if( mrsqlite3_is_open(mailbox->m_sql) ) {
			mrsqlite3_close__(mailbox->m_sql);
		}

		free(mailbox->m_dbfile);
		mailbox->m_dbfile = NULL;

		free(mailbox->m_blobdir);
		mailbox->m_blobdir = NULL;

	mrsqlite3_unlock(mailbox->m_sql);
}


/**
 * Check if the mailbox database is open.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new().
 *
 * @return 0=mailbox is not open, 1=mailbox is open.
 */
int mrmailbox_is_open(const mrmailbox_t* mailbox)
{
	if( mailbox == NULL ) {
		return 0; /* error - database not opened */
	}

	return mrsqlite3_is_open(mailbox->m_sql);
}


/**
 * Get the blob directory.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new().
 *
 * @return Blob directory associated with the mailbox object, empty string if unset or on errors. NULL is never returned.
 *     The returned string must be free()'d.
 */
char* mrmailbox_get_blobdir(mrmailbox_t* mailbox)
{
	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return safe_strdup(NULL);
	}
	return safe_strdup(mailbox->m_blobdir);
}


/*******************************************************************************
 * INI-handling, Information
 ******************************************************************************/


/**
 * Configure the mailbox.  The configuration is handled by key=value pairs. Typical configuration options are:
 *
 * - addr         = address to display (needed)
 * - mail_server  = IMAP-server, guessed if left out
 * - mail_user    = IMAP-username, guessed if left out
 * - mail_pw      = IMAP-password (needed)
 * - mail_port    = IMAP-port, guessed if left out
 * - send_server  = SMTP-server, guessed if left out
 * - send_user    = SMTP-user, guessed if left out
 * - send_pw      = SMTP-password, guessed if left out
 * - send_port    = SMTP-port, guessed if left out
 * - server_flags = IMAP-/SMTP-flags, guessed if left out
 * - displayname  = Own name to use when sending messages.  MUAs are allowed to spread this way eg. using CC, defaults to empty
 * - selfstatus   = Own status to display eg. in email footers, defaults to a standard text
 * - e2ee_enabled = 0=no e2ee, 1=prefer encryption (default)
 *
 * @memberof mrmailbox_t
 *
 * @param ths the mailbox object
 *
 * @param key the option to change, typically one of the strings listed above
 *
 * @param value the value to save for "key"
 *
 * @return 0=failure, 1=success
 */
int mrmailbox_set_config(mrmailbox_t* ths, const char* key, const char* value)
{
	int ret;

	if( ths == NULL || ths->m_magic != MR_MAILBOX_MAGIC || key == NULL ) { /* "value" may be NULL */
		return 0;
	}

	mrsqlite3_lock(ths->m_sql);

		ret = mrsqlite3_set_config__(ths->m_sql, key, value);
		update_config_cache__(ths, key);

	mrsqlite3_unlock(ths->m_sql);

	return ret;
}


/**
 * Get a configuration option.  The configuration option is typically set by mrmailbox_set_config() or by the library itself.
 *
 * @memberof mrmailbox_t
 *
 * @param ths the mailbox object as created by mrmmailbox_new()
 *
 * @param key the key to query
 *
 * @param def default value to return if "key" is unset
 *
 * @return Returns current value of "key", if "key" is unset, "def" is returned (which may be NULL)
 *     If the returned values is not NULL, the return value must be free()'d,
 */
char* mrmailbox_get_config(mrmailbox_t* ths, const char* key, const char* def)
{
	char* ret;

	if( ths == NULL || ths->m_magic != MR_MAILBOX_MAGIC || key == NULL ) { /* "def" may be NULL */
		return strdup_keep_null(def);
	}

	mrsqlite3_lock(ths->m_sql);

		ret = mrsqlite3_get_config__(ths->m_sql, key, def);

	mrsqlite3_unlock(ths->m_sql);

	return ret; /* the returned string must be free()'d, returns NULL only if "def" is NULL and "key" is unset */
}


/**
 * Configure the mailbox.  Similar to mrmailbox_set_config() but sets an integer instead of a string.
 * If there is already a key with a string set, this is overwritten by the given integer value.
 *
 * @memberof mrmailbox_t
 */
int mrmailbox_set_config_int(mrmailbox_t* ths, const char* key, int32_t value)
{
	int ret;

	if( ths == NULL || ths->m_magic != MR_MAILBOX_MAGIC || key == NULL ) {
		return 0;
	}

	mrsqlite3_lock(ths->m_sql);

		ret = mrsqlite3_set_config_int__(ths->m_sql, key, value);
		update_config_cache__(ths, key);

	mrsqlite3_unlock(ths->m_sql);

	return ret;
}


/**
 * Get a configuration option. Similar as mrmailbox_get_config() but gets the value as an integer instead of a string.
 *
 * @memberof mrmailbox_t
 */
int32_t mrmailbox_get_config_int(mrmailbox_t* ths, const char* key, int32_t def)
{
	int32_t ret;

	if( ths == NULL || ths->m_magic != MR_MAILBOX_MAGIC || key == NULL ) {
		return def;
	}

	mrsqlite3_lock(ths->m_sql);

		ret = mrsqlite3_get_config_int__(ths->m_sql, key, def);

	mrsqlite3_unlock(ths->m_sql);

	return ret;
}


/**
 * Get information about the mailbox.  The information is returned by a multi-line string and contains information about the current
 * configuration and the last log entries.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as returned by mrmailbox_new().
 *
 * @return String which must be free()'d after usage.  Never returns NULL.
 */
char* mrmailbox_get_info(mrmailbox_t* mailbox)
{
	const char* unset = "0";
	char *displayname = NULL, *temp = NULL, *l_readable_str = NULL, *l2_readable_str = NULL, *fingerprint_str = NULL;
	mrloginparam_t *l = NULL, *l2 = NULL;
	int contacts, chats, real_msgs, deaddrop_msgs, is_configured, dbversion, mdns_enabled, e2ee_enabled, prv_key_count, pub_key_count;
	mrkey_t* self_public = mrkey_new();

	mrstrbuilder_t  ret;
	mrstrbuilder_init(&ret, 0);

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return safe_strdup("ErrBadPtr");
	}

	/* read data (all pointers may be NULL!) */
	l = mrloginparam_new();
	l2 = mrloginparam_new();

	mrsqlite3_lock(mailbox->m_sql);

		mrloginparam_read__(l, mailbox->m_sql, "");
		mrloginparam_read__(l2, mailbox->m_sql, "configured_" /*the trailing underscore is correct*/);

		displayname     = mrsqlite3_get_config__(mailbox->m_sql, "displayname", NULL);

		chats           = mrmailbox_get_chat_cnt__(mailbox);
		real_msgs       = mrmailbox_get_real_msg_cnt__(mailbox);
		deaddrop_msgs   = mrmailbox_get_deaddrop_msg_cnt__(mailbox);
		contacts        = mrmailbox_get_real_contact_cnt__(mailbox);

		is_configured   = mrsqlite3_get_config_int__(mailbox->m_sql, "configured", 0);

		dbversion       = mrsqlite3_get_config_int__(mailbox->m_sql, "dbversion", 0);

		e2ee_enabled    = mailbox->m_e2ee_enabled;

		mdns_enabled    = mrsqlite3_get_config_int__(mailbox->m_sql, "mdns_enabled", MR_MDNS_DEFAULT_ENABLED);

		sqlite3_stmt* stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "SELECT COUNT(*) FROM keypairs;");
		sqlite3_step(stmt);
		prv_key_count = sqlite3_column_int(stmt, 0);
		sqlite3_finalize(stmt);

		stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "SELECT COUNT(*) FROM acpeerstates;");
		sqlite3_step(stmt);
		pub_key_count = sqlite3_column_int(stmt, 0);
		sqlite3_finalize(stmt);

		if( mrkey_load_self_public__(self_public, l2->m_addr, mailbox->m_sql) ) {
			fingerprint_str = mrkey_get_formatted_fingerprint(self_public);
		}
		else {
			fingerprint_str = safe_strdup("<Not yet calculated>");
		}

	mrsqlite3_unlock(mailbox->m_sql);

	l_readable_str = mrloginparam_get_readable(l);
	l2_readable_str = mrloginparam_get_readable(l2);

	/* create info
	- some keys are display lower case - these can be changed using the `set`-command
	- we do not display the password here; in the cli-utility, you can see it using `get mail_pw`
	- use neutral speach; the Delta Chat Core is not directly related to any front end or end-product
	- contributors: You're welcome to add your names here */
	temp = mr_mprintf(
		"Chats: %i\n"
		"Chat messages: %i\n"
		"Messages in mailbox: %i\n"
		"Contacts: %i\n"
		"Database=%s, dbversion=%i, Blobdir=%s\n"
		"\n"
		"displayname=%s\n"
		"configured=%i\n"
		"config0=%s\n"
		"config1=%s\n"
		"mdns_enabled=%i\n"
		"e2ee_enabled=%i\n"
		"E2EE_DEFAULT_ENABLED=%i\n"
		"Private keys=%i, public keys=%i, fingerprint=\n%s\n"
		"\n"
		"Using Delta Chat Core v%i.%i.%i, SQLite %s-ts%i, libEtPan %i.%i, OpenSSL %i.%i.%i%c. Compiled " __DATE__ ", " __TIME__ " for %i bit usage.\n\n"
		"Log excerpt:\n"
		/* In the frontends, additional software hints may follow here. */

		, chats, real_msgs, deaddrop_msgs, contacts
		, mailbox->m_dbfile? mailbox->m_dbfile : unset,   dbversion,   mailbox->m_blobdir? mailbox->m_blobdir : unset

        , displayname? displayname : unset
		, is_configured
		, l_readable_str, l2_readable_str

		, mdns_enabled

		, e2ee_enabled
		, MR_E2EE_DEFAULT_ENABLED
		, prv_key_count, pub_key_count, fingerprint_str

		, MR_VERSION_MAJOR, MR_VERSION_MINOR, MR_VERSION_REVISION
		, SQLITE_VERSION, sqlite3_threadsafe()   ,  libetpan_get_version_major(), libetpan_get_version_minor()
		, (int)(OPENSSL_VERSION_NUMBER>>28), (int)(OPENSSL_VERSION_NUMBER>>20)&0xFF, (int)(OPENSSL_VERSION_NUMBER>>12)&0xFF, (char)('a'-1+((OPENSSL_VERSION_NUMBER>>4)&0xFF))
		, sizeof(void*)*8

		);
	mrstrbuilder_cat(&ret, temp);
	free(temp);

	/* add log excerpt */
	pthread_mutex_lock(&mailbox->m_log_ringbuf_critical); /*take care not to log here! */
		for( int i = 0; i < MR_LOG_RINGBUF_SIZE; i++ ) {
			int j = (mailbox->m_log_ringbuf_pos+i) % MR_LOG_RINGBUF_SIZE;
			if( mailbox->m_log_ringbuf[j] ) {
				struct tm wanted_struct;
				memcpy(&wanted_struct, localtime(&mailbox->m_log_ringbuf_times[j]), sizeof(struct tm));
				temp = mr_mprintf("\n%02i:%02i:%02i ", (int)wanted_struct.tm_hour, (int)wanted_struct.tm_min, (int)wanted_struct.tm_sec);
					mrstrbuilder_cat(&ret, temp);
					mrstrbuilder_cat(&ret, mailbox->m_log_ringbuf[j]);
				free(temp);
			}
		}
	pthread_mutex_unlock(&mailbox->m_log_ringbuf_critical);

	/* free data */
	mrloginparam_unref(l);
	mrloginparam_unref(l2);
	free(displayname);
	free(l_readable_str);
	free(l2_readable_str);
	free(fingerprint_str);
	mrkey_unref(self_public);
	return ret.m_buf; /* must be freed by the caller */
}


/*******************************************************************************
 * Misc.
 ******************************************************************************/


int mrmailbox_get_archived_count__(mrmailbox_t* mailbox)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_chats_WHERE_archived, "SELECT COUNT(*) FROM chats WHERE blocked=0 AND archived=1;");
	if( sqlite3_step(stmt) == SQLITE_ROW ) {
		return sqlite3_column_int(stmt, 0);
	}
	return 0;
}


/**
 * Find out the version of the Delta Chat core library.
 *
 * @memberof mrmailbox_t
 *
 * @return String with version number as `major.minor.revision`. The return value must be free()'d.
 */
char* mrmailbox_get_version_str(void)
{
	return mr_mprintf("%i.%i.%i", (int)MR_VERSION_MAJOR, (int)MR_VERSION_MINOR, (int)MR_VERSION_REVISION);
}


void mrmailbox_wake_lock(mrmailbox_t* mailbox)
{
	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
	}
	pthread_mutex_lock(&mailbox->m_wake_lock_critical);
		mailbox->m_wake_lock++;
		if( mailbox->m_wake_lock == 1 ) {
			mailbox->m_cb(mailbox, MR_EVENT_WAKE_LOCK, 1, 0);
		}
	pthread_mutex_unlock(&mailbox->m_wake_lock_critical);
}


void mrmailbox_wake_unlock(mrmailbox_t* mailbox)
{
	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
	}
	pthread_mutex_lock(&mailbox->m_wake_lock_critical);
		if( mailbox->m_wake_lock == 1 ) {
			mailbox->m_cb(mailbox, MR_EVENT_WAKE_LOCK, 0, 0);
		}

		if( mailbox->m_wake_lock > 0 ) {
			mailbox->m_wake_lock--;
		}
	pthread_mutex_unlock(&mailbox->m_wake_lock_critical);
}


/*******************************************************************************
 * Connect
 ******************************************************************************/


void mrmailbox_connect_to_imap(mrmailbox_t* ths, mrjob_t* job /*may be NULL if the function is called directly!*/)
{
	int             is_locked = 0;
	mrloginparam_t* param = mrloginparam_new();

	if( ths == NULL || ths->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	if( mrimap_is_connected(ths->m_imap) ) {
		mrmailbox_log_info(ths, 0, "Already connected or trying to connect.");
		goto cleanup;
	}

	mrsqlite3_lock(ths->m_sql);
	is_locked = 1;

		if( mrsqlite3_get_config_int__(ths->m_sql, "configured", 0) == 0 ) {
			mrmailbox_log_error(ths, 0, "Not configured.");
			goto cleanup;
		}

		mrloginparam_read__(param, ths->m_sql, "configured_" /*the trailing underscore is correct*/);

	mrsqlite3_unlock(ths->m_sql);
	is_locked = 0;

	if( !mrimap_connect(ths->m_imap, param) ) {
		mrjob_try_again_later(job, MR_STANDARD_DELAY);
		goto cleanup;
	}

cleanup:
	if( is_locked ) { mrsqlite3_unlock(ths->m_sql); }
	mrloginparam_unref(param);
}


/**
 * Connect to the mailbox using the configured settings.  We connect using IMAP-IDLE or, if this is not possible,
 * a using pull algorithm.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new()
 *
 * @return None
 */
void mrmailbox_connect(mrmailbox_t* mailbox)
{
	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);

		mailbox->m_smtp->m_log_connect_errors = 1;
		mailbox->m_imap->m_log_connect_errors = 1;

		mrjob_kill_action__(mailbox, MRJ_CONNECT_TO_IMAP);
		mrjob_add__(mailbox, MRJ_CONNECT_TO_IMAP, 0, NULL, 0);

	mrsqlite3_unlock(mailbox->m_sql);
}


/**
 * Disonnect the mailbox from the server.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new()
 *
 * @return None
 */
void mrmailbox_disconnect(mrmailbox_t* mailbox)
{
	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);

		mrjob_kill_action__(mailbox, MRJ_CONNECT_TO_IMAP);

	mrsqlite3_unlock(mailbox->m_sql);

	mrimap_disconnect(mailbox->m_imap);
	mrsmtp_disconnect(mailbox->m_smtp);
}


/**
 * Stay alive.
 * The library tries itself to stay alive. For this purpose there is an additional
 * "heartbeat" thread that checks if the IDLE-thread is up and working. This check is done about every minute.
 * However, depending on the operating system, this thread may be delayed or stopped, if this is the case you can
 * force additional checks manually by just calling mrmailbox_heartbeat() about every minute.
 * If in doubt, call this function too often, not too less :-)
 *
 * The function MUST NOT be called from the UI thread and may take a moment to return.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object.
 *
 * @return None.
 */
void mrmailbox_heartbeat(mrmailbox_t* mailbox)
{
	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
	}

	//mrmailbox_log_info(ths, 0, "<3 Mailbox");
	mrimap_heartbeat(mailbox->m_imap);
}

/**
 * Get a list of chats. The list can be filtered by query parameters.
 * To get the chat messages, use mrmailbox_get_chat_msgs().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned by mrmailbox_new()
 *
 * @param listflags A combination of flags:
 *     - if the flag MR_GCL_ARCHIVED_ONLY is set, only archived chats are returned.
 *       if MR_GCL_ARCHIVED_ONLY is not set, only unarchived chats are returned and
 *       the pseudo-chat MR_CHAT_ID_ARCHIVED_LINK is added if there are _any_ archived
 *       chats
 *     - if the flag MR_GCL_NO_SPECIALS is set, deaddrop and archive link are not added
 *       to the list (may be used eg. for selecting chats on forwarding, the flag is
 *       not needed when MR_GCL_ARCHIVED_ONLY is already set)
 *
 * @param query_str An optional query for filtering the list.  Only chats matching this query
 *     are returned.  Give NULL for no filtering.
 *
 * @param query_id An optional contact ID for filtering the list.  Only chats including this contact ID
 *     are returned.  Give 0 for no filtering.
 *
 * @return A chatlist as an mrchatlist_t object. Must be freed using
 *     mrchatlist_unref() when no longer used
 */
mrchatlist_t* mrmailbox_get_chatlist(mrmailbox_t* mailbox, int listflags, const char* query_str, uint32_t query_id)
{
	int success = 0;
	int db_locked = 0;
	mrchatlist_t* obj = mrchatlist_new(mailbox);

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	db_locked = 1;

		if( !mrchatlist_load_from_db__(obj, listflags, query_str, query_id) ) {
			goto cleanup;
		}

		success = 1;

cleanup:
	if( db_locked ) { mrsqlite3_unlock(mailbox->m_sql); }

	if( success ) {
		return obj;
	}
	else {
		mrchatlist_unref(obj);
		return NULL;
	}
}


/**
 * Get chat object by a chat ID.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The ID of the chat to get the chat object for.
 *
 * @return A chat object of the type mrchat_t, must be freed using mrchat_unref() when done.
 */
mrchat_t* mrmailbox_get_chat(mrmailbox_t* mailbox, uint32_t chat_id)
{
	int success = 0;
	int db_locked = 0;
	mrchat_t* obj = mrchat_new(mailbox);

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	db_locked = 1;

		if( !mrchat_load_from_db__(obj, chat_id) ) {
			goto cleanup;
		}

		success = 1;

cleanup:
	if( db_locked ) { mrsqlite3_unlock(mailbox->m_sql); }

	if( success ) {
		return obj;
	}
	else {
		mrchat_unref(obj);
		return NULL;
	}
}


/**
 * Mark all messages in a chat as _noticed_.
 * _Noticed_ messages are no longer _fresh_ and do not count as being unseen.
 * IMAP/MDNs is not done for noticed messages.  See also mrmailbox_marknoticed_contact()
 * and mrmailbox_markseen_msgs()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The chat ID of which all messages should be marked as being noticed.
 *
 * @return None.
 */
void mrmailbox_marknoticed_chat(mrmailbox_t* mailbox, uint32_t chat_id)
{
	/* marking a chat as "seen" is done by marking all fresh chat messages as "noticed" -
	"noticed" messages are not counted as being unread but are still waiting for being marked as "seen" using mrmailbox_markseen_msgs() */
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);

		stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_state_WHERE_chat_id_AND_state,
			"UPDATE msgs SET state=" MR_STRINGIFY(MR_STATE_IN_NOTICED) " WHERE chat_id=? AND state=" MR_STRINGIFY(MR_STATE_IN_FRESH) ";");
		sqlite3_bind_int(stmt, 1, chat_id);
		sqlite3_step(stmt);

	mrsqlite3_unlock(mailbox->m_sql);
}


/**
 * Check, if there is a normal chat with a given contact.
 * To get the chat messages, use mrmailbox_get_chat_msgs().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param contact_id The contact ID to check.
 *
 * @return If there is a normal chat with the given contact_id, this chat_id is
 *     returned.  If there is no normal chat with the contact_id, the function
 *     returns 0.
 */
uint32_t mrmailbox_get_chat_id_by_contact_id(mrmailbox_t* mailbox, uint32_t contact_id)
{
	uint32_t chat_id = 0;
	int      chat_id_blocked = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return 0;
	}

	mrsqlite3_lock(mailbox->m_sql);

		mrmailbox_lookup_real_nchat_by_contact_id__(mailbox, contact_id, &chat_id, &chat_id_blocked);

	mrsqlite3_unlock(mailbox->m_sql);

	return chat_id_blocked? 0 : chat_id; /* from outside view, chats only existing in the deaddrop do not exist */
}


uint32_t mrmailbox_get_chat_id_by_grpid__(mrmailbox_t* mailbox, const char* grpid, int* ret_blocked, int* ret_verified)
{
	uint32_t      chat_id = 0;
	sqlite3_stmt* stmt;

	if(ret_blocked)  { *ret_blocked = 0;  }
	if(ret_verified) { *ret_verified = 0; }

	if( mailbox == NULL || grpid == NULL ) {
		goto cleanup;
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_CHATS_WHERE_grpid,
		"SELECT id, blocked, type FROM chats WHERE grpid=?;");
	sqlite3_bind_text (stmt, 1, grpid, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt)==SQLITE_ROW ) {
		                    chat_id      =  sqlite3_column_int(stmt, 0);
		if(ret_blocked)  { *ret_blocked  =  sqlite3_column_int(stmt, 1); }
		if(ret_verified) { *ret_verified = (sqlite3_column_int(stmt, 2)==MR_CHAT_TYPE_VERIFIED_GROUP); }
	}

cleanup:
	return chat_id;
}


/**
 * Create a normal chat with a single user.  To create group chats,
 * see mrmailbox_create_group_chat().
 *
 * If there is already an exitant chat, this ID is returned and no new chat is
 * crated.  If there is no existant chat with the user, a new chat is created;
 * this new chat may already contain messages, eg. from the deaddrop, to get the
 * chat messages, use mrmailbox_get_chat_msgs().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param contact_id The contact ID to create the chat for.  If there is already
 *     a chat with this contact, the already existing ID is returned.
 *
 * @return The created or reused chat ID on success. 0 on errors.
 */
uint32_t mrmailbox_create_chat_by_contact_id(mrmailbox_t* mailbox, uint32_t contact_id)
{
	uint32_t      chat_id = 0;
	int           chat_blocked = 0;
	int           send_event = 0, locked = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return 0;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		mrmailbox_lookup_real_nchat_by_contact_id__(mailbox, contact_id, &chat_id, &chat_blocked);
		if( chat_id ) {
			if( chat_blocked ) {
				mrmailbox_unblock_chat__(mailbox, chat_id); /* unblock chat (typically move it from the deaddrop to view) */
				send_event = 1;
			}
			goto cleanup; /* success */
		}

        if( 0==mrmailbox_real_contact_exists__(mailbox, contact_id) && contact_id!=MR_CONTACT_ID_SELF ) {
			mrmailbox_log_warning(mailbox, 0, "Cannot create chat, contact %i does not exist.", (int)contact_id);
			goto cleanup;
        }

		mrmailbox_create_or_lookup_nchat_by_contact_id__(mailbox, contact_id, MR_CHAT_NOT_BLOCKED, &chat_id, NULL);
		if( chat_id ) {
			send_event = 1;
		}

		mrmailbox_scaleup_contact_origin__(mailbox, contact_id, MR_ORIGIN_CREATE_CHAT);

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }

	if( send_event ) {
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0);
	}

	return chat_id;
}


/**
 * Create a normal chat or a group chat by a messages ID that comes typically
 * from the deaddrop, MR_CHAT_ID_DEADDROP (1).
 *
 * If the given message ID already belongs to a normal chat or to a group chat,
 * the chat ID of this chat is returned and no new chat is created.
 * If a new chat is created, the given message ID is moved to this chat, however,
 * there may be more messages moved to the chat from the deaddrop. To get the
 * chat messages, use mrmailbox_get_chat_msgs().
 *
 * If the user should be start asked the chat is created, he should just be
 * asked whether he wants to chat with the _contact_ belonging to the message;
 * the group names may be really weired when take from the subject of implicit
 * groups and this may look confusing.
 *
 * Moreover, this function also scales up the origin of the contact belonging
 * to the message and, depending on the contacts origin, messages from the
 * same group may be shown or not - so, all in all, it is fine to show the
 * contact name only.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param msg_id The message ID to create the chat for.
 *
 * @return The created or reused chat ID on success. 0 on errors.
 */
uint32_t mrmailbox_create_chat_by_msg_id(mrmailbox_t* mailbox, uint32_t msg_id)
{
	int       locked     = 0;
	uint32_t  chat_id    = 0;
	int       send_event = 0;
	mrmsg_t*  msg        = mrmsg_new();
	mrchat_t* chat       = mrchat_new(mailbox);

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( !mrmsg_load_from_db__(msg, mailbox, msg_id)
		 || !mrchat_load_from_db__(chat, msg->m_chat_id)
		 || chat->m_id <= MR_CHAT_ID_LAST_SPECIAL ) {
			goto cleanup;
		}

		chat_id = chat->m_id;

		if( chat->m_blocked ) {
			mrmailbox_unblock_chat__(mailbox, chat->m_id);
			send_event = 1;
		}

		mrmailbox_scaleup_contact_origin__(mailbox, msg->m_from_id, MR_ORIGIN_CREATE_CHAT);

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrmsg_unref(msg);
	mrchat_unref(chat);
	if( send_event ) {
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0);
	}
	return chat_id;
}


static mrarray_t* mrmailbox_get_chat_media__(mrmailbox_t* mailbox, uint32_t chat_id, int msg_type, int or_msg_type)
{
	mrarray_t* ret = mrarray_new(mailbox, 100);

	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_WHERE_ctt,
		"SELECT id FROM msgs WHERE chat_id=? AND (type=? OR type=?) ORDER BY timestamp, id;");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, msg_type);
	sqlite3_bind_int(stmt, 3, or_msg_type>0? or_msg_type : msg_type);
	while( sqlite3_step(stmt) == SQLITE_ROW ) {
		mrarray_add_id(ret, sqlite3_column_int(stmt, 0));
	}

	return ret;
}


/**
 * Returns all message IDs of the given types in a chat.  Typically used to show
 * a gallery.  The result must be mrarray_unref()'d
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The chat ID to get all messages with media from.
 *
 * @param msg_type Specify a message type to query here, one of the MR_MSG_* constats.
 *
 * @param or_msg_type Another message type to return, one of the MR_MSG_* constats.
 *     The function will return both types then.  0 if you need only one.
 *
 * @return An array with messages from the given chat ID that have the wanted message types.
 */
mrarray_t* mrmailbox_get_chat_media(mrmailbox_t* mailbox, uint32_t chat_id, int msg_type, int or_msg_type)
{
	mrarray_t* ret = NULL;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return NULL;
	}

	mrsqlite3_lock(mailbox->m_sql);

		ret = mrmailbox_get_chat_media__(mailbox, chat_id, msg_type, or_msg_type);

	mrsqlite3_unlock(mailbox->m_sql);

	return ret;
}


/**
 * Get next/previous message of the same type.
 * Typically used to implement the "next" and "previous" buttons on a media
 * player playing eg. voice messages.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param curr_msg_id  This is the current (image) message displayed.
 *
 * @param dir 1=get the next (image) message, -1=get the previous one.
 *
 * @return Returns the message ID that should be played next. The
 *     returned message is in the same chat as the given one and has the same type.
 *     Typically, this result is passed again to mrmailbox_get_next_media()
 *     later on the next swipe. If there is not next/previous message, the function returns 0.
 */
uint32_t mrmailbox_get_next_media(mrmailbox_t* mailbox, uint32_t curr_msg_id, int dir)
{
	uint32_t ret_msg_id = 0;
	mrmsg_t* msg = mrmsg_new();
	int      locked = 0;
	mrarray_t* list = NULL;
	int      i, cnt;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( !mrmsg_load_from_db__(msg, mailbox, curr_msg_id) ) {
			goto cleanup;
		}

		if( (list=mrmailbox_get_chat_media__(mailbox, msg->m_chat_id, msg->m_type, 0))==NULL ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	cnt = mrarray_get_cnt(list);
	for( i = 0; i < cnt; i++ ) {
		if( curr_msg_id == mrarray_get_id(list, i) )
		{
			if( dir > 0 ) {
				/* get the next message from the current position */
				if( i+1 < cnt ) {
					ret_msg_id = mrarray_get_id(list, i+1);
				}
			}
			else if( dir < 0 ) {
				/* get the previous message from the current position */
				if( i-1 >= 0 ) {
					ret_msg_id = mrarray_get_id(list, i-1);
				}
			}
			break;
		}
	}


cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrarray_unref(list);
	mrmsg_unref(msg);
	return ret_msg_id;
}


/**
 * Get contact IDs belonging to a chat.
 *
 * - for normal chats, the function always returns exactly one contact,
 *   MR_CONTACT_ID_SELF is _not_ returned.
 *
 * - for group chats all members are returned, MR_CONTACT_ID_SELF is returned
 *   explicitly as it may happen that oneself gets removed from a still existing
 *   group
 *
 * - for the deaddrop, all contacts are returned, MR_CONTACT_ID_SELF is not
 *   added
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 * @param chat_id Chat ID to get the belonging contact IDs for.
 *
 * @return an array of contact IDs belonging to the chat; must be freed using mrarray_unref() when done.
 */
mrarray_t* mrmailbox_get_chat_contacts(mrmailbox_t* mailbox, uint32_t chat_id)
{
	/* Normal chats do not include SELF.  Group chats do (as it may happen that one is deleted from a
	groupchat but the chats stays visible, moreover, this makes displaying lists easier) */
	int           locked = 0;
	mrarray_t*    ret = mrarray_new(mailbox, 100);
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	if( chat_id == MR_CHAT_ID_DEADDROP ) {
		goto cleanup; /* we could also create a list for all contacts in the deaddrop by searching contacts belonging to chats with chats.blocked=2, however, currently this is not needed */
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_contact_id_FROM_chats_contacts_WHERE_chat_id_ORDER_BY,
			"SELECT cc.contact_id FROM chats_contacts cc"
				" LEFT JOIN contacts c ON c.id=cc.contact_id"
				" WHERE cc.chat_id=?"
				" ORDER BY c.id=1, LOWER(c.name||c.addr), c.id;");
		sqlite3_bind_int(stmt, 1, chat_id);

		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			mrarray_add_id(ret, sqlite3_column_int(stmt, 0));
		}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	return ret;
}


/**
 * Returns the message IDs of all _fresh_ messages of any chat. Typically used for implementing
 * notification summaries.  The result must be free()'d.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 */
mrarray_t* mrmailbox_get_fresh_msgs(mrmailbox_t* mailbox)
{
	int           show_deaddrop, success = 0, locked = 0;
	mrarray_t*    ret = mrarray_new(mailbox, 128);
	sqlite3_stmt* stmt = NULL;

	if( mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || ret == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		show_deaddrop = 0;//mrsqlite3_get_config_int__(mailbox->m_sql, "show_deaddrop", 0);

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_LEFT_JOIN_contacts_WHERE_fresh,
			"SELECT m.id"
				" FROM msgs m"
				" LEFT JOIN contacts ct ON m.from_id=ct.id"
				" LEFT JOIN chats c ON m.chat_id=c.id"
				" WHERE m.state=" MR_STRINGIFY(MR_STATE_IN_FRESH) " AND ct.blocked=0 AND (c.blocked=0 OR c.blocked=?)"
				" ORDER BY m.timestamp DESC,m.id DESC;"); /* the list starts with the newest messages*/
		sqlite3_bind_int(stmt, 1, show_deaddrop? MR_CHAT_DEADDROP_BLOCKED : 0);

		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			mrarray_add_id(ret, sqlite3_column_int(stmt, 0));
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }

	if( success ) {
		return ret;
	}
	else {
		if( ret ) {
			mrarray_unref(ret);
		}
		return NULL;
	}
}


/**
 * Get all message IDs belonging to a chat.
 * Optionally, some special markers added to the ID-array may help to
 * implement virtual lists.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The chat ID of which the messages IDs should be queried.
 *
 * @param flags If set to MR_GCM_ADD_DAY_MARKER, the marker MR_MSG_ID_DAYMARKER will
 *     be added before each day (regarding the local timezone).  Set this to 0 if you do not want this behaviour.
 *
 * @param marker1before An optional message ID.  If set, the id MR_MSG_ID_MARKER1 will be added just
 *   before the given ID in the returned array.  Set this to 0 if you do not want this behaviour.
 *
 * @return Array of message IDs, must be mrarray_unref()'d when no longer used.
 */
mrarray_t* mrmailbox_get_chat_msgs(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t flags, uint32_t marker1before)
{
	clock_t       start = clock();

	int           success = 0, locked = 0;
	mrarray_t*    ret = mrarray_new(mailbox, 512);
	sqlite3_stmt* stmt = NULL;

	uint32_t      curr_id;
	time_t        curr_local_timestamp;
	int           curr_day, last_day = 0;
	long          cnv_to_local = mr_gm2local_offset();
	#define       SECONDS_PER_DAY 86400

	if( mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || ret == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( chat_id == MR_CHAT_ID_DEADDROP )
		{
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_LEFT_JOIN_chats_contacts_WHERE_blocked,
				"SELECT m.id, m.timestamp"
					" FROM msgs m"
					" LEFT JOIN chats ON m.chat_id=chats.id"
					" LEFT JOIN contacts ON m.from_id=contacts.id"
					" WHERE m.from_id!=" MR_STRINGIFY(MR_CONTACT_ID_SELF)
					"   AND m.hidden=0 "
					"   AND chats.blocked=" MR_STRINGIFY(MR_CHAT_DEADDROP_BLOCKED)
					"   AND contacts.blocked=0"
					" ORDER BY m.timestamp,m.id;"); /* the list starts with the oldest message*/
		}
		else if( chat_id == MR_CHAT_ID_STARRED )
		{
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_LEFT_JOIN_contacts_WHERE_starred,
				"SELECT m.id, m.timestamp"
					" FROM msgs m"
					" LEFT JOIN contacts ct ON m.from_id=ct.id"
					" WHERE m.starred=1 "
					"   AND m.hidden=0 "
					"   AND ct.blocked=0"
					" ORDER BY m.timestamp,m.id;"); /* the list starts with the oldest message*/
		}
		else
		{
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_LEFT_JOIN_contacts_WHERE_c,
				"SELECT m.id, m.timestamp"
					" FROM msgs m"
					//" LEFT JOIN contacts ct ON m.from_id=ct.id"
					" WHERE m.chat_id=? "
					"   AND m.hidden=0 "
					//"   AND ct.blocked=0" -- we hide blocked-contacts from starred and deaddrop, but we have to show them in groups (otherwise it may be hard to follow conversation, wa and tg do the same. however, maybe this needs discussion some time :)
					" ORDER BY m.timestamp,m.id;"); /* the list starts with the oldest message*/
			sqlite3_bind_int(stmt, 1, chat_id);
		}

		while( sqlite3_step(stmt) == SQLITE_ROW )
		{
			curr_id = sqlite3_column_int(stmt, 0);

			/* add user marker */
			if( curr_id == marker1before ) {
				mrarray_add_id(ret, MR_MSG_ID_MARKER1);
			}

			/* add daymarker, if needed */
			if( flags&MR_GCM_ADDDAYMARKER ) {
				curr_local_timestamp = (time_t)sqlite3_column_int64(stmt, 1) + cnv_to_local;
				curr_day = curr_local_timestamp/SECONDS_PER_DAY;
				if( curr_day != last_day ) {
					mrarray_add_id(ret, MR_MSG_ID_DAYMARKER);
					last_day = curr_day;
				}
			}

			mrarray_add_id(ret, curr_id);
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }

	mrmailbox_log_info(mailbox, 0, "Message list for chat #%i created in %.3f ms.", chat_id, (double)(clock()-start)*1000.0/CLOCKS_PER_SEC);

	if( success ) {
		return ret;
	}
	else {
		if( ret ) {
			mrarray_unref(ret);
		}
		return NULL;
	}
}


/**
 * Search messages containing the given query string.
 * Searching can be done globally (chat_id=0) or in a specified chat only (chat_id
 * set).
 *
 * Global chat results are typically displayed using mrmsg_get_summary(), chat
 * search results may just hilite the corresponding messages and present a
 * prev/next button.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id ID of the chat to search messages in.
 *     Set this to 0 for a global search.
 *
 * @param query The query to search for.
 *
 * @return An array of message IDs. Must be freed using mrarray_unref() when no longer needed.
 *     If nothing can be found, the function returns NULL.
 */
mrarray_t* mrmailbox_search_msgs(mrmailbox_t* mailbox, uint32_t chat_id, const char* query)
{
	clock_t       start = clock();

	int           success = 0, locked = 0;
	mrarray_t*    ret = mrarray_new(mailbox, 100);
	char*         strLikeInText = NULL, *strLikeBeg=NULL, *real_query = NULL;
	sqlite3_stmt* stmt = NULL;

	if( mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || ret == NULL || query == NULL ) {
		goto cleanup;
	}

	real_query = safe_strdup(query);
	mr_trim(real_query);
	if( real_query[0]==0 ) {
		success = 1; /*empty result*/
		goto cleanup;
	}

	strLikeInText = mr_mprintf("%%%s%%", real_query);
	strLikeBeg = mr_mprintf("%s%%", real_query); /*for the name search, we use "Name%" which is fast as it can use the index ("%Name%" could not). */

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		/* Incremental search with "LIKE %query%" cannot take advantages from any index
		("query%" could for COLLATE NOCASE indexes, see http://www.sqlite.org/optoverview.html#like_opt )
		An alternative may be the FULLTEXT sqlite stuff, however, this does not really help with incremental search.
		An extra table with all words and a COLLATE NOCASE indexes may help, however,
		this must be updated all the time and probably consumes more time than we can save in tenthousands of searches.
		For now, we just expect the following query to be fast enough :-) */
		if( chat_id ) {
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_WHERE_chat_id_AND_query,
				"SELECT m.id, m.timestamp FROM msgs m"
				" LEFT JOIN contacts ct ON m.from_id=ct.id"
				" WHERE m.chat_id=? "
					" AND m.hidden=0 "
					" AND ct.blocked=0 AND (txt LIKE ? OR ct.name LIKE ?)"
				" ORDER BY m.timestamp,m.id;"); /* chats starts with the oldest message*/
			sqlite3_bind_int (stmt, 1, chat_id);
			sqlite3_bind_text(stmt, 2, strLikeInText, -1, SQLITE_STATIC);
			sqlite3_bind_text(stmt, 3, strLikeBeg, -1, SQLITE_STATIC);
		}
		else {
			int show_deaddrop = 0;//mrsqlite3_get_config_int__(mailbox->m_sql, "show_deaddrop", 0);
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_i_FROM_msgs_WHERE_query,
				"SELECT m.id, m.timestamp FROM msgs m"
				" LEFT JOIN contacts ct ON m.from_id=ct.id"
				" LEFT JOIN chats c ON m.chat_id=c.id"
				" WHERE m.chat_id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL)
					" AND m.hidden=0 "
					" AND (c.blocked=0 OR c.blocked=?)"
					" AND ct.blocked=0 AND (m.txt LIKE ? OR ct.name LIKE ?)"
				" ORDER BY m.timestamp DESC,m.id DESC;"); /* chat overview starts with the newest message*/
			sqlite3_bind_int (stmt, 1, show_deaddrop? MR_CHAT_DEADDROP_BLOCKED : 0);
			sqlite3_bind_text(stmt, 2, strLikeInText, -1, SQLITE_STATIC);
			sqlite3_bind_text(stmt, 3, strLikeBeg, -1, SQLITE_STATIC);
		}

		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			mrarray_add_id(ret, sqlite3_column_int(stmt, 0));
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	free(strLikeInText);
	free(strLikeBeg);
	free(real_query);

	mrmailbox_log_info(mailbox, 0, "Message list for search \"%s\" in chat #%i created in %.3f ms.", query, chat_id, (double)(clock()-start)*1000.0/CLOCKS_PER_SEC);


	if( success ) {
		return ret;
	}
	else {
		if( ret ) {
			mrarray_unref(ret);
		}
		return NULL;
	}
}


static void set_draft_int(mrmailbox_t* mailbox, mrchat_t* chat, uint32_t chat_id, const char* msg)
{
	sqlite3_stmt* stmt;
	mrchat_t*     chat_to_delete = NULL;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	if( chat==NULL ) {
		if( (chat=mrmailbox_get_chat(mailbox, chat_id)) == NULL ) {
			goto cleanup;
		}
		chat_to_delete = chat;
	}

	if( msg && msg[0]==0 ) {
		msg = NULL; /* an empty draft is no draft */
	}

	if( chat->m_draft_text==NULL && msg==NULL
	 && chat->m_draft_timestamp==0 ) {
		goto cleanup; /* nothing to do - there is no old and no new draft */
	}

	if( chat->m_draft_timestamp && chat->m_draft_text && msg && strcmp(chat->m_draft_text, msg)==0 ) {
		goto cleanup; /* for equal texts, we do not update the timestamp */
	}

	/* save draft in object - NULL or empty: clear draft */
	free(chat->m_draft_text);
	chat->m_draft_text      = msg? safe_strdup(msg) : NULL;
	chat->m_draft_timestamp = msg? time(NULL) : 0;

	/* save draft in database */
	mrsqlite3_lock(mailbox->m_sql);

		stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_chats_SET_draft_WHERE_id,
			"UPDATE chats SET draft_timestamp=?, draft_txt=? WHERE id=?;");
		sqlite3_bind_int64(stmt, 1, chat->m_draft_timestamp);
		sqlite3_bind_text (stmt, 2, chat->m_draft_text? chat->m_draft_text : "", -1, SQLITE_STATIC); /* SQLITE_STATIC: we promise the buffer to be valid until the query is done */
		sqlite3_bind_int  (stmt, 3, chat->m_id);

		sqlite3_step(stmt);

	mrsqlite3_unlock(mailbox->m_sql);

	mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0);

cleanup:
	mrchat_unref(chat_to_delete);
}


/**
 * Save a draft for a chat.
 *
 * To get the draft for a given chat ID, use mrchat_t::m_draft_text
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The chat ID to save the draft for.
 *
 * @param msg The message text to save as a draft.
 *
 * @return None.
 */
void mrmailbox_set_draft(mrmailbox_t* mailbox, uint32_t chat_id, const char* msg)
{
	set_draft_int(mailbox, NULL, chat_id, msg);
}


int mrchat_set_draft(mrchat_t* chat, const char* msg) /* deprecated */
{
	set_draft_int(chat->m_mailbox, chat, chat->m_id, msg);
	return 1;
}


int mrmailbox_get_fresh_msg_count__(mrmailbox_t* mailbox, uint32_t chat_id)
{
	sqlite3_stmt* stmt = NULL;

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_state_AND_chat_id,
		"SELECT COUNT(*) FROM msgs "
		" WHERE state=" MR_STRINGIFY(MR_STATE_IN_FRESH)
		"   AND hidden=0 "
		"   AND chat_id=?;"); /* we have an index over the state-column, this should be sufficient as there are typically only few fresh messages */
	sqlite3_bind_int(stmt, 1, chat_id);

	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


uint32_t mrmailbox_get_last_deaddrop_fresh_msg__(mrmailbox_t* mailbox)
{
	sqlite3_stmt* stmt = NULL;

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_msgs_WHERE_fresh_AND_deaddrop,
		"SELECT m.id "
		" FROM msgs m "
		" LEFT JOIN chats c ON c.id=m.chat_id "
		" WHERE m.state=" MR_STRINGIFY(MR_STATE_IN_FRESH)
		"   AND m.hidden=0 "
		"   AND c.blocked=" MR_STRINGIFY(MR_CHAT_DEADDROP_BLOCKED)
		" ORDER BY m.timestamp DESC, m.id DESC;"); /* we have an index over the state-column, this should be sufficient as there are typically only few fresh messages */

	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


int mrmailbox_get_total_msg_count__(mrmailbox_t* mailbox, uint32_t chat_id)
{
	sqlite3_stmt* stmt = NULL;

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_chat_id,
		"SELECT COUNT(*) FROM msgs WHERE chat_id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);

	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


size_t mrmailbox_get_chat_cnt__(mrmailbox_t* mailbox)
{
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || mailbox->m_sql->m_cobj==NULL ) {
		return 0; /* no database, no chats - this is no error (needed eg. for information) */
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_chats,
		"SELECT COUNT(*) FROM chats WHERE id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL) " AND blocked=0;");
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


void mrmailbox_lookup_real_nchat_by_contact_id__(mrmailbox_t* mailbox, uint32_t contact_id, uint32_t* ret_chat_id, int* ret_chat_blocked)
{
	/* checks for "real" chats or self-chat */
	sqlite3_stmt* stmt;

	if( ret_chat_id )      { *ret_chat_id = 0;      }
	if( ret_chat_blocked ) { *ret_chat_blocked = 0; }

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || mailbox->m_sql->m_cobj==NULL ) {
		return; /* no database, no chats - this is no error (needed eg. for information) */
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_chats_WHERE_contact_id,
			"SELECT c.id, c.blocked"
			" FROM chats c"
			" INNER JOIN chats_contacts j ON c.id=j.chat_id"
			" WHERE c.type=" MR_STRINGIFY(MR_CHAT_TYPE_SINGLE) " AND c.id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL) " AND j.contact_id=?;");
	sqlite3_bind_int(stmt, 1, contact_id);

	if( sqlite3_step(stmt) == SQLITE_ROW ) {
		if( ret_chat_id )      { *ret_chat_id      = sqlite3_column_int(stmt, 0); }
		if( ret_chat_blocked ) { *ret_chat_blocked = sqlite3_column_int(stmt, 1); }
	}
}


void mrmailbox_create_or_lookup_nchat_by_contact_id__(mrmailbox_t* mailbox, uint32_t contact_id, int create_blocked, uint32_t* ret_chat_id, int* ret_chat_blocked)
{
	uint32_t      chat_id = 0;
	int           chat_blocked = 0;
	mrcontact_t*  contact = NULL;
	char*         chat_name;
	char*         q = NULL;
	sqlite3_stmt* stmt = NULL;

	if( ret_chat_id )      { *ret_chat_id = 0;      }
	if( ret_chat_blocked ) { *ret_chat_blocked = 0; }

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || mailbox->m_sql->m_cobj==NULL ) {
		return; /* database not opened - error */
	}

	if( contact_id == 0 ) {
		return;
	}

	mrmailbox_lookup_real_nchat_by_contact_id__(mailbox, contact_id, &chat_id, &chat_blocked);
	if( chat_id != 0 ) {
		if( ret_chat_id )      { *ret_chat_id      = chat_id;      }
		if( ret_chat_blocked ) { *ret_chat_blocked = chat_blocked; }
		return; /* soon success */
	}

	/* get fine chat name */
	contact = mrcontact_new(mailbox);
	if( !mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id) ) {
		goto cleanup;
	}

	chat_name = (contact->m_name&&contact->m_name[0])? contact->m_name : contact->m_addr;

	/* create chat record */
	q = sqlite3_mprintf("INSERT INTO chats (type, name, param, blocked) VALUES(%i, %Q, %Q, %i)", MR_CHAT_TYPE_SINGLE, chat_name,
		contact_id==MR_CONTACT_ID_SELF? "K=1" : "", create_blocked);
	assert( MRP_SELFTALK == 'K' );
	stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, q);
	if( stmt == NULL) {
		goto cleanup;
	}

    if( sqlite3_step(stmt) != SQLITE_DONE ) {
		goto cleanup;
    }

    chat_id = sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj);

	sqlite3_free(q);
	q = NULL;
	sqlite3_finalize(stmt);
	stmt = NULL;

	/* add contact IDs to the new chat record (may be replaced by mrmailbox_add_to_chat_contacts_table__()) */
	q = sqlite3_mprintf("INSERT INTO chats_contacts (chat_id, contact_id) VALUES(%i, %i)", chat_id, contact_id);
	stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, q);

	if( sqlite3_step(stmt) != SQLITE_DONE ) {
		goto cleanup;
	}

	sqlite3_free(q);
	q = NULL;
	sqlite3_finalize(stmt);
	stmt = NULL;

cleanup:
	if( q )       { sqlite3_free(q); }
	if( stmt )    { sqlite3_finalize(stmt); }
	if( contact ) { mrcontact_unref(contact); }

	if( ret_chat_id )      { *ret_chat_id      = chat_id; }
	if( ret_chat_blocked ) { *ret_chat_blocked = create_blocked; }
}


void mrmailbox_unarchive_chat__(mrmailbox_t* mailbox, uint32_t chat_id)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_chats_SET_unarchived, "UPDATE chats SET archived=0 WHERE id=?");
	sqlite3_bind_int (stmt, 1, chat_id);
	sqlite3_step(stmt);
}



/**
 * Get the total number of messages in a chat.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The ID of the chat to count the messages for.
 *
 * @return Number of total messages in the given chat. 0 for errors or empty chats.
 */
int mrmailbox_get_total_msg_count(mrmailbox_t* mailbox, uint32_t chat_id)
{
	int ret;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return 0;
	}

	mrsqlite3_lock(mailbox->m_sql);
		ret = mrmailbox_get_total_msg_count__(mailbox, chat_id);
	mrsqlite3_unlock(mailbox->m_sql);

	return ret;
}


/**
 * Get the number of _fresh_ messages in a chat.  Typically used to implement
 * a badge with a number in the chatlist.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The ID of the chat to count the messages for.
 *
 * @return Number of fresh messages in the given chat. 0 for errors or if there are no fresh messages.
 */
int mrmailbox_get_fresh_msg_count(mrmailbox_t* mailbox, uint32_t chat_id)
{
	int ret;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return 0;
	}

	mrsqlite3_lock(mailbox->m_sql);
		ret = mrmailbox_get_fresh_msg_count__(mailbox, chat_id);
	mrsqlite3_unlock(mailbox->m_sql);

	return ret;
}


/**
 * Archive or unarchive a chat.
 *
 * Archived chats are not included in the default chatlist returned
 * by mrmailbox_get_chatlist().  Instead, if there are _any_ archived chats,
 * the pseudo-chat with the chat_id MR_CHAT_ID_ARCHIVED_LINK will be added the the
 * end of the chatlist.
 *
 * To get a list of archived chats, use mrmailbox_get_chatlist() with the flag MR_GCL_ARCHIVED_ONLY.
 *
 * To find out the archived state of a given chat, use mrchat_t::m_archived
 *
 * Calling this function usually results in the event #MR_EVENT_MSGS_CHANGED
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The ID of the chat to archive or unarchive.
 *
 * @param archive 1=archive chat, 0=unarchive chat, all other values are reserved for future use
 *
 * @return None
 */
void mrmailbox_archive_chat(mrmailbox_t* mailbox, uint32_t chat_id, int archive)
{
	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || chat_id <= MR_CHAT_ID_LAST_SPECIAL || (archive!=0 && archive!=1) ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);
		sqlite3_stmt* stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "UPDATE chats SET archived=? WHERE id=?;");
		sqlite3_bind_int  (stmt, 1, archive);
		sqlite3_bind_int  (stmt, 2, chat_id);
		sqlite3_step(stmt);
		sqlite3_finalize(stmt);
	mrsqlite3_unlock(mailbox->m_sql);

	mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0);
}


/*******************************************************************************
 * Delete a chat
 ******************************************************************************/


/**
 * Delete a chat.
 *
 * Messages are deleted from the device and the chat database entry is deleted.
 * After that, the event #MR_EVENT_MSGS_CHANGED is posted.
 *
 * Things that are _not_ done implicitly:
 *
 * - Messages are **not deleted from the server**.
 *
 * - The chat or the contact is **not blocked**, so new messages from the user/the group may appear
 *   and the user may create the chat again.
 *
 * - **Groups are not left** - this would
 *   be unexpected as (1) deleting a normal chat also does not prevent new mails
 *   from arriving, (2) leaving a group requires sending a message to
 *   all group members - esp. for groups not used for a longer time, this is
 *   really unexpected when deletion results in contacting all members again,
 *   (3) only leaving groups is also a valid usecase.
 *
 * To leave a chat explicitly, use mrmailbox_remove_contact_from_chat() with
 * chat_id=MR_CONTACT_ID_SELF)
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id The ID of the chat to delete.
 *
 * @return None
 */
void mrmailbox_delete_chat(mrmailbox_t* mailbox, uint32_t chat_id)
{
	/* Up to 2017-11-02 deleting a group also implied leaving it, see above why we have changed this. */
	int       locked = 0, pending_transaction = 0;
	mrchat_t* obj = mrchat_new(mailbox);
	char*     q3 = NULL;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

        if( !mrchat_load_from_db__(obj, chat_id) ) {
			goto cleanup;
        }

		mrsqlite3_begin_transaction__(mailbox->m_sql);
		pending_transaction = 1;

			q3 = sqlite3_mprintf("DELETE FROM msgs_mdns WHERE msg_id IN (SELECT msg_id FROM msgs WHERE chat_id=%i);", chat_id);
			if( !mrsqlite3_execute__(mailbox->m_sql, q3) ) {
				goto cleanup;
			}
			sqlite3_free(q3);
			q3 = NULL;

			q3 = sqlite3_mprintf("DELETE FROM msgs WHERE chat_id=%i;", chat_id);
			if( !mrsqlite3_execute__(mailbox->m_sql, q3) ) {
				goto cleanup;
			}
			sqlite3_free(q3);
			q3 = NULL;

			q3 = sqlite3_mprintf("DELETE FROM chats_contacts WHERE chat_id=%i;", chat_id);
			if( !mrsqlite3_execute__(mailbox->m_sql, q3) ) {
				goto cleanup;
			}
			sqlite3_free(q3);
			q3 = NULL;

			q3 = sqlite3_mprintf("DELETE FROM chats WHERE id=%i;", chat_id);
			if( !mrsqlite3_execute__(mailbox->m_sql, q3) ) {
				goto cleanup;
			}
			sqlite3_free(q3);
			q3 = NULL;

		mrsqlite3_commit__(mailbox->m_sql);
		pending_transaction = 0;

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0);

cleanup:
	if( pending_transaction ) { mrsqlite3_rollback__(mailbox->m_sql); }
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrchat_unref(obj);
	if( q3 ) { sqlite3_free(q3); }
}


/*******************************************************************************
 * Sending messages
 ******************************************************************************/


void mrmailbox_send_msg_to_imap(mrmailbox_t* mailbox, mrjob_t* job)
{
	mrmimefactory_t  mimefactory;
	char*            server_folder = NULL;
	uint32_t         server_uid = 0;

	mrmimefactory_init(&mimefactory, mailbox);

	/* connect to IMAP-server */
	if( !mrimap_is_connected(mailbox->m_imap) ) {
		mrmailbox_connect_to_imap(mailbox, NULL);
		if( !mrimap_is_connected(mailbox->m_imap) ) {
			mrjob_try_again_later(job, MR_STANDARD_DELAY);
			goto cleanup;
		}
	}

	/* create message */
	if( mrmimefactory_load_msg(&mimefactory, job->m_foreign_id)==0
	 || mimefactory.m_from_addr == NULL ) {
		goto cleanup; /* should not happen as we've sent the message to the SMTP server before */
	}

	if( !mrmimefactory_render(&mimefactory) ) {
		goto cleanup; /* should not happen as we've sent the message to the SMTP server before */
	}

	if( !mrimap_append_msg(mailbox->m_imap, mimefactory.m_msg->m_timestamp, mimefactory.m_out->str, mimefactory.m_out->len, &server_folder, &server_uid) ) {
		mrjob_try_again_later(job, MR_STANDARD_DELAY);
		goto cleanup;
	}
	else {
		mrsqlite3_lock(mailbox->m_sql);
			mrmailbox_update_server_uid__(mailbox, mimefactory.m_msg->m_rfc724_mid, server_folder, server_uid);
		mrsqlite3_unlock(mailbox->m_sql);
	}

cleanup:
	mrmimefactory_empty(&mimefactory);
	free(server_folder);
}


static void mark_as_error(mrmailbox_t* mailbox, mrmsg_t* msg)
{
	if( mailbox==NULL || msg==NULL ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);
		mrmailbox_update_msg_state__(mailbox, msg->m_id, MR_STATE_OUT_ERROR);
	mrsqlite3_unlock(mailbox->m_sql);
	mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, msg->m_chat_id, 0);
}


void mrmailbox_send_msg_to_smtp(mrmailbox_t* mailbox, mrjob_t* job)
{
	mrmimefactory_t mimefactory;

	mrmimefactory_init(&mimefactory, mailbox);

	/* connect to SMTP server, if not yet done */
	if( !mrsmtp_is_connected(mailbox->m_smtp) ) {
		mrloginparam_t* loginparam = mrloginparam_new();
			mrsqlite3_lock(mailbox->m_sql);
				mrloginparam_read__(loginparam, mailbox->m_sql, "configured_");
			mrsqlite3_unlock(mailbox->m_sql);
			int connected = mrsmtp_connect(mailbox->m_smtp, loginparam);
		mrloginparam_unref(loginparam);
		if( !connected ) {
			mrjob_try_again_later(job, MR_STANDARD_DELAY);
			goto cleanup;
		}
	}

	/* load message data */
	if( !mrmimefactory_load_msg(&mimefactory, job->m_foreign_id)
	 || mimefactory.m_from_addr == NULL ) {
		mrmailbox_log_warning(mailbox, 0, "Cannot load data to send, maybe the message is deleted in between.");
		goto cleanup; /* no redo, no IMAP - there won't be more recipients next time (as the data does not exist, there is no need in calling mark_as_error()) */
	}

	/* check if the message is ready (normally, only video files may be delayed this way) */
	if( mimefactory.m_increation ) {
		mrmailbox_log_info(mailbox, 0, "File is in creation, retrying later.");
		mrjob_try_again_later(job, MR_INCREATION_POLL);
		goto cleanup;
	}

	/* send message - it's okay if there are no recipients, this is a group with only OURSELF; we only upload to IMAP in this case */
	if( clist_count(mimefactory.m_recipients_addr) > 0 ) {
		if( !mrmimefactory_render(&mimefactory) ) {
			mark_as_error(mailbox, mimefactory.m_msg);
			mrmailbox_log_error(mailbox, 0, "Empty message."); /* should not happen */
			goto cleanup; /* no redo, no IMAP - there won't be more recipients next time. */
		}

		/* have we guaranteed encryption but cannot fulfill it for any reason? Do not send the message then.*/
		if( mrparam_get_int(mimefactory.m_msg->m_param, MRP_GUARANTEE_E2EE, 0) && !mimefactory.m_out_encrypted ) {
			mark_as_error(mailbox, mimefactory.m_msg);
			mrmailbox_log_error(mailbox, 0, "End-to-end-encryption unavailable unexpectedly.");
			goto cleanup; /* unrecoverable */
		}

		if( !mrsmtp_send_msg(mailbox->m_smtp, mimefactory.m_recipients_addr, mimefactory.m_out->str, mimefactory.m_out->len) ) {
			mrsmtp_disconnect(mailbox->m_smtp);
			mrjob_try_again_later(job, MR_AT_ONCE); /* MR_AT_ONCE is only the _initial_ delay, if the second try failes, the delay gets larger */
			goto cleanup;
		}
	}

	/* done */
	mrsqlite3_lock(mailbox->m_sql);
	mrsqlite3_begin_transaction__(mailbox->m_sql);

		/* debug print? */
		if( mrsqlite3_get_config_int__(mailbox->m_sql, "save_eml", 0) ) {
			char* emlname = mr_mprintf("%s/to-smtp-%i.eml", mailbox->m_blobdir, (int)mimefactory.m_msg->m_id);
			FILE* emlfileob = fopen(emlname, "w");
			if( emlfileob ) {
				if( mimefactory.m_out ) {
					fwrite(mimefactory.m_out->str, 1, mimefactory.m_out->len, emlfileob);
				}
				fclose(emlfileob);
			}
			free(emlname);
		}

		mrmailbox_update_msg_state__(mailbox, mimefactory.m_msg->m_id, MR_STATE_OUT_DELIVERED);
		if( mimefactory.m_out_encrypted && mrparam_get_int(mimefactory.m_msg->m_param, MRP_GUARANTEE_E2EE, 0)==0 ) {
			mrparam_set_int(mimefactory.m_msg->m_param, MRP_GUARANTEE_E2EE, 1); /* can upgrade to E2EE - fine! */
			mrmsg_save_param_to_disk__(mimefactory.m_msg);
		}

		if( (mailbox->m_imap->m_server_flags&MR_NO_EXTRA_IMAP_UPLOAD)==0
		 && mrparam_get(mimefactory.m_chat->m_param, MRP_SELFTALK, 0)==0
		 && mrparam_get_int(mimefactory.m_msg->m_param, MRP_CMD, 0)!=MR_CMD_SECUREJOIN_MESSAGE ) {
			mrjob_add__(mailbox, MRJ_SEND_MSG_TO_IMAP, mimefactory.m_msg->m_id, NULL, 0); /* send message to IMAP in another job */
		}

		// TODO: add to keyhistory
		mrmailbox_add_to_keyhistory__(mailbox, NULL, 0, NULL, NULL);

	mrsqlite3_commit__(mailbox->m_sql);
	mrsqlite3_unlock(mailbox->m_sql);

	mailbox->m_cb(mailbox, MR_EVENT_MSG_DELIVERED, mimefactory.m_msg->m_chat_id, mimefactory.m_msg->m_id);

cleanup:
	mrmimefactory_empty(&mimefactory);
}


static int last_msg_in_chat_encrypted(mrsqlite3_t* sql, uint32_t chat_id)
{
	int last_is_encrypted = 0;
	sqlite3_stmt* stmt = mrsqlite3_predefine__(sql, SELECT_param_FROM_msgs,
		"SELECT param "
		" FROM msgs "
		" WHERE timestamp=(SELECT MAX(timestamp) FROM msgs WHERE chat_id=?) "
		" ORDER BY id DESC;");
	sqlite3_bind_int(stmt, 1, chat_id);
	if( sqlite3_step(stmt) == SQLITE_ROW ) {
		mrparam_t* msg_param = mrparam_new();
		mrparam_set_packed(msg_param, (char*)sqlite3_column_text(stmt, 0));
		if( mrparam_exists(msg_param, MRP_GUARANTEE_E2EE) ) {
			last_is_encrypted = 1;
		}
		mrparam_unref(msg_param);
	}
	return last_is_encrypted;
}


static uint32_t mrmailbox_send_msg_i__(mrmailbox_t* mailbox, mrchat_t* chat, const mrmsg_t* msg, time_t timestamp)
{
	char*         rfc724_mid = NULL;
	sqlite3_stmt* stmt;
	uint32_t      msg_id = 0, to_id = 0;

	if( !MR_CHAT_TYPE_CAN_SEND(chat->m_type) ) {
		mrmailbox_log_error(mailbox, 0, "Cannot send to chat type #%i.", chat->m_type);
		goto cleanup;
	}

	if( MR_CHAT_TYPE_IS_MULTI(chat->m_type) && !mrmailbox_is_contact_in_chat__(mailbox, chat->m_id, MR_CONTACT_ID_SELF) ) {
		mrmailbox_log_error(mailbox, MR_ERR_SELF_NOT_IN_GROUP, NULL);
		goto cleanup;
	}

	{
		char* from = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", NULL);
		if( from == NULL ) {
			mrmailbox_log_error(mailbox, 0, "Cannot send message, not configured successfully.");
			goto cleanup;
		}
		rfc724_mid = mr_create_outgoing_rfc724_mid(MR_CHAT_TYPE_IS_MULTI(chat->m_type)? chat->m_grpid : NULL, from);
		free(from);
	}

	if( chat->m_type == MR_CHAT_TYPE_SINGLE )
	{
		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_c_FROM_chats_contacts_WHERE_c,
			"SELECT contact_id FROM chats_contacts WHERE chat_id=?;");
		sqlite3_bind_int(stmt, 1, chat->m_id);
		if( sqlite3_step(stmt) != SQLITE_ROW ) {
			mrmailbox_log_error(mailbox, 0, "Cannot send message, contact for chat #%i not found.", chat->m_id);
			goto cleanup;
		}
		to_id = sqlite3_column_int(stmt, 0);
	}
	else if( MR_CHAT_TYPE_IS_MULTI(chat->m_type) )
	{
		if( mrparam_get_int(chat->m_param, MRP_UNPROMOTED, 0)==1 ) {
			/* mark group as being no longer unpromoted */
			mrparam_set(chat->m_param, MRP_UNPROMOTED, NULL);
			mrchat_update_param__(chat);
		}
	}

	/* check if we can guarantee E2EE for this message.  If we can, we won't send the message without E2EE later (because of a reset, changed settings etc. - messages may be delayed significally if there is no network present) */
	int do_guarantee_e2ee = 0;
	if( mailbox->m_e2ee_enabled && mrparam_get_int(msg->m_param, MRP_FORCE_PLAINTEXT, 0)==0 )
	{
		int can_encrypt = 1, all_mutual = 1; /* be optimistic */
		sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_p_FROM_chats_contacs_JOIN_contacts_peerstates_WHERE_cc,
			"SELECT ps.prefer_encrypted "
			 " FROM chats_contacts cc "
			 " LEFT JOIN contacts c ON cc.contact_id=c.id "
			 " LEFT JOIN acpeerstates ps ON c.addr=ps.addr "
			 " WHERE cc.chat_id=? "                                               /* take care that this statement returns NULL rows if there is no peerstates for a chat member! */
			 " AND cc.contact_id>" MR_STRINGIFY(MR_CONTACT_ID_LAST_SPECIAL) ";"); /* for MRP_SELFTALK this statement does not return any row */
		sqlite3_bind_int(stmt, 1, chat->m_id);
		while( sqlite3_step(stmt) == SQLITE_ROW )
		{
			if( sqlite3_column_type(stmt, 0)==SQLITE_NULL ) {
				can_encrypt = 0;
				all_mutual = 0;
			}
			else {
				/* the peerstate exist, so we have either public_key or gossip_key and can encrypt potentially */
				int prefer_encrypted = sqlite3_column_int(stmt, 0);
				if( prefer_encrypted != MRA_PE_MUTUAL ) {
					all_mutual = 0;
				}
			}
		}

		if( can_encrypt )
		{
			if( all_mutual ) {
				do_guarantee_e2ee = 1;
			}
			else {
				if( last_msg_in_chat_encrypted(mailbox->m_sql, chat->m_id) ) {
					do_guarantee_e2ee = 1;
				}
			}
		}
	}

	if( do_guarantee_e2ee ) {
		mrparam_set_int(msg->m_param, MRP_GUARANTEE_E2EE, 1);
	}
	mrparam_set(msg->m_param, MRP_ERRONEOUS_E2EE, NULL); /* reset eg. on forwarding */

	/* add message to the database */
	stmt = mrsqlite3_predefine__(mailbox->m_sql, INSERT_INTO_msgs_mcftttstpb,
		"INSERT INTO msgs (rfc724_mid,chat_id,from_id,to_id, timestamp,type,state, txt,param,hidden) VALUES (?,?,?,?, ?,?,?, ?,?,?);");
	sqlite3_bind_text (stmt,  1, rfc724_mid, -1, SQLITE_STATIC);
	sqlite3_bind_int  (stmt,  2, MR_CHAT_ID_MSGS_IN_CREATION);
	sqlite3_bind_int  (stmt,  3, MR_CONTACT_ID_SELF);
	sqlite3_bind_int  (stmt,  4, to_id);
	sqlite3_bind_int64(stmt,  5, timestamp);
	sqlite3_bind_int  (stmt,  6, msg->m_type);
	sqlite3_bind_int  (stmt,  7, MR_STATE_OUT_PENDING);
	sqlite3_bind_text (stmt,  8, msg->m_text? msg->m_text : "",  -1, SQLITE_STATIC);
	sqlite3_bind_text (stmt,  9, msg->m_param->m_packed, -1, SQLITE_STATIC);
	sqlite3_bind_int  (stmt, 10, msg->m_hidden);
	if( sqlite3_step(stmt) != SQLITE_DONE ) {
		mrmailbox_log_error(mailbox, 0, "Cannot send message, cannot insert to database.", chat->m_id);
		goto cleanup;
	}

	msg_id = sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj);

	/* finalize message object on database, we set the chat ID late as we don't know it sooner */
	mrmailbox_update_msg_chat_id__(mailbox, msg_id, chat->m_id);
	mrjob_add__(mailbox, MRJ_SEND_MSG_TO_SMTP, msg_id, NULL, 0); /* resuts on an asynchronous call to mrmailbox_send_msg_to_smtp()  */

cleanup:
	free(rfc724_mid);
	return msg_id;
}


/**
 * Send a message of any type to a chat. The given message object is not unref'd
 * by the function but some fields are set up.
 *
 * Sends the event #MR_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * To send a simple text message, you can also use mrmailbox_send_text_msg()
 * which is easier to use.
 *
 * @private @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 *
 * @param chat_id Chat ID to send the message to.
 *
 * @param msg Message object to send to the chat defined by the chat ID.
 *     The function does not take ownership of the object, so you have to
 *     free it using mrmsg_unref() as usual.
 *
 * @return The ID of the message that is about being sent.
 *
 * Examples:
 *
 * ```
 * mrmsg_t* msg1 = mrmsg_new();
 *    mrmsg_set_type(msg1, MR_MSG_TEXT);
 *    mrmsg_set_text(msg1, "Hi there!");
 *    mrmailbox_send_msg(mailbox, chat_id, msg1); // send a simple text message
 * mrmsg_unref(msg1);
 *
 * mrmsg_t* msg2 = mrmsg_new();
 *    mrmsg_set_type(msg2, MR_MSG_IMAGE);
 *    mrmsg_set_file(msg2, "/path/to/image.jpg");
 *    mrmailbox_send_msg(mailbox, chat_id, msg2); // send a simple text message
 * mrmsg_unref(msg1);
 * ```
 */
uint32_t mrmailbox_send_msg_object(mrmailbox_t* mailbox, uint32_t chat_id, mrmsg_t* msg)
{
	int   locked = 0, transaction_pending = 0;
	char* pathNfilename = NULL;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || msg == NULL || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		return 0;
	}

	msg->m_id      = 0;
	msg->m_mailbox = mailbox;

	if( msg->m_type == MR_MSG_TEXT )
	{
		; /* the caller should check if the message text is empty */
	}
	else if( MR_MSG_NEEDS_ATTACHMENT(msg->m_type) )
	{
		pathNfilename = mrparam_get(msg->m_param, MRP_FILE, NULL);
		if( pathNfilename )
		{
			/* Got an attachment. Take care, the file may not be ready in this moment!
			This is useful eg. if a video should be sent and already shown as "being processed" in the chat.
			In this case, the user should create an `.increation`; when the file is deleted later on, the message is sent.
			(we do not use a state in the database as this would make eg. forwarding such messages much more complicated) */

			if( msg->m_type == MR_MSG_FILE || msg->m_type == MR_MSG_IMAGE )
			{
				/* Correct the type, take care not to correct already very special formats as GIF or VOICE.
				Typical conversions:
				- from FILE to AUDIO/VIDEO/IMAGE
				- from FILE/IMAGE to GIF */
				int   better_type = 0;
				char* better_mime = NULL;
				mrmsg_guess_msgtype_from_suffix(pathNfilename, &better_type, &better_mime);
				if( better_type ) {
					msg->m_type = better_type;
					mrparam_set(msg->m_param, MRP_MIMETYPE, better_mime);
				}
				free(better_mime);
			}

			if( (msg->m_type == MR_MSG_IMAGE || msg->m_type == MR_MSG_GIF)
			 && (mrparam_get_int(msg->m_param, MRP_WIDTH, 0)<=0 || mrparam_get_int(msg->m_param, MRP_HEIGHT, 0)<=0) ) {
				/* set width/height of images, if not yet done */
				unsigned char* buf = NULL; size_t buf_bytes; uint32_t w, h;
				if( mr_read_file(pathNfilename, (void**)&buf, &buf_bytes, msg->m_mailbox) ) {
					if( mr_get_filemeta(buf, buf_bytes, &w, &h) ) {
						mrparam_set_int(msg->m_param, MRP_WIDTH, w);
						mrparam_set_int(msg->m_param, MRP_HEIGHT, h);
					}
				}
				free(buf);
			}

			mrmailbox_log_info(mailbox, 0, "Attaching \"%s\" for message type #%i.", pathNfilename, (int)msg->m_type);

			if( msg->m_text ) { free(msg->m_text); }
			if( msg->m_type == MR_MSG_AUDIO ) {
				char* filename = mr_get_filename(pathNfilename);
				char* author = mrparam_get(msg->m_param, MRP_AUTHORNAME, "");
				char* title = mrparam_get(msg->m_param, MRP_TRACKNAME, "");
				msg->m_text = mr_mprintf("%s %s %s", filename, author, title); /* for outgoing messages, also add the mediainfo. For incoming messages, this is not needed as the filename is build from these information */
				free(filename);
				free(author);
				free(title);
			}
			else if( MR_MSG_MAKE_FILENAME_SEARCHABLE(msg->m_type) ) {
				msg->m_text = mr_get_filename(pathNfilename);
			}
			else if( MR_MSG_MAKE_SUFFIX_SEARCHABLE(msg->m_type) ) {
				msg->m_text = mr_get_filesuffix_lc(pathNfilename);
			}
		}
		else
		{
			mrmailbox_log_error(mailbox, 0, "Attachment missing for message of type #%i.", (int)msg->m_type); /* should not happen */
			goto cleanup;
		}
	}
	else
	{
		mrmailbox_log_error(mailbox, 0, "Cannot send messages of type #%i.", (int)msg->m_type); /* should not happen */
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;
	mrsqlite3_begin_transaction__(mailbox->m_sql);
	transaction_pending = 1;

		mrmailbox_unarchive_chat__(mailbox, chat_id);

		mailbox->m_smtp->m_log_connect_errors = 1;

		{
			mrchat_t* chat = mrchat_new(mailbox);
			if( mrchat_load_from_db__(chat, chat_id) ) {
				msg->m_id = mrmailbox_send_msg_i__(mailbox, chat, msg, mr_create_smeared_timestamp__());
				if( msg ->m_id == 0 ) {
					goto cleanup; /* error already logged */
				}
			}
			mrchat_unref(chat);
		}

	mrsqlite3_commit__(mailbox->m_sql);
	transaction_pending = 0;
	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, chat_id, msg->m_id);

cleanup:
	if( transaction_pending ) { mrsqlite3_rollback__(mailbox->m_sql); }
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	free(pathNfilename);
	return msg->m_id;
}


/**
 * Send a simple text message a given chat.
 *
 * Sends the event #MR_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * See also mrmailbox_send_image_msg().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 * @param chat_id Chat ID to send the text message to.
 * @param text_to_send Text to send to the chat defined by the chat ID.
 *
 * @return The ID of the message that is about being sent.
 */
uint32_t mrmailbox_send_text_msg(mrmailbox_t* mailbox, uint32_t chat_id, const char* text_to_send)
{
	mrmsg_t* msg = mrmsg_new();
	uint32_t ret = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || chat_id <= MR_CHAT_ID_LAST_SPECIAL || text_to_send == NULL ) {
		goto cleanup;
	}

	msg->m_type = MR_MSG_TEXT;
	msg->m_text = safe_strdup(text_to_send);

	ret = mrmailbox_send_msg_object(mailbox, chat_id, msg);

cleanup:
	mrmsg_unref(msg);
	return ret;
}


/**
 * Send an image to a chat.
 *
 * Sends the event #MR_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * See also mrmailbox_send_text_msg().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 * @param chat_id Chat ID to send the image to.
 * @param file Full path of the image file to send. The core may make a copy of the file.
 * @param filemime Mime type of the file to send. NULL if you don't know or don't care.
 * @param width Width in pixel of the file. 0 if you don't know or don't care.
 * @param height Width in pixel of the file. 0 if you don't know or don't care.
 *
 * @return The ID of the message that is about being sent.
 */
uint32_t mrmailbox_send_image_msg(mrmailbox_t* mailbox, uint32_t chat_id, const char* file, const char* filemime, int width, int height)
{
	mrmsg_t* msg = mrmsg_new();
	uint32_t ret = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || chat_id <= MR_CHAT_ID_LAST_SPECIAL || file == NULL ) {
		goto cleanup;
	}

	msg->m_type = MR_MSG_IMAGE;
	mrparam_set    (msg->m_param, MRP_FILE,   file);
	mrparam_set_int(msg->m_param, MRP_WIDTH,  width);  /* set in sending job, if 0 */
	mrparam_set_int(msg->m_param, MRP_HEIGHT, height); /* set in sending job, if 0 */

	ret = mrmailbox_send_msg_object(mailbox, chat_id, msg);

cleanup:
	mrmsg_unref(msg);
	return ret;

}


/**
 * Send a video to a chat.
 *
 * Sends the event #MR_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * See also mrmailbox_send_image_msg().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 * @param chat_id Chat ID to send the video to.
 * @param file Full path of the video file to send. The core may make a copy of the file.
 * @param filemime Mime type of the file to send. NULL if you don't know or don't care.
 * @param width Width in video of the file, if known. 0 if you don't know or don't care.
 * @param height Width in video of the file, if known. 0 if you don't know or don't care.
 * @param duration Length of the video in milliseconds. 0 if you don't know or don't care.
 *
 * @return The ID of the message that is about being sent.
 */
uint32_t mrmailbox_send_video_msg(mrmailbox_t* mailbox, uint32_t chat_id, const char* file, const char* filemime, int width, int height, int duration)
{
	mrmsg_t* msg = mrmsg_new();
	uint32_t ret = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || chat_id <= MR_CHAT_ID_LAST_SPECIAL || file == NULL ) {
		goto cleanup;
	}

	msg->m_type = MR_MSG_VIDEO;
	mrparam_set    (msg->m_param, MRP_FILE,     file);
	mrparam_set    (msg->m_param, MRP_MIMETYPE, filemime);
	mrparam_set_int(msg->m_param, MRP_WIDTH,    width);
	mrparam_set_int(msg->m_param, MRP_HEIGHT,   height);
	mrparam_set_int(msg->m_param, MRP_DURATION, duration);

	ret = mrmailbox_send_msg_object(mailbox, chat_id, msg);

cleanup:
	mrmsg_unref(msg);
	return ret;

}


/**
 * Send a voice message to a chat.  Voice messages are messages just recorded though the device microphone.
 * For sending music or other audio data, use mrmailbox_send_audio_msg().
 *
 * Sends the event #MR_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 * @param chat_id Chat ID to send the voice message to.
 * @param file Full path of the file to send. The core may make a copy of the file.
 * @param filemime Mime type of the file to send. NULL if you don't know or don't care.
 * @param duration Length of the voice message in milliseconds. 0 if you don't know or don't care.
 *
 * @return The ID of the message that is about being sent.
 */
uint32_t mrmailbox_send_voice_msg(mrmailbox_t* mailbox, uint32_t chat_id, const char* file, const char* filemime, int duration)
{
	mrmsg_t* msg = mrmsg_new();
	uint32_t ret = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || chat_id <= MR_CHAT_ID_LAST_SPECIAL || file == NULL ) {
		goto cleanup;
	}

	msg->m_type = MR_MSG_VOICE;
	mrparam_set    (msg->m_param, MRP_FILE,     file);
	mrparam_set    (msg->m_param, MRP_MIMETYPE, filemime);
	mrparam_set_int(msg->m_param, MRP_DURATION, duration);

	ret = mrmailbox_send_msg_object(mailbox, chat_id, msg);

cleanup:
	mrmsg_unref(msg);
	return ret;
}


/**
 * Send an audio file to a chat.  Audio messages are eg. music tracks.
 * For voice messages just recorded though the device microphone, use mrmailbox_send_voice_msg().
 *
 * Sends the event #MR_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 * @param chat_id Chat ID to send the audio to.
 * @param file Full path of the file to send. The core may make a copy of the file.
 * @param filemime Mime type of the file to send. NULL if you don't know or don't care.
 * @param duration Length of the audio in milliseconds. 0 if you don't know or don't care.
 * @param author Author or artist of the file. NULL if you don't know or don't care.
 * @param trackname Trackname or title of the file. NULL if you don't know or don't care.
 *
 * @return The ID of the message that is about being sent.
 */
uint32_t mrmailbox_send_audio_msg(mrmailbox_t* mailbox, uint32_t chat_id, const char* file, const char* filemime, int duration, const char* author, const char* trackname)
{
	mrmsg_t* msg = mrmsg_new();
	uint32_t ret = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || chat_id <= MR_CHAT_ID_LAST_SPECIAL || file == NULL ) {
		goto cleanup;
	}

	msg->m_type = MR_MSG_AUDIO;
	mrparam_set    (msg->m_param, MRP_FILE,       file);
	mrparam_set    (msg->m_param, MRP_MIMETYPE,   filemime);
	mrparam_set_int(msg->m_param, MRP_DURATION,   duration);
	mrparam_set    (msg->m_param, MRP_AUTHORNAME, author);
	mrparam_set    (msg->m_param, MRP_TRACKNAME,  trackname);

	ret = mrmailbox_send_msg_object(mailbox, chat_id, msg);

cleanup:
	mrmsg_unref(msg);
	return ret;
}


/**
 * Send a document to a chat. Use this function to send any document or file to
 * a chat.
 *
 * Sends the event #MR_EVENT_MSGS_CHANGED on succcess.
 * However, this does not imply, the message really reached the recipient -
 * sending may be delayed eg. due to network problems. However, from your
 * view, you're done with the message. Sooner or later it will find its way.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as returned from mrmailbox_new().
 * @param chat_id Chat ID to send the document to.
 * @param file Full path of the file to send. The core may make a copy of the file.
 * @param filemime Mime type of the file to send. NULL if you don't know or don't care.
 *
 * @return The ID of the message that is about being sent.
 */
uint32_t mrmailbox_send_file_msg(mrmailbox_t* mailbox, uint32_t chat_id, const char* file, const char* filemime)
{
	mrmsg_t* msg = mrmsg_new();
	uint32_t ret = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || chat_id <= MR_CHAT_ID_LAST_SPECIAL || file == NULL ) {
		goto cleanup;
	}

	msg->m_type = MR_MSG_FILE;
	mrparam_set(msg->m_param, MRP_FILE,     file);
	mrparam_set(msg->m_param, MRP_MIMETYPE, filemime);

	ret = mrmailbox_send_msg_object(mailbox, chat_id, msg);

cleanup:
	mrmsg_unref(msg);
	return ret;
}


/**
 * Send foreign contact data to a chat.
 *
 * Sends the name and the email address of another contact to a chat.
 * The contact this may or may not be a member of the chat.
 *
 * Typically used to share a contact to another member or to a group of members.
 *
 * Internally, the function just creates an appropriate text message and sends it
 * using mrmailbox_send_text_msg().
 *
 * NB: The "vcard" in the function name is just an abbreviation of "visiting card" and
 * is not related to the VCARD data format.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object.
 *
 * @param chat_id The chat to send the message to.
 *
 * @param contact_id The contact whichs data should be shared to the chat.
 *
 * @return Returns the ID of the message sent.
 */
uint32_t mrmailbox_send_vcard_msg(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t contact_id)
{
	uint32_t     ret = 0;
	mrmsg_t*     msg = mrmsg_new();
	mrcontact_t* contact = NULL;
	char*        text_to_send = NULL;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	if( (contact=mrmailbox_get_contact(mailbox, contact_id)) == NULL ) {
		goto cleanup;
	}

	if( contact->m_authname && contact->m_authname[0] ) {
		text_to_send = mr_mprintf("%s: %s", contact->m_authname, contact->m_addr);
	}
	else {
		text_to_send = safe_strdup(contact->m_addr);
	}

	ret = mrmailbox_send_text_msg(mailbox, chat_id, text_to_send);

cleanup:
	mrmsg_unref(msg);
	mrcontact_unref(contact);
	free(text_to_send);
	return ret;
}


/* similar to mrmailbox_add_device_msg() but without locking and without sending
 * an event.
 */
uint32_t mrmailbox_add_device_msg__(mrmailbox_t* mailbox, uint32_t chat_id, const char* text, time_t timestamp)
{
	sqlite3_stmt* stmt = NULL;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || text == NULL ) {
		return 0;
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, INSERT_INTO_msgs_cftttst,
		"INSERT INTO msgs (chat_id,from_id,to_id, timestamp,type,state, txt) VALUES (?,?,?, ?,?,?, ?);");
	sqlite3_bind_int  (stmt,  1, chat_id);
	sqlite3_bind_int  (stmt,  2, MR_CONTACT_ID_DEVICE);
	sqlite3_bind_int  (stmt,  3, MR_CONTACT_ID_DEVICE);
	sqlite3_bind_int64(stmt,  4, timestamp);
	sqlite3_bind_int  (stmt,  5, MR_MSG_TEXT);
	sqlite3_bind_int  (stmt,  6, MR_STATE_IN_NOTICED);
	sqlite3_bind_text (stmt,  7, text,  -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) != SQLITE_DONE ) {
		return 0;
	}

	return sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj);
}


/*
 * Log a device message.
 * Such a message is typically shown in the "middle" of the chat, the user can check this using mrmsg_is_info().
 * Texts are typically "Alice has added Bob to the group" or "Alice fingerprint verified."
 */
uint32_t mrmailbox_add_device_msg(mrmailbox_t* mailbox, uint32_t chat_id, const char* text)
{
	uint32_t      msg_id = 0;
	int           locked = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || text == NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		mrmailbox_add_device_msg__(mailbox, chat_id, text, mr_create_smeared_timestamp__());

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, chat_id, msg_id);

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	return msg_id;
}


/*******************************************************************************
 * Handle Group Chats
 ******************************************************************************/


#define IS_SELF_IN_GROUP__ (mrmailbox_is_contact_in_chat__(mailbox, chat_id, MR_CONTACT_ID_SELF)==1)
#define DO_SEND_STATUS_MAILS (mrparam_get_int(chat->m_param, MRP_UNPROMOTED, 0)==0)


int mrmailbox_is_group_explicitly_left__(mrmailbox_t* mailbox, const char* grpid)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_FROM_leftgrps_WHERE_grpid, "SELECT id FROM leftgrps WHERE grpid=?;");
	sqlite3_bind_text (stmt, 1, grpid, -1, SQLITE_STATIC);
	return (sqlite3_step(stmt)==SQLITE_ROW);
}


void mrmailbox_set_group_explicitly_left__(mrmailbox_t* mailbox, const char* grpid)
{
	if( !mrmailbox_is_group_explicitly_left__(mailbox, grpid) )
	{
		sqlite3_stmt* stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, "INSERT INTO leftgrps (grpid) VALUES(?);");
		sqlite3_bind_text (stmt, 1, grpid, -1, SQLITE_STATIC);
		sqlite3_step(stmt);
		sqlite3_finalize(stmt);
	}
}


static int mrmailbox_real_group_exists__(mrmailbox_t* mailbox, uint32_t chat_id)
{
	// check if a group or a verified group exists under the given ID
	sqlite3_stmt* stmt;
	int           ret = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || mailbox->m_sql->m_cobj==NULL
	 || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		return 0;
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_chats_WHERE_id,
		"SELECT id FROM chats "
		" WHERE id=? "
		"   AND (type=" MR_STRINGIFY(MR_CHAT_TYPE_GROUP) " OR type=" MR_STRINGIFY(MR_CHAT_TYPE_VERIFIED_GROUP) ");");
	sqlite3_bind_int(stmt, 1, chat_id);

	if( sqlite3_step(stmt) == SQLITE_ROW ) {
		ret = 1;
	}

	return ret;
}


int mrmailbox_add_to_chat_contacts_table__(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t contact_id)
{
	/* add a contact to a chat; the function does not check the type or if any of the record exist or are already added to the chat! */
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, INSERT_INTO_chats_contacts,
		"INSERT INTO chats_contacts (chat_id, contact_id) VALUES(?, ?)");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, contact_id);
	return (sqlite3_step(stmt)==SQLITE_DONE)? 1 : 0;
}


/**
 * Create a new group chat.
 *
 * After creation, the group has one member with the
 * ID MR_CONTACT_ID_SELF and is in _unpromoted_ state.  This means, you can
 * add or remove members, change the name, the group image and so on without
 * messages being sent to all group members.
 *
 * This changes as soon as the first message is sent to the group members and
 * the group becomes _promoted_.  After that, all changes are synced with all
 * group members by sending status message.
 *
 * To check, if a chat is still unpromoted, you mrchat_is_unpromoted()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 * @param verified If set to 1 the function creates a secure verfied group.
 *     Only secure-verified members are allowd in these groups and end-to-end-encryption is always enabled.
 * @param chat_name The name of the group chat to create.
 *     The name may be changed later using mrmailbox_set_chat_name().
 *     To find out the name of a group later, see mrchat_t::m_name
 *
 * @return The chat ID of the new group chat, 0 on errors.
 */
uint32_t mrmailbox_create_group_chat(mrmailbox_t* mailbox, int verified, const char* chat_name)
{
	uint32_t      chat_id = 0;
	int           locked = 0;
	char*         draft_txt = NULL, *grpid = NULL;
	sqlite3_stmt* stmt = NULL;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || chat_name==NULL || chat_name[0]==0 ) {
		return 0;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		draft_txt = mrstock_str_repl_string(MR_STR_NEWGROUPDRAFT, chat_name);
		grpid = mr_create_id();

		stmt = mrsqlite3_prepare_v2_(mailbox->m_sql,
			"INSERT INTO chats (type, name, draft_timestamp, draft_txt, grpid, param) VALUES(?, ?, ?, ?, ?, 'U=1');" /*U=MRP_UNPROMOTED*/ );
		sqlite3_bind_int  (stmt, 1, verified? MR_CHAT_TYPE_VERIFIED_GROUP : MR_CHAT_TYPE_GROUP);
		sqlite3_bind_text (stmt, 2, chat_name, -1, SQLITE_STATIC);
		sqlite3_bind_int64(stmt, 3, time(NULL));
		sqlite3_bind_text (stmt, 4, draft_txt, -1, SQLITE_STATIC);
		sqlite3_bind_text (stmt, 5, grpid, -1, SQLITE_STATIC);
		if(  sqlite3_step(stmt)!=SQLITE_DONE ) {
			goto cleanup;
		}

		if( (chat_id=sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj)) == 0 ) {
			goto cleanup;
		}

		if( mrmailbox_add_to_chat_contacts_table__(mailbox, chat_id, MR_CONTACT_ID_SELF) ) {
			goto cleanup;
		}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( stmt) { sqlite3_finalize(stmt); }
	free(draft_txt);
	free(grpid);

	if( chat_id ) {
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0);
	}

	return chat_id;
}


/**
 * Set group name.
 *
 * If the group is already _promoted_ (any message was sent to the group),
 * all group members are informed by a special status message that is sent automatically by this function.
 *
 * Sends out #MR_EVENT_CHAT_MODIFIED and #MR_EVENT_MSGS_CHANGED if a status message was sent.
 *
 * @memberof mrmailbox_t
 *
 * @param chat_id The chat ID to set the name for.  Must be a group chat.
 *
 * @param new_name New name of the group.
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 *
 * @return 1=success, 0=error
 */
int mrmailbox_set_chat_name(mrmailbox_t* mailbox, uint32_t chat_id, const char* new_name)
{
	/* the function only sets the names of group chats; normal chats get their names from the contacts */
	int       success = 0, locked = 0;
	mrchat_t* chat = mrchat_new(mailbox);
	mrmsg_t*  msg = mrmsg_new();
	char*     q3 = NULL;

	if( mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || new_name==NULL || new_name[0]==0 || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( 0==mrmailbox_real_group_exists__(mailbox, chat_id)
		 || 0==mrchat_load_from_db__(chat, chat_id) ) {
			goto cleanup;
		}

		if( strcmp(chat->m_name, new_name)==0 ) {
			success = 1;
			goto cleanup; /* name not modified */
		}

		if( !IS_SELF_IN_GROUP__ ) {
			mrmailbox_log_error(mailbox, MR_ERR_SELF_NOT_IN_GROUP, NULL);
			goto cleanup; /* we shoud respect this - whatever we send to the group, it gets discarded anyway! */
		}

		q3 = sqlite3_mprintf("UPDATE chats SET name=%Q WHERE id=%i;", new_name, chat_id);
		if( !mrsqlite3_execute__(mailbox->m_sql, q3) ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* send a status mail to all group members, also needed for outself to allow multi-client */
	if( DO_SEND_STATUS_MAILS )
	{
		msg->m_type = MR_MSG_TEXT;
		msg->m_text = mrstock_str_repl_string2(MR_STR_MSGGRPNAME, chat->m_name, new_name);
		mrparam_set_int(msg->m_param, MRP_CMD, MR_CMD_GROUPNAME_CHANGED);
		msg->m_id = mrmailbox_send_msg_object(mailbox, chat_id, msg);
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, chat_id, msg->m_id);
	}
	mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, chat_id, 0);

	success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( q3 ) { sqlite3_free(q3); }
	mrchat_unref(chat);
	mrmsg_unref(msg);
	return success;
}


/**
 * Set group profile image.
 *
 * If the group is already _promoted_ (any message was sent to the group),
 * all group members are informed by a special status message that is sent automatically by this function.
 *
 * Sends out #MR_EVENT_CHAT_MODIFIED and #MR_EVENT_MSGS_CHANGED if a status message was sent.
 *
 * To find out the profile image of a chat, use mrchat_get_profile_image()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 *
 * @param chat_id The chat ID to set the image for.
 *
 * @param new_image Full path of the image to use as the group image.  If you pass NULL here,
 *     the group image is deleted (for promoted groups, all members are informed about this change anyway).
 *
 * @return 1=success, 0=error
 */
int mrmailbox_set_chat_profile_image(mrmailbox_t* mailbox, uint32_t chat_id, const char* new_image /*NULL=remove image*/)
{
	int       success = 0, locked = 0;;
	mrchat_t* chat = mrchat_new(mailbox);
	mrmsg_t*  msg = mrmsg_new();

	if( mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( 0==mrmailbox_real_group_exists__(mailbox, chat_id)
		 || 0==mrchat_load_from_db__(chat, chat_id) ) {
			goto cleanup;
		}

		if( !IS_SELF_IN_GROUP__ ) {
			mrmailbox_log_error(mailbox, MR_ERR_SELF_NOT_IN_GROUP, NULL);
			goto cleanup; /* we shoud respect this - whatever we send to the group, it gets discarded anyway! */
		}

		mrparam_set(chat->m_param, MRP_PROFILE_IMAGE, new_image/*may be NULL*/);
		if( !mrchat_update_param__(chat) ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* send a status mail to all group members, also needed for outself to allow multi-client */
	if( DO_SEND_STATUS_MAILS )
	{
		mrparam_set_int(msg->m_param, MRP_CMD,       MR_CMD_GROUPIMAGE_CHANGED);
		mrparam_set    (msg->m_param, MRP_CMD_PARAM, new_image);
		msg->m_type = MR_MSG_TEXT;
		msg->m_text = mrstock_str(new_image? MR_STR_MSGGRPIMGCHANGED : MR_STR_MSGGRPIMGDELETED);
		msg->m_id = mrmailbox_send_msg_object(mailbox, chat_id, msg);
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, chat_id, msg->m_id);
	}
	mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, chat_id, 0);

	success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrchat_unref(chat);
	mrmsg_unref(msg);
	return success;
}


int mrmailbox_get_chat_contact_count__(mrmailbox_t* mailbox, uint32_t chat_id)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_chats_contacts_WHERE_chat_id,
		"SELECT COUNT(*) FROM chats_contacts WHERE chat_id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);
	if( sqlite3_step(stmt) == SQLITE_ROW ) {
		return sqlite3_column_int(stmt, 0);
	}
	return 0;
}


int mrmailbox_is_contact_in_chat__(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t contact_id)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_void_FROM_chats_contacts_WHERE_chat_id_AND_contact_id,
		"SELECT contact_id FROM chats_contacts WHERE chat_id=? AND contact_id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, contact_id);
	return (sqlite3_step(stmt) == SQLITE_ROW)? 1 : 0;
}


/**
 * Check if a given contact ID is a member of a group chat.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 *
 * @param chat_id The chat ID to check.
 *
 * @param contact_id The contact ID to check.  To check if yourself is member
 *     of the chat, pass MR_CONTACT_ID_SELF (1) here.
 *
 * @return 1=contact ID is member of chat ID, 0=contact is not in chat
 */
int mrmailbox_is_contact_in_chat(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t contact_id)
{
	/* this function works for group and for normal chats, however, it is more useful for group chats.
	MR_CONTACT_ID_SELF may be used to check, if the user itself is in a group chat (MR_CONTACT_ID_SELF is not added to normal chats) */
	int ret = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return 0;
	}

	mrsqlite3_lock(mailbox->m_sql);

		ret = mrmailbox_is_contact_in_chat__(mailbox, chat_id, contact_id);

	mrsqlite3_unlock(mailbox->m_sql);

	return ret;
}


int mrmailbox_add_contact_to_chat4(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t contact_id, int from_handshake)
{
	int             success   = 0, locked = 0;
	mrcontact_t*    contact   = mrmailbox_get_contact(mailbox, contact_id);
	mrapeerstate_t* peerstate = mrapeerstate_new(mailbox);
	mrchat_t*       chat      = mrchat_new(mailbox);
	mrmsg_t*        msg       = mrmsg_new();
	char*           self_addr = NULL;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || contact == NULL || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( 0==mrmailbox_real_group_exists__(mailbox, chat_id) /*this also makes sure, not contacts are added to special or normal chats*/
		 || (0==mrmailbox_real_contact_exists__(mailbox, contact_id) && contact_id!=MR_CONTACT_ID_SELF)
		 || 0==mrchat_load_from_db__(chat, chat_id) ) {
			goto cleanup;
		}

		if( !IS_SELF_IN_GROUP__ ) {
			mrmailbox_log_error(mailbox, MR_ERR_SELF_NOT_IN_GROUP, NULL);
			goto cleanup; /* we shoud respect this - whatever we send to the group, it gets discarded anyway! */
		}

		if( from_handshake && mrparam_get_int(chat->m_param, MRP_UNPROMOTED, 0)==1 ) {
			// after a handshake, force sending the `Chat-Group-Member-Added` message
			mrparam_set(chat->m_param, MRP_UNPROMOTED, NULL);
			mrchat_update_param__(chat);
		}

		self_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", "");
		if( strcasecmp(contact->m_addr, self_addr)==0 ) {
			goto cleanup; /* ourself is added using MR_CONTACT_ID_SELF, do not add it explicitly. if SELF is not in the group, members cannot be added at all. */
		}

		if( mrmailbox_is_contact_in_chat__(mailbox, chat_id, contact_id) )
		{
			if( !from_handshake ) {
				success = 1;
				goto cleanup;
			}
			// else continue and send status mail
		}
		else
		{
			if( !mrapeerstate_load_by_addr__(peerstate, mailbox->m_sql, contact->m_addr) ) {
				goto cleanup;
			}

			if( chat->m_type==MR_CHAT_TYPE_VERIFIED_GROUP
			 && mrcontact_is_verified__(contact, peerstate)!=MRV_BIDIRECTIONAL ) {
				mrmailbox_log_error(mailbox, 0, "Only bidirectional verified contacts can be added to verfied groups.");
				goto cleanup;
			}

			if( 0==mrmailbox_add_to_chat_contacts_table__(mailbox, chat_id, contact_id) ) {
				goto cleanup;
			}
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* send a status mail to all group members */
	if( DO_SEND_STATUS_MAILS )
	{
		msg->m_type = MR_MSG_TEXT;
		msg->m_text = mrstock_str_repl_string(MR_STR_MSGADDMEMBER, (contact->m_authname&&contact->m_authname[0])? contact->m_authname : contact->m_addr);
		mrparam_set_int(msg->m_param, MRP_CMD,       MR_CMD_MEMBER_ADDED_TO_GROUP);
		mrparam_set    (msg->m_param, MRP_CMD_PARAM, contact->m_addr);
		mrparam_set_int(msg->m_param, MRP_CMD_PARAM2,from_handshake); // combine the Secure-Join protocol headers with the Chat-Group-Member-Added header
		msg->m_id = mrmailbox_send_msg_object(mailbox, chat_id, msg);
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, chat_id, msg->m_id);
	}
	mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, chat_id, 0);

	success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrchat_unref(chat);
	mrcontact_unref(contact);
	mrapeerstate_unref(peerstate);
	mrmsg_unref(msg);
	free(self_addr);
	return success;
}


/**
 * Add a member to a group.
 *
 * If the group is already _promoted_ (any message was sent to the group),
 * all group members are informed by a special status message that is sent automatically by this function.
 *
 * If the group is a verified group, only verified contacts can be added to the group.
 *
 * Sends out #MR_EVENT_CHAT_MODIFIED and #MR_EVENT_MSGS_CHANGED if a status message was sent.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 *
 * @param chat_id The chat ID to add the contact to.  Must be a group chat.
 *
 * @param contact_id The contact ID to add to the chat.
 *
 * @return 1=member added to group, 0=error
 */
int mrmailbox_add_contact_to_chat(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t contact_id /*may be MR_CONTACT_ID_SELF*/)
{
	return mrmailbox_add_contact_to_chat4(mailbox, chat_id, contact_id, 0);
}


/**
 * Remove a member from a group.
 *
 * If the group is already _promoted_ (any message was sent to the group),
 * all group members are informed by a special status message that is sent automatically by this function.
 *
 * Sends out #MR_EVENT_CHAT_MODIFIED and #MR_EVENT_MSGS_CHANGED if a status message was sent.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new().
 *
 * @param chat_id The chat ID to remove the contact from.  Must be a group chat.
 *
 * @param contact_id The contact ID to remove from the chat.
 *
 * @return 1=member removed from group, 0=error
 */
int mrmailbox_remove_contact_from_chat(mrmailbox_t* mailbox, uint32_t chat_id, uint32_t contact_id /*may be MR_CONTACT_ID_SELF*/)
{
	int          success = 0, locked = 0;
	mrcontact_t* contact = mrmailbox_get_contact(mailbox, contact_id);
	mrchat_t*    chat = mrchat_new(mailbox);
	mrmsg_t*     msg = mrmsg_new();
	char*        q3 = NULL;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || chat_id <= MR_CHAT_ID_LAST_SPECIAL || (contact_id<=MR_CONTACT_ID_LAST_SPECIAL && contact_id!=MR_CONTACT_ID_SELF) ) {
		goto cleanup; /* we do not check if "contact_id" exists but just delete all records with the id from chats_contacts */
	}                 /* this allows to delete pending references to deleted contacts.  Of course, this should _not_ happen. */

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( 0==mrmailbox_real_group_exists__(mailbox, chat_id)
		 || 0==mrchat_load_from_db__(chat, chat_id) ) {
			goto cleanup;
		}

		if( !IS_SELF_IN_GROUP__ ) {
			mrmailbox_log_error(mailbox, MR_ERR_SELF_NOT_IN_GROUP, NULL);
			goto cleanup; /* we shoud respect this - whatever we send to the group, it gets discarded anyway! */
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* send a status mail to all group members - we need to do this before we update the database -
	otherwise the !IS_SELF_IN_GROUP__-check in mrchat_send_msg() will fail. */
	if( contact )
	{
		if( DO_SEND_STATUS_MAILS )
		{
			msg->m_type = MR_MSG_TEXT;
			if( contact->m_id == MR_CONTACT_ID_SELF ) {
				mrmailbox_set_group_explicitly_left__(mailbox, chat->m_grpid);
				msg->m_text = mrstock_str(MR_STR_MSGGROUPLEFT);
			}
			else {
				msg->m_text = mrstock_str_repl_string(MR_STR_MSGDELMEMBER, (contact->m_authname&&contact->m_authname[0])? contact->m_authname : contact->m_addr);
			}
			mrparam_set_int(msg->m_param, MRP_CMD,       MR_CMD_MEMBER_REMOVED_FROM_GROUP);
			mrparam_set    (msg->m_param, MRP_CMD_PARAM, contact->m_addr);
			msg->m_id = mrmailbox_send_msg_object(mailbox, chat_id, msg);
			mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, chat_id, msg->m_id);
		}
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		q3 = sqlite3_mprintf("DELETE FROM chats_contacts WHERE chat_id=%i AND contact_id=%i;", chat_id, contact_id);
		if( !mrsqlite3_execute__(mailbox->m_sql, q3) ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	mailbox->m_cb(mailbox, MR_EVENT_CHAT_MODIFIED, chat_id, 0);

	success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( q3 ) { sqlite3_free(q3); }
	mrchat_unref(chat);
	mrcontact_unref(contact);
	mrmsg_unref(msg);
	return success;
}



/*******************************************************************************
 * Handle Contacts
 ******************************************************************************/


int mrmailbox_real_contact_exists__(mrmailbox_t* mailbox, uint32_t contact_id)
{
	sqlite3_stmt* stmt;
	int           ret = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || mailbox->m_sql->m_cobj==NULL
	 || contact_id <= MR_CONTACT_ID_LAST_SPECIAL ) {
		return 0;
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_WHERE_id,
		"SELECT id FROM contacts WHERE id=?;");
	sqlite3_bind_int(stmt, 1, contact_id);

	if( sqlite3_step(stmt) == SQLITE_ROW ) {
		ret = 1;
	}

	return ret;
}


size_t mrmailbox_get_real_contact_cnt__(mrmailbox_t* mailbox)
{
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || mailbox->m_sql->m_cobj==NULL ) {
		return 0;
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_contacts, "SELECT COUNT(*) FROM contacts WHERE id>?;");
	sqlite3_bind_int(stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


uint32_t mrmailbox_add_or_lookup_contact__( mrmailbox_t* mailbox,
                                           const char*  name /*can be NULL, the caller may use mr_normalize_name() before*/,
                                           const char*  addr__,
                                           int          origin,
                                           int*         sth_modified )
{
	#define       CONTACT_MODIFIED 1
	#define       CONTACT_CREATED  2
	sqlite3_stmt* stmt;
	uint32_t      row_id = 0;
	int           dummy;
	char*         addr = NULL;

	if( sth_modified == NULL ) {
		sth_modified = &dummy;
	}

	*sth_modified = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || addr__ == NULL || origin <= 0 ) {
		goto cleanup;
	}

	/* normalize the email-address:
	- remove leading `mailto:` */
	addr = mr_normalize_addr(addr__);

	/* rough check if email-address is valid */
	if( strlen(addr) < 3 || strchr(addr, '@')==NULL || strchr(addr, '.')==NULL ) {
		mrmailbox_log_warning(mailbox, 0, "Bad address \"%s\" for contact \"%s\".", addr, name?name:"<unset>");
		goto cleanup;
	}

	/* insert email-address to database or modify the record with the given email-address.
	we treat all email-addresses case-insensitive. */
	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_inao_FROM_contacts_a,
		"SELECT id, name, addr, origin, authname FROM contacts WHERE addr=? COLLATE NOCASE;");
	sqlite3_bind_text(stmt, 1, (const char*)addr, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) == SQLITE_ROW )
	{
		const char  *row_name, *row_addr, *row_authname;
		int         row_origin, update_addr = 0, update_name = 0, update_authname = 0;

		row_id       = sqlite3_column_int(stmt, 0);
		row_name     = (const char*)sqlite3_column_text(stmt, 1); if( row_name == NULL ) { row_name = ""; }
		row_addr     = (const char*)sqlite3_column_text(stmt, 2); if( row_addr == NULL ) { row_addr = addr; }
		row_origin   = sqlite3_column_int(stmt, 3);
		row_authname = (const char*)sqlite3_column_text(stmt, 4); if( row_authname == NULL ) { row_authname = ""; }

		if( name && name[0] ) {
			if( row_name && row_name[0] ) {
				if( origin>=row_origin && strcmp(name, row_name)!=0 ) {
					update_name = 1;
				}
			}
			else {
				update_name = 1;
			}

			if( origin == MR_ORIGIN_INCOMING_UNKNOWN_FROM && strcmp(name, row_authname)!=0 ) {
				update_authname = 1;
			}
		}

		if( origin>=row_origin && strcmp(addr, row_addr)!=0 /*really compare case-sensitive here*/ ) {
			update_addr = 1;
		}

		if( update_name || update_authname || update_addr || origin>row_origin )
		{
			stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_contacts_nao_WHERE_i,
				"UPDATE contacts SET name=?, addr=?, origin=?, authname=? WHERE id=?;");
			sqlite3_bind_text(stmt, 1, update_name?       name   : row_name, -1, SQLITE_STATIC);
			sqlite3_bind_text(stmt, 2, update_addr?       addr   : row_addr, -1, SQLITE_STATIC);
			sqlite3_bind_int (stmt, 3, origin>row_origin? origin : row_origin);
			sqlite3_bind_text(stmt, 4, update_authname?   name   : row_authname, -1, SQLITE_STATIC);
			sqlite3_bind_int (stmt, 5, row_id);
			sqlite3_step     (stmt);

			if( update_name )
			{
				/* Update the contact name also if it is used as a group name.
				This is one of the few duplicated data, however, getting the chat list is easier this way.*/
				stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_chats_SET_n_WHERE_c,
					"UPDATE chats SET name=? WHERE type=? AND id IN(SELECT chat_id FROM chats_contacts WHERE contact_id=?);");
				sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
				sqlite3_bind_int (stmt, 2, MR_CHAT_TYPE_SINGLE);
				sqlite3_bind_int (stmt, 3, row_id);
				sqlite3_step     (stmt);
			}

			*sth_modified = CONTACT_MODIFIED;
		}
	}
	else
	{
		stmt = mrsqlite3_predefine__(mailbox->m_sql, INSERT_INTO_contacts_neo,
			"INSERT INTO contacts (name, addr, origin) VALUES(?, ?, ?);");
		sqlite3_bind_text(stmt, 1, name? name : "", -1, SQLITE_STATIC); /* avoid NULL-fields in column */
		sqlite3_bind_text(stmt, 2, addr,    -1, SQLITE_STATIC);
		sqlite3_bind_int (stmt, 3, origin);
		if( sqlite3_step(stmt) == SQLITE_DONE )
		{
			row_id = sqlite3_last_insert_rowid(mailbox->m_sql->m_cobj);
			*sth_modified = CONTACT_CREATED;
		}
		else
		{
			mrmailbox_log_error(mailbox, 0, "Cannot add contact."); /* should not happen */
		}
	}

cleanup:
	free(addr);
	return row_id;
}


void mrmailbox_scaleup_contact_origin__(mrmailbox_t* mailbox, uint32_t contact_id, int origin)
{
	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
	}

	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_contacts_SET_origin_WHERE_id,
		"UPDATE contacts SET origin=? WHERE id=? AND origin<?;");
	sqlite3_bind_int(stmt, 1, origin);
	sqlite3_bind_int(stmt, 2, contact_id);
	sqlite3_bind_int(stmt, 3, origin);
	sqlite3_step(stmt);
}


int mrmailbox_is_contact_blocked__(mrmailbox_t* mailbox, uint32_t contact_id)
{
	int          is_blocked = 0;
	mrcontact_t* contact = mrcontact_new(mailbox);

	if( mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id) ) { /* we could optimize this by loading only the needed fields */
		if( contact->m_blocked ) {
			is_blocked = 1;
		}
	}

	mrcontact_unref(contact);
	return is_blocked;
}


int mrmailbox_get_contact_origin__(mrmailbox_t* mailbox, uint32_t contact_id, int* ret_blocked)
{
	int          ret = 0;
	int          dummy; if( ret_blocked==NULL ) { ret_blocked = &dummy; }
	mrcontact_t* contact = mrcontact_new(mailbox);

	*ret_blocked = 0;

	if( !mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id) ) { /* we could optimize this by loading only the needed fields */
		goto cleanup;
	}

	if( contact->m_blocked ) {
		*ret_blocked = 1;
		goto cleanup;
	}

	ret = contact->m_origin;

cleanup:
	mrcontact_unref(contact);
	return ret;
}


/**
 * Add a single contact.
 *
 * We assume, the contact name, if any, is entered by the user and is used "as is" therefore,
 * mr_normalize_name() is _not_ called for the name.
 *
 * To add a number of contacts, see mrmailbox_add_address_book() which is much faster for adding
 * a bunch of addresses.
 *
 * May result in a #MR_EVENT_CONTACTS_CHANGED event.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @param name Name of the contact to add. If you do not know the name belonging
 *     to the address, you can give NULL here.
 *
 * @param addr E-mail-address of the contact to add. If the email address
 *     already exists, the name is updated and the origin is increased to
 *     "manually created".
 *
 * @return Contact ID of the created or reused contact.
 */
uint32_t mrmailbox_create_contact(mrmailbox_t* mailbox, const char* name, const char* addr)
{
	uint32_t contact_id = 0;
	int      sth_modified = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || addr == NULL || addr[0]==0 ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);

		contact_id = mrmailbox_add_or_lookup_contact__(mailbox, name, addr, MR_ORIGIN_MANUALLY_CREATED, &sth_modified);

	mrsqlite3_unlock(mailbox->m_sql);

	mailbox->m_cb(mailbox, MR_EVENT_CONTACTS_CHANGED, sth_modified==CONTACT_CREATED? contact_id : 0, 0);

cleanup:
	return contact_id;
}


/**
 * Add a number of contacts.
 *
 * Typically used to add the whole address book from the OS. As names here are typically not
 * well formatted, we call mr_normalize_name() for each name given.
 *
 * To add a single contact entered by the user, you should prefer mrmailbox_create_contact(),
 * however, for adding a bunch of addresses, this function is _much_ faster.
 *
 * The function takes are of not overwriting names manually added or edited by mrmailbox_create_contact().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new().
 *
 * @param adr_book A multi-line string in the format in the format
 *     `Name one\nAddress one\nName two\Address two`.  If an email address
 *      already exists, the name is updated and the origin is increased to
 *      "manually created".
 *
 * @return The number of modified or added contacts.
 */
int mrmailbox_add_address_book(mrmailbox_t* mailbox, const char* adr_book) /* format: Name one\nAddress one\nName two\Address two */
{
	carray* lines = NULL;
	size_t  i, iCnt;
	int     sth_modified, modify_cnt = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || adr_book == NULL ) {
		goto cleanup;
	}

	if( (lines=mr_split_into_lines(adr_book))==NULL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);

		mrsqlite3_begin_transaction__(mailbox->m_sql);

		iCnt = carray_count(lines);
		for( i = 0; i+1 < iCnt; i += 2 ) {
			char* name = (char*)carray_get(lines, i);
			char* addr = (char*)carray_get(lines, i+1);
			mr_normalize_name(name);
			mrmailbox_add_or_lookup_contact__(mailbox, name, addr, MR_ORIGIN_ADRESS_BOOK, &sth_modified);
			if( sth_modified ) {
				modify_cnt++;
			}
		}

		mrsqlite3_commit__(mailbox->m_sql);

	mrsqlite3_unlock(mailbox->m_sql);

cleanup:
	mr_free_splitted_lines(lines);

	return modify_cnt;
}


/**
 * Returns known and unblocked contacts.
 *
 * To get information about a single contact, see mrmailbox_get_contact().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @param listflags A combination of flags:
 *     - if the flag MR_GCL_ADD_SELF is set, SELF is added to the list unless filtered by other parameters
 *     - if the flag MR_GCL_VERIFIED_ONLY is set, only verified contacts are returned.
 *       if MR_GCL_VERIFIED_ONLY is not set, verified and unverified contacts are returned.
 * @param query A string to filter the list.  Typically used to implement an
 *     incremental search.  NULL for no filtering.
 *
 * @return An array containing all contact IDs.  Must be mrarray_unref()'d
 *     after usage.
 */
mrarray_t* mrmailbox_get_contacts(mrmailbox_t* mailbox, uint32_t listflags, const char* query)
{
	int           locked = 0;
	char*         self_addr = NULL;
	char*         self_name = NULL;
	char*         self_name2 = NULL;
	int           add_self = 0;
	mrarray_t*    ret = mrarray_new(mailbox, 100);
	char*         s3strLikeCmd = NULL;
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		self_addr = mrsqlite3_get_config__(mailbox->m_sql, "configured_addr", ""); /* we add MR_CONTACT_ID_SELF explicitly; so avoid doubles if the address is present as a normal entry for some case */

		if( (listflags&MR_GCL_VERIFIED_ONLY) || query )
		{
			if( (s3strLikeCmd=sqlite3_mprintf("%%%s%%", query? query : ""))==NULL ) {
				goto cleanup;
			}
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_WHERE_query_ORDER_BY,
				"SELECT c.id FROM contacts c"
					" LEFT JOIN acpeerstates ps ON c.addr=ps.addr "
					" WHERE c.addr!=? AND c.id>" MR_STRINGIFY(MR_CONTACT_ID_LAST_SPECIAL) " AND c.origin>=" MR_STRINGIFY(MR_ORIGIN_MIN_CONTACT_LIST) " AND c.blocked=0 AND (c.name LIKE ? OR c.addr LIKE ?)" /* see comments in mrmailbox_search_msgs() about the LIKE operator */
					" AND (ps.public_key_verified=? OR ps.gossip_key_verified=? OR 1=?) "
					" ORDER BY LOWER(c.name||c.addr),c.id;");
			sqlite3_bind_text(stmt, 1, self_addr, -1, SQLITE_STATIC);
			sqlite3_bind_text(stmt, 2, s3strLikeCmd, -1, SQLITE_STATIC);
			sqlite3_bind_text(stmt, 3, s3strLikeCmd, -1, SQLITE_STATIC);
			sqlite3_bind_int (stmt, 4, (listflags&MR_GCL_VERIFIED_ONLY)? MRV_BIDIRECTIONAL : 0);
			sqlite3_bind_int (stmt, 5, (listflags&MR_GCL_VERIFIED_ONLY)? MRV_BIDIRECTIONAL : 0);
			sqlite3_bind_int (stmt, 6, (listflags&MR_GCL_VERIFIED_ONLY)? 0/*force checking for MRV_BIDIRECTIONAL*/ : 1/*force statement being always true*/);

			self_name  = mrsqlite3_get_config__(mailbox->m_sql, "displayname", "");
			self_name2 = mrstock_str(MR_STR_SELF);
			if( query==NULL || mr_str_contains(self_addr, query) || mr_str_contains(self_name, query) || mr_str_contains(self_name2, query) ) {
				add_self = 1;
			}
		}
		else
		{
			stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_ORDER_BY,
				"SELECT id FROM contacts"
					" WHERE addr!=? AND id>" MR_STRINGIFY(MR_CONTACT_ID_LAST_SPECIAL) " AND origin>=" MR_STRINGIFY(MR_ORIGIN_MIN_CONTACT_LIST) " AND blocked=0"
					" ORDER BY LOWER(name||addr),id;");
			sqlite3_bind_text(stmt, 1, self_addr, -1, SQLITE_STATIC);

			add_self = 1;
		}

		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			mrarray_add_id(ret, sqlite3_column_int(stmt, 0));
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* to the end of the list, add self - this is to be in sync with member lists and to allow the user to start a self talk */
	if( (listflags&MR_GCL_ADD_SELF) && add_self ) {
		mrarray_add_id(ret, MR_CONTACT_ID_SELF);
	}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( s3strLikeCmd ) { sqlite3_free(s3strLikeCmd); }
	free(self_addr);
	free(self_name);
	free(self_name2);
	return ret;
}


/**
 * Get blocked contacts.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @return An array containing all blocked contact IDs.  Must be mrarray_unref()'d
 *     after usage.
 */
mrarray_t* mrmailbox_get_blocked_contacts(mrmailbox_t* mailbox)
{
	mrarray_t*    ret = mrarray_new(mailbox, 100);
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_id_FROM_contacts_WHERE_blocked,
			"SELECT id FROM contacts"
				" WHERE id>? AND blocked!=0"
				" ORDER BY LOWER(name||addr),id;");
		sqlite3_bind_int(stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			mrarray_add_id(ret, sqlite3_column_int(stmt, 0));
		}

	mrsqlite3_unlock(mailbox->m_sql);

cleanup:
	return ret;
}


/**
 * Get the number of blocked contacts.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 */
int mrmailbox_get_blocked_count(mrmailbox_t* mailbox)
{
	int           ret = 0, locked = 0;
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_contacts_WHERE_blocked,
			"SELECT COUNT(*) FROM contacts"
				" WHERE id>? AND blocked!=0");
		sqlite3_bind_int(stmt, 1, MR_CONTACT_ID_LAST_SPECIAL);
		if( sqlite3_step(stmt) != SQLITE_ROW ) {
			goto cleanup;
		}
		ret = sqlite3_column_int(stmt, 0);

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	return ret;
}


/**
 * Get a single contact object.  For a list, see eg. mrmailbox_get_contacts().
 *
 * For contact MR_CONTACT_ID_SELF (1), the function returns the name
 * MR_STR_SELF (typically "Me" in the selected language) and the email address
 * defined by mrmailbox_set_config().
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @param contact_id ID of the contact to get the object for.
 *
 * @return The contact object, must be freed using mrcontact_unref() when no
 *     longer used.  NULL on errors.
 */
mrcontact_t* mrmailbox_get_contact(mrmailbox_t* mailbox, uint32_t contact_id)
{
	mrcontact_t* ret = mrcontact_new(mailbox);

	mrsqlite3_lock(mailbox->m_sql);

		if( !mrcontact_load_from_db__(ret, mailbox->m_sql, contact_id) ) {
			mrcontact_unref(ret);
			ret = NULL;
		}

	mrsqlite3_unlock(mailbox->m_sql);

	return ret; /* may be NULL */
}


static void marknoticed_contact__(mrmailbox_t* mailbox, uint32_t contact_id)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_state_WHERE_from_id_AND_state,
		"UPDATE msgs SET state=" MR_STRINGIFY(MR_STATE_IN_NOTICED) " WHERE from_id=? AND state=" MR_STRINGIFY(MR_STATE_IN_FRESH) ";");
	sqlite3_bind_int(stmt, 1, contact_id);
	sqlite3_step(stmt);
}


/**
 * Mark all messages sent by the given contact
 * as _noticed_.  See also mrmailbox_marknoticed_chat() and
 * mrmailbox_markseen_msgs()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmmailbox_new()
 *
 * @param contact_id The contact ID of which all messages should be marked as noticed.
 *
 * @return none
 */
void mrmailbox_marknoticed_contact(mrmailbox_t* mailbox, uint32_t contact_id)
{
    if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
    }
    mrsqlite3_lock(mailbox->m_sql);

		marknoticed_contact__(mailbox, contact_id);

    mrsqlite3_unlock(mailbox->m_sql);
}


void mrmailbox_block_chat__(mrmailbox_t* mailbox, uint32_t chat_id, int new_blocking)
{
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		return;
	}

	stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_chats_SET_blocked_WHERE_chat_id,
		"UPDATE chats SET blocked=? WHERE id=?;");
	sqlite3_bind_int(stmt, 1, new_blocking);
	sqlite3_bind_int(stmt, 2, chat_id);
	sqlite3_step(stmt);
}


void mrmailbox_unblock_chat__(mrmailbox_t* mailbox, uint32_t chat_id)
{
	mrmailbox_block_chat__(mailbox, chat_id, MR_CHAT_NOT_BLOCKED);
}


/**
 * Block or unblock a contact.
 *
 * May result in a #MR_EVENT_CONTACTS_CHANGED event.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @param contact_id The ID of the contact to block or unblock.
 *
 * @param new_blocking 1=block contact, 0=unblock contact
 *
 * @return None.
 */
void mrmailbox_block_contact(mrmailbox_t* mailbox, uint32_t contact_id, int new_blocking)
{
	int locked = 0, send_event = 0, transaction_pending = 0;
	mrcontact_t*  contact = mrcontact_new(mailbox);
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || contact_id <= MR_CONTACT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id)
		 && contact->m_blocked != new_blocking )
		{
			mrsqlite3_begin_transaction__(mailbox->m_sql);
			transaction_pending = 1;

				stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_contacts_SET_b_WHERE_i,
					"UPDATE contacts SET blocked=? WHERE id=?;");
				sqlite3_bind_int(stmt, 1, new_blocking);
				sqlite3_bind_int(stmt, 2, contact_id);
				if( sqlite3_step(stmt)!=SQLITE_DONE ) {
					goto cleanup;
				}

				/* also (un)block all chats with _only_ this contact - we do not delete them to allow a non-destructive blocking->unblocking.
				(Maybe, beside normal chats (type=100) we should also block group chats with only this user.
				However, I'm not sure about this point; it may be confusing if the user wants to add other people;
				this would result in recreating the same group...) */
				stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_chats_SET_blocked_WHERE_contact_id,
					"UPDATE chats SET blocked=? WHERE type=? AND id IN (SELECT chat_id FROM chats_contacts WHERE contact_id=?);");
				sqlite3_bind_int(stmt, 1, new_blocking);
				sqlite3_bind_int(stmt, 2, MR_CHAT_TYPE_SINGLE);
				sqlite3_bind_int(stmt, 3, contact_id);
				if( sqlite3_step(stmt)!=SQLITE_DONE ) {
					goto cleanup;
				}

				/* mark all messages from the blocked contact as being noticed (this is to remove the deaddrop popup) */
				marknoticed_contact__(mailbox, contact_id);

			mrsqlite3_commit__(mailbox->m_sql);
			transaction_pending = 0;

			send_event = 1;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	if( send_event ) {
		mailbox->m_cb(mailbox, MR_EVENT_CONTACTS_CHANGED, 0, 0);
	}

cleanup:
	if( transaction_pending ) { mrsqlite3_rollback__(mailbox->m_sql); }
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrcontact_unref(contact);
}


static void cat_fingerprint(mrstrbuilder_t* ret, const char* addr, const char* fingerprint_verified, const char* fingerprint_unverified)
{
	mrstrbuilder_cat(ret, "\n\n");
	mrstrbuilder_cat(ret, addr);
	mrstrbuilder_cat(ret, ":\n");
	mrstrbuilder_cat(ret, (fingerprint_verified&&fingerprint_verified[0])? fingerprint_verified : fingerprint_unverified);

	if( fingerprint_verified && fingerprint_verified[0]
	 && fingerprint_unverified && fingerprint_unverified[0]
	 && strcmp(fingerprint_verified, fingerprint_unverified)!=0 ) {
		// might be that for verified chats the - older - verified gossiped key is used
		// and for normal chats the - newer - unverified key :/
		mrstrbuilder_cat(ret, "\n\n");
		mrstrbuilder_cat(ret, addr);
		mrstrbuilder_cat(ret, " (alternative):\n");
		mrstrbuilder_cat(ret, fingerprint_unverified);
	}
}


/**
 * Get encryption info for a contact.
 * Get a multi-line encryption info, containing your fingerprint and the
 * fingerprint of the contact, used eg. to compare the fingerprints for a simple out-of-band verification.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @param contact_id ID of the contact to get the encryption info for.
 *
 * @return multi-line text, must be free()'d after usage.
 */
char* mrmailbox_get_contact_encrinfo(mrmailbox_t* mailbox, uint32_t contact_id)
{
	int             locked = 0;
	mrloginparam_t* loginparam = mrloginparam_new();
	mrcontact_t*    contact = mrcontact_new(mailbox);
	mrapeerstate_t* peerstate = mrapeerstate_new(mailbox);
	mrkey_t*        self_key = mrkey_new();
	char*           fingerprint_self = NULL;
	char*           fingerprint_other_verified = NULL;
	char*           fingerprint_other_unverified = NULL;
	char*           p;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	mrstrbuilder_t  ret;
	mrstrbuilder_init(&ret, 0);

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( !mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id) ) {
			goto cleanup;
		}
		mrapeerstate_load_by_addr__(peerstate, mailbox->m_sql, contact->m_addr);
		mrloginparam_read__(loginparam, mailbox->m_sql, "configured_");

		mrkey_load_self_public__(self_key, loginparam->m_addr, mailbox->m_sql);

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	if( mrapeerstate_peek_key(peerstate, MRV_NOT_VERIFIED) )
	{
		// E2E available :)
		p = mrstock_str(peerstate->m_prefer_encrypt == MRA_PE_MUTUAL? MR_STR_E2E_PREFERRED : MR_STR_E2E_AVAILABLE); mrstrbuilder_cat(&ret, p); free(p);

		if( self_key->m_binary == NULL ) {
			mrpgp_rand_seed(mailbox, peerstate->m_addr, strlen(peerstate->m_addr) /*just some random data*/);
			mrmailbox_ensure_secret_key_exists(mailbox);
			mrsqlite3_lock(mailbox->m_sql);
			locked = 1;
				mrkey_load_self_public__(self_key, loginparam->m_addr, mailbox->m_sql);
			mrsqlite3_unlock(mailbox->m_sql);
			locked = 0;
		}

		mrstrbuilder_cat(&ret, " ");
		p = mrstock_str(MR_STR_FINGERPRINTS); mrstrbuilder_cat(&ret, p); free(p);
		mrstrbuilder_cat(&ret, ":");

		fingerprint_self = mrkey_get_formatted_fingerprint(self_key);
		fingerprint_other_verified = mrkey_get_formatted_fingerprint(mrapeerstate_peek_key(peerstate, MRV_BIDIRECTIONAL));
		fingerprint_other_unverified = mrkey_get_formatted_fingerprint(mrapeerstate_peek_key(peerstate, MRV_NOT_VERIFIED));

		if( strcmp(loginparam->m_addr, peerstate->m_addr)<0 ) {
			cat_fingerprint(&ret, loginparam->m_addr, fingerprint_self, NULL);
			cat_fingerprint(&ret, peerstate->m_addr, fingerprint_other_verified, fingerprint_other_unverified);
		}
		else {
			cat_fingerprint(&ret, peerstate->m_addr, fingerprint_other_verified, fingerprint_other_unverified);
			cat_fingerprint(&ret, loginparam->m_addr, fingerprint_self, NULL);
		}
	}
	else
	{
		// No E2E available
		if( !(loginparam->m_server_flags&MR_IMAP_SOCKET_PLAIN)
		 && !(loginparam->m_server_flags&MR_SMTP_SOCKET_PLAIN) )
		{
			p = mrstock_str(MR_STR_ENCR_TRANSP); mrstrbuilder_cat(&ret, p); free(p);
		}
		else
		{
			p = mrstock_str(MR_STR_ENCR_NONE); mrstrbuilder_cat(&ret, p); free(p);
		}
	}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrapeerstate_unref(peerstate);
	mrcontact_unref(contact);
	mrloginparam_unref(loginparam);
	mrkey_unref(self_key);
	free(fingerprint_self);
	free(fingerprint_other_verified);
	free(fingerprint_other_unverified);
	return ret.m_buf;
}


/**
 * Delete a contact.  The contact is deleted from the local device.  It may happen that this is not
 * possible as the contact is in use.  In this case, the contact can be blocked.
 *
 * May result in a #MR_EVENT_CONTACTS_CHANGED event.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new().
 *
 * @param contact_id ID of the contact to delete.
 *
 * @return 1=success, 0=error
 */
int mrmailbox_delete_contact(mrmailbox_t* mailbox, uint32_t contact_id)
{
	int           locked = 0, success = 0;
	sqlite3_stmt* stmt;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || contact_id <= MR_CONTACT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		/* we can only delete contacts that are not in use anywhere; this function is mainly for the user who has just
		created an contact manually and wants to delete it a moment later */
		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_chats_contacts_WHERE_contact_id,
			"SELECT COUNT(*) FROM chats_contacts WHERE contact_id=?;");
		sqlite3_bind_int(stmt, 1, contact_id);
		if( sqlite3_step(stmt) != SQLITE_ROW || sqlite3_column_int(stmt, 0) >= 1 ) {
			goto cleanup;
		}

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_ft,
			"SELECT COUNT(*) FROM msgs WHERE from_id=? OR to_id=?;");
		sqlite3_bind_int(stmt, 1, contact_id);
		sqlite3_bind_int(stmt, 2, contact_id);
		if( sqlite3_step(stmt) != SQLITE_ROW || sqlite3_column_int(stmt, 0) >= 1 ) {
			goto cleanup;
		}

		stmt = mrsqlite3_predefine__(mailbox->m_sql, DELETE_FROM_contacts_WHERE_id,
			"DELETE FROM contacts WHERE id=?;");
		sqlite3_bind_int(stmt, 1, contact_id);
		if( sqlite3_step(stmt) != SQLITE_DONE ) {
			goto cleanup;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	mailbox->m_cb(mailbox, MR_EVENT_CONTACTS_CHANGED, 0, 0);

	success = 1;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	return success;
}


int mrmailbox_contact_addr_equals__(mrmailbox_t* mailbox, uint32_t contact_id, const char* other_addr)
{
	int addr_are_equal = 0;
	if( other_addr ) {
		mrcontact_t* contact = mrcontact_new(mailbox);
		if( mrcontact_load_from_db__(contact, mailbox->m_sql, contact_id) ) {
			if( contact->m_addr ) {
				if( strcasecmp(contact->m_addr, other_addr)==0 ) {
					addr_are_equal = 1;
				}
			}
		}
		mrcontact_unref(contact);
	}
	return addr_are_equal;
}



/*******************************************************************************
 * Handle Messages
 ******************************************************************************/


void mrmailbox_update_msg_chat_id__(mrmailbox_t* mailbox, uint32_t msg_id, uint32_t chat_id)
{
    sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_chat_id_WHERE_id,
		"UPDATE msgs SET chat_id=? WHERE id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, msg_id);
	sqlite3_step(stmt);
}


void mrmailbox_update_msg_state__(mrmailbox_t* mailbox, uint32_t msg_id, int state)
{
    sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_state_WHERE_id,
		"UPDATE msgs SET state=? WHERE id=?;");
	sqlite3_bind_int(stmt, 1, state);
	sqlite3_bind_int(stmt, 2, msg_id);
	sqlite3_step(stmt);
}


size_t mrmailbox_get_real_msg_cnt__(mrmailbox_t* mailbox)
{
	if( mailbox->m_sql->m_cobj==NULL ) {
		return 0;
	}

	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_assigned,
		"SELECT COUNT(*) "
		" FROM msgs m "
		" LEFT JOIN chats c ON c.id=m.chat_id "
		" WHERE m.id>" MR_STRINGIFY(MR_MSG_ID_LAST_SPECIAL)
		" AND m.chat_id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL)
		" AND c.blocked=0;");
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		mrsqlite3_log_error(mailbox->m_sql, "mr_get_assigned_msg_cnt_() failed.");
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


size_t mrmailbox_get_deaddrop_msg_cnt__(mrmailbox_t* mailbox)
{
	if( mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || mailbox->m_sql->m_cobj==NULL ) {
		return 0;
	}

	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_unassigned,
		"SELECT COUNT(*) FROM msgs m LEFT JOIN chats c ON c.id=m.chat_id WHERE c.blocked=2;");
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


int mrmailbox_rfc724_mid_cnt__(mrmailbox_t* mailbox, const char* rfc724_mid)
{
	if( mailbox==NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || mailbox->m_sql->m_cobj==NULL ) {
		return 0;
	}

	/* check the number of messages with the same rfc724_mid */
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_WHERE_rfc724_mid,
		"SELECT COUNT(*) FROM msgs WHERE rfc724_mid=?;");
	sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	return sqlite3_column_int(stmt, 0);
}


/* check, if the given Message-ID exists in the database (if not, the message is normally downloaded from the server and parsed,
so, we should even keep unuseful messages in the database (we can leave the other fields empty to save space) */
uint32_t mrmailbox_rfc724_mid_exists__(mrmailbox_t* mailbox, const char* rfc724_mid, char** ret_server_folder, uint32_t* ret_server_uid)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_ss_FROM_msgs_WHERE_m,
		"SELECT server_folder, server_uid, id FROM msgs WHERE rfc724_mid=?;");
	sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		if( ret_server_folder ) { *ret_server_folder = NULL; }
		if( ret_server_uid )    { *ret_server_uid    = 0; }
		return 0;
	}

	if( ret_server_folder ) { *ret_server_folder = safe_strdup((char*)sqlite3_column_text(stmt, 0)); }
	if( ret_server_uid )    { *ret_server_uid = sqlite3_column_int(stmt, 1); /* may be 0 */ }
	return sqlite3_column_int(stmt, 2);
}


void mrmailbox_update_server_uid__(mrmailbox_t* mailbox, const char* rfc724_mid, const char* server_folder, uint32_t server_uid)
{
	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_ss_WHERE_rfc724_mid,
		"UPDATE msgs SET server_folder=?, server_uid=? WHERE rfc724_mid=?;"); /* we update by "rfc724_mid" instead of "id" as there may be several db-entries refering to the same "rfc724_mid" */
	sqlite3_bind_text(stmt, 1, server_folder, -1, SQLITE_STATIC);
	sqlite3_bind_int (stmt, 2, server_uid);
	sqlite3_bind_text(stmt, 3, rfc724_mid, -1, SQLITE_STATIC);
	sqlite3_step(stmt);
}


/**
 * Get a single message object of the type mrmsg_t.
 * For a list of messages in a chat, see mrmailbox_get_chat_msgs()
 * For a list or chats, see mrmailbox_get_chatlist()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox Mailbox object as created by mrmailbox_new()
 *
 * @param msg_id The message ID for which the message object should be created.
 *
 * @return A mrmsg_t message object. When done, the object must be freed using mrmsg_unref()
 */
mrmsg_t* mrmailbox_get_msg(mrmailbox_t* mailbox, uint32_t msg_id)
{
	int success = 0;
	int db_locked = 0;
	mrmsg_t* obj = mrmsg_new();

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	db_locked = 1;

		if( !mrmsg_load_from_db__(obj, mailbox, msg_id) ) {
			goto cleanup;
		}

		success = 1;

cleanup:
	if( db_locked ) { mrsqlite3_unlock(mailbox->m_sql); }

	if( success ) {
		return obj;
	}
	else {
		mrmsg_unref(obj);
		return NULL;
	}
}


/**
 * Get an informational text for a single message. the text is multiline and may
 * contain eg. the raw text of the message.
 *
 * The max. text returned is typically longer (about 100000 characters) than the
 * max. text returned by mrmsg_get_text() (about 30000 characters).
 *
 * If the library is compiled for andoid, some basic html-formatting for he
 * subject and the footer is added. However we should change this function so
 * that it returns eg. an array of pairwise key-value strings and the caller
 * can show the whole stuff eg. in a table.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new().
 *
 * @param msg_id the message id for which information should be generated
 *
 * @return text string, must be free()'d after usage
 */
char* mrmailbox_get_msg_info(mrmailbox_t* mailbox, uint32_t msg_id)
{
	mrstrbuilder_t ret;
	int            locked = 0;
	sqlite3_stmt*  stmt;
	mrmsg_t*       msg = mrmsg_new();
	mrcontact_t*   contact_from = mrcontact_new(mailbox);
	char           *rawtxt = NULL, *p;

	mrstrbuilder_init(&ret, 0);

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		mrmsg_load_from_db__(msg, mailbox, msg_id);
		mrcontact_load_from_db__(contact_from, mailbox->m_sql, msg->m_from_id);

		stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_txt_raw_FROM_msgs_WHERE_id,
			"SELECT txt_raw FROM msgs WHERE id=?;");
		sqlite3_bind_int(stmt, 1, msg_id);
		if( sqlite3_step(stmt) != SQLITE_ROW ) {
			p = mr_mprintf("Cannot load message #%i.", (int)msg_id); mrstrbuilder_cat(&ret, p); free(p);
			goto cleanup;
		}

		rawtxt = safe_strdup((char*)sqlite3_column_text(stmt, 0));

		#ifdef __ANDROID__
			p = strchr(rawtxt, '\n');
			if( p ) {
				char* subject = rawtxt;
				*p = 0;
				p++;
				rawtxt = mr_mprintf("<b>%s</b>\n%s", subject, p);
				free(subject);
			}
		#endif

		mr_trim(rawtxt);
		mr_truncate_str(rawtxt, MR_MAX_GET_INFO_LEN);

		/* add time */
		mrstrbuilder_cat(&ret, "Sent: ");
		p = mr_timestamp_to_str(mrmsg_get_timestamp(msg)); mrstrbuilder_cat(&ret, p); free(p);
		mrstrbuilder_cat(&ret, "\n");

		if( msg->m_from_id != MR_CONTACT_ID_SELF ) {
			mrstrbuilder_cat(&ret, "Received: ");
			p = mr_timestamp_to_str(msg->m_timestamp_rcvd? msg->m_timestamp_rcvd : msg->m_timestamp); mrstrbuilder_cat(&ret, p); free(p);
			mrstrbuilder_cat(&ret, "\n");
		}

		if( msg->m_from_id == MR_CONTACT_ID_DEVICE || msg->m_to_id == MR_CONTACT_ID_DEVICE ) {
			goto cleanup; // device-internal message, no further details needed
		}

		/* add mdn's time and readers */
		stmt = mrsqlite3_prepare_v2_(mailbox->m_sql,
			"SELECT contact_id, timestamp_sent FROM msgs_mdns WHERE msg_id=?;");
		sqlite3_bind_int (stmt, 1, msg_id);
		while( sqlite3_step(stmt) == SQLITE_ROW ) {
			mrstrbuilder_cat(&ret, "Read: ");
			p = mr_timestamp_to_str(sqlite3_column_int64(stmt, 1)); mrstrbuilder_cat(&ret, p); free(p);
			mrstrbuilder_cat(&ret, " by ");

			mrcontact_t* contact = mrcontact_new(mailbox);
				mrcontact_load_from_db__(contact, mailbox->m_sql, sqlite3_column_int64(stmt, 0));
				p = mrcontact_get_display_name(contact); mrstrbuilder_cat(&ret, p); free(p);
			mrcontact_unref(contact);
			mrstrbuilder_cat(&ret, "\n");
		}
		sqlite3_finalize(stmt);

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* add state */
	p = NULL;
	switch( msg->m_state ) {
		case MR_STATE_IN_FRESH:      p = safe_strdup("Fresh");           break;
		case MR_STATE_IN_NOTICED:    p = safe_strdup("Noticed");         break;
		case MR_STATE_IN_SEEN:       p = safe_strdup("Seen");            break;
		case MR_STATE_OUT_DELIVERED: p = safe_strdup("Delivered");       break;
		case MR_STATE_OUT_ERROR:     p = safe_strdup("Error");           break;
		case MR_STATE_OUT_MDN_RCVD:  p = safe_strdup("Read");            break;
		case MR_STATE_OUT_PENDING:   p = safe_strdup("Pending");         break;
		default:                     p = mr_mprintf("%i", msg->m_state); break;
	}
	mrstrbuilder_catf(&ret, "State: %s", p);
	free(p);

	p = NULL;
	int e2ee_errors;
	if( (e2ee_errors=mrparam_get_int(msg->m_param, MRP_ERRONEOUS_E2EE, 0)) ) {
		if( e2ee_errors&MRE2EE_NO_VALID_SIGNATURE ) {
			p = safe_strdup("Encrypted, no valid signature");
		}
	}
	else if( mrparam_get_int(msg->m_param, MRP_GUARANTEE_E2EE, 0) ) {
		p = safe_strdup("Encrypted");
	}

	if( p ) {
		mrstrbuilder_catf(&ret, ", %s", p);
		free(p);
	}
	mrstrbuilder_cat(&ret, "\n");

	/* add sender (only for info messages as the avatar may not be shown for them) */
	if( mrmsg_is_info(msg) ) {
		mrstrbuilder_cat(&ret, "Sender: ");
		p = mrcontact_get_name_n_addr(contact_from); mrstrbuilder_cat(&ret, p); free(p);
		mrstrbuilder_cat(&ret, "\n");
	}

	/* add file info */
	char* file = mrparam_get(msg->m_param, MRP_FILE, NULL);
	if( file ) {
		p = mr_mprintf("\nFile: %s, %i bytes\n", file, (int)mr_get_filebytes(file)); mrstrbuilder_cat(&ret, p); free(p);
	}

	if( msg->m_type != MR_MSG_TEXT ) {
		p = NULL;
		switch( msg->m_type )  {
			case MR_MSG_AUDIO: p = safe_strdup("Audio");          break;
			case MR_MSG_FILE:  p = safe_strdup("File");           break;
			case MR_MSG_GIF:   p = safe_strdup("GIF");            break;
			case MR_MSG_IMAGE: p = safe_strdup("Image");          break;
			case MR_MSG_VIDEO: p = safe_strdup("Video");          break;
			case MR_MSG_VOICE: p = safe_strdup("Voice");          break;
			default:           p = mr_mprintf("%i", msg->m_type); break;
		}
		mrstrbuilder_catf(&ret, "Type: %s\n", p);
		free(p);
	}

	int w = mrparam_get_int(msg->m_param, MRP_WIDTH, 0), h = mrparam_get_int(msg->m_param, MRP_HEIGHT, 0);
	if( w != 0 || h != 0 ) {
		p = mr_mprintf("Dimension: %i x %i\n", w, h); mrstrbuilder_cat(&ret, p); free(p);
	}

	int duration = mrparam_get_int(msg->m_param, MRP_DURATION, 0);
	if( duration != 0 ) {
		p = mr_mprintf("Duration: %i ms\n", duration); mrstrbuilder_cat(&ret, p); free(p);
	}

	/* add rawtext */
	if( rawtxt && rawtxt[0] ) {
		mrstrbuilder_cat(&ret, "\n");
		mrstrbuilder_cat(&ret, rawtxt);
		mrstrbuilder_cat(&ret, "\n");
	}

	/* add Message-ID, Server-Folder and Server-UID; the database ID is normally only of interest if you have access to sqlite; if so you can easily get it from the "msgs" table. */
	#ifdef __ANDROID__
		mrstrbuilder_cat(&ret, "<c#808080>");
	#endif

	if( msg->m_rfc724_mid && msg->m_rfc724_mid[0] ) {
		mrstrbuilder_catf(&ret, "\nMessage-ID: %s", msg->m_rfc724_mid);
	}

	if( msg->m_server_folder && msg->m_server_folder[0] ) {
		mrstrbuilder_catf(&ret, "\nLast seen as: %s/%i", msg->m_server_folder, (int)msg->m_server_uid);
	}

	#ifdef __ANDROID__
		mrstrbuilder_cat(&ret, "</c>");
	#endif

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrmsg_unref(msg);
	mrcontact_unref(contact_from);
	free(rawtxt);
	return ret.m_buf;
}


/**
 * Forward messages to another chat.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new()
 *
 * @param msg_ids an array of uint32_t containing all message IDs that should be forwarded
 *
 * @param msg_cnt the number of messages IDs in the msg_ids array
 *
 * @param chat_id The destination chat ID.
 *
 * @return none
 */
void mrmailbox_forward_msgs(mrmailbox_t* mailbox, const uint32_t* msg_ids, int msg_cnt, uint32_t chat_id)
{
	mrmsg_t*      msg = mrmsg_new();
	mrchat_t*     chat = mrchat_new(mailbox);
	mrcontact_t*  contact = mrcontact_new(mailbox);
	int           locked = 0, transaction_pending = 0;
	carray*       created_db_entries = carray_new(16);
	char*         idsstr = NULL, *q3 = NULL;
	sqlite3_stmt* stmt = NULL;
	time_t        curr_timestamp;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || msg_ids==NULL || msg_cnt <= 0 || chat_id <= MR_CHAT_ID_LAST_SPECIAL ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;
	mrsqlite3_begin_transaction__(mailbox->m_sql);
	transaction_pending = 1;

		mrmailbox_unarchive_chat__(mailbox, chat_id);

		mailbox->m_smtp->m_log_connect_errors = 1;

		if( !mrchat_load_from_db__(chat, chat_id) ) {
			goto cleanup;
		}

		curr_timestamp = mr_create_smeared_timestamps__(msg_cnt);

		idsstr = mr_arr_to_string(msg_ids, msg_cnt);
		q3 = sqlite3_mprintf("SELECT id FROM msgs WHERE id IN(%s) ORDER BY timestamp,id", idsstr);
		stmt = mrsqlite3_prepare_v2_(mailbox->m_sql, q3);
		while( sqlite3_step(stmt)==SQLITE_ROW )
		{
			int src_msg_id = sqlite3_column_int(stmt, 0);
			if( !mrmsg_load_from_db__(msg, mailbox, src_msg_id) ) {
				goto cleanup;
			}

			mrparam_set_int(msg->m_param, MRP_FORWARDED, 1);
			mrparam_set    (msg->m_param, MRP_GUARANTEE_E2EE, NULL);
			mrparam_set    (msg->m_param, MRP_FORCE_PLAINTEXT, NULL);

			uint32_t new_msg_id = mrmailbox_send_msg_i__(mailbox, chat, msg, curr_timestamp++);
			carray_add(created_db_entries, (void*)(uintptr_t)chat_id, NULL);
			carray_add(created_db_entries, (void*)(uintptr_t)new_msg_id, NULL);
		}

	mrsqlite3_commit__(mailbox->m_sql);
	transaction_pending = 0;

cleanup:
	if( transaction_pending ) { mrsqlite3_rollback__(mailbox->m_sql); }
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	if( created_db_entries ) {
		size_t i, icnt = carray_count(created_db_entries);
		for( i = 0; i < icnt; i += 2 ) {
			mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, (uintptr_t)carray_get(created_db_entries, i), (uintptr_t)carray_get(created_db_entries, i+1));
		}
		carray_free(created_db_entries);
	}
	mrcontact_unref(contact);
	mrmsg_unref(msg);
	mrchat_unref(chat);
	if( stmt ) { sqlite3_finalize(stmt); }
	free(idsstr);
	if( q3 ) { sqlite3_free(q3); }
}


/**
 * Star/unstar messages by setting the last parameter to 0 (unstar) or 1 (star).
 * Starred messages are collected in a virtual chat that can be shown using
 * mrmailbox_get_chat_msgs() using the chat_id MR_CHAT_ID_STARRED.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object as created by mrmailbox_new()
 *
 * @param msg_ids An array of uint32_t message IDs defining the messages to star or unstar
 *
 * @param msg_cnt The number of IDs in msg_ids
 *
 * @param star 0=unstar the messages in msg_ids, 1=star them
 *
 * @return none
 */
void mrmailbox_star_msgs(mrmailbox_t* mailbox, const uint32_t* msg_ids, int msg_cnt, int star)
{
	int i;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || msg_ids == NULL || msg_cnt <= 0 || (star!=0 && star!=1) ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);
	mrsqlite3_begin_transaction__(mailbox->m_sql);

		for( i = 0; i < msg_cnt; i++ )
		{
			sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, UPDATE_msgs_SET_starred_WHERE_id,
				"UPDATE msgs SET starred=? WHERE id=?;");
			sqlite3_bind_int(stmt, 1, star);
			sqlite3_bind_int(stmt, 2, msg_ids[i]);
			sqlite3_step(stmt);
		}

	mrsqlite3_commit__(mailbox->m_sql);
	mrsqlite3_unlock(mailbox->m_sql);
}


/*******************************************************************************
 * Delete messages
 ******************************************************************************/


/* internal function */
void mrmailbox_delete_msg_on_imap(mrmailbox_t* mailbox, mrjob_t* job)
{
	int      locked = 0, delete_from_server = 1;
	mrmsg_t* msg = mrmsg_new();

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( !mrmsg_load_from_db__(msg, mailbox, job->m_foreign_id)
		 || msg->m_rfc724_mid == NULL || msg->m_rfc724_mid[0] == 0 /* eg. device messages have no Message-ID */ ) {
			goto cleanup;
		}

		if( mrmailbox_rfc724_mid_cnt__(mailbox, msg->m_rfc724_mid) != 1 ) {
			mrmailbox_log_info(mailbox, 0, "The message is deleted from the server when all parts are deleted.");
			delete_from_server = 0;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* if this is the last existing part of the message, we delete the message from the server */
	if( delete_from_server )
	{
		if( !mrimap_is_connected(mailbox->m_imap) ) {
			mrmailbox_connect_to_imap(mailbox, NULL);
			if( !mrimap_is_connected(mailbox->m_imap) ) {
				mrjob_try_again_later(job, MR_STANDARD_DELAY);
				goto cleanup;
			}
		}

		if( !mrimap_delete_msg(mailbox->m_imap, msg->m_rfc724_mid, msg->m_server_folder, msg->m_server_uid) )
		{
			mrjob_try_again_later(job, MR_STANDARD_DELAY);
			goto cleanup;
		}
	}

	/* we delete the database entry ...
	- if the message is successfully removed from the server
	- or if there are other parts of the message in the database (in this case we have not deleted if from the server)
	(As long as the message is not removed from the IMAP-server, we need at least one database entry to avoid a re-download) */
	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, DELETE_FROM_msgs_WHERE_id,
			"DELETE FROM msgs WHERE id=?;");
		sqlite3_bind_int(stmt, 1, msg->m_id);
		sqlite3_step(stmt);

		stmt = mrsqlite3_predefine__(mailbox->m_sql, DELETE_FROM_msgs_mdns_WHERE_m,
			"DELETE FROM msgs_mdns WHERE msg_id=?;");
		sqlite3_bind_int(stmt, 1, msg->m_id);
		sqlite3_step(stmt);

		char* pathNfilename = mrparam_get(msg->m_param, MRP_FILE, NULL);
		if( pathNfilename ) {
			if( strncmp(mailbox->m_blobdir, pathNfilename, strlen(mailbox->m_blobdir))==0 )
			{
				char* strLikeFilename = mr_mprintf("%%f=%s%%", pathNfilename);
				sqlite3_stmt* stmt2 = mrsqlite3_prepare_v2_(mailbox->m_sql, "SELECT id FROM msgs WHERE type!=? AND param LIKE ?;"); /* if this gets too slow, an index over "type" should help. */
				sqlite3_bind_int (stmt2, 1, MR_MSG_TEXT);
				sqlite3_bind_text(stmt2, 2, strLikeFilename, -1, SQLITE_STATIC);
				int file_used_by_other_msgs = (sqlite3_step(stmt2)==SQLITE_ROW)? 1 : 0;
				free(strLikeFilename);
				sqlite3_finalize(stmt2);

				if( !file_used_by_other_msgs )
				{
					mr_delete_file(pathNfilename, mailbox);

					char* increation_file = mr_mprintf("%s.increation", pathNfilename);
					mr_delete_file(increation_file, mailbox);
					free(increation_file);

					char* filenameOnly = mr_get_filename(pathNfilename);
					if( msg->m_type==MR_MSG_VOICE ) {
						char* waveform_file = mr_mprintf("%s/%s.waveform", mailbox->m_blobdir, filenameOnly);
						mr_delete_file(waveform_file, mailbox);
						free(waveform_file);
					}
					else if( msg->m_type==MR_MSG_VIDEO ) {
						char* preview_file = mr_mprintf("%s/%s-preview.jpg", mailbox->m_blobdir, filenameOnly);
						mr_delete_file(preview_file, mailbox);
						free(preview_file);
					}
					free(filenameOnly);
				}
			}
			free(pathNfilename);
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrmsg_unref(msg);
}


/**
 * Delete messages. The messages are deleted on the current device and
 * on the IMAP server.
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox the mailbox object as created by mrmailbox_new()
 *
 * @param msg_ids an array of uint32_t containing all message IDs that should be deleted
 *
 * @param msg_cnt the number of messages IDs in the msg_ids array
 *
 * @return none
 */
void mrmailbox_delete_msgs(mrmailbox_t* mailbox, const uint32_t* msg_ids, int msg_cnt)
{
	int i;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || msg_ids == NULL || msg_cnt <= 0 ) {
		return;
	}

	mrsqlite3_lock(mailbox->m_sql);
	mrsqlite3_begin_transaction__(mailbox->m_sql);

		for( i = 0; i < msg_cnt; i++ )
		{
			mrmailbox_update_msg_chat_id__(mailbox, msg_ids[i], MR_CHAT_ID_TRASH);
			mrjob_add__(mailbox, MRJ_DELETE_MSG_ON_IMAP, msg_ids[i], NULL, 0); /* results in a call to mrmailbox_delete_msg_on_imap() */
		}

	mrsqlite3_commit__(mailbox->m_sql);
	mrsqlite3_unlock(mailbox->m_sql);
}


/*******************************************************************************
 * mark message as seen
 ******************************************************************************/


void mrmailbox_markseen_msg_on_imap(mrmailbox_t* mailbox, mrjob_t* job)
{
	int      locked = 0;
	mrmsg_t* msg = mrmsg_new();
	char*    new_server_folder = NULL;
	uint32_t new_server_uid = 0;
	int      in_ms_flags = 0, out_ms_flags = 0;

	if( !mrimap_is_connected(mailbox->m_imap) ) {
		mrmailbox_connect_to_imap(mailbox, NULL);
		if( !mrimap_is_connected(mailbox->m_imap) ) {
			mrjob_try_again_later(job, MR_STANDARD_DELAY);
			goto cleanup;
		}
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;

		if( !mrmsg_load_from_db__(msg, mailbox, job->m_foreign_id) ) {
			goto cleanup;
		}

		/* add an additional job for sending the MDN (here in a thread for fast ui resonses) (an extra job as the MDN has a lower priority) */
		if( mrparam_get_int(msg->m_param, MRP_WANTS_MDN, 0) /* MRP_WANTS_MDN is set only for one part of a multipart-message */
		 && mrsqlite3_get_config_int__(mailbox->m_sql, "mdns_enabled", MR_MDNS_DEFAULT_ENABLED) ) {
			in_ms_flags |= MR_MS_SET_MDNSent_FLAG;
		}

	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	if( msg->m_is_msgrmsg ) {
		in_ms_flags |= MR_MS_ALSO_MOVE;
	}

	if( mrimap_markseen_msg(mailbox->m_imap, msg->m_server_folder, msg->m_server_uid,
		   in_ms_flags, &new_server_folder, &new_server_uid, &out_ms_flags) != 0 )
	{
		if( (new_server_folder && new_server_uid) || out_ms_flags&MR_MS_MDNSent_JUST_SET )
		{
			mrsqlite3_lock(mailbox->m_sql);
			locked = 1;

				if( new_server_folder && new_server_uid )
				{
					mrmailbox_update_server_uid__(mailbox, msg->m_rfc724_mid, new_server_folder, new_server_uid);
				}

				if( out_ms_flags&MR_MS_MDNSent_JUST_SET )
				{
					mrjob_add__(mailbox, MRJ_SEND_MDN, msg->m_id, NULL, 0); /* results in a call to mrmailbox_send_mdn() */
				}

			mrsqlite3_unlock(mailbox->m_sql);
			locked = 0;
		}
	}
	else
	{
		mrjob_try_again_later(job, MR_STANDARD_DELAY);
	}

cleanup:
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
	mrmsg_unref(msg);
	free(new_server_folder);
}


void mrmailbox_markseen_mdn_on_imap(mrmailbox_t* mailbox, mrjob_t* job)
{
	char*    server_folder = mrparam_get    (job->m_param, MRP_SERVER_FOLDER, NULL);
	uint32_t server_uid    = mrparam_get_int(job->m_param, MRP_SERVER_UID, 0);
	char*    new_server_folder = NULL;
	uint32_t new_server_uid    = 0;
	int      out_ms_flags = 0;

	if( !mrimap_is_connected(mailbox->m_imap) ) {
		mrmailbox_connect_to_imap(mailbox, NULL);
		if( !mrimap_is_connected(mailbox->m_imap) ) {
			mrjob_try_again_later(job, MR_STANDARD_DELAY);
			goto cleanup;
		}
	}

	if( mrimap_markseen_msg(mailbox->m_imap, server_folder, server_uid, MR_MS_ALSO_MOVE, &new_server_folder, &new_server_uid, &out_ms_flags) == 0 ) {
		mrjob_try_again_later(job, MR_STANDARD_DELAY);
	}

cleanup:
	free(server_folder);
	free(new_server_folder);
}


/**
 * Mark a message as _seen_, updates the IMAP state and
 * sends MDNs. if the message is not in a real chat (eg. a contact request), the
 * message is only marked as NOTICED and no IMAP/MDNs is done.  See also
 * mrmailbox_marknoticed_chat() and mrmailbox_marknoticed_contact()
 *
 * @memberof mrmailbox_t
 *
 * @param mailbox The mailbox object.
 *
 * @param msg_ids an array of uint32_t containing all the messages IDs that should be marked as seen.
 *
 * @param msg_cnt The number of message IDs in msg_ids.
 *
 * @return none
 */
void mrmailbox_markseen_msgs(mrmailbox_t* mailbox, const uint32_t* msg_ids, int msg_cnt)
{
	int locked = 0, transaction_pending = 0;
	int i, send_event = 0;
	int curr_state = 0, curr_blocked = 0;

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || msg_ids == NULL || msg_cnt <= 0 ) {
		goto cleanup;
	}

	mrsqlite3_lock(mailbox->m_sql);
	locked = 1;
	mrsqlite3_begin_transaction__(mailbox->m_sql);
	transaction_pending = 1;

		for( i = 0; i < msg_cnt; i++ )
		{
			sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_state_blocked_FROM_msgs_LEFT_JOIN_chats_WHERE_id,
				"SELECT m.state, c.blocked "
				" FROM msgs m "
				" LEFT JOIN chats c ON c.id=m.chat_id "
				" WHERE m.id=? AND m.chat_id>" MR_STRINGIFY(MR_CHAT_ID_LAST_SPECIAL));
			sqlite3_bind_int(stmt, 1, msg_ids[i]);
			if( sqlite3_step(stmt) != SQLITE_ROW ) {
				goto cleanup;
			}
			curr_state   = sqlite3_column_int(stmt, 0);
			curr_blocked = sqlite3_column_int(stmt, 1);
			if( curr_blocked == 0 )
			{
				if( curr_state == MR_STATE_IN_FRESH || curr_state == MR_STATE_IN_NOTICED ) {
					mrmailbox_update_msg_state__(mailbox, msg_ids[i], MR_STATE_IN_SEEN);
					mrmailbox_log_info(mailbox, 0, "Seen message #%i.", msg_ids[i]);
					mrjob_add__(mailbox, MRJ_MARKSEEN_MSG_ON_IMAP, msg_ids[i], NULL, 0); /* results in a call to mrmailbox_markseen_msg_on_imap() */
					send_event = 1;
				}
			}
			else
			{
				/* message may be in contact requests, mark as NOTICED, this does not force IMAP updated nor send MDNs */
				if( curr_state == MR_STATE_IN_FRESH ) {
					mrmailbox_update_msg_state__(mailbox, msg_ids[i], MR_STATE_IN_NOTICED);
					send_event = 1;
				}
			}
		}

	mrsqlite3_commit__(mailbox->m_sql);
	transaction_pending = 0;
	mrsqlite3_unlock(mailbox->m_sql);
	locked = 0;

	/* the event is needed eg. to remove the deaddrop from the chatlist */
	if( send_event ) {
		mailbox->m_cb(mailbox, MR_EVENT_MSGS_CHANGED, 0, 0);
	}

cleanup:
	if( transaction_pending ) { mrsqlite3_rollback__(mailbox->m_sql); }
	if( locked ) { mrsqlite3_unlock(mailbox->m_sql); }
}


int mrmailbox_mdn_from_ext__(mrmailbox_t* mailbox, uint32_t from_id, const char* rfc724_mid, time_t timestamp_sent,
                                     uint32_t* ret_chat_id,
                                     uint32_t* ret_msg_id)
{
	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || from_id <= MR_CONTACT_ID_LAST_SPECIAL || rfc724_mid == NULL || ret_chat_id==NULL || ret_msg_id==NULL
	 || *ret_chat_id != 0 || *ret_msg_id != 0 ) {
		return 0;
	}

	sqlite3_stmt* stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_it_FROM_msgs_JOIN_chats_WHERE_rfc724,
		"SELECT m.id, c.id, c.type, m.state FROM msgs m "
		" LEFT JOIN chats c ON m.chat_id=c.id "
		" WHERE rfc724_mid=? AND from_id=1 "
		" ORDER BY m.id;"); /* the ORDER BY makes sure, if one rfc724_mid is splitted into its parts, we always catch the same one. However, we do not send multiparts, we do not request MDNs for multiparts, and should not receive read requests for multiparts. So this is currently more theoretical. */
	sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0;
	}

	*ret_msg_id    = sqlite3_column_int(stmt, 0);
	*ret_chat_id   = sqlite3_column_int(stmt, 1);
	int chat_type  = sqlite3_column_int(stmt, 2);
	int msg_state  = sqlite3_column_int(stmt, 3);

	if( msg_state!=MR_STATE_OUT_PENDING && msg_state!=MR_STATE_OUT_DELIVERED ) {
		return 0; /* eg. already marked as MDNS_RCVD. however, it is importent, that the message ID is set above as this will allow the caller eg. to move the message away */
	}

	// collect receipt senders, we do this also for normal chats as we may want to show the timestamp
	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_c_FROM_msgs_mdns_WHERE_mc,
		"SELECT contact_id FROM msgs_mdns WHERE msg_id=? AND contact_id=?;");
	sqlite3_bind_int(stmt, 1, *ret_msg_id);
	sqlite3_bind_int(stmt, 2, from_id);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		stmt = mrsqlite3_predefine__(mailbox->m_sql, INSERT_INTO_msgs_mdns,
			"INSERT INTO msgs_mdns (msg_id, contact_id, timestamp_sent) VALUES (?, ?, ?);");
		sqlite3_bind_int  (stmt, 1, *ret_msg_id);
		sqlite3_bind_int  (stmt, 2, from_id);
		sqlite3_bind_int64(stmt, 3, timestamp_sent);
		sqlite3_step(stmt);
	}

	// Normal chat? that's quite easy.
	if( chat_type == MR_CHAT_TYPE_SINGLE ) {
		mrmailbox_update_msg_state__(mailbox, *ret_msg_id, MR_STATE_OUT_MDN_RCVD);
		return 1; /* send event about new state */
	}

	// Group chat: get the number of receipt senders
	stmt = mrsqlite3_predefine__(mailbox->m_sql, SELECT_COUNT_FROM_msgs_mdns_WHERE_m,
		"SELECT COUNT(*) FROM msgs_mdns WHERE msg_id=?;");
	sqlite3_bind_int(stmt, 1, *ret_msg_id);
	if( sqlite3_step(stmt) != SQLITE_ROW ) {
		return 0; /* error */
	}
	int ist_cnt  = sqlite3_column_int(stmt, 0);

	/*
	Groupsize:  Min. MDNs

	1 S         n/a
	2 SR        1
	3 SRR       2
	4 SRRR      2
	5 SRRRR     3
	6 SRRRRR    3

	(S=Sender, R=Recipient)
	*/
	int soll_cnt = (mrmailbox_get_chat_contact_count__(mailbox, *ret_chat_id)+1/*for rounding, SELF is already included!*/) / 2;
	if( ist_cnt < soll_cnt ) {
		return 0; /* wait for more receipts */
	}

	/* got enough receipts :-) */
	mrmailbox_update_msg_state__(mailbox, *ret_msg_id, MR_STATE_OUT_MDN_RCVD);
	return 1;
}


void mrmailbox_send_mdn(mrmailbox_t* mailbox, mrjob_t* job)
{
	mrmimefactory_t mimefactory;
	mrmimefactory_init(&mimefactory, mailbox);

	if( mailbox == NULL || mailbox->m_magic != MR_MAILBOX_MAGIC || job == NULL ) {
		return;
	}

	/* connect to SMTP server, if not yet done */
	if( !mrsmtp_is_connected(mailbox->m_smtp) )
	{
		mrloginparam_t* loginparam = mrloginparam_new();
			mrsqlite3_lock(mailbox->m_sql);
				mrloginparam_read__(loginparam, mailbox->m_sql, "configured_");
			mrsqlite3_unlock(mailbox->m_sql);
			int connected = mrsmtp_connect(mailbox->m_smtp, loginparam);
		mrloginparam_unref(loginparam);
		if( !connected ) {
			mrjob_try_again_later(job, MR_STANDARD_DELAY);
			goto cleanup;
		}
	}

    if( !mrmimefactory_load_mdn(&mimefactory, job->m_foreign_id)
     || !mrmimefactory_render(&mimefactory) ) {
		goto cleanup;
    }

	//char* t1=mr_null_terminate(mimefactory.m_out->str,mimefactory.m_out->len);printf("~~~~~MDN~~~~~\n%s\n~~~~~/MDN~~~~~",t1);free(t1); // DEBUG OUTPUT

	if( !mrsmtp_send_msg(mailbox->m_smtp, mimefactory.m_recipients_addr, mimefactory.m_out->str, mimefactory.m_out->len) ) {
		mrsmtp_disconnect(mailbox->m_smtp);
		mrjob_try_again_later(job, MR_AT_ONCE); /* MR_AT_ONCE is only the _initial_ delay, if the second try failes, the delay gets larger */
		goto cleanup;
	}

cleanup:
	mrmimefactory_empty(&mimefactory);
}

