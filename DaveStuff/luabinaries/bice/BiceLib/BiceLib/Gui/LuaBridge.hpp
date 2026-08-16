#pragma once

#include <string>

/**
 * The one place the overlay talks to Lua.
 *
 * Phase 0 established that hoi3_tfh.exe's Present runs on a thread that also runs
 * Lua, and never renders while another thread is inside Lua, so calling the
 * interpreter from the render thread is safe. That measurement only observed threads
 * entering BiceLib's own exports though, so every call here is guarded rather than
 * assumed: wrong thread, unknown state or a call already in flight all mean "skip".
 *
 * Pages call Lua functions by dotted path ("BiceLibGui.ICDays.Collect") so each page
 * can own its own Lua namespace.
 */
namespace Gui {
    namespace Lua {
        /**
        @brief whether a game session exists

        Page data comes from CCurrentGameState, CCountryDataBase and friends, which
        are only meaningful in a running game. Calling them at the main menu faults
        inside the game's own code, where lua_pcall offers no protection, so this
        gates every call rather than leaving it to each page to remember.

        Read straight from the CCurrentGameState pointer instead of a flag set by the
        mod's daily tick: the pointer is correct even while the game is paused, and it
        needs no cooperation from Lua.
        */
        bool sessionActive();

        /**@brief whether a call may be made right now (session, render thread, known state, not re-entrant)*/
        bool available();

        /**@brief why available() is false, for showing in the page*/
        const char* unavailableReason();

        /**
        @brief calls a no argument Lua function and leaves its table result on the stack

        Every successful call must be paired with endCall(). Field readers below only
        work between the two.
        */
        bool beginTableCall(const char* dottedPath);
        void endCall();

        /**@brief reads a field of the table currently on top of the stack*/
        double numberField(const char* key, double fallback = 0.0);
        bool boolField(const char* key, bool fallback = false);
        std::string stringField(const char* key, const char* fallback = "");

        /**@brief number of entries in the array field \p key, 0 if it is not a table*/
        int arrayLength(const char* key);

        /**@brief reads element \p index (0 based) of a plain array of strings*/
        std::string arrayStringAt(const char* key, int index);

        /**
        @brief pushes element \p index (0 based) of an array of tables onto the stack

        While pushed, the field readers above address that row. Pair every true
        result with popArrayElement().
        */
        bool pushArrayElement(const char* key, int index);
        void popArrayElement();

        /**@brief calls a Lua function with no arguments, discarding results*/
        bool call(const char* dottedPath);

        /**@brief calls a Lua function with one number argument, discarding results*/
        bool callWithNumber(const char* dottedPath, double value);

        /**@brief calls a Lua function with one string argument, discarding results*/
        bool callWithString(const char* dottedPath, const char* value);
    }
}
