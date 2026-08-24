#pragma once
#include <cstdint>

/**
 * CProvinceBuilding - one building in one province, and CBuilding, the definition it
 * points at.
 *
 * A province holds an array of these at CMapProvince::Offsets::buildings, one entry per
 * building the mod defines, whether the province has one or not. **Index 0 is
 * "nobuilding"**, so the array is one longer than common/buildings.txt and every real
 * building sits one index later than its position in that file. Read the name off the
 * definition rather than counting lines in the file.
 *
 * Levels are scaled by a thousand: an infrastructure of 4 reads as 4000. Checked
 * against every province in a running game - 1,500 of 1,500 had a level between 1 and
 * 10, which is what infrastructure should look like.
 *
 * Offsets from DaveStuff/mem/classes/CProvinceBuilding.py, confirmed live. Only valid
 * for this build of hoi3_tfh.exe.
 */
namespace CProvinceBuilding {
    namespace Offsets {
        constexpr uintptr_t effect = 0x10;
        constexpr uintptr_t definition_ptr = 0x18;   // a CBuilding
        constexpr uintptr_t level_max = 0x20;        // x1000
        constexpr uintptr_t level_current = 0x24;    // x1000
    }

    namespace VFTable {
        constexpr uintptr_t CProvinceBuilding = 0x11C0A50;      // module relative
        constexpr uintptr_t CProvinceBuildingBase = 0x11C0A78;  // the base at object +8
    }

    /**@brief a level is held as thousandths; this is the level a person would say*/
    constexpr int LEVEL_SCALE = 1000;

    /**@brief what the array holds before the first real building*/
    constexpr int NO_BUILDING_INDEX = 0;

    /**@brief the mod defines 59, and the array carries nobuilding as well*/
    constexpr int MAX_BUILDINGS = 128;
}

/**
 * CBuilding - what a building is, rather than one a province has.
 */
namespace CBuilding {
    namespace Offsets {
        constexpr uintptr_t name = 0x1C;        // the key, "air_base"
        constexpr uintptr_t displayName = 0x38; // what the game shows, "Air Base"
    }
}
