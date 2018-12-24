#ifndef __DC_APEERSTATE_H__
#define __DC_APEERSTATE_H__
#ifdef __cplusplus
extern "C" {
#endif


#include "dc_key.h"


typedef struct dc_aheader_t dc_aheader_t;


#define DC_PE_NOPREFERENCE   0 /* prefer-encrypt states */
#define DC_PE_MUTUAL         1
#define DC_PE_RESET         20


/**
 * Library-internal.
 */
typedef struct dc_apeerstate_t
{
	/** @privatesection */
	dc_context_t*  context;

	char*          addr;
	time_t         last_seen;  /* may be 0 if the peer was created by gossipping */

	time_t         last_seen_autocrypt;
	int            prefer_encrypt;

	#define        DC_NOT_VERIFIED      0
	#define        DC_BIDIRECT_VERIFIED 2

	dc_key_t*      public_key; /* may be NULL, however, in the database, either public_key or gossip_key is set */
	char*          public_key_fingerprint;

	dc_key_t*      gossip_key; /* may be NULL */
	time_t         gossip_timestamp;
	char*          gossip_key_fingerprint;

	dc_key_t*      verified_key; // may be NULL
	char*          verified_key_fingerprint;

	#define        DC_SAVE_TIMESTAMPS 0x01
	#define        DC_SAVE_ALL        0x02
	int            to_save;

	#define        DC_DE_ENCRYPTION_PAUSED   0x01 // recoverable by an incoming encrypted mail
	#define        DC_DE_FINGERPRINT_CHANGED 0x02 // recoverable by a new verify
	int            degrade_event;

} dc_apeerstate_t;


dc_apeerstate_t* dc_apeerstate_new                  (dc_context_t*); /* the returned pointer is ref'd and must be unref'd after usage */
void             dc_apeerstate_unref                (dc_apeerstate_t*);

int              dc_apeerstate_init_from_header     (dc_apeerstate_t*, const dc_aheader_t*, time_t message_time);
int              dc_apeerstate_init_from_gossip     (dc_apeerstate_t*, const dc_aheader_t*, time_t message_time);

int              dc_apeerstate_degrade_encryption   (dc_apeerstate_t*, time_t message_time);

void             dc_apeerstate_apply_header         (dc_apeerstate_t*, const dc_aheader_t*, time_t message_time);
void             dc_apeerstate_apply_gossip         (dc_apeerstate_t*, const dc_aheader_t*, time_t message_time);

char*            dc_apeerstate_render_gossip_header (const dc_apeerstate_t*, int min_verified);

dc_key_t*        dc_apeerstate_peek_key             (const dc_apeerstate_t*, int min_verified);

int              dc_apeerstate_recalc_fingerprint   (dc_apeerstate_t*);

#define          DC_PS_GOSSIP_KEY 0
#define          DC_PS_PUBLIC_KEY 1
int              dc_apeerstate_set_verified         (dc_apeerstate_t*, int which_key, const char* fingerprint, int verified);

int              dc_apeerstate_load_by_addr         (dc_apeerstate_t*, dc_sqlite3_t*, const char* addr);
int              dc_apeerstate_load_by_fingerprint  (dc_apeerstate_t*, dc_sqlite3_t*, const char* fingerprint);
int              dc_apeerstate_save_to_db           (const dc_apeerstate_t*, dc_sqlite3_t*, int create);

int              dc_apeerstate_has_verified_key     (const dc_apeerstate_t*, const dc_hash_t* fingerprints);

#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_APEERSTATE_H__ */

