#include <Hooks/Tooltips/ParadropLine.hpp>

#include <GameClasses/CSubUnitDefinition.hpp>
#include <GameClasses/GameMessage.hpp>
#include <GameClasses/GameString.hpp>
#include <GameState/Localisation.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <algorithm>
#include <cstdio>
#include <string>
#include <vector>

namespace {
    /**
     * **The `terrainbonus` arm's copy of the terrain text**: `call 0x401BD0` at `0x3EA9DB`,
     * `std::string::assignString(out, &designer->terrain_text, 0, -1)` with the three
     * arguments already pushed and the tooltip in ECX. The next instruction jumps to the
     * epilogue, which takes the return value from EBX itself, so nothing after the call
     * reads what it left in EAX.
     */
    const uintptr_t COPY_SITE = 0x3EA9DB;
    const uintptr_t COPY_CALL = 0x1BD0;
    const uintptr_t COPY_RESUME = 0x3EA9E0;

    /**@brief the design, a CList of CSubUnitDefinition*, on the CDivisionDesigner*/
    const uintptr_t DESIGN = 0x1B4;

    /**
     * **`MakeCountrySubUnitDefinition(country, type, out)`**, `__stdcall`, `ret 0xC`: the
     * type's figures at the country's current levels, copied into `out`. The design's
     * definitions are the database's own, with no research in them, and technology does move
     * `transport_weight`. Checked through the brigade picker's own call to it.
     */
    const uintptr_t MAKE_COUNTRY_DEFINITION = 0x107500;
    const uintptr_t MAKE_COUNTRY_DEFINITION_CALLER = 0x3ED3A4;
    typedef void* (__stdcall* MakeCountryDefinition)(uintptr_t country, uintptr_t type, void* out);

    /**
     * **`CSubUnitDefinition(this, name, index)`**, `__stdcall`, `ret 0xC`. `out` above has to
     * be a constructed definition, because the copy into it assigns strings and vectors.
     * Checked through `UpdateDesign`'s own call to it, which passes `---` and 0 to a block of
     * `DEFINITION_SIZE` bytes.
     */
    const uintptr_t CONSTRUCT_DEFINITION = 0x1A3510;
    const uintptr_t CONSTRUCT_DEFINITION_CALLER = 0x3E6B9B;
    typedef void* (__stdcall* ConstructDefinition)(void* self, const void* name, int index);
    const size_t DEFINITION_SIZE = 0x228;

    /**@brief a unit's figures are thousandths; the boarding test compares whole ones*/
    const int THOUSAND = 1000;

    /**@brief more than any division holds; a list longer than this is not the design*/
    const int MAX_BRIGADES = 64;

    /**@brief the game's own colour escapes, in Windows-1252 as the localisation stores them*/
    const char* const GREEN = "\xA7G";
    const char* const RED = "\xA7R";
    const char* const WHITE = "\xA7W";

    /**@brief what the game indents a trigger's lines by, one level*/
    const char* const INDENT = "   ";

    DWORD copyCall = 0;
    DWORD copyResume = 0;
    MakeCountryDefinition makeCountryDefinition = nullptr;
    ConstructDefinition constructDefinition = nullptr;

    /**
     * **The one definition the country's versions are made into**, constructed by the game's
     * own constructor the first time it is wanted and then reused: each make assigns over it.
     * Never destroyed, so whatever it holds lives as long as the process, which is one
     * definition's worth.
     */
    alignas(8) unsigned char countryDefinition[DEFINITION_SIZE];
    bool countryDefinitionMade = false;

    /**
     * **The last weight worked out, and what it was worked out for.** The tooltip is asked
     * for again while the mouse rests on it, and each make builds and destroys a regiment,
     * so the same design for the same country is answered from here. Research finished
     * while the tooltip is up shows from the next change to the design.
     */
    std::vector<uintptr_t> weighedBrigades;
    uintptr_t weighedCountry = 0;
    int weighedWeight = -1;

    bool installedFlag = false;
    const char* statusText = "not installed";

    /**@brief the type's name as the picker shows it - its key, localised - or the key*/
    std::string nameOf(uintptr_t definition) {
        const std::string key =
            HDS::readStringAsStored(definition + CSubUnitDefinition::Offsets::key);
        if (key.empty()) {
            return "?";
        }
        const std::string name = Localisation::text(key.c_str());
        return name.empty() ? key : name;
    }

