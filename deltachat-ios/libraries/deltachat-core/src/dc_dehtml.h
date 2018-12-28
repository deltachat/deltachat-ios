#ifndef __DC_DEHTML_H__
#define __DC_DEHTML_H__
#ifdef __cplusplus
extern "C" {
#endif


/*** library-internal *********************************************************/

char* dc_dehtml(char* buf_terminated); /* dc_dehtml() returns way too many lineends; however, an optimisation on this issue is not needed as the lineends are typically remove in further processing by the caller */


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_DEHTML_H__ */

