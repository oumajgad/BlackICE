#include <Windows.h>

#include <cstdint>

namespace Hooks {
    extern DWORD MODULE_BASE;
    bool hook(void* hookAddress, void* hookFunc, int len, int NOPs);

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
