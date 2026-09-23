#include <Hooks/Tooltips/ManpowerText.hpp>

#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCountryDataBase.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CModifier.hpp>
#include <GameClasses/CRegiment.hpp>
#include <GameClasses/CSubUnitDefinition.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/GameString.hpp>
#include <Hooks/EffectText/EffectText.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>

namespace {
    // ---------------------------------------------------------------------------------
    // The daily reinforcement pass, `0x11BA60`.
    // ---------------------------------------------------------------------------------

    /**
     * **Where the pass starts over**: `mov [esi + 0xA9C], edi` with `edi` zero, the last
     * of the three counters the function clears before it walks anything. `esi` is the
     * country, which is what makes this the place to clear ours as well - a pass and its
     * split then begin and end together, whatever order the game visits countries in.
     */
    const uintptr_t RESET_SITE = 0x11BBFC;
    const unsigned char RESET_BYTES[6] = { 0x89, 0xBE, 0x9C, 0x0A, 0x00, 0x00 };
    const uintptr_t RESET_RESUME = 0x11BC02;

    /**
     * **Where a subunit's share is added**: `add [eax + 0xA9C], ecx`, inside the loop
     * over a unit's subunits. `eax` is the country and `ecx` is the manpower this
     * subunit's missing strength is worth.
     *
     * Which subunit that is has not been in a register since `0x11C013`, but it is still
     * in the frame: the loop wrote it to `[esp + 0x44]` on the way in and reads it back
     * three times after, the last at `0x11C43D`. The stack has not moved between there
     * and here - the very next instruction reads `[esp + 0x48]` for the loop's own next
     * node - so the slot holds at this instruction exactly.
     */
    const uintptr_t ADD_SITE = 0x11C60C;
    const unsigned char ADD_BYTES[6] = { 0x01, 0x88, 0x9C, 0x0A, 0x00, 0x00 };
    const uintptr_t ADD_RESUME = 0x11C612;

    // ---------------------------------------------------------------------------------
    // Troop rotation, in `CUnit`'s slot 32 - the per-unit daily update at `0x1BAF70`.
    //
    // Land only, by the `IsLand` test at the top: a navy shares this function and
    // `CAir`'s override ends by calling it, so all three arrive and only an army gets
    // past. Nothing here has to know that - the hook stands on the store, so what it
    // totals is whatever the game actually took - but it is why the tooltip says the
    // army rather than the armed forces.
    // ---------------------------------------------------------------------------------

    /**
     * **Where rotation takes the strength off**: `mov [edi + 0x5C], ebx`, the store that
     * ends the loop body, with the `cmp` after it taken as well to make six bytes.
     *
     * Standing on the store rather than on the drain that was worked out above it is
     * what makes the figure the real one: the drain is clamped to nothing below zero and
     * to the maximum above it, so the strength that actually went is `[edi + 0x5C]`
     * before this instruction less `ebx` after it. `edi` is the subunit and `esi` is
     * still the unit, which is how the country is reached.
     *
     * The `jns` two instructions above lands exactly on the first byte of this, so the
     * jump that replaces it is still the thing that branch arrives at. Nothing lands
     * inside the five bytes - checked over the whole function, not assumed.
     */
    const uintptr_t ROTATION_SITE = 0x1BB25D;
    const unsigned char ROTATION_BYTES[6] = { 0x89, 0x5F, 0x5C, 0x3B, 0x5F, 0x30 };
    const uintptr_t ROTATION_RESUME = 0x1BB263;

    /**
     * **The values array of a country's own modifier**, which is
     * `CCountry::Offsets::global_modifier` plus `CModifier::Offsets::values` - the same
     * `[country + 0xDA8]` the game fetches at `0x1BB16B` before reading rotation out of
     * it. An entry is `CModifier::Entry::SIZE` bytes and holds a CFixedPoint.
     */
    const uintptr_t MODIFIER_VALUES =
        CCountry::Offsets::global_modifier + CModifier::Offsets::values;

