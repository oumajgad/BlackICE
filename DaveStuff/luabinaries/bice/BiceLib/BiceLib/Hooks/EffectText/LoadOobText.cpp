#include <Hooks/EffectText/LoadOobText.hpp>

#include <Hooks/EffectText/EffectText.hpp>
#include <GameClasses/CCountry.hpp>
#include <GameClasses/CLeader.hpp>
#include <GameClasses/GameString.hpp>
#include <GameState/OobFile.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>
#include <map>
#include <string>

namespace {
    // The load_oob effect's text builder, `CLoadOOBEffect::GetText` - slot 9 of its
    // vftable, the same slot the kill_leader one introduces.
    //
    // The first site is the function's own first three instructions, taken together
    // because they come to exactly five bytes: all the stub wants is ecx, the effect,
    // which is gone two instructions later.
    const uintptr_t ENTRY_SITE = 0x5BBE40;
    const unsigned char ENTRY_BYTES[5] = { 0x55, 0x8B, 0xEC, 0x6A, 0xFF };

    // The second is the last call before it returns, by which point the string the
    // effect will show has been built and is still in the frame at [ebp+8].
    const uintptr_t RELEASE_SITE = 0x5BBEB1;
    const uintptr_t RELEASE_REPLACEMENTS = 0x687020;

    // Where CStringEffect keeps its string, which for this effect is the file path.
    const uintptr_t EFFECT_STRING = 0x20;

    // How much of a long list a tooltip is given. Ten leaders covers all but the
    // largest starting orders of battle: 97.5% of the mod's `history/units` files
    // assign six or fewer, and the handful above ten are the whole-country ones -
    // FRA_1936 has 150 - which no event loads.
    //
    // **Holding Alt lifts both**, so the few files that do go over can still be read
    // in full. See altHeld.
    const int LEADERS_SHOWN = 10;
    const int PLACES_SHOWN = 4;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    DWORD releaseAddress = 0;
    DWORD jumpBackEntry = 0;
    DWORD jumpBackRelease = 0;

    // Which load_oob the text is being built for: the builder loses `this` three
    // instructions in, and what is wanted from it - the path - is read at the end.
    uintptr_t capturedEffect = 0;

    /**
    @brief the rank a unit of this kind is commanded by, or 0 where there is no rule

    The order of battle's own levels. Ranks are 1 to 4 in the files - `ResetToStarting`
    is the only thing that writes 0 - so the number is the level, except that **nothing
    asks for a field marshal**: rank 4 is an honour rather than a job in this mod.

    Fleets and air commands are left alone: their levels do not line up with the land
    ones, and nothing here knows what they should be. LoadOobText.hpp has the numbers
    this was chosen against.
    */
    int rankFor(const std::string& kind) {
        if (kind == "division") {
            return 1;
        }
        if (kind == "corps") {
            return 2;
        }
        if (kind == "army" || kind == "armygroup" || kind == "theatre") {
            return 3;
        }
        return 0;
    }

    /**
    @brief where a leader is now, as this tooltip should say it

    In red, because it is what the file takes away: the unit is about to lose the leader
    it has. "no command" is left plain - nothing is being disturbed.
    */
    std::string leaderNow(uintptr_t leader) {
        const Hooks::EffectText::Posting posting = Hooks::EffectText::postingOf(leader);
        if (!posting.any()) {
            return "no command";
        }
        std::string where = posting.unit;
        if (!posting.province.empty()) {
            where += ", " + posting.province;
        }
        return "\xA7R" + where + "\xA7W";
    }

    /**
    @brief whether either Alt is down right now

    `GetAsyncKeyState` rather than anything the game keeps, because this runs on
    whichever thread is drawing the tooltip and has no business reading the game's input
    state. `VK_MENU` is both Alt keys. The high bit is "down now"; the low bit is "was
    pressed since last asked" and is deliberately not used - it would latch a tap that
    happened while the mouse was somewhere else entirely.

    It is read afresh for every rebuild, so the tooltip answers the key while it is up.
    */
    bool altHeld() {
        return (GetAsyncKeyState(VK_MENU) & 0x8000) != 0;
    }

    /**
    @brief the provinces the file's units appear in, as one line

    @param showAll  every place rather than the first few
    @param hidAny   set when something was left out, cleared never - the caller passes
                    one flag through the whole description so the hint is offered once
    */
    std::string placesLine(const OobFile::Summary& file, bool showAll, bool& hidAny) {
        std::string places;
        char one[128] = {};
        const size_t limit = showAll ? file.places.size() : PLACES_SHOWN;
        for (size_t i = 0; i < file.places.size() && i < limit; i++) {
            const OobFile::Place& place = file.places[i];
            const std::string name = place.name.empty()
                ? std::to_string(place.provinceId) : place.name;
            if (place.units > 1) {
                _snprintf_s(one, sizeof(one), _TRUNCATE, "%s\xA7Y%s\xA7W (%d)",
                    places.empty() ? "" : ", ", name.c_str(), place.units);
            }
            else {
                _snprintf_s(one, sizeof(one), _TRUNCATE, "%s\xA7Y%s\xA7W",
                    places.empty() ? "" : ", ", name.c_str());
            }
            places += one;
        }
        if (file.places.size() > limit) {
            _snprintf_s(one, sizeof(one), _TRUNCATE, " and %d more",
                static_cast<int>(file.places.size() - limit));
            places += one;
            hidAny = true;
        }
        return places;
    }

