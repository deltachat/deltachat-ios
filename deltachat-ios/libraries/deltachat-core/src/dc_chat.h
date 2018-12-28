#ifndef __DC_CHAT_H__
#define __DC_CHAT_H__
#ifdef __cplusplus
extern "C" {
#endif


/* values for the chats.blocked database field */
#define         DC_CHAT_NOT_BLOCKED       0
#define         DC_CHAT_MANUALLY_BLOCKED  1
#define         DC_CHAT_DEADDROP_BLOCKED  2


/** the structure behind dc_chat_t */
struct _dc_chat
{
	/** @privatesection */
	uint32_t        magic;
	uint32_t        id;
	int             type;             /**< Chat type. Use dc_chat_get_type() to access this field. */
	char*           name;             /**< Name of the chat. Use dc_chat_get_name() to access this field. NULL if unset. */
	int             archived;         /**< Archived state. Better use dc_chat_get_archived() to access this object. */
	dc_context_t*   context;          /**< The context object the chat belongs to. */
	char*           grpid;            /**< Group ID that is used by all clients. Only used if the chat is a group. NULL if unset */
	int             blocked;          /**< One of DC_CHAT_*_BLOCKED */
	dc_param_t*     param;            /**< Additional parameters for a chat. Should not be used directly. */
};

int             dc_chat_load_from_db               (dc_chat_t*, uint32_t id);
int             dc_chat_update_param               (dc_chat_t*);

#define         DC_CHAT_TYPE_IS_MULTI(a)   ((a)==DC_CHAT_TYPE_GROUP || (a)==DC_CHAT_TYPE_VERIFIED_GROUP)
#define         DC_CHAT_TYPE_CAN_SEND(a)   ((a)==DC_CHAT_TYPE_SINGLE || (a)==DC_CHAT_TYPE_GROUP || (a)==DC_CHAT_TYPE_VERIFIED_GROUP)

#define         DC_CHAT_PREFIX              "Chat:"      /* you MUST NOT modify this or the following strings */


// Context functions to work with chats
int             dc_add_to_chat_contacts_table              (dc_context_t*, uint32_t chat_id, uint32_t contact_id);
int             dc_is_contact_in_chat                      (dc_context_t*, uint32_t chat_id, uint32_t contact_id);
size_t          dc_get_chat_cnt                            (dc_context_t*);
uint32_t        dc_get_chat_id_by_grpid                    (dc_context_t*, const char* grpid, int* ret_blocked, int* ret_verified);
void            dc_create_or_lookup_nchat_by_contact_id    (dc_context_t*, uint32_t contact_id, int create_blocked, uint32_t* ret_chat_id, int* ret_chat_blocked);
void            dc_lookup_real_nchat_by_contact_id         (dc_context_t*, uint32_t contact_id, uint32_t* ret_chat_id, int* ret_chat_blocked);
void            dc_unarchive_chat                          (dc_context_t*, uint32_t chat_id);
void            dc_block_chat                              (dc_context_t*, uint32_t chat_id, int new_blocking);
void            dc_unblock_chat                            (dc_context_t*, uint32_t chat_id);
void            dc_add_device_msg                          (dc_context_t*, uint32_t chat_id, const char* text);
int             dc_get_chat_contact_cnt                    (dc_context_t*, uint32_t chat_id);
int             dc_is_group_explicitly_left                (dc_context_t*, const char* grpid);
void            dc_set_group_explicitly_left               (dc_context_t*, const char* grpid);

#define         DC_FROM_HANDSHAKE                          0x01
int             dc_add_contact_to_chat_ex                  (dc_context_t*, uint32_t chat_id, uint32_t contact_id, int flags);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_CHAT_H__ */