    /**
     * How the annual rate becomes a daily one, and so what a month of it is.
     *
     * The game divides by 365000 - a thousandth-scaled rate over a year - so a month is
     * a twelfth of the year rather than thirty days, and saying so keeps the projection
     * consistent with the mechanic instead of with the calendar.
     */
    const int DAYS_PER_YEAR = 365;
    const int MONTHS_PER_YEAR = 12;

    // ---------------------------------------------------------------------------------
    // Attrition, in the pass `CUnit::UpdateDaily` calls at `0x1C7530`.
    // ---------------------------------------------------------------------------------

    /**
     * **Where attrition takes the strength off**, and the same shape as rotation's store
     * down to the clamp above it - which is no coincidence: both are a subunit losing
     * strength, written back through `[reg + 0x5C]` with the ceiling at `+0x30` raised
     * after.
     *
     * `esi` is the subunit and `edi` is what its strength is about to become, so what
     * actually went is `[esi + 0x5C]` before this instruction less `edi` after it.
     *
     * The unit is **not** in a register here - `edi` held it at the top of the function
     * and has since been reused - so it comes off the frame at `[ebp + 8]`, where the
     * function's first argument is.
     */
    const uintptr_t ATTRITION_SITE = 0x1C76E2;
    const unsigned char ATTRITION_BYTES[6] = { 0x89, 0x7E, 0x5C, 0x3B, 0x7E, 0x30 };
    const uintptr_t ATTRITION_RESUME = 0x1C76E8;

    // ---------------------------------------------------------------------------------
    // Casualty trickleback, at `0x1C3F30`.
    // ---------------------------------------------------------------------------------

    /**
     * **Where the manpower comes back**: `add [esi + 0xBCC], eax`, the one write in the
     * whole of that function - `esi` is the country and `eax` is the manpower, already
     * in the units the tooltip prints.
     *
     * Nothing has to be priced here, unlike attrition and rotation: the game has already
     * turned the casualties into manpower by the time it gets here, through the same two
     * definition fields.
     */
    const uintptr_t TRICKLEBACK_SITE = 0x1C3FF2;
    const unsigned char TRICKLEBACK_BYTES[6] = { 0x01, 0x86, 0xCC, 0x0B, 0x00, 0x00 };
    const uintptr_t TRICKLEBACK_RESUME = 0x1C3FF8;

    /**
     * **How many days of attrition and trickleback are kept.**
     *
     * Rotation is a rate, so one day of it projects honestly over a month. These two are
     * not: attrition depends on where the army is standing and trickleback only happens
     * when somebody is being shot at, so a month projected from a single day would swing
     * wildly. What is reported instead is the average day over however much history there
     * is, up to this many, times a month - which starts rough and settles into a real
     * figure.
     */
    const int HISTORY_DAYS = 30;

    // ---------------------------------------------------------------------------------
    // The tooltip, `0x2D0540`.
    // ---------------------------------------------------------------------------------

    /**
     * **The first thing done after the sentence is finished**: a five byte call, which a
     * five byte jump stands in for exactly, and the stub reproduces it.
     *
     * Both halves of the function reach here - the game formats `$NEED$` and `$USED$` to
     * one decimal or two depending on the size of the need, in two whole copies of the
     * same code - so this is the one point where the built text is complete and nothing
     * has been done to it yet.
     */
    const uintptr_t TOOLTIP_SITE = 0x2D0885;
    const uintptr_t TOOLTIP_CALL = 0x5FF30;
    const uintptr_t TOOLTIP_RESUME = 0x2D088A;

    /**@brief `std::string(int value, int decimals)`, the game's own; it constructs into
       the string it is given, so that one has to be empty*/
    const uintptr_t FORMAT_NUMBER = 0x65ACA0;
    typedef void* (__stdcall* FormatNumber)(void* out, int value, int decimals);

    /**@brief what the tooltip prints the need from, on CCountry*/
    const uintptr_t REINFORCEMENT_MANPOWER = 0xA9C;

    /**
     * **The game's own rule for how many decimals to print** (`0x2D0639`): a need of ten
     * or more gets one, anything smaller gets two. It decides for `$USED$` as well as
     * `$NEED$`, so the whole sentence is at one precision - and the three parts are
     * printed at that same one, or they would not read as parts of it.
     */
    const int FEWER_DECIMALS_FROM = 10000;

