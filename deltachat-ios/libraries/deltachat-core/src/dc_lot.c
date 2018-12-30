#include "dc_context.h"


#define DC_LOT_MAGIC 0x00107107


dc_lot_t* dc_lot_new()
{
	dc_lot_t* lot = NULL;

	if ((lot=calloc(1, sizeof(dc_lot_t)))==NULL) {
		exit(27); /* cannot allocate little memory, unrecoverable error */
	}

	lot->magic = DC_LOT_MAGIC;
	lot->text1_meaning  = 0;

    return lot;
}


/**
 * Frees an object containing a set of parameters.
 * If the set object contains strings, the strings are also freed with this function.
 * Set objects are created eg. by dc_chatlist_get_summary() or dc_msg_get_summary().
 *
 * @memberof dc_lot_t
 * @param set The object to free.
 *     If NULL is given, nothing is done.
 * @return None.
 */
void dc_lot_unref(dc_lot_t* set)
{
	if (set==NULL || set->magic!=DC_LOT_MAGIC) {
		return;
	}

	dc_lot_empty(set);
	set->magic = 0;
	free(set);
}


void dc_lot_empty(dc_lot_t* lot)
{
	if (lot==NULL || lot->magic!=DC_LOT_MAGIC) {
		return;
	}

	free(lot->text1);
	lot->text1 = NULL;
	lot->text1_meaning = 0;

	free(lot->text2);
	lot->text2 = NULL;

	free(lot->fingerprint);
	lot->fingerprint = NULL;

	free(lot->invitenumber);
	lot->invitenumber = NULL;

	free(lot->auth);
	lot->auth = NULL;

	lot->timestamp = 0;
	lot->state = 0;
	lot->id = 0;
}


/**
 * Get first string. The meaning of the string is defined by the creator of the object and may be roughly described by dc_lot_get_text1_meaning().
 *
 * @memberof dc_lot_t
 * @param lot The lot object.
 * @return A string, the string may be empty and the returned value must be free()'d. NULL if there is no such string.
 */
char* dc_lot_get_text1(const dc_lot_t* lot)
{
	if (lot==NULL || lot->magic!=DC_LOT_MAGIC) {
		return NULL;
	}
	return dc_strdup_keep_null(lot->text1);
}


/**
 * Get second string. The meaning of the string is defined by the creator of the object.
 *
 * @memberof dc_lot_t
 *
 * @param lot The lot object.
 *
 * @return A string, the string may be empty and the returned value must be free()'d	. NULL if there is no such string.
 */
char* dc_lot_get_text2(const dc_lot_t* lot)
{
	if (lot==NULL || lot->magic!=DC_LOT_MAGIC) {
		return NULL;
	}
	return dc_strdup_keep_null(lot->text2);
}


/**
 * Get the meaning of the first string.  Posssible meanings of the string are defined by the creator of the object and may be returned eg.
 * as DC_TEXT1_DRAFT, DC_TEXT1_USERNAME or DC_TEXT1_SELF.
 *
 * @memberof dc_lot_t
 * @param lot The lot object.
 * @return Returns the meaning of the first string, possible meanings are defined by the creator of the object.
 *    0 if there is no concrete meaning or on errors.
 */
int dc_lot_get_text1_meaning(const dc_lot_t* lot)
{
	if (lot==NULL || lot->magic!=DC_LOT_MAGIC) {
		return 0;
	}
	return lot->text1_meaning;
}


/**
 * Get the associated state. The meaning of the state is defined by the creator of the object.
 *
 * @memberof dc_lot_t
 *
 * @param lot The lot object.
 *
 * @return The state as defined by the creator of the object. 0 if there is not state or on errors.
 */
int dc_lot_get_state(const dc_lot_t* lot)
{
	if (lot==NULL || lot->magic!=DC_LOT_MAGIC) {
		return 0;
	}
	return lot->state;
}


/**
 * Get the associated ID. The meaning of the ID is defined by the creator of the object.
 *
 * @memberof dc_lot_t
 * @param lot The lot object.
 * @return The state as defined by the creator of the object. 0 if there is not state or on errors.
 */
uint32_t dc_lot_get_id(const dc_lot_t* lot)
{
	if (lot==NULL || lot->magic!=DC_LOT_MAGIC) {
		return 0;
	}
	return lot->id;
}


/**
 * Get the associated timestamp.
 * The timestamp is returned as a unix timestamp in seconds.
 * The meaning of the timestamp is defined by the creator of the object.
 *
 * @memberof dc_lot_t
 *
 * @param lot The lot object.
 *
 * @return The timestamp as defined by the creator of the object. 0 if there is not timestamp or on errors.
 */
time_t dc_lot_get_timestamp(const dc_lot_t* lot)
{
	if (lot==NULL || lot->magic!=DC_LOT_MAGIC) {
		return 0;
	}
	return lot->timestamp;
}


void dc_lot_fill(dc_lot_t* lot, const dc_msg_t* msg, const dc_chat_t* chat, const dc_contact_t* contact, dc_context_t* context)
{
	if (lot==NULL || lot->magic!=DC_LOT_MAGIC || msg==NULL) {
		return;
	}

	if (msg->state==DC_STATE_OUT_DRAFT)
	{
		lot->text1 = dc_stock_str(context, DC_STR_DRAFT);
		lot->text1_meaning = DC_TEXT1_DRAFT;
	}
	else if (msg->from_id==DC_CONTACT_ID_SELF)
	{
		if (dc_msg_is_info(msg)) {
			lot->text1 = NULL;
			lot->text1_meaning = 0;
		}
		else {
			lot->text1 = dc_stock_str(context, DC_STR_SELF);
			lot->text1_meaning = DC_TEXT1_SELF;
		}
	}
	else if (chat==NULL)
	{
		lot->text1 = NULL;
		lot->text1_meaning = 0;
	}
	else if (DC_CHAT_TYPE_IS_MULTI(chat->type))
	{
		if (dc_msg_is_info(msg) || contact==NULL) {
			lot->text1 = NULL;
			lot->text1_meaning = 0;
		}
		else {
			lot->text1 = dc_contact_get_first_name(contact);
			lot->text1_meaning = DC_TEXT1_USERNAME;
		}
	}

	lot->text2     = dc_msg_get_summarytext_by_raw(msg->type, msg->text, msg->param, DC_SUMMARY_CHARACTERS, context);
	lot->timestamp = dc_msg_get_timestamp(msg);
	lot->state     = msg->state;
}
