#include <Hooks/EffectTextHooks.hpp>

#include <GameClasses/CLeader.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/GameString.hpp>
#include <GameState/Localisation.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>
#include <cstring>

namespace {
    // Inside the kill_leader effect's text builder, which is the function that owns
    // the string KILL_LEADER_EFFECT. Both sites are a five byte call, so a five byte
    // jump stands in for one exactly and the stub reproduces the call it replaced.
    //
    // The first is where the leader's name is formatted, and it is there rather than
    // anywhere later because esi still holds the leader: two calls on it is reused.
    const uintptr_t FORMAT_NAME_SITE = 0x5ADE62;

    // The second is the game's own `$NAME$` replacement, the last thing done to the
    // text. Standing here means ours go in beside it with the text still in hand.
    const uintptr_t REPLACE_SITE = 0x5ADE8A;

    // What those two sites call, checked rather than assumed: the bytes are read as a
    // call and its target resolved, so a build where either has moved is refused
    // instead of patched.
    const uintptr_t FORMAT_NAME = 0x65B150;
    const uintptr_t REPLACE_VARIABLE = 0x682F40;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the naked stubs, which is why they are plain words rather than anything
    // with a constructor.
    DWORD formatNameAddress = 0;
    DWORD replaceVariableAddress = 0;
    DWORD jumpBackFormat = 0;
    DWORD jumpBackReplace = 0;

    // Which leader the text is being built for, caught at the first site and used at
    // the second. The two are forty bytes apart in one straight line, so this never
    // has to survive anything.
    uintptr_t capturedLeader = 0;

