#include <GameClasses/CMapProvince.hpp>
#include <utils.hpp>

namespace CMapProvince {
    namespace Offsets {
        uintptr_t CTerrain_ptr = 0xD4;
        uintptr_t CModifierDefinitions_ptr = 0x114;
        uintptr_t CProvinceBuilding_array_ptr = 0x310;

        uintptr_t id = 0xD0;
        uintptr_t supply_pool = 0x164;
        uintptr_t fuel_pool = 0x168;
        uintptr_t oil = 0x27C;
        uintptr_t metal = 0x280;
        uintptr_t energy = 0x284;
        uintptr_t rares = 0x288;
        uintptr_t manpower = 0x320;
        uintptr_t leadership = 0x324;
        uintptr_t owner_tag = 0x32C;
        uintptr_t owner_id = 0x330;
        uintptr_t controller_tag = 0x334;
        uintptr_t controller_id = 0x338;
    }

    CMapProvince Make(uintptr_t addr) {
        CMapProvince res = CMapProvince{};
        res.CTerrain_ptr = addr + Offsets::CTerrain_ptr;
        res.CModifierDefinitions_ptr = addr + Offsets::CModifierDefinitions_ptr;
        res.CProvinceBuilding_array_ptr = addr + Offsets::CProvinceBuilding_array_ptr;
        res.id = *(int*)(addr + Offsets::id);
        res.supply_pool = *(int*)(addr + Offsets::supply_pool);
        res.fuel_pool = *(int*)(addr + Offsets::fuel_pool);
        res.oil = *(int*)(addr + Offsets::oil);
        res.metal = *(int*)(addr + Offsets::metal);
        res.energy = *(int*)(addr + Offsets::energy);
        res.rares = *(int*)(addr + Offsets::rares);
        res.manpower = *(int*)(addr + Offsets::manpower);
        res.leadership = *(int*)(addr + Offsets::leadership);
        //res.owner_tag = utils::getCString((DWORD*)(addr + Offsets::owner_tag));
        //res.owner_id = *(int*)(addr + Offsets::owner_id);
        //res.controller_tag = utils::getCString((DWORD*)(addr + Offsets::controller_tag));
        //res.controller_id = *(int*)(addr + Offsets::controller_id);
        return res;
    }

    CMapProvince GetMapProvinceById(Memory::External& external, int id) {
        Address modulePtr = external.getModule("hoi3_tfh.exe");
        uintptr_t moduleBase = modulePtr.get();
        uintptr_t CCurrentGameStatePtr = *(uintptr_t*)(moduleBase + 0x1689790);
        DEBUG_OUT(printf("CCurrentGameStatePtr: %#010x \n", CCurrentGameStatePtr));
        uintptr_t mapProvincesArray = *(uintptr_t*)(CCurrentGameStatePtr + 0xb8c);
        DEBUG_OUT(printf("mapProvincesArray: %#010x \n", mapProvincesArray));
        uintptr_t CMapProvincePtr = *(uintptr_t*)(mapProvincesArray + id * 4);
        DEBUG_OUT(printf("CMapProvincePtr: %#010x \n", CMapProvincePtr));
        auto province = Make(CMapProvincePtr);
        return province;
    }

    void pushModifiers(lua_State* L, CMapProvince province) {
        lua_pushstring(L, "modifiers");
        lua_newtable(L);

        uintptr_t CProvinceBuilding_array = *(uintptr_t*)province.CModifierDefinitions_ptr;

        int local_ic = *(uintptr_t*)(CProvinceBuilding_array + 0x80);
        lua_pushstring(L, "local_ic");
        lua_pushinteger(L, local_ic);
        lua_settable(L, -3);
        int local_oil = *(uintptr_t*)(CProvinceBuilding_array + 0x90);
        lua_pushstring(L, "local_oil");
        lua_pushinteger(L, local_oil);
        lua_settable(L, -3);
        int local_energy = *(uintptr_t*)(CProvinceBuilding_array + 0xa0);
        lua_pushstring(L, "local_energy");
        lua_pushinteger(L, local_energy);
        lua_settable(L, -3);
        int local_metal = *(uintptr_t*)(CProvinceBuilding_array + 0xb0);
        lua_pushstring(L, "local_metal");
        lua_pushinteger(L, local_metal);
        lua_settable(L, -3);
        int local_rares = *(uintptr_t*)(CProvinceBuilding_array + 0xc0);
        lua_pushstring(L, "local_rares");
        lua_pushinteger(L, local_rares);
        lua_settable(L, -3);
        int local_leadership = *(uintptr_t*)(CProvinceBuilding_array + 0x100);
        lua_pushstring(L, "local_leadership");
        lua_pushinteger(L, local_leadership);
        lua_settable(L, -3);

        lua_settable(L, -3);
    }

    void PushCMapProvinceToStack(lua_State* L, CMapProvince province) {
        DEBUG_OUT(printf("province.id: %i \n", province.id));
        //DEBUG_OUT(printf("province.owner_tag: %s \n", province.owner_tag));

        lua_newtable(L);

        lua_pushstring(L, "id");
        lua_pushinteger(L, province.id);
        lua_settable(L, -3);
        lua_pushstring(L, "supply_pool");
        lua_pushinteger(L, province.supply_pool);
        lua_settable(L, -3);
        lua_pushstring(L, "fuel_pool");
        lua_pushinteger(L, province.fuel_pool);
        lua_settable(L, -3);
        lua_pushstring(L, "oil");
        lua_pushinteger(L, province.oil);
        lua_settable(L, -3);
        lua_pushstring(L, "metal");
        lua_pushinteger(L, province.metal);
        lua_settable(L, -3);
        lua_pushstring(L, "energy");
        lua_pushinteger(L, province.energy);
        lua_settable(L, -3);
        lua_pushstring(L, "rares");
        lua_pushinteger(L, province.rares);
        lua_settable(L, -3);
        lua_pushstring(L, "manpower");
        lua_pushinteger(L, province.manpower);
        lua_settable(L, -3);
        lua_pushstring(L, "leadership");
        lua_pushinteger(L, province.leadership);
        lua_settable(L, -3);

        pushModifiers(L, province);

        //lua_pushstring(L, "owner_tag");
        //lua_pushstring(L, province.owner_tag);
        //lua_settable(L, -3);
        return;
    }
}
