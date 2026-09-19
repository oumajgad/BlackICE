#include <GameState/Inspector.hpp>

#include <GameClasses/CInGameIdler.hpp>

#include <MemScan.hpp>
#include <TextEncoding.hpp>
#include <utils.hpp>
#include <HoiDataStructures.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/CSubUnitDefinition.hpp>
#include <GameClasses/CTerrain.hpp>
#include <GameClasses/CUnitAdjuster.hpp>

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
            // Land holds strength in tens where air and naval hold
            // thousandths, so the same stat needs two entries. Their masks do not
            // overlap, so exactly one is ever picked and it keeps its place in
            // the order stats are listed in.
            { "max_strength",        CSubUnitDefinition::Offsets::max_strength,        0.1f,  "",     MASK_ARMY },
            { "max_strength",        CSubUnitDefinition::Offsets::max_strength,        0.001f, "",     MASK_NAVY | MASK_AIR },
            { "max_organisation",    CSubUnitDefinition::Offsets::max_organisation,    0.001f, "",     MASK_ALL },
            { "morale",              CSubUnitDefinition::Offsets::morale,              0.1f,   "%",    MASK_ALL },
            { "manpower",            CSubUnitDefinition::Offsets::build_cost_manpower, 0.001f, "",     MASK_ALL },
            { "officers",            CSubUnitDefinition::Offsets::officers,            0.001f, "",     MASK_ALL },
            { "max_speed",           CSubUnitDefinition::Offsets::max_speed,           0.001f, " kph", MASK_ALL },
            // What it costs to build, which this page never showed. All three are x1000,
            // checked against the mod's own files: armor_brigade is 21.3 IC over 157 days,
            // a carrier 22.0 over 700.
            { "build_cost_ic",       CSubUnitDefinition::Offsets::build_cost_ic,       0.001f, "",     MASK_ALL },
            { "build_time",          CSubUnitDefinition::Offsets::build_time,          0.001f, " days", MASK_ALL },
            { "completion_size",     CSubUnitDefinition::Offsets::completion_size,     0.001f, "",     MASK_ALL },
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
            { "sub_detection",       CSubUnitDefinition::Offsets::sub_detection,       0.001f, "",     MASK_NAVY },
            // Zero on everything that is not a carrier, and 2 on one (x1000 like the rest).
            { "carrier_size",        CSubUnitDefinition::Offsets::carrier_size,        0.001f, "",     MASK_NAVY },
            { "shore_bombardment",   CSubUnitDefinition::Offsets::shore_bombardment,   0.001f, "",     MASK_NAVY },
            { "hull",                CSubUnitDefinition::Offsets::hull,                0.001f, "",     MASK_NAVY },
            { "positioning",         CSubUnitDefinition::Offsets::positioning,         0.001f, "",     MASK_NAVY },

            // Air
            { "strategic_attack",    CSubUnitDefinition::Offsets::strategic_attack,    0.001f, "",     MASK_AIR },
            { "surface_defence",     CSubUnitDefinition::Offsets::surface_defence,     0.001f, "",     MASK_AIR },
        };
        return descs;
    }


    /**
    @brief reads a Hoi3 CString: 16 byte inline buffer, length at +0x10, and for
           anything longer than 15 characters a pointer to the text at +0x0
    */
    bool readHoi3String(uintptr_t address, std::string& out) {
        uint32_t length = 0;
        if (!Mem::tryRead(address + 0x10, length) || length > 1024) {
            return false;
        }
        if (length == 0) {
            out.clear();
            return true;
        }

        uintptr_t textAddress = address;
        if (length > 15 && !Mem::tryRead(address, textAddress)) {
            return false;
        }

        std::vector<char> buffer(length + 1, '\0');
        if (!Mem::tryReadBytes(textAddress, buffer.data(), length)) {
            return false;
        }
        // Unit names are player entered and full of umlauts in a German game, and the
        // game stores them as Windows-1252.
        out = Text::toUtf8(buffer.data(), strlen(buffer.data()));
        return true;
    }

    /**
     * The four blocks a unit file writes outside the terrains - `night`, `fort`, `river`
     * and `amphibious`. The definition keeps each as a CUnitAdjuster of its own rather than
     * in the terrain vector, so the terrain walk above never sees them.
     *
     * **Which types carry them, read live**: `night` is set on 916 of 1500 ships and 213 of
     * 807 wings, so it is listed for everything; `fort`, `river` and `amphibious` are set on
     * 1146, 1240 and 1296 of 1500 land regiments and on no ship or wing at all, so they are
     * listed for armies only.
     */
    void collectEnvironments(Entity& entity, uintptr_t subUnitDefinitionPtr, unsigned typeMask) {
        struct Environment { const char* name; uintptr_t offset; unsigned typeMask; };
        static const Environment environments[] = {
            { "night",      CSubUnitDefinition::Offsets::night,      MASK_ALL },
            { "fort",       CSubUnitDefinition::Offsets::fort,       MASK_ARMY },
            { "river",      CSubUnitDefinition::Offsets::river,      MASK_ARMY },
            { "amphibious", CSubUnitDefinition::Offsets::amphibious, MASK_ARMY },
        };

        for (const Environment& environment : environments) {
            if ((environment.typeMask & typeMask) == 0) {
                continue;
            }
            CUnitAdjuster::CUnitAdjuster adjuster;
            if (!Mem::tryRead(subUnitDefinitionPtr + environment.offset, adjuster)) {
                return;
            }
            // Held by value on the definition, so there is no terrain to add and no
            // pointer to check - but an all-zero block means the file said nothing about
            // this environment, and a row of zeroes is just noise.
            if (adjuster.attack == 0 && adjuster.defence == 0 &&
                adjuster.movement == 0 && adjuster.attrition == 0) {
                continue;
            }
            TerrainStat stat;
            stat.name = environment.name;
            stat.isWater = false;
            stat.isEnvironment = true;
            stat.attack = adjuster.attack;
            stat.defence = adjuster.defence;
            stat.attrition = adjuster.attrition;
            stat.movement = adjuster.movement;
            entity.terrain.push_back(stat);
        }
    }

    /**
     * **The definition a unit points at is its own, not the shared type.** `CUnit + 0xC8` is
     * an aggregate the game keeps for the whole division: **read live**, its `max_strength`,
     * `soft_attack`, `supply_consumption`, `build_cost_ic` and `defensiveness` are the sum
     * over the unit's regiments' own definitions on 539 of 540 armies, and `max_speed` is
     * the slowest of them on all 540. Each regiment's own definition already carries its
     * technology levels (see CTechnology.hpp), so what this page shows is the unit's
     * effective stats with tech in them, not the paper values from the unit file.
     */
    void collectStats(Entity& entity, uintptr_t unitPtr, unsigned typeMask) {
        uintptr_t subUnitDefinitionPtr = 0;
        if (!Mem::tryRead(unitPtr + CUnit::Offsets::CSubUnitDefinitionPtr, subUnitDefinitionPtr) ||
            subUnitDefinitionPtr == 0) {
            return;
        }

        for (const StatDesc& desc : statDescs()) {
            if ((desc.typeMask & typeMask) == 0) {
                continue;
            }
            int value = 0;
            if (!Mem::tryRead(subUnitDefinitionPtr + desc.offset, value)) {
                entity.stats.clear();
                return; // Not a real CSubUnitDefinition, don't show half a table
            }
            Stat stat;
            stat.name = desc.name;
            stat.rawValue = value;
            stat.factor = desc.factor;
            stat.unit = desc.unit;
            entity.stats.push_back(stat);
        }

        // Air units get no terrain modifiers, matching shouldIncludeTerrainType() in Lua.
        if (typeMask == MASK_AIR) {
            return;
        }

        uintptr_t adjusterArrayPtr = 0;
        if (!Mem::tryRead(subUnitDefinitionPtr + CSubUnitDefinition::Offsets::terrain_adjusters, adjusterArrayPtr) ||
            adjusterArrayPtr == 0) {
            return;
        }

        // Read on first use. The definitions come off the map in one pass now, so
        // there is nothing to defer behind a button the way there was while this
        // meant walking the heap.
        if (CTerrain::Terrains->empty()) {
            CTerrain::CacheTerrains();
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

            CUnitAdjuster::CUnitAdjuster adjuster;
            if (!Mem::tryRead(adjusterArrayPtr + (terrain->id * CUnitAdjuster::SIZE), adjuster)) {
                entity.terrain.clear();
                return;
            }

            TerrainStat stat;
            stat.name = terrain->name;
            stat.isWater = terrain->is_water;
            stat.attack = adjuster.attack + terrain->attack;
            stat.defence = adjuster.defence + terrain->defence;
            stat.attrition = adjuster.attrition + terrain->attrition;
            stat.movement = adjuster.movement;
            entity.terrain.push_back(stat);
        }

        collectEnvironments(entity, subUnitDefinitionPtr, typeMask);
    }
}

