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

        /**
        @brief whether a game session is required for a call to be allowed

        On by default, and only the Lua console turns it off: a script that touches
        nothing but the mod's own Lua runs perfectly well at the main menu, and being
        able to poke at the parsers there is half the point of having a console. It is
        the caller's business what the script then reaches for - a game object at the
        menu still faults where no pcall can help.

        Restore it as soon as the call is done; leaving it off would let every other
        page fetch data at the menu, which is exactly what the gate exists to stop.
        */
        void setSessionRequired(bool required);

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

        /**@brief as beginTableCall, for a function taking one string argument*/
        bool beginTableCallWithString(const char* dottedPath, const char* value);

        /**@brief as beginTableCall, for a function taking one number argument*/
        bool beginTableCallWithNumber(const char* dottedPath, double value);

        /**@brief as beginTableCall, for a function taking a string and a number*/
        bool beginTableCallWithStringAndNumber(const char* dottedPath, const char* text, double number);

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

        /**
         * What the game's Lua interpreters are holding.
         *
         * The game opens a state per AI context and never closes one - lua_close is
         * not even among the functions it imports - so every state it has ever
         * opened is still alive, and each ran autoexec.lua and pulled in the whole
         * mod's Lua for itself. Whether that is tens of megabytes or hundreds is
         * worth knowing before anyone tries to do something about it.
         */
        struct StateMemory
        {
            int states = 0;      // states that have loaded BiceLib
            int distinct = 0;    // ... of which independent, rather than coroutines
            unsigned __int64 bytes = 0;
            unsigned __int64 largest = 0;
        };

        /**@brief totals Lua's own accounting across every state. Safe at any time:
           it reads a counter and neither allocates nor collects.*/
        StateMemory stateMemory();
    }
}
