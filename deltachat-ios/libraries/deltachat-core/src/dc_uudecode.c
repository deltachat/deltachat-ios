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


#include "dc_context.h"
#include "dc_uudecode.h"


/**
 * This function takes a text and returns this text stripped by the first uuencoded part;
 * the uuencoded part itself is returned by three return parameters.
 *
 * If there are no uuencoded parts, the function terminates fast by returning NULL.
 *
 * @param text Null-terminated text to search uuencode parts in.
 *     The text is not modified, instead, the modified text is returned on success.
 * @param[out] ret_binary Points to a pointer that is set to the binary blob on
 *     success.
 *     The data is allocated with malloc() and must be free()'d by the caller.
 *     If no uuencoded part is found, this parameter is set to NULL and the function returns NULL.
 * @param[out] ret_binary_bytes Points to an integer that should be set to
 *     binary blob bytes on success.
 * @param[out] ret_filename Points to a pointer that should be set to the filename of the blob.
 *     The data is allocated with malloc() and must be free()'d by the caller.
 *     If no uuencoded part is found, this parameter is set to NULL and the function returns NULL.
 * @return If uuencoded parts are found in the given text, the function returns the
 *     given text stripped by the first uuencode block.
 *     The caller will call dc_uudecode_do() again with this remaining text then.
 *     This way, multiple uuencoded parts can be stripped from a text.
 *     If no uuencoded parts are found or on errors, NULL is returned.
 */
char* dc_uudecode_do(const char* text, char** ret_binary, size_t* ret_binary_bytes, char** ret_filename)
{
	// CAVE: This function may be called in a loop until it returns NULL, so make sure not to create an invinitive look.

	if (text == NULL || ret_binary == NULL || ret_binary_bytes == NULL || ret_filename == NULL) {
		goto cleanup; // bad parameters
	}

cleanup:
	return NULL;
}


