#pragma once
#include <cstdint>

/**
 * CFaction - one of the game's three alliances, and CMinister - one cabinet post.
 *
 * Both named from their own `LoadKey` - `CFaction::LoadKey` (`0x1227E0`) and
 * `CMinister::LoadKey` (`0x12C630`) - and read back out of the running game.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CFaction {
    namespace Offsets {
        /**@brief the faction's tag, saved as `tag`. **Read live**: the game holds exactly
           three - `axis`, `alli` and `comi`*/
        constexpr uintptr_t tag = 0xC;

        /**@brief the members, a list of CCountryTag, one `country=` line each*/
        constexpr uintptr_t members = 0x28;

        /**@brief saved as `icon`. **Read live**: nothing readable as a string on any of the
           three, so what it holds has not been settled*/
        constexpr uintptr_t icon = 0x3C;

        /**@brief an object of its own, loaded through its vtable, saved as `rule`*/
        constexpr uintptr_t rule = 0x40;

        /**@brief an object of its own, loaded through its vtable, saved as `modifier`*/
        constexpr uintptr_t modifier = 0x7C;

        /**@brief saved as `progress`, x1000. **Read live**: 860.0 for the axis, 686.0 for
           the allies, 182.0 for the comintern*/
        constexpr uintptr_t progress = 0xAC;

        /**@brief saved as `neutrality`, x1000. **Read live**: 25.0 for the axis and zero for
           the other two*/
        constexpr uintptr_t neutrality = 0xB0;

        /**@brief a std::string, saved as `influence`. **Read live**: `align_towards_axis`,
           `align_towards_allies`, `align_towards_comintern` - the decision each faction
           pulls countries with*/
        constexpr uintptr_t influence = 0xBC;
    }

    namespace VFTable {
        constexpr uintptr_t CFaction = 0x11C2430;     // module relative, RTTI, 8 slots
    }

    namespace GameFunction {
        constexpr uintptr_t SaveContents = 0x123400;  // slot 2
        constexpr uintptr_t LoadKey = 0x1227E0;       // slot 4
    }
}

/**
 * CMinister - one minister a country can appoint. **Read live**: 6257 of them.
 *
 * **It is never written to a save**: its slot 2 is the shared empty `ret 4`, so the class is
 * read out of the mod's files and only ever referenced afterwards. Its loader is the file
 * parser, which is what names the fields below.
 */
namespace CMinister {
    namespace Offsets {
        /**@brief the minister's name, a std::string, read from `name`. **Read live**:
           `Alfred Rosenberg`, `Thomas Mann`*/
        constexpr uintptr_t name = 0x30;

        /**@brief a game tick, read from `start_date` - when the minister becomes available*/
        constexpr uintptr_t start_date = 0x54;

        /**@brief a game tick, read from `death_date`*/
        constexpr uintptr_t death_date = 0x58;

        /**@brief his ideology, read from `ideology`*/
        constexpr uintptr_t ideology = 0x6C;

        /**@brief read from `loyalty`, x1000. **Read live**: 1000 or 750*/
        constexpr uintptr_t loyalty = 0x70;

        /**@brief his portrait, a std::string, read from `picture`. **Read live**: `M57`,
           `M64`, `M82`*/
        constexpr uintptr_t picture = 0x74;
    }

    namespace VFTable {
        constexpr uintptr_t CMinister = 0x11C2AB4;    // module relative, RTTI, 9 slots
    }

    namespace GameFunction {
        constexpr uintptr_t LoadKey = 0x12C630;       // slot 4; slot 2 is the empty `ret 4`
    }
}
