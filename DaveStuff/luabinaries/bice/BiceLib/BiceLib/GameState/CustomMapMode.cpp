#include <GameState/CustomMapMode.hpp>
#include <GameClasses/CCurrentGameState.hpp>

#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CProvinceBuilding.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/MapModeHooks.hpp>
#include <MemScan.hpp>
#include <Settings.hpp>

#include <algorithm>
#include <cmath>

namespace {
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

    std::vector<CustomMapMode::Source> knownBuildings;

    // Fields on the province itself, so the list is fixed rather than read from the
    // game. Keys as the mod's history files spell them. Deliberately not the
    // province's `local_` modifiers at +0x114, which is what CMapProvince::BuildingOffsets
    // - despite the name - reads: those change what a province produces, and are not
    // what it has.
    const std::vector<CustomMapMode::Source> RESOURCES = {
        { CMapProvince::Offsets::energy, "energy", "Energy" },
        { CMapProvince::Offsets::metal, "metal", "Metal" },
        { CMapProvince::Offsets::rares, "rare_materials", "Rare Materials" },
        { CMapProvince::Offsets::oil, "crude_oil", "Crude Oil" },
        { CMapProvince::Offsets::manpower, "manpower", "Manpower" },
        { CMapProvince::Offsets::leadership, "leadership", "Leadership" },
    };

    // The percentiles the resource scale runs between. See CustomMapMode::Scale.
    const double SCALE_LOW = 0.01;
    const double SCALE_HIGH = 0.99;

    bool enabledFlag = false;
    CustomMapMode::Kind shownKind = CustomMapMode::Kind::Building;

    // One selection per kind, so switching kind and back lands where it was.
    int selectedBuilding = -1;
    int selectedResource = -1;

    // Built on the thread that draws the page, when a resource is chosen, and read by
    // colourFor on whichever thread rebuilds the map. A change mid-rebuild can mix two
    // scales in one map for one repaint; the next is whole. Worth that rather than a
    // lock on a function every province passes through.
    CustomMapMode::Scale resourceScale;

    CustomMapMode::Palette activePalette = CustomMapMode::Palette::Green;
    bool paletteLoaded = false;

