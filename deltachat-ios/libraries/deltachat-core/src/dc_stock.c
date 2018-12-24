/* Add translated strings that are used by the messager backend.
As the logging functions may use these strings, do not log any
errors from here. */


#include "dc_context.h"


static char* default_string(int id)
{
	switch (id) {
		case DC_STR_NOMESSAGES:            return dc_strdup("No messages.");
		case DC_STR_SELF:                  return dc_strdup("Me");
		case DC_STR_DRAFT:                 return dc_strdup("Draft");
		case DC_STR_MEMBER:                return dc_strdup("%1$s member(s)");
		case DC_STR_CONTACT:               return dc_strdup("%1$s contact(s)");
		case DC_STR_VOICEMESSAGE:          return dc_strdup("Voice message");
		case DC_STR_DEADDROP:              return dc_strdup("Mailbox");
		case DC_STR_IMAGE:                 return dc_strdup("Image");
		case DC_STR_GIF:                   return dc_strdup("GIF");
		case DC_STR_VIDEO:                 return dc_strdup("Video");
		case DC_STR_AUDIO:                 return dc_strdup("Audio");
		case DC_STR_FILE:                  return dc_strdup("File");
		case DC_STR_ENCRYPTEDMSG:          return dc_strdup("Encrypted message");
		case DC_STR_STATUSLINE:            return dc_strdup("Sent with my Delta Chat Messenger: https://delta.chat");
		case DC_STR_NEWGROUPDRAFT:         return dc_strdup("Hello, I've just created the group \"%1$s\" for us.");
		case DC_STR_MSGGRPNAME:            return dc_strdup("Group name changed from \"%1$s\" to \"%2$s\".");
		case DC_STR_MSGGRPIMGCHANGED:      return dc_strdup("Group image changed.");
		case DC_STR_MSGADDMEMBER:          return dc_strdup("Member %1$s added.");
		case DC_STR_MSGDELMEMBER:          return dc_strdup("Member %1$s removed.");
		case DC_STR_MSGGROUPLEFT:          return dc_strdup("Left group.");
		case DC_STR_E2E_AVAILABLE:         return dc_strdup("End-to-end encryption available.");
		case DC_STR_ENCR_TRANSP:           return dc_strdup("Transport-encryption.");
		case DC_STR_ENCR_NONE:             return dc_strdup("No encryption.");
		case DC_STR_FINGERPRINTS:          return dc_strdup("Fingerprints");
		case DC_STR_READRCPT:              return dc_strdup("Return receipt");
		case DC_STR_READRCPT_MAILBODY:     return dc_strdup("This is a return receipt for the message \"%1$s\".");
		case DC_STR_MSGGRPIMGDELETED:      return dc_strdup("Group image deleted.");
		case DC_STR_E2E_PREFERRED:         return dc_strdup("End-to-end encryption preferred.");
		case DC_STR_ARCHIVEDCHATS:         return dc_strdup("Archived chats");
		case DC_STR_STARREDMSGS:           return dc_strdup("Starred messages");
		case DC_STR_AC_SETUP_MSG_SUBJECT:  return dc_strdup("Autocrypt Setup Message");
		case DC_STR_AC_SETUP_MSG_BODY:     return dc_strdup("This is the Autocrypt Setup Message used to transfer your key between clients.\n\nTo decrypt and use your key, open the message in an Autocrypt-compliant client and enter the setup code presented on the generating device.");
		case DC_STR_SELFTALK_SUBTITLE:     return dc_strdup("Messages I sent to myself");
		case DC_STR_CANTDECRYPT_MSG_BODY:  return dc_strdup("This message was encrypted for another setup.");
		case DC_STR_CANNOT_LOGIN:          return dc_strdup("Cannot login as %1$s.");
		case DC_STR_SERVER_RESPONSE:       return dc_strdup("Response from %1$s: %2$s");
	}
	return dc_strdup("ErrStr");
}


static char* get_string(dc_context_t* context, int id, int qty)
{
	char* ret = NULL;
	if (context) {
		ret = (char*)context->cb(context, DC_EVENT_GET_STRING, id, qty);
	}
	if (ret == NULL) {
		ret = default_string(id);
	}
	return ret;
}


char* dc_stock_str(dc_context_t* context, int id)
{
	return get_string(context, id, 0);
}


char* dc_stock_str_repl_string(dc_context_t* context, int id, const char* to_insert)
{
	char* ret = get_string(context, id, 0);
	dc_str_replace(&ret, "%1$s", to_insert);
	return ret;
}


char* dc_stock_str_repl_int(dc_context_t* context, int id, int to_insert_int)
{
	char* ret = get_string(context, id, to_insert_int);
	char* to_insert_str = dc_mprintf("%i", (int)to_insert_int);
	dc_str_replace(&ret, "%1$s", to_insert_str);
	free(to_insert_str);
	return ret;
}


char* dc_stock_str_repl_string2(dc_context_t* context, int id, const char* to_insert, const char* to_insert2)
{
	char* ret = get_string(context, id, 0);
	dc_str_replace(&ret, "%1$s", to_insert);
	dc_str_replace(&ret, "%2$s", to_insert2);
	return ret;
}
