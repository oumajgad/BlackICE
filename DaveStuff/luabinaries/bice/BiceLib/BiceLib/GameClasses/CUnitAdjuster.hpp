#pragma once
#include <cstdint>

/**
 * CUnitAdjuster - what a unit type gets in one environment, and all a technology can change
 * about one.
 *
 * The game holds them by value: one per terrain in the vector at
 * `CSubUnitDefinition::Offsets::terrain_adjusters`, and four more inline on the definition
 * for `night`, `fort`, `river` and `amphibious`.
 *
 * **The four numbers are the class's own save keys**, which is where these names come from:
 * `CUnitAdjuster::LoadKey` (`0x1D4C10`) reads `attack` into +0x8, `defence` into +0xC,
 * `movement` into +0x10 and `attrition` into +0x14. Its SaveContents is an empty `ret`, so
 * an adjuster is read out of the mod's files and never written back.
 *
 * All four are x1000. `CUnitAdjuster::Scale` (`0x1D4E20`) multiplies every one of them by a
 * thousandths factor and does nothing else, which is what says these four are all there is
 * to one. That call is how a technology's effect is scaled by the level a regiment holds -
 * see CTechnology.hpp.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CUnitAdjuster {
    namespace Offsets {
        constexpr uintptr_t vftable = 0x0;

        /**@brief not this class's own: CPersistent keeps a SaveToken here and its
           constructor sets it to `none`. See CPersistent.hpp*/
        constexpr uintptr_t token = 0x4;

        constexpr uintptr_t attack = 0x8;      // all four x1000
        constexpr uintptr_t defence = 0xC;
        constexpr uintptr_t movement = 0x10;
        constexpr uintptr_t attrition = 0x14;
    }

    /**@brief the whole object; the game's own stride when it indexes a terrain vector*/
    constexpr uintptr_t SIZE = 0x18;

    namespace VFTable {
        constexpr uintptr_t CUnitAdjuster = 0x11C3520; // module relative, RTTI, 6 slots
    }

    namespace GameFunction {
        /**@brief `void __stdcall Scale(CUnitAdjuster* adjuster@ESI, int factor@stack:4)`,
           the factor in thousandths*/
        constexpr uintptr_t Scale = 0x1D4E20;

        /**@brief slot 4 of CPersistent: the four keys above*/
        constexpr uintptr_t LoadKey = 0x1D4C10;
    }

    struct CUnitAdjuster
    {
        int vftable;
        int token;      // CPersistent's; `none` on every object in a running game
        int attack;
        int defence;
        int movement;
        int attrition;
    };
}
