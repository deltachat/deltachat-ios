#include "wrapper.h"

void callbackSwift(int, long, long, const char*, const char*);

uintptr_t callback_ios(dc_context_t* mailbox, int event, uintptr_t data1, uintptr_t data2)
{
    callbackSwift(event, data1, data2, data1? (const char*)data1 : "", data2? (const char*)data2 : "");
    return 0;
}
