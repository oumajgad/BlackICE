#pragma once
#include <cstdint>
#include <string>
#include <vector>

/**
 * CTrait - one leader trait, as the game holds it.
 *
 * The game builds one instance per trait the mod defines and hands leaders pointers to
 * them. They are definitions: made once while the mod loads and alive for the rest of
 * the process. The class name is from RTTI.
 *
 * They are kept in a list of their own, reached through a lazily made object at
 * GLOBAL_POINTER - see all(). BiceLib used to find them by scanning every committed
 * page for the vftable and sifting the hits with a magic number; reading the list
 * needs neither, and it is the game's own set rather than whatever a scan turned up.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CTrait {
    namespace Offsets {
        constexpr uintptr_t name = 0x2C;
    }

    namespace VFTable {
        constexpr uintptr_t CTrait = 0x11C7DC0;      // module relative
        constexpr uintptr_t CNullTrait = 0x11C7DFC;  // what sits at index 0 of the list
    }

    /**
     * The object holding every trait, made on first use by the getter at `0x1B4640`
     * and kept in this global. `0x1C` bytes.
     *
     * It is not filled until the mod's traits are loaded, so before that the list is
     * empty - which is what the deferral in bice.cpp is waiting for.
     */
    constexpr uintptr_t GLOBAL_POINTER = 0x16855EC;

    namespace DataBaseOffsets {
        /**@brief the number of entries, the same as (end - begin) / 4*/
        constexpr uintptr_t count = 0x00;

        /**
         * The traits themselves: begin and end, four byte elements.
         *
         * **Index 0 is a CNullTrait**, the way index 0 of a province's building array
         * is "nobuilding", so the entry there is not a CTrait and all() leaves it out.
         */
        constexpr uintptr_t traits_begin = 0x0C;
        constexpr uintptr_t traits_end = 0x10;
    }

    /**
     * A bound on the list, so a begin/end pair that is not one is refused rather than
     * walked. The mod defines a few hundred.
     */
    constexpr size_t MAX_TRAITS = 8192;

    /**
    @brief every trait, in the game's own order; empty until the mod's traits are loaded

    The CNullTrait at index 0 is left out, so everything answered here carries the
    CTrait vftable and its name can be read at Offsets::name.
    */
    std::vector<uintptr_t> all();

    /**@brief how many traits are loaded, 0 before they are*/
    size_t count();

    /**@brief the trait with this name, or 0*/
    uintptr_t findByName(const std::string& name);
}
