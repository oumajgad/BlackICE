#pragma once
#include <cstdint>
#include <string>
#include <unordered_map>
#include <lua.hpp>

namespace CLeader {
    namespace Offsets {
        constexpr uintptr_t id = 0xC;
        constexpr uintptr_t trait_ll_start = 0x30;
        constexpr uintptr_t trait_ll_end = 0x34;
        constexpr uintptr_t number_of_traits = 0x38;
        constexpr uintptr_t unit_ptr = 0x40;
        // constexpr uintptr_t country_tag = 0x44;
        // constexpr uintptr_t country_id = 0x48;
        constexpr uintptr_t name = 0x4C;
        // constexpr uintptr_t type = 0x68;
        constexpr uintptr_t rank = 0x6C;
        constexpr uintptr_t skill = 0x70;
        constexpr uintptr_t max_skill = 0x74;
        constexpr uintptr_t experience = 0x78;
        constexpr uintptr_t experience_2 = 0x7C;
        // constexpr uintptr_t loyalty = 0x80;
        // constexpr uintptr_t CLeaderHistoryOffset = 0x84;
    }

    struct CLeader
    {
        uintptr_t _address;
        unsigned int id;
        uintptr_t trait_ll_start;
        uintptr_t trait_ll_end;
        int number_of_traits;
        uintptr_t unit_ptr;
        // uintptr_t country_tag;
        // int country_id;
        // By value: the game's copy is Windows-1252 and lives at the game's pleasure,
        // so it is converted and copied out rather than pointed at.
        std::string name;
        // int type;
        int rank;
        int skill;
        int max_skill;
        int experience;
        // int experience_2;
        // int loyalty;
        // uintptr_t CLeaderHistoryOffset;
    };

    extern std::unordered_map<unsigned int, uintptr_t>* leaderCache;

    CLeader Make(uintptr_t addr);
    void CacheLeaders();
    CLeader GetLeaderById(unsigned int id);
    void PushCLeaderToStack(lua_State* L, CLeader leader);
}