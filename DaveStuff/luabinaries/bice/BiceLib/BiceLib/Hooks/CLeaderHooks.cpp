#include <Windows.h>
#include <string>
#include <iostream>

#include <utils.hpp>

#include <Hooks/Hooks.hpp>
#include <Hooks/CLeaderHooks.hpp>

// Jumpbacks
DWORD Hooks::CLeader::jumpBack_leaderDontSaveRankSpecificTraitsHook;
DWORD Hooks::CLeader::jumpBack_leaderRankChangeHook;
DWORD Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkill;
DWORD Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkillSelected;

// Activation vars
bool Hooks::CLeader::isLeaderRankChangeHookActive = false;
bool Hooks::CLeader::isLeaderSkillLossOnPromotionActive = false;
bool Hooks::CLeader::isRankSpecificTraitsActive = false;

// Misc
HDS::Hoi3CString Hooks::CLeader::emptyString = {" ", 1};

int Hooks::CLeader::getPureSkillAndTraitListNode(DWORD* leaderAddress, HDS::LinkedListNodeSingle** out) {
    DEBUG_OUT(printf("getPureSkillAndTraitListNode called \n"));
    DWORD pureSkill = 0;
    HDS::LinkedListNodeSingle* traitListNode = (HDS::LinkedListNodeSingle*)*((DWORD*)leaderAddress + (0x30 / 4));
    while (traitListNode != 0) {
        DEBUG_OUT(printf("traitListNode: %#010x \n", (uintptr_t)traitListNode));
        DEBUG_OUT(printf("data: %#010x \n", (uintptr_t)traitListNode->data));
        DEBUG_OUT(printf("prev: %#010x \n", (uintptr_t)traitListNode->prev));
        DEBUG_OUT(printf("next: %#010x \n", (uintptr_t)traitListNode->next));

        DWORD trait = traitListNode->data;
        DWORD traitNameLength = *((DWORD*)trait + (0x3C / 4));
        char* traitName;
        if (traitNameLength > 15) {
            traitName = (char*)*(DWORD*)((BYTE*)trait + 0x2C);
        }
        else {
            traitName = (char*)((BYTE*)trait + 0x2C);
        }

        std::string traitNameAsString = std::string(traitName);
        DEBUG_OUT(printf("traitNameAsString: %s \n", traitNameAsString.c_str()));
        if (traitNameAsString.find("pskill_") == 0) {
            auto substr = traitNameAsString.substr(7);
            pureSkill = std::stoi(substr, nullptr, 10);
            DEBUG_OUT(printf("pureSkill: %i \n", pureSkill));
            *out = traitListNode;
            return pureSkill;
        }
        DEBUG_OUT(printf("----------\n"));

        traitListNode = (HDS::LinkedListNodeSingle*)traitListNode->next;
    }
    DEBUG_OUT(printf("traitListNode == 0 \n"));
    return 0;
}