    int& selectionFor(CustomMapMode::Kind kind) {
        return (kind == CustomMapMode::Kind::Resource) ? selectedResource : selectedBuilding;
    }

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
        return CCurrentGameState::current();
    }

    /**
    @brief the province vector's first entry, and how many entries it has

    Read once for a loop over every province, rather than through
    CCurrentGameState::province() for each - that re-reads the vector every call, and
    finds the module through the loader to do it.

    @returns 0 when there is no game, leaving \p begin at 0
    */
    int provinceVector(uint32_t& begin) {
        begin = 0;
        const uintptr_t state = gameState();
        const int count = CCurrentGameState::provinceCount();
        if (state == 0 || count == 0
            || !Mem::tryRead(state + CCurrentGameState::Offsets::provinces_begin, begin)) {
            begin = 0;
            return 0;
        }
        return count;
    }

    /**@brief any province that has a building array, to read the definitions off*/
    uintptr_t anyProvince() {
        uint32_t array = 0;
        const int count = provinceVector(array);

        // From one: id 0 is a placeholder owned by nobody, not a place on the map.
        for (int id = 1; id < count; id++) {
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

    // The most any province holds of anything is 100, leadership in one province; a
    // thousand is far past that and still nowhere near what junk in a field reads as.
    // The same guard levelIn keeps for buildings, where four real provinces of fourteen
    // thousand hold something that is not a level.
    const int MAX_SANE_RESOURCE = 1000 * CustomMapMode::RESOURCE_SCALE;

    /**@brief a resource's raw value in one province; 0 when it has none or it cannot be read*/
    int resourceIn(uintptr_t province, uintptr_t field) {
        int32_t value = 0;
        if (province == 0 || !Mem::tryRead(province + field, value)
            || value < 0 || value > MAX_SANE_RESOURCE) {
            return 0;
        }
        return value;
    }

    /**@brief the value in a sorted list at quantile \p q, as the history analysis took it*/
    int at(const std::vector<int>& sorted, double q) {
        size_t i = static_cast<size_t>(q * static_cast<double>(sorted.size()));
        if (i >= sorted.size()) {
            i = sorted.size() - 1;
        }
        return sorted[i];
    }

    /**
    @brief works out the scale for one resource from every province that has any

    Every province's value is read, which is fourteen thousand reads - done on a click,
    not on a frame, and not on the thread that paints the map.

    The shade boundaries are held as the raw values they begin at, so colourFor only
    compares integers; the logarithm is taken ten times here and never per province.
    Each is rounded up, because a value reaches a boundary exactly when it is at least
    the true one - and a raw value is an integer.
    */
    CustomMapMode::Scale buildScale(uintptr_t field) {
        CustomMapMode::Scale scale;

        // To the vector's own end and no further. Past it is spare capacity holding
        // whatever the memory last held; walking to a fixed 20000 read 20 of those as
        // "provinces with energy", some in the hundreds of millions, the 99th
        // percentile landed on one, and the legend ran to a million in exponent form.
        // See CCurrentGameState::Offsets::provinces_begin.
        uint32_t array = 0;
        const int count = provinceVector(array);
        if (count == 0) {
            return scale;
        }

        std::vector<int> values;
        for (int id = 1; id < count; id++) {
            uint32_t province = 0;
            if (!Mem::tryRead(array + id * 4, province) || province == 0) {
                continue;
            }
            const int value = resourceIn(province, field);
            if (value > 0) {
                values.push_back(value);
            }
        }
        if (values.empty()) {
            return scale;
        }
        std::sort(values.begin(), values.end());

        const int low = at(values, SCALE_LOW);
        const int high = at(values, SCALE_HIGH);
        scale.producing = static_cast<int>(values.size());
        scale.valid = true;

        // Everything the same, or too few to spread: one boundary, and every province
        // with any reaches it.
        if (high <= low) {
            for (int i = 0; i < CustomMapMode::TOP_LEVEL; i++) {
                scale.starts[i] = low;
            }
            return scale;
        }

        const double ratio = static_cast<double>(high) / static_cast<double>(low);
        for (int i = 0; i < CustomMapMode::TOP_LEVEL; i++) {
            const double start = static_cast<double>(low) *
                std::pow(ratio, static_cast<double>(i) / (CustomMapMode::TOP_LEVEL - 1));
            scale.starts[i] = static_cast<int>(std::ceil(start - 1e-9));
        }
        // The ends exactly, whatever rounding did to them.
        scale.starts[0] = low;
        scale.starts[CustomMapMode::TOP_LEVEL - 1] = high;
        return scale;
    }

    /**@brief rebuilds the resource scale if a resource is what is shown*/
    void refreshScale() {
        if (shownKind != CustomMapMode::Kind::Resource
            || selectedResource < 0
            || selectedResource >= static_cast<int>(RESOURCES.size())) {
            resourceScale = CustomMapMode::Scale();
            return;
        }
        resourceScale = buildScale(RESOURCES[selectedResource].where);
    }

}

const std::vector<CustomMapMode::Source>& CustomMapMode::buildings() {
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

        Source building;
        building.where = static_cast<uintptr_t>(i);
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

const std::vector<CustomMapMode::Source>& CustomMapMode::resources() {
    return RESOURCES;
}

const std::vector<CustomMapMode::Source>& CustomMapMode::sources(Kind which) {
    return (which == Kind::Resource) ? resources() : buildings();
}

void CustomMapMode::forget() {
    knownBuildings.clear();
}

bool CustomMapMode::enabled() {
    // The stored choice, not selected(): this is asked for every province on the map,
    // and checking the choice against the list would mean asking for the list each time.
    return enabledFlag && selectionFor(shownKind) >= 0;
}

bool CustomMapMode::requested() {
    return enabledFlag;
}

void CustomMapMode::setEnabled(bool on) {
    if (on) {
        Hooks::MapMode::install();

        // Switching the mode on with nothing chosen would leave it waiting for a
        // second click before anything happened, so the first one is selected.
        int& chosen = selectionFor(shownKind);
        if (chosen < 0 && !sources(shownKind).empty()) {
            chosen = 0;
        }
        // Again, even with a resource already chosen: the game has moved on since it
        // was, and the scale should describe the map as it is now.
        refreshScale();
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

CustomMapMode::Kind CustomMapMode::kind() {
    return shownKind;
}

int CustomMapMode::selected() {
    return selectionFor(shownKind);
}

void CustomMapMode::select(Kind which, int index) {
    shownKind = which;
    selectionFor(which) = index;
    refreshScale();
    Hooks::MapMode::setActive(enabled());
    Hooks::MapMode::repaint();
}

void CustomMapMode::showKind(Kind which) {
    // The first of the kind if nothing of it has been chosen yet, for the same reason
    // switching the mode on does: otherwise the map goes blank until a second click.
    int chosen = selectionFor(which);
    if (chosen < 0 && !sources(which).empty()) {
        chosen = 0;
    }
    select(which, chosen);
}

const CustomMapMode::Scale& CustomMapMode::scale() {
    return resourceScale;
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

int CustomMapMode::valueIn(uintptr_t province) {
    const int chosen = selectionFor(shownKind);
    const std::vector<Source>& all = sources(shownKind);
    if (chosen < 0 || chosen >= static_cast<int>(all.size()) || province == 0) {
        return 0;
    }
    const Source& source = all[chosen];
    return (shownKind == Kind::Resource)
        ? resourceIn(province, source.where)
        : levelIn(province, static_cast<int>(source.where));
}

int CustomMapMode::shadeFor(int value) {
    if (value <= 0) {
        return 1;
    }

    // A building's level is its shade: both run 1 to 10, the same ladder the game's
    // own infrastructure map mode climbs, so a level means the same thing here.
    if (shownKind == Kind::Building) {
        return (value > TOP_LEVEL) ? TOP_LEVEL : value;
    }

    // A resource climbs the scale: the highest shade whose start it reaches.
    const Scale& scale = resourceScale;
    if (!scale.valid) {
        return 1;
    }
    int shade = 1;
    for (int i = 1; i < TOP_LEVEL; i++) {
        if (value >= scale.starts[i]) {
            shade = i + 1;
        }
    }
    return shade;
}

uint32_t CustomMapMode::shadeColour(int shade) {
    const int capped = (shade < 1) ? 1 : (shade > TOP_LEVEL) ? TOP_LEVEL : shade;

    if (currentPalette() == Palette::Heat) {
        return heatColour(capped);
    }

    const int green = GREEN_FLOOR + (GREEN_RANGE * capped) / TOP_LEVEL;
    const int side = SIDE_FLOOR + (SIDE_RANGE * capped) / TOP_LEVEL;
    return pack(side, green, side);
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

    // How much the player knows about it decides both halves of the appearance below.
    // Using the game's own intel rather than who owns the province means an ally's
    // ground, or somewhere scouted, reads as well as the player's own - and somewhere
    // never seen says only that the thing is there.
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

    const int value = valueIn(province);
    if (value <= 0) {
        return seen ? COLOUR_WITHOUT_SEEN : COLOUR_WITHOUT_UNSEEN;
    }

    // Only somewhere the player knows is shaded by value. Anywhere else it shows up at
    // the lowest shade, so the map says where the thing is without claiming to know
    // how much of it is there.
    return shadeColour(seen ? shadeFor(value) : 1);
}

bool CustomMapMode::hooked() {
    return Hooks::MapMode::installed();
}

const char* CustomMapMode::status() {
    return Hooks::MapMode::status();
}
