/*******************************************************************************
 *
 *                              Delta Chat Core
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


#ifndef __MREVENT_H__
#define __MREVENT_H__
#ifdef __cplusplus
extern "C" {
#endif


/**
 * @file
 *
 * The following constants are used as events reported to the callback given to mrmailbox_new().
 */


/**
 * The user may write an informational string to the log.
 * Passed to the callback given to mrmailbox_new().
 * This event should not be reported using a popup or something like that.
 *
 * @param data1 0
 *
 * @param data2 Info string
 *
 * @return 0
 */
#define MR_EVENT_INFO                     100


/**
 * The user should write an warning string to the log.
 * Passed to the callback given to mrmailbox_new().
 * This event should not be reported using a popup or something like that.
 *
 * @param data1 0
 *
 * @param data2 Warning string
 *
 * @return 0
 */
#define MR_EVENT_WARNING                  300


/**
 * The user should show an error.
 * The error must be reported to the user by a non-disturbing bubble or so.
 *
 * @param data1 0
 *
 * @param data2 Error string
 *
 * @return 0
 */
#define MR_EVENT_ERROR                    400


/**
 * One or more messages changed for some reasons in the database. Messages may be added or
 * removed.
 *
 * @param data1 chat_id for single added messages
 *
 * @param data2 msg_id for single added messages
 *
 * @return 0
 */
#define MR_EVENT_MSGS_CHANGED             2000


/**
 * There is a fresh message. Typically, the user will show an notification
 * when receiving this message.
 *
 * @param data1 chat_id
 *
 * @param data2 msg_id
 *
 * @return 0
 */
#define MR_EVENT_INCOMING_MSG             2005


/**
 * A single message is send successfully (state changed from  MR_STATE_OUT_PENDING to
 * MR_STATE_OUT_DELIVERED, see mrmsg_t::m_state).
 *
 * @param data1 chat_id
 *
 * @param data2 msg_id
 *
 * @return 0
 */
#define MR_EVENT_MSG_DELIVERED            2010


/**
 * A single message is read by the receiver (state changed from MR_STATE_OUT_DELIVERED to
 * MR_STATE_OUT_MDN_RCVD, see mrmsg_t::m_state).
 *
 * @param data1 chat_id
 *
 * @param data2 msg_id
 *
 * @return 0
 */
#define MR_EVENT_MSG_READ                 2015


/**
 * Group name/image changed or members added/removed.
 *
 * @param data1 chat_id
 *
 * @param data2 0
 *
 * @return 0
 */
#define MR_EVENT_CHAT_MODIFIED            2020


/**
 * Contact(s) created, renamed, blocked or deleted.
 *
 * @param data1 0
 *
 * @param data2 0
 *
 * @return 0
 */
#define MR_EVENT_CONTACTS_CHANGED         2030


/**
 * Configurartion enden.
 * You'll get this event from a call to mrmailbox_configure_and_connect()
 *
 * @param data1 0=failed-not-connected, 1=configured-and-connected
 *
 * @param data2 0
 *
 * @return 0
 */
#define MR_EVENT_CONFIGURE_ENDED          2040


/**
 * Inform about the configuration progress.
 * As we want to get rid of the threads in the core, this event may be deleted.
 *
 * @param data1 permille
 *
 * @param data2 0
 *
 * @return 0
 */
#define MR_EVENT_CONFIGURE_PROGRESS       2041


/**
 * Import/export done. You'll get this event from a call to mrmailbox_imex().
 * As we want to get rid of the threads in the core, this event may be deleted.
 *
 * @param data1 0:failed, 1=success
 *
 * @param data2 0
 *
 * @return 0
 */
#define MR_EVENT_IMEX_ENDED               2050


/**
 * Inform about the import/export progress.
 *
 * @param data1 Permille
 *
 * @param data2 0
 *
 * @return 0
 */
#define MR_EVENT_IMEX_PROGRESS            2051


/**
 * A file has been exported. A file has been written by mrmailbox_imex().
 * This event may be send multiple times by a single call to mrmailbox_imex();
 * if the export is done, #MR_EVENT_IMEX_ENDED is sent.
 *
 * A typical purpose for a handler of this event may be to make the file public to some system
 * services.
 *
 * @param data1 File name
 *
 * @param data2 0
 *
 * @return 0
 */
#define MR_EVENT_IMEX_FILE_WRITTEN        2052


/*******************************************************************************
 * The following events are functions that should be provided by the frontends
 ******************************************************************************/


/**
 * Ask the frontend about the offline state.
 * This function may be provided by the frontend. If we already know, that we're
 * offline, eg. there is no need to try to connect and things will speed up.
 *
 * @param data1 0
 *
 * @param data2 0
 *
 * @return 0=online, 1=offline
 */
#define MR_EVENT_IS_OFFLINE               2081


/** get a string from the frontend, data1=MR_STR_*, ret=string which will be
free()'d by the backend */
#define MR_EVENT_GET_STRING               2091


/** synchronous http/https(!) call, data1=url, ret=content which will be
free()'d by the backend, 0 on errors */
#define MR_EVENT_GET_QUANTITY_STRING      2092


/** synchronous http/https(!) call, data1=url, ret=content which will be free()'d
by the backend, 0 on errors */
#define MR_EVENT_HTTP_GET                 2100

/** acquire wakeLock (data1=1) or release it (data1=0), the backend does not make
nested or unsynchronized calls */
#define MR_EVENT_WAKE_LOCK                2110


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MREVENT_H__ */

