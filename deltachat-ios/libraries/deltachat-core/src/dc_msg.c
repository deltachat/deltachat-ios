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


#include "dc_context.h"
#include "dc_imap.h"
#include "dc_smtp.h"
#include "dc_job.h"
#include "dc_pgp.h"
#include "dc_mimefactory.h"

#define DC_MSG_MAGIC 0x11561156


/**
 * Create new message object. Message objects are needed eg. for sending messages using
 * dc_send_msg().  Moreover, they are returned eg. from dc_get_msg(),
 * set up with the current state of a message. The message object is not updated;
 * to achieve this, you have to recreate it.
 *
 * @memberof dc_msg_t
 * @param context The context that should be stored in the message object.
 * @return The created message object.
 */
dc_msg_t* dc_msg_new(dc_context_t* context)
{
	dc_msg_t* msg = NULL;

	if ((msg=calloc(1, sizeof(dc_msg_t)))==NULL) {
		exit(15); /* cannot allocate little memory, unrecoverable error */
	}

	msg->context   = context;
	msg->magic     = DC_MSG_MAGIC;
	msg->type      = DC_MSG_UNDEFINED;
	msg->state     = DC_STATE_UNDEFINED;
	msg->param     = dc_param_new();

	return msg;
}


/**
 * Free a message object. Message objects are created eg. by dc_get_msg().
 *
 * @memberof dc_msg_t
 * @param msg The message object to free.
 * @return None.
 */
void dc_msg_unref(dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return;
	}

	dc_msg_empty(msg);
	dc_param_unref(msg->param);
	msg->magic = 0;
	free(msg);
}


/**
 * Empty a message object.
 *
 * @private @memberof dc_msg_t
 * @param msg The message object to empty.
 * @return None.
 */
void dc_msg_empty(dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return;
	}

	free(msg->text);
	msg->text = NULL;

	free(msg->rfc724_mid);
	msg->rfc724_mid = NULL;

	free(msg->server_folder);
	msg->server_folder = NULL;

	dc_param_set_packed(msg->param, NULL);

	msg->hidden = 0;
}


/**
 * Get the ID of the message.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return the ID of the message, 0 on errors.
 */
uint32_t dc_msg_get_id(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return 0;
	}
	return msg->id;
}


/**
 * Get the ID of contact who wrote the message.
 *
 * If the ID is equal to DC_CONTACT_ID_SELF (1), the message is an outgoing
 * message that is typically shown on the right side of the chat view.
 *
 * Otherwise, the message is an incoming message; to get details about the sender,
 * pass the returned ID to dc_get_contact().
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return the ID of the contact who wrote the message, DC_CONTACT_ID_SELF (1)
 *     if this is an outgoing message, 0 on errors.
 */
uint32_t dc_msg_get_from_id(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return 0;
	}
	return msg->from_id;
}


/**
 * Get the ID of chat the message belongs to.
 * To get details about the chat, pass the returned ID to dc_get_chat().
 * If a message is still in the deaddrop, the ID DC_CHAT_ID_DEADDROP is returned
 * although internally another ID is used.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return the ID of the chat the message belongs to, 0 on errors.
 */
uint32_t dc_msg_get_chat_id(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return 0;
	}
	return msg->chat_blocked? DC_CHAT_ID_DEADDROP : msg->chat_id;
}


/**
 * Get the type of the message.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return One of DC_MSG_TEXT (10), DC_MSG_IMAGE (20), DC_MSG_GIF (21),
 *     DC_MSG_AUDIO (40), DC_MSG_VOICE (41), DC_MSG_VIDEO (50), DC_MSG_FILE (60)
 *     or DC_MSG_UNDEFINED (0) if the type is undefined.
 */
int dc_msg_get_type(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return DC_MSG_UNDEFINED;
	}
	return msg->type;
}


/**
 * Get the state of a message.
 *
 * Incoming message states:
 * - DC_STATE_IN_FRESH (10) - Incoming _fresh_ message. Fresh messages are not noticed nor seen and are typically shown in notifications. Use dc_get_fresh_msgs() to get all fresh messages.
 * - DC_STATE_IN_NOTICED (13) - Incoming _noticed_ message. Eg. chat opened but message not yet read - noticed messages are not counted as unread but did not marked as read nor resulted in MDNs. Use dc_marknoticed_chat() or dc_marknoticed_contact() to mark messages as being noticed.
 * - DC_STATE_IN_SEEN (16) - Incoming message, really _seen_ by the user. Marked as read on IMAP and MDN may be send. Use dc_markseen_msgs() to mark messages as being seen.
 *
 * Outgoing message states:
 * - DC_STATE_OUT_PENDING (20) - The user has send the "send" button but the
 *   message is not yet sent and is pending in some way. Maybe we're offline (no checkmark).
 * - DC_STATE_OUT_FAILED (24) - _Unrecoverable_ error (_recoverable_ errors result in pending messages), you'll receive the event #DC_EVENT_MSG_FAILED.
 * - DC_STATE_OUT_DELIVERED (26) - Outgoing message successfully delivered to server (one checkmark). Note, that already delivered messages may get into the state DC_STATE_OUT_FAILED if we get such a hint from the server.
 *   If a sent message changes to this state, you'll receive the event #DC_EVENT_MSG_DELIVERED.
 * - DC_STATE_OUT_MDN_RCVD (28) - Outgoing message read by the recipient (two checkmarks; this requires goodwill on the receiver's side)
 *   If a sent message changes to this state, you'll receive the event #DC_EVENT_MSG_READ.
 *
 * If you just want to check if a message is sent or not, please use dc_msg_is_sent() which regards all states accordingly.
 *
 * The state of just created message objects is DC_STATE_UNDEFINED (0).
 * The state is always set by the core-library, users of the library cannot set the state directly, but it is changed implicitly eg.
 * when calling  dc_marknoticed_chat() or dc_markseen_msgs().
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return The state of the message.
 */
int dc_msg_get_state(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return DC_STATE_UNDEFINED;
	}
	return msg->state;
}


/**
 * Get message sending time. The sending time is returned by a unix timestamp.
 * Note that the message list is not sorted by the _sending_ time but by the _receiving_ time.
 * Cave: the message list is sorted by receiving time (otherwise new messages would non pop up at the expected place),
 * however, if a message is delayed for any reason, the correct sending time will be displayed.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return The time of the message.
 */
time_t dc_msg_get_timestamp(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return 0;
	}

	return msg->timestamp_sent? msg->timestamp_sent : msg->timestamp;
}


/**
 * Get the text of the message.
 * If there is no text associalted with the message, an empty string is returned.
 * NULL is never returned.
 *
 * The returned text is plain text, HTML is stripped.
 * The returned text is truncated to a max. length of currently about 30000 characters,
 * it does not make sense to show more text in the message list and typical controls
 * will have problems with showing much more text.
 * This max. length is to avoid passing _lots_ of data to the frontend which may
 * result eg. from decoding errors (assume some bytes missing in a mime structure, forcing
 * an attachment to be plain text).
 *
 * To get information about the message and more/raw text, use dc_get_msg_info().
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return Message text. The result must be free()'d. Never returns NULL.
 */
char* dc_msg_get_text(const dc_msg_t* msg)
{
	char* ret = NULL;

	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return dc_strdup(NULL);
	}

	ret = dc_strdup(msg->text);
	dc_truncate_str(ret, DC_MAX_GET_TEXT_LEN); /* we do not do this on load: (1) for speed reasons (2) we may decide to process the full text on other places */
	return ret;
}


/**
 * Find out full path, file name and extension of the file associated with a
 * message.
 *
 * Typically files are associated with images, videos, audios, documents.
 * Plain text messages do not have a file.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return Full path, file name and extension of the file associated with the
 *     message.  If there is no file associated with the message, an emtpy
 *     string is returned.  NULL is never returned and the returned value must be free()'d.
 */
