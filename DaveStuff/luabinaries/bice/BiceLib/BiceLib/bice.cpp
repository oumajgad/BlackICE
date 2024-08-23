#include <lua.hpp>
#include <CasualLibrary.hpp>

#include <string>
#include <iostream>
#include <intrin.h>
#include <processthreadsapi.h>
#include <chrono>

#include <HoiDataStructures.hpp>

#include <CCountry.hpp>
#include <Hooks/Hooks.hpp>
#include <Hooks/CLeaderHooks.hpp>
#include <Patches.hpp>

int DATA_SECTION_START = 0x12F5000;
bool DEBUG = true;
DWORD MODULE_BASE;


__declspec(dllexport) int getCountryFlags(lua_State* L)
{
    //std::cout << "getCountryFlags called" << std::endl;
    std::string searchTag = luaL_checklstring(L, 1, NULL);
    //std::cout << "searchTag: " << searchTag << std::endl;

    Memory::External external = Memory::External(GetCurrentProcessId(), DEBUG);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    //std::cout << "modulePtr: " << Memory::n2hexstr(modulePtr.get()) << std::endl;

    auto ctr = external.findCountryInstance(modulePtr.get() + DATA_SECTION_START, searchTag);

    if (ctr != 0) {
        uintptr_t flagsOffset = ctr + 0x180 + 0x4; // CFlagsVFTable + Flag Tree beginning
        uintptr_t flagsPtr = external.read<uintptr_t>(flagsOffset);
        //std::cout << "flagsPtr: " << Memory::n2hexstr(flagsPtr) << std::endl;

        auto flags = CCountry::getFlags(external, flagsPtr);
        //std::cout << "flags->size(): " << flags->size() << std::endl;

        lua_createtable(L, flags->size(), 0);
        for (int i = 0; i < flags->size(); i++) {
            lua_pushstring(L, flags->at(i).c_str());
            lua_rawseti(L, -2, i + 1); /* In lua indices start at 1 */
        }

        delete flags;
        return 1;

    }
    lua_pushnil(L);
    return 1;
}

__declspec(dllexport) int getCountryVariables(lua_State* L)
{
    //std::cout << "getCountryFlags called" << std::endl;
    std::string searchTag = luaL_checklstring(L, 1, NULL);
    //std::cout << "searchTag: " << searchTag << std::endl;

    Memory::External external = Memory::External(GetCurrentProcessId(), DEBUG);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    //std::cout << "modulePtr: " << Memory::n2hexstr(modulePtr.get()) << std::endl;

    auto ctr = external.findCountryInstance(modulePtr.get() + DATA_SECTION_START, searchTag);

    if (ctr != 0) {
        uintptr_t varsOffset = ctr + 0x1AC + 0x4; // CVariablesVFTable + Vars Tree beginning
        uintptr_t varsPtr = external.read<uintptr_t>(varsOffset);
        //std::cout << "varsPtr: " << Memory::n2hexstr(varsPtr) << std::endl;

        auto vars = CCountry::getVars(external, varsPtr);
        //std::cout << "vars->size(): " << vars->size() << std::endl;

        lua_newtable(L, 0, vars->size());
        for (int i = 0; i < vars->size(); i++) {
            lua_pushstring(L, vars->at(i).name.c_str());
            lua_pushinteger(L, vars->at(i).value);
            lua_settable(L, -3);
        }

        delete vars;
        return 1;
    }
    lua_pushnil(L);
    return 1;
}

void activateLeaderRankChangeHook() {
    DWORD hookAddress = MODULE_BASE + 0x1D7CDC;
    Hooks::CLeader::jumpBack_leaderRankChangeHook = hookAddress + 6;
    if (!Hooks::hook((void*)hookAddress, Hooks::CLeader::leaderRankChangeHook, 5, 1)) {
        std::cout << "Hook 'LeaderRankChangeHook' failed" << std::endl;
    }
    else {
        std::cout << "Hook 'LeaderRankChangeHook' succeeded" << std::endl;
        std::cout << "jumpBack_leaderRankChangeHook: " << Memory::n2hexstr(Hooks::CLeader::jumpBack_leaderRankChangeHook) << std::endl;
    }
    Hooks::CLeader::isLeaderRankChangeHookActive = true;
}

