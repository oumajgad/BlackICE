#pragma once
#include <Windows.h>

#include <cstdint>

/**
 * Byte patches: instructions of the game's rewritten in place, with no stub behind them.
 *
 * **Every one checks before it writes.** Each site carries the bytes vanilla `hoi3_tfh.exe`
 * holds there and the bytes the patch puts there, and a patch is applied only when every
 * one of its sites holds one or the other - so a build that is not this one is left alone
 * rather than corrupted, and a patch is never left half written. A site already holding
 * the patched bytes counts as done: the installed exe may have had the same change made
 * to it on disk (the tech decay and war exhaustion patches both are, as of 2026-11-07).
 *
 * The vanilla bytes were read from an untouched copy of the executable, not the installed
 * one - reversing/findings/FINDINGS-bicelibsites.md, sections 1, 4, 5 and 9. Only valid
 * for this build of hoi3_tfh.exe.
 */
namespace Patches {
    /**@brief writes \p len bytes at \p address; checks nothing about what was there*/
    bool patchBytes(void* address, const BYTE values[], int len);

    bool fixMinisterTechDecay(uintptr_t moduleBase);
    bool disableWarExhaustionNeutralityReset(uintptr_t moduleBase);
    bool disableInterAiExpeditionaries(uintptr_t moduleBase);
    bool historicalModelLogicFix(uintptr_t moduleBase);
    bool seaTerrainColourInSimplifiedMapMode(uintptr_t moduleBase);
}
