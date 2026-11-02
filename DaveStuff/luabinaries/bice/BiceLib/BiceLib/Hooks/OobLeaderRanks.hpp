#pragma once

/**
 * Gives a leader an order of battle puts on a land unit the rank that unit takes.
 *
 * An order of battle's `leader = N` puts leader N on the unit **whoever he is** - the
 * game compares nothing of his with the unit's. So a file written against one set of
 * leader histories, or a history whose `rank` the game never applies (a leader dated after
 * the start comes into service at rank 1 whatever it says), leaves leaders commanding
 * units the game itself would never let them take. Below the rank his command needs the
 * unit gets nothing of him in battle and his name is written in red.
 *
 * ## The rule
 *
 * The game's own, from `CUnit::MayTakeLeader` (`0x1BFBA0`) - what a player and the
 * automatic choice may put on a land unit, an exact rank by its level:
 *
 * | level | rank |
 * | --- | --- |
 * | division | 1 |
 * | corps | 2 |
 * | army | 3 |
 * | army group | 4 |
 * | theatre | 4 |
 *
 * So a leader is **raised or lowered** to it. Fleets and air units are left alone: they
 * take any rank. So is a leader of the wrong arm, and **a leader of another country** - the
 * maintainer's choice, which also keeps clear of a new game putting a country's leaders in
 * service only once its own turn comes (below).
 *
 * ## Where it stands
 *
 * **On the two calls to `CUnit::SetLeader` in `CUnit::LoadKey`'s `leader` case**
 * (`0x1B7787` for `leader = N`, `0x1B77E7` for a save's `leader = { id type }`). Both
 * are redirected here, and the leader's rank is fitted just before the game's own call.
 * The unit's level is already set by then: the loader writes `oob_level` from the block's
 * keyword before it reads the block, and the owner too.
 *
 * **Only while an order of battle file is being read.** `CUnit::LoadKey` also reads every
 * unit out of a save, so the three calls to `CCountry::LoadOobFile` (`0xFFED0`) are
 * redirected as well and keep a count while one runs. Those three are the `load_oob`
 * effect, a new game's history order of battle, and the custom game setup's reset of its
 * units stage. A save goes through none of them.
 * reversing/findings/FINDINGS-leaderassign.md, section 3.1, has all of it.
 *
 * ## Putting him in service
 *
 * A leader whose history's first `rank` is dated after today is at rank 0 and not in his
 * country's `active_leaders`. Raising his rank alone would not last: on that date the
 * daily pass finds him missing from the list and sets him to rank 1. So a leader fitted
 * here who is not in the list is added to it, through the game's own
 * `CCountry::AddActiveLeader` (`0xDDB80`), with no change filed in the country's history -
 * as the daily pass files none.
 *
 * In a new game a country's leaders are put in service **before its own order of battle
 * is loaded**, and after the countries before it have loaded theirs. So adding a country's
 * own leader here cannot be repeated by the game later. Another country's leader could be
 * repeated, because `ActivateRankedLeaders` appends without looking, which is one more
 * reason those are left alone.
 *
 * ## Multiplayer
 *
 * Everything the fitting reads is game state - the leader's rank, arm and country, the
 * unit's level and owner, the country's list - and it runs at the point the order of
 * battle's own units are made. So it does on each machine whatever loading the file does
 * there, and adds no difference of its own. That holds only while every player has the
 * same BiceLib switched on the same way, which is why it is switched on from
 * `script/bicelib_lua.lua` and nowhere local.
 *
 * **Switched on from Lua**: `BiceLib.Leaders.activateOobLeaderRanks()`.
 */
namespace Hooks {
    namespace OobLeaderRanks {
        /**@brief patches the five calls, once; safe to call again*/
        bool install();

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();

        /**@brief the rank a land unit of this oob_level takes, or 0 for one it does not
                  fit - a fleet, an air unit, anything else*/
        int rankFor(int oobLevel);
    }
}
