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
#include <sys/types.h>
#include <unistd.h>
#include <openssl/opensslv.h>
#include <assert.h>
#include "dc_context.h"
#include "dc_imap.h"
#include "dc_smtp.h"
#include "dc_openssl.h"
#include "dc_mimefactory.h"
#include "dc_tools.h"
#include "dc_job.h"
#include "dc_key.h"
#include "dc_pgp.h"
#include "dc_apeerstate.h"


/**
 * A callback function that is used if no user-defined callback is given to dc_context_new().
 * The callback function simply returns 0 which is safe for every event.
 *
 * @private @memberof dc_context_t
 */
static uintptr_t cb_dummy(dc_context_t* context, int event, uintptr_t data1, uintptr_t data2)
{
	return 0;
}


/**
 * The following three callback are given to dc_imap_new() to read/write configuration
 * and to handle received messages. As the imap-functions are typically used in
 * a separate user-thread, also these functions may be called from a different thread.
 *
 * @private @memberof dc_context_t
 */
static char* cb_get_config(dc_imap_t* imap, const char* key, const char* def)
{
	dc_context_t* context = (dc_context_t*)imap->userData;
	return dc_sqlite3_get_config(context->sql, key, def);
}


static void cb_set_config(dc_imap_t* imap, const char* key, const char* value)
{
	dc_context_t* context = (dc_context_t*)imap->userData;
	dc_sqlite3_set_config(context->sql, key, value);
}


static void cb_receive_imf(dc_imap_t* imap, const char* imf_raw_not_terminated, size_t imf_raw_bytes, const char* server_folder, uint32_t server_uid, uint32_t flags)
{
	dc_context_t* context = (dc_context_t*)imap->userData;
	dc_receive_imf(context, imf_raw_not_terminated, imf_raw_bytes, server_folder, server_uid, flags);
}


/**
 * Create a new context object.  After creation it is usually
 * opened, connected and mails are fetched.
 *
 * @memberof dc_context_t
 * @param cb a callback function that is called for events (update,
 *     state changes etc.) and to get some information form the client (eg. translation
 *     for a given string).
 *     See @ref DC_EVENT for a list of possible events that may be passed to the callback.
 *     - The callback MAY be called from _any_ thread, not only the main/GUI thread!
 *     - The callback MUST NOT call any dc_* and related functions unless stated
 *       otherwise!
 *     - The callback SHOULD return _fast_, for GUI updates etc. you should
 *       post yourself an asynchronous message to your GUI thread, if needed.
 *     - If not mentioned otherweise, the callback should return 0.
 * @param userdata can be used by the client for any purpuse.  He finds it
 *     later in dc_get_userdata().
 * @param os_name is only for decorative use and is shown eg. in the `X-Mailer:` header
 *     in the form "Delta Chat <version> for <os_name>".
 *     You can give the name of the operating system and/or the used environment here.
 *     It is okay to give NULL, in this case `X-Mailer:` header is set to "Delta Chat <version>".
 * @return a context object with some public members the object must be passed to the other context functions
 *     and the object must be freed using dc_context_unref() after usage.
 */
