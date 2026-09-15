#pragma once
#include <cstdint>

/**
 * CCountryDataBase - every country by id, and the lookup from a tag's letters to its id.
 *
 * One instance, `0x57C` bytes, created on first use and stored in a global of its own.
 * It has no vftable, so the RTTI export does not list it and a disassembler shows only
 * the global. The Lua API names it: `CCountryDataBase.GetTag` fetches exactly this
 * object, and `CCountryTag::GetCountry` indexes its country array.
 *
 * Not read by BiceLib: CCountry::all() and CCountry::findByTag walk the game state's
 * own list (CCurrentGameState::Offsets::countries_begin) instead. Whether that list and
 * the array here hold the same pointers has not been checked.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CCountryDataBase {
    /**@brief where the pointer to the database lives, module relative; null until first use*/
    constexpr uintptr_t GLOBAL_POINTER = 0x16855A4;

    /**
     * The functions that make and use it, module relative.
     *
     * `Construct` takes the object as its one stack argument and answers it (`ret 4`);
     * the game allocates `0x57C` bytes and calls it wherever it finds the global null.
     *
     * `GetTag` is `CCountryTag* __stdcall(CCountryDataBase*, CCountryTag* out, const char*)`:
     * the tag whose three letters are the string, or `---` with id 0 when there is none.
     */
    constexpr uintptr_t Construct = 0x24D0;
    constexpr uintptr_t GetTag = 0x118480;

    constexpr uintptr_t SIZE = 0x57C;

    namespace Offsets {
        /**
         * **Every country by id**: a vector of CCountry*, first, last and end of storage.
         * A CCountryTag's id half indexes it directly - that is the whole of
         * `CCountryTag::GetCountry`.
         */
        constexpr uintptr_t countries_first = 0x16C;
        constexpr uintptr_t countries_last = 0x170;
        constexpr uintptr_t countries_end = 0x174;

        /**
         * **The tags, hashed by their letters**: 64 buckets of 16 bytes, each a vector of
         * eight byte CCountryTags whose first and last are its first two words. A tag's
         * bucket is the sum of its three characters, modulo 64, and `GetTag` searches only
         * that one.
         */
        constexpr uintptr_t tag_buckets = 0x17C;
        constexpr uintptr_t TAG_BUCKET_COUNT = 64;
        constexpr uintptr_t TAG_BUCKET_SIZE = 0x10;
    }
}
