#include <stdarg.h>
#include <unistd.h>
#include "dc_context.h"
#include "dc_apeerstate.h"


#define MAILTO_SCHEME      "mailto:"
#define MATMSG_SCHEME      "MATMSG:"
#define VCARD_BEGIN        "BEGIN:VCARD"
#define SMTP_SCHEME        "SMTP:"


/**
 * Check a scanned QR code.
 * The function should be called after a QR code is scanned.
 * The function takes the raw text scanned and checks what can be done with it.
 *
 * The QR code state is returned in dc_lot_t::state as:
 *
 * - DC_QR_ASK_VERIFYCONTACT with dc_lot_t::id=Contact ID
 * - DC_QR_ASK_VERIFYGROUP withdc_lot_t::text1=Group name
 * - DC_QR_FPR_OK with dc_lot_t::id=Contact ID
 * - DC_QR_FPR_MISMATCH with dc_lot_t::id=Contact ID
 * - DC_QR_FPR_WITHOUT_ADDR with dc_lot_t::test1=Formatted fingerprint
 * - DC_QR_ADDR with dc_lot_t::id=Contact ID
 * - DC_QR_TEXT with dc_lot_t::text1=Text
 * - DC_QR_URL with dc_lot_t::text1=URL
 * - DC_QR_ERROR with dc_lot_t::text1=Error string
 *
 *
 * @memberof dc_context_t
 * @param context The context object.
 * @param qr The text of the scanned QR code.
 * @return Parsed QR code as an dc_lot_t object. The returned object must be
 *     freed using dc_lot_unref() after usage.
 */
