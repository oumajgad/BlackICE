#pragma once
#include <cstdint>
#include <lua.hpp>

namespace CMapProvince {
    namespace Offsets {
        constexpr uintptr_t CTerrain_ptr = 0xD4;
        constexpr uintptr_t CModifierDefinitions_ptr = 0x114;
        constexpr uintptr_t CProvinceBuilding_array_ptr = 0x310;

        constexpr uintptr_t id = 0xD0;
        constexpr uintptr_t victory_points = 0x34;

        /**
         * What each country knows about this province: a pointer to one byte per
         * country, and how many of them there are.
         *
         * Index it by the country's index, the same one controller_id holds and the
         * same one the map is drawn for. Check the count first - it is the number of
         * countries in the game, 108 in BlackICE, and a country index past it means
         * there is nothing to read.
         *
         * The values that actually turn up in a running game are 0 for somewhere
         * never seen, 3 for partial intel, and 9 for a province the country owns -
         * measured over all 14,000 provinces, where every one of the 262 the player
         * held read 9.
         *
         * Two thresholds matter, both the game's own: at two or more a province counts
         * as seen and is painted at full brightness rather than dimmed, and at six or
         * more the province window shows what is built there. The second was found by
         * testing rather than read out of the code.
         *
         * Found from the VP map mode's colouring loop, which reads exactly this pair
         * to decide how dim a province should be.
         */
        constexpr uintptr_t intel_by_country_ptr = 0x370;
        constexpr uintptr_t intel_country_count = 0x374;

        constexpr uintptr_t supply_pool = 0x164;
        constexpr uintptr_t fuel_pool = 0x168;
        constexpr uintptr_t oil = 0x27C;
        constexpr uintptr_t metal = 0x280;
        constexpr uintptr_t energy = 0x284;
        constexpr uintptr_t rares = 0x288;
        constexpr uintptr_t manpower = 0x320;
        constexpr uintptr_t leadership = 0x324;
        constexpr uintptr_t owner_tag = 0x32C; // four characters, HDS::readTag
        constexpr uintptr_t owner_id = 0x330;
        constexpr uintptr_t controller_tag = 0x334; // four characters, HDS::readTag
        constexpr uintptr_t controller_id = 0x338;
    }

    /**
     * The buildings array a province points at. These are the pooled totals the
     * province shows, not one entry per building.
     */
    namespace BuildingOffsets {
        constexpr uintptr_t ic = 0x80;
        constexpr uintptr_t oil = 0x90;
        constexpr uintptr_t energy = 0xA0;
        constexpr uintptr_t metal = 0xB0;
        constexpr uintptr_t rares = 0xC0;
        constexpr uintptr_t leadership = 0x100;
    }

    /**@brief the province array hangs off the game state, not off a province*/
    constexpr uintptr_t GAME_STATE_PROVINCE_ARRAY = 0xB8C;

    struct CMapProvince
    {
        uintptr_t CTerrain_ptr;
        uintptr_t CModifierDefinitions_ptr;
        uintptr_t CProvinceBuilding_array_ptr;
        int id;
        int supply_pool;
        int fuel_pool;
        int oil;
        int metal;
        int energy;
        int rares;
        int manpower;
        int leadership;
        //char* owner_tag;
        //int owner_id;
        //char* controller_tag;
        //int controller_id;
    };

    CMapProvince Make(uintptr_t addr);
    CMapProvince GetMapProvinceById(int id);
    void PushCMapProvinceToStack(lua_State* L, CMapProvince province);

}