#pragma once
#include <cstdint>

/**
 * CDefines - what the game read out of `common/defines.lua`.
 *
 * `GetDefines` (`0x45D90`) makes it on first use and keeps it at `0x1686040`. The object
 * itself is mostly pointers to blocks, one per block in the file, and **a block is the
 * file's entries in file order, one dword each, x1000**.
 *
 * That last part is worth knowing before adding anything here: an offset in a block is
 * `index x 4`, and the index is the entry's position in its block in `defines.lua`. It has
 * been checked exactly once, on the economy block, where all 21 entries matched the mod's
 * own values in a running game - see `Economy`. **The military block does not count out the
 * same way**, so the mapping is not safe to assume; check a block against a running game
 * before trusting a name in it.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CDefines {
    /**@brief the single instance, made by `GetDefines` (`0x45D90`)*/
    constexpr uintptr_t Instance = 0x1686040;

    namespace Offsets {
        /**@brief the `economy = { ... }` block; see CDefines::Economy*/
        constexpr uintptr_t economy = 0x9C;

        /**@brief the `military = { ... }` block, which CDefinesSupply describes*/
        constexpr uintptr_t military = 0xAC;
    }

    /**
     * The `economy` block, `Offsets::economy`. Every value is x1000.
     *
     * **Read live**, and not a guess: all 21 entries match the mod's own `defines.lua`,
     * values included, and they carry the mod's numbers rather than vanilla's.
     */
    namespace Economy {
        constexpr uintptr_t MAX_PROVINCE_SELL_PRICE = 0x00;
        constexpr uintptr_t LEADERSHIP_TO_DIPLOMACY = 0x04;
        constexpr uintptr_t IC_TO_MONEY = 0x08;
        constexpr uintptr_t IC_TO_CONSUMER_GOODS = 0x0C;
        constexpr uintptr_t IC_TO_SUPPLIES = 0x10;
        constexpr uintptr_t CONVOY_BUILD_COST = 0x14;
        constexpr uintptr_t CONVOY_BUILD_TIME = 0x18;
        constexpr uintptr_t ESCORT_BUILD_COST = 0x1C;
        constexpr uintptr_t ESCORT_BUILD_TIME = 0x20;
        constexpr uintptr_t LEADERSHIP_TO_SPIES = 0x24;
        constexpr uintptr_t BUILDING_REPAIR_SPEED = 0x28;
        constexpr uintptr_t LEADERSHIP_TO_OFFICERS = 0x2C;
        constexpr uintptr_t THREAT_FROM_CONVOYS_MODIFIER = 0x30;
        constexpr uintptr_t CONVOY_CONSTRUCTION_SIZE = 0x34;
        constexpr uintptr_t MAX_DAILY_TRADE = 0x38;
        constexpr uintptr_t CONVOY_PATH_LENGTH_MULT = 0x3C;
        constexpr uintptr_t CONVOY_TRADE_WEIGHT_MULT = 0x40;
        constexpr uintptr_t RESOURCE_TO_IC_COST = 0x44;
        constexpr uintptr_t CARGO_TONS_SUNK_SCALE = 0x48;
        constexpr uintptr_t LL_CONVOY_EFF_IMPACT = 0x4C;
        constexpr uintptr_t LL_CONVOY_EFF_REGAIN = 0x50;
    }

    /**
     * What a convoy or an escort costs and takes to build: four functions of one shape
     * (**read**), each `define x (1000 + a technology figure) / 1000`, floored at 10.
     *
     *     0xFD590  GetConvoyBuildCost   Economy::CONVOY_BUILD_COST   CTechnologyStatus +0x44
     *     0xFD600  GetConvoyBuildTime   Economy::CONVOY_BUILD_TIME                    +0x48
     *     0xFD670  GetEscortBuildCost   Economy::ESCORT_BUILD_COST                    +0x4C
     *     0xFD6E0  GetEscortBuildTime   Economy::ESCORT_BUILD_TIME                    +0x50
     *
     * All four are CCountry methods answering a CFixedPoint through a hidden pointer.
     */
    namespace GameFunction {
        constexpr uintptr_t GetDefines = 0x45D90;
    }
}
