#pragma once
#include <cstdint>

/**
 * CRegiment - one regiment, brigade or ship inside a unit.
 *
 * The unit holds them in the list at CUnit::Offsets::regiments. The order of battle reads air and naval sub units through
 * these same offsets and has never shown anything that looked wrong, but only the land
 * case is known to be CRegiment: the class name comes from RTTI, the layout from the
 * memory map in DaveStuff/mem.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CRegiment {
    namespace Offsets {
        /**
         * **What the regiment has left**, in the same scale as its definition's
         * max_strength: x10 on a land regiment, x1000 on an air or naval one, which
         * Oob::strengthOf() applies.
         *
         * Read off the game (**read**): what a unit's supply consumption is scaled by
         * against `CSubUnitDefinition::max_strength` (`0x1BB6CB`), what a new regiment is
         * given when it is built, and what the unit's own average strength
         * (CUnit::Slots::AVERAGE_STRENGTH) is the average of.
         */
        constexpr uintptr_t strength = 0x5C;

        /**
         * **A ceiling rather than what it has**: set to the regiment's strength when it is
         * built and afterwards only ever raised to it, never lowered (**read**, the
         * builder at `0x484F7E`). CUnit's slot 24 adds this up over a unit's regiments
         * without averaging it.
         *
         * BiceLib read this as the strength until 2026-09-16. For a regiment at full
         * strength the two are the same, which is why nothing looked wrong.
         */
        constexpr uintptr_t strength_ceiling = 0x30;

        constexpr uintptr_t organisation = 0x60; // x1000
        constexpr uintptr_t name = 0x68;
        constexpr uintptr_t sub_unit_definition_ptr = 0x58;

        /**@brief the CUnit this regiment belongs to

           How the game's per regiment supply and fuel functions reach the unit's order and
           the order of battle above it, rather than being passed either (**read**).*/
        constexpr uintptr_t unit_ptr = 0xB0;

        /**
         * **Every point here is another 1% of supply and fuel** for this regiment: the
         * consumption functions add `extra_consumption x 10` to a potency whose base is
         * 1000, then scale the definition's figure by it (**read**, `0x1BB7A0` and
         * `0x1AD300`). The 10 is a define at `0x168873C` whose name is not known and which
         * nine other places read for unrelated things; see `reversing/CLASSES.md`.
         *
         * A cached total: the game recomputes it at `0x1ABFC0` by adding up the second
         * dword of every element of the list at +0x84. **What that list holds has not been
         * established**, so the name says what the field does, not what it counts.
         */
        constexpr uintptr_t extra_consumption = 0xCC;
    }

    /**@brief the whole object, from the allocation its builders make (`0x84D56`, **read**)*/
    constexpr uintptr_t SIZE = 0xD8;

    namespace VFTable {
        constexpr uintptr_t CRegiment = 0x11BDD7C; // module relative, RTTI, unused so far
    }
}