dc_context_t* dc_context_new(dc_callback_t cb, void* userdata, const char* os_name)
{
	dc_context_t* context = NULL;

	if ((context=calloc(1, sizeof(dc_context_t)))==NULL) {
		exit(23); /* cannot allocate little memory, unrecoverable error */
	}

	pthread_mutex_init(&context->smear_critical, NULL);
	pthread_mutex_init(&context->bobs_qr_critical, NULL);
	pthread_mutex_init(&context->log_ringbuf_critical, NULL);
	pthread_mutex_init(&context->imapidle_condmutex, NULL);
	pthread_mutex_init(&context->smtpidle_condmutex, NULL);
	pthread_cond_init(&context->smtpidle_cond, NULL);

	context->magic    = DC_CONTEXT_MAGIC;
	context->userdata = userdata;
	context->cb       = cb? cb : cb_dummy;
	context->os_name  = dc_strdup_keep_null(os_name);
	context->shall_stop_ongoing = 1; /* the value 1 avoids dc_stop_ongoing_process() from stopping already stopped threads */

	dc_openssl_init(); // OpenSSL is used by libEtPan and by netpgp, init before using these parts.

	dc_pgp_init();
	context->sql      = dc_sqlite3_new(context);
	context->imap     = dc_imap_new(cb_get_config, cb_set_config, cb_receive_imf, (void*)context, context);
	context->smtp     = dc_smtp_new(context);

	/* Random-seed.  An additional seed with more random data is done just before key generation
	(the timespan between this call and the key generation time is typically random.
	Moreover, later, we add a hash of the first message data to the random-seed
	(it would be okay to seed with even more sensible data, the seed values cannot be recovered from the PRNG output, see OpenSSL's RAND_seed()) */
	uintptr_t seed[5];
	seed[0] = (uintptr_t)time(NULL);     /* time */
	seed[1] = (uintptr_t)seed;           /* stack */
	seed[2] = (uintptr_t)context;        /* heap */
	seed[3] = (uintptr_t)pthread_self(); /* thread ID */
	seed[4] = (uintptr_t)getpid();       /* process ID */
	dc_pgp_rand_seed(context, seed, sizeof(seed));

	return context;
}


/**
 * Free a context object.
 * If app runs can only be terminated by a forced kill, this may be superfluous.
 * Before the context object is freed, connections to SMTP, IMAP and database
 * are closed. You can also do this explicitly by calling dc_close() on your own
 * before calling dc_context_unref().
 *
 * @memberof dc_context_t
 * @param context the context object as created by dc_context_new().
 * @return none
 */
void dc_context_unref(dc_context_t* context)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return;
	}

	dc_pgp_exit();

	if (dc_is_open(context)) {
		dc_close(context);
	}

	dc_imap_unref(context->imap);
	dc_smtp_unref(context->smtp);
	dc_sqlite3_unref(context->sql);

	dc_openssl_exit();

	pthread_mutex_destroy(&context->smear_critical);
	pthread_mutex_destroy(&context->bobs_qr_critical);
	pthread_mutex_destroy(&context->log_ringbuf_critical);
	pthread_mutex_destroy(&context->imapidle_condmutex);
	pthread_cond_destroy(&context->smtpidle_cond);
	pthread_mutex_destroy(&context->smtpidle_condmutex);

	for (int i = 0; i < DC_LOG_RINGBUF_SIZE; i++) {
		free(context->log_ringbuf[i]);
	}

	free(context->os_name);
	context->magic = 0;
	free(context);
}


/**
 * Get user data associated with a context object.
 *
 * @memberof dc_context_t
 * @param context the context object as created by dc_context_new().
 * @return User data, this is the second parameter given to dc_context_new().
 */
void* dc_get_userdata(dc_context_t* context)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return NULL;
	}
	return context->userdata;
}


/**
 * This function reads some simple integer flags for fast and easy access.
 * To keep multi-thread-safety, we must not cache strings this way.
 * The function is called by dc_config_set*() and by dc_open().
 *
 * @private @memberof dc_context_t
 */
static void update_config_cache(dc_context_t* context, const char* key)
{
	if (key==NULL || strcmp(key, "e2ee_enabled")==0) {
		context->e2ee_enabled = dc_sqlite3_get_config_int(context->sql, "e2ee_enabled", DC_E2EE_DEFAULT_ENABLED);
	}
}


/**
 * Open context database.  If the given file does not exist, it is
 * created and can be set up using dc_set_config() afterwards.
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new().
 * @param dbfile The file to use to store the database, sth. like `~/file` won't
 *     work on all systems, if in doubt, use absolute paths.
 * @param blobdir A directory to store the blobs in. The trailing slash is added
 *     by deltachat-core, so if you want to avoid double slashes, do not add one.
 *     If you pass NULL or the empty string, deltachat-core creates a directory
 *     beside _dbfile_ with the same name and the suffix `-blobs`.
 * @return 1 on success, 0 on failure
 */
