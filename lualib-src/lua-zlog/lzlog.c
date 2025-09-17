#include "lzlog.h"

/***
 * @function zlog.init(confpath)
 * @desc Initialize zlog.
 * @param confpath[string] - zlog conf path
 * @return zlog[zlog] - zlog context that cab ne used to create a category
*/
LUALIB_API int lzlog_init(lua_State* L) {
    const char* confpath = luaL_checkstring(L, 1);
    int rc = zlog_init(confpath);
    lzlog_assert(L, rc == 0, "Failed to initialized zlog");
    lzlog* z = (lzlog*)lua_newuserdata(L, sizeof(lzlog));
    z->confpath = confpath;
    z->init = 1;
    lzlog_setmeta(L, "zlog");
    return 1;
}

lzlog* lzlog_check(lua_State* L, int index) {
    lzlog* z = (lzlog*)luaL_checkudata(L, index, LZLOG_MT);
    luaL_argcheck(L, z != NULL && z->confpath != NULL, index, LZLOG_MT " expected");
    return z;
}

LUALIB_API int lzlog_index(lua_State* L) {
    const char* key = luaL_checkstring(L, 2);
    lua_getmetatable(L, 1);
    lua_getfield(L, -1, key);
    /* return if the key present in the metatable */
    if (!lua_isnil(L, -1)) {
        return 1;
    }
    return 0;
}

LUALIB_API int lzlog_gc(lua_State* L) {
    lzlog* self = lzlog_check(L, 1);
    if (self->confpath != NULL) {
        zlog_fini();
        self->confpath = NULL;
        self->init = 0;
    }
    return 0;
}

lzlog_category* lzlog_category_check(lua_State* L, int index) {
    lzlog_category* c = (lzlog_category*)luaL_checkudata(L, index, LZLOG_CATEGORY_MT);
    luaL_argcheck(
        L,
        c != NULL && c->name != NULL && c->category != NULL,
        index,
        LZLOG_CATEGORY_MT " expected"
    );
    return c;
}
/* category */
/***
 * @function zlog:category(name), zlog:get_category(name)
 * @desc Create and return a category context.
 * @param name[string] - Category name
 * @return category[zlog.category] - zlog category instance.
*/
LUALIB_API int lzlog_category_new(lua_State* L) {
    lzlog* self = lzlog_check(L, 1);
    lzlog_assert(L, self->init == 1, "Not initialized"); //not really neeed.
    const char* name = luaL_checkstring(L, 2);
    lzlog_category* c = (lzlog_category*)lua_newuserdata(L, sizeof(lzlog_category));
    c->category = zlog_get_category(name);
    c->name = name;
    lzlog_setmeta(L, LZLOG_CATEGORY_MT);
    return 1;
}

LUALIB_API int lzlog_category_index(lua_State* L) {
    const char* key = luaL_checkstring(L, 2);
    lua_getmetatable(L, 1);
    lua_getfield(L, -1, key);
    /* return if the key present in the metatable */
    if (!lua_isnil(L, -1)) {
        return 1;
    }
    return 0;
}

LUALIB_API int lzlog_category_gc(lua_State* L) {
    lzlog_category* self = lzlog_category_check(L, 1);
    /* zlog_fini clears the categories allocation, the zlog_category_del is not exposed */
    if (self->name != NULL) {
        self->name = NULL;
    }
    return 0;
}

/***
 * @function category:fatal(message)
 * @desc log fatal message
 * @params message[string]
*/
LUALIB_API int lzlog_category_fatal(lua_State* L) {
    lzlog_category* self = lzlog_category_check(L, 1);
    const char* message = lua_tostring(L, 2);
    zlog_fatal(self->category, message);
    return 0;
}

/***
 * @function category:error(message)
 * @desc log error message
 * @params message[string]
*/
LUALIB_API int lzlog_category_error(lua_State* L) {
    lzlog_category* self = lzlog_category_check(L, 1);
    const char* message = lua_tostring(L, 2);
    zlog_error(self->category, message);
    return 0;
}

/***
 * @function category:warn(message)
 * @desc log warn message
 * @params message[string]
*/
LUALIB_API int lzlog_category_warn(lua_State* L) {
    lzlog_category* self = lzlog_category_check(L, 1);
    const char* message = lua_tostring(L, 2);
    zlog_warn(self->category, message);
    return 0;
}

/***
 * @function category:notice(message)
 * @desc log notice message
 * @params message[string]
*/
LUALIB_API int lzlog_category_notice(lua_State* L) {
    lzlog_category* self = lzlog_category_check(L, 1);
    const char* message = lua_tostring(L, 2);
    zlog_notice(self->category, message);
    return 0;
}

/***
 * @function category:debug(message)
 * @desc log debug message
 * @params message[string]
*/
LUALIB_API int lzlog_category_debug(lua_State* L) {
    lzlog_category* self = lzlog_category_check(L, 1);
    const char* message = lua_tostring(L, 2);
    zlog_debug(self->category, message);
    return 0;
}

/***
 * @function category:info(message)
 * @desc log info message
 * @params message[string]
*/
LUALIB_API int lzlog_category_info(lua_State* L) {
    lzlog_category* self = lzlog_category_check(L, 1);
    const char* message = lua_tostring(L, 2);
    zlog_info(self->category, message);
    return 0;
}

LUALIB_API int luaopen_zlog(lua_State* L) {
    lua_newtable(L);
    luaL_setfuncs(L, lzlog_funcs, 0);
    lua_pushliteral(L, LZLOG_VERSION);
    lua_setfield(L, -2, "_VERSION");
    lua_pushliteral(L, LZLOG_COPYRIGHT);
    lua_setfield(L, -2, "_COPYRIGHT");
    lua_pushliteral(L, LZLOG_DESCRIPTION);
    lua_setfield(L, -2, "_DESCRIPTION");
    /* push metatables */
    lzlog_createmeta(L, LZLOG_MT, lzlog_methods);
    lzlog_createmeta(L, LZLOG_CATEGORY_MT, lzlog_category_methods);
    return 1;
}
