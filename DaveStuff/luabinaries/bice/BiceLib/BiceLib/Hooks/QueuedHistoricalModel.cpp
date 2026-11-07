#include <Hooks/QueuedHistoricalModel.hpp>

#include <Hooks/Hooks.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdint>

namespace {
    // cmp eax, [esi+0x18]; jae 0x82FF1; mov esi, eax; add eax, 0xC; cmp [esi], edx -
    // the test replaced (five bytes) and the search it ends
    const uintptr_t SITE = 0x83020;
    const unsigned char SITE_BYTES[12] = {
        0x3B, 0x46, 0x18, 0x73, 0xCC, 0x8B, 0xF0, 0x83, 0xC0, 0x0C, 0x39, 0x16 };
    const int REPLACED_LENGTH = 5;

    // mov ebx, [edi+4]; push 0x10 - the game's own append, which the stub jumps to
    const uintptr_t APPEND = 0x8302E;
    const unsigned char APPEND_BYTES[5] = { 0x8B, 0x5F, 0x04, 0x6A, 0x10 };

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the naked stub, which is why they are plain words.
    DWORD namedResume = 0;
    DWORD appendResume = 0;

    // A model entry's shape - the technology, then its level - with level 0. Only +4 is read.
    DWORD zeroModelEntry[3] = { 0, 0, 0 };

    /**
    @brief the end-of-model test, with an append of 0 where the game gave up

    EAX the next model entry to look at, ESI the CHistoricalModel (+0x18 the end of its
    entries), EDX the technology looked for.
    */
    __declspec(naked) void testStub() {
        __asm {
            cmp eax, [esi + 0x18]           // the two instructions this replaced:
            jae notNamed                    // every entry looked at, and none was this one
            jmp [namedResume]

        notNamed:
            lea esi, zeroModelEntry         // the append reads the level at [esi + 4]
            jmp [appendResume]
        }
    }
}

bool Hooks::QueuedHistoricalModel::install() {
    if (installedFlag) {
        return true;
    }
    const uintptr_t base = Hooks::MODULE_BASE;
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::bytesAre(base + SITE, SITE_BYTES, sizeof(SITE_BYTES))
        || !Hooks::bytesAre(base + APPEND, APPEND_BYTES, sizeof(APPEND_BYTES))) {
        statusText = "the historical_model loop is not what this build expects";
        return false;
    }

    namedResume = static_cast<DWORD>(base + SITE + REPLACED_LENGTH);
    appendResume = static_cast<DWORD>(base + APPEND);
    if (!Hooks::hookAt(base + SITE, &testStub, SITE_BYTES, REPLACED_LENGTH)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    return true;
}

bool Hooks::QueuedHistoricalModel::installed() {
    return installedFlag;
}

const char* Hooks::QueuedHistoricalModel::status() {
    return statusText;
}