int dc_open(dc_context_t* context, const char* dbfile, const char* blobdir)
{
	int success = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || dbfile==NULL) {
		goto cleanup;
	}

	/* Open() sets up the object and connects to the given database
	from which all configuration is read/written to. */

	/* Create/open sqlite database */
	if (!dc_sqlite3_open(context->sql, dbfile, 0)) {
		goto cleanup;
	}

	/* backup dbfile name */
	context->dbfile = dc_strdup(dbfile);

	/* set blob-directory
	(to avoid double slashed, the given directory should not end with an slash) */
	if (blobdir && blobdir[0]) {
		context->blobdir = dc_strdup(blobdir);
	}
	else {
		context->blobdir = dc_mprintf("%s-blobs", dbfile);
		dc_create_folder(context->blobdir, context);
	}

	update_config_cache(context, NULL);

	success = 1;

cleanup:
	if (!success) {
		if (dc_sqlite3_is_open(context->sql)) {
			dc_sqlite3_close(context->sql);
		}
	}

	return success;
}


/**
 * Close context database opened by dc_open().
 * Before this, connections to SMTP and IMAP are closed; these connections
 * are started automatically as needed eg. by sending for fetching messages.
 * This function is also implicitly called by dc_context_unref().
 * Multiple calls to this functions are okay, the function takes care not
 * to free objects twice.
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new().
 * @return None.
 */
void dc_close(dc_context_t* context)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return;
	}

	dc_imap_disconnect(context->imap);
	dc_smtp_disconnect(context->smtp);

	if (dc_sqlite3_is_open(context->sql)) {
		dc_sqlite3_close(context->sql);
	}

	free(context->dbfile);
	context->dbfile = NULL;

	free(context->blobdir);
	context->blobdir = NULL;
}


/**
 * Check if the context database is open.
 *
 * @memberof dc_context_t
 * @param context the context object as created by dc_context_new().
 * @return 0=context is not open, 1=context is open.
 */
int dc_is_open(const dc_context_t* context)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return 0; /* error - database not opened */
	}

	return dc_sqlite3_is_open(context->sql);
}


/**
 * Get the blob directory.
 *
 * @memberof dc_context_t
 * @param context the context object as created by dc_context_new().
 * @return Blob directory associated with the context object, empty string if unset or on errors. NULL is never returned.
 *     The returned string must be free()'d.
 */
char* dc_get_blobdir(const dc_context_t* context)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return dc_strdup(NULL);
	}
	return dc_strdup(context->blobdir);
}


/*******************************************************************************
 * INI-handling, Information
 ******************************************************************************/


static int32_t get_sys_config_int(const char* key, int32_t def, int* def_returned)
{
	if (strcmp(key, "sys.msgsize_max_recommended")==0) {
		return DC_MSGSIZE_MAX_RECOMMENDED;
	}
	else {
		*def_returned = 1;
		return def;
	}
}


static char* get_sys_config_str(const char* key, const char* def)
{
	if (strcmp(key, "sys.version")==0) {
		return dc_strdup(DC_VERSION_STR);
	}
	else {
		int def_returned = 0;
		int32_t int_val = get_sys_config_int(key, 0, &def_returned);
		return def_returned? dc_strdup_keep_null(def) : dc_mprintf("%i", int_val);
	}
}


/**
 * Configure the context.  The configuration is handled by key=value pairs, see
 * dc_get_config() for a list of possible options.
 *
 * @memberof dc_context_t
 * @param context The context object
 * @param key The option to change, see dc_get_config() for a list.
 *     Keys starting with `sys` cannot be modified.
 * @param value The value to save for "key"
 * @return 0=failure, 1=success
 */
