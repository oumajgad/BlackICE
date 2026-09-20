#pragma once

#include <cstdint>
#include <string>

/**
 * What an event option's effects say they will do, and the parts for changing it.
 *
 * Every effect builds its own sentence, in its own function, reached through slot 9 of
 * its class - so **a patch here is always per effect**, and each one lives in a file of
 * its own beside this. What they have in common is here.
 *
 * There are two shapes a patch can take, and which one fits depends on the effect:
 *
 * **Fill in a variable.** An effect whose text comes from a localisation string with
 * `$NAME$` style variables in it can be given more of them, and the localisation
 * decides whether and where they show. `KillLeaderText.hpp` does this.
 *
 * **Write the line.** An effect with no localisation behind it - `load_oob` looks its
 * file path up as though the path were a key, and shows what comes back - has nothing
 * to fill in, so the built string is replaced instead. `LoadOobText.hpp` does this.
 *
 * Each patch is switched on from Lua by itself, under `BiceLib.EffectTexts`, and
 * nothing is written to the game until it is. How the effect text machinery was worked
 * out is in reversing/FINDINGS-effecttext.md.
 */
namespace Hooks {
    namespace EffectText {
        /**
        @brief finds the parts below, once; false where this build does not have them

        Called by each patch's own install before it writes anything.
        */
        bool ready();

        /**
        @brief the game's own `text.Replace(key, value)`

        Three arguments in three places - the text in ecx, the key in esi, the value on
        the stack - so it cannot be called from C at all. The key is the variable's name
        without its dollars, and the value is copied, so neither need outlive the call.

        Both are game strings: pass `Game::String::raw()`, or a pointer to one the game
        owns.
        */
        void replaceVariable(void* text, const void* key, const void* value);

        /**
        @brief the same, from plain characters

        The text stays Windows-1252, and a value that is going to sit inside a colour
        should have had its own colours taken out - see `Game::withoutColours`.
        */
        void setVariable(void* text, const char* name, const char* value);

        /**
        @brief the country an effect's scope is about, or 0

        A scope carries a `CCountryTag` at +0x10, which is what the kill_leader builder
        reads and what CLoadOOBEffect::Execute indexes the country database with.
        */
        uintptr_t countryOfScope(uintptr_t scope);

        /**@brief what a leader commands and where, as text; empty when he commands nothing*/
        struct Posting
        {
            std::string unit;       // the unit's name, with its own colours taken out
            std::string province;   // where that unit is, or "" if it cannot be read

            bool any() const { return !unit.empty(); }
        };

        /**
        @brief where a leader is **now**, read out of the running game

        The one question both patches ask of the game rather than of a file: what a
        leader is about to be taken from.
        */
        Posting postingOf(uintptr_t leader);
    }
}