    /**
    @brief the design's transport weight at the player's levels, whole, or -1 where unknown

    What `CAir::MayLoad` compares against a plane's room: the sum of the brigades'
    `transport_weight`, cut to a whole number. Each brigade's is its type made at the
    country's levels, as the picker's columns are.
    */
    int designWeight(const std::vector<uintptr_t>& brigades) {
        const uintptr_t country = Game::playerCountry();
        if (country == 0) {
            return -1;
        }
        if (country == weighedCountry && brigades == weighedBrigades) {
            return weighedWeight;
        }

        if (!countryDefinitionMade) {
            const Game::String name("---");
            constructDefinition(countryDefinition, name.raw(), 0);
            countryDefinitionMade = true;
        }

        int total = 0;
        for (uintptr_t type : brigades) {
            makeCountryDefinition(country, type, countryDefinition);
            int weight = 0;
            if (!Mem::tryRead(reinterpret_cast<uintptr_t>(countryDefinition)
                    + CSubUnitDefinition::Offsets::weight, weight)) {
                return -1;
            }
            total += weight;
        }

        weighedBrigades = brigades;
        weighedCountry = country;
        weighedWeight = total / THOUSAND;
        return weighedWeight;
    }

    /**
    @brief puts the paradrop line in front of the terrain text just copied into \p tooltip

    The text is `GuiTooltipText + 0`, the string the call above wrote. Anything unreadable
    leaves the tooltip as the game made it: a wrong answer here would be worse than none.
    */
    void __cdecl prependParadrop(uintptr_t tooltip, uintptr_t designer) {
        const std::vector<uintptr_t> brigades = HDS::walkList(designer + DESIGN, MAX_BRIGADES);
        if (brigades.empty()) {
            return;
        }

        std::vector<std::string> blockers;
        for (uintptr_t definition : brigades) {
            unsigned char canParadrop = 0;
            if (!Mem::tryRead(definition + CSubUnitDefinition::Offsets::can_paradrop,
                    canParadrop)) {
                return;
            }
            if (canParadrop != 0) {
                continue;
            }
            const std::string name = nameOf(definition);
            if (std::find(blockers.begin(), blockers.end(), name) == blockers.end()) {
                blockers.push_back(name);
            }
        }

        std::string weight;
        const int whole = designWeight(brigades);
        if (whole >= 0) {
            weight = " (Weight: " + std::to_string(whole) + ")";
        }

        std::string text;
        if (blockers.empty()) {
            text = std::string("This unit ") + GREEN + "can" + WHITE + " be paradropped"
                + weight;
        } else {
            text = std::string("This unit ") + RED + "can not" + WHITE + " be paradropped"
                + weight + ":";
            for (const std::string& name : blockers) {
                text += "\n";
                text += INDENT;
                text += name;
            }
        }

        const std::string terrain = Game::rawChars(tooltip);
        if (!terrain.empty()) {
            text += "\n\n" + terrain;
        }
        Game::assignTo(reinterpret_cast<void*>(tooltip), text.c_str());
    }

    /**
    @brief makes the copy it replaced, then adds the line

    Reached by a jump with the copy's three arguments on the stack and the tooltip in ECX,
    exactly as the call would have found them; the copy pops its own arguments. EBX is the
    tooltip and `[ebp - 0x14]` the designer throughout the arm.
    */
    __declspec(naked) void terrainTextCopied() {
        __asm {
            call [copyCall]                 // exactly the call this replaced

            pushad
            pushfd
            push dword ptr [ebp - 0x14]     // the designer
            push ebx                        // the tooltip
            call prependParadrop
            add esp, 8
            popfd
            popad

            jmp [copyResume]
        }
    }
}

bool Hooks::Tooltips::ParadropLine::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = static_cast<uintptr_t>(Hooks::MODULE_BASE);
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::isCallTo(base + COPY_SITE, base + COPY_CALL)) {
        statusText = "the division designer's terrain tooltip is not built where this "
            "build expects";
        ERROR_OUT(printf("ParadropLine: %#010x is not the call expected\n",
            static_cast<unsigned>(base + COPY_SITE)));
        return false;
    }

    if (!Hooks::isCallTo(base + MAKE_COUNTRY_DEFINITION_CALLER, base + MAKE_COUNTRY_DEFINITION)
        || !Hooks::isCallTo(base + CONSTRUCT_DEFINITION_CALLER, base + CONSTRUCT_DEFINITION)) {
        statusText = "the functions the weight is made with are not where this build "
            "expects";
        ERROR_OUT(printf("ParadropLine: MakeCountrySubUnitDefinition or the definition "
            "constructor is not where expected\n"));
        return false;
    }

    copyCall = static_cast<DWORD>(base + COPY_CALL);
    copyResume = static_cast<DWORD>(base + COPY_RESUME);
    makeCountryDefinition = reinterpret_cast<MakeCountryDefinition>(base + MAKE_COUNTRY_DEFINITION);
    constructDefinition = reinterpret_cast<ConstructDefinition>(base + CONSTRUCT_DEFINITION);

    if (!Hooks::hook(reinterpret_cast<void*>(base + COPY_SITE), &terrainTextCopied, 5, 0)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("ParadropLine: the division designer's terrain tooltip says whether "
        "the design can be paradropped\n"));
    return true;
}

bool Hooks::Tooltips::ParadropLine::installed() {
    return installedFlag;
}

const char* Hooks::Tooltips::ParadropLine::status() {
    return statusText;
}
