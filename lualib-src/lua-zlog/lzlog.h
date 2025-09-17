#ifndef LZLOG_H
#define LZLOG_H

#include "lzlog_aux.h"
#include "zlog.h"

#define LZLOG_VERSION "lua-zlog 0.0.1"
#define LZLOG_COPYRIGHT "Copyright (c) 2017, Zaher Marzuq"
#define LZLOG_DESCRIPTION "Lua binding for zlog"

#define LZLOG_MT "zlog"
#define LZLOG_CATEGORY_MT "zlog.category"

LUALIB_API int lzlog_init(lua_State* L);
LUALIB_API int lzlog_index(lua_State* L);
LUALIB_API int lzlog_gc(lua_State* L);
/* category methods */
LUALIB_API int lzlog_category_new(lua_State* L);
LUALIB_API int lzlog_category_index(lua_State* L);
LUALIB_API int lzlog_category_gc(lua_State* L);
LUALIB_API int lzlog_category_fatal(lua_State* L);
LUALIB_API int lzlog_category_error(lua_State* L);
LUALIB_API int lzlog_category_warn(lua_State* L);
LUALIB_API int lzlog_category_notice(lua_State* L);
LUALIB_API int lzlog_category_info(lua_State* L);
LUALIB_API int lzlog_category_debug(lua_State* L);

typedef struct {
    const char* confpath;
    uint8_t init;
} lzlog;

typedef struct {
    zlog_category_t* category;
    const char* name;
} lzlog_category;

static const luaL_Reg lzlog_methods[] = { { "finish", lzlog_gc },
                                          { "category", lzlog_category_new },
                                          { "get_category", lzlog_category_new },
                                          { "__gc", lzlog_gc },
                                          { "__index", lzlog_index },
                                          { NULL, NULL } };

static const luaL_Reg lzlog_category_methods[] = {
    { "__gc", lzlog_category_gc },
    { "__index", lzlog_category_index },
    { "fatal", lzlog_category_fatal },
    { "error", lzlog_category_error },
    { "warn", lzlog_category_warn },
    { "notice", lzlog_category_notice },
    { "info", lzlog_category_info },
    { "debug", lzlog_category_debug },
    { NULL, NULL },
};

static const luaL_Reg lzlog_funcs[] = { { "init", lzlog_init }, { NULL, NULL } };

#endif
