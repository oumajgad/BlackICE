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

int Hooks::CArmy::armyGroupUnitLimitPerCountry[300];
int Hooks::CArmy::armyUnitLimitPerCountry[300];
int Hooks::CArmy::corpsUnitLimitPerCountry[300];

std::unordered_map<std::string, Hooks::CArmy::CommandLimitTrait*>* Hooks::CArmy::commandLimitTraits = new std::unordered_map<std::string, Hooks::CArmy::CommandLimitTrait*>;


int getTraitsEffect(DWORD leaderAddress) {
    int res = 0;
    HDS::LinkedListNodeSingle* traitListNode = (HDS::LinkedListNodeSingle*)*((DWORD*)leaderAddress + (0x30 / 4));
    while (traitListNode != 0) {
        DEBUG_OUT(printf("traitListNode: %#010x \n", (uintptr_t) traitListNode));
        DEBUG_OUT(printf("data: %#010x \n", (uintptr_t) traitListNode->data));
        DEBUG_OUT(printf("prev: %#010x \n", (uintptr_t) traitListNode->prev));
        DEBUG_OUT(printf("next: %#010x \n", (uintptr_t) traitListNode->next));

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
        if (Hooks::CArmy::commandLimitTraits->find(traitNameAsString) != Hooks::CArmy::commandLimitTraits->end()) {
            auto clt = Hooks::CArmy::commandLimitTraits->at(traitNameAsString);
            res += clt->limitEffect;
            DEBUG_OUT(printf("clt->limitEffect: %i \n", clt->limitEffect));
            DEBUG_OUT(printf("res: %i \n", res));
        }
        DEBUG_OUT(printf("----------\n"));

        traitListNode = (HDS::LinkedListNodeSingle*)traitListNode->next;
    }
    DEBUG_OUT(printf("traitListNode == 0 \n"));

    return res;
}

int getAttachedBrigadesAmount(DWORD* higherUnitAddress) {
    int res = 0;

    DEBUG_OUT(printf("getAttachedBrigadesAmount higherUnitAddress: %#010x \n", (uintptr_t)higherUnitAddress));
    HDS::LinkedListNodeSingle* unitListNode = (HDS::LinkedListNodeSingle*)*((DWORD*)higherUnitAddress + (0x1e4 / 4));
    while (unitListNode != 0) {
        DEBUG_OUT(printf("unitListNode: %#010x \n", (uintptr_t)unitListNode));
        DEBUG_OUT(printf("data: %#010x \n", (uintptr_t)unitListNode->data));
        DEBUG_OUT(printf("prev: %#010x \n", (uintptr_t)unitListNode->prev));
        DEBUG_OUT(printf("next: %#010x \n", (uintptr_t)unitListNode->next));

        DWORD unit = unitListNode->data;
        DWORD brigadesAmount = *((DWORD*)unit + (0x40 / 4));
        DWORD oobLevel = *((DWORD*)unit + (0x1f4 / 4));
        if (brigadesAmount == 1 && oobLevel == 4) { // oobLevel: 4 = Division (and brigades) / 5 = Navy / 6 = Air
            res++;
        }
        DEBUG_OUT(printf("res %d \n",res));

        unitListNode = (HDS::LinkedListNodeSingle*)unitListNode->next;
    }

    return res;
}

DWORD handleUnitAttachmentLimit(DWORD currentlyAttachedUnitAmount, DWORD* unitToAttach, DWORD* lastCountedUnit) {
    DEBUG_OUT(printf("attachedUnitAmount: %d \n", (unsigned int)currentlyAttachedUnitAmount));
    DEBUG_OUT(printf("unitToAttachName: %s \n", utils::getCString(unitToAttach + (0x16c / 4))));
    DEBUG_OUT(printf("lastCountedUnitName: %s \n", utils::getCString(lastCountedUnit + (0x16c / 4))));

    DWORD newLimit = 5;

    DWORD brigadesAmount = *(unitToAttach + (0x40 / 4));
    DEBUG_OUT(printf("brigadesAmount: %d \n", brigadesAmount));
    if (brigadesAmount == 1) {
        return 999;
    }

    DWORD tagId = *(unitToAttach + (0x128 / 4));
    DEBUG_OUT(printf("tagId: %d \n", tagId));
    DWORD* higherUnit = (DWORD*)*(lastCountedUnit + (0x1e0 / 4));
    DEBUG_OUT(printf("higherUnit: %#010x \n", (unsigned int) higherUnit));
    if (higherUnit != 0) {
        char* higherUnitName = utils::getCString(higherUnit + (0x16c / 4));
        DEBUG_OUT(printf("higherUnitName: %s \n", higherUnitName));
        DWORD higherUnitOobLevel = *(higherUnit + (0x1f4 / 4));
        DEBUG_OUT(printf("higherUnitOobLevel: %u \n", higherUnitOobLevel));

        if (higherUnitOobLevel == 1) { // Army Group
            if (Hooks::CArmy::armyGroupUnitLimitPerCountry[tagId] != 0) {
                newLimit = Hooks::CArmy::armyGroupUnitLimitPerCountry[tagId];
            }
            else {
                newLimit = Hooks::CArmy::armyGroupUnitLimit;
            }
        }
        else if (higherUnitOobLevel == 2) { // Army
            if (Hooks::CArmy::armyUnitLimitPerCountry[tagId] != 0) {
                newLimit = Hooks::CArmy::armyUnitLimitPerCountry[tagId];
            }
            else {
                newLimit = Hooks::CArmy::armyUnitLimit;
            }
        }
        else if (higherUnitOobLevel == 3) { // Corps
            if (Hooks::CArmy::corpsUnitLimitPerCountry[tagId] != 0) {
                newLimit = Hooks::CArmy::corpsUnitLimitPerCountry[tagId];
            }
            else {
                newLimit = Hooks::CArmy::corpsUnitLimit;
            }
        }

        DWORD leaderAddress = *(higherUnit + (0x12c / 4));
        if (leaderAddress != 0) {
            newLimit += getTraitsEffect(leaderAddress);
        }

        // Since Brigades can be attached infinitely, we need to exclude their count from the total
        // To do that we simply add their amount to the limit.
        newLimit += getAttachedBrigadesAmount(higherUnit);
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
        mov newLimit, 5
    }

    if (Hooks::CArmy::isUnitAttachmentLimitHookActive) {
        newLimit = handleUnitAttachmentLimit(currentlyAttachedUnitAmount, unitToAttach, lastCountedUnit);
    }

    _asm {
        mov edi, newLimit
        mov esp, ebp
        pop ebp
        cmp[ebp + 0x8],edi // the original compare, flags are preserved during the following code
        popad
        pop edi
        jmp[Hooks::CArmy::jumpBack_unitAttachmentLimitHook]
    }
}

