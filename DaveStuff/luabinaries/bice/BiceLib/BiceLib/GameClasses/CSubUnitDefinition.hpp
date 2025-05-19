#pragma once
#include <CasualLibrary.hpp>
#include <lua.hpp>

namespace CSubUnitDefinition {
    namespace Offsets {
        // General
        extern uintptr_t is_buildable;
        extern uintptr_t CUnitAdjuster_ptr;
        extern uintptr_t max_strength;
        extern uintptr_t max_organisation;
        extern uintptr_t morale;
        extern uintptr_t supply_consumption;
        extern uintptr_t fuel_consumption;
        extern uintptr_t officers;
        extern uintptr_t max_speed;
        extern uintptr_t air_defence;
        extern uintptr_t air_attack;
        extern uintptr_t manpower;
        extern uintptr_t sprite;
        // Land units
        extern uintptr_t width;
        extern uintptr_t weight;
        extern uintptr_t softness;
        extern uintptr_t suppression;
        extern uintptr_t soft_attack;
        extern uintptr_t hard_attack;
        extern uintptr_t piercing_attack;
        extern uintptr_t armor;
        extern uintptr_t defensiveness;
        extern uintptr_t toughness;
        // Ships
        extern uintptr_t is_transport;
        extern uintptr_t is_sub;
        extern uintptr_t can_be_pride;
        extern uintptr_t is_capital;
        extern uintptr_t transport_capacity;
        extern uintptr_t range;
        extern uintptr_t firing_distance;
        extern uintptr_t surface_detection;
        extern uintptr_t air_detection;
        extern uintptr_t sub_detection;
        extern uintptr_t visibility;
        extern uintptr_t sea_defence;
        extern uintptr_t convoy_attack;
        extern uintptr_t sea_attack;
        extern uintptr_t sub_attack;
        extern uintptr_t shore_bombardment;
        extern uintptr_t hull;
        extern uintptr_t sub_unit_amount;
        extern uintptr_t positioning;
        extern uintptr_t unk_2e;
        // Air
        extern uintptr_t surface_defence;
        extern uintptr_t strategic_attack;

    }
    void pushCSubUnitDefinitionToStack(lua_State* L, uintptr_t unitPtr);
}