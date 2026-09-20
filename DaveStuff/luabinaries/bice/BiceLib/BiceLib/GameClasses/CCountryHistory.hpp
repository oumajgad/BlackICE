#pragma once
#include <cstdint>

/**
 * CHistoryContainer and CCountryHistory - how `history/countries` and `history/provinces`
 * are read, and why a date is a valid key in them.
 *
 * **`CHistoryContainer::LoadKey` handles only the dates.** It is the loader
 * `CCountryHistory` and `CProvinceHistory` both inherit, and all it does is decide
 * whether the key is a date:
 *
 *     capital = 9191          # not a date, so applied at once
 *     government = absolute_monarchy
 *
 *     1938.9.1 = {            # a date, so the block is read and applied on that day
 *         head_of_state = 54001
 *         ...
 *     }
 *
 * A key that is not a date goes straight to **vftable slot 9**, the derived class's
 * entry handler; a key that is one parses the date and then loops, reading key/value
 * pairs out of the block and calling that same slot 9 for each. **So there is exactly one
 * grammar**, and a date block is only a way of postponing it - which is why anything that
 * works at the top of a country file also works inside a dated block.
 *
 * ## What the entry handler names
 *
 * `CCountryHistory`'s handler (slot 9) names **33 keys outright**:
 *
 *     alignment  capital  clr_country_flag  clr_global_flag  crude_oil  decision
 *     dissent  energy  fuel  government  government_in_exile  historical_friend
 *     ideology  join_faction  leader  leave_faction  manpower  metal  money
 *     national_unity  neutrality  nukes  officers  officers_ratio  oob  organization
 *     popularity  rare_materials  remove_decision  set_country_flag  set_global_flag
 *     supplies  threat
 *
 * and everything else is resolved as **a name out of a database**. Counting what the mod's
 * own 108 country files say at the top level (**read live**, against the running game's
 * databases):
 *
 * | | uses |
 * | --- | --- |
 * | a technology | 6119 |
 * | a technology category, the practicals and theories | 4222 |
 * | one of the 33 above | 1082 |
 * | a government position - `head_of_state = 54001` | 884 |
 * | a law | 631 |
 *
 * That is everything bar **78 names nothing declares at all, in 219 uses** - starting
 * technologies that were removed. See bugs.md at the mod root.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CHistoryContainer {
    namespace GameFunction {
        /**
         * Slot 4. `(this, parse)` - the key is tested for being a date; if it is not, it
         * goes to slot 9 as it stands, and if it is, the date is parsed and every pair in
         * the block that follows goes to slot 9 instead.
         *
         * **Ghidra's analysis does not find it**, because nothing calls it except through
         * a vftable. Make a function there before decompiling.
         */
        constexpr uintptr_t LoadKey = 0x1FCC10;
    }

    namespace VFTable {
        /**@brief the slot both histories put their own entry handler in*/
        constexpr int ENTRY_SLOT = 9;
    }
}

namespace CCountryHistory {
    namespace GameFunction {
        /**@brief slot 9: one key of a country's history, dated or not. 23 keys of its own
                  and the rest by database lookup*/
        constexpr uintptr_t LoadEntry = 0x1ECA90;
    }

    namespace VFTable {
        constexpr uintptr_t CCountryHistory = 0x11C9710;   // module relative, 10 slots
    }
}

/**
 * CProvinceHistory - `history/provinces`, the same date-block shape as the country half.
 *
 * **Its entry handler names eighteen keys**:
 *
 *     add_core  controller  crude_oil  energy  fuel  leadership  manpower  metal  money
 *     owner  points  rare_materials  remove_core  revolt  revolt_risk
 *     strategic_resource  supplies  terrain
 *
 * and everything else is a building. **That is the whole grammar** - against the mod's own
 * province files nothing else is left:
 *
 * | | uses |
 * | --- | --- |
 * | one of the eighteen | 50,174 |
 * | a building from `common/buildings.txt` | 17,330 |
 * | nine misspelled keys, in bugs.md | 15 |
 *
 * An earlier reading of this handler found only twelve keys and left the four province
 * resources looking unaccounted for. That was `switchmap.py` shadowing a variable, not
 * the engine hiding anything - see FINDINGS-script.md.
 */
namespace CProvinceHistory {
    namespace GameFunction {
        /**@brief slot 9: `owner`, `controller`, `manpower`, `add_core`, and then names*/
        constexpr uintptr_t LoadEntry = 0x1FCED0;
    }
}

/**
 * CTechStatistics - **the country-wide effects a technology can have**.
 *
 * A technology writes them at its own top level, beside its `allow` block:
 *
 *     construction_engineering = {
 *         reinforce_chance = 0.015
 *         supply_throughput = 0.05
 *     }
 *
 * and its loader is one switch with a case per effect. **44 of them**, which is the whole
 * list - anything else at that level is a unit type (a per-unit effect), a technology (a
 * prerequisite), or the technology's own shape.
 *
 *     allow_escorts              attack_delay             attack_movement_speed
 *     bomber_targeting           casualty_trickleback     combat_efficiency
 *     convoy_build_cost          convoy_build_time        decay
 *     dig_in_cap                 division_size            energy_production
 *     energy_to_oil_conversion   escort_build_cost        escort_build_time
 *     escort_efficiency          fighter_targeting        frontline_focus
 *     ground_defence_effiency    ic_efficiency            ic_modifier
 *     ic_to_supplies             leadership_gain          listening_station
 *     manpower_gain              maximum_attrition        metal_production
 *     naval_air_target_chance    naval_base_efficiency    nuclear_production
 *     provincial_aa_efficiency   radar_impact             radio_strength
 *     rares_production           refinery_efficiency      reinforce_chance
 *     repair_rate                research_efficiency      reserve_focus
 *     supply_throughput          supply_transfer_cost     targeting_chance
 *     targeting_choice           unit_cooperation
 *
 * **`ground_defence_effiency` is the engine's own spelling**, missing an `i`. A mod that
 * spells it correctly gets nothing.
 *
 * **Eight of the 44 the mod never uses**: `convoy_build_cost`, `convoy_build_time`,
 * `decay`, `dig_in_cap`, `division_size`, `escort_build_cost`, `escort_build_time` and
 * `ground_defence_effiency`. They are levers nothing pulls.
 *
 * See CSubUnitDefinition.hpp for `CTechnologyStatus`, which is where the totals end up.
 */
namespace CTechStatistics {
    namespace GameFunction {
        /**@brief slot 4: a case per country-wide technology effect, 44 of them*/
        constexpr uintptr_t LoadKey = 0x137DB0;
    }
}
