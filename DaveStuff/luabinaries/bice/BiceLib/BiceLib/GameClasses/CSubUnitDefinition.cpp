#include <GameClasses/CSubUnitDefinition.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/CTerrain.hpp>
#include <utils.hpp>
#include <HoiDataStructures.hpp>

namespace CSubUnitDefinition {
    void pushTerrainStatsToStack(lua_State* L, uintptr_t unitAdjusterArrayPtr) {
        DEBUG_OUT(printf("unitAdjusterArrayPtr: %#010x\n", unitAdjusterArrayPtr));

        for (int i = 0; i < CTerrain::Terrains->size(); i++) {
            auto terrain = CTerrain::Terrains->at(i);
            HDS::CUnitAdjuster* unitAdjuster = (HDS::CUnitAdjuster*) (unitAdjusterArrayPtr + (terrain->id * 24)); // 24 => Length of the CUnidAdjuster object
            DEBUG_OUT(printf("unitAdjusterArrayPtr + (terrain->id * 24): %#010x\n", unitAdjusterArrayPtr + (terrain->id * 24)));
            
            DEBUG_OUT(printf("terrain->name: %s\n", terrain->name.c_str()));
            DEBUG_OUT(printf("terrain->id: %i\n", terrain->id));
            DEBUG_OUT(printf("terrain->attack: %i\n", terrain->attack));
            DEBUG_OUT(printf("terrain->defence: %i\n", terrain->defence));
            DEBUG_OUT(printf("terrain->attrition: %i\n", terrain->attrition));
            DEBUG_OUT(printf("unitAdjuster->attack: %i\n", unitAdjuster->attack));
            DEBUG_OUT(printf("unitAdjuster->defence: %i\n", unitAdjuster->defence));
            DEBUG_OUT(printf("unitAdjuster->movement: %i\n", unitAdjuster->movement));
            DEBUG_OUT(printf("unitAdjuster->attrition: %i\n", unitAdjuster->attrition));

            lua_pushstring(L, terrain->name.c_str()); // push key for the terrain in the unit stats table
            lua_newtable(L); // create new table for terrain stats
            lua_pushstring(L, "is_water");
            lua_pushboolean(L, terrain->is_water);
            lua_settable(L, -3);

            // push terrain stats
            lua_pushstring(L, "attrition");
            lua_pushinteger(L, unitAdjuster->attrition + terrain->attrition);
            lua_settable(L, -3);
            lua_pushstring(L, "attack");
            lua_pushinteger(L, unitAdjuster->attack + terrain->attack);
            lua_settable(L, -3);
            lua_pushstring(L, "defence");
            lua_pushinteger(L, unitAdjuster->defence + terrain->defence);
            lua_settable(L, -3);
            lua_pushstring(L, "movement");
            lua_pushinteger(L, unitAdjuster->movement);
            lua_settable(L, -3);

            // set terrain key in the unit stats table
            lua_settable(L, -3);
        }
    }