std::vector<uintptr_t>* getTraitsData;
bool getTraitsDone = false;
std::vector<uintptr_t>* getTraits() {
    if (!getTraitsDone) {
        //std::cout << "getTraits" << std::endl;
        Memory::External external = Memory::External(GetCurrentProcessId(), DEBUG);
        Address modulePtr = external.getModule("hoi3_tfh.exe");
        //std::cout << "modulePtr: " << Memory::n2hexstr(modulePtr.get()) << std::endl;

        uintptr_t CTraitVFTable = modulePtr.get() + 0x11C7DC0;
        //std::cout << "CTraitVFTable: " << Memory::n2hexstr(CTraitVFTable) << std::endl;
        std::string CTraitVFTableSig = Memory::ptrToSignature(CTraitVFTable);
        //std::cout << "CTraitVFTableSig: " << CTraitVFTableSig << std::endl;
        getTraitsData = external.findSignatures(modulePtr.get() + DATA_SECTION_START, CTraitVFTableSig.c_str(), 4, 99999);
        if (getTraitsData->size() != 0) {
            std::cout << "Traits vector filled" << std::endl;
            getTraitsDone = true;
        }
    }
    return getTraitsData;
}


BOOL activateRankSpecificTraitsDone = false;
__declspec(dllexport) int activateRankSpecificTraits(lua_State* L)
{
    if (activateRankSpecificTraitsDone) {
        return 0;
    }

    if (!Hooks::CLeader::isLeaderRankChangeHookActive) {
        activateLeaderRankChangeHook();
    }

    std::vector<uintptr_t>* traits = getTraits();
    //std::cout << "traits->size: " << traits->size() << std::endl;
    if (traits->size() == 0) {
        // Traits are not set up when the LUA is first run -> defer hooking until the LUA context is reloaded during save loading
        std::cout << "Hook 'activateRankSpecificTraits' deferred until save load" << std::endl;
        return 0;
    }

    auto tempRankTraits = new std::vector<uintptr_t>; // unsorted vector of the traits which are used to track leader skill
    /*
    Hooks::CLeader::skillTraits = new std::vector<DWORD>; // sorted vector of the traits
    for (auto& trait : *traits) {
        DWORD traitNameLength;
        traitNameLength = *((DWORD*)trait + (0x3C / 4));
        char* traitName;
        if (traitNameLength > 15) {
            traitName = (char*)*(DWORD*)((BYTE*)trait + 0x2C);
        }
        else {
            traitName = (char*)((BYTE*)trait + 0x2C);
        }

        std::string traitNameAsString = std::string(traitName);
        if (traitNameAsString.find("rankSpecificTrait_") == 0) {
            std::cout << "traitName: " << traitNameAsString << std::endl;
            tempRankTraits->push_back(trait);
            Hooks::CLeader::skillTraits->push_back(trait); // also push back the Hooks::skillTraits vector so the indexes get filled
        }
    }
    */


    Hooks::CLeader::isRankSpecificTraitsActive = true;
    activateRankSpecificTraitsDone = TRUE;
    delete tempRankTraits;
    return 0;
}


