#pragma once

namespace HDS {
    struct CVariable
    {
        std::string name;
        int32_t value;
    };

    struct LinkedListNodeSingle
    {
        uintptr_t data;
        uintptr_t prev;
        uintptr_t next;
        // + 4 bytes (maybe padding)
    };
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