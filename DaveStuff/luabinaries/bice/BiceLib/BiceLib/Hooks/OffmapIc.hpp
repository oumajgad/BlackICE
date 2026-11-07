#pragma once
#include <cstdint>

/**
 * Takes the `local_ic` part out of a country's base IC and adds its offmap IC back once.
 *
 * `CCountry::UpdateIC` (`0xF0CC0`), once a day per country, sums over its provinces each
 * one's base IC times `1 + local_ic` - the province modifier's `IC` and `LOCAL_IC` entries,
 * in thousandths - and stores the sum, in whole IC, in `CCountry::Offsets::total_ic`.
 *
 * ## The two hooks
 *
 * | rva | replaced | what is in hand |
 * | --- | --- | --- |
 * | `0xF0F22` | `mov ecx, [esi+0x330]` | one province's term (EAX), the province (ESI), the country (EBX). What `local_ic` added to the term is put by for the country |
 * | `0xF0F9D` | `mov [ebx+0x604], eax` | the sum about to be stored (EAX), the country (EBX). What was put by comes off, and offmap IC goes on |
 *
 * Offmap IC is worked out as `global IC / 1000 - (sum - local part / 1000)`, with global IC
 * the `IC` entry of the country's global modifier; it is kept per country for the overlay
 * and also written back into that entry, as `offmap * 1000`. The stored total is then
 * `sum + offmap`.
 *
 * Both replay the instruction they replace and resume after it.
 * reversing/findings/FINDINGS-bicelibsites.md, section 2, has the registers.
 *
 * ## Multiplayer
 *
 * Inside the daily pass every machine runs, from the country's own figures.
 *
 * **Switched on from Lua**: `BiceLib.ComplexPatches.fixOffMapIC()`.
 */
namespace Hooks {
    namespace OffmapIc {
        /**@brief hooks both sites, once; safe to call again*/
        bool install();

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();

        /**@brief the offmap IC the last daily pass worked out for the country, in whole IC*/
        int offmapIc(uintptr_t country);
    }
}