BOOL activateLeaderPromotionSkillLossDone = false;
__declspec(dllexport) int activateLeaderPromotionSkillLoss(lua_State* L)
{
    if (activateLeaderPromotionSkillLossDone) {
        return 0;
    }

    if (!Hooks::CLeader::isLeaderRankChangeHookActive) {
        activateLeaderRankChangeHook();
    }

    std::vector<uintptr_t>* traits = getTraits();
    //std::cout << "traits->size: " << traits->size() << std::endl;
    if (traits->size() == 0) {
        // Traits are not set up when the LUA is first run -> defer hooking until the LUA context is reloaded during save loading
        std::cout << "Hook 'activateLeaderPromotionSkillLoss' deferred until save load" << std::endl;
        return 0;
    }

    auto tempSkillTraits = new std::vector<uintptr_t>; // unsorted vector of the traits which are used to track leader skill
    Hooks::CLeader::skillTraits = new std::vector<DWORD>; // sorted vector of the traits
    for (auto& trait : *traits) {
        DWORD traitNameLength;
        traitNameLength = *((DWORD*)trait + (0x3C / 4));
        char* traitName;
        if (traitNameLength > 15) {
            traitName = (char*) *(DWORD*)((BYTE*)trait + 0x2C);
        }
        else {
            traitName = (char*)((BYTE*)trait + 0x2C);
        }

        std::string traitNameAsString = std::string(traitName);
        if (traitNameAsString.find("pskill_") == 0) {
            //std::cout << "traitName: " << traitNameAsString << std::endl;
            tempSkillTraits->push_back(trait);
            Hooks::CLeader::skillTraits->push_back(trait); // also push back the Hooks::skillTraits vector so the indexes get filled
        }
    }

    for (auto& trait : *tempSkillTraits) {
        char* traitName;
        traitName = (char*)((BYTE*)trait + 0x2C);
        std::string traitNameAsString = std::string(traitName);
        //std::cout << "traitName: " << traitNameAsString << std::endl;
        auto substr = traitNameAsString.substr(7);
        //std::cout << "substr: " << substr << std::endl;
        auto index = std::stoi(substr, nullptr, 10);
        //std::cout << "index: " << index << std::endl;
        Hooks::CLeader::skillTraits->at(index) = (DWORD) trait;
    }

    Hooks::CLeader::isLeaderSkillLossOnPromotionActive = true;
    activateLeaderPromotionSkillLossDone = TRUE;
    delete tempSkillTraits;
    return 0;
}


BOOL activateLeaderListShowMaxSkillDone = false;
__declspec(dllexport) int activateLeaderListShowMaxSkill(lua_State* L)
{
    if (activateLeaderListShowMaxSkillDone) {
        return 0;
    }

    DWORD hookAddress = MODULE_BASE + 0x365688;
    Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkill = hookAddress + 7;

    if (!Hooks::hook((void*)hookAddress, Hooks::CLeader::patchLeaderListShowMaxSkill, 5, 2)) {
        std::cout << "Hook 'activateLeaderListShowMaxSkill' failed" << std::endl;
    }
    else {
        std::cout << "Hook 'activateLeaderListShowMaxSkill' succeeded" << std::endl;
        std::cout << "jumpBack_patchLeaderListShowMaxSkill: " << Memory::n2hexstr(Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkill) << std::endl;
    }
    activateLeaderListShowMaxSkillDone = TRUE;
    return 0;
}


BOOL activateLeaderListShowMaxSkillSelectedDone = false;
__declspec(dllexport) int activateLeaderListShowMaxSkillSelected(lua_State* L)
{
    if (activateLeaderListShowMaxSkillSelectedDone) {
        return 0;
    }

    DWORD hookAddress = MODULE_BASE + 0x3679d4;
    Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkillSelected = hookAddress + 7;

    if (!Hooks::hook((void*)hookAddress, Hooks::CLeader::patchLeaderListShowMaxSkillSelected, 5, 2)) {
        std::cout << "Hook 'activateLeaderListShowMaxSkillSelected' failed" << std::endl;
    }
    else {
        std::cout << "Hook 'activateLeaderListShowMaxSkillSelected' succeeded" << std::endl;
        std::cout << "jumpBack_patchLeaderListShowMaxSkillSelected: " << Memory::n2hexstr(Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkillSelected) << std::endl;
    }
    activateLeaderListShowMaxSkillSelectedDone = TRUE;
    return 0;
}


