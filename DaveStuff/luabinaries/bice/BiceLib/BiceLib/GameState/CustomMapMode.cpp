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

    // Nothing in the mod builds anywhere near this; it is only here to reject a slot
    // that does not hold a level at all.
    const int MAX_SANE_LEVEL = 100;

    // A province with none of the chosen building: lighter where the player can see
    // what is there, darker where they cannot.
    const uint32_t COLOUR_WITHOUT_SEEN = 0xFFC8C8C8;     // light grey
    const uint32_t COLOUR_WITHOUT_UNSEEN = 0xFF787878;   // darker grey

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

bool CustomMapMode::requested() {
    return enabledFlag;
}

void CustomMapMode::setEnabled(bool on) {
    if (on) {
        Hooks::MapMode::install();

        // Switching it on with nothing chosen would leave the mode asking for a
        // second click before it did anything, so it chooses the first building.
        if (selectedIndex < 0 && !buildings().empty()) {
            selectedIndex = 0;
        }
    }
    enabledFlag = on;
    Hooks::MapMode::setActive(enabled());
    Hooks::MapMode::repaint();
}

int CustomMapMode::selected() {
    return selectedIndex;
}

void CustomMapMode::select(int buildingIndex) {
    selectedIndex = buildingIndex;
    Hooks::MapMode::setActive(enabled());
    Hooks::MapMode::repaint();
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
        if (province != 0 && Mem::tryRead(province + CMapProvince::Offsets::victory_points, points)) {
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

    // How much the player knows about it decides both halves of the appearance below.
    // Using the game's own intel rather than who owns the province means an ally's
    // ground, or somewhere scouted, reads as well as the player's own - and somewhere
    // never seen says only that the building is there.
    int32_t known = 0;
    int32_t count = 0;
    uint32_t intelArray = 0;
    if (viewingCountry >= 0
        && Mem::tryRead(province + CMapProvince::Offsets::intel_country_count, count)
        && count > viewingCountry
        && Mem::tryRead(province + CMapProvince::Offsets::intel_by_country_ptr, intelArray)
        && intelArray != 0) {
        uint8_t intel = 0;
        if (Mem::tryRead(intelArray + viewingCountry, intel)) {
            known = intel;
        }
    }
    const bool seen = known >= INTEL_FOR_REAL_LEVEL;

    const int level = levelIn(province, all[selectedIndex].index);
    if (level <= 0) {
        return seen ? COLOUR_WITHOUT_SEEN : COLOUR_WITHOUT_UNSEEN;
    }

    // Only somewhere the player knows is shaded by level. Anywhere else the building
    // shows up at the lowest shade, so the map says where it is without claiming to
    // know how much of it is there.
    const int shown = seen ? level : 1;
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