char* dc_msg_get_file(const dc_msg_t* msg)
{
	char* ret = NULL;

	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		goto cleanup;
	}

	ret = dc_param_get(msg->param, DC_PARAM_FILE, NULL);

cleanup:
	return ret? ret : dc_strdup(NULL);
}


/**
 * Get base file name without path. The base file name includes the extension; the path
 * is not returned. To get the full path, use dc_msg_get_file().
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return Base file name plus extension without part.  If there is no file
 *     associated with the message, an empty string is returned.  The returned
 *     value must be free()'d.
 */
char* dc_msg_get_filename(const dc_msg_t* msg)
{
	char* ret = NULL;
	char* pathNfilename = NULL;

	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		goto cleanup;
	}

	pathNfilename = dc_param_get(msg->param, DC_PARAM_FILE, NULL);
	if (pathNfilename==NULL) {
		goto cleanup;
	}

	ret = dc_get_filename(pathNfilename);

cleanup:
	free(pathNfilename);
	return ret? ret : dc_strdup(NULL);
}


/**
 * Get mime type of the file.  If there is not file, an empty string is returned.
 * If there is no associated mime type with the file, the function guesses on; if
 * in doubt, `application/octet-stream` is returned. NULL is never returned.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return String containing the mime type. Must be free()'d after usage. NULL is never returned.
 */
char* dc_msg_get_filemime(const dc_msg_t* msg)
{
	char* ret = NULL;
	char* file = NULL;

	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		goto cleanup;
	}

	ret = dc_param_get(msg->param, DC_PARAM_MIMETYPE, NULL);
	if (ret==NULL) {
		file = dc_param_get(msg->param, DC_PARAM_FILE, NULL);
		if (file==NULL) {
			goto cleanup;
		}
		dc_msg_guess_msgtype_from_suffix(file, NULL, &ret);

		if (ret==NULL) {
			ret = dc_strdup("application/octet-stream");
		}
	}

cleanup:
	free(file);
	return ret? ret : dc_strdup(NULL);
}


/**
 * Get the size of the file.  Returns the size of the file associated with a
 * message, if applicable.
 *
 * Typically, this is used to show the size of document messages, eg. a PDF.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return File size in bytes, 0 if not applicable or on errors.
 */
uint64_t dc_msg_get_filebytes(const dc_msg_t* msg)
{
	uint64_t ret = 0;
	char*    file = NULL;

	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		goto cleanup;
	}

	file = dc_param_get(msg->param, DC_PARAM_FILE, NULL);
	if (file==NULL) {
		goto cleanup;
	}

	ret = dc_get_filebytes(file);

cleanup:
	free(file);
	return ret;
}


/**
 * Get real author and title.
 *
 * The information is returned by a dc_lot_t object with the following fields:
 *
 * - dc_lot_t::text1: Author of the media.  For voice messages, this is the sender.
 *   For music messages, the information are read from the filename. NULL if unknown.
 * - dc_lot_t::text2: Title of the media.  For voice messages, this is the date.
 *   For music messages, the information are read from the filename. NULL if unknown.
 *
 * Currently, we do not read ID3 and such at this stage, the needed libraries are too complicated and oversized.
 * However, this is no big problem, as the sender usually sets the filename in a way we expect it.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return Media information as an dc_lot_t object. Must be freed using dc_lot_unref().  NULL is never returned.
 */
dc_lot_t* dc_msg_get_mediainfo(const dc_msg_t* msg)
{
	dc_lot_t*     ret = dc_lot_new();
	char*         pathNfilename = NULL;
	dc_contact_t* contact = NULL;

	if (msg==NULL || msg->magic!=DC_MSG_MAGIC || msg->context==NULL) {
		goto cleanup;
	}

	if (msg->type==DC_MSG_VOICE)
	{
		if ((contact = dc_get_contact(msg->context, msg->from_id))==NULL) {
			goto cleanup;
		}
		ret->text1 = dc_strdup((contact->name&&contact->name[0])? contact->name : contact->addr);
		ret->text2 = dc_stock_str(msg->context, DC_STR_VOICEMESSAGE);
	}
	else
	{
		ret->text1 = dc_param_get(msg->param, DC_PARAM_AUTHORNAME, NULL);
		ret->text2 = dc_param_get(msg->param, DC_PARAM_TRACKNAME, NULL);
		if (ret->text1 && ret->text1[0] && ret->text2 && ret->text2[0]) {
			goto cleanup;
		}
		free(ret->text1); ret->text1 = NULL;
		free(ret->text2); ret->text2 = NULL;

		pathNfilename = dc_param_get(msg->param, DC_PARAM_FILE, NULL);
		if (pathNfilename==NULL) {
			goto cleanup;
		}
		dc_msg_get_authorNtitle_from_filename(pathNfilename, &ret->text1, &ret->text2);
		if (ret->text1==NULL && ret->text2!=NULL) {
			ret->text1 = dc_stock_str(msg->context, DC_STR_AUDIO);
		}
	}

cleanup:
	free(pathNfilename);
	dc_contact_unref(contact);
	return ret;
}


/**
 * Get width of image or video.  The width is returned in pixels.
 * If the width is unknown or if the associated file is no image or video file,
 * 0 is returned.
 *
 * Often the ascpect ratio is the more interesting thing. You can calculate
 * this using dc_msg_get_width() / dc_msg_get_height().
 *
 * See also dc_msg_get_duration().
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return Width in pixels, if applicable. 0 otherwise or if unknown.
 */
int dc_msg_get_width(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return 0;
	}
	return dc_param_get_int(msg->param, DC_PARAM_WIDTH, 0);
}


/**
 * Get height of image or video.  The height is returned in pixels.
 * If the height is unknown or if the associated file is no image or video file,
 * 0 is returned.
 *
 * Often the ascpect ratio is the more interesting thing. You can calculate
 * this using dc_msg_get_width() / dc_msg_get_height().
 *
 * See also dc_msg_get_duration().
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return Height in pixels, if applicable. 0 otherwise or if unknown.
 */
int dc_msg_get_height(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return 0;
	}
	return dc_param_get_int(msg->param, DC_PARAM_HEIGHT, 0);
}


/**
 * Get duration of audio or video.  The duration is returned in milliseconds (ms).
 * If the duration is unknown or if the associated file is no audio or video file,
 * 0 is returned.
 *
 * See also dc_msg_get_width() and dc_msg_get_height().
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return Duration in milliseconds, if applicable. 0 otherwise or if unknown.
 */
int dc_msg_get_duration(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return 0;
	}
	return dc_param_get_int(msg->param, DC_PARAM_DURATION, 0);
}


/**
 * Check if a padlock should be shown beside the message.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return 1=padlock should be shown beside message, 0=do not show a padlock beside the message.
 */
int dc_msg_get_showpadlock(const dc_msg_t* msg)
{
	/* a padlock guarantees that the message is e2ee _and_ answers will be as well */
	int show_encryption_state = 0;

	if (msg==NULL || msg->magic!=DC_MSG_MAGIC || msg->context==NULL) {
		return 0;
	}

	if (msg->context->e2ee_enabled) {
		show_encryption_state = 1;
	}
	else {
		dc_chat_t* chat = dc_get_chat(msg->context, msg->chat_id);
		show_encryption_state = dc_chat_is_verified(chat);
		dc_chat_unref(chat);
	}

	if (show_encryption_state) {
		if (dc_param_get_int(msg->param, DC_PARAM_GUARANTEE_E2EE, 0)!=0) {
			return 1;
		}
	}

	return 0;
}


