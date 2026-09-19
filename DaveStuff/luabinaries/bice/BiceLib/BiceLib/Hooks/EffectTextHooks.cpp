#include <Hooks/EffectTextHooks.hpp>

#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCountryDataBase.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CLeader.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/GameString.hpp>
#include <GameState/Localisation.hpp>
#include <GameState/OobFile.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>
#include <cstring>
#include <map>
#include <string>

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

    // The load_oob effect's text builder, `CLoadOOBEffect::GetText` - slot 9 of its
    // vftable, the same slot the kill_leader one introduces. It looks the file path up
    // as though it were a localisation key, which finds nothing, and shows the path.
    //
    // The first site is the function's own first three instructions, taken together
    // because they come to exactly five bytes: all the stub wants is ecx, the effect,
    // which is gone two instructions later.
    const uintptr_t OOB_ENTRY_SITE = 0x5BBE40;
    const unsigned char OOB_ENTRY[5] = { 0x55, 0x8B, 0xEC, 0x6A, 0xFF };

    // The second is the last call before it returns, by which point the string the
    // effect will show has been built and is still in the frame at [ebp+8].
    const uintptr_t OOB_RELEASE_SITE = 0x5BBEB1;
    const uintptr_t RELEASE_REPLACEMENTS = 0x687020;

    // What an effect's scope carries: the country it is being asked about, as a
    // CCountryTag. The kill_leader builder reads the same field.
    const uintptr_t SCOPE_COUNTRY_TAG = 0x10;

    // Where CStringEffect keeps its string, which for this effect is the file path.
    const uintptr_t EFFECT_STRING = 0x20;

    bool installedFlag = false;
    bool oobInstalledFlag = false;
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

    DWORD releaseAddress = 0;
    DWORD jumpBackOobEntry = 0;
    DWORD jumpBackOobRelease = 0;

    // The same catch, for the load_oob effect: its own text builder loses `this` three
    // instructions in, and what is wanted from it - the path - is read at the end.
    uintptr_t capturedOobEffect = 0;

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
            // Without its own colours: $WHERE$ puts it inside one, and a
            // localisation that colours $UNIT$ would have the same trouble.
            unitValue.set(
                Game::withoutColours(Game::rawChars(unit + CUnit::Offsets::name)).c_str());

            uintptr_t province = 0;
            int provinceId = 0;
            if (Mem::tryRead(unit + CUnit::Offsets::current_province_ptr, province) && province != 0
                && Mem::tryRead(province + CMapProvince::Offsets::id, provinceId) && provinceId > 0) {
                // A province's name is localisation, not anything in memory: the
                // key is PROV<id>. Localisation::text does the looking up and the
                // rendering that the game's own lookup leaves to its caller.
                locationValue.set(Game::withoutColours(
                    Localisation::textForId("PROV", provinceId).c_str()).c_str());
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

    /**@brief the country an effect's scope is about, or 0*/
    uintptr_t countryOfScope(uintptr_t scope) {
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

    /**
    @brief the rank a unit of this kind is commanded by, or 0 where there is no rule

    The order of battle's own levels: a division is a major general's, a corps a
    lieutenant general's, and everything above them a general's. Ranks are 1 to 4 in the
    files - `ResetToStarting` is the only thing that writes 0.

    **Nothing asks for a field marshal.** Rank 4 is an honour rather than a job in this
    mod: army groups and theatres are held by generals often enough that wanting one
    would be wrong, which is David's reading of his own order of battle.

    Fleets and air commands are left alone: their levels do not line up with the land
    ones, and nothing here knows what they should be.
    */
    int rankFor(const std::string& kind) {
        if (kind == "division") {
            return 1;
        }
        if (kind == "corps") {
            return 2;
        }
        if (kind == "army") {
            return 3;
        }
        if (kind == "armygroup" || kind == "theatre") {
            return 3;
        }
        return 0;
    }

    /**
    @brief where a leader is now, as the tooltip should say it

    Read out of the running game rather than out of the file, which is the whole point:
    what the file says is what he is about to command, and this is what he leaves.

    **Coloured here** rather than by the caller, because whether there is anything to
    colour is the same question as what to say.
    */
    std::string leaderNow(uintptr_t leader) {
        uintptr_t unit = 0;
        if (!Mem::tryRead(leader + CLeader::Offsets::unit_ptr, unit) || unit == 0) {
            return "no command";
        }
        // Stripped: a unit name carrying its own colour would end the red below at
        // its first code, and leave the rest of the line looking unremarkable.
        std::string where = Game::withoutColours(Game::rawChars(unit + CUnit::Offsets::name));
        uintptr_t province = 0;
        int provinceId = 0;
        if (Mem::tryRead(unit + CUnit::Offsets::current_province_ptr, province) && province != 0
            && Mem::tryRead(province + CMapProvince::Offsets::id, provinceId) && provinceId > 0) {
            const std::string name =
                Game::withoutColours(Localisation::textForId("PROV", provinceId).c_str());
            if (!name.empty()) {
                where += ", " + name;
            }
        }
        // In red, because it is what the file takes away: this unit is about to lose
        // the leader it has. "no command" is left plain - nothing is being disturbed.
        return where.empty() ? "no command" : "\xA7R" + where + "\xA7W";
    }

    /**
    @brief what the load_oob effect should say, built from the file and the live game

    The counts and the leader ids come out of the file; who those leaders command comes
    out of the game. Long lists are cut short, because this is a tooltip - an order of
    battle for a whole country runs to hundreds of units in dozens of provinces.

    @param path the file, as the effect carries it
    @param scope what the option is being shown for, which says whose leaders to look at
    */
    std::string describeOob(const char* path, uintptr_t scope) {
        const OobFile::Summary& file = OobFile::of(path);
        std::string text = path;
        if (!file.found) {
            return text + "\n\xA7RNot in the mod or the game.\xA7W";
        }

        char line[512] = {};
        if (file.units > 0) {
            const int SHOWN = 4;
            std::string places;
            for (size_t i = 0; i < file.places.size() && i < SHOWN; i++) {
                const OobFile::Place& place = file.places[i];
                char one[128] = {};
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
            if (file.places.size() > SHOWN) {
                _snprintf_s(line, sizeof(line), _TRUNCATE, " and %d more",
                    static_cast<int>(file.places.size()) - SHOWN);
                places += line;
            }
            _snprintf_s(line, sizeof(line), _TRUNCATE, "\n\xA7Y%d\xA7W units in %s",
                file.units, places.c_str());
            text += line;
        }

        std::string made;
        if (file.brigades > 0) {
            _snprintf_s(line, sizeof(line), _TRUNCATE, "%d brigades", file.brigades);
            made += line;
        }
        if (file.ships > 0) {
            _snprintf_s(line, sizeof(line), _TRUNCATE, "%s%d ships",
                made.empty() ? "" : ", ", file.ships);
            made += line;
        }
        if (file.wings > 0) {
            _snprintf_s(line, sizeof(line), _TRUNCATE, "%s%d wings",
                made.empty() ? "" : ", ", file.wings);
            made += line;
        }
        if (!made.empty()) {
            text += "\n" + made;
        }
        if (file.constructions > 0) {
            _snprintf_s(line, sizeof(line), _TRUNCATE,
                "\n\xA7Y%d\xA7W added to production", file.constructions);
            text += line;
        }

        if (file.leaders.empty()) {
            return text;
        }

        // The country's own list, walked once: the ids in the file are its leaders,
        // and this is fresher than any cache - a game can be loaded over another.
        std::map<int, uintptr_t> byId;
        const uintptr_t country = countryOfScope(scope);
        if (country != 0) {
            const std::vector<uintptr_t> leaders =
                HDS::walkList(country + CCountry::Offsets::leaders);
            for (uintptr_t leader : leaders) {
                int id = 0;
                if (Mem::tryRead(leader + CLeader::Offsets::id, id)) {
                    byId.insert(std::make_pair(id, leader));
                }
            }
        }

        _snprintf_s(line, sizeof(line), _TRUNCATE, "\n\xA7Y%d\xA7W leaders take command:",
            static_cast<int>(file.leaders.size()));
        text += line;

        // Ten covers all but the largest starting orders of battle: 97.5% of the mod's
        // `history/units` files assign six leaders or fewer, and the handful above ten
        // are the whole-country ones - FRA_1936 has 150 - which no event loads.
        const int SHOWN = 10;
        int shown = 0;
        for (const OobFile::Assignment& assignment : file.leaders) {
            if (shown >= SHOWN) {
                _snprintf_s(line, sizeof(line), _TRUNCATE, "\n  and %d more",
                    static_cast<int>(file.leaders.size()) - shown);
                text += line;
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
    @brief writes the description over the string the effect was going to show

    Kept for a moment because a tooltip is rebuilt on every frame the mouse is over it,
    and this reads a file and walks a country's leaders. A second is short enough that
    a reassignment made while the tooltip is up still shows.

    @param out the string the effect shows, already built and holding the path
    @param scope what the option is being shown for
    */
    void __cdecl writeOobDescription(void* out, uintptr_t scope) {
        const uintptr_t effect = capturedOobEffect;
        capturedOobEffect = 0;      // one text, not the next
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
        const ULONGLONG now = GetTickCount64();
        if (kept.empty() || keptFor != path || now - keptAt > 1000) {
            keptFor = path;
            kept = describeOob(path, scope);
            keptAt = now;
        }
        Game::assignTo(out, kept.c_str());
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

    /**
    @brief stands in for the load_oob text builder's first three instructions

    Only to keep ecx, which is the effect and so the file path: three instructions
    later it has been turned into a pointer to the string inside it, and by the end of
    the function nothing has it at all. The three it replaces are reproduced exactly -
    the stub is jumped to, so the stack is what the function's own entry saw.
    */
    __declspec(naked) void hookedOobEntry() {
        __asm {
            mov capturedOobEffect, ecx      // which load_oob this text is about

            push ebp                        // exactly the three this replaced
            mov ebp, esp
            push -1

            jmp [jumpBackOobEntry]
        }
    }

    /**
    @brief stands in for the last call in the load_oob text builder

    By here the string the effect will show is built and sits at [ebp+8], and the scope
    at [ebp+0xC] - ebp is still the builder's own frame, which is what makes both
    reachable from a stub. The description goes in over it, then the call this replaced
    is made exactly as it was.
    */
    __declspec(naked) void hookedOobRelease() {
        __asm {
            pushad
            pushfd
            push dword ptr [ebp + 0x0C]     // the scope, for whose leaders to read
            push dword ptr [ebp + 8]        // the string the effect will show
            call writeOobDescription
            add esp, 8
            popfd
            popad

            call [releaseAddress]           // exactly the call this replaced
            jmp [jumpBackOobRelease]
        }
    }

    /**@brief whether the bytes at \p site are what this build should have there*/
    bool bytesMatch(uintptr_t site, const unsigned char* expected, int length) {
        for (int i = 0; i < length; i++) {
            unsigned char byte = 0;
            if (!Mem::tryRead(site + i, byte) || byte != expected[i]) {
                return false;
            }
        }
        return true;
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

bool Hooks::EffectText::installKillLeader() {
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

bool Hooks::EffectText::installLoadOob() {
    if (oobInstalledFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }

    // The entry is checked as bytes because it is a prologue rather than a call, and
    // the stub reproduces those exact instructions; the other is checked by resolving
    // the call, which survives the image moving.
    if (!bytesMatch(base + OOB_ENTRY_SITE, OOB_ENTRY, 5)
        || !callsTo(base + OOB_RELEASE_SITE, base + RELEASE_REPLACEMENTS)) {
        statusText = "the load_oob effect text is not what this build expects";
        ERROR_OUT(printf("EffectText hook: the code at %#010x is not what was expected\n",
            static_cast<unsigned>(base + OOB_ENTRY_SITE)));
        return false;
    }

    releaseAddress = static_cast<DWORD>(base + RELEASE_REPLACEMENTS);
    jumpBackOobEntry = static_cast<DWORD>(base + OOB_ENTRY_SITE + 5);
    jumpBackOobRelease = static_cast<DWORD>(base + OOB_RELEASE_SITE + 5);

    if (!Hooks::hook(reinterpret_cast<void*>(base + OOB_ENTRY_SITE), &hookedOobEntry, 5, 0)
        || !Hooks::hook(reinterpret_cast<void*>(base + OOB_RELEASE_SITE), &hookedOobRelease, 5, 0)) {
        statusText = "could not make the code writable";
        return false;
    }

    oobInstalledFlag = true;
    statusText = "installed";
    INFO_OUT(printf("EffectText load_oob hooks installed at %#010x and %#010x\n",
        static_cast<unsigned>(base + OOB_ENTRY_SITE),
        static_cast<unsigned>(base + OOB_RELEASE_SITE)));
    return true;
}

bool Hooks::EffectText::killLeaderInstalled() {
    return installedFlag;
}

bool Hooks::EffectText::loadOobInstalled() {
    return oobInstalledFlag;
}

const char* Hooks::EffectText::status() {
    return statusText;
}
