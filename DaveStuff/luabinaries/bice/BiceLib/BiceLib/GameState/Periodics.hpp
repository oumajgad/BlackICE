#pragma once

#include <string>

/**
 * Runs the mod's BiceLib setup from every game in a session, once a game day.
 *
 * Some of what BiceLib changes is set from Lua and held in each game's own memory - the
 * unit limits of each HQ, which depend on technology. In multiplayer only the host runs
 * the mod's scheduled scripts, so without this a client keeps whatever it was set up
 * with. The overlay's Present hook runs in every game, clients included, so the setup
 * is driven from there.
 *
 * The work itself is the Lua function BiceLibDailyPeriodics, in bicelib_lua.lua.
 */
namespace Periodics {
    /**
    @brief calls BiceLibDailyPeriodics once a game day; call every frame

    In the first frame of each day at one o'clock or later, and only on a frame where
    GameClock::movedInPlay() says a game is running. A day whose call could not be made
    because Lua was busy is tried again on the next frame the clock moves.
    */
    void update();

    /**
     * What the job has done in the game that is loaded now. All empty until its first
     * call after a load, and emptied again by the next load.
     */
    struct Status
    {
        int lastRunTick = 0;        // the last call made, 0 for none
        bool lastRunOk = false;     // whether it completed, rather than failed in Lua
        std::string lastError;      // why it failed, when it did

        int limitsCheckedTick = 0;  // the last call that also checked the OOB unit limits

        // The HQ unit limits BiceLib held for the country being played after the last
        // call; limitsKnown is false when that country could not be found.
        bool limitsKnown = false;
        std::string playerTag;
        int corpsLimit = 0;
        int armyLimit = 0;
        int armyGroupLimit = 0;
    };

    /**@brief the status for the game loaded now*/
    Status status();
}
