#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <GameClasses/CGoodsPool.hpp>
#include <GameClasses/CModifier.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

namespace CMapProvince {
    CMapProvince Make(uintptr_t addr) {
        CMapProvince res = CMapProvince{};
        res.modifier = addr + Offsets::modifier;
        res.CProvinceBuilding_array_ptr = addr + Offsets::CProvinceBuilding_array_ptr;
        res.id = *(int*)(addr + Offsets::id);

        const uintptr_t pool = addr + Offsets::pool;
        res.supply_pool = *(int*)(pool + CGoodsPool::Goods::supplies);
        res.fuel_pool = *(int*)(pool + CGoodsPool::Goods::fuel);

        const uintptr_t producing = addr + Offsets::current_producing;
        res.oil = *(int*)(producing + CGoodsPool::Goods::crude_oil);
        res.metal = *(int*)(producing + CGoodsPool::Goods::metal);
        res.energy = *(int*)(producing + CGoodsPool::Goods::energy);
        res.rares = *(int*)(producing + CGoodsPool::Goods::rare_materials);

        res.manpower = *(int*)(addr + Offsets::manpower);
        res.leadership = *(int*)(addr + Offsets::leadership);
        //res.owner_tag = HDS::readTag(addr + Offsets::owner);
        //res.owner_id = *(int*)(addr + Offsets::owner + CCountryTag::Offsets::id);
        //res.controller_tag = HDS::readTag(addr + Offsets::controller);
        //res.controller_id = *(int*)(addr + Offsets::controller + CCountryTag::Offsets::id);
        return res;
    }

    CMapProvince GetMapProvinceById(int id) {
        // Through the bounded lookup, which stops at the province vector's end. This
        // used to index the array raw with an id straight from Lua, so one past the map
        // read the junk in the vector's spare capacity or faulted outright.
        const uintptr_t province = CCurrentGameState::province(id);
        DEBUG_OUT(printf("CMapProvincePtr: %#010x \n", static_cast<unsigned>(province)));
        return (province != 0) ? Make(province) : CMapProvince{};
    }

    /**@brief one value of the province's modifier, pushed into the table on top of the stack*/
    void pushModifierValue(lua_State* L, uintptr_t values, const char* key, int type) {
        const int value = *(int*)(values + CModifier::entryOffset(type) + CModifier::Entry::value);
        lua_pushstring(L, key);
        lua_pushinteger(L, value);
        lua_settable(L, -3);
    }

    void pushModifiers(lua_State* L, CMapProvince province) {
        lua_pushstring(L, "modifiers");
        lua_newtable(L);

        const uintptr_t values = *(uintptr_t*)(province.modifier + CModifier::Offsets::values);

        pushModifierValue(L, values, "local_ic", CModifier::LOCAL_IC);
        pushModifierValue(L, values, "local_oil", CModifier::LOCAL_CRUDE_OIL);
        pushModifierValue(L, values, "local_energy", CModifier::LOCAL_ENERGY);
        pushModifierValue(L, values, "local_metal", CModifier::LOCAL_METAL);
        pushModifierValue(L, values, "local_rares", CModifier::LOCAL_RARE_MATERIALS);
        pushModifierValue(L, values, "local_leadership", CModifier::LOCAL_LEADERSHIP);

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
