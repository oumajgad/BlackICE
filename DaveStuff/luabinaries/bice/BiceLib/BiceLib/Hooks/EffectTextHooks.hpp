#pragma once

/**
 * What an event option's effects say they will do, for two effects that said too
 * little.
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
 * own.
 *
 * ## load_oob
 *
 * `load_oob = "GER/GER_Kriegsmarine_Creation.txt"` shows that path and nothing else,
 * because the effect looks the path up as though it were a localisation key and the
 * game has nothing to say about it. **There is no key to fill in here**, so BiceLib
 * writes the whole line instead: how many units appear, where, what they are made of,
 * and which leaders the file takes for itself - with what each of those commands now,
 * which is the part a player cannot find out any other way.
 *
 * Nothing about the file is in memory until the effect fires, so the file is read off
 * disk the same way the game will read it. See GameState/OobFile.hpp.
 *
 * **A leader whose rank is below the job gets a red line.** The rule is the order of
 * battle's own levels - a division is a major general's, a corps a lieutenant general's,
 * and everything above a corps a general's - and it is David's
 * choice, made against the numbers rather than assumed: across the mod's own
 * `history/units`, corps are led by a rank 1 leader 613 times of 844, so the warning is
 * meant to fire on those. Fleets and air commands are left out, because their levels do
 * not line up with the land ones.
 *
 * The engine has no such rule to copy - its only rank defines, `AIR_RANK_1..4` and
 * `NAVAL_RANK_1..4`, are command limits, not level requirements.
 *
 * Also two stubs: one at the function's entry to catch the effect, and one at the last
 * call before it returns, where the built string is in hand and can be replaced.
 *
 * How the effect text is built, and where the addresses come from, is in
 * reversing/FINDINGS-effecttext.md.
 *
 * **Both are switched on from Lua**, like every other hook that changes what the game
 * shows, and separately: `BiceLib.EffectTexts.activateKillLeaderVariables()` and
 * `activateLoadOobDetails()` in `bicelib_lua.lua`. Nothing is patched until they are
 * called.
 */
namespace Hooks {
    namespace EffectText {
        /**@brief patches the kill_leader effect's two sites, once; safe to call again*/
        bool installKillLeader();
        bool killLeaderInstalled();

        /**@brief patches the load_oob effect's two sites, once; safe to call again*/
        bool installLoadOob();
        bool loadOobInstalled();

        /**@brief why the last one that was asked for is not installed*/
        const char* status();
    }
}
