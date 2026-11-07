#include <Hooks/Tooltips/ParadropLine.hpp>

#include <GameClasses/CSubUnitDefinition.hpp>
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

        std::string text;
        if (blockers.empty()) {
            text = std::string("This unit ") + GREEN + "can" + WHITE + " be paradropped";
        } else {
            text = std::string("This unit ") + RED + "can not" + WHITE + " be paradropped:";
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

    copyCall = static_cast<DWORD>(base + COPY_CALL);
    copyResume = static_cast<DWORD>(base + COPY_RESUME);

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
