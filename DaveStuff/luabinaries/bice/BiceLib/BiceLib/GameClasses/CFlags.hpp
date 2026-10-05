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
     * One node of a **ternary search tree**, which is what the three links mean.
     *
     * This block used to say "what the tree means by each link has not been worked out" and
     * carried the names `parent`, `sibling` and `child` from an external note. Those were
     * wrong, and wrong in a way that did not show: the walk BiceLib does visits every element
     * whichever way the links are labelled, so nothing misbehaved. Settled 2026-10-05 off
     * `TernarySearchTreeFind` (rva `0x67E030`) and `TernarySearchTreeInsert` (rva `0x4DA70`),
     * which compare the key byte and then take `+0xC` when it sorts above and `+0x8` when
     * below, and corroborated by `CVariables::SaveSubtree` (rva `0x77000`) walking
     * low -> element -> equal -> high, which is why every `variables={}` block in a savegame
     * comes out alphabetical.
     *
     * `project.json`'s own entry for `TernarySearchTreeFind` had the layout right all along -
     * the function half of the fact base disagreed with the struct half, and the function was
     * the one to believe. See `reversing/findings/FINDINGS-negatives.md`.
     *
     * **Keys are case-insensitive**: both the find and the insert fold the character through
     * `tolower`, and only the insert stores the folded form. So a flag or variable named
     * `BaseIC` and one named `baseic` are the same one.
     */
    namespace NodeOffsets {
        /**@brief the CFlag or CVariable whose name ends here, or 0 where no name ends*/
        constexpr uintptr_t element = 0x0;

        /**@brief the character this node stands for, folded to lower case*/
        constexpr uintptr_t character = 0x4;

        /**@brief keys whose character at this position sorts **below** this node's*/
        constexpr uintptr_t low = 0x8;

        /**@brief keys whose character at this position sorts **above** this node's*/
        constexpr uintptr_t high = 0xC;

        /**@brief the next character of a key that matched here - the only link that
                  advances the key*/
        constexpr uintptr_t equal = 0x10;
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
