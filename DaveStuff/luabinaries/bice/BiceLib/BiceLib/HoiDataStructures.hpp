#pragma once

#include <cstdint>
#include <string>
#include <vector>

/**
 * The shapes the game's compiler produced - its strings and its lists - and the safe
 * way to read them.
 *
 * The structs here describe the layout. Prefer the two functions at the bottom over
 * dereferencing those structs: they go through Mem::tryRead, so a pointer that turns
 * out not to be what we assumed gives back nothing instead of taking the process down,
 * and readString also converts out of the game's Windows-1252 into the UTF-8 that
 * ImGui and Lua expect.
 */
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

    /**
    @brief reads a Hoi3CString at \p address, or "" if it is not one

    Sixteen bytes that are either the characters themselves or a pointer to them, then
    the length; past fifteen characters it is a pointer.

    Converted to UTF-8 on the way out, because the game's text is Windows-1252 and both
    ImGui and Lua draw anything else as a fallback glyph - which turns every German
    name into a row of question marks. This is the boundary, so it happens here once
    rather than at each place a name is used.
    */
    [[nodiscard]] std::string readString(uintptr_t address);

    /**
    @brief reads a fixed size character buffer, stopping at the first NUL

    Not everything the game holds as text is a Hoi3CString. A country tag is four
    bytes in place, with the next field hard against it - readString on one of those
    reads whatever follows as a length and hands back nothing at all.

    The rule of thumb: if a name field has a _length field sixteen bytes after it, it
    is a Hoi3CString; if the next field starts within a few bytes, it is one of these.
    */
    [[nodiscard]] std::string readChars(uintptr_t address, size_t size);

    /**@brief a country tag ("GER"), which is four bytes wherever the game keeps one*/
    [[nodiscard]] std::string readTag(uintptr_t address);

    /**
    @brief follows the list whose head pointer sits at \p listField

    @returns what each node held, which is usually a pointer to the thing in the list

    Guarded two ways, because a list read out of a structure that is not what we
    assumed is not a list: it stops at a node it has already seen, and after
    \p maxSteps nodes whatever happens.
    */
    [[nodiscard]] std::vector<uintptr_t> walkList(uintptr_t listField, int maxSteps = 25000);
}