/**
 * Get a summary for a message.
 *
 * The summary is returned by a dc_lot_t object with the following fields:
 *
 * - dc_lot_t::text1: contains the username or the string "Me".
 *   The string may be colored by having a look at text1_meaning.
 *   If the name should not be displayed, the element is NULL.
 * - dc_lot_t::text1_meaning: one of DC_TEXT1_USERNAME or DC_TEXT1_SELF.
 *   Typically used to show dc_lot_t::text1 with different colors. 0 if not applicable.
 * - dc_lot_t::text2: contains an excerpt of the message text.
 * - dc_lot_t::timestamp: the timestamp of the message.
 * - dc_lot_t::state: The state of the message as one of the DC_STATE_* constants (see #dc_msg_get_state()).
 *
 * Typically used to display a search result. See also dc_chatlist_get_summary() to display a list of chats.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @param chat To speed up things, pass an already available chat object here.
 *     If the chat object is not yet available, it is faster to pass NULL.
 * @return The summary as an dc_lot_t object. Must be freed using dc_lot_unref().  NULL is never returned.
 */
dc_lot_t* dc_msg_get_summary(const dc_msg_t* msg, const dc_chat_t* chat)
{
	dc_lot_t*      ret = dc_lot_new();
	dc_contact_t*  contact = NULL;
	dc_chat_t*     chat_to_delete = NULL;

	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		goto cleanup;
	}

	if (chat==NULL) {
		if ((chat_to_delete=dc_get_chat(msg->context, msg->chat_id))==NULL) {
			goto cleanup;
		}
		chat = chat_to_delete;
	}

	if (msg->from_id!=DC_CONTACT_ID_SELF && DC_CHAT_TYPE_IS_MULTI(chat->type)) {
		contact = dc_get_contact(chat->context, msg->from_id);
	}

	dc_lot_fill(ret, msg, chat, contact, msg->context);

cleanup:
	dc_contact_unref(contact);
	dc_chat_unref(chat_to_delete);
	return ret;
}


/**
 * Get a message summary as a single line of text.  Typically used for
 * notifications.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @param approx_characters Rough length of the expected string.
 * @return A summary for the given messages. The returned string must be free()'d.
 *     Returns an empty string on errors, never returns NULL.
 */
char* dc_msg_get_summarytext(const dc_msg_t* msg, int approx_characters)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return dc_strdup(NULL);
	}

	return dc_msg_get_summarytext_by_raw(msg->type, msg->text, msg->param, approx_characters, msg->context);
}


/**
 * Check if a message was sent successfully.
 *
 * Currently, "sent" messages are messages that are in the state "delivered" or "mdn received",
 * see dc_msg_get_state().
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return 1=message sent successfully, 0=message not yet sent or message is an incoming message.
 */
int dc_msg_is_sent(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return 0;
	}
	return (msg->state >= DC_STATE_OUT_DELIVERED)? 1 : 0;
}


/**
 * Check if a message is starred.  Starred messages are "favorites" marked by the user
 * with a "star" or something like that.  Starred messages can typically be shown
 * easily and are not deleted automatically.
 *
 * To star one or more messages, use dc_star_msgs(), to get a list of starred messages,
 * use dc_get_chat_msgs() using DC_CHAT_ID_STARRED as the chat_id.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return 1=message is starred, 0=message not starred.
 */
int dc_msg_is_starred(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return 0;
	}
	return msg->starred? 1 : 0;
}


/**
 * Check if the message is a forwarded message.
 *
 * Forwarded messages may not be created by the contact given as "from".
 *
 * Typically, the UI shows a little text for a symbol above forwarded messages.
 *
 * For privacy reasons, we do not provide the name or the email address of the
 * original author (in a typical GUI, you select the messages text and click on
 * "forwared"; you won't expect other data to be send to the new recipient,
 * esp. as the new recipient may not be in any relationship to the original author)
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return 1=message is a forwarded message, 0=message not forwarded.
 */
int dc_msg_is_forwarded(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return 0;
	}
	return dc_param_get_int(msg->param, DC_PARAM_FORWARDED, 0)? 1 : 0;
}


/**
 * Check if the message is an informational message, created by the
 * device or by another users. Such messages are not "typed" by the user but
 * created due to other actions, eg. dc_set_chat_name(), dc_set_chat_profile_image()
 * or dc_add_contact_to_chat().
 *
 * These messages are typically shown in the center of the chat view,
 * dc_msg_get_text() returns a descriptive text about what is going on.
 *
 * There is no need to perfrom any action when seeing such a message - this is already done by the core.
 * Typically, these messages are displayed in the center of the chat.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return 1=message is a system command, 0=normal message
 */
int dc_msg_is_info(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return 0;
	}

	int cmd = dc_param_get_int(msg->param, DC_PARAM_CMD, 0);

	if (msg->from_id==DC_CONTACT_ID_DEVICE
	 || msg->to_id==DC_CONTACT_ID_DEVICE
	 || (cmd && cmd!=DC_CMD_AUTOCRYPT_SETUP_MESSAGE)) {
		return 1;
	}

	return 0;
}


/**
 * Check if the message is an Autocrypt Setup Message.
 *
 * Setup messages should be shown in an unique way eg. using a different text color.
 * On a click or another action, the user should be prompted for the setup code
 * which is forwarded to dc_continue_key_transfer() then.
 *
 * Setup message are typically generated by dc_initiate_key_transfer() on another device.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return 1=message is a setup message, 0=no setup message.
 *     For setup messages, dc_msg_get_type() returns DC_MSG_FILE.
 */
int dc_msg_is_setupmessage(const dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC || msg->type!=DC_MSG_FILE) {
		return 0;
	}

	return dc_param_get_int(msg->param, DC_PARAM_CMD, 0)==DC_CMD_AUTOCRYPT_SETUP_MESSAGE? 1 : 0;
}


/**
 * Get the first characters of the setup code.
 *
 * Typically, this is used to pre-fill the first entry field of the setup code.
 * If the user has several setup messages, he can be sure typing in the correct digits.
 *
 * To check, if a message is a setup message, use dc_msg_is_setupmessage().
 * To decrypt a secret key from a setup message, use dc_continue_key_transfer().
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @return Typically, the first two digits of the setup code or an empty string if unknown.
 *     NULL is never returned. Must be free()'d when done.
 */
char* dc_msg_get_setupcodebegin(const dc_msg_t* msg)
{
	char*        filename = NULL;
	char*        buf = NULL;
	size_t       buf_bytes = 0;
	const char*  buf_headerline = NULL; // just a pointer inside buf, MUST NOT be free()'d
	const char*  buf_setupcodebegin = NULL; // just a pointer inside buf, MUST NOT be free()'d
	char*        ret = NULL;

	if (!dc_msg_is_setupmessage(msg)) {
		goto cleanup;
	}

	if ((filename=dc_msg_get_file(msg))==NULL || filename[0]==0) {
		goto cleanup;
	}

	if (!dc_read_file(filename, (void**)&buf, &buf_bytes, msg->context) || buf==NULL || buf_bytes <= 0) {
		goto cleanup;
	}

	if (!dc_split_armored_data(buf, &buf_headerline, &buf_setupcodebegin, NULL, NULL)
	 || strcmp(buf_headerline, "-----BEGIN PGP MESSAGE-----")!=0 || buf_setupcodebegin==NULL) {
		goto cleanup;
	}

	ret = dc_strdup(buf_setupcodebegin); /* we need to make a copy as buf_setupcodebegin just points inside buf (which will be free()'d on cleanup) */

cleanup:
	free(filename);
	free(buf);
	return ret? ret : dc_strdup(NULL);
}


#define DC_MSG_FIELDS " m.id,rfc724_mid,m.server_folder,m.server_uid,m.chat_id, " \
                      " m.from_id,m.to_id,m.timestamp,m.timestamp_sent,m.timestamp_rcvd, m.type,m.state,m.msgrmsg,m.txt, " \
                      " m.param,m.starred,m.hidden,c.blocked "


