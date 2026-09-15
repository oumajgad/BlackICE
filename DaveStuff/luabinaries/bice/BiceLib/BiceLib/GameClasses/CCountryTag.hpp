#pragma once
#include <cstdint>

/**
 * CCountryTag - a country as the game refers to it: its three letters, and its id.
 *
 * Eight bytes, no vftable, and held by value almost everywhere a country is named: a
 * country carries its own, a province its owner and controller, a unit and a convoy
 * their owner. An owner's offset for one is where the tag starts, and the two fields
 * are this second offset.
 *
 * The id is what the game's `CCountryTag::GetIndex` answers, and it indexes the country
 * database's array directly (CCountryDataBase::Offsets::countries_first). Id 0 with
 * the letters `---` is the null tag, which is what a field holds where there is no
 * country.
 *
 * HDS::readTag reads the letters.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CCountryTag {
    namespace Offsets {
        /**@brief three characters and a NUL, in place rather than a string*/
        constexpr uintptr_t tag = 0x0;

        /**@brief the country's id, the game's `GetIndex`*/
        constexpr uintptr_t id = 0x4;
    }

    constexpr uintptr_t SIZE = 0x8;
    constexpr uintptr_t TAG_LENGTH = 4;
}