    FormatNumber formatNumber = nullptr;

    /**
     * Where the game loaded, kept rather than asked for.
     *
     * `Mem::moduleBase` is `GetModuleHandleA`, which takes the loader lock and walks
     * the module list - fine once, but the country lookup below runs for every subunit
     * of every land unit twice a day, once for rotation and once for attrition.
     */
    uintptr_t gameBase = 0;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the naked stubs, which is why they are plain words rather than anything
    // with a constructor.
    DWORD resetResume = 0;
    DWORD addResume = 0;
    DWORD rotationResume = 0;
    DWORD attritionResume = 0;
    DWORD tricklebackResume = 0;
    DWORD tooltipCall = 0;
    DWORD tooltipResume = 0;

    DWORD landVFTable = 0;
    DWORD airVFTable = 0;
    DWORD navyVFTable = 0;

    /**@brief one country's manpower need, taken apart*/
    struct Split
    {
        uintptr_t country;
        int land;
        int air;
        int navy;

        /**
         * What the three add up to, kept so the tooltip can tell whether they are worth
         * showing: it has to equal what the country holds, or something was counted
         * while this was not watching.
         */
        int total;

        /**
         * **What rotation has cost since this country's last reinforcement pass**, and
         * the last full day of it.
         *
         * The two passes are both daily and both per country, so whatever lands in
         * `rotationPending` between one reset and the next is exactly one day's worth,
         * however the game interleaves them. That is why the day is taken from the
         * game's own passes and not from the clock.
         *
         * `rotationDaily` is only published from the **second** reset onwards, because
         * the first one closes a day that was already part over when this was installed.
         */
        int rotationPending;
        int rotationDaily;
        bool rotationKnown;
        bool sawReset;

        /**
         * **What attrition cost and trickleback returned**, a day per slot, oldest
         * overwritten. `nextDay` is where the day being closed goes and `daysRecorded`
         * stops at HISTORY_DAYS once the ring is full.
         *
         * Kept as history rather than as one figure because neither is a rate; see
         * HISTORY_DAYS.
         */
        int attritionDays[HISTORY_DAYS];
        int tricklebackDays[HISTORY_DAYS];
        int nextDay;
        int daysRecorded;
        int attritionPending;
        int tricklebackPending;
    };

    /**@brief the ring's average day over what history there is, scaled to a month*/
    bool monthlyFrom(const Split* slot, const int* days, int& out) {
        if (slot == nullptr || slot->daysRecorded <= 0) {
            return false;
        }
        long long total = 0;
        for (int i = 0; i < slot->daysRecorded; i++) {
            total += days[i];
        }
        out = static_cast<int>(total * DAYS_PER_YEAR / MONTHS_PER_YEAR
            / slot->daysRecorded);
        return true;
    }

    /**
     * Room for every country the pass can visit, and then some.
     *
     * A country is a pointer, and loading another game makes new ones - so entries from
     * a session that has ended are dead weight. Rather than track sessions, the table
     * starts again when it fills: the worst that costs is one in-game day of a tooltip
     * that says nothing, and it cannot grow without bound.
     */
    const int SPLIT_CAPACITY = 512;
    Split splits[SPLIT_CAPACITY];
    int splitCount = 0;

    /**
     * The last one looked up.
     *
     * A pass does one country from beginning to end before it starts another, so every
     * subunit in it asks for the same entry as the one before - and without this each of
     * them would walk the table.
     */
    Split* recent = nullptr;

