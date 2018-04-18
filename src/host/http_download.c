/**
* \file   http_download.c
* \brief  HTTP download support using libcurl.
* \author Copyright (c) 2017 Blizzard Entertainment, João Matos and the Premake project
*/

#include "premake.h"
#include "curl_utils.h"

#ifdef PREMAKE_CURL

static size_t curl_file_cb(void *ptr, size_t size, size_t nmemb, FILE *stream)
{
	return fwrite(ptr, size, nmemb, stream);
}

int http_download(lua_State* L)
{
	curl_state state;
	CURL* curl;
	CURLcode code = CURLE_FAILED_INIT;

	FILE* fp;
	const char* file = luaL_checkstring(L, 2);

	fp = fopen(file, "wb");
	if (!fp)
	{
		lua_pushstring(L, "Unable to open file.");
		lua_pushnumber(L, -1);
		return 2;
	}

	if (lua_istable(L, 3))
	{
		// http.download(source, destination, { options })
		curl = curlRequest(L, &state, /*optionsIndex=*/3, /*progressFnIndex=*/0, /*headersIndex=*/0);
	}
	else
	{
		// backward compatible function signature
		// http.download(source, destination, progressFunction, { headers })
		curl = curlRequest(L, &state, /*optionsIndex=*/0, /*progressFnIndex=*/3, /*headersIndex=*/4);
	}

	if (curl)
	{
		curl_easy_setopt(curl, CURLOPT_HTTPGET, 1);
		curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_file_cb);

		code = curl_easy_perform(curl);
	}

	fclose(fp);

	return curlRequestFinish(L, &state, curl, code);
}

#endif
