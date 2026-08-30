#pragma once
#include <cstdint>

/**
 * CInGameIdler - the in game screen: the map view, the selection, and the autosave
 * request.
 *
 * One instance while a game is running, and it is **the object at
 * CCurrentGameState::Offsets::in_game_screen** - confirmed live, the two addresses are
 * the same and the object there carries this vftable. So it can be reached by one
 * dereference off the game state rather than by scanning for the vftable, which is
 * what `cacheIngameIdler` in bice.cpp still does.
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

    /**
     * Virtual slots worth calling, by index into the vftable above.
     *
     * Only valid together with that vftable, so anything calling one has to check the
     * object carries it first - which is what centreOnProvince below does.
     */
    namespace Slots {
        /**
         * **Centre the map on a province.** thiscall, one argument, a CMapProvince*.
         *
         * This is what the unit panel's `unit_location_button` calls, and so what the
         * `w` shortcut on that button does. Its handler is four instructions: take
         * the unit's idler from CUnit::Offsets::in_game_idler_ptr, its province from
         * CUnit::Offsets::current_province_ptr, and call this. The routine itself
         * reads the province's map x and y and writes the camera position.
         */
        constexpr int CENTRE_ON_PROVINCE = 48;    // vftable + 0xC0
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
    /**
    @brief moves the map to a province, the way the unit panel's location button does

    Answers false rather than doing anything when there is no session, when the object
    the game state points at is not a CInGameIdler, or when the province is not a
    readable object.

    @param province a CMapProvince*, as Oob::Unit::province holds
    */
    bool centreOnProvince(uintptr_t province);

    namespace MapMode {
        constexpr int VICTORY_POINTS = 7;    // the one Custom Mapmode takes over
        constexpr int SIMPLIFIED_TERRAIN = 13;
        constexpr int AIR = 18;
        constexpr int NAVAL = 19;
    }
}
