#include <wtypes.h>
#include <lua.hpp>

#include <utils.hpp>

char* utils::getCString(DWORD* addr) {
    DWORD stringLength = *(addr + (0x10/4));
    char* res;
    if (stringLength > 15) {
        res = (char*)*addr;
    }
    else {
        res = (char*)addr;
    }
    return res;
}

lua_State* utils::LUA_STATE;
void utils::logInLua(lua_State* state, const char* toLog) {
    lua_getglobal(state, "BiceLibLuaLog");
    lua_pushstring(state, toLog);
    lua_pcall(state, 1, 0, 0);
    return;
}
