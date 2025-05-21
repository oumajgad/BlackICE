#pragma once
#include <CasualLibrary.hpp>
#include <lua.hpp>

namespace CTerrain {
    namespace Offsets {
        extern uintptr_t id;
        extern uintptr_t name;          // 0x28
        extern uintptr_t name_length;   // 0x38
        extern uintptr_t is_water;
        extern uintptr_t defence;
        extern uintptr_t attack;
        extern uintptr_t attrition;
    }
    struct CTerrain
    {
        int id;
        char* name;
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
    void CacheTerrains(Memory::External& external);
    CTerrain* Make(uintptr_t addr);
}