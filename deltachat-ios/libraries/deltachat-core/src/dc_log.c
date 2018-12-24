/* Asynchronous "Thread-errors" are reported by the dc_log_error()
function.  These errors must be shown to the user by a bubble or so.

"Normal" errors are usually returned by a special value (null or so) and are
usually not reported using dc_log_error() - its up to the caller to
decide, what should be reported or done.  However, these "Normal" errors
are usually logged by dc_log_warning(). */


#include <stdarg.h>
#include <memory.h>
#include "dc_context.h"


static void log_vprintf(dc_context_t* context, int event, int data1, const char* msg_format, va_list va)
{
	char* msg = NULL;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return;
	}

	if (msg_format)
	{
		#define BUFSIZE 1024
		char tempbuf[BUFSIZE+1];
		vsnprintf(tempbuf, BUFSIZE, msg_format, va);
		msg = dc_strdup(tempbuf);
	}
	else
	{
		msg = dc_mprintf("event #%i", (int)event);
	}

	context->cb(context, event, (uintptr_t)data1, (uintptr_t)msg);
}


void dc_log_info(dc_context_t* context, int data1, const char* msg, ...)
{
	va_list va;
	va_start(va, msg); /* va_start() expects the last non-variable argument as the second parameter */
		log_vprintf(context, DC_EVENT_INFO, data1, msg, va);
	va_end(va);
}

void dc_log_event(dc_context_t* context, int event_code, int data1, const char* msg, ...)
{
	va_list va;
	va_start(va, msg); /* va_start() expects the last non-variable argument as the second parameter */
		log_vprintf(context, event_code, data1, msg, va);
	va_end(va);
}


void dc_log_event_seq(dc_context_t* context, int event_code, int* sequence_start, const char* msg, ...)
{
	// logs an event and add a sequence-start-indicator to data1;
	// once logged, the sequence-start-indicator is set to 0 so that subseqent events are marked as such.
	// the indicator is useful for the ui eg. to not raise every connection-retry arror to the user.
	if (context==NULL || sequence_start==NULL || context->magic!=DC_CONTEXT_MAGIC) {
		return;
	}

	va_list va;
	va_start(va, msg);
		log_vprintf(context, event_code, *sequence_start, msg, va);
		*sequence_start = 0;
	va_end(va);
}


void dc_log_warning(dc_context_t* context, int data1, const char* msg, ...)
{
	va_list va;
	va_start(va, msg); /* va_start() expects the last non-variable argument as the second parameter */
		log_vprintf(context, DC_EVENT_WARNING, data1, msg, va);
	va_end(va);
}


void dc_log_error(dc_context_t* context, int data1, const char* msg, ...)
{
	va_list va;
	va_start(va, msg);
		log_vprintf(context, DC_EVENT_ERROR, data1, msg, va);
	va_end(va);
}
