#include <Hooks/NavyScreenPenalty.hpp>

#include <Hooks/Hooks.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdint>

namespace {
    // cmp esi, edx; jge 0x1665F6
    const uintptr_t SITE = 0x166560;
    const unsigned char SITE_BYTES[8] = { 0x3B, 0xF2, 0x0F, 0x8D, 0x8E, 0x00, 0x00, 0x00 };
    const uintptr_t SCALE_END = 0x1665F6;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    bool penaltySet = false;
    bool ratioSet = false;

    // Read by the naked stub, which is why they are plain words.
    DWORD screenPenalty = 333;          // x1000
    DWORD screensPerCapital = 1;
    DWORD scaleEnd = 0;

    /**@brief EDX the capital ships, ESI the screens, [esp+0x1C] the penalty (0 on entry)*/
    __declspec(naked) void testStub() {
        __asm {
            imul edx, screensPerCapital     // the screens the capitals want
            cmp esi, edx
            jge enough
            mov eax, screenPenalty
            mov [esp + 0x1C], eax
        enough:
            jmp [scaleEnd]
        }
    }
}

bool Hooks::NavyScreenPenalty::install() {
    if (installedFlag) {
        return true;
    }
    const uintptr_t base = Hooks::MODULE_BASE;
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    scaleEnd = static_cast<DWORD>(base + SCALE_END);
    if (!Hooks::hookAt(base + SITE, &testStub, SITE_BYTES, sizeof(SITE_BYTES))) {
        statusText = Hooks::bytesAre(base + SITE, SITE_BYTES, sizeof(SITE_BYTES))
            ? "could not make the code writable"
            : "the screen test is not what this build expects";
        return false;
    }
    installedFlag = true;
    statusText = "installed";
    return true;
}

void Hooks::NavyScreenPenalty::setPenalty(int thousandths) {
    if (!penaltySet) {
        screenPenalty = static_cast<DWORD>(thousandths);
        penaltySet = true;
    }
}

void Hooks::NavyScreenPenalty::setScreensPerCapital(int ratio) {
    if (!ratioSet) {
        screensPerCapital = static_cast<DWORD>(ratio);
        ratioSet = true;
    }
}

bool Hooks::NavyScreenPenalty::installed() {
    return installedFlag;
}

const char* Hooks::NavyScreenPenalty::status() {
    return statusText;
}
