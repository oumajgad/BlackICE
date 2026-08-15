#include <Inspector.hpp>

#include <MemScan.hpp>
#include <utils.hpp>
#include <HoiDataStructures.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/CSubUnitDefinition.hpp>
#include <GameClasses/CTerrain.hpp>

namespace {
    using namespace Inspector;

    constexpr int DATA_SECTION_START = 0x12F5000;

    // A selection list should never be this long. Guards against walking a corrupt
    // or circular list forever.
    constexpr int MAX_SELECTED_ENTITIES = 256;

    struct StatDesc
    {
        const char* name;
        uintptr_t offset;   // Into CSubUnitDefinition
        float factor;
        const char* unit;
        unsigned typeMask;  // Which unit types this stat is meaningful for
    };

    /**
     * Mirrors the "properties" table and the per type "blacklists" in inspector.lua:
     * a stat is listed for a unit type here exactly when the Lua side does not
     * blacklist it for that type.
     *
     * Built on first use rather than at namespace scope: the offsets live in another
     * translation unit, so a static initializer here could run before they are set.
     */
    const std::vector<StatDesc>& statDescs() {
        static const std::vector<StatDesc> descs = {
            // General
            { "max_strength",        CSubUnitDefinition::Offsets::max_strength,        0.001f, "",     MASK_ALL },
            { "max_organisation",    CSubUnitDefinition::Offsets::max_organisation,    0.001f, "",     MASK_ALL },
            { "morale",              CSubUnitDefinition::Offsets::morale,              0.1f,   "%",    MASK_ALL },
            { "manpower",            CSubUnitDefinition::Offsets::manpower,            0.001f, "",     MASK_ALL },
            { "officers",            CSubUnitDefinition::Offsets::officers,            0.001f, "",     MASK_ALL },
            { "max_speed",           CSubUnitDefinition::Offsets::max_speed,           0.001f, " kph", MASK_ALL },
            { "supply_consumption",  CSubUnitDefinition::Offsets::supply_consumption,  0.001f, "",     MASK_ALL },
            { "fuel_consumption",    CSubUnitDefinition::Offsets::fuel_consumption,    0.001f, "",     MASK_ALL },
            { "air_defence",         CSubUnitDefinition::Offsets::air_defence,         0.001f, "",     MASK_ALL },
            { "air_attack",          CSubUnitDefinition::Offsets::air_attack,          0.001f, "",     MASK_ALL },
            { "sub_unit_amount",     CSubUnitDefinition::Offsets::sub_unit_amount,     0.001f, "",     MASK_NAVY | MASK_AIR },
            { "soft_attack",         CSubUnitDefinition::Offsets::soft_attack,         0.001f, "",     MASK_ARMY | MASK_AIR },
            { "hard_attack",         CSubUnitDefinition::Offsets::hard_attack,         0.001f, "",     MASK_ARMY | MASK_AIR },
            { "air_detection",       CSubUnitDefinition::Offsets::air_detection,       0.001f, "",     MASK_NAVY | MASK_AIR },
            { "transport_capacity",  CSubUnitDefinition::Offsets::transport_capacity,  0.001f, "",     MASK_NAVY | MASK_AIR },
            { "sea_attack",          CSubUnitDefinition::Offsets::sea_attack,          0.001f, "",     MASK_NAVY | MASK_AIR },

            // Land
            { "width",               CSubUnitDefinition::Offsets::width,               0.001f, "",     MASK_ARMY },
            { "weight",              CSubUnitDefinition::Offsets::weight,              0.001f, "",     MASK_ARMY },
            { "defensiveness",       CSubUnitDefinition::Offsets::defensiveness,       0.001f, "",     MASK_ARMY },
            { "toughness",           CSubUnitDefinition::Offsets::toughness,           0.001f, "",     MASK_ARMY },
            { "softness",            CSubUnitDefinition::Offsets::softness,            0.1f,   "%",    MASK_ARMY },
            { "armor",               CSubUnitDefinition::Offsets::armor,               0.001f, "",     MASK_ARMY },
            { "suppression",         CSubUnitDefinition::Offsets::suppression,         0.001f, "",     MASK_ARMY },
            { "piercing_attack",     CSubUnitDefinition::Offsets::piercing_attack,     0.001f, "",     MASK_ARMY },

            // Naval
            { "range",               CSubUnitDefinition::Offsets::range,               0.001f, " km",  MASK_NAVY | MASK_AIR },
            { "firing_distance",     CSubUnitDefinition::Offsets::firing_distance,     0.001f, " km",  MASK_NAVY },
            { "surface_detection",   CSubUnitDefinition::Offsets::surface_detection,   0.001f, "",     MASK_NAVY | MASK_AIR },
            { "visibility",          CSubUnitDefinition::Offsets::visibility,          0.001f, "",     MASK_NAVY },
            { "sea_defence",         CSubUnitDefinition::Offsets::sea_defence,         0.001f, "",     MASK_NAVY },
            { "convoy_attack",       CSubUnitDefinition::Offsets::convoy_attack,       0.001f, "",     MASK_NAVY },
            { "sub_attack",          CSubUnitDefinition::Offsets::sub_attack,          0.001f, "",     MASK_NAVY },
            { "shore_bombardment",   CSubUnitDefinition::Offsets::shore_bombardment,   0.001f, "",     MASK_NAVY },
            { "hull",                CSubUnitDefinition::Offsets::hull,                0.001f, "",     MASK_NAVY },
            { "positioning",         CSubUnitDefinition::Offsets::positioning,         0.001f, "",     MASK_NAVY },

            // Air
            { "strategic_attack",    CSubUnitDefinition::Offsets::strategic_attack,    0.001f, "",     MASK_AIR },
            { "surface_defence",     CSubUnitDefinition::Offsets::surface_defence,     0.001f, "",     MASK_AIR },
        };
        return descs;
    }

