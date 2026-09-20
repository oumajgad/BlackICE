#include <Hooks/EffectText/KillLeaderText.hpp>

#include <Hooks/EffectText/EffectText.hpp>
#include <GameClasses/GameString.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>
#include <string>

namespace {
    // Inside the kill_leader effect's text builder, which is the function that owns the
    // string KILL_LEADER_EFFECT. Both sites are a five byte call, so a five byte jump
    // stands in for one exactly and the stub reproduces the call it replaced.
    //
    // The first is where the leader's name is formatted, and it is there rather than
    // anywhere later because esi still holds the leader: two calls on it is reused.
    const uintptr_t FORMAT_NAME_SITE = 0x5ADE62;

    // The second is the game's own `$NAME$` replacement, the last thing done to the
    // text. Standing here means ours go in beside it with the text still in hand.
    const uintptr_t REPLACE_SITE = 0x5ADE8A;

    // What those two sites call, checked rather than assumed.
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
    // the second. The two are forty bytes apart in one straight line, so this never has
    // to survive anything.
    uintptr_t capturedLeader = 0;

    /**
    @brief puts $UNIT$, $LOCATION$ and $WHERE$ into the text beside the game's $NAME$

    Called from the second stub with the text the game is about to put the leader's name
    into. A leader with no command leaves all three empty rather than absent, so a
    localisation that asks for one never shows a bare `$UNIT$`.

    @param text the std::string the effect's sentence is being built in
    */
    void __cdecl addPlaceVariables(void* text) {
        const uintptr_t leader = capturedLeader;
        capturedLeader = 0;     // one text, not the next
        if (text == nullptr || leader == 0) {
            return;
        }

        const Hooks::EffectText::Posting posting = Hooks::EffectText::postingOf(leader);

        // Punctuation and the game's own colour codes, and no words: a connector like
        // "in" would be English in a line the localisation is supposed to own. \xA7 is
        // the colour escape, Y yellow and W back to white, which is how the game
        // colours the leader's name in the same sentence.
        char where[256] = {};
        if (!posting.unit.empty() && !posting.province.empty()) {
            _snprintf_s(where, sizeof(where), _TRUNCATE, " (\xA7Y%s\xA7W, \xA7Y%s\xA7W)",
                posting.unit.c_str(), posting.province.c_str());
        }
        else if (!posting.unit.empty()) {
            _snprintf_s(where, sizeof(where), _TRUNCATE, " (\xA7Y%s\xA7W)",
                posting.unit.c_str());
        }

        Hooks::EffectText::setVariable(text, "UNIT", posting.unit.c_str());
        Hooks::EffectText::setVariable(text, "LOCATION", posting.province.c_str());
        Hooks::EffectText::setVariable(text, "WHERE", where);
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

    Ours go in first, which changes nothing - each replacement is a different variable -
    and leaves the stack exactly as the game's own call found it.

    On entry ecx is the text, esi the game's own key, and the value it is replacing with
    is already pushed. Everything a call could disturb is saved around ours.
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
}

bool Hooks::EffectText::KillLeader::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::EffectText::ready()) {
        statusText = "the effect text machinery is not where this build expects it";
        return false;
    }

    // Both sites are checked before either is written, so a build this does not fit
    // leaves the game untouched rather than half patched. Checking that each is a call
    // to the function it should be is stronger than checking five fixed bytes: it
    // survives the whole image moving and refuses anything else.
    if (!Hooks::isCallTo(base + FORMAT_NAME_SITE, base + FORMAT_NAME)
        || !Hooks::isCallTo(base + REPLACE_SITE, base + REPLACE_VARIABLE)) {
        statusText = "the kill_leader effect text is not what this build expects";
        ERROR_OUT(printf("KillLeaderText: the code at %#010x is not what was expected\n",
            static_cast<unsigned>(base + FORMAT_NAME_SITE)));
        return false;
    }

    formatNameAddress = static_cast<DWORD>(base + FORMAT_NAME);
    replaceVariableAddress = static_cast<DWORD>(base + REPLACE_VARIABLE);
    jumpBackFormat = static_cast<DWORD>(base + FORMAT_NAME_SITE + 5);
    jumpBackReplace = static_cast<DWORD>(base + REPLACE_SITE + 5);

    // Five bytes for five: a call and a jump are the same size, so there is nothing to
    // pad.
    if (!Hooks::hook(reinterpret_cast<void*>(base + FORMAT_NAME_SITE), &hookedFormatName, 5, 0)
        || !Hooks::hook(reinterpret_cast<void*>(base + REPLACE_SITE), &hookedReplaceName, 5, 0)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("KillLeaderText: hooks installed at %#010x and %#010x\n",
        static_cast<unsigned>(base + FORMAT_NAME_SITE),
        static_cast<unsigned>(base + REPLACE_SITE)));
    return true;
}

bool Hooks::EffectText::KillLeader::installed() {
    return installedFlag;
}

const char* Hooks::EffectText::KillLeader::status() {
    return statusText;
}