dc_lot_t* dc_check_qr(dc_context_t* context, const char* qr)
{
	char*            payload = NULL;
	char*            addr = NULL; // must be normalized, if set
	char*            fingerprint = NULL; // must be normalized, if set
	char*            name = NULL;
	char*            invitenumber = NULL;
	char*            auth = NULL;
	dc_apeerstate_t* peerstate = dc_apeerstate_new(context);
	dc_lot_t*        qr_parsed = dc_lot_new();
	uint32_t         chat_id = 0;
	char*            device_msg = NULL;
	char*            grpid = NULL;
	char*            grpname = NULL;

	qr_parsed->state = 0;

	if (context==NULL || context->magic!=DC_CONTEXT_MAGIC || qr==NULL) {
		goto cleanup;
	}

	dc_log_info(context, 0, "Scanned QR code: %s", qr);

	/* split parameters from the qr code
	 ------------------------------------ */

	if (strncasecmp(qr, DC_OPENPGP4FPR_SCHEME, strlen(DC_OPENPGP4FPR_SCHEME))==0)
	{
		/* scheme: OPENPGP4FPR:FINGERPRINT#a=ADDR&n=NAME&i=INVITENUMBER&s=AUTH
		       or: OPENPGP4FPR:FINGERPRINT#a=ADDR&g=GROUPNAME&x=GROUPID&i=INVITENUMBER&s=AUTH */

		payload  = dc_strdup(&qr[strlen(DC_OPENPGP4FPR_SCHEME)]);
		char* fragment = strchr(payload, '#'); /* must not be freed, only a pointer inside payload */
		if (fragment)
		{
			*fragment = 0;
			fragment++;

			dc_param_t* param = dc_param_new();
			dc_param_set_urlencoded(param, fragment);

			addr = dc_param_get(param, 'a', NULL);
			if (addr) {
				char* urlencoded = dc_param_get(param, 'n', NULL);
				if(urlencoded) {
					name = dc_urldecode(urlencoded);
					dc_normalize_name(name);
					free(urlencoded);
				}

				invitenumber  = dc_param_get(param, 'i', NULL);
				auth          = dc_param_get(param, 's', NULL);

				grpid  = dc_param_get(param, 'x', NULL);
				if (grpid) {
					urlencoded = dc_param_get(param, 'g', NULL);
					if (urlencoded) {
						grpname = dc_urldecode(urlencoded);
						free(urlencoded);
					}
				}
			}

			dc_param_unref(param);
		}

		fingerprint = dc_normalize_fingerprint(payload);
	}
	else if (strncasecmp(qr, MAILTO_SCHEME, strlen(MAILTO_SCHEME))==0)
	{
		/* scheme: mailto:addr...?subject=...&body=... */
		payload = dc_strdup(&qr[strlen(MAILTO_SCHEME)]);
		char* query = strchr(payload, '?'); /* must not be freed, only a pointer inside payload */
		if (query) {
			*query = 0;
		}
		addr = dc_strdup(payload);
	}
	else if (strncasecmp(qr, SMTP_SCHEME, strlen(SMTP_SCHEME))==0)
	{
		/* scheme: `SMTP:addr...:subject...:body...` */
		payload = dc_strdup(&qr[strlen(SMTP_SCHEME)]);
		char* colon = strchr(payload, ':'); /* must not be freed, only a pointer inside payload */
		if (colon) {
			*colon = 0;
		}
		addr = dc_strdup(payload);
	}
	else if (strncasecmp(qr, MATMSG_SCHEME, strlen(MATMSG_SCHEME))==0)
	{
		/* scheme: `MATMSG:TO:addr...;SUB:subject...;BODY:body...;` - there may or may not be linebreaks after the fields */
		char* to = strstr(qr, "TO:"); /* does not work when the text `TO:` is used in subject/body _and_ TO: is not the first field. we ignore this case. */
		if (to) {
			addr = dc_strdup(&to[3]);
			char* semicolon = strchr(addr, ';');
			if (semicolon) { *semicolon = 0; }
		}
		else {
			qr_parsed->state = DC_QR_ERROR;
			qr_parsed->text1 = dc_strdup("Bad e-mail address.");
			goto cleanup;
		}
	}
	else if (strncasecmp(qr, VCARD_BEGIN, strlen(VCARD_BEGIN))==0)
	{
		/* scheme: `VCARD:BEGIN\nN:last name;first name;...;\nEMAIL:addr...;` */
		carray* lines = dc_split_into_lines(qr);
		for (int i = 0; i < carray_count(lines); i++) {
			char* key   = (char*)carray_get(lines, i); dc_trim(key);
			char* value = strchr(key, ':');
			if (value) {
				*value = 0;
				value++;
				char* semicolon = strchr(key, ';'); if (semicolon) { *semicolon = 0; } /* handle `EMAIL;type=work:` stuff */
				if (strcasecmp(key, "EMAIL")==0) {
					semicolon = strchr(value, ';'); if (semicolon) { *semicolon = 0; } /* use the first EMAIL */
					addr = dc_strdup(value);
				}
				else if (strcasecmp(key, "N")==0) {
					semicolon = strchr(value, ';'); if (semicolon) { semicolon = strchr(semicolon+1, ';'); if (semicolon) { *semicolon = 0; } } /* the N format is `lastname;prename;wtf;title` - skip everything after the second semicolon */
					name = dc_strdup(value);
					dc_str_replace(&name, ";", ","); /* the format "lastname,prename" is handled by dc_normalize_name() */
					dc_normalize_name(name);
				}
			}
		}
		dc_free_splitted_lines(lines);
	}

	/* check the paramters
	  ---------------------- */

	if (addr) {
		char* temp = dc_urldecode(addr);      free(addr); addr = temp; /* urldecoding is needed at least for OPENPGP4FPR but should not hurt in the other cases */
		      temp = dc_addr_normalize(addr); free(addr); addr = temp;

		if (!dc_may_be_valid_addr(addr)) {
			qr_parsed->state = DC_QR_ERROR;
			qr_parsed->text1 = dc_strdup("Bad e-mail address.");
			goto cleanup;
		}
	}

	if (fingerprint) {
		if (strlen(fingerprint) != 40) {
			qr_parsed->state = DC_QR_ERROR;
			qr_parsed->text1 = dc_strdup("Bad fingerprint length in QR code.");
			goto cleanup;
		}
	}

	/* let's see what we can do with the parameters
	  ---------------------------------------------- */

	if (fingerprint)
	{
		/* fingerprint set ... */

		if (addr==NULL || invitenumber==NULL || auth==NULL)
		{
			// _only_ fingerprint set ...
			// (we could also do this before/instead of a secure-join, however, this may require complicated questions in the ui)
			if (dc_apeerstate_load_by_fingerprint(peerstate, context->sql, fingerprint)) {
				qr_parsed->state = DC_QR_FPR_OK;
				qr_parsed->id    = dc_add_or_lookup_contact(context, NULL, peerstate->addr, DC_ORIGIN_UNHANDLED_QR_SCAN, NULL);

				dc_create_or_lookup_nchat_by_contact_id(context, qr_parsed->id, DC_CHAT_DEADDROP_BLOCKED, &chat_id, NULL);
				device_msg = dc_mprintf("%s verified.", peerstate->addr);
			}
			else {
				qr_parsed->text1 = dc_format_fingerprint(fingerprint);
				qr_parsed->state = DC_QR_FPR_WITHOUT_ADDR;
			}
		}
		else
		{
			// fingerprint + addr set, secure-join requested
			// do not comapre the fingerprint already - it may have changed - errors are catched later more proberly.
			// (theroretically, there is also the state "addr=set, fingerprint=set, invitenumber=0", however, currently, we won't get into this state)
			if (grpid && grpname) {
				qr_parsed->state = DC_QR_ASK_VERIFYGROUP;
				qr_parsed->text1 = dc_strdup(grpname);
				qr_parsed->text2 = dc_strdup(grpid);
			}
			else {
				qr_parsed->state = DC_QR_ASK_VERIFYCONTACT;
			}

			qr_parsed->id            = dc_add_or_lookup_contact(context, name, addr, DC_ORIGIN_UNHANDLED_QR_SCAN, NULL);
			qr_parsed->fingerprint   = dc_strdup(fingerprint);
			qr_parsed->invitenumber  = dc_strdup(invitenumber);
			qr_parsed->auth          = dc_strdup(auth);
		}
	}
	else if (addr)
	{
        qr_parsed->state = DC_QR_ADDR;
		qr_parsed->id    = dc_add_or_lookup_contact(context, name, addr, DC_ORIGIN_UNHANDLED_QR_SCAN, NULL);
	}
	else if (strstr(qr, "http://")==qr || strstr(qr, "https://")==qr)
	{
		qr_parsed->state = DC_QR_URL;
		qr_parsed->text1 = dc_strdup(qr);
	}
	else
	{
        qr_parsed->state = DC_QR_TEXT;
		qr_parsed->text1 = dc_strdup(qr);
	}

	if (device_msg) {
		dc_add_device_msg(context, chat_id, device_msg);
	}

cleanup:
	free(addr);
	free(fingerprint);
	dc_apeerstate_unref(peerstate);
	free(payload);
	free(name);
	free(invitenumber);
	free(auth);
	free(device_msg);
	free(grpname);
	free(grpid);
	return qr_parsed;
}


