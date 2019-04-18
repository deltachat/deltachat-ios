/* librpgp Header Version 0.1.0 */

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * A PGP message
 * https://tools.ietf.org/html/rfc4880.html#section-11.3
 */
typedef struct rpgp_Message rpgp_Message;

typedef struct rpgp_PublicOrSecret rpgp_PublicOrSecret;

/**
 * Represents a Public PGP key, which is signed and either received or ready to be transferred.
 */
typedef struct rpgp_SignedPublicKey rpgp_SignedPublicKey;

/**
 * Represents a secret signed PGP key.
 */
typedef struct rpgp_SignedSecretKey rpgp_SignedSecretKey;

typedef rpgp_SignedSecretKey rpgp_signed_secret_key;

/**
 * Represents a vector, that can be passed to C land.
 * Has to be deallocated using [rpgp_cvec_drop], otherwise leaks memory.
 */
typedef struct {
  uint8_t *data;
  size_t len;
} rpgp_cvec;

typedef rpgp_Message rpgp_message;

typedef rpgp_SignedPublicKey rpgp_signed_public_key;

typedef rpgp_PublicOrSecret rpgp_public_or_secret_key;

/**
 * Message decryption result.
 */
typedef struct {
  /**
   * A pointer to the decrypted message.
   */
  rpgp_message *message_ptr;
  /**
   * Pointer to a list of fingerprints which verified the signature.
   */
  char **valid_ids_ptr;
  size_t valid_ids_len;
} rpgp_message_decrypt_result;

/**
 * Generates a new RSA key.
 */
rpgp_signed_secret_key *rpgp_create_rsa_skey(uint32_t bits, const char *user_id);

/**
 * Generates a new x25519 key.
 */
rpgp_signed_secret_key *rpgp_create_x25519_skey(const char *user_id);

/**
 * Get a pointer to the data of the given [cvec].
 */
const uint8_t *rpgp_cvec_data(rpgp_cvec *cvec_ptr);

/**
 * Free the given [cvec].
 */
void rpgp_cvec_drop(rpgp_cvec *cvec_ptr);

/**
 * Get the length of the data of the given [cvec].
 */
size_t rpgp_cvec_len(rpgp_cvec *cvec_ptr);

rpgp_message *rpgp_encrypt_bytes_to_keys(const uint8_t *bytes_ptr,
                                         size_t bytes_len,
                                         const rpgp_signed_public_key *const *pkeys_ptr,
                                         size_t pkeys_len);

rpgp_message *rpgp_encrypt_bytes_with_password(const uint8_t *bytes_ptr,
                                               size_t bytes_len,
                                               const char *password_ptr);

/**
 * Calculate the SHA256 hash of the given bytes.
 */
rpgp_cvec *rpgp_hash_sha256(const uint8_t *bytes_ptr, size_t bytes_len);

/**
 * Frees the memory of the passed in key, making the pointer invalid after this method was called.
 */
void rpgp_key_drop(rpgp_public_or_secret_key *key_ptr);

/**
 * Returns the Fingerprint for the passed in key. The caller is responsible to call [rpgp_cvec_drop] with the returned memory, to free it.
 */
rpgp_cvec *rpgp_key_fingerprint(rpgp_public_or_secret_key *key_ptr);

/**
 * Creates an in-memory representation of a PGP key, based on the armor file given.
 * The returned pointer should be stored, and reused when calling methods "on" this key.
 * When done with it [rpgp_key_drop] should be called, to free the memory.
 */
rpgp_public_or_secret_key *rpgp_key_from_armor(const uint8_t *raw, size_t len);

/**
 * Creates an in-memory representation of a PGP key, based on the serialized bytes given.
 */
rpgp_public_or_secret_key *rpgp_key_from_bytes(const uint8_t *raw, size_t len);

/**
 * Returns the KeyID for the passed in key. The caller is responsible to call [rpgp_string_drop] with the returned memory, to free it.
 */
char *rpgp_key_id(rpgp_public_or_secret_key *key_ptr);

/**
 * Returns `true` if this key is a public key, false otherwise.
 */
bool rpgp_key_is_public(rpgp_public_or_secret_key *key_ptr);

/**
 * Returns `true` if this key is a secret key, false otherwise.
 */
bool rpgp_key_is_secret(rpgp_public_or_secret_key *key_ptr);

/**
 * Calculate the number of bytes in the last error's error message **not**
 * including any trailing `null` characters.
 */
int rpgp_last_error_length(void);

