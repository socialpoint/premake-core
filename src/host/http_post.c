/**
 * \file   http_post.c
 * \brief  HTTP post request support using libcurl.
 * \author Copyright (c) 2017 Blizzard Entertainment, João Matos and the Premake project
 */

#include "premake.h"
#include "curl_utils.h"

#ifdef PREMAKE_CURL

int http_post(lua_State* L)
{
	curl_state state;
	CURL* curl;
	CURLcode code = CURLE_FAILED_INIT;

	// http.post(source, postdata, { options })
	curl = curlRequest(L, &state, /*optionsIndex=*/3, /*progressFnIndex=*/0, /*headersIndex=*/0);
	if (curl)
	{
		size_t dataSize;
		const char* data = luaL_checklstring(L, 2, &dataSize);

		curl_easy_setopt(curl, CURLOPT_POST, 1);
		if (data && dataSize > 0)
		{
			curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)dataSize);
			curl_easy_setopt(curl, CURLOPT_POSTFIELDS, data);
		}

		code = curl_easy_perform(curl);
	}

	lua_pushlstring(L, state.S.data, state.S.length);
	return 1+curlRequestFinish(L, &state, curl, code);
}

#endif
