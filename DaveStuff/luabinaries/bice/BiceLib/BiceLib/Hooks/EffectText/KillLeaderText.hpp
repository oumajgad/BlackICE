#pragma once

/**
 * Extra variables for what `kill_leader` shows in an event option's tooltip.
 *
 * The game fills in one, `$NAME$`, so `KILL_LEADER_EFFECT` can say which leader is
 * going and nothing else - not which unit he commands, nor where that unit is, which is
 * what tells a player whether it matters. This adds three more:
 *
 * | | |
 * | --- | --- |
 * | `$UNIT$` | the unit the leader commands, empty in the officer pool |
 * | `$LOCATION$` | the province that unit is in, from its `PROV<id>` localisation |
 * | `$WHERE$` | ` (unit, province)` ready made, and empty rather than ` ()` |
 *
 * `$WHERE$` is the one to use in a sentence, because the other two leave an empty
 * bracket behind on a leader with no command. All three do nothing unless the
 * localisation asks for them, so the game's own `$NAME$` line keeps working untouched -
 * and a string that asks for one BiceLib is not there to fill shows the `$WHERE$` as it
 * stands, so a failed install is visible rather than silent.
 *
 * Two stubs, both standing in for a `call` and both reproducing it: one to catch which
 * leader the text is being built for, and one to add the variables beside the game's
 * own. See EffectText.hpp for the shared parts, and
 * reversing/FINDINGS-effecttext.md for the addresses.
 *
 * **Switched on from Lua**: `BiceLib.EffectTexts.activateKillLeaderVariables()`.
 */
namespace Hooks {
    namespace EffectText {
        namespace KillLeader {
            /**@brief patches the effect's two sites, once; safe to call again*/
            bool install();

            bool installed();

            /**@brief why it is not installed, when it is not*/
            const char* status();
        }
    }
}
