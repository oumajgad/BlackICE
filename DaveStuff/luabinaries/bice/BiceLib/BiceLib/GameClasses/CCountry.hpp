#pragma once
#include <cstdint>
#include <string>
#include <utility>
#include <vector>
#include <utils.hpp>
#include <HoiDataStructures.hpp>

/**
 * Several of the country's fields are objects held by value - its tags, its lists, its
 * flags, variables, goods pools and global modifier. For those the offset here is where
 * the object starts, and what is inside it is a second offset from that object's own
 * header: the country's id is `tag + CCountryTag::Offsets::id`.
 */
namespace CCountry {
    namespace Offsets {
        /**
         * **The country's tag and id**, a CCountryTag. Read the letters with
         * HDS::readTag and the id at `tag + CCountryTag::Offsets::id`.
         */
        constexpr uintptr_t tag = 0x1E4;

        /**
         * A second CCountryTag. It is the one the game's own `GetCountryTag` answers. Why
         * the country holds two has not been established.
         */
        constexpr uintptr_t country_tag = 0xCA4;

        /**
         * A bool, the game's `IsGovernmentInExile`. While it is set, the country's
         * stockpile is the pool it holds at `+0x9F8` rather than its capital's - see
         * capital_province_id.
         */
        constexpr uintptr_t is_government_in_exile = 0x95;

        /**@brief the country's industrial capacity now and at most, the game's
                  `GetTotalIC` and `GetMaxIC`; the offmap IC fix writes the first*/
        constexpr uintptr_t total_ic = 0x604;
        constexpr uintptr_t max_ic = 0x60C;

        /**
         * **The country's flags and variables**, a CFlags and a CVariables held by value -
         * the addresses the game's `GetFlags` and `GetVariables` answer. Each is a tree
         * whose root is at CTernary::Offsets::root; see CFlags.hpp.
         */
        constexpr uintptr_t flags = 0x180;
        constexpr uintptr_t variables = 0x1AC;

        /**
         * **The country's convoys**, a list (HDS::ListOffsets) whose nodes each hold a
         * CConvoy*; HDS::walkList reads it. Every convoy is in exactly one list, its
         * owner's. The game's own `GetConvoys` answers it, as a `CList<CConvoy*>`.
         */
        constexpr uintptr_t convoys = 0xA0;

        /**@brief the modifiers currently on the country, a list (HDS::ListOffsets);
                  the entries are ActiveModifierOffsets*/
        constexpr uintptr_t active_modifiers = 0x648;

        /**@brief the country's units, a CUnitList - a list of CUnit* at every level
                  rather than the top one, so the shape of an order of battle is not in
                  here. The address the game's `GetUnits` answers.*/
        constexpr uintptr_t units = 0xBAC;

        /**
         * **The country's modifier totals**, a CModifier held by value - the address the
         * game's `GetGlobalModifier` answers. One value per ModifierType, behind the
         * pointer at CModifier::Offsets::values.
         */
        constexpr uintptr_t global_modifier = 0xD90;

        /**
         * **The country's leaders**, a list (HDS::ListOffsets), which is what
         * HDS::walkList reads.
         *
         * Every leader in the game belongs to exactly one country's list, so walking
         * all of them is how CLeader::CacheLeaders finds them. Confirmed live: the
         * count field agrees with the walk, and the walk over all 108 countries
         * reaches 24,137 of the 24,138 objects a vftable scan turns up. The one it
         * leaves out has the null tag `---` and sits in the file parser's memory, so
         * it is a template rather than a leader anybody has.
         */
        constexpr uintptr_t leaders = 0xE10;

        /**
         * **The capital, as a province id** - index it into the game state's province
         * vector. The game's own "capital province" (`0x2F100`) reads this, and so does
         * its `GetActingCapital` - which by that name is where the government sits now,
         * rather than the capital it started with; not checked.
         *
         * The country's stockpile is the capital's pool: `CCountry:GetPool()`
         * (`0xF4DE0`) answers `&capital->pool` (CMapProvince::Offsets::pool), unless the
         * country is a government in exile (is_government_in_exile), when it answers the
         * pool held here at `+0x9F8`.
         */
        constexpr uintptr_t capital_province_id = 0xE24;

        /**
         * **The country's goods pools**, each a CGoodsPool. It holds 23, `+0x74C` to
         * `+0xA64`; these are the ones the game's own accessors name.
         *
         * `total_produced` is a day's resource income: what arrives in the capital's pool
         * each midnight, before anything is spent. It is what the connected provinces
         * yield, with modifiers, plus what the country's resource convoys carried in
         * from networks cut off from the capital (CConvoy::Offsets::daily) - which is
         * presumably the split `home_produced` and `convoyed_in` record; only
         * `total_produced` has been checked against a running game.
         *
         * The `sans_allied_supply` pair presumably leave out what went to or came from
         * allies as supply help; that is read from the names, not from the game.
         */
        constexpr uintptr_t total_produced = 0x74C;
        constexpr uintptr_t home_produced = 0x770;
        constexpr uintptr_t convoyed_in = 0x794;
        constexpr uintptr_t convoyed_out = 0x7B8;
        constexpr uintptr_t traded_away = 0x7DC;
        constexpr uintptr_t traded_away_sans_allied_supply = 0x800;
        constexpr uintptr_t traded_for = 0x86C;
        constexpr uintptr_t traded_for_sans_allied_supply = 0x890;
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


    /**@brief every element in the tree under \p nodePtr, a CTernary node*/
    void traverseFlagsAndVarTreeDepthFirst(std::vector<std::uintptr_t>& res, uintptr_t nodePtr);
    std::vector<std::pair<std::string, std::string>> getActiveEventModifiers(uintptr_t country);
    /**@brief every value of the country's global modifier, by the definition's name*/
    std::vector<std::pair<std::string, int>> getGeneralModifiers(uintptr_t country);
    /**@brief the country's flags, by value: the caller owns nothing*/
    std::vector<std::string> getFlags(uintptr_t country);
    /**@brief the country's non zero variables, by value*/
    std::vector<HDS::CVariable> getVars(uintptr_t country);

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