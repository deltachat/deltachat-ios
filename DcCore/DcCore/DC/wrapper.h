#ifndef wrapper_h
#define wrapper_h

#include <stdio.h>
#include "deltachat.h"

// redeclare, so swift understands they are opaque types
typedef dc_context_t dc_context_t;
typedef dc_contact_t dc_contact_t;
typedef dc_chat_t dc_chat_t;
typedef dc_msg_t dc_msg_t;
typedef dc_lot_t dc_lot_t;
typedef dc_array_t dc_array_t;
typedef dc_chatlist_t dc_chatlist_t;

#endif /* wrapper_h */
