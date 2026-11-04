#include <Hooks/ResourceConversion.hpp>

#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <GameClasses/CGoodsPool.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CSubUnitDefinition.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <algorithm>
#include <cstdint>

namespace {

    // The stubs use these as literal displacements; this is what says they are the ones
    // GameClasses names.
    static_assert(CCountry::Offsets::total_ic == 0x604, "the energy stub loads [ebx+0x604]");
    static_assert(CGoodsPool::Goods::fuel == 0x0C, "the refining stub compares [eax+0x0C]");

    /**
     * **The sites**, module relative, and the bytes each must hold. Nothing branches into
     * either hooked range after its first byte: a scan of every rel8 and rel32 branch in
     * .text finds none, and finds `0xF0FE9 jge 0xF0FF5` and `0xF1A1D jmp 0xF1A2B` - onto
     * the first bytes - as its positive control.
     * reversing/findings/FINDINGS-distribute.md, section 7.
     *
     * In `CCountry::UpdateIC`, the country in ebx, `applyDailyEffects` at [ebp+0xC]:
     *
     *   ENERGY_SITE   0xF0FF5  mov edi, [ebx+0x604]           the block's first instruction
     *   ENERGY_APPLY  0xF13BA  mov [ebp+8], edi ; test ; jle  the game's writes: crude oil in
     *                                                          edi, energy in esi
     *   ENERGY_SKIP   0xF13E8  mov eax, [ebx+0x604]           the industry need, where every
     *                                                          one of the block's skips lands
     *
     * In `CCountry::ConvertCrudeOilToFuel`, the country in esi, the stockpile in eax:
     *
     *   REFINE_SITE   0xF1A2B  cmp [eax+0xC], 99000.000 ; jge  the first stop, 13 bytes
     *   REFINE_APPLY  0xF1BA4  mov ebx, edi ; neg ebx          the game's writes, yield and
     *                                                          spread: crude oil in edi
     *   REFINE_EXIT   0xF1DE7  mov ecx, [ebp-0xC]              the epilogue both stops reach
     */
    const uintptr_t ENERGY_SITE = 0xF0FF5;
    const uintptr_t ENERGY_RESUME = 0xF0FFB;
    const unsigned char ENERGY_SITE_BYTES[6] = { 0x8B, 0xBB, 0x04, 0x06, 0x00, 0x00 };
    const uintptr_t ENERGY_APPLY = 0xF13BA;
    const unsigned char ENERGY_APPLY_BYTES[7] = { 0x89, 0x7D, 0x08, 0x85, 0xFF, 0x7E, 0x27 };
    const uintptr_t ENERGY_SKIP = 0xF13E8;
    const unsigned char ENERGY_SKIP_BYTES[6] = { 0x8B, 0x83, 0x04, 0x06, 0x00, 0x00 };

    const uintptr_t REFINE_SITE = 0xF1A2B;
    const uintptr_t REFINE_RESUME = 0xF1A38;
    const unsigned char REFINE_SITE_BYTES[13] = {
        0x81, 0x78, 0x0C, 0xC0, 0x9E, 0xE6, 0x05, 0x0F, 0x8D, 0xAF, 0x03, 0x00, 0x00 };
    const uintptr_t REFINE_APPLY = 0xF1BA4;
    const unsigned char REFINE_APPLY_BYTES[4] = { 0x8B, 0xDF, 0xF7, 0xDB };
    const uintptr_t REFINE_EXIT = 0xF1DE7;
    const unsigned char REFINE_EXIT_BYTES[3] = { 0x8B, 0x4D, 0xF4 };

    /**
     * **The base of the energy rate**, 100 - a tenth - written once by the static
     * initialiser at `0x8B6650` from `floor(100.5f)`; `CCountry::GetOilConversionRate` adds
     * technology to it. Read rather than written down, so the rate is the game's own.
     */
    const uintptr_t BASE_OIL_CONVERSION_RATE = 0x1687478;

    /**@brief the game's own stop for refining, 99,000 fuel, in thousandths*/
    const int64_t FUEL_STOP = 99000000;

