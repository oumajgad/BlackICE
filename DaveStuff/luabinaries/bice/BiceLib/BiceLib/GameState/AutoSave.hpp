#pragma once

#include <cstdint>
#include <string>

/**
 * An extra autosave, taken a few days before the month turns.
 *
 * The game evaluates event trigger conditions on the month change and only then. A
 * save made after that moment has already had its evaluation, so loading it fires
 * nothing for that month; a save made shortly before it still has the evaluation
 * ahead of it. This takes one, every month, at a configurable distance from the 1st.
 *
 * It sits alongside the game's own autosave rather than replacing it. The frequency
 * in `settings.txt` keeps working exactly as before, and switching this off leaves
 * the game deciding on its own.
 *
 * The saves are named for their date with a suffix - `IRE_1937_02_27_14_premonth.hoi3`
 * - and so do not enter the three file rotation the game's own autosave uses. Nothing
 * prunes them; they accumulate until deleted by hand.
 *
 * How the game's own decision was found, and why the hook sits where it does, is in
 * reversing/FINDINGS-autosave.md.
 */
namespace AutoSave {
    /**
     * How close to the month change the save may be asked for.
     *
     * One day is the latest that is still before the change. The upper bound is a day
     * short of February so the chosen day exists in every month; asking for more
     * would silently skip the short ones.
     */
    constexpr int MIN_DAYS_BEFORE = 1;
    constexpr int MAX_DAYS_BEFORE = 27;
    constexpr int DEFAULT_DAYS_BEFORE = 2;

    /**
    @brief puts back what was switched on last time

    Called once while BiceLib is starting. The rule has to be in place whether or not
    anybody opens the page, so this is what installs the hooks after a restart rather
    than the first draw of the page.
    */
    void restore();

    /**@brief whether the extra save is switched on*/
    bool enabled();

    /**
    @brief turns it on or off, and remembers which

    Installs the hooks the first time it is turned on. While off the stubs reproduce
    the instructions they replaced and call nothing here.
    */
    void setEnabled(bool on);

    /**
    @brief how many days before the 1st of the next month the save is taken

    Two means the save is dated two days before the 1st: on the 30th of a 31 day
    month, the 26th of February.
    */
    int daysBefore();
    void setDaysBefore(int days);

    /**
    @brief what is put on the end of the name, before the extension

    Written into the game's own name building, so it may hold only what a file name
    may hold. An empty suffix is allowed and gives a name the game itself could have
    written.
    */
    const std::string& suffix();
    void setSuffix(const std::string& text);

    /**
    @brief whether this tick is the day the save should be taken on

    Pure arithmetic on the tick, so it is cheap enough for the hook and testable
    without a game.
    */
    bool isSaveDay(int tick);

    /**
    @brief the hook's entry point: asks the game for a save if this is the day

    Called with the game's own autosave flag already cleared, which is the state the
    decision function leaves behind before making its own mind up. Setting the flag
    here adds a save; the game's own decision runs afterwards and may set it too,
    which changes nothing - a flag already raised cannot be raised twice.

    @param idler the CInGameIdler the decision was called about
    @param tick the current tick, as the decision function read it
    */
    void onDecision(uintptr_t idler, int tick);

    /**@brief the date of the last save this asked for, empty until one is asked for*/
    const std::string& lastRequested();

    /**@brief how many this has asked for since the DLL was loaded*/
    int requestedCount();

    /**@brief the name the next save would be given, for the page to show*/
    std::string exampleName();

    bool hooked();

    /**@brief why it is not hooked, when it is not*/
    const char* status();
}
