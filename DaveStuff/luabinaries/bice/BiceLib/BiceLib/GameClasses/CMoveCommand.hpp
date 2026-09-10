#pragma once
#include <cstdint>

/**
 * CMoveCommand - "move this unit there", as it is sent between the machines of a
 * multiplayer game.
 *
 * The command's slot 6 (`0x5D88C0`) routes the unit when the command runs and hands it
 * the path (`Find` at `0x5D8F08`, then `SetUnitPath` at `0x5D8F1C`). That much is read off
 * the code.
 *
 * **What it is not known to do is decide a strategic redeployment's route.** Replacing
 * the very safe finder's step cost here - and in CStrategicRedeploymentOrder's re-route,
 * the only other place that finder is built - changed nothing about the route a
 * redeploying unit took, in two tests in the game at the heaviest weighting. So either the
 * route comes from somewhere else, or slot 0 is not what decides it. See
 * reversing/FINDINGS-redeploy.md; the approach was judged by the person testing it to
 * have misread the problem.
 *
 * Which of three finders slot 6 uses comes from three bytes on the command, set by the
 * constructor and copied by the copy constructor:
 *
 *     +0x6A set   CVerySafePathFind    the finder strategic redeployment re-routes with
 *     +0x69 set   CSafePathFind
 *     neither     CPathFind
 *
 * Copied by the copy constructor, which suggests they travel with the command between
 * machines. Not checked.
 *
 * `+0x68` picks between two ways of routing that end in the same Find call with the same
 * choice of finder; every player move sets it.
 *
 * **Who sets "very safe" is not settled.** The GUI reaches the command through `0x89A840`,
 * which forwards its fifth argument as `+0x6A`. Of its 26 callers, 13 pass 1 - always
 * together with "safe". That may be one window handling each kind of order, or it may
 * mean the game routes ordinary moves very safely too.
 *
 * Only valid for this build of hoi3_tfh.exe. Module relative.
 */
namespace CMoveCommand {
    namespace VFTable {
        constexpr uintptr_t CMoveCommand = 0x11C8C1C;
    }

    namespace Slots {
        constexpr int ROUTE_UNIT = 6;
    }

    namespace Offsets {
        constexpr uintptr_t target_province = 0x64;   // province id
        constexpr uintptr_t mode_68 = 0x68;           // bool
        constexpr uintptr_t safe = 0x69;              // bool
        constexpr uintptr_t very_safe = 0x6A;         // bool
    }

    namespace GameFunction {
        /**@brief slot 6: works the unit's route out and gives it to the unit*/
        constexpr uintptr_t RouteUnit = 0x1D88C0;

        /**
        @brief CMoveCommand(a, target, mode68, safe, verySafe), ret 0x14

        Also 0x1D86F0, which leaves everything zero, and 0x1D93F0, which copies.
        */
        constexpr uintptr_t Construct = 0x1D87F0;

        /**@brief what the GUI calls; forwards its fourth and fifth arguments as safe and very safe*/
        constexpr uintptr_t IssueFromInterface = 0x49A840;
    }

    namespace Sites {
        /**
        @brief where RouteUnit puts its three finders on the stack, before choosing one

            0x1D8A96   C7 44 24 20 <imm32>   CPathFind
            0x1D8A9E   C7 44 24 1C <imm32>   CSafePathFind
            0x1D8AA6   C7 44 24 18 <imm32>   CVerySafePathFind

        A finder is only its vftable, so each of these four byte immediates is the whole
        of a finder. Repointing the very safe one was tried and removed; see the file
        comment.
        */
        constexpr uintptr_t PICK_VERY_SAFE = 0x1D8AA6;
        constexpr uintptr_t PICK_VERY_SAFE_IMMEDIATE = 0x1D8AAA;
    }
}
