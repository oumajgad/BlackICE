#pragma once

/**
 * Ctrl in the "unassign all leaders" confirmation makes it unassign only the leaders of
 * the units that are currently selected.
 *
 * The button in the leader assignment window raises the `CONFIRM_REMOVEAll` dialog, and
 * confirming it builds a `CRemoveAllLeadersCommand` for the played country and posts it.
 * That command carries a country and nothing about units: its `Execute` walks the whole
 * unit list and assigns `CLeader::null()` to each one.
 *
 * **So the choice is made where the command is built, not where it runs**, and that is
 * the whole design. The hook sits on the post in the dialog's own handler - which only
 * ever executes on the machine whose player clicked - and when Ctrl is held it posts one
 * `CAssignLeaderCommand(unit, CLeader::null())` per selected unit instead of the
 * country-wide command. What then travels between clients is an explicit list of units,
 * so every client does the same thing.
 *
 * **Tested in multiplayer, 2026-10-04, and it holds.** That is the observation the design
 * rests on rather than an argument from the code: the command keeps each end as a
 * `CPersistent` id pair rather than a pointer, which is what lets every client resolve the
 * same units. Also confirmed in that session: the selection survives the leader assignment
 * window being open, which is what the per-unit path needs in order to have anything to
 * act on.
 *
 * An earlier version filtered inside `CRemoveAllLeadersCommand::Execute` instead. That
 * was wrong and is worth recording: `Execute` runs on *every* client, while the Ctrl key
 * and the selection are local to one machine, so it stripped a subset on the client that
 * pressed the button and everything everywhere else. No test inside `Execute` can fix
 * that, because the command does not carry what was selected.
 *
 * With Ctrl up the stub is the five instructions it replaced and nothing else runs.
 *
 * Only valid for this build of hoi3_tfh.exe.
 */
namespace Hooks {
    namespace UnassignSelected {
        /**
        @brief patch the command post in CConfirmRemoveAll's confirm handler

        Verifies the eleven bytes it is about to replace before writing anything, so a
        build this does not fit leaves the game untouched rather than half patched.

        @return whether the hook is in place
        */
        bool install();

        /**@brief whether install() wrote the hook*/
        bool installed();

        /**@brief one line for the overlay: installed, or why not*/
        const char* status();

        /**
        @brief turn the Ctrl behaviour on or off

        While this is off the stub reproduces the instructions it replaced and no C of
        ours runs at all, which is the only way to be sure a feature switched off cannot
        disturb a register or a flag.
        */
        void setActive(bool on);

        /**@brief whether the Ctrl behaviour is on*/
        bool active();

        /**@brief the naked stub - installed by install(), never called directly*/
        void postHook();
    }
}
