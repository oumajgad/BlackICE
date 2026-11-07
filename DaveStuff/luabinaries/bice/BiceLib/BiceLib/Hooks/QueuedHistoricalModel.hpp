#pragma once

/**
 * Makes `historical_model` on a queued line build every technology at the model's level.
 *
 * A brigade of a `military_construction` given `historical_model = N` has its model list
 * filled by walking the unit type's technologies and appending the level of each one the
 * model names - and **nothing for one it does not**. The list is later handed out by
 * position, so every level after a gap lands on the technology before the one meant, and
 * the type's last technologies get none. A model read from units/models names only what
 * its file names, so most of them have gaps. On the map the same model is applied by
 * technology, which is why the same model is right there and wrong in the queue.
 *
 * This appends a 0 for a technology the model does not name, which is what the map gives
 * it, so the list is as long as the type's technologies and every level is in its place.
 *
 * One five byte jump at rva `0x83020`, over `cmp eax, [esi+0x18]; jae 0x82FF1` in
 * `CBrigadeConstructionDefinition::LoadKey`, to a stub that does that test itself; nothing
 * jumps into those five bytes, and the loop's exit restores esi. The search it ends and the
 * append it borrows are checked too, before anything is written.
 * reversing/findings/FINDINGS-buildqueue.md, section 10, has the reading.
 *
 * **Switched on from Lua**: `BiceLib.ComplexPatches.fixQueuedHistoricalModel()`.
 */
namespace Hooks {
    namespace QueuedHistoricalModel {
        /**@brief hooks the test, once; safe to call again*/
        bool install();

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
