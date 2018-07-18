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


#include <dirent.h>
#include <unistd.h>
#include "dc_context.h"
#include "dc_loginparam.h"
#include "dc_imap.h"
#include "dc_smtp.h"
#include "dc_saxparser.h"
#include "dc_job.h"


/*******************************************************************************
 * Tools
 ******************************************************************************/


static char* read_autoconf_file(dc_context_t* context, const char* url)
{
	char* filecontent = NULL;
	dc_log_info(context, 0, "Testing %s ...", url);
	filecontent = (char*)context->cb(context, DC_EVENT_HTTP_GET, (uintptr_t)url, 0);
	if (filecontent==NULL) {
		dc_log_info(context, 0, "Can't read file."); /* this is not a warning or an error, we're just testing */
		return NULL;
	}
	return filecontent;
}


/*******************************************************************************
 * Thunderbird's Autoconfigure
 ******************************************************************************/


/* documentation: https://developer.mozilla.org/en-US/docs/Mozilla/Thunderbird/Autoconfiguration */


typedef struct moz_autoconfigure_t
{
	const dc_loginparam_t* in;
	char*                  in_emaildomain;
	char*                  in_emaillocalpart;

	dc_loginparam_t*       out;
	int                    out_imap_set;
	int                    out_smtp_set;

	/* currently, we assume there is only one emailProvider tag in the
	file, see example at https://wiki.mozilla.org/Thunderbird:Autoconfiguration:ConfigFileFormat
	moreover, we assume, the returned domains match the one queried.  I've not seen another example (bp).
	However, _if_ the assumptions are wrong, we can add a first saxparser-pass that searches for the correct domain
	and the second pass will look for the index found. */

	#define                MOZ_SERVER_IMAP 1
	#define                MOZ_SERVER_SMTP 2
	int                    tag_server;

	#define                MOZ_HOSTNAME    10
	#define                MOZ_PORT        11
	#define                MOZ_USERNAME    12
	#define                MOZ_SOCKETTYPE  13
	int                    tag_config;

} moz_autoconfigure_t;


static void moz_autoconfigure_starttag_cb(void* userdata, const char* tag, char** attr)
{
	moz_autoconfigure_t* moz_ac = (moz_autoconfigure_t*)userdata;
	const char*          p1 = NULL;

	if (strcmp(tag, "incomingserver")==0) {
		moz_ac->tag_server = (moz_ac->out_imap_set==0 && (p1=dc_attr_find(attr, "type"))!=NULL && strcasecmp(p1, "imap")==0)? MOZ_SERVER_IMAP : 0;
		moz_ac->tag_config = 0;
	}
	else if (strcmp(tag, "outgoingserver")==0) {
		moz_ac->tag_server = moz_ac->out_smtp_set==0? MOZ_SERVER_SMTP : 0;
		moz_ac->tag_config = 0;
	}
	else if (strcmp(tag, "hostname")==0) {
		moz_ac->tag_config = MOZ_HOSTNAME;
	}
	else if (strcmp(tag, "port")==0 ) {
		moz_ac->tag_config = MOZ_PORT;
	}
	else if (strcmp(tag, "sockettype")==0) {
		moz_ac->tag_config = MOZ_SOCKETTYPE;
	}
	else if (strcmp(tag, "username")==0) {
		moz_ac->tag_config = MOZ_USERNAME;
	}
}


