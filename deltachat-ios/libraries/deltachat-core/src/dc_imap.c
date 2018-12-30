#include <stdlib.h>
#include <libetpan/libetpan.h>
#include <sys/stat.h>
#include <string.h>
#include <unistd.h>
#include "dc_context.h"
#include "dc_imap.h"
#include "dc_job.h"
#include "dc_loginparam.h"


static int  setup_handle_if_needed   (dc_imap_t*);
static void unsetup_handle           (dc_imap_t*);

#define FREE_SET(a)        if((a)) { mailimap_set_free((a)); }
#define FREE_FETCH_LIST(a) if((a)) { mailimap_fetch_list_free((a)); }


/*******************************************************************************
 * Tools
 ******************************************************************************/


int dc_imap_is_error(dc_imap_t* imap, int code)
{
	if (code==MAILIMAP_NO_ERROR /*0*/
	 || code==MAILIMAP_NO_ERROR_AUTHENTICATED /*1*/
	 || code==MAILIMAP_NO_ERROR_NON_AUTHENTICATED /*2*/)
	{
		return 0;
	}

	if (code==MAILIMAP_ERROR_STREAM /*4*/
	 || code==MAILIMAP_ERROR_PARSE /*5*/)
	{
		dc_log_info(imap->context, 0, "IMAP stream lost; we'll reconnect soon.");
		imap->should_reconnect = 1;
	}

	return 1;
}


static char* get_error_msg(dc_imap_t* imap, const char* what_failed, int code)
{
	char*           stock = NULL;
	dc_strbuilder_t msg;
	dc_strbuilder_init(&msg, 1000);

	switch (code) {
		case MAILIMAP_ERROR_LOGIN:
			stock = dc_stock_str_repl_string(imap->context, DC_STR_CANNOT_LOGIN, imap->imap_user);
			dc_strbuilder_cat(&msg, stock);
			break;

		default:
			dc_strbuilder_catf(&msg, "%s, IMAP-error #%i", what_failed, code);
			break;
	}
	free(stock);
	stock = NULL;

	if (imap->etpan->imap_response) {
		dc_strbuilder_cat(&msg, "\n\n");
		stock = dc_stock_str_repl_string2(imap->context, DC_STR_SERVER_RESPONSE, imap->imap_server, imap->etpan->imap_response);
		dc_strbuilder_cat(&msg, stock);
	}
	free(stock);
	stock = NULL;

	return msg.buf;
}


static void get_config_lastseenuid(dc_imap_t* imap, const char* folder, uint32_t* uidvalidity, uint32_t* lastseenuid)
{
	*uidvalidity = 0;
	*lastseenuid = 0;

	char* key = dc_mprintf("imap.mailbox.%s", folder);
	char* val1 = imap->get_config(imap, key, NULL), *val2 = NULL, *val3 = NULL;
	if (val1)
	{
		/* the entry has the format `imap.mailbox.<folder>=<uidvalidity>:<lastseenuid>` */
		val2 = strchr(val1, ':');
		if (val2)
		{
			*val2 = 0;
			val2++;

			val3 = strchr(val2, ':');
			if (val3) { *val3 = 0; /* ignore everything bethind an optional second colon to allow future enhancements */ }

			*uidvalidity = atol(val1);
			*lastseenuid = atol(val2);
		}
	}
	free(val1); /* val2 and val3 are only pointers inside val1 and MUST NOT be free()'d */
	free(key);
}


static void set_config_lastseenuid(dc_imap_t* imap, const char* folder, uint32_t uidvalidity, uint32_t lastseenuid)
{
	char* key = dc_mprintf("imap.mailbox.%s", folder);
	char* val = dc_mprintf("%lu:%lu", uidvalidity, lastseenuid);
	imap->set_config(imap, key, val);
	free(val);
	free(key);
}


/*******************************************************************************
 * Handle folders
 ******************************************************************************/


static int select_folder(dc_imap_t* imap, const char* folder /*may be NULL*/)
{
	if (imap==NULL) {
		return 0;
	}

	if (imap->etpan==NULL) {
		imap->selected_folder[0] = 0;
		imap->selected_folder_needs_expunge = 0;
		return 0;
	}

	/* if there is a new folder and the new folder is equal to the selected one, there's nothing to do.
	if there is _no_ new folder, we continue as we might want to expunge below.  */
	if (folder && folder[0] && strcmp(imap->selected_folder, folder)==0) {
		return 1;
	}

	/* deselect existing folder, if needed (it's also done implicitly by SELECT, however, without EXPUNGE then) */
	if (imap->selected_folder_needs_expunge) {
		if (imap->selected_folder[0]) {
			dc_log_info(imap->context, 0, "Expunge messages in \"%s\".", imap->selected_folder);
			mailimap_close(imap->etpan); /* a CLOSE-SELECT is considerably faster than an EXPUNGE-SELECT, see https://tools.ietf.org/html/rfc3501#section-6.4.2 */
		}
		imap->selected_folder_needs_expunge = 0;
	}

	/* select new folder */
	if (folder) {
		int r = mailimap_select(imap->etpan, folder);
		if (dc_imap_is_error(imap, r) || imap->etpan->imap_selection_info==NULL) {
			imap->selected_folder[0] = 0;
			return 0;
		}
	}

	free(imap->selected_folder);
	imap->selected_folder = dc_strdup(folder);
	return 1;
}


/*******************************************************************************
 * Fetch Messages
 ******************************************************************************/


static uint32_t peek_uid(struct mailimap_msg_att* msg_att)
{
	/* search the UID in a list of attributes returned by a FETCH command */
	clistiter* iter1;
	for (iter1=clist_begin(msg_att->att_list); iter1!=NULL; iter1=clist_next(iter1))
	{
		struct mailimap_msg_att_item* item = (struct mailimap_msg_att_item*)clist_content(iter1);
		if (item)
		{
			if (item->att_type==MAILIMAP_MSG_ATT_ITEM_STATIC)
			{
				if (item->att_data.att_static->att_type==MAILIMAP_MSG_ATT_UID)
				{
					return item->att_data.att_static->att_data.att_uid;
				}
			}
		}
	}

	return 0;
}


