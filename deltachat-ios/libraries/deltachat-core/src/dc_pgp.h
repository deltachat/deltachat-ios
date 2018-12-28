#ifndef __DC_PGP_H__
#define __DC_PGP_H__
#ifdef __cplusplus
extern "C" {
#endif


/*** library-private **********************************************************/

typedef struct dc_key_t dc_key_t;
typedef struct dc_keyring_t dc_keyring_t;


/* validation errors */
#define DC_E2EE_NO_VALID_SIGNATURE 0x02

/* misc. */
void dc_pgp_init             (void);
void dc_pgp_exit             (void);
void dc_pgp_rand_seed        (dc_context_t*, const void* buf, size_t bytes);
int  dc_split_armored_data  (char* buf, const char** ret_headerline, const char** ret_setupcodebegin, const char** ret_preferencrypt, const char** ret_base64);

/* public key encryption */
#define DC_KEYGEN_BITS  3072
#define DC_KEYGEN_E    65537
int  dc_pgp_create_keypair   (dc_context_t*, const char* addr, dc_key_t* public_key, dc_key_t* private_key);

int  dc_pgp_is_valid_key     (dc_context_t*, const dc_key_t*);
int  dc_pgp_calc_fingerprint (const dc_key_t*, uint8_t** fingerprint, size_t* fingerprint_bytes);
int  dc_pgp_split_key        (dc_context_t*, const dc_key_t* private_in, dc_key_t* public_out);

int  dc_pgp_pk_encrypt       (dc_context_t*, const void* plain, size_t plain_bytes, const dc_keyring_t*, const dc_key_t* sign_key, int use_armor, void** ret_ctext, size_t* ret_ctext_bytes);
int  dc_pgp_pk_decrypt       (dc_context_t*, const void* ctext, size_t ctext_bytes, const dc_keyring_t*, const dc_keyring_t* validate_keys, int use_armor, void** plain, size_t* plain_bytes, dc_hash_t* ret_signature_fingerprints);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif // __DC_PGP_H__