static int dc_msg_set_from_stmt(dc_msg_t* msg, sqlite3_stmt* row, int row_offset) /* field order must be DC_MSG_FIELDS */
{
	dc_msg_empty(msg);

	msg->id           =           (uint32_t)sqlite3_column_int  (row, row_offset++);
	msg->rfc724_mid   =    dc_strdup((char*)sqlite3_column_text (row, row_offset++));
	msg->server_folder=    dc_strdup((char*)sqlite3_column_text (row, row_offset++));
	msg->server_uid   =           (uint32_t)sqlite3_column_int  (row, row_offset++);
	msg->chat_id      =           (uint32_t)sqlite3_column_int  (row, row_offset++);

	msg->from_id      =           (uint32_t)sqlite3_column_int  (row, row_offset++);
	msg->to_id        =           (uint32_t)sqlite3_column_int  (row, row_offset++);
	msg->timestamp    =             (time_t)sqlite3_column_int64(row, row_offset++);
	msg->timestamp_sent =           (time_t)sqlite3_column_int64(row, row_offset++);
	msg->timestamp_rcvd =           (time_t)sqlite3_column_int64(row, row_offset++);

	msg->type         =                     sqlite3_column_int  (row, row_offset++);
	msg->state        =                     sqlite3_column_int  (row, row_offset++);
	msg->is_msgrmsg   =                     sqlite3_column_int  (row, row_offset++);
	msg->text         =    dc_strdup((char*)sqlite3_column_text (row, row_offset++));

	dc_param_set_packed( msg->param, (char*)sqlite3_column_text (row, row_offset++));
	msg->starred      =                     sqlite3_column_int  (row, row_offset++);
	msg->hidden       =                     sqlite3_column_int  (row, row_offset++);
	msg->chat_blocked =                     sqlite3_column_int  (row, row_offset++);

	if (msg->chat_blocked==2) {
		dc_truncate_n_unwrap_str(msg->text, 256 /* 256 characters is about a half screen on a 5" smartphone display */,
			0/*unwrap*/);
	}

	return 1;
}


/**
 * Load a message from the database to the message object.
 *
 * @private @memberof dc_msg_t
 */
int dc_msg_load_from_db(dc_msg_t* msg, dc_context_t* context, uint32_t id)
{
	int           success = 0;
	sqlite3_stmt* stmt = NULL;

	if (msg==NULL || msg->magic!=DC_MSG_MAGIC || context==NULL || context->sql==NULL) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT " DC_MSG_FIELDS
		" FROM msgs m LEFT JOIN chats c ON c.id=m.chat_id"
		" WHERE m.id=?;");
	sqlite3_bind_int(stmt, 1, id);

	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}

	if (!dc_msg_set_from_stmt(msg, stmt, 0)) { /* also calls dc_msg_empty() */
		goto cleanup;
	}

	msg->context = context;

	success = 1;

cleanup:
	sqlite3_finalize(stmt);
	return success;
}


/**
 * Guess message type from suffix.
 *
 * @private @memberof dc_msg_t
 * @param pathNfilename Path and filename of the file to guess the type for.
 * @param[out] ret_msgtype Guessed message type is copied here as one of the DC_MSG_* constants.
 *     May be NULL if you're not interested in this value.
 * @param[out] ret_mime The pointer to a string buffer is set to the guessed MIME-type. May be NULL. Must be free()'d by the caller.
 * @return None. But there are output parameters.
 */
void dc_msg_guess_msgtype_from_suffix(const char* pathNfilename, int* ret_msgtype, char** ret_mime)
{
	char* suffix = NULL;
	int   dummy_msgtype = 0;
	char* dummy_buf = NULL;

	if (pathNfilename==NULL) {
		goto cleanup;
	}

	if (ret_msgtype==NULL) { ret_msgtype = &dummy_msgtype; }
	if (ret_mime==NULL)    { ret_mime = &dummy_buf; }

	*ret_msgtype = DC_MSG_UNDEFINED;
	*ret_mime = NULL;

	suffix = dc_get_filesuffix_lc(pathNfilename);
	if (suffix==NULL) {
		goto cleanup;
	}

	if (strcmp(suffix, "mp3")==0) {
		*ret_msgtype = DC_MSG_AUDIO;
		*ret_mime = dc_strdup("audio/mpeg");
	}
	else if (strcmp(suffix, "mp4")==0) {
		*ret_msgtype = DC_MSG_VIDEO;
		*ret_mime = dc_strdup("video/mp4");
	}
	else if (strcmp(suffix, "jpg")==0 || strcmp(suffix, "jpeg")==0) {
		*ret_msgtype = DC_MSG_IMAGE;
		*ret_mime = dc_strdup("image/jpeg");
	}
	else if (strcmp(suffix, "png")==0) {
		*ret_msgtype = DC_MSG_IMAGE;
		*ret_mime = dc_strdup("image/png");
	}
	else if (strcmp(suffix, "gif")==0) {
		*ret_msgtype = DC_MSG_GIF;
		*ret_mime = dc_strdup("image/gif");
	}

cleanup:
	free(suffix);
	free(dummy_buf);
}


void dc_msg_get_authorNtitle_from_filename(const char* pathNfilename, char** ret_author, char** ret_title)
{
	/* function extracts AUTHOR and TITLE from a path given as `/path/other folder/AUTHOR - TITLE.mp3`
	if the mark ` - ` is not preset, the whole name (without suffix) is used as the title and the author is NULL. */
	char* author = NULL;
	char* title = NULL;
	char* p = NULL;

	dc_split_filename(pathNfilename, &title, NULL);
	p = strstr(title, " - ");
	if (p) {
		*p = 0;
		author = title;
		title  = dc_strdup(&p[3]);
	}

	if (ret_author) { *ret_author = author; } else { free(author); }
	if (ret_title)  { *ret_title  = title; }  else { free(title); }
}


char* dc_msg_get_summarytext_by_raw(int type, const char* text, dc_param_t* param, int approx_characters, dc_context_t* context)
{
	/* get a summary text, result must be free()'d, never returns NULL. */
	char* ret = NULL;
	char* pathNfilename = NULL;
	char* label = NULL;
	char* value = NULL;

	switch (type) {
		case DC_MSG_IMAGE:
			ret = dc_stock_str(context, DC_STR_IMAGE);
			break;

		case DC_MSG_GIF:
			ret = dc_stock_str(context, DC_STR_GIF);
			break;

		case DC_MSG_VIDEO:
			ret = dc_stock_str(context, DC_STR_VIDEO);
			break;

		case DC_MSG_VOICE:
			ret = dc_stock_str(context, DC_STR_VOICEMESSAGE);
			break;

		case DC_MSG_AUDIO:
			if ((value=dc_param_get(param, DC_PARAM_TRACKNAME, NULL))==NULL) { /* although we send files with "author - title" in the filename, existing files may follow other conventions, so this lookup is neccessary */
				pathNfilename = dc_param_get(param, DC_PARAM_FILE, "ErrFilename");
				dc_msg_get_authorNtitle_from_filename(pathNfilename, NULL, &value);
			}
			label = dc_stock_str(context, DC_STR_AUDIO);
			ret = dc_mprintf("%s: %s", label, value);
			break;

		case DC_MSG_FILE:
			if (dc_param_get_int(param, DC_PARAM_CMD, 0)==DC_CMD_AUTOCRYPT_SETUP_MESSAGE) {
				ret = dc_stock_str(context, DC_STR_AC_SETUP_MSG_SUBJECT);
			}
			else {
				pathNfilename = dc_param_get(param, DC_PARAM_FILE, "ErrFilename");
				value = dc_get_filename(pathNfilename);
				label = dc_stock_str(context, DC_STR_FILE);
				ret = dc_mprintf("%s: %s", label, value);
			}
			break;

		default:
			if (text) {
				ret = dc_strdup(text);
				dc_truncate_n_unwrap_str(ret, approx_characters, 1/*unwrap*/);
			}
			break;
	}

	/* cleanup */
	free(pathNfilename);
	free(label);
	free(value);
	if (ret==NULL) {
		ret = dc_strdup(NULL);
	}
	return ret;
}


