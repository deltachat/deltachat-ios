//
//  wrapper.h
//  deltachat-ios
//
//  Created by Jonas Reinsch on 07.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

#ifndef wrapper_h
#define wrapper_h

#include <stdio.h>
#include "deltachat.h"

// typedef uintptr_t (*mrmailboxcb_t) (mrmailbox_t*, int event, uintptr_t data1, uintptr_t data2);

// redeclare, so swift understands they are opaque types
typedef dc_context_t dc_context_t;
typedef dc_contact_t dc_contact_t;
typedef dc_chat_t dc_chat_t;
typedef dc_msg_t dc_msg_t;
typedef dc_lot_t dc_lot_t;
typedef dc_array_t dc_array_t;
typedef dc_chatlist_t dc_chatlist_t;

uintptr_t callback_ios(dc_context_t* mailbox, int event, uintptr_t data1, uintptr_t data2);

#endif /* wrapper_h */
