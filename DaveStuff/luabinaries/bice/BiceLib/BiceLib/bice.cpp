#include <lua.hpp>
#include <CasualLibrary.hpp>

#include <iostream>
#include <intrin.h>
#include <processthreadsapi.h>
#include <chrono>

#include <CCountry.hpp>
#include <Hooks.hpp>
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


BOOL activateLeaderPromotionSkillLossDone = false;
__declspec(dllexport) int activateLeaderPromotionSkillLoss(lua_State* L)
{
    if (activateLeaderPromotionSkillLossDone) {
        return 0;
    }

    DWORD hookAddress = MODULE_BASE + 0x1D7CDC;
    Hooks::jumpBackPatchLeaderSkillLossOnPromotion = hookAddress + 6;

    if (!Hooks::hook((void*)hookAddress, Hooks::patchLeaderSkillLossOnPromotion, 5, 1)) {
        std::cout << "Hook 'activateLeaderPromotionSkillLoss' failed" << std::endl;
    }
    else {
        std::cout << "Hook 'activateLeaderPromotionSkillLoss' succeeded" << std::endl;
        std::cout << "jumpBackPatchLeaderSkillLossOnPromotion: " << Memory::n2hexstr(Hooks::jumpBackPatchLeaderSkillLossOnPromotion) << std::endl;
    }
    activateLeaderPromotionSkillLossDone = TRUE;
    return 0;
}


BOOL activateLeaderListShowMaxSkillDone = false;
__declspec(dllexport) int activateLeaderListShowMaxSkill(lua_State* L)
{
    if (activateLeaderListShowMaxSkillDone) {
        return 0;
    }

    DWORD hookAddress = MODULE_BASE + 0x365688;
    Hooks::jumpBack_patchLeaderListShowMaxSkill = hookAddress + 7;

    if (!Hooks::hook((void*)hookAddress, Hooks::patchLeaderListShowMaxSkill, 5, 2)) {
        std::cout << "Hook 'activateLeaderListShowMaxSkill' failed" << std::endl;
    }
    else {
        std::cout << "Hook 'activateLeaderListShowMaxSkill' succeeded" << std::endl;
        std::cout << "jumpBack_patchLeaderListShowMaxSkill: " << Memory::n2hexstr(Hooks::jumpBack_patchLeaderListShowMaxSkill) << std::endl;
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
    Hooks::jumpBack_patchLeaderListShowMaxSkillSelected = hookAddress + 7;

    if (!Hooks::hook((void*)hookAddress, Hooks::patchLeaderListShowMaxSkillSelected, 5, 2)) {
        std::cout << "Hook 'activateLeaderListShowMaxSkillSelected' failed" << std::endl;
    }
    else {
        std::cout << "Hook 'activateLeaderListShowMaxSkillSelected' succeeded" << std::endl;
        std::cout << "jumpBack_patchLeaderListShowMaxSkillSelected: " << Memory::n2hexstr(Hooks::jumpBack_patchLeaderListShowMaxSkillSelected) << std::endl;
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