std::vector<DWORD>* Hooks::CLeader::skillTraits;
bool Hooks::CLeader::checkTraitSkillLevelConsistency(DWORD* leaderAddress) {
    DWORD currentRank = *((BYTE*)leaderAddress + 0x6C);
    DWORD currentSkill = *((BYTE*)leaderAddress + 0x70);
    DWORD experience = *((BYTE*)leaderAddress + 0x78);

    DEBUG_OUT(printf("currentRank: %i \n", currentRank));
    DEBUG_OUT(printf("currentSkill: %i \n", currentSkill));
    DEBUG_OUT(printf("experience: %u \n", experience));

    HDS::LinkedListNodeSingle* traitListNode = 0;
    DWORD pureSkill = getPureSkillAndTraitListNode(leaderAddress, &traitListNode);
    DEBUG_OUT(printf("pureSkill: %i \n", pureSkill));
    if (traitListNode == 0) {
        DEBUG_OUT(printf("traitListNode == 0 \n"));
        return false;
    }

    int expectedSkill = (pureSkill - (currentRank - 1));
    if (expectedSkill > 0) {
        int gainedSkill = currentSkill - expectedSkill;
        DEBUG_OUT(printf("gainedSkill: %i \n", gainedSkill));
        if (gainedSkill > 0) {
            DEBUG_OUT(printf("gainedSkill > 0 \n"));
            auto newTrait = skillTraits->at(pureSkill + gainedSkill);
            DEBUG_OUT(printf("newTrait: %#010x \n", newTrait));
            traitListNode->data = newTrait;
        }
    }
    return true;
}
struct SkillLevelExp {
    int level;  // skill level
    DWORD exp; // first DWORD of the experience / second one should be zeroed. the game does not handle skill above 10 well
    DWORD exp_1Perc_step; // 1% Point step
};
SkillLevelExp skillExperiencePerLevel[16] = {
    {0, 0, 327680},
    {1, 32768000, 327680},
    {2, 65536000, 655360},
    {3, 131072000, 1310720},
    {4, 262144000, 1310720},
    {5, 393216000, 1966080},
    {6, 589824000, 2293760},
    {7, 819200000, 2621440},
    {8, 1081344000 ,3276800},
    {9, 1409024000, 5570560},
    {10, 1966080000, 0}
};
typedef void(__stdcall* getLeaderExperiencePercentFunction)(int param_1, unsigned int* param_2);
void Hooks::CLeader::adjustSkillLevel(DWORD* leaderAddress, DWORD* CPromoteLeaderCommand, DWORD newRank) {
    DEBUG_OUT(printf("adjustSkillLevel called \n"));

    UINT8 currentSkill = *((BYTE*)leaderAddress + 0x70);
    DWORD experience = *(DWORD*)((BYTE*)leaderAddress + 0x78);
    UINT8 direction = *((BYTE*)CPromoteLeaderCommand + 0x64); // 0 = Higher Rank ; 1 = Lower Rank

    getLeaderExperiencePercentFunction getLeaderExperiencePercent = reinterpret_cast<getLeaderExperiencePercentFunction>(Hooks::MODULE_BASE + 0x181c50);
    unsigned int experiencePercent = 0; // 1000 = 100% - 500 = 50%
    getLeaderExperiencePercent((int)leaderAddress, &experiencePercent);

    DEBUG_OUT(printf("currentSkill: %i \n", (int) currentSkill));
    DEBUG_OUT(printf("direction: %i \n", (int) direction));
    DEBUG_OUT(printf("newRank: %i \n", (int) newRank));
    DEBUG_OUT(printf("experience: %u \n", experience));
    DEBUG_OUT(printf("experiencePercent: %u \n", experiencePercent));

    HDS::LinkedListNodeSingle* traitListNode = 0;
    int pureSkill = getPureSkillAndTraitListNode(leaderAddress, &traitListNode);
    DEBUG_OUT(printf("pureSkill: %i \n", pureSkill));
    DEBUG_OUT(printf("pureSkill - (int) newRank: %i \n", pureSkill - (int)newRank));

    if (direction == 1 && (pureSkill - (int)newRank) >= 0) { // Demotion
        *((BYTE*)leaderAddress + 0x70) = currentSkill + 1;
        if (experiencePercent > 0 && experiencePercent < 1000) { // bounds check
            *(DWORD*)((BYTE*)leaderAddress + 0x78) = (skillExperiencePerLevel[currentSkill + 1].exp) + (experiencePercent / 10 * skillExperiencePerLevel[currentSkill + 1].exp_1Perc_step);
            *(DWORD*)((BYTE*)leaderAddress + 0x7C) = 0;
        }
        else { // the percentage makes no sense -> fall back to 0
            *(DWORD*)((BYTE*)leaderAddress + 0x78) = skillExperiencePerLevel[currentSkill + 1].exp;
            *(DWORD*)((BYTE*)leaderAddress + 0x7C) = 0;
        }
    }
    else if (direction == 0 && currentSkill != 0) { // Promotion
        *((BYTE*)leaderAddress + 0x70) = currentSkill - 1;
        if (experiencePercent > 0 && experiencePercent < 1000) { // bounds check
            *(DWORD*)((BYTE*)leaderAddress + 0x78) = (skillExperiencePerLevel[currentSkill - 1].exp) + (experiencePercent / 10 * skillExperiencePerLevel[currentSkill - 1].exp_1Perc_step);
            *(DWORD*)((BYTE*)leaderAddress + 0x7C) = 0;
        }
        else { // the percentage makes no sense -> fall back to 0
            *(DWORD*)((BYTE*)leaderAddress + 0x78) = skillExperiencePerLevel[currentSkill - 1].exp;
            *(DWORD*)((BYTE*)leaderAddress + 0x7C) = 0;
        }
    }
}

enum class RANK_STATE {
    NOT_FOUND = -1,
    ACTIVE = 1,
    INACTIVE = 0
};

