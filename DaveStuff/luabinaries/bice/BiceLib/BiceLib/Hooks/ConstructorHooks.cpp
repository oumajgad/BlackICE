#include <Hooks/ConstructorHooks.hpp>
#include <GameClasses/CCountry.hpp>

DWORD Hooks::Constructors::jumpback_CCountryHook;

__declspec(naked) void Hooks::Constructors::CCountryHook() {
    _asm {
        mov eax, [ebx + 0x1e8] // get country ID
        mov [CCountry::CountryPtrs + eax * 4], ebx // mov country ptr to array index

        // original code
        mov ecx, [ebp + -0xc]
        pop edi
        pop esi
        jmp[Hooks::Constructors::jumpback_CCountryHook]
    }
}
