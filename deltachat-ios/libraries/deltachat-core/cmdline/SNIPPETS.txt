/*******************************************************************************
 * Restoring
 ******************************************************************************/

mrimap_t: ...
	pthread_t             m_restore_thread;
	int                   m_restore_thread_created;
	int                   m_restore_do_exit;


mrimap_disconnect: ...
		if( ths->m_restore_thread_created )
		{
			mrmailbox_log_info(ths->m_mailbox, 0, "Stopping IMAP-restore-thread...");
				ths->m_restore_do_exit = 1;
				pthread_join(ths->m_restore_thread, NULL);
			mrmailbox_log_info(ths->m_mailbox, 0, "IMAP-restore-thread stopped.");
		}

static void* restore_thread_entry_point(void* entry_arg)
{
	mrimap_t*  ths = (mrimap_t*)entry_arg;
	mrosnative_setup_thread(ths->m_mailbox); /* must be very first */

	int        r, handle_locked = 0, idle_blocked = 0;
	clist      *folder_list = NULL, *fetch_result = NULL;
	clistiter  *folder_iter, *fetch_iter;
	#define    CHECK_EXIT if( ths->m_restore_do_exit ) { goto exit_; }

	mrmailbox_log_info(ths->m_mailbox, 0, "IMAP-restore-thread started.");

	LOCK_HANDLE
	BLOCK_IDLE
		INTERRUPT_IDLE
		mrmailbox_log_info(ths->m_mailbox, 0, "IMAP-restore-thread gets folders.");
		if( !setup_handle_if_needed__(ths)
		 || (folder_list=list_folders__(ths))==NULL ) {
			goto exit_;
		}
	UNBLOCK_IDLE
	UNLOCK_HANDLE

	for( folder_iter = clist_begin(folder_list); folder_iter != NULL ; folder_iter = clist_next(folder_iter) )
	{
		mrimapfolder_t* folder = (mrimapfolder_t*)clist_content(folder_iter);

		CHECK_EXIT

		LOCK_HANDLE
		BLOCK_IDLE
			INTERRUPT_IDLE
			setup_handle_if_needed__(ths);
			mrmailbox_log_info(ths->m_mailbox, 0, "IMAP-restore-thread gets messages in \"%s\".", folder->m_name_utf8);
			if( select_folder__(ths, folder->m_name_to_select)
			 && ths->m_hEtpan->imap_selection_info->sel_has_exists )
			{
				/* fetch the last 200 messages by one-based-index. TODO: we should regard the given timespan somehow */
				int32_t i_last  = ths->m_hEtpan->imap_selection_info->sel_exists;
				int32_t i_first = MR_MAX(i_last-200, 1);

				struct mailimap_set* set = mailimap_set_new_interval(i_first, i_last);
					r = mailimap_fetch(ths->m_hEtpan, set, ths->m_fetch_type_uid, &fetch_result); /* execute FETCH from:to command, result includes the given index */
				mailimap_set_free(set);
			}
		UNBLOCK_IDLE
		UNLOCK_HANDLE

		if( !is_error(ths, r) && fetch_result != NULL )
		{
			for( fetch_iter = clist_begin(fetch_result); fetch_iter != NULL ; fetch_iter = clist_next(fetch_iter) )
			{
				CHECK_EXIT

				struct mailimap_msg_att* msg_att = (struct mailimap_msg_att*)clist_content(fetch_iter); /* mailimap_msg_att is a list of attributes: list is a list of message attributes */
				uint32_t cur_uid = peek_uid(msg_att);
				if( cur_uid )
				{
					fetch_single_msg(ths, folder->m_name_to_select, cur_uid, 1);
				}
			}

			mailimap_fetch_list_free(fetch_result);
			fetch_result = NULL;
		}
	}

	mrmailbox_log_info(ths->m_mailbox, 0, "IMAP-restore-thread finished.");

exit_:
	UNBLOCK_IDLE
	UNLOCK_HANDLE /* needed before the follow lock as the handle may be locked or unlocked when arriving in exit_*/

	if( fetch_result ) {
		mailimap_fetch_list_free(fetch_result);
	}

	if( folder_list ) {
		free_folders(folder_list);
	}

	LOCK_HANDLE
		ths->m_restore_thread_created = 0;
	UNLOCK_HANDLE
	mrosnative_unsetup_thread(ths->m_mailbox); /* must be very last */
	return NULL;
}


int mrimap_restore(mrimap_t* ths, time_t seconds_to_restore)
{
	int success = 0, handle_locked = 0;

	if( ths==NULL || !ths->m_connected || seconds_to_restore <= 0 ) {
		goto cleanup;
	}

	LOCK_HANDLE
		if( ths->m_restore_thread_created ) {
			goto cleanup;
		}
		ths->m_restore_thread_created = 1;
		ths->m_restore_do_exit = 0;
	UNLOCK_HANDLE

	pthread_create(&ths->m_restore_thread, NULL, restore_thread_entry_point, ths);

	success = 1;

cleanup:
	return success;
}


/* in cmdline ... */
	else if( strcmp(cmd, "restore")==0 )
	{
		if( arg1 ) {
			int days = atoi(arg1);
			ret = mrmailbox_restore(mailbox, days*24*60*60)? COMMAND_SUCCEEDED : COMMAND_FAILED;
		}
		else {
			ret = safe_strdup("ERROR: Argument <days> missing.");
		}
	}
	
/* restore old data from the IMAP server, not really implemented. */
int mrmailbox_restore(mrmailbox_t* ths, time_t seconds_to_restore)
{
	if( ths == NULL ) {
		return 0;
	}

	return mrimap_restore(ths->m_imap, seconds_to_restore);
}
	

static char* get_file_disposition_suffix_(struct mailmime_disposition* file_disposition)
{
	if( file_disposition ) {
		clistiter* cur;
		for( cur = clist_begin(file_disposition->dsp_parms); cur != NULL; cur = clist_next(cur) ) {
			struct mailmime_disposition_parm* dsp_param = (struct mailmime_disposition_parm*)clist_content(cur);
			if( dsp_param ) {
				if( dsp_param->pa_type==MAILMIME_DISPOSITION_PARM_FILENAME ) {
					return mr_get_filesuffix_lc(dsp_param->pa_data.pa_filename);
				}
			}
		}
	}
	return NULL;
}

