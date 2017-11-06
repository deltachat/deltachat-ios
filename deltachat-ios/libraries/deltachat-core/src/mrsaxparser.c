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
 *******************************************************************************
 *
 * File:    mrsaxparser.c
 *
 ******************************************************************************/


#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "mrmailbox.h"
#include "mrtools.h"
#include "mrsaxparser.h"


/*******************************************************************************
 * Decoding text
 ******************************************************************************/


static const char* s_ent[] = {
	/* Convert entities as &auml; to UTF-8 characters.

	- The first strings MUST NOT start with `&` and MUST end with `;`.
	- take care not to miss a comma between the strings.
	- It's also possible to specify the destination as a character reference as `&#34;` (they are converted in a second pass without a table). */

	/* basic XML/HTML */
	"lt;",      "<",	"gt;",      ">",	"quot;",    "\"",	"apos;",    "'",
	"amp;",     "&",    "nbsp;",    " ",

	/* advanced HTML */
	"iexcl;",   "¡",	"cent;",    "¢",	"pound;",   "£",	"curren;",  "¤",
	"yen;",     "¥",	"brvbar;",  "¦",	"sect;",    "§",	"uml;",     "¨",
	"copy;",    "©",	"ordf;",    "ª",	"laquo;",   "«",	"not;",     "¬",
	"shy;",     "-",	"reg;",     "®",	"macr;",    "¯",	"deg;",     "°",
	"plusmn;",  "±",	"sup2;",    "²",	"sup3;",    "³",	"acute;",   "´",
	"micro;",   "µ",	"para;",    "¶",	"middot;",  "·",	"cedil;",   "¸",
	"sup1;",    "¹",	"ordm;",    "º",	"raquo;",   "»",	"frac14;",  "¼",
	"frac12;",  "½",	"frac34;",  "¾",	"iquest;",  "¿",	"Agrave;",  "À",
	"Aacute;",  "Á",	"Acirc;",   "Â",	"Atilde;",  "Ã",	"Auml;",    "Ä",
	"Aring;",   "Å",	"AElig;",   "Æ",	"Ccedil;",  "Ç",	"Egrave;",  "È",
	"Eacute;",  "É",	"Ecirc;",   "Ê",	"Euml;",    "Ë",	"Igrave;",  "Ì",
	"Iacute;",  "Í",	"Icirc;",   "Î",	"Iuml;",    "Ï",	"ETH;",     "Ð",
	"Ntilde;",  "Ñ",	"Ograve;",  "Ò",	"Oacute;",  "Ó",	"Ocirc;",   "Ô",
	"Otilde;",  "Õ",	"Ouml;",    "Ö",	"times;",   "×",	"Oslash;",  "Ø",
	"Ugrave;",  "Ù",	"Uacute;",  "Ú",	"Ucirc;",   "Û",	"Uuml;",    "Ü",
	"Yacute;",  "Ý",	"THORN;",   "Þ",	"szlig;",   "ß",	"agrave;",  "à",
	"aacute;",  "á",	"acirc;",   "â",	"atilde;",  "ã",	"auml;",    "ä",
	"aring;",   "å",	"aelig;",   "æ",	"ccedil;",  "ç",	"egrave;",  "è",
	"eacute;",  "é",	"ecirc;",   "ê",	"euml;",    "ë",	"igrave;",  "ì",
	"iacute;",  "í",	"icirc;",   "î",	"iuml;",    "ï",	"eth;",     "ð",
	"ntilde;",  "ñ",	"ograve;",  "ò",	"oacute;",  "ó",	"ocirc;",   "ô",
	"otilde;",  "õ",	"ouml;",    "ö",	"divide;",  "÷",	"oslash;",  "ø",
	"ugrave;",  "ù",	"uacute;",  "ú",	"ucirc;",   "û",	"uuml;",    "ü",
	"yacute;",  "ý",	"thorn;",   "þ",	"yuml;",    "ÿ",	"OElig;",   "Œ",
	"oelig;",   "œ",	"Scaron;",  "Š",	"scaron;",  "š",	"Yuml;",    "Ÿ",
	"fnof;",    "ƒ",	"circ;",    "ˆ",	"tilde;",   "˜",	"Alpha;",   "Α",
	"Beta;",    "Β",	"Gamma;",   "Γ",	"Delta;",   "Δ",	"Epsilon;", "Ε",
	"Zeta;",    "Ζ",	"Eta;",     "Η",	"Theta;",   "Θ",	"Iota;",    "Ι",
	"Kappa;",   "Κ",	"Lambda;",  "Λ",	"Mu;",      "Μ",	"Nu;",      "Ν",
	"Xi;",      "Ξ",	"Omicron;", "Ο",	"Pi;",      "Π",	"Rho;",     "Ρ",
	"Sigma;",   "Σ",	"Tau;",     "Τ",	"Upsilon;", "Υ",	"Phi;",     "Φ",
	"Chi;",     "Χ",	"Psi;",     "Ψ",	"Omega;",   "Ω",	"alpha;",   "α",
	"beta;",    "β",	"gamma;",   "γ",	"delta;",   "δ",	"epsilon;", "ε",
	"zeta;",    "ζ",	"eta;",     "η",	"theta;",   "θ",	"iota;",    "ι",
	"kappa;",   "κ",	"lambda;",  "λ",	"mu;",      "μ",	"nu;",      "ν",
	"xi;",      "ξ",	"omicron;", "ο",	"pi;",      "π",	"rho;",     "ρ",
	"sigmaf;",  "ς",	"sigma;",   "σ",	"tau;",     "τ",	"upsilon;", "υ",
	"phi;",     "φ",	"chi;",     "χ",	"psi;",     "ψ",	"omega;",   "ω",
	"thetasym;","ϑ",	"upsih;",   "ϒ",	"piv;",     "ϖ",	"ensp;",    " ",
	"emsp;",    " ",	"thinsp;",  " ",	"zwnj;",    "" ,	"zwj;",     "" ,
	"lrm;",     "" ,	"rlm;",     "" ,	"ndash;",   "–",	"mdash;",   "—",
	"lsquo;",   "‘",	"rsquo;",   "’",	"sbquo;",   "‚",	"ldquo;",   "“",
	"rdquo;",   "”",	"bdquo;",   "„",	"dagger;",  "†",	"Dagger;",  "‡",
	"bull;",    "•",	"hellip;",  "…",	"permil;",  "‰",	"prime;",   "′",
	"Prime;",   "″",	"lsaquo;",  "‹",	"rsaquo;",  "›",	"oline;",   "‾",
	"frasl;",   "⁄",	"euro;",    "€",	"image;",   "ℑ",	"weierp;",  "℘",
	"real;",    "ℜ",	"trade;",   "™",	"alefsym;", "ℵ",	"larr;",    "←",
	"uarr;",    "↑",	"rarr;",    "→",	"darr;",    "↓",	"harr;",    "↔",
	"crarr;",   "↵",	"lArr;",    "⇐",	"uArr;",    "⇑",	"rArr;",    "⇒",
	"dArr;",    "⇓",	"hArr;",    "⇔",	"forall;",  "∀",	"part;",    "∂",
	"exist;",   "∃",	"empty;",   "∅",	"nabla;",   "∇",	"isin;",    "∈",
	"notin;",   "∉",	"ni;",      "∋",	"prod;",    "∏",	"sum;",     "∑",
	"minus;",   "−",	"lowast;",  "∗",	"radic;",   "√",	"prop;",    "∝",
	"infin;",   "∞",	"ang;",     "∠",	"and;",     "∧",	"or;",      "∨",
	"cap;",     "∩",	"cup;",     "∪",	"int;",     "∫",	"there4;",  "∴",
	"sim;",     "∼",	"cong;",    "≅",	"asymp;",   "≈",	"ne;",      "≠",
	"equiv;",   "≡",	"le;",      "≤",	"ge;",      "≥",	"sub;",     "⊂",
	"sup;",     "⊃",	"nsub;",    "⊄",	"sube;",    "⊆",	"supe;",    "⊇",
	"oplus;",   "⊕",	"otimes;",  "⊗",	"perp;",    "⊥",	"sdot;",    "⋅",
	"lceil;",   "⌈",	"rceil;",   "⌉",	"lfloor;",  "⌊",	"rfloor;",  "⌋",
	"lang;",    "<",	"rang;",    ">",	"loz;",     "◊",	"spades;",  "♠",
	"clubs;",   "♣",	"hearts;",  "♥",	"diams;",   "♦",

	/* MUST be last */
	NULL,       NULL,
};