/**
 * Write the most recent error message into a caller-provided buffer as a UTF-8
 * string, returning the number of bytes written.
 * # Note
 * This writes a **UTF-8** string into the buffer. Windows users may need to
 * convert it to a UTF-16 "unicode" afterwards.
 * If there are no recent errors then this returns `0` (because we wrote 0
 * bytes). `-1` is returned if there are any errors, for example when passed a
 * null pointer or a buffer of insufficient size.
 */
char *rpgp_last_error_message(void);

/**
 * Free a [message_decrypt_result].
 */
void rpgp_message_decrypt_result_drop(rpgp_message_decrypt_result *res_ptr);

/**
 * Decrypt the passed in message, without attempting to use a password.
 */
rpgp_message_decrypt_result *rpgp_msg_decrypt_no_pw(const rpgp_message *msg_ptr,
                                                    const rpgp_signed_secret_key *const *skeys_ptr,
                                                    size_t skeys_len,
                                                    const rpgp_signed_public_key *const *pkeys_ptr,
                                                    size_t pkeys_len);

/**
 * Decrypt the passed in message, using a password.
 */
rpgp_message *rpgp_msg_decrypt_with_password(const rpgp_message *msg_ptr, const char *password_ptr);

/**
 * Free a [message], that was created by rpgp.
 */
void rpgp_msg_drop(rpgp_message *msg_ptr);

/**
 * Parse an armored message.
 */
rpgp_message *rpgp_msg_from_armor(const uint8_t *msg_ptr, size_t msg_len);

/**
 * Parse a message in bytes format.
 */
rpgp_message *rpgp_msg_from_bytes(const uint8_t *msg_ptr, size_t msg_len);

/**
 * Get the fingerprint of a given encrypted message, by index, in hexformat.
 */
char *rpgp_msg_recipients_get(rpgp_message *msg_ptr, uint32_t i);

/**
 * Get the number of fingerprints of a given encrypted message.
 */
uint32_t rpgp_msg_recipients_len(rpgp_message *msg_ptr);

/**
 * Encodes the message into its ascii armored representation.
 */
rpgp_cvec *rpgp_msg_to_armored(const rpgp_message *msg_ptr);

/**
 * Encodes the message into its ascii armored representation, returning a string.
 */
char *rpgp_msg_to_armored_str(const rpgp_message *msg_ptr);

/**
 * Returns the underlying data of the given message.
 * Fails when the message is encrypted. Decompresses compressed messages.
 */
rpgp_cvec *rpgp_msg_to_bytes(const rpgp_message *msg_ptr);

/**
 * Free the given [signed_public_key].
 */
void rpgp_pkey_drop(rpgp_signed_public_key *pkey_ptr);

/**
 * Parse a serialized public key, into the native rPGP memory representation.
 */
rpgp_signed_public_key *rpgp_pkey_from_bytes(const uint8_t *raw, size_t len);

/**
 * Get the key id of the given [signed_public_key].
 */
char *rpgp_pkey_key_id(rpgp_signed_public_key *pkey_ptr);

/**
 * Serialize the [signed_public_key] to bytes.
 */
rpgp_cvec *rpgp_pkey_to_bytes(rpgp_signed_public_key *pkey_ptr);

rpgp_message *rpgp_sign_encrypt_bytes_to_keys(const uint8_t *bytes_ptr,
                                              size_t bytes_len,
                                              const rpgp_signed_public_key *const *pkeys_ptr,
                                              size_t pkeys_len,
                                              const rpgp_signed_secret_key *skey_ptr);

/**
 * Free the memory of a secret key.
 */
void rpgp_skey_drop(rpgp_signed_secret_key *skey_ptr);

/**
 * Creates an in-memory representation of a Secret PGP key, based on the serialized bytes given.
 */
rpgp_signed_secret_key *rpgp_skey_from_bytes(const uint8_t *raw, size_t len);

/**
 * Returns the KeyID for the passed in key.
 */
char *rpgp_skey_key_id(rpgp_signed_secret_key *skey_ptr);

/**
 * Get the signed public key matching the given private key. Only works for non password protected keys.
 */
rpgp_signed_public_key *rpgp_skey_public_key(rpgp_signed_secret_key *skey_ptr);

/**
 * Serialize a secret key into its byte representation.
 */
rpgp_cvec *rpgp_skey_to_bytes(rpgp_signed_secret_key *skey_ptr);

/**
 * Free string, that was created by rpgp.
 */
void rpgp_string_drop(char *p);
