#pragma once
#include <cstdint>
#include <lua.hpp>

/**
 * CSubUnitDefinition - what a kind of regiment, brigade or ship is, rather than one
 * the game has built. The unit type's stats live here; CUnit points at one through
 * CUnit::Offsets::CSubUnitDefinitionPtr.
 *
 * One definition covers land, sea and air, so most of the fields below only mean
 * anything for one of the three - which is what the grouping says.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CSubUnitDefinition {
    /**
     * **A definition is 0x248 bytes** - the gap between neighbours in memory is 584 in
     * 45059 of the pairs a running game has - and **a type has more than one of them**.
     * Besides the definition the unit file makes, every technology that changes the type
     * carries a delta with the same key at `+0x08` and only the fields it touches; the
     * other fields are zero.
     *
     * **So reading "the" definition of a type by scanning for the first instance with
     * that key is wrong**, and quietly so: it can hand back a delta. Seven corps HQs
     * looked like they had lost their combined arms group that way, and had not. Take
     * every instance and expect several.
     */

    /**
     * **Still unplaced**, out of the 70 keys `CSubUnitDefinition::LoadKey` (`0x1A3C80`)
     * takes: `distance` - which fits nothing at any scale, so technology probably moves
     * it - and `type`, `on_completion`, `usable_by`, `minimum_of_type`,
     * `max_percentage_of_type`, `available_trigger`, `extra_amphibious_defence` and
     * `repair_cost_multiplier`, which are strings, triggers or constants and so cannot be
     * fitted against the files at all. They need the offsets read out of the handlers,
     * which is where the decompiler hides them.
     */
    namespace Offsets {
        // General

        // The type's key, as the mod's own files spell it - "infantry_brigade",
        // "artillery_brigade". A std::string, so read it through HDS::readString.
        constexpr uintptr_t key = 0x08;

        // The type's index among all unit types, as the game's GetIndex answers it -
        // what per-type vectors, such as a combatant's losses, are indexed by.
        constexpr uintptr_t index = 0x24;

        // Which kind of unit it is. Booleans, named as the game's own accessors name them
        // (IsRegiment, IsShip, IsCag, IsBomber, CanParadrop).
        constexpr uintptr_t is_regiment = 0x2D;

        /**
         * Three more of the same, which no accessor names. `CCountry::GetBuildTime`
         * (`0xE19A0`) tests them in this order - rocket, tank, air, ship - and picks the
         * matching build speed modifier for whichever hits, so **each flag is named by the
         * modifier it chooses**: ROCKET_BUILD_SPEED (89), TANK_BUILD_SPEED (90),
         * AIR_BUILD_SPEED (87), NAVAL_BUILD_SPEED (91), and LAND_BUILD_SPEED (88) when none
         * of them does.
         *
         * **Read live** and they agree: `+0x2C` is set on `interceptor`, `cag`,
         * `transport_plane`, `flying_rocket` and `flying_bomb`; `+0x33` on the two flying
         * bombs alone; `+0x34` on `armor_brigade` alone. The order matters - a rocket is air
         * as well, and is tested first.
         */
        constexpr uintptr_t is_air = 0x2C;
        constexpr uintptr_t is_rocket = 0x33;
        constexpr uintptr_t is_tank = 0x34;               // `is_armor` in the files
        constexpr uintptr_t is_ship = 0x2E;
        constexpr uintptr_t is_cag = 0x32;                // carrier air group
        constexpr uintptr_t is_bomber = 0x37;
        constexpr uintptr_t can_paradrop = 0x38;

        constexpr uintptr_t is_buildable = 0x36;          // boolean
        /**
         * **The terrain modifiers**, a vector of CUnitAdjuster (CUnitAdjuster.hpp): begin
         * here, end at +0x58,
         * 0x18 bytes each and **indexed by terrain id**. **Read live**: 45 entries on every
         * definition, of which 28 are non-zero on an engineer_brigade, and they are the
         * unit file's terrain blocks to the digit - entry 16 is `urban`, 17 `plains`, 18
         * `woods`, 32 `mountain`.
         */
        constexpr uintptr_t terrain_adjusters = 0x54;
        constexpr uintptr_t terrain_adjusters_end = 0x58;

        /**
         * **The four environments that are not terrain**, a CUnitAdjuster each, held by
         * value. Named by reading each one's value back against the unit files: for
         * `armor_brigade` `fort` is `{0.55, 0.55}`, `river` `{-0.5, 0.35, -0.75}` and
         * `amphibious` `{-1.1, -1.1}`, and `night` is `0.7` attack on a commando_brigade,
         * `0.5` on a paratrooper_brigade and -2.0 movement on a naval_corps_hq_brigade -
         * all exactly what those files say.
         */
        constexpr uintptr_t night = 0x64;
        constexpr uintptr_t fort = 0x7C;
        constexpr uintptr_t river = 0x94;
        constexpr uintptr_t amphibious = 0xAC;

        /**@brief a second vector of CUnitAdjuster, walked by the same code as the terrain
           one. **Read live**: empty on every definition in this mod*/
        constexpr uintptr_t other_adjusters = 0xC4;
        constexpr uintptr_t other_adjusters_end = 0xC8;
        /**
         * **The technology category this type's build cost is discounted by**, a
         * CTechnologyCategory* - the same mechanism buildings use.
         *
         * **Read live**: `infantry_brigade` points at `infantry_practical`, `carrier` at
         * `carrier_practical`, `interceptor` at `single_engine_aircraft_practical`.
         */
        constexpr uintptr_t technology_category_ptr = 0x3C;

        /**
         * **The technologies that bear on this type**, a vector of CTechnology*: begin here,
         * end at +0x48. A loaded definition holds 45 to 56 of them (**read live**). The game
         * adds up `CTechnologyStatus::Offsets::level_by_technology` over them and feeds
         * the total to GetBuildCostIC as its third argument.
         */
        constexpr uintptr_t technologies = 0x44;
        constexpr uintptr_t technologies_end = 0x48;

        // What it costs to build one, as the unit files spell it (**read**, from the
        // game's own GetBuildCostIC, GetBuildCostMP and GetBuildTime). All x1000.
        constexpr uintptr_t build_cost_ic = 0xF8;
        constexpr uintptr_t build_cost_manpower = 0xFC;   // the game's GetBuildCostMP
        constexpr uintptr_t build_time = 0x100;

        // `completion_size` - how much of a unit one of these counts as while it is being
        // built (**read**, the game's GetCompletionSize). x1000.
        constexpr uintptr_t completion_size = 0xE4;

        // The game's own accessor calls this GetDefaultStrength; the unit files call it
        // max_strength, which is the name kept here.
        constexpr uintptr_t max_strength = 0xEC;
        constexpr uintptr_t max_organisation = 0xF0;
        constexpr uintptr_t morale = 0xF4;
        constexpr uintptr_t max_speed = 0x108;
        constexpr uintptr_t supply_consumption = 0x110;
        constexpr uintptr_t fuel_consumption = 0x114;
        constexpr uintptr_t officers = 0x118;
        constexpr uintptr_t air_defence = 0x128;
        constexpr uintptr_t air_attack = 0x140;
        /**
         * **`radio_strength` in the unit files**, x1000. It was called `sub_unit_amount`
         * here, which was wrong: **read live** against the files, 1273 unit types set it
         * to something other than 1 and every one of them matches - `1.5` is 1500.
         */
        constexpr uintptr_t radio_strength = 0x180;
        constexpr uintptr_t sprite = 0x198;

        /**
         * **`priority` in the unit files**, and not scaled: 83 on `infantry_brigade`, 110
         * on `armor_brigade`, 1 on `interceptor`. **Read live**, it fits 98% of the 1642
         * types across 80 distinct values.
         */
        constexpr uintptr_t priority = 0x194;

        /**
         * **`active`**, 1 or 0 rather than a byte. **Read live**: every one of the 84
         * types that declare `active = yes` has 1 here, and 1510 of the 1539 declaring
         * `no` have 0 - what the other 29 are has not been looked into.
         */
        constexpr uintptr_t active = 0x1D0;

        /**
         * **What a transport does to an amphibious invasion**, both x1000 and both only
         * ever set on the four types that declare `transport = yes`:
         * `Aux_vessel`, `Aux_vessel_LR`, `landing_craft` and `transport_ship`.
         */
        constexpr uintptr_t amphibious_invasion_speed = 0x188;
        constexpr uintptr_t amphibious_invasion_defence = 0x18C;

        /**@brief **`is_mobile`**; set on 147 types against the 152 that declare it*/
        constexpr uintptr_t is_mobile = 0x35;

        /**
         * **`unit_group`** - which combined arms group the type belongs to, as **a one
         * based index into `common/combined_arms.txt`'s own order**: the first group
         * declared there is 1, and **0 means none**. The loader looks the name up and
         * stores what it finds (`0x1A4CF1`), so a name that file does not declare leaves
         * a 0 behind without complaint.
         *
         * **Read live** across 1067 types: every group in the mod maps to exactly one
         * value and the order matches the file's.
         */
        constexpr uintptr_t unit_group = 0x1B4;

        // Land units
        constexpr uintptr_t width = 0xE8;   // `combat_width` in the files
        constexpr uintptr_t weight = 0x10C;   // `transport_weight` in the files
        constexpr uintptr_t defensiveness = 0x11C;
        constexpr uintptr_t toughness = 0x120;
        constexpr uintptr_t softness = 0x124;
        constexpr uintptr_t armor = 0x12C;   // `armor_value` in the files
        constexpr uintptr_t suppression = 0x130;
        constexpr uintptr_t soft_attack = 0x134;
        constexpr uintptr_t hard_attack = 0x138;
        constexpr uintptr_t piercing_attack = 0x13C;   // `ap_attack` in the files

        // Ships
        constexpr uintptr_t is_capital = 0x2F;    // boolean / `capital`
        constexpr uintptr_t is_transport = 0x30;  // boolean / `transport`
        constexpr uintptr_t is_sub = 0x31;        // boolean
        constexpr uintptr_t can_be_pride = 0x39;  // boolean
        constexpr uintptr_t transport_capacity = 0x144;   // `transport_capability` in the files
        constexpr uintptr_t range = 0x148;
        constexpr uintptr_t firing_distance = 0x14C;
        constexpr uintptr_t surface_detection = 0x150;
        constexpr uintptr_t air_detection = 0x154;
        constexpr uintptr_t sub_detection = 0x158;
        constexpr uintptr_t visibility = 0x15C;
        constexpr uintptr_t sea_defence = 0x160;
        constexpr uintptr_t convoy_attack = 0x164;
        constexpr uintptr_t sea_attack = 0x168;
        constexpr uintptr_t sub_attack = 0x16C;
        constexpr uintptr_t shore_bombardment = 0x170;
        constexpr uintptr_t hull = 0x178;
        constexpr uintptr_t positioning = 0x184;

        /**
         * **`carrier_size`**, how many carrier air groups the ship carries, x1000 as
         * every other figure here. The game's `IsCarrier` is nothing but this being
         * above zero (`0x94650`: `cmp [ecx+0x190], 0; setg al`).
         *
         * **read**, live: of every key in the mod only the carriers have it, and
         * each one matches its unit file exactly - `carrier` and `command_carrier` and
         * the fifteen `CV_*` uniques 2000 for `carrier_size = 2`, `light_carrier` 1000
         * for 1, and **`escort_carrier` 0**, which in this mod means the game does not
         * count an escort carrier as a carrier at all.
         */
        constexpr uintptr_t carrier_size = 0x190;

        // Air
        constexpr uintptr_t surface_defence = 0x174;
        constexpr uintptr_t strategic_attack = 0x17C;
    }

    void pushCSubUnitDefinitionToStack(lua_State* L, uintptr_t unitPtr);
}

