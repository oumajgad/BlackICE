#pragma once
#include <CasualLibrary.hpp>
#include <lua.hpp>

namespace CMapProvince {
    namespace Offsets {
        extern uintptr_t CTerrain_ptr;
        extern uintptr_t CModifierDefinitions_ptr;
        extern uintptr_t CProvinceBuilding_array_ptr;
        extern uintptr_t id;
        extern uintptr_t supply_pool;
        extern uintptr_t fuel_pool;
        extern uintptr_t oil;
        extern uintptr_t metal;
        extern uintptr_t energy;
        extern uintptr_t rares;
        extern uintptr_t manpower;
        extern uintptr_t leadership;
        extern uintptr_t owner_tag;
        extern uintptr_t owner_id;
        extern uintptr_t controller_tag;
        extern uintptr_t controller_id;
    }

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
    CMapProvince GetMapProvinceById(Memory::External& external, int id);
    void PushCMapProvinceToStack(lua_State* L, CMapProvince province);

}