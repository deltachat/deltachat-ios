#include "dc_context.h"
#include "dc_loginparam.h"


dc_loginparam_t* dc_loginparam_new()
{
	dc_loginparam_t* loginparam = NULL;

	if ((loginparam=calloc(1, sizeof(dc_loginparam_t)))==NULL) {
		exit(22); /* cannot allocate little memory, unrecoverable error */
	}

	return loginparam;
}


void dc_loginparam_unref(dc_loginparam_t* loginparam)
{
	if (loginparam==NULL) {
		return;
	}

	dc_loginparam_empty(loginparam);
	free(loginparam);
}


void dc_loginparam_empty(dc_loginparam_t* loginparam)
{
	if (loginparam == NULL) {
		return; /* ok, but nothing to do */
	}

	free(loginparam->addr);        loginparam->addr        = NULL;
	free(loginparam->mail_server); loginparam->mail_server = NULL;
	                          loginparam->mail_port   = 0;
	free(loginparam->mail_user);   loginparam->mail_user   = NULL;
	free(loginparam->mail_pw);     loginparam->mail_pw     = NULL;
	free(loginparam->send_server); loginparam->send_server = NULL;
	                          loginparam->send_port   = 0;
	free(loginparam->send_user);   loginparam->send_user   = NULL;
	free(loginparam->send_pw);     loginparam->send_pw     = NULL;
	                          loginparam->server_flags= 0;
}


void dc_loginparam_read(dc_loginparam_t* loginparam, dc_sqlite3_t* sql, const char* prefix)
{
	char* key = NULL;
	#define LP_PREFIX(a) sqlite3_free(key); key=sqlite3_mprintf("%s%s", prefix, (a));

	dc_loginparam_empty(loginparam);

	LP_PREFIX("addr");        loginparam->addr        = dc_sqlite3_get_config      (sql, key, NULL);

	LP_PREFIX("mail_server"); loginparam->mail_server = dc_sqlite3_get_config      (sql, key, NULL);
	LP_PREFIX("mail_port");   loginparam->mail_port   = dc_sqlite3_get_config_int  (sql, key, 0);
	LP_PREFIX("mail_user");   loginparam->mail_user   = dc_sqlite3_get_config      (sql, key, NULL);
	LP_PREFIX("mail_pw");     loginparam->mail_pw     = dc_sqlite3_get_config      (sql, key, NULL);

	LP_PREFIX("send_server"); loginparam->send_server = dc_sqlite3_get_config      (sql, key, NULL);
	LP_PREFIX("send_port");   loginparam->send_port   = dc_sqlite3_get_config_int  (sql, key, 0);
	LP_PREFIX("send_user");   loginparam->send_user   = dc_sqlite3_get_config      (sql, key, NULL);
	LP_PREFIX("send_pw");     loginparam->send_pw     = dc_sqlite3_get_config      (sql, key, NULL);

	LP_PREFIX("server_flags");loginparam->server_flags= dc_sqlite3_get_config_int  (sql, key, 0);

	sqlite3_free(key);
}


void dc_loginparam_write(const dc_loginparam_t* loginparam, dc_sqlite3_t* sql, const char* prefix)
{
	char* key = NULL;

	LP_PREFIX("addr");         dc_sqlite3_set_config      (sql, key, loginparam->addr);

	LP_PREFIX("mail_server");  dc_sqlite3_set_config      (sql, key, loginparam->mail_server);
	LP_PREFIX("mail_port");    dc_sqlite3_set_config_int  (sql, key, loginparam->mail_port);
	LP_PREFIX("mail_user");    dc_sqlite3_set_config      (sql, key, loginparam->mail_user);
	LP_PREFIX("mail_pw");      dc_sqlite3_set_config      (sql, key, loginparam->mail_pw);

	LP_PREFIX("send_server");  dc_sqlite3_set_config      (sql, key, loginparam->send_server);
	LP_PREFIX("send_port");    dc_sqlite3_set_config_int  (sql, key, loginparam->send_port);
	LP_PREFIX("send_user");    dc_sqlite3_set_config      (sql, key, loginparam->send_user);
	LP_PREFIX("send_pw");      dc_sqlite3_set_config      (sql, key, loginparam->send_pw);

	LP_PREFIX("server_flags"); dc_sqlite3_set_config_int  (sql, key, loginparam->server_flags);

	sqlite3_free(key);
}


static char* get_readable_flags(int flags)
{
	dc_strbuilder_t strbuilder;
	dc_strbuilder_init(&strbuilder, 0);
	#define CAT_FLAG(f, s) if ((1<<bit)==(f)) { dc_strbuilder_cat(&strbuilder, (s)); flag_added = 1; }

	for (int bit = 0; bit <= 30; bit++)
	{
		if (flags&(1<<bit))
		{
			int flag_added = 0;

			CAT_FLAG(DC_LP_AUTH_XOAUTH2,         "XOAUTH2 ");
			CAT_FLAG(DC_LP_AUTH_NORMAL,          "AUTH_NORMAL ");

			CAT_FLAG(DC_LP_IMAP_SOCKET_STARTTLS, "IMAP_STARTTLS ");
			CAT_FLAG(DC_LP_IMAP_SOCKET_SSL,      "IMAP_SSL ");
			CAT_FLAG(DC_LP_IMAP_SOCKET_PLAIN,    "IMAP_PLAIN ");

			CAT_FLAG(DC_LP_SMTP_SOCKET_STARTTLS, "SMTP_STARTTLS ");
			CAT_FLAG(DC_LP_SMTP_SOCKET_SSL,      "SMTP_SSL ");
			CAT_FLAG(DC_LP_SMTP_SOCKET_PLAIN,    "SMTP_PLAIN ");

			if (!flag_added) {
				char* temp = dc_mprintf("0x%x ", 1<<bit); dc_strbuilder_cat(&strbuilder, temp); free(temp);
			}
		}
	}

	if (strbuilder.buf[0]==0) { dc_strbuilder_cat(&strbuilder, "0"); }
	dc_trim(strbuilder.buf);
	return strbuilder.buf;
}


char* dc_loginparam_get_readable(const dc_loginparam_t* loginparam)
{
	const char* unset = "0";
	const char* pw = "***";

	if (loginparam==NULL) {
		return dc_strdup(NULL);
	}

	char* flags_readable = get_readable_flags(loginparam->server_flags);

	char* ret = dc_mprintf("%s %s:%s:%s:%i %s:%s:%s:%i %s",
		loginparam->addr? loginparam->addr : unset,

		loginparam->mail_user? loginparam->mail_user : unset,
		loginparam->mail_pw? pw : unset,
		loginparam->mail_server? loginparam->mail_server : unset,
		loginparam->mail_port,

		loginparam->send_user? loginparam->send_user : unset,
		loginparam->send_pw? pw : unset,
		loginparam->send_server? loginparam->send_server : unset,
		loginparam->send_port,

		flags_readable);

	free(flags_readable);
	return ret;
}