int dc_set_config(dc_context_t* context, const char* key, const char* value)
{
	int ret = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || key==NULL) { /* "value" may be NULL */
		return 0;
	}

	ret = dc_sqlite3_set_config(context->sql, key, value);
	update_config_cache(context, key);

	return ret;
}


/**
 * Get a configuration option. The configuration option is typically set by dc_set_config() or by the library itself.
 * To get an option as an integer, you can use dc_get_config_int() as an alternative.
 * Typical configuration options are:
 *
 * - `addr`         = address to display (needed)
 * - `mail_server`  = IMAP-server, guessed if left out
 * - `mail_user`    = IMAP-username, guessed if left out
 * - `mail_pw`      = IMAP-password (needed)
 * - `mail_port`    = IMAP-port, guessed if left out
 * - `send_server`  = SMTP-server, guessed if left out
 * - `send_user`    = SMTP-user, guessed if left out
 * - `send_pw`      = SMTP-password, guessed if left out
 * - `send_port`    = SMTP-port, guessed if left out
 * - `server_flags` = IMAP-/SMTP-flags, guessed if left out
 * - `displayname`  = Own name to use when sending messages.  MUAs are allowed to spread this way eg. using CC, defaults to empty
 * - `selfstatus`   = Own status to display eg. in email footers, defaults to a standard text
 * - `e2ee_enabled` = 0=no end-to-end-encryption, 1=prefer end-to-end-encryption (default)
 *
 * Moreover, this function can be used to query some global system values:
 *
 * - `sys.version`  = get the version string eg. as `1.2.3` or as `1.2.3special4`
 * - `sys.msgsize_max_recommended` = maximal recommended attachment size in bytes.
 *                    All possible overheads are already substracted and this value can be used eg. for direct comparison
 *                    with the size of a file the user wants to attach. If an attachment is larger than this value,
 *                    an error (no warning as it should be shown to the user) is logged but the attachment is sent anyway.
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new(). For querying system values, this can be NULL.
 * @param key The key to query
 * @param def Default value to return if "key" is unset.
 * @return Returns current value of "key", if "key" is unset, "def" is returned (which may be NULL)
 *     If the returned values is not NULL, the return value must be free()'d,
 */
char* dc_get_config(dc_context_t* context, const char* key, const char* def)
{
	if (key && key[0]=='s' && key[1]=='y' && key[2]=='s' && key[3]=='.') {
		return get_sys_config_str(key, def);
	}

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || key==NULL) { /* "def" may be NULL */
		return dc_strdup_keep_null(def);
	}

	return dc_sqlite3_get_config(context->sql, key, def);
}


/**
 * Configure the context.  Similar to dc_set_config() but sets an integer instead of a string.
 * If there is already a key with a string set, this is overwritten by the given integer value.
 *
 * @memberof dc_context_t
 */
int dc_set_config_int(dc_context_t* context, const char* key, int32_t value)
{
	int ret = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || key==NULL) {
		return 0;
	}

	ret = dc_sqlite3_set_config_int(context->sql, key, value);
	update_config_cache(context, key);

	return ret;
}


/**
 * Get a configuration option. Similar as dc_get_config() but gets the value as an integer instead of a string.
 *
 * @memberof dc_context_t
 */
int32_t dc_get_config_int(dc_context_t* context, const char* key, int32_t def)
{
	if (key && key[0]=='s' && key[1]=='y' && key[2]=='s' && key[3]=='.') {
		int def_returned = 0;
		return get_sys_config_int(key, def, &def_returned);
	}

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || key==NULL) {
		return def;
	}

	return dc_sqlite3_get_config_int(context->sql, key, def);
}


/**
 * Find out the version of the Delta Chat core library.
 * Deprecated, use dc_get_config() instread
 *
 * @private @memberof dc_context_t
 * @return String with version number as `major.minor.revision`. The return value must be free()'d.
 */