static char* unquote_rfc724_mid(const char* in)
{
	/* remove < and > from the given message id */
	char* out = dc_strdup(in);
	int   out_len = strlen(out);
	if (out_len > 2) {
		if (out[0]=='<')         { out[0] = ' '; }
		if (out[out_len-1]=='>') { out[out_len-1] = ' '; }
		dc_trim(out);
	}
	return out;
}


static const char* peek_rfc724_mid(struct mailimap_msg_att* msg_att)
{
	if (msg_att==NULL) {
		return NULL;
	}

	/* search the UID in a list of attributes returned by a FETCH command */
	clistiter* iter1;
	for (iter1=clist_begin(msg_att->att_list); iter1!=NULL; iter1=clist_next(iter1))
	{
		struct mailimap_msg_att_item* item = (struct mailimap_msg_att_item*)clist_content(iter1);
		if (item)
		{
			if (item->att_type==MAILIMAP_MSG_ATT_ITEM_STATIC)
			{
				if (item->att_data.att_static->att_type==MAILIMAP_MSG_ATT_ENVELOPE)
				{
					struct mailimap_envelope* env = item->att_data.att_static->att_data.att_env;
					if (env && env->env_message_id) {
						return env->env_message_id;
					}
				}
			}
		}
	}

	return NULL;
}


static int peek_flag_keyword(struct mailimap_msg_att* msg_att, const char* flag_keyword)
{
	/* search $MDNSent in a list of attributes returned by a FETCH command */
	if (msg_att==NULL || msg_att->att_list==NULL || flag_keyword==NULL) {
		return 0;
	}

	clistiter *iter1, *iter2;
	for (iter1=clist_begin(msg_att->att_list); iter1!=NULL; iter1=clist_next(iter1))
	{
		struct mailimap_msg_att_item* item = (struct mailimap_msg_att_item*)clist_content(iter1);
		if (item)
		{
			if (item->att_type==MAILIMAP_MSG_ATT_ITEM_DYNAMIC)
			{
				if (item->att_data.att_dyn->att_list /*I've seen NULL here ...*/)
				{
					for (iter2=clist_begin(item->att_data.att_dyn->att_list); iter2!=NULL ; iter2=clist_next(iter2))
					{
						struct mailimap_flag_fetch* flag_fetch =(struct mailimap_flag_fetch*) clist_content(iter2);
						if (flag_fetch && flag_fetch->fl_type==MAILIMAP_FLAG_FETCH_OTHER)
						{
							struct mailimap_flag* flag = flag_fetch->fl_flag;
							if (flag)
							{
								if (flag->fl_type==MAILIMAP_FLAG_KEYWORD && flag->fl_data.fl_keyword!=NULL
								 && strcmp(flag->fl_data.fl_keyword, flag_keyword)==0) {
									return 1; /* flag found */
								}
							}
						}
					}
				}
			}
		}
	}
	return 0;
}


static void peek_body(struct mailimap_msg_att* msg_att, char** p_msg, size_t* p_msg_bytes, uint32_t* flags, int* deleted)
{
	if (msg_att==NULL) {
		return;
	}
	/* search body & Co. in a list of attributes returned by a FETCH command */
	clistiter *iter1, *iter2;
	for (iter1=clist_begin(msg_att->att_list); iter1!=NULL; iter1=clist_next(iter1))
	{
		struct mailimap_msg_att_item* item = (struct mailimap_msg_att_item*)clist_content(iter1);
		if (item)
		{
			if (item->att_type==MAILIMAP_MSG_ATT_ITEM_DYNAMIC)
			{
				if (item->att_data.att_dyn->att_list /*I've seen NULL here ...*/)
				{
					for (iter2=clist_begin(item->att_data.att_dyn->att_list); iter2!=NULL ; iter2=clist_next(iter2))
					{
						struct mailimap_flag_fetch* flag_fetch =(struct mailimap_flag_fetch*) clist_content(iter2);
						if (flag_fetch && flag_fetch->fl_type==MAILIMAP_FLAG_FETCH_OTHER)
						{
							struct mailimap_flag* flag = flag_fetch->fl_flag;
							if (flag)
							{
								if (flag->fl_type==MAILIMAP_FLAG_SEEN) {
									*flags |= DC_IMAP_SEEN;
								}
								else if (flag->fl_type==MAILIMAP_FLAG_DELETED) {
									*deleted = 1;
								}
							}
						}
					}
				}
			}
			else if (item->att_type==MAILIMAP_MSG_ATT_ITEM_STATIC)
			{
				if (item->att_data.att_static->att_type==MAILIMAP_MSG_ATT_BODY_SECTION)
				{
					*p_msg = item->att_data.att_static->att_data.att_body_section->sec_body_part;
					*p_msg_bytes = item->att_data.att_static->att_data.att_body_section->sec_length;
				}
			}
		}
	}
}


