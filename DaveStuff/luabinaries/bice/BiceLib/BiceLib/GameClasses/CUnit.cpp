#include <GameClasses/CUnit.hpp>
#include <utils.hpp>

namespace CUnit {
    namespace Offsets {
        uintptr_t is_selected = 0x4;
        uintptr_t type = 0x10;
        uintptr_t id = 0x14;
        uintptr_t regiments_linked_list_first_ptr = 0x38;
        uintptr_t regiments_linked_list_last_ptr = 0x3C;
        uintptr_t regiments_amount = 0x40;
        uintptr_t upgrade_prio = 0xA4;          // boolean!
        uintptr_t upgrade_active = 0xA5;        // boolean!
        uintptr_t reinforcements_active = 0xA6; // boolean!
        uintptr_t order_ptr = 0xB0;
        uintptr_t CSubUnitDefinitionPtr = 0xC8;
        uintptr_t combat_cooldown = 0xD4;
        uintptr_t supply_received_percentage = 0xFC;
        uintptr_t fuel_received_percentage = 0x100;
        uintptr_t owner_tag = 0x124;
        uintptr_t owner_id = 0x128;
        uintptr_t leader_ptr = 0x12C;
        uintptr_t current_province_ptr = 0x130;
        uintptr_t supplied_from_province_ptr = 0x134;
        uintptr_t movement_order_next_province_ptr = 0x138;
        uintptr_t movement_order_last_current_province_ptr = 0x13C;
        uintptr_t movement_order_remaining_provinces_count = 0x140;
        uintptr_t in_game_idler_ptr = 0x160;
        uintptr_t name = 0x16C;
        uintptr_t name_length = 0x17C;
        uintptr_t dig_in_level = 0x1C8;
        uintptr_t base_ca_bonus = 0x1CC;
        uintptr_t higher_oob_unit_ptr = 0x1E0;
        uintptr_t lower_oob_unit_linked_list_first_ptr = 0x1E4;
        uintptr_t lower_oob_unit_linked_list_last_ptr = 0x1E8;
        uintptr_t lower_oob_unit_amount = 0x1EC;
        uintptr_t oob_level = 0x1F4;
    }

    void pushCUnitToStack(lua_State* L, uintptr_t unitPtr) {
        DEBUG_OUT(printf("unitPtr: %#010x\n", unitPtr));
        DEBUG_OUT(printf("nameOffset: %#010x\n", unitPtr + CUnit::Offsets::name));

        auto name = utils::getCString((DWORD*) (unitPtr + CUnit::Offsets::name));
        lua_pushstring(L, "name");
        lua_pushstring(L, name);
        lua_settable(L, -3);
	    return;
    }
}