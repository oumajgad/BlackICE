#include <Hooks/PlaceUnresearchedBuildings.hpp>

#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CProvinceBuilding.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdint>

namespace {
    // test al, al; je 0x17E5B7
    const uintptr_t SITE = 0x17E4E5;
    const unsigned char SITE_BYTES[8] = { 0x84, 0xC0, 0x0F, 0x84, 0xCA, 0x00, 0x00, 0x00 };
    const uintptr_t REFUSED = 0x17E5B7;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the naked stub, which is why they are plain words.
    DWORD allowedResume = 0;
    DWORD refusedResume = 0;

    /**@brief whether the province has room for one more level of the building*/
    bool __stdcall roomFor(uintptr_t deployment, uintptr_t province) {
        const uintptr_t building =
            Mem::readOr<uint32_t>(deployment + CBuildingDeployment::Offsets::building);
        if (building == 0) {
            return false;
        }
        const int index = Mem::readOr<int32_t>(building + CBuilding::Offsets::index, -1);
        const int maxLevel = Mem::readOr<int32_t>(building + CBuilding::Offsets::max_allowed_level);
        const uintptr_t buildings =
            Mem::readOr<uint32_t>(province + CMapProvince::Offsets::CProvinceBuilding_array_ptr);
        if (index < 0 || buildings == 0) {
            return false;
        }
        const uintptr_t inProvince = Mem::readOr<uint32_t>(buildings + index * sizeof(uint32_t));
        if (inProvince == 0) {
            return false;
        }
        const int levels = Mem::readOr<int32_t>(inProvince + CProvinceBuilding::Offsets::level_max);
        return levels < maxLevel * 1000;
    }

    __declspec(naked) void testStub() {
        __asm {
            pushad
            push ebx                        // the province
            push edi                        // the deployment
            call roomFor
            test al, al
            popad                           // leaves the flags alone
            jz refused
            jmp [allowedResume]
        refused:
            jmp [refusedResume]
        }
    }
}

bool Hooks::PlaceUnresearchedBuildings::install() {
    if (installedFlag) {
        return true;
    }
    const uintptr_t base = Hooks::MODULE_BASE;
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    allowedResume = static_cast<DWORD>(base + SITE + sizeof(SITE_BYTES));
    refusedResume = static_cast<DWORD>(base + REFUSED);
    if (!Hooks::hookAt(base + SITE, &testStub, SITE_BYTES, sizeof(SITE_BYTES))) {
        statusText = Hooks::bytesAre(base + SITE, SITE_BYTES, sizeof(SITE_BYTES))
            ? "could not make the code writable"
            : "the deploy test is not what this build expects";
        return false;
    }
    installedFlag = true;
    statusText = "installed";
    return true;
}

bool Hooks::PlaceUnresearchedBuildings::installed() {
    return installedFlag;
}

const char* Hooks::PlaceUnresearchedBuildings::status() {
    return statusText;
}