static int fetch_single_msg(dc_imap_t* imap, const char* folder, uint32_t server_uid)
{
	/* the function returns:
	    0  the caller should try over again later
	or  1  if the messages should be treated as received, the caller should not try to read the message again (even if no database entries are returned) */
	char*       msg_content = NULL;
	size_t      msg_bytes = 0;
	int         r = 0;
	int         retry_later = 0;
	int         deleted = 0;
	uint32_t    flags = 0;
	clist*      fetch_result = NULL;
	clistiter*  cur;

	if (imap==NULL) {
		goto cleanup;
	}

	if (imap->etpan==NULL) {
		goto cleanup;
	}


	{
		struct mailimap_set* set = mailimap_set_new_single(server_uid);
			r = mailimap_uid_fetch(imap->etpan, set, imap->fetch_type_body, &fetch_result);
		mailimap_set_free(set);
	}

	if (dc_imap_is_error(imap, r) || fetch_result==NULL) {
		fetch_result = NULL;
		dc_log_warning(imap->context, 0, "Error #%i on fetching message #%i from folder \"%s\"; retry=%i.", (int)r, (int)server_uid, folder, (int)imap->should_reconnect);
		if (imap->should_reconnect) {
			retry_later = 1; /* maybe we should also retry on other errors, however, we should check this carefully, as this may result in a dead lock! */
		}
		goto cleanup; /* this is an error that should be recovered; the caller should try over later to fetch the message again (if there is no such message, we simply get an empty result) */
	}

	if ((cur=clist_begin(fetch_result))==NULL) {
		dc_log_warning(imap->context, 0, "Message #%i does not exist in folder \"%s\".", (int)server_uid, folder);
		goto cleanup; /* server response is fine, however, there is no such message, do not try to fetch the message again */
	}

	struct mailimap_msg_att* msg_att = (struct mailimap_msg_att*)clist_content(cur);
	peek_body(msg_att, &msg_content, &msg_bytes, &flags, &deleted);
	if (msg_content==NULL  || msg_bytes <= 0 || deleted) {
		/* dc_log_warning(imap->context, 0, "Message #%i in folder \"%s\" is empty or deleted.", (int)server_uid, folder); -- this is a quite usual situation, do not print a warning */
		goto cleanup;
	}

	imap->receive_imf(imap, msg_content, msg_bytes, folder, server_uid, flags);

cleanup:

	if (fetch_result) {
		mailimap_fetch_list_free(fetch_result);
	}
	return retry_later? 0 : 1;
}


static int fetch_from_single_folder(dc_imap_t* imap, const char* folder)
{
	int                  r;
	uint32_t             uidvalidity = 0;
	uint32_t             lastseenuid = 0;
	uint32_t             new_lastseenuid = 0;
	clist*               fetch_result = NULL;
	size_t               read_cnt = 0;
	size_t               read_errors = 0;
	clistiter*           cur;
	struct mailimap_set* set;

	if (imap==NULL) {
		goto cleanup;
	}

	if (imap->etpan==NULL) {
		dc_log_info(imap->context, 0, "Cannot fetch from \"%s\" - not connected.", folder);
		goto cleanup;
	}

	if (select_folder(imap, folder)==0) {
		dc_log_warning(imap->context, 0, "Cannot select folder %s for fetching.", folder);
		goto cleanup;
	}

	/* compare last seen UIDVALIDITY against the current one */
	get_config_lastseenuid(imap, folder, &uidvalidity, &lastseenuid);
	if (uidvalidity!=imap->etpan->imap_selection_info->sel_uidvalidity)
	{
		/* first time this folder is selected or UIDVALIDITY has changed, init lastseenuid and save it to config */
		if (imap->etpan->imap_selection_info->sel_uidvalidity <= 0) {
			dc_log_error(imap->context, 0, "Cannot get UIDVALIDITY for folder \"%s\".", folder);
			goto cleanup;
		}

		if (imap->etpan->imap_selection_info->sel_has_exists) {
			if (imap->etpan->imap_selection_info->sel_exists <= 0) {
				dc_log_info(imap->context, 0, "Folder \"%s\" is empty.", folder);
				goto cleanup;
			}
			/* `FETCH <message sequence number> (UID)` */
			set = mailimap_set_new_single(imap->etpan->imap_selection_info->sel_exists);
		}
		else {
			/* `FETCH * (UID)` - according to RFC 3501, `*` represents the largest message sequence number; if the mailbox is empty,
			an error resp. an empty list is returned. */
			dc_log_info(imap->context, 0, "EXISTS is missing for folder \"%s\", using fallback.", folder);
			set = mailimap_set_new_single(0);
		}
		r = mailimap_fetch(imap->etpan, set, imap->fetch_type_prefetch, &fetch_result);
		mailimap_set_free(set);

		if (dc_imap_is_error(imap, r) || fetch_result==NULL || (cur=clist_begin(fetch_result))==NULL) {
			dc_log_info(imap->context, 0, "Empty result returned for folder \"%s\".", folder);
			goto cleanup; /* this might happen if the mailbox is empty an EXISTS does not work */
		}

		struct mailimap_msg_att* msg_att = (struct mailimap_msg_att*)clist_content(cur);
		lastseenuid = peek_uid(msg_att);
		mailimap_fetch_list_free(fetch_result);
		fetch_result = NULL;
		if (lastseenuid <= 0) {
			dc_log_error(imap->context, 0, "Cannot get largest UID for folder \"%s\"", folder);
			goto cleanup;
		}

		/* if the UIDVALIDITY has _changed_, decrease lastseenuid by one to avoid gaps (well add 1 below) */
		if (uidvalidity > 0 && lastseenuid > 1) {
			lastseenuid -= 1;
		}

		/* store calculated uidvalidity/lastseenuid */
		uidvalidity = imap->etpan->imap_selection_info->sel_uidvalidity;
		set_config_lastseenuid(imap, folder, uidvalidity, lastseenuid);
	}

	/* fetch messages with larger UID than the last one seen (`UID FETCH lastseenuid+1:*)`, see RFC 4549 */
	set = mailimap_set_new_interval(lastseenuid+1, 0);
		r = mailimap_uid_fetch(imap->etpan, set, imap->fetch_type_prefetch, &fetch_result);
	mailimap_set_free(set);

	if (dc_imap_is_error(imap, r) || fetch_result==NULL)
	{
		fetch_result = NULL;
		if (r==MAILIMAP_ERROR_PROTOCOL) {
			dc_log_info(imap->context, 0, "Folder \"%s\" is empty", folder);
			goto cleanup; /* the folder is simply empty, this is no error */
		}
		dc_log_warning(imap->context, 0, "Cannot fetch message list from folder \"%s\".", folder);
		goto cleanup;
	}

	/* go through all mails in folder (this is typically _fast_ as we already have the whole list) */
	for (cur = clist_begin(fetch_result); cur!=NULL ; cur = clist_next(cur))
	{
		struct mailimap_msg_att* msg_att = (struct mailimap_msg_att*)clist_content(cur); /* mailimap_msg_att is a list of attributes: list is a list of message attributes */
		uint32_t cur_uid = peek_uid(msg_att);
		if (cur_uid > 0
		 && cur_uid!=lastseenuid /* `UID FETCH <lastseenuid+1>:*` may include lastseenuid if "*"==lastseenuid */)
		{
			char* rfc724_mid = unquote_rfc724_mid(peek_rfc724_mid(msg_att));

			read_cnt++;
			if (!imap->precheck_imf(imap, rfc724_mid, folder, cur_uid)) {
				if (fetch_single_msg(imap, folder, cur_uid)==0/* 0=try again later*/) {
					read_errors++; // with read_errors, lastseenuid is not written
				}
			}
			else {
				dc_log_info(imap->context, 0, "Skipping message %s by precheck.", rfc724_mid);
			}

			if (cur_uid > new_lastseenuid) {
				new_lastseenuid = cur_uid;
			}

			free(rfc724_mid);
		}
	}

	if (!read_errors && new_lastseenuid > 0) {
		set_config_lastseenuid(imap, folder, uidvalidity, new_lastseenuid);
	}

	/* done */
cleanup:

	if (read_errors) {
		dc_log_warning(imap->context, 0, "%i mails read from \"%s\" with %i errors.", (int)read_cnt, folder, (int)read_errors);
	}
	else {
		dc_log_info(imap->context, 0, "%i mails read from \"%s\".", (int)read_cnt, folder);
	}

	if (fetch_result) {
		mailimap_fetch_list_free(fetch_result);
	}

	return read_cnt;
}


