#pragma once
#include <cstdint>

/**
 * CTrait - one leader trait, as the game holds it.
 *
 * The game builds one instance per trait defined in the mod and hands leaders pointers
 * to them, so a trait is found by scanning the data section for the vftable rather
 * than by looking it up anywhere. The class name is from RTTI.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CTrait {
    namespace Offsets {
        constexpr uintptr_t name = 0x2C;
    }

    namespace VFTable {
        constexpr uintptr_t CTrait = 0x11C7DC0; // module relative
    }
}