/* Recursively decodes entity and character references and normalizes new lines.
set "type" to ...
'&' for general entity decoding,
'%' for parameter entity decoding (currently not needed),
'c' for cdata sections,
' ' for attribute normalization, or
'*' for non-cdata attribute normalization (currently not needed).
Returns s, or if the decoded string is longer than s, returns a malloced string
that must be freed.
Function based upon ezxml_decode() from the "ezxml" parser which is
Copyright 2004-2006 Aaron Voisine <aaron@voisine.org> */
static char* xml_decode(char* s, char type)
{
	char *e, *r = s, *m = s;
	long b, c, d, l;

	for (; *s; s++) { /* normalize line endings */
		while (*s == '\r') {
			*(s++) = '\n';
			if (*s == '\n') memmove(s, (s + 1), strlen(s));
		}
	}

	for (s = r; ; ) {
		while( *s && *s != '&' /*&& (*s != '%' || type != '%')*/ && !isspace(*s)) s++;

		if( ! *s )
		{
			break;
		}
		else if( type != 'c' && ! strncmp(s, "&#", 2) )
		{
			/* character reference */
			if (s[2] == 'x') c = strtol(s + 3, &e, 16); /* base 16 */
			else c = strtol(s + 2, &e, 10); /* base 10 */
			if (! c || *e != ';') { s++; continue; } /* not a character ref */

			if (c < 0x80) *(s++) = c; /* US-ASCII subset */
			else { /* multi-byte UTF-8 sequence */
				for (b = 0, d = c; d; d /= 2) b++; /* number of bits in c */
				b = (b - 2) / 5; /* number of bytes in payload */
				*(s++) = (0xFF << (7 - b)) | (c >> (6 * b)); /* head */
				while (b) *(s++) = 0x80 | ((c >> (6 * --b)) & 0x3F); /* payload */
			}

			memmove(s, strchr(s, ';') + 1, strlen(strchr(s, ';')));
		}
		else if( (*s == '&' && (type == '&' || type == ' ' /*|| type == '*'*/))
		    /*|| (*s == '%' && type == '%')*/ )
		{
			/* entity reference */
			for (b = 0; s_ent[b] && strncmp(s + 1, s_ent[b], strlen(s_ent[b])); b += 2)
				; /* find entity in entity list */

			if (s_ent[b++]) { /* found a match */
				if ((c = strlen(s_ent[b])) - 1 > (e = strchr(s, ';')) - s) {
					l = (d = (s - r)) + c + strlen(e); /* new length */
					r = (r == m) ? strcpy(malloc(l), r) : realloc(r, l);
					e = strchr((s = r + d), ';'); /* fix up pointers */
				}

				memmove(s + c, e + 1, strlen(e)); /* shift rest of string */
				strncpy(s, s_ent[b], c); /* copy in replacement text */
			}
			else s++; /* not a known entity */
		}
		else if ((type == ' ' /*|| type == '*'*/) && isspace(*s))
		{
			*(s++) = ' ';
		}
		else s++; /* no decoding needed */
	}

	/* normalize spaces for non-cdata attributes
	if (type == '*') {
		for (s = r; *s; s++) {
			if ((l = strspn(s, " "))) memmove(s, s + l, strlen(s + l) + 1);
			while (*s && *s != ' ') s++;
		}
		if (--s >= r && *s == ' ') *s = '\0';
	}*/

	return r;
}


