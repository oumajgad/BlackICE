#pragma once
#include <cstdint>
#include <lua.hpp>

/**
 * CSubUnitDefinition - what a kind of regiment, brigade or ship is, rather than one
 * the game has built. The unit type's stats live here; CUnit points at one through
 * CUnit::Offsets::CSubUnitDefinitionPtr.
 *
 * One definition covers land, sea and air, so most of the fields below only mean
 * anything for one of the three - which is what the grouping says.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CSubUnitDefinition {
    namespace Offsets {
        // General
        constexpr uintptr_t is_buildable = 0x36;          // boolean
        constexpr uintptr_t CUnitAdjuster_ptr = 0x54;     // Terrain modifiers
        constexpr uintptr_t max_strength = 0xEC;
        constexpr uintptr_t max_organisation = 0xF0;
        constexpr uintptr_t morale = 0xF4;
        constexpr uintptr_t manpower = 0xFC;
        constexpr uintptr_t max_speed = 0x108;
        constexpr uintptr_t supply_consumption = 0x110;
        constexpr uintptr_t fuel_consumption = 0x114;
        constexpr uintptr_t officers = 0x118;
        constexpr uintptr_t air_defence = 0x128;
        constexpr uintptr_t air_attack = 0x140;
        constexpr uintptr_t sub_unit_amount = 0x180;
        constexpr uintptr_t sprite = 0x198;

        // Land units
        constexpr uintptr_t width = 0xE8;
        constexpr uintptr_t weight = 0x10C;
        constexpr uintptr_t defensiveness = 0x11C;
        constexpr uintptr_t toughness = 0x120;
        constexpr uintptr_t softness = 0x124;
        constexpr uintptr_t armor = 0x12C;
        constexpr uintptr_t suppression = 0x130;
        constexpr uintptr_t soft_attack = 0x134;
        constexpr uintptr_t hard_attack = 0x138;
        constexpr uintptr_t piercing_attack = 0x13C;

        // Ships
        constexpr uintptr_t is_capital = 0x2F;    // boolean
        constexpr uintptr_t is_transport = 0x30;  // boolean
        constexpr uintptr_t is_sub = 0x31;        // boolean
        constexpr uintptr_t can_be_pride = 0x39;  // boolean
        constexpr uintptr_t transport_capacity = 0x144;
        constexpr uintptr_t range = 0x148;
        constexpr uintptr_t firing_distance = 0x14C;
        constexpr uintptr_t surface_detection = 0x150;
        constexpr uintptr_t air_detection = 0x154;
        constexpr uintptr_t sub_detection = 0x158;
        constexpr uintptr_t visibility = 0x15C;
        constexpr uintptr_t sea_defence = 0x160;
        constexpr uintptr_t convoy_attack = 0x164;
        constexpr uintptr_t sea_attack = 0x168;
        constexpr uintptr_t sub_attack = 0x16C;
        constexpr uintptr_t shore_bombardment = 0x170;
        constexpr uintptr_t hull = 0x178;
        constexpr uintptr_t positioning = 0x184;
        constexpr uintptr_t unk_2e = 0x2E;

        // Air
        constexpr uintptr_t surface_defence = 0x174;
        constexpr uintptr_t strategic_attack = 0x17C;
    }

    void pushCSubUnitDefinitionToStack(lua_State* L, uintptr_t unitPtr);
}