std::unordered_map<std::string, Hooks::CLeader::RankSpecificTrait*>* Hooks::CLeader::rankSpecificTraitsActive = new std::unordered_map<std::string, Hooks::CLeader::RankSpecificTrait*>;
std::unordered_map<std::string, Hooks::CLeader::RankSpecificTrait*>* Hooks::CLeader::rankSpecificTraitsInActive = new std::unordered_map<std::string, Hooks::CLeader::RankSpecificTrait*>;
RANK_STATE getRankSpecificTrait(std::string* traitName, Hooks::CLeader::RankSpecificTrait** out) {
    if (Hooks::CLeader::rankSpecificTraitsActive->find(*traitName) != Hooks::CLeader::rankSpecificTraitsActive->end()) {
        DEBUG_OUT(printf("rankSpecificTraitsActive found \n"));
        *out = Hooks::CLeader::rankSpecificTraitsActive->at(*traitName);
        return RANK_STATE::ACTIVE;
    }
    else if (Hooks::CLeader::rankSpecificTraitsInActive->find(*traitName) != Hooks::CLeader::rankSpecificTraitsInActive->end()) {
        DEBUG_OUT(printf("rankSpecificTraitsInActive found \n"));
        *out = Hooks::CLeader::rankSpecificTraitsInActive->at(*traitName);
        return RANK_STATE::INACTIVE;
    }
    return RANK_STATE::NOT_FOUND;
}

void Hooks::CLeader::checkRankSpecificTraitsConsistency(DWORD* leaderAddress, DWORD newRank) {
    DEBUG_OUT(printf("#### checkRankSpecificTraitsConsistency ####\n"));
    DEBUG_OUT(printf("leaderAddress: %#010x - newRank: %i\n", (uintptr_t)leaderAddress, newRank));
    if (newRank == -1) {
        newRank = *(DWORD*)((BYTE*)leaderAddress + 0x6C);
        DEBUG_OUT(printf("Adjusted newRank: %u\n", newRank));
    }
    
    HDS::LinkedListNodeSingle* traitListNode = (HDS::LinkedListNodeSingle*)*((DWORD*)leaderAddress + (0x30 / 4));
    while (traitListNode != 0) {
        DEBUG_OUT(printf("traitListNode: %#010x \n", (uintptr_t) traitListNode));
        DEBUG_OUT(printf("data: %#010x \n", (uintptr_t)traitListNode->data));
        DEBUG_OUT(printf("prev: %#010x \n", (uintptr_t)traitListNode->prev));
        DEBUG_OUT(printf("next: %#010x \n", (uintptr_t)traitListNode->next));

        DWORD trait = traitListNode->data;
        std::string traitNameAsString = std::string(utils::getCString((DWORD*)trait + (0x2C / 4)));

        DEBUG_OUT(printf("traitNameAsString: %s \n", traitNameAsString.c_str()));

        Hooks::CLeader::RankSpecificTrait* rankSpecificTrait;
        if (traitNameAsString.find("rankSpecificTrait_") == 0) {
            RANK_STATE state = getRankSpecificTrait(&traitNameAsString, &rankSpecificTrait);
            DEBUG_OUT(printf("state: %i \n", static_cast<int>(state)));
            DEBUG_OUT(printf("rankSpecificTrait: %#010x \n", (uintptr_t) rankSpecificTrait));
            DEBUG_OUT(printf("rankSpecificTrait->lowerRank: %u \n", rankSpecificTrait->lowerRank));
            DEBUG_OUT(printf("rankSpecificTrait->upperRank: %u \n", rankSpecificTrait->upperRank));
            DEBUG_OUT(printf("newRank: %u \n", newRank));
            if (state == RANK_STATE::INACTIVE && rankSpecificTrait!= 0 && newRank >= rankSpecificTrait->lowerRank && newRank <= rankSpecificTrait->upperRank) { // Trait is inactive - rank matches -> activate
                INFO_OUT(printf("Activated rankSpecificTrait '%s' for '%s'\n", rankSpecificTrait->activeName.c_str(), utils::getCString(leaderAddress + (0x4C / 4))));
                traitListNode->data = rankSpecificTrait->activeTraitPtr;
            }
            else if (state == RANK_STATE::ACTIVE && rankSpecificTrait != 0 && (newRank < rankSpecificTrait->lowerRank || newRank > rankSpecificTrait->upperRank)) { // Trait is active - rank doesn't match -> deactivate
                INFO_OUT(printf("De-Activated rankSpecificTrait '%s' for '%s'\n", rankSpecificTrait->inactiveName.c_str(), utils::getCString(leaderAddress + (0x4C / 4))));
                traitListNode->data = rankSpecificTrait->inActiveTraitPtr;
            }
            else if (state == RANK_STATE::NOT_FOUND) { // Trait was not found
                WARNING_OUT(printf("Rank Specific Trait '%s' was not registered in LUA.\n", traitNameAsString.c_str()));
            }
        }
        DEBUG_OUT(printf("----------\n"));

        traitListNode = (HDS::LinkedListNodeSingle*)traitListNode->next;
    }
    DEBUG_OUT(printf("traitListNode == 0 \n"));
}

