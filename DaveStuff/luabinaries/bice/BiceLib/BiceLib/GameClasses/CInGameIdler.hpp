#pragma once
#include <cstdint>

/**
 * CInGameIdler - the in game screen: the map view, the selection, and the autosave
 * request.
 *
 * One instance while a game is running. It can be found by scanning for its vftable,
 * which is what `cacheIngameIdler` in bice.cpp does, and it is very probably the same
 * object as CCurrentGameState::Offsets::in_game_screen - both hold the current map
 * mode at +0xD34. That has not been confirmed by comparing the two addresses live, so
 * neither file claims it as fact.
 *
 * The autosave fields, and how the decision that writes them was found, are in
 * `reversing/FINDINGS-autosave.md`. The map mode numbering is in
 * `reversing/FINDINGS-mapmode.md` and `reversing/mapmode.py`.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CInGameIdler {
    namespace VFTable {
        constexpr uintptr_t CInGameIdler = 0x11CEB54;   // module relative, 111 slots
    }

    namespace Offsets {
        /**
         * Zero in a single player game. The autosave decision reads it to pick between
         * setting the request flag directly and building a message instead, which
         * looks like multiplayer; that reading has not been tested.
         */
        constexpr uintptr_t multiplayer = 0x68;

        /**
         * **An autosave is wanted.** The writer does nothing until this is set, and
         * the decision clears it at the top of every run, so it is only ever live
         * between the two. Setting it is the whole of how BiceLib asks for a save.
         */
        constexpr uintptr_t autosave_requested = 0xAB0;

        /**@brief the writer has already spent its one frame of delay*/
        constexpr uintptr_t autosave_delayed = 0xAB1;

        /**
         * The map mode currently on screen, by the game's own numbering, which is not
         * the numbering in the gui files: the VP button is `mapmode_10` but mode 7.
         * `reversing/mapmode.py` has the full table and prints the live value.
         */
        constexpr uintptr_t current_map_mode = 0xD34;

        /**@brief the selected things, as the start and end of a list*/
        constexpr uintptr_t selection_first = 0x1304;
        constexpr uintptr_t selection_last = 0x1308;
    }

    /**
     * Map modes worth naming, by the game's numbering rather than the button names.
     * The rest are in reversing/mapmode.py.
     */
    namespace MapMode {
        constexpr int VICTORY_POINTS = 7;    // the one Custom Mapmode takes over
        constexpr int SIMPLIFIED_TERRAIN = 13;
        constexpr int AIR = 18;
        constexpr int NAVAL = 19;
    }
}
