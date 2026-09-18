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
        constexpr uintptr_t is_tank = 0x34;
        constexpr uintptr_t is_ship = 0x2E;
        constexpr uintptr_t is_cag = 0x32;                // carrier air group
        constexpr uintptr_t is_bomber = 0x37;
        constexpr uintptr_t can_paradrop = 0x38;

        constexpr uintptr_t is_buildable = 0x36;          // boolean
        constexpr uintptr_t CUnitAdjuster_ptr = 0x54;     // Terrain modifiers
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
         * adds up `CTechnologyStatus::Offsets::build_cost_by_technology` over them and feeds
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
        constexpr uintptr_t sub_unit_amount = 0x180;
        constexpr uintptr_t sprite = 0x198;

        // Land units
        constexpr uintptr_t width = 0xE8;
        constexpr uintptr_t weight = 0x10C;
        constexpr uintptr_t defensiveness = 0x11C;
        constexpr uintptr_t toughness = 0x120;
        constexpr uintptr_t softness = 0x124;
        constexpr uintptr_t armor = 0x12C;
        constexpr uintptr_t suppression = 0x130;
        constexpr uintptr_t soft_attack = 0x134;
        constexpr uintptr_t hard_attack = 0x138;
        constexpr uintptr_t piercing_attack = 0x13C;

        // Ships
        constexpr uintptr_t is_capital = 0x2F;    // boolean
        constexpr uintptr_t is_transport = 0x30;  // boolean
        constexpr uintptr_t is_sub = 0x31;        // boolean
        constexpr uintptr_t can_be_pride = 0x39;  // boolean
        constexpr uintptr_t transport_capacity = 0x144;
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

        /**@brief a pointer to ints indexed by CTechnology's index (+0x244): what each
                  technology does to a unit type's build cost, summed over the type's own
                  technology list (**read**, `0x63D40`)*/
        constexpr uintptr_t build_cost_by_technology = 0x218;

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
