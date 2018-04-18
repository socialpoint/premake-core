/**
* \file   http_get.c
* \brief  HTTP get request support using libcurl.
* \author Copyright (c) 2017 Blizzard Entertainment, João Matos and the Premake project
*/

#include "premake.h"
#include "curl_utils.h"

#ifdef PREMAKE_CURL

int http_get(lua_State* L)
{
	curl_state state;
	CURL* curl;
	CURLcode code = CURLE_FAILED_INIT;

	if (lua_istable(L, 2))
	{
		// http.get(source, { options })
		curl = curlRequest(L, &state, /*optionsIndex=*/2, /*progressFnIndex=*/0, /*headersIndex=*/0);
	}
	else
	{
		// backward compatible function signature
		// http.get(source, progressFunction, { headers })
		curl = curlRequest(L, &state, /*optionsIndex=*/0, /*progressFnIndex=*/2, /*headersIndex=*/3);
	}

	if (curl)
	{
		curl_easy_setopt(curl, CURLOPT_HTTPGET, 1);

		code = curl_easy_perform(curl);
	}

	lua_pushlstring(L, state.S.data, state.S.length);
	return 1+curlRequestFinish(L, &state, curl, code);
}

#endif
