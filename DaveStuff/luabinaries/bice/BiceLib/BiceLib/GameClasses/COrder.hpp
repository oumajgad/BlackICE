#pragma once
#include <cstdint>

/**
 * COrder - what a unit has been told to do.
 *
 * Six classes derive from it, all at offset 0: CMoveOrder, CNullOrder and
 * CStrategicRedeploymentOrder add nothing at all and share COrder's save path outright,
 * while CAirOrder, CNavalOrder and CSupportAttackOrder override it and call back into
 * COrder's for the keys they do not handle themselves.
 *
 * Named from `COrder::SaveContents` (`0x187530`) and `COrder::LoadKey` (`0x186FE0`) - see
 * CPersistent.hpp for how that works - and checked against a `strategic_redeployment=` block
 * in a save, which carries the lot:
 *
 *     strategic_redeployment={ province=2712 stance=1 start_date="1942.4.7.15"
 *                              death_date="1942.4.7.15" return_to_base=no time=2
 *                              priority=0 stop=0.700 }
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace COrder {
    namespace Offsets {
        /**@brief the CUnit this order belongs to; not saved, since the unit is what writes
           the order out. **Read live**: a CArmy, CNavy or CAir by its own RTTI on every
           order in a running game*/
        constexpr uintptr_t unit = 0x8;

        /**@brief where the order sends the unit, a CMapProvince*, saved as `province` by
           writing that province's id. **Read live**: a CMapProvince on every order that has
           one, and null on every CNullOrder*/
        constexpr uintptr_t province = 0xC;

        /**@brief what the order is aimed at, an object id like a sub unit's, saved as
           `target` and only where it is not the game's "no object" pair. **Read live**: set
           on 12 of 357 air orders and on nothing else*/
        constexpr uintptr_t target_type = 0x10;
        constexpr uintptr_t target_id = 0x14;

        /**@brief saved as `return_to_base`. **Read live**: set on 30 of 357 air orders.
           CNavalOrder keeps its own at +0x34 instead*/
        constexpr uintptr_t return_to_base = 0x18;

        /**@brief saved as `priority`. **Read live**: zero on every order in a running game.
           CAirOrder parses it into this same field; CNavalOrder keeps its own at +0x38*/
        constexpr uintptr_t priority = 0x1C;

        /**@brief saved as `stance`. **Read live**: 1 on every order in a running game, so
           what the other values mean is open*/
        constexpr uintptr_t stance = 0x20;

        /**@brief saved as `stop`, x1000. **Read live**: 0.7 on redeployments and support
           attacks, -1.0 on move and null orders*/
        constexpr uintptr_t stop = 0x24;

        /**@brief game ticks, saved as `start_date` and `death_date` and written as dates.
           **Read live**: real dates on a redeployment - 60814998 is 1942-05-09 06:00 - and
           the zero tick 43808760 on orders that were never given one*/
        constexpr uintptr_t start_date = 0x28;
        constexpr uintptr_t death_date = 0x2C;

        /**@brief saved as `time`, read with `%i`. **Read live**: 2 on every order in a
           running game*/
        constexpr uintptr_t time = 0x30;
    }

    namespace VFTable {
        constexpr uintptr_t COrder = 0x11C589C;   // module relative, RTTI, 35 slots
        constexpr uintptr_t CAirOrder = 0x11C5EB4;                // 40 slots, five of its own
        constexpr uintptr_t CMoveOrder = 0x11C59BC;
        constexpr uintptr_t CNavalOrder = 0x11C6CD4;
        constexpr uintptr_t CNullOrder = 0x11C592C;
        constexpr uintptr_t CSupportAttackOrder = 0x11C5A4C;
    }

    namespace GameFunction {
        constexpr uintptr_t SaveContents = 0x187530;   // slot 2
        constexpr uintptr_t LoadKey = 0x186FE0;        // slot 4
    }
}

/**
 * CAirOrder - an air mission, with two things COrder has no room for.
 *
 * Its loader handles `return_to_base` and `priority` itself, into COrder's own fields, and
 * anything it does not know it looks up **as a unit type**: a key that names one stores its
 * value into the array at +0x34 indexed by `CSubUnitDefinition::Offsets::index`. So an air
 * order's block can carry a line per unit type. **Read live**: that array and the province
 * list below are empty on 356 of 357 air orders in a running game.
 */
namespace CAirOrder {
    namespace Offsets {
        /**@brief ints indexed by a sub unit definition's index, filled from any save key
           that names a unit type*/
        constexpr uintptr_t by_unit_type = 0x34;

        /**@brief the provinces the mission covers, saved one `provinces=` line each; a list
           whose nodes are 16 bytes - the CMapProvince, the previous node, the next and a
           spare*/
        constexpr uintptr_t provinces_first = 0x44;
        constexpr uintptr_t provinces_last = 0x48;
        constexpr uintptr_t provinces_count = 0x4C;
    }
}

/**
 * CNavalOrder - and the one trap in this family.
 *
 * **It keeps its own `return_to_base` and `priority` rather than the base's**: its loader
 * intercepts both keys before COrder sees them and stores them at +0x34 and +0x38, leaving
 * COrder's +0x18 and +0x1C unused on a naval order. The same key means a different field
 * depending on which order class is reading it.
 *
 * **Read live**: no CNavalOrder existed in the game this was read from, so none of these
 * five has been seen holding a value.
 */
namespace CNavalOrder {
    namespace Offsets {
        constexpr uintptr_t return_to_base = 0x34;   // not COrder's +0x18
        constexpr uintptr_t priority = 0x38;         // not COrder's +0x1C
        constexpr uintptr_t capital = 0x3C;          // saved as `capital`
        constexpr uintptr_t sub_unit = 0x40;         // saved as `sub_unit`
        constexpr uintptr_t other = 0x44;            // saved as `other`
    }
}

/**
 * CSupportAttackOrder - a unit joining someone else's battle. One key of its own.
 */
namespace CSupportAttackOrder {
    namespace Offsets {
        /**@brief saved as `combat`. **Read live**: set on all three of them*/
        constexpr uintptr_t combat = 0x34;
    }
}