uintptr_t Inspector::idlerAddress() {
    return CInGameIdler::current();
}

std::vector<Entity> Inspector::getSelection() {
    std::vector<Entity> selection;

    const uintptr_t ingameIdlerPtr = idlerAddress();
    if (ingameIdlerPtr == 0) {
        return selection;
    }

    const uintptr_t moduleBase = Mem::moduleBase("hoi3_tfh.exe");
    const uintptr_t CArmyVFTable = moduleBase + 0x11BDE0C;
    const uintptr_t CNavyVFTable = moduleBase + 0x11C869C;
    const uintptr_t CAirVFTable = moduleBase + 0x011C8774;
    const uintptr_t CMapProvinceVFTable = moduleBase + 0x11BEC1C;

    // Everything below walks pointers that are only meaningful if this really is the
    // live idler. While cycling candidates it usually is not, so every read is
    // validated and a bad one just ends the walk.
    uintptr_t nodePtr = 0;
    if (!Mem::tryRead(ingameIdlerPtr + 0x1304, nodePtr)) {
        return selection;
    }

    int guard = 0;
    while (nodePtr != 0 && guard++ < MAX_SELECTED_ENTITIES) {
        HDS::LinkedListNodeSingle node;
        if (!Mem::tryRead(nodePtr, node)) {
            break;
        }

        const uintptr_t entityPtr = node.data;
        if (entityPtr == 0) {
            break;
        }

        uintptr_t entityType = 0;
        if (!Mem::tryRead(entityPtr, entityType)) {
            break;
        }

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
            readHoi3String(entityPtr + CUnit::Offsets::name, entity.name);
            collectStats(entity, entityPtr, typeMask);
        }

        selection.push_back(entity);
        nodePtr = reinterpret_cast<uintptr_t>(node.next);
    }

    return selection;
}
