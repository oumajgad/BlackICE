#pragma once
#include <cstdint>

/**
 * CMap - the map itself, and the definitions loaded with it.
 *
 * One instance, `0x2A94` bytes, constructed at `0x883A0` and stored in a global of its
 * own. It is not on the game state and it is not the object
 * CCurrentGameState::Offsets::in_game_screen points at - that one is the CInGameIdler,
 * which holds the *view* of the map. This holds the map's own data.
 *
 * The terrain definitions hang off it, which is how CTerrain::CacheTerrains finds them
 * without scanning: the routine that parses `map/terrain.txt` is slot 5 of this
 * class's vftable, and every CTerrain it builds is pushed into the vector below.
 *
 * `DaveStuff/mem/classes/CMap.py` has the player fields, and they line up: the object
 * is `0x2A94` bytes and the tag sits at `0x2A88`. That script finds the object by
 * scanning for the vftable; the global here is the same object without the scan.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CMap {
    /**@brief where the pointer to the map lives, module relative*/
    constexpr uintptr_t GLOBAL_POINTER = 0x168557C;

    namespace VFTable {
        constexpr uintptr_t CMap = 0x11BE3EC;        // module relative, 6 slots
        constexpr uintptr_t CMapSecondary = 0x11BE408;  // the base at object +0x1C
    }

    namespace Offsets {
        /**
         * **Every terrain the mod defines**, as a vector of CTerrain*: begin and end,
         * four byte elements, so the count is (end - begin) / 4.
         *
         * Filled once while the map loads and not touched afterwards - terrains are
         * definitions, not game objects.
         */
        constexpr uintptr_t terrains_begin = 0x2210;
        constexpr uintptr_t terrains_end = 0x2214;

        /**
         * The player's tag and id, from `DaveStuff/mem/classes/CMap.py`. Not read by
         * BiceLib - CCurrentGameState::Offsets::player_tag is the one that has been
         * checked against a running game - and recorded here so the two are not
         * confused for each other.
         */
        constexpr uintptr_t player_tag = 0x2A88;   // mem, unverified here
        constexpr uintptr_t player_id = 0x2A8C;    // mem, unverified here
    }

    /**
    @brief the live CMap, or 0 when there is none

    Read through Mem::tryRead and checked against this class's vftable, so a global
    that has not been filled in yet answers 0 rather than handing out rubbish.
    */
    uintptr_t current();
}
