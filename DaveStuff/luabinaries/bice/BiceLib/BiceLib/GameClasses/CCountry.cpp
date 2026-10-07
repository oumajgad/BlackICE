#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <GameClasses/CFlags.hpp>
#include <GameClasses/CModifier.hpp>
#include <Hooks/Hooks.hpp>

#include <MemScan.hpp>

namespace {
    /**
     * A bound on the country list, so a garbage begin/end pair is refused instead of
     * being walked. The game defines a few hundred; this only has to be past that and
     * short of anything that would take a noticeable time to read.
     */
    const size_t MAX_COUNTRIES = 4096;

    /**@brief the two capital accessors, both `__thiscall` on the country and both
       answering a CMapProvince*/
    const uintptr_t GET_CAPITAL_LOCATION = 0x17AF0;
    const uintptr_t GET_ACTING_CAPITAL_LOCATION = 0x2F100;
    typedef uintptr_t(__thiscall* GetLocation)(uintptr_t country);

    /**@brief either accessor, called on \p country, guarding the nulls*/
    uintptr_t locationThrough(uintptr_t rva, uintptr_t country) {
        if (country == 0 || Hooks::MODULE_BASE == 0) {
            return 0;
        }
        return reinterpret_cast<GetLocation>(Hooks::MODULE_BASE + rva)(country);
    }

    /**
    @brief the country list as a base and a count, or false when there is none

    Read from the game state every time rather than kept: the list is the game's, and
    anything held here could only be staler than it.
    */
    bool countryRange(uintptr_t& begin, size_t& count) {
        begin = 0;
        count = 0;

        const uintptr_t state = CCurrentGameState::current();
        if (state == 0) {
            return false;
        }

        uint32_t first = 0;
        uint32_t last = 0;
        if (!Mem::tryRead(state + CCurrentGameState::Offsets::countries_begin, first)
            || !Mem::tryRead(state + CCurrentGameState::Offsets::countries_end, last)
            || first == 0 || last < first) {
            return false;
        }

        const size_t entries = (last - first) / sizeof(uint32_t);
        if (entries == 0 || entries > MAX_COUNTRIES) {
            return false;
        }

        begin = first;
        count = entries;
        return true;
    }

    // The flag and variable trees are only as deep as the mod makes them, but nothing
    // here has checked that, and a tree read out of something that is not one has no
    // depth at all. This bounds the recursion either way.
    //
    // **Raised from 256 to 2048 on 2026-10-07.** `depth` counts every link followed, and
    // two of the three - `low` and `high` - are the binary-search dimension rather than the
    // key dimension. A ternary search tree built in insertion order can skew, so with
    // BlackICE's thousands of flags a long low/high chain could plausibly have passed 256
    // and had the rest of the tree silently dropped. Nobody has measured the real depth;
    // 2048 is headroom rather than a known bound, and the cap is still here to stop a
    // runaway read of something that is not a tree. At roughly a hundred bytes a frame this
    // is about 200 KB of stack at full depth, against the 1 MB a thread gets by default.
    const int MAX_TREE_DEPTH = 2048;

    template <typename T>
    T readValue(uintptr_t address, T fallback = T()) {
        T value = fallback;
        if (!Mem::tryRead(address, value)) {
            return fallback;
        }
        return value;
    }

    void traverse(std::vector<std::uintptr_t>& res, uintptr_t nodePtr, int depth) {
        if (nodePtr == 0 || depth > MAX_TREE_DEPTH) {
            return;
        }

        // The three links, under the names the tree actually uses. They were `parent`,
        // `sibling` and `child` here until 2026-10-07, which is what `CTernary::NodeOffsets`
        // called them before `TernarySearchTreeFind` settled the layout - the header was
        // corrected and this was not, so the build stopped. The mapping is the one the
        // header's own account implies: the old `parent` was the low link, `child` the
        // equal link and `sibling` the high link.
        //
        // **The visit order is deliberate.** low -> element -> equal -> high is the order
        // `CVariables::SaveSubtree` walks, which is why a savegame's `variables={}` block
        // comes out alphabetical - so this produces the keys in the same order the game
        // writes them, rather than in a shape that only happens to be complete.
        namespace Node = CTernary::NodeOffsets;
        const uintptr_t element = readValue<uint32_t>(nodePtr + Node::element);
        const uintptr_t lowNode = readValue<uint32_t>(nodePtr + Node::low);
        const uintptr_t equalNode = readValue<uint32_t>(nodePtr + Node::equal);
        const uintptr_t highNode = readValue<uint32_t>(nodePtr + Node::high);

        if (lowNode != 0) {
            traverse(res, lowNode, depth + 1);
        }
        if (element != 0) {
            res.push_back(element);
        }
        if (equalNode != 0) {
            traverse(res, equalNode, depth + 1);
        }
        if (highNode != 0) {
            traverse(res, highNode, depth + 1);
        }
    }
}

void CCountry::traverseFlagsAndVarTreeDepthFirst(std::vector<std::uintptr_t>& res, uintptr_t nodePtr) {
    traverse(res, nodePtr, 0);
}