    Split* slotFor(uintptr_t country, bool create) {
        if (country == 0) {
            return nullptr;
        }
        if (recent != nullptr && recent->country == country) {
            return recent;
        }
        for (int i = 0; i < splitCount; i++) {
            if (splits[i].country == country) {
                recent = &splits[i];
                return recent;
            }
        }
        if (!create) {
            return nullptr;
        }
        if (splitCount >= SPLIT_CAPACITY) {
            splitCount = 0;         // nothing here belongs to a live game any more
        }
        Split* slot = &splits[splitCount++];
        slot->country = country;
        slot->land = 0;
        slot->air = 0;
        slot->navy = 0;
        slot->total = 0;
        slot->rotationPending = 0;
        slot->rotationDaily = 0;
        slot->rotationKnown = false;
        slot->sawReset = false;
        for (int i = 0; i < HISTORY_DAYS; i++) {
            slot->attritionDays[i] = 0;
            slot->tricklebackDays[i] = 0;
        }
        slot->nextDay = 0;
        slot->daysRecorded = 0;
        slot->attritionPending = 0;
        slot->tricklebackPending = 0;
        recent = slot;
        return slot;
    }

    /**
    @brief the country a unit belongs to, the way the game reaches it itself

    The unit carries a `CCountryTag`, whose id half indexes the country database - which
    is the whole of `CCountryTag::GetCountry`, and what the rotation code does at
    `0x1BB0DD` before reading the modifier.
    */
    uintptr_t countryOfUnit(uintptr_t unit) {
        int id = 0;
        if (unit == 0
            || !Mem::tryRead(unit + CUnit::Offsets::owner + CCountryTag::Offsets::id, id)
            || id <= 0) {
            return 0;
        }
        uintptr_t database = 0;
        uintptr_t first = 0;
        uintptr_t last = 0;
        uintptr_t country = 0;
        if (gameBase == 0
            || !Mem::tryRead(gameBase + CCountryDataBase::GLOBAL_POINTER, database)
            || database == 0
            || !Mem::tryRead(database + CCountryDataBase::Offsets::countries_first, first)
            || !Mem::tryRead(database + CCountryDataBase::Offsets::countries_last, last)) {
            return 0;
        }
        const uintptr_t at = first + 4u * static_cast<unsigned>(id);
        if (first == 0 || at >= last || !Mem::tryRead(at, country)) {
            return 0;
        }
        return country;
    }

    /**
    @brief a country's pass is beginning; forget what the last one counted

    Called from the stub that stands where the game clears its own counter, so the two
    can never be out of step by a whole pass.
    */
    void __cdecl startPass(uintptr_t country) {
        Split* slot = slotFor(country, true);
        if (slot == nullptr) {
            return;
        }
        slot->land = 0;
        slot->air = 0;
        slot->navy = 0;
        slot->total = 0;

        // A day of rotation closes here as well, because this is the only thing in the
        // game that happens once a day per country and that we stand on. The first one
        // is thrown away: it closes a day this was not watching all of.
        if (slot->sawReset) {
            slot->rotationDaily = slot->rotationPending;
            slot->rotationKnown = true;

            slot->attritionDays[slot->nextDay] = slot->attritionPending;
            slot->tricklebackDays[slot->nextDay] = slot->tricklebackPending;
            slot->nextDay = (slot->nextDay + 1) % HISTORY_DAYS;
            if (slot->daysRecorded < HISTORY_DAYS) {
                slot->daysRecorded++;
            }
        }
        slot->sawReset = true;
        slot->rotationPending = 0;
        slot->attritionPending = 0;
        slot->tricklebackPending = 0;
    }

    /**
    @brief puts one subunit's share of the need where it belongs

    @param country the CCountry the game is adding to
    @param subunit the CRegiment, CWing or CShip the share is for
    @param amount  manpower in thousandths, the same units the counter is in
    */
    void __cdecl addShare(uintptr_t country, uintptr_t subunit, int amount) {
        Split* slot = slotFor(country, true);
        if (slot == nullptr || subunit == 0) {
            return;
        }

        // Which of the three it is, asked of the object itself. A pointer whose vftable
        // is none of the three is not a subunit this build knows about, and its share is
        // left out of the parts while the total still counts it - which the tooltip then
        // notices, rather than quietly attributing it to land.
        DWORD vftable = 0;
        if (!Mem::tryRead(subunit, vftable)) {
            return;
        }
        if (vftable == landVFTable) {
            slot->land += amount;
        }
        else if (vftable == airVFTable) {
            slot->air += amount;
        }
        else if (vftable == navyVFTable) {
            slot->navy += amount;
        }
        slot->total += amount;
    }

