#include <GameClasses/CMapProvince.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

namespace CMapProvince {
    CMapProvince Make(uintptr_t addr) {
        CMapProvince res = CMapProvince{};
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

    CMapProvince GetMapProvinceById(int id) {
        uintptr_t moduleBase = Mem::moduleBase("hoi3_tfh.exe");
        uintptr_t CCurrentGameStatePtr = *(uintptr_t*)(moduleBase + 0x1689790);
        DEBUG_OUT(printf("CCurrentGameStatePtr: %#010x \n", CCurrentGameStatePtr));
        uintptr_t mapProvincesArray = *(uintptr_t*)(CCurrentGameStatePtr + GAME_STATE_PROVINCE_ARRAY);
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

        int local_ic = *(uintptr_t*)(CProvinceBuilding_array + BuildingOffsets::ic);
        lua_pushstring(L, "local_ic");
        lua_pushinteger(L, local_ic);
        lua_settable(L, -3);
        int local_oil = *(uintptr_t*)(CProvinceBuilding_array + BuildingOffsets::oil);
        lua_pushstring(L, "local_oil");
        lua_pushinteger(L, local_oil);
        lua_settable(L, -3);
        int local_energy = *(uintptr_t*)(CProvinceBuilding_array + BuildingOffsets::energy);
        lua_pushstring(L, "local_energy");
        lua_pushinteger(L, local_energy);
        lua_settable(L, -3);
        int local_metal = *(uintptr_t*)(CProvinceBuilding_array + BuildingOffsets::metal);
        lua_pushstring(L, "local_metal");
        lua_pushinteger(L, local_metal);
        lua_settable(L, -3);
        int local_rares = *(uintptr_t*)(CProvinceBuilding_array + BuildingOffsets::rares);
        lua_pushstring(L, "local_rares");
        lua_pushinteger(L, local_rares);
        lua_settable(L, -3);
        int local_leadership = *(uintptr_t*)(CProvinceBuilding_array + BuildingOffsets::leadership);
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