    /**@brief what the file's units are made of, as one line; empty if nothing is*/
    std::string madeOfLine(const OobFile::Summary& file) {
        std::string made;
        char one[64] = {};
        if (file.brigades > 0) {
            _snprintf_s(one, sizeof(one), _TRUNCATE, "%d brigades", file.brigades);
            made += one;
        }
        if (file.ships > 0) {
            _snprintf_s(one, sizeof(one), _TRUNCATE, "%s%d ships",
                made.empty() ? "" : ", ", file.ships);
            made += one;
        }
        if (file.wings > 0) {
            _snprintf_s(one, sizeof(one), _TRUNCATE, "%s%d wings",
                made.empty() ? "" : ", ", file.wings);
            made += one;
        }
        return made;
    }

    /**
    @brief the country's leaders by id

    Walked fresh rather than taken from a cache: a game can be loaded over another, and
    a tooltip is not worth a stale address.
    */
    std::map<int, uintptr_t> leadersOf(uintptr_t country) {
        std::map<int, uintptr_t> byId;
        if (country == 0) {
            return byId;
        }
        const std::vector<uintptr_t> leaders =
            HDS::walkList(country + CCountry::Offsets::leaders);
        for (uintptr_t leader : leaders) {
            int id = 0;
            if (Mem::tryRead(leader + CLeader::Offsets::id, id)) {
                byId.insert(std::make_pair(id, leader));
            }
        }
        return byId;
    }

    /**
    @brief the leaders the file takes, and what each of them leaves behind

    @param showAll  every leader rather than the first ten
    @param hidAny   set when some were left out
    */
    std::string leadersPart(const OobFile::Summary& file, uintptr_t scope,
        bool showAll, bool& hidAny) {
        if (file.leaders.empty()) {
            return "";
        }
        const std::map<int, uintptr_t> byId =
            leadersOf(Hooks::EffectText::countryOfScope(scope));

        char line[512] = {};
        _snprintf_s(line, sizeof(line), _TRUNCATE, "\n\xA7Y%d\xA7W leaders take command:",
            static_cast<int>(file.leaders.size()));
        std::string text = line;

        int shown = 0;
        for (const OobFile::Assignment& assignment : file.leaders) {
            if (!showAll && shown >= LEADERS_SHOWN) {
                _snprintf_s(line, sizeof(line), _TRUNCATE, "\n  and %d more",
                    static_cast<int>(file.leaders.size()) - shown);
                text += line;
                hidAny = true;
                break;
            }
            shown++;

            const std::map<int, uintptr_t>::const_iterator found = byId.find(assignment.leaderId);
            if (found == byId.end()) {
                _snprintf_s(line, sizeof(line), _TRUNCATE,
                    "\n  \xA7R%d - not one of this country's leaders\xA7W",
                    assignment.leaderId);
                text += line;
                continue;
            }
            _snprintf_s(line, sizeof(line), _TRUNCATE, "\n  \xA7Y%s\xA7W to a %s - %s",
                Game::withoutColours(
                    Game::rawChars(found->second + CLeader::Offsets::name)).c_str(),
                assignment.kind.empty() ? "unit" : assignment.kind.c_str(),
                leaderNow(found->second).c_str());
            text += line;

            // The rank the job wants against the rank he holds. Said in red because it
            // is a mistake in the file rather than something the player can act on.
            const int wanted = rankFor(assignment.kind);
            int rank = 0;
            if (wanted > 0 && Mem::tryRead(found->second + CLeader::Offsets::rank, rank)
                && rank < wanted) {
                _snprintf_s(line, sizeof(line), _TRUNCATE,
                    "\n    \xA7Rrank %d, and a %s wants %d\xA7W",
                    rank, assignment.kind.c_str(), wanted);
                text += line;
            }
        }
        return text;
    }

    /**
    @brief what the effect should say, built from the file and the live game

    The counts and the leader ids come out of the file; who those leaders command comes
    out of the game.

    @param path the file, as the effect carries it
    @param scope what the option is being shown for, which says whose leaders to look at
    @param showAll every place and every leader, however many there are
    */
    std::string describe(const char* path, uintptr_t scope, bool showAll) {
        const OobFile::Summary& file = OobFile::of(path);
        std::string text = path;
        if (!file.found) {
            return text + "\n\xA7RNot in the mod or the game.\xA7W";
        }

        bool hidAny = false;
        char line[512] = {};
        if (file.units > 0) {
            _snprintf_s(line, sizeof(line), _TRUNCATE, "\n\xA7Y%d\xA7W units in %s",
                file.units, placesLine(file, showAll, hidAny).c_str());
            text += line;
        }
        const std::string made = madeOfLine(file);
        if (!made.empty()) {
            text += "\n" + made;
        }
        if (file.constructions > 0) {
            _snprintf_s(line, sizeof(line), _TRUNCATE,
                "\n\xA7Y%d\xA7W added to production", file.constructions);
            text += line;
        }
        text += leadersPart(file, scope, showAll, hidAny);

        // Only when something was actually left out: a tooltip that fits should not
        // spend a line telling the player about a key that would change nothing.
        //
        // It ends with a newline of its own. An option can carry more than one
        // `load_oob`, and the game runs their texts straight together - so without it
        // the next file's path starts on the end of this line.
        if (hidAny) {
            text += "\n\xA7Ghold Alt for the rest\xA7W\n";
        }
        return text;
    }

