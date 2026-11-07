#include <Hooks/MaxInfrastructure.hpp>

#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CProvinceBuilding.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdint>
#include <string>

namespace {

    // The stubs write the field as a literal displacement; this is what says it is the one
    // GameClasses names.
    static_assert(CMapProvince::Offsets::MaxInfrastructure == 0x5C,
        "the stubs store [reg+0x5C] as a literal");

    /**
     * **The three stores**, module relative, each with the instruction after it, which the
     * five byte jump also covers and the stub puts back. Nothing branches into any of them
     * after its first byte: a scan of every rel8 and rel32 branch in .text finds none, and
     * finds `0xB8003 jmp 0xB8024` - onto a first byte - as its positive control.
     *
     *   LoadKey             0x96152  mov [edi+0x5C], eax ; mov ecx, [esp+0xB4]     10 bytes, EDI the province
     *   SetBuildingLevel    0xA3B0A  mov [esi+0x5C], eax ; cmp byte [ebp+0x10], bl  6 bytes, ESI the province
     *   OnLevelChanged      0xB8024  mov [esi+0x5C], eax ; mov edx, [g]             9 bytes, ESI the province
     *
     * The last one's operand is an absolute address, relocated with the module, so its
     * bytes are checked and its load is made against the base at install time.
     * reversing/findings/FINDINGS-extrainfra.md, section 2.
     */
    const uintptr_t LOADKEY_SITE = 0x96152;
    const uintptr_t LOADKEY_RESUME = 0x9615C;
    const unsigned char LOADKEY_BYTES[10] = {
        0x89, 0x47, 0x5C, 0x8B, 0x8C, 0x24, 0xB4, 0x00, 0x00, 0x00 };

    const uintptr_t SETLEVEL_SITE = 0xA3B0A;
    const uintptr_t SETLEVEL_RESUME = 0xA3B10;
    const unsigned char SETLEVEL_BYTES[6] = { 0x89, 0x46, 0x5C, 0x38, 0x5D, 0x10 };

    const uintptr_t LEVELCHANGED_SITE = 0xB8024;
    const uintptr_t LEVELCHANGED_RESUME = 0xB802D;
    const unsigned char LEVELCHANGED_BYTES[5] = { 0x89, 0x46, 0x5C, 0x8B, 0x15 };
    const uintptr_t LEVELCHANGED_GLOBAL = 0x1687098;   // the operand of mov edx, [g]

    const char* const INFRA = "infra";

    // Read by the naked stubs, which is why they are plain words.
    DWORD loadKeyResume = 0;
    DWORD setLevelResume = 0;
    DWORD levelChangedResume = 0;
    DWORD levelChangedGlobal = 0;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // infra's index in a province's building array: -1 not looked for yet, -2 not there.
    // Every province's array is laid out alike, one entry per building the mod defines.
    int infraIndex = -1;

    int findInfra(uint32_t array) {
        for (int i = CProvinceBuilding::NO_BUILDING_INDEX + 1; i < CProvinceBuilding::MAX_BUILDINGS; i++) {
            uint32_t entry = 0;
            uint32_t definition = 0;
            if (!Mem::tryRead(array + i * 4, entry) || entry == 0
                || !Mem::tryRead(entry + CProvinceBuilding::Offsets::definition_ptr, definition)
                || definition == 0) {
                break;
            }
            if (HDS::readString(definition + CBuilding::Offsets::name) == INFRA) {
                return i;
            }
        }
        ERROR_OUT(printf("MaxInfrastructure: no building is called infra; the game's figure is left as it is\n"));
        return -2;
    }

