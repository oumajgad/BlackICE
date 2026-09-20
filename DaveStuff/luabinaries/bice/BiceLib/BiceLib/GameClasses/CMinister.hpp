#pragma once
#include <cstdint>

/**
 * CMinister - one person who can hold a government post.
 *
 * **They are declared in `common/countries/<Country>.txt`, not in `minister_types.txt`** -
 * that file declares CMinisterType, which is a CModifier. A CMinister is a
 * `CReferenceObject`, and its block is a person:
 *
 *     ministers = {
 *         54001 = {
 *             name = "Muhammed Zahir"
 *             ideology = fascistic
 *             loyalty = 1.00
 *             picture = M54001
 *             head_of_state = autocratic_charmer      # a posting: position = type
 *             chief_of_navy = indirect_approach_doctrine
 *             start_date = 1936.1.1
 *         }
 *     }
 *
 * **A minister can hold several posts**, each with its own type, and that is what the
 * unnamed keys are: `LoadKey` handles `name`, `ideology`, `loyalty`, `picture`,
 * `start_date` and `death_date` by token, **accepts and discards `type`**, and treats
 * everything else as a government position whose value is a minister type - appending the
 * pair to `postings`. A key that is not a position, or a value that is not a type, is a
 * parse error and the posting is dropped.
 *
 * Both lookups go through the databases in GameClasses/CGovernment.hpp.
 *
 * **Read live against the mod, 6257 blocks and 6257 objects**, matched on the 5747 names
 * no other block shares: the id, loyalty, ideology and the postings all agree on every
 * one bar the two the mod has broken (below), and `picture` on all but the five that do
 * not declare it.
 *
 * ## Two things the mod gets wrong
 *
 * Both found by this fit, neither fixed - they are content decisions.
 *
 * **`Japan.txt`, Doihara Kenji (5193)**: `chief_of_army = static_defense_doctrine`, and
 * `static_defense_doctrine` is not one of the 106 types `minister_types.txt` declares. The
 * loader drops that posting, so he can never be chief of army. It is the only posting in
 * the whole mod that names a type that does not exist.
 *
 * **`Italy.txt`, Mario Roatta (3140)**: the block reads
 *
 *     picture =
 *     chief_of_army L6644= armoured_spearhead_doctrine
 *
 * The tokenizer does not care about line ends, so it takes `chief_of_army` as the value of
 * `picture` and then `L6644` as a key of its own, which is not a position. **Read live**
 * he has no postings at all and his picture is the string `chief_of_army`.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CMinister {
    /**@brief 0x90 bytes: neighbours are 0x98 apart in 5467 of the pairs, which is this plus
              the heap's header*/
    constexpr uintptr_t SIZE = 0x90;

    namespace Offsets {
        /**@brief the type half of the object id pair - **read live** 38 on all 6257*/
        constexpr uintptr_t id_type = 0x8;

        /**@brief **the minister's id**, the number that opens his block and what a country's
                  `head_of_state = 54001` points at. **Read live**: 6257 of 6257, and no two
                  ministers in the mod share one*/
        constexpr uintptr_t id = 0xC;

        /**@brief an Hoi3CString that is **empty on all 6257** - nothing in LoadKey writes it*/
        constexpr uintptr_t unused_string = 0x14;

        /**@brief `name`, an Hoi3CString - **read live** `Muhammed Zahir`, `Doihara Kenji`*/
        constexpr uintptr_t name = 0x30;

        /**
         * Two CMinisterType pointers, **both the CNullMinisterType (`noMinisterType`) on
         * all 6257** in a running 1942 game, so what fills them has not been seen. They are
         * not the postings; those are the list below.
         */
        constexpr uintptr_t current_type = 0x4C;
        constexpr uintptr_t current_type_other = 0x50;

        /**@brief `start_date` as a game tick - when he becomes available. **Read live**: all
                  6257 blocks declare one, 1936.1.1 on 2076 of them*/
        constexpr uintptr_t start_date = 0x54;

        /**@brief `death_date` as a game tick. **Read live**: only two ministers in the mod
                  have one, and the other 6255 hold the same sentinel*/
        constexpr uintptr_t death_date = 0x58;

        /**
         * **The posts he can hold and the type he is in each**, a `CList<CMinisterPosting>`
         * - a node is the position and the type side by side, then the links, so the node
         * is 0x14 bytes with `next` at `+0xC`.
         *
         * **Read live**: the pairs are exactly the file's on 5746 of 5747, the one
         * exception being the Doihara Kenji posting the mod names a missing type for.
         */
        constexpr uintptr_t postings = 0x5C;
        constexpr uintptr_t postings_last = 0x60;
        constexpr uintptr_t postings_count = 0x64;

        /**@brief `ideology`, a CIdeology* out of the ideology database. **Read live**: 5747
                  of 5747, and ten distinct across the mod*/
        constexpr uintptr_t ideology = 0x6C;

        /**@brief `loyalty` x1000. **Read live**: 5747 of 5747, and only eight distinct
                  values in the whole mod*/
        constexpr uintptr_t loyalty = 0x70;

        /**
         * `picture`, an Hoi3CString - **read live** `M54001`, `M57`.
         *
         * **It defaults to `empty_position`**: five blocks in the mod declare no picture and
         * exactly five live ministers carry that string, so an absent picture is the
         * engine's placeholder rather than an empty string.
         */
        constexpr uintptr_t picture = 0x74;
    }

    namespace GameFunction {
        /**@brief slot 0 of the vftable - the destructor CMinister introduces*/
        constexpr uintptr_t Destructor = 0x12C550;

        /**@brief slot 4: six keys by token, `type` discarded, everything else a posting*/
        constexpr uintptr_t LoadKey = 0x12C630;
    }

    namespace VFTable {
        constexpr uintptr_t CMinister = 0x11C2AB4;   // module relative, 9 slots
    }
}

/**
 * CMinisterType - one of the 106 kinds of minister in `common/minister_types.txt`.
 *
 * It is a CModifier, like CGovernment and CIdeology, and it keeps its key and its index
 * where every CModifier-derived named type does - which is the pattern worth carrying to
 * the next one of these.
 */
namespace CMinisterType {
    namespace Offsets {
        /**@brief the key, the first field after the CModifier base - `autocratic_charmer`*/
        constexpr uintptr_t key = 0x30;

        /**@brief its index in the minister type database, 0 being CNullMinisterType*/
        constexpr uintptr_t index = 0x4C;
    }

    namespace GameFunction {
        /**@brief the database, made on first use at `g_minister_types` (0x16879D0) - the
                  same CNameDataBase shape as the ideologies and the government positions*/
        constexpr uintptr_t GetMinisterTypes = 0x12B140;
    }
}
