#include <lua.hpp>
#include <CasualLibrary.hpp>

#include <string>
#include <iostream>
#include <intrin.h>
#include <processthreadsapi.h>
#include <chrono>

#include <utils.hpp>
#include <HoiDataStructures.hpp>

#include <CCountry.hpp>
#include <Hooks/Hooks.hpp>
#include <Hooks/CLeaderHooks.hpp>
#include <Hooks/CArmyHooks.hpp>
#include <Patches.hpp>

int DATA_SECTION_START = 0x12F5000;
bool EXTERNAL_DEBUG = false; // debug mode for the CasualLib::External Class
DWORD MODULE_BASE;


/////////////////////////////////////
//         INFO FUNCTIONS          //
/////////////////////////////////////

std::unordered_map<std::string, uintptr_t>* countryCache = new std::unordered_map<std::string, uintptr_t>;
uintptr_t getCountry(Memory::External &external, std::string tag) {
    if (countryCache->find(tag) != countryCache->end()) {
        return countryCache->at(tag);
    }

    uintptr_t ctr = external.findCountryInstance(MODULE_BASE + DATA_SECTION_START, tag);
    if (ctr != 0) {
        countryCache->insert(std::make_pair(tag, ctr));
        DEBUG_OUT(std::cout << "added to countryCache: " << tag << std::endl);
        return ctr;
    }

    return 0;
}

