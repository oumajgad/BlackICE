#pragma once
#include <cstdint>

/**
 * CModifier - a full set of modifier values, one per kind of modifier the game knows.
 *
 * Held by value: **a country's global modifier** is one at CCountry::Offsets::global_modifier,
 * and **a province's local modifier** one at CMapProvince::Offsets::modifier. Laws,
 * ministers, ideologies, traits and the rest derive from it (RTTI).
 *
 * The values are not in the object. It holds a pointer to an array of Entry, one per
 * ModifierType and indexed by it, which the game's own `CModifier::GetValue`
 * (`0x179E0`) reads and nothing more: `[this + 0x18][type * 8]`. So a value is three
 * steps - the modifier's offset in its owner, the pointer here, and the entry.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CModifier {
    namespace VFTable {
        constexpr uintptr_t CModifier = 0x11BC4F8;           // module relative, RTTI, 13 slots
        constexpr uintptr_t CProvinceModifier = 0x11BC530;   // what a province's carries
    }

    /**
     * The constructor, taking the object on the stack: sets the vftable and zeroes the
     * two triples at +0x8 and +0x18. The country's and the province's constructors both
     * call it on their embedded modifier.
     */
    constexpr uintptr_t Construct = 0x593F0;

    /**
     * `0x2C` bytes: the country's constructor builds its modifier at +0xD90 and the next
     * object at +0xDBC. A CProvinceModifier adds the province pointer, `0x30`, and the
     * province's constructor carries on at +0x12C, just past it.
     */
    constexpr uintptr_t SIZE = 0x2C;
    constexpr uintptr_t PROVINCE_MODIFIER_SIZE = 0x30;

    namespace Offsets {
        /**
         * **The values**, a pointer to an array of Entry indexed by ModifierType. The
         * constructor zeroes it together with the two words after it, which are
         * presumably its end and capacity; that has not been checked.
         */
        constexpr uintptr_t values = 0x18;

        /**
         * On a CProvinceModifier only: the province it belongs to. The province's
         * constructor stores itself here straight after building the modifier.
         */
        constexpr uintptr_t province = 0x2C;
    }

    /**@brief one element of the values array*/
    namespace Entry {
        /**@brief a CFixedPoint, thousandths in an int: 1000 is a value of 1*/
        constexpr uintptr_t value = 0x0;

        /**@brief the CModifierDefinition saying which modifier this is*/
        constexpr uintptr_t definition_ptr = 0x4;

        constexpr uintptr_t SIZE = 0x8;
    }

    /**
     * How many entries the array holds, and so how many kinds of modifier this build
     * has. From `DaveStuff/mem`, not checked against the array's end.
     */
    constexpr int COUNT = 143;

    /**
     * **Which modifier an entry is**, by the game's own numbering: the values its Lua API
     * registers on CModifier as `ModifierType`, each named there `_MODIFIER_LOCAL_IC_`
     * and so on. Only the ones registered to Lua are here - 57 is not registered, nor is
     * anything from 83 up.
     */
    enum ModifierType : int {
        MINIMUM_REVOLT_RISK = 0,
        LOCAL_REVOLT_RISK = 1,
        GLOBAL_REVOLT_RISK = 2,
        LOCAL_MANPOWER = 3,
        GLOBAL_MANPOWER = 4,
        LOCAL_MANPOWER_MODIFIER = 5,
        GLOBAL_MANPOWER_MODIFIER = 6,
        ATTRITION = 7,
        WAR_EXHAUSTION = 8,
        MAX_WAR_EXHAUSTION = 9,
        FORT_LEVEL = 10,
        COASTAL_FORT_LEVEL = 11,
        INFRASTRUCTURE = 12,
        LOCAL_INFRASTRUCTURE = 13,
        GLOBAL_INFRASTRUCTURE = 14,
        IC = 15,
        LOCAL_IC = 16,
        GLOBAL_IC = 17,
        LOCAL_CRUDE_OIL = 18,
        GLOBAL_CRUDE_OIL = 19,
        LOCAL_ENERGY = 20,
        GLOBAL_ENERGY = 21,
        LOCAL_METAL = 22,
        GLOBAL_METAL = 23,
        LOCAL_RARE_MATERIALS = 24,
        GLOBAL_RARE_MATERIALS = 25,
        LOCAL_SUPPLIES = 26,
        GLOBAL_SUPPLIES = 27,
        LOCAL_FUEL = 28,
        GLOBAL_FUEL = 29,
        LOCAL_MONEY = 30,
        GLOBAL_MONEY = 31,
        LOCAL_LEADERSHIP = 32,
        GLOBAL_LEADERSHIP = 33,
        LOCAL_LEADERSHIP_MODIFIER = 34,
        GLOBAL_LEADERSHIP_MODIFIER = 35,
        DRIFT_SPEED = 36,
        SUSEPTIBILITY = 37,
        INCORPORATE_COST = 38,
        TERRITORIAL_PRIDE = 39,
        WAR_CONSUMER_GOODS_DEMAND = 40,
        PEACE_CONSUMER_GOODS_DEMAND = 41,
        ESPIONAGE_BONUS = 42,
        DISSENT = 43,
        NATIONAL_UNITY = 44,
        NAVAL_CAPACITY = 45,
        AIR_CAPACITY = 46,
        ALIGN_TOWARDS = 47,
        RADAR_LEVEL = 48,
        SUPPLY_CONSUMPTION = 49,
        PEACETIME_MANPOWER_ROTATION = 50,
        UNIT_RECRUITMENT_TIME = 51,
        UNIT_START_EXPERIENCE = 52,
        UNIT_REPAIR = 53,
        COUNTER_INTELLIGENCE = 54,
        COUNTER_ESPIONAGE = 55,
        THREAT_IMPACT = 56,
        PEACE_OFFMAP_INTEL = 58,
        OFFMAP_LAND_INTEL = 59,
        OFFMAP_NAVAL_INTEL = 60,
        OFFMAP_INDUSTRY_INTEL = 61,
        OFFMAP_POLITICAL_INTEL = 62,
        COMBAT_MOVEMENT_SPEED = 63,
        ATTACK_REINFORCE_CHANCE = 64,
        DEFEND_REINFORCE_CHANCE = 65,
        COMBAT_WIDTH = 66,
        ORG_REGAIN = 67,
        NATIONAL_UNITY_EFFECT = 68,
        RULING_PARTY_SUPPORT = 69,
        LAND_ORGANISATION = 70,
        AIR_ORGANISATION = 71,
        NAVAL_ORGANISATION = 72,
        RESEARCH_EFFICIENCY = 73,
        INDUSTRIAL_EFFICIENCY = 74,
        LOCAL_ANTI_AIR = 75,
        LOCAL_PARTISAN_SUPPORT = 76,
        RESERVES_PENALTY_SIZE = 77,
        NEUTRALITY_CHANGE = 78,
        PARTISAN_EFFICENCY = 79,
        NAVAL_BASE_EFFICIENCY = 80,
        SUPPLY_THROUGHPUT = 81,
        OFFICER_RECRUITMENT = 82,
    };

    /**@brief where the entry for \p type sits in the values array*/
    constexpr uintptr_t entryOffset(int type) {
        return static_cast<uintptr_t>(type) * Entry::SIZE;
    }
}

/**
 * CModifierDefinition - what one kind of modifier is: the thing an Entry points at.
 */
namespace CModifierDefinition {
    namespace VFTable {
        constexpr uintptr_t CModifierDefinition = 0x11BC4E4;   // module relative, RTTI
    }

    namespace Offsets {
        /**@brief its key, a Hoi3CString, "local_ic"*/
        constexpr uintptr_t name = 0x4;
    }
}
