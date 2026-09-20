#include <Hooks/EffectText/EffectText.hpp>

#include <GameClasses/CCountryDataBase.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CLeader.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/GameString.hpp>
#include <GameState/Localisation.hpp>
#include <MemScan.hpp>

#include <Windows.h>

namespace {
    // The variable mechanism itself: the text in ecx, the value pushed, and the key in
    // **esi**, which the compiler left in a register variable and the callee reads from
    // there. `ret 4`.
    const uintptr_t REPLACE_VARIABLE = 0x682F40;

    // What an effect's scope carries: the country it is being asked about, as a
    // CCountryTag - three letters and then the id that indexes the country database.
    const uintptr_t SCOPE_COUNTRY_TAG = 0x10;

    // Read by the stub below, which is why it is a plain word.
    DWORD replaceVariableAddress = 0;

    bool looked = false;
}

bool Hooks::EffectText::ready() {
    if (looked) {
        return replaceVariableAddress != 0;
    }
    looked = true;
    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        return false;
    }
    replaceVariableAddress = static_cast<DWORD>(base + REPLACE_VARIABLE);
    return true;
}

__declspec(naked) void Hooks::EffectText::replaceVariable(
        void* /*text*/, const void* /*key*/, const void* /*value*/) {
    __asm {
        push ebp
        mov ebp, esp
        push esi

        mov ecx, [ebp + 8]              // the text being built
        mov esi, [ebp + 0x0C]           // the variable's name, without the $ $
        push dword ptr [ebp + 0x10]     // what to put in its place
        call [replaceVariableAddress]   // thiscall: it takes the pushed argument off

        pop esi
        pop ebp
        ret
    }
}

void Hooks::EffectText::setVariable(void* text, const char* name, const char* value) {
    if (text == nullptr || name == nullptr) {
        return;
    }
    const Game::String key(name);
    const Game::String held(value == nullptr ? "" : value);
    replaceVariable(text, key.raw(), held.raw());
}

uintptr_t Hooks::EffectText::countryOfScope(uintptr_t scope) {
    int id = 0;
    if (scope == 0
        || !Mem::tryRead(scope + SCOPE_COUNTRY_TAG + CCountryTag::Offsets::id, id) || id <= 0) {
        return 0;
    }
    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    uintptr_t database = 0;
    uintptr_t first = 0;
    uintptr_t last = 0;
    uintptr_t country = 0;
    if (base == 0
        || !Mem::tryRead(base + CCountryDataBase::GLOBAL_POINTER, database) || database == 0
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

Hooks::EffectText::Posting Hooks::EffectText::postingOf(uintptr_t leader) {
    Posting posting;
    uintptr_t unit = 0;
    if (leader == 0 || !Mem::tryRead(leader + CLeader::Offsets::unit_ptr, unit) || unit == 0) {
        return posting;
    }

    // Colours out: both callers put this inside one of their own, and a name carrying
    // its own code would end that colour at the name and leave the rest of the line
    // looking unremarkable. Unit names in this mod do carry them.
    posting.unit = Game::withoutColours(Game::rawChars(unit + CUnit::Offsets::name));

    uintptr_t province = 0;
    int provinceId = 0;
    if (Mem::tryRead(unit + CUnit::Offsets::current_province_ptr, province) && province != 0
        && Mem::tryRead(province + CMapProvince::Offsets::id, provinceId) && provinceId > 0) {
        // A province's name is localisation, not anything in memory: the key is
        // PROV<id>. Localisation::text does the looking up and the rendering that the
        // game's own lookup leaves to its caller.
        posting.province =
            Game::withoutColours(Localisation::textForId("PROV", provinceId).c_str());
    }
    return posting;
}
