#pragma once

/**
 * Replaces the naval combat penalty for too few screens with a flat one, at a ratio of
 * screens to capital ships the mod sets.
 *
 * `CNavalCombatant::ApplyCombatModifiers` (`0x166480`) works the penalty out from the
 * screens (ESI) and the capital ships (EDX), on a sliding scale, into `[esp+0x1C]`; the
 * test that starts it is `cmp esi, edx; jge 0x1665F6` at `0x166560`, eight bytes, with
 * `[esp+0x1C]` already zeroed and EDX already known to be above 0. The hook takes that test
 * over and skips the scale: below `capitals * screensPerCapital` screens the penalty is
 * the flat figure, otherwise none, and either way it carries on at `0x1665F6` where the
 * scale would have ended. Nothing from `0x1665F6` on reads EDX or EAX before setting them,
 * as the scale's own end leaves both changed. reversing/findings/FINDINGS-bicelibsites.md,
 * section 2.
 *
 * **Switched off in BlackICE** - the calls are commented out in `script/bicelib_lua.lua`.
 *
 * **Switched on from Lua**: `BiceLib.Navy.setScreenPenalty(thousandths)` and
 * `setScreensPerCapitalRatio(ratio)`. Each sets its figure once; later calls are ignored.
 */
namespace Hooks {
    namespace NavyScreenPenalty {
        /**@brief hooks the test, once; safe to call again*/
        bool install();

        /**@brief the penalty below the ratio, in thousandths; 333 until set*/
        void setPenalty(int thousandths);

        /**@brief how many screens each capital ship wants; 1 until set*/
        void setScreensPerCapital(int ratio);

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