char* dc_get_version_str(void)
{
	return dc_strdup(DC_VERSION_STR);
}


/**
 * Get information about the context.  The information is returned by a multi-line string and contains information about the current
 * configuration and the last log entries.
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @return String which must be free()'d after usage.  Never returns NULL.
 */
char* dc_get_info(dc_context_t* context)
{
	const char*      unset = "0";
	char*            displayname = NULL;
	char*            temp = NULL;
	char*            l_readable_str = NULL;
	char*            l2_readable_str = NULL;
	char*            fingerprint_str = NULL;
	dc_loginparam_t* l = NULL;
	dc_loginparam_t* l2 = NULL;
	int              contacts = 0;
	int              chats = 0;
	int              real_msgs = 0;
	int              deaddrop_msgs = 0;
	int              is_configured = 0;
	int              dbversion = 0;
	int              mdns_enabled = 0;
	int              e2ee_enabled = 0;
	int              prv_key_cnt = 0;
	int              pub_key_cnt = 0;
	dc_key_t*        self_public = dc_key_new();

	dc_strbuilder_t  ret;
	dc_strbuilder_init(&ret, 0);

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return dc_strdup("ErrBadPtr");
	}

	/* read data (all pointers may be NULL!) */
	l = dc_loginparam_new();
	l2 = dc_loginparam_new();

	dc_loginparam_read(l, context->sql, "");
	dc_loginparam_read(l2, context->sql, "configured_" /*the trailing underscore is correct*/);

	displayname     = dc_sqlite3_get_config(context->sql, "displayname", NULL);

	chats           = dc_get_chat_cnt(context);
	real_msgs       = dc_get_real_msg_cnt(context);
	deaddrop_msgs   = dc_get_deaddrop_msg_cnt(context);
	contacts        = dc_get_real_contact_cnt(context);

	is_configured   = dc_sqlite3_get_config_int(context->sql, "configured", 0);

	dbversion       = dc_sqlite3_get_config_int(context->sql, "dbversion", 0);

	e2ee_enabled    = context->e2ee_enabled;

	mdns_enabled    = dc_sqlite3_get_config_int(context->sql, "mdns_enabled", DC_MDNS_DEFAULT_ENABLED);

	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql, "SELECT COUNT(*) FROM keypairs;");
	sqlite3_step(stmt);
	prv_key_cnt = sqlite3_column_int(stmt, 0);
	sqlite3_finalize(stmt);

	stmt = dc_sqlite3_prepare(context->sql, "SELECT COUNT(*) FROM acpeerstates;");
	sqlite3_step(stmt);
	pub_key_cnt = sqlite3_column_int(stmt, 0);
	sqlite3_finalize(stmt);

	if (dc_key_load_self_public(self_public, l2->addr, context->sql)) {
		fingerprint_str = dc_key_get_formatted_fingerprint(self_public);
	}
	else {
		fingerprint_str = dc_strdup("<Not yet calculated>");
	}

	l_readable_str = dc_loginparam_get_readable(l);
	l2_readable_str = dc_loginparam_get_readable(l2);

	/* create info
	- some keys are display lower case - these can be changed using the `set`-command
	- we do not display the password here; in the cli-utility, you can see it using `get mail_pw`
	- use neutral speach; the Delta Chat Core is not directly related to any front end or end-product
	- contributors: You're welcome to add your names here */
	temp = dc_mprintf(
		"Chats: %i\n"
		"Chat messages: %i\n"
		"Messages in contact requests: %i\n"
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
		"Using Delta Chat Core v%s, SQLite %s-ts%i, libEtPan %i.%i, OpenSSL %i.%i.%i%c. Compiled " __DATE__ ", " __TIME__ " for %i bit usage.\n\n"
		"Log excerpt:\n"
		/* In the frontends, additional software hints may follow here. */

		, chats, real_msgs, deaddrop_msgs, contacts
		, context->dbfile? context->dbfile : unset,   dbversion,   context->blobdir? context->blobdir : unset

        , displayname? displayname : unset
		, is_configured
		, l_readable_str, l2_readable_str

		, mdns_enabled

		, e2ee_enabled
		, DC_E2EE_DEFAULT_ENABLED
		, prv_key_cnt, pub_key_cnt, fingerprint_str

		, DC_VERSION_STR
		, SQLITE_VERSION, sqlite3_threadsafe()   ,  libetpan_get_version_major(), libetpan_get_version_minor()
		, (int)(OPENSSL_VERSION_NUMBER>>28), (int)(OPENSSL_VERSION_NUMBER>>20)&0xFF, (int)(OPENSSL_VERSION_NUMBER>>12)&0xFF, (char)('a'-1+((OPENSSL_VERSION_NUMBER>>4)&0xFF))
		, sizeof(void*)*8

		);
	dc_strbuilder_cat(&ret, temp);
	free(temp);

	/* add log excerpt */
	pthread_mutex_lock(&context->log_ringbuf_critical); /*take care not to log here! */
		for (int i = 0; i < DC_LOG_RINGBUF_SIZE; i++) {
			int j = (context->log_ringbuf_pos+i) % DC_LOG_RINGBUF_SIZE;
			if (context->log_ringbuf[j]) {
				struct tm wanted_struct;
				memcpy(&wanted_struct, localtime(&context->log_ringbuf_times[j]), sizeof(struct tm));
				temp = dc_mprintf("\n%02i:%02i:%02i ", (int)wanted_struct.tm_hour, (int)wanted_struct.tm_min, (int)wanted_struct.tm_sec);
					dc_strbuilder_cat(&ret, temp);
					dc_strbuilder_cat(&ret, context->log_ringbuf[j]);
				free(temp);
			}
		}
	pthread_mutex_unlock(&context->log_ringbuf_critical);

	/* free data */
	dc_loginparam_unref(l);
	dc_loginparam_unref(l2);
	free(displayname);
	free(l_readable_str);
	free(l2_readable_str);
	free(fingerprint_str);
	dc_key_unref(self_public);
	return ret.buf; /* must be freed by the caller */
}


