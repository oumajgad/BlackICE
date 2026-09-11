#pragma once
#include <cstdint>

/**
 * CGoodsPool - an amount of each of the seven goods, and nothing else.
 *
 * `0x24` bytes: the vftable, the `0x18d` every CPersistent carries at +0x4, then seven
 * values in **thousandths** - 1000 is one unit, the way every amount the game keeps is
 * held. The order is not the order the game lists goods in anywhere else: fuel sits
 * between supplies and money, and crude oil comes before metal.
 *
 * It is embedded rather than pointed at almost everywhere: nine in every province (see
 * CMapProvince::Offsets::pool and the eight after it), two in a convoy, 23 in a
 * country. Lua's `CCountry:GetPool()` hands out the capital province's `pool`.
 *
 * The offsets below are within a pool, so reading a good means adding two: where the
 * pool sits in its owner, then where the good sits in the pool.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CGoodsPool {
    namespace VFTable {
        constexpr uintptr_t CGoodsPool = 0x11C1BD4;   // module relative, RTTI, 6 slots
    }

    constexpr uintptr_t SIZE = 0x24;

    /**
     * Where each good sits in a pool, named by its save key. Read out of the pool's save
     * reader (slot 4, `0x123A90`), which stores each key into its slot.
     */
    namespace Goods {
        constexpr uintptr_t supplies = 0x08;
        constexpr uintptr_t fuel = 0x0C;
        constexpr uintptr_t money = 0x10;
        constexpr uintptr_t crude_oil = 0x14;
        constexpr uintptr_t metal = 0x18;
        constexpr uintptr_t energy = 0x1C;
        constexpr uintptr_t rare_materials = 0x20;

        constexpr int COUNT = 7;
    }
}
