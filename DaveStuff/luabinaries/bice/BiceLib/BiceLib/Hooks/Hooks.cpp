#include <string>
#include <iostream>
#include <vector>

#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>

DWORD Hooks::MODULE_BASE;

bool Hooks::hook(void* hookAddress, void* hookFunc, int len, int NOPs) {
    if (len < 5) {
        return false;
    }
    else {
        DWORD protection;
        VirtualProtect(hookAddress, len + NOPs, PAGE_EXECUTE_READWRITE, &protection);

        DWORD relativeHookFuncAddress = ((DWORD)hookFunc - (DWORD)hookAddress) - 5;

        *(BYTE*)hookAddress = 0xE9; // JMP
        *(DWORD*)((DWORD)hookAddress + 1) = relativeHookFuncAddress;

        for (int i = 0; i < NOPs; i++) {
            *(BYTE*)((DWORD)hookAddress + len + i) = 0x90;
        }

        DWORD trash;
        VirtualProtect(hookAddress, len + NOPs, protection, &trash);
        return true;
    }
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
