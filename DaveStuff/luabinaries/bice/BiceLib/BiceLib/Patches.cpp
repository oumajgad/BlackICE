#include <Windows.h>
#include <iostream>
#include <Patches.hpp>


bool Patches::patchBytes(void* address, BYTE values[], int len) {
    //std::cout << "patchBytes" << std::endl;
    DWORD protection;
    auto vp1 = VirtualProtect(address, len, PAGE_EXECUTE_READWRITE, &protection);
    if (!vp1) {
        std::cout << "Changing protection failed" << std::endl;
        return 0;
    }
    for (int i = 0; i < len; i++) {
        //std::cout << "i: " << i << " address: " << (int)((DWORD)address + i) << " value: " << (int)(values[i]) << std::endl;
        *(BYTE*)((DWORD)address + i) = values[i];
    }

    DWORD trash;
    auto vp2 = VirtualProtect(address, len, protection, &trash);
    if (!vp2) {
        std::cout << "Resetting protection failed" << std::endl;
        return 0;
    }
    return 1;
}

bool Patches::fixOffMapIC(uintptr_t moduleBase) {
    BYTE one[3] = { 0xf7, 0x69, 0x78 };
    DWORD address1 = moduleBase + 0xf0f90;
    if (!patchBytes((void*)address1, one, 3)) {
        return 0;
    }

    BYTE two[6] = { 0x8b, 0x41, 0x78, 0x90, 0x90, 0x90 };
    DWORD address2 = moduleBase + 0xf0fa9;
    if (!patchBytes((void*)address2, two, 6)) {
        return 0;
    }
    return 1;
}

bool Patches::fixMinisterTechDecay(uintptr_t moduleBase) {
    BYTE one[1] = { 0x01 };
    DWORD address1 = moduleBase + 0xde3ed;
    if (!patchBytes((void*)address1, one, 1)) {
        return 0;
    }
    return 1;
}

bool Patches::disableWarExhaustionNeutralityReset(uintptr_t moduleBase) {
    BYTE one[1] = { 0x01 };
    DWORD address1 = moduleBase + 0xdcc12;
    if (!patchBytes((void*)address1, one, 1)) {
        return 0;
    }

    BYTE two[6] = { 0x90, 0x90, 0x90, 0x90, 0x90, 0x90 };
    DWORD address2 = moduleBase + 0xdcc18;
    if (!patchBytes((void*)address2, two, 6)) {
        return 0;
    }
    return 1;
}

bool Patches::disableInterAiExpeditionaries(uintptr_t moduleBase) {
    BYTE one[2] = { 0x90, 0xE9 };
    DWORD address1 = moduleBase + 0x4b348a;
    if (!patchBytes((void*)address1, one, 2)) {
        return 0;
    }

    BYTE two[2] = { 0x90, 0xE9 };
    DWORD address2 = moduleBase + 0x4b37e5;
    if (!patchBytes((void*)address2, two, 2)) {
        return 0;
    }
    return 1;
}