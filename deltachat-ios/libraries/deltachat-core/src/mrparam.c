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



#include <stdlib.h>
#include <string.h>
#include "mrmailbox_internal.h"
#include "mrtools.h"


/*******************************************************************************
 * Tools
 ******************************************************************************/


static char* find_param(char* ths, int key, char** ret_p2)
{
	char *p1, *p2;

	/* let p1 point to the start of the */
	p1 = ths;
	while( 1 ) {
		if( p1 == NULL || *p1 == 0 ) {
			return NULL;
		}
		else if( *p1 == key && p1[1] == '=' ) {
			break;
		}
		else {
			p1 = strchr(p1, '\n'); /* if `\r\n` is used, this `\r` is also skipped by this*/
			if( p1 ) {
				p1++;
			}
		}
	}

	/* let p2 point to the character _after_ the value - eiter `\n` or `\0` */
	p2 = strchr(p1, '\n');
	if( p2 == NULL ) {
		p2 = &p1[strlen(p1)];
	}

	*ret_p2 = p2;
	return p1;
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


/**
 * @memberof mrparam_t
 */
mrparam_t* mrparam_new()
{
	mrparam_t* param;

	if( (param=calloc(1, sizeof(mrparam_t)))==NULL ) {
		exit(28); /* cannot allocate little memory, unrecoverable error */
	}

	param->m_packed = calloc(1, 1);

    return param;
}


/**
 * @memberof mrparam_t
 */
void mrparam_unref(mrparam_t* param)
{
	if( param==NULL ) {
		return;
	}

	mrparam_empty(param);
	free(param->m_packed);
	free(param);
}


/**
 * @memberof mrparam_t
 */
void mrparam_empty(mrparam_t* param)
{
	if( param == NULL ) {
		return;
	}

	param->m_packed[0] = 0;
}


/**
 * @memberof mrparam_t
 */
void mrparam_set_packed(mrparam_t* param, const char* packed)
{
	if( param == NULL ) {
		return;
	}

	mrparam_empty(param);

	if( packed ) {
		free(param->m_packed);
		param->m_packed = safe_strdup(packed);
	}
}


/**
 * @memberof mrparam_t
 */
int mrparam_exists(mrparam_t* param, int key)
{
	char *p2;

	if( param == NULL || key == 0 ) {
		return 0;
	}

	return find_param(param->m_packed, key, &p2)? 1 : 0;
}


/**
 * @memberof mrparam_t
 */
char* mrparam_get(mrparam_t* param, int key, const char* def)
{
	char *p1, *p2, bak, *ret;

	if( param == NULL || key == 0 ) {
		return def? safe_strdup(def) : NULL;
	}

	p1 = find_param(param->m_packed, key, &p2);
	if( p1 == NULL ) {
		return def? safe_strdup(def) : NULL;
	}

	p1 += 2; /* skip key and "=" (safe as find_param checks for its existance) */

	bak = *p2;
	*p2 = 0;
	ret = safe_strdup(p1);
	mr_rtrim(ret); /* to be safe with '\r' characters ... */
	*p2 = bak;
	return ret;
}


/**
 * @memberof mrparam_t
 */
int32_t mrparam_get_int(mrparam_t* param, int key, int32_t def)
{
	if( param == NULL || key == 0 ) {
		return def;
	}

    char* str = mrparam_get(param, key, NULL);
    if( str == NULL ) {
		return def;
    }
    int32_t ret = atol(str);
    free(str);
    return ret;
}


/**
 * @memberof mrparam_t
 *
 */
void mrparam_set(mrparam_t* param, int key, const char* value)
{
	char *old1, *old2, *new1 = NULL;

	if( param == NULL || key == 0 ) {
		return;
	}

	old1 = param->m_packed;
	old2 = NULL;

	/* remove existing parameter from packed string, if any */
	if( old1 ) {
		char *p1, *p2;
		p1 = find_param(old1, key, &p2);
		if( p1 != NULL ) {
			*p1 = 0;
			old2 = p2;
		}
		else if( value==NULL ) {
			return; /* parameter does not exist and should be cleared -> done. */
		}
	}

	mr_rtrim(old1); /* trim functions are null-pointer-safe */
	mr_ltrim(old2);

	if( old1 && old1[0]==0 ) { old1 = NULL; }
	if( old2 && old2[0]==0 ) { old2 = NULL; }

	/* create new string */
	if( value ) {
		new1 = mr_mprintf("%s%s%c=%s%s%s",
			old1?  old1 : "",
			old1?  "\n" : "",
			key,
			value,
			old2?  "\n" : "",
			old2?  old2 : "");
	}
	else {
		new1 = mr_mprintf("%s%s%s",
			old1?         old1 : "",
			(old1&&old2)? "\n" : "",
			old2?         old2 : "");
	}

	free(param->m_packed);
	param->m_packed = new1;
}


/**
 * @memberof mrparam_t
 */
void mrparam_set_int(mrparam_t* param, int key, int32_t value)
{
	if( param == NULL || key == 0 ) {
		return;
	}

    char* value_str = mr_mprintf("%i", (int)value);
    if( value_str == NULL ) {
		return;
    }
    mrparam_set(param, key, value_str);
    free(value_str);
}
