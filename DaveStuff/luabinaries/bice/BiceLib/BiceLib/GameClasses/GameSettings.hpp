#pragma once
#include <cstdint>

/**
 * The game's settings object - what `settings.txt` is read into.
 *
 * **Not named after its class**, unlike everything else in this folder: the object has
 * no vftable entry in the RTTI export to name it by, so it is named for what it holds.
 * A single lazily created instance of `0x18C` bytes, reached through one module
 * relative pointer, with its getter at `0x5FF30`.
 *
 * The live file is not the one in the game folder - it is the per mod copy under
 * Documents; see the note in `reversing/FINDINGS-autosave.md`.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace GameSettings {
    /**@brief where the pointer to the settings object lives, module relative*/
    constexpr uintptr_t GLOBAL_POINTER = 0x16863F8;

    namespace Offsets {
        /**
         * The style number the water shader picks its technique from, and so what
         * decides whether sea provinces take a map mode's colour at all. Only 16, 18
         * and 19 colour the sea. Not read by BiceLib: it is written by the map mode
         * setters, and `Patches::seaTerrainColourInSimplifiedMapMode` changes the one
         * the Simplified Terrain setter writes. See `reversing/FINDINGS-mapmode.md`.
         */
        constexpr uintptr_t map_style = 0xF4;

        /**
         * `debug_saves`. Not a boolean: zero means the autosave rotates three files,
         * and any other value N means one dated file per save, taken on the 1st of
         * every Nth month instead of on the frequency below.
         */
        constexpr uintptr_t debug_saves = 0x158;

        /**@brief the autosave frequency, as AutosaveFrequency below*/
        constexpr uintptr_t autosave_frequency = 0x15C;
    }

    /**
     * What `autosave=` in settings.txt turns into. The constructor's default is
     * YEARLY.
     */
    enum AutosaveFrequency {
        AUTOSAVE_NEVER = 0,
        AUTOSAVE_WEEKLY = 1,
        AUTOSAVE_MONTHLY = 2,
        AUTOSAVE_HALFYEAR = 3,      // the 1st of January and the 1st of July
        AUTOSAVE_YEARLY = 4,
        AUTOSAVE_FIVE_YEAR = 5,
    };
}
