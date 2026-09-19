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

        /**
         * **The leadership distribution** - the four sliders leadership is split between.
         * A vector: this is its first element, +0x5E8 its end and +0x5EC its capacity, and
         * it always holds four `CDistributionSetting*` in this order, each object's vftable
         * saying which it is (**read live**):
         *
         *     [0] CDistributeNCO          officers
         *     [1] CDistributeDiplomacy
         *     [2] CDistributeEspionage
         *     [3] CDistributeResearch
         *
         * The game's own `CCountry::GetLeadershipDistributionAt(i)` (`0xE06C0`) is nothing
         * but `[this + 0x5E4][i]`, which is where the name comes from.
         */
        constexpr uintptr_t leadership_distribution = 0x5E4;
        constexpr uintptr_t leadership_distribution_end = 0x5E8;
        constexpr uintptr_t leadership_distribution_capacity = 0x5EC;

        /**
         * **The industrial capacity distribution** - the six production sliders, the same
         * shape as the leadership one above: first element here, end at +0x5F8, capacity
         * at +0x5FC. Six `CDistributionSetting*` in the order of the game's own
         * `ProductionCategory` enum, which it registers to Lua on `CDistributionSetting`
         * (**named**; the order is **read live** off the six objects' vftables):
         *
         *     [0] CDistributeLendLease      _PRODUCTION_LENDLEASE_
         *     [1] CDistributeConsumerGoods  _PRODUCTION_CONSUMER_
         *     [2] CDistributeProduction     _PRODUCTION_PRODUCTION_
         *     [3] CDistributeSupply         _PRODUCTION_SUPPLY_
         *     [4] CDistributeReinforcement  _PRODUCTION_REINFORCEMENT_
         *     [5] CDistributeUpgrade        _PRODUCTION_UPGRADE_
         */
        constexpr uintptr_t production_distribution = 0x5F4;
        constexpr uintptr_t production_distribution_end = 0x5F8;
        constexpr uintptr_t production_distribution_capacity = 0x5FC;

        /**@brief the country's industrial capacity now and at most, the game's
                  `GetTotalIC` and `GetMaxIC`; the offmap IC fix writes the first*/
        constexpr uintptr_t total_ic = 0x604;

        /**
         * **The country's own level in each technology category**, a pointer to ints in
         * thousandths indexed by CTechnologyCategory::Offsets::index - the theories and
         * practicals, and holding whole and half levels (**read live**, against the game's own
         * category keys).
         */
        /**
         * **What the country has finished and not yet placed**, a linked list: head here,
         * tail at `+0x68C` and the count at `+0x690`. It holds `CUnitDeployment` and, for a
         * building whose definition has `capital` set and whose construction named no
         * province, `CBuildingDeployment` (`0x82A80` makes one and `0xF56C0` appends it).
         * **Read live**: in a 1942 game the USA had 50 entries, all CUnitDeployment.
         */
        constexpr uintptr_t deployments = 0x688;
        constexpr uintptr_t deployments_last = 0x68C;
        constexpr uintptr_t deployments_count = 0x690;

        constexpr uintptr_t own_ability = 0x698;

        /**
         * **Who shares each category with this country** - the game's technology sharing,
         * a CCountryTag per category beside the levels.
         *
         * **The tag is on the receiver, not the giver**, one slot per category, so a
         * country can be shared each category by at most one other (**read live**).
         *
         * What it buys is the higher of the two levels: the game's own
         * `CCountry::GetAbility(CTechnologyCategory*)` (`0xE0290`) answers this country's
         * own level unless a tag is set here and that country's is higher. The build cost
         * discount (`0xE1AC0`) does the same lookup inline, so sharing cuts what the
         * receiver pays for buildings and units as well as helping its research.
         */
        constexpr uintptr_t ability_shared_from = 0x6A8;

        /**
         * **What reinforcement and upgrading currently cost**, which the spare IC
         * calculation (`0xF4B90`) subtracts from what those two sliders allocate
         * (**read**). Nothing else about them has been checked.
         */
        constexpr uintptr_t reinforcement_cost = 0xA98;
        constexpr uintptr_t upgrade_cost = 0xAA4;
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
         * **The two capitals, each a province id** - index either into the game state's
         * province vector.
         *
         * `+0xE20` is the capital and `+0xE24` where the government sits now. That was
         * recorded the other way round until 2026-09-19, when the pair of accessors
         * settled it: `CCountry::GetCapitalLocation` (`0x17AF0`) and
         * `GetActingCapitalLocation` (`0x2F100`) are the same function but for the offset
         * they read, and `GetActingCapital` (`0x6C370`) answers `+0xE24` (**read**).
         *
         * **The Lua API is a trap here**: it registers `GetActingCapital` under the name
         * `GetCapital`, so a script asking a country for its capital is told where the
         * government sits.
         *
         * The stockpile follows the **acting** capital: `CCountry:GetPool()` (`0xF4DE0`)
         * calls `GetActingCapitalLocation` and adds the province's pool offset, unless the
         * country is a government in exile (is_government_in_exile), when it answers the
         * pool held here at `+0x9F8`.
         */
        constexpr uintptr_t capital_province_id = 0xE20;
        constexpr uintptr_t acting_capital_province_id = 0xE24;

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

        /**
         * **Three more named by the save**, and the rest by what the daily figures do with
         * them. Which good a pool holds is `pool + CGoodsPool::Goods::supplies +
         * category * 4`, the category being the game's GoodsCategory.
         *
         * The country's writer (`0xCFF20` and around) saves ten of the 23, each under a key
         * it names by an id - `usage` is `0x5A6`, `to` is `0x350`, `back` is `0x397`. The
         * ids come from a table `reversing/saveTokens.py` rebuilds; the keys it gives for
         * the pools BiceLib had already named all agree, which is what makes the three new
         * ones worth trusting. The other thirteen are **not saved at all**, so nothing names them. What is known
         * of each is below, and **four of them are never used in this build**: `+0x824`,
         * `+0x848`, `+0x944` and `+0xA64` hold nothing, and the first three are written
         * nowhere but the constructor and the two daily resets (`0xD34xx` and `0x1033xx`,
         * which write a constant over every pool). The terms the daily figures spend on
         * `+0x824`, `+0x848` and `+0xA64` therefore contribute nothing (**read live**).
         *
         * **`+0xA1C` and `+0xA40` are the unit supply draw** (**read**, `0x1BB950`): when a
         * unit takes supply from a country, `+0xA1C` is credited if the unit stands in that
         * country's own acting capital province, and `+0xA40` on the branch where the
         * supplier is the unit's own country - the other branch credits `traded_away` and
         * `traded_for` instead, which is where allied supply is recorded. `+0xA1C` holds
         * supplies alone, `+0xA40` supplies and fuel.
         *
         * Three more are told apart by the goods they move in, each moving in some and never
         * in others (**read live**):
         *
         * `+0x8D8` and `+0x8B4` are the **conversion pair**, what it consumes and what it
         * makes: crude oil in and fuel out, and energy in and oil out where a country makes
         * synthetic. The rate is per country, which is the FUEL_CONVERSION modifier (92) at
         * work, and it fits their part in the daily figures - the input an expense, the
         * output an income.
         *
         * `+0x968` is **what the country's industry needs**: metal, energy and rares in
         * 1 : 2 : 0.5 without exception, which `usage` tracks to within a fraction of a
         * percent.
         *
         * `+0x920` and `+0x8FC` are **the two sides of the puppet tribute**, where a subject
         * hands its overlord everything it holds over a threshold. The subject's share is
         * `+0x920`, held as a **negative**; the overlord's is `+0x8FC`, and the `overlord`
         * tag at `+0xF38` on the subject names who receives it. Only subjects hold anything
         * in the first and only overlords in the second, and the two match good for good.
         * It is **not** `traded_away` and `traded_for`, which are far larger and cover
         * ordinary trade.
         *
         * **One case does not balance**: a subject's tribute can leave its overlord's
         * `+0x8FC` empty. Whether the goods are dropped, credited elsewhere, or only counted
         * on arrival has not been established.
         */
        constexpr uintptr_t usage = 0x98C;          // saved as "usage"; an expense
        constexpr uintptr_t sent_to = 0x9B0;        // saved as "to"; an expense
        constexpr uintptr_t sent_back = 0x9D4;      // saved as "back"; an income
        constexpr uintptr_t supply_drawn_at_capital = 0xA1C;
        constexpr uintptr_t supply_drawn_own = 0xA40;
        constexpr uintptr_t conversion_made = 0x8B4;      // an income
        constexpr uintptr_t conversion_used = 0x8D8;      // an expense
        constexpr uintptr_t resources_needed = 0x968;     // metal : energy : rares = 1 : 2 : 0.5
        constexpr uintptr_t tribute_received = 0x8FC;    // from this country's subjects
        constexpr uintptr_t tribute_sent = 0x920;        // to its overlord, held negative
        // Nothing fills these. +0x824, +0x848 and +0x944 are written nowhere but the
        // constructor and the daily resets; +0xA64 has writes but is empty in practice.
        constexpr uintptr_t unused_pool_824 = 0x824;
        constexpr uintptr_t unused_pool_848 = 0x848;
        constexpr uintptr_t unused_pool_944 = 0x944;
        constexpr uintptr_t unused_pool_A64 = 0xA64;

        /**@brief the stockpile a government in exile holds itself, saved as just "pool" -
                  see is_government_in_exile*/
        constexpr uintptr_t pool_in_exile = 0x9F8;

        /**
         * **Named from the key the game saves them under.** `CCountry::SaveContents`
         * (`0xCFCE0`) loads the field, writes the key, then writes the value, and
         * `CCountry::LoadKey` (`0xCCDA0`) reads it back into the same place - so the pairing
         * is the code's, not a guess. See CPersistent.hpp for how that works.
         *
         * The method checks out where it can be checked: it gives `+0xA8C` the key
         * `neutrality`, `+0xB4` `escorts` and `+0xBAC` `active_leaders`, which is what the
         * Lua API already called them.
         *
         * A few of these come from a country's history file rather than a save - `major`,
         * `color`, `graphical_culture`, `history`, `manpower` - since the loader takes both.
         */
        constexpr uintptr_t ignored_keys = 0x74;             // SaveToken[], skipped on load
        constexpr uintptr_t ignored_keys_end = 0x78;
        constexpr uintptr_t duration = 0x98;                 // saved as "duration"
        constexpr uintptr_t convoys_changed = 0x9C;          // set when a convoy is added
        constexpr uintptr_t officers = 0xC4;                 // saved as "officers"
        constexpr uintptr_t starting_manpower = 0x158;       // LoadKey copies Manpower here
        constexpr uintptr_t is_major = 0x15C;                // "major"; a yes/no
        constexpr uintptr_t ai_hard_strategy = 0x1DC;        // a CPersistent of its own
        constexpr uintptr_t ai_event_strategy = 0x334;       // a CPersistent of its own
        constexpr uintptr_t lendlease_distributions = 0x6B8; // and _end at +0x6BC
        constexpr uintptr_t lendlease_distributions_end = 0x6BC;
        constexpr uintptr_t lend_lease_from_values = 0x6C8;
        constexpr uintptr_t lend_lease_from_values_end = 0x6CC;
        constexpr uintptr_t lend_lease_from_yesterday_values = 0x6D8;
        constexpr uintptr_t lend_lease_from_yesterday_values_end = 0x6DC;
        constexpr uintptr_t diplo_influence = 0xA88;
        constexpr uintptr_t last_election_at_start = 0xAAC;  // see the comment
        constexpr uintptr_t last_election = 0xAB0;           // a date
        constexpr uintptr_t last_rebel_acceptance = 0xAB4;   // a date
        constexpr uintptr_t remove_fow = 0xAB8;              // a linked list
        constexpr uintptr_t remove_fow_end = 0xABC;
        constexpr uintptr_t remove_fow_count = 0xAC0;
        constexpr uintptr_t last_surrender = 0xAC8;          // a date
        constexpr uintptr_t war_exhaustion = 0xAD0;
        constexpr uintptr_t color = 0xC30;                   // a CPersistent of its own
        constexpr uintptr_t has_color = 0xC4C;               // set when "color" is read
        constexpr uintptr_t history = 0xCCC;                 // a CPersistent of its own
        constexpr uintptr_t active_leaders = 0xE00;          // and _end, _capacity after it
        constexpr uintptr_t active_leaders_end = 0xE04;
        constexpr uintptr_t active_leaders_capacity = 0xE08;
        constexpr uintptr_t active_mission = 0xE38;          // a CPersistent of its own
        constexpr uintptr_t graphical_culture = 0xF20;       // AfterLoad gives it "Generic"
        constexpr uintptr_t declarewar = 0xF24;              // a linked list
        constexpr uintptr_t declarewar_end = 0xF28;
        constexpr uintptr_t declarewar_count = 0xF2C;
        constexpr uintptr_t land_battles_fought = 0x1080;
        constexpr uintptr_t air_battles_fought = 0x1084;
        constexpr uintptr_t naval_battles_fought = 0x1088;
        constexpr uintptr_t historical_friends = 0x10A4;     // and _end, _capacity after it
        constexpr uintptr_t historical_friends_end = 0x10A8;
        constexpr uintptr_t historical_friends_capacity = 0x10AC;
        constexpr uintptr_t election = 0x113C;               // a yes/no
        constexpr uintptr_t espionage = 0x1160;              // 0xF8 an entry, one per country
        constexpr uintptr_t espionage_end = 0x1164;
        constexpr uintptr_t spiescaught = 0x11D4;

        /**
         * **Who this country borders**: which countries are in the `Neighbours` list
         * (`+0xFD8`) and the `ControllerNeighbours` list (`+0xFE8`), one byte per country,
         * indexed by the country's id and as long as the country count. The constructor
         * makes and clears both; one function (`0xE21E0`) fills them, and it is that
         * function that says what each one counts (**read**):
         *
         *  - `neighbours` walks the provinces this country **owns**. An adjacent province
         *    counts only where its **owner and controller are the same** - so not one
         *    somebody is occupying - and is neither unowned nor this country. The owner is
         *    what gets marked.
         *  - `controller_neighbours` walks the provinces this country **controls**. An
         *    adjacent province counts where it is owned by somebody, and neither owned nor
         *    controlled by this country. The **controller** is what gets marked.
         *
         * So occupation moves a country from one list to the other, in both directions at
         * once. **Read live** off a 1942 game, and every case follows from those two rules:
         * Sweden has Norway and Finland as neighbours but not Denmark, because Germany holds
         * Denmark - and Germany instead, under control. Germany owns only its own ground, so
         * its first list is four countries and its second twelve. Poland, Denmark and Greece
         * still own their land and keep their old borders in the first, and hold nothing, so
         * the second is empty. Yugoslavia, annexed, owns nothing and has the first empty
         * while the second still has what its remaining ground touches.
         *
         * `CCountry::IsNeighbour` (`0xC86C0`) is the first indexed by the tag's id and
         * nothing more. `CCountry::IsNonExileNeighbour` (`0xC86E0`) is the second, **and** a
         * check that the other country is not a government in exile - the list itself is not
         * free of exiles.
         */
        constexpr uintptr_t neighbours = 0xF58;
        constexpr uintptr_t neighbours_end = 0xF5C;
        constexpr uintptr_t neighbours_capacity = 0xF60;
        constexpr uintptr_t controller_neighbours = 0xF68;
        constexpr uintptr_t controller_neighbours_end = 0xF6C;
        constexpr uintptr_t controller_neighbours_capacity = 0xF70;
    }

    /**
     * **A day's figures for one good**, all four `CFixedPoint` through a hidden pointer and
     * all taking a GoodsCategory (**read**).
     *
     *     0xF1830  GetDailyIncome    home_produced, convoyed_in, and the five income pools
     *     0xF1950  GetDailyExpense   the three expense pools, convoyed_out, traded_away,
     *                                less the two shortfall pools
     *     0xF19A0  GetDailyNeed      the same seven, all added
     *     0xF18A0  GetDailyBalance   income less expense, worked out inline
     *
     * **`convoyed_in` counts only for goods other than supplies and fuel** - categories 0
     * and 1 are tested and skipped - so what convoys bring in of those two never shows in
     * the income or the balance.
     */
    namespace GameFunction {
        constexpr uintptr_t GetDailyIncome = 0xF1830;
        constexpr uintptr_t GetDailyExpense = 0xF1950;
        constexpr uintptr_t GetDailyNeed = 0xF19A0;
        constexpr uintptr_t GetDailyBalance = 0xF18A0;

        // The country's three CPersistent slots - see CPersistent.hpp. Together they are
        // the full list of the keys a country is saved under, and the only place some of
        // its fields are named at all.
        constexpr uintptr_t SaveContents = 0xCFCE0;   // slot 2, what a country writes
        constexpr uintptr_t LoadKey = 0xCCDA0;        // slot 4, one key read back
        constexpr uintptr_t AfterLoad = 0xD2500;      // slot 5, the fix-ups afterwards

        /**@brief neighbours[tag.id] and nothing else*/
        constexpr uintptr_t IsNeighbour = 0xC86C0;

        /**@brief controller_neighbours[tag.id], and that country not being in exile*/
        constexpr uintptr_t IsNonExileNeighbour = 0xC86E0;

        /**
         * `0x103C60` - whether trading with a country needs convoys. **Read**: no, if it is
         * a `neighbours` neighbour; otherwise yes unless both acting capitals sit in an
         * area and are on one continent, or on two continents joined overland
         * (`AreaIsConnectedTo`, `0xB8DC0`).
         */
        constexpr uintptr_t NeedConvoyToTradeWith = 0x103C60;

        /**@brief fills both neighbour sets, and the two CCountryList they stand for*/
        constexpr uintptr_t RebuildNeighbours = 0xE21E0;
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

/**
 * CDistributionSetting - one of the four sliders a country's leadership is split between.
 *
 * `0x28` bytes, from the allocation its builder makes (`0xC9FA5`). The four are made
 * together and pushed onto CCountry::Offsets::leadership_distribution; each derives from
 * this and only overrides how much it needs.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CDistributionSetting {
    namespace VFTable {
        constexpr uintptr_t CDistributeNCO = 0x11C22A4;         // module relative, RTTI
        constexpr uintptr_t CDistributeDiplomacy = 0x11C22D8;
        constexpr uintptr_t CDistributeEspionage = 0x11C230C;
        constexpr uintptr_t CDistributeResearch = 0x11C2340;
    }

    constexpr uintptr_t SIZE = 0x28;

    namespace Offsets {
        /**
         * **The share of leadership this slider is set to**, and the game's own
         * `GetBasePercentage` - registered to Lua as `CDistributionSetting:GetPercentage`
         * (**named**). Eight bytes: the compiler's RTTI calls the type
         * `fpml::fixed_point<__int64,48,15>`, so 32768 is 1 and the four sum to it.
         *
         * The four always add to one (**read live**).
         */
        constexpr uintptr_t base_percentage = 0x8;

        /**
         * A second figure of the same kind, which the allowed research slots calculation
         * multiplies the percentage by. The constructor sets it to 1 and it stays there
         * (**read live**); **what would change it has not been established.**
         */
        constexpr uintptr_t factor = 0x10;

        /**@brief the CCountry this belongs to; `GetNeeded` reads the country through it*/
        constexpr uintptr_t country_ptr = 0x18;
    }

    /**
     * Virtual slot 3, `GetNeeded`: how much of this the country is actually using.
     * `CDistributeResearch`'s (`0x121450`) answers the country's
     * `GetNumberOfCurrentResearch` (`CCountry +0x640`) shifted into the fixed point.
     */
    namespace Slots {
        constexpr int GET_NEEDED = 3;
    }
}
