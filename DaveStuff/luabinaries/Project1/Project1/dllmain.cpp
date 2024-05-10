#include <lua.hpp>
#include <Windows.h>
#include <processthreadsapi.h>
#include <memoryapi.h>


__declspec(dllexport) int hello(lua_State* L)
{
    auto handle = GetCurrentProcess();
    SIZE_T bytes_written;
    int address = 0xF0390;
    char buffer[] = { 0xF7, 0x69, 0x78 };
    WriteProcessMemory(handle, &address, &buffer, 3, &bytes_written);

    MessageBoxA(NULL, "homo", "yo", MB_OK); // Testing and shit.
    lua_pushnumber(L, bytes_written); // Add a value to the function stack
    lua_pushstring(L, ":^)"); // Add a value to the function stack
    return 2; // Return N values from the function stack to the caller (LUA)
}

__declspec(dllexport) int goodbye(lua_State* L)
{
    return 0;
}

__declspec(dllexport) luaL_Reg bice[] = {
    {"goodbye", goodbye},
    {"hello", hello},
    {NULL, NULL}
};

#define new_lib(L, l) (lua_newtable(L), luaL_register(L, NULL, l))

__declspec(dllexport) int luaopen_bice(lua_State* L)
{
    //    new_lib(L, test);
    lua_newtable(L);
    luaL_register(L, NULL, bice);
    return 1;
}