#include <Windows.h>
#include <string>

#include <HoiDataStructures.hpp>

#include <Hooks/Hooks.hpp>
#include <Hooks/CLeaderHooks.hpp>


DWORD Hooks::CLeader::jumpBack_PatchLeaderSkillLossOnPromotion;
DWORD Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkill;
DWORD Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkillSelected;
std::vector<DWORD>* Hooks::CLeader::skillTraits;


int Hooks::CLeader::getPureSkilleAndTraitListNode(DWORD* leaderAddress, HDS::LinkedListNodeSingle** out) {
    DWORD pureSkill = 0;
    HDS::LinkedListNodeSingle* traitListNode = (HDS::LinkedListNodeSingle*)*((DWORD*)leaderAddress + (0x30 / 4));
    while (traitListNode != 0) {
        //std::cout << "traitListNode: " << traitListNode << std::endl;
        //std::cout << "data: " << traitListNode->data << std::endl;
        //std::cout << "prev: " << traitListNode->prev << std::endl;
        //std::cout << "next: " << traitListNode->next << std::endl;

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
        //std::cout << "traitNameAsString: " << traitNameAsString << std::endl;
        if (traitNameAsString.find("pskill_") == 0) {
            auto substr = traitNameAsString.substr(7);
            pureSkill = std::stoi(substr, nullptr, 10);
            //std::cout << "pureSkill: " << pureSkill << std::endl;
            *out = traitListNode;
            return pureSkill;
        }
        //std::cout << "----------" << std::endl;

        traitListNode = (HDS::LinkedListNodeSingle*)traitListNode->next;
    }
    return 0;
}