static void moz_autoconfigure_text_cb(void* userdata, const char* text, int len)
{
	moz_autoconfigure_t* moz_ac = (moz_autoconfigure_t*)userdata;

	char* val = dc_strdup(text);
	dc_trim(val);
	dc_str_replace(&val, "%EMAILADDRESS%",   moz_ac->in->addr);
	dc_str_replace(&val, "%EMAILLOCALPART%", moz_ac->in_emaillocalpart);
	dc_str_replace(&val, "%EMAILDOMAIN%",    moz_ac->in_emaildomain);

	if (moz_ac->tag_server==MOZ_SERVER_IMAP)
	{
		switch (moz_ac->tag_config) {
			case MOZ_HOSTNAME:
				free(moz_ac->out->mail_server);
				moz_ac->out->mail_server = val;
				val = NULL;
				break;

			case MOZ_PORT:
				moz_ac->out->mail_port = atoi(val);
				break;

			case MOZ_USERNAME:
				free(moz_ac->out->mail_user);
				moz_ac->out->mail_user = val;
				val = NULL;
				break;

			case MOZ_SOCKETTYPE:
				if (strcasecmp(val, "ssl")==0)      { moz_ac->out->server_flags |=DC_LP_IMAP_SOCKET_SSL; }
				if (strcasecmp(val, "starttls")==0) { moz_ac->out->server_flags |=DC_LP_IMAP_SOCKET_STARTTLS; }
				if (strcasecmp(val, "plain")==0)    { moz_ac->out->server_flags |=DC_LP_IMAP_SOCKET_PLAIN; }
				break;
		}
	}
	else if (moz_ac->tag_server==MOZ_SERVER_SMTP)
	{
		switch (moz_ac->tag_config) {
			case MOZ_HOSTNAME:
				free(moz_ac->out->send_server);
				moz_ac->out->send_server = val;
				val = NULL;
				break;

			case MOZ_PORT:
				moz_ac->out->send_port = atoi(val);
				break;

			case MOZ_USERNAME:
				free(moz_ac->out->send_user);
				moz_ac->out->send_user = val;
				val = NULL;
				break;

			case MOZ_SOCKETTYPE:
				if (strcasecmp(val, "ssl")==0)      { moz_ac->out->server_flags |=DC_LP_SMTP_SOCKET_SSL; }
				if (strcasecmp(val, "starttls")==0) { moz_ac->out->server_flags |=DC_LP_SMTP_SOCKET_STARTTLS; }
				if (strcasecmp(val, "plain")==0)    { moz_ac->out->server_flags |=DC_LP_SMTP_SOCKET_PLAIN; }
				break;
		}
	}

	free(val);
}


static void moz_autoconfigure_endtag_cb(void* userdata, const char* tag)
{
	moz_autoconfigure_t* moz_ac = (moz_autoconfigure_t*)userdata;

	if (strcmp(tag, "incomingserver")==0) {
		moz_ac->tag_server = 0;
		moz_ac->tag_config = 0;
		moz_ac->out_imap_set = 1;
	}
	else if (strcmp(tag, "outgoingserver")==0) {
		moz_ac->tag_server = 0;
		moz_ac->tag_config = 0;
		moz_ac->out_smtp_set = 1;
	}
	else {
		moz_ac->tag_config = 0;
	}
}


static dc_loginparam_t* moz_autoconfigure(dc_context_t* context, const char* url, const dc_loginparam_t* param_in)
{
	char*               xml_raw = NULL;
	moz_autoconfigure_t moz_ac;

	memset(&moz_ac, 0, sizeof(moz_autoconfigure_t));

	if ((xml_raw=read_autoconf_file(context, url))==NULL) {
		goto cleanup;
	}

	moz_ac.in                = param_in;
	moz_ac.in_emaillocalpart = dc_strdup(param_in->addr); char* p = strchr(moz_ac.in_emaillocalpart, '@'); if (p==NULL) { goto cleanup; } *p = 0;
	moz_ac.in_emaildomain    = dc_strdup(p+1);
	moz_ac.out               = dc_loginparam_new();

	dc_saxparser_t                saxparser;
	dc_saxparser_init            (&saxparser, &moz_ac);
	dc_saxparser_set_tag_handler (&saxparser, moz_autoconfigure_starttag_cb, moz_autoconfigure_endtag_cb);
	dc_saxparser_set_text_handler(&saxparser, moz_autoconfigure_text_cb);
	dc_saxparser_parse           (&saxparser, xml_raw);

	if (moz_ac.out->mail_server==NULL
	 || moz_ac.out->mail_port  ==0
	 || moz_ac.out->send_server==NULL
	 || moz_ac.out->send_port  ==0)
	{
		{ char* r = dc_loginparam_get_readable(moz_ac.out); dc_log_warning(context, 0, "Bad or incomplete autoconfig: %s", r); free(r); }

		dc_loginparam_unref(moz_ac.out); /* autoconfig failed for the given URL */
		moz_ac.out = NULL;
		goto cleanup;
	}

cleanup:
	free(xml_raw);
	free(moz_ac.in_emaildomain);
	free(moz_ac.in_emaillocalpart);
	return moz_ac.out; /* may be NULL */
}


