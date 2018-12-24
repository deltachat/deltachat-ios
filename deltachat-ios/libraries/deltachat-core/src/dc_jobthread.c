#include <stdarg.h>
#include <unistd.h>
#include "dc_context.h"
#include "dc_imap.h"


/*******************************************************************************
 * init, exit, suspend-for-configure
 ******************************************************************************/


void dc_jobthread_init(dc_jobthread_t* jobthread, dc_context_t* context, const char* name,
                       const char* folder_config_name)
{
	if (jobthread==NULL || context==NULL || name==NULL) {
		return;
	}

	jobthread->context = context;
	jobthread->name = dc_strdup(name);
	jobthread->folder_config_name = dc_strdup(folder_config_name);

	jobthread->imap = NULL;

	pthread_mutex_init(&jobthread->mutex, NULL);

	pthread_cond_init(&jobthread->idle_cond, NULL);
	jobthread->idle_condflag = 0;

	jobthread->jobs_needed = 0;
	jobthread->suspended = 0;
	jobthread->using_handle = 0;
}


void dc_jobthread_exit(dc_jobthread_t* jobthread)
{
	if (jobthread==NULL) {
		return;
	}

	pthread_cond_destroy(&jobthread->idle_cond);
	pthread_mutex_destroy(&jobthread->mutex);

	free(jobthread->name);
	jobthread->name = NULL;

	free(jobthread->folder_config_name);
	jobthread->folder_config_name = NULL;
}


void dc_jobthread_suspend(dc_jobthread_t* jobthread, int suspend)
{
	if (jobthread==NULL) {
		return;
	}

	if (suspend)
	{
		dc_log_info(jobthread->context, 0, "Suspending %s-thread.", jobthread->name);
		pthread_mutex_lock(&jobthread->mutex);
			jobthread->suspended = 1;
		pthread_mutex_unlock(&jobthread->mutex);

		dc_jobthread_interrupt_idle(jobthread);

		// wait until we're out of idle,
		// after that the handle won't be in use anymore
		while (1) {
			pthread_mutex_lock(&jobthread->mutex);
				if (jobthread->using_handle==0) {
					pthread_mutex_unlock(&jobthread->mutex);
					return;
				}
			pthread_mutex_unlock(&jobthread->mutex);
			usleep(300*1000);
		}
	}
	else
	{
		dc_log_info(jobthread->context, 0, "Unsuspending %s-thread.", jobthread->name);
		pthread_mutex_lock(&jobthread->mutex);
			jobthread->suspended = 0;
			jobthread->idle_condflag = 1;
			pthread_cond_signal(&jobthread->idle_cond);
		pthread_mutex_unlock(&jobthread->mutex);
	}
}


/*******************************************************************************
 * the typical fetch, idle, interrupt-idle
 ******************************************************************************/


static int connect_to_imap(dc_jobthread_t* jobthread)
{
	int   ret_connected = DC_NOT_CONNECTED;
	char* mvbox_name = NULL;

	if(dc_imap_is_connected(jobthread->imap)) {
		ret_connected = DC_ALREADY_CONNECTED;
		goto cleanup;
	}

	if (!(ret_connected=dc_connect_to_configured_imap(jobthread->context, jobthread->imap))) {
		goto cleanup;
	}

	if (dc_sqlite3_get_config_int(jobthread->context->sql, "folders_configured", 0)<DC_FOLDERS_CONFIGURED_VERSION) {
		dc_configure_folders(jobthread->context, jobthread->imap, DC_CREATE_MVBOX);
	}

	mvbox_name = dc_sqlite3_get_config(jobthread->context->sql, jobthread->folder_config_name, NULL);
	if (mvbox_name==NULL) {
		ret_connected = DC_NOT_CONNECTED;
		goto cleanup;
	}

	dc_imap_set_watch_folder(jobthread->imap, mvbox_name);

cleanup:
	free(mvbox_name);
	return ret_connected;
}