    /**
    @brief prices the strength rotation has just taken off one subunit

    **The conversion is the game's own, not a second guess at it.** Work the
    reinforcement pass's arithmetic through and everything cancels: it takes the
    fraction of strength missing, multiplies by the subunit's `build_cost_manpower`
    scaled by `maximum / max_strength`, and divides by the fraction's thousandths - which
    leaves

        manpower = missing strength x build_cost_manpower / max_strength

    or, in words, refilling all of a subunit costs exactly what building it cost. So the
    strength rotation removes prices the same way, through the same two fields of the
    same definition object - and the definition is the **copy this subunit owns**, so the
    figures are its own with its technology in them.

    @param subunit the CRegiment, CWing or CShip
    @param unit    the CUnit it is in, which carries the owner
    @param before  its strength, read before the store this stands on
    @param after   what the store is about to write
    */
    int manpowerForStrength(uintptr_t subunit, int strength) {
        uintptr_t definition = 0;
        int maxStrength = 0;
        int buildCost = 0;
        if (strength <= 0
            || !Mem::tryRead(subunit + CRegiment::Offsets::sub_unit_definition_ptr, definition)
            || definition == 0
            || !Mem::tryRead(definition + CSubUnitDefinition::Offsets::max_strength, maxStrength)
            || maxStrength <= 0
            || !Mem::tryRead(definition + CSubUnitDefinition::Offsets::build_cost_manpower, buildCost)
            || buildCost <= 0) {
            return 0;
        }
        // Sixty four bits for the multiply alone: a full strength brigade's build cost
        // in thousandths times a day of drain passes four billion easily.
        return static_cast<int>(
            static_cast<long long>(strength) * buildCost / maxStrength);
    }

    void __cdecl rotationDrain(uintptr_t subunit, uintptr_t unit, int before, int after) {
        const int manpower = manpowerForStrength(subunit, before - after);
        if (manpower <= 0) {
            return;         // clamped to nothing, or not priceable
        }
        Split* slot = slotFor(countryOfUnit(unit), true);
        if (slot != nullptr) {
            slot->rotationPending += manpower;
        }
    }

    /**
    @brief the same for attrition, which takes strength the same way and in the same units

    Its own hook rather than a shared one, because the two stores are in different
    functions and hold the subunit and the unit in different places - and because a
    player wants to know which of the two is costing them.
    */
    void __cdecl attritionDrain(uintptr_t subunit, uintptr_t unit, int before, int after) {
        const int manpower = manpowerForStrength(subunit, before - after);
        if (manpower <= 0) {
            return;
        }
        Split* slot = slotFor(countryOfUnit(unit), true);
        if (slot != nullptr) {
            slot->attritionPending += manpower;
        }
    }

    /**
    @brief what casualty trickleback has just put back into the pool

    Nothing to price: the game has already turned the casualties into manpower, through
    the same `build_cost_manpower / max_strength` the rest of this file uses.

    @param country the CCountry being credited
    @param amount  manpower, in the units the tooltip prints
    */
    void __cdecl tricklebackGained(uintptr_t country, int amount) {
        if (amount <= 0) {
            return;
        }
        Split* slot = slotFor(country, true);
        if (slot != nullptr) {
            slot->tricklebackPending += amount;
        }
    }

    /**@brief one number, written the way the game writes the total*/
    void setNumber(void* text, const char* name, int value, int decimals) {
        Game::String number;
        formatNumber(number.raw(), value, decimals);
        const Game::String key(name);
        Hooks::EffectText::replaceVariable(text, key.raw(), number.raw());
    }

    /**
    @brief the country's peacetime_manpower_rotation, in thousandths

    Read where the game reads it, and the only modifier in the executable with exactly
    one reader - so this value and the drain it causes cannot come apart.
    */
    bool rotationRate(uintptr_t country, int& out) {
        uintptr_t values = 0;
        return country != 0
            && Mem::tryRead(country + MODIFIER_VALUES, values) && values != 0
            && Mem::tryRead(values + CModifier::PEACETIME_MANPOWER_ROTATION
                * CModifier::Entry::SIZE + CModifier::Entry::value, out);
    }