/*******************************************************************************
 * Outlook's Autodiscover
 ******************************************************************************/


typedef struct outlk_autodiscover_t
{
	const dc_loginparam_t* in;

	dc_loginparam_t*       out;
	int                    out_imap_set;
	int                    out_smtp_set;

	/* file format: https://msdn.microsoft.com/en-us/library/bb204278(v=exchg.80).aspx */
	#define                OUTLK_TYPE         1
	#define                OUTLK_SERVER       2
	#define                OUTLK_PORT         3
	#define                OUTLK_SSL          4
	#define                OUTLK_REDIRECTURL  5
	#define                _OUTLK_CNT_        6
	int                    tag_config;

	char*                  config[_OUTLK_CNT_];
	char*                  redirect;

} outlk_autodiscover_t;


static void outlk_clean_config(outlk_autodiscover_t* outlk_ad)
{
	int i;
	for (i = 0; i < _OUTLK_CNT_; i++) {
		free(outlk_ad->config[i]);
		outlk_ad->config[i] = NULL;
	}
}


static void outlk_autodiscover_starttag_cb(void* userdata, const char* tag, char** attr)
{
	outlk_autodiscover_t* outlk_ad = (outlk_autodiscover_t*)userdata;

	     if (strcmp(tag, "protocol")==0)    { outlk_clean_config(outlk_ad); } /* this also cleans "redirecturl", however, this is not problem as the protocol block is only valid for action "settings". */
	else if (strcmp(tag, "type")==0)        { outlk_ad->tag_config = OUTLK_TYPE; }
	else if (strcmp(tag, "server")==0)      { outlk_ad->tag_config = OUTLK_SERVER; }
	else if (strcmp(tag, "port")==0)        { outlk_ad->tag_config = OUTLK_PORT; }
	else if (strcmp(tag, "ssl")==0)         { outlk_ad->tag_config = OUTLK_SSL; }
	else if (strcmp(tag, "redirecturl")==0) { outlk_ad->tag_config = OUTLK_REDIRECTURL; }
}


static void outlk_autodiscover_text_cb(void* userdata, const char* text, int len)
{
	outlk_autodiscover_t* outlk_ad = (outlk_autodiscover_t*)userdata;

	char* val = dc_strdup(text);
	dc_trim(val);

	free(outlk_ad->config[outlk_ad->tag_config]);
	outlk_ad->config[outlk_ad->tag_config] = val;
}


static void outlk_autodiscover_endtag_cb(void* userdata, const char* tag)
{
	outlk_autodiscover_t* outlk_ad = (outlk_autodiscover_t*)userdata;

	if (strcmp(tag, "protocol")==0)
	{
		/* copy collected confituration to out (we have to delay this as we do not know when the <type> tag appears in the sax-stream) */
		if (outlk_ad->config[OUTLK_TYPE])
		{
			int port    = dc_atoi_null_is_0(outlk_ad->config[OUTLK_PORT]),
			    ssl_on  = (outlk_ad->config[OUTLK_SSL] && strcasecmp(outlk_ad->config[OUTLK_SSL], "on")==0),
			    ssl_off = (outlk_ad->config[OUTLK_SSL] && strcasecmp(outlk_ad->config[OUTLK_SSL], "off")==0);

			if (strcasecmp(outlk_ad->config[OUTLK_TYPE], "imap")==0 && outlk_ad->out_imap_set==0)
			{
                outlk_ad->out->mail_server = dc_strdup_keep_null(outlk_ad->config[OUTLK_SERVER]);
                outlk_ad->out->mail_port   = port;
                     if (ssl_on)  { outlk_ad->out->server_flags |= DC_LP_IMAP_SOCKET_SSL; }
                else if (ssl_off) { outlk_ad->out->server_flags |= DC_LP_IMAP_SOCKET_PLAIN; }
                outlk_ad->out_imap_set = 1;
			}
			else if (strcasecmp(outlk_ad->config[OUTLK_TYPE], "smtp")==0 && outlk_ad->out_smtp_set==0)
			{
                outlk_ad->out->send_server = dc_strdup_keep_null(outlk_ad->config[OUTLK_SERVER]);
                outlk_ad->out->send_port   = port;
                     if (ssl_on)  { outlk_ad->out->server_flags |= DC_LP_SMTP_SOCKET_SSL; }
                else if (ssl_off) { outlk_ad->out->server_flags |= DC_LP_SMTP_SOCKET_PLAIN; }
                outlk_ad->out_smtp_set = 1;
			}
		}

		outlk_clean_config(outlk_ad);
	}
	outlk_ad->tag_config = 0;
}


