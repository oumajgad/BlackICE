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
    }
}
