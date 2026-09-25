#pragma once

#include <cstdint>

/**
 * The base stats behind a battle tooltip's modifier list.
 *
 * Hovering a unit in a battle gives a list of percentages - `Attack Modifier: 44.70%`,
 * `Defend Modifier: 149.50%`, then whatever else applies that day - and never says what
 * they are percentages *of*. A player can read that a leader is worth +35.7% without
 * being able to tell whether the division hits for 12 or for 120.
 *
 * This puts the division's own stats on the end of it, under the armour line.
 *
 * ## Where the tooltip is built
 *
 * `0x329D40`, the only caller of which is `0x331C77`. It writes, in order: the leader
 * line (`LEADER_COMMAND_INFO`, or `NO_LEADER_FOR_THIS_1`/`_2`), `UNIT_COMBAT_WIDTH`,
 * `CURR_COMB_STR`, `BATTLE_ATTACKMOD`, `BATTLE_DEFENDMOD`, `CURR_COMB_ORG`, and then
 * the variable part - a walk of a linked list on the unit whose every node is one
 * combat modifier. Each node's id becomes a localisation key through the switch at
 * `0x164060`, which is the whole enum and nothing else: `BM_DISSENT` is 0,
 * `BM_LEADER_BONUS` 1, `BM_COMBINED_ARMS` 0x12, `BM_TERRAIN` 0x19, `BM_NIGHT_MODIFIER`
 * 0x1C, up to `BM_SURPRISE_BONUS` at 0x1D - the bound is its own `cmp eax, 0x1d`.
 *
 * **The unit is in EDI** for the whole of the second half. That it is a `CUnit` is not
 * assumed: `[edi + 0x12C]` is read for the leader line and is `CUnit::leader_ptr`, and
 * `[edi + 0x40]` is compared against 1 to decide whether to say "division" or "corps",
 * which is the count of `CUnit::regiments`. The hook checks the vftable anyway, so a
 * build where this is not so adds nothing rather than nonsense.
 *
 * `CUnit + 0xDC` is the modifier list and `+0xEC`, `+0xF0`, `+0xF4` and `+0xF8` are what
 * the two percentages are worked out from. They sit in the gap between `combat_cooldown`
 * (`+0xD4`) and `supply_received_percentage` (`+0xFC`) and are recorded in
 * `reversing/ghidra/project.json` as far as this went; naming them properly wants a
 * live read.
 *
 * ## Where the stats come from
 *
 * `CRegiment + 0x58` is **the subunit's own definition**, not the type's shared
 * template, and `CSubUnit::ApplyTechnologies` (`0x1ABFC0`) rebuilds it from the template
 * plus every technology's effect scaled by its level. So the fields read here already
 * have research in them and nothing has to be summed a second way - which matters,
 * because a breakdown that disagrees with the number beside it is worse than none.
 *
 * ## How a division's stats are added up
 *
 * **This is the one assumption in here, and it is worth checking.** The attack and
 * defence values are summed over the brigades; `armor` and `piercing_attack` are
 * averaged over the brigades that have one, since a division does not get thicker armour
 * by having more tanks in it. If the engine's own combat maths disagrees, this is the
 * line to change - it is one function, `aggregate`.
 *
 * ## Why the text is built here rather than in the localisation
 *
 * Offering `$SOFTATTACK$` and the rest as variables for a localisation key to place is the
 * better pattern, and is how the manpower tooltip works. **It cannot work here.** The game
 * renders a line's key and *then* appends `": <value>"` to what came back, so anything
 * written into the key lands between the label and its number: `Defend Modifier`, the
 * whole block, and then `149.50%` on the end of it. A key cannot place anything after its
 * own value.
 *
 * So the block is written here, in English, and appended to the finished tooltip. The cost
 * is real - it cannot be translated or reworded without a rebuild - so prefer variables
 * anywhere the value is not appended this way.
 *
 * It goes on the end, below the armour line, because that is where the stats it is about
 * already are.
 *
 * **Switched on from Lua**: `BiceLib.Tooltips.activateCombatUnitStats()`.
 */
namespace Hooks {
    namespace Tooltips {
        namespace CombatUnitStats {
            /**@brief patches the two sites, once; safe to call again*/
            bool install();

            bool installed();

            /**@brief why it is not installed, when it is not*/
            const char* status();

            /**
             * @brief the unit the last battle tooltip was about, or 0
             *
             * Kept for the reversing probes, which have no other way to lay hands on a
             * live CUnit: this is the one place BiceLib is handed one by the game. It
             * survives the tooltip it came from, unlike the slot the hook itself uses,
             * which is cleared as it is read.
             */
            uintptr_t lastUnit();

            /**
             * @brief throw that unit away
             *
             * So a probe cannot arm on a unit from an older tooltip. The battle tooltip
             * has a sibling (`0x327CD0`) whose part is not established, and if hovering
             * some kinds of unit goes through that one instead, `lastUnit()` would quietly
             * still hold whatever was hovered before. Forgetting between runs turns that
             * into a refusal rather than a wrong answer.
             */
            void forgetUnit();
        }
    }
}
