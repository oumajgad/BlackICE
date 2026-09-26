#pragma once

#include <cstdint>

/**
 * What a unit has dealt and taken in the battle it is in.
 *
 * The game does not keep this. `CCombatant + 0x84` is the strength a **side** has lost and
 * `+0x88`/`+0x98` are destroyed and damaged **per subunit type**; nothing is per unit, and
 * damage *dealt* is not recorded at all - a side's losses are the other side's work by
 * implication only. So it is counted here.
 *
 * ## Where the count comes from
 *
 * One hook, on the `call CUnit::TakeDamage` at rva `0x16B312` inside
 * `CLandCombatant::FireUnit`, which is the moment a shot has landed and its damage has been
 * worked out. Everything needed is in hand there and nowhere else at once:
 *
 *     EAX        the unit being hit
 *     ESI        the unit that fired
 *     [esp]      the strength damage, thousandths
 *     [esp + 4]  the organisation damage
 *     [ebp + 8]  the firing side, whose `combat` (+0x3C) says which battle this is
 *
 * **Standing on the game's own call is the point.** The alternative is to re-derive the
 * damage from the attack values, the softness split, the modifiers, the doctrine factor and
 * the armour deflection - five places to drift from what the game actually did. Here the
 * number counted is the number applied, by construction.
 *
 * It is land only, which is the mechanic's own limit rather than this one's: naval and air
 * combat override `CCombat::Tick` and reach none of this. See reversing/FINDINGS-combat.md.
 *
 * ## What is counted, and when it resets
 *
 * Strength and organisation damage, both in thousandths - the same units the game keeps
 * them in. They are the two arguments of the same call, so neither costs more than the
 * other to count.
 *
 * **Totals belong to one battle.** Each unit's entry remembers which `CCombat` it was
 * fighting in, and a shot that arrives for a different one clears the unit first - so a
 * division that fights twice in a day shows the second battle rather than the sum. Nothing
 * clears entries when a battle ends: a unit keeps its last battle's figures until it fights
 * again, which is what makes the tooltip readable just after a fight rather than empty.
 *
 * **The same four figures are also kept for one round.** A combat round is an hour, so a
 * round's figures are stamped with the game tick they arrived under, and the first damage of
 * a later tick clears them. They read as the last tick the unit *did* something rather than
 * as the tick now: a division out of the line keeps the last round it fought.
 *
 * The table is capped. Units are created and destroyed over a campaign and an address can be
 * reused, so it is bounded rather than grown forever - entries are keyed by the unit's id,
 * and a newcomer that finds every slot it probes taken evicts one of them. The log says when
 * that starts happening.
 *
 * **Switched on with the rest of the battle tooltip**, by
 * `BiceLib.Tooltips.activateCombatUnitStats()`.
 */
namespace Hooks {
    namespace Tooltips {
        namespace CombatUnitDamage {
            /**@brief patches the one site, once; safe to call again*/
            bool install();

            bool installed();

            /**@brief why it is not installed, when it is not*/
            const char* status();

            /**@brief strength this unit has dealt in its current battle, thousandths*/
            int dealtBy(uintptr_t unit);

            /**@brief strength this unit has taken in its current battle, thousandths*/
            int takenBy(uintptr_t unit);

            /**@brief organisation this unit has dealt in its current battle, thousandths*/
            int dealtOrganisationBy(uintptr_t unit);

            /**@brief organisation this unit has taken in its current battle, thousandths*/
            int takenOrganisationBy(uintptr_t unit);

            /**@brief strength dealt in the last tick this unit fought, thousandths*/
            int dealtLastTickBy(uintptr_t unit);

            /**@brief strength taken in the last tick this unit fought, thousandths*/
            int takenLastTickBy(uintptr_t unit);

            /**@brief organisation dealt in the last tick this unit fought, thousandths*/
            int dealtOrganisationLastTickBy(uintptr_t unit);

            /**@brief organisation taken in the last tick this unit fought, thousandths*/
            int takenOrganisationLastTickBy(uintptr_t unit);

            /**@brief whether this unit has a battle worth reporting at all*/
            bool known(uintptr_t unit);
        }
    }
}