static dc_loginparam_t* outlk_autodiscover(dc_context_t* context, const char* url__, const dc_loginparam_t* param_in)
{
	char*                 xml_raw = NULL;
	char*                 url = dc_strdup(url__);
	outlk_autodiscover_t  outlk_ad;
	int                   i;

	for (i = 0; i < 10 /* follow up to 10 xml-redirects (http-redirects are followed in read_autoconf_file() */; i++)
	{
		memset(&outlk_ad, 0, sizeof(outlk_autodiscover_t));

		if ((xml_raw=read_autoconf_file(context, url))==NULL) {
			goto cleanup;
		}

		outlk_ad.in                = param_in;
		outlk_ad.out               = dc_loginparam_new();

		dc_saxparser_t                 saxparser;
		dc_saxparser_init            (&saxparser, &outlk_ad);
		dc_saxparser_set_tag_handler (&saxparser, outlk_autodiscover_starttag_cb, outlk_autodiscover_endtag_cb);
		dc_saxparser_set_text_handler(&saxparser, outlk_autodiscover_text_cb);
		dc_saxparser_parse           (&saxparser, xml_raw);

		if (outlk_ad.config[OUTLK_REDIRECTURL] && outlk_ad.config[OUTLK_REDIRECTURL][0]) {
			free(url);
			url = dc_strdup(outlk_ad.config[OUTLK_REDIRECTURL]);
			dc_loginparam_unref(outlk_ad.out);
			outlk_clean_config(&outlk_ad);
			free(xml_raw);
			xml_raw = NULL;
		}
		else {
			break;
		}
	}

	if (outlk_ad.out->mail_server==NULL
	 || outlk_ad.out->mail_port  ==0
	 || outlk_ad.out->send_server==NULL
	 || outlk_ad.out->send_port  ==0)
	{
		{ char* r = dc_loginparam_get_readable(outlk_ad.out); dc_log_warning(context, 0, "Bad or incomplete autoconfig: %s", r); free(r); }
		dc_loginparam_unref(outlk_ad.out); /* autoconfig failed for the given URL */
		outlk_ad.out = NULL;
		goto cleanup;
	}

cleanup:
	free(url);
	free(xml_raw);
	outlk_clean_config(&outlk_ad);
	return outlk_ad.out; /* may be NULL */
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


void dc_job_do_DC_JOB_CONFIGURE_IMAP(dc_context_t* context, dc_job_t* job)
{
	int              success = 0;
	int              i = 0;
	int              imap_connected_here = 0;
	int              smtp_connected_here = 0;
	int              ongoing_allocated_here = 0;

	dc_loginparam_t* param = NULL;
	char*            param_domain = NULL; /* just a pointer inside param, must not be freed! */
	char*            param_addr_urlencoded = NULL;
	dc_loginparam_t* param_autoconfig = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	if (!dc_alloc_ongoing(context)) {
		goto cleanup;
	}
	ongoing_allocated_here = 1;

	#define PROGRESS(p) \
				if (context->shall_stop_ongoing) { goto cleanup; } \
				context->cb(context, DC_EVENT_CONFIGURE_PROGRESS, (p)<1? 1 : ((p)>999? 999 : (p)), 0);

	if (!dc_sqlite3_is_open(context->sql)) {
		dc_log_error(context, 0, "Cannot configure, database not opened.");
		goto cleanup;
	}

	dc_imap_disconnect(context->imap);
	dc_smtp_disconnect(context->smtp);

	//dc_sqlite3_set_config_int(context->sql, "configured", 0); -- NO: we do _not_ reset this flag if it was set once; otherwise the user won't get back to his chats (as an alternative, we could change the UI).  Moreover, and not changeable in the UI, we use this flag to check if we shall search for backups.
	context->smtp->log_connect_errors = 1;
	context->imap->log_connect_errors = 1;

	dc_log_info(context, 0, "Configure ...");

	PROGRESS(0)

	if (context->cb(context, DC_EVENT_IS_OFFLINE, 0, 0)!=0) {
		dc_log_error(context, DC_ERROR_NO_NETWORK, NULL);
		goto cleanup;
	}

	PROGRESS(100)

	/* 1.  Load the parameters and check email-address and password
	 **************************************************************************/

	param = dc_loginparam_new();

	dc_loginparam_read(param, context->sql, "");

	if (param->addr==NULL) {
		dc_log_error(context, 0, "Please enter the email address.");
		goto cleanup;
	}
	dc_trim(param->addr);

	param_domain = strchr(param->addr, '@');
	if (param_domain==NULL || param_domain[0]==0) {
		dc_log_error(context, 0, "Bad email-address.");
		goto cleanup;
	}
	param_domain++;

	param_addr_urlencoded = dc_urlencode(param->addr);

	/* if no password is given, assume an empty password.
	(in general, unset values are NULL, not the empty string, this allows to use eg. empty user names or empty passwords) */
	if (param->mail_pw==NULL) {
		param->mail_pw = dc_strdup(NULL);
	}

	PROGRESS(200)


	/* 2.  Autoconfig
	 **************************************************************************/

	if (param->mail_server ==NULL
	 && param->mail_port   ==0
	/*&&param->mail_user   ==NULL -- the user can enter a loginname which is used by autoconfig then */
	 && param->send_server ==NULL
	 && param->send_port   ==0
	 && param->send_user   ==NULL
	/*&&param->send_pw     ==NULL -- the password cannot be auto-configured and is no criterion for autoconfig or not */
	 && param->server_flags==0)
	{
		/* A.  Search configurations from the domain used in the email-address */
		for (i = 0; i <= 1; i++) {
			if (param_autoconfig==NULL) {
				char* url = dc_mprintf("%s://autoconfig.%s/mail/config-v1.1.xml?emailaddress=%s", i==0?"https":"http", param_domain, param_addr_urlencoded); /* Thunderbird may or may not use SSL */
				param_autoconfig = moz_autoconfigure(context, url, param);
				free(url);
				PROGRESS(300+i*20)
			}
		}

		for (i = 0; i <= 1; i++) {
			if (param_autoconfig==NULL) {
				char* url = dc_mprintf("%s://%s/.well-known/autoconfig/mail/config-v1.1.xml?emailaddress=%s", i==0?"https":"http", param_domain, param_addr_urlencoded); // the doc does not mention `emailaddress=`, however, Thunderbird adds it, see https://releases.mozilla.org/pub/thunderbird/ ,  which makes some sense
				param_autoconfig = moz_autoconfigure(context, url, param);
				free(url);
				PROGRESS(340+i*30)
			}
		}

		for (i = 0; i <= 1; i++) {
			if (param_autoconfig==NULL) {
				char* url = dc_mprintf("https://%s%s/autodiscover/autodiscover.xml", i==0?"":"autodiscover.", param_domain); /* Outlook uses always SSL but different domains */
				param_autoconfig = outlk_autodiscover(context, url, param);
				free(url);
				PROGRESS(400+i*50)
			}
		}

		/* B.  If we have no configuration yet, search configuration in Thunderbird's centeral database */
		if (param_autoconfig==NULL)
		{
			char* url = dc_mprintf("https://autoconfig.thunderbird.net/v1.1/%s", param_domain); /* always SSL for Thunderbird's database */
			param_autoconfig = moz_autoconfigure(context, url, param);
			free(url);
			PROGRESS(500)
		}

		/* C.  Do we have any result? */
		if (param_autoconfig)
		{
			{ char* r = dc_loginparam_get_readable(param_autoconfig); dc_log_info(context, 0, "Got autoconfig: %s", r); free(r); }

			if (param_autoconfig->mail_user) {
				free(param->mail_user);
				param->mail_user= dc_strdup_keep_null(param_autoconfig->mail_user);
			}
			param->mail_server  = dc_strdup_keep_null(param_autoconfig->mail_server); /* all other values are always NULL when entering autoconfig */
			param->mail_port    =                  param_autoconfig->mail_port;
			param->send_server  = dc_strdup_keep_null(param_autoconfig->send_server);
			param->send_port    =                  param_autoconfig->send_port;
			param->send_user    = dc_strdup_keep_null(param_autoconfig->send_user);
			param->server_flags =                  param_autoconfig->server_flags;

			/* althoug param_autoconfig's data are no longer needed from, it is important to keep the object as
			we may enter "deep guessing" if we could not read a configuration */
		}
	}


	/* 3.  Internal specials (eg. for uploading to chats-folder etc.)
	 **************************************************************************/

	if (strcasecmp(param_domain, "gmail.com")==0 || strcasecmp(param_domain, "googlemail.com")==0)
	{
		/* NB: Checking GMa'l too often (<10 Minutes) may result in blocking, says https://github.com/itprojects/InboxPager/blob/HEAD/README.md#gmail-configuration
		Also note https://www.google.com/settings/security/lesssecureapps */
		param->server_flags |= DC_LP_AUTH_XOAUTH2 | DC_NO_EXTRA_IMAP_UPLOAD | DC_NO_MOVE_TO_CHATS;
	}


	/* 2.  Fill missing fields with defaults
	 **************************************************************************/

	#define TYPICAL_IMAP_SSL_PORT       993 /* our default */
	#define TYPICAL_IMAP_STARTTLS_PORT  143 /* not used very often but eg. by posteo.de, default for PLAIN */

	#define TYPICAL_SMTP_SSL_PORT       465 /* our default */
	#define TYPICAL_SMTP_STARTTLS_PORT  587 /* also used very often, SSL:STARTTLS is maybe 50:50 */
	#define TYPICAL_SMTP_PLAIN_PORT      25

	if (param->mail_server==NULL) {
		param->mail_server = dc_mprintf("imap.%s", param_domain);
	}

	if (param->mail_port==0) {
		param->mail_port = (param->server_flags&(DC_LP_IMAP_SOCKET_STARTTLS|DC_LP_IMAP_SOCKET_PLAIN))?  TYPICAL_IMAP_STARTTLS_PORT : TYPICAL_IMAP_SSL_PORT;
	}

	if (param->mail_user==NULL) {
		param->mail_user = dc_strdup(param->addr);
	}

	if (param->send_server==NULL && param->mail_server) {
		param->send_server = dc_strdup(param->mail_server);
		if (strncmp(param->send_server, "imap.", 5)==0) {
			memcpy(param->send_server, "smtp", 4);
		}
	}

	if (param->send_port==0) {
		param->send_port = (param->server_flags&DC_LP_SMTP_SOCKET_STARTTLS)?  TYPICAL_SMTP_STARTTLS_PORT :
			((param->server_flags&DC_LP_SMTP_SOCKET_PLAIN)? TYPICAL_SMTP_PLAIN_PORT : TYPICAL_SMTP_SSL_PORT);
	}

	if (param->send_user==NULL && param->mail_user) {
		param->send_user = dc_strdup(param->mail_user);
	}

	if (param->send_pw==NULL && param->mail_pw) {
		param->send_pw = dc_strdup(param->mail_pw);
	}

	if (!dc_exactly_one_bit_set(param->server_flags&DC_LP_AUTH_FLAGS))
	{
		param->server_flags &= ~DC_LP_AUTH_FLAGS;
		param->server_flags |= DC_LP_AUTH_NORMAL;
	}

	if (!dc_exactly_one_bit_set(param->server_flags&DC_LP_IMAP_SOCKET_FLAGS))
	{
		param->server_flags &= ~DC_LP_IMAP_SOCKET_FLAGS;
		param->server_flags |= (param->send_port==TYPICAL_IMAP_STARTTLS_PORT?  DC_LP_IMAP_SOCKET_STARTTLS : DC_LP_IMAP_SOCKET_SSL);
	}

	if (!dc_exactly_one_bit_set(param->server_flags&DC_LP_SMTP_SOCKET_FLAGS))
	{
		param->server_flags &= ~DC_LP_SMTP_SOCKET_FLAGS;
		param->server_flags |= ( param->send_port==TYPICAL_SMTP_STARTTLS_PORT?  DC_LP_SMTP_SOCKET_STARTTLS :
			(param->send_port==TYPICAL_SMTP_PLAIN_PORT? DC_LP_SMTP_SOCKET_PLAIN: DC_LP_SMTP_SOCKET_SSL));
	}


	/* do we have a complete configuration? */
	if (param->addr        ==NULL
	 || param->mail_server ==NULL
	 || param->mail_port   ==0
	 || param->mail_user   ==NULL
	 || param->mail_pw     ==NULL
	 || param->send_server ==NULL
	 || param->send_port   ==0
	 || param->send_user   ==NULL
	 || param->send_pw     ==NULL
	 || param->server_flags==0)
	{
		dc_log_error(context, 0, "Account settings incomplete.");
		goto cleanup;
	}

	PROGRESS(600)

	/* try to connect to IMAP */
	{ char* r = dc_loginparam_get_readable(param); dc_log_info(context, 0, "Trying: %s", r); free(r); }

	if (!dc_imap_connect(context->imap, param)) {
		goto cleanup;
	}

	imap_connected_here = 1;

	PROGRESS(800)

	/* try to connect to SMTP - if we did not got an autoconfig, the first try was SSL-465 and we do a second try with STARTTLS-587 */
	if (!dc_smtp_connect(context->smtp, param))  {
		if (param_autoconfig) {
			goto cleanup;
		}

		PROGRESS(850)

		param->server_flags &= ~DC_LP_SMTP_SOCKET_FLAGS;
		param->server_flags |=  DC_LP_SMTP_SOCKET_STARTTLS;
		param->send_port    =   TYPICAL_SMTP_STARTTLS_PORT;
		{ char* r = dc_loginparam_get_readable(param); dc_log_info(context, 0, "Trying: %s", r); free(r); }

		if (!dc_smtp_connect(context->smtp, param)) {
			goto cleanup;
		}
	}

	smtp_connected_here = 1;

	PROGRESS(900)

	/* configuration success - write back the configured parameters with the "configured_" prefix; also write the "configured"-flag */

	dc_loginparam_write(param, context->sql, "configured_" /*the trailing underscore is correct*/);
	dc_sqlite3_set_config_int(context->sql, "configured", 1);

	PROGRESS(920)

	// we generate the keypair just now - we could also postpone this until the first message is sent, however,
	// this may result in a unexpected and annoying delay when the user sends his very first message
	// (~30 seconds on a Moto G4 play) and might looks as if message sending is always that slow.
	dc_ensure_secret_key_exists(context);

	success = 1;
	dc_log_info(context, 0, "Configure completed.");

	PROGRESS(940)

cleanup:
	context->cb(context, DC_EVENT_CONFIGURE_PROGRESS, 950, 0);

	if (imap_connected_here) { dc_imap_disconnect(context->imap); }
	context->cb(context, DC_EVENT_CONFIGURE_PROGRESS, 960, 0);

	if (smtp_connected_here) { dc_smtp_disconnect(context->smtp); }
	context->cb(context, DC_EVENT_CONFIGURE_PROGRESS, 970, 0);

	dc_loginparam_unref(param);
	dc_loginparam_unref(param_autoconfig);
	free(param_addr_urlencoded);
	if (ongoing_allocated_here) { dc_free_ongoing(context); }
	context->cb(context, DC_EVENT_CONFIGURE_PROGRESS, 980, 0);

	context->cb(context, DC_EVENT_CONFIGURE_PROGRESS, 990, 0);

	context->cb(context, DC_EVENT_CONFIGURE_PROGRESS, success? 1000 : 0, 0);
}


/**
 * Configure and connect a context.
 * For this, the function creates a job that is executed in the IMAP-thread then;
 * this requires to call dc_perform_imap_jobs() regulary.
 *
 * - Before your call this function, you should set at least `addr` and `mail_pw`
 *   using dc_set_config().
 *
 * - While dc_configure() returns immediately, the started configuration-job may take a while,
 *   you can stop it using dc_stop_ongoing_process().
 *
 * - The function sends out a number of #DC_EVENT_CONFIGURE_PROGRESS events that may be used to create
 *   a progress bar or stuff like that.
 *
 * @memberof dc_context_t
 * @param context the context object as created by dc_context_new().
 * @return None.
 *
 * There is no need to call this every program start, the result is saved in the
 * database and you can call use the connection directly:
 *
 * ```
 * if (!dc_is_configured(context)) {
 *     dc_configure(context);
 *     // wait for progress events
 * }
 * ```
 */
void dc_configure(dc_context_t* context)
{
	dc_job_kill_actions(context, DC_JOB_CONFIGURE_IMAP, 0);
	dc_job_add(context, DC_JOB_CONFIGURE_IMAP, 0, NULL, 0); // results in a call to dc_configure_job()
}


/**
 * Check if the context is already configured.
 *
 * Typically, for unconfigured accounts, the user is prompeted for
 * to enter some settings and dc_configure() is called in a thread then.
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new().
 * @return 1=context is configuredc can be used;
 *     0=context is not configured and a configuration by dc_configure() is required.
 */
int dc_is_configured(const dc_context_t* context)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return 0;
	}

	if (dc_imap_is_connected(context->imap)) { /* if we're connected, we're also configured. this check will speed up the check as no database is involved */
		return 1;
	}

	return dc_sqlite3_get_config_int(context->sql, "configured", 0)? 1 : 0;
}