__declspec(dllexport) int getCountryFlags(lua_State* L)
{
    DEBUG_OUT(std::cout << "getCountryFlags called" << std::endl);
    std::string searchTag = luaL_checklstring(L, 1, NULL);
    DEBUG_OUT(std::cout << "searchTag: " << searchTag << std::endl);

    Memory::External external = Memory::External(GetCurrentProcessId(), EXTERNAL_DEBUG);

    uintptr_t ctr = getCountry(external, searchTag);
    DEBUG_OUT(std::cout << "ctr: " << Memory::n2hexstr(ctr) << std::endl);

    if (ctr != 0) {
        uintptr_t flagsOffset = ctr + 0x180 + 0x4; // CFlagsVFTable + Flag Tree beginning
        uintptr_t flagsPtr = external.read<uintptr_t>(flagsOffset);
        DEBUG_OUT(std::cout << "flagsPtr: " << Memory::n2hexstr(flagsPtr) << std::endl);

        auto flags = CCountry::getFlags(external, flagsPtr);
        DEBUG_OUT(std::cout << "flags->size(): " << flags->size() << std::endl);

        lua_createtable(L, flags->size(), 0);
        for (size_t i = 0; i < flags->size(); i++) {
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
    DEBUG_OUT(std::cout << "getCountryVariables called" << std::endl);
    std::string searchTag = luaL_checklstring(L, 1, NULL);
    DEBUG_OUT(std::cout << "searchTag: " << searchTag << std::endl);

    Memory::External external = Memory::External(GetCurrentProcessId(), EXTERNAL_DEBUG);

    uintptr_t ctr = getCountry(external, searchTag);
    DEBUG_OUT(std::cout << "ctr: " << Memory::n2hexstr(ctr) << std::endl);

    if (ctr != 0) {
        uintptr_t varsOffset = ctr + 0x1AC + 0x4; // CVariablesVFTable + Vars Tree beginning
        uintptr_t varsPtr = external.read<uintptr_t>(varsOffset);
        DEBUG_OUT(std::cout << "varsPtr: " << Memory::n2hexstr(varsPtr) << std::endl);

        auto vars = CCountry::getVars(external, varsPtr);
        DEBUG_OUT(std::cout << "vars->size(): " << vars->size() << std::endl);

        lua_newtable(L, 0, vars->size());
        for (size_t i = 0; i < vars->size(); i++) {
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

/////////////////////////////////////
//        LEADER FUNCTIONS         //
/////////////////////////////////////
bool cacheTraitsDone = false;
std::unordered_map<std::string, uintptr_t>* traitCache = new std::unordered_map<std::string, uintptr_t>;
uintptr_t getTrait(Memory::External& external, std::string traitName) {
    if (traitCache->find(traitName) != traitCache->end()) {
        return traitCache->at(traitName);
    }

    uintptr_t res = external.findTraitInstance(MODULE_BASE + DATA_SECTION_START, traitName);
    if (res != 0) {
        traitCache->insert(std::make_pair(traitName, res));
        DEBUG_OUT(printf("Added to traitCache: %s - %#010x \n", traitName.c_str(), res));
        return res;
    }

    return 0;
}
void addTraitToCache(std::string traitName, uintptr_t address) {
    traitCache->insert(std::make_pair(traitName, address));
    //DEBUG_OUT(printf("Added to traitCache: %s - %#010x \n", traitName.c_str(), address));
    return;
}
void cacheTraits() {
    if (!cacheTraitsDone) {
        Memory::External external = Memory::External(GetCurrentProcessId(), EXTERNAL_DEBUG);

        uintptr_t CTraitVFTable = MODULE_BASE + 0x11C7DC0;
        //std::cout << "CTraitVFTable: " << Memory::n2hexstr(CTraitVFTable) << std::endl;
        std::string CTraitVFTableSig = Memory::ptrToSignature(CTraitVFTable);
        //std::cout << "CTraitVFTableSig: " << CTraitVFTableSig << std::endl;
        std::vector<uintptr_t>* traits;
        traits = external.findSignatures(MODULE_BASE + DATA_SECTION_START, CTraitVFTableSig.c_str(), 4, 99999);
        if (traits->size() != 0) {
            for (auto& traitAddr : *traits) {
                std::string traitName = utils::getCString((DWORD*)traitAddr + (0x2C / 4));
                addTraitToCache(traitName, traitAddr);
            }
            INFO_OUT(printf("Trait cache filled (%i) \n", traitCache->size()));
            cacheTraitsDone = true;
            delete traits;
            return;
        }
    }
    return;
}

bool cacheLeadersDone = false;
std::unordered_map<unsigned int, uintptr_t>* leaderCache = new std::unordered_map<unsigned int, uintptr_t>;
uintptr_t getLeader(Memory::External& external, unsigned int leaderId) {
    if (leaderCache->find(leaderId) != leaderCache->end()) {
        return leaderCache->at(leaderId);
    }

    uintptr_t res = external.findLeaderInstance(MODULE_BASE + DATA_SECTION_START, leaderId);
    if (res != 0) {
        leaderCache->insert(std::make_pair(leaderId, res));
        //DEBUG_OUT(printf("Added to leaderCache: %u - %#010x \n", leaderId, res));
        return res;
    }

    return 0;
}
void addLeaderToCache(unsigned int leaderId, uintptr_t address) {
    leaderCache->insert(std::make_pair(leaderId, address));
    DEBUG_OUT(printf("Added to leaderCache: %u - %#010x \n", leaderId, address));
    return;
}
void cacheLeaders() {
    if (!cacheLeadersDone) {
        Memory::External external = Memory::External(GetCurrentProcessId(), EXTERNAL_DEBUG);

        uintptr_t CLeaderVFTable = MODULE_BASE + 0x11C5220;
        //std::cout << "CLeaderVFTable: " << Memory::n2hexstr(CLeaderVFTable) << std::endl;
        std::string CLeaderVFTableSig = Memory::ptrToSignature(CLeaderVFTable);
        //std::cout << "CLeaderVFTableSig: " << CLeaderVFTableSig << std::endl;
        std::vector<uintptr_t>* leaders;
        leaders = external.findSignatures(MODULE_BASE + DATA_SECTION_START, CLeaderVFTableSig.c_str(), 4, 99999);
        if (leaders->size() > 1) { // there is always a "NULL Leader", so check for more than 1
            for (auto& leaderAddr : *leaders) {
                unsigned int leaderId = *(DWORD*)((BYTE*)leaderAddr + 0xC);;
                addLeaderToCache(leaderId, leaderAddr);
            }
            INFO_OUT(printf("Leader cache filled (%i) \n", leaderCache->size()));
            cacheLeadersDone = true;
            delete leaders;
            return;
        }
    }
    return;
}

typedef void(__stdcall* CLeaderAddTraitFunction)(int leaderAddress, unsigned int* trait);
__declspec(dllexport) int addTraitToLeader(lua_State* L){
    DEBUG_OUT(printf("addTraitToLeader called\n"));

    unsigned int leaderId = luaL_checkinteger(L, 1);
    DEBUG_OUT(printf("leaderId: '%u'\n", leaderId));
    std::string traitName = luaL_checklstring(L, 2, NULL);
    DEBUG_OUT(printf("trait: '%s'\n", traitName.c_str()));

    Memory::External external = Memory::External(GetCurrentProcessId(), EXTERNAL_DEBUG);

    auto leaderAddr = getLeader(external, leaderId);
    auto traitAddr = getTrait(external, traitName);
    if (leaderAddr == 0) {
        INFO_OUT(printf("Couldn't find leader with ID '%u'\n", leaderId));
        lua_pushboolean(L, false);
        return 1;
    }
    else if (traitAddr == 0) {
        INFO_OUT(printf("Couldn't find trait with name '%s'\n", traitName.c_str()));
        lua_pushboolean(L, false);
        return 1;
    }

    CLeaderAddTraitFunction cLeaderAddTraitFunction = reinterpret_cast<CLeaderAddTraitFunction>(Hooks::MODULE_BASE + 0x181a60);
    cLeaderAddTraitFunction(leaderAddr, (unsigned int*) traitAddr);

    lua_pushboolean(L, true);
    DEBUG_OUT(printf("addTraitToLeader finished\n"));
    return 1;
}

void activateLeaderRankChangeHook() {
    DWORD hookAddress = MODULE_BASE + 0x1D7CDC;
    Hooks::CLeader::jumpBack_leaderRankChangeHook = hookAddress + 6;
    if (!Hooks::hook((void*)hookAddress, Hooks::CLeader::leaderRankChangeHook, 5, 1)) {
        INFO_OUT(std::cout << "Hook 'activateLeaderRankChangeHook' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Hook 'activateLeaderRankChangeHook' succeeded" << std::endl);
        DEBUG_OUT(std::cout << "jumpBack_leaderRankChangeHook: " << Memory::n2hexstr(Hooks::CLeader::jumpBack_leaderRankChangeHook) << std::endl);
    }
}

void activateLeaderDontSaveRankSpecificTraitsHook() {
    DWORD hookAddress = MODULE_BASE + 0x17FF08;
    Hooks::CLeader::jumpBack_leaderDontSaveRankSpecificTraitsHook = hookAddress + 7;
    if (!Hooks::hook((void*)hookAddress, Hooks::CLeader::leaderDontSaveRankSpecificTraitsHook, 5, 2)) {
        INFO_OUT(std::cout << "Hook 'activateLeaderDontSaveRankSpecificTraitsHook' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Hook 'activateLeaderDontSaveRankSpecificTraitsHook' succeeded" << std::endl);
        DEBUG_OUT(std::cout << "jumpBack_leaderDontSaveRankSpecificTraitsHook: " << Memory::n2hexstr(Hooks::CLeader::jumpBack_leaderDontSaveRankSpecificTraitsHook) << std::endl);
    }
}

__declspec(dllexport) int addRankSpecificTrait(lua_State* L) {
    DEBUG_OUT(std::cout << "addRankSpecificTrait called" << std::endl);

    std::string activeName = luaL_checklstring(L, 1, NULL);
    std::string inActiveName = luaL_checklstring(L, 2, NULL);
    int lowerRank = luaL_checkinteger(L, 3);
    int upperRank = luaL_checkinteger(L, 4);

    cacheTraits();

    if (traitCache->size() == 0) {
        INFO_OUT(std::cout << "addRankSpecificTrait for: '" << activeName << "' not executed due to unitialised traits" << std::endl);
        lua_pushboolean(L, false);
        return 1;
    }
    if (Hooks::CLeader::rankSpecificTraitsActive->find(activeName) != Hooks::CLeader::rankSpecificTraitsActive->end()) {
        DEBUG_OUT(std::cout << "addRankSpecificTrait for: '" << activeName << "' was already added" << std::endl);
        lua_pushboolean(L, true);
        return 1;
    }
    if (traitCache->find(activeName) == traitCache->end() || traitCache->find(inActiveName) == traitCache->end()) {
        INFO_OUT(std::cout << "Trait for RankSpecificTrait '" << activeName << "' not found!" << std::endl);
        lua_pushboolean(L, false);
        return 1;
    }

    DEBUG_OUT(std::cout << "activeName: " << activeName << std::endl);
    DEBUG_OUT(std::cout << "inActiveName: " << inActiveName << std::endl);
    DEBUG_OUT(std::cout << "lowerRank: " << lowerRank << std::endl);
    DEBUG_OUT(std::cout << "upperRank: " << upperRank << std::endl);

    Hooks::CLeader::RankSpecificTrait* rst = new Hooks::CLeader::RankSpecificTrait;
    rst->lowerRank = lowerRank;
    rst->upperRank = upperRank;
    rst->activeName = activeName;
    rst->activeTraitPtr = 0;
    rst->inActiveTraitPtr = 0;
    rst->inactiveName = inActiveName;

    rst->activeTraitPtr = traitCache->at(activeName);
    DEBUG_OUT(std::cout << "rst->activeTraitPtr: " << rst->activeTraitPtr << std::endl);
    rst->inActiveTraitPtr = traitCache->at(inActiveName);
    DEBUG_OUT(std::cout << "rst->inActiveTraitPtr: " << rst->inActiveTraitPtr << std::endl);
    
    Hooks::CLeader::rankSpecificTraitsActive->insert(std::make_pair(activeName, rst));
    Hooks::CLeader::rankSpecificTraitsInActive->insert(std::make_pair(inActiveName, rst));

    DEBUG_OUT(std::cout << "Hooks::CLeader::rankSpecificTraitsInActive->size(): " << Hooks::CLeader::rankSpecificTraitsInActive->size() << std::endl);

    lua_pushboolean(L, true);
    INFO_OUT(std::cout << "addRankSpecificTrait for: '" << activeName << "' done" << std::endl);
    DEBUG_OUT(std::cout << "addRankSpecificTrait finished" << std::endl);
    return 1;
}

BOOL activateRankSpecificTraitsDone = false;
__declspec(dllexport) int activateRankSpecificTraits(lua_State* L)
{
    if (activateRankSpecificTraitsDone) {
        return 0;
    }

    if (!Hooks::CLeader::isLeaderRankChangeHookActive) {
        activateLeaderRankChangeHook();
        activateLeaderDontSaveRankSpecificTraitsHook();
        Hooks::CLeader::isLeaderRankChangeHookActive = true;
    }

    cacheTraits();
    if (traitCache->size() == 0) {
        // Traits are not set up when the LUA is first run -> defer hooking until the LUA context is reloaded during save loading
        INFO_OUT(std::cout << "Hook 'activateRankSpecificTraits' deferred until save load" << std::endl);
        return 0;
    }

    Hooks::CLeader::isRankSpecificTraitsActive = true;
    activateRankSpecificTraitsDone = true;
    INFO_OUT(std::cout << "Hook 'activateRankSpecificTraits' activated" << std::endl);
    return 0;
}

BOOL checkRankSpecificTraitsConsistencyDone = false;
__declspec(dllexport) int checkRankSpecificTraitsConsistency(lua_State* L)
{
    if (checkRankSpecificTraitsConsistencyDone) {
        return 0;
    }


    cacheTraits();
    cacheLeaders();
    if (traitCache->size() == 0 || leaderCache->size() == 0) {
        return 0;
    }
    INFO_OUT(printf("Checking rank specific traits consistency.\n"));

    for (auto entry = leaderCache->begin(); entry != leaderCache->end(); ++entry) {
        Hooks::CLeader::checkRankSpecificTraitsConsistency((DWORD*) entry->second, -1);
    }

    checkRankSpecificTraitsConsistencyDone = true;
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

    cacheTraits();
    if (traitCache->size() == 0) {
        // Traits are not set up when the LUA is first run -> defer hooking until the LUA context is reloaded during save loading
        INFO_OUT(std::cout << "Hook 'activateLeaderPromotionSkillLoss' deferred until save load" << std::endl);
        return 0;
    }

    auto tempSkillTraits = new std::vector<uintptr_t>; // unsorted vector of the traits which are used to track leader skill
    Hooks::CLeader::skillTraits = new std::vector<DWORD>; // sorted vector of the traits
    for (auto entry = traitCache->begin(); entry != traitCache->end(); ++entry) {
        auto trait = entry->second;
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
    activateLeaderPromotionSkillLossDone = true;
    delete tempSkillTraits;
    INFO_OUT(std::cout << "Hook 'activateLeaderPromotionSkillLoss' activated" << std::endl);
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
        INFO_OUT(std::cout << "Hook 'activateLeaderListShowMaxSkill' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Hook 'activateLeaderListShowMaxSkill' succeeded" << std::endl);
        DEBUG_OUT(std::cout << "jumpBack_patchLeaderListShowMaxSkill: " << Memory::n2hexstr(Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkill) << std::endl);
    }
    activateLeaderListShowMaxSkillDone = true;
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
        INFO_OUT(std::cout << "Hook 'activateLeaderListShowMaxSkillSelected' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Hook 'activateLeaderListShowMaxSkillSelected' succeeded" << std::endl);
        DEBUG_OUT(std::cout << "jumpBack_patchLeaderListShowMaxSkillSelected: " << Memory::n2hexstr(Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkillSelected) << std::endl);
    }
    activateLeaderListShowMaxSkillSelectedDone = true;
    return 0;
}

/////////////////////////////////////
//          UNIT FUNCTIONS         //
/////////////////////////////////////
void activateUnitAttachmentLimitHook()
{
    if (Hooks::CArmy::isUnitAttachmentLimitHookActive) {
        return;
    }

    DWORD hookAddress = MODULE_BASE + 0x1b9733;
    Hooks::CArmy::jumpBack_unitAttachmentLimitHook = hookAddress + 5;

    if (!Hooks::hook((void*)hookAddress, Hooks::CArmy::unitAttachmentLimitHook, 5, 0)) {
        INFO_OUT(std::cout << "Hook 'activateUnitAttachmentLimitHook' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Hook 'activateUnitAttachmentLimitHook' succeeded" << std::endl);
        DEBUG_OUT(std::cout << "jumpBack_unitAttachmentLimitHook: " << Memory::n2hexstr(Hooks::CArmy::jumpBack_unitAttachmentLimitHook) << std::endl);
    }

    Hooks::CArmy::isUnitAttachmentLimitHookActive = true;
    return;
}

bool setCorpsUnitLimitDone = false;
__declspec(dllexport) int setCorpsUnitLimit(lua_State* L)
{
    if (!Hooks::CArmy::isUnitAttachmentLimitHookActive) {
        activateUnitAttachmentLimitHook();
    }

    int newLimit = luaL_checkinteger(L, 1);
    bool force = lua_toboolean(L, 2);

    if (force || setCorpsUnitLimitDone == false) {
        Hooks::CArmy::corpsUnitLimit = newLimit;
        setCorpsUnitLimitDone = true;
        INFO_OUT(std::cout << "Corps unit limit set to: " << newLimit << std::endl);
    }
    return 0;
}

bool setArmyUnitLimitDone = false;
__declspec(dllexport) int setArmyUnitLimit(lua_State* L)
{
    if (!Hooks::CArmy::isUnitAttachmentLimitHookActive) {
        activateUnitAttachmentLimitHook();
    }

    int newLimit = luaL_checkinteger(L, 1);
    bool force = lua_toboolean(L, 2);

    if (force || setArmyUnitLimitDone == false) {
        Hooks::CArmy::armyUnitLimit = newLimit;
        setArmyUnitLimitDone = true;
        INFO_OUT(std::cout << "Army unit limit set to: " << newLimit << std::endl);
    }
    return 0;
}

bool setArmyGroupUnitLimitDone = false;
__declspec(dllexport) int setArmyGroupUnitLimit(lua_State* L)
{
    if (!Hooks::CArmy::isUnitAttachmentLimitHookActive) {
        activateUnitAttachmentLimitHook();
    }

    int newLimit = luaL_checkinteger(L, 1);
    bool force = lua_toboolean(L, 2);

    if (force || setArmyGroupUnitLimitDone == false) {
        Hooks::CArmy::armyGroupUnitLimit = newLimit;
        setArmyGroupUnitLimitDone = true;
        INFO_OUT(std::cout << "Armygroup unit limit set to: " << newLimit << std::endl);
    }
    return 0;
}

__declspec(dllexport) int addCommandLimitTrait(lua_State* L)
{
    std::string traitName = luaL_checkstring(L, 1);
    int effect = luaL_checkinteger(L, 2);
    DEBUG_OUT(std::cout << "addCommandLimitTrait: '" << traitName << "' - effect: " << effect << std::endl);

    if (Hooks::CArmy::commandLimitTraits->find(traitName) != Hooks::CArmy::commandLimitTraits->end()) {
        DEBUG_OUT(std::cout << "addCommandLimitTrait for: " << traitName << " was already added" << std::endl);
        return 0;
    }

    Hooks::CArmy::CommandLimitTrait* clt = new Hooks::CArmy::CommandLimitTrait;
    clt->traitName = traitName;
    clt->limitEffect = effect;

    Hooks::CArmy::commandLimitTraits->insert(std::make_pair(traitName, clt));

    DEBUG_OUT(std::cout << "Hooks::CArmy::commandLimitTraits->size(): " << Hooks::CArmy::commandLimitTraits->size() << std::endl);
    DEBUG_OUT(std::cout << "addCommandLimitTrait finished" << std::endl);
    return 0;
}


/////////////////////////////////////
//          GAME PATCHES           //
/////////////////////////////////////

BOOL activateOffmapICPatchDone = false;
__declspec(dllexport) int activateOffmapICPatch(lua_State* L)
{
    if (activateOffmapICPatchDone) {
        return 0;
    }
    
    if (!Patches::patchOffMapIC(MODULE_BASE)) {
        INFO_OUT(std::cout << "Patch 'activateOffmapICPatch' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Patch 'activateOffmapICPatch' succeeded" << std::endl);
    }

    activateOffmapICPatchDone = true;
    return 0;
}


BOOL activateMinisterTechDecayPatchDone = false;
__declspec(dllexport) int activateMinisterTechDecayPatch(lua_State* L)
{
    if (activateMinisterTechDecayPatchDone) {
        return 0;
    }

    if (!Patches::patchMinisterTechDecay(MODULE_BASE)) {
        INFO_OUT(std::cout << "Patch 'activateMinisterTechDecayPatch' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Patch 'activateMinisterTechDecayPatch' succeeded" << std::endl);
    }


    activateMinisterTechDecayPatchDone = true;
    return 0;
}


BOOL activateWarExhaustionNeutralityResetPatchDone = false;
__declspec(dllexport) int activateWarExhaustionNeutralityResetPatch(lua_State* L)
{
    if (activateWarExhaustionNeutralityResetPatchDone) {
        return 0;
    }

    if (!Patches::patchWarExhaustionNeutralityReset(MODULE_BASE)) {
        INFO_OUT(std::cout << "Patch 'activateWarExhaustionNeutralityResetPatch' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Patch 'activateWarExhaustionNeutralityResetPatch' succeeded" << std::endl);
    }

    activateWarExhaustionNeutralityResetPatchDone = true;
    return 0;
}


/////////////////////////////////////
//         MISC FUNCTIONS          //
/////////////////////////////////////
bool moduleBaseAlreadySet = false;
__declspec(dllexport) int setModuleBase(lua_State* L)
{
    if (moduleBaseAlreadySet) {
        return 0;
    }
    Memory::External external = Memory::External(GetCurrentProcessId(), EXTERNAL_DEBUG);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    MODULE_BASE = modulePtr.get();
    Hooks::MODULE_BASE = MODULE_BASE;
    INFO_OUT(std::cout << "MODULE_BASE at: " << Memory::n2hexstr(MODULE_BASE) << std::endl);
    moduleBaseAlreadySet = true;
    return 0;
}

bool consoleStarted = false;
__declspec(dllexport) int startConsole(lua_State* L)
{
    if (consoleStarted) { 
        return 0;
    }
    AllocConsole();
    FILE* fp;
    freopen_s(&fp, "CONOUT$", "w", stdout); // output only

    HANDLE handle = GetStdHandle(STD_INPUT_HANDLE);
    SetConsoleMode(handle, ENABLE_EXTENDED_FLAGS);  // Set mode to this to prevent accidentially selecting something in the console
    // because that will freeze the entire thing until it is unselected

    HWND window = GetConsoleWindow();
    RECT r;
    GetWindowRect(window, &r);
    MoveWindow(window, r.left + 50, r.top + 50, 1000, 600, TRUE);

    consoleStarted = true;
    return 0;
}

#include <chrono>
#include <thread>

__declspec(dllexport) int test(lua_State* L)
{
    INFO_OUT(printf("#### test called ####\n"));
    Memory::External external = Memory::External(GetCurrentProcessId(), EXTERNAL_DEBUG);

    std::this_thread::sleep_for(std::chrono::seconds(20));

    /*
    printMemory();
    Memory::heapWalkExternal(external.handle);
    printMemory();

    uintptr_t CTraitVFTable = MODULE_BASE + 0x1C7DC0;
    //std::cout << "CTraitVFTable: " << Memory::n2hexstr(CTraitVFTable) << std::endl;
    std::string CTraitVFTableSig = Memory::ptrToSignature(CTraitVFTable);
    //std::cout << "CTraitVFTableSig: " << CTraitVFTableSig << std::endl;
    std::vector<uintptr_t>* traits;
    traits = external.findSignatures(MODULE_BASE + DATA_SECTION_START, CTraitVFTableSig.c_str(), 4, 99999);
    printMemory();
    */


    return 0;
}

__declspec(dllexport) int deactivateInterAiExpeditionaries(lua_State* L)
{
    INFO_OUT(printf("#### deactivateInterAiExpeditionaries called ####\n"));

    BYTE one[2] = { 0x90, 0xE9 };
    DWORD address1 = MODULE_BASE + 0x4ba8c2;
    Patches::patchBytes((void*)address1, one, 2);

    BYTE two[2] = { 0x90, 0xE9 };
    DWORD address2 = MODULE_BASE + 0x4b37e5;
    Patches::patchBytes((void*)address2, two, 2);

    return 0;
}



__declspec(dllexport) luaL_Reg BiceLib[] = {
    // Misc
    {"startConsole", startConsole},
    {"setModuleBase", setModuleBase},
    {"test", test},
    {"deactivateInterAiExpeditionaries", deactivateInterAiExpeditionaries},
    // Info Functions
    {"getCountryFlags", getCountryFlags},
    {"getCountryVariables", getCountryVariables},
    // Leader Functions
    {"addRankSpecificTrait", addRankSpecificTrait},
    {"activateRankSpecificTraits", activateRankSpecificTraits},
    {"checkRankSpecificTraitsConsistency", checkRankSpecificTraitsConsistency},
    {"activateLeaderPromotionSkillLoss", activateLeaderPromotionSkillLoss},
    {"activateLeaderListShowMaxSkill", activateLeaderListShowMaxSkill},
    {"activateLeaderListShowMaxSkillSelected", activateLeaderListShowMaxSkillSelected},
    {"addTraitToLeader", addTraitToLeader},
    // Unit Functions
    {"setCorpsUnitLimit", setCorpsUnitLimit},
    {"setArmyUnitLimit", setArmyUnitLimit},
    {"setArmyGroupUnitLimit", setArmyGroupUnitLimit},
    {"addCommandLimitTrait", addCommandLimitTrait},
    // Patches
    {"activateOffmapICPatch", activateOffmapICPatch},
    {"activateMinisterTechDecayPatch", activateMinisterTechDecayPatch},
    {"activateWarExhaustionNeutralityResetPatch", activateWarExhaustionNeutralityResetPatch},
    {NULL, NULL}
};


extern "C"
__declspec(dllexport) int luaopen_BiceLib(lua_State* L)
{
    lua_newtable(L);
    luaL_register(L, NULL, BiceLib);
    return 1;
}