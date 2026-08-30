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
         * The in game screen, which is what holds the current map mode and the
         * selection. Very probably the CInGameIdler - both expose the map mode at
         * +0xD34 and both are driven as the same object - but that has not been
         * confirmed by comparing the two addresses in a running game, so
         * CInGameIdler.hpp is written as its own class rather than merged into this.
         */
        constexpr uintptr_t in_game_screen = 0xBE8;

        /**
         * The player's country tag: three characters, a NUL, then the country id, the
         * way a tag is held everywhere. The game reads it as a C string when it builds
         * a save file name.
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
