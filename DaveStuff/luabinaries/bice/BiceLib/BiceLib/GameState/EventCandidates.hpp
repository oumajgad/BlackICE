#pragma once

#include <string>

/**
 * Rebuilds the game's per-country candidate event lists, which a load leaves empty.
 *
 * **The bug this fixes.** The daily event pass does not look at the event database; it
 * walks a per-country list of candidates at `CCountry +0x8`, and skips a country whose
 * list is empty. That list is built in exactly one function, and the only thing on the
 * tick that calls it is the **monthly** pass. It is not in the savegame and
 * `CCountry::AfterLoad` does not build it, so a loaded game has every list empty and
 * fires nothing at all until the month turns - then a barrage arrives at once. Load on
 * the 2nd of a month and nearly four weeks of events pile up behind it.
 *
 * `is_triggered_only` events are unaffected either way: they are never candidates, so
 * they keep working through the dead period. That is the tell, if you want to see the
 * bug rather than take it on trust.
 *
 * **Nothing is patched.** The engine's own rebuild is left exactly as written and simply
 * called earlier - the same call, with the same argument, that the monthly pass makes. It
 * clears each list before refilling it, so calling it when the lists are already good is
 * harmless: the cost is one wasted pass.
 *
 * **Every country, not only the one being played.** The rebuild's first pass walks the
 * whole country database and frees every country's list with no filter at all; its second
 * pass refills them from the event list. The count this records is the player's only
 * because that is the cheapest one to look up and report.
 *
 * **Driven from Lua**, by `BiceLib.Events.rebuildCandidates()` in the mod's OMG handler,
 * which runs once after each save is loaded. That makes it switchable with the rest of
 * the mod's scripted behaviour rather than something the DLL does on its own.
 *
 * reversing/findings/FINDINGS-events.md has the three layers and how the bug was found.
 */
namespace EventCandidates {
    /**
    @brief rebuilds every country's candidate event list now; false if it did not run

    Checks that a game is on screen, that the scenario's event list exists, that the game
    is not busy with a save or a load, and that the engine's rebuild is the one this was
    written against - and does nothing at all if any of those fails, rather than calling
    into something it does not recognise. Safe to call more than once.

    Call it from the game's own thread: the tick and the overlay's Present share the one
    that owns the Lua state, and the lists this walks belong to it.
    */
    bool rebuildNow();

    /**
     * What the last call did.
     */
    struct Status
    {
        bool ran = false;           // whether a call has been made in this run
        int ranTick = 0;            // the clock reading when it was made
        bool ok = false;            // whether it did the work
        std::string lastError;      // why it did not, when it did not

        // The candidate count for the country being played, read either side of the call.
        // These test the diagnosis as well as the fix: `countBefore` should be 0 after a
        // load, and a number in the hundreds there would mean a load does build the lists
        // after all and the barrage has some other cause. -1 means it could not be read.
        std::string playerTag;
        int countBefore = -1;
        int countAfter = -1;
    };

    /**@brief what the last call did*/
    Status status();
}
