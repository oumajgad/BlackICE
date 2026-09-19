#pragma once
#include <cstdint>

/**
 * CProvinceBuilding - one building in one province, and CBuilding, the definition it
 * points at.
 *
 * A province holds an array of these at CMapProvince::Offsets::buildings, one entry per
 * building the mod defines, whether the province has one or not. **Index 0 is
 * "nobuilding"**, so the array is one longer than common/buildings.txt and every real
 * building sits one index later than its position in that file. Read the name off the
 * definition rather than counting lines in the file.
 *
 * Levels are scaled by a thousand: an infrastructure of 4 reads as 4000. This holds
 * across a running game - of 1,500 provinces carrying infrastructure, all 1,500 give
 * a level between 1 and 10 once divided down.
 *
 * Offsets from DaveStuff/mem/classes/CProvinceBuilding.py, confirmed live. Only valid
 * for this build of hoi3_tfh.exe.
 */
namespace CProvinceBuilding {
    namespace Offsets {
        constexpr uintptr_t effect = 0x10;
        constexpr uintptr_t definition_ptr = 0x18;   // a CBuilding
        constexpr uintptr_t level_max = 0x20;        // x1000
        constexpr uintptr_t level_current = 0x24;    // x1000
    }

    namespace VFTable {
        constexpr uintptr_t CProvinceBuilding = 0x11C0A50;      // module relative
        constexpr uintptr_t CProvinceBuildingBase = 0x11C0A78;  // the base at object +8
    }

    /**@brief a level is held as thousandths; this is the level a person would say*/
    constexpr int LEVEL_SCALE = 1000;

    /**@brief what the array holds before the first real building*/
    constexpr int NO_BUILDING_INDEX = 0;

    /**@brief the mod defines 59, and the array carries nobuilding as well*/
    constexpr int MAX_BUILDINGS = 128;
}

/**
 * CBuilding - what a building is, rather than one a province has.
 */
namespace CBuilding {
    namespace VFTable {
        constexpr uintptr_t CBuilding = 0x11C09F8;   // module relative, RTTI
    }

    namespace Offsets {
        /**
         * **What a building does, and it is only ever one thing**: the value at
         * `effect_size` and the modifier it belongs to at `effect`. Whichever modifier key
         * the definition carries lands here - `ic = 1` on industry, `infrastructure = 0.1`
         * on infra, `fort_level = 0.4` on land_fort, `local_anti_air = 2.5` on anti_air,
         * `local_crude_oil = 0.3` on oil_well - and a building with no such key, like
         * `air_base`, has zero and the NONE modifier.
         *
         * `CBuilding::LoadKey` reaches it through its last branch: a key it does not know
         * is looked up in the modifier table, and if it is there the definition goes in
         * `effect` and the number in `effect_size`. **Read live** against the mod's own
         * `buildings.txt`, every one of the seven checked agreeing to the thousandth.
         */
        constexpr uintptr_t effect_size = 0x8;  // x1000
        constexpr uintptr_t effect = 0xC;       // the modifier definition; its name is at +4

        constexpr uintptr_t name = 0x1C;        // the key, "air_base"
        constexpr uintptr_t displayName = 0x38; // what the game shows, "Air Base"
        constexpr uintptr_t index = 0x54;       // the game's GetIndex