    /**
    @brief writes the description over the string the effect was going to show

    Kept for a moment because a tooltip is rebuilt on every frame the mouse is over it,
    and this reads a file and walks a country's leaders. A second is short enough that a
    reassignment made while the tooltip is up still shows.

    **Alt is part of what the kept text is of.** Keeping it on the path alone would make
    the key look broken for up to a second - the player holds Alt, the tooltip carries on
    showing the short version, and by the time it changes they have let go. It costs one
    extra rebuild each time the key changes and nothing at all otherwise.

    @param out the string the effect shows, already built and holding the path
    @param scope what the option is being shown for
    */
    void __cdecl writeDescription(void* out, uintptr_t scope) {
        const uintptr_t effect = capturedEffect;
        capturedEffect = 0;     // one text, not the next
        if (out == nullptr || effect == 0) {
            return;
        }
        const char* path = Game::rawChars(effect + EFFECT_STRING);
        if (path[0] == 0) {
            return;
        }

        static std::string keptFor;
        static std::string kept;
        static ULONGLONG keptAt = 0;
        static bool keptAll = false;
        const bool showAll = altHeld();
        const ULONGLONG now = GetTickCount64();
        if (kept.empty() || keptFor != path || keptAll != showAll
            || now - keptAt > 1000) {
            keptFor = path;
            keptAll = showAll;
            kept = describe(path, scope, showAll);
            keptAt = now;
        }
        Game::assignTo(out, kept.c_str());
    }

    /**
    @brief stands in for the text builder's first three instructions

    Only to keep ecx, which is the effect and so the file path: three instructions later
    it has become a pointer to the string inside it, and by the end of the function
    nothing has it at all. The three it replaces are reproduced exactly - the stub is
    jumped to, so the stack is what the function's own entry saw.
    */
    __declspec(naked) void hookedEntry() {
        __asm {
            mov capturedEffect, ecx     // which load_oob this text is about

            push ebp                    // exactly the three this replaced
            mov ebp, esp
            push -1

            jmp [jumpBackEntry]
        }
    }

    /**
    @brief stands in for the last call in the text builder

    By here the string the effect will show is built and sits at [ebp+8], and the scope
    at [ebp+0xC] - ebp is still the builder's own frame, which is what makes both
    reachable from a stub. The description goes in over it, then the call this replaced
    is made exactly as it was.
    */
    __declspec(naked) void hookedRelease() {
        __asm {
            pushad
            pushfd
            push dword ptr [ebp + 0x0C]     // the scope, for whose leaders to read
            push dword ptr [ebp + 8]        // the string the effect will show
            call writeDescription
            add esp, 8
            popfd
            popad

            call [releaseAddress]           // exactly the call this replaced
            jmp [jumpBackRelease]
        }
    }
}

bool Hooks::EffectText::LoadOob::install() {
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

    // The entry is checked as bytes because it is a prologue rather than a call, and
    // the stub reproduces those exact instructions; the other is checked by resolving
    // the call, which survives the image moving.
    if (!Hooks::bytesAre(base + ENTRY_SITE, ENTRY_BYTES, 5)
        || !Hooks::isCallTo(base + RELEASE_SITE, base + RELEASE_REPLACEMENTS)) {
        statusText = "the load_oob effect text is not what this build expects";
        ERROR_OUT(printf("LoadOobText: the code at %#010x is not what was expected\n",
            static_cast<unsigned>(base + ENTRY_SITE)));
        return false;
    }

    releaseAddress = static_cast<DWORD>(base + RELEASE_REPLACEMENTS);
    jumpBackEntry = static_cast<DWORD>(base + ENTRY_SITE + 5);
    jumpBackRelease = static_cast<DWORD>(base + RELEASE_SITE + 5);

    if (!Hooks::hook(reinterpret_cast<void*>(base + ENTRY_SITE), &hookedEntry, 5, 0)
        || !Hooks::hook(reinterpret_cast<void*>(base + RELEASE_SITE), &hookedRelease, 5, 0)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("LoadOobText: hooks installed at %#010x and %#010x\n",
        static_cast<unsigned>(base + ENTRY_SITE),
        static_cast<unsigned>(base + RELEASE_SITE)));
    return true;
}

bool Hooks::EffectText::LoadOob::installed() {
    return installedFlag;
}

const char* Hooks::EffectText::LoadOob::status() {
    return statusText;
}