/*******************************************************************************
 * Watch thread
 ******************************************************************************/


int dc_imap_fetch(dc_imap_t* imap)
{
	int   success = 0;

	if (imap==NULL || !imap->connected) {
		goto cleanup;
	}

	setup_handle_if_needed(imap);

	// as during the fetch commands, new messages may arrive, we fetch until we do not
	// get any more. if IDLE is called directly after, there is only a small chance that
	// messages are missed and delayed until the next IDLE call
	while (fetch_from_single_folder(imap, imap->watch_folder) > 0) {
		;
	}

	success = 1;

cleanup:
	return success;
}


static void fake_idle(dc_imap_t* imap)
{
	/* Idle using timeouts. This is also needed if we're not yet configured -
	in this case, we're waiting for a configure job */

	time_t fake_idle_start_time = time(NULL);
	time_t seconds_to_wait = 0;

	dc_log_info(imap->context, 0, "IMAP-fake-IDLEing...");

	int do_fake_idle = 1;
	while (do_fake_idle)
	{
		// wait a moment: every 5 seconds in the first 3 minutes after a new message, after that every 60 seconds
		seconds_to_wait = (time(NULL)-fake_idle_start_time < 3*60)? 5 : 60;
		pthread_mutex_lock(&imap->watch_condmutex);

			int r = 0;
			struct timespec wakeup_at;
			memset(&wakeup_at, 0, sizeof(wakeup_at));
			wakeup_at.tv_sec  = time(NULL)+seconds_to_wait;
			while (imap->watch_condflag==0 && r==0) {
				r = pthread_cond_timedwait(&imap->watch_cond, &imap->watch_condmutex, &wakeup_at); /* unlock mutex -> wait -> lock mutex */
				if (imap->watch_condflag) {
					do_fake_idle = 0;
				}
			}
			imap->watch_condflag = 0;

		pthread_mutex_unlock(&imap->watch_condmutex);

		if (do_fake_idle==0) {
			return;
		}

		// check for new messages. fetch_from_single_folder() has the side-effect that messages
		// are also downloaded, however, typically this would take place in the FETCH command
		// following IDLE otherwise, so this seems okay here.
		if (setup_handle_if_needed(imap)) { // the handle may not be set up if configure is not yet done
			if (fetch_from_single_folder(imap, imap->watch_folder)) {
				do_fake_idle = 0;
			}
		}
		else {
			// if we cannot connect, set the starting time to a small value which will
			// result in larger timeouts (60 instead of 5 seconds) for re-checking the availablility of network.
			// to get the _exact_ moment of re-available network, the ui should call interrupt_idle()
			fake_idle_start_time = 0;
		}
	}
}


void dc_imap_idle(dc_imap_t* imap)
{
	int   r = 0;
	int   r2 = 0;

	if (imap==NULL) {
		goto cleanup;
	}

	if (imap->can_idle)
	{
		setup_handle_if_needed(imap);

		if (imap->idle_set_up==0 && imap->etpan && imap->etpan->imap_stream) {
			r = mailstream_setup_idle(imap->etpan->imap_stream);
			if (dc_imap_is_error(imap, r)) {
				dc_log_warning(imap->context, 0, "IMAP-IDLE: Cannot setup.");
				fake_idle(imap);
				goto cleanup;
			}
			imap->idle_set_up = 1;
		}

		if (!imap->idle_set_up || !select_folder(imap, imap->watch_folder)) {
			dc_log_warning(imap->context, 0, "IMAP-IDLE not setup.");
			fake_idle(imap);
			goto cleanup;
		}

		r = mailimap_idle(imap->etpan);
		if (dc_imap_is_error(imap, r)) {
			dc_log_warning(imap->context, 0, "IMAP-IDLE: Cannot start.");
			fake_idle(imap);
			goto cleanup;
		}

		// most servers do not allow more than ~28 minutes; stay clearly below that.
		// a good value that is also used by other MUAs is 23 minutes.
		// if needed, the ui can call dc_imap_interrupt_idle() to trigger a reconnect.
		#define IDLE_DELAY_SECONDS (23*60)

		r = mailstream_wait_idle(imap->etpan->imap_stream, IDLE_DELAY_SECONDS);
		r2 = mailimap_idle_done(imap->etpan);

		if (r==MAILSTREAM_IDLE_ERROR /*0*/ || r==MAILSTREAM_IDLE_CANCELLED /*4*/) {
			dc_log_info(imap->context, 0, "IMAP-IDLE wait cancelled, r=%i, r2=%i; we'll reconnect soon.", r, r2);
			imap->should_reconnect = 1;
		}
		else if (r==MAILSTREAM_IDLE_INTERRUPTED /*1*/) {
			dc_log_info(imap->context, 0, "IMAP-IDLE interrupted.");
		}
		else if (r== MAILSTREAM_IDLE_HASDATA /*2*/) {
			dc_log_info(imap->context, 0, "IMAP-IDLE has data.");
		}
		else if (r==MAILSTREAM_IDLE_TIMEOUT /*3*/) {
			dc_log_info(imap->context, 0, "IMAP-IDLE timeout.");
		}
		else {
			dc_log_warning(imap->context, 0, "IMAP-IDLE returns unknown value r=%i, r2=%i.", r, r2);
		}
	}
	else
	{
		fake_idle(imap);
	}

cleanup:
	;
}


