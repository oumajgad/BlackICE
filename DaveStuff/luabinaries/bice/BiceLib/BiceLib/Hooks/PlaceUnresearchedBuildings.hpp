#pragma once

/**
 * Lets a finished building be put in a province whether or not the country has researched
 * it - and asks everything else the game asks.
 *
 * `CBuildingDeployment::CanDeployIn` (`0x17E480`, slot 10 - every way a waiting building is
 * placed comes through it) asks `CCountry::IsBuildingAllowed` (`0xDFFC0`), which refuses six
 * things in order: a building the country has not been given by research; a province it does
 * not control (the underground excepted); the levels there plus those queued reaching
 * `max_level`; a port building without a port; `not_if_x_exists`; a missing prerequisite.
 * **Only the first is waived here**, and only for this one caller.
 *
 * ## The two sites
 *
 * | rva | bytes | what it becomes |
 * | --- | --- | --- |
 * | `0x17E4E0` | `call 0xDFFC0`, in CanDeployIn | a jump to a stub that raises a flag, makes the same call with the same arguments still on the stack, lowers the flag and comes back after the five bytes |
 * | `0xDFFF0` | `cmp byte ptr [eax+edx], 0; jne 0xE000B` - the research test, `technology_status +0x28C [index]` | the same test, passed outright while the flag is up |
 *
 * So the four other callers of IsBuildingAllowed - the Lua API's among them - get the
 * game's answer unchanged, and CanDeployIn gets the game's answer to the five other
 * questions.
 *
 * **Until 2026-11-07 it did far less of the game's asking**: it stood on CanDeployIn's test of
 * the answer and asked only whether the level already there was below `max_level`, so it also
 * let a building into a province the country did not control, past `max_level` with levels
 * queued, and without its port or prerequisites.
 *
 * ## Multiplayer
 *
 * The flag is up only while CanDeployIn runs, on whichever machine runs it, and nothing
 * local decides anything, so every machine answers alike.
 *
 * reversing/findings/FINDINGS-bicelibsites.md, section 7.
 *
 * **Switched on from Lua**: `BiceLib.ComplexPatches.enablePlacingNonResearchedBuildings()`.
 */
namespace Hooks {
    namespace PlaceUnresearchedBuildings {
        /**@brief hooks both sites, once; safe to call again*/
        bool install();

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