/**
 * CTechnologyStatus - what a country's research has come to. CCountry +0xDF8 points at one.
 *
 * Only the pieces the build cost calculations read are here.
 */
namespace CTechnologyStatus {
    namespace Offsets {
        /**@brief the game's `GetIcModifier`, registered to Lua (**named**)*/
        constexpr uintptr_t ic_modifier = 0x90;

        /**@brief added to the technology category discount by `0xE1AC0`; the neighbour of
                  the one above, and **not** the same figure*/
        constexpr uintptr_t build_discount_extra = 0x94;

        /**
         * **The country's researched level of each technology**, a pointer to ints indexed
         * by CTechnology's index (`+0x244`).
         *
         * It was named `build_cost_by_technology` for its first caller, `0x63D40`, which
         * sums it over a unit type's own technologies and hands the total to
         * GetBuildCostIC - but the array is levels, not costs.
         * `CHistoricalModelSet::MakeSubUnit` copies out of it straight into a new
         * regiment's `CSubUnitTechnology::level` (`mov [ecx+4], esi` at `0x183183`), and
         * **read live** it equals the level 6859 of 7445 regiment entries carry, counting
         * only the non-zero ones - the rest being regiments raised before their country
         * researched further.
         */
        constexpr uintptr_t level_by_technology = 0x218;

