#include <string>
#include <iostream>
#include <vector>

#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>

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

