#pragma once
#include <cstdint>

/**
 * CTechnology - one technology, and what it does to the units it bears on.
 *
 * **How a technology reaches a unit.** Its effects are not modifiers on the country: each
 * one is a **whole CSubUnitDefinition used as a delta**, named after the unit type it
 * applies to, which is exactly how the technology files spell it -
 * `infantry_brigade = { soft_attack = 0.1 }` inside a technology becomes a definition whose
 * `key` is `infantry_brigade` and whose only non-zero field is `soft_attack`.
 *
 * `CSubUnit::ApplyTechnologies` (`0x1ABFC0`) is what puts them together, and every regiment,
 * ship and wing carries its own copy of its definition for the result (see CRegiment.hpp,
 * `technologies`):
 *
 *     definition = template + sum over the sub unit's technologies of (effect x level)
 *
 * **Read live**: that holds to the point on all 1068 engineer_brigade regiments in a 1942
 * game, on every field tried - `soft_attack`, `max_speed`, `supply_consumption`, the river
 * and fort adjusters and the terrain ones - and the remainder each time is exactly what the
 * unit file says and what the template object in memory holds.
 *
 * This mod's technologies hold **16044 effects across 1175 technologies** (**read live**),
 * so this is the mechanism most of BlackICE's unit balance goes through.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CTechnology {
    namespace Offsets {
        /**@brief the technology's key as the files spell it, a std::string -
           `art_barrel_ammo`. **Read live**, and the loader looks a sub unit's save keys up
           by it*/
        constexpr uintptr_t key = 0x20C;

        /**@brief its name for the player, a std::string - `Artillery Barrel and
           Ammunition`*/
        constexpr uintptr_t name = 0x228;

        /**
         * **What this technology does to each unit type**, a list whose nodes hold the
         * effect at +0 and the next node at +8. Each effect is a CSubUnitDefinition
         * carrying only the changes, and `CSubUnitDefinition::Offsets::key` on it is the
         * unit type the effect is for - which is what `CSubUnit::ApplyTechnologies` matches
         * against the sub unit's own type before applying it.
         *
         * **Read live**: 1175 technologies with 16044 effects between them.
         */
        constexpr uintptr_t effects = 0x294;

        /**
         * **The rest of what a technology file writes**, from `CTechnology::LoadKey`
         * (`0x134AC0`) and **checked against the mod's own 1174 technologies**: the
         * count after each is how many declare the key and how many of those agree.
         *
         * The two that miss by one are a technology declared twice in different files,
         * not a doubt about the offset.
         */
        constexpr uintptr_t start_year = 0x2B4;          // 1173 of 1174, 31 values
        constexpr uintptr_t first_offset = 0x2B8;        // 801 of 802, 32 values
        constexpr uintptr_t additional_offset = 0x2C0;   // 795 of 795, 6 values
        constexpr uintptr_t max_level = 0x2C4;           // 877 of 877, 20 values
        constexpr uintptr_t change = 0x288;              // 388 of 388, a yes or no
        constexpr uintptr_t stealable = 0x2BC;           // 569 of 569, a yes or no

        /**
         * `is_nuclear`. 14 technologies declare it and all 14 agree, but every one of
         * them says `yes`, so the offset rests on the loader rather than on the data.
         */
        constexpr uintptr_t is_nuclear = 0x2CC;

        /**
         * **The `allow` block**, a trigger held by value: the loader hands the block
         * straight to slot 3 of whatever sits here, which is how every other trigger in
         * the game loads itself.
         */
        constexpr uintptr_t allow = 0x248;

        /**
         * **The three build modifiers**, each read by the same helper (`0x45140`) into
         * sixteen bytes of its own: `build_cost_ic_modifier`, `build_cost_mp_modifier`
         * and `build_time_modifier`. What those sixteen bytes hold has not been read.
         */
        constexpr uintptr_t build_cost_ic_modifier = 0x2D0;
        constexpr uintptr_t build_cost_mp_modifier = 0x2E0;
        constexpr uintptr_t build_time_modifier = 0x2F0;

        /**
         * **`activate_building`**, the building this technology unlocks - and the loader
         * writes the technology back onto the building at its `+0x10`, so the two point
         * at each other. `activate_unit` goes onto a list instead (`0x86CC20`), with no
         * field of its own here.
         */
        constexpr uintptr_t activate_building = 0x310;

        /**@brief `can_upgrade`; 273 of 273 agree*/
        constexpr uintptr_t can_upgrade = 0x314;
    }
}
