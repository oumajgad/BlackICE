#include <lua.hpp>
#include <CasualLibrary.hpp>

#include <iostream>
#include <intrin.h>
#include <processthreadsapi.h>
#include <chrono>

#include <CCountry.hpp>

int DATA_SECTION_START = 0x12F5000;
bool DEBUG = true;

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
        std::cout << "vars->size(): " << vars->size() << std::endl;

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


__declspec(dllexport) int startConsole(lua_State* L)
{
    AllocConsole();
    FILE* fp;
    freopen_s(&fp, "CONOUT$", "w", stdout); // output only
    return 0;
}

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
        mov[leaderAddress], edi
        mov[CPromoteLeaderCommand], esi
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
        mov[edi + 0x6c], eax
        cmp[edi + 0x68], ebx
        jmp [jumpBackPatchLeaderSkillLossOnPromotion]
    }
}

__declspec(dllexport) int activateLeaderPromotionSkillLoss(lua_State* L)
{
    Memory::External external = Memory::External(GetCurrentProcessId(), DEBUG);
    Address modulePtr = external.getModule("hoi3_tfh.exe");

    DWORD hookAddress = modulePtr + 0x1d7cdc;
    jumpBackPatchLeaderSkillLossOnPromotion = hookAddress + 6;

    if (!hook((void*)hookAddress, patchLeaderSkillLossOnPromotion, 5, 1)) {
        std::cout << "Patch 'activateLeaderPromotionSkillLoss' failed" << std::endl;
    }
    else {
        std::cout << "Patch 'activateLeaderPromotionSkillLoss' succeeded" << std::endl;
        std::cout << "jumpBackPatchLeaderSkillLossOnPromotion: " << Memory::n2hexstr(jumpBackPatchLeaderSkillLossOnPromotion) << std::endl;
    }

    return 0;
}


__declspec(dllexport) luaL_Reg BiceLib[] = {
    {"getCountryFlags", getCountryFlags},
    {"getCountryVariables", getCountryVariables},
    {"startConsole", startConsole},
    {"activateLeaderPromotionSkillLoss", activateLeaderPromotionSkillLoss },
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