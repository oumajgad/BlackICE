#pragma once
#include <cstdint>

/**
 * CGovernment - one form of government, as `common/governments.txt` declares it.
 *
 * **It derives from CModifier** (RTTI: `CGovernment : CModifier : CPersistent`), so the
 * first 0x2C bytes are the modifier and everything below starts at 0x2C. That is also the
 * fallthrough in `LoadKey`: a key that is neither an ideology nor a government position is
 * handed to `CModifier::LoadKey`, which is what the file's own header note means by "Uses
 * all 'modifiers' possible thats exported as a Modifier". BlackICE uses none of them.
 *
 * A block is short, and the whole class is in it:
 *
 *     fascist_republic = {
 *         national_socialist = yes      # an acceptable ideology  -> `ideologies`
 *         fascistic = yes
 *         paternal_autocrat = yes
 *         head_of_state = yes           # a position elections change -> `elected_positions`
 *         ...
 *         election = no                 # -> `election`
 *     }
 *
 * `LoadKey` handles three keys by token and looks everything else up by name:
 *
 * | key | token | |
 * | --- | --- | --- |
 * | `duration` | 108 | atoi of the value text |
 * | `valid_for_new_country` | 1715 | the value token against `yes` |
 * | `election` | 1736 | the shared yes/no parser at `0x67B410` |
 *
 * then the ideology database, then the government position database, then CModifier.
 *
 * ## The null at index 0
 *
 * Both databases **reserve index 0 for a null object** - `CNullIdeology` and
 * `CNullGovernmentPosition`, and there is a `CNullGovernment` for this class too. So the
 * eleven positions the mod declares are indices 1 to 11, the bitset is twelve bits wide,
 * and **bit 0 is never set on any government**. The same goes for `index` below, which
 * runs 1 to 18 rather than 0 to 17. Reading the file's order onto the bits directly is
 * off by one, which is worth knowing before fitting any of the ~20 CNull* classes'
 * databases.
 *
 * **Read live**: all four loaded fields agree with the file on all eighteen governments.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CGovernment {
    /**@brief 0x80 bytes: neighbours are 0x88 apart, which is this plus the heap's header*/
    constexpr uintptr_t SIZE = 0x80;

    namespace Offsets {
        /**@brief `duration`, saved under token 108 - atoi of the value text, so no scaling.
                  **Read live**: 18 of 18, and 0 on the ten that do not declare it*/
        constexpr uintptr_t duration = 0x2C;

        /**
         * **The ideologies this government is acceptable to**, a `CList<CIdeology*>` that
         * `LoadKey` builds by hand rather than through the list helpers - it news a 0x10
         * byte node, links it, and bumps the count, appending only where the value is
         * `yes`.
         *
         * **Read live**: the names walked out of it are exactly the ideology keys set to
         * `yes` in the file, on 18 of 18.
         */
        constexpr uintptr_t ideologies = 0x30;
        constexpr uintptr_t ideologies_last = 0x34;
        constexpr uintptr_t ideologies_count = 0x38;

        /**
         * **The government's own key as a SaveToken**, registered at construction by the
         * dynamic token registrar at `0x669CA0` - the one whose failure message is
         * `"Error on dynamic token: "`.
         *
         * **Read live** against the running game's token table: 2451 is `nogovernment`
         * and 2452 to 2469 are the eighteen governments in file order. It is not in
         * `ghidra/saveTokens.json`, because that holds only the tokens compiled into the
         * executable; see reversing/saveTokens.py.
         */
        constexpr uintptr_t token = 0x40;

        /**@brief the government's key as text, an Hoi3CString - `national_socialism` and
                  the other seventeen*/
        constexpr uintptr_t key = 0x44;

        /**
         * **Which government this is**, the third argument to the constructor.
         * **Read live**: 1 to 18 in the file's order, because index 0 belongs to
         * `CNullGovernment`.
         */
        constexpr uintptr_t index = 0x60;

        /**@brief `valid_for_new_country`, token 1715 - **the constructor defaults it to 1**
                  and BlackICE never sets it, so it is 1 on all eighteen*/
        constexpr uintptr_t valid_for_new_country = 0x64;

        /**
         * **Which government positions an election changes**, one bit per
         * CGovernmentPosition, numbered by that position's own index at its `+0x4C`. The
         * three pointers are the bitset's block vector; the mod's twelve positions fit in
         * the single 4 byte block it allocates.
         *
         * **Read live**: the bits are exactly the file's `head_of_state = yes` and the
         * rest, on 18 of 18 - once bit 0 is left to `CNullGovernmentPosition`.
         */
        constexpr uintptr_t elected_positions = 0x68;
        constexpr uintptr_t elected_positions_end = 0x6C;
        constexpr uintptr_t elected_positions_capacity = 0x70;

        /**@brief how many bits the set above has - **read live** 12 on every government,
                  the size of the position database including its null*/
        constexpr uintptr_t elected_position_count = 0x78;

        /**@brief `election`, token 1736, through the shared yes/no parser. **Read live**:
                  18 of 18, and the constructor defaults it to 0*/
        constexpr uintptr_t election = 0x7C;
    }

    namespace GameFunction {
        /**
         * The constructor: `(this, key, index)`, all three on the stack, `ret 0xC`, and it
         * answers `this` in eax. It zeroes `duration` and the ideology list, copies the
         * key, takes `index` from its caller, sets `valid_for_new_country` to 1 and
         * `election` to 0, empties the position bitset, and finishes by registering the
         * key as a dynamic token into `token`.
         */
        constexpr uintptr_t Constructor = 0x123C90;

        /**@brief slot 4; three keys of its own, then the two databases, then CModifier*/
        constexpr uintptr_t LoadKey = 0x124660;
    }

    namespace VFTable {
        constexpr uintptr_t CGovernment = 0x11C25CC;   // module relative
    }
}

