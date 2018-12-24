#ifndef __DC_SMTP_H__
#define __DC_SMTP_H__
#ifdef __cplusplus
extern "C" {
#endif


#include "dc_loginparam.h"


/*** library-private **********************************************************/

typedef struct dc_smtp_t
{
	mailsmtp*       etpan;
	char*           from;
	int             esmtp;

	int             log_connect_errors;

	dc_context_t*   context; /* only for logging! */

	char*           error;
	int             error_etpan; // one of the MAILSMTP_ERROR_* codes, eg. MAILSMTP_ERROR_EXCEED_STORAGE_ALLOCATION
} dc_smtp_t;

dc_smtp_t*   dc_smtp_new          (dc_context_t*);
void         dc_smtp_unref        (dc_smtp_t*);
int          dc_smtp_is_connected (const dc_smtp_t*);
int          dc_smtp_connect      (dc_smtp_t*, const dc_loginparam_t*);
void         dc_smtp_disconnect   (dc_smtp_t*);
int          dc_smtp_send_msg     (dc_smtp_t*, const clist* recipients, const char* data, size_t data_bytes);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_SMTP_H__ */

