#pragma once

/**
 * Lets a finished building be put in a province whatever the country has researched, up to
 * the building's `max_level`.
 *
 * `CBuildingDeployment::CanDeployIn` (`0x17E480`) asks `CCountry::IsBuildingAllowed`
 * (`0xDFFC0`) and refuses on a false - `test al, al; je 0x17E5B7` at `0x17E4E5`, eight
 * bytes. The hook stands on that test and **asks its own question in place of the game's**:
 * whether the province's `level_max` is below the building's `max_allowed_level`. EDI is the
 * deployment, EBX the province. True resumes at `0x17E4ED`, after the test; false goes where
 * the `je` went.
 *
 * ## What it skips besides the research
 *
 * `IsBuildingAllowed` asks more than whether the building is researched, and the hook
 * answers none of it: for any building but the underground, that **the country controls
 * the province**; that the levels there **plus those queued** for it stay within
 * `max_level`; that a port building has a port; `not_if_x_exists`; prerequisites.
 *
 * So as written it allows a building in a province the country does not control, past
 * `max_level` while a construction for the province is queued, and without its port or
 * prerequisites, as far as the deploy menu lets it be tried. Kept exactly as the hook did
 * it before; whether it should is the maintainer's call.
 *
 * reversing/findings/FINDINGS-bicelibsites.md, section 7.
 *
 * **Switched on from Lua**: `BiceLib.ComplexPatches.enablePlacingNonResearchedBuildings()`.
 */
namespace Hooks {
    namespace PlaceUnresearchedBuildings {
        /**@brief hooks the test, once; safe to call again*/
        bool install();

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
