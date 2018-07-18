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


#ifndef __DC_SQLITE3_H__
#define __DC_SQLITE3_H__
#ifdef __cplusplus
extern "C" {
#endif


/*** library-private **********************************************************/

#include <sqlite3.h>
#include <libetpan/libetpan.h>
#include <pthread.h>


/**
 * Library-internal.
 */
typedef struct dc_sqlite3_t
{
	/** @privatesection */
	sqlite3*        cobj;               /**< is the database given as dbfile to Open() */
	dc_context_t*   context;            /**< used for logging and to acquire wakelocks, there may be N dc_sqlite3_t objects per context! In practise, we use 2 on backup, 1 otherwise. */

} dc_sqlite3_t;


dc_sqlite3_t* dc_sqlite3_new              (dc_context_t*);
void          dc_sqlite3_unref            (dc_sqlite3_t*);

#define       DC_OPEN_READONLY            0x01
int           dc_sqlite3_open             (dc_sqlite3_t*, const char* dbfile, int flags);

void          dc_sqlite3_close            (dc_sqlite3_t*);
int           dc_sqlite3_is_open          (const dc_sqlite3_t*);

/* handle configurations, private */
int           dc_sqlite3_set_config       (dc_sqlite3_t*, const char* key, const char* value);
int           dc_sqlite3_set_config_int   (dc_sqlite3_t*, const char* key, int32_t value);
char*         dc_sqlite3_get_config       (dc_sqlite3_t*, const char* key, const char* def); /* the returned string must be free()'d, returns NULL on errors */
int32_t       dc_sqlite3_get_config_int   (dc_sqlite3_t*, const char* key, int32_t def);

/* tools, these functions are compatible to the corresponding sqlite3_* functions */
sqlite3_stmt* dc_sqlite3_prepare          (dc_sqlite3_t*, const char* sql); /* the result mus be freed using sqlite3_finalize() */
int           dc_sqlite3_execute          (dc_sqlite3_t*, const char* sql);
int           dc_sqlite3_table_exists     (dc_sqlite3_t*, const char* name);
void          dc_sqlite3_log_error        (dc_sqlite3_t*, const char* msg, ...);
uint32_t      dc_sqlite3_get_rowid        (dc_sqlite3_t*, const char* table, const char* field, const char* value);

void          dc_sqlite3_begin_transaction  (dc_sqlite3_t*);
void          dc_sqlite3_commit             (dc_sqlite3_t*);
void          dc_sqlite3_rollback           (dc_sqlite3_t*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __DC_SQLITE3_H__ */

