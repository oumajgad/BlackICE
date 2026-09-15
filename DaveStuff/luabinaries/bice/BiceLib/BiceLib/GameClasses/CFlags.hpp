#pragma once
#include <cstdint>

/**
 * CFlags and CVariables - a country's flags and variables, each a tree keyed by name.
 *
 * Both are held by value (CCountry::Offsets::flags and ::variables; the game's
 * `GetFlags` and `GetVariables` answer exactly those addresses), and both have the same
 * shape, because both are a CTernary - a search tree over the characters of the names -
 * with CPersistent as a second base at +0x24 (RTTI). So one set of offsets reads either.
 *
 * Reading one is three layers: the tree's root in the object, the nodes, and the element
 * a node holds - a CFlag or CVariable, which is where the name is.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CTernary {
    namespace Offsets {
        /**@brief the root node; the CTernary's vftable is at +0x0*/
        constexpr uintptr_t root = 0x4;
    }

    /**
     * One node. The names are the ones BiceLib reads them by, which walk every element
     * the game shows; what the tree means by each link has not been worked out.
     */
    namespace NodeOffsets {
        /**@brief the CFlag or CVariable ending here, or 0 where no name ends*/
        constexpr uintptr_t element = 0x0;

        /**@brief the character this node stands for, per DaveStuff/mem; not read here*/
        constexpr uintptr_t character = 0x4;

        /**@brief per DaveStuff/mem, where a name added later hangs rather than changing
                  the root*/
        constexpr uintptr_t parent = 0x8;
        constexpr uintptr_t sibling = 0xC;
        constexpr uintptr_t child = 0x10;
    }
}

namespace CFlags {
    namespace VFTable {
        constexpr uintptr_t CFlags = 0x11BB468;   // module relative, RTTI; the CPersistent one is at +0x24
    }

    /**@brief a CFlag, what a node's element points at*/
    namespace ElementOffsets {
        constexpr uintptr_t name = 0x0;           // a Hoi3CString

        /**@brief a byte, set or not: all the game's `CFlags::IsFlagSet` (`0x4D620`) reads
                  of the element its lookup finds*/
        constexpr uintptr_t is_set = 0x1C;
    }
}

namespace CVariables {
    namespace VFTable {
        constexpr uintptr_t CVariables = 0x11BD700;   // module relative, RTTI
    }

    /**@brief a CVariable, what a node's element points at*/
    namespace ElementOffsets {
        constexpr uintptr_t name = 0x0;           // a Hoi3CString
        /**@brief a CFixedPoint: what the game's `CVariables::GetVariable` (`0x76F60`)
                  answers from the element its lookup finds*/
        constexpr uintptr_t value = 0x1C;
    }
}