/**
 * Check if a message is still in creation.  The user can mark files as being
 * in creation by simply creating a file `<filename>.increation`. If
 * `<filename>` is created then, the user should just delete
 * `<filename>.increation`.
 *
 * Typically, this is used for videos that should be recoded by the user before
 * they can be sent.
 *
 * @memberof dc_msg_t
 * @param msg the message object
 * @return 1=message is still in creation (`<filename>.increation` exists),
 *     0=message no longer in creation
 */
int dc_msg_is_increation(const dc_msg_t* msg)
{
	/* surrounds dc_msg_is_increation() with locking and error checking */
	int is_increation = 0;

	if (msg==NULL || msg->magic!=DC_MSG_MAGIC || msg->context==NULL) {
		return 0;
	}

	if (DC_MSG_NEEDS_ATTACHMENT(msg->type))
	{
		char* pathNfilename = dc_param_get(msg->param, DC_PARAM_FILE, NULL);
		if (pathNfilename) {
			char* totest = dc_mprintf("%s.increation", pathNfilename);
			if (dc_file_exist(totest)) {
				is_increation = 1;
			}
			free(totest);
			free(pathNfilename);
		}
	}

	return is_increation;
}


void dc_msg_save_param_to_disk(dc_msg_t* msg)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC || msg->context==NULL || msg->context->sql==NULL) {
		return;
	}

	sqlite3_stmt* stmt = dc_sqlite3_prepare(msg->context->sql,
		"UPDATE msgs SET param=? WHERE id=?;");
	sqlite3_bind_text(stmt, 1, msg->param->packed, -1, SQLITE_STATIC);
	sqlite3_bind_int (stmt, 2, msg->id);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
}


/**
 * Set the type of a message object.
 * The function does not check of the type is valid and the function does not alter any information in the database;
 * both may be done by dc_send_msg() later.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @param type The type to set, one of DC_MSG_TEXT (10), DC_MSG_IMAGE (20), DC_MSG_GIF (21),
 *     DC_MSG_AUDIO (40), DC_MSG_VOICE (41), DC_MSG_VIDEO (50), DC_MSG_FILE (60)
 * @return None.
 */
void dc_msg_set_type(dc_msg_t* msg, int type)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return;
	}
	msg->type = type;
}


/**
 * Set the text of a message object.
 * This does not alter any information in the database; this may be done by dc_send_msg() later.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @param text Message text.
 * @return None.
 */
void dc_msg_set_text(dc_msg_t* msg, const char* text)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return;
	}
	free(msg->text);
	msg->text = dc_strdup(text);
}


/**
 * Set the file associated with a message object.
 * This does not alter any information in the database
 * nor copy or move the file or checks if the file exist.
 * All this can be done with dc_send_msg() later.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @param file If the message object is used in dc_send_msg() later,
 *     this must be the full path of the image file to send.
 * @param filemime Mime type of the file. NULL if you don't know or don't care.
 * @return None.
 */
void dc_msg_set_file(dc_msg_t* msg, const char* file, const char* filemime)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return;
	}
	dc_param_set(msg->param, DC_PARAM_FILE, file);
	dc_param_set(msg->param, DC_PARAM_MIMETYPE, filemime);
}


/**
 * Set the dimensions associated with message object.
 * Typically this is the width and the height of an image or video associated using dc_msg_set_file().
 * This does not alter any information in the database; this may be done by dc_send_msg() later.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @param width Width in pixels, if known. 0 if you don't know or don't care.
 * @param height Height in pixels, if known. 0 if you don't know or don't care.
 * @return None.
 */
void dc_msg_set_dimension(dc_msg_t* msg, int width, int height)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return;
	}
	dc_param_set_int(msg->param, DC_PARAM_WIDTH, width);
	dc_param_set_int(msg->param, DC_PARAM_HEIGHT, height);
}


/**
 * Set the duration associated with message object.
 * Typically this is the duration of an audio or video associated using dc_msg_set_file().
 * This does not alter any information in the database; this may be done by dc_send_msg() later.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @param duration Length in milliseconds. 0 if you don't know or don't care.
 * @return None.
 */
void dc_msg_set_duration(dc_msg_t* msg, int duration)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return;
	}
	dc_param_set_int(msg->param, DC_PARAM_DURATION, duration);
}


/**
 * Set the media information associated with message object.
 * Typically this is the author and the trackname of an audio or video associated using dc_msg_set_file().
 * This does not alter any information in the database; this may be done by dc_send_msg() later.
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @param author Author or artist. NULL if you don't know or don't care.
 * @param trackname Trackname or title. NULL if you don't know or don't care.
 * @return None.
 */
void dc_msg_set_mediainfo(dc_msg_t* msg, const char* author, const char* trackname)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		return;
	}
	dc_param_set(msg->param, DC_PARAM_AUTHORNAME, author);
	dc_param_set(msg->param, DC_PARAM_TRACKNAME, trackname);
}


/**
 * Late filing information to a message.
 * In contrast to the dc_msg_set_*() functions, this function really stores the information in the database.
 *
 * Sometimes, the core cannot find out the width, the height or the duration
 * of an image, an audio or a video.
 *
 * If, in these cases, the frontend can provide the information, it can save
 * them together with the message object for later usage.
 *
 * This function should only be used if dc_msg_get_width(), dc_msg_get_height() or dc_msg_get_duration()
 * do not provide the expected values.
 *
 * To get the stored values later, use dc_msg_get_width(), dc_msg_get_height() or dc_msg_get_duration().
 *
 * @memberof dc_msg_t
 * @param msg The message object.
 * @param width The new width to store in the message object. 0 if you do not want to change it.
 * @param height The new height to store in the message object. 0 if you do not want to change it.
 * @param duration The new duration to store in the message object. 0 if you do not want to change it.
 * @return None.
 */
void dc_msg_latefiling_mediasize(dc_msg_t* msg, int width, int height, int duration)
{
	if (msg==NULL || msg->magic!=DC_MSG_MAGIC) {
		goto cleanup;
	}

	if (width > 0) {
		dc_param_set_int(msg->param, DC_PARAM_WIDTH, width);
	}

	if (height > 0) {
		dc_param_set_int(msg->param, DC_PARAM_HEIGHT, height);
	}

	if (duration > 0) {
		dc_param_set_int(msg->param, DC_PARAM_DURATION, duration);
	}

	dc_msg_save_param_to_disk(msg);

cleanup:
	;
}


/*******************************************************************************
 * Context functions to work with messages
 ******************************************************************************/


void dc_update_msg_chat_id(dc_context_t* context, uint32_t msg_id, uint32_t chat_id)
{
	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
		"UPDATE msgs SET chat_id=? WHERE id=?;");
	sqlite3_bind_int(stmt, 1, chat_id);
	sqlite3_bind_int(stmt, 2, msg_id);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
}


void dc_update_msg_state(dc_context_t* context, uint32_t msg_id, int state)
{
	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
		"UPDATE msgs SET state=? WHERE id=?;");
	sqlite3_bind_int(stmt, 1, state);
	sqlite3_bind_int(stmt, 2, msg_id);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
}


/**
 * Changes the state of PENDING or DELIVERED messages to DC_STATE_OUT_FAILED.
 * Moreover, the message error text can be updated.
 * Finally, the given error text is also logged using dc_log_error().
 *
 * @private @memberof dc_context_t
 */
