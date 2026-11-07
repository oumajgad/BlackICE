#include <Hooks/Tooltips/CombinedArmsLine.hpp>

#include <GameClasses/CCountry.hpp>
#include <GameClasses/GameMessage.hpp>
#include <GameClasses/GameString.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>
#include <cstdlib>
#include <string>

namespace {
    /**
     * **The indicator arm's copy of the group's name**: `call 0x401BD0` at `0x3EB4B0`,
     * `std::string::assignString(out, name, 0, -1)` with the arguments pushed and the tooltip
     * in ECX and EBX. The group is in EDI, and the arm goes on to use EDI after the call, so the
     * copy keeps it.
     */
    const uintptr_t COPY_SITE = 0x3EB4B0;
    const uintptr_t COPY_CALL = 0x1BD0;
    const uintptr_t COPY_RESUME = 0x3EB4B5;

    /**
     * **The unit database's global**, the one `CSubUnitDataBase::GetInstance` answers. The
     * combined arms groups are the vector at its `+0`, indexed by their one-based number - the
     * arm reaches the group as `begin[atoi(suffix)]`.
     */
    const uintptr_t UNIT_DATABASE = 0x16886F0;
    const uintptr_t GROUPS_BEGIN = 0x0;
    const uintptr_t GROUPS_END = 0x4;

    /**@brief more than combined_arms.txt will ever declare; a longer vector is a bad read*/
    const int MAX_GROUPS = 256;

    /**@brief a group's `base = yes`, a byte; the designer's base test reads it*/
    const uintptr_t GROUP_BASE = 0x24;
    /**@brief a group's `value`, thousandths*/
    const uintptr_t GROUP_VALUE = 0x28;

    /**@brief CTechnologyStatus: an array of ints, the research bonus of each group by index*/
    const uintptr_t GROUP_TECHNOLOGY_BONUS = 0x5C;

    /**@brief the game's own colour escapes, in Windows-1252 as the localisation stores them*/
    const char* const GREEN = "\xA7G";
    const char* const RED = "\xA7R";
    const char* const WHITE = "\xA7W";

    DWORD copyCall = 0;
    DWORD copyResume = 0;
    uintptr_t unitDatabase = 0;

    bool installedFlag = false;
    const char* statusText = "not installed";

    /**@brief the group's one-based number, or -1 if it is not in the database's vector*/
    int indexOf(uintptr_t group) {
        uintptr_t database = 0;
        uintptr_t begin = 0;
        uintptr_t end = 0;
        if (!Mem::tryRead(unitDatabase, database) || database == 0
            || !Mem::tryRead(database + GROUPS_BEGIN, begin)
            || !Mem::tryRead(database + GROUPS_END, end)
            || end < begin || (end - begin) / 4 > MAX_GROUPS) {
            return -1;
        }
        const int count = static_cast<int>((end - begin) / 4);
        for (int i = 1; i < count; i++) {
            uintptr_t entry = 0;
            if (Mem::tryRead(begin + i * 4, entry) && entry == group) {
                return i;
            }
        }
        return -1;
    }

    /**@brief the player's research bonus for group \p index, thousandths; 0 where unknown*/
    int technologyBonus(int index) {
        const uintptr_t country = Game::playerCountry();
        uintptr_t status = 0;
        uintptr_t bonuses = 0;
        int bonus = 0;
        if (country == 0
            || !Mem::tryRead(country + CCountry::Offsets::technology_status, status) || status == 0
            || !Mem::tryRead(status + GROUP_TECHNOLOGY_BONUS, bonuses) || bonuses == 0
            || !Mem::tryRead(bonuses + index * 4, bonus)) {
            return 0;
        }
        return bonus;
    }

    /**@brief thousandths as a signed percentage with one decimal - 125 is "+12.5%"*/
    std::string percent(int thousandths) {
        const int tenths = std::abs(thousandths);
        char buffer[32];
        sprintf_s(buffer, "%s%d.%d%%", thousandths < 0 ? "-" : "+", tenths / 10, tenths % 10);
        return buffer;
    }

    /**
    @brief adds the bonus and base lines under the name just copied into \p tooltip

    Anything unreadable leaves the tooltip as the game made it.
    */
    void __cdecl appendGroupLines(uintptr_t tooltip, uintptr_t group) {
        const int index = indexOf(group);
        if (index < 0) {
            return;
        }
        unsigned char base = 0;
        int value = 0;
        if (!Mem::tryRead(group + GROUP_BASE, base) || !Mem::tryRead(group + GROUP_VALUE, value)) {
            return;
        }
        const int technology = technologyBonus(index);

        std::string text = Game::rawChars(tooltip);
        text += "\nCombined arms bonus: " + percent(value + technology);
        if (technology != 0) {
            text += " (" + percent(technology) + " from technology)";
        }
        if (base != 0) {
            text += std::string("\nBase: ") + GREEN + "yes" + WHITE
                + " - activates combined arms for the division";
        } else {
            text += std::string("\nBase: ") + RED + "no" + WHITE
                + " - counts only alongside a base brigade";
        }
        Game::assignTo(reinterpret_cast<void*>(tooltip), text.c_str());
    }

    /**
    @brief makes the copy it replaced, then adds the lines

    Reached by a jump with the copy's arguments on the stack and the tooltip in ECX, as the
    call would have found them; the copy pops its own. EBX is the tooltip and EDI the group.
    */
    __declspec(naked) void groupNameCopied() {
        __asm {
            call [copyCall]                 // exactly the call this replaced

            pushad
            pushfd
            push edi                        // the group
            push ebx                        // the tooltip
            call appendGroupLines
            add esp, 8
            popfd
            popad

            jmp [copyResume]
        }
    }
}

bool Hooks::Tooltips::CombinedArmsLine::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = static_cast<uintptr_t>(Hooks::MODULE_BASE);
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::isCallTo(base + COPY_SITE, base + COPY_CALL)) {
        statusText = "the division designer's combined arms tooltip is not built where this "
            "build expects";
        ERROR_OUT(printf("CombinedArmsLine: %#010x is not the call expected\n",
            static_cast<unsigned>(base + COPY_SITE)));
        return false;
    }

    copyCall = static_cast<DWORD>(base + COPY_CALL);
    copyResume = static_cast<DWORD>(base + COPY_RESUME);
    unitDatabase = base + UNIT_DATABASE;

    if (!Hooks::hook(reinterpret_cast<void*>(base + COPY_SITE), &groupNameCopied, 5, 0)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("CombinedArmsLine: the division designer's combined arms tooltips say "
        "what each group gives\n"));
    return true;
}

bool Hooks::Tooltips::CombinedArmsLine::installed() {
    return installedFlag;
}

const char* Hooks::Tooltips::CombinedArmsLine::status() {
    return statusText;
}
