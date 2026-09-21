#pragma once

#include <Windows.h>

#include <cstdint>

/**
 * Saves the game and closes it, instead of letting it crash.
 *
 * Shared by everything that can see the game is finished before it dies: the address
 * space watch in OutOfMemory, and the pure virtual call handler in PureCall. Each of
 * those decides *that* the game is over; this decides what to do about it.
 *
 * ## The save
 *
 * The game's own autosave writer does the work. `[idler+0xAB0]` is the whole of how
 * one is asked for - the writer runs every frame and does nothing until that byte is
 * set - so nothing here has to know how a save is built. It is named `crashsave`
 * through the same rotation the scheduled saves use, so it keeps three files of its
 * own and never ages out an autosave. See reversing/FINDINGS-autosave.md.
 *
 * ## Two ways in, because the callers are in different positions
 *
 * **From the frame loop** (requestFromFrameLoop): raise the flag and let the game's
 * own writer pick it up next frame, on its own thread, in its own time. The safest
 * way, and the right one when there will *be* a next frame.
 *
 * **Right now** (saveNowAndClose): set both flags and call the writer directly, on
 * whatever thread is asking. For a caller that cannot return and wait - a purecall
 * handler returns into the CRT's abort path, so there is no next frame to wait for.
 *
 * ## What it costs, measured
 *
 * Three of these were written in four frames each with the largest free block down at
 * 2 and 4 MB, and the save's own net cost was about 356 KB. It does not need much,
 * which is why no memory is held in reserve for it.
 */
namespace CrashSave {
    /**@brief how far along a crash save is*/
    enum class Stage
    {
        Idle,       // nothing has gone wrong
        Saving,     // asked for, waiting for the game to write it
        Done,       // written
        Failed,     // could not be asked for, or the game never wrote it
    };

    Stage stage();

    /**@brief one line on what happened, for the page and the message box*/
    const char* stageText();

    /**@brief what asked for it, for the page and the message box*/
    const char* reason();

    /**
    @brief pumped once a frame, from the Present hook

    Does nothing at all unless a save is waiting to be written. Only the frame loop
    path needs it; saveNowAndClose never returns.
    */
    void update();

    /**
    @brief asks the game to save, then to be told and closed

    Returns immediately. The save lands a frame or two later and the message box comes
    with it. Once asked, it is asked - a second call does nothing.

    @param why what went wrong, as the message box should say it, e.g.
           "has run out of memory"
    */
    void requestFromFrameLoop(const char* why);

    /**
    @brief saves, says why, and closes the game, without returning

    For a caller that has no next frame. The save is written synchronously on the
    calling thread by calling the game's writer directly, so it is done by the time
    this moves on.

    **It does not come back.** The process is ended once the message box is dismissed,
    which is what the caller was about to happen to anyway.

    @param why what went wrong, as the message box should say it
    @param caveat an extra paragraph warning what the save may be worth, or null
           where there is nothing to warn about
    */
    void saveNowAndClose(const char* why, const char* caveat = nullptr);

    /**@brief appends a line to OutOfMemory.log beside the DLL*/
    void log(const char* text);

    /**@brief free address space when the save was asked for, 0 if it has not been*/
    unsigned __int64 roomBefore();

    /**@brief and when the game had finished writing it*/
    unsigned __int64 roomAfter();
}