void dc_set_msg_failed(dc_context_t* context, uint32_t msg_id, const char* error)
{
	dc_msg_t*     msg = dc_msg_new(context);
	sqlite3_stmt* stmt = NULL;

	if (!dc_msg_load_from_db(msg, context, msg_id)) {
		goto cleanup;
	}

	if (DC_STATE_OUT_PENDING==msg->state || DC_STATE_OUT_DELIVERED==msg->state) {
		msg->state = DC_STATE_OUT_FAILED;
	}

	if (error) {
		dc_param_set(msg->param, DC_PARAM_ERROR, error);
		dc_log_error(context, 0, "%s", error);
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"UPDATE msgs SET state=?, param=? WHERE id=?;");
	sqlite3_bind_int (stmt, 1, msg->state);
	sqlite3_bind_text(stmt, 2, msg->param->packed, -1, SQLITE_STATIC);
	sqlite3_bind_int (stmt, 3, msg_id);
	sqlite3_step(stmt);

	context->cb(context, DC_EVENT_MSG_FAILED, msg->chat_id, msg_id);

cleanup:
	sqlite3_finalize(stmt);
	dc_msg_unref(msg);
}


size_t dc_get_real_msg_cnt(dc_context_t* context)
{
	sqlite3_stmt* stmt = NULL;
	size_t        ret = 0;

	if (context->sql->cobj==NULL) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT COUNT(*) "
		" FROM msgs m "
		" LEFT JOIN chats c ON c.id=m.chat_id "
		" WHERE m.id>" DC_STRINGIFY(DC_MSG_ID_LAST_SPECIAL)
		" AND m.chat_id>" DC_STRINGIFY(DC_CHAT_ID_LAST_SPECIAL)
		" AND c.blocked=0;");
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		dc_sqlite3_log_error(context->sql, "dc_get_real_msg_cnt() failed.");
		goto cleanup;
	}

	ret = sqlite3_column_int(stmt, 0);

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


size_t dc_get_deaddrop_msg_cnt(dc_context_t* context)
{
	sqlite3_stmt* stmt = NULL;
	size_t        ret = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || context->sql->cobj==NULL) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT COUNT(*) FROM msgs m LEFT JOIN chats c ON c.id=m.chat_id WHERE c.blocked=2;");
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}

	ret = sqlite3_column_int(stmt, 0);

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


int dc_rfc724_mid_cnt(dc_context_t* context, const char* rfc724_mid)
{
	/* check the number of messages with the same rfc724_mid */
	int           ret = 0;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || context->sql->cobj==NULL) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT COUNT(*) FROM msgs WHERE rfc724_mid=?;");
	sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}

	ret = sqlite3_column_int(stmt, 0);

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


/**
 * Check, if the given Message-ID exists in the database.
 * If not, the caller loads the message typically completely from the server and parses it.
 * To avoid unnecessary dowonloads and parsing, we should even keep unuseful messages
 * in the database (we can leave the other fields empty to save space).
 *
 * @private @memberof dc_context_t
 */
uint32_t dc_rfc724_mid_exists(dc_context_t* context, const char* rfc724_mid, char** ret_server_folder, uint32_t* ret_server_uid)
{
	uint32_t ret = 0;
	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
		"SELECT server_folder, server_uid, id FROM msgs WHERE rfc724_mid=?;");
	sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		if (ret_server_folder) { *ret_server_folder = NULL; }
		if (ret_server_uid)    { *ret_server_uid    = 0; }
		goto cleanup;
	}

	if (ret_server_folder) { *ret_server_folder = dc_strdup((char*)sqlite3_column_text(stmt, 0)); }
	if (ret_server_uid)    { *ret_server_uid = sqlite3_column_int(stmt, 1); /* may be 0 */ }
	ret = sqlite3_column_int(stmt, 2);

cleanup:
	sqlite3_finalize(stmt);
	return ret;
}


void dc_update_server_uid(dc_context_t* context, const char* rfc724_mid, const char* server_folder, uint32_t server_uid)
{
	sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
		"UPDATE msgs SET server_folder=?, server_uid=? WHERE rfc724_mid=?;"); /* we update by "rfc724_mid" instead of "id" as there may be several db-entries refering to the same "rfc724_mid" */
	sqlite3_bind_text(stmt, 1, server_folder, -1, SQLITE_STATIC);
	sqlite3_bind_int (stmt, 2, server_uid);
	sqlite3_bind_text(stmt, 3, rfc724_mid, -1, SQLITE_STATIC);
	sqlite3_step(stmt);
	sqlite3_finalize(stmt);
}


/**
 * Get a single message object of the type dc_msg_t.
 * For a list of messages in a chat, see dc_get_chat_msgs()
 * For a list or chats, see dc_get_chatlist()
 *
 * @memberof dc_context_t
 * @param context The context as created by dc_context_new().
 * @param msg_id The message ID for which the message object should be created.
 * @return A dc_msg_t message object. When done, the object must be freed using dc_msg_unref()
 */
dc_msg_t* dc_get_msg(dc_context_t* context, uint32_t msg_id)
{
	int success = 0;
	dc_msg_t* obj = dc_msg_new(context);

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	if (!dc_msg_load_from_db(obj, context, msg_id)) {
		goto cleanup;
	}

	success = 1;

cleanup:
	if (success) {
		return obj;
	}
	else {
		dc_msg_unref(obj);
		return NULL;
	}
}


/**
 * Get an informational text for a single message. the text is multiline and may
 * contain eg. the raw text of the message.
 *
 * The max. text returned is typically longer (about 100000 characters) than the
 * max. text returned by dc_msg_get_text() (about 30000 characters).
 *
 * If the library is compiled for andoid, some basic html-formatting for he
 * subject and the footer is added. However we should change this function so
 * that it returns eg. an array of pairwise key-value strings and the caller
 * can show the whole stuff eg. in a table.
 *
 * @memberof dc_context_t
 * @param context the context object as created by dc_context_new().
 * @param msg_id the message id for which information should be generated
 * @return text string, must be free()'d after usage
 */
