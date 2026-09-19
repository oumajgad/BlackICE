#pragma once
#include <cstdint>

/**
 * CTheatre - one theatre of the order of battle, saved as `area_theatre`.
 *
 * Named from `CTheatre::SaveContents` (`0xAFDF0`) and `CTheatre::LoadKey` (`0xB01F0`) - see
 * CPersistent.hpp - and read back out of the running game, which held 100 of them. The
 * game state hands each an id from `CCurrentGameState::Global::theatre_id`.
 *
 *     area_theatre={ id={ id=4 type=45 }
 *                    front={ provinces={ 3294 3160 3094 } local_enemy="HUN" front=no sea=no }
 *                    front={ ... }
 *                    provinces={ 781 7306 820 864 ... }
 *                    unit={ id=205 type=41 } country="GER" hot=yes }
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CTheatre {
    namespace Offsets {
        /**@brief the theatre's object id, saved as `id`. **Read live**: type 45*/
        constexpr uintptr_t id_type = 0x8;
        constexpr uintptr_t id = 0xC;

        /**
         * **The provinces in the theatre**, a CList of CMapProvince*, saved as one
         * `provinces={ ... }` block of ids. **Read live**: the ids come back in the save's
         * own order - 781, 7306, 820, 864 for the theatre the save calls id 4328 - and the
         * count at +0x38 matches the walk, from 20 provinces to 569.
         */
        constexpr uintptr_t provinces_first = 0x30;
        constexpr uintptr_t provinces_last = 0x34;
        constexpr uintptr_t provinces_count = 0x38;

        /**
         * **A second CList of CMapProvince***, filled by a key the token table calls `key`,
         * through an adder of its own (`0xAFCE0`) rather than the one `provinces` uses.
         *
         * **It cannot survive a save.** `CTheatre::SaveContents` walks this list and the one
         * at +0x30 into a single sorted, deduped `provinces={ ... }` block, so a theatre
         * that is loaded back has everything in the first list and nothing here. That is why
         * no save carries a `key=` line.
         *
         * **Read live**: 3 of 100 theatres hold exactly one province here, and it looks like
         * the theatre's seat - the city it is named for or run from:
         *
         *     theatre 4328  GER  HQ unit `Paris HQ`                 Paris
         *     theatre 80    USA  HQ unit `Pacific High Command`     San Francisco
         *     theatre 81    USA  HQ unit `Eastern Defense Command`  Washington D.C.
         *
         * **It is not where the HQ unit stands**: Paris HQ's unit is in Berlin and Pacific
         * High Command's in Honolulu. The province is in the theatre's own province list in
         * all three cases. Three samples and no reader found, so the name says where it
         * comes from rather than what it is for.
         */
        constexpr uintptr_t key_provinces_first = 0x40;
        constexpr uintptr_t key_provinces_last = 0x44;
        constexpr uintptr_t key_provinces_count = 0x48;

        /**
         * **The fronts**, a CList of CAreaBorder, one `front=` block each - a province list,
         * a `local_enemy` tag, and the `front` and `sea` flags. **Read live**: what the
         * nodes hold is a CAreaBorder by its own RTTI, one to six per theatre, and the count
         * at +0x58 matches the walk.
         */
        constexpr uintptr_t fronts_first = 0x50;
        constexpr uintptr_t fronts_last = 0x54;
        constexpr uintptr_t fronts_count = 0x58;

        /**@brief saved as `hot`. **Read live**: set on 19 of the 100*/
        constexpr uintptr_t hot = 0x70;

        /**@brief the theatre's own unit, an object id, saved as `unit`. **Read live**: type
           41 on every theatre*/
        constexpr uintptr_t unit_type = 0x74;
        constexpr uintptr_t unit_id = 0x78;

        /**@brief whose theatre it is, a CCountryTag, saved as `country`. **Read live**: ENG
           has 11 of them, JAP and VIC 6 each*/
        constexpr uintptr_t country = 0x7C;

        /**@brief the AI's priority for it. **Read live**: 1000 on 54 theatres, 90 on 11, 500
           on 8*/
        constexpr uintptr_t priority = 0xA4;
    }

    namespace VFTable {
        constexpr uintptr_t CTheatre = 0x11C0788;   // module relative, RTTI, 8 slots
    }

    namespace GameFunction {
        constexpr uintptr_t SaveContents = 0xAFDF0;   // slot 2
        constexpr uintptr_t LoadKey = 0xB01F0;        // slot 4
    }
}
