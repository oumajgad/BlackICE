#include <Windows.h>
#include <string>
#include <iostream>

#include <HoiDataStructures.hpp>
#include <utils.hpp>

#include <Hooks/Hooks.hpp>
#include <Hooks/CArmyHooks.hpp>

// Jumpbacks
DWORD Hooks::CArmy::jumpBack_unitAttachmentLimitHook;

// Activation vars
bool Hooks::CArmy::isUnitAttachmentLimitHookActive = false;


DWORD handle(DWORD currentlyAttachedUnitAmount, DWORD* unitToAttach, DWORD* lastCountedUnit) {
    DEBUG_OUT(printf("attachedUnitAmount: %d \n", (unsigned int)currentlyAttachedUnitAmount));

    char* unitToAttachName = utils::getCString(unitToAttach + (0x16c / 4));
    DEBUG_OUT(printf("unitToAttachName: %s \n", unitToAttachName));
    //char* lastCountedUnitName = utils::getCString(lastCountedUnit + (0x16c / 4));
    //DEBUG_OUT(printf("lastCountedUnitName: %s \n", lastCountedUnitName));

    DWORD* higherUnit = (DWORD*)*(lastCountedUnit + (0x1e0/4));
    //DEBUG_OUT(printf("higherUnit: %#010x \n", (unsigned int) higherUnit));
    if (higherUnit != 0) {
        char* higherUnitName = utils::getCString(higherUnit + (0x16c / 4));
        DEBUG_OUT(printf("higherUnitName: %s \n", higherUnitName));
    }
    return 10;
}

__declspec(naked) void Hooks::CArmy::unitAttachmentLimitHook() {
    DWORD currentlyAttachedUnitAmount;
    DWORD newLimit;
    DWORD* unitToAttach; // EBX
    DWORD* lastCountedUnit; // ECX 
    // The attached unit of the higher unit which was last counted -> use it to get a pointer to the higher unit // If it is 0 then the function has already exited (0x1b9705)

    _asm {
        pushad
        push ebp
        mov ebp, esp
        sub esp, __LOCAL_SIZE
        mov esi, [ebp + 0x38]
        mov[currentlyAttachedUnitAmount], esi
        mov[unitToAttach], ebx
        mov[lastCountedUnit], ecx
    }

    if (Hooks::CArmy::isUnitAttachmentLimitHookActive) {
        newLimit = handle(currentlyAttachedUnitAmount, unitToAttach, lastCountedUnit);
    }

    _asm {
        mov edi, [newLimit]
        mov esp, ebp
        pop ebp
        cmp[ebp + 0x8],edi
        popad
        pop edi
        jmp[Hooks::CArmy::jumpBack_unitAttachmentLimitHook]
    }
}

