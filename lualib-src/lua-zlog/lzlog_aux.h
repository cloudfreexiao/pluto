#ifndef LZLOG_AUX_H
#define LZLOG_AUX_H
#include <string.h>
#include <lauxlib.h>

#if !defined LUA_VERSION_NUM || LUA_VERSION_NUM == 501
LUALIB_API void luaL_setfuncs(lua_State* L, const luaL_Reg* l, int nup);
#endif

void lzlog_setmeta(lua_State* L, const char* name);
void lzlog_createmeta(lua_State* L, const char* name, const luaL_Reg* methods);
void lzlog_error(lua_State* L, const char* msg);
void lzlog_assert(lua_State* L, int cond, const char* msg);

#endif
