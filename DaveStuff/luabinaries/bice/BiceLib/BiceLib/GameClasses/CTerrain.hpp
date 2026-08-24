#pragma once
#include <cstdint>
#include <string>
#include <vector>
#include <lua.hpp>

namespace CTerrain {
    namespace Offsets {
        constexpr uintptr_t id = 0x8;
        constexpr uintptr_t name = 0x28;   // a Hoi3CString, so its length is at 0x38
        constexpr uintptr_t is_water = 0x48;
        constexpr uintptr_t defence = 0x4C;
        constexpr uintptr_t attack = 0x50;
        constexpr uintptr_t attrition = 0x5C;
    }

    namespace VFTable {
        constexpr uintptr_t CTerrain = 0x11C0764; // module relative
    }
    struct CTerrain
    {
        int id;
        std::string name;
        bool is_water;
        int defence;
        int attack;
        int attrition;
        // int movement_cost;
        // int temperature;
        // int humidity;
        // int precipitation;
    };
    extern std::vector<CTerrain*>* Terrains;
    void CacheTerrains();
    CTerrain* Make(uintptr_t addr);
}