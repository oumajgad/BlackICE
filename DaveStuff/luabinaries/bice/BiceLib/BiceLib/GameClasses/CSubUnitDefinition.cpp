#include <GameClasses/CSubUnitDefinition.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/CTerrain.hpp>
#include <GameClasses/CUnitAdjuster.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

namespace {
    struct Stat
    {
        const char* key;        // the Lua key, which utility/gameinfos/inspector.lua reads
        uintptr_t offset;
    };

    // `radio_strength` was `sub_unit_amount` here once, which it is not: the unit files call
    // it radio_strength and the values agree on 1273 types.
    const Stat STATS[] = {
        // General
        {"radio_strength", CSubUnitDefinition::Offsets::radio_strength},
        {"max_strength", CSubUnitDefinition::Offsets::max_strength},
        {"max_organisation", CSubUnitDefinition::Offsets::max_organisation},
        {"manpower", CSubUnitDefinition::Offsets::build_cost_manpower},
        {"morale", CSubUnitDefinition::Offsets::morale},
        {"supply_consumption", CSubUnitDefinition::Offsets::supply_consumption},
        {"fuel_consumption", CSubUnitDefinition::Offsets::fuel_consumption},
        {"officers", CSubUnitDefinition::Offsets::officers},
        {"max_speed", CSubUnitDefinition::Offsets::max_speed},
        {"air_defence", CSubUnitDefinition::Offsets::air_defence},
        {"air_attack", CSubUnitDefinition::Offsets::air_attack},
        {"soft_attack", CSubUnitDefinition::Offsets::soft_attack},
        {"hard_attack", CSubUnitDefinition::Offsets::hard_attack},
        {"air_detection", CSubUnitDefinition::Offsets::air_detection},
        {"transport_capacity", CSubUnitDefinition::Offsets::transport_capacity},
        {"sea_attack", CSubUnitDefinition::Offsets::sea_attack},
        // Land
        {"width", CSubUnitDefinition::Offsets::width},
        {"weight", CSubUnitDefinition::Offsets::weight},
        {"defensiveness", CSubUnitDefinition::Offsets::defensiveness},
        {"toughness", CSubUnitDefinition::Offsets::toughness},
        {"softness", CSubUnitDefinition::Offsets::softness},
        {"armor", CSubUnitDefinition::Offsets::armor},
        {"suppression", CSubUnitDefinition::Offsets::suppression},
        {"piercing_attack", CSubUnitDefinition::Offsets::piercing_attack},
        // Navy
        {"range", CSubUnitDefinition::Offsets::range},
        {"firing_distance", CSubUnitDefinition::Offsets::firing_distance},
        {"surface_detection", CSubUnitDefinition::Offsets::surface_detection},
        {"visibility", CSubUnitDefinition::Offsets::visibility},
        {"sea_defence", CSubUnitDefinition::Offsets::sea_defence},
        {"convoy_attack", CSubUnitDefinition::Offsets::convoy_attack},
        {"sub_attack", CSubUnitDefinition::Offsets::sub_attack},
        {"shore_bombardment", CSubUnitDefinition::Offsets::shore_bombardment},
        {"hull", CSubUnitDefinition::Offsets::hull},
        {"positioning", CSubUnitDefinition::Offsets::positioning},
        // Air
        {"strategic_attack", CSubUnitDefinition::Offsets::strategic_attack},
        {"surface_defence", CSubUnitDefinition::Offsets::surface_defence},
    };

    /**@brief a table per terrain, keyed by its name, into the table on top of the stack*/
    void pushTerrainStats(lua_State* L, uintptr_t adjusters) {
        CTerrain::CacheTerrains();
        for (const CTerrain::CTerrain& terrain : CTerrain::Terrains) {
            CUnitAdjuster::CUnitAdjuster adjuster = {};
            if (!Mem::tryRead(adjusters + terrain.id * CUnitAdjuster::SIZE, adjuster)) {
                continue;
            }
            lua_createtable(L, 0, 5);
            lua_pushboolean(L, terrain.is_water);
            lua_setfield(L, -2, "is_water");
            lua_pushinteger(L, adjuster.attrition + terrain.attrition);
            lua_setfield(L, -2, "attrition");
            lua_pushinteger(L, adjuster.attack + terrain.attack);
            lua_setfield(L, -2, "attack");
            lua_pushinteger(L, adjuster.defence + terrain.defence);
            lua_setfield(L, -2, "defence");
            lua_pushinteger(L, adjuster.movement);
            lua_setfield(L, -2, "movement");
            lua_setfield(L, -2, terrain.name.c_str());
        }
    }
}

namespace CSubUnitDefinition {
    void pushCSubUnitDefinitionToStack(lua_State* L, uintptr_t unitPtr) {
        const uintptr_t definition =
            Mem::readOr<uint32_t>(unitPtr + CUnit::Offsets::CSubUnitDefinitionPtr);
        if (definition == 0) {
            return;
        }

        const uintptr_t adjusters = Mem::readOr<uint32_t>(definition + Offsets::terrain_adjusters);
        if (adjusters != 0) {
            pushTerrainStats(L, adjusters);
        }

        for (const Stat& stat : STATS) {
            lua_pushinteger(L, Mem::readOr<int32_t>(definition + stat.offset));
            lua_setfield(L, -2, stat.key);
        }
    }
}
