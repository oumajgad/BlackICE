#pragma once
#include <cstdint>
#include <string>
#include <utility>
#include <vector>
#include <utils.hpp>
#include <HoiDataStructures.hpp>

namespace CCountry {
    namespace Offsets {
        // Four characters in place, not a Hoi3CString - the id starts right
        // after it. Read it with HDS::readTag.
        constexpr uintptr_t tag = 0x1E4;
        constexpr uintptr_t id = 0x1E8;

        // Both are trees rather than lists, and both start one word past the vftable
        // of the CFlags / CVariables the country holds inline.
        constexpr uintptr_t flags_tree_root_ptr = 0x180 + 0x4;
        constexpr uintptr_t variables_tree_root_ptr = 0x1AC + 0x4;

        /**@brief head of the list of modifiers currently on the country*/
        constexpr uintptr_t active_modifiers_list_first_ptr = 0x648;

        /**@brief head of the country's list of units, at every level rather than the
                  top one - the shape of an order of battle is not in here*/
        constexpr uintptr_t units_linked_list_first_ptr = 0xBAC;

        /**@brief the country's modifier totals, one entry per general modifier*/
        constexpr uintptr_t general_modifiers_array_ptr = 0xDA8;
    }

    /**
     * A node of the flag and variable trees.
     *
     * The name sits at the start of the node, so a node address reads as a string
     * directly; only a variable carries a value with it.
     */
    namespace TreeNodeOffsets {
        constexpr uintptr_t name = 0x0;
        constexpr uintptr_t element = 0x0;
        constexpr uintptr_t parent = 0x8;
        constexpr uintptr_t sibling = 0xC;
        constexpr uintptr_t child = 0x10;
        constexpr uintptr_t variable_value = 0x1C;
    }

    /**
     * What the active modifier list holds. Which class this is has not been
     * established, so it is described by where it is reached from rather than named.
     */
    namespace ActiveModifierOffsets {
        constexpr uintptr_t definition_ptr = 0x8;
        constexpr uintptr_t expiry_tick = 0xC;
        constexpr uintptr_t definition_name = 0x2C; // on the definition, not the entry
    }

    /**
     * The general modifier array: pairs of a value and the definition it belongs to.
     * The count is the number of general modifiers the game defines, which is fixed
     * for a build.
     */
    namespace GeneralModifierOffsets {
        constexpr uintptr_t value = 0x0;
        constexpr uintptr_t definition_ptr = 0x4;
        constexpr uintptr_t definition_name = 0x4; // on the definition, not the entry
        constexpr uintptr_t entry_size = 0x8;
        constexpr int count = 143;
    }


    void traverseFlagsAndVarTreeDepthFirst(std::vector<std::uintptr_t>& res, uintptr_t nodePtr);
    std::vector<std::pair<std::string, std::string>> getActiveEventModifiers(uintptr_t listNodePtr);
    std::vector<std::pair<std::string, int>> getGeneralModifiers(uintptr_t listNodePtr);
    /**@brief the country's flags, by value: the caller owns nothing*/
    std::vector<std::string> getFlags(uintptr_t nodePtr);
    /**@brief the country's non zero variables, by value*/
    std::vector<HDS::CVariable> getVars(uintptr_t nodePtr);

    /**
    @brief every country in the game, read from the game state each time

    The game's own list, so it is always current: a country that comes into existence
    later is in it, and nothing has to be told to refresh. Empty outside a session.
    */
    std::vector<uintptr_t> all();

    /**
    @brief the country with this tag ("GER"), or 0

    Walks the list above and compares the three characters in place, without building
    a string per country, so it is cheap enough to call while drawing.
    */
    uintptr_t findByTag(const std::string& tag);

    /**@brief the country with this id, or 0*/
    uintptr_t findById(int id);
}