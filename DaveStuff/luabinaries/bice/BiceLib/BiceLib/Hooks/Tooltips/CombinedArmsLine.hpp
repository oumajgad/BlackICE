#pragma once

/**
 * What a combined arms group gives, on the division designer's `combined_arms_indicator_`
 * tooltips.
 *
 * The game's tooltip is the group's name, with its description after a moment, and says
 * neither how much the group adds nor whether it is the kind that switches combined arms on.
 * This adds both under the name:
 *
 *     Infantry
 *     Combined arms bonus: +10.0%
 *     Base: no - counts only alongside a base brigade
 *
 * with the research part shown apart where there is one - `+12.5% (+2.5% from technology)`
 * - and only "yes" and "no" coloured, green and red.
 *
 * ## The rule
 *
 * `UpdateDesign` lights indicator `i`, and adds to the design's bonus, only where a brigade of
 * the design is in group `i` **and** some brigade's group is a base one; what it adds is the
 * group's `value` (`+0x28`) and the country's `CTechnologyStatus +0x5C[i]`. The base flag is the
 * group's byte at `+0x24`. Combat gates on the same thing: `CUnit +0x1CC` is nought without a
 * base group, and `BM_COMBINED_ARMS` is only applied above nought. See
 * reversing/findings/FINDINGS-builders.md, section 2, and FINDINGS-buildertooltips.md, section 7.
 *
 * ## Where
 *
 * `CDivisionDesigner::BuildTooltip`'s arm for a name beginning `combined_arms_indicator_`
 * copies the group's name into the tooltip in EBX with `call 0x401BD0` at `0x3EB4B0`, the
 * group in EDI. That call is replaced: the stub makes it as it was, then adds the two lines.
 * The group's index is found by looking for it in the unit database's vector of groups, which
 * is how the arm itself reached it.
 *
 * **Switched on from Lua**: `BiceLib.Tooltips.activateCombinedArmsLine()`.
 */
namespace Hooks {
    namespace Tooltips {
        namespace CombinedArmsLine {
            /**@brief patches the call, once; safe to call again*/
            bool install();

            bool installed();

            /**@brief why it is not installed, when it is not*/
            const char* status();
        }
    }
}