    const char* const USES_OIL = "zzDsafe_usesCustomOilConversion";
    const char* const ENERGY_PER_DAY = "zzDsafe_CustomConversion_energyPerDay";
    const char* const ENERGY_KEEP = "zzDsafe_CustomConversion_energyKeep";
    const char* const OIL_TARGET = "zzDsafe_CustomConversion_oilTarget";

    const char* const USES_FUEL = "zzDsafe_usesCustomFuelConversion";
    const char* const CRUDE_PER_DAY = "zzDsafe_CustomConversion_crudePerDay";
    const char* const CRUDE_KEEP = "zzDsafe_CustomConversion_crudeKeep";
    const char* const FUEL_TARGET = "zzDsafe_CustomConversion_fuelTarget";

    // Read by the naked stubs, which is why they are plain words.
    DWORD energyResume = 0;
    DWORD energyApply = 0;
    DWORD energySkip = 0;
    DWORD refineResume = 0;
    DWORD refineApply = 0;
    DWORD refineExit = 0;
    DWORD baseRateAddress = 0;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    /**@brief the registers as pushad leaves them, lowest address first*/
    struct SavedRegisters {
        uint32_t edi, esi, ebp, esp, ebx, edx, ecx, eax;
    };
    static_assert(sizeof(SavedRegisters) == 32, "pushad saves eight dwords");

    // What decideEnergy answers. The stub compares against the literals.
    enum EnergyAnswer : int { GAME_DECIDES = 0, CONVERT_NOTHING = 1, CONVERT = 2 };

    // decideRefining's answer when the game is to decide; the stub compares against -1.
    const int REFINE_GAME_DECIDES = -1;

    template <typename T>
    T at(uintptr_t address) {
        return *reinterpret_cast<const T*>(address);
    }

    /**@brief a variable, never below nought: a negative amount or limit means none*/
    int64_t setting(uintptr_t country, const char* name) {
        return (std::max)(static_cast<int64_t>(CCountry::variableValue(country, name)), int64_t(0));
    }

    /**@brief whether this country's conversion is the player's: played, and switched on*/
    bool playerDecides(uintptr_t country, const char* usesVariable) {
        const int id = at<int32_t>(country + CCountry::Offsets::country_tag + CCountryTag::Offsets::id);
        return CCurrentGameState::isPlayed(id) && CCountry::variableValue(country, usesVariable) != 0;
    }

    /**@brief the stockpile, as `CCountry::GetPool` finds it; 0 where there is none*/
    uintptr_t stockpile(uintptr_t country) {
        if (at<uint8_t>(country + CCountry::Offsets::is_government_in_exile) != 0) {
            return country + CCountry::Offsets::pool_in_exile;
        }
        const uintptr_t capital = CCountry::actingCapitalLocation(country);
        return capital == 0 ? 0 : capital + CMapProvince::Offsets::pool;
    }

    /**@brief crude oil one energy makes, thousandths: the game's base plus technology*/
    int64_t oilRate(uintptr_t technology) {
        return static_cast<int64_t>(at<int32_t>(baseRateAddress))
            + at<int32_t>(technology + CTechnologyStatus::Offsets::oil_conversion_bonus);
    }

    /**@brief the energy the game's `max(0.05 x IC, 1)` crude oil costs at \p rate*/
    int64_t energyCapFor(int64_t ic, int64_t rate) {
        if (rate <= 0) {
            return 0;
        }
        const int64_t per = (std::max)((1000000 + rate / 2) / rate, int64_t(1000));
        const int64_t most = (std::max)(ic * 50, int64_t(1000));
        return most * per / 1000;
    }

    /**@brief the game's half an IC of crude oil, the halving toward nought as its own*/
    int64_t crudeCapFor(int64_t ic) {
        return (ic / 2) * 1000;
    }

