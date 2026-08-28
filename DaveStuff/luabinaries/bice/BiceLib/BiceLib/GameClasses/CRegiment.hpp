#pragma once
#include <cstdint>

/**
 * CRegiment - one regiment, brigade or ship inside a unit.
 *
 * The unit holds them in the list at CUnit::Offsets::regiments_linked_list_first_ptr,
 * with the count beside it. The order of battle reads air and naval sub units through
 * these same offsets and has never shown anything that looked wrong, but only the land
 * case is known to be CRegiment: the class name comes from RTTI, the layout from the
 * memory map in DaveStuff/mem.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CRegiment {
    namespace Offsets {
        // x10 on a land regiment, x1000 on an air or naval one. Oob::strengthOf()
        // is where that is applied.
        constexpr uintptr_t strength = 0x30;
        constexpr uintptr_t organisation = 0x60; // x1000
        constexpr uintptr_t name = 0x68;
    }

    namespace VFTable {
        constexpr uintptr_t CRegiment = 0x11BDD7C; // module relative, RTTI, unused so far
    }
}