bool Hooks::CLeader::checkTraitSkillLevelConsistency(DWORD* leaderAddress) {
    DWORD currentRank = *((BYTE*)leaderAddress + 0x6C);
    DWORD currentSkill = *((BYTE*)leaderAddress + 0x70);
    DWORD experience = *((BYTE*)leaderAddress + 0x78);

    //std::cout << "currentRank: " << currentRank << std::endl;
    //std::cout << "currentSkill: " << currentSkill << std::endl;
    //std::cout << "experience: " << experience << std::endl;

    HDS::LinkedListNodeSingle* traitListNode = 0;
    DWORD pureSkill = getPureSkilleAndTraitListNode(leaderAddress, &traitListNode);
    //std::cout << "pureSkill: " << pureSkill << std::endl;
    if (traitListNode == 0) {
        //std::cout << "traitListNode == 0" << std::endl;
        return false;
    }

    //int gainedSkill = (currentSkill + currentRank - 1) - pureSkill;
    int expectedSkill = (pureSkill - (currentRank - 1));
    if (expectedSkill > 0) {
        int gainedSkill = currentSkill - expectedSkill;
        //std::cout << "gainedSkill: " << gainedSkill << std::endl;
        if (gainedSkill > 0) {
            //std::cout << "gainedSkill > 0" << std::endl;
            auto newTrait = skillTraits->at(pureSkill + gainedSkill);
            //std::cout << "newTrait: " << newTrait << std::endl;
            traitListNode->data = newTrait;
        }
    }
    return true;
}
struct skillLevelExp {
    int level;  // skill level
    DWORD exp; // first DWORD of the experience / second one should be zeroed. the game does not handle skill above 10 well
    DWORD exp_1Perc_step; // 1% Point step
};
skillLevelExp skillExperiencePerLevel[16] = {
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
    DWORD currentSkill = *((BYTE*)leaderAddress + 0x70);
    DWORD experience = *(DWORD*)((BYTE*)leaderAddress + 0x78);
    DWORD direction = *((BYTE*)CPromoteLeaderCommand + 0x64); // 0 = Higher Rank ; 1 = Lower Rank

    getLeaderExperiencePercentFunction getLeaderExperiencePercent = reinterpret_cast<getLeaderExperiencePercentFunction>(Hooks::MODULE_BASE + 0x181c50);
    unsigned int experiencePercent = 0; // 1000 = 100% - 500 = 50%
    getLeaderExperiencePercent((int)leaderAddress, &experiencePercent);

    //std::cout << "currentSkill: " << currentSkill << std::endl;
    //std::cout << "direction: " << direction << std::endl;
    //std::cout << "newRank: " << newRank << std::endl;
    //std::cout << "experience: " << experience << std::endl;
    //std::cout << "experiencePercent: " << experiencePercent << std::endl;

    //int nextLevelPercentage = getNextLevelPercentage(currentSkill, experience);
    //std::cout << "nextLevelPercentage: " << nextLevelPercentage << std::endl;

    HDS::LinkedListNodeSingle* traitListNode = 0;
    int pureSkill = getPureSkilleAndTraitListNode(leaderAddress, &traitListNode);
    //std::cout << "pureSkill: " << pureSkill << std::endl;
    //std::cout << "pureSkill - (int) newRank: " << pureSkill - (int)newRank << std::endl;

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

__declspec(naked) void Hooks::CLeader::patchLeaderSkillLossOnPromotion() {
    DWORD* leaderAddress;
    DWORD* CPromoteLeaderCommand;
    DWORD newRank;
    _asm {
        mov[leaderAddress], edi
        mov[CPromoteLeaderCommand], esi
        mov newRank, eax
        pushad
    }

    //std::cout << "patchLeaderSkillLossOnPromotion hook called" << std::endl;
    //std::cout << "leaderAddress: " << leaderAddress << std::endl;

    if (checkTraitSkillLevelConsistency(leaderAddress)) { // no skill change if the general doesn't have the "pskill" trait
        adjustSkillLevel(leaderAddress, CPromoteLeaderCommand, newRank);
    }



    _asm {
        popad
        mov[edi + 0x6c], eax
        cmp[edi + 0x68], ebx
        jmp[Hooks::CLeader::jumpBack_PatchLeaderSkillLossOnPromotion]
    }
}

__declspec(naked) void Hooks::CLeader::patchLeaderListShowMaxSkill() {
    DWORD* leaderAddress;
    CHAR* currentSkillCharArray;
    _asm {
        mov[currentSkillCharArray], eax
        mov eax, [esp + 0xC]
        mov[leaderAddress], eax
        mov eax, [currentSkillCharArray]
        pushad
    }

    //std::cout << "patchLeaderListShowMaxSkill" << std::endl;
    //std::cout << "leaderAddress: " << leaderAddress << std::endl;
    //std::cout << "currentSkillCharArray: " << currentSkillCharArray << std::endl;

    if (leaderAddress != 0) { // for some reason the trait filtering causes a 0 leaderAddress to appear
        DWORD currentSkill;
        DWORD maxSkill;
        currentSkill = *((BYTE*)leaderAddress + 0x70);
        maxSkill = *((BYTE*)leaderAddress + 0x74);

        //std::cout << "currentSkill: " << currentSkill << std::endl;
        //std::cout << "maxSkill: " << maxSkill << std::endl;

        sprintf(currentSkillCharArray, "%d (%d)", currentSkill, maxSkill);

        //std::cout << "currentSkillCharArray: " << currentSkillCharArray << std::endl;
    }

    _asm {
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
        mov[currentSkillCharArray], eax
        mov eax, [ebp + 0xC]
        mov[leaderAddress], eax
        mov eax, [currentSkillCharArray]
        pushad
    }

    //std::cout << "patchLeaderListShowMaxSkill" << std::endl;
    //std::cout << "leaderAddress: " << leaderAddress << std::endl;
    //std::cout << "currentSkillCharArray: " << currentSkillCharArray << std::endl;

    DWORD currentSkill;
    DWORD maxSkill;
    currentSkill = *((BYTE*)leaderAddress + 0x70);
    maxSkill = *((BYTE*)leaderAddress + 0x74);

    //std::cout << "currentSkill: " << currentSkill << std::endl;
    //std::cout << "maxSkill: " << maxSkill << std::endl;

    sprintf(currentSkillCharArray, "%d (%d)", currentSkill, maxSkill);

    //std::cout << "currentSkillCharArray: " << currentSkillCharArray << std::endl;


    _asm {
        popad
        mov esi, eax
        mov ecx, esi
        add esp, 0xC
        jmp[Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkillSelected]
    }
}