    /**
    @brief fills $LAND$, $AIR$, $NAVY$, $ROTATION$ and $ROTATIONCOST$

    @param text    the std::string holding MANPOWER_DETAILS_IRO, with the game's own
                   variables already in it
    @param country the CCountry it is about
    */
    void __cdecl addBreakdown(void* text, uintptr_t country) {
        if (text == nullptr) {
            return;
        }

        // **The rate stands on its own**: it is read straight off the country rather
        // than counted up, so it is right from the first tooltip and does not depend on
        // a pass having been watched. A thousandth is a tenth of a percent, and the
        // formatter divides by a thousand, so a hundred times it prints as a percentage.
        int rate = 0;
        if (rotationRate(country, rate)) {
            setNumber(text, "ROTATION", rate * 100, 1);
        }
        else {
            Hooks::EffectText::setVariable(text, "ROTATION", "");
        }

        const Split* rotation = slotFor(country, false);
        if (rotation != nullptr && rotation->rotationKnown) {
            // A day's cost projected over a month - a twelfth of a year, because the
            // rate the drain came from is annual.
            const long long monthly = static_cast<long long>(rotation->rotationDaily)
                * DAYS_PER_YEAR / MONTHS_PER_YEAR;
            setNumber(text, "ROTATIONCOST", static_cast<int>(monthly),
                monthly >= FEWER_DECIMALS_FROM ? 1 : 2);
        }
        else {
            // Nothing has been watched for a whole day yet, which lasts until the next
            // daily tick and no longer.
            Hooks::EffectText::setVariable(text, "ROTATIONCOST", "");
        }

        // Attrition and trickleback are averaged over what history there is rather than
        // projected from today, because neither is a rate. Both are blank until a first
        // day has been closed.
        int monthly = 0;
        if (rotation != nullptr && monthlyFrom(rotation, rotation->attritionDays, monthly)) {
            setNumber(text, "ATTRITION", monthly,
                monthly >= FEWER_DECIMALS_FROM ? 1 : 2);
        }
        else {
            Hooks::EffectText::setVariable(text, "ATTRITION", "");
        }
        if (rotation != nullptr && monthlyFrom(rotation, rotation->tricklebackDays, monthly)) {
            setNumber(text, "TRICKLEBACK", monthly,
                monthly >= FEWER_DECIMALS_FROM ? 1 : 2);
        }
        else {
            Hooks::EffectText::setVariable(text, "TRICKLEBACK", "");
        }

        int need = 0;
        const bool read = country != 0
            && Mem::tryRead(country + REINFORCEMENT_MANPOWER, need);
        const Split* slot = read ? slotFor(country, false) : nullptr;

        // Nothing counted and nothing to count is a split of three zeroes, not a gap:
        // a country whose army is at full strength has a real answer.
        const bool sound = read && ((slot != nullptr && slot->total == need)
            || (slot == nullptr && need == 0));

        if (!sound) {
            // Everything the localisation asks for still gets an answer, or the tooltip
            // would show `$LAND$` to the player. Blank, because the alternative is three
            // numbers that do not add up to the one beside them.
            Hooks::EffectText::setVariable(text, "LAND", "");
            Hooks::EffectText::setVariable(text, "AIR", "");
            Hooks::EffectText::setVariable(text, "NAVY", "");
            return;
        }

        const int decimals = need >= FEWER_DECIMALS_FROM ? 1 : 2;
        setNumber(text, "LAND", slot == nullptr ? 0 : slot->land, decimals);
        setNumber(text, "AIR", slot == nullptr ? 0 : slot->air, decimals);
        setNumber(text, "NAVY", slot == nullptr ? 0 : slot->navy, decimals);
    }

    /**
    @brief clears our split where the game clears its counter

    `edi` is zero here and `esi` is the country, both the game's; the stub touches
    neither, and finishes by doing the store it replaced.
    */
    __declspec(naked) void passStarted() {
        __asm {
            pushad
            pushfd
            push esi                        // the country whose pass is starting
            call startPass
            add esp, 4
            popfd
            popad

            mov dword ptr [esi + 0xA9C], edi    // exactly the instruction this replaced
            jmp [resetResume]
        }
    }

