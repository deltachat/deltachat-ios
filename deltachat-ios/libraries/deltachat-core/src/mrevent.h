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
 *
 * If you do not want to handle an event, it is always safe to return 0, so there is no need to add a "case" for every event.
 */


/**
 * The library-user may write an informational string to the log.
 * Passed to the callback given to mrmailbox_new().
 *
 * This event should not be reported to the end-user using a popup or something like that.
 *
 * @param data1 0
 *
 * @param data2 Info string in english language.
 *
 * @return 0
 */
#define MR_EVENT_INFO                     100


/**
 * The library-user should write a warning string to the log.
 * Passed to the callback given to mrmailbox_new().
 *
 * This event should not be reported to the end-user using a popup or something like that.
 *
 * @param data1 0
 *
 * @param data2 Warning string in english language.
 *
 * @return 0
 */
#define MR_EVENT_WARNING                  300


/**
 * The library-user should report an error to the end-user.
 * Passed to the callback given to mrmailbox_new().
 *
 * As most things are asynchrounous, things may go wrong at any time and the user
 * should not be disturbed by a dialog or so.  Instead, use a bubble or so.
 *
 * However, for ongoing processes (eg. mrmailbox_configure_and_connect())
 * or for functions that are expected to fail (eg. mrmailbox_continue_key_transfer())
 * it might be better to delay showing these events until the function has really
 * failed (returned false). It should be sufficient to report only the _last_ error
 * in a messasge box then.
 *
 * @param data1 Error code, see mrerror.h for a list of constants.
 *
 * @param data2 Error string, always set, never NULL. Frequent error strings are
 *     localized using MR_EVENT_GET_STRING, however, most error strings will be
 *     in english language.
 *
 *
 * @return 0
 */
#define MR_EVENT_ERROR                    400



/**
 * Messages or chats changed.  One or more messages or chats changed for various
 * reasons in the database:
 * - Messages sent, received or removed
 * - A message could not be sent (see mrmsg_get_state()/MR_STATE_OUT_ERROR)
 * - Chats created, deleted or archived
 * - A draft has been set
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
 * There is no extra #MR_EVENT_MSGS_CHANGED event send together with this event.
 *
 * @param data1 chat_id
 *
 * @param data2 msg_id
 *
 * @return 0
 */
#define MR_EVENT_INCOMING_MSG             2005


/**
 * A single message is sent successfully (state changed from  MR_STATE_OUT_PENDING to
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
 * Chat changed.  The name or the image of a chat group was changed or members were added or removed.
 * Or the verify state of a chat has changed.
 * See mrmailbox_set_chat_name(), mrmailbox_set_chat_profile_image(), mrmailbox_add_contact_to_chat()
 * and mrmailbox_remove_contact_from_chat().
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
 * Inform about the configuration progress started by mrmailbox_configure_and_connect().
 *
 * @param data1 Permille
 *
 * @param data2 0
 *
 * @return 0
 */
#define MR_EVENT_CONFIGURE_PROGRESS       2041


/**
 * Inform about the import/export progress started by mrmailbox_imex().
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
 * This event may be sent multiple times by a single call to mrmailbox_imex().
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


#define MR_EVENT_SECUREJOIN_REQUESTED     2060


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


/**
 * Requeste a localized string from the frontend.
 *
 * @param data1 ID of the string to request, one of the MR_STR_* constants as defined in mrstock.h
 *
 * @param data2 0
 *
 * @return Null-terminated UTF-8 string.  CAVE: The string will be free()'d by the core, so make
 *     sure it is allocated using malloc() or a compatible function.
 *     If you cannot provide the requested string, just return 0; the core will use a default string then.
 */
#define MR_EVENT_GET_STRING               2091


/**
 * Requeste a localized quantitiy string from the frontend.
 * Quantitiy strings may have eg. different plural forms and usually also include the count itself to the string.
 * Typical strings in this form are "1 Message" vs. "2 Messages".
 *
 * @param data1 ID of the string to request, one of the MR_STR_* constants as defined in mrstock.h
 *
 * @param data2 The count. The frontend may return different strings on this value and normally also includes
 *     the value itself to the string.
 *
 * @return Null-terminated UTF-8 string.  CAVE: The string will be free()'d by the core, so make
 *     sure it is allocated using malloc() or a compatible function.
 *     If you cannot provide the requested string, just return 0; the core will use a default string then.
 */
#define MR_EVENT_GET_QUANTITY_STRING      2092


/**
 * Request a HTTP-file or HTTPS-file from the frontend.
 *
 * @param data1 Null-terminated UTF-8 string containing the URL. The string starts with https:// or http://. Must not be free()'d or modified by the frontend.
 *
 * @param data2 0
 *
 * @return The content of the requested file as a null-terminated UTF-8 string;
 *     Response headers, encodings etc. must be stripped, only the raw file, which may be binary, should be returned.
 *     CAVE: The string will be free()'d by the core,
 *     so make sure it is allocated using malloc() or a compatible function.
 *     If you cannot provide the content, just return 0.
 */
#define MR_EVENT_HTTP_GET                 2100

/**
 * Acquire or release a wakelock.
 *
 * The core surrounds critical functions that should not be killed by the operating system with wakelocks.
 * Before a critical function _MR_EVENT_WAKE_LOCK with data1=1_ is called, when it finishes, _MR_EVENT_WAKE_LOCK with data1=0_ is called.
 * If you do not need this functionality, just ignore this event.
 *
 * @param data1 1=acquire wakelock, 0=release wakelock, the core does not make nested or unsynchronized calls
 *
 * @param data2 0
 *
 * @return 0
 */
#define MR_EVENT_WAKE_LOCK                2110


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MREVENT_H__ */

