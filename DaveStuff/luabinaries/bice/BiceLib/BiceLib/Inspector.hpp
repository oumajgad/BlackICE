#pragma once

#include <cstdint>
#include <string>
#include <vector>

/**
 * Reads the currently selected in game entities straight into C++ structs.
 *
 * This is the same data BiceLib.Inspector.getSelectedEntity() hands to Lua, but
 * without going through the Lua stack so the ImGui overlay can render it. The
 * scaling factors and per unit type filtering mirror script/utility/gameinfos/inspector.lua.
 */
namespace Inspector {
    enum UnitTypeMask {
        MASK_ARMY = 1 << 0,
        MASK_NAVY = 1 << 1,
        MASK_AIR = 1 << 2,
        MASK_ALL = MASK_ARMY | MASK_NAVY | MASK_AIR
    };

    struct Stat
    {
        const char* name;
        int rawValue;
        float factor;     // Game stores fixed point, multiply to get the displayed value
        const char* unit;
    };

    struct TerrainStat
    {
        const char* name;
        bool isWater;
        int attack;
        int defence;
        int attrition;
        int movement;
    };

    struct Entity
    {
        const char* type = "Unknown"; // Army / Navy / Air / Province / Unknown
        std::string name;
        uintptr_t address = 0;
        std::vector<Stat> stats;
        std::vector<TerrainStat> terrain;
    };

    /**
    @brief (re)scans for CIngameIdler, the object holding the current selection

    It only exists once a session is running, so scanning from the main menu finds
    nothing. This is deliberately not called automatically: the scan walks the whole
    heap, which is far too expensive to retry on a timer.
    @returns true if an idler was found
    */
    bool recacheIdler();

    /**@brief address of the cached CIngameIdler, 0 if it has not been found yet*/
    uintptr_t idlerAddress();

    /**@brief entities currently selected in game
       @returns the selection, or an empty vector if the idler is not cached yet*/
    std::vector<Entity> getSelection();
}
