#pragma once

/**
 * Lets a **played** country set its own daily conversion of energy into crude oil and of
 * crude oil into fuel, through country variables, where the game decides both from its IC
 * and from thresholds no file can move. A country nobody plays converts as the game does.
 *
 * ## What the game does
 *
 * Both run once a day in the country's daily pass, energy first. All hardcoded but the
 * yields, which technology and the `FUEL_CONVERSION` modifier move.
 *
 * - **Energy into crude oil**, a block of `CCountry::UpdateIC`: at most
 *   `max(0.05 x IC, 1)` crude oil a day, at `1 / rate` energy each, `rate` being 0.1 plus
 *   technology; only towards holding twice as much energy as crude oil, and never out of
 *   the `2 x IC` energy industry needs that day.
 * - **Crude oil into fuel**, `CCountry::ConvertCrudeOilToFuel`: `IC / 2` crude oil a day,
 *   unless fuel is at 99,000, or above a year of the crude oil coming in and above twice
 *   the crude oil held.
 *
 * reversing/findings/FINDINGS-distribute.md, sections 4 and 6.
 *
 * **In BlackICE energy into crude oil starts switched off.** Every country's history gives
 * it `hidden_coal_to_oil_base_counter`, `energy_to_oil_conversion = -1`, so the rate is
 * 0.1 - 1 = -0.9, and the game converts nothing at or below 0. `hidden_coal_to_oil_activate`
 * (+1) brings it back to 0.1, and only events give it: 48998, the synthetic industry, and
 * 93673, Germany's Four Year Plan. The patch keeps that gate - a played country's own
 * amounts convert nothing either until then - so the settings can be made early and apply
 * from the day it opens. Seen in a running game on 2026-11-04: Germany in January 1936,
 * rate -0.90, nothing converted, while refining followed its own settings.
 *
 * ## The variables
 *
 * All in the units a stockpile is shown in - `set_variable = { which = ... value = 50 }`
 * is 50 a day. **Nought means off or no limit**, because a save drops a variable that is
 * exactly nought and a missing one reads nought, so the two have to mean the same.
 *
 *     zzDsafe_usesCustomOilConversion          1: energy into crude oil is the player's
 *     zzDsafe_CustomConversion_energyPerDay    energy to spend a day
 *     zzDsafe_CustomConversion_energyKeep      never take energy below this
 *     zzDsafe_CustomConversion_oilTarget       convert only while crude oil is below this
 *
 *     zzDsafe_usesCustomFuelConversion         1: crude oil into fuel is the player's
 *     zzDsafe_CustomConversion_crudePerDay     crude oil to spend a day
 *     zzDsafe_CustomConversion_crudeKeep       never take crude oil below this
 *     zzDsafe_CustomConversion_fuelTarget      convert only while fuel is below this
 *
 * The maintainer's decisions, 2026-11-04: the amount is what is **spent**; it is **capped
 * at the game's own capacity** - `0.05 x IC` crude oil made, so `0.05 x IC / rate` energy
 * spent, and `IC / 2` crude oil refined; and energy is **never taken below the `2 x IC`
 * industry needs** - the resource cap reads the stockpile a few instructions later and cuts
 * that day's IC by one for every two energy short, telling nobody. `energyKeep` can only
 * raise that floor. The 99,000 fuel stop is the game's and stays.
 *
 * Only the decision is ours. Both hooks hand the amounts back to the game's own code, which
 * moves the goods, records them in the two conversion pools the ledger and tomorrow's
 * figures read, applies the yields, and spreads the fuel over the capital's area.
 *
 * ## Multiplayer
 *
 * Every machine runs the daily pass, and the hooks read only what every machine holds
 * alike: the variables, who plays which country (`CCurrentGameState::isPlayed`, what the
 * `ai` trigger asks), the stockpile, the IC and the technology. The variables are set by
 * events and decisions, which run everywhere, or by `CSetVariableCommand`, which is
 * broadcast. Integer arithmetic only.
 *
 * **Switched on from Lua**: `BiceLib.ComplexPatches.customResourceConversion()`.
 */
#include <cstdint>

namespace Hooks {
    namespace ResourceConversion {
        /**
         * **What a country may convert today**, all thousandths - the caps the hooks hold
         * a player's amounts to, worked out by the same code, so the overlay shows the
         * figure that will apply.
         */
        struct Capacity
        {
            int64_t oilRate = 0;        // crude oil one energy makes, 100 being a tenth
            int64_t energyCap = 0;      // energy that may be spent: max(0.05 x IC, 1) crude oil's worth
            int64_t energyFloor = 0;    // 2 x IC, what industry needs; never converted
            int64_t crudeCap = 0;       // crude oil that may be refined: IC / 2, whole
            bool played = false;        // a person plays it, so its own settings apply
        };

        /**@brief what \p country may convert today; false where the game has no answer
                  for it - not installed, no stockpile, no technology*/
        bool capacity(uintptr_t country, Capacity& out);

        /**@brief patches both conversions, once; safe to call again*/
        bool install();

        bool installed();

        /**@brief why it is not installed, when it is not*/
        const char* status();
    }
}
