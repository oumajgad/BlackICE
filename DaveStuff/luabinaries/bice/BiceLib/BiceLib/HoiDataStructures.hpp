#pragma once

#include <cstdint>
#include <string>

namespace HDS {
    struct CVariable
    {
        std::string name;
        int32_t value;
    };

    struct LinkedListNodeSingle
    {
        uintptr_t data;
        LinkedListNodeSingle* prev;
        LinkedListNodeSingle* next;
        // + 4 bytes (maybe padding)
    };

    /**@brief the same node as offsets, for walking a list without dereferencing it*/
    namespace NodeOffsets {
        constexpr uintptr_t data = 0x0;
        constexpr uintptr_t prev = 0x4;
        constexpr uintptr_t next = 0x8;
    }
    struct Hoi3CString
    {
        char stringData [16];
        int32_t length;
        int32_t maxLength = 0xF;
    };

    struct CUnitAdjuster
    {
        int vftable;
        int pad_1;
        int attack;
        int defence;
        int movement;
        int attrition;
    };
}