    /**
    @brief the game's own `text.Replace(key, value)`, which takes its key in esi

    Three arguments in three places: the text in ecx, the key in esi and the value on
    the stack. The compiler put the key in a register variable and the callee reads it
    from there, so there is no way to make this call from C.
    */
    __declspec(naked) void replaceVariable(void* /*text*/, const void* /*key*/, const void* /*value*/) {
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

    /**
    @brief puts $UNIT$, $LOCATION$ and $WHERE$ into the text beside the game's $NAME$

    Called from the second stub with the text the game is about to put the leader's
    name into. A leader with no command leaves all three empty rather than absent, so
    a localisation that asks for one never shows a bare `$UNIT$`.

    @param text the std::string the effect's sentence is being built in
    */
    void __cdecl addPlaceVariables(void* text) {
        const uintptr_t leader = capturedLeader;
        capturedLeader = 0;     // one text, not the next
        if (text == nullptr || leader == 0) {
            return;
        }

        Game::String unitValue;
        Game::String locationValue;
        Game::String whereValue;

        uintptr_t unit = 0;
        if (Mem::tryRead(leader + CLeader::Offsets::unit_ptr, unit) && unit != 0) {
            unitValue.set(Game::rawChars(unit + CUnit::Offsets::name));

            uintptr_t province = 0;
            int provinceId = 0;
            if (Mem::tryRead(unit + CUnit::Offsets::current_province_ptr, province) && province != 0
                && Mem::tryRead(province + CMapProvince::Offsets::id, provinceId) && provinceId > 0) {
                // A province's name is localisation, not anything in memory: the
                // key is PROV<id>. Localisation::text does the looking up and the
                // rendering that the game's own lookup leaves to its caller.
                locationValue.set(Localisation::textForId("PROV", provinceId).c_str());
            }

            // Punctuation and the game's own colour codes, and no words: a connector
            // like "in" would be English in a line the localisation is supposed to
            // own. \xA7 is the colour escape, Y yellow and W back to white, which is
            // how the game colours the leader's name in the same sentence.
            char where[256] = {};
            if (!unitValue.empty() && !locationValue.empty()) {
                _snprintf_s(where, sizeof(where), _TRUNCATE, " (\xA7Y%s\xA7W, \xA7Y%s\xA7W)",
                    unitValue.text(), locationValue.text());
            }
            else if (!unitValue.empty()) {
                _snprintf_s(where, sizeof(where), _TRUNCATE, " (\xA7Y%s\xA7W)", unitValue.text());
            }
            whereValue.set(where);
        }

        const Game::String unitKey("UNIT");
        const Game::String locationKey("LOCATION");
        const Game::String whereKey("WHERE");
        replaceVariable(text, unitKey.raw(), unitValue.raw());
        replaceVariable(text, locationKey.raw(), locationValue.raw());
        replaceVariable(text, whereKey.raw(), whereValue.raw());
    }

    /**
    @brief stands in for the call that formats the leader's name

    esi is the leader here, put there by the search that found him in the country's
    list, and this is the last instruction that still has it - the register is reused
    two calls later. Nothing else changes: the call it replaced is made exactly as it
    was, and the caller takes its argument off the stack afterwards as it always did.
    */
    __declspec(naked) void hookedFormatName() {
        __asm {
            mov capturedLeader, esi     // which leader this text is about
            call [formatNameAddress]    // exactly the call this replaced
            jmp [jumpBackFormat]
        }
    }

    /**
    @brief stands in for the game's own $NAME$ replacement, and adds ours to it

    Ours go in first, which changes nothing - each replacement is a different variable
    - and leaves the stack exactly as the game's own call found it.

    On entry ecx is the text, esi the game's own key, and the value it is replacing
    with is already pushed. Everything a call could disturb is saved around ours.
    */
    __declspec(naked) void hookedReplaceName() {
        __asm {
            pushad
            pushfd
            push ecx                        // the text being built
            call addPlaceVariables
            add esp, 4
            popfd
            popad

            call [replaceVariableAddress]   // exactly the call this replaced
            jmp [jumpBackReplace]
        }
    }

    /**@brief whether the five bytes at \p site are a call to \p target*/
    bool callsTo(uintptr_t site, uintptr_t target) {
        unsigned char opcode = 0;
        int32_t relative = 0;
        if (!Mem::tryRead(site, opcode) || opcode != 0xE8) {
            return false;
        }
        if (!Mem::tryRead(site + 1, relative)) {
            return false;
        }
        return site + 5 + static_cast<uintptr_t>(static_cast<intptr_t>(relative)) == target;
    }
}

bool Hooks::EffectText::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }

    // Both sites are checked before either is written, so a build this does not fit
    // leaves the game untouched rather than half patched. Checking that each is a
    // call to the function it should be is stronger than checking five fixed bytes:
    // it survives the whole image moving and refuses anything else.
    if (!callsTo(base + FORMAT_NAME_SITE, base + FORMAT_NAME)
        || !callsTo(base + REPLACE_SITE, base + REPLACE_VARIABLE)) {
        statusText = "the kill_leader effect text is not what this build expects";
        ERROR_OUT(printf("EffectText hook: the code at %#010x is not what was expected\n",
            static_cast<unsigned>(base + FORMAT_NAME_SITE)));
        return false;
    }

    formatNameAddress = static_cast<DWORD>(base + FORMAT_NAME);
    replaceVariableAddress = static_cast<DWORD>(base + REPLACE_VARIABLE);
    jumpBackFormat = static_cast<DWORD>(base + FORMAT_NAME_SITE + 5);
    jumpBackReplace = static_cast<DWORD>(base + REPLACE_SITE + 5);

    // Five bytes for five: a call and a jump are the same size, so there is nothing
    // to pad.
    if (!Hooks::hook(reinterpret_cast<void*>(base + FORMAT_NAME_SITE), &hookedFormatName, 5, 0)
        || !Hooks::hook(reinterpret_cast<void*>(base + REPLACE_SITE), &hookedReplaceName, 5, 0)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("EffectText hooks installed at %#010x and %#010x\n",
        static_cast<unsigned>(base + FORMAT_NAME_SITE),
        static_cast<unsigned>(base + REPLACE_SITE)));
    return true;
}

bool Hooks::EffectText::installed() {
    return installedFlag;
}

const char* Hooks::EffectText::status() {
    return statusText;
}
