#pragma once
#include <cstdint>

/**
 * CActiveMission - a mission a country has been given, from the mission files.
 *
 * Named from `CActiveMission::SaveContents` (`0x5C7BE0`) and `CActiveMission::LoadKey`
 * (`0x5C7A20`) - see CPersistent.hpp.
 *
 * **Read live**: 108 of them in a 1942 game, and **every one is the null mission** - its
 * `type` is a CNullMission whose key is `no_mission` and its `owner` is the no-country tag
 * `---`. So the layout below is named off the loader and the types are confirmed by RTTI,
 * but no mission with anything in it has been seen.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CActiveMission {
    namespace Offsets {
        /**@brief which mission, looked up by name in the mission database and saved as
           `type` by its key. **Read live**: a CNullMission on all 108, key `no_mission`*/
        constexpr uintptr_t type = 0x8;

        /**@brief a CEventScope held by value, saved as `scope` through its own Load and
           Save. **Read live**: a CEventScope by its own RTTI*/
        constexpr uintptr_t scope = 0xC;

        /**@brief set to `this + 0x54` when `parent_scope` is read, so the mission can reach
           the scope below without knowing whether it has one*/
        constexpr uintptr_t parent_scope_ptr = 0x44;

        /**@brief a second CEventScope held by value, saved as `parent_scope`*/
        constexpr uintptr_t parent_scope = 0x54;

        /**@brief a game tick, saved as `start_date` and written as a date*/
        constexpr uintptr_t start_date = 0x9C;

        /**@brief whose mission it is, a CCountryTag, saved as `owner`. **Read live**: `---`
           on all 108, which goes with every one of them being the null mission*/
        constexpr uintptr_t owner = 0xA0;
    }

    namespace VFTable {
        constexpr uintptr_t CActiveMission = 0x11F5D74;   // module relative, RTTI, 6 slots
    }

    namespace GameFunction {
        constexpr uintptr_t SaveContents = 0x5C7BE0;   // slot 2
        constexpr uintptr_t LoadKey = 0x5C7A20;        // slot 4
    }
}
