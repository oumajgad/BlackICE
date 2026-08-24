#include <GameState/CustomMapMode.hpp>

#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CProvinceBuilding.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/MapModeHooks.hpp>
#include <MemScan.hpp>

namespace {
    // The game state, and the province array hanging off it - the same route
    // CMapProvince::GetMapProvinceById takes.
    const uintptr_t GAME_STATE_POINTER = 0x1689790;

    // Enough to find a province that has a building array; provinces are numbered from
    // one and the sea ones have none.
    const int MAX_PROVINCE_ID = 20000;

    // The victory point field the loop reads, answered with zero while the mode is on.
    const uintptr_t PROVINCE_VICTORY_POINTS = 0x34;

    // Nothing in the mod builds anywhere near this; it is only here to reject a slot
    // that does not hold a level at all.
    const int MAX_SANE_LEVEL = 100;

    // Who holds the province, as an index into the same country array the loop uses
    // for the fog of war - so it can be compared with the country being drawn for.
    const uintptr_t PROVINCE_CONTROLLER = 0x338;

    // A province with none of the chosen building.
    const uint32_t COLOUR_WITHOUT = 0xFFC8C8C8;          // light grey

    // The green ramp, level 1 to TOP_LEVEL.
    //
    // Red and blue are not zero, and that matters: the version of this that set them
    // to zero showed no green on the map at all, while the same code with them at
    // 20-50 did. Something downstream does not take a colour with two dead channels.
    const int GREEN_FLOOR = 90;
    const int GREEN_RANGE = 165;
    const int SIDE_FLOOR = 24;
    const int SIDE_RANGE = 36;

    std::vector<CustomMapMode::Building> knownBuildings;
    bool enabledFlag = false;
    int selectedIndex = -1;

    uint32_t pack(int red, int green, int blue) {
        return 0xFF000000u
            | (static_cast<uint32_t>(red & 0xFF) << 16)
            | (static_cast<uint32_t>(green & 0xFF) << 8)
            | static_cast<uint32_t>(blue & 0xFF);
    }

    uintptr_t gameState() {
        const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
        if (base == 0) {
            return 0;
        }
        uint32_t state = 0;
        if (!Mem::tryRead(base + GAME_STATE_POINTER, state)) {
            return 0;
        }
        return state;
    }

    /**@brief any province that has a building array, to read the definitions off*/
    uintptr_t anyProvince() {
        const uintptr_t state = gameState();
        if (state == 0) {
            return 0;
        }
        uint32_t array = 0;
        if (!Mem::tryRead(state + CMapProvince::GAME_STATE_PROVINCE_ARRAY, array)
            || array == 0) {
            return 0;
        }

        for (int id = 1; id < MAX_PROVINCE_ID; id++) {
            uint32_t province = 0;
            if (!Mem::tryRead(array + id * 4, province) || province == 0) {
                continue;
            }
            uint32_t buildings = 0;
            if (Mem::tryRead(province + CMapProvince::Offsets::CProvinceBuilding_array_ptr,
                buildings) && buildings != 0) {
                return province;
            }
        }
        return 0;
    }

}

const std::vector<CustomMapMode::Building>& CustomMapMode::buildings() {
    if (!knownBuildings.empty()) {
        return knownBuildings;
    }

    const uintptr_t province = anyProvince();
    if (province == 0) {
        return knownBuildings;
    }

    uint32_t array = 0;
    if (!Mem::tryRead(province + CMapProvince::Offsets::CProvinceBuilding_array_ptr, array)
        || array == 0) {
        return knownBuildings;
    }

    for (int i = 0; i < CProvinceBuilding::MAX_BUILDINGS; i++) {
        uint32_t entry = 0;
        if (!Mem::tryRead(array + i * 4, entry) || entry == 0) {
            break;
        }
        uint32_t definition = 0;
        if (!Mem::tryRead(entry + CProvinceBuilding::Offsets::definition_ptr, definition)
            || definition == 0) {
            break;
        }

        Building building;
        building.index = i;
        building.name = HDS::readString(definition + CBuilding::Offsets::name);
        building.label = HDS::readString(definition + CBuilding::Offsets::displayName);
        if (building.name.empty()) {
            break;
        }

        // The array starts with a placeholder standing for "no building here", which
        // is why every real building sits one later than in common/buildings.txt.
        if (i != CProvinceBuilding::NO_BUILDING_INDEX) {
            knownBuildings.push_back(building);
        }
    }
    return knownBuildings;
}

