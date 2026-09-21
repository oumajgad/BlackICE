#pragma once

/**
 * Catches a pure virtual call, so the game is saved instead of vanishing.
 *
 * A pure virtual call means a virtual function was dispatched through a slot that has
 * no implementation - almost always an object being used while it is still being
 * constructed, or after it has been destroyed. The CRT's answer is to print a runtime
 * error and abort, so the game disappears and takes the session with it.
 *
 * ## Where it is caught
 *
 * `_purecall` (rva `0x7961D5`) is what every such slot points at, and it is **511
 * bytes of nothing but this**:
 *
 * ```
 * FF 35 <__pPurecall>     push the handler, kept encoded   rva 0x134D238
 * FF 15 <DecodePointer>   decode it                        rva 0x92B040
 * 85 C0 / 74 02 / FF D0   if one is installed, call it - no arguments
 * 6A 19                   otherwise push 25 = _RT_PUREVIRT, and abort
 * ```
 *
 * So there is a handler slot standing ready and nothing in it: `__pPurecall` lives in
 * `.bss`, the CRT's startup encodes a null into it, and no other code in the
 * executable ever writes it. Putting something there is the whole of the job - no
 * instruction is patched.
 *
 * **Our own `_set_purecall_handler` would not do**: BiceLib links its own CRT and
 * would write its own copy of that global. The game's one is written directly.
 * `EncodePointer`'s cookie is per process rather than per module, so a pointer encoded
 * here decodes correctly over there. This is the same arrangement, and the same two
 * imports, as the new handler described in reversing/FINDINGS-allocator.md.
 *
 * ## Why this one is worth doing
 *
 * `_purecall` sits in **510 vftable slots** and is never called directly, so it is
 * reached by ordinary virtual dispatch. Unlike the allocator's new handler - which was
 * installed, live, and provably never called, because the game dies without its own
 * allocator ever refusing anything - there is no question about whether this one gets
 * reached. If a pure virtual is called, this runs.
 *
 * ## What it can and cannot promise
 *
 * The handler cannot return: returning lands back on the abort path. So the save is
 * written **synchronously, on whichever thread hit the purecall**, by calling the
 * game's own writer directly - see CrashSave::saveNowAndClose.
 *
 * That carries two risks worth stating rather than hiding. The object that caused the
 * purecall is half built or already gone, and if the save walks it the save itself can
 * fault. And a purecall on a thread other than the game's own leaves the main thread
 * free to change state underneath the save. **Neither makes anything worse**: without
 * this, the process was aborting regardless, so the worst case is the crash that was
 * already happening.
 */
namespace PureCall {
    /**
    @brief installs the handler, once

    Checks `_purecall` is the code this expects and that the slot still holds the CRT's
    encoded null before writing anything, so a build this does not fit is left alone
    and a handler somebody else installed is never taken over.
    */
    bool install();

    /**@brief puts the game's own encoded null back*/
    void remove();

    bool installed();

    /**@brief why it is not installed, when it is not*/
    const char* status();

    /**
    @brief calls the game's `_purecall` exactly as a pure virtual slot would

    For testing the handler without waiting years for the bug. A vftable slot holds
    this same address, so a real pure virtual call is this call and nothing else - which
    makes it a faithful test rather than an approximation of one.

    **It does not come back**: it saves, says so, and closes the game.
    */
    void provoke();
}
