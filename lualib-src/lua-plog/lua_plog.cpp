
#include <lua.hpp>

// #include <plog/Formatters/TxtFormatter.h>
// #include <plog/Initializers/ConsoleInitializer.h>
// #include <plog/Log.h>

// #define set_field(f,v)          lua_pushliteral(L, v); \
//                                 lua_setfield(L, -2, f)

// #define add_constant(c)         lua_pushinteger(L, LOG_##c); \
//                                 lua_setfield(L, -2, #c)

extern "C" {
int luaopen_plog(lua_State* L) {
    luaL_Reg l[] = {
        // { "new", lnew },
        { nullptr, nullptr },
    };
    luaL_newlib(L, l);
    return 1;
}
}