    /**
    @brief splits the share the game is about to add

    The subunit is at `[esp + 0x44]` as the game left it; `pushad` and `pushfd` have put
    thirty six bytes under it by the time it is read, which is where the 0x68 comes from.
    */
    __declspec(naked) void needAdded() {
        __asm {
            pushad
            pushfd
            mov edx, dword ptr [esp + 0x68] // 0x44 + 0x24: the subunit it is for
            push ecx                        // how much manpower
            push edx
            push eax                        // which country
            call addShare
            add esp, 12
            popfd
            popad

            add dword ptr [eax + 0xA9C], ecx    // exactly the instruction this replaced
            jmp [addResume]
        }
    }

    /**
    @brief totals what rotation costs, as it takes the strength away

    The old strength is read before the store, which is the only place it still exists.
    The `cmp` is reproduced after the flags are restored, because the `jle` this returns
    to is what reads it.
    */
    __declspec(naked) void rotationApplied() {
        __asm {
            pushad
            pushfd
            push ebx                        // what the strength is about to become
            push dword ptr [edi + 0x5C]     // and what it still is
            push esi                        // the unit, for its owner
            push edi                        // the subunit
            call rotationDrain
            add esp, 16
            popfd
            popad

            mov dword ptr [edi + 0x5C], ebx     // exactly the two this replaced
            cmp ebx, dword ptr [edi + 0x30]
            jmp [rotationResume]
        }
    }

    /**
    @brief totals what attrition costs, as it takes the strength away

    The same shape as the rotation stub and for the same reason, but the registers are
    the other way round - `esi` is the subunit here and `edi` the new strength - and the
    unit has to come off the frame rather than out of a register.
    */
    __declspec(naked) void attritionApplied() {
        __asm {
            pushad
            pushfd
            push edi                        // what the strength is about to become
            push dword ptr [esi + 0x5C]     // and what it still is
            push dword ptr [ebp + 8]        // the unit, the function's first argument
            push esi                        // the subunit
            call attritionDrain
            add esp, 16
            popfd
            popad

            mov dword ptr [esi + 0x5C], edi     // exactly the two this replaced
            cmp edi, dword ptr [esi + 0x30]
            jmp [attritionResume]
        }
    }

    /**
    @brief totals what trickleback returns, as it goes into the pool

    The add this replaces sets flags that nothing reads - the next instruction is a
    `cmp` on the same word - so the stub only has to put the registers back.
    */
    __declspec(naked) void tricklebackAdded() {
        __asm {
            pushad
            pushfd
            push eax                        // the manpower coming back
            push esi                        // the country being credited
            call tricklebackGained
            add esp, 8
            popfd
            popad

            add dword ptr [esi + 0xBCC], eax    // exactly the instruction this replaced
            jmp [tricklebackResume]
        }
    }

    /**
    @brief adds the three variables, on the way out of the tooltip builder

    The frame is still the builder's, so the sentence and the country are where it put
    them: `[ebp - 0x80]` is the string every path has finished with, and `[ebp - 0x4C]`
    is the CCountry it looked the numbers up on.
    */
    __declspec(naked) void tooltipBuilt() {
        __asm {
            pushad
            pushfd
            lea eax, [ebp - 0x80]           // the finished sentence
            push dword ptr [ebp - 0x4C]     // the country it is about
            push eax
            call addBreakdown
            add esp, 8
            popfd
            popad

            call [tooltipCall]              // exactly the call this replaced
            jmp [tooltipResume]
        }
    }
}

