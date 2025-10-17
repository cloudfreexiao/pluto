#include <lua.hpp>

#include "quill.hpp"

extern "C" {
int luaopen_quill(lua_State* L) {
    luaL_Reg l[] = {
        { nullptr, nullptr },
    };
    luaL_newlib(L, l);
    return 1;
}
}