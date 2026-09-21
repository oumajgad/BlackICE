#pragma once

#include <Windows.h>

#include <cstddef>
#include <cstdint>

/**
 * Saves the game and closes it, rather than letting it run out of memory and crash.
 *
 * A 32 bit process runs out of **places to put things** long before the machine runs
 * out of memory, and that is what kills this one. Once it does, the game dies wherever
 * it happens to be, and whatever was unsaved is gone.
 *
 * ## What it watches, and what it does not
 *
 * **The largest single block the process can still be given**, and not the total free
 * space, which was tried first and is the wrong number: two deaths were measured with
 * 16 and 30 MB still free and nothing bigger than 244 KB to put anything in. An
 * allocation needs one block, so a process with plenty of room in small pieces is
 * already finished.
 *
 * Measured by asking for a block and giving it straight back, which is the same
 * question a failing allocation asks, costs one call while the answer is yes, and
 * needs no walk of the address space. Taken twice a second from the Present hook.
 *
 * ## What it does
 *
 * Below the threshold, and once only: ask the game to save, wait for it to be written,
 * say why in a message box, and close the game. The save is the game's own autosave
 * writer - `[idler+0xAB0]` is the whole of how one is asked for - so it happens on the
 * game's own thread in the game's own time, named `crashsave` through the same
 * rotation the scheduled saves use. See reversing/FINDINGS-autosave.md.
 *
 * **Measured**: three of these were written in four frames each with the largest free
 * block at 2 and 4 MB, and the save's own net cost was about 356 KB.
 *
 * ## What used to be here
 *
 * A new handler installed into the game's own CRT, so a refused allocation could be
 * caught at the moment it happened. It worked - it was installed, live, and provably
 * never called - because the game dies without its own allocator ever refusing
 * anything. There was also a 64 MB reserved "parachute" handed to the save, which the
 * measurements above show it does not need. Both are gone; the reasoning and the
 * disassembly behind them are kept in reversing/FINDINGS-allocator.md.
 */
namespace OutOfMemory {
    /**
     * How small the largest block it can still get means the game is finished.
     *
     * Low enough that an ordinary session never reaches it, and high enough that there
     * is still room to write a save when it does - which was measured at about 356 KB
     * with the block size down at 2 MB.
     */
    constexpr unsigned __int64 DEFAULT_TRIGGER_AT = 2u * 1024u * 1024u;

    /**@brief where the crash save has got to*/
    enum class Stage
    {
        Watching,   // nothing wrong yet
        Saving,     // the save has been asked for, waiting for the game to write it
        Done,       // written; the message is up and the game is about to be closed
        Failed,     // it could not be asked for, or the game never wrote it
    };

    /**
    @brief looked at once a frame, from the Present hook

    Cheap while nothing is wrong: one call for the free space, and a probe twice a
    second that stops at the first size it gets.
    */
    void update();

    /**@brief the free address space as of the last frame, in total*/
    unsigned __int64 freeNow();

    /**
    @brief the largest single block the process can still be given

    **This is what the trigger watches.** Worth showing on its own: a session where it
    is falling is a session on its way out, and the total free space says nothing about
    that.
    */
    unsigned __int64 largestBlock();

    bool watching();

    /**
    @brief turns it on or off, and remembers which

    Off means the game is left to die however it would have. On means that below the
    threshold it is saved, told why, and **closed** - which is a large thing to do to
    somebody's game, so it is one checkbox and it says so.
    */
    void setWatching(bool on);

    /**@brief the largest block below which the crash save fires*/
    unsigned __int64 triggerAt();
    void setTriggerAt(unsigned __int64 bytes);

    Stage stage();

    /**@brief one line on what happened, for the page and the message box*/
    const char* stageText();

    /**
    @brief starts the crash save now, whatever the free space is

    The same path the threshold takes, so testing it tests the real thing - message
    box and closing the game included.
    */
    void trigger();

    /**@brief free address space when the save was asked for, 0 if it has not been*/
    unsigned __int64 freeAtTrigger();

    /**@brief and when the game had finished writing it*/
    unsigned __int64 freeAfterSave();

    // ---- the ballast -----------------------------------------------------------------

    /**
     * How much room the ballast leaves the game by default.
     *
     * Enough to keep drawing and to get a frame or two further, little enough that the
     * next thing the game wants is refused.
     */
    constexpr unsigned __int64 DEFAULT_LEAVE_FREE = 50u * 1024u * 1024u;

    /**
    @brief holds the address space down to \p leaveFree and keeps holding it

    **For bringing the wall to the game rather than waiting for it.** Takes everything
    but a sliver and keeps it, so the crash save can be seen doing its job in a minute
    instead of after an evening's play.

    **Nothing gives it back except releaseBallast.** An earlier version handed a chunk
    back on each failed allocation; that quietly changed the memory picture in the
    middle of the test it was meant to serve, and it is gone.

    `leaveFree` is approximate: free address space includes holes too small for
    anything to use, and those count towards it.

    @returns how many reservations it took
    */
    int hold(unsigned __int64 leaveFree);

    /**@brief gives the whole ballast back at once*/
    void releaseBallast();

    /**@brief how much ballast is still held*/
    unsigned __int64 ballastHeld();

    /**@brief how many reservations it is held in*/
    int ballastReservations();
}
