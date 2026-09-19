#pragma once
#include <cstdint>

/**
 * CWar - one war, who is on each side, and what it is being fought over.
 *
 * The game state keeps three lists of them: `active_war`, `previous_war` and, for the
 * separate `CUndeclaredWar`, `undeclared_war`. **Read live**: 19 wars in a 1942 game.
 *
 * Named from `CWar::SaveContents` (`0x64EC90`) and `CWar::LoadKey` (`0x64E610`) - see
 * CPersistent.hpp - and read back out of the running game, where the sides come out as the
 * tags you would expect: the War of Italian Aggression is `ITA` against `FRA`, `ENG`, `OMN`
 * and twenty-five more.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CWar {
    namespace Offsets {
        /**@brief saved as `revolutionary_war`, and read straight off whether the value
           token is `yes`*/
        constexpr uintptr_t revolutionary_war = 0x8;

        /**@brief a game tick, saved as `action` and written as a date. **Read live**:
           60815253, which is 1942-05-19, on most of the wars in a 1942 game*/
        constexpr uintptr_t action = 0xC;

        /**@brief the war's name, a std::string, saved as `name`. **Read live**: `War of
           Italian Aggression`, `2nd War of German Aggression`, `Chinese Civil War`*/
        constexpr uintptr_t name = 0x10;

        /**
         * **The two sides**, each a `std::vector<CCountryTag>`: begin, end, and the end of
         * the capacity. One `attacker=` or `defender=` line per entry.
         *
         * **Read the end at +0x30 and +0x40, not the capacity** - the two are equal on some
         * wars and not on others, and reading the capacity hands back stale tags past the
         * end. BiceLib had the two begins named already; the rest is new.
         */
        constexpr uintptr_t attackers = 0x2C;
        constexpr uintptr_t attackers_end = 0x30;
        constexpr uintptr_t attackers_capacity = 0x34;
        constexpr uintptr_t defenders = 0x3C;
        constexpr uintptr_t defenders_end = 0x40;
        constexpr uintptr_t defenders_capacity = 0x44;

        /**@brief a CWarHistory held by value - the war's own object, saved as `history` by
           calling its Load and Save. **Read live**: a CWarHistory by its own RTTI, and it
           carries CPersistent's vftable and token like any other*/
        constexpr uintptr_t history = 0x4C;

        /**@brief saved as `limited`. **Read live**: set on all 19 wars in the game*/
        constexpr uintptr_t is_limited = 0x70;

        /**@brief CCountryTags, saved as `target`, `original_attacker` and
           `original_defender`. **Read live**: all three are the no-country tag `---` on
           every war in the game, so what sets them has not been seen*/
        constexpr uintptr_t target = 0x84;
        constexpr uintptr_t original_attacker = 0x8C;
        constexpr uintptr_t original_defender = 0x94;
    }

    namespace VFTable {
        constexpr uintptr_t CWar = 0x11FBE78;   // module relative, RTTI, 6 slots
    }

    namespace GameFunction {
        constexpr uintptr_t SaveContents = 0x64EC90;   // slot 2
        constexpr uintptr_t LoadKey = 0x64E610;        // slot 4

        /**@brief adds a country to the attackers: `(CWar* war, int, int, char tag[4], int
           id)`. The loader calls it for every `attacker=` line*/
        constexpr uintptr_t AddAttacker = 0x64F220;

        /**@brief the same for the defenders*/
        constexpr uintptr_t AddDefender = 0x6506B0;
    }
}

/**
 * CWarGoal - what one country wants out of a war. A war carries a list of them, one
 * `war_goal=` block each, and the game holds 262 in a 1942 game.
 *
 * BiceLib had four of its five fields from the Lua API; the loader
 * (`CWarGoal::LoadKey`, `0x79A90`) adds the fifth and confirms the rest.
 */
namespace CWarGoal {
    namespace Offsets {
        /**@brief **what the goal is**, a CCasusBelliType*, saved as `casus_belli` by its
           key. The loader looks the name up and falls back to indexing the list by number.
           **Read live**: a CCasusBelliType on 259 of 262 goals and a CNullCasusBelliType on
           one*/
        constexpr uintptr_t casus_belli = 0xC;

        constexpr uintptr_t country = 0x10;     // saved as `country`, a CCountryTag
        constexpr uintptr_t actor = 0x18;       // saved as `actor`
        constexpr uintptr_t recipient = 0x20;   // saved as `receiver`
        constexpr uintptr_t region = 0x28;      // saved as `region`, a CRegion* by name
    }

    namespace VFTable {
        constexpr uintptr_t CWarGoal = 0x11BDB34;
    }

    namespace GameFunction {
        constexpr uintptr_t SaveContents = 0x7A7A0;
        constexpr uintptr_t LoadKey = 0x79A90;
    }
}

/**
 * CUndeclaredWar - two countries fighting without a war, which is how the game models the
 * American escort war before 1941. **Read live**: one of them, `USA` against `GER`.
 */
namespace CUndeclaredWar {
    namespace Offsets {
        /**@brief the two sides, each a vector of CCountryTag again, begin and end*/
        constexpr uintptr_t attackers = 0x8;
        constexpr uintptr_t attackers_end = 0xC;
        constexpr uintptr_t defenders = 0x18;
        constexpr uintptr_t defenders_end = 0x1C;
    }

    namespace VFTable {
        constexpr uintptr_t CUndeclaredWar = 0x11BD6E4;
    }

    namespace GameFunction {
        constexpr uintptr_t SaveContents = 0x75E70;
        constexpr uintptr_t LoadKey = 0x75A60;
        constexpr uintptr_t AddAttacker = 0x76040;   // (this, tag, id)
        constexpr uintptr_t AddDefender = 0x761C0;
    }
}

/**@brief CCasusBelliType - a kind of war goal, as the mod's files spell it*/
namespace CCasusBelliType {
    namespace Offsets {
        /**@brief the key, a std::string. **Read live**: `oder_neisse_line`,
           `china_war_goal`, `occupation_japan`*/
        constexpr uintptr_t key = 0x14;
    }
}