void CustomMapMode::forget() {
    knownBuildings.clear();
}

bool CustomMapMode::enabled() {
    return enabledFlag && selectedIndex >= 0;
}

void CustomMapMode::setEnabled(bool on) {
    if (on) {
        Hooks::MapMode::install();
    }
    enabledFlag = on;
    Hooks::MapMode::setActive(enabled());
}

int CustomMapMode::selected() {
    return selectedIndex;
}

void CustomMapMode::select(int buildingIndex) {
    selectedIndex = buildingIndex;
    Hooks::MapMode::setActive(enabled());
}

int CustomMapMode::levelIn(uintptr_t province, int buildingIndex) {
    if (province == 0 || buildingIndex < 0) {
        return 0;
    }

    uint32_t array = 0;
    if (!Mem::tryRead(province + CMapProvince::Offsets::CProvinceBuilding_array_ptr, array)
        || array == 0) {
        return 0;
    }
    uint32_t entry = 0;
    if (!Mem::tryRead(array + buildingIndex * 4, entry) || entry == 0) {
        return 0;
    }
    int32_t level = 0;
    if (!Mem::tryRead(entry + CProvinceBuilding::Offsets::level_current, level)) {
        return 0;
    }
    if (level <= 0) {
        return 0;
    }

    // A handful of provinces hold something in this slot that is not a level - four
    // of fourteen thousand came back in the hundreds of thousands. Whatever they are,
    // they are not a building, and letting them through would paint them as though
    // they were the highest level on the map.
    const int levels = level / CProvinceBuilding::LEVEL_SCALE;
    if (levels > MAX_SANE_LEVEL) {
        return 0;
    }
    return levels;
}

int CustomMapMode::victoryPointsFor(uintptr_t province) {
    // Off: the VP map mode behaves exactly as it always did.
    if (!enabled() || province == 0) {
        int32_t points = 0;
        if (province != 0 && Mem::tryRead(province + PROVINCE_VICTORY_POINTS, points)) {
            return points;
        }
        return 0;
    }
    return 0;
}

uint32_t CustomMapMode::colourFor(uintptr_t province, int viewingCountry) {
    if (!enabled() || province == 0) {
        return 0;
    }

    const std::vector<Building>& all = buildings();
    if (selectedIndex < 0 || selectedIndex >= static_cast<int>(all.size())) {
        return 0;
    }

    const int level = levelIn(province, all[selectedIndex].index);
    if (level <= 0) {
        return COLOUR_WITHOUT;
    }

    // Only what the player holds is shaded by level. Anywhere else the building shows
    // up at the lowest shade, so the map says where it is without claiming to know how
    // much of it is there.
    int32_t controller = -1;
    const bool mine = Mem::tryRead(province + PROVINCE_CONTROLLER, controller)
        && controller == viewingCountry;

    const int shown = mine ? level : 1;
    const int capped = (shown > TOP_LEVEL) ? TOP_LEVEL : shown;

    const int green = GREEN_FLOOR + (GREEN_RANGE * capped) / TOP_LEVEL;
    const int side = SIDE_FLOOR + (SIDE_RANGE * capped) / TOP_LEVEL;
    return pack(side, green, side);
}

bool CustomMapMode::hooked() {
    return Hooks::MapMode::installed();
}

const char* CustomMapMode::status() {
    return Hooks::MapMode::status();
}
