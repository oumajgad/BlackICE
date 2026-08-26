#include <GameState/CustomMapMode.hpp>

#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CProvinceBuilding.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/MapModeHooks.hpp>
#include <MemScan.hpp>
#include <Settings.hpp>

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
    // The floors below hold red and blue off zero. That was once taken for a hard
    // requirement, after a colour with both channels at zero drew nothing while the
    // same colour with them between 20 and 50 drew correctly. It is not one: the
    // game's own infrastructure ramp ends on pure green, red and blue both zero, and
    // draws it. Whatever went wrong on that occasion was something else. The floors
    // stay because this ramp is tuned around them.
    const int GREEN_FLOOR = 90;
    const int GREEN_RANGE = 165;
    const int SIDE_FLOOR = 24;
    const int SIDE_RANGE = 36;

    // The heat ramp, taken from the game's own infrastructure map mode. Its colouring
    // loop at 0x466F80 tests the infrastructure level against ten thresholds and picks
    // one of exactly these colours. Building levels run 1 to TOP_LEVEL, the same range
    // infrastructure does, so the ladder carries across unchanged and this map mode
    // reads the way that one does.
    //
    // The game keeps them as floats with blue at zero and alpha at one; its packer at
    // 0x6628B0 multiplies by 255 and truncates toward zero, and these are what comes
    // out of it.
    //
    // Deliberately not smooth: 6 is a bright yellow green and 7 a dark one, so the
    // ladder steps backwards in brightness there before climbing again. That is the
    // game's own choice, reproduced rather than tidied up.
    const int HEAT_RAMP[CustomMapMode::TOP_LEVEL][3] = {
        {  25,   0, 0 },   // 1   near black red
        { 153,   0, 0 },   // 2   dark red
        { 204,  25, 0 },   // 3   red
        { 255,  76, 0 },   // 4   orange
        { 255, 255, 0 },   // 5   yellow
        { 165, 191, 0 },   // 6   yellow green
        {  25, 102, 0 },   // 7   dark green
        {  51, 127, 0 },   // 8   green
        {  63, 186, 0 },   // 9   brighter green
        {   0, 255, 0 },   // 10  pure green
    };

    // Kept between sessions, by name rather than by number so the file says which
    // ramp it means. Anything unrecognised reads as the green one.
    const char* PALETTE_KEY = "customMapMode.palette";
    const char* PALETTE_GREEN = "green";
    const char* PALETTE_HEAT = "heat";

    std::vector<CustomMapMode::Building> knownBuildings;
    bool enabledFlag = false;
    int selectedIndex = -1;
    CustomMapMode::Palette activePalette = CustomMapMode::Palette::Green;
    bool paletteLoaded = false;

    uint32_t pack(int red, int green, int blue) {
        return 0xFF000000u
            | (static_cast<uint32_t>(red & 0xFF) << 16)
            | (static_cast<uint32_t>(green & 0xFF) << 8)
            | static_cast<uint32_t>(blue & 0xFF);
    }

    /**
    @brief the chosen palette, reading the saved one the first time it is asked for

    Read on demand rather than at startup: the settings file lives beside the DLL, and
    the DLL is loaded long before there is any reason to know what colour anything is.
    */
    CustomMapMode::Palette currentPalette() {
        if (!paletteLoaded) {
            paletteLoaded = true;
            activePalette = (Settings::getString(PALETTE_KEY, PALETTE_GREEN) == PALETTE_HEAT)
                ? CustomMapMode::Palette::Heat
                : CustomMapMode::Palette::Green;
        }
        return activePalette;
    }

    /**@brief the heat ramp at one level, which must be 1 to TOP_LEVEL*/
    uint32_t heatColour(int capped) {
        const int* rgb = HEAT_RAMP[capped - 1];
        return pack(rgb[0], rgb[1], rgb[2]);
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

        // Switching the mode on with nothing chosen would leave it waiting for a
        // second click before anything happened, so the first building is selected.
        if (selectedIndex < 0 && !buildings().empty()) {
            selectedIndex = 0;
        }
    }
    enabledFlag = on;
    Hooks::MapMode::setActive(enabled());
    Hooks::MapMode::repaint();
}

CustomMapMode::Palette CustomMapMode::palette() {
    return currentPalette();
}

void CustomMapMode::setPalette(Palette which) {
    currentPalette();       // so the load does not overwrite this afterwards
    activePalette = which;
    Settings::setString(PALETTE_KEY,
        (which == Palette::Heat) ? PALETTE_HEAT : PALETTE_GREEN);
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

    // A handful of provinces hold something in this slot that is not a level: four
    // of fourteen thousand carry values in the hundreds of thousands. Whatever those
    // are, they are not building levels, and letting them through would paint those
    // provinces as though they held the highest level on the map.
    const int levels = level / CProvinceBuilding::LEVEL_SCALE;
    if (levels > MAX_SANE_LEVEL) {
        return 0;
    }
    return levels;
}

int CustomMapMode::victoryPointsFor(uintptr_t province) {
    // Off: the VP map mode keeps the game's own colours.
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

    if (currentPalette() == Palette::Heat) {
        return heatColour(capped);
    }

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
