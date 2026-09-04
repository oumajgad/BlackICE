#pragma once

/**
 * The record of finished combats, kept because the game does not keep one.
 *
 * The game prunes its own combat history after a few days, so a report covering a year
 * has to be built up as the game is played. Every combat the hook catches is appended
 * to a file belonging to the campaign, and the file is read back when a campaign is
 * resumed.
 *
 * One file per campaign, named for the number the campaign claims on OMG - see
 * script/utility_data/bicedata_combat.lua. Without that, two campaigns would pour
 * their combats into the same record.
 *
 * A campaign is not one timeline. Loading a savegame from a year ago and playing on
 * fights that year's battles again, differently, and the record ends up holding both
 * runs - so counting a month would add two timelines together. Every load therefore
 * starts a *session*, whose parent is the session the loaded savegame was written in,
 * and every combat is filed under the session that fought it. The chain of parents
 * from the current session back to the root is the timeline being played; a session
 * off that chain was abandoned and its combats are set aside.
 *
 * The chain alone is not enough, because an ancestor kept playing past the point the
 * branch left it. So a session also records the tick it started at, and an ancestor
 * counts only up to where its child in the chain branched off.
 *
 * The sessions live in a file of their own beside the combats, because they are a
 * different kind of thing and a reader of either should not have to skip the other.
 *
 * The files live beside the DLL, under a folder of their own, which a deploy keeps -
 * see PreserveInScript in zDsafeMoveFiles.py. A record is months of playing and is
 * not reproducible, so it outlives the DLL that wrote it.
 */

#include <cstdint>
#include <string>
#include <vector>

#include <GameState/CombatLog.hpp>

namespace Combat {
    struct Entry
    {
        unsigned int tick = 0;
        Branch branch = Branch::Unknown;
        int provinceId = 0;
        Outcome winner = Outcome::Unknown;

        // The game names only the winner - it reads a side's tag out of a country
        // list the beaten side no longer has. The loser's tag here comes from a second
        // list the beaten side keeps, and is "---" only when that could not be read
        // either, in which case the combat cannot be counted for the country that
        // lost it. See Combat/CombatLog.
        char attackerTag[8] = {};
        int attackerId = 0;
        int attackerLosses = 0; // thousandths
        int attackerMen = 0;    // what it had in the fight, whole men

        char defenderTag[8] = {};
        int defenderId = 0;
        int defenderLosses = 0;
        int defenderMen = 0;

        // Which run of the campaign fought it. Zero for a combat written before
        // sessions existed, which the chain treats as the root of every timeline -
        // so an old record keeps counting rather than disappearing.
        unsigned int session = 0;
    };

    /**@brief what one country's fighting came to over a stretch of time*/
    struct Tally
    {
        int combats = 0;
        int won = 0;
        int lost = 0;
        int asAttacker = 0;
        int asDefender = 0;
        // Sixty four bits, because these are thousandths of a man added up over a
        // whole war. Thirty two run out at 2.1 billion, which is only 2.1 million
        // casualties - a figure the eastern front passes without trying, and one an
        // int reports as a negative number when it does.
        int64_t losses = 0; // thousandths
        int64_t kills = 0;
    };

    namespace Store {
        /**
        @brief keeps the record current

        Asks Lua for the campaign number if it does not have one, loads that
        campaign's file the first time, and drains whatever the hook has captured
        since. Cheap enough to call every frame; does its work only when there is
        work.

        Call from the render thread - it talks to Lua and touches files, neither of
        which belongs on the thread the hook runs on.
        */
        void update();

        /**@brief 0 until the campaign has claimed a number*/
        int campaign();

        /**@brief where the record is being kept, empty until there is a campaign*/
        const std::string& path();

        /**@brief where the sessions are listed, empty until there is a campaign*/
        const std::string& sessionPath();

        /**@brief the session combats are being filed under, 0 before one is claimed*/
        unsigned int session();

        /**@brief how many sessions the timeline being played is made of*/
        int timelineDepth();

        /**@brief combats in the file that belong to a branch this timeline left*/
        int setAside();

        /**
        @brief true when a savegame has been loaded and the session is not known yet

        A load is spotted from the game's clock, which costs nothing, but the session
        it started can only be read through Lua - and this only talks to Lua once a
        combat has been captured, since there is no safe way to call it at the main
        menu. In between, the page is showing the timeline as it was before the load.
        Combat is near enough constant in a war that the gap closes in game hours;
        in peace it can be long, and there is nothing in it to get wrong.
        */
        bool sessionPending();

        /**@brief why there is no record yet, when there is none*/
        const std::string& reason();

        int count();

        /**@brief combats the hook caught that were overwritten before they could be
           filed. Should be zero; anything else means the drain stalled*/
        unsigned int lost();
        const std::vector<Entry>& entries();

        /**
        @brief adds up what \p tag did between two ticks

        @param branch the kind of combat to count, or Branch::Unknown for all of them
        */
        Tally tally(const std::string& tag, unsigned int fromTick, unsigned int toTick,
            Branch branch);

        /**@brief the game's current tick, 0 if it cannot be read*/
        unsigned int currentTick();

    }
}
