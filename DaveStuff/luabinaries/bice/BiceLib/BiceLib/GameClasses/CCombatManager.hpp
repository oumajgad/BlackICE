#pragma once
#include <cstdint>

/**
 * CCombatManager - the combats being fought, and the history of the ones that ended.
 *
 * There is one, held by value in the game state at
 * CCurrentGameState::Offsets::combat_manager, and **CCombatHistory is held by value
 * inside it** at Offsets::history. The game state's constructor (`0x27D070`) writes
 * both vftables, each at its own address. The history is reached as two offsets added:
 * the manager's in the game state, then the history's in the manager.
 *
 * BiceLib keeps its own record of combats rather than reading these (GameState/CombatLog),
 * because the game's history entries carry no casualties and are pruned after a few days.
 * How the layout was found is in reversing/FINDINGS-combat.md.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CCombatManager {
    namespace VFTable {
        constexpr uintptr_t CCombatManager = 0x11B68F8;   // module relative, RTTI
    }

    namespace Offsets {
        /**@brief the combats going on now, an HDS::ListOffsets list of CCombat* */
        constexpr uintptr_t combats = 0x8;

        /**@brief the CCombatHistory, held by value*/
        constexpr uintptr_t history = 0x18;
    }
}

namespace CCombatHistory {
    namespace VFTable {
        constexpr uintptr_t CCombatHistory = 0x11B68DC;   // module relative, RTTI
    }

    namespace Offsets {
        /**
         * **The combats that ended.** First, last and count like a list, but the
         * first and last are CCombatHistoryEntry themselves, not nodes: the entries are
         * linked through their own EntryOffsets::previous and ::next, so HDS::walkList
         * does not read it.
         */
        constexpr uintptr_t entries_first = 0x8;
        constexpr uintptr_t entries_last = 0xC;
        constexpr uintptr_t entries_count = 0x10;
    }

    /**@brief a CCombatHistoryEntry, as its constructor (`0x2F340`) fills it*/
    namespace EntryOffsets {
        constexpr uintptr_t tick = 0x8;          // when the combat ended
        constexpr uintptr_t kind = 0xC;          // CCombat::Slots::KIND
        constexpr uintptr_t attacker = 0x10;     // a CCountryTag
        constexpr uintptr_t defender = 0x18;     // a CCountryTag
        constexpr uintptr_t province_id = 0x24;
        constexpr uintptr_t previous = 0x28;
        constexpr uintptr_t next = 0x2C;
    }
}
