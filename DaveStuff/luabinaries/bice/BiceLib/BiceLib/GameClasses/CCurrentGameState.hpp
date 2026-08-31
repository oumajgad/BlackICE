#pragma once
#include <cstdint>

/**
 * CCurrentGameState - the running game, and the one global everything else is reached
 * from.
 *
 * Held in a single module relative pointer, created lazily, `0xda8` bytes, constructed
 * at `0x27D070`. **It exists at the main menu**: its being non-null proves a session
 * has been started at some point, not that one is loaded now. Anything that must not
 * run outside a session needs a stronger check than this - see the note in
 * `README-imgui.md` about the Present hook.
 *
 * How the anchor and the combat fields were found is in `reversing/CLASSES.md`; the
 * autosave fields are in `reversing/FINDINGS-autosave.md` and the map mode ones in
 * `reversing/FINDINGS-mapmode.md`.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CCurrentGameState {
    /**@brief where the pointer to the live state lives, module relative*/
    constexpr uintptr_t GLOBAL_POINTER = 0x1689790;

    namespace VFTable {
        constexpr uintptr_t CCurrentGameState = 0x11CF674;   // module relative
    }

    namespace Offsets {
        /**@brief a CCombatManager, embedded rather than pointed at*/
        constexpr uintptr_t combat_manager = 0xB5C;

        /**@brief the CCombatHistory inside that manager (combat_manager + 0x18)*/
        constexpr uintptr_t combat_history = 0xB74;

        /**
         * The current tick: hours since 43800000, in years of 365 days with no leap
         * day. utils::gameTickToParts turns one into a date.
         */
        constexpr uintptr_t tick = 0xBDC;

        /**
         * **The CInGameIdler**, which holds the current map mode and the selection.
         * Confirmed: this pointer and the one instance found by scanning for
         * CInGameIdler's vftable are the same address, and the object here carries
         * that vftable. Its fields are in CInGameIdler.hpp.
         */
        constexpr uintptr_t in_game_screen = 0xBE8;

        /**
         * **Every country in the game**, as a vector of CCountry*: begin and end, with
         * four byte elements, so the count is (end - begin) / 4.
         *
         * This is the game's own list - `CCountryDataBase.GetCountries` in Lua hands
         * out the address of exactly this - so it is always current and cannot miss a
         * country. CCountry::all() reads it.
         */
        constexpr uintptr_t countries_begin = 0xBBC;
        constexpr uintptr_t countries_end = 0xBC0;

        /**
         * One entry per country id, non zero for a country somebody is playing. From
         * `DaveStuff/mem/classes/CCurrentGameState.py`, and confirmed live: the entry
         * for the country being played reads 1.
         */
        constexpr uintptr_t played_countries_array = 0xBCC;

        /**
         * The player's country tag: three characters, a NUL, then the country id, the
         * way a tag is held everywhere. The game reads it as a C string when it builds
         * a save file name, which is how it was found, and it reads as the country
         * being played in a running game.
         *
         * **Not +0x18.** `DaveStuff/mem/classes/CCurrentGameState.py` records the
         * player tag there, but that script reads its fields from the address of the
         * global rather than from the object it points at, so its base is one
         * dereference short. Measured from the object, +0x18 is a tag field holding
         * `---`, the null tag, in a running single player game - as is +0x90 - while
         * +0xC30 holds the country actually being played. The offsets in that file are
         * otherwise good against the object: +0xBCC above came from it and checks out.
         */
        constexpr uintptr_t player_tag = 0xC30;

        /**
         * Checked before the game will consider an autosave, and it has to be zero.
         * It is zero in an ordinary running game, so it is not "a session is loaded";
         * what it actually means has not been established.
         */
        constexpr uintptr_t autosave_blocked = 0xD9D;
    }

    /**
    @brief the live game state, or 0 when there is none

    Reads the global through Mem::tryRead, so a module that is not loaded or a pointer
    that is not one answers 0 rather than faulting.
    */
    uintptr_t current();

    /**
    @brief the current tick, or 0 when there is no session

    Zero is not a real tick - the epoch is 43800000 - so it doubles as "there is
    nothing to read".
    */
    int currentTick();
}