BOOL activateOffmapICPatchDone = false;
__declspec(dllexport) int activateOffmapICPatch(lua_State* L)
{
    if (activateOffmapICPatchDone) {
        return 0;
    }
    
    if (!Patches::patchOffMapIC(MODULE_BASE)) {
        std::cout << "Patch 'activateOffmapICPatch' failed" << std::endl;
    }
    else {
        std::cout << "Patch 'activateOffmapICPatch' succeeded" << std::endl;
    }

    activateOffmapICPatchDone = TRUE;
    return 0;
}


BOOL activateMinisterTechDecayPatchDone = false;
__declspec(dllexport) int activateMinisterTechDecayPatch(lua_State* L)
{
    if (activateMinisterTechDecayPatchDone) {
        return 0;
    }

    if (!Patches::patchMinisterTechDecay(MODULE_BASE)) {
        std::cout << "Patch 'activateMinisterTechDecayPatch' failed" << std::endl;
    }
    else {
        std::cout << "Patch 'activateMinisterTechDecayPatch' succeeded" << std::endl;
    }


    activateMinisterTechDecayPatchDone = TRUE;
    return 0;
}


BOOL activateWarExhaustionNeutralityResetPatchDone = false;
__declspec(dllexport) int activateWarExhaustionNeutralityResetPatch(lua_State* L)
{
    if (activateWarExhaustionNeutralityResetPatchDone) {
        return 0;
    }

    if (!Patches::patchWarExhaustionNeutralityReset(MODULE_BASE)) {
        std::cout << "Patch 'activateWarExhaustionNeutralityResetPatch' failed" << std::endl;
    }
    else {
        std::cout << "Patch 'activateWarExhaustionNeutralityResetPatch' succeeded" << std::endl;
    }

    activateWarExhaustionNeutralityResetPatchDone = TRUE;
    return 0;
}


__declspec(dllexport) int setModuleBase(lua_State* L)
{
    Memory::External external = Memory::External(GetCurrentProcessId(), DEBUG);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    MODULE_BASE = modulePtr.get();
    Hooks::MODULE_BASE = MODULE_BASE;
    return 0;
}


__declspec(dllexport) int startConsole(lua_State* L)
{
    AllocConsole();
    FILE* fp;
    freopen_s(&fp, "CONOUT$", "w", stdout); // output only

    HANDLE handle = GetStdHandle(STD_INPUT_HANDLE);
    SetConsoleMode(handle, ENABLE_EXTENDED_FLAGS);  // Set mode to this to prevent accidentially selecting something in the console
                                                    // because that will freeze the entire thing until it is unselected

    return 0;
}


__declspec(dllexport) luaL_Reg BiceLib[] = {
    {"getCountryFlags", getCountryFlags},
    {"getCountryVariables", getCountryVariables},
    {"startConsole", startConsole},
    {"setModuleBase", setModuleBase},
    {"activateRankSpecificTraits", activateRankSpecificTraits},
    {"activateLeaderPromotionSkillLoss", activateLeaderPromotionSkillLoss},
    {"activateLeaderListShowMaxSkill", activateLeaderListShowMaxSkill},
    {"activateLeaderListShowMaxSkillSelected", activateLeaderListShowMaxSkillSelected},
    {"activateOffmapICPatch", activateOffmapICPatch},
    {"activateMinisterTechDecayPatch", activateMinisterTechDecayPatch},
    {"activateWarExhaustionNeutralityResetPatch", activateWarExhaustionNeutralityResetPatch},
    {NULL, NULL}
};

// #define new_lib(L, l) (lua_newtable(L), luaL_register(L, NULL, l))

extern "C"
__declspec(dllexport) int luaopen_BiceLib(lua_State* L)
{

    //    new_lib(L, test);
    lua_newtable(L);
    luaL_register(L, NULL, BiceLib);
    return 1;
}