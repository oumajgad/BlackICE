#pragma once

/**
 * Extra variables for the text an event option's effects show.
 *
 * The game builds that text out of a localisation string with `$NAME$` style variables
 * in it, and fills each one in as it goes. `kill_leader` fills in one, `$NAME$`, so
 * `KILL_LEADER_EFFECT` can say which leader is going and nothing else - not which unit
 * he commands, nor where that unit is, which is what tells a player whether it matters.
 *
 * This adds three more variables to that one effect, so the localisation can place
 * them:
 *
 * | | |
 * | --- | --- |
 * | `$UNIT$` | the unit the leader commands, empty in the officer pool |
 * | `$LOCATION$` | the province that unit is in, from its `PROV<id>` localisation |
 * | `$WHERE$` | ` (unit, province)` ready made, and empty rather than ` ()` |
 *
 * `$WHERE$` is the one to use in a sentence, because the other two leave an empty
 * bracket behind on a leader with no command. All three do nothing unless the
 * localisation asks for them, so the game's own `$NAME$` line keeps working untouched.
 *
 * **The localisation is what decides whether any of this shows.** A string that asks
 * for a variable BiceLib is not there to fill shows the `$WHERE$` as it stands, so the
 * failure is visible rather than silent.
 *
 * Two stubs, both standing in for a `call` and both reproducing it: one to catch which
 * leader the text is being built for, and one to add the variables beside the game's
 * own. How the effect text is built, and where the addresses come from, is in
 * reversing/FINDINGS-effecttext.md.
 *
 * **Switched on from Lua**, like every other hook that changes what the game shows:
 * `BiceLib.EffectTexts.activateKillLeaderVariables()` in `bicelib_lua.lua`. Nothing is
 * patched until it is called.
 */
namespace Hooks {
    namespace EffectText {
        /**@brief patches the two sites, once; safe to call again*/
        bool install();

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
