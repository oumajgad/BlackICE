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
 * The files live beside the DLL, under a folder of their own. Note that a deploy
 * clears that directory, so a developer redeploying loses the record; a player never
 * does.
 */

#include <cstdint>
#include <string>
#include <vector>

#include <Combat/CombatLog.hpp>

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
    };

    /**@brief what one country's fighting came to over a stretch of time*/
    struct Tally
    {
        int combats = 0;
        int won = 0;
        int lost = 0;
        int asAttacker = 0;
        int asDefender = 0;
        int losses = 0; // thousandths
        int kills = 0;
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