void hanldeTraitSaving(DWORD* leaderAddress, DWORD* traitAddress, DWORD** out) {
    std::string traitName = std::string(utils::getCString(traitAddress + 0x2C / 4));
    if (traitName.find("rankSpecificTrait_") == 0) {
        int leaderId = *(DWORD*)((BYTE*)leaderAddress + 0xC);
        *out = (DWORD*) &Hooks::CLeader::emptyString;
        DEBUG_OUT(printf("LeaderId '%i' NOT saving trait '%s'\n", leaderId, traitName.c_str()))
    }
    /*
    else {
        DEBUG_OUT(printf("Leader '%i' saving trait '%s'\n", *(DWORD*)leaderAddress + (0xC / 4), traitName.c_str()))
    }
    */
}

__declspec(naked) void Hooks::CLeader::leaderDontSaveRankSpecificTraitsHook() {
    DWORD* leaderAddress;
    DWORD* traitAddress;
    DWORD* finalTraitStringAddress;
    _asm {
        pushad
        push ebp
        mov ebp, esp
        sub esp, __LOCAL_SIZE
        mov eax, [ebp + 0x24]
        mov[leaderAddress], eax
        mov[traitAddress], ecx
        add ecx, 0x2c
        mov[finalTraitStringAddress], ecx
    }

    if (isRankSpecificTraitsActive) {
        hanldeTraitSaving(leaderAddress, traitAddress, &finalTraitStringAddress);
    }

    _asm {
        mov eax, finalTraitStringAddress
        mov esp, ebp                        // restore stack
        pop ebp                             // restore stack
        mov [esp + 0x18], eax               // Write address onto stackposition of pushed ecx (because pushad)
        popad                               // restore registers
        lea edi, [esp + 0xc]                // original code
        jmp[Hooks::CLeader::jumpBack_leaderDontSaveRankSpecificTraitsHook]
    }
}

__declspec(naked) void Hooks::CLeader::leaderRankChangeHook() {
    DWORD* leaderAddress;
    DWORD* CPromoteLeaderCommand;
    DWORD newRank;
    _asm {
        pushad
        push ebp
        mov ebp, esp
        sub esp, __LOCAL_SIZE
        mov[leaderAddress], edi
        mov[CPromoteLeaderCommand], esi
        mov newRank, eax
    }

    if (isLeaderSkillLossOnPromotionActive) {
        if (checkTraitSkillLevelConsistency(leaderAddress)) { // no skill change if the general doesn't have the "pskill" trait
            adjustSkillLevel(leaderAddress, CPromoteLeaderCommand, newRank);
        }
    }

    if (isRankSpecificTraitsActive) {
        checkRankSpecificTraitsConsistency(leaderAddress, newRank);
    }

    _asm {
        mov esp, ebp
        pop ebp
        popad
        mov[edi + 0x6c], eax
        cmp[edi + 0x68], ebx
        jmp[Hooks::CLeader::jumpBack_leaderRankChangeHook]
    }
}

__declspec(naked) void Hooks::CLeader::patchLeaderListShowMaxSkill() {
    DWORD* leaderAddress;
    CHAR* currentSkillCharArray;
    _asm {
        pushad
        push ebp
        mov ebp, esp
        sub esp, __LOCAL_SIZE
        mov[currentSkillCharArray], eax
        mov eax, [ebp + 0x30]
        mov[leaderAddress], eax
        mov eax, [currentSkillCharArray]
    }

    if (leaderAddress != 0) { // for some reason the trait filtering causes a 0 leaderAddress to appear
        DWORD currentSkill;
        DWORD maxSkill;
        currentSkill = *((BYTE*)leaderAddress + 0x70);
        maxSkill = *((BYTE*)leaderAddress + 0x74);
        sprintf(currentSkillCharArray, "%d (%d)", currentSkill, maxSkill);
    }

    _asm {
        mov esp, ebp
        pop ebp
        popad
        mov esi, eax
        mov ecx, esi
        add esp, 0xC
        jmp[Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkill]
    }
}

__declspec(naked) void Hooks::CLeader::patchLeaderListShowMaxSkillSelected() {
    DWORD* leaderAddress;
    CHAR* currentSkillCharArray;
    _asm {
        pushad
        push ebp
        mov ecx, [ebp + 0xC]    // save leader pointer before we mess with the stackframe pointer
        mov ebp, esp
        sub esp, __LOCAL_SIZE
        mov[currentSkillCharArray], eax
        mov[leaderAddress], ecx
        mov eax, [currentSkillCharArray]
    }
    UINT8 currentSkill;
    UINT8 maxSkill;
    currentSkill = *((BYTE*)leaderAddress + 0x70);
    maxSkill = *((BYTE*)leaderAddress + 0x74);
    sprintf(currentSkillCharArray, "%d (%d)", currentSkill, maxSkill);
    _asm {
        mov esp, ebp
        pop ebp
        popad
        mov esi, eax
        mov ecx, esi
        add esp, 0xC
        jmp[Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkillSelected]
    }
}
