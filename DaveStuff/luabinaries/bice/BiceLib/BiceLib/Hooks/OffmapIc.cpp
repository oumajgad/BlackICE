#include <Hooks/OffmapIc.hpp>

#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CModifier.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdint>

namespace {
    // mov ecx, [esi+0x330]
    const uintptr_t COUNT_SITE = 0xF0F22;
    const unsigned char COUNT_BYTES[6] = { 0x8B, 0x8E, 0x30, 0x03, 0x00, 0x00 };

    // mov [ebx+0x604], eax
    const uintptr_t STORE_SITE = 0xF0F9D;
    const unsigned char STORE_BYTES[6] = { 0x89, 0x83, 0x04, 0x06, 0x00, 0x00 };

    // Indexed by country id. BlackICE has 107 tags; the bound is checked all the same.
    const int MAX_COUNTRIES = 300;
    int localPart[MAX_COUNTRIES] = {};     // x1000, today's provinces so far
    int offmap[MAX_COUNTRIES] = {};        // whole IC, the last pass

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the naked stubs, which is why they are plain words.
    DWORD countResume = 0;
    DWORD storeResume = 0;

    int countryId(uintptr_t country) {
        const int id = Mem::readOr<int32_t>(
            country + CCountry::Offsets::country_tag + CCountryTag::Offsets::id, -1);
        return (id >= 0 && id < MAX_COUNTRIES) ? id : -1;
    }

    /**@brief the IC entry of a modifier's values, x1000*/
    uintptr_t icEntry(uintptr_t modifier) {
        const uintptr_t values = Mem::readOr<uint32_t>(modifier + CModifier::Offsets::values);
        if (values == 0) {
            return 0;
        }
        return values + CModifier::entryOffset(CModifier::IC) + CModifier::Entry::value;
    }

    void __stdcall provinceCounted(uintptr_t province, uintptr_t country, int term) {
        const int id = countryId(country);
        const uintptr_t base = icEntry(province + CMapProvince::Offsets::modifier);
        if (id < 0 || base == 0) {
            return;
        }
        localPart[id] += term - Mem::readOr<int32_t>(base);
    }

    int __stdcall sumReached(uintptr_t country, int sum) {
        const int id = countryId(country);
        const uintptr_t global = icEntry(country + CCountry::Offsets::global_modifier);
        if (id < 0 || global == 0) {
            return sum;
        }

        const int local = localPart[id];
        localPart[id] = 0;      // for tomorrow's pass

        const int withoutLocal = sum - local / 1000;
        const int offmapIc = Mem::readOr<int32_t>(global) / 1000 - withoutLocal;
        offmap[id] = offmapIc;
        *reinterpret_cast<int32_t*>(global) = offmapIc * 1000;
        return sum + offmapIc;
    }

    __declspec(naked) void countStub() {
        __asm {
            pushad
            pushfd
            push eax                        // the province's term
            push ebx                        // the country
            push esi                        // the province
            call provinceCounted
            popfd
            popad
            mov ecx, [esi + 0x330]          // the instruction replaced
            jmp [countResume]
        }
    }

    __declspec(naked) void storeStub() {
        __asm {
            pushad
            pushfd
            push eax                        // the sum
            push ebx                        // the country
            call sumReached
            mov [esp + 0x20], eax           // over the eax pushad saved
            popfd
            popad
            mov [ebx + 0x604], eax          // the instruction replaced
            jmp [storeResume]
        }
    }
}

bool Hooks::OffmapIc::install() {
    if (installedFlag) {
        return true;
    }
    const uintptr_t base = Hooks::MODULE_BASE;
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::bytesAre(base + COUNT_SITE, COUNT_BYTES, sizeof(COUNT_BYTES))
        || !Hooks::bytesAre(base + STORE_SITE, STORE_BYTES, sizeof(STORE_BYTES))) {
        statusText = "the daily IC pass is not what this build expects";
        return false;
    }

    countResume = static_cast<DWORD>(base + COUNT_SITE + sizeof(COUNT_BYTES));
    storeResume = static_cast<DWORD>(base + STORE_SITE + sizeof(STORE_BYTES));
    if (!Hooks::hookAt(base + COUNT_SITE, &countStub, COUNT_BYTES, sizeof(COUNT_BYTES))
        || !Hooks::hookAt(base + STORE_SITE, &storeStub, STORE_BYTES, sizeof(STORE_BYTES))) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    return true;
}

bool Hooks::OffmapIc::installed() {
    return installedFlag;
}

const char* Hooks::OffmapIc::status() {
    return statusText;
}

int Hooks::OffmapIc::offmapIc(uintptr_t country) {
    const int id = countryId(country);
    return id < 0 ? 0 : offmap[id];
}
