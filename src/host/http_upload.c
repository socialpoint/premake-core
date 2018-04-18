/**
 * \file   http_upload.c
 * \brief  HTTP put request to upload a file support using libcurl.
 * \author Copyright (c) 2018 Social Point, Miguel Ibero and the Premake project
 */

#include "premake.h"
#include "curl_utils.h"

#ifdef PREMAKE_CURL

int http_upload(lua_State* L)
{
	curl_state state;
	CURL* curl;
	CURLcode code = CURLE_FAILED_INIT;
	FILE* fp;

	const char* file = luaL_checkstring(L, 2);
	fp = fopen(file, "rb");
	if (!fp)
	{
		lua_pushstring(L, "Unable to open file.");
		lua_pushnumber(L, -1);
		return 2;
	}

	// http.upload(url, filepath, { options })
	curl = curlRequest(L, &state, /*optionsIndex=*/3, /*progressFnIndex=*/0, /*headersIndex=*/0);
	if (curl)
	{

		curl_easy_setopt(curl, CURLOPT_UPLOAD, 1);
		curl_easy_setopt(curl, CURLOPT_READDATA, fp);

		code = curl_easy_perform(curl);
	}

	fclose(fp);

	lua_pushlstring(L, state.S.data, state.S.length);
	return 1+curlRequestFinish(L, &state, curl, code);
}

#endif
