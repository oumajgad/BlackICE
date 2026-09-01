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
        // By value, like the CTerrain it comes from: a pointer here would outlive
        // nothing in particular.
        std::string name;
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
    @brief where the in game screen is, or 0 when there is no session

    Read from the game state every time, so it follows a game being loaded or left
    with nothing to press. It used to be found by scanning the heap for the vftable,
    which turned up several objects and left the page cycling through them to find
    the live one; CInGameIdler::current() answers exactly, so none of that is needed.
    */
    uintptr_t idlerAddress();

    /**@brief entities currently selected in game
       @returns the selection, or an empty vector when there is no session*/
    std::vector<Entity> getSelection();
}