char* dc_get_msg_info(dc_context_t* context, uint32_t msg_id)
{
	sqlite3_stmt*   stmt = NULL;
	dc_msg_t*       msg = dc_msg_new(context);
	dc_contact_t*   contact_from = dc_contact_new(context);
	char*           rawtxt = NULL;
	char*           p = NULL;
	dc_strbuilder_t ret;
	dc_strbuilder_init(&ret, 0);

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		goto cleanup;
	}

	dc_msg_load_from_db(msg, context, msg_id);
	dc_contact_load_from_db(contact_from, context->sql, msg->from_id);

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT txt_raw FROM msgs WHERE id=?;");
	sqlite3_bind_int(stmt, 1, msg_id);
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		p = dc_mprintf("Cannot load message #%i.", (int)msg_id); dc_strbuilder_cat(&ret, p); free(p);
		goto cleanup;
	}
	rawtxt = dc_strdup((char*)sqlite3_column_text(stmt, 0));
	sqlite3_finalize(stmt);
	stmt = NULL;

	#ifdef __ANDROID__
		p = strchr(rawtxt, '\n');
		if (p) {
			char* subject = rawtxt;
			*p = 0;
			p++;
			rawtxt = dc_mprintf("<b>%s</b>\n%s", subject, p);
			free(subject);
		}
	#endif

	dc_trim(rawtxt);
	dc_truncate_str(rawtxt, DC_MAX_GET_INFO_LEN);

	/* add time */
	dc_strbuilder_cat(&ret, "Sent: ");
	p = dc_timestamp_to_str(dc_msg_get_timestamp(msg)); dc_strbuilder_cat(&ret, p); free(p);
	dc_strbuilder_cat(&ret, "\n");

	if (msg->from_id!=DC_CONTACT_ID_SELF) {
		dc_strbuilder_cat(&ret, "Received: ");
		p = dc_timestamp_to_str(msg->timestamp_rcvd? msg->timestamp_rcvd : msg->timestamp); dc_strbuilder_cat(&ret, p); free(p);
		dc_strbuilder_cat(&ret, "\n");
	}

	if (msg->from_id==DC_CONTACT_ID_DEVICE || msg->to_id==DC_CONTACT_ID_DEVICE) {
		goto cleanup; // device-internal message, no further details needed
	}

	/* add mdn's time and readers */
	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT contact_id, timestamp_sent FROM msgs_mdns WHERE msg_id=?;");
	sqlite3_bind_int (stmt, 1, msg_id);
	while (sqlite3_step(stmt)==SQLITE_ROW) {
		dc_strbuilder_cat(&ret, "Read: ");
		p = dc_timestamp_to_str(sqlite3_column_int64(stmt, 1)); dc_strbuilder_cat(&ret, p); free(p);
		dc_strbuilder_cat(&ret, " by ");

		dc_contact_t* contact = dc_contact_new(context);
			dc_contact_load_from_db(contact, context->sql, sqlite3_column_int64(stmt, 0));
			p = dc_contact_get_display_name(contact); dc_strbuilder_cat(&ret, p); free(p);
		dc_contact_unref(contact);
		dc_strbuilder_cat(&ret, "\n");
	}
	sqlite3_finalize(stmt);
	stmt = NULL;

	/* add state */
	p = NULL;
	switch (msg->state) {
		case DC_STATE_IN_FRESH:      p = dc_strdup("Fresh");           break;
		case DC_STATE_IN_NOTICED:    p = dc_strdup("Noticed");         break;
		case DC_STATE_IN_SEEN:       p = dc_strdup("Seen");            break;
		case DC_STATE_OUT_DELIVERED: p = dc_strdup("Delivered");       break;
		case DC_STATE_OUT_FAILED:    p = dc_strdup("Failed");          break;
		case DC_STATE_OUT_MDN_RCVD:  p = dc_strdup("Read");            break;
		case DC_STATE_OUT_PENDING:   p = dc_strdup("Pending");         break;
		default:                     p = dc_mprintf("%i", msg->state); break;
	}
	dc_strbuilder_catf(&ret, "State: %s", p);
	free(p);

	p = NULL;
	int e2ee_errors;
	if ((e2ee_errors=dc_param_get_int(msg->param, DC_PARAM_ERRONEOUS_E2EE, 0))) {
		if (e2ee_errors&DC_E2EE_NO_VALID_SIGNATURE) {
			p = dc_strdup("Encrypted, no valid signature");
		}
	}
	else if (dc_param_get_int(msg->param, DC_PARAM_GUARANTEE_E2EE, 0)) {
		p = dc_strdup("Encrypted");
	}

	if (p) {
		dc_strbuilder_catf(&ret, ", %s", p);
		free(p);
	}
	dc_strbuilder_cat(&ret, "\n");


	if ((p=dc_param_get(msg->param, DC_PARAM_ERROR, NULL))!=NULL) {
		dc_strbuilder_catf(&ret, "Error: %s\n", p);
		free(p);
	}

	/* add sender (only for info messages as the avatar may not be shown for them) */
	if (dc_msg_is_info(msg)) {
		dc_strbuilder_cat(&ret, "Sender: ");
		p = dc_contact_get_name_n_addr(contact_from); dc_strbuilder_cat(&ret, p); free(p);
		dc_strbuilder_cat(&ret, "\n");
	}

	/* add file info */
	if ((p=dc_param_get(msg->param, DC_PARAM_FILE, NULL))!=NULL) {
		dc_strbuilder_catf(&ret, "\nFile: %s, %i bytes\n", p, (int)dc_get_filebytes(p));
		free(p);
	}

	if (msg->type!=DC_MSG_TEXT) {
		p = NULL;
		switch (msg->type)  {
			case DC_MSG_AUDIO: p = dc_strdup("Audio");          break;
			case DC_MSG_FILE:  p = dc_strdup("File");           break;
			case DC_MSG_GIF:   p = dc_strdup("GIF");            break;
			case DC_MSG_IMAGE: p = dc_strdup("Image");          break;
			case DC_MSG_VIDEO: p = dc_strdup("Video");          break;
			case DC_MSG_VOICE: p = dc_strdup("Voice");          break;
			default:           p = dc_mprintf("%i", msg->type); break;
		}
		dc_strbuilder_catf(&ret, "Type: %s\n", p);
		free(p);
	}

	int w = dc_param_get_int(msg->param, DC_PARAM_WIDTH, 0);
	int h = dc_param_get_int(msg->param, DC_PARAM_HEIGHT, 0);
	if (w!=0 || h!=0) {
		p = dc_mprintf("Dimension: %i x %i\n", w, h); dc_strbuilder_cat(&ret, p); free(p);
	}

	int duration = dc_param_get_int(msg->param, DC_PARAM_DURATION, 0);
	if (duration!=0) {
		p = dc_mprintf("Duration: %i ms\n", duration); dc_strbuilder_cat(&ret, p); free(p);
	}

	/* add rawtext */
	if (rawtxt && rawtxt[0]) {
		dc_strbuilder_cat(&ret, "\n");
		dc_strbuilder_cat(&ret, rawtxt);
		dc_strbuilder_cat(&ret, "\n");
	}

	/* add Message-ID, Server-Folder and Server-UID; the database ID is normally only of interest if you have access to sqlite; if so you can easily get it from the "msgs" table. */
	#ifdef __ANDROID__
		dc_strbuilder_cat(&ret, "<c#808080>");
	#endif

	if (msg->rfc724_mid && msg->rfc724_mid[0]) {
		dc_strbuilder_catf(&ret, "\nMessage-ID: %s", msg->rfc724_mid);
	}

	if (msg->server_folder && msg->server_folder[0]) {
		dc_strbuilder_catf(&ret, "\nLast seen as: %s/%i", msg->server_folder, (int)msg->server_uid);
	}

	#ifdef __ANDROID__
		dc_strbuilder_cat(&ret, "</c>");
	#endif

cleanup:
	sqlite3_finalize(stmt);
	dc_msg_unref(msg);
	dc_contact_unref(contact_from);
	free(rawtxt);
	return ret.buf;
}


/**
 * Star/unstar messages by setting the last parameter to 0 (unstar) or 1 (star).
 * Starred messages are collected in a virtual chat that can be shown using
 * dc_get_chat_msgs() using the chat_id DC_CHAT_ID_STARRED.
 *
 * @memberof dc_context_t
 * @param context The context object as created by dc_context_new()
 * @param msg_ids An array of uint32_t message IDs defining the messages to star or unstar
 * @param msg_cnt The number of IDs in msg_ids
 * @param star 0=unstar the messages in msg_ids, 1=star them
 * @return none
 */
void dc_star_msgs(dc_context_t* context, const uint32_t* msg_ids, int msg_cnt, int star)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || msg_ids==NULL || msg_cnt<=0 || (star!=0 && star!=1)) {
		return;
	}

	dc_sqlite3_begin_transaction(context->sql);

		sqlite3_stmt* stmt = dc_sqlite3_prepare(context->sql,
			"UPDATE msgs SET starred=? WHERE id=?;");
		for (int i = 0; i < msg_cnt; i++)
		{
			sqlite3_reset(stmt);
			sqlite3_bind_int(stmt, 1, star);
			sqlite3_bind_int(stmt, 2, msg_ids[i]);
			sqlite3_step(stmt);
		}
		sqlite3_finalize(stmt);

	dc_sqlite3_commit(context->sql);
}


/*******************************************************************************
 * Delete messages
 ******************************************************************************/


/**
 * Delete messages. The messages are deleted on the current device and
 * on the IMAP server.
 *
 * @memberof dc_context_t
 * @param context the context object as created by dc_context_new()
 * @param msg_ids an array of uint32_t containing all message IDs that should be deleted
 * @param msg_cnt the number of messages IDs in the msg_ids array
 * @return none
 */
