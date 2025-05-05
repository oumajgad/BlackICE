#include <Windows.h>
#include <string>
#include <iostream>

#include <utils.hpp>

#include <Hooks/Hooks.hpp>
#include <Hooks/CNavyHooks.hpp>

// Jumpbacks
DWORD Hooks::CNavy::origJmp_screenPenaltyHook;

// Activation vars
bool Hooks::CNavy::isNavyScreenPenaltyHookActive = false;

// Vars defaults
DWORD Hooks::CNavy::screenPenalty = 333; // => 33.3%
DWORD Hooks::CNavy::screensPerCapital = 1;


__declspec(naked) void Hooks::CNavy::screenPenaltyCalulation() {
    // EDX = capital_ships_amount
    // ESI = screens_amount
    // esp + 0x1c = effective screen penalty
    _asm {
        // Apply adjusted screen ratio
        imul edx, Hooks::CNavy::screensPerCapital
        cmp esi, edx // compare screens amount to adjusted capital amount
        jge[noScreenPenalty] // if more screen -> No penalty

        mov eax, Hooks::CNavy::screenPenalty
        mov [esp + 0x1c], eax
        jmp[Hooks::CNavy::origJmp_screenPenaltyHook]

        noScreenPenalty:
            jmp[Hooks::CNavy::origJmp_screenPenaltyHook]
    }
}

