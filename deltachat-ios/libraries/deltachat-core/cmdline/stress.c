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


/* Stress some functions for testing; if used as a lib, this file is obsolete.
For memory checking, use eg.
$ valgrind --leak-check=full --tool=memcheck ./deltachat-core <db>
*/


#include <ctype.h>
#include <assert.h>
#include "../src/dc_context.h"
#include "../src/dc_simplify.h"
#include "../src/dc_mimeparser.h"
#include "../src/dc_mimefactory.h"
#include "../src/dc_pgp.h"
#include "../src/dc_apeerstate.h"
#include "../src/dc_aheader.h"
#include "../src/dc_keyring.h"
#include "../src/dc_saxparser.h"


/* some data used for testing
 ******************************************************************************/

/* s_em_setupfile is a AES-256 symm. encrypted setup message created by Enigmail
with an "encrypted session key", see RFC 4880.  The code is in s_em_setupcode */
static const char* s_em_setupcode = "1742-0185-6197-1303-7016-8412-3581-4441-0597";
static const char* s_em_setupfile =
"-----BEGIN PGP MESSAGE-----\n"
"Passphrase-Format: numeric9x4\n"
"Passphrase-Begin: 17\n"
"\n"
"wy4ECQMI0jNRBQfVKHVg1+a2Yihd6JAjR9H0kk3oDVeX7nc4Oi+IjEtonUJt\n"
"PQpO0tPWASWYuYvjZSuTz9r1yZYV+y4mu9bu9NEQoRlWg2wnbjoUoKk4emFF\n"
"FweUj84iI6VWTCSRyMu5d5JS1RfOdX4CG/muLAegyIHezqYOEC0Z3b9Ci9rd\n"
"DiSgqqN+/LDkUR/vr7L2CSLN5suBP9Hsz75AtaV8DJ2DYDywYX89yH1CfL1O\n"
"WohyrJPdmGJZfdvQX0LI9mzN7MH0W6vUJeCaUpujc+UkLiOM6TDB74rmYF+V\n"
"Z7K9BXbaN4V6dyxVZfgpXUoZlaNpvqPJXuLHJ68umkuIgIyQvzmMj3mFgZ8s\n"
"akCt6Cf3o5O9n2PJvX89vuNnDGJrO5booEqGaBJfwUk0Rwb0gWsm5U0gceUz\n"
"dce8KZK15CzX+bNv5OC+8jjjBw7mBHVt+2q8LI+G9fEy9NIREkp5/v2ZRN0G\n"
"R6lpZwW+8TkMvJnriQeABqDpxsJVT6ENYAhkPG3AZCr/whGBU3EbDzPexXkz\n"
"qt8Pdu5DrazLSFtjpjkekrjCh43vHjGl8IOiWxKQx0VfBkHJ7O9CsHmb0r1o\n"
"F++fMh0bH1/aewmlg5wd0ixwZoP1o79he8Q4kfATZAjvB1xSLyMma+jxW5uu\n"
"U3wYUOsUmYmzo46/QzizFCUpaTJ4ZQZY1/4sflidsl/XgZ0fD1NCrdkWBNA1\n"
"0tQF949pEAeA4hSfHfQDNKAY8A7fk8lZblqWPkyu/0x8eV537QOhs89ZvhSB\n"
"V87KEAwxWt60+Eolf8PvvkvB/AKlfWq4MYShgyldwwCfkED3rv2mvTsdqfvW\n"
"WvqZNo4eRkJrnv9Be3LaXoFyY6a3z+ObBIkKI+u5azGJYge97O4E2DrUEKdQ\n"
"cScq5upzXity0E+Yhm964jzBzxnA52S4RoXzkjTxH+AHjQ5+MHQxmRfMd2ly\n"
"7skM106weVOR0JgOdkvfiOFDTHZLIVCzVyYVlOUJYYwPhmM1426zbegHNkaM\n"
"M2WgvjMp5G+X9qfDWKecntQJTziyDFZKfd1UrUCPHrvl1Ac9cuqgcCXLtdUS\n"
"jI+e1Y9fXvgyvHiMX0ztSz1yfvnRt34508G9j68fEQFQR/VIepULB5/SqKbq\n"
"p2flgJL48kY32hEw2GRPri64Tv3vMPIWa//zvQDhQPmcd3S4TqnTIIKUoTAO\n"
"NUo6GS9UAX12fdSFPZINcAkNIaB69+iwGyuJE4FLHKVkqNnNmDwF3fl0Oczo\n"
"hbboWzA3GlpR2Ri6kfe0SocfGR0CHT5ZmqI6es8hWx+RN8hpXcsRxGS0BMi2\n"
"mcJ7fPY+bKastnEeatP+b0XN/eaJAPZPZSF8PuPeQ0Uc735fylPrrgtWK9Gp\n"
"Wq0DPaWV/+O94OB/JvWT5wq7d/EEVbTck5FPl4gdv3HHpaaQ6/8G89wVMEXA\n"
"GUxB8WuvNeHAtQ7qXF7TkaZvUpF0rb1aV88uABOOPpsfAyWJo/PExCZacg8R\n"
"GOQYI6inV5HcGUw06yDSqArHZmONveqjbDBApenearcskv6Uz7q+Bp60GGSA\n"
"lvU3C3RyP/OUc1azOp72MIe0+JvP8S5DN9/Ltc/5ZyZHOjLoG+npIXnThYwV\n"
"0kkrlsi/7loCzvhcWOac1vrSaGVCfifkYf+LUFQFrFVbxKLOQ6vTsYZWM0yM\n"
"QsMMywW5A6CdROT5UB0UKRh/S1cwCwrN5UFTRt2UpDF3wSBAcChsHyy90RAL\n"
"Xd4+ZIyf29GIFuwwQyzGBWnXQ2ytU4kg/D5XSqJbJJTya386UuyQpnFjI19R\n"
"uuD0mvEfFvojCKDJDWguUNtWsHSg01NXDSrY26BhlOkMpUrzPfX5r0FQpgDS\n"
"zOdY9SIG+y9MKG+4nwmYnFM6V5NxVL+6XZ7BQTvlLIcIIu+BujVNWteDnWNZ\n"
"T1UukCGmFd8sNZpCc3wu4o/gLDQxih/545tWMf0dmeUfYhKcjSX9uucMRZHT\n"
"1N0FINw04fDdp2LccL+WCGatFGnkZVPw3asid4d1od9RG9DbNRBJEp/QeNhc\n"
"/peJCPLGYlA1NjTEq+MVB+DHdGNOuy//be3KhedBr6x4VVaDzL6jyHu/a7PR\n"
"BWRVtI1CIVDxyrEXucHdGQoEm7p+0G2zouOe/oxbPFoEYrjaI+0e/FN3u/Y3\n"
"aG0dlYWbxeHMqTh2F3lB/CFALReeGqqN6PwRyePWKaVctZYb6ydf9JVl6q1/\n"
"aV9C5rf9eFGqqA+OIx/+XuAG1w0rwlznvtajHzCoUeA4QfbmuOV/t5drWN2N\n"
"PCk2mJlcSmd7lx53rnOIgme1hggchjezc4TisL4PvSLxjJ7DxzktD2jv2I/Q\n"
"OlSxTUaXnGfIVedsI0WjFomz5w9tZjC0B5O5TpSRRz6gfpe/OC3kV7qs1YCS\n"
"lJTTxj1mTs6wqt0WjKkN/Ke0Cm5r7NQ79szDNlcC0AViEOQb3U1R88nNdiVx\n"
"ymKT5Dl+yM6acv53lNX6O5BH+mpP2/pCpi3x+kYFyr4cUsNgVVGlhmkPWctZ\n"
"trHvO7wcLrAsrLNqRxt1G3DLjQt9VY+w5qOPJv6s9qd5JBL/qtH5zqIXiXlM\n"
"IWI9LLwHFFXqjk/f6G4LyOeHB9AqccGQ4IztgzTKmYEmFWVIpTO4UN6+E7yQ\n"
"gtcYSIUEJo824ht5rL+ODqmCSAWsWIomEoTPvgn9QqO0YRwAEMpsFtE17klS\n"
"qjbYyV7Y5A0jpCvqbnGmZPqCgzjjN/p5VKSNjSdM0vdwBRgpXlyooXg/EGoJ\n"
"ZTZH8nLSuYMMu7AK8c7DKJ1AocTNYHRe9xFV8RzEiIm3zaezxa0r+Fo3nuTX\n"
"UR9DOH0EHaDLrFQcfS5y1iRxY9CHg0N2ECaUzr/H7jck9mLZ7v9xisj3QDuv\n"
"i0xQbC4BTxMEBGTK8fOcjHHOABOyhqotOreERqwOV2c1OOGUQE8QK18zJCUd\n"
"BTmQZ709ttASD7VWK4TraOGczZXkZsKdZko5T6+6EkFy9H+gwENLUG9zk0x9\n"
"2G5zicDr6PDoAGDuoB3B3VA8ertXTX7zEz30N6m+tcAtPWka0owokLy3f0o7\n"
"ZdytBPkly8foTMWKF2vsJ8K4Xdn/57jJ2qFku32xmtiPIoa6s8wINO06AVB0\n"
"0/AuttvxcPr+ycE+9wRZHx6JBujAqOZztU3zu8WZMaqVKb7gnmkWPiL+1XFp\n"
"2+mr0AghScIvjzTDEjigDtLydURJrW01wXjaR0ByBT4z8ZjaNmQAxIPOIRFC\n"
"bD0mviaoX61qgQLmSc6mzVlzzNZRCKtSvvGEK5NJ6CB6g2EeFau8+w0Zd+vv\n"
"/iv6Img3pUBgvpMaIsxRXvGZwmo2R0tztJt+CqHRvyTWjQL+CjIAWyoHEdVH\n"
"k7ne/q9zo3iIMsQUO7tVYtgURpRYc2OM1IVQtrgbmbYGEdOrhMjaWULg9C7o\n"
"6oDM0EFlCAId3P8ykXQNMluFKlf9il5nr19B/qf/wh6C7DFLOmnjTWDXrEiP\n"
"6wFEWTeUWLchGlbpiJFEu05MWPIRoRd3BHQvVpzLLgeBdxMVW7D6WCK+KJxI\n"
"W1rOKhhLVvKU3BrFgr12A4uQm+6w1j33Feh68Y0JB7GLDBBGe11QtLCD6kz5\n"
"RzFl+GbgiwpHi3nlCc5yiNwyPq/JRxU3GRb62YJcsSQBg+CD3Mk5FGiDcuvp\n"
"kZXOcTE2FAnUDigjEs+oH2qkhD4/5CiHkrfFJTzv+wqw+jwxPor2jkZH2akN\n"
"6PssXQYupXJE3NmcyaYT+b5E6qbkIyQj7CknkiqmrqrmxkOQxA+Ab2Vy9zrW\n"
"u0+Wvf+C+SebWTo3qfJZQ3KcASZHa5AGoSHetWzH2fNLIHfULXac/T++1DWE\n"
"nbeNvhXiFmAJ+BRsZj9p6RcnSamk4bjAbX1lg2G3Sq6MiA1fIRSMlSjuDLrQ\n"
"8xfVFrg7gfBIIQPErJWv2GdAsz76sLxuSXQLKYpFnozvMT7xRs84+iRNWWh9\n"
"SNibbEjlh0DcJlKw49Eis/bN22sDQWy4awHuRvvQetk/QCgp54epuqWnbxoE\n"
"XZDgGBBkMc3or+6Cxr3q9x7J/oHLvPb+Q5yVP9fyz6ZiSVWluMefA9smjJ/A\n"
"KMD84s7uO/8/4yug+swXGrcBjHSddTcy05vm+7X6o9IEZKZb5tz7VqAfEcuk\n"
"QNPUWCMudhzxSNr4+yVXRVpcjsjKtplJcXC5aIuJwq3C5OdysCGqXWjLuUu1\n"
"OFSoPvTsYC2VxYdFUcczeHEFTxXoXz3I0TyLPyxUNsJiKpUGt/SXmV/IyAx+\n"
"h6pZ2OUXspC9d78DdiHZtItPjEGiIb678ZyMxWPE59XQd/ad92mlPHU8InXD\n"
"yTq6otZ7LwAOLGbDR9bqN7oX8PCHRwuu30hk2b4+WkZn/WLd2KCPddQswZJg\n"
"Qgi5ajUaFhZvxF5YNTqIzzYVh7Y8fFMfzH9AO+SJqy+0ECX0GwtHHeVsXYNb\n"
"P/NO/ma4MI8301JyipPmdtzvvt9NOD/PJcnZH2KmDquARXMO/vKbn3rNUXog\n"
"pTFqqyNTr4L5FK86QPEoE4hDy9ItHGlEuiNVD+5suGVGUgYfV7AvZU46EeqO\n"
"rfFj8wNSX1aK/pIwWmh1EkygPSxomWRUANLX1jO6zX9wk2X80Xn9q/8jot1k\n"
"Vl54OOd7cvGls2wKkEZi5h3p6KKZHJ+WIDBQupeJbuma1GK8wAiwjDH59Y0X\n"
"wXHAk7XA+t4u0dgRpZbUUMqQmvEvfJaCr4qMlpuGdEYbbpIMUB1qCfYU9taL\n"
"zbepMIT+XYD5mTyytZhR+zrsfpt1EzbrhuabqPioySoIS/1+bWfxvndq16r0\n"
"AdNxR5LiVSVh8QJr3B/HJhVghgSVrrynniG3E94abNWL/GNxPS/dTHSf8ass\n"
"vbv7+uznADzHsMiG/ZlLAEkQJ9j0ENJvHmnayeVFIXDV6jPCcQJ+rURDgl7z\n"
"/qTLfe3o3zBMG78LcB+xDNXTQrK5Z0LX7h17hLSElpiUghFa9nviCsT0nkcr\n"
"nz302P4IOFwJuYMMCEfW+ywTn+CHpKjLHWkZSZ4q6LzNTbbgXZn/vh7njNf0\n"
"QHaHmaMNxnDhUw/Bl13uM52qtsfEYK07SEhLFlJbAk0G7q+OabK8dJxCRwS3\n"
"X9k4juzLUYhX8XBovg9G3YEVckb6iM8/LF/yvNXbUsPrdhYU9lPA63xD0Pgb\n"
"zthZCLIlnF+lS6e41WJv3n1dc4dFWD7F5tmt/7uwLC6oUGYsccSzY+bUkYhL\n"
"dp7tlQRd5AG/Xz8XilORk8cUjvi6uZss5LyQpKvGSU+77C8ZV/oS62BdS5TE\n"
"osBTrO2/9FGzQtHT+8DJSTPPgR6rcQUWLPemiG09ACKfRQ/g3b9Qj0upOcKL\n"
"6dti0lq7Aorc39vV18DPMFBOwzchUEBlBFyuSa4AoD30tsoilAC3qbzBwu3z\n"
"QLjmst76HEcWDkxgDAhlBz6/XgiVZsCivn7ygigmc2+hNEzIdDsKKfM9bkoe\n"
"3uJzmmsv8Bh5ZEtfGoGNmu/zA7tgvTOCBeotYeHr2O6pLmYb3hK+E/qCBl14\n"
"8pK4qYrjAlF+ZMq9BzXcaz5mRfKVfAQtghHOaNqopBczSE1bjFF6HaNhIaGa\n"
"N8YdabNQG7mLI/fgBxJfkPl6HdIhEpctp4RURbSFhW+wn0o85VyHM6a+6Vgj\n"
"NrYmhxPZ6N1KN0Qy76aNiw7nAToRRcOv87uZnkDIeVH8mP/0hldyiy/Y97cG\n"
"QgOeQHOG27QW57nHhqLRqvf0zzQZekuXWFbqajpaabEcdGXyiUpJ8/ZopBPM\n"
"AJwfkyA2LkV946IA4JV6sPnu9pYzpXQ4vdQKJ6DoDUyRTQmgmfSFGtfHAozY\n"
"V9k0iQeetSkYYtOagTrg3t92v7M00o/NJW/rKX4jj2djD8wtBovOcv4kxg4Z\n"
"o58Iv94ROim48XfyesvSYKN1xqqbXH4sfE6b4b9pLUxQVOmWANLK9MK8D+Ci\n"
"IvrGbz5U5bZP6vlNbe9bYzjvWTPjaMrjXknRTBcikavqOfDTSIVFtT4qvhvK\n"
"42PpOrm0qdiLwExGKQ9FfEfYZRgEcYRGg7rH3oNz6ZNOEXppF3tCl9yVOlFb\n"
"ygdIeT3Z3HeOQbAsi8jK7o16DSXL7ZOpFq9Bv9yzusrF7Eht/fSEpAVUO3D1\n"
"IuqjZcsQRhMtIvnF0oFujFtooJx9x3dj/RarvEGX/NzwATZkgJ+yWs2etruA\n"
"EzMQqED4j7Lb790zEWnt+nuHdCdlPnNy8RG5u5X62p3h5KqUbg9HfmIuuESi\n"
"hwr6dKsVQGc5XUB5KTt0dtjWlK5iaetDsZFuF5+aE0Xa6PmiQ2e7ZPFyxXmO\n"
"T/PSHzobx0qClKCu+tSWA1HDSL08IeoGZEyyhoaxyn5D9r1Mqg101v/iu59r\n"
"lRRs+plAhbuq5aQA3WKtF1N6Zb5+AVRpNUyrxyHoH36ddR4/n7lnIld3STGD\n"
"RqZLrOuKHS3dCNW2Pt15lU+loYsWFZwC6T/tAbvwhax+XaBMiKQSDFmG9sBw\n"
"TiM1JWXhq2IsjXBvCl6k2AKWLQOvc/Hin+oYs4d7M9mi0vdoEOAMadU/+Pqn\n"
"uZzP941mOUV5UeTCCbjpyfI7qtIi3TH1cQmC2kG2HrvQYuM6Momp//JusH1+\n"
"9eHgFo25HbitcKJ1sAqxsnYIW5/jIVyIJC7tatxmNfFQQ/LUb2cT+Jowwsf4\n"
"bbPinA9S6aQFy9k3vk07V2ouYl+cpMMXmNAUrboFRLxw7QDapWYMKdmnbU5O\n"
"HZuDz3iyrm0lMPsRtt/f5WUhZYY4vXT5/dj+8P6Pr5fdc4S84i5qEzf7bX/I\n"
"Sc6fpISdYBscfHdv6uXsEVtVPKEuQVYwhyc4kkwVKjZBaqsgjAA7VEhQXzO3\n"
"rC7di4UhabWQCQTG1GYZyrj4bm6dg/32uVxMoLS5kuSpi3nMz5JmQahLqRxh\n"
"argg13K2/MJ7w2AI23gCvO5bEmD1ZXIi1aGYdZfu7+KqrTumYxj0KgIesgU0\n"
"6ekmPh4Zu5lIyKopa89nfQVj3uKbwr9LLHegfzeMhvI5WQWghKcNcXEvJwSA\n"
"vEik5aXm2qSKXT+ijXBy5MuNeICoGaQ5WA0OJ30Oh5dN0XpLtFUWHZKThJvR\n"
"mngm1QCMMw2v/j8=\n"
"=9sJE\n"
"-----END PGP MESSAGE-----\n";