void dc_delete_msgs(dc_context_t* context, const uint32_t* msg_ids, int msg_cnt)
{
	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || msg_ids==NULL || msg_cnt<=0) {
		return;
	}

	dc_sqlite3_begin_transaction(context->sql);

		for (int i = 0; i < msg_cnt; i++)
		{
			dc_update_msg_chat_id(context, msg_ids[i], DC_CHAT_ID_TRASH);
			dc_job_add(context, DC_JOB_DELETE_MSG_ON_IMAP, msg_ids[i], NULL, 0);
		}

	dc_sqlite3_commit(context->sql);
}


/*******************************************************************************
 * mark message as seen
 ******************************************************************************/


/**
 * Mark a message as _seen_, updates the IMAP state and
 * sends MDNs. If the message is not in a real chat (eg. a contact request), the
 * message is only marked as NOTICED and no IMAP/MDNs is done.  See also
 * dc_marknoticed_chat() and dc_marknoticed_contact()
 *
 * @memberof dc_context_t
 * @param context The context object.
 * @param msg_ids an array of uint32_t containing all the messages IDs that should be marked as seen.
 * @param msg_cnt The number of message IDs in msg_ids.
 * @return none
 */
void dc_markseen_msgs(dc_context_t* context, const uint32_t* msg_ids, int msg_cnt)
{
	int transaction_pending = 0;
	int i = 0;
	int send_event = 0;
	int curr_state = 0;
	int curr_blocked = 0;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || msg_ids==NULL || msg_cnt<=0) {
		goto cleanup;
	}

	dc_sqlite3_begin_transaction(context->sql);
	transaction_pending = 1;

		stmt = dc_sqlite3_prepare(context->sql,
			"SELECT m.state, c.blocked "
			" FROM msgs m "
			" LEFT JOIN chats c ON c.id=m.chat_id "
			" WHERE m.id=? AND m.chat_id>" DC_STRINGIFY(DC_CHAT_ID_LAST_SPECIAL));
		for (i = 0; i < msg_cnt; i++)
		{
			sqlite3_reset(stmt);
			sqlite3_bind_int(stmt, 1, msg_ids[i]);
			if (sqlite3_step(stmt)!=SQLITE_ROW) {
				continue;
			}
			curr_state   = sqlite3_column_int(stmt, 0);
			curr_blocked = sqlite3_column_int(stmt, 1);
			if (curr_blocked==0)
			{
				if (curr_state==DC_STATE_IN_FRESH || curr_state==DC_STATE_IN_NOTICED) {
					dc_update_msg_state(context, msg_ids[i], DC_STATE_IN_SEEN);
					dc_log_info(context, 0, "Seen message #%i.", msg_ids[i]);
					dc_job_add(context, DC_JOB_MARKSEEN_MSG_ON_IMAP, msg_ids[i], NULL, 0); /* results in a call to dc_markseen_msg_on_imap() */
					send_event = 1;
				}
			}
			else
			{
				/* message may be in contact requests, mark as NOTICED, this does not force IMAP updated nor send MDNs */
				if (curr_state==DC_STATE_IN_FRESH) {
					dc_update_msg_state(context, msg_ids[i], DC_STATE_IN_NOTICED);
					send_event = 1;
				}
			}
		}

	dc_sqlite3_commit(context->sql);
	transaction_pending = 0;

	/* the event is needed eg. to remove the deaddrop from the chatlist */
	if (send_event) {
		context->cb(context, DC_EVENT_MSGS_CHANGED, 0, 0);
	}

cleanup:
	if (transaction_pending) { dc_sqlite3_rollback(context->sql); }
	sqlite3_finalize(stmt);
}


int dc_mdn_from_ext(dc_context_t* context, uint32_t from_id, const char* rfc724_mid, time_t timestamp_sent,
                    uint32_t* ret_chat_id, uint32_t* ret_msg_id)
{
	int           read_by_all = 0;
	sqlite3_stmt* stmt = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || from_id<=DC_CONTACT_ID_LAST_SPECIAL || rfc724_mid==NULL || ret_chat_id==NULL || ret_msg_id==NULL
	 || *ret_chat_id!=0 || *ret_msg_id!=0) {
		goto cleanup;
	}

	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT m.id, c.id, c.type, m.state FROM msgs m "
		" LEFT JOIN chats c ON m.chat_id=c.id "
		" WHERE rfc724_mid=? AND from_id=1 "
		" ORDER BY m.id;"); /* the ORDER BY makes sure, if one rfc724_mid is splitted into its parts, we always catch the same one. However, we do not send multiparts, we do not request MDNs for multiparts, and should not receive read requests for multiparts. So this is currently more theoretical. */
	sqlite3_bind_text(stmt, 1, rfc724_mid, -1, SQLITE_STATIC);
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup;
	}
	*ret_msg_id    = sqlite3_column_int(stmt, 0);
	*ret_chat_id   = sqlite3_column_int(stmt, 1);
	int chat_type  = sqlite3_column_int(stmt, 2);
	int msg_state  = sqlite3_column_int(stmt, 3);
	sqlite3_finalize(stmt);
	stmt = NULL;

	if (msg_state!=DC_STATE_OUT_PENDING && msg_state!=DC_STATE_OUT_DELIVERED) {
		goto cleanup; /* eg. already marked as MDNS_RCVD. however, it is importent, that the message ID is set above as this will allow the caller eg. to move the message away */
	}

	// collect receipt senders, we do this also for normal chats as we may want to show the timestamp
	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT contact_id FROM msgs_mdns WHERE msg_id=? AND contact_id=?;");
	sqlite3_bind_int(stmt, 1, *ret_msg_id);
	sqlite3_bind_int(stmt, 2, from_id);
	int mdn_already_in_table = (sqlite3_step(stmt)==SQLITE_ROW)? 1 : 0;
	sqlite3_finalize(stmt);
	stmt = NULL;

	if (!mdn_already_in_table) {
		stmt = dc_sqlite3_prepare(context->sql,
			"INSERT INTO msgs_mdns (msg_id, contact_id, timestamp_sent) VALUES (?, ?, ?);");
		sqlite3_bind_int  (stmt, 1, *ret_msg_id);
		sqlite3_bind_int  (stmt, 2, from_id);
		sqlite3_bind_int64(stmt, 3, timestamp_sent);
		sqlite3_step(stmt);
		sqlite3_finalize(stmt);
		stmt = NULL;
	}

	// Normal chat? that's quite easy.
	if (chat_type==DC_CHAT_TYPE_SINGLE) {
		dc_update_msg_state(context, *ret_msg_id, DC_STATE_OUT_MDN_RCVD);
		read_by_all = 1;
		goto cleanup; /* send event about new state */
	}

	// Group chat: get the number of receipt senders
	stmt = dc_sqlite3_prepare(context->sql,
		"SELECT COUNT(*) FROM msgs_mdns WHERE msg_id=?;");
	sqlite3_bind_int(stmt, 1, *ret_msg_id);
	if (sqlite3_step(stmt)!=SQLITE_ROW) {
		goto cleanup; /* error */
	}
	int ist_cnt  = sqlite3_column_int(stmt, 0);
	sqlite3_finalize(stmt);
	stmt = NULL;

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
	int soll_cnt = (dc_get_chat_contact_cnt(context, *ret_chat_id)+1/*for rounding, SELF is already included!*/) / 2;
	if (ist_cnt < soll_cnt) {
		goto cleanup; /* wait for more receipts */
	}

	/* got enough receipts :-) */
	dc_update_msg_state(context, *ret_msg_id, DC_STATE_OUT_MDN_RCVD);
	read_by_all = 1;

cleanup:
	sqlite3_finalize(stmt);
	return read_by_all;
}
