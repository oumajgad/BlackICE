#pragma once

/**
 * Whether the division being designed can be paradropped, on the designer's terrain tooltip.
 *
 * The division designer says nothing about it anywhere, and the brigade picker's lines have
 * no tooltip at all in the original. So the one tooltip the designer has room in -
 * `terrainbonus`, the terrain summary - starts with a line saying so:
 *
 *     This unit can be paradropped
 *
 * or, with the brigades that stop it listed under it, each once, in the design's order:
 *
 *     This unit can not be paradropped:
 *        Artillery
 *        Engineers
 *
 * with only "can" and "can not" coloured, green and red.
 *
 * ## The rule
 *
 * `CAir::MayLoad`, the game's own test for putting a land unit aboard a transport plane,
 * wants **every brigade** to have `can_paradrop` (`CSubUnitDefinition + 0x38`). Its other two
 * tests - organisation at `PARATROOP_MISSION_ORG_REQ` of the maximum, and the weight fitting
 * the plane - are about a unit that exists and a plane that carries it, so a design on paper
 * has nothing to answer them with. See reversing/findings/FINDINGS-transport.md, D.2.
 *
 * ## Where
 *
 * `CDivisionDesigner::BuildTooltip` (`0x3EA930`) answers `terrainbonus` with five
 * instructions: push the designer's terrain text (`+0x1D4`), `call` the game's string assign
 * into the tooltip in EBX, and jump to the epilogue. That `call`, at `0x3EA9DB`, is replaced:
 * the stub makes it exactly as it was, then puts the line in front of what it copied. The
 * designer is still in `[ebp - 0x14]` there. The design is the `CList` at `+0x1B4`, of
 * `CSubUnitDefinition*` - `UpdateDesign` reads each node's combined arms group off it. See
 * reversing/findings/FINDINGS-buildertooltips.md, sections 2 and 6.
 *
 * **An empty design adds nothing**: its terrain text is empty and the game shows no tooltip
 * for it, which a line of ours would undo.
 *
 * **Switched on from Lua**: `BiceLib.Tooltips.activateParadropLine()`.
 */
namespace Hooks {
    namespace Tooltips {
        namespace ParadropLine {
            /**@brief patches the call, once; safe to call again*/
            bool install();

            bool installed();

            /**@brief why it is not installed, when it is not*/
            const char* status();
        }
    }
}
