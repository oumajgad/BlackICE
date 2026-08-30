#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <Hooks/Hooks.hpp>

#include <MemScan.hpp>

namespace {
    /**
     * A bound on the country list, so a garbage begin/end pair is refused instead of
     * being walked. The game defines a few hundred; this only has to be past that and
     * short of anything that would take a noticeable time to read.
     */
    const size_t MAX_COUNTRIES = 4096;

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
    const int MAX_TREE_DEPTH = 256;

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

        namespace Node = CCountry::TreeNodeOffsets;
        const uintptr_t element = readValue<uint32_t>(nodePtr + Node::element);
        const uintptr_t parentNode = readValue<uint32_t>(nodePtr + Node::parent);
        const uintptr_t siblingNode = readValue<uint32_t>(nodePtr + Node::sibling);
        const uintptr_t childNode = readValue<uint32_t>(nodePtr + Node::child);

        if (parentNode != 0) {
            traverse(res, parentNode, depth + 1);
        }
        if (element != 0) {
            res.push_back(element);
        }
        if (childNode != 0) {
            traverse(res, childNode, depth + 1);
        }
        if (siblingNode != 0) {
            traverse(res, siblingNode, depth + 1);
        }
    }
}

void CCountry::traverseFlagsAndVarTreeDepthFirst(std::vector<std::uintptr_t>& res, uintptr_t nodePtr) {
    traverse(res, nodePtr, 0);
}

std::vector<std::pair<std::string, std::string>> CCountry::getActiveEventModifiers(uintptr_t countryPtr) {
    std::vector<std::pair<std::string, std::string>> res;

    const std::vector<uintptr_t> modifiers =
        HDS::walkList(countryPtr + Offsets::active_modifiers_list_first_ptr);

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

    const uintptr_t arrayBase = readValue<uint32_t>(countryPtr + Offsets::general_modifiers_array_ptr);
    if (arrayBase == 0) {
        return res;
    }

    for (int i = 0; i < GeneralModifierOffsets::count; i++) {
        const uintptr_t entry = arrayBase + (i * GeneralModifierOffsets::entry_size);
        const uintptr_t definition =
            readValue<uint32_t>(entry + GeneralModifierOffsets::definition_ptr);

        const std::string modifierName =
            HDS::readString(definition + GeneralModifierOffsets::definition_name);
        const int modifierValue = readValue<int32_t>(entry + GeneralModifierOffsets::value);

        res.push_back(std::make_pair(modifierName, modifierValue));
    }
    return res;
}

std::vector<std::string> CCountry::getFlags(uintptr_t countryPtr) {
    std::vector<std::uintptr_t> ptrs;

    const uintptr_t flagsPtr = readValue<uint32_t>(countryPtr + Offsets::flags_tree_root_ptr);
    CCountry::traverseFlagsAndVarTreeDepthFirst(ptrs, flagsPtr);

    std::vector<std::string> res;
    res.reserve(ptrs.size());
    for (auto& i : ptrs) {
        res.push_back(HDS::readString(i + TreeNodeOffsets::name));
    }
    return res;
}

std::vector<HDS::CVariable> CCountry::getVars(uintptr_t countryPtr) {
    std::vector<std::uintptr_t> ptrs;

    const uintptr_t varsPtr = readValue<uint32_t>(countryPtr + Offsets::variables_tree_root_ptr);
    CCountry::traverseFlagsAndVarTreeDepthFirst(ptrs, varsPtr);

    std::vector<HDS::CVariable> res;
    for (auto& i : ptrs) {
        HDS::CVariable x;
        x.name = HDS::readString(i + TreeNodeOffsets::name);
        x.value = readValue<int32_t>(i + TreeNodeOffsets::variable_value);
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
        if (!Mem::tryReadBytes(country + Offsets::tag, have, sizeof(have))) {
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
        if (Mem::tryRead(country + Offsets::id, have) && have == id) {
            return country;
        }
    }
    return 0;
}
