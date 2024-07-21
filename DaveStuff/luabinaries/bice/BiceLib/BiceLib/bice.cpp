#include <lua.hpp>
#include <Windows.h>
#include <processthreadsapi.h>
#include <memoryapi.h>


__declspec(dllexport) int hello(lua_State* L)
{
    lua_pushnumber(L, 1); // Add a value to the function stack
    lua_pushstring(L, "Hallo"); // Add a value to the function stack
    return 2; // Return N values from the function stack to the caller (LUA)
}

__declspec(dllexport) int goodbye(lua_State* L)
{
    return 0;
}

__declspec(dllexport) luaL_Reg BiceLib[] = {
    {"goodbye", goodbye},
    {"hello", hello},
    {NULL, NULL}
};

// #define new_lib(L, l) (lua_newtable(L), luaL_register(L, NULL, l))

extern "C"
__declspec(dllexport) int luaopen_BiceLib(lua_State* L)
{
    //    new_lib(L, test);
    lua_newtable(L);
    luaL_register(L, NULL, BiceLib);
    return 1;
}