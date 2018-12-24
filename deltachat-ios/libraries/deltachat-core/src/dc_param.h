#ifndef __DC_PARAM_H__
#define __DC_PARAM_H__
#ifdef __cplusplus
extern "C" {
#endif


/**
 * An object for handling key=value parameter lists; for the key, curently only
 * a single character is allowed.
 *
 * The object is used eg. by dc_chat_t or dc_msg_t, for readable paramter names,
 * these classes define some DC_PARAM_* constantats.
 *
 * Only for library-internal use.
 */
typedef struct dc_param_t
{
	/** @privatesection */
	char*           packed;    /**< Always set, never NULL. */
} dc_param_t;


#define DC_PARAM_FILE              'f'  /* for msgs */
#define DC_PARAM_WIDTH             'w'  /* for msgs */
#define DC_PARAM_HEIGHT            'h'  /* for msgs */
#define DC_PARAM_DURATION          'd'  /* for msgs */
#define DC_PARAM_MIMETYPE          'm'  /* for msgs */
#define DC_PARAM_GUARANTEE_E2EE    'c'  /* for msgs: incoming: message is encryoted, outgoing: guarantee E2EE or the message is not send */
#define DC_PARAM_ERRONEOUS_E2EE    'e'  /* for msgs: decrypted with validation errors or without mutual set, if neither 'c' nor 'e' are preset, the messages is only transport encrypted */
#define DC_PARAM_FORCE_PLAINTEXT   'u'  /* for msgs: force unencrypted message, either DC_FP_ADD_AUTOCRYPT_HEADER (1), DC_FP_NO_AUTOCRYPT_HEADER (2) or 0 */
#define DC_PARAM_WANTS_MDN         'r'  /* for msgs: an incoming message which requestes a MDN (aka read receipt) */
#define DC_PARAM_FORWARDED         'a'  /* for msgs */
#define DC_PARAM_CMD               'S'  /* for msgs */
#define DC_PARAM_CMD_ARG           'E'  /* for msgs */
#define DC_PARAM_CMD_ARG2          'F'  /* for msgs */
#define DC_PARAM_CMD_ARG3          'G'  /* for msgs */
#define DC_PARAM_CMD_ARG4          'H'  /* for msgs */
#define DC_PARAM_ERROR             'L'  /* for msgs */

#define DC_PARAM_SERVER_FOLDER     'Z'  /* for jobs */
#define DC_PARAM_SERVER_UID        'z'  /* for jobs */
#define DC_PARAM_ALSO_MOVE         'M'  /* for jobs */

#define DC_PARAM_UNPROMOTED        'U'  /* for groups */
#define DC_PARAM_PROFILE_IMAGE     'i'  /* for groups and contacts */
#define DC_PARAM_SELFTALK          'K'  /* for chats */


// values for DC_PARAM_FORCE_PLAINTEXT
#define DC_FP_ADD_AUTOCRYPT_HEADER 1
#define DC_FP_NO_AUTOCRYPT_HEADER  2


/* user functions */
int             dc_param_exists         (dc_param_t*, int key);
char*           dc_param_get            (const dc_param_t*, int key, const char* def); /* the value may be an empty string, "def" is returned only if the value unset.  The result must be free()'d in any case. */
int32_t         dc_param_get_int        (const dc_param_t*, int key, int32_t def);
void            dc_param_set            (dc_param_t*, int key, const char* value);
void            dc_param_set_int        (dc_param_t*, int key, int32_t value);

/* library-private */
dc_param_t*     dc_param_new            ();
void            dc_param_empty          (dc_param_t*);
void            dc_param_unref          (dc_param_t*);
void            dc_param_set_packed     (dc_param_t*, const char*);
void            dc_param_set_urlencoded (dc_param_t*, const char*);


#ifdef __cplusplus
} // /extern "C"
#endif
#endif // __DC_PARAM_H__
