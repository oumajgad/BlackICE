#pragma once

/**
 * Keeps a province's `MaxInfrastructure` the figure of its `infra` building, whatever
 * other building with the `infrastructure` effect it has.
 *
 * ## The problem
 *
 * `CMapProvince +0x5C` is what areas are made from - a province belongs to one only above
 * 100, one level - and areas are what the supply network groups and the AI's theatres and
 * fronts are built on. The game writes it in three places, and **every one of them writes
 * the figure of whichever infrastructure building it is handling, with no comparison**:
 *
 *  - `CProvince::LoadKey`, for each such building in a saved province (`0x96152`);
 *  - `SetProvinceBuildingLevel`, the building effect (`0xA3B0A`);
 *  - `CProvinceBuilding_OnLevelChanged`, a finished construction (`0xB8024`).
 *
 * With one such building in the base game nothing could go wrong. BlackICE's `extra_infra`
 * (`infrastructure = 0.05`) is a second, written after `infra` in every save, so a loaded
 * province reads `extra_infra`'s level x 50: Shanghai, infra 8, came back as 50. Areas are
 * made from scratch only as a game is entered, so a load put 1,603 provinces of a 1937 save
 * in no area at all - and the AI's daily sealift pass reads the first province of the empty
 * null area for any unit bound for one, which crashed the game as the save loaded.
 * reversing/findings/FINDINGS-extrainfra.md has the reading and the dump.
 *
 * ## The patch
 *
 * **At each of the three stores**, a jump to a stub that lets the store happen and then
 * writes `infra`'s level x its figure / 1000 over it - LoadKey's own formula, read off
 * `infra`'s entry in the province's building array. So the figure is the base game's in
 * every path, and the areas the game makes from it come out as they would without
 * `extra_infra`. `extra_infra` still adds to the effective infrastructure, which the game
 * works out separately from the province's modifiers.
 *
 * `SetProvinceBuildingLevel` then tests the new figure to decide whether a province in no
 * area joins one; the stub hands it the corrected figure, not the overwritten one.
 *
 * `infra` is found by name in the province's building array the first time a store is
 * reached. If no building is called `infra` the stubs leave the game's figure alone.
 *
 * ## Multiplayer
 *
 * It reads only the province's own buildings, inside the load and the effects every machine
 * runs, so every machine writes the same figure. Switched on from `script/bicelib_lua.lua`,
 * where it has to be before a save is loaded.
 *
 * **Switched on from Lua**: `BiceLib.ComplexPatches.fixMaxInfrastructure()`.
 */
namespace Hooks {
    namespace MaxInfrastructure {
        /**@brief patches the three stores, once; safe to call again*/
        bool install();

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
