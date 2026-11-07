#pragma once

/**
 * Shows a leader's maximum skill beside his skill - `3 (5)` - in the two places the leader
 * window shows the skill as a bare number.
 *
 * ## Where
 *
 * Both places build the text the same way: the skill (`CLeader +0x70`) through `_itoa` into
 * a buffer on the stack, then `mov esi, eax; mov ecx, esi; add esp, 0xC` and a copy of that
 * buffer into the element's own string. The hook stands on those seven bytes, after the
 * `_itoa` and before the copy.
 *
 * | rva | in | the leader is |
 * | --- | --- | --- |
 * | `0x365688` | `CLeaderAssignmentEntry::CLeaderAssignmentEntry` (`0x365490`), a row of the list | `[ebp+0x14]`, its fourth argument, which the game reads at `0x365666` |
 * | `0x3679D4` | `CLeaderAssignmentPanel::CLeaderAssignmentPanel` (`0x3671A0`), the selected leader | `[ebp+0xC]`, which held the unit until `0x367935` stored the unit's leader (`CUnit +0x12C`) over it |
 *
 * All rvas.
 *
 * The game reads `+0x70` through both without a null test, so neither is ever null.
 *
 * ## How
 *
 * **The game's buffer is not touched.** The text is written into one of ours and the
 * pointer handed on in its place: the code after the hook only measures what eax points at
 * and copies it into the element's string, so our buffer has to live only until that copy,
 * a few instructions later on the same thread.
 *
 * Anything that does not read as a CLeader by its vftable - the null leader among them -
 * keeps the game's own text.
 *
 * **Replaces** `patchLeaderListShowMaxSkill` and `...Selected` in CLeaderHooks.cpp
 * (2026-11-07). The first read its leader from the game's `esp+0xC`, which at that point is
 * the `edi` the constructor's prologue saved - the caller's register, which only usually
 * held the leader; that is where the zero it had to test for came from. Both wrote
 * `"%d (%d)"` into the game's buffer with `sprintf` and no size.
 *
 * Display only: nothing is written to the game's state, so it is safe in multiplayer.
 *
 * reversing/findings/FINDINGS-bicelibsites.md, section 3, has the reading.
 *
 * **Switched on from Lua**: `BiceLib.Leaders.activateLeaderListShowMaxSkill()` and
 * `activateLeaderListShowMaxSkillSelected()` - each installs both places.
 */
namespace Hooks {
    namespace LeaderListSkill {
        /**@brief hooks both places, once; safe to call again*/
        bool install();

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
