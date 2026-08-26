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
 
    BYTE three[14] = { 0xC7, 0x86, 0xD0, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0x90, 0x90, 0x90 };
    DWORD address3 = moduleBase + 0xdcbd3;
    if (!patchBytes((void*)address3, three, 14)) {
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

bool Patches::historicalModelLogicFix(uintptr_t moduleBase) {
    BYTE one[2] = { 0xEB, 0x2A };
    DWORD address1 = moduleBase + 0x1832A8;
    if (!patchBytes((void*)address1, one, 2)) {
        return 0;
    }

    BYTE two[6] = { 0xC7, 0xC1, 0x00, 0x00, 0x10, 0x00 };
    DWORD address2 = moduleBase + 0x1832D4;
    if (!patchBytes((void*)address2, two, 6)) {
        return 0;
    }

    BYTE three[2] = { 0xEB, 0xCE };
    DWORD address3 = moduleBase + 0x1832DA;
    if (!patchBytes((void*)address3, three, 2)) {
        return 0;
    }
    return 1;
}

/**
 * Makes the Simplified Terrain map mode colour the sea as well as the land.
 *
 * That map mode's colouring loop already visits all 3,547 sea provinces and works out
 * a colour for each. The water ignores those colours, because the water is drawn by a
 * shader of its own that comes in two forms: water.fx compiles every technique twice,
 * once plainly and once with PROVINCE_COLOR defined, and only the second samples the
 * province colour textures and mixes them into the water.
 *
 * Which of the two is used comes down to a single style number the map mode setter
 * writes to the graphics settings at +0xF4. The renderer tests it in two places - once
 * to decide whether to refill the sea's colour texture at all, and once to pick
 * WaterNearColor over WaterNear - and both accept only 16, 18 and 19. Air writes 18
 * and Naval writes 19, which is why the sea is coloured in those two modes. Simplified
 * Terrain writes 8.
 *
 * Changing that 8 is the whole patch. Any of 16, 18 and 19 produces a coloured sea;
 * 18 is the air map mode's value. Only this map mode's setter is touched, so
 * Infrastructure, which writes the same 8 from a setter of its own, keeps plain water.
 *
 * reversing/FINDINGS-mapmode.md traces the path from the colour store to the shader.
 */
bool Patches::seaTerrainColourInSimplifiedMapMode(uintptr_t moduleBase) {
    // mov dword ptr [eax+0xF4], 8 - the last of three settings the Simplified Terrain
    // setter writes, at the point where it has the settings object in eax.
    const DWORD address = moduleBase + 0x266E74;
    const BYTE expected[10] = { 0xC7, 0x80, 0xF4, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00 };

    // The whole instruction is verified before any of it is changed, so a build that
    // does not carry it at this address is left alone rather than corrupted.
    for (int i = 0; i < 10; i++) {
        if (*(BYTE*)(address + i) != expected[i]) {
            std::cout << "seaTerrainColourInSimplifiedMapMode: the map mode setter is "
                "not what this build expects" << std::endl;
            return 0;
        }
    }

    BYTE style[1] = { 0x12 };   // 18, the number the air map mode uses
    return patchBytes((void*)(address + 6), style, 1);
}