    uintptr_t ingameIdlerPtr = 0;

    void collectStats(Entity& entity, uintptr_t unitPtr, unsigned typeMask) {
        const uintptr_t subUnitDefinitionPtr =
            *reinterpret_cast<uintptr_t*>(unitPtr + CUnit::Offsets::CSubUnitDefinitionPtr);
        if (subUnitDefinitionPtr == 0) {
            return;
        }

        for (const StatDesc& desc : statDescs()) {
            if ((desc.typeMask & typeMask) == 0) {
                continue;
            }
            Stat stat;
            stat.name = desc.name;
            stat.rawValue = *reinterpret_cast<int*>(subUnitDefinitionPtr + desc.offset);
            stat.factor = desc.factor;
            stat.unit = desc.unit;
            entity.stats.push_back(stat);
        }

        // Air units get no terrain modifiers, matching shouldIncludeTerrainType() in Lua.
        if (typeMask == MASK_AIR) {
            return;
        }

        const uintptr_t adjusterArrayPtr =
            *reinterpret_cast<uintptr_t*>(subUnitDefinitionPtr + CSubUnitDefinition::Offsets::CUnitAdjuster_ptr);
        if (adjusterArrayPtr == 0) {
            return;
        }

        for (CTerrain::CTerrain* terrain : *CTerrain::Terrains) {
            if (terrain == nullptr) {
                continue;
            }
            // Armies only care about land, navies only about water.
            const bool wantWater = (typeMask == MASK_NAVY);
            if (terrain->is_water != wantWater) {
                continue;
            }

            // 24 => sizeof(CUnitAdjuster) in the game
            const HDS::CUnitAdjuster* adjuster =
                reinterpret_cast<HDS::CUnitAdjuster*>(adjusterArrayPtr + (terrain->id * 24));

            TerrainStat stat;
            stat.name = terrain->name;
            stat.isWater = terrain->is_water;
            stat.attack = adjuster->attack + terrain->attack;
            stat.defence = adjuster->defence + terrain->defence;
            stat.attrition = adjuster->attrition + terrain->attrition;
            stat.movement = adjuster->movement;
            entity.terrain.push_back(stat);
        }
    }
}

bool Inspector::recacheIdler() {
    ingameIdlerPtr = 0;

    const uintptr_t moduleBase = Mem::moduleBase("hoi3_tfh.exe");
    if (moduleBase == 0) {
        return false;
    }

    const uintptr_t CIngameIdlerVFTable = moduleBase + 0x11CEB54;
    auto hits = Mem::findPointers(moduleBase + DATA_SECTION_START, CIngameIdlerVFTable, 99);
    if (hits.empty()) {
        DEBUG_OUT(printf("Inspector: no CIngameIdler found (is a session running?)\n"));
        return false;
    }

    ingameIdlerPtr = hits.back();
    DEBUG_OUT(printf("Inspector: CIngameIdler at %#010x (%i candidates)\n",
        ingameIdlerPtr, static_cast<int>(hits.size())));

    // Terrain modifiers are looked up by terrain id, and the terrain objects only
    // exist once a session is running too. Same scan, so do it from the same button
    // rather than retrying it on the sampling timer.
    if (CTerrain::Terrains->empty()) {
        CTerrain::CacheTerrains();
        DEBUG_OUT(printf("Inspector: cached %i terrains\n", static_cast<int>(CTerrain::Terrains->size())));
    }

    return true;
}

uintptr_t Inspector::idlerAddress() {
    return ingameIdlerPtr;
}

std::vector<Entity> Inspector::getSelection() {
    std::vector<Entity> selection;

    if (ingameIdlerPtr == 0) {
        return selection;
    }

    const uintptr_t moduleBase = Mem::moduleBase("hoi3_tfh.exe");
    const uintptr_t CArmyVFTable = moduleBase + 0x11BDE0C;
    const uintptr_t CNavyVFTable = moduleBase + 0x11C869C;
    const uintptr_t CAirVFTable = moduleBase + 0x011C8774;
    const uintptr_t CMapProvinceVFTable = moduleBase + 0x11BEC1C;

    uintptr_t* idler = reinterpret_cast<uintptr_t*>(ingameIdlerPtr);
    HDS::LinkedListNodeSingle* currentNode =
        reinterpret_cast<HDS::LinkedListNodeSingle*>(*(idler + (0x1304 / 4)));

    int guard = 0;
    while (currentNode != nullptr && guard++ < MAX_SELECTED_ENTITIES) {
        const uintptr_t entityPtr = currentNode->data;
        if (entityPtr == 0) {
            break;
        }

        const uintptr_t entityType = *reinterpret_cast<uintptr_t*>(entityPtr);

        Entity entity;
        entity.address = entityPtr;

        unsigned typeMask = 0;
        if (entityType == CArmyVFTable) {
            entity.type = "Army";
            typeMask = MASK_ARMY;
        }
        else if (entityType == CNavyVFTable) {
            entity.type = "Navy";
            typeMask = MASK_NAVY;
        }
        else if (entityType == CAirVFTable) {
            entity.type = "Air";
            typeMask = MASK_AIR;
        }
        else if (entityType == CMapProvinceVFTable) {
            entity.type = "Province";
        }

        if (typeMask != 0) {
            const char* name = utils::getCString(
                reinterpret_cast<DWORD*>(entityPtr + CUnit::Offsets::name));
            if (name != nullptr) {
                entity.name = name;
            }
            collectStats(entity, entityPtr, typeMask);
        }

        selection.push_back(entity);
        currentNode = currentNode->next;
    }

    return selection;
}
