#include <lua.hpp>
#include <CasualLibrary.hpp>

#include <iostream>
#include <intrin.h>
#include <processthreadsapi.h>
#include <chrono>

int DATA_SECTION_START = 0x12F5000;

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
    Memory::External external = Memory::External(GetCurrentProcessId(), true);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    std::cout << modulePtr.get() << std::endl;

    long x = external.read<long>(modulePtr.get() + 0x11C1BA8, true);
    testHeaps(external);

    lua_pushstring(L, "a");
    lua_pushstring(L, "b");
    lua_pushstring(L, "c");
    return 3; // Return N values from the function stack to the caller (LUA)
}

static void traverseFlagsAndVarTreeDepthFirst(Memory::External& external, std::vector<std::uintptr_t>* res, uintptr_t nodePtr) {
    if (nodePtr == 0) {
        return;
    }
    uintptr_t element = external.read<uintptr_t>(nodePtr);
    char character = external.read<char>(nodePtr + 0x4);
    uintptr_t sibling = external.read<uintptr_t>(nodePtr + 0xC);
    uintptr_t child = external.read<uintptr_t>(nodePtr + 0x10);
    //std::cout << "nodePtr: " << Memory::n2hexstr(nodePtr) 
    //    << " char: " << character 
    //    << " element: " << Memory::n2hexstr(element) 
    //    << " sibling: " << Memory::n2hexstr(sibling) 
    //    << " child: " << Memory::n2hexstr(child) << std::endl;
    if (element != 0) {
        //std::cout << "element" << std::endl;
        res->push_back(element);
    }
    if (child != 0) {
        //std::cout << "child" << std::endl;
        traverseFlagsAndVarTreeDepthFirst(external, res, child);
    }
    if (sibling != 0) {
        //std::cout << "sibling " << sibling << std::endl;
        traverseFlagsAndVarTreeDepthFirst(external, res, sibling);
    }
}

std::vector<std::string>* getFlags(Memory::External& external, uintptr_t nodePtr) {
    std::vector<std::uintptr_t>* ptrs = new std::vector<std::uintptr_t>;
    traverseFlagsAndVarTreeDepthFirst(external, ptrs, nodePtr);
    //std::cout << "ptrs->size(): " << ptrs->size() << std::endl;
    std::vector<std::string>* res = new std::vector<std::string>;
    for (auto& i : *ptrs) {
        std::string x = external.readStringMaybePtr(i);
        res->push_back(x);
        //std::cout << n2hexstr(i) << " - " << x << std::endl;
    }
    delete ptrs;
    return res;
}

__declspec(dllexport) int getCountryFlags(lua_State* L)
{
    //std::cout << "getCountryFlags called" << std::endl;
    std::string searchTag = luaL_checklstring(L, 1, NULL);
    //std::cout << "searchTag: " << searchTag << std::endl;

    Memory::External external = Memory::External(GetCurrentProcessId(), true);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    //std::cout << "modulePtr: " << Memory::n2hexstr(modulePtr.get()) << std::endl;

    auto ctry = external.findCountryInstance(modulePtr.get() + DATA_SECTION_START, searchTag);

    uintptr_t flagsOffset = ctry + 0x180 + 0x4; // CFlagsVFTable + Flag Tree beginning
    uintptr_t flagsPtr = external.read<uintptr_t>(flagsOffset);
    //std::cout << "flagsPtr: " << Memory::n2hexstr(flagsPtr) << std::endl;

    auto flags = getFlags(external, flagsPtr);
    //std::cout << "flags->size(): " << flags->size() << std::endl;

    lua_createtable(L, flags->size(), 0);
    for (int i = 0; i < flags->size(); i++) {
        lua_pushstring(L, flags->at(i).c_str());
        lua_rawseti(L, -2, i + 1); /* In lua indices start at 1 */
    }
    delete flags;
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