#pragma once
#include <CasualLibrary.hpp>
#include <lua.hpp>

namespace CUnit {
    namespace Offsets {
        extern uintptr_t is_selected;
        extern uintptr_t type;
        extern uintptr_t id;
        extern uintptr_t regiments_linked_list_first_ptr;
        extern uintptr_t regiments_linked_list_last_ptr;
        extern uintptr_t regiments_amount;
        extern uintptr_t upgrade_prio;          // boolean!
        extern uintptr_t upgrade_active;        // boolean!
        extern uintptr_t reinforcements_active; // boolean!
        extern uintptr_t order_ptr;
        extern uintptr_t CSubUnitDefinitionPtr;
        extern uintptr_t combat_cooldown;
        extern uintptr_t supply_received_percentage;
        extern uintptr_t fuel_received_percentage;
        extern uintptr_t owner_tag;
        extern uintptr_t owner_id;
        extern uintptr_t leader_ptr;
        extern uintptr_t current_province_ptr;
        extern uintptr_t supplied_from_province_ptr;
        extern uintptr_t movement_order_next_province_ptr;
        extern uintptr_t movement_order_last_current_province_ptr;
        extern uintptr_t movement_order_remaining_provinces_count;
        extern uintptr_t in_game_idler_ptr;
        extern uintptr_t name;
        extern uintptr_t name_length;
        extern uintptr_t dig_in_level;
        extern uintptr_t base_ca_bonus;
        extern uintptr_t higher_oob_unit_ptr;
        extern uintptr_t lower_oob_unit_linked_list_first_ptr;
        extern uintptr_t lower_oob_unit_linked_list_last_ptr;
        extern uintptr_t lower_oob_unit_amount;
        extern uintptr_t oob_level;
    }
    void pushCUnitToStack(lua_State* L, uintptr_t unitPtr);
}