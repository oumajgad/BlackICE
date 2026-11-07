#include <Hooks/PlaceUnresearchedBuildings.hpp>

#include <Hooks/Hooks.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdint>

namespace {
    // CCountry::IsBuildingAllowed
    const uintptr_t IS_BUILDING_ALLOWED = 0xDFFC0;

    // call 0xDFFC0, in CBuildingDeployment::CanDeployIn
    const uintptr_t CALL_SITE = 0x17E4E0;
    const int CALL_LENGTH = 5;

    // cmp byte ptr [eax+edx], 0; jne 0xE000B - the research test, first in IsBuildingAllowed
    const uintptr_t RESEARCH_SITE = 0xDFFF0;
    const unsigned char RESEARCH_BYTES[6] = { 0x80, 0x3C, 0x10, 0x00, 0x75, 0x15 };
    const uintptr_t RESEARCH_PASSED = 0xE000B;
    const uintptr_t RESEARCH_FAILED = 0xDFFF6;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the naked stubs, which is why they are plain words.
    DWORD isBuildingAllowed = 0;
    DWORD callResume = 0;
    DWORD researchPassed = 0;
    DWORD researchFailed = 0;

    // Up only while CanDeployIn's own call to IsBuildingAllowed runs.
    volatile BYTE deploying = 0;

    /**
    @brief CanDeployIn's call, made with the flag up

    The arguments are on the stack and the country in ECX exactly as the replaced `call`
    left them; IsBuildingAllowed takes them off (`ret 8`) and answers in AL, which is what
    the `test al, al` after the five bytes reads.
    */
    __declspec(naked) void callStub() {
        __asm {
            mov byte ptr [deploying], 1
            call dword ptr [isBuildingAllowed]
            mov byte ptr [deploying], 0
            jmp [callResume]
        }
    }

    /**@brief the research test, passed while CanDeployIn is asking; EAX the index, EDX the array*/
    __declspec(naked) void researchStub() {
        __asm {
            cmp byte ptr [deploying], 0
            jne passed
            cmp byte ptr [eax + edx], 0     // the test replaced
            jne passed
            jmp [researchFailed]
        passed:
            jmp [researchPassed]
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
    if (!Hooks::isCallTo(base + CALL_SITE, base + IS_BUILDING_ALLOWED)
        || !Hooks::bytesAre(base + RESEARCH_SITE, RESEARCH_BYTES, sizeof(RESEARCH_BYTES))) {
        statusText = "CanDeployIn or IsBuildingAllowed is not what this build expects";
        return false;
    }

    isBuildingAllowed = static_cast<DWORD>(base + IS_BUILDING_ALLOWED);
    callResume = static_cast<DWORD>(base + CALL_SITE + CALL_LENGTH);
    researchPassed = static_cast<DWORD>(base + RESEARCH_PASSED);
    researchFailed = static_cast<DWORD>(base + RESEARCH_FAILED);

    // The research test first: hooked alone it changes nothing, as the flag is down
    if (!Hooks::hookAt(base + RESEARCH_SITE, &researchStub, RESEARCH_BYTES, sizeof(RESEARCH_BYTES))
        || !Hooks::hook(reinterpret_cast<void*>(base + CALL_SITE), &callStub, CALL_LENGTH, 0)) {
        statusText = "could not make the code writable";
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
