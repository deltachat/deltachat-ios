/*******************************************************************************
 *
 *                              Delta Chat Core
 *                      Copyright (C) 2017 Björn Petersen
 *                   Contact: r10s@b44t.com, http://b44t.com
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see http://www.gnu.org/licenses/ .
 *
 ******************************************************************************/


#include <openssl/ssl.h>
#include <openssl/rand.h>
#include <openssl/rsa.h>
#include <openssl/evp.h>
#include "dc_context.h"


static pthread_mutex_t  s_init_lock         = PTHREAD_MUTEX_INITIALIZER;
static int              s_init_not_required = 0;
static int              s_init_counter      = 0;
static pthread_mutex_t* s_mutex_buf         = NULL;


/**
 * Skip OpenSSL initialisation.
 * By default, the OpenSSL library is initialized thread-safe when calling
 * dc_context_new() the first time.  When the last context-object is deleted
 * using dc_context_unref(), the OpenSSL library will be released as well.
 *
 * If your app needs OpenSSL on its own _outside_ these calls, you have to initialize the
 * OpenSSL-library yourself and skip the initialisation in deltachat-core by calling
 * dc_openssl_init_not_required() _before_ calling dc_context_new() the first time.
 *
 * Multiple calls to dc_openssl_init_not_required() are not needed, however,
 * they do not harm.
 *
 * @memberof dc_context_t
 * @return None.
 */
void dc_openssl_init_not_required(void)
{
	pthread_mutex_lock(&s_init_lock);

		s_init_not_required = 1;

	pthread_mutex_unlock(&s_init_lock);
}


static unsigned long id_function(void)
{
	return ((unsigned long)pthread_self());
}


static void locking_function(int mode, int n, const char* file, int line)
{
	if (mode & CRYPTO_LOCK) {
		pthread_mutex_lock(&s_mutex_buf[n]);
	}
	else {
		pthread_mutex_unlock(&s_mutex_buf[n]);
	}
}


struct CRYPTO_dynlock_value
{
	pthread_mutex_t mutex;
};


static struct CRYPTO_dynlock_value* dyn_create_function(const char* file, int line)
{
	struct CRYPTO_dynlock_value* value = (struct CRYPTO_dynlock_value*)malloc(sizeof(struct CRYPTO_dynlock_value));
	if (NULL==value) {
		return NULL;
	}
	pthread_mutex_init(&value->mutex, NULL);
	return value;
}


static void dyn_lock_function(int mode, struct CRYPTO_dynlock_value* l, const char* file, int line)
{
	if (mode & CRYPTO_LOCK) {
		pthread_mutex_lock(&l->mutex);
	}
	else {
		pthread_mutex_unlock(&l->mutex);
	}
}


static void dyn_destroy_function(struct CRYPTO_dynlock_value* l, const char* file, int line)
{
	pthread_mutex_destroy(&l->mutex);
	free(l);
}


void dc_openssl_init(void)
{
	pthread_mutex_lock(&s_init_lock);

		s_init_counter++;
		if (s_init_counter==1)
		{
			if (!s_init_not_required) {
				s_mutex_buf = (pthread_mutex_t*)malloc(CRYPTO_num_locks() * sizeof(*s_mutex_buf));
				if (s_mutex_buf==NULL) {
					exit(53);
				}

				for (int i=0 ; i<CRYPTO_num_locks(); i++) {
					pthread_mutex_init(&s_mutex_buf[i], NULL);
				}
				CRYPTO_set_id_callback(id_function);
				CRYPTO_set_locking_callback(locking_function);
				CRYPTO_set_dynlock_create_callback(dyn_create_function);
				CRYPTO_set_dynlock_lock_callback(dyn_lock_function);
				CRYPTO_set_dynlock_destroy_callback(dyn_destroy_function);

				// see https://wiki.openssl.org/index.php/Library_Initialization
				#ifdef __APPLE__
					OPENSSL_init();
				#else
					SSL_load_error_strings();
					#if OPENSSL_VERSION_NUMBER < 0x10100000L
					SSL_library_init();
					#else
					OPENSSL_init_ssl(0, NULL);
					#endif
				#endif
				OpenSSL_add_all_algorithms();
			}
			mailstream_openssl_init_not_required();
		}

	pthread_mutex_unlock(&s_init_lock);
}


void dc_openssl_exit(void)
{
	pthread_mutex_lock(&s_init_lock);

		if (s_init_counter>0)
		{
			s_init_counter--;
			if (s_init_counter==0 && !s_init_not_required)
			{
				CRYPTO_set_id_callback(NULL);
				CRYPTO_set_locking_callback(NULL);
				CRYPTO_set_dynlock_create_callback(NULL);
				CRYPTO_set_dynlock_lock_callback(NULL);
				CRYPTO_set_dynlock_destroy_callback(NULL);
				for (int i=0 ; i<CRYPTO_num_locks(); i++) {
					pthread_mutex_destroy(&s_mutex_buf[i]);
				}
				free(s_mutex_buf);
				s_mutex_buf = NULL;
			}
		}

	pthread_mutex_unlock(&s_init_lock);
}
