#include <lua.hpp>

#include "spdlog/spdlog.h"


extern "C" {
int luaopen_spdlog(lua_State* L) {
    luaL_Reg l[] = {
        { nullptr, nullptr },
    };
    luaL_newlib(L, l);
    return 1;
}
}