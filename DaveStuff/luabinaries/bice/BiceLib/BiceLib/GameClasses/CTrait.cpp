#include <GameClasses/CTrait.hpp>

#include <HoiDataStructures.hpp>
#include <MemScan.hpp>

namespace {
    /**
    @brief the trait list as a base and a count, or false when there is none

    Read from the global every time. The traits are definitions and never move, but
    the list does not exist until the mod is loaded, and answering false for that is
    what lets the callers defer their work until it does.
    */
    bool traitRange(uintptr_t& begin, size_t& count) {
        begin = 0;
        count = 0;

        const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
        if (base == 0) {
            return false;
        }

        uint32_t database = 0;
        if (!Mem::tryRead(base + CTrait::GLOBAL_POINTER, database) || database == 0) {
            return false;
        }

        uint32_t first = 0;
        uint32_t last = 0;
        if (!Mem::tryRead(database + CTrait::DataBaseOffsets::traits_begin, first)
            || !Mem::tryRead(database + CTrait::DataBaseOffsets::traits_end, last)
            || first == 0 || last < first) {
            return false;
        }

        const size_t entries = (last - first) / sizeof(uint32_t);
        if (entries == 0 || entries > CTrait::MAX_TRAITS) {
            return false;
        }

        begin = first;
        count = entries;
        return true;
    }

    /**@brief whether this is a CTrait rather than the CNullTrait the list starts with*/
    bool isTrait(uintptr_t candidate) {
        const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
        uint32_t vftable = 0;
        return base != 0
            && Mem::tryRead(candidate, vftable)
            && vftable == base + CTrait::VFTable::CTrait;
    }
}

std::vector<uintptr_t> CTrait::all() {
    std::vector<uintptr_t> out;

    uintptr_t begin = 0;
    size_t entries = 0;
    if (!traitRange(begin, entries)) {
        return out;
    }

    out.reserve(entries);
    for (size_t i = 0; i < entries; i++) {
        uint32_t trait = 0;
        if (Mem::tryRead(begin + i * sizeof(uint32_t), trait) && trait != 0 && isTrait(trait)) {
            out.push_back(trait);
        }
    }
    return out;
}

size_t CTrait::count() {
    return all().size();
}

uintptr_t CTrait::findByName(const std::string& name) {
    if (name.empty()) {
        return 0;
    }

    uintptr_t begin = 0;
    size_t entries = 0;
    if (!traitRange(begin, entries)) {
        return 0;
    }

    for (size_t i = 0; i < entries; i++) {
        uint32_t trait = 0;
        if (!Mem::tryRead(begin + i * sizeof(uint32_t), trait) || trait == 0 || !isTrait(trait)) {
            continue;
        }
        if (HDS::readString(trait + Offsets::name) == name) {
            return trait;
        }
    }
    return 0;
}
