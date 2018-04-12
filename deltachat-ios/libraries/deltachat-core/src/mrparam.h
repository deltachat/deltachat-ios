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


#ifndef __MRPARAM_H__
#define __MRPARAM_H__
#ifdef __cplusplus
extern "C" {
#endif


/**
 * An object for handling key=value parameter lists; for the key, curently only
 * a single character is allowed.
 *
 * The object is used eg. by mrchat_t or mrmsg_t, for readable paramter names,
 * these classes define some MRP_* constantats.
 *
 * Only for library-internal use.
 */
typedef struct mrparam_t
{
	/** @privatesection */
	char*           m_packed;    /**< Always set, never NULL. */
} mrparam_t;


#define MRP_FILE              'f'  /* for msgs */
#define MRP_WIDTH             'w'  /* for msgs */
#define MRP_HEIGHT            'h'  /* for msgs */
#define MRP_DURATION          'd'  /* for msgs */
#define MRP_MIMETYPE          'm'  /* for msgs */
#define MRP_AUTHORNAME        'N'  /* for msgs: name of author or artist */
#define MRP_TRACKNAME         'n'  /* for msgs: name of author or artist */
#define MRP_GUARANTEE_E2EE    'c'  /* for msgs: incoming: message is encryoted, outgoing: guarantee E2EE or the message is not send */
#define MRP_ERRONEOUS_E2EE    'e'  /* for msgs: decrypted with validation errors or without mutual set, if neither 'c' nor 'e' are preset, the messages is only transport encrypted */
#define MRP_FORCE_UNENCRYPTED 'u'  /* for msgs: force unencrypted message, 1=add Autocrypt header, 2=no Autocrypt header */
#define MRP_WANTS_MDN         'r'  /* for msgs: an incoming message which requestes a MDN (aka read receipt) */
#define MRP_FORWARDED         'a'  /* for msgs */
#define MRP_CMD               'S'  /* for msgs */
#define MRP_CMD_PARAM         'E'  /* for msgs */
#define MRP_CMD_PARAM2        'F'  /* for msgs */
#define MRP_CMD_PARAM3        'G'  /* for msgs */

#define MRP_SERVER_FOLDER     'Z'  /* for jobs */
#define MRP_SERVER_UID        'z'  /* for jobs */
#define MRP_TIMES             't'  /* for jobs: times a job was tried */
#define MRP_TIMES_INCREATION  'T'  /* for jobs: times a job was tried, used for increation */

#define MRP_REFERENCES        'R'  /* for groups and chats: References-header last used for a chat */
#define MRP_UNPROMOTED        'U'  /* for groups */
#define MRP_PROFILE_IMAGE     'i'  /* for groups and contacts */
#define MRP_SELFTALK          'K'  /* for chats */


/* user functions */
int             mrparam_exists         (mrparam_t*, int key);
char*           mrparam_get            (mrparam_t*, int key, const char* def); /* the value may be an empty string, "def" is returned only if the value unset.  The result must be free()'d in any case. */
int32_t         mrparam_get_int        (mrparam_t*, int key, int32_t def);
void            mrparam_set            (mrparam_t*, int key, const char* value);
void            mrparam_set_int        (mrparam_t*, int key, int32_t value);

/* library-private */
mrparam_t*      mrparam_new            ();
void            mrparam_empty          (mrparam_t*);
void            mrparam_unref          (mrparam_t*);
void            mrparam_set_packed     (mrparam_t*, const char*);
void            mrparam_set_urlencoded (mrparam_t*, const char*);


#ifdef __cplusplus
} /* /extern "C" */
#endif
#endif /* __MRPARAM_H__ */