void dc_imap_interrupt_idle(dc_imap_t* imap)
{
	if (imap==NULL) {
		return;
	}

	if (imap->can_idle)
	{
		if (imap->etpan && imap->etpan->imap_stream) {
			mailstream_interrupt_idle(imap->etpan->imap_stream);
		}
	}

	// always signal the fake-idle as it may be used if the real-idle is not available for any reasons (no network ...)
	pthread_mutex_lock(&imap->watch_condmutex);
		imap->watch_condflag = 1;
		pthread_cond_signal(&imap->watch_cond);
	pthread_mutex_unlock(&imap->watch_condmutex);
}


/*******************************************************************************
 * Setup handle
 ******************************************************************************/


static int setup_handle_if_needed(dc_imap_t* imap)
{
	int r = 0;
	int success = 0;

	if (imap==NULL || imap->imap_server==NULL) {
		goto cleanup;
	}

    if (imap->should_reconnect) {
		unsetup_handle(imap);
    }

    if (imap->etpan) {
		success = 1;
		goto cleanup;
    }

	imap->etpan = mailimap_new(0, NULL);

	mailimap_set_timeout(imap->etpan, DC_IMAP_TIMEOUT_SEC);

	if (imap->server_flags&(DC_LP_IMAP_SOCKET_STARTTLS|DC_LP_IMAP_SOCKET_PLAIN))
	{
		r = mailimap_socket_connect(imap->etpan, imap->imap_server, imap->imap_port);
		if (dc_imap_is_error(imap, r)) {
			dc_log_event_seq(imap->context, DC_EVENT_ERROR_NETWORK, &imap->log_connect_errors,
				"Could not connect to IMAP-server %s:%i. (Error #%i)", imap->imap_server, (int)imap->imap_port, (int)r);
			goto cleanup;
		}

		if (imap->server_flags&DC_LP_IMAP_SOCKET_STARTTLS)
		{
			r = mailimap_socket_starttls(imap->etpan);
			if (dc_imap_is_error(imap, r)) {
				dc_log_event_seq(imap->context, DC_EVENT_ERROR_NETWORK, &imap->log_connect_errors,
					"Could not connect to IMAP-server %s:%i using STARTTLS. (Error #%i)", imap->imap_server, (int)imap->imap_port, (int)r);
				goto cleanup;
			}
			dc_log_info(imap->context, 0, "IMAP-server %s:%i STARTTLS-connected.", imap->imap_server, (int)imap->imap_port);
		}
		else
		{
			dc_log_info(imap->context, 0, "IMAP-server %s:%i connected.", imap->imap_server, (int)imap->imap_port);
		}
	}
	else
	{
		r = mailimap_ssl_connect(imap->etpan, imap->imap_server, imap->imap_port);
		if (dc_imap_is_error(imap, r)) {
			dc_log_event_seq(imap->context, DC_EVENT_ERROR_NETWORK, &imap->log_connect_errors,
				"Could not connect to IMAP-server %s:%i using SSL. (Error #%i)", imap->imap_server, (int)imap->imap_port, (int)r);
			goto cleanup;
		}
		dc_log_info(imap->context, 0, "IMAP-server %s:%i SSL-connected.", imap->imap_server, (int)imap->imap_port);
	}

	/* TODO: There are more authorisation types, see mailcore2/MCIMAPSession.cpp, however, I'm not sure of they are really all needed */
	/*if (imap->server_flags&DC_LP_AUTH_XOAUTH2)
	{
		//TODO: Support XOAUTH2, we "just" need to get the token someway. If we do so, there is no more need for the user to enable
		//https://www.google.com/settings/security/lesssecureapps - however, maybe this is also not needed if the user had enabled 2-factor-authorisation.
		if (mOAuth2Token==NULL) {
			r = MAILIMAP_ERROR_STREAM;
		}
		else {
			r = mailimap_oauth2_authenticate(imap->etpan, imap->imap_use, mOAuth2Token);
		}
	}
	else*/
	{
		/* DC_LP_AUTH_NORMAL or no auth flag set */
		r = mailimap_login(imap->etpan, imap->imap_user, imap->imap_pw);
	}

	if (dc_imap_is_error(imap, r)) {
		char* msg = get_error_msg(imap, "Cannot login", r);
		dc_log_event_seq(imap->context, DC_EVENT_ERROR_NETWORK, &imap->log_connect_errors,
			"%s", msg);
		free(msg);
		goto cleanup;
	}

	dc_log_event(imap->context, DC_EVENT_IMAP_CONNECTED, 0,
                 "IMAP-login as %s ok.", imap->imap_user);

	success = 1;

cleanup:
	if (success==0) {
		unsetup_handle(imap);
	}

	imap->should_reconnect = 0;
	return success;
}


static void unsetup_handle(dc_imap_t* imap)
{
	if (imap==NULL) {
		return;
	}

	if (imap->etpan)
	{
		if (imap->idle_set_up) {
			mailstream_unsetup_idle(imap->etpan->imap_stream);
			imap->idle_set_up = 0;
		}

		if (imap->etpan->imap_stream!=NULL) {
			mailstream_close(imap->etpan->imap_stream); /* not sure, if this is really needed, however, mailcore2 does the same */
			imap->etpan->imap_stream = NULL;
		}

		mailimap_free(imap->etpan);
		imap->etpan = NULL;

		dc_log_info(imap->context, 0, "IMAP disconnected.");
	}

	imap->selected_folder[0] = 0;

	/* we leave sent_folder set; normally this does not change in a normal reconnect; we'll update this folder if we get errors */
}


