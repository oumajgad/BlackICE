#include <Windows.h>

namespace Hooks {
    bool hook(void* hookAddress, void* hookFunc, int len, int NOPs) {
        if (len < 5) {
            return false;
        }
        else {
            DWORD protection;
            VirtualProtect(hookAddress, len, PAGE_EXECUTE_READWRITE, &protection);

            DWORD relativeHookFuncAddress = ((DWORD)hookFunc - (DWORD)hookAddress) - 5;

            *(BYTE*)hookAddress = 0xE9; // JMP
            *(DWORD*)((DWORD)hookAddress + 1) = relativeHookFuncAddress;

            for (int i = 0; i < NOPs; i++) {
                *(BYTE*)((DWORD)hookAddress + len + i) = 0x90;
            }

            DWORD trash;
            VirtualProtect(hookAddress, len, protection, &trash);
            return true;
        }
    }

    DWORD jumpBackPatchLeaderSkillLossOnPromotion;
    __declspec(naked) void patchLeaderSkillLossOnPromotion() {
        DWORD* leaderAddress;
        DWORD* CPromoteLeaderCommand;
        DWORD newRank;
        _asm {
            mov [leaderAddress], edi
            mov [CPromoteLeaderCommand], esi
            mov newRank, eax
            pushad
        }

        //std::vector<int>* x;
        //x = new std::vector<int>;

        std::cout << "patchLeaderSkillLossOnPromotion hook called" << std::endl;
        std::cout << "leaderAddress: " << leaderAddress << std::endl;
        std::cout << "newRank: " << newRank << std::endl;

        DWORD currentSkill;
        DWORD startingSkill;
        DWORD direction; // 0 = Higher Rank ; 1 = Lower Rank

        currentSkill = *((BYTE*)leaderAddress + 0x70);
        startingSkill = *((BYTE*)leaderAddress + 0x84 + 0x44);
        direction = *((BYTE*)CPromoteLeaderCommand + 0x64);

        std::cout << "currentSkill: " << currentSkill << std::endl;
        std::cout << "startingSkill: " << startingSkill << std::endl;
        std::cout << "direction: " << direction << std::endl;

        if (direction == 1 && currentSkill < startingSkill) { // Demotion
            *((BYTE*)leaderAddress + 0x70) = currentSkill + 1;
        }
        else if (direction == 0 && currentSkill != 0) { // Promotion
            *((BYTE*)leaderAddress + 0x70) = currentSkill - 1;
        }

        _asm {
            popad
            mov [edi + 0x6c], eax
            cmp [edi + 0x68], ebx
            jmp [jumpBackPatchLeaderSkillLossOnPromotion]
        }
    }

    DWORD jumpBack_patchLeaderListShowMaxSkill;
    __declspec(naked) void patchLeaderListShowMaxSkill() {
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
            jmp[jumpBack_patchLeaderListShowMaxSkill]
        }
    }

    DWORD jumpBack_patchLeaderListShowMaxSkillSelected;
    __declspec(naked) void patchLeaderListShowMaxSkillSelected() {
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
            jmp[jumpBack_patchLeaderListShowMaxSkillSelected]
        }
    }
}