/*******************************************************************************
 * Tools
 ******************************************************************************/


#define XML_WS "\t\r\n "


static void def_starttag_cb (void* userdata, const char* tag, char** attr) { }
static void def_endtag_cb   (void* userdata, const char* tag) { }
static void def_text_cb     (void* userdata, const char* text, int len) { }


static void call_text_cb(mrsaxparser_t* ths, char* text, size_t len, char type)
{
	if( text && len )
	{
		char bak = text[len], *text_new;

		text[len] = '\0';
		text_new = xml_decode(text, type);
		ths->m_text_cb(ths->m_userdata, text_new, len);
		if( text != text_new ) { free(text_new); }

		text[len] = bak;
	}
}


static void do_free_attr(char** attr, int* free_attr)
{
	/* "attr" are key/value pairs; the function frees the data if the corresponding bit in "free_attr" is set.
	(we need this as we try to use the strings from the "main" document instead of allocating small strings) */
	#define FREE_KEY    0x01
	#define FREE_VALUE  0x02
	int i = 0;
	while( attr[i] ) {
		if( free_attr[i>>1]&FREE_KEY   && attr[i]   ) { free(attr[i]);   }
		if( free_attr[i>>1]&FREE_VALUE && attr[i+1] ) { free(attr[i+1]); }
		i += 2;
	}
	attr[0] = NULL; /* set list to zero-length */
}


