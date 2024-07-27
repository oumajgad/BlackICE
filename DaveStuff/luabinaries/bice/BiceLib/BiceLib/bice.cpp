#include <lua.hpp>
#include <CasualLibrary.hpp>

#include <iostream>
#include <intrin.h>
#include <processthreadsapi.h>
#include <chrono>

int DATA_SECTION_START = 0x12F5000;


template <typename I> std::string n2hexstr(I w, size_t hex_len = sizeof(I) << 1) {
    static const char* digits = "0123456789ABCDEF";
    std::string rc(hex_len, '0');
    for (size_t i = 0, j = (hex_len - 1) * 4; i < hex_len; ++i, j -= 4)
        rc[i] = digits[(w >> j) & 0x0f];
    return rc;
}

std::string toSignature(std::string& str) {
    std::string res(8 + 3, '0'); // 8 chars + 3 spaces
    int offset = 0;
    for (int i = 0; i < 8; i++) {
        res[i + offset] = str[i];
        if (i == 1 || i == 3 || i == 5) {
            res[i + offset + 1] = ' ';
            offset++;
        }
    }
    return res;
}

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
    //std::cout << "nodePtr: " << n2hexstr(nodePtr) << " char: " << character << " element: " << n2hexstr(element) << " sibling: " << n2hexstr(sibling) << " child: " << n2hexstr(child) << std::endl;
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
    Memory::External external = Memory::External(GetCurrentProcessId(), true);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    std::cout << "Modulebase: " << n2hexstr(modulePtr.get()) << std::endl;

    std::cout << "getCountryFlags called" << std::endl;
    std::string searchTag = luaL_checklstring(L, 1, NULL);
    std::cout << "searchTag: " << searchTag << std::endl;

    uintptr_t CCountryVFTableAddr = modulePtr.get() + 0x11C1BA8;
    std::string x = n2hexstr(_byteswap_ulong(CCountryVFTableAddr));
    std::cout << "x: " << x << std::endl;
    auto sig = toSignature(x);
    std::cout << "sig: " << sig << std::endl;

    std::vector<uintptr_t>* sigs = external.findSignatures(modulePtr.get() + DATA_SECTION_START, sig.c_str(), 4, 128);
    std::cout << "sigs->size(): " << sigs->size() << std::endl;

    std::vector<std::string>* flags = new std::vector<std::string>;

    for (auto& country : *sigs) {
        std::string tag = external.readString(country + 0x1E4, 3);
        std::cout << n2hexstr(country) << " " << tag << std::endl;
        if (strcmp(tag.c_str(), searchTag.c_str()) == 0) {
            uintptr_t flagsOffset = country + 0x180 + 0x4; // CFlagsVFTable + Flag Tree beginning
            uintptr_t flagsPtr = external.read<uintptr_t>(flagsOffset);
            std::cout << "flagsPtr: " << n2hexstr(flagsPtr) << std::endl;

            auto flags = getFlags(external, flagsPtr);
            std::cout << "flags->size(): " << flags->size() << std::endl;

            lua_createtable(L, flags->size(), 0);
            for (int i = 0; i < flags->size(); i++) {
                lua_pushstring(L, flags->at(i).c_str());
                lua_rawseti(L, -2, i + 1); /* In lua indices start at 1 */
            }
            delete flags;
            break;
        }
    }
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