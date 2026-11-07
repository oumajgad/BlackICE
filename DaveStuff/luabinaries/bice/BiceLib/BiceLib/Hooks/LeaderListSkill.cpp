#include <Hooks/LeaderListSkill.hpp>

#include <GameClasses/CLeader.hpp>
#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdint>
#include <cstdio>

namespace {
    // mov esi, eax; mov ecx, esi; add esp, 0xC - the same seven bytes at both places
    const unsigned char REPLACED[7] = { 0x8B, 0xF0, 0x8B, 0xCE, 0x83, 0xC4, 0x0C };
    const int REPLACED_LENGTH = 7;

    const uintptr_t LIST_SITE = 0x365688;
    const uintptr_t SELECTED_SITE = 0x3679D4;

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the naked stubs, which is why they are plain words.
    DWORD listResume = 0;
    DWORD selectedResume = 0;
    DWORD leaderVFTable = 0;

    // Lives only until the game copies it, a few instructions on; see the header.
    char text[32] = {};

    /**@brief the text to show: ours for a leader, the game's for anything else*/
    const char* __stdcall skillText(uintptr_t leader, const char* gameText) {
        int32_t skill = 0;
        int32_t maxSkill = 0;
        if (Mem::readOr<uint32_t>(leader) != leaderVFTable
            || !Mem::tryRead(leader + CLeader::Offsets::skill, skill)
            || !Mem::tryRead(leader + CLeader::Offsets::max_skill, maxSkill)) {
            return gameText;
        }
        snprintf(text, sizeof(text), "%d (%d)", skill, maxSkill);
        return text;
    }

    /**
    @brief the list row: the leader is the constructor's argument at [ebp+0x14]

    Our pointer goes into the eax pushad saved, so the replayed `mov esi, eax` takes it.
    The flags are kept as every stub here keeps them.
    */
    __declspec(naked) void listStub() {
        __asm {
            pushad
            pushfd
            push eax                        // the game's text
            push dword ptr [ebp + 0x14]     // the leader
            call skillText
            mov [esp + 0x20], eax           // over the eax pushad saved
            popfd
            popad
            mov esi, eax                    // the seven bytes replaced
            mov ecx, esi
            add esp, 0xC
            jmp [listResume]
        }
    }

    /**@brief the selected leader: [ebp+0xC], where the constructor stored the unit's leader*/
    __declspec(naked) void selectedStub() {
        __asm {
            pushad
            pushfd
            push eax
            push dword ptr [ebp + 0xC]
            call skillText
            mov [esp + 0x20], eax
            popfd
            popad
            mov esi, eax
            mov ecx, esi
            add esp, 0xC
            jmp [selectedResume]
        }
    }
}

bool Hooks::LeaderListSkill::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Hooks::MODULE_BASE;
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::bytesAre(base + LIST_SITE, REPLACED, REPLACED_LENGTH)
        || !Hooks::bytesAre(base + SELECTED_SITE, REPLACED, REPLACED_LENGTH)) {
        statusText = "the leader window does not format the skill where this build expects";
        return false;
    }

    leaderVFTable = static_cast<DWORD>(base + CLeader::VFTable::CLeader);
    listResume = static_cast<DWORD>(base + LIST_SITE + REPLACED_LENGTH);
    selectedResume = static_cast<DWORD>(base + SELECTED_SITE + REPLACED_LENGTH);

    if (!Hooks::hookAt(base + LIST_SITE, &listStub, REPLACED, REPLACED_LENGTH)
        || !Hooks::hookAt(base + SELECTED_SITE, &selectedStub, REPLACED, REPLACED_LENGTH)) {
        statusText = "could not make the code writable";
        return false;
    }

    installedFlag = true;
    statusText = "installed";
    return true;
}

bool Hooks::LeaderListSkill::installed() {
    return installedFlag;
}

const char* Hooks::LeaderListSkill::status() {
    return statusText;
}
