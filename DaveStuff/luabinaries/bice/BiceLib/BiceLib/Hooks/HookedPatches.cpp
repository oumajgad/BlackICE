#include <Hooks/HookedPatches.hpp>
#include <utils.hpp>

DWORD Hooks::Patches::jumpback_fixOffmapIc_CountLocalIc;
DWORD Hooks::Patches::jumpback_fixOffmapIc_SetBaseIc;

int Hooks::Patches::localIcEffectPerCountry[300]; // x1000
__declspec(naked) void Hooks::Patches::fixOffmapIc_CountLocalIc() {
    _asm {
        pushad
        mov esi, [esi + 0x114] // province modifiers
        mov esi, [esi + 0x78]  // province base_ic
        sub eax, esi           // sub base_ic from total_ic to get the local_ic effect value
        mov ebx, [ebx + 0xca8] // get country id
        add [localIcEffectPerCountry + ebx * 4], eax // add local_ic effect value to array

        popad
        mov ecx, [esi + 0x330]
        jmp[Hooks::Patches::jumpback_fixOffmapIc_CountLocalIc]
    }
}

int handle(DWORD* country, int baseIcWithOffmapButNoLocalx1000, int baseIcWithLocalButNoOffmap) {
    int countryId = *(country + 0xca8 / 4);
    DEBUG_OUT(printf("countryId: %i\n", countryId));
    //DEBUG_OUT(printf("baseIcWithOffmapButNoLocalx1000: %i\n", baseIcWithOffmapButNoLocalx1000));
    //DEBUG_OUT(printf("baseIcWithLocalButNoOffmap: %i\n", baseIcWithLocalButNoOffmap));

    int localIcEffect = Hooks::Patches::localIcEffectPerCountry[countryId];
    //DEBUG_OUT(printf("localIcEffect: %i\n", localIcEffect));
    Hooks::Patches::localIcEffectPerCountry[countryId] = 0; // zero local ic effect array for tomorrows iteration

    int baseBaseIC = baseIcWithLocalButNoOffmap - (localIcEffect / 1000);
    //DEBUG_OUT(printf("baseBaseIC: %i\n", baseBaseIC));

    int offmapIc = (baseIcWithOffmapButNoLocalx1000 / 1000) - baseBaseIC;
    DEBUG_OUT(printf("offmapIc: %i\n", offmapIc));

    DWORD* countryModifierIc = (DWORD*)(*(country + 0xda8 / 4) + 0x78);
    *countryModifierIc = offmapIc * 1000;

    return baseIcWithLocalButNoOffmap + offmapIc;
}

__declspec(naked) void Hooks::Patches::fixOffmapIc_SetBaseIc() {
    DWORD* country;
    int baseIcWithOffmapButNoLocalx1000;
    int baseIcWithLocalButNoOffmap;
    int result;

    _asm {
        pushad
        push ebp
        mov ebp, esp
        sub esp, __LOCAL_SIZE
        //mov edx, [ebx + 0xca8]
        mov[country], ebx
        mov edx, [ecx + 0x78]
        mov[baseIcWithOffmapButNoLocalx1000], edx
        mov[baseIcWithLocalButNoOffmap], eax
    }

    result = handle(country, baseIcWithOffmapButNoLocalx1000, baseIcWithLocalButNoOffmap);

    _asm {
        mov eax, result
        mov esp, ebp
        pop ebp
        mov[esp + 0x1c], eax
        popad
        mov[ebx + 0x604], eax
        jmp[Hooks::Patches::jumpback_fixOffmapIc_SetBaseIc]
    }

    /*
    _asm {
        pushad
        mov ebx, [ebx + 0xca8]                          // get country id
        mov eax, [localIcEffectPerCountry + ebx * 4]    // get local ic effects
        mov ecx, [ecx + 0x78]                           // get base ic + offmap ic value
        mov edx, [ebp + 0x8]                            // get base ic + local ic value
        sub edx, eax                                    // get pure base ic
        sub ecx, edx                                    // get pure offmap ic value
        add[ebp + 0x8], ecx                             // add pure offmap ic to base ic + local ic

        mov[localIcEffectPerCountry + ebx * 4], 0x0     // zero local ic effect array for tomorrows iteration
        popad
        mov eax, 0x10624dd3
        imul[ebp + 0x8]
        jmp[Hooks::Patches::jumpback_fixOffmapIc_SetBaseIc]
    }
    _asm {
        pushad
        pushfd
        mov ebx, [ebx + 0xca8]                          // get country id
        mov eax, [localIcEffectPerCountry + ebx * 4]    // get local ic effects
        mov ecx, [ecx + 0x78]                           // get base ic + offmap ic value
        mov edx, [ebp + 0x8]                            // get base ic + local ic value
        sub edx, eax                                    // get pure base ic
        sub ecx, edx                                    // get pure offmap ic value
        add[ebp + 0x8], ecx                             // add pure offmap ic to base ic + local ic

        mov[localIcEffectPerCountry + ebx * 4], 0x0     // zero local ic effect array for tomorrows iteration
        popfd
        popad
        mov eax, 0x10624dd3
        imul[ebp + 0x8]
        jmp[Hooks::Patches::jumpback_fixOffmapIc_SetBaseIc]
    }
    */

}