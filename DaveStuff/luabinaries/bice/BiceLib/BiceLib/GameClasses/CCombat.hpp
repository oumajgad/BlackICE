#pragma once
#include <cstdint>

/**
 * CCombat - one fight in one province, and CCombatant, one side of it.
 *
 * A land battle, a naval battle, an air battle and the three kinds of bombing raid are
 * each a class of their own deriving from CCombat, and each builds its own kind of
 * CCombatant for the two sides. **Every field here is on the base classes**, so the same
 * offsets read all six: the game's own history entry is filled from a plain `CCombat*`
 * without dispatching on the kind, and every combatant runs the base constructor.
 *
 * The combats going on are listed in the CCombatManager; the game hands a combat that
 * has just ended to the function GameState/CombatLog hooks. How the layout was found is
 * in reversing/FINDINGS-combat.md.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace CCombat {
    /**
     * Which kind a combat is, by the vftable at its start, module relative (RTTI). Each
     * also carries its CSelectable base's vftable at +0x8, which never appears at the
     * start of one.
     */
    namespace VFTable {
        constexpr uintptr_t CCombat = 0x11C4D14;          // abstract
        constexpr uintptr_t CLandCombat = 0x11C4EE4;
        constexpr uintptr_t CNavalCombat = 0x11C4F5C;
        constexpr uintptr_t CAirCombat = 0x11C4FD4;
        constexpr uintptr_t CGroundBombing = 0x11B6934;
        constexpr uintptr_t CLandBombing = 0x11B69AC;
        constexpr uintptr_t CNavalBombing = 0x11B6A24;
    }

    namespace Slots {
        /**
         * **The kind**, as Kind below: pure virtual on CCombat, and every kind overrides
         * it with a constant (`mov eax, N; ret`). Comparing vftables comes to the same
         * answer without a call.
         */
        constexpr int KIND = 11;
    }

    /**@brief what slot KIND answers, the game's own numbering*/
    enum Kind : int {
        LAND = 1,
        NAVAL = 2,
        AIR = 3,
        GROUND_BOMBING = 4,
        LAND_BOMBING = 5,
        NAVAL_BOMBING = 6,
    };

    namespace Offsets {
        /**@brief the two sides, each a CCombatant of the kind this combat builds*/
        constexpr uintptr_t attacker = 0x10;
        constexpr uintptr_t defender = 0x14;

        /**@brief the CMapProvince fought over*/
        constexpr uintptr_t province = 0x18;

        /**
         * Two ints that tracked each other - 3 and 3 in one battle, 2 and 2 in another.
         * `DaveStuff/mem` calls them day and duration, which those values do not fit.
         * What they are is not known.
         */
        constexpr uintptr_t unknown_1c = 0x1C;
        constexpr uintptr_t unknown_20 = 0x20;

        /**@brief the CTerrain fought on; from DaveStuff/mem*/
        constexpr uintptr_t terrain = 0x24;

        /**@brief a byte the game's history entry keeps a copy of; what it means is not known*/
        constexpr uintptr_t flag = 0x2B;
    }
}

namespace CCombatant {
    /**@brief module relative, RTTI; which a combat builds is read off its slot 6*/
    namespace VFTable {
        constexpr uintptr_t CCombatant = 0x11C4CA4;
        constexpr uintptr_t CLandCombatant = 0x11C4DFC;          // CLandCombat
        constexpr uintptr_t CNavalCombatant = 0x11C4D8C;         // CNavalCombat
        constexpr uintptr_t CAirCombatant = 0x11C4E74;           // CAirCombat
        constexpr uintptr_t CGroundTargetCombatant = 0x11C464C;  // CGroundBombing
        constexpr uintptr_t CLandTargetCombatant = 0x11C472C;    // CLandBombing
        constexpr uintptr_t CNavalTargetCombatant = 0x11C46BC;   // CNavalBombing
        constexpr uintptr_t CBomberCombatant = 0x11C45DC;        // not built by CAirCombat
    }

    /**
     * The base constructor, which every kind of combatant runs: the object and a byte on
     * the stack, with the combat in ecx. It sets up every field below, sizing the three
     * per subunit type vectors to one entry per subunit type there is.
     */
    constexpr uintptr_t Construct = 0x164550;

    namespace Offsets {
        /**@brief back to the CCombat this side is fighting in*/
        constexpr uintptr_t combat = 0x3C;

        /**
         * The units on this side, by `DaveStuff/mem`. The constructor sets it up as a list
         * (HDS::ListOffsets), not the vector mem took it for. Not read by BiceLib.
         */
        constexpr uintptr_t units = 0x40;

        /**
         * **The countries still in the fight on this side**, a list (HDS::ListOffsets)
         * whose nodes hold a CCountryTag at their start. The game's history entry takes
         * its tag from the first node, and writes `---` when the count is zero - which
         * is what it is on the side that lost, since its units are gone from the fight.
         */
        constexpr uintptr_t countries = 0x54;

        /**
         * **This side's own countries**, a list in the same layout that is **kept** when
         * the one above is emptied - so on the beaten side it is the only thing that
         * still names it.
         */
        constexpr uintptr_t own_countries = 0x64;

        /**
         * **The men on this side, per subunit type**: a std::vector of ints (begin, end,
         * capacity), indexed by CSubUnitDefinition::Offsets::index, each a headcount in
         * thousandths. Summed over a thousand it is the "out of 25700 troops" the battle
         * message prints, which is built exactly that way at `0x1745F4`. Only men in a
         * land or naval fight: an air combat counts subunits here, a bombing raid leaves
         * it empty.
         */
        constexpr uintptr_t men_begin = 0x74;
        constexpr uintptr_t men_end = 0x78;

        /**
         * **Strength lost, in thousandths**: the battle message prints this over a
         * thousand as its casualties, and a subunit destroyed outright adds exactly 1000.
         */
        constexpr uintptr_t losses = 0x84;

        /**
         * **Subunits destroyed, per subunit type**, the same shape as the men: 1000 per
         * one destroyed. Not read by BiceLib.
         */
        constexpr uintptr_t destroyed_begin = 0x88;
        constexpr uintptr_t destroyed_end = 0x8C;

        /**@brief damage short of destruction, per subunit type, the same shape; not read*/
        constexpr uintptr_t damage_begin = 0x98;
        constexpr uintptr_t damage_end = 0x9C;
    }
}
