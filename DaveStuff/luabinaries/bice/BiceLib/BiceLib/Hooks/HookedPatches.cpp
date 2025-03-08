#include <Hooks/HookedPatches.hpp>
#include <utils.hpp>

DWORD Hooks::Patches::jumpback_fixOffmapIc_CountLocalIc;
DWORD Hooks::Patches::jumpback_fixOffmapIc_SetBaseIc;

int Hooks::Patches::localIcEffectPerCountry[300];   // x1000
int Hooks::Patches::offmapIcPerCountry[300];        // offmap IC to be used in Utility display
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

int handleOffmapIc(DWORD* country, int baseIcWithOffmapButNoLocalx1000, int baseIcWithLocalButNoOffmap) {
    int countryId = *(country + 0xca8 / 4);
    //DEBUG_OUT(printf("countryId: %i\n", countryId));
    //DEBUG_OUT(printf("baseIcWithOffmapButNoLocalx1000: %i\n", baseIcWithOffmapButNoLocalx1000));
    //DEBUG_OUT(printf("baseIcWithLocalButNoOffmap: %i\n", baseIcWithLocalButNoOffmap));

    int localIcEffect = Hooks::Patches::localIcEffectPerCountry[countryId];
    //DEBUG_OUT(printf("localIcEffect: %i\n", localIcEffect));
    Hooks::Patches::localIcEffectPerCountry[countryId] = 0; // zero local ic effect array for tomorrows iteration

    int baseBaseIC = baseIcWithLocalButNoOffmap - (localIcEffect / 1000);
    //DEBUG_OUT(printf("baseBaseIC: %i\n", baseBaseIC));

    int offmapIc = (baseIcWithOffmapButNoLocalx1000 / 1000) - baseBaseIC;
    Hooks::Patches::offmapIcPerCountry[countryId] = offmapIc;
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

    result = handleOffmapIc(country, baseIcWithOffmapButNoLocalx1000, baseIcWithLocalButNoOffmap);

    _asm {
        mov eax, result
        mov esp, ebp
        pop ebp
        mov[esp + 0x1c], eax
        popad
        mov[ebx + 0x604], eax
        jmp[Hooks::Patches::jumpback_fixOffmapIc_SetBaseIc]
    }
}

DWORD Hooks::Patches::jumpback_enablePlacingNonResearchedBuildings;
DWORD Hooks::Patches::jumpback_enablePlacingNonResearchedBuildings_OriginalReturn;
__declspec(naked) void Hooks::Patches::enablePlacingNonResearchedBuildings() {
    _asm {

        // EAX
        // EBX = CMapProvince
        // ECX
        // EDX
        // ESI = CCountry
        // EDI = CBuildingDeployment ( + 0x38 = CBuilding)
        pushad
        mov eax, [edi + 0x38]       // Get building (CBuilding)
        mov ecx, [eax + 0x54]       // Get index
        mov eax, [eax + 0x68]       // Get max allowed level
        imul eax,eax,0x3e8
        mov ebx, [ebx + 0x310]      // Get province buildings array
        mov ebx, [ebx + ecx * 4]    // Get building in province (CProvinceBuilding)
        mov ebx, [ebx + 0x20]       // Get max building level in province

        cmp ebx, eax // compare max allowed to current max


        popad
        jge[jmpToOrig] // Dont allow placing if above limit
        jmp[Hooks::Patches::jumpback_enablePlacingNonResearchedBuildings]

        jmpToOrig:
            jmp[Hooks::Patches::jumpback_enablePlacingNonResearchedBuildings_OriginalReturn] // Dont allow placing if above limit
    }
}
