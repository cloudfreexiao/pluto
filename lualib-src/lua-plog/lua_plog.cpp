
#include <lua.hpp>
#include <plog/Formatters/TxtFormatter.h>
#include <plog/Initializers/ConsoleInitializer.h>
#include <plog/Log.h>


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