#pragma once
#include <Windows.h>

#include <cstdint>

namespace Hooks {
    /**@brief where hoi3_tfh.exe is loaded; set as the DLL loads, the one copy everything uses*/
    extern DWORD MODULE_BASE;

    /**
    @brief writes a jmp to \p hookFunc at \p hookAddress, then \p NOPs nops after its 5 bytes

    Checks nothing about what it overwrites; the caller has (bytesAre, isCallTo). Prefer
    hookAt, which makes that check part of the call. False if the code could not be made
    writable, and then nothing was written.

    @param len always 5, the jmp; kept for the callers that pass it
    */
    bool hook(void* hookAddress, void* hookFunc, int len, int NOPs);

    /**
    @brief hooks \p site only if its \p length bytes are exactly \p expected

    The jmp takes five of them and the rest become nops, so a stub that replays the
    replaced instructions resumes at `site + length` - which is the one number a caller
    needs, and the one the old hooks used to work out by hand. Writes nothing when the
    bytes are not what this build should hold.

    @param site absolute
    */
    [[nodiscard]] bool hookAt(uintptr_t site, void* stub, const unsigned char* expected, int length);

    /**
    @brief whether the five bytes at \p site are a call to \p target

    **What a hook should check before it writes anything.** Stronger than comparing
    fixed bytes where the site is a call: it resolves the call and compares where it
    goes, so it holds however the image is laid out and refuses anything else.

    @param site the instruction, absolute
    @param target where it should go, absolute
    */
    [[nodiscard]] bool isCallTo(uintptr_t site, uintptr_t target);

    /**
    @brief whether the bytes at \p site are exactly \p expected

    For a site that is not a call - a function prologue a stub reproduces, say - where
    there is nothing to resolve and the bytes themselves are what must hold.
    */
    [[nodiscard]] bool bytesAre(uintptr_t site, const unsigned char* expected, int length);
}