/*******************************************************************************
 * Main interface
 ******************************************************************************/


const char* mrattr_find(char** attr, const char* key)
{
	if( attr && key ) {
		int i = 0;
		while( attr[i] && strcmp(key, attr[i]) ) {
			i += 2;
		}

		if( attr[i] ) {
			return attr[i + 1];
		}
	}
	return NULL;
}


void mrsaxparser_init(mrsaxparser_t* ths, void* userdata)
{
	ths->m_userdata    = userdata;
	ths->m_starttag_cb = def_starttag_cb;
	ths->m_endtag_cb   = def_endtag_cb;
	ths->m_text_cb     = def_text_cb;
}


void mrsaxparser_set_tag_handler(mrsaxparser_t* ths, mrsaxparser_starttag_cb_t starttag_cb, mrsaxparser_endtag_cb_t endtag_cb)
{
	if( ths == NULL ) {
		return;
	}

	ths->m_starttag_cb = starttag_cb? starttag_cb : def_starttag_cb;
	ths->m_endtag_cb   = endtag_cb?   endtag_cb   : def_endtag_cb;
}


void mrsaxparser_set_text_handler (mrsaxparser_t* ths, mrsaxparser_text_cb_t text_cb)
{
	if( ths == NULL ) {
		return;
	}

	ths->m_text_cb = text_cb? text_cb : def_text_cb;
}


