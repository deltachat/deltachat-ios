#include <memory.h>
#include "dc_context.h"
#include "dc_key.h"
#include "dc_keyring.h"
#include "dc_tools.h"


dc_keyring_t* dc_keyring_new()
{
	dc_keyring_t* keyring;

	if ((keyring=calloc(1, sizeof(dc_keyring_t)))==NULL) {
		exit(42); /* cannot allocate little memory, unrecoverable error */
	}
	return keyring;
}


void dc_keyring_unref(dc_keyring_t* keyring)
{
	if (keyring == NULL) {
		return;
	}

	for (int i = 0; i < keyring->count; i++) {
		dc_key_unref(keyring->keys[i]);
	}
	free(keyring->keys);
	free(keyring);
}


void dc_keyring_add(dc_keyring_t* keyring, dc_key_t* to_add)
{
	if (keyring==NULL || to_add==NULL) {
		return;
	}

	/* expand array, if needed */
	if (keyring->count == keyring->allocated) {
		int newsize = (keyring->allocated * 2) + 10;
		if ((keyring->keys=realloc(keyring->keys, newsize*sizeof(dc_key_t*)))==NULL) {
			exit(41);
		}
		keyring->allocated = newsize;
	}

	keyring->keys[keyring->count] = dc_key_ref(to_add);
	keyring->count++;
}


int dc_keyring_load_self_private_for_decrypting(dc_keyring_t* keyring, const char* self_addr, dc_sqlite3_t* sql)
{
	if (keyring==NULL || self_addr==NULL || sql==NULL) {
		return 0;
	}

	sqlite3_stmt* stmt = dc_sqlite3_prepare(sql,
		"SELECT private_key FROM keypairs ORDER BY addr=? DESC, is_default DESC;");
	sqlite3_bind_text (stmt, 1, self_addr, -1, SQLITE_STATIC);
	while (sqlite3_step(stmt) == SQLITE_ROW) {
		dc_key_t* key = dc_key_new();
			if (dc_key_set_from_stmt(key, stmt, 0, DC_KEY_PRIVATE)) {
				dc_keyring_add(keyring, key);
			}
		dc_key_unref(key); /* unref in any case, dc_keyring_add() adds its own reference */
	}
	sqlite3_finalize(stmt);

	return 1;
}