std::vector<std::pair<std::string, std::string>> CCountry::getActiveEventModifiers(uintptr_t countryPtr) {
    std::vector<std::pair<std::string, std::string>> res;

    const std::vector<uintptr_t> modifiers =
        HDS::walkList(countryPtr + Offsets::active_modifiers);

    for (size_t i = 0; i < modifiers.size(); i++) {
        const uintptr_t definition =
            readValue<uint32_t>(modifiers[i] + ActiveModifierOffsets::definition_ptr);
        const std::string name =
            HDS::readString(definition + ActiveModifierOffsets::definition_name);

        const int expiryDateTick =
            readValue<int32_t>(modifiers[i] + ActiveModifierOffsets::expiry_tick);

        res.push_back(std::make_pair(name, utils::gameTickToDate(expiryDateTick)));
    }
    return res;
}

std::vector<std::pair<std::string, int>> CCountry::getGeneralModifiers(uintptr_t countryPtr) {
    std::vector<std::pair<std::string, int>> res;

    const uintptr_t values = readValue<uint32_t>(
        countryPtr + Offsets::global_modifier + CModifier::Offsets::values);
    if (values == 0) {
        return res;
    }

    for (int i = 0; i < CModifier::COUNT; i++) {
        const uintptr_t entry = values + CModifier::entryOffset(i);
        const uintptr_t definition =
            readValue<uint32_t>(entry + CModifier::Entry::definition_ptr);

        const std::string modifierName =
            HDS::readString(definition + CModifierDefinition::Offsets::name);
        const int modifierValue = readValue<int32_t>(entry + CModifier::Entry::value);

        res.push_back(std::make_pair(modifierName, modifierValue));
    }
    return res;
}

std::vector<std::string> CCountry::getFlags(uintptr_t countryPtr) {
    std::vector<std::uintptr_t> ptrs;

    const uintptr_t flagsPtr =
        readValue<uint32_t>(countryPtr + Offsets::flags + CTernary::Offsets::root);
    CCountry::traverseFlagsAndVarTreeDepthFirst(ptrs, flagsPtr);

    std::vector<std::string> res;
    res.reserve(ptrs.size());
    for (auto& i : ptrs) {
        res.push_back(HDS::readString(i + CFlags::ElementOffsets::name));
    }
    return res;
}

std::vector<HDS::CVariable> CCountry::getVars(uintptr_t countryPtr) {
    std::vector<std::uintptr_t> ptrs;

    const uintptr_t varsPtr =
        readValue<uint32_t>(countryPtr + Offsets::variables + CTernary::Offsets::root);
    CCountry::traverseFlagsAndVarTreeDepthFirst(ptrs, varsPtr);

    std::vector<HDS::CVariable> res;
    for (auto& i : ptrs) {
        HDS::CVariable x;
        x.name = HDS::readString(i + CVariables::ElementOffsets::name);
        x.value = readValue<int32_t>(i + CVariables::ElementOffsets::value);
        if (x.value != 0) {
            res.push_back(x);
        }
    }
    return res;
}

std::vector<uintptr_t> CCountry::all() {
    std::vector<uintptr_t> out;

    uintptr_t begin = 0;
    size_t count = 0;
    if (!countryRange(begin, count)) {
        return out;
    }

    out.reserve(count);
    for (size_t i = 0; i < count; i++) {
        uint32_t country = 0;
        if (Mem::tryRead(begin + i * sizeof(uint32_t), country) && country != 0) {
            out.push_back(country);
        }
    }
    return out;
}

uintptr_t CCountry::findByTag(const std::string& tag) {
    if (tag.size() < 3) {
        return 0;
    }

    uintptr_t begin = 0;
    size_t count = 0;
    if (!countryRange(begin, count)) {
        return 0;
    }

    for (size_t i = 0; i < count; i++) {
        uint32_t country = 0;
        if (!Mem::tryRead(begin + i * sizeof(uint32_t), country) || country == 0) {
            continue;
        }

        // Compared in place. A tag is three characters and a NUL, so there is nothing
        // to build and nothing to free per country.
        char have[3] = {};
        if (!Mem::tryReadBytes(country + Offsets::tag + CCountryTag::Offsets::tag, have, sizeof(have))) {
            continue;
        }
        if (have[0] == tag[0] && have[1] == tag[1] && have[2] == tag[2]) {
            return country;
        }
    }
    return 0;
}

uintptr_t CCountry::findById(int id) {
    uintptr_t begin = 0;
    size_t count = 0;
    if (!countryRange(begin, count)) {
        return 0;
    }

    // Walked rather than indexed: nothing has established that the list is in id
    // order, and the id is one read away on each country.
    for (size_t i = 0; i < count; i++) {
        uint32_t country = 0;
        if (!Mem::tryRead(begin + i * sizeof(uint32_t), country) || country == 0) {
            continue;
        }
        int32_t have = 0;
        if (Mem::tryRead(country + Offsets::tag + CCountryTag::Offsets::id, have) && have == id) {
            return country;
        }
    }
    return 0;
}

uintptr_t CCountry::capitalLocation(uintptr_t country) {
    return locationThrough(GET_CAPITAL_LOCATION, country);
}

uintptr_t CCountry::actingCapitalLocation(uintptr_t country) {
    return locationThrough(GET_ACTING_CAPITAL_LOCATION, country);
}
