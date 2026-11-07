#include <string>
#include <iostream>
#include <vector>

#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>

// Set as the DLL is loaded, so nothing can use it before it is right. It was set by a Lua
// call, setModuleBase, and every hook installed before that call wrote to the bare rva.
// The loader lock this runs under is the loader's own and is re-entrant, so asking for a
// module that is already loaded is safe here.
DWORD Hooks::MODULE_BASE = static_cast<DWORD>(Mem::moduleBase("hoi3_tfh.exe"));

bool Hooks::hook(void* hookAddress, void* hookFunc, int len, int NOPs) {
    if (len < 5 || NOPs < 0 || hookAddress == nullptr) {
        return false;
    }
    const SIZE_T size = static_cast<SIZE_T>(len + NOPs);
    unsigned char* const site = static_cast<unsigned char*>(hookAddress);

    DWORD protection = 0;
    if (!VirtualProtect(site, size, PAGE_EXECUTE_READWRITE, &protection)) {
        return false;
    }

    const DWORD relative = reinterpret_cast<DWORD>(hookFunc) - reinterpret_cast<DWORD>(site) - 5;
    site[0] = 0xE9; // jmp rel32
    *reinterpret_cast<DWORD*>(site + 1) = relative;
    for (int i = 0; i < NOPs; i++) {
        site[len + i] = 0x90;
    }

    DWORD unused = 0;
    VirtualProtect(site, size, protection, &unused);
    FlushInstructionCache(GetCurrentProcess(), site, size);
    return true;
}

bool Hooks::hookAt(uintptr_t site, void* stub, const unsigned char* expected, int length) {
    if (length < 5 || !bytesAre(site, expected, length)) {
        return false;
    }
    return hook(reinterpret_cast<void*>(site), stub, 5, length - 5);
}

bool Hooks::isCallTo(uintptr_t site, uintptr_t target) {
    unsigned char opcode = 0;
    int32_t relative = 0;
    if (!Mem::tryRead(site, opcode) || opcode != 0xE8) {
        return false;
    }
    if (!Mem::tryRead(site + 1, relative)) {
        return false;
    }
    return site + 5 + static_cast<uintptr_t>(static_cast<intptr_t>(relative)) == target;
}

bool Hooks::bytesAre(uintptr_t site, const unsigned char* expected, int length) {
    for (int i = 0; i < length; i++) {
        unsigned char byte = 0;
        if (!Mem::tryRead(site + i, byte) || byte != expected[i]) {
            return false;
        }
    }
    return true;
}
