// deprecated file
#ifndef __MRMAILBOX_DEPRECATED_H__
#define __MRMAILBOX_DEPRECATED_H__
#ifdef __cplusplus
extern "C" {
#endif

#include "deltachat.h"

// types
#define mrmailbox_t                         dc_context_t
#define mrmailboxcb_t                       dc_callback_t
#define mrarray_t                           dc_array_t
#define mrchatlist_t                        dc_chatlist_t
#define mrchat_t                            dc_chat_t
#define mrmsg_t                             dc_msg_t
#define mrcontact_t                         dc_contact_t
#define mrlot_t                             dc_lot_t

// mailbox functions
#define MR_GCL_ARCHIVED_ONLY                DC_GCL_ARCHIVED_ONLY
#define MR_GCL_NO_SPECIALS                  DC_GCL_NO_SPECIALS
#define MR_GCL_VERIFIED_ONLY                DC_GCL_VERIFIED_ONLY
#define MR_GCL_ADD_SELF                     DC_GCL_ADD_SELF
#define MR_IMEX_EXPORT_SELF_KEYS            DC_IMEX_EXPORT_SELF_KEYS
#define MR_IMEX_IMPORT_SELF_KEYS            DC_IMEX_IMPORT_SELF_KEYS
#define MR_IMEX_EXPORT_BACKUP               DC_IMEX_EXPORT_BACKUP
#define MR_IMEX_IMPORT_BACKUP               DC_IMEX_IMPORT_BACKUP
#define MR_QR_ASK_VERIFYCONTACT             DC_QR_ASK_VERIFYCONTACT
#define MR_QR_ASK_VERIFYGROUP               DC_QR_ASK_VERIFYGROUP
#define MR_QR_FPR_OK                        DC_QR_FPR_OK
#define MR_QR_FPR_MISMATCH                  DC_QR_FPR_MISMATCH
#define MR_QR_FPR_WITHOUT_ADDR              DC_QR_FPR_WITHOUT_ADDR
#define MR_QR_ADDR                          DC_QR_ADDR
#define MR_QR_TEXT                          DC_QR_TEXT
#define MR_QR_URL                           DC_QR_URL
#define MR_QR_ERROR                         DC_QR_ERROR
#define MR_GCM_ADDDAYMARKER                 DC_GCM_ADDDAYMARKER
#define mrmailbox_new                       dc_context_new
#define mrmailbox_unref                     dc_context_unref
#define mrmailbox_get_userdata              dc_get_userdata
#define mrmailbox_open                      dc_open
#define mrmailbox_close                     dc_close
#define mrmailbox_is_open                   dc_is_open
#define mrmailbox_get_blobdir               dc_get_blobdir
#define mrmailbox_set_config                dc_set_config
#define mrmailbox_get_config                dc_get_config
#define mrmailbox_set_config_int            dc_set_config_int
#define mrmailbox_get_config_int            dc_get_config_int
#define mrmailbox_get_info                  dc_get_info
#define mrmailbox_get_version_str           dc_get_version_str
#define mrmailbox_configure                 dc_configure
#define mrmailbox_is_configured             dc_is_configured
#define mrmailbox_get_chatlist              dc_get_chatlist
#define mrmailbox_create_chat_by_msg_id     dc_create_chat_by_msg_id
#define mrmailbox_create_chat_by_contact_id dc_create_chat_by_contact_id
#define mrmailbox_get_chat_id_by_contact_id dc_get_chat_id_by_contact_id
#define mrmailbox_send_text_msg             dc_send_text_msg
#define mrmailbox_send_image_msg            dc_send_image_msg
#define mrmailbox_send_video_msg            dc_send_video_msg
#define mrmailbox_send_voice_msg            dc_send_voice_msg
#define mrmailbox_send_audio_msg            dc_send_audio_msg
#define mrmailbox_send_file_msg             dc_send_file_msg
#define mrmailbox_send_vcard_msg            dc_send_vcard_msg
#define mrmailbox_set_draft                 dc_set_text_draft
#define mrmailbox_get_chat_msgs             dc_get_chat_msgs
#define mrmailbox_get_total_msg_count       dc_get_msg_cnt
#define mrmailbox_get_fresh_msg_count       dc_get_fresh_msg_cnt
#define mrmailbox_get_fresh_msgs            dc_get_fresh_msgs
#define mrmailbox_marknoticed_chat          dc_marknoticed_chat
#define mrmailbox_get_chat_media            dc_get_chat_media
#define mrmailbox_get_next_media            dc_get_next_media
#define mrmailbox_archive_chat              dc_archive_chat
#define mrmailbox_delete_chat               dc_delete_chat
#define mrmailbox_get_chat_contacts         dc_get_chat_contacts
#define mrmailbox_search_msgs               dc_search_msgs
#define mrmailbox_get_chat                  dc_get_chat
#define mrmailbox_create_group_chat         dc_create_group_chat
#define mrmailbox_is_contact_in_chat        dc_is_contact_in_chat
#define mrmailbox_add_contact_to_chat       dc_add_contact_to_chat
#define mrmailbox_remove_contact_from_chat  dc_remove_contact_from_chat
#define mrmailbox_set_chat_name             dc_set_chat_name
#define mrmailbox_set_chat_profile_image    dc_set_chat_profile_image
#define mrmailbox_get_msg_info              dc_get_msg_info
#define mrmailbox_delete_msgs               dc_delete_msgs
#define mrmailbox_forward_msgs              dc_forward_msgs
#define mrmailbox_marknoticed_contact       dc_marknoticed_contact
#define mrmailbox_markseen_msgs             dc_markseen_msgs
#define mrmailbox_star_msgs                 dc_star_msgs
#define mrmailbox_get_msg                   dc_get_msg
#define mrmailbox_create_contact            dc_create_contact
#define mrmailbox_add_address_book          dc_add_address_book
#define mrmailbox_get_contacts              dc_get_contacts
#define mrmailbox_get_blocked_count         dc_get_blocked_cnt
#define mrmailbox_get_blocked_contacts      dc_get_blocked_contacts
#define mrmailbox_block_contact             dc_block_contact
#define mrmailbox_get_contact_encrinfo      dc_get_contact_encrinfo
#define mrmailbox_delete_contact            dc_delete_contact
#define mrmailbox_get_contact               dc_get_contact
#define mrmailbox_imex                      dc_imex
#define mrmailbox_imex_has_backup           dc_imex_has_backup
#define mrmailbox_check_password            dc_check_password
#define mrmailbox_initiate_key_transfer     dc_initiate_key_transfer
#define mrmailbox_continue_key_transfer     dc_continue_key_transfer
#define mrmailbox_stop_ongoing_process      dc_stop_ongoing_process
#define mrmailbox_check_qr                  dc_check_qr
#define mrmailbox_get_securejoin_qr         dc_get_securejoin_qr
#define mrmailbox_join_securejoin           dc_join_securejoin
#define mrmailbox_imex_cancel               dc_stop_ongoing_process
#define mrmailbox_configure_cancel          dc_stop_ongoing_process
#define mrmailbox_heartbeat(a)

// array functions
#define mrarray_new                         dc_array_new
#define mrarray_empty                       dc_array_empty
#define mrarray_unref                       dc_array_unref
#define mrarray_add_uint                    dc_array_add_uint
#define mrarray_add_id                      dc_array_add_id
#define mrarray_add_ptr                     dc_array_add_ptr
#define mrarray_get_cnt                     dc_array_get_cnt
#define mrarray_get_uint                    dc_array_get_uint
#define mrarray_get_id                      dc_array_get_id
#define mrarray_get_ptr                     dc_array_get_ptr
#define mrarray_search_id                   dc_array_search_id
#define mrarray_get_raw                     dc_array_get_raw

// chatlist functions
#define mrchatlist_new                      dc_chatlist_new
#define mrchatlist_empty                    dc_chatlist_empty
#define mrchatlist_unref                    dc_chatlist_unref
#define mrchatlist_get_cnt                  dc_chatlist_get_cnt
#define mrchatlist_get_chat_id              dc_chatlist_get_chat_id
#define mrchatlist_get_msg_id               dc_chatlist_get_msg_id
#define mrchatlist_get_summary              dc_chatlist_get_summary
#define mrchatlist_get_mailbox              dc_chatlist_get_context

// chat functions
#define MR_CHAT_ID_DEADDROP                 DC_CHAT_ID_DEADDROP
#define MR_CHAT_ID_TRASH                    DC_CHAT_ID_TRASH
#define MR_CHAT_ID_MSGS_IN_CREATION         DC_CHAT_ID_MSGS_IN_CREATION
#define MR_CHAT_ID_STARRED                  DC_CHAT_ID_STARRED
#define MR_CHAT_ID_ARCHIVED_LINK            DC_CHAT_ID_ARCHIVED_LINK
#define MR_CHAT_ID_LAST_SPECIAL             DC_CHAT_ID_LAST_SPECIAL
#define MR_CHAT_TYPE_UNDEFINED              DC_CHAT_TYPE_UNDEFINED
#define MR_CHAT_TYPE_SINGLE                 DC_CHAT_TYPE_SINGLE
#define MR_CHAT_TYPE_GROUP                  DC_CHAT_TYPE_GROUP
#define MR_CHAT_TYPE_VERIFIED_GROUP         DC_CHAT_TYPE_VERIFIED_GROUP
#define mrchat_new                          dc_chat_new
#define mrchat_empty                        dc_chat_empty
#define mrchat_unref                        dc_chat_unref
#define mrchat_get_id                       dc_chat_get_id
#define mrchat_get_type                     dc_chat_get_type
#define mrchat_get_name                     dc_chat_get_name
#define mrchat_get_subtitle                 dc_chat_get_subtitle
#define mrchat_get_profile_image            dc_chat_get_profile_image
#define mrchat_get_draft                    dc_chat_get_text_draft
#define mrchat_get_draft_timestamp          dc_chat_get_draft_timestamp
#define mrchat_get_archived                 dc_chat_get_archived
#define mrchat_is_unpromoted                dc_chat_is_unpromoted
#define mrchat_is_self_talk                 dc_chat_is_self_talk
#define mrchat_is_verified                  dc_chat_is_verified

// message functions
#define MR_MSG_ID_MARKER1                   DC_MSG_ID_MARKER1
#define MR_MSG_ID_DAYMARKER                 DC_MSG_ID_DAYMARKER
#define MR_MSG_ID_LAST_SPECIAL              DC_MSG_ID_LAST_SPECIAL
#define MR_MSG_UNDEFINED                    DC_MSG_UNDEFINED
#define MR_MSG_TEXT                         DC_MSG_TEXT
#define MR_MSG_IMAGE                        DC_MSG_IMAGE
#define MR_MSG_GIF                          DC_MSG_GIF
#define MR_MSG_AUDIO                        DC_MSG_AUDIO
#define MR_MSG_VOICE                        DC_MSG_VOICE
#define MR_MSG_VIDEO                        DC_MSG_VIDEO
#define MR_MSG_FILE                         DC_MSG_FILE
#define MR_STATE_UNDEFINED                  DC_STATE_UNDEFINED
#define MR_STATE_IN_FRESH                   DC_STATE_IN_FRESH
#define MR_STATE_IN_NOTICED                 DC_STATE_IN_NOTICED
#define MR_STATE_IN_SEEN                    DC_STATE_IN_SEEN
#define MR_STATE_OUT_PENDING                DC_STATE_OUT_PENDING
#define MR_STATE_OUT_ERROR                  DC_STATE_OUT_FAILED
#define MR_STATE_OUT_DELIVERED              DC_STATE_OUT_DELIVERED
#define MR_STATE_OUT_MDN_RCVD               DC_STATE_OUT_MDN_RCVD
#define mrmsg_new                           dc_msg_new
#define mrmsg_unref                         dc_msg_unref
#define mrmsg_empty                         dc_msg_empty
#define mrmsg_get_id                        dc_msg_get_id
#define mrmsg_get_from_id                   dc_msg_get_from_id
#define mrmsg_get_chat_id                   dc_msg_get_chat_id
#define mrmsg_get_type                      dc_msg_get_type
#define mrmsg_get_state                     dc_msg_get_state
#define mrmsg_get_timestamp                 dc_msg_get_timestamp
#define mrmsg_get_text                      dc_msg_get_text
#define mrmsg_get_file                      dc_msg_get_file
#define mrmsg_get_filename                  dc_msg_get_filename
#define mrmsg_get_filemime                  dc_msg_get_filemime
#define mrmsg_get_filebytes                 dc_msg_get_filebytes
#define mrmsg_get_mediainfo                 dc_msg_get_mediainfo
#define mrmsg_get_width                     dc_msg_get_width
#define mrmsg_get_height                    dc_msg_get_height
#define mrmsg_get_duration                  dc_msg_get_duration
#define mrmsg_get_showpadlock               dc_msg_get_showpadlock
#define mrmsg_get_summary                   dc_msg_get_summary
#define mrmsg_get_summarytext               dc_msg_get_summarytext
#define mrmsg_is_sent                       dc_msg_is_sent
#define mrmsg_is_starred                    dc_msg_is_starred
#define mrmsg_is_forwarded                  dc_msg_is_forwarded
#define mrmsg_is_info                       dc_msg_is_info
#define mrmsg_is_increation                 dc_msg_is_increation
#define mrmsg_is_setupmessage               dc_msg_is_setupmessage
#define mrmsg_get_setupcodebegin            dc_msg_get_setupcodebegin
#define mrmsg_latefiling_mediasize          dc_msg_latefiling_mediasize

// contact function
#define MR_CONTACT_ID_SELF                  DC_CONTACT_ID_SELF
#define MR_CONTACT_ID_DEVICE                DC_CONTACT_ID_DEVICE
#define MR_CONTACT_ID_LAST_SPECIAL          DC_CONTACT_ID_LAST_SPECIAL
#define mrcontact_new                       dc_contact_new
#define mrcontact_empty                     dc_contact_empty
#define mrcontact_unref                     dc_contact_unref
#define mrcontact_get_id                    dc_contact_get_id
#define mrcontact_get_addr                  dc_contact_get_addr
#define mrcontact_get_name                  dc_contact_get_name
#define mrcontact_get_display_name          dc_contact_get_display_name
#define mrcontact_get_name_n_addr           dc_contact_get_name_n_addr
#define mrcontact_get_first_name            dc_contact_get_first_name
#define mrcontact_is_blocked                dc_contact_is_blocked
#define mrcontact_is_verified               dc_contact_is_verified

// lot functions
#define MR_TEXT1_DRAFT                      DC_TEXT1_DRAFT
#define MR_TEXT1_USERNAME                   DC_TEXT1_USERNAME
#define MR_TEXT1_SELF                       DC_TEXT1_SELF
#define mrlot_new                           dc_lot_new
#define mrlot_empty                         dc_lot_empty
#define mrlot_unref                         dc_lot_unref
#define mrlot_get_text1                     dc_lot_get_text1
#define mrlot_get_text2                     dc_lot_get_text2
#define mrlot_get_text1_meaning             dc_lot_get_text1_meaning
#define mrlot_get_state                     dc_lot_get_state
#define mrlot_get_id                        dc_lot_get_id
#define mrlot_get_timestamp                 dc_lot_get_timestamp


// events
#define MR_EVENT_INFO                        DC_EVENT_INFO
#define MR_EVENT_WARNING                     DC_EVENT_WARNING
#define MR_EVENT_ERROR                       DC_EVENT_ERROR
#define MR_EVENT_MSGS_CHANGED                DC_EVENT_MSGS_CHANGED
#define MR_EVENT_INCOMING_MSG                DC_EVENT_INCOMING_MSG
#define MR_EVENT_MSG_DELIVERED               DC_EVENT_MSG_DELIVERED
#define MR_EVENT_MSG_READ                    DC_EVENT_MSG_READ
#define MR_EVENT_CHAT_MODIFIED               DC_EVENT_CHAT_MODIFIED
#define MR_EVENT_CONTACTS_CHANGED            DC_EVENT_CONTACTS_CHANGED
#define MR_EVENT_CONFIGURE_PROGRESS          DC_EVENT_CONFIGURE_PROGRESS
#define MR_EVENT_IMEX_PROGRESS               DC_EVENT_IMEX_PROGRESS
#define MR_EVENT_IMEX_FILE_WRITTEN           DC_EVENT_IMEX_FILE_WRITTEN
#define MR_EVENT_SECUREJOIN_INVITER_PROGRESS DC_EVENT_SECUREJOIN_INVITER_PROGRESS
#define MR_EVENT_SECUREJOIN_JOINER_PROGRESS  DC_EVENT_SECUREJOIN_JOINER_PROGRESS
#define MR_EVENT_IS_OFFLINE                  DC_EVENT_IS_OFFLINE
#define MR_EVENT_GET_STRING                  DC_EVENT_GET_STRING
#define MR_EVENT_GET_QUANTITY_STRING         DC_EVENT_GET_QUANTITY_STRING
#define MR_EVENT_HTTP_GET                    DC_EVENT_HTTP_GET

// errors
#define MR_ERR_SEE_STRING                    DC_ERROR_SEE_STRING
#define MR_ERR_SELF_NOT_IN_GROUP             DC_ERROR_SELF_NOT_IN_GROUP
#define MR_ERR_NONETWORK                     DC_ERROR_NO_NETWORK


#ifdef __cplusplus
}
#endif
#endif // __MRMAILBOX_DEPRECATED_H__

