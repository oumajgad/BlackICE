#include <lua.hpp>

#include <CasualLibrary.hpp>

#include <iostream>
#include <intrin.h>
#include <processthreadsapi.h>

int DATA_SECTION_START = 0x12F5000;

int RAM_GB_LIMIT = 0xFFFFFFFF; // 4GB Address space limit

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


__declspec(dllexport) int hello(lua_State* L)
{
    Memory::External external = Memory::External(GetCurrentProcessId(), true);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    std::cout << modulePtr.get() << std::endl;

    long x = external.read<long>(modulePtr.get() + 0x11C1BA8, true);

    std::string x_hex = n2hexstr(x);
    std::string x_hex_swapped = n2hexstr(_byteswap_ulong(x));

    std::cout << x << std::endl;
    std::cout << x_hex << std::endl;
    std::cout << x_hex_swapped << std::endl;


    std::string signature = toSignature(x_hex_swapped);
    std::cout << signature << std::endl;

    Address sig_address = external.findSignature(modulePtr.get() + DATA_SECTION_START, signature.c_str(), 256);
    std::cout << n2hexstr(sig_address.get()) << std::endl;


    lua_pushstring(L, x_hex.c_str());
    lua_pushstring(L, x_hex_swapped.c_str());
    lua_pushstring(L, n2hexstr(sig_address.get()).c_str());
    return 3; // Return N values from the function stack to the caller (LUA)
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