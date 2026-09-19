#pragma once
#include <cstdint>

/**
 * CRebelFaction - one partisan or rebel group: who it is, who it is against, and where.
 *
 * The game state keeps them in the list at `CCurrentGameState::Offsets::rebel_factions`, and
 * hands each a running id from `CCurrentGameState::Global::rebel_id`.
 *
 * Named from `CRebelFaction::SaveContents` (`0xB91C0`) and `CRebelFaction::LoadKey`
 * (`0xB9420`) - see CPersistent.hpp - and checked against a `rebel_faction=` block in a save
 * and against the running game, which held the same faction:
 *
 *     rebel_faction={ id={ id=953 type=39 } type="nationalist_rebels"
 *                     name="Chinese Nationalists" country="JAP" target="JAP"
 *                     independence="CHI" government="imperial" province=5448
 *                     army={ id=954 type=39 } provinces={ 5448 } }
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CRebelFaction {
    namespace Offsets {
        /**@brief the faction's object id, saved as `id`; the type half is first in memory
           and second in the save, as everywhere else. **Read live**: type 39*/
        constexpr uintptr_t id_type = 0x8;
        constexpr uintptr_t id = 0xC;

        /**@brief what kind of rebels these are, a CRebelType*, saved as `type` by its key.
           **Read live**: a CRebelType by its own RTTI, and the mod defines six -
           disgruntled_rabble, fascist_rebels, nationalist_rebels, organized_partisans,
           partisans, patriot_rebels*/
        constexpr uintptr_t type = 0x30;

        /**@brief where they are, a CMapProvince*, saved as `province` by writing that
           province's id. **Read live**: a CMapProvince*/
        constexpr uintptr_t province = 0x34;

        /**@brief **whose country they are rising in**, a CCountryTag, saved as `country`*/
        constexpr uintptr_t country = 0x38;

        /**@brief the government they would install, a CGovernment*, saved as `government`.
           **Read live**: a CGovernment by its own RTTI; the mod defines eighteen, from
           absolute_monarchy to socialist_republic*/
        constexpr uintptr_t government = 0x40;

        /**@brief **who they want the province to end up as**, a CCountryTag, saved as
           `independence` - `CHI` for the Chinese Nationalists inside Japan*/
        constexpr uintptr_t independence = 0x44;

        /**@brief their name, a std::string, saved as `name`*/
        constexpr uintptr_t name = 0x54;

        /**
         * **Who they are fighting**, a CCountryTag per entry and one `target=` line each.
         * The nodes are 20 bytes: the tag's four characters, its id, the previous node, the
         * next and a spare. **Read live**: one target, `JAP`.
         */
        constexpr uintptr_t targets_first = 0x70;
        constexpr uintptr_t targets_last = 0x74;
        constexpr uintptr_t targets_count = 0x78;

        /**
         * **The armies they have in the field**, an object id per entry and one `army=`
         * block each, nodes of the same 20-byte shape. **Read live**: none on the faction
         * in the running game, one in the save it came from.
         */
        constexpr uintptr_t armies_first = 0x80;
        constexpr uintptr_t armies_last = 0x84;
        constexpr uintptr_t armies_count = 0x88;

        /**@brief the provinces they claim, saved as one `provinces={ ... }` block of ids; a
           vector, so begin here and end at +0x98*/
        constexpr uintptr_t provinces = 0x94;
        constexpr uintptr_t provinces_end = 0x98;
    }

    namespace VFTable {
        constexpr uintptr_t CRebelFaction = 0x11C0B6C;  // module relative, RTTI, 8 slots
    }

    namespace GameFunction {
        constexpr uintptr_t SaveContents = 0xB91C0;     // slot 2
        constexpr uintptr_t LoadKey = 0xB9420;          // slot 4
    }
}

/**@brief CRebelType - a kind of rebel, as `common/rebel_types.txt` spells it*/
namespace CRebelType {
    namespace Offsets {
        /**@brief the type's key, a std::string - `nationalist_rebels`. **Read live**: six
           of them in this mod*/
        constexpr uintptr_t key = 0xC;
    }
}

/**@brief CGovernment - a government a country or a rebel faction can have*/
namespace CGovernment {
    namespace Offsets {
        /**@brief the government's key, a std::string - `imperial`, `social_democracy`.
           **Read live**: eighteen of them in this mod*/
        constexpr uintptr_t key = 0x44;
    }
}