    /**
    @brief energy into crude oil for a played country that has switched it on

    Answers GAME_DECIDES for everyone else, which runs the game's block untouched. Otherwise
    leaves the energy to spend in esi and the crude oil it makes in edi for the game's own
    writes, or answers CONVERT_NOTHING. All thousandths; IC is whole.

        floor  = max(2000 x IC, energyKeep)            ; what industry needs, at least
        spare  = energy - floor
        rate   = base + technology                     ; GetOilConversionRate
        per    = max(round(1000000 / rate), 1000)      ; energy one crude oil costs
        cap    = max(50 x IC, 1000) x per / 1000       ; the game's 0.05 an IC, as energy
        spend  = min(energyPerDay, cap, spare)
        made   = spend x rate / 1000                   ; the game's own product

    Nothing when the day's effects are off - the game converts nothing then either - or
    when crude oil has reached oilTarget.
    */
    int __stdcall decideEnergy(uintptr_t country, int applyDailyEffects, SavedRegisters* registers) {
        if (!playerDecides(country, USES_OIL)) {
            return GAME_DECIDES;
        }
        if (applyDailyEffects == 0) {
            return CONVERT_NOTHING;
        }
        const uintptr_t pool = stockpile(country);
        const uintptr_t technology = at<uint32_t>(country + CCountry::Offsets::technology_status);
        if (pool == 0 || technology == 0) {
            return CONVERT_NOTHING;
        }

        const int64_t ic = at<int32_t>(country + CCountry::Offsets::total_ic);
        const int64_t energy = at<int32_t>(pool + CGoodsPool::Goods::energy);
        const int64_t crude = at<int32_t>(pool + CGoodsPool::Goods::crude_oil);

        const int64_t target = setting(country, OIL_TARGET);
        if (target > 0 && crude >= target) {
            return CONVERT_NOTHING;
        }

        const int64_t floor = (std::max)(ic * 2000, setting(country, ENERGY_KEEP));
        const int64_t spare = energy - floor;
        const int64_t rate = oilRate(technology);
        if (spare <= 0 || rate <= 0) {
            return CONVERT_NOTHING;
        }

        const int64_t cap = energyCapFor(ic, rate);
        const int64_t spend = (std::min)((std::min)(setting(country, ENERGY_PER_DAY), cap), spare);
        const int64_t made = spend * rate / 1000;
        if (spend <= 0 || made <= 0) {
            return CONVERT_NOTHING;
        }

        registers->esi = static_cast<uint32_t>(spend);
        registers->edi = static_cast<uint32_t>(made);
        return CONVERT;
    }

    /**
    @brief crude oil into fuel for a played country that has switched it on

    REFINE_GAME_DECIDES for everyone else. Otherwise the crude oil to refine, which the
    game's own code turns into fuel; 0 for none. Thousandths; IC is whole.

        cap   = (IC / 2) x 1000                        ; the game's half an IC, toward nought
        spend = min(crudePerDay, cap, crude - crudeKeep)

    Nothing at the game's 99,000 fuel, or once fuel has reached fuelTarget.
    */
    int __stdcall decideRefining(uintptr_t country, uintptr_t pool) {
        if (!playerDecides(country, USES_FUEL)) {
            return REFINE_GAME_DECIDES;
        }
        const int64_t fuel = at<int32_t>(pool + CGoodsPool::Goods::fuel);
        const int64_t crude = at<int32_t>(pool + CGoodsPool::Goods::crude_oil);
        if (fuel >= FUEL_STOP) {
            return 0;
        }
        const int64_t target = setting(country, FUEL_TARGET);
        if (target > 0 && fuel >= target) {
            return 0;
        }

        const int64_t ic = at<int32_t>(country + CCountry::Offsets::total_ic);
        const int64_t cap = crudeCapFor(ic);
        const int64_t available = crude - setting(country, CRUDE_KEEP);
        const int64_t spend = (std::min)((std::min)(setting(country, CRUDE_PER_DAY), cap), available);
        return spend > 0 ? static_cast<int>(spend) : 0;
    }

    /**
    @brief UpdateIC's energy block: the game's, ours, or none

    The flags are not live here: the instruction this replaces is followed by an imul, and
    both places it may go on to set them before they are read. Nor is eax.
    */
    __declspec(naked) void energyStub() {
        __asm {
            pushad
            mov eax, esp                        // the saved registers
            movzx ecx, byte ptr [ebp + 0x0C]    // applyDailyEffects
            push eax
            push ecx
            push ebx                            // the country
            call decideEnergy
            cmp eax, 2                          // CONVERT
            je convert
            test eax, eax                       // GAME_DECIDES
            je gameDecides
            popad
            jmp [energySkip]
        convert:
            popad                               // esi the energy, edi the crude oil
            jmp [energyApply]
        gameDecides:
            popad
            mov edi, dword ptr [ebx + 0x604]    // the instruction the jump covered
            jmp [energyResume]
        }
    }