/**
 * The two name databases `CGovernment::LoadKey` looks its remaining keys up in.
 *
 * Neither object has a vftable - the first word is the entry count - and both are
 * singletons made on first use. They share one lookup, `0x12A5F0`, which takes the
 * database in eax and an Hoi3CString on the stack and answers the object or null.
 *
 * **Read live**: the ideology database holds `noIdeology` and the ten ideologies of
 * `common/ideologies.txt`; the position database holds `noGovernmentPosition` and the
 * eleven of `common/government_positions.txt`, both in file order after the null.
 */
namespace CNameDataBase {
    namespace Offsets {
        /**@brief how many entries - **read live** 11 and 12*/
        constexpr uintptr_t count = 0x0;

        /**@brief what the by-name lookup searches; its shape has not been read*/
        constexpr uintptr_t by_name = 0x8;

        /**@brief the entries in index order, a vector of pointers*/
        constexpr uintptr_t first = 0xC;
        constexpr uintptr_t last = 0x10;
    }

    namespace GameFunction {
        /**@brief the ideology database, made on first use at `g_ideologies` (0x16878BC)*/
        constexpr uintptr_t GetIdeologies = 0x127280;

        /**@brief the government position database, at `g_government_positions`
                  (0x1687990)*/
        constexpr uintptr_t GetGovernmentPositions = 0x12BA30;

        /**@brief `(database@EAX, Hoi3CString* name)`, `ret 4`, the object or null in eax*/
        constexpr uintptr_t GetByName = 0x12A5F0;
    }
}

/**
 * A CIdeology and a CGovernmentPosition both derive from CModifier as well, and the two
 * fields this class needed from them are the same on each.
 */
namespace CIdeologyAndPosition {
    namespace Offsets {
        /**@brief the key, the first field after the CModifier base - `head_of_state`,
                  `national_socialist`*/
        constexpr uintptr_t key = 0x30;

        /**@brief **its index**, and the bit number CGovernment's `elected_positions` uses.
                  **Read live**: 0 to 11 and 0 to 10, matching the database order*/
        constexpr uintptr_t index = 0x4C;
    }
}
