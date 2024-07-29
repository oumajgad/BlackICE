#include <lua.hpp>
#include <CasualLibrary.hpp>

#include <iostream>
#include <intrin.h>
#include <processthreadsapi.h>
#include <chrono>

#include <CCountry.hpp>

int DATA_SECTION_START = 0x12F5000;
bool DEBUG = true;

void testHeaps(Memory::External external) {
    auto start1 = std::chrono::high_resolution_clock::now();
    auto regions1 = Memory::heapWalkExternal(external.handle);
    auto stop1 = std::chrono::high_resolution_clock::now();
    auto duration1 = std::chrono::duration_cast<std::chrono::microseconds>(stop1 - start1);
    std::cout << "External: " << regions1->size() << " - " << duration1.count() << std::endl;

    auto start2 = std::chrono::high_resolution_clock::now();
    auto regions2 = Memory::heapWalkInternal();
    auto stop2 = std::chrono::high_resolution_clock::now();
    auto duration2 = std::chrono::duration_cast<std::chrono::microseconds>(stop2 - start2);
    std::cout << "Internal: " << regions2->size() << " - " << duration2.count() << std::endl;
}


__declspec(dllexport) int hello(lua_State* L)
{
    Memory::External external = Memory::External(GetCurrentProcessId(), DEBUG);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    std::cout << modulePtr.get() << std::endl;

    long x = external.read<long>(modulePtr.get() + 0x11C1BA8, true);
    testHeaps(external);

    lua_pushstring(L, "a");
    lua_pushstring(L, "b");
    lua_pushstring(L, "c");
    return 3; // Return N values from the function stack to the caller (LUA)
}

__declspec(dllexport) int getCountryFlags(lua_State* L)
{
    //std::cout << "getCountryFlags called" << std::endl;
    std::string searchTag = luaL_checklstring(L, 1, NULL);
    //std::cout << "searchTag: " << searchTag << std::endl;

    Memory::External external = Memory::External(GetCurrentProcessId(), DEBUG);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    //std::cout << "modulePtr: " << Memory::n2hexstr(modulePtr.get()) << std::endl;

    auto ctry = external.findCountryInstance(modulePtr.get() + DATA_SECTION_START, searchTag);

    uintptr_t flagsOffset = ctry + 0x180 + 0x4; // CFlagsVFTable + Flag Tree beginning
    uintptr_t flagsPtr = external.read<uintptr_t>(flagsOffset);
    //std::cout << "flagsPtr: " << Memory::n2hexstr(flagsPtr) << std::endl;

    auto flags = CCountry::getFlags(external, flagsPtr);
    //std::cout << "flags->size(): " << flags->size() << std::endl;

    lua_createtable(L, flags->size(), 0);
    for (int i = 0; i < flags->size(); i++) {
        lua_pushstring(L, flags->at(i).c_str());
        lua_rawseti(L, -2, i + 1); /* In lua indices start at 1 */
    }

    delete flags;
    return 1;
}

__declspec(dllexport) int getCountryVariables(lua_State* L)
{
    //std::cout << "getCountryFlags called" << std::endl;
    std::string searchTag = luaL_checklstring(L, 1, NULL);
    //std::cout << "searchTag: " << searchTag << std::endl;

    Memory::External external = Memory::External(GetCurrentProcessId(), DEBUG);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    //std::cout << "modulePtr: " << Memory::n2hexstr(modulePtr.get()) << std::endl;

    auto ctr = external.findCountryInstance(modulePtr.get() + DATA_SECTION_START, searchTag);

    uintptr_t varsOffset = ctr + 0x1AC + 0x4; // CVariablesVFTable + Vars Tree beginning
    uintptr_t varsPtr = external.read<uintptr_t>(varsOffset);
    //std::cout << "varsPtr: " << Memory::n2hexstr(varsPtr) << std::endl;

    auto vars = CCountry::getVars(external, varsPtr);
    std::cout << "vars->size(): " << vars->size() << std::endl;

    lua_newtable(L, 0, vars->size());
    for (int i = 0; i < vars->size(); i++) {
        lua_pushstring(L, vars->at(i).name.c_str());
        lua_pushinteger(L, vars->at(i).value);
        lua_settable(L, -3);
    }

    delete vars;
    return 1;
}


__declspec(dllexport) int startConsole(lua_State* L)
{
    AllocConsole();
    FILE* fp;
    freopen_s(&fp, "CONOUT$", "w", stdout); // output only
    return 0;
}


__declspec(dllexport) luaL_Reg BiceLib[] = {
    {"getCountryFlags", getCountryFlags},
    {"getCountryVariables", getCountryVariables},
    {"hello", hello},
    {"startConsole", startConsole},
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