    /**
    @brief ConvertCrudeOilToFuel's first stop: the game's, or straight to the writes

    edi is free here - the game's next instruction loads it, and the epilogue pops it.
    */
    __declspec(naked) void refineStub() {
        __asm {
            pushad
            push eax                            // the stockpile
            push esi                            // the country
            call decideRefining
            mov dword ptr [esp], eax            // into the saved edi
            popad
            cmp edi, -1                         // REFINE_GAME_DECIDES
            je gameDecides
            test edi, edi
            jle done
            jmp [refineApply]
        gameDecides:
            cmp dword ptr [eax + 0x0C], 0x5E69EC0   // the instructions the jump covered
            jge done
            jmp [refineResume]
        done:
            jmp [refineExit]
        }
    }
}

bool Hooks::ResourceConversion::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }

    if (!Hooks::bytesAre(base + ENERGY_SITE, ENERGY_SITE_BYTES, 6)
        || !Hooks::bytesAre(base + ENERGY_APPLY, ENERGY_APPLY_BYTES, 7)
        || !Hooks::bytesAre(base + ENERGY_SKIP, ENERGY_SKIP_BYTES, 6)
        || !Hooks::bytesAre(base + REFINE_SITE, REFINE_SITE_BYTES, 13)
        || !Hooks::bytesAre(base + REFINE_APPLY, REFINE_APPLY_BYTES, 4)
        || !Hooks::bytesAre(base + REFINE_EXIT, REFINE_EXIT_BYTES, 3)) {
        statusText = "the conversion code is not what this build expects";
        ERROR_OUT(printf("ResourceConversion: a site is not the instruction expected\n"));
        return false;
    }

    int32_t baseRate = 0;
    if (!Mem::tryRead(base + BASE_OIL_CONVERSION_RATE, baseRate) || baseRate <= 0) {
        statusText = "the base oil conversion rate is not set";
        return false;
    }

    energyResume = static_cast<DWORD>(base + ENERGY_RESUME);
    energyApply = static_cast<DWORD>(base + ENERGY_APPLY);
    energySkip = static_cast<DWORD>(base + ENERGY_SKIP);
    refineResume = static_cast<DWORD>(base + REFINE_RESUME);
    refineApply = static_cast<DWORD>(base + REFINE_APPLY);
    refineExit = static_cast<DWORD>(base + REFINE_EXIT);
    baseRateAddress = static_cast<DWORD>(base + BASE_OIL_CONVERSION_RATE);

    if (!Hooks::hook(reinterpret_cast<void*>(base + ENERGY_SITE), &energyStub, 5, 1)
        || !Hooks::hook(reinterpret_cast<void*>(base + REFINE_SITE), &refineStub, 5, 8)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    return true;
}

bool Hooks::ResourceConversion::capacity(uintptr_t country, Capacity& out) {
    out = Capacity();
    if (!installedFlag || country == 0) {
        return false;
    }
    int32_t ic = 0;
    uint32_t technology = 0;
    int32_t id = 0;
    if (!Mem::tryRead(country + CCountry::Offsets::total_ic, ic)
        || !Mem::tryRead(country + CCountry::Offsets::technology_status, technology)
        || technology == 0
        || !Mem::tryRead(country + CCountry::Offsets::country_tag + CCountryTag::Offsets::id, id)) {
        return false;
    }
    int32_t bonus = 0;
    int32_t base = 0;
    if (!Mem::tryRead(technology + CTechnologyStatus::Offsets::oil_conversion_bonus, bonus)
        || !Mem::tryRead(baseRateAddress, base)) {
        return false;
    }

    out.oilRate = static_cast<int64_t>(base) + bonus;
    out.energyCap = energyCapFor(ic, out.oilRate);
    out.energyFloor = static_cast<int64_t>(ic) * 2000;
    out.crudeCap = crudeCapFor(ic);
    out.played = CCurrentGameState::isPlayed(id);
    return true;
}

bool Hooks::ResourceConversion::installed() {
    return installedFlag;
}

const char* Hooks::ResourceConversion::status() {
    return statusText;
}
