#include <GameState/CustomMapMode.hpp>
#include <GameClasses/CCurrentGameState.hpp>

#include <GameClasses/CGoodsPool.hpp>
#include <GameClasses/CInGameIdler.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CProvinceBuilding.hpp>
#include <GameState/GameClock.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/MapModeHooks.hpp>
#include <MemScan.hpp>
#include <Settings.hpp>

#include <algorithm>
#include <cmath>
#include <excpt.h>

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
    // what it has. The four goods are slots of what the province yields now.
    CustomMapMode::Source resource(uintptr_t where, const char* name, const char* label) {
        CustomMapMode::Source source;
        source.where = where;
        source.name = name;
        source.label = label;
        source.scaling = CustomMapMode::Scaling::Map;
        source.unit = CustomMapMode::Unit::Amount;
        return source;
    }

    const uintptr_t PRODUCING = CMapProvince::Offsets::current_producing;
    const std::vector<CustomMapMode::Source> RESOURCES = {
        resource(PRODUCING + CGoodsPool::Goods::energy, "energy", "Energy"),
        resource(PRODUCING + CGoodsPool::Goods::metal, "metal", "Metal"),
        resource(PRODUCING + CGoodsPool::Goods::rare_materials, "rare_materials", "Rare Materials"),
        resource(PRODUCING + CGoodsPool::Goods::crude_oil, "crude_oil", "Crude Oil"),
        resource(CMapProvince::Offsets::manpower, "manpower", "Manpower"),
        resource(CMapProvince::Offsets::leadership, "leadership", "Leadership"),
    };

    // Days of supply, in thousandths of a day. Close together at the bottom, where a
    // province is running out, and wide at the top: the game keeps a province stocked
    // for SUPPLYPOOL_DAYS of its need, 35 in BlackICE, so one that is well supplied
    // sits in the top shade and anything below it is falling behind.
    const std::vector<int> DAY_BANDS = {
        0, 1000, 2000, 3000, 5000, 7000, 10000, 15000, 21000, 30000 };

    // Steps to the depot, lowest first. The last band holds only CUT_OFF, so a province
    // cut off from every depot is never mistaken for one that is merely far away.
    const std::vector<int> DISTANCE_BANDS = {
        0, 1, 2, 4, 7, 12, 20, 35, 60, CustomMapMode::CUT_OFF };

    // Load, in thousandths of the province's capacity, lowest first. The last band
    // starts at full, so a province asked for more than it can pass on is on its own.
    const std::vector<int> LOAD_BANDS = {
        0, 100, 200, 300, 400, 500, 600, 700, 850, 1000 };

    CustomMapMode::Source supply(CustomMapMode::SupplyMeasure measure, const char* name,
        const char* label, CustomMapMode::Scaling scaling, CustomMapMode::Unit unit,
        const char* explanation) {
        CustomMapMode::Source source;
        source.where = static_cast<uintptr_t>(measure);
        source.name = name;
        source.label = label;
        source.scaling = scaling;
        source.unit = unit;
        source.explanation = explanation;
        if (measure == CustomMapMode::SupplyMeasure::DaysOfSupplies
            || measure == CustomMapMode::SupplyMeasure::DaysOfFuel) {
            source.bands = DAY_BANDS;
        }
        else if (measure == CustomMapMode::SupplyMeasure::DepotDistance) {
            source.bands = DISTANCE_BANDS;
            source.higherIsWorse = true;
        }
        else if (measure == CustomMapMode::SupplyMeasure::SupplyLoad
            || measure == CustomMapMode::SupplyMeasure::FuelLoad) {
            source.bands = LOAD_BANDS;
            source.higherIsWorse = true;
        }
        return source;
    }

    using Measure = CustomMapMode::SupplyMeasure;
    using Scaling = CustomMapMode::Scaling;
    using Unit = CustomMapMode::Unit;
    const std::vector<CustomMapMode::Source> SUPPLIES = {
        supply(Measure::DaysOfSupplies, "days_of_supplies", "Days of supplies",
            Scaling::Bands, Unit::Days,
            "How many days the supplies in the province last its units, at what they use a "
            "day. Each shade starts at the number of days under it. The game keeps a "
            "province stocked for 35 days of its need, so a well supplied one sits in the "
            "top shade. Only provinces with units that use supplies are shaded."),
        supply(Measure::DaysOfFuel, "days_of_fuel", "Days of fuel",
            Scaling::Bands, Unit::Days,
            "How many days the fuel in the province lasts its units, at what they use a "
            "day. Each shade starts at the number of days under it. The game keeps a "
            "province stocked for 35 days of its need, so a well supplied one sits in the "
            "top shade. Only provinces with units that use fuel are shaded."),
        supply(Measure::DepotDistance, "depot_distance", "Distance to depot",
            Scaling::Bands, Unit::Steps,
            "Steps to the supply depot the province draws from. Each shade starts at the "
            "number under it: depots are the top shade, and provinces cut off from every "
            "depot the bottom one. Land in no supply network at all is grey."),
        supply(Measure::SupplyLoad, "supply_load", "Supply line load",
            Scaling::Bands, Unit::Percent,
            "How much of what the province can pass on in a day is asked of it today - "
            "its own units' shortfall and what provinces further out want through it. "
            "Each shade starts at the share under it; at 100% the line through here is "
            "full, and anything beyond waits. How much a province can pass on is the "
            "game's own figure, worked out from the province's modifiers and its "
            "controller's."),
        supply(Measure::FuelLoad, "fuel_load", "Fuel line load",
            Scaling::Bands, Unit::Percent,
            "The same for fuel, which shares the province's capacity figure: how much of "
            "what it can pass on in a day is asked of it today. At 100% the line through "
            "here is full."),
        supply(Measure::SupplyTraffic, "supply_traffic", "Supply traffic",
            Scaling::Map, Unit::Amount,
            "Supplies passed on through the province today, on their way out from the "
            "depot - the supply lines themselves."),
        supply(Measure::FuelTraffic, "fuel_traffic", "Fuel traffic",
            Scaling::Map, Unit::Amount,
            "Fuel passed on through the province today, on its way out from the depot."),
        supply(Measure::SupplyStock, "supply_stock", "Supplies stored",
            Scaling::Map, Unit::Amount,
            "Supplies in the province. A capital's are the country's whole stockpile, so "
            "it sits in the top shade."),
        supply(Measure::FuelStock, "fuel_stock", "Fuel stored",
            Scaling::Map, Unit::Amount,
            "Fuel in the province. A capital's is the country's whole stockpile, so it "
            "sits in the top shade."),
    };

    // The percentiles the resource scale runs between. See CustomMapMode::Scale.
    const double SCALE_LOW = 0.01;
    const double SCALE_HIGH = 0.99;

    bool enabledFlag = false;
    CustomMapMode::Kind shownKind = CustomMapMode::Kind::Building;

    // One selection per kind, so switching kind and back lands where it was.
    int selectedBuilding = -1;
    int selectedResource = -1;
    int selectedSupply = -1;

    // Built on the thread that draws the page, when a source is chosen, and read by
    // colourFor on whichever thread rebuilds the map. A change mid-rebuild can mix two
    // scales in one map for one repaint; the next is whole. Worth that rather than a
    // lock on a function every province passes through.
    CustomMapMode::Scale activeScale;

    // update() paints once a game day, from this hour on, and remembers the day it did.
    const int PAINT_FROM_HOUR = 1;
    int paintedDay = 0;

    CustomMapMode::Palette activePalette = CustomMapMode::Palette::Green;
    bool paletteLoaded = false;

    int& selectionFor(CustomMapMode::Kind kind) {
        switch (kind) {
        case CustomMapMode::Kind::Resource: return selectedResource;
        case CustomMapMode::Kind::Supply: return selectedSupply;
        default: return selectedBuilding;
        }
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

    // Far past the largest stockpile a country holds, and still well inside what an int
    // holds; only here to reject a field that does not hold an amount.
    const int MAX_SANE_SUPPLY = 1000000 * 1000;

    // A province with a year's supplies is as well off as the top shade can say.
    const long long MAX_DAYS = 365LL * CustomMapMode::DAYS_SCALE;

    /**@brief one good in one of the province's embedded pools; 0 when unreadable or below zero*/
    int poolGood(uintptr_t province, uintptr_t pool, uintptr_t good) {
        int32_t value = 0;
        if (!Mem::tryRead(province + pool + good, value)
            || value < 0 || value > MAX_SANE_SUPPLY) {
            return 0;
        }
        return value;
    }

    /**
    @brief one good in today's buffer of a double buffered pair, read through its pointer

    0 when the pointer does not land on one of the two buffers it chooses between.
    */
    int bufferGood(uintptr_t province, uintptr_t pointer, uintptr_t bufferA,
        uintptr_t bufferB, uintptr_t good) {
        uint32_t buffer = 0;
        if (!Mem::tryRead(province + pointer, buffer)
            || (buffer != province + bufferA && buffer != province + bufferB)) {
            return 0;
        }
        return poolGood(buffer, 0, good);
    }

    /**@brief how long the province's stock of \p good lasts its units, in thousandths of a day*/
    int daysOf(uintptr_t province, uintptr_t good) {
        const int need = poolGood(province, CMapProvince::Offsets::need, good);
        if (need <= 0) {
            return CustomMapMode::NO_VALUE;
        }
        const int stock = poolGood(province, CMapProvince::Offsets::pool, good);
        const long long days = static_cast<long long>(stock) * CustomMapMode::DAYS_SCALE / need;
        return static_cast<int>((days > MAX_DAYS) ? MAX_DAYS : days);
    }

    /**@brief an amount, or NO_VALUE where there is none*/
    int anyOf(int amount) {
        return (amount > 0) ? amount : CustomMapMode::NO_VALUE;
    }

    // What a province can pass on in a day, as the daily supply pass is handed it: the
    // game works it out per province just before the pass (RVA 0x9DD00), keeps it only
    // for the pass, and throws it away. So it is worked out again here, by calling the
    // same function, once when a load source is chosen and once a day after that.
    //
    // __stdcall(CMapProvince*, int* out), answering out; thousandths, like any amount.
    // It only reads: the province's local modifiers, two defines and the controller's
    // modifiers.
    const uintptr_t SUPPLY_CAPACITY = 0x9DD00;

    // Indexed by province id. A fixed array rather than a vector, because colourFor may
    // read it on the thread that repaints the map while it is being refilled: an int
    // read mid-refill is at worst a day old, where a reallocated vector would be gone.
    const int MAX_PROVINCES = 100000;
    int capacities[MAX_PROVINCES] = {};
    int capacityCount = 0;

    // A load past this is as full as the bottom shade can say; also what a province
    // with no capacity at all reads as.
    const long long MAX_LOAD = 10000;

    typedef int* (__stdcall* CapacityFunction)(uintptr_t province, int* out);

    /**@brief the game's capacity for one province; false if the call faulted*/
    bool capacityOf(CapacityFunction function, uintptr_t province, int& out) {
        __try {
            int value = 0;
            function(province, &value);
            out = value;
            return true;
        }
        __except (EXCEPTION_EXECUTE_HANDLER) {
            return false;
        }
    }

    /**@brief fills capacities for every province, by calling the game's function*/
    void refreshCapacities() {
        capacityCount = 0;
        const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
        uint32_t array = 0;
        const int count = provinceVector(array);
        if (base == 0 || count == 0 || count > MAX_PROVINCES) {
            return;
        }
        const CapacityFunction function =
            reinterpret_cast<CapacityFunction>(base + SUPPLY_CAPACITY);

        for (int id = 1; id < count; id++) {
            uint32_t province = 0;
            int capacity = 0;
            if (!Mem::tryRead(array + id * 4, province) || province == 0
                || !capacityOf(function, province, capacity)) {
                capacity = 0;
            }
            capacities[id] = capacity;
        }
        capacityCount = count;
    }

    /**
    @brief how much of its capacity is asked of the province today, in thousandths

    Today's `drawn` over the capacity: the province's own shortfall and the demand
    passed on to it from further out, which the pass stops accepting once a province's
    drawn reaches its capacity.
    */
    int loadOf(uintptr_t province, uintptr_t good) {
        using namespace CMapProvince::Offsets;
        const int drawn = bufferGood(province, drawn_ptr, drawn_buffer_a, drawn_buffer_b, good);
        int32_t id = 0;
        if (drawn <= 0 || !Mem::tryRead(province + CMapProvince::Offsets::id, id)
            || id <= 0 || id >= capacityCount) {
            return CustomMapMode::NO_VALUE;
        }
        const int capacity = capacities[id];
        if (capacity <= 0) {
            return static_cast<int>(MAX_LOAD);
        }
        const long long load = static_cast<long long>(drawn) * 1000 / capacity;
        return static_cast<int>((load > MAX_LOAD) ? MAX_LOAD : load);
    }

    int depotDistance(uintptr_t province) {
        int32_t depot = 0;
        int32_t distance = 0;
        if (!Mem::tryRead(province + CMapProvince::Offsets::supply_depot_id, depot)
            || !Mem::tryRead(province + CMapProvince::Offsets::supply_depot_distance, distance)
            || depot <= 0 || distance < 0) {
            // Depot 0 is no supply network at all: the sea, and some land besides.
            return CustomMapMode::NO_VALUE;
        }
        return (distance >= CustomMapMode::CUT_OFF) ? CustomMapMode::CUT_OFF : distance;
    }

    int supplyIn(uintptr_t province, CustomMapMode::SupplyMeasure measure) {
        using namespace CMapProvince::Offsets;
        const uintptr_t supplies = CGoodsPool::Goods::supplies;
        const uintptr_t fuel = CGoodsPool::Goods::fuel;
        switch (measure) {
        case Measure::DaysOfSupplies: return daysOf(province, supplies);
        case Measure::DaysOfFuel:     return daysOf(province, fuel);
        case Measure::SupplyTraffic:
            return anyOf(bufferGood(province, throughput_ptr, throughput_buffer_a,
                throughput_buffer_b, supplies));
        case Measure::FuelTraffic:
            return anyOf(bufferGood(province, throughput_ptr, throughput_buffer_a,
                throughput_buffer_b, fuel));
        case Measure::SupplyStock:    return anyOf(poolGood(province, pool, supplies));
        case Measure::FuelStock:      return anyOf(poolGood(province, pool, fuel));
        case Measure::DepotDistance:  return depotDistance(province);
        case Measure::SupplyLoad:     return loadOf(province, supplies);
        case Measure::FuelLoad:       return loadOf(province, fuel);
        }
        return CustomMapMode::NO_VALUE;
    }

    /**@brief \p source's value in \p province, for a source of \p kind; NO_VALUE for none*/
    int valueOf(const CustomMapMode::Source& source, CustomMapMode::Kind kind,
        uintptr_t province) {
        if (province == 0) {
            return CustomMapMode::NO_VALUE;
        }
        switch (kind) {
        case CustomMapMode::Kind::Resource:
            return anyOf(resourceIn(province, source.where));
        case CustomMapMode::Kind::Supply:
            return supplyIn(province, static_cast<CustomMapMode::SupplyMeasure>(source.where));
        default:
            return anyOf(CustomMapMode::levelIn(province, static_cast<int>(source.where)));
        }
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
    @brief works out the scale for one source from every province that has any

    Every province's value is read, which is fourteen thousand reads - done on a click,
    or once at the start of a repaint for supply, never per province.

    The shade boundaries are held as the raw values they begin at, so colourFor only
    compares integers; the logarithm is taken ten times here and never per province.
    Each is rounded up, because a value reaches a boundary exactly when it is at least
    the true one - and a raw value is an integer.
    */
    CustomMapMode::Scale buildScale(const CustomMapMode::Source& source, CustomMapMode::Kind kind) {
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
            const int value = valueOf(source, kind, province);
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

    /**@brief a source's fixed bands as a scale, so shading them is the same as any other*/
    CustomMapMode::Scale bandScale(const CustomMapMode::Source& source) {
        CustomMapMode::Scale scale;
        if (source.bands.size() != CustomMapMode::TOP_LEVEL) {
            return scale;
        }
        for (int i = 0; i < CustomMapMode::TOP_LEVEL; i++) {
            scale.starts[i] = source.bands[i];
        }
        scale.valid = true;
        return scale;
    }

    /**@brief whether the source shown is one of the loads, which need the capacities*/
    bool showsLoad() {
        if (shownKind != CustomMapMode::Kind::Supply) {
            return false;
        }
        const CustomMapMode::Source* source = CustomMapMode::shownSource();
        if (source == nullptr) {
            return false;
        }
        const auto measure = static_cast<CustomMapMode::SupplyMeasure>(source->where);
        return measure == Measure::SupplyLoad || measure == Measure::FuelLoad;
    }

    /**@brief works out the scale for whatever is shown now, and the capacities a load needs*/
    void refreshScale() {
        if (showsLoad()) {
            refreshCapacities();
        }
        const CustomMapMode::Source* source = CustomMapMode::shownSource();
        if (source == nullptr) {
            activeScale = CustomMapMode::Scale();
            return;
        }
        switch (source->scaling) {
        case Scaling::Map:   activeScale = buildScale(*source, shownKind); break;
        case Scaling::Bands: activeScale = bandScale(*source); break;
        default:             activeScale = CustomMapMode::Scale(); break;
        }
    }

    /**
    @brief whether what is shown has to be worked out again each day

    A map scale over supply, and a load, whose capacities change with the modifiers.
    */
    bool followsTheDay() {
        if (shownKind != CustomMapMode::Kind::Supply) {
            return false;
        }
        const CustomMapMode::Source* source = CustomMapMode::shownSource();
        return source != nullptr && (source->scaling == Scaling::Map || showsLoad());
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

const std::vector<CustomMapMode::Source>& CustomMapMode::supplies() {
    return SUPPLIES;
}

const std::vector<CustomMapMode::Source>& CustomMapMode::sources(Kind which) {
    switch (which) {
    case Kind::Resource: return resources();
    case Kind::Supply: return supplies();
    default: return buildings();
    }
}

const CustomMapMode::Source* CustomMapMode::shownSource() {
    const int chosen = selectionFor(shownKind);
    const std::vector<Source>& all = sources(shownKind);
    if (chosen < 0 || chosen >= static_cast<int>(all.size())) {
        return nullptr;
    }
    return &all[chosen];
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
        // Again, even with a source already chosen: the game has moved on since it
        // was, and the scale should describe the map as it is now.
        refreshScale();
    }
    enabledFlag = on;
    Hooks::MapMode::setActive(enabled());
    Hooks::MapMode::repaint();
}

void CustomMapMode::update() {
    // Only ever on a frame where the clock has just moved in play. A paused game and
    // the main menu look the same - a clock standing still - so neither may paint.
    if (!GameClock::movedInPlay() || !enabled()) {
        return;
    }

    // Once a day, after the midnight processing has run.
    const int day = GameClock::day();
    if (day == paintedDay || GameClock::hour() < PAINT_FROM_HOUR) {
        return;
    }
    paintedDay = day;

    if (followsTheDay()) {
        refreshScale();
    }
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
    return activeScale;
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
    const Source* source = shownSource();
    if (source == nullptr) {
        return NO_VALUE;
    }
    return valueOf(*source, shownKind, province);
}

int CustomMapMode::shadeFor(int value) {
    const Source* source = shownSource();
    if (source == nullptr || value == NO_VALUE) {
        return 1;
    }

    // A building's level is its shade: both run 1 to 10, the same ladder the game's
    // own infrastructure map mode climbs, so a level means the same thing here.
    if (source->scaling == Scaling::Level) {
        return (value < 1) ? 1 : (value > TOP_LEVEL) ? TOP_LEVEL : value;
    }

    // Anything else climbs its scale: the highest shade whose start it reaches.
    const Scale& scale = activeScale;
    if (!scale.valid) {
        return 1;
    }
    int shade = 1;
    for (int i = 1; i < TOP_LEVEL; i++) {
        if (value >= scale.starts[i]) {
            shade = i + 1;
        }
    }
    return source->higherIsWorse ? (TOP_LEVEL + 1 - shade) : shade;
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

int CustomMapMode::tooltipModeFor(int mode) {
    if (mode != CInGameIdler::MapMode::VICTORY_POINTS || !enabled()) {
        return mode;
    }
    switch (shownKind) {
    case Kind::Supply: return CInGameIdler::MapMode::SUPPLY;
    case Kind::Resource: return CInGameIdler::MapMode::RESOURCES;
    default: return mode;
    }
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

    // Supply says nothing about a province the player cannot see - not even that there
    // is something to say, since having units that need supplies gives them away.
    if (!seen && shownKind == Kind::Supply) {
        return COLOUR_WITHOUT_UNSEEN;
    }

    const int value = valueIn(province);
    if (value == NO_VALUE) {
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