/*******************************************************************************
 * Connect/Disconnect
 ******************************************************************************/


static void free_connect_param(dc_imap_t* imap)
{
	free(imap->imap_server);
	imap->imap_server = NULL;

	free(imap->imap_user);
	imap->imap_user = NULL;

	free(imap->imap_pw);
	imap->imap_pw = NULL;

	imap->watch_folder[0] = 0;

	imap->selected_folder[0] = 0;

	imap->imap_port = 0;
	imap->can_idle  = 0;
	imap->has_xlist = 0;
}


int dc_imap_connect(dc_imap_t* imap, const dc_loginparam_t* lp)
{
	int success = 0;

	if (imap==NULL || lp==NULL
	 || lp->mail_server==NULL || lp->mail_user==NULL || lp->mail_pw==NULL) {
		return 0;
	}

	if (imap->connected) {
		success = 1;
		goto cleanup;
	}

	imap->imap_server  = dc_strdup(lp->mail_server);
	imap->imap_port    = lp->mail_port;
	imap->imap_user    = dc_strdup(lp->mail_user);
	imap->imap_pw      = dc_strdup(lp->mail_pw);
	imap->server_flags = lp->server_flags;

	if (!setup_handle_if_needed(imap)) {
		goto cleanup;
	}

	/* we set the following flags here and not in setup_handle_if_needed() as they must not change during connection */
	imap->can_idle = mailimap_has_idle(imap->etpan);
	imap->has_xlist = mailimap_has_xlist(imap->etpan);

	#ifdef __APPLE__
	imap->can_idle = 0; // HACK to force iOS not to work IMAP-IDLE which does not work for now, see also (*)
	#endif


	if (!imap->skip_log_capabilities
	 && imap->etpan->imap_connection_info && imap->etpan->imap_connection_info->imap_capability)
	{
		/* just log the whole capabilities list (the mailimap_has_*() function also use this list, so this is a good overview on problems) */
		imap->skip_log_capabilities = 1;
		dc_strbuilder_t capinfostr;
		dc_strbuilder_init(&capinfostr, 0);
		clist* list = imap->etpan->imap_connection_info->imap_capability->cap_list;
		if (list) {
			clistiter* cur;
			for(cur = clist_begin(list) ; cur!=NULL ; cur = clist_next(cur)) {
				struct mailimap_capability * cap = clist_content(cur);
				if (cap && cap->cap_type==MAILIMAP_CAPABILITY_NAME) {
					dc_strbuilder_cat(&capinfostr, " ");
					dc_strbuilder_cat(&capinfostr, cap->cap_data.cap_name);
				}
			}
		}
		dc_log_info(imap->context, 0, "IMAP-capabilities:%s", capinfostr.buf);
		free(capinfostr.buf);
	}

	imap->connected = 1;
	success = 1;

cleanup:
	if (success==0) {
		unsetup_handle(imap);
		free_connect_param(imap);
	}
	return success;
}


void dc_imap_disconnect(dc_imap_t* imap)
{
	if (imap==NULL) {
		return;
	}

	if (imap->connected)
	{
		unsetup_handle(imap);
		free_connect_param(imap);
		imap->connected = 0;
	}
}


int dc_imap_is_connected(const dc_imap_t* imap)
{
	return (imap && imap->connected);
}