    /**
    @brief writes infra's figure over whatever the store just wrote

    `level_max x effect_size / 1000`, LoadKey's own formula, in 64 bits and toward nought as
    its helper does. A province with no infra gets 0, which is what it holds before any
    infrastructure building is loaded into it.
    */
    void __stdcall restoreFromInfra(uintptr_t province) {
        const uint32_t array =
            *reinterpret_cast<uint32_t*>(province + CMapProvince::Offsets::CProvinceBuilding_array_ptr);
        if (array == 0) {
            return;
        }
        if (infraIndex == -1) {
            infraIndex = findInfra(array);
        }
        if (infraIndex < 0) {
            return;
        }
        const uint32_t entry = *reinterpret_cast<uint32_t*>(array + infraIndex * 4);
        if (entry == 0) {
            return;
        }
        const uint32_t definition =
            *reinterpret_cast<uint32_t*>(entry + CProvinceBuilding::Offsets::definition_ptr);
        if (definition == 0) {
            return;
        }
        const int64_t level = *reinterpret_cast<int32_t*>(entry + CProvinceBuilding::Offsets::level_max);
        const int64_t figure = *reinterpret_cast<int32_t*>(definition + CBuilding::Offsets::effect_size);
        *reinterpret_cast<int32_t*>(province + CMapProvince::Offsets::MaxInfrastructure) =
            static_cast<int32_t>(level * figure / 1000);
    }

    /**@brief LoadKey: the store, the fix, then the read the jump covered*/
    __declspec(naked) void loadKeyStore() {
        __asm {
            mov dword ptr [edi + 0x5C], eax
            pushad
            pushfd
            push edi                        // the province
            call restoreFromInfra
            popfd
            popad
            mov ecx, dword ptr [esp + 0xB4]
            jmp [loadKeyResume]
        }
    }

    /**
    @brief SetProvinceBuildingLevel: the store, the fix, then the notify test

    eax is the figure the next lines test to decide whether a province in no area joins
    one, so it is handed the corrected figure. The flags are the compare's, as they were.
    */
    __declspec(naked) void setLevelStore() {
        __asm {
            mov dword ptr [esi + 0x5C], eax
            pushad
            pushfd
            push esi                        // the province
            call restoreFromInfra
            popfd
            popad
            mov eax, dword ptr [esi + 0x5C]
            cmp byte ptr [ebp + 0x10], bl
            jmp [setLevelResume]
        }
    }

    /**@brief OnLevelChanged: the store, the fix, then the load of the relocated global*/
    __declspec(naked) void levelChangedStore() {
        __asm {
            mov dword ptr [esi + 0x5C], eax
            pushad
            pushfd
            push esi                        // the province
            call restoreFromInfra
            popfd
            popad
            mov eax, dword ptr [esi + 0x5C]
            mov edx, levelChangedGlobal
            mov edx, dword ptr [edx]
            jmp [levelChangedResume]
        }
    }
}

bool Hooks::MaxInfrastructure::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = static_cast<uintptr_t>(Hooks::MODULE_BASE);
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }

    const uint32_t global = static_cast<uint32_t>(base + LEVELCHANGED_GLOBAL);
    const unsigned char* g = reinterpret_cast<const unsigned char*>(&global);
    const unsigned char levelChangedOperand[4] = { g[0], g[1], g[2], g[3] };
    if (!Hooks::bytesAre(base + LOADKEY_SITE, LOADKEY_BYTES, 10)
        || !Hooks::bytesAre(base + SETLEVEL_SITE, SETLEVEL_BYTES, 6)
        || !Hooks::bytesAre(base + LEVELCHANGED_SITE, LEVELCHANGED_BYTES, 5)
        || !Hooks::bytesAre(base + LEVELCHANGED_SITE + 5, levelChangedOperand, 4)) {
        statusText = "the three MaxInfrastructure stores are not what this build expects";
        ERROR_OUT(printf("MaxInfrastructure: a store is not the instruction expected\n"));
        return false;
    }

    loadKeyResume = static_cast<DWORD>(base + LOADKEY_RESUME);
    setLevelResume = static_cast<DWORD>(base + SETLEVEL_RESUME);
    levelChangedResume = static_cast<DWORD>(base + LEVELCHANGED_RESUME);
    levelChangedGlobal = static_cast<DWORD>(global);

    if (!Hooks::hook(reinterpret_cast<void*>(base + LOADKEY_SITE), &loadKeyStore, 5, 5)
        || !Hooks::hook(reinterpret_cast<void*>(base + SETLEVEL_SITE), &setLevelStore, 5, 1)
        || !Hooks::hook(reinterpret_cast<void*>(base + LEVELCHANGED_SITE), &levelChangedStore, 5, 4)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    return true;
}

bool Hooks::MaxInfrastructure::installed() {
    return installedFlag;
}

const char* Hooks::MaxInfrastructure::status() {
    return statusText;
}
