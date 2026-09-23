#pragma once

/**
 * What the manpower tooltip's "needs X manpower to reinforce" is made of.
 *
 * `MANPOWER_DETAILS_IRO` shows one number for the whole country, which says nothing
 * about where it is going: a player looking at it cannot tell a shattered army from a
 * fleet waiting on dockyard crews. This splits that number into land, air and naval and
 * offers each as a variable the localisation can place.
 *
 * ## Where the number comes from
 *
 * The daily reinforcement pass (`0x11BA60`) zeroes three counters on the country and
 * then walks every unit and every subunit under it. For a subunit that is short of
 * strength it works out the manpower that shortfall is worth and adds it to
 * `CCountry + 0xA9C`, which is exactly what the tooltip reads back.
 *
 * **So the split is taken from that one `add`**, not computed a second way. At the
 * instruction that performs it the subunit whose share is being added is still on the
 * stack, and what class it is - `CRegiment`, `CWing` or `CShip` - is the whole answer.
 * Three numbers that add up to the game's own by construction, rather than three that
 * ought to.
 *
 * Reproducing the arithmetic instead would mean reimplementing supply, technology and
 * reserve scaling and hoping the total agreed; a breakdown that does not add up to the
 * figure printed beside it is worse than no breakdown.
 *
 * ## Troop rotation
 *
 * `peacetime_manpower_rotation` is a law modifier, and **its name is misleading twice
 * over**: it is not gated on peace, and it costs no manpower directly. It is read in
 * exactly one place in the executable - `0x1BB171`, inside `CUnit::UpdateDaily`,
 * virtual slot 32, at `0x1BAF70`:
 *
 *     if (!this->IsLand()) return                 // slot 15, and the whole of the gate
 *     ...dig in, if at war and standing still...
 *     rotation = the owner's peacetime_manpower_rotation
 *     if the unit is under-supplied
 *         rotation x= 1 + (1 - supply) x PEACETIME_MANPOWER_ROTATION_LOW_SUPPLY_FACTOR
 *     for each subunit
 *         strength = clamp(strength - maximum x rotation / 365000, 0, maximum)
 *
 * The `365000` is what makes it an annual rate applied daily - and, with dig-in
 * advancing one level a call, the only evidence for the period in the slot's name.
 * No caller for it has been found; see reversing/FINDINGS-manpower.md.
 *
 * **It is land only, and `IsLand` is the whole of why.** All three unit classes reach
 * that test: `CArmy` and `CNavy` share this function, and `CAir` overrides slot 32 with
 * `0x1D0B60`, which does its own work and then ends by calling this one on every path.
 * A fleet and an air command run the function and fail the test. So the cost below is
 * an army's alone.
 *
 * **It is not gated on war**, though it reads as though it might be. The `isAtWar` test
 * is one of five early-outs from the *dig-in* block above, and every one of them jumps
 * to the rotation code rather than past it: the block has seven incoming edges and six
 * of them are branches taken to skip digging in. Read off the whole function's flow
 * graph, not off one jump.
 *
 * So rotation takes **strength**, and the manpower only appears a step later, when the
 * reinforcement pass puts that strength back. It is the reason a quiet army still bleeds
 * manpower, which is what makes it worth a line here.
 *
 * **What it costs is exact, not estimated.** Working the reinforcement pass's arithmetic
 * through, everything cancels to `missing strength x build_cost_manpower / max_strength`
 * - refilling all of a subunit costs what building it cost - so the strength rotation
 * takes prices through the same two fields of the same definition. The daily total is
 * projected over a twelfth of a year, to match the rate it came from.
 *
 * ## Attrition and trickleback
 *
 * Two more of the same shape. **Attrition** (`ApplyAttrition`, `0x1C7530`, which
 * `CUnit::UpdateDaily` calls) takes strength off a subunit exactly as rotation does -
 * the same clamp, the same store through `[reg + 0x5C]` - so it is hooked the same way
 * and priced with the same formula. It is gated on `IsLand` too, and skipped while the
 * unit is in combat, and its rate comes off the **province's** modifier rather than the
 * country's.
 *
 * **Casualty trickleback** (`0x1C3F30`) is the only thing here that gives manpower back.
 * Nothing has to be priced: the game has already turned the casualties into manpower,
 * through the same two definition fields, before it credits the pool at `0x1C3FF2`.
 *
 * **Both are averaged rather than projected.** Rotation is a rate, so a day of it
 * projects honestly over a month; these two are not - attrition depends on where the
 * army is standing and trickleback only happens when somebody is being shot at. Thirty
 * days of each are kept and the average day is reported times a month, so the figure
 * starts rough and settles rather than swinging with one day's fighting.
 *
 * ## What the localisation gets
 *
 * `$LAND$`, `$AIR$` and `$NAVY$`, each formatted by the game's own number formatter at
 * the same precision it gave `$NEED$` - so they read like the total they came from -
 * `$ROTATION$` and `$ROTATIONCOST$` for the rate as a percentage and the month it
 * projects to, and `$ATTRITION$` and `$TRICKLEBACK$` for a month of each of those. The
 * localisation decides whether and where they show; nothing appears until
 * `interface.csv` asks for them.
 *
 * Where the split cannot be vouched for - the hook was installed part way through a
 * pass, so what was counted does not add up to what the country holds - all three come
 * back empty rather than wrong. That can only last until the next daily tick, and
 * `$ROTATIONCOST$` is blank over the same window, for the same reason: the first day it
 * sees is one it did not watch all of. `$ROTATION$` is read rather than counted, so it
 * is right immediately.
 *
 * **Switched on from Lua**: `BiceLib.Tooltips.activateManpowerBreakdown()`.
 */
namespace Hooks {
    namespace Tooltips {
        namespace Manpower {
            /**@brief patches the three sites, once; safe to call again*/
            bool install();

            bool installed();

            /**@brief why it is not installed, when it is not*/
            const char* status();
        }
    }
}