void dc_imap_set_watch_folder(dc_imap_t* imap, const char* watch_folder)
{
	if (imap==NULL || watch_folder==NULL) {
		return;
	}

	free(imap->watch_folder);
	imap->watch_folder = dc_strdup(watch_folder);
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


dc_imap_t* dc_imap_new(dc_get_config_t get_config, dc_set_config_t set_config,
                       dc_precheck_imf_t precheck_imf, dc_receive_imf_t receive_imf,
                       void* userData, dc_context_t* context)
{
	dc_imap_t* imap = NULL;

	if ((imap=calloc(1, sizeof(dc_imap_t)))==NULL) {
		exit(25); /* cannot allocate little memory, unrecoverable error */
	}

	imap->log_connect_errors = 1;

	imap->context        = context;
	imap->get_config     = get_config;
	imap->set_config     = set_config;
	imap->precheck_imf   = precheck_imf;
	imap->receive_imf    = receive_imf;
	imap->userData       = userData;

	pthread_mutex_init(&imap->watch_condmutex, NULL);
	pthread_cond_init(&imap->watch_cond, NULL);

	//imap->enter_watch_wait_time = 0;

	imap->watch_folder = calloc(1, 1);
	imap->selected_folder = calloc(1, 1);

	/* create some useful objects */

	// object to fetch UID and Message-Id
	//
	// TODO: we're using `FETCH ... (... ENVELOPE)` currently,
	//   mainly because peek_rfc724_mid() can handle this structure
	//   and it is easier wrt to libEtPan.
	//   however, if the other ENVELOPE fields are known to be not needed in the near future,
	//   this could be changed to `FETCH ... (... BODY[HEADER.FIELDS (MESSAGE-ID)])`
	imap->fetch_type_prefetch = mailimap_fetch_type_new_fetch_att_list_empty();
	mailimap_fetch_type_new_fetch_att_list_add(imap->fetch_type_prefetch, mailimap_fetch_att_new_uid());
	mailimap_fetch_type_new_fetch_att_list_add(imap->fetch_type_prefetch, mailimap_fetch_att_new_envelope());

	// object to fetch flags and body
	imap->fetch_type_body = mailimap_fetch_type_new_fetch_att_list_empty();
	mailimap_fetch_type_new_fetch_att_list_add(imap->fetch_type_body, mailimap_fetch_att_new_flags());
	mailimap_fetch_type_new_fetch_att_list_add(imap->fetch_type_body, mailimap_fetch_att_new_body_peek_section(mailimap_section_new(NULL)));

	// object to fetch flags only
	imap->fetch_type_flags = mailimap_fetch_type_new_fetch_att_list_empty();
	mailimap_fetch_type_new_fetch_att_list_add(imap->fetch_type_flags, mailimap_fetch_att_new_flags());

    return imap;
}


void dc_imap_unref(dc_imap_t* imap)
{
	if (imap==NULL) {
		return;
	}

	dc_imap_disconnect(imap);

	pthread_cond_destroy(&imap->watch_cond);
	pthread_mutex_destroy(&imap->watch_condmutex);
	free(imap->watch_folder);
	free(imap->selected_folder);
	if (imap->fetch_type_prefetch)   { mailimap_fetch_type_free(imap->fetch_type_prefetch); }
	if (imap->fetch_type_body)       { mailimap_fetch_type_free(imap->fetch_type_body); }
	if (imap->fetch_type_flags)      { mailimap_fetch_type_free(imap->fetch_type_flags); }
	free(imap);
}


static int add_flag(dc_imap_t* imap, uint32_t server_uid, struct mailimap_flag* flag)
{
	int                              r = 0;
	struct mailimap_flag_list*       flag_list = NULL;
	struct mailimap_store_att_flags* store_att_flags = NULL;
	struct mailimap_set*             set = mailimap_set_new_single(server_uid);

	if (imap==NULL || imap->etpan==NULL) {
		goto cleanup;
	}

	flag_list = mailimap_flag_list_new_empty();
	mailimap_flag_list_add(flag_list, flag);

	store_att_flags = mailimap_store_att_flags_new_add_flags(flag_list); /* FLAGS.SILENT does not return the new value */

	r = mailimap_uid_store(imap->etpan, set, store_att_flags);
	if (dc_imap_is_error(imap, r)) {
		goto cleanup;
	}

cleanup:
	if (store_att_flags) {
		mailimap_store_att_flags_free(store_att_flags);
	}
	if (set) {
		mailimap_set_free(set);
	}
	return imap->should_reconnect? 0 : 1; /* all non-connection states are treated as success - the mail may already be deleted or moved away on the server */
}


dc_imap_res dc_imap_move(dc_imap_t* imap, const char* folder, uint32_t uid,
                         const char* dest_folder, uint32_t* dest_uid)
{
	dc_imap_res          res = DC_RETRY_LATER;
	int                  r = 0;
	struct mailimap_set* set = mailimap_set_new_single(uid);
	uint32_t             res_uid = 0;
	struct mailimap_set* res_setsrc = NULL;
	struct mailimap_set* res_setdest = NULL;

	if (imap==NULL || folder==NULL || uid==0
	 || dest_folder==NULL || dest_uid==NULL || set==NULL) {
		res = DC_FAILED;
		goto cleanup;
	}

    if (strcasecmp(folder, dest_folder)==0) {
		dc_log_info(imap->context, 0, "Skip moving message; message %s/%i is already in %s...", folder, (int)uid, dest_folder);
		res = DC_ALREADY_DONE;
		goto cleanup;
    }

	dc_log_info(imap->context, 0, "Moving message %s/%i to %s...", folder, (int)uid, dest_folder);

	if (select_folder(imap, folder)==0) {
		dc_log_warning(imap->context, 0, "Cannot select folder %s for moving message.", folder);
		goto cleanup;
	}

	/* TODO/TOCHECK: UIDPLUS extension may not be supported on servers;
	if in doubt, we can find out the resulting UID using "imap_selection_info->sel_uidnext" then */

	r = mailimap_uidplus_uid_move(imap->etpan, set, dest_folder, &res_uid, &res_setsrc, &res_setdest);
	if (dc_imap_is_error(imap, r)) {
		dc_log_info(imap->context, 0, "Cannot move message, fallback to COPY/DELETE %s/%i to %s...", folder, (int)uid, dest_folder);
		r = mailimap_uidplus_uid_copy(imap->etpan, set, dest_folder, &res_uid, &res_setsrc, &res_setdest);
		if (dc_imap_is_error(imap, r)) {
			dc_log_info(imap->context, 0, "Cannot copy message.");
			goto cleanup;
		}
		else {
			if (add_flag(imap, uid, mailimap_flag_new_deleted())==0) {
				dc_log_warning(imap->context, 0, "Cannot mark message as \"Deleted\".");
			}

			// force an EXPUNGE resp. CLOSE for the selected folder
			imap->selected_folder_needs_expunge = 1;
		}
	}

	if (res_setdest) {
		clistiter* cur = clist_begin(res_setdest->set_list);
		if (cur!=NULL) {
			struct mailimap_set_item* item;
			item = clist_content(cur);
			*dest_uid = item->set_first;
		}
		mailimap_set_free(res_setdest);
	}

	res = DC_SUCCESS;

cleanup:
	FREE_SET(set);
	FREE_SET(res_setsrc);
	return res==DC_RETRY_LATER?
		(imap->should_reconnect? DC_RETRY_LATER : DC_FAILED) : res;
}


dc_imap_res dc_imap_set_seen(dc_imap_t* imap, const char* folder, uint32_t uid)
{
	dc_imap_res res = DC_RETRY_LATER;

	if (imap==NULL || folder==NULL || uid==0) {
		res = DC_FAILED;
		goto cleanup;
	}

	if (imap->etpan==NULL) {
		goto cleanup;
	}

	dc_log_info(imap->context, 0, "Marking message %s/%i as seen...", folder, (int)uid);

	if (select_folder(imap, folder)==0) {
		dc_log_warning(imap->context, 0, "Cannot select folder %s for setting SEEN flag.", folder);
		goto cleanup;
	}

	if (add_flag(imap, uid, mailimap_flag_new_seen())==0) {
		dc_log_warning(imap->context, 0, "Cannot mark message as seen.");
		goto cleanup;
	}

	res = DC_SUCCESS;

cleanup:
	return res==DC_RETRY_LATER?
		(imap->should_reconnect? DC_RETRY_LATER : DC_FAILED) : res;
}


dc_imap_res dc_imap_set_mdnsent(dc_imap_t* imap, const char* folder, uint32_t uid)
{
	// returns 0=job should be retried later, 1=job done, 2=job done and flag just set
	dc_imap_res          res = DC_RETRY_LATER;
	struct mailimap_set* set = mailimap_set_new_single(uid);
	clist*               fetch_result = NULL;

	if (imap==NULL || folder==NULL || uid==0 || set==NULL) {
		res = DC_FAILED;
		goto cleanup;
	}

	if (imap->etpan==NULL) {
		goto cleanup;
	}

	dc_log_info(imap->context, 0, "Marking message %s/%i as $MDNSent...", folder, (int)uid);

	if (select_folder(imap, folder)==0) {
		dc_log_warning(imap->context, 0, "Cannot select folder %s for setting $MDNSent flag.", folder);
		goto cleanup;
	}

	/* Check if the folder can handle the `$MDNSent` flag (see RFC 3503).  If so, and not set: set the flags and return this information.
	If the folder cannot handle the `$MDNSent` flag, we risk duplicated MDNs; it's up to the receiving MUA to handle this then (eg. Delta Chat has no problem with this). */
	int can_create_flag = 0;
	if (imap->etpan->imap_selection_info!=NULL
	 && imap->etpan->imap_selection_info->sel_perm_flags!=NULL)
	{
		clistiter* iter;
		for (iter=clist_begin(imap->etpan->imap_selection_info->sel_perm_flags); iter!=NULL; iter=clist_next(iter))
		{
			struct mailimap_flag_perm* fp = (struct mailimap_flag_perm*)clist_content(iter);
			if (fp) {
				if (fp->fl_type==MAILIMAP_FLAG_PERM_ALL) {
					can_create_flag = 1;
					break;
				}
				else if (fp->fl_type==MAILIMAP_FLAG_PERM_FLAG && fp->fl_flag) {
					struct mailimap_flag* fl = (struct mailimap_flag*)fp->fl_flag;
					if (fl->fl_type==MAILIMAP_FLAG_KEYWORD
					 && fl->fl_data.fl_keyword
					 && strcmp(fl->fl_data.fl_keyword, "$MDNSent")==0) {
						can_create_flag = 1;
						break;
					}
				}
			}
		}
	}

	if (can_create_flag)
	{
		int r = mailimap_uid_fetch(imap->etpan, set, imap->fetch_type_flags, &fetch_result);
		if (dc_imap_is_error(imap, r) || fetch_result==NULL) {
			goto cleanup;
		}

		clistiter* cur=clist_begin(fetch_result);
		if (cur==NULL) {
			goto cleanup;
		}

		if (peek_flag_keyword((struct mailimap_msg_att*)clist_content(cur), "$MDNSent")) {
			res = DC_ALREADY_DONE;
		}
		else {
			if (add_flag(imap, uid, mailimap_flag_new_flag_keyword(dc_strdup("$MDNSent")))==0) {
				goto cleanup;
			}
			res = DC_SUCCESS;
		}

		dc_log_info(imap->context, 0, res==DC_SUCCESS? "$MDNSent just set and MDN will be sent." : "$MDNSent already set and MDN already sent.");
	}
	else
	{
		res = DC_SUCCESS;
		dc_log_info(imap->context, 0, "Cannot store $MDNSent flags, risk sending duplicate MDN.");
	}

cleanup:
	FREE_SET(set);
	FREE_FETCH_LIST(fetch_result);
	return res==DC_RETRY_LATER?
		(imap->should_reconnect? DC_RETRY_LATER : DC_FAILED) : res;
}


int dc_imap_delete_msg(dc_imap_t* imap, const char* rfc724_mid, const char* folder, uint32_t server_uid)
{
	int    success = 0;
	int    r = 0;
	clist* fetch_result = NULL;
	char*  is_rfc724_mid = NULL;
	char*  new_folder = NULL;

	if (imap==NULL || rfc724_mid==NULL || folder==NULL || folder[0]==0) {
		success = 1; /* job done, do not try over */
		goto cleanup;
	}

	dc_log_info(imap->context, 0, "Marking message \"%s\", %s/%i for deletion...", rfc724_mid, folder, (int)server_uid);

	if (select_folder(imap, folder)==0) {
		dc_log_warning(imap->context, 0, "Cannot select folder %s for deleting message.", folder);
		goto cleanup;
	}

	/* check if Folder+UID matches the Message-ID (to detect if the messages
	was moved around by other MUAs and in place of an UIDVALIDITY check)
	*/
	if (server_uid)
	{
		clistiter* cur = NULL;
		const char* is_quoted_rfc724_mid = NULL;

		struct mailimap_set* set = mailimap_set_new_single(server_uid);
			r = mailimap_uid_fetch(imap->etpan, set, imap->fetch_type_prefetch, &fetch_result);
		mailimap_set_free(set);

		if (dc_imap_is_error(imap, r) || fetch_result==NULL
		 || (cur=clist_begin(fetch_result))==NULL
		 || (is_quoted_rfc724_mid=peek_rfc724_mid((struct mailimap_msg_att*)clist_content(cur)))==NULL
		 || (is_rfc724_mid=unquote_rfc724_mid(is_quoted_rfc724_mid))==NULL
		 || strcmp(is_rfc724_mid, rfc724_mid)!=0)
		{
			dc_log_warning(imap->context, 0, "UID not found in the given folder or does not match Message-ID.");
			server_uid = 0;
		}
	}

	/* server_uid is 0 now if it was not given or if it does not match the given message id;
	try to search for it in all folders (the message may be moved by another MUA to a folder we do not sync or the sync is a moment ago) */
	if (server_uid==0) {
			dc_log_warning(imap->context, 0, "Message-ID \"%s\" not found in any folder, cannot delete message.", rfc724_mid);
			goto cleanup;
	}


	/* mark the message for deletion */
	if (add_flag(imap, server_uid, mailimap_flag_new_deleted())==0) {
		dc_log_warning(imap->context, 0, "Cannot mark message as \"Deleted\"."); /* maybe the message is already deleted */
		goto cleanup;
	}

	/* force an EXPUNGE resp. CLOSE for the selected folder */
	imap->selected_folder_needs_expunge = 1;

	success = 1;

cleanup:

	if (fetch_result) { mailimap_fetch_list_free(fetch_result); }
	free(is_rfc724_mid);
	free(new_folder);

	return success? 1 : dc_imap_is_connected(imap); /* only return 0 on connection problems; we should try later again in this case */

}

