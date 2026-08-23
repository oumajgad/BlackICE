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
 * Everything here is only valid for this build of hoi3_tfh.exe, which is already true
 * of every address in BiceLib. The layout came from the memory map in DaveStuff/mem,
 * which is where anything further learned about these structures should go back to.
 */
namespace CUnit {
    namespace Offsets {
        constexpr uintptr_t is_selected = 0x4;
        constexpr uintptr_t type = 0x10;
        constexpr uintptr_t id = 0x14;
        constexpr uintptr_t regiments_linked_list_first_ptr = 0x38;
        constexpr uintptr_t regiments_linked_list_last_ptr = 0x3C;
        constexpr uintptr_t regiments_amount = 0x40;
        constexpr uintptr_t upgrade_prio = 0xA4;          // boolean!
        constexpr uintptr_t upgrade_active = 0xA5;        // boolean!
        constexpr uintptr_t reinforcements_active = 0xA6; // boolean!
        constexpr uintptr_t order_ptr = 0xB0;
        constexpr uintptr_t CSubUnitDefinitionPtr = 0xC8;
        constexpr uintptr_t combat_cooldown = 0xD4;
        constexpr uintptr_t supply_received_percentage = 0xFC;
        constexpr uintptr_t fuel_received_percentage = 0x100;
        constexpr uintptr_t owner_tag = 0x124;
        constexpr uintptr_t owner_id = 0x128;
        constexpr uintptr_t leader_ptr = 0x12C;
        constexpr uintptr_t current_province_ptr = 0x130;
        constexpr uintptr_t supplied_from_province_ptr = 0x134;
        constexpr uintptr_t movement_order_next_province_ptr = 0x138;
        constexpr uintptr_t movement_order_last_current_province_ptr = 0x13C;
        constexpr uintptr_t movement_order_remaining_provinces_count = 0x140;
        constexpr uintptr_t in_game_idler_ptr = 0x160;
        constexpr uintptr_t name = 0x16C;
        constexpr uintptr_t name_length = 0x17C;
        constexpr uintptr_t dig_in_level = 0x1C8;
        constexpr uintptr_t base_ca_bonus = 0x1CC;
        constexpr uintptr_t higher_oob_unit_ptr = 0x1E0;
        constexpr uintptr_t lower_oob_unit_linked_list_first_ptr = 0x1E4;
        constexpr uintptr_t lower_oob_unit_linked_list_last_ptr = 0x1E8;
        constexpr uintptr_t lower_oob_unit_amount = 0x1EC;
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

    /**@brief the values oob_level takes; only land units use the whole ladder*/
    namespace Level {
        constexpr int Theatre = 0;
        constexpr int ArmyGroup = 1;
        constexpr int Army = 2;
        constexpr int Corps = 3;
        constexpr int Division = 4;   // also what a lone brigade is held as
        constexpr int Navy = 5;
    }

    void pushCUnitToStack(lua_State* L, uintptr_t unitPtr);
}
