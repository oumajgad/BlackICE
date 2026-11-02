#pragma once

/**
 * Brings a leader into service at the rank his history names, not at rank 1.
 *
 * A leader whose history dates his first `rank` after the game's start is at rank 0 and
 * out of service until that day. Then the country's daily pass (`RunCountryDailyPass`,
 * `0xDA530`) puts him in `active_leaders` - **and writes rank 1, whatever the line says**
 * (`mov dword ptr [edi + 0x6C], 1` at `0xDAACE`). So `1939.1.1 = { rank = 3 }` makes a
 * major general of him in 1939. BlackICE's histories have 527 such lines; the validator
 * reports each as BV313.
 *
 * ## The patch
 *
 * **On that one store.** It becomes a jump here, and the rank written is the one the line
 * names: the first `CRankChange` in the leader's history entries, which is the entry the
 * pass matched today's date against - it walks the same list for the first entry whose
 * slot 6 answers `rank`, and only a CRankChange does. The pass had dropped the entry by the
 * time of the store, so it is found again rather than read out of a register.
 *
 * A rank outside 1 to 4 is held to them: below 1 the leader would be in service at rank
 * 0, which the game never makes, and above 4 is a rank no promotion can reach.
 *
 * Everything else is the game's own: the day, the test that he is not in service yet, and
 * the append to the list after the store.
 *
 * ## What it does not do
 *
 * **A later `rank` line is still never applied** to a leader already in service: the pass
 * looks only for the first. The validator's BV313 reports those apart.
 *
 * A leader an order of battle has already put in service (Hooks/OobLeaderRanks.hpp) is
 * skipped by the pass on his day, as before, and keeps the rank his unit gave him.
 *
 * ## Multiplayer
 *
 * It reads only the leader's own history, inside the daily pass every machine runs, so it
 * writes the same rank on each. Switched on from `script/bicelib_lua.lua` for that reason.
 *
 * reversing/findings/FINDINGS-leaders.md, section 3, has the listing.
 *
 * **Switched on from Lua**: `BiceLib.Leaders.activateHistoryLeaderRanks()`.
 */
namespace Hooks {
    namespace HistoryLeaderRanks {
        /**@brief patches the store, once; safe to call again*/
        bool install();

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