void dc_jobthread_fetch(dc_jobthread_t* jobthread, int use_network)
{
	if (jobthread==NULL) {
		return;
	}

	pthread_mutex_lock(&jobthread->mutex);
		if (jobthread->suspended) {
			pthread_mutex_unlock(&jobthread->mutex);
			return;
		}

		jobthread->using_handle = 1;
	pthread_mutex_unlock(&jobthread->mutex);

	if (!use_network || jobthread->imap==NULL) {
		goto cleanup;
	}

	clock_t start = clock();

	if (!connect_to_imap(jobthread)) {
		goto cleanup;
	}

	dc_log_info(jobthread->context, 0, "%s-fetch started...", jobthread->name);
	dc_imap_fetch(jobthread->imap);

	if (jobthread->imap->should_reconnect)
	{
		dc_log_info(jobthread->context, 0, "%s-fetch aborted, starting over...", jobthread->name);
		dc_imap_fetch(jobthread->imap);
	}

	dc_log_info(jobthread->context, 0, "%s-fetch done in %.0f ms.", jobthread->name, (double)(clock()-start)*1000.0/CLOCKS_PER_SEC);

cleanup:
	pthread_mutex_lock(&jobthread->mutex);
		jobthread->using_handle = 0;
	pthread_mutex_unlock(&jobthread->mutex);
}


void dc_jobthread_idle(dc_jobthread_t* jobthread, int use_network)
{
	if (jobthread==NULL) {
		return;
	}

	pthread_mutex_lock(&jobthread->mutex);
		if (jobthread->jobs_needed) {
			dc_log_info(jobthread->context, 0, "%s-IDLE will not be started as it was interrupted while not ideling.", jobthread->name);
			jobthread->jobs_needed = 0;
			pthread_mutex_unlock(&jobthread->mutex);
			return;
		}

		if (jobthread->suspended) {
			while (jobthread->idle_condflag==0) {
				// unlock mutex -> wait -> lock mutex
				pthread_cond_wait(&jobthread->idle_cond, &jobthread->mutex);
			}
			jobthread->idle_condflag = 0;
			pthread_mutex_unlock(&jobthread->mutex);
			return;
		}

		jobthread->using_handle = 1;
	pthread_mutex_unlock(&jobthread->mutex);

	if (!use_network || jobthread->imap==NULL) {
		pthread_mutex_lock(&jobthread->mutex);
			jobthread->using_handle = 0;
			while (jobthread->idle_condflag==0) {
				// unlock mutex -> wait -> lock mutex
				pthread_cond_wait(&jobthread->idle_cond, &jobthread->mutex);
			}
			jobthread->idle_condflag = 0;
		pthread_mutex_unlock(&jobthread->mutex);
		return;
	}

	connect_to_imap(jobthread);

	dc_log_info(jobthread->context, 0, "%s-IDLE started...", jobthread->name);
	dc_imap_idle(jobthread->imap);
	dc_log_info(jobthread->context, 0, "%s-IDLE ended.", jobthread->name);

	pthread_mutex_lock(&jobthread->mutex);
		jobthread->using_handle = 0;
	pthread_mutex_unlock(&jobthread->mutex);
}


void dc_jobthread_interrupt_idle(dc_jobthread_t* jobthread)
{
	if (jobthread==NULL) {
		return;
	}

	pthread_mutex_lock(&jobthread->mutex);
		// when we're not in idle, make sure not to enter it
		jobthread->jobs_needed = 1;
	pthread_mutex_unlock(&jobthread->mutex);

	dc_log_info(jobthread->context, 0, "Interrupting %s-IDLE...", jobthread->name);
	if (jobthread->imap) {
		dc_imap_interrupt_idle(jobthread->imap);
	}

	// in case we're not IMAP-ideling, also raise the signal
	pthread_mutex_lock(&jobthread->mutex);
		jobthread->idle_condflag = 1;
		pthread_cond_signal(&jobthread->idle_cond);
	pthread_mutex_unlock(&jobthread->mutex);
}
