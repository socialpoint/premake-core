/**
 * \file   http_request.c
 * \brief  generic HTTP request support using libcurl.
 * \author Copyright (c) 2017 Blizzard Entertainment, João Matos and the Premake project
 */

#include "premake.h"
#include "curl_utils.h"
#include <string.h>

#ifdef PREMAKE_CURL

typedef struct
{
	const char* data;
	size_t len;
	size_t pos;
} curl_read_state;

size_t curl_read_cb(char *buffer, size_t size, size_t nitems, void *instream)
{
	curl_read_state* read_state = (curl_read_state*)instream;
	size_t curl_size = nitems * size;
	size_t max_size = read_state->len - read_state->pos;
	size_t copy_size = (max_size < curl_size) ? max_size : curl_size;
	memcpy(buffer, read_state->data + read_state->pos, copy_size);
	read_state->pos += copy_size;
	return copy_size;
}

static int curl_seek_cb(void *userp, curl_off_t offset, int origin)
{
	curl_read_state* read_state = (curl_read_state*)userp;
	curl_off_t p;
	switch(origin)
	{
		case SEEK_CUR:
			p = read_state->pos;
			break;
		case SEEK_END:
			p = read_state->len - 1;
			break;
		default:
			p = 0;
			break;
	}
	p += offset;
	if(p < 0 || p >= read_state->len)
	{
		return CURL_SEEKFUNC_CANTSEEK;
	}
	read_state->pos = p;
	return CURL_SEEKFUNC_OK;
}

int http_request(lua_State* L)
{
	curl_state state;
	CURL* curl;
	CURLcode code = CURLE_FAILED_INIT;

	// http.request(method, url, bodydata, { options })

	const char* method = luaL_checkstring(L, 1);
	lua_remove(L, 1);
	curl = curlRequest(L, &state, /*optionsIndex=*/3, /*progressFnIndex=*/0, /*headersIndex=*/0);
	if (curl)
	{
		curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method);

		curl_read_state read_state;
		read_state.data = luaL_checklstring(L, 2, &read_state.len);
		read_state.pos = 0;
		if (read_state.data && read_state.len > 0)
		{
			curl_easy_setopt(curl, CURLOPT_UPLOAD, 1);
			curl_easy_setopt(curl, CURLOPT_INFILESIZE_LARGE, (curl_off_t)read_state.len);
			curl_easy_setopt(curl, CURLOPT_READDATA, &read_state);
			curl_easy_setopt(curl, CURLOPT_READFUNCTION, curl_read_cb);
			curl_easy_setopt(curl, CURLOPT_SEEKDATA, &read_state);
			curl_easy_setopt(curl, CURLOPT_SEEKFUNCTION, curl_seek_cb);
		}

		code = curl_easy_perform(curl);
	}

	lua_pushlstring(L, state.S.data, state.S.length);
	return 1+curlRequestFinish(L, &state, curl, code);
}

#endif