void mrsaxparser_parse(mrsaxparser_t* ths, const char* buf_start__)
{
	char bak, *buf_start, *last_text_start, *p;

	#define MAX_ATTR 100 /* attributes per tag - a fixed border here is a security feature, not a limit */
	char*   attr[(MAX_ATTR+1)*2]; /* attributes as key/value pairs, +1 for terminating the list */
	int     free_attr[MAX_ATTR]; /* free the value at attr[i*2+1]? */

	attr[0] = NULL; /* null-terminate list, this also terminates "free_values" */

	if( ths == NULL ) {
		return;
	}

	buf_start = safe_strdup(buf_start__); /* we make a copy as we can easily null-terminate tag names and attributes "in place" */
	last_text_start = buf_start;
	p               = buf_start;
	while( *p )
	{
		if( *p == '<' )
		{
			call_text_cb(ths, last_text_start, p - last_text_start, '&'); /* flush pending text */

			p++;
			if( strncmp(p, "!--", 3) == 0 )
			{
				/* skip <!-- ... --> comment
				 **************************************************************/

				p = strstr(p, "-->");
				if( p == NULL ) { goto cleanup; }
				p += 3;
			}
			else if( strncmp(p, "![CDATA[", 8) == 0 )
			{
				/* process <![CDATA[ ... ]]> text
				 **************************************************************/

				char* text_beg = p + 8;
				if( (p = strstr(p, "]]>"))!=NULL ) /* `]]>` itself is not allowed in CDATA and must be escaped by dividing into two CDATA parts  */ {
					call_text_cb(ths, text_beg, p-text_beg, 'c');
					p += 3;
				}
				else {
					call_text_cb(ths, text_beg, strlen(text_beg), 'c'); /* CDATA not closed, add all remaining text */
					goto cleanup;
				}
			}
			else if( strncmp(p, "!DOCTYPE", 8) == 0 )
			{
				/* skip <!DOCTYPE ...> or <!DOCTYPE name [ ... ]>
				 **************************************************************/

				while( *p && *p != '[' && *p != '>'  ) p++; /* search for [ or >, whatever comes first */
				if( *p == 0 ) {
					goto cleanup; /* unclosed doctype */
				}
				else if( *p == '[' ) {
					p = strstr(p, "]>"); /* search end of inline doctype */
					if( p == NULL ) {
						goto cleanup; /* unclosed inline doctype */
					}
					else {
						p += 2;
					}
				}
				else {
					p++;
				}
			}
			else if( *p == '?' )
			{
				/* skip <? ... ?> processing instruction
				 **************************************************************/

				p = strstr(p, "?>");
				if( p == NULL ) { goto cleanup; } /* unclosed processing instruction */
				p += 2;
			}
			else
			{
				p += strspn(p, XML_WS); /* skip whitespace between `<` and tagname */
				if( *p == '/' )
				{
					/* process </tag> end tag
					 **************************************************************/

					p++;
					p += strspn(p, XML_WS); /* skip whitespace between `/` and tagname */
					char* beg_tag_name = p;
					p += strcspn(p, XML_WS "/>"); /* find character after tagname */
					if( p != beg_tag_name )
					{
						bak = *p;
						*p = '\0'; /* null-terminate tag name temporary, eg. a covered `>` may get important downwards */
						mr_strlower_in_place(beg_tag_name);
						ths->m_endtag_cb(ths->m_userdata, beg_tag_name);
						*p = bak;
					}
				}
				else
				{
					/* process <tag attr1="val" attr2='val' attr3=val ..>
					 **************************************************************/

					do_free_attr(attr, free_attr);

					char* beg_tag_name = p;
					p += strcspn(p, XML_WS "/>"); /* find character after tagname */
					if( p != beg_tag_name )
					{
						char* after_tag_name = p;

						/* scan for attributes */
						int attr_index = 0;
						while( isspace(*p) ) { p++; } /* forward to first attribute name beginning */
						for( ; *p && *p != '/' && *p != '>'; attr_index += 2 )
						{
							char *beg_attr_name = p, *beg_attr_value = NULL, *beg_attr_value_new = NULL;

							p += strcspn(p, XML_WS "=/>"); /* get end of attribute name */
							if( p != beg_attr_name )
							{
								/* attribute found */
								char* after_attr_name = p;
								p += strspn(p, XML_WS); /* skip whitespace between attribute name and possible `=` */
								if( *p == '=' )
								{
									p += strspn(p, XML_WS "="); /* skip spaces and equal signs */
									char quote = *p;
									if( quote == '"' || quote == '\'' )
									{
										/* quoted attribute value */
										p++;
										beg_attr_value = p;

										while( *p && *p != quote ) { p++; }
										if( *p ) {
											*p = '\0'; /* null terminate attribute val */
											p++;
										}

										beg_attr_value_new = xml_decode(beg_attr_value, ' ');
									}
									else
									{
										/* unquoted attribute value, as the needed null-terminated may overwrite important characters, we'll create a copy */
										beg_attr_value = p;
										p += strcspn(p, XML_WS "/>"); /* get end of attribute value */
										bak = *p;
										*p = '\0';
											char* temp = safe_strdup(beg_attr_value);
											beg_attr_value_new = xml_decode(temp, ' ');
											if( beg_attr_value_new!=temp ) { free(temp); }
										*p = bak;
									}
								}
								else
								{
									beg_attr_value_new = safe_strdup(NULL);
								}

								/* add attribute */
								if( attr_index < MAX_ATTR )
								{
									char* beg_attr_name_new = beg_attr_name;
									int   free_bits = (beg_attr_value_new != beg_attr_value)? FREE_VALUE : 0;
									if( after_attr_name == p ) {
										/* take care not to overwrite the current pointer (happens eg. for `<tag attrWithoutValue>` */
										bak = *after_attr_name;
										*after_attr_name = '\0';
										beg_attr_name_new = safe_strdup(beg_attr_name);
										*after_attr_name = bak;
										free_bits |= FREE_KEY;
									}
									else {
										*after_attr_name = '\0';
									}

									mr_strlower_in_place(beg_attr_name_new);
									attr[attr_index]         = beg_attr_name_new;
									attr[attr_index+1]       = beg_attr_value_new;
									attr[attr_index+2]       = NULL; /* null-terminate list */
									free_attr[attr_index>>1] = free_bits;
								}
							}

							while( isspace(*p) ) { p++; } /* forward to attribute name beginning */
						}

						char bak = *after_tag_name; /* backup the character as it may be `/` or `>` which gets important downwards */
						*after_tag_name = 0;
						mr_strlower_in_place(beg_tag_name);
						ths->m_starttag_cb(ths->m_userdata, beg_tag_name, attr);
						*after_tag_name = bak;

						/* self-closing tag */
						p += strspn(p, XML_WS); /* skip whitespace before possible `/` */
						if( *p == '/' )
						{
							p++;
							*after_tag_name = 0;
							ths->m_endtag_cb(ths->m_userdata, beg_tag_name); /* already lowercase from starttag_cb()-call */
						}
					}

				} /* end of processing start-tag */

				p = strchr(p, '>');
				if( p == NULL ) { goto cleanup; } /* unclosed start-tag or end-tag */
				p++;

			} /* end of processing start-tag or end-tag */

			last_text_start = p;
		}
		else
		{
			p++;
		}
	}

	call_text_cb(ths, last_text_start, p - last_text_start, '&'); /* flush pending text */

cleanup:
	do_free_attr(attr, free_attr);
	free(buf_start);
}