/*******************************************************************************
 * Search
 ******************************************************************************/


/**
 * Returns the message IDs of all _fresh_ messages of any chat. Typically used for implementing
 * notification summaries.
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @return Array of message IDs, must be dc_array_unref()'d when no longer used.
 */
dc_array_t* dc_get_fresh_msgs(dc_context_t* context)
{
	int           show_deaddrop = 0;
	int           success = 0;
	dc_array_t*   ret = dc_array_new(context, 128);
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || ret==NULL) {
		goto cleanup;
	}

	show_deaddrop = 0;//dc_sqlite3_get_config_int(context->sql, "show_deaddrop", 0);

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT m.id"
			" FROM msgs m"
			" LEFT JOIN contacts ct ON m.from_id=ct.id"
			" LEFT JOIN chats c ON m.chat_id=c.id"
			" WHERE m.state=" DC_STRINGIFY(DC_STATE_IN_FRESH) " AND ct.blocked=0 AND (c.blocked=0 OR c.blocked=?)"
			" ORDER BY m.timestamp DESC,m.id DESC;"); /* the list starts with the newest messages*/
	sqlite3_bind_int(stmt, 1, show_deaddrop? DC_CHAT_DEADDROP_BLOCKED : 0);

	while (sqlite3_step(stmt)==SQLITE_ROW) {
		dc_array_add_id(ret, sqlite3_column_int(stmt, 0));
	}

	success = 1;

cleanup:
	sqlite3_finalize(stmt);

	if (success) {
		return ret;
	}
	else {
		if (ret) {
			dc_array_unref(ret);
		}
		return NULL;
	}
}


