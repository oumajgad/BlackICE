#include <Windows.h>
#include <string>
#include <vector>
#include <iostream>

#include <GameClasses/CLeader.hpp>
#include <GameClasses/CTrait.hpp>
#include <GameClasses/CUnit.hpp>
#include <HoiDataStructures.hpp>
#include <utils.hpp>

#include <Hooks/Hooks.hpp>
#include <Hooks/CArmyHooks.hpp>

namespace {
    // The unit pointers here come straight out of the game's own registers, so they
    // are read directly rather than through Mem::tryRead. What each offset means is
    // in GameClasses/CUnit.hpp; nothing in this file should spell one out.
    DWORD unitField(uintptr_t unit, uintptr_t offset) {
        return *(DWORD*)(unit + offset);
    }

    DWORD unitField(const void* unit, uintptr_t offset) {
        return unitField((uintptr_t)unit, offset);
    }

    std::string unitName(uintptr_t unit) {
        return HDS::readString(unit + CUnit::Offsets::name);
    }

    std::string unitName(const void* unit) {
        return unitName((uintptr_t)unit);
    }
}

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
    const std::vector<uintptr_t> traits =
        HDS::walkList(leaderAddress + CLeader::Offsets::trait_ll_start);
    for (size_t i = 0; i < traits.size(); i++) {
        const uintptr_t trait = traits[i];
        std::string traitNameAsString = HDS::readString(trait + CTrait::Offsets::name);
        DEBUG_OUT(printf("traitNameAsString: %s \n", traitNameAsString.c_str()));
        if (Hooks::CArmy::commandLimitTraits->find(traitNameAsString) != Hooks::CArmy::commandLimitTraits->end()) {
            auto clt = Hooks::CArmy::commandLimitTraits->at(traitNameAsString);
            res += clt->limitEffect;
            DEBUG_OUT(printf("clt->limitEffect: %i \n", clt->limitEffect));
            DEBUG_OUT(printf("res: %i \n", res));
        }
        DEBUG_OUT(printf("----------\n"));
    }

    return res;
}

int getAttachedBrigadesAmount(DWORD* higherUnitAddress) {
    int res = 0;

    DEBUG_OUT(printf("getAttachedBrigadesAmount higherUnitAddress: %#010x \n", (uintptr_t)higherUnitAddress));
    const std::vector<uintptr_t> attached = HDS::walkList(
        (uintptr_t)higherUnitAddress + CUnit::Offsets::lower_oob_unit_linked_list_first_ptr);
    for (size_t i = 0; i < attached.size(); i++) {
        const uintptr_t unit = attached[i];
        DWORD brigadesAmount = unitField(unit, CUnit::Offsets::regiments_amount);
        DWORD oobLevel = unitField(unit, CUnit::Offsets::oob_level);
        if (brigadesAmount == 1 && oobLevel == CUnit::Level::Division) { // brigades are held as divisions
            res++;
        }
        DEBUG_OUT(printf("res %d \n",res));
    }

    return res;
}

DWORD handleUnitAttachmentLimit(DWORD currentlyAttachedUnitAmount, DWORD* unitToAttach, DWORD* lastCountedUnit) {
    DEBUG_OUT(printf("attachedUnitAmount: %d \n", (unsigned int)currentlyAttachedUnitAmount));
    DEBUG_OUT(printf("unitToAttachName: %s \n", unitName(unitToAttach).c_str()));
    DEBUG_OUT(printf("lastCountedUnitName: %s \n", unitName(lastCountedUnit).c_str()));

    DWORD newLimit = 5;

    DWORD brigadesAmount = unitField(unitToAttach, CUnit::Offsets::regiments_amount);
    DWORD oobLevel = unitField(unitToAttach, CUnit::Offsets::oob_level);
    DEBUG_OUT(printf("brigadesAmount: %d \n", brigadesAmount));
    if (brigadesAmount == 1 && oobLevel == CUnit::Level::Division) {
        return 999;
    }

    DWORD tagId = unitField(unitToAttach, CUnit::Offsets::owner_id);
    DEBUG_OUT(printf("tagId: %d \n", tagId));
    DWORD* higherUnit = (DWORD*)unitField(lastCountedUnit, CUnit::Offsets::higher_oob_unit_ptr);
    DEBUG_OUT(printf("higherUnit: %#010x \n", (unsigned int) higherUnit));
    if (higherUnit != 0) {
        DEBUG_OUT(printf("higherUnitName: %s \n", unitName(higherUnit).c_str()));
        DWORD higherUnitOobLevel = unitField(higherUnit, CUnit::Offsets::oob_level);
        DEBUG_OUT(printf("higherUnitOobLevel: %u \n", higherUnitOobLevel));

        if (higherUnitOobLevel == CUnit::Level::ArmyGroup) {
            if (Hooks::CArmy::armyGroupUnitLimitPerCountry[tagId] != 0) {
                newLimit = Hooks::CArmy::armyGroupUnitLimitPerCountry[tagId];
            }
            else {
                newLimit = Hooks::CArmy::armyGroupUnitLimit;
            }
        }
        else if (higherUnitOobLevel == CUnit::Level::Army) {
            if (Hooks::CArmy::armyUnitLimitPerCountry[tagId] != 0) {
                newLimit = Hooks::CArmy::armyUnitLimitPerCountry[tagId];
            }
            else {
                newLimit = Hooks::CArmy::armyUnitLimit;
            }
        }
        else if (higherUnitOobLevel == CUnit::Level::Corps) {
            if (Hooks::CArmy::corpsUnitLimitPerCountry[tagId] != 0) {
                newLimit = Hooks::CArmy::corpsUnitLimitPerCountry[tagId];
            }
            else {
                newLimit = Hooks::CArmy::corpsUnitLimit;
            }
        }

        DWORD leaderAddress = unitField(higherUnit, CUnit::Offsets::leader_ptr);
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

