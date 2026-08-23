#pragma once
#include <cstdint>
#include <lua.hpp>

namespace CMapProvince {
    namespace Offsets {
        constexpr uintptr_t CTerrain_ptr = 0xD4;
        constexpr uintptr_t CModifierDefinitions_ptr = 0x114;
        constexpr uintptr_t CProvinceBuilding_array_ptr = 0x310;

        constexpr uintptr_t id = 0xD0;
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