/*
 * Request an ongoing process to start.
 * Returns 0=process started, 1=not started, there is running another process
 */
int dc_alloc_ongoing(dc_context_t* context)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return 0;
	}

	if (context->ongoing_running || context->shall_stop_ongoing==0) {
		dc_log_warning(context, 0, "There is already another ongoing process running.");
		return 0;
	}

	context->ongoing_running    = 1;
	context->shall_stop_ongoing = 0;
	return 1;
}


/*
 * Frees the process allocated with dc_alloc_ongoing() - independingly of dc_shall_stop_ongoing.
 * If dc_alloc_ongoing() fails, this function MUST NOT be called.
 */
void dc_free_ongoing(dc_context_t* context)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return;
	}

	context->ongoing_running    = 0;
	context->shall_stop_ongoing = 1; /* avoids dc_stop_ongoing_process() to stop the thread */
}


/**
 * Signal an ongoing process to stop.
 *
 * After that, dc_stop_ongoing_process() returns _without_ waiting
 * for the ongoing process to return.
 *
 * The ongoing process will return ASAP then, however, it may
 * still take a moment.  If in doubt, the caller may also decide to kill the
 * thread after a few seconds; eg. the process may hang in a
 * function not under the control of the core (eg. #DC_EVENT_HTTP_GET). Another
 * reason for dc_stop_ongoing_process() not to wait is that otherwise it
 * would be GUI-blocking and should be started in another thread then; this
 * would make things even more complicated.
 *
 * Typical ongoing processes are started by dc_configure(),
 * dc_initiate_key_transfer() or dc_imex(). As there is always at most only
 * one onging process at the same time, there is no need to define _which_ process to exit.
 *
 * @memberof dc_context_t
 * @param context The context object.
 * @return None
 */
void dc_stop_ongoing_process(dc_context_t* context)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return;
	}

	if (context->ongoing_running && context->shall_stop_ongoing==0)
	{
		dc_log_info(context, 0, "Signaling the ongoing process to stop ASAP.");
		context->shall_stop_ongoing = 1;
	}
	else
	{
		dc_log_info(context, 0, "No ongoing process to stop.");
	}
}