        /**@brief **what it costs to build**, x1000 - `cost` in `common/buildings.txt`

           **Read live** and checked against the mod's file: `air_base` 2600 for `cost = 2.6`,
           `naval_base` 4275 for `4.275`, the nuclear reactors 50000 for `50`. What a country
           actually pays is `CCountry::GetBuildCost` (`0xDFDA0`), which discounts this.*/
        /**
         * **`capital = yes` in buildings.txt.** `CBuilding::LoadKey` (`0xB6950`) sets it
         * from that key, and it does two things:
         *
         *  - **the production screen** only looks for a build button for a building that
         *    has it. Three places walk the building database, skip anything without the
         *    flag, and ask the window for a child named after the building's key -
         *    `country_production.gui`'s `air_base`, `naval_base`, `industry`, `anti_air`,
         *    `radar_station`, `nuclear_reactor` and `rocket_test` buttons. BlackICE's own
         *    `country_production.gui` has none of those, so nothing comes of it there.
         *  - **when a construction finishes with no province** (`0x85C98`), only a flagged
         *    building does anything: the game makes a `CBuildingDeployment` holding it and
         *    puts it in the country's deployment queue, beside finished units. Without the
         *    flag, or with a province, the level of `province->buildings[index]` goes up
         *    instead.
         *
         * **Read live**: set on 47 of the 60 buildings. The ones without it are the forts -
         * `land_fort`, `coastal_fort`, `beach_defence`, `fortress`, `weather_fort`,
         * `desperate_defence` - plus `infra` and BlackICE's `request_*` entries. Those are
         * exactly the buildings that are always raised in a province you name up front.
         */
        /**
         * **Everything else `buildings.txt` sets**, from `CBuilding::LoadKey` (`0xB6950`),
         * which is the whole of the file's grammar for a building. `cost`,
         * `completion_size` and `damage_factor` are x1000; `time` and `max_level` are plain.
         * A key the file leaves out keeps the default the constructor gave it, which is why
         * `show_for_province` and `repair` read true on buildings that never mention them.
         */
        constexpr uintptr_t time = 0x5C;              // "time", in days
        constexpr uintptr_t port = 0x61;              // "port"
        constexpr uintptr_t on_completion = 0x6C;     // a std::string: the practical it feeds
        constexpr uintptr_t completion_size = 0x8C;   // x1000
        constexpr uintptr_t damage_factor = 0x90;     // x1000
        constexpr uintptr_t onmap = 0x94;             // "onmap"
        constexpr uintptr_t visibility = 0x95;        // "visibility"
        constexpr uintptr_t show_for_province = 0x96; // "show_for_province"
        /**
         * **Two lists of words that nothing ever reads.** Each key takes a `{ ... }` block
         * and every word in it becomes a `std::string` on a list - head, tail and count in
         * the usual three - and that is the end of it.
         *
         * Inside CBuilding's own code (`0xB65D0` to `0xB7400`) the only references to
         * either list are the two branches of `CBuilding::LoadKey` that fill them and the
         * two places that empty them again. Outside it, none of the 44 places that fetch
         * the building database goes on to read either. **No consumer was found**, which
         * is not quite the same as proving there is none - a reader could reach a building
         * by a route not enumerated here - but nothing suggests one.
         *
         * Neither vanilla's `buildings.txt` nor BlackICE's uses either key, and **read
         * live**, all 61 buildings have both lists empty.
         */
        constexpr uintptr_t prerequisites = 0xAC;
        constexpr uintptr_t prerequisites_last = 0xB0;
        constexpr uintptr_t prerequisites_count = 0xB4;
        constexpr uintptr_t not_if_x_exists = 0xCC;
        constexpr uintptr_t not_if_x_exists_last = 0xD0;
        constexpr uintptr_t not_if_x_exists_count = 0xD4;
        constexpr uintptr_t confirm = 0xDC;           // "confirm"
        constexpr uintptr_t orientation = 0xDD;       // "orientation"
        constexpr uintptr_t repair = 0xDE;            // "repair"

        constexpr uintptr_t capital = 0x60;

        constexpr uintptr_t cost = 0x58;

        /**@brief **the technology category the cost is discounted by**, a
                  CTechnologyCategory*

           **Read live**: most buildings point at `construction_practical`, the nuclear
           reactors at `nuclear_bomb`, `smallarms_factory` at `infantry_theory`,
           `automotive_factory` at `automotive_theory`, `radar_station` at
           `electronic_engineering_practical`.*/
        constexpr uintptr_t technology_category_ptr = 0x88;
    }
}

/**
 * CTechnologyCategory - one of the 48 theory and practical lines a country has a level in.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CTechnologyCategory {
    namespace VFTable {
        constexpr uintptr_t CTechnologyCategory = 0x11C3510;   // module relative, RTTI, 3 slots

        /**@brief the `nocategory` object, which derives from it and adds a fourth slot

           **Slot 2 is the same body either way** - the folded `mov al,1; ret` at `0xA92590`,
           which 259 virtual tables share - so a null category answers the build cost check
           exactly as a real one does. See `CCountry::GetBuildCost`.*/
        constexpr uintptr_t CNullTechnologyCategory = 0x11C355C;
    }

    /**
     * Its three virtuals, all named by BiceLib. Slots 0 and 1 answer a std::string by value,
     * copied from the two strings below; the bodies are the same two addresses the technology
     * *folder* classes use, so neither can be named from its body (**read**).
     *
     * **Slot 2 is inference**: the body is the folded `mov al,1; ret` at `0xA92590`, which is
     * also what `CMinister::IsValid` and half a dozen other registered `IsValid` methods are,
     * and `CNullTechnologyFolder` - the null object of the sibling class - overrides exactly
     * that slot with `xor al,al; ret`. `CNullTechnologyCategory` does **not** override it, so
     * a null category answers true; see `CCountry::GetBuildCost`.
     */
    namespace Slots {
        constexpr int GET_NAME = 0;
        constexpr int GET_SHORT_NAME = 1;
        constexpr int IS_VALID = 2;
    }

    namespace Offsets {
        constexpr uintptr_t key = 0x8;          // "construction_practical"
        constexpr uintptr_t displayName = 0x24; // "Construction Practical"

        /**@brief the key of the short name, "construction_practical_short"; slot 1 answers it*/
        constexpr uintptr_t shortName = 0x40;

        /**@brief what CCountry::Offsets::category_levels and category_shared_from are
                  indexed by; 1 to 48 in this mod, 0 being no category*/
        constexpr uintptr_t index = 0x5C;
    }
}
