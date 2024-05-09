#include <lauxlib.h>
#include <lua.h>
#include <Windows.h>

// Because This is Lua I do not think you need a DLLMain function
// https://learn.microsoft.com/en-us/cpp/build/reference/md-mt-ld-use-run-time-library?view=msvc-170&source=recommendations
__declspec(dllexport) int hello(lua_State* L)
{
    printf("hello!\n");
    MessageBoxA(NULL, "homo", "yo", MB_OK); // Testing and shit.
    lua_pushnumber(L, 1234); // Add a value to the function stack
    lua_pushstring(L, "testy"); // Add a value to the function stack
    return 2; // Return N values from the function stack to the caller (LUA)
}

__declspec(dllexport) int goodbye(lua_State* L)
{
    printf("goodbye!\n");
    return 0;
}

__declspec(dllexport) luaL_Reg bice_dll[] = {
    {"goodbye", goodbye},
    {"hello", hello},
    {NULL, NULL}
};

#define new_lib(L, l) (lua_newtable(L), luaL_register(L, NULL, l))

__declspec(dllexport) int luaopen_test(lua_State* L)
{
    //    new_lib(L, test);
    lua_newtable(L);
    luaL_register(L, NULL, bice_dll);
    return 1;
}