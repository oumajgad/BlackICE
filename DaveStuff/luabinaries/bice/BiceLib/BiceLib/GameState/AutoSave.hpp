#pragma once

#include <cstdint>
#include <string>

/**
 * Two extra autosaves, each switched on by itself.
 *
 * **Before the month turns.** The game evaluates event trigger conditions on the month
 * change and only then. A save made after that moment has already had its evaluation,
 * so loading it fires nothing for that month; a save made shortly before it still has
 * the evaluation ahead of it. This takes one, every month, at a configurable distance
 * from the 1st.
 *
 * **Every so many minutes.** A save on a wall clock rather than a game calendar, so
 * the most a crash can cost is the interval, whatever speed the game is running at.
 *
 * Both sit alongside the game's own autosave rather than replacing it. The frequency
 * in `settings.txt` keeps working exactly as before, and switching both off leaves the
 * game deciding on its own.
 *
 * Each rotates among three files of its own, the way the game's own autosave does -
 * `autosave_premonth.hoi3`, `oldautosave_premonth.hoi3`,
 * `olderautosave_premonth.hoi3`, and the same three for `autosave_timed` - so they
 * cannot pile up, and no set pushes another out.
 *
 * Rotating means the files are renamed as they age, so a name cannot carry the date it
 * was taken on. The date is still on the save itself, and the load menu shows it.
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
     * How far apart the timed saves may be asked for, in minutes of real time.
     *
     * A minute is the floor because the check only runs when the game day changes:
     * asking for less would not produce more saves, only a save on every day change.
     * Four hours is as far out as the feature is still doing anything for anybody.
     */
    constexpr int MIN_MINUTES = 1;
    constexpr int MAX_MINUTES = 240;
    constexpr int DEFAULT_MINUTES = 15;

    /**
    @brief puts back what was switched on last time

    Called once while BiceLib is starting. The rule has to be in place whether or not
    anybody opens the page, so this is what installs the hooks after a restart rather
    than the first draw of the page.
    */
    void restore();

    /**@brief whether the save before the month change is switched on*/
    bool enabled();

    /**
    @brief turns it on or off, and remembers which

    Installs the hooks the first time either save is turned on. With both off the stubs
    reproduce the instructions they replaced and call nothing here.
    */
    void setEnabled(bool on);

    /**@brief whether the save on a timer is switched on*/
    bool timedEnabled();
    void setTimedEnabled(bool on);

    /**
    @brief how many minutes of real time between timed saves

    Real time, not game time: it is measured with the system clock and does not care
    what speed the game is at. It is only *looked* at when the game day changes, which
    is the one moment BiceLib is called at, so a paused game takes no saves and a
    running one takes its save on the first day change after the interval is up.
    */
    int minutes();
    void setMinutes(int value);

    /**
    @brief how long until the timed save is due, in seconds

    Negative when nothing is being timed - the feature is off, or no day has passed
    yet. Zero means it is due and waiting for the game day to change.
    */
    int secondsUntilDue();

    /**
    @brief how many days before the 1st of the next month the save is taken

    Two means the save is dated two days before the 1st: on the 30th of a 31 day
    month, the 26th of February.
    */
    int daysBefore();
    void setDaysBefore(int days);

    /**
    @brief what the monthly save's three rotating files are called

    The base of the name, before the prefix and the extension. Written into the game's
    own name building, so it may hold only what a file name may hold. Empty falls back
    to a default rather than producing files called `.hoi3`.
    */
    const std::string& saveName();
    void setSaveName(const std::string& text);

    /**@brief the same, for the timed save's own three files*/
    const std::string& timedSaveName();
    void setTimedSaveName(const std::string& text);

    /**
    @brief one of the monthly save's three file names, newest first, for the page
    */
    std::string fileName(int slot);

    /**@brief one of the timed save's three file names, newest first*/
    std::string timedFileName(int slot);

    /**
    @brief whether this tick is the day the monthly save should be taken on

    Pure arithmetic on the tick, so it is cheap enough for the hook and testable
    without a game.
    */
    bool isSaveDay(int tick);

    /**
    @brief the hook's entry point: asks the game for a save if one is due

    Called with the game's own autosave flag already cleared, which is the state the
    decision function leaves behind before making its own mind up. Setting the flag
    here adds a save; the game's own decision runs afterwards and may set it too,
    which changes nothing - a flag already raised cannot be raised twice.

    It is the only moment either extra save is decided, and it comes round once per
    game day, so both are as fine grained as that and no finer.

    The month save is asked first where both are due on the same call: there is one
    request flag, so one save, and the month save is the one that has to land on a
    particular day. The timer is restarted by it either way - a save has been taken,
    which is all the timer is promising.

    @param idler the CInGameIdler the decision was called about
    @param tick the current tick, as the decision function read it
    */
    void onDecision(uintptr_t idler, int tick);

    /**@brief the date of the last monthly save asked for, empty until there is one*/
    const std::string& lastRequested();

    /**@brief how many monthly saves this has asked for since the DLL was loaded*/
    int requestedCount();

    /**@brief the same two, for the timed save*/
    const std::string& lastTimedRequested();
    int timedRequestedCount();

    bool hooked();

    /**@brief why it is not hooked, when it is not*/
    const char* status();
}