    void pushCSubUnitDefinitionToStack(lua_State* L, uintptr_t unitPtr) {
        DEBUG_OUT(printf("unitPtr: %#010x\n", unitPtr));

        uintptr_t subUnitDefinitionPtr = * (uintptr_t *) (unitPtr + CUnit::Offsets::CSubUnitDefinitionPtr);

        DEBUG_OUT(printf("subUnitDefinitionPtr: %#010x\n", subUnitDefinitionPtr));

        pushTerrainStatsToStack(L, *(uintptr_t*)(subUnitDefinitionPtr + Offsets::CUnitAdjuster_ptr));

        // GENERAL
        int sub_unit_amount = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::sub_unit_amount);
        lua_pushstring(L, "sub_unit_amount");
        lua_pushinteger(L, sub_unit_amount);
        lua_settable(L, -3);
        int max_strength = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::max_strength);
        lua_pushstring(L, "max_strength");
        lua_pushinteger(L, max_strength);
        lua_settable(L, -3);
        int max_organisation = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::max_organisation);
        lua_pushstring(L, "max_organisation");
        lua_pushinteger(L, max_organisation);
        lua_settable(L, -3);
        int manpower = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::manpower);
        lua_pushstring(L, "manpower");
        lua_pushinteger(L, manpower);
        lua_settable(L, -3);
        int morale = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::morale);
        lua_pushstring(L, "morale");
        lua_pushinteger(L, morale);
        lua_settable(L, -3);
        int supply_consumption = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::supply_consumption);
        lua_pushstring(L, "supply_consumption");
        lua_pushinteger(L, supply_consumption);
        lua_settable(L, -3);
        int fuel_consumption = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::fuel_consumption);
        lua_pushstring(L, "fuel_consumption");
        lua_pushinteger(L, fuel_consumption);
        lua_settable(L, -3);
        int officers = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::officers);
        lua_pushstring(L, "officers");
        lua_pushinteger(L, officers);
        lua_settable(L, -3);
        int max_speed = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::max_speed);
        lua_pushstring(L, "max_speed");
        lua_pushinteger(L, max_speed);
        lua_settable(L, -3);
        int air_defence = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::air_defence);
        lua_pushstring(L, "air_defence");
        lua_pushinteger(L, air_defence);
        lua_settable(L, -3);
        int air_attack = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::air_attack);
        lua_pushstring(L, "air_attack");
        lua_pushinteger(L, air_attack);
        lua_settable(L, -3);
        int soft_attack = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::soft_attack);
        lua_pushstring(L, "soft_attack");
        lua_pushinteger(L, soft_attack);
        lua_settable(L, -3);
        int hard_attack = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::hard_attack);
        lua_pushstring(L, "hard_attack");
        lua_pushinteger(L, hard_attack);
        lua_settable(L, -3);
        int air_detection = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::air_detection);
        lua_pushstring(L, "air_detection");
        lua_pushinteger(L, air_detection);
        lua_settable(L, -3);
        int transport_capacity = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::transport_capacity);
        lua_pushstring(L, "transport_capacity");
        lua_pushinteger(L, transport_capacity);
        lua_settable(L, -3);
        int sea_attack = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::sea_attack);
        lua_pushstring(L, "sea_attack");
        lua_pushinteger(L, sea_attack);
        lua_settable(L, -3);

        // ARMY
        int width = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::width);
        lua_pushstring(L, "width");
        lua_pushinteger(L, width);
        lua_settable(L, -3);
        int weight = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::weight);
        lua_pushstring(L, "weight");
        lua_pushinteger(L, weight);
        lua_settable(L, -3);
        int defensiveness = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::defensiveness);
        lua_pushstring(L, "defensiveness");
        lua_pushinteger(L, defensiveness);
        lua_settable(L, -3);
        int toughness = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::toughness);
        lua_pushstring(L, "toughness");
        lua_pushinteger(L, toughness);
        lua_settable(L, -3);
        int softness = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::softness);
        lua_pushstring(L, "softness");
        lua_pushinteger(L, softness);
        lua_settable(L, -3);
        int armor = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::armor);
        lua_pushstring(L, "armor");
        lua_pushinteger(L, armor);
        lua_settable(L, -3);
        int suppression = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::suppression);
        lua_pushstring(L, "suppression");
        lua_pushinteger(L, suppression);
        lua_settable(L, -3);
        int piercing_attack = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::piercing_attack);
        lua_pushstring(L, "piercing_attack");
        lua_pushinteger(L, piercing_attack);
        lua_settable(L, -3);

        // NAVY
        int range = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::range);
        lua_pushstring(L, "range");
        lua_pushinteger(L, range);
        lua_settable(L, -3);
        int firing_distance = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::firing_distance);
        lua_pushstring(L, "firing_distance");
        lua_pushinteger(L, firing_distance);
        lua_settable(L, -3);
        int surface_detection = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::surface_detection);
        lua_pushstring(L, "surface_detection");
        lua_pushinteger(L, surface_detection);
        lua_settable(L, -3);
        int visibility = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::visibility);
        lua_pushstring(L, "visibility");
        lua_pushinteger(L, visibility);
        lua_settable(L, -3);
        int sea_defence = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::sea_defence);
        lua_pushstring(L, "sea_defence");
        lua_pushinteger(L, sea_defence);
        lua_settable(L, -3);
        int convoy_attack = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::convoy_attack);
        lua_pushstring(L, "convoy_attack");
        lua_pushinteger(L, convoy_attack);
        lua_settable(L, -3);
        int sub_attack = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::sub_attack);
        lua_pushstring(L, "sub_attack");
        lua_pushinteger(L, sub_attack);
        lua_settable(L, -3);
        int shore_bombardment = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::shore_bombardment);
        lua_pushstring(L, "shore_bombardment");
        lua_pushinteger(L, shore_bombardment);
        lua_settable(L, -3);
        int hull = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::hull);
        lua_pushstring(L, "hull");
        lua_pushinteger(L, hull);
        lua_settable(L, -3);
        int positioning = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::positioning);
        lua_pushstring(L, "positioning");
        lua_pushinteger(L, positioning);
        lua_settable(L, -3);

        // AIR
        int strategic_attack = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::strategic_attack);
        lua_pushstring(L, "strategic_attack");
        lua_pushinteger(L, strategic_attack);
        lua_settable(L, -3);
        int surface_defence = *(uintptr_t*)(subUnitDefinitionPtr + Offsets::surface_defence);
        lua_pushstring(L, "surface_defence");
        lua_pushinteger(L, surface_defence);
        lua_settable(L, -3);
    }
}