        /**@brief a pointer to ints indexed by CSubUnitDefinition::Offsets::index: what
                  technology has done to that unit type's build cost (**read**)*/
        constexpr uintptr_t build_cost_by_unit_type = 0x24C;

        /**@brief the same for manpower, read by `0x63D40`'s manpower half (**read**)*/
        constexpr uintptr_t build_cost_mp_by_unit_type = 0x25C;

        /**@brief and the same for build time, read by `CCountry::GetBuildTime` (**read**)*/
        constexpr uintptr_t build_time_by_unit_type = 0x26C;
    }
}

/**
 * **What a unit type will cost this country in all**, `0x63D40` - `__cdecl`, four arguments:
 * the definition, the country, and somewhere to put an IC figure and a manpower one, either
 * of which may be null to skip that half. Both come back as 64 bit fixed point with 15
 * fractional bits, the `fpml::fixed_point<__int64,48,15>` the game counts in.
 *
 * It is the whole of a build, not a day of one: it adds up the definition's technologies,
 * hands that total to `CCountry::GetBuildTime` (`0xE19A0`) for the days, works the daily cost
 * out with the same terms as `CCountry::GetBuildCostIC` - **except the reserves step, which
 * it does not have** - and multiplies the two. The manpower half does the same from
 * `build_cost_manpower` with `build_cost_mp_by_unit_type` and a floor from a global.
 *
 * Its three callers all add the two figures onto running totals, so this is the piece a
 * production queue is priced with. **Read**, all of it.
 */