/**
 * Search messages containing the given query string.
 * Searching can be done globally (chat_id=0) or in a specified chat only (chat_id
 * set).
 *
 * Global chat results are typically displayed using dc_msg_get_summary(), chat
 * search results may just hilite the corresponding messages and present a
 * prev/next button.
 *
 * @memberof dc_context_t
 * @param context The context object as returned from dc_context_new().
 * @param chat_id ID of the chat to search messages in.
 *     Set this to 0 for a global search.
 * @param query The query to search for.
 * @return An array of message IDs. Must be freed using dc_array_unref() when no longer needed.
 *     If nothing can be found, the function returns NULL.
 */
dc_array_t* dc_search_msgs(dc_context_t* context, uint32_t chat_id, const char* query)
{
	//clock_t       start = clock();

	int           success = 0;
	dc_array_t*   ret = dc_array_new(context, 100);
	char*         strLikeInText = NULL;
	char*         strLikeBeg = NULL;
	char*         real_query = NULL;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || ret==NULL || query==NULL) {
		goto cleanup;
	}

	real_query = dc_strdup(query);
	dc_trim(real_query);
	if (real_query[0]==0) {
		success = 1; /*empty result*/
		goto cleanup;
	}

	strLikeInText = dc_mprintf("%%%s%%", real_query);
	strLikeBeg = dc_mprintf("%s%%", real_query); /*for the name search, we use "Name%" which is fast as it can use the index ("%Name%" could not). */

	/* Incremental search with "LIKE %query%" cannot take advantages from any index
	("query%" could for COLLATE NOCASE indexes, see http://www.sqlite.org/optoverview.html#like_opt)
	An alternative may be the FULLTEXT sqlite stuff, however, this does not really help with incremental search.
	An extra table with all words and a COLLATE NOCASE indexes may help, however,
	this must be updated all the time and probably consumes more time than we can save in tenthousands of searches.
	For now, we just expect the following query to be fast enough :-) */
	if (chat_id) {
		stmt = dc_sqlite3_prepare(context->sql,
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
		int show_deaddrop = 0;//dc_sqlite3_get_config_int(context->sql, "show_deaddrop", 0);
		stmt = dc_sqlite3_prepare(context->sql,
			"SELECT m.id, m.timestamp FROM msgs m"
			" LEFT JOIN contacts ct ON m.from_id=ct.id"
			" LEFT JOIN chats c ON m.chat_id=c.id"
			" WHERE m.chat_id>" DC_STRINGIFY(DC_CHAT_ID_LAST_SPECIAL)
				" AND m.hidden=0 "
				" AND (c.blocked=0 OR c.blocked=?)"
				" AND ct.blocked=0 AND (m.txt LIKE ? OR ct.name LIKE ?)"
			" ORDER BY m.timestamp DESC,m.id DESC;"); /* chat overview starts with the newest message*/
		sqlite3_bind_int (stmt, 1, show_deaddrop? DC_CHAT_DEADDROP_BLOCKED : 0);
		sqlite3_bind_text(stmt, 2, strLikeInText, -1, SQLITE_STATIC);
		sqlite3_bind_text(stmt, 3, strLikeBeg, -1, SQLITE_STATIC);
	}

	while (sqlite3_step(stmt)==SQLITE_ROW) {
		dc_array_add_id(ret, sqlite3_column_int(stmt, 0));
	}

	success = 1;

cleanup:
	free(strLikeInText);
	free(strLikeBeg);
	free(real_query);
	sqlite3_finalize(stmt);

	//dc_log_info(context, 0, "Message list for search \"%s\" in chat #%i created in %.3f ms.", query, chat_id, (double)(clock()-start)*1000.0/CLOCKS_PER_SEC);

	if (success) {
		return ret;
	}
	else {
		if (ret) {
			dc_array_unref(ret);
		}
		return NULL;
	}
}
