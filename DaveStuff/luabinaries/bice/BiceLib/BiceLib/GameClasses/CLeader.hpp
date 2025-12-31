#pragma once
#include <CasualLibrary.hpp>
#include <lua.hpp>

namespace CLeader {
    namespace Offsets {
        extern uintptr_t id;
        extern uintptr_t trait_ll_start;
        extern uintptr_t trait_ll_end;
        extern uintptr_t number_of_traits;
        extern uintptr_t unit_ptr;
        // extern uintptr_t country_tag;
        // extern uintptr_t country_id;
        extern uintptr_t name;
        // extern uintptr_t type;
        extern uintptr_t rank;
        extern uintptr_t skill;
        extern uintptr_t max_skill;
        extern uintptr_t experience;
        // extern uintptr_t experience_2;
        // extern uintptr_t loyalty;
        // extern uintptr_t CLeaderHistoryOffset;
    }

    struct CLeader
    {
        unsigned int id;
        uintptr_t trait_ll_start;
        uintptr_t trait_ll_end;
        int number_of_traits;
        uintptr_t unit_ptr;
        // uintptr_t country_tag;
        // int country_id;
        char* name;
        // int type;
        int rank;
        int skill;
        int max_skill;
        int experience;
        // int experience_2;
        // int loyalty;
        // uintptr_t CLeaderHistoryOffset;
    };

    CLeader Make(uintptr_t addr);
    CLeader GetLeaderById(Memory::External& external, unsigned int id);
    void PushCLeaderToStack(lua_State* L, CLeader leader);
}