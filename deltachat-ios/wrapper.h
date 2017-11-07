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
#include "mrmailbox.h"

// typedef uintptr_t (*mrmailboxcb_t) (mrmailbox_t*, int event, uintptr_t data1, uintptr_t data2);


uintptr_t callback_ios(mrmailbox_t* mailbox, int event, uintptr_t data1, uintptr_t data2);

#endif /* wrapper_h */
