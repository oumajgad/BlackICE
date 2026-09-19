#pragma once
#include <cstdint>

/**
 * CAIStrategy - what the AI has decided about everyone else.
 *
 * One per country (**read live**: 326 of them), reached from `CCountry +0x1DC`, and the
 * whole of it is named from the keys `CAIStrategy::SaveContents` (`0x4A4860`) writes and
 * `CAIStrategy::LoadKey` (`0x4A40B0`) reads back. See CPersistent.hpp for how that works.
 *
 * **The four percentages are x1000 and the three land/air/naval ones add to one.** Read live
 * off a 1942 game, Germany had `max_subunits` 1250, `land_perc` 837, `air_perc` 50,
 * `naval_perc` 113 and `armor_bias` 330.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CAIStrategy {
    namespace VFTable {
        constexpr uintptr_t CAIStrategy = 0x11EBF24;   // module relative, RTTI, 6 slots
    }

    namespace Offsets {
        /**@brief the country this strategy belongs to*/
        constexpr uintptr_t country_tag = 0x8;

        /**@brief the AI personality, saved as `personality`*/
        constexpr uintptr_t personality = 0x18;

        constexpr uintptr_t initialized = 0x14;   // "initialized"
        constexpr uintptr_t is_static = 0x15;     // "static"
        constexpr uintptr_t consolidate = 0x16;   // "consolidate"

        /**
         * **Provinces the AI has picked out**, each a list of sixteen bytes - first, last,
         * count and a spare. Written one key per entry.
         */
        constexpr uintptr_t conquer_prov = 0x1C;
        constexpr uintptr_t defend_prov = 0x2C;
        constexpr uintptr_t building_prov = 0x10C;

        /**
         * **What the AI thinks of other countries**, each twenty-eight bytes: a list of
         * sixteen - first, last, count and a spare - and then a count, `0x1FF` and a
         * pointer. Read live off Germany in a 1942 game: two on `threat`, seven on
         * `antagonize`, seven on `befriend`, three on `protect`, three on `military_access`,
         * two on `rival`, none on `vassal`.
         */
        constexpr uintptr_t threat = 0x3C;
        constexpr uintptr_t antagonize = 0x58;
        constexpr uintptr_t befriend = 0x74;
        constexpr uintptr_t protect = 0x90;
        constexpr uintptr_t vassal = 0xAC;
        constexpr uintptr_t military_access = 0xC8;
        constexpr uintptr_t rival = 0x11C;

        /**@brief the theatres, saved as `area_theatre` with the tag beside it*/
        constexpr uintptr_t theatres = 0xE4;

        /**@brief how many brigades the AI is aiming for, x1000*/
        constexpr uintptr_t max_subunits = 0xF8;

        /**@brief how it splits production, x1000; the three add to one*/
        constexpr uintptr_t land_perc = 0xFC;
        constexpr uintptr_t air_perc = 0x100;
        constexpr uintptr_t naval_perc = 0x104;

        /**@brief how much of the land share goes to armour, x1000*/
        constexpr uintptr_t armor_bias = 0x108;

        /**@brief who it means to fight, saved as `war_with`*/
        constexpr uintptr_t war_targets = 0x148;
    }

    namespace GameFunction {
        constexpr uintptr_t LoadKey = 0x4A40B0;       // slot 4, one key read back
        constexpr uintptr_t SaveContents = 0x4A4860;  // slot 2, what a strategy writes
    }
}
