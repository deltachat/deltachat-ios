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
#include "dc_context.h"
#include "dc_tools.h"


static char* find_param(char* haystack, int key, char** ret_p2)
{
	char* p1 = NULL;
	char* p2 = NULL;

	/* let p1 point to the start of the */
	p1 = haystack;
	while (1) {
		if (p1==NULL || *p1==0) {
			return NULL;
		}
		else if (*p1==key && p1[1]=='=') {
			break;
		}
		else {
			p1 = strchr(p1, '\n'); /* if `\r\n` is used, this `\r` is also skipped by this*/
			if (p1) {
				p1++;
			}
		}
	}

	/* let p2 point to the character _after_ the value - eiter `\n` or `\0` */
	p2 = strchr(p1, '\n');
	if (p2==NULL) {
		p2 = &p1[strlen(p1)];
	}

	*ret_p2 = p2;
	return p1;
}


/**
 * Create new parameter list object.
 *
 * @private @memberof dc_param_t
 * @return The created parameter list object.
 */
dc_param_t* dc_param_new()
{
	dc_param_t* param = NULL;

	if ((param=calloc(1, sizeof(dc_param_t)))==NULL) {
		exit(28); /* cannot allocate little memory, unrecoverable error */
	}

	param->packed = calloc(1, 1);

    return param;
}


/**
 * Free an parameter list object created eg. by dc_param_new().
 *
 * @private @memberof dc_param_t
 * @param param The parameter list object to free.
 */
void dc_param_unref(dc_param_t* param)
{
	if (param==NULL) {
		return;
	}

	dc_param_empty(param);
	free(param->packed);
	free(param);
}


/**
 * Delete all parameters in the object.
 *
 * @memberof dc_param_t
 * @param param Parameter object to modify.
 * @return None.
 */
void dc_param_empty(dc_param_t* param)
{
	if (param==NULL) {
		return;
	}

	param->packed[0] = 0;
}


/**
 * Store a parameter set.  The parameter set must be given in a packed form as
 * `a=value1\nb=value2`. The format should be very strict, additional spaces are not allowed.
 *
 * Before the new packed parameters are stored, _all_ existant parameters are deleted.
 *
 * @private @memberof dc_param_t
 * @param param Parameter object to modify.
 * @param packed Parameters to set, see comment above.
 * @return None.
 */
void dc_param_set_packed(dc_param_t* param, const char* packed)
{
	if (param==NULL) {
		return;
	}

	dc_param_empty(param);

	if (packed) {
		free(param->packed);
		param->packed = dc_strdup(packed);
	}
}


/**
 * Same as dc_param_set_packed() but uses '&' as a separator (instead '\n').
 * Urldecoding itself is not done by this function, this is up to the caller.
 */
void dc_param_set_urlencoded(dc_param_t* param, const char* urlencoded)
{
	if (param==NULL) {
		return;
	}

	dc_param_empty(param);

	if (urlencoded) {
		free(param->packed);
		param->packed = dc_strdup(urlencoded);
		dc_str_replace(&param->packed, "&", "\n");
	}
}


/**
 * Check if a parameter exists.
 *
 * @memberof dc_param_t
 * @param param Parameter object to query.
 * @param key Key of the parameter to check the existance, one of the DC_PARAM_* constants.
 * @return 1=parameter exists in object, 0=parameter does not exist in parameter object.
 */
int dc_param_exists(dc_param_t* param, int key)
{
	char *p2 = NULL;

	if (param==NULL || key==0) {
		return 0;
	}

	return find_param(param->packed, key, &p2)? 1 : 0;
}


/**
 * Get value of a parameter.
 *
 * @memberof dc_param_t
 * @param param Parameter object to query.
 * @param key Key of the parameter to get, one of the DC_PARAM_* constants.
 * @param def Value to return if the parameter is not set.
 * @return The stored value or the default value.  In both cases, the returned value must be free()'d.
 */
char* dc_param_get(const dc_param_t* param, int key, const char* def)
{
	char* p1 = NULL;
	char* p2 = NULL;
	char  bak = 0;
	char* ret = NULL;

	if (param==NULL || key==0) {
		return def? dc_strdup(def) : NULL;
	}

	p1 = find_param(param->packed, key, &p2);
	if (p1==NULL) {
		return def? dc_strdup(def) : NULL;
	}

	p1 += 2; /* skip key and "=" (safe as find_param checks for its existance) */

	bak = *p2;
	*p2 = 0;
	ret = dc_strdup(p1);
	dc_rtrim(ret); /* to be safe with '\r' characters ... */
	*p2 = bak;
	return ret;
}


/**
 * Get value of a parameter.
 *
 * @memberof dc_param_t
 * @param param Parameter object to query.
 * @param key Key of the parameter to get, one of the DC_PARAM_* constants.
 * @param def Value to return if the parameter is not set.
 * @return The stored value or the default value.
 */
int32_t dc_param_get_int(const dc_param_t* param, int key, int32_t def)
{
	if (param==NULL || key==0) {
		return def;
	}

    char* str = dc_param_get(param, key, NULL);
    if (str==NULL) {
		return def;
    }
    int32_t ret = atol(str);
    free(str);
    return ret;
}


/**
 * Set parameter to a string.
 *
 * @memberof dc_param_t
 * @param param Parameter object to modify.
 * @param key Key of the parameter to modify, one of the DC_PARAM_* constants.
 * @param value Value to store for key. NULL to clear the value.
 * @return None.
 */
void dc_param_set(dc_param_t* param, int key, const char* value)
{
	char* old1 = NULL;
	char* old2 = NULL;
	char* new1 = NULL;

	if (param==NULL || key==0) {
		return;
	}

	old1 = param->packed;
	old2 = NULL;

	/* remove existing parameter from packed string, if any */
	if (old1) {
		char *p1, *p2;
		p1 = find_param(old1, key, &p2);
		if (p1 != NULL) {
			*p1 = 0;
			old2 = p2;
		}
		else if (value==NULL) {
			return; /* parameter does not exist and should be cleared -> done. */
		}
	}

	dc_rtrim(old1); /* trim functions are null-pointer-safe */
	dc_ltrim(old2);

	if (old1 && old1[0]==0) { old1 = NULL; }
	if (old2 && old2[0]==0) { old2 = NULL; }

	/* create new string */
	if (value) {
		new1 = dc_mprintf("%s%s%c=%s%s%s",
			old1?  old1 : "",
			old1?  "\n" : "",
			key,
			value,
			old2?  "\n" : "",
			old2?  old2 : "");
	}
	else {
		new1 = dc_mprintf("%s%s%s",
			old1?         old1 : "",
			(old1&&old2)? "\n" : "",
			old2?         old2 : "");
	}

	free(param->packed);
	param->packed = new1;
}


/**
 * Set parameter to an integer.
 *
 * @memberof dc_param_t
 * @param param Parameter object to modify.
 * @param key Key of the parameter to modify, one of the DC_PARAM_* constants.
 * @param value Value to store for key.
 * @return None.
 */
void dc_param_set_int(dc_param_t* param, int key, int32_t value)
{
	if (param==NULL || key==0) {
		return;
	}

    char* value_str = dc_mprintf("%i", (int)value);
    if (value_str==NULL) {
		return;
    }
    dc_param_set(param, key, value_str);
    free(value_str);
}
