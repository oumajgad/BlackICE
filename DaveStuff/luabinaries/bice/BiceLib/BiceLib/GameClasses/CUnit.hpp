#pragma once
#include <cstdint>
#include <lua.hpp>

/**
 * CArmy, CNavy and CAir - the three classes an order of battle is made of.
 *
 * They share a layout, so one set of offsets covers all three, and which of them a
 * unit is is told by its vftable rather than by any field. A unit is a node in a
 * tree: theatres at the top, then army groups, armies, corps and divisions.
 *
 * Everything here is only valid for this build of hoi3_tfh.exe, as is every address
 * in BiceLib. The layout comes from the memory map in DaveStuff/mem, which is also
 * where anything further learned about these structures belongs.
 */
namespace CUnit {
    namespace Offsets {
        /**@brief the unit is selected - **one byte**

           Read as `cmp byte ptr [unit+4], 0`, and +0x5 to +0x7 hold other fields, which
           carry data of their own while this byte is zero. It used to be recorded as four
           bytes wide.*/
        constexpr uintptr_t is_selected = 0x4;
        constexpr uintptr_t type = 0x10;
        constexpr uintptr_t id = 0x14;
        /**
         * **The unit's own regiments**, a list (HDS::ListOffsets) of CRegiment*. Not a
         * field but a base class: CUnit derives from `CList<CSubUnit*>` at this offset
         * (RTTI). The count is `regiments + HDS::ListOffsets::count`.
         */
        constexpr uintptr_t regiments = 0x38;
        constexpr uintptr_t upgrade_prio = 0xA4;          // boolean!
        constexpr uintptr_t upgrade_active = 0xA5;        // boolean!
        constexpr uintptr_t reinforcements_active = 0xA6; // boolean!
        /**
         * **The unit's current order**, a COrder*.
         *
         * Which kind it is comes from virtual slot 16, which COrder leaves pure virtual and
         * every concrete order fills with `mov eax, <id>; ret`. `0x5A4` is
         * `CStrategicRedeploymentOrder`; the rest of the ids are in `reversing/CLASSES.md`.
         * The game reads it this way itself - a land unit whose order answers `0x5A4` burns
         * no fuel (**read**, `0x1BB7A0`).
         */
        constexpr uintptr_t order_ptr = 0xB0;
        constexpr uintptr_t CSubUnitDefinitionPtr = 0xC8;
        constexpr uintptr_t combat_cooldown = 0xD4;
        constexpr uintptr_t supply_received_percentage = 0xFC;
        constexpr uintptr_t fuel_received_percentage = 0x100;
        constexpr uintptr_t owner = 0x124;     // a CCountryTag
        constexpr uintptr_t leader_ptr = 0x12C;
        constexpr uintptr_t current_province_ptr = 0x130;
        constexpr uintptr_t supplied_from_province_ptr = 0x134;
        constexpr uintptr_t movement_order_next_province_ptr = 0x138;
        constexpr uintptr_t movement_order_last_current_province_ptr = 0x13C;
        constexpr uintptr_t movement_order_remaining_provinces_count = 0x140;
        constexpr uintptr_t in_game_idler_ptr = 0x160;
        constexpr uintptr_t name = 0x16C;      // a Hoi3CString
        constexpr uintptr_t dig_in_level = 0x1C8;
        constexpr uintptr_t base_ca_bonus = 0x1CC;
        constexpr uintptr_t higher_oob_unit_ptr = 0x1E0;
        /**@brief the units directly below this one in the order of battle, a CUnitList
                  (HDS::ListOffsets) - the game's `GetChildren`*/
        constexpr uintptr_t children = 0x1E4;
        constexpr uintptr_t oob_level = 0x1F4;
    }

    /**
     * What a unit is, by the vftable at the start of it.
     *
     * Module relative, so add Mem::moduleBase("hoi3_tfh.exe") before comparing. A
     * pointer whose vftable is none of these is not a unit at all, which is the check
     * that keeps a stale pointer from being read as though it were one.
     *
     * Each class has a second vftable as well, for the base it inherits at object
     * offset 8. Those never appear at the start of a unit, so they are not here.
     */
    namespace VFTable {
        constexpr uintptr_t CArmy = 0x11BDE0C;
        constexpr uintptr_t CNavy = 0x11C869C;
        constexpr uintptr_t CAir = 0x11C8774;
    }

    /**
     * Virtual slots worth calling, by index into the vftable above. All four unit
     * classes share these three, and each answers a CFixedPoint through a hidden return
     * pointer: `int* __thiscall slot(CUnit* unit, int* result)`, cleaning four bytes.
     *
     * The first two are what the game shows for a unit: it walks the regiments at
     * Offsets::regiments, adds the field up, and divides by the regiment count
     * (Offsets::regiments + HDS::ListOffsets::count). **read.**
     */
    namespace Slots {
        /**@brief the average of the regiments' CRegiment::Offsets::organisation*/
        constexpr int AVERAGE_ORGANISATION = 20;

        /**@brief the average of the regiments' CRegiment::Offsets::strength*/
        constexpr int AVERAGE_STRENGTH = 21;

        /**@brief the regiments' CRegiment::Offsets::strength_ceiling added up, not averaged*/
        constexpr int TOTAL_STRENGTH_CEILING = 24;
    }

    /**@brief the values oob_level takes; only land units use the whole ladder*/
    namespace Level {
        constexpr int Theatre = 0;
        constexpr int ArmyGroup = 1;
        constexpr int Army = 2;
        constexpr int Corps = 3;
        constexpr int Division = 4;   // also what a lone brigade is held as
        constexpr int Navy = 5;
    }

    /**
     * The game's own consumption calculations, called rather than reimplemented.
     *
     * The definition's supply_consumption and fuel_consumption are only the base
     * figures for one sub unit. What the game shows on a unit is those summed over
     * its regiments, each scaled by how much of its strength is left, and the whole
     * scaled by a potency that starts at 1000, gains the country's global modifier
     * CModifier::SUPPLY_CONSUMPTION, and loses an amount for the skill of the leader of the army group
     * above the unit. Reimplementing that would mean maintaining a copy of it, while
     * calling it keeps the numbers the game's own.
     *
     * Both are module relative addresses, so they are only right for this build.
     * Neither writes anything to the game.
     */
    namespace GameFunction {
        constexpr uintptr_t supplyConsumption = 0x1BB560;
        constexpr uintptr_t fuelConsumption = 0x1BB7A0;
    }

    /**@brief what the unit's own regiments consume, in thousandths - 2910 is 2.91

       Zero for a unit that holds no regiments of its own: a corps consumes through
       the divisions under it, and the order of battle adds those up separately.

       @param unit a CArmy, CNavy or CAir
       @param withoutLeaders leaves out the leader and country effects, giving the
              base figure the unit inspector shows*/
    [[nodiscard]] int supplyConsumption(uintptr_t unit, bool withoutLeaders = false);

    /**@brief the same for fuel, in thousandths*/
    [[nodiscard]] int fuelConsumption(uintptr_t unit, bool withoutLeaders = false);

    void pushCUnitToStack(lua_State* L, uintptr_t unitPtr);
}
