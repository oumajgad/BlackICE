#pragma once
#include <cstdint>

/**
 * CStrategicRedeploymentOrder - a unit taken off the map and moved by rail and road.
 *
 * Derives from COrder. How it routes the unit is one helper, `0x588700`, called from the
 * order's own virtual methods - slots 13 and 14, from three call sites. That helper
 * takes the order in edi, not ecx: the unit at +8, the province it is going to at +0xC.
 *
 * When the unit is due its next step the helper first checks the unit's path, and
 * returns without routing when the path's first entry is the province the unit is going
 * to. That early return is what keeps a route the player painted by hand, and is wanted.
 * Only when it falls through does this build a CVerySafePathFind on the stack, route, and
 * hand the result to the unit (`0x5C9AC0`). All read off the code.
 *
 * **Where a redeployment's route actually comes from is not known.** Replacing the very
 * safe finder's step cost here changed nothing in a game; replacing it in CMoveCommand as
 * well changed nothing either. See reversing/FINDINGS-redeploy.md.
 *
 * Only valid for this build of hoi3_tfh.exe. Module relative.
 */
namespace CStrategicRedeploymentOrder {
    namespace VFTable {
        constexpr uintptr_t CStrategicRedeploymentOrder = 0x11C5ADC;   // 35 slots
    }

    namespace GameFunction {
        /**@brief routes the unit; the order in edi, answering a bool*/
        constexpr uintptr_t RouteUnit = 0x188700;

        /**@brief gives a found route to a unit: (unit, path, 1)*/
        constexpr uintptr_t SetUnitPath = 0x1C9AC0;
    }

    namespace Sites {
        /**
        @brief the instruction that picks the finder

            0x1887FE   C7 44 24 14 <imm32>    mov dword ptr [esp+14h], imm32

        The immediate is CPathFind::VFTable::CVerySafePathFind plus the module base. The
        executable references that table twice: this, and CMoveCommand's route planner
        (CMoveCommand::Sites::PICK_VERY_SAFE), which is where routes actually come from.
        */
        constexpr uintptr_t PICK_FINDER = 0x1887FE;
        constexpr uintptr_t PICK_FINDER_IMMEDIATE = 0x188802;
    }
}