void stress_functions(dc_context_t* context)
{
	/* test dc_saxparser_t
	 **************************************************************************/

	{
		dc_saxparser_t saxparser;
		dc_saxparser_init(&saxparser, NULL);
		dc_saxparser_parse(&saxparser, "<tag attr=val="); // should not crash or cause a deadlock
		dc_saxparser_parse(&saxparser, "<tag attr=\"val\"="); // should not crash or cause a deadlock
	}

	/* test dc_simplify_t and dc_saxparser_t (indirectly used by dc_simplify_t)
	 **************************************************************************/

	{
		dc_simplify_t* simplify = dc_simplify_new();

		const char* html = "\r\r\nline1<br>\r\n\r\n\r\rline2\n\r"; /* check, that `<br>\ntext` does not result in `\n text` */
		char* plain = dc_simplify_simplify(simplify, html, strlen(html), 1);
		assert( strcmp(plain, "line1\nline2")==0 );
		free(plain);

		html = "<a href=url>text</a"; /* check unquoted attribute and unclosed end-tag */
		plain = dc_simplify_simplify(simplify, html, strlen(html), 1);
		assert( strcmp(plain, "[text](url)")==0 );
		free(plain);

		html = "<!DOCTYPE name [<!DOCTYPE ...>]><!-- comment -->text <b><?php echo ... ?>bold</b><![CDATA[<>]]>";
		plain = dc_simplify_simplify(simplify, html, strlen(html), 1);
		assert( strcmp(plain, "text *bold*<>")==0 );
		free(plain);

		html = "&lt;&gt;&quot;&apos;&amp; &auml;&Auml;&ouml;&Ouml;&uuml;&Uuml;&szlig; foo&AElig;&ccedil;&Ccedil; &diams;&noent;&lrm;&rlm;&zwnj;&zwj;";
		plain = dc_simplify_simplify(simplify, html, strlen(html), 1);
		assert( strcmp(plain, "<>\"'& äÄöÖüÜß fooÆçÇ ♦&noent;")==0 );
		free(plain);

		dc_simplify_unref(simplify);
	}

	/* test mailmime
	**************************************************************************/

	{
		const char* txt =  "FieldA: ValueA\nFieldB: ValueB\n";
		struct mailmime* mime = NULL;
		size_t dummy = 0;
		assert( mailmime_parse(txt, strlen(txt), &dummy, &mime) == MAIL_NO_ERROR );
		assert( mime != NULL );

		struct mailimf_fields* fields = mailmime_find_mailimf_fields(mime);
		assert( fields != NULL );

		struct mailimf_optional_field* of_a = mailimf_find_optional_field(fields, "fielda");
		assert( of_a && of_a->fld_value );
		assert( strcmp(of_a->fld_name, "FieldA")==0 );
		assert( strcmp(of_a->fld_value, "ValueA")==0 );

		of_a = mailimf_find_optional_field(fields, "FIELDA");
		assert( of_a && of_a->fld_value );
		assert( strcmp(of_a->fld_name, "FieldA")==0 );
		assert( strcmp(of_a->fld_value, "ValueA")==0 );

		struct mailimf_optional_field* of_b = mailimf_find_optional_field(fields, "FieldB");
		assert( of_b && of_b->fld_value );
		assert( strcmp(of_b->fld_value, "ValueB")==0 );

		mailmime_free(mime);
	}

	/* test dc_mimeparser_t
	**************************************************************************/

	{
		dc_mimeparser_t* mimeparser = dc_mimeparser_new(context->blobdir, context);

		const char* raw =
			"Content-Type: multipart/mixed; boundary=\"==break==\";\n"
			"Subject: outer-subject\n"
			"X-Special-A: special-a\n"
			"Foo: Bar\n"
			"Chat-Version: 0.0\n"
			"\n"
			"--==break==\n"
			"Content-Type: text/plain; protected-headers=\"v1\";\n"
			"Subject: inner-subject\n"
			"X-Special-B: special-b\n"
			"Foo: Xy\n"
			"Chat-Version: 1.0\n"
			"\n"
			"test1\n"
			"\n"
			"--==break==--\n"
			"\n";

		dc_mimeparser_parse(mimeparser, raw, strlen(raw));

		assert( strcmp(mimeparser->subject, "inner-subject")==0 );

		struct mailimf_optional_field* of = dc_mimeparser_lookup_optional_field(mimeparser, "X-Special-A");
		assert( strcmp(of->fld_value, "special-a")==0 );

		of = dc_mimeparser_lookup_optional_field(mimeparser, "Foo");
		assert( strcmp(of->fld_value, "Bar")==0 ); /* completely unknown values are not overwritten */

		of = dc_mimeparser_lookup_optional_field(mimeparser, "Chat-Version");
		assert( strcmp(of->fld_value, "1.0")==0 );

		assert( carray_count(mimeparser->parts) == 1 );

		dc_mimeparser_unref(mimeparser);
	}

	/* test message helpers
	 **************************************************************************/

	{
		int type;
		char* mime;
		dc_msg_guess_msgtype_from_suffix("foo/bar-sth.mp3", NULL, NULL);
		dc_msg_guess_msgtype_from_suffix("foo/bar-sth.mp3", NULL, &mime);
		assert( strcmp(mime, "audio/mpeg")==0 );
		dc_msg_guess_msgtype_from_suffix("foo/bar-sth.mp3", &type, NULL);
		assert( type == DC_MSG_AUDIO );
		free(mime);
	}

	/* test some string functions
	 **************************************************************************/

	{
		char* str = strdup("aaa");
		int replacements = dc_str_replace(&str, "a", "ab"); /* no endless recursion here! */
		assert( strcmp(str, "ababab")==0 );
		assert( replacements == 3 );
		free(str);

		str = strdup("this is a little test string");
			dc_truncate_str(str, 16);
			assert( strcmp(str, "this is a " DC_EDITORIAL_ELLIPSE)==0 );
		free(str);

		str = strdup("1234");
			dc_truncate_str(str, 2);
			assert( strcmp(str, "1234")==0 );
		free(str);

		str = strdup("1234567");
			dc_truncate_str(str, 1);
			assert( strcmp(str, "1[...]")==0 );
		free(str);

		str = strdup("123456");
			dc_truncate_str(str, 4);
			assert( strcmp(str, "123456")==0 );
		free(str);

		str = dc_insert_breaks("just1234test", 4, " ");
		assert( strcmp(str, "just 1234 test")==0 );
		free(str);

		str = dc_insert_breaks("just1234tes", 4, "--");
		assert( strcmp(str, "just--1234--tes")==0 );
		free(str);

		str = dc_insert_breaks("just1234t", 4, "");
		assert( strcmp(str, "just1234t")==0 );
		free(str);

		str = dc_insert_breaks("", 4, "---");
		assert( strcmp(str, "")==0 );
		free(str);

		str = dc_null_terminate("abcxyz", 3);
		assert( strcmp(str, "abc")==0 );
		free(str);

		str = dc_null_terminate("abcxyz", 0);
		assert( strcmp(str, "")==0 );
		free(str);

		str = dc_null_terminate(NULL, 0);
		assert( strcmp(str, "")==0 );
		free(str);

		assert( strcmp("fresh="     DC_STRINGIFY(DC_STATE_IN_FRESH),      "fresh=10")==0 ); /* these asserts check the values, the existance of the macros and also DC_STRINGIFY() */
		assert( strcmp("noticed="   DC_STRINGIFY(DC_STATE_IN_NOTICED),    "noticed=13")==0 );
		assert( strcmp("seen="      DC_STRINGIFY(DC_STATE_IN_SEEN),       "seen=16")==0 );
		assert( strcmp("pending="   DC_STRINGIFY(DC_STATE_OUT_PENDING),   "pending=20")==0 );
		assert( strcmp("failed="    DC_STRINGIFY(DC_STATE_OUT_FAILED),    "failed=24")==0 );
		assert( strcmp("delivered=" DC_STRINGIFY(DC_STATE_OUT_DELIVERED), "delivered=26")==0 );
		assert( strcmp("mdn_rcvd="  DC_STRINGIFY(DC_STATE_OUT_MDN_RCVD),  "mdn_rcvd=28")==0 );

		assert( strcmp("undefined="    DC_STRINGIFY(DC_CHAT_TYPE_UNDEFINED),      "undefined=0")==0 );
		assert( strcmp("single="       DC_STRINGIFY(DC_CHAT_TYPE_SINGLE),         "single=100")==0 );
		assert( strcmp("group="        DC_STRINGIFY(DC_CHAT_TYPE_GROUP),          "group=120")==0 );
		assert( strcmp("vgroup="       DC_STRINGIFY(DC_CHAT_TYPE_VERIFIED_GROUP), "vgroup=130")==0 );

		assert( strcmp("deaddrop="     DC_STRINGIFY(DC_CHAT_ID_DEADDROP),         "deaddrop=1")==0 );
		assert( strcmp("trash="        DC_STRINGIFY(DC_CHAT_ID_TRASH),            "trash=3")==0 );
		assert( strcmp("in_creation="  DC_STRINGIFY(DC_CHAT_ID_MSGS_IN_CREATION), "in_creation=4")==0 );
		assert( strcmp("starred="      DC_STRINGIFY(DC_CHAT_ID_STARRED),          "starred=5")==0 );
		assert( strcmp("archivedlink=" DC_STRINGIFY(DC_CHAT_ID_ARCHIVED_LINK),    "archivedlink=6")==0 );
		assert( strcmp("spcl_chat="    DC_STRINGIFY(DC_CHAT_ID_LAST_SPECIAL),     "spcl_chat=9")==0 );

		assert( strcmp("self="         DC_STRINGIFY(DC_CONTACT_ID_SELF),          "self=1")==0 );
		assert( strcmp("spcl_contact=" DC_STRINGIFY(DC_CONTACT_ID_LAST_SPECIAL),  "spcl_contact=9")==0 );

		assert( strcmp("grpimg="    DC_STRINGIFY(DC_CMD_GROUPIMAGE_CHANGED), "grpimg=3")==0 );

		assert( strcmp("notverified="    DC_STRINGIFY(DC_NOT_VERIFIED),  "notverified=0")==0 );
		assert( strcmp("bidirectional="  DC_STRINGIFY(DC_BIDIRECT_VERIFIED), "bidirectional=2")==0 );

		assert( strcmp("public="  DC_STRINGIFY(DC_KEY_PUBLIC), "public=0")==0 );
		assert( strcmp("private="  DC_STRINGIFY(DC_KEY_PRIVATE), "private=1")==0 );

		assert( DC_PARAM_FILE == 'f' );
		assert( DC_PARAM_WIDTH == 'w' );
		assert( DC_PARAM_HEIGHT == 'h' );
		assert( DC_PARAM_DURATION == 'd' );
		assert( DC_PARAM_MIMETYPE == 'm' );
		assert( DC_PARAM_AUTHORNAME == 'N' );
		assert( DC_PARAM_TRACKNAME == 'n' );
		assert( DC_PARAM_FORWARDED == 'a' );
		assert( DC_PARAM_UNPROMOTED == 'U' );

		char* buf1 = strdup("ol\xc3\xa1 mundo <>\"'& äÄöÖüÜß fooÆçÇ ♦&noent;"); char* buf2 = strdup(buf1);
		dc_replace_bad_utf8_chars(buf2);
		assert( strcmp(buf1, buf2)==0 );
		free(buf1); free(buf2);

		buf1 = strdup("ISO-String with Ae: \xC4"); buf2 = strdup(buf1);
		dc_replace_bad_utf8_chars(buf2);
		assert( strcmp("ISO-String with Ae: _", buf2)==0 );
		free(buf1); free(buf2);

		buf1 = strdup(""); buf2 = strdup(buf1);
		dc_replace_bad_utf8_chars(buf2);
		assert( buf2[0]==0 );
		free(buf1); free(buf2);

		dc_replace_bad_utf8_chars(NULL); /* should do nothing */

		buf1 = dc_urlencode("Björn Petersen");
		assert( strcmp(buf1, "Bj%C3%B6rn+Petersen") == 0 );
		buf2 = dc_urldecode(buf1);
		assert( strcmp(buf2, "Björn Petersen") == 0 );
		free(buf1); free(buf2);

		buf1 = dc_create_id();
		assert( strlen(buf1) == DC_CREATE_ID_LEN );
		free(buf1);

		buf1 = dc_decode_header_words("=?utf-8?B?dGVzdMOkw7bDvC50eHQ=?=");
		assert( strcmp(buf1, "testäöü.txt")==0 );
		free(buf1);

		buf1 = dc_decode_header_words("just ascii test");
		assert( strcmp(buf1, "just ascii test")==0 );
		free(buf1);

		buf1 = dc_encode_header_words("abcdef");
		assert( strcmp(buf1, "abcdef")==0 );
		free(buf1);

		buf1 = dc_encode_header_words("testäöü.txt");
		assert( strncmp(buf1, "=?utf-8", 7)==0 );
		buf2 = dc_decode_header_words(buf1);
		assert( strcmp("testäöü.txt", buf2)==0 );
		free(buf1);
		free(buf2);

		buf1 = dc_decode_header_words("=?ISO-8859-1?Q?attachment=3B=0D=0A_filename=3D?= =?ISO-8859-1?Q?=22test=E4=F6=FC=2Etxt=22=3B=0D=0A_size=3D39?=");
		assert( strcmp(buf1, "attachment;\r\n filename=\"testäöü.txt\";\r\n size=39")==0 );
		free(buf1);

		buf1 = dc_encode_ext_header("Björn Petersen");
		assert( strcmp(buf1, "utf-8''Bj%C3%B6rn%20Petersen") == 0 );
		buf2 = dc_decode_ext_header(buf1);
		assert( strcmp(buf2, "Björn Petersen") == 0 );
		free(buf1);
		free(buf2);

		buf1 = dc_decode_ext_header("iso-8859-1'en'%A3%20rates");
		assert( strcmp(buf1, "£ rates") == 0 );
		assert( strcmp(buf1, "\xC2\xA3 rates") == 0 );
		free(buf1);

		buf1 = dc_decode_ext_header("wrong'format"); // bad format -> should return given string
		assert( strcmp(buf1, "wrong'format") == 0 );
		free(buf1);

		buf1 = dc_decode_ext_header("''"); // empty charset -> should return given string
		assert( strcmp(buf1, "''") == 0 );
		free(buf1);

		buf1 = dc_decode_ext_header("x''"); // charset given -> return empty encoded string
		assert( strcmp(buf1, "") == 0 );
		free(buf1);

		buf1 = dc_decode_ext_header("'"); // bad format -> should return given string
		assert( strcmp(buf1, "'") == 0 );
		free(buf1);

		buf1 = dc_decode_ext_header(""); // bad format -> should return given string - empty in this case
		assert( strcmp(buf1, "") == 0 );
		free(buf1);

		assert(  dc_needs_ext_header("Björn") );
		assert( !dc_needs_ext_header("Bjoern") );
		assert( !dc_needs_ext_header("") );
		assert(  dc_needs_ext_header(" ") );
		assert(  dc_needs_ext_header("a b") );
		assert( !dc_needs_ext_header(NULL) );

		buf1 = dc_encode_modified_utf7("Björn Petersen", 1);
		assert( strcmp(buf1, "Bj&APY-rn_Petersen")==0 );
		buf2 = dc_decode_modified_utf7(buf1, 1);
		assert( strcmp(buf2, "Björn Petersen")==0 );
		free(buf1);
		free(buf2);
	}

	/* test dc_array_t
	 **************************************************************************/

	{
		#define TEST_CNT  1000
		dc_array_t* arr = dc_array_new(NULL, 7);
		assert( dc_array_get_cnt(arr) == 0 );

		int i;
		for (i = 0; i < TEST_CNT; i++) {
			dc_array_add_id(arr, i+1*2);
		}
		assert( dc_array_get_cnt(arr) == TEST_CNT );

		for (i = 0; i< TEST_CNT; i++) {
			assert( dc_array_get_id(arr, i) == i+1*2 );
		}
		assert( dc_array_get_id(arr, -1) == 0 ); /* test out-of-range access */
		assert( dc_array_get_id(arr, TEST_CNT) == 0 ); /* test out-of-range access */
		assert( dc_array_get_id(arr, TEST_CNT+1) == 0 ); /* test out-of-range access */

		dc_array_empty(arr);
		assert( dc_array_get_cnt(arr) == 0 );

		dc_array_add_id(arr, 13);
		dc_array_add_id(arr, 7);
		dc_array_add_id(arr, 666);
		dc_array_add_id(arr, 0);
		dc_array_add_id(arr, 5000);
		dc_array_sort_ids(arr);
		assert( dc_array_get_id(arr, 0)==0 && dc_array_get_id(arr, 1)==7 && dc_array_get_id(arr, 2)==13 && dc_array_get_id(arr, 3)==666 );

		char* str = dc_array_get_string(arr, "-");
		assert( strcmp(str, "0-7-13-666-5000")==0 );
		free(str);

		const uint32_t arr2[] = { 0, 12, 133, 1999999 };
		str = dc_arr_to_string(arr2, 4);
		assert( strcmp(str, "0,12,133,1999999")==0 );
		free(str);
		dc_array_empty(arr);

		dc_array_add_ptr(arr, "XX");
		dc_array_add_ptr(arr, "item1");
		dc_array_add_ptr(arr, "bbb");
		dc_array_add_ptr(arr, "aaa");
		dc_array_sort_strings(arr);
		assert( strcmp("XX",    (char*)dc_array_get_ptr(arr, 0))==0 );
		assert( strcmp("aaa",   (char*)dc_array_get_ptr(arr, 1))==0 );
		assert( strcmp("bbb",   (char*)dc_array_get_ptr(arr, 2))==0 );
		assert( strcmp("item1", (char*)dc_array_get_ptr(arr, 3))==0 );

		dc_array_unref(arr);
	}

	/* test dc_param
	 **************************************************************************/

	{
		dc_param_t* p1 = dc_param_new();

		dc_param_set_packed(p1, "\r\n\r\na=1\nb=2\n\nc = 3 ");

		assert( dc_param_get_int(p1, 'a', 0)==1 );
		assert( dc_param_get_int(p1, 'b', 0)==2 );
		assert( dc_param_get_int(p1, 'c', 0)==0 ); /* c is not accepted, spaces and weird characters are not allowed in param, were very strict there */
		assert( dc_param_exists (p1, 'c')==0 );

		dc_param_set_int(p1, 'd', 4);
		assert( dc_param_get_int(p1, 'd', 0)==4 );

		dc_param_empty(p1);
		dc_param_set    (p1, 'a', "foo");
		dc_param_set_int(p1, 'b', 2);
		dc_param_set    (p1, 'c', NULL);
		dc_param_set_int(p1, 'd', 4);
		assert( strcmp(p1->packed, "a=foo\nb=2\nd=4")==0 );

		dc_param_set    (p1, 'b', NULL);
		assert( strcmp(p1->packed, "a=foo\nd=4")==0 );

		dc_param_set    (p1, 'a', NULL);
		dc_param_set    (p1, 'd', NULL);
		assert( strcmp(p1->packed, "")==0 );

		dc_param_unref(p1);
	}

	/* test Autocrypt header parsing functions
	 **************************************************************************/

	{
		dc_aheader_t* ah = dc_aheader_new();
		char*         rendered = NULL;
		int           ah_ok;

		ah_ok = dc_aheader_set_from_string(ah, "addr=a@b.example.org; prefer-encrypt=mutual; keydata=RGVsdGEgQ2hhdA==");
		assert( ah_ok == 1 );
		assert( ah->addr && strcmp(ah->addr, "a@b.example.org")==0 );
		assert( ah->public_key->bytes==10 && strncmp((char*)ah->public_key->binary, "Delta Chat", 10)==0 );
		assert( ah->prefer_encrypt==DC_PE_MUTUAL );

		rendered = dc_aheader_render(ah);
		assert( rendered && strcmp(rendered, "addr=a@b.example.org; prefer-encrypt=mutual; keydata= RGVsdGEgQ2hhdA==")==0 );

		ah_ok = dc_aheader_set_from_string(ah, " _foo; __FOO=BAR ;;; addr = a@b.example.org ;\r\n   prefer-encrypt = mutual ; keydata = RG VsdGEgQ\r\n2hhdA==");
		assert( ah_ok == 1 );
		assert( ah->addr && strcmp(ah->addr, "a@b.example.org")==0 );
		assert( ah->public_key->bytes==10 && strncmp((char*)ah->public_key->binary, "Delta Chat", 10)==0 );
		assert( ah->prefer_encrypt==DC_PE_MUTUAL );

		ah_ok = dc_aheader_set_from_string(ah, "addr=a@b.example.org; prefer-encrypt=ignoreUnknownValues; keydata=RGVsdGEgQ2hhdA==");
		assert( ah_ok == 1 ); /* only "yes" or "no" are valid for prefer-encrypt ... */

		ah_ok = dc_aheader_set_from_string(ah, "addr=a@b.example.org; keydata=RGVsdGEgQ2hhdA==");
		assert( ah_ok == 1 && ah->prefer_encrypt==DC_PE_NOPREFERENCE ); /* ... "nopreference" is use if the attribute is missing (see Autocrypt-Level0) */

		ah_ok = dc_aheader_set_from_string(ah, "");
		assert( ah_ok == 0 );

		ah_ok = dc_aheader_set_from_string(ah, ";");
		assert( ah_ok == 0 );

		ah_ok = dc_aheader_set_from_string(ah, "foo");
		assert( ah_ok == 0 );

		ah_ok = dc_aheader_set_from_string(ah, "\n\n\n");
		assert( ah_ok == 0 );

		ah_ok = dc_aheader_set_from_string(ah, " ;;");
		assert( ah_ok == 0 );

		ah_ok = dc_aheader_set_from_string(ah, "addr=a@t.de; unknwon=1; keydata=jau"); /* unknwon non-underscore attributes result in invalid headers */
		assert( ah_ok == 0 );

		dc_aheader_unref(ah);
		free(rendered);
	}

	/* test PGP armor parsing
	 **************************************************************************/

	{
		int ok;
		char *buf;
		const char *headerline, *setupcodebegin, *preferencrypt, *base64;

		buf = strdup("-----BEGIN PGP MESSAGE-----\nNoVal:\n\ndata\n-----END PGP MESSAGE-----");
		ok = dc_split_armored_data(buf, &headerline, &setupcodebegin, NULL, &base64);
		assert( ok == 1 );
		assert( headerline && strcmp(headerline, "-----BEGIN PGP MESSAGE-----")==0 );
		assert( base64 && strcmp(base64, "data") == 0 );
		free(buf);

		buf = strdup("-----BEGIN PGP MESSAGE-----\n\ndat1\n-----END PGP MESSAGE-----\n-----BEGIN PGP MESSAGE-----\n\ndat2\n-----END PGP MESSAGE-----");
		ok = dc_split_armored_data(buf, &headerline, &setupcodebegin, NULL, &base64);
		assert( ok == 1 );
		assert( headerline && strcmp(headerline, "-----BEGIN PGP MESSAGE-----")==0 );
		assert( base64 && strcmp(base64, "dat1") == 0 );
		free(buf);

		buf = strdup("foo \n -----BEGIN PGP MESSAGE----- \n base64-123 \n  -----END PGP MESSAGE-----");
		ok = dc_split_armored_data(buf, &headerline, &setupcodebegin, NULL, &base64);
		assert( ok == 1 );
		assert( headerline && strcmp(headerline, "-----BEGIN PGP MESSAGE-----")==0 );
		assert( setupcodebegin == NULL );
		assert( base64 && strcmp(base64, "base64-123")==0 );
		free(buf);

		buf = strdup("foo-----BEGIN PGP MESSAGE-----");
		ok = dc_split_armored_data(buf, &headerline, &setupcodebegin, NULL, &base64);
		assert( ok == 0 );
		free(buf);

		buf = strdup("foo \n -----BEGIN PGP MESSAGE-----\n  Passphrase-BeGIN  :  23 \n  \n base64-567 \r\n abc \n  -----END PGP MESSAGE-----\n\n\n");
		ok = dc_split_armored_data(buf, &headerline, &setupcodebegin, NULL, &base64);
		assert( ok == 1 );
		assert( headerline && strcmp(headerline, "-----BEGIN PGP MESSAGE-----")==0 );
		assert( setupcodebegin && strcmp(setupcodebegin, "23")==0 );
		assert( base64 && strcmp(base64, "base64-567 \n abc")==0 );
		free(buf);

		buf = strdup("-----BEGIN PGP PRIVATE KEY BLOCK-----\n Autocrypt-Prefer-Encrypt :  mutual \n\nbase64\n-----END PGP PRIVATE KEY BLOCK-----");
		ok = dc_split_armored_data(buf, &headerline, NULL, &preferencrypt, &base64);
		assert( ok == 1 );
		assert( headerline && strcmp(headerline, "-----BEGIN PGP PRIVATE KEY BLOCK-----")==0 );
		assert( preferencrypt && strcmp(preferencrypt, "mutual")==0 );
		assert( base64 && strcmp(base64, "base64")==0 );
		free(buf);
	}

	/* test Autocrypt Setup Message
	 **************************************************************************/

	{
		char* norm = dc_normalize_setup_code(context, "123422343234423452346234723482349234");
		assert( norm );
		assert( strcmp(norm, "1234-2234-3234-4234-5234-6234-7234-8234-9234") == 0 );
		free(norm);

		norm = dc_normalize_setup_code(context, "\t1 2 3422343234- foo bar-- 423-45 2 34 6234723482349234      ");
		assert( norm );
		assert( strcmp(norm, "1234-2234-3234-4234-5234-6234-7234-8234-9234") == 0 );
		free(norm);
	}

	{
		char* buf = NULL;
		const char *headerline = NULL, *setupcodebegin = NULL, *preferencrypt = NULL;

		buf = strdup(s_em_setupfile);
			assert( dc_split_armored_data(buf, &headerline, &setupcodebegin, &preferencrypt, NULL) );
			assert( headerline && strcmp(headerline, "-----BEGIN PGP MESSAGE-----")==0 );
			assert( setupcodebegin && strlen(setupcodebegin)<strlen(s_em_setupcode) && strncmp(setupcodebegin, s_em_setupcode, strlen(setupcodebegin))==0 );
			assert( preferencrypt==NULL );
		free(buf);

		assert( (buf=dc_decrypt_setup_file(context, s_em_setupcode, s_em_setupfile)) != NULL );
			assert( dc_split_armored_data(buf, &headerline, &setupcodebegin, &preferencrypt, NULL) );
			assert( headerline && strcmp(headerline, "-----BEGIN PGP PRIVATE KEY BLOCK-----")==0 );
			assert( setupcodebegin==NULL );
			assert( preferencrypt && strcmp(preferencrypt, "mutual")==0 );
		free(buf);
	}

	if (dc_is_configured(context) )
	{
		char *setupcode = NULL, *setupfile = NULL;

		assert( (setupcode=dc_create_setup_code(context)) != NULL );
		assert( strlen(setupcode) == 44 );
		assert( setupcode[4]=='-' && setupcode[9]=='-' && setupcode[14]=='-' && setupcode[19]=='-' && setupcode[24]=='-' && setupcode[29]=='-' && setupcode[34]=='-' && setupcode[39]=='-' );

		assert( (setupfile=dc_render_setup_file(context, setupcode)) != NULL );

		{
			char *buf = dc_strdup(setupfile);
			const char *headerline = NULL, *setupcodebegin = NULL;
			assert( dc_split_armored_data(buf, &headerline, &setupcodebegin, NULL, NULL) );
			assert( headerline && strcmp(headerline, "-----BEGIN PGP MESSAGE-----")==0 );
			assert( setupcodebegin && strlen(setupcodebegin)==2 && strncmp(setupcodebegin, setupcode, 2)==0 );
			free(buf);
		}

		{
			char *payload = NULL;
			const char *headerline = NULL;
			assert( (payload=dc_decrypt_setup_file(context, setupcode, setupfile))!=NULL );
			assert( dc_split_armored_data(payload, &headerline, NULL, NULL, NULL) );
			assert( headerline && strcmp(headerline, "-----BEGIN PGP PRIVATE KEY BLOCK-----")==0 );
			free(payload);
		}

		free(setupfile);
		free(setupcode);
	}

	/* test end-to-end-encryption
	 **************************************************************************/

	{
		dc_key_t *bad_key = dc_key_new();
			#define BAD_DATA_BYTES 4096
			unsigned char bad_data[BAD_DATA_BYTES];
			for( int i = 0; i < BAD_DATA_BYTES; i++ ) {
				bad_data[i] = (unsigned char)(i&0xFF);
			}
			for( int j = 0; j < BAD_DATA_BYTES/40; j++ ) {
				dc_key_set_from_binary(bad_key, &bad_data[j], BAD_DATA_BYTES/2 + j, (j&1)? DC_KEY_PUBLIC : DC_KEY_PRIVATE);
				assert( !dc_pgp_is_valid_key(context, bad_key) );
			}
		dc_key_unref(bad_key);
	}

	{
		dc_key_t *public_key = dc_key_new(), *private_key = dc_key_new();
		dc_pgp_create_keypair(context, "foo@bar.de", public_key, private_key);
		assert( dc_pgp_is_valid_key(context, public_key) );
		assert( dc_pgp_is_valid_key(context, private_key) );
		//{char *t1=dc_key_render_asc(public_key); printf("%s",t1);dc_write_file("/home/bpetersen/temp/stress-public.asc", t1,strlen(t1),mailbox);dc_write_file("/home/bpetersen/temp/stress-public.der", public_key->binary, public_key->bytes, mailbox);free(t1);}
		//{char *t1=dc_key_render_asc(private_key);printf("%s",t1);dc_write_file("/home/bpetersen/temp/stress-private.asc",t1,strlen(t1),mailbox);dc_write_file("/home/bpetersen/temp/stress-private.der",private_key->binary,private_key->bytes,mailbox);free(t1);}

		{
			dc_key_t *test_key = dc_key_new();
			assert( dc_pgp_split_key(context, private_key, test_key) );
			//assert( dc_key_equals(public_key, test_key) );
			dc_key_unref(test_key);
		}

		dc_key_t *public_key2 = dc_key_new(), *private_key2 = dc_key_new();
		dc_pgp_create_keypair(context, "two@zwo.de", public_key2, private_key2);

		assert( !dc_key_equals(public_key, public_key2) );

		const char* original_text = "This is a test";
		void *ctext_signed = NULL, *ctext_unsigned = NULL;
		size_t ctext_signed_bytes = 0, ctext_unsigned_bytes, plain_bytes = 0;

		{
			dc_keyring_t* keyring = dc_keyring_new();
			dc_keyring_add(keyring, public_key);
			dc_keyring_add(keyring, public_key2);
				int ok = dc_pgp_pk_encrypt(context, original_text, strlen(original_text), keyring, private_key, 1, (void**)&ctext_signed, &ctext_signed_bytes);
				assert( ok && ctext_signed && ctext_signed_bytes>0 );
				assert( strncmp((char*)ctext_signed, "-----BEGIN PGP MESSAGE-----", 27)==0 );
				assert( ((char*)ctext_signed)[ctext_signed_bytes-1]!=0 ); /*armored strings are not null-terminated!*/
				//{char* t3 = dc_null_terminate((char*)ctext,ctext_bytes);printf("\n%i ENCRYPTED BYTES: {\n%s\n}\n",(int)ctext_bytes,t3);free(t3);}

				ok = dc_pgp_pk_encrypt(context, original_text, strlen(original_text), keyring, NULL, 1, (void**)&ctext_unsigned, &ctext_unsigned_bytes);
				assert( ok && ctext_unsigned && ctext_unsigned_bytes>0 );
				assert( strncmp((char*)ctext_unsigned, "-----BEGIN PGP MESSAGE-----", 27)==0 );
				assert( ctext_unsigned_bytes < ctext_signed_bytes );

			dc_keyring_unref(keyring);
		}

		{
			dc_keyring_t* keyring = dc_keyring_new();
			dc_keyring_add(keyring, private_key);

			dc_keyring_t* public_keyring = dc_keyring_new();
			dc_keyring_add(public_keyring, public_key);

			dc_keyring_t* public_keyring2 = dc_keyring_new();
			dc_keyring_add(public_keyring2, public_key2);

			void* plain = NULL;
			dc_hash_t valid_signatures;
			dc_hash_init(&valid_signatures, DC_HASH_STRING, 1/*copy key*/);
			int ok;

			ok = dc_pgp_pk_decrypt(context, ctext_signed, ctext_signed_bytes, keyring, public_keyring/*for validate*/, 1, &plain, &plain_bytes, &valid_signatures);
			assert( ok && plain && plain_bytes>0 );
			assert( strncmp((char*)plain, original_text, strlen(original_text))==0 );
			assert( dc_hash_cnt(&valid_signatures) == 1 );
			free(plain); plain = NULL;
			dc_hash_clear(&valid_signatures);

			ok = dc_pgp_pk_decrypt(context, ctext_signed, ctext_signed_bytes, keyring, NULL/*for validate*/, 1, &plain, &plain_bytes, &valid_signatures);
			assert( ok && plain && plain_bytes>0 );
			assert( strncmp((char*)plain, original_text, strlen(original_text))==0 );
			assert( dc_hash_cnt(&valid_signatures) == 0 );
			free(plain); plain = NULL;
			dc_hash_clear(&valid_signatures);

			ok = dc_pgp_pk_decrypt(context, ctext_signed, ctext_signed_bytes, keyring, public_keyring2/*for validate*/, 1, &plain, &plain_bytes, &valid_signatures);
			assert( ok && plain && plain_bytes>0 );
			assert( strncmp((char*)plain, original_text, strlen(original_text))==0 );
			assert( dc_hash_cnt(&valid_signatures) == 0 );
			free(plain); plain = NULL;
			dc_hash_clear(&valid_signatures);

			dc_keyring_add(public_keyring2, public_key);
			ok = dc_pgp_pk_decrypt(context, ctext_signed, ctext_signed_bytes, keyring, public_keyring2/*for validate*/, 1, &plain, &plain_bytes, &valid_signatures);
			assert( ok && plain && plain_bytes>0 );
			assert( strncmp((char*)plain, original_text, strlen(original_text))==0 );
			assert( dc_hash_cnt(&valid_signatures) == 1 );
			free(plain); plain = NULL;
			dc_hash_clear(&valid_signatures);

			ok = dc_pgp_pk_decrypt(context, ctext_unsigned, ctext_unsigned_bytes, keyring, public_keyring/*for validate*/, 1, &plain, &plain_bytes, &valid_signatures);
			assert( ok && plain && plain_bytes>0 );
			assert( strncmp((char*)plain, original_text, strlen(original_text))==0 );
			assert( dc_hash_cnt(&valid_signatures) == 0 );
			free(plain); plain = NULL;
			dc_hash_clear(&valid_signatures);

			dc_keyring_unref(keyring);
			dc_keyring_unref(public_keyring);
			dc_keyring_unref(public_keyring2);
		}

		{
			dc_keyring_t* keyring = dc_keyring_new();
			dc_keyring_add(keyring, private_key2);

			dc_keyring_t* public_keyring = dc_keyring_new();
			dc_keyring_add(public_keyring, public_key);

			void* plain = NULL;
			int ok = dc_pgp_pk_decrypt(context, ctext_signed, ctext_signed_bytes, keyring, public_keyring/*for validate*/, 1, &plain, &plain_bytes, NULL);
			assert( ok && plain && plain_bytes>0 );
			assert( strcmp(plain, original_text)==0 );
			free(plain);

			dc_keyring_unref(keyring);
			dc_keyring_unref(public_keyring);
		}

		free(ctext_signed);
		free(ctext_unsigned);
		dc_key_unref(public_key2);
		dc_key_unref(private_key2);
		dc_key_unref(public_key);
		dc_key_unref(private_key);
	}


	/* test out-of-band verification
	 **************************************************************************/

	{
		char* fingerprint = dc_normalize_fingerprint(" 1234  567890 \n AbcD abcdef ABCDEF ");
		assert( fingerprint );
		assert( strcmp(fingerprint, "1234567890ABCDABCDEFABCDEF") == 0 );
		free(fingerprint);
	}

	if (dc_is_configured(context))
	{
		char* qr = dc_get_securejoin_qr(context, 0);
		assert( strlen(qr)>55 && strncmp(qr, "OPENPGP4FPR:", 12)==0 && strncmp(&qr[52], "#a=", 3)==0 );

		dc_lot_t* res = dc_check_qr(context, qr);
		assert( res );
		assert( res->state == DC_QR_ASK_VERIFYCONTACT || res->state == DC_QR_FPR_MISMATCH || res->state == DC_QR_FPR_WITHOUT_ADDR );

		dc_lot_unref(res);
		free(qr);

		res = dc_check_qr(context, "BEGIN:VCARD\nVERSION:3.0\nN:Last;First\nEMAIL;TYPE=INTERNET:stress@test.local\nEND:VCARD");
		assert( res );
		assert( res->state == DC_QR_ADDR );
		assert( res->id != 0 );
		dc_lot_unref(res);
	}
}