bool Hooks::Tooltips::Manpower::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::EffectText::ready()) {
        statusText = "the game's variable replacement was not found";
        return false;
    }

    if (!Hooks::bytesAre(base + RESET_SITE, RESET_BYTES, 6)) {
        statusText = "the reinforcement pass does not start where this build expects";
        ERROR_OUT(printf("Manpower: %#010x is not the instruction expected\n",
            static_cast<unsigned>(base + RESET_SITE)));
        return false;
    }
    if (!Hooks::bytesAre(base + ADD_SITE, ADD_BYTES, 6)) {
        statusText = "the reinforcement pass does not total where this build expects";
        ERROR_OUT(printf("Manpower: %#010x is not the instruction expected\n",
            static_cast<unsigned>(base + ADD_SITE)));
        return false;
    }
    if (!Hooks::bytesAre(base + ROTATION_SITE, ROTATION_BYTES, 6)) {
        statusText = "troop rotation does not apply where this build expects";
        ERROR_OUT(printf("Manpower: %#010x is not the instruction expected\n",
            static_cast<unsigned>(base + ROTATION_SITE)));
        return false;
    }
    if (!Hooks::bytesAre(base + ATTRITION_SITE, ATTRITION_BYTES, 6)) {
        statusText = "attrition does not apply where this build expects";
        ERROR_OUT(printf("Manpower: %#010x is not the instruction expected\n",
            static_cast<unsigned>(base + ATTRITION_SITE)));
        return false;
    }
    if (!Hooks::bytesAre(base + TRICKLEBACK_SITE, TRICKLEBACK_BYTES, 6)) {
        statusText = "casualty trickleback does not credit where this build expects";
        ERROR_OUT(printf("Manpower: %#010x is not the instruction expected\n",
            static_cast<unsigned>(base + TRICKLEBACK_SITE)));
        return false;
    }
    if (!Hooks::isCallTo(base + TOOLTIP_SITE, base + TOOLTIP_CALL)) {
        statusText = "the manpower tooltip does not end where this build expects";
        ERROR_OUT(printf("Manpower: %#010x is not the call expected\n",
            static_cast<unsigned>(base + TOOLTIP_SITE)));
        return false;
    }

    gameBase = base;
    formatNumber = reinterpret_cast<FormatNumber>(base + FORMAT_NUMBER);
    resetResume = static_cast<DWORD>(base + RESET_RESUME);
    addResume = static_cast<DWORD>(base + ADD_RESUME);
    rotationResume = static_cast<DWORD>(base + ROTATION_RESUME);
    attritionResume = static_cast<DWORD>(base + ATTRITION_RESUME);
    tricklebackResume = static_cast<DWORD>(base + TRICKLEBACK_RESUME);
    tooltipCall = static_cast<DWORD>(base + TOOLTIP_CALL);
    tooltipResume = static_cast<DWORD>(base + TOOLTIP_RESUME);

    landVFTable = static_cast<DWORD>(base + CRegiment::VFTable::CRegiment);
    airVFTable = static_cast<DWORD>(base + CRegiment::VFTable::CWing);
    navyVFTable = static_cast<DWORD>(base + CRegiment::VFTable::CShip);

    // The counting goes in before the tooltip that reads it, so the first tooltip to be
    // built after this has something to say. Installing part way through a pass still
    // leaves one that has counted less than the country holds, which is what the
    // tooltip checks for rather than trusts.
    if (!Hooks::hook(reinterpret_cast<void*>(base + RESET_SITE), &passStarted, 5, 1)
        || !Hooks::hook(reinterpret_cast<void*>(base + ADD_SITE), &needAdded, 5, 1)
        || !Hooks::hook(reinterpret_cast<void*>(base + ROTATION_SITE), &rotationApplied, 5, 1)
        || !Hooks::hook(reinterpret_cast<void*>(base + ATTRITION_SITE), &attritionApplied, 5, 1)
        || !Hooks::hook(reinterpret_cast<void*>(base + TRICKLEBACK_SITE), &tricklebackAdded, 5, 1)
        || !Hooks::hook(reinterpret_cast<void*>(base + TOOLTIP_SITE), &tooltipBuilt, 5, 0)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("Manpower: $LAND$, $AIR$, $NAVY$, $ROTATION$, $ROTATIONCOST$, "
        "$ATTRITION$ and $TRICKLEBACK$ are available to MANPOWER_DETAILS_IRO\n"));
    return true;
}

bool Hooks::Tooltips::Manpower::installed() {
    return installedFlag;
}

const char* Hooks::Tooltips::Manpower::status() {
    return statusText;
}
