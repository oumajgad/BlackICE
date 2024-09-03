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


DWORD handle(DWORD currentlyAttachedUnitAmount) {
    DEBUG_OUT(printf("attachedUnitAmount: %d \n", (unsigned int)currentlyAttachedUnitAmount));
    return 10;
}

__declspec(naked) void Hooks::CArmy::unitAttachmentLimitHook() {
    DWORD currentlyAttachedUnitAmount;
    DWORD newLimit;
    _asm {
        pushad
        push    ebp
        mov     ebp, esp
        sub     esp, __LOCAL_SIZE
        mov     esi, [ebp + 0x38]
        mov     [currentlyAttachedUnitAmount], esi
    }

    if (Hooks::CArmy::isUnitAttachmentLimitHookActive) {
        newLimit = handle(currentlyAttachedUnitAmount);
    }

    _asm {
        mov      esp, ebp
        pop      ebp
        popad
        mov edi, [newLimit]
        cmp edi, [ebp + 0x8]
        pop edi
        jmp[Hooks::CArmy::jumpBack_unitAttachmentLimitHook]
    }
}

