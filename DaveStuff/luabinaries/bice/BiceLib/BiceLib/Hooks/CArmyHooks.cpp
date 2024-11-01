#include <Windows.h>
#include <string>
#include <iostream>

#include <HoiDataStructures.hpp>
#include <utils.hpp>

#include <Hooks/Hooks.hpp>
#include <Hooks/CArmyHooks.hpp>

// Jumpbacks
DWORD Hooks::CArmy::jumpBack_unitAttachmentLimitHook;

// Activation vars
bool Hooks::CArmy::isUnitAttachmentLimitHookActive = false;

// Vars defaults
DWORD Hooks::CArmy::armyGroupUnitLimit = 5;
DWORD Hooks::CArmy::armyUnitLimit = 5;
DWORD Hooks::CArmy::corpsUnitLimit = 5;

std::unordered_map<std::string, Hooks::CArmy::CommandLimitTrait*>* Hooks::CArmy::commandLimitTraits = new std::unordered_map<std::string, Hooks::CArmy::CommandLimitTrait*>;


int getTraitsEffect(DWORD leaderAddress) {
    int res = 0;
    HDS::LinkedListNodeSingle* traitListNode = (HDS::LinkedListNodeSingle*)*((DWORD*)leaderAddress + (0x30 / 4));
    while (traitListNode != 0) {
        DEBUG_OUT(std::cout << "traitListNode: " << traitListNode << std::endl);
        DEBUG_OUT(std::cout << "data: " << traitListNode->data << std::endl);
        DEBUG_OUT(std::cout << "prev: " << traitListNode->prev << std::endl);
        DEBUG_OUT(std::cout << "next: " << traitListNode->next << std::endl);

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
        DEBUG_OUT(std::cout << "traitNameAsString: " << traitNameAsString << std::endl);
        if (Hooks::CArmy::commandLimitTraits->find(traitNameAsString) != Hooks::CArmy::commandLimitTraits->end()) {
            auto clt = Hooks::CArmy::commandLimitTraits->at(traitNameAsString);
            res += clt->limitEffect;
            DEBUG_OUT(std::cout << "clt->limitEffect: " << clt->limitEffect << std::endl);
            DEBUG_OUT(std::cout << "res: " << res << std::endl);
        }
        DEBUG_OUT(std::cout << "----------" << std::endl);

        traitListNode = (HDS::LinkedListNodeSingle*)traitListNode->next;
    }
    DEBUG_OUT(std::cout << "traitListNode == 0 " << std::endl);

    return res;
}

DWORD handleUnitAttachmentLimit(DWORD currentlyAttachedUnitAmount, DWORD* unitToAttach, DWORD* lastCountedUnit) {
    DEBUG_OUT(printf("attachedUnitAmount: %d \n", (unsigned int)currentlyAttachedUnitAmount));
    DEBUG_OUT(printf("unitToAttachName: %s \n", utils::getCString(unitToAttach + (0x16c / 4))));
    DEBUG_OUT(printf("lastCountedUnitName: %s \n", utils::getCString(lastCountedUnit + (0x16c / 4))));

    DWORD newLimit = 5;

    DWORD* higherUnit = (DWORD*)*(lastCountedUnit + (0x1e0 / 4));
    DEBUG_OUT(printf("higherUnit: %#010x \n", (unsigned int) higherUnit));
    if (higherUnit != 0) {
        char* higherUnitName = utils::getCString(higherUnit + (0x16c / 4));
        DEBUG_OUT(printf("higherUnitName: %s \n", higherUnitName));
        DWORD higherUnitOobLevel = *(higherUnit + (0x1f4 / 4));
        DEBUG_OUT(printf("higherUnitOobLevel: %u \n", higherUnitOobLevel));

        if (higherUnitOobLevel == 1) { // Army Group
            newLimit = Hooks::CArmy::armyGroupUnitLimit;
        }
        else if (higherUnitOobLevel == 2) { // Army
            newLimit = Hooks::CArmy::armyUnitLimit;
        }
        else if (higherUnitOobLevel == 3) { // Corps
            newLimit = Hooks::CArmy::corpsUnitLimit;
        }

        DWORD leaderAddress = *(higherUnit + (0x12c / 4));
        if (leaderAddress != 0) {
            newLimit += getTraitsEffect(leaderAddress);
        }
    }


    return newLimit;
}

__declspec(naked) void Hooks::CArmy::unitAttachmentLimitHook() {
    DWORD currentlyAttachedUnitAmount;
    DWORD newLimit;
    DWORD* unitToAttach; // EBX
    DWORD* lastCountedUnit; // ECX 
    // The attached unit of the higher unit which was last counted -> use it to get a pointer to the higher unit // Cant be 0 since the function has exits early in that case (0x1b9705)

    _asm {
        pushad
        push ebp
        mov ebp, esp
        sub esp, __LOCAL_SIZE
        mov esi, [ebp + 0x38]
        mov[currentlyAttachedUnitAmount], esi
        mov[unitToAttach], ebx
        mov[lastCountedUnit], ecx
    }

    if (Hooks::CArmy::isUnitAttachmentLimitHookActive) {
        newLimit = handleUnitAttachmentLimit(currentlyAttachedUnitAmount, unitToAttach, lastCountedUnit);
    }

    _asm {
        mov edi, [newLimit]
        mov esp, ebp
        pop ebp
        cmp[ebp + 0x8],edi
        popad
        pop edi
        jmp[Hooks::CArmy::jumpBack_unitAttachmentLimitHook]
    }
}

