#include "wrapper.h"

long callbackSwift(int, long, long, const char*, const char*);


 uintptr_t callback_ios(dc_context_t* mailbox, int event, uintptr_t data1, uintptr_t data2)
{
    return callbackSwift(event, data1, data2, (const char*)data1, (const char*)data2);
}
