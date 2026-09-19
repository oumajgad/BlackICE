#pragma once
#include <cstdint>
#include <string>
#include <vector>
#include <lua.hpp>

namespace CTerrain {
    /**
     * **Read live against `map/terrain.txt`**, which is where these come from. Five
     * terrains were compared field by field and every value agrees once scaled by 1000:
     * ocean declares only `movement_cost = 1.0` and reads 1000 with the rest zero, plains
     * `2` reads 2000, woods `1.45 / -0.15 / 0.2` reads 1450 / -150 / 200, urban
     * `1.25 / -0.5 / 0.7 / attrition 1` reads 1250 / -500 / 700 / 1000, and mountain
     * `1.6 / -0.3 / 0.45 / attrition 2 / temperature -10 / precipitation 10` reads 1600 /
     * -300 / 450 / 2000 / -10000 / 10000.
     */
    namespace Offsets {
        constexpr uintptr_t id = 0x8;
        constexpr uintptr_t name = 0x28;   // a Hoi3CString, so its length is at 0x38

        /**
         * **Parsed and then never used.** `movement_cost` is in every terrain block -
         * mountain 1.6, plains 2.0, ocean 1.0, urban 1.25, woods 1.45, all x1000 here - but
         * the game does not take it into account, so what a unit moves at in a terrain is
         * its own per-terrain modifier on `max_speed` and nothing else. Recorded because it
         * looks exactly like a field that should matter.
         */
        constexpr uintptr_t movement_cost = 0x44;

        constexpr uintptr_t is_water = 0x48;
        constexpr uintptr_t defence = 0x4C;
        constexpr uintptr_t attack = 0x50;

        /**@brief x1000, from the terrain's `temperature`. **Read live**: -10000 on mountain,
           which declares `-10`, and zero on the four terrains that declare none. One
           positive sample, so it is the weakest of these*/
        constexpr uintptr_t temperature = 0x58;

        constexpr uintptr_t attrition = 0x5C;

        /**@brief x1000, from the terrain's `precipitation`, and the same one-sample
           evidence as `temperature`: 10000 on mountain, which declares `10`*/
        constexpr uintptr_t precipitation = 0x64;
    }

    /**
     * A bound on the terrain list, so a begin/end pair that is not one is refused
     * rather than walked. The mod defines a few dozen.
     */
    constexpr size_t MAX_TERRAINS = 512;

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