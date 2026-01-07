#include <lua.hpp>
#include <CasualLibrary.hpp>

#include <string>
#include <iostream>
#include <intrin.h>
#include <processthreadsapi.h>
#include <chrono>

#include <utils.hpp>
#include <HoiDataStructures.hpp>

#include <GameClasses/CCountry.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/CSubUnitDefinition.hpp>
#include <GameClasses/CTerrain.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CLeader.hpp>
#include <Hooks/Hooks.hpp>
#include <Hooks/CLeaderHooks.hpp>
#include <Hooks/CArmyHooks.hpp>
#include <Hooks/CNavyHooks.hpp>
#include <Hooks/HookedPatches.hpp>
#include <Hooks/ConstructorHooks.hpp>
#include <Patches.hpp>

int DATA_SECTION_START = 0x12F5000;
bool EXTERNAL_DEBUG = false; // debug mode for the CasualLib::External Class
DWORD MODULE_BASE;

lua_State* LUA_STATE = nullptr;
std::vector<lua_State*> *LUA_STATES = new std::vector<lua_State*>;

/////////////////////////////////////
//       GAME INFO FUNCTIONS       //
/////////////////////////////////////

std::unordered_map<std::string, uintptr_t>* countryCache = new std::unordered_map<std::string, uintptr_t>;
uintptr_t getCountry(std::string tag) {
    if (countryCache->find(tag) != countryCache->end()) {
        return countryCache->at(tag);
    }

    return 0;
}

void addCountryToCache(std::string tag, uintptr_t address) {
    countryCache->insert(std::make_pair(tag, address));
    DEBUG_OUT(printf("Added to countryCache: %s - %#010x \n", tag.c_str(), address));
    return;
}

bool cacheCountriesDone = false;
__declspec(dllexport) int cacheCountries(lua_State* L)
{
    if (!cacheCountriesDone) {
        for (int i = 0; i < 300; i++) {
            uintptr_t countryPtr = CCountry::CountryPtrs[i];
            if (countryPtr == 0) { // Array not yet initialized OR end of array reached
                break;
            }
            std::string countryTag = utils::getCString((DWORD*)(countryPtr + 0x1E4));
            addCountryToCache(countryTag, countryPtr);
            cacheCountriesDone = true;
        }
        if (cacheCountriesDone) {
            INFO_OUT(printf("Country cache filled (%i) \n", countryCache->size()));
        }
    }
    return 0;
}

__declspec(dllexport) int getProvinceDetails(lua_State* L)
{
    int provinceId = luaL_checkint(L, 1, NULL);
    Memory::External external = Memory::External(GetCurrentProcessId(), EXTERNAL_DEBUG);
    auto province = CMapProvince::GetMapProvinceById(external, provinceId);
    CMapProvince::PushCMapProvinceToStack(L, province);
    return 1;
}

__declspec(dllexport) int getCountryActiveEventModifiers(lua_State* L)
{
    std::string searchTag = luaL_checklstring(L, 1, NULL);
    uintptr_t ctr = getCountry(searchTag);
    if (ctr != 0) {
        auto activeModifiers = CCountry::getActiveEventModifiers(ctr);
        lua_createtable(L, activeModifiers.size(), 0);
        for (size_t i = 0; i < activeModifiers.size(); i++) {
            lua_pushstring(L, activeModifiers.at(i).first.c_str());
            lua_pushstring(L, activeModifiers.at(i).second.c_str());
            lua_settable(L, -3);
        }
        return 1;
    }
    lua_pushnil(L);
    return 1;
}

__declspec(dllexport) int getCountryFlags(lua_State* L)
{
    std::string searchTag = luaL_checklstring(L, 1, NULL);
    uintptr_t ctr = getCountry(searchTag);
    if (ctr != 0) {
        auto flags = CCountry::getFlags(ctr);
        lua_createtable(L, flags->size(), 0);
        for (size_t i = 0; i < flags->size(); i++) {
            lua_pushstring(L, flags->at(i).c_str());
            lua_rawseti(L, -2, i + 1);
        }
        delete flags;
        return 1;

    }
    lua_pushnil(L);
    return 1;
}

__declspec(dllexport) int getCountryVariables(lua_State* L)
{
    std::string searchTag = luaL_checklstring(L, 1, NULL);
    uintptr_t ctr = getCountry(searchTag);
    if (ctr != 0) {
        auto vars = CCountry::getVars(ctr);
        lua_createtable(L, 0, vars->size());
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

__declspec(dllexport) int getCountryOffmapIc(lua_State* L)
{
    std::string searchTag = luaL_checklstring(L, 1, NULL);
    uintptr_t ctr = getCountry(searchTag);
    if (ctr != 0) {
        int countryId = *(int *)(ctr + 0x1e8);
        lua_pushinteger(L, Hooks::Patches::offmapIcPerCountry[countryId]);
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
    DEBUG_OUT(printf("Added to traitCache: %s - %#010x \n", traitName.c_str(), address));
    //std::string x = std::format("Added to traitCache : {} - {:x}", traitName.c_str(), address);
    //logInLua(x.c_str());
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
    //std::string x = std::format("Added to leaderCache : {} - {:x}", leaderId, address);
    //logInLua(x.c_str());
    return;
}
void cacheLeaders() {
    if (!cacheLeadersDone) {
        Memory::External external = Memory::External(GetCurrentProcessId(), EXTERNAL_DEBUG);

        uintptr_t CLeaderVFTable = MODULE_BASE + 0x11C5220;
        std::string CLeaderVFTableSig = Memory::ptrToSignature(CLeaderVFTable);
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

__declspec(dllexport) int getLeaderDetails(lua_State* L) {
    DEBUG_OUT(printf("getLeaderDetails called\n"));
    unsigned int leaderId = luaL_checkinteger(L, 1);
    DEBUG_OUT(printf("leaderId: %d\n", leaderId));
    Memory::External external = Memory::External(GetCurrentProcessId(), EXTERNAL_DEBUG);
    auto leader = CLeader::GetLeaderById(external, leaderId);
    if (leader.id != 0) {
        CLeader::PushCLeaderToStack(L, leader);
    }
    else {
        lua_pushnil(L);
    }
    return 1;
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
        ERROR_OUT(printf("Couldn't find leader with ID '%u'\n", leaderId));
        lua_pushboolean(L, false);
        return 1;
    }
    else if (traitAddr == 0) {
        ERROR_OUT(printf("Couldn't find trait with name '%s'\n", traitName.c_str()));
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
        ERROR_OUT(printf("Hook 'activateLeaderRankChangeHook' failed \n"));
    }
    else {
        INFO_OUT(printf("Hook 'activateLeaderRankChangeHook' succeeded \n"));
        DEBUG_OUT(printf("jumpBack_leaderRankChangeHook: %#010x \n", Hooks::CLeader::jumpBack_leaderRankChangeHook));
        Hooks::CLeader::isLeaderRankChangeHookActive = true;
    }
}

void activateLeaderDontSaveRankSpecificTraitsHook() {
    DWORD hookAddress = MODULE_BASE + 0x17FF08;
    Hooks::CLeader::jumpBack_leaderDontSaveRankSpecificTraitsHook = hookAddress + 7;
    if (!Hooks::hook((void*)hookAddress, Hooks::CLeader::leaderDontSaveRankSpecificTraitsHook, 5, 2)) {
        INFO_OUT(printf("Hook 'activateLeaderDontSaveRankSpecificTraitsHook' failed\n"));
    }
    else {
        INFO_OUT(printf("Hook 'activateLeaderDontSaveRankSpecificTraitsHook' succeeded\n"));
        DEBUG_OUT(printf("jumpBack_leaderDontSaveRankSpecificTraitsHook: %#010x \n", Hooks::CLeader::jumpBack_leaderDontSaveRankSpecificTraitsHook));
    }
}

__declspec(dllexport) int addRankSpecificTrait(lua_State* L) {
    DEBUG_OUT(printf("addRankSpecificTrait called\n"));

    std::string activeName = luaL_checklstring(L, 1, NULL);
    std::string inActiveName = luaL_checklstring(L, 2, NULL);
    int lowerRank = luaL_checkinteger(L, 3);
    int upperRank = luaL_checkinteger(L, 4);

    cacheTraits();

    if (traitCache->size() == 0) {
        INFO_OUT(printf("addRankSpecificTrait for: '%s' deferred until save load \n", activeName.c_str()));
        lua_pushboolean(L, false);
        return 1;
    }
    if (Hooks::CLeader::rankSpecificTraitsActive->find(activeName) != Hooks::CLeader::rankSpecificTraitsActive->end()) {
        DEBUG_OUT(printf("addRankSpecificTrait for: '%s' was already added \n", activeName.c_str()));
        lua_pushboolean(L, true);
        return 1;
    }
    if (traitCache->find(activeName) == traitCache->end() || traitCache->find(inActiveName) == traitCache->end()) {
        ERROR_OUT(printf("Trait for RankSpecificTrait '%s' not found!", activeName.c_str()));
        lua_pushboolean(L, false);
        return 1;
    }

    DEBUG_OUT(printf("activeName: %s \n", activeName.c_str()));
    DEBUG_OUT(printf("inActiveName: %s \n", inActiveName.c_str()));
    DEBUG_OUT(printf("lowerRank: %i \n", lowerRank));
    DEBUG_OUT(printf("upperRank: %i \n", upperRank));

    Hooks::CLeader::RankSpecificTrait* rst = new Hooks::CLeader::RankSpecificTrait;
    rst->lowerRank = lowerRank;
    rst->upperRank = upperRank;
    rst->activeName = activeName;
    rst->activeTraitPtr = 0;
    rst->inActiveTraitPtr = 0;
    rst->inactiveName = inActiveName;

    rst->activeTraitPtr = traitCache->at(activeName);
    DEBUG_OUT(printf("rst->activeTraitPtr: %#010x \n", rst->activeTraitPtr));
    rst->inActiveTraitPtr = traitCache->at(inActiveName);
    DEBUG_OUT(printf("rst->inActiveTraitPtr: %#010x \n", rst->inActiveTraitPtr));
    
    Hooks::CLeader::rankSpecificTraitsActive->insert(std::make_pair(activeName, rst));
    Hooks::CLeader::rankSpecificTraitsInActive->insert(std::make_pair(inActiveName, rst));

    DEBUG_OUT(printf("Hooks::CLeader::rankSpecificTraitsInActive->size(): %i \n", Hooks::CLeader::rankSpecificTraitsInActive->size()));

    lua_pushboolean(L, true);
    INFO_OUT(printf("addRankSpecificTrait for: '%s' done\n", activeName.c_str()));
    DEBUG_OUT(printf("addRankSpecificTrait finished\n"));
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
    }

    cacheTraits();
    if (traitCache->size() == 0) {
        // Traits are not set up when the LUA is first run -> defer hooking until the LUA context is reloaded during save loading
        INFO_OUT(printf("Hook 'activateRankSpecificTraits' deferred until save load \n"));
        return 0;
    }

    Hooks::CLeader::isRankSpecificTraitsActive = true;
    activateRankSpecificTraitsDone = true;
    INFO_OUT(printf("Hook 'activateRankSpecificTraits' activated \n"));
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
        INFO_OUT(printf("Hook 'activateLeaderPromotionSkillLoss' deferred until save load \n"));
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
            tempSkillTraits->push_back(trait);
            Hooks::CLeader::skillTraits->push_back(trait); // also push back the Hooks::skillTraits vector so the indexes get filled
        }
    }

    for (auto& trait : *tempSkillTraits) {
        char* traitName;
        traitName = (char*)((BYTE*)trait + 0x2C);
        std::string traitNameAsString = std::string(traitName);
        auto substr = traitNameAsString.substr(7);
        auto index = std::stoi(substr, nullptr, 10);
        Hooks::CLeader::skillTraits->at(index) = (DWORD) trait;
    }

    Hooks::CLeader::isLeaderSkillLossOnPromotionActive = true;
    activateLeaderPromotionSkillLossDone = true;
    delete tempSkillTraits;
    INFO_OUT(printf("Hook 'activateLeaderPromotionSkillLoss' activated \n"));
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
        ERROR_OUT(printf("Hook 'activateLeaderListShowMaxSkill' failed \n"));
    }
    else {
        INFO_OUT(printf("Hook 'activateLeaderListShowMaxSkill' succeeded \n"));
        DEBUG_OUT(printf("jumpBack_patchLeaderListShowMaxSkill: %#010x \n", Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkill));
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
        ERROR_OUT(printf("Hook 'activateLeaderListShowMaxSkillSelected' failed \n"));
    }
    else {
        INFO_OUT(printf("Hook 'activateLeaderListShowMaxSkillSelected' succeeded \n"));
        DEBUG_OUT(printf("jumpBack_patchLeaderListShowMaxSkillSelected: %#010x \n", Hooks::CLeader::jumpBack_patchLeaderListShowMaxSkillSelected));
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
        ERROR_OUT(printf("Hook 'activateUnitAttachmentLimitHook' failed \n"));
    }
    else {
        INFO_OUT(printf("Hook 'activateUnitAttachmentLimitHook' succeeded \n"));
        DEBUG_OUT(printf("jumpBack_unitAttachmentLimitHook: %#010x \n", Hooks::CArmy::jumpBack_unitAttachmentLimitHook));
    }

    Hooks::CArmy::isUnitAttachmentLimitHookActive = true;
    return;
}

__declspec(dllexport) int setCorpsUnitLimit(lua_State* L)
{
    if (!Hooks::CArmy::isUnitAttachmentLimitHookActive) {
        activateUnitAttachmentLimitHook();
    }

    int newLimit = luaL_checkinteger(L, 1);
    std::string tag = luaL_checklstring(L, 2, NULL);

    if (tag.compare("---") == 0) {
        Hooks::CArmy::corpsUnitLimit = newLimit;
        DEBUG_OUT(printf("Corps unit limit set to: %i \n", newLimit));
    }
    else {
        auto ctr = getCountry(tag);
        if (ctr != 0) {
            int tagId = *(DWORD*)(ctr + 0x1E8);
            if (Hooks::CArmy::corpsUnitLimitPerCountry[tagId] != newLimit) {
                Hooks::CArmy::corpsUnitLimitPerCountry[tagId] = newLimit;
                DEBUG_OUT(printf("Corps unit limit set to: %i for %s \n", newLimit, tag.c_str()))
            }
        }
    }
    return 0;
}

__declspec(dllexport) int setArmyUnitLimit(lua_State* L)
{
    if (!Hooks::CArmy::isUnitAttachmentLimitHookActive) {
        activateUnitAttachmentLimitHook();
    }

    int newLimit = luaL_checkinteger(L, 1);
    std::string tag = luaL_checklstring(L, 2, NULL);
    
    if (tag.compare("---") == 0) {
        Hooks::CArmy::armyUnitLimit = newLimit;
        DEBUG_OUT(printf("Army unit limit set to: %i \n", newLimit));
    }
    else {
        auto ctr = getCountry(tag);
        if (ctr != 0) {
            int tagId = *(DWORD*)(ctr + 0x1E8);
            if (Hooks::CArmy::armyUnitLimitPerCountry[tagId] != newLimit) {
                Hooks::CArmy::armyUnitLimitPerCountry[tagId] = newLimit;
                DEBUG_OUT(printf("Army unit limit set to: %i for %s \n", newLimit, tag.c_str()));
            }
        }
    }
    return 0;
}

__declspec(dllexport) int setArmyGroupUnitLimit(lua_State* L)
{
    if (!Hooks::CArmy::isUnitAttachmentLimitHookActive) {
        activateUnitAttachmentLimitHook();
    }

    int newLimit = luaL_checkinteger(L, 1);
    std::string tag = luaL_checklstring(L, 2, NULL);

    if (tag.compare("---") == 0) {
        Hooks::CArmy::armyGroupUnitLimit = newLimit;
        DEBUG_OUT(printf("Armygroup unit limit set to: %i \n", newLimit));
    }
    else {
        auto ctr = getCountry(tag);
        if (ctr != 0) {
            int tagId = *(DWORD*)(ctr + 0x1E8);
            if (Hooks::CArmy::armyGroupUnitLimitPerCountry[tagId] != newLimit) {
                Hooks::CArmy::armyGroupUnitLimitPerCountry[tagId] = newLimit;
                DEBUG_OUT(printf("Armygroup unit limit set to: %i for %s \n", newLimit, tag.c_str()));
            }
        }
    }
    return 0;
}

__declspec(dllexport) int addCommandLimitTrait(lua_State* L)
{
    std::string traitName = luaL_checkstring(L, 1);
    int effect = luaL_checkinteger(L, 2);

    if (!Hooks::CArmy::isUnitAttachmentLimitHookActive) {
        activateUnitAttachmentLimitHook();
    }

    if (Hooks::CArmy::commandLimitTraits->find(traitName) != Hooks::CArmy::commandLimitTraits->end()) {
        DEBUG_OUT(printf("addCommandLimitTrait for: '%s' was already added \n", traitName.c_str()));
        return 0;
    }

    INFO_OUT(printf("addCommandLimitTrait: '%s' - effect: %i \n", traitName.c_str(), effect));

    Hooks::CArmy::CommandLimitTrait* clt = new Hooks::CArmy::CommandLimitTrait;
    clt->traitName = traitName;
    clt->limitEffect = effect;

    Hooks::CArmy::commandLimitTraits->insert(std::make_pair(traitName, clt));

    DEBUG_OUT(printf("Hooks::CArmy::commandLimitTraits->size(): %i \n", Hooks::CArmy::commandLimitTraits->size()));
    DEBUG_OUT(printf("addCommandLimitTrait finished \n"));
    return 0;
}


/////////////////////////////////////
//         NAVY FUNCTIONS          //
/////////////////////////////////////

void activateScreenPenaltyCalculationHook()
{
    if (Hooks::CNavy::isNavyScreenPenaltyHookActive) {
        return;
    }

    DWORD hookAddress = MODULE_BASE + 0x166560;
    Hooks::CNavy::origJmp_screenPenaltyHook = MODULE_BASE + 0x1665f6;

    if (!Hooks::hook((void*)hookAddress, Hooks::CNavy::screenPenaltyCalulation, 5, 0)) {
        ERROR_OUT(printf("Hook 'screenPenaltyCalulation' failed \n"));
    }
    else {
        INFO_OUT(printf("Hook 'screenPenaltyCalulation' succeeded \n"));
        DEBUG_OUT(printf("origJmp_screenPenaltyHook: %#010x \n", Hooks::CNavy::origJmp_screenPenaltyHook));
    }

    Hooks::CNavy::isNavyScreenPenaltyHookActive = true;
    return;
}

bool screenPenaltySet = false;
__declspec(dllexport) int setScreenPenalty(lua_State* L)
{
    if (screenPenaltySet) {
        return 0;
    }

    int screenPenalty = luaL_checkinteger(L, 1);

    if (!Hooks::CNavy::isNavyScreenPenaltyHookActive) {
        activateScreenPenaltyCalculationHook();
    }

    DEBUG_OUT(printf("Set screen penalty to %i\n", screenPenalty));
    Hooks::CNavy::screenPenalty = screenPenalty;

    screenPenaltySet = true;

    return 0;
}

bool screenRatioSet = false;
__declspec(dllexport) int setScreensPerCapitalRatio(lua_State* L)
{
    if (screenRatioSet) {
        return 0;
    }

    int ratio = luaL_checkinteger(L, 1);

    if (!Hooks::CNavy::isNavyScreenPenaltyHookActive) {
        activateScreenPenaltyCalculationHook();
    }

    DEBUG_OUT(printf("Set screen to capital ratio to %i\n", ratio));
    Hooks::CNavy::screensPerCapital = ratio;

    screenRatioSet = true;

    return 0;
}


/////////////////////////////////////
//        COMPLEX PATCHES          //
/////////////////////////////////////

BOOL fixOffMapICDone = false;
__declspec(dllexport) int fixOffMapIC(lua_State* L)
{
    if (fixOffMapICDone) {
        return 0;
    }

    DWORD hookAddress1 = MODULE_BASE + 0xf0f22;
    Hooks::Patches::jumpback_fixOffmapIc_CountLocalIc = hookAddress1 + 6;

    if (!Hooks::hook((void*)hookAddress1, Hooks::Patches::fixOffmapIc_CountLocalIc, 5, 1)) {
        ERROR_OUT(std::cout << "Hook 'fixOffmapIc_CountLocalIc' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Hook 'fixOffmapIc_CountLocalIc' succeeded" << std::endl);
        DEBUG_OUT(std::cout << "jumpback_fixOffmapIc_CountLocalIc: " << Memory::n2hexstr(Hooks::Patches::jumpback_fixOffmapIc_CountLocalIc) << std::endl);
    }

    DWORD hookAddress2 = MODULE_BASE + 0xf0f9d;
    Hooks::Patches::jumpback_fixOffmapIc_SetBaseIc = hookAddress2 + 6;

    if (!Hooks::hook((void*)hookAddress2, Hooks::Patches::fixOffmapIc_SetBaseIc, 5, 1)) {
        ERROR_OUT(std::cout << "Hook 'fixOffmapIc_SetBaseIc' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Hook 'fixOffmapIc_SetBaseIc' succeeded" << std::endl);
        DEBUG_OUT(std::cout << "jumpback_fixOffmapIc_SetBaseIc: " << Memory::n2hexstr(Hooks::Patches::jumpback_fixOffmapIc_SetBaseIc) << std::endl);
    }


    fixOffMapICDone = true;
    return 0;
}

BOOL countryHookDone = false;
__declspec(dllexport) int hookCountryConstructor(lua_State* L)
{
    if (countryHookDone) {
        return 0;
    }

    DWORD hookAddress = MODULE_BASE + 0xca653;
    Hooks::Constructors::jumpback_CCountryHook = hookAddress + 5;

    if (!Hooks::hook((void*)hookAddress, Hooks::Constructors::CCountryHook, 5, 0)) {
        ERROR_OUT(std::cout << "Hook 'hookCountryConstructor' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Hook 'hookCountryConstructor' succeeded" << std::endl);
    }

    countryHookDone = true;
    return 0;
}

bool enablePlacingNonResearchedBuildingsDone = false;
__declspec(dllexport) int enablePlacingNonResearchedBuildings(lua_State* L)
{
    if (enablePlacingNonResearchedBuildingsDone) {
        return 0;
    }

    DWORD hookAddress = MODULE_BASE + 0x17e4e5;
    Hooks::Patches::jumpback_enablePlacingNonResearchedBuildings = hookAddress + 6;
    Hooks::Patches::jumpback_enablePlacingNonResearchedBuildings_OriginalReturn = hookAddress + 210;

    if (!Hooks::hook((void*)hookAddress, Hooks::Patches::enablePlacingNonResearchedBuildings, 5, 3)) {
        ERROR_OUT(std::cout << "Hook 'enablePlacingNonResearchedBuildings' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Hook 'enablePlacingNonResearchedBuildings' succeeded" << std::endl);
        DEBUG_OUT(std::cout << "jumpback_enablePlacingNonResearchedBuildings: " << Memory::n2hexstr(Hooks::Patches::jumpback_enablePlacingNonResearchedBuildings) << std::endl);
    }

    enablePlacingNonResearchedBuildingsDone = true;
    return 0;
}


/////////////////////////////////////
//          BYTE PATCHES           //
/////////////////////////////////////


BOOL fixMinisterTechDecayDone = false;
__declspec(dllexport) int fixMinisterTechDecay(lua_State* L)
{
    if (fixMinisterTechDecayDone) {
        return 0;
    }

    if (!Patches::fixMinisterTechDecay(MODULE_BASE)) {
        ERROR_OUT(std::cout << "Patch 'fixMinisterTechDecay' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Patch 'fixMinisterTechDecay' succeeded" << std::endl);
    }


    fixMinisterTechDecayDone = true;
    return 0;
}


BOOL disableWarExhaustionNeutralityResetDone = false;
__declspec(dllexport) int disableWarExhaustionNeutralityReset(lua_State* L)
{
    if (disableWarExhaustionNeutralityResetDone) {
        return 0;
    }

    if (!Patches::disableWarExhaustionNeutralityReset(MODULE_BASE)) {
        ERROR_OUT(std::cout << "Patch 'disableWarExhaustionNeutralityReset' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Patch 'disableWarExhaustionNeutralityReset' succeeded" << std::endl);
    }

    disableWarExhaustionNeutralityResetDone = true;
    return 0;
}

bool disableInterAiExpeditionariesDone = false;
__declspec(dllexport) int disableInterAiExpeditionaries(lua_State* L)
{
    if (disableInterAiExpeditionariesDone) {
        return 0;
    }

    if (!Patches::disableInterAiExpeditionaries(MODULE_BASE)) {
        ERROR_OUT(std::cout << "Patch 'disableInterAiExpeditionaries' failed" << std::endl);
    }
    else {
        INFO_OUT(std::cout << "Patch 'disableInterAiExpeditionaries' succeeded" << std::endl);
    }

    disableInterAiExpeditionariesDone = true;
    return 0;
}
/////////////////////////////////////
//      INSPECTOR FUNCTIONS        //
/////////////////////////////////////

uintptr_t* CIngameIdlerPtr = 0;
__declspec(dllexport) int cacheIngameIdler(lua_State* L)
{
    // Find CIngameIdler
    if (CIngameIdlerPtr == 0) {
        Memory::External external = Memory::External(GetCurrentProcessId(), EXTERNAL_DEBUG);

        uintptr_t CIngameIdlerVFTable = MODULE_BASE + 0x11CEB54;
        std::string sig = Memory::ptrToSignature(CIngameIdlerVFTable);
        auto res = external.findSignatures(MODULE_BASE + DATA_SECTION_START, sig.c_str(), 4, 99);
        DEBUG_OUT(printf("res->size(): %i \n", res->size()));
        if (res->size() != 0) {
            CIngameIdlerPtr = (uintptr_t*)res->at(res->size() - 1);
            DEBUG_OUT(printf("CIngameIdlerPtr set to: %#010x \n", (uintptr_t)CIngameIdlerPtr));
            delete res;
        }
    }
}

__declspec(dllexport) int getSelectedEntity(lua_State* L)
{
    cacheIngameIdler(L);

    // Find CTerrains to get indices for each units CUnitAdjusterArray
    if (CTerrain::Terrains->size() == 0) {
        Memory::External external = Memory::External(GetCurrentProcessId(), EXTERNAL_DEBUG);
        CTerrain::CacheTerrains(external);
    }


    if (CIngameIdlerPtr != 0 && CTerrain::Terrains->size() != 0) {
        lua_newtable(L); // Create the table which will hold the selected items
        uintptr_t selectedThingsListStartPtr = *(CIngameIdlerPtr + (0x1304 / 4));
        uintptr_t selectedThingsListEndPtr = *(CIngameIdlerPtr + (0x1308 / 4));
        int8_t amountOfSelectedThings = *(CIngameIdlerPtr + (0x1308 / 4 + 1));
        DEBUG_OUT(printf("selectedThingsListStartPtr: %#010x \n", selectedThingsListStartPtr));
        DEBUG_OUT(printf("selectedThingsListEndPtr: %#010x \n", selectedThingsListEndPtr));
        DEBUG_OUT(printf("amountOfSelectedThings: %i \n", amountOfSelectedThings));

        HDS::LinkedListNodeSingle* currentNode = (HDS::LinkedListNodeSingle*)selectedThingsListStartPtr;

        int i = 1; // Index for our table. Remember LUA starts at 1
        while (currentNode != 0) {
            uintptr_t CArmyVFTABLE = MODULE_BASE + 0x11BDE0C;
            uintptr_t CNavyVFTABLE = MODULE_BASE + 0x11C869C;
            uintptr_t CAirVFTABLE = MODULE_BASE + 0x011C8774;
            uintptr_t CMapProvinceVFTABLE = MODULE_BASE + 0x11BEC1C;

            // DEBUG_OUT(printf("currentNode->data: %#010x \n", currentNode->data));
            uintptr_t entityType = *((uintptr_t*)currentNode->data);
            lua_pushinteger(L, i);
            lua_newtable(L); // Create the table for the item
            if (entityType == CArmyVFTABLE) {
                DEBUG_OUT(printf("CArmy \n"));
                lua_pushstring(L, "type");
                lua_pushstring(L, "Army");
                lua_settable(L, -3);
                CUnit::pushCUnitToStack(L, currentNode->data);
                CSubUnitDefinition::pushCSubUnitDefinitionToStack(L, currentNode->data);
            } else if (entityType == CNavyVFTABLE) {
                DEBUG_OUT(printf("CNavy \n"));
                lua_pushstring(L, "type");
                lua_pushstring(L, "Navy");
                lua_settable(L, -3);
                CUnit::pushCUnitToStack(L, currentNode->data);
                CSubUnitDefinition::pushCSubUnitDefinitionToStack(L, currentNode->data);
            } else if (entityType == CAirVFTABLE) {
                DEBUG_OUT(printf("CAir \n"));
                lua_pushstring(L, "type");
                lua_pushstring(L, "Air");
                lua_settable(L, -3);
                CUnit::pushCUnitToStack(L, currentNode->data);
                CSubUnitDefinition::pushCSubUnitDefinitionToStack(L, currentNode->data);
            } else if (entityType == CMapProvinceVFTABLE) {
                DEBUG_OUT(printf("CMapProvince \n"));
                lua_pushstring(L, "type");
                lua_pushstring(L, "Province");
                lua_settable(L, -3);
                // CUnit::pushCUnitToStack(L, currentNode->data);
            } else {
                DEBUG_OUT(printf("Unknown Type \n"));
                lua_pushstring(L, "type");
                lua_pushstring(L, "Unknown");
                lua_settable(L, -3);
            }
            currentNode = currentNode->next;
            i++;
            lua_settable(L, -3);
        }
    }
    else {
        lua_pushnil(L);
    }

    return 1;
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
__declspec(dllexport) int stopConsole(lua_State* L)
{
    if (!consoleStarted) {
        return 0;
    }
    printf("\nConsole has been detached! You can now close the console window.\n");
    FreeConsole();

    consoleStarted = false;
    return 0;
}

#include <chrono>
#include <thread>
bool periodicsJobStarted = false;
DWORD WINAPI periodicsJob(void* data) {
    if (periodicsJobStarted) {
        return 0;
    }
    periodicsJobStarted = true;
    DEBUG_OUT(printf("periodicsJob started\n"));
    while (true) {
        DEBUG_OUT(printf("periodicsJob loop\n"));
        cacheCountries(LUA_STATE);
        if (cacheCountriesDone) {
            lua_getglobal(LUA_STATE, "CheckOobUnitLimitTechnologyStatus");
            lua_pcall(LUA_STATE, 0, 0, 0);
        }

        std::this_thread::sleep_for(std::chrono::seconds(60));
    }
    return 0;
}

__declspec(dllexport) luaL_Reg BiceLib[] = {
    // Misc
    {"startConsole", startConsole},
    {"stopConsole", stopConsole},
    {"setModuleBase", setModuleBase},
    {"cacheCountries", cacheCountries},
    {"cacheIngameIdler", cacheIngameIdler},
    {"hookCountryConstructor", hookCountryConstructor},
    {NULL, NULL}
};

void registerFunction(lua_State* this_state, const char* name, lua_CFunction function) {
    lua_pushstring(this_state, name);
    lua_pushcfunction(this_state, function);
    lua_settable(this_state, -3);
    return;
}

void registerGameInfoFunctions(lua_State* this_state) {
    lua_pushstring(this_state, "GameInfo");
    lua_newtable(this_state);
    registerFunction(this_state, "getProvinceDetails", getProvinceDetails);
    registerFunction(this_state, "getCountryFlags", getCountryFlags);
    registerFunction(this_state, "getCountryVariables", getCountryVariables);
    registerFunction(this_state, "getCountryOffmapIc", getCountryOffmapIc);
    registerFunction(this_state, "getCountryActiveEventModifiers", getCountryActiveEventModifiers);
    lua_settable(this_state, -3);
    return;
}

void registerLeaderFunctions(lua_State* this_state) {
    lua_pushstring(this_state, "Leaders");
    lua_newtable(this_state);
    registerFunction(this_state, "addRankSpecificTrait", addRankSpecificTrait);
    registerFunction(this_state, "activateRankSpecificTraits", activateRankSpecificTraits);
    registerFunction(this_state, "checkRankSpecificTraitsConsistency", checkRankSpecificTraitsConsistency);
    // registerFunction(this_state, "activateLeaderPromotionSkillLoss", activateLeaderPromotionSkillLoss);
    registerFunction(this_state, "activateLeaderListShowMaxSkill", activateLeaderListShowMaxSkill);
    registerFunction(this_state, "activateLeaderListShowMaxSkillSelected", activateLeaderListShowMaxSkillSelected);
    registerFunction(this_state, "addTraitToLeader", addTraitToLeader);
    registerFunction(this_state, "getLeaderDetails", getLeaderDetails);
    lua_settable(this_state, -3);
    return;
}

void registerUnitFunctions(lua_State* this_state) {
    lua_pushstring(this_state, "Units");
    lua_newtable(this_state);
    registerFunction(this_state, "setCorpsUnitLimit", setCorpsUnitLimit);
    registerFunction(this_state, "setArmyUnitLimit", setArmyUnitLimit);
    registerFunction(this_state, "setArmyGroupUnitLimit", setArmyGroupUnitLimit);
    registerFunction(this_state, "addCommandLimitTrait", addCommandLimitTrait);
    lua_settable(this_state, -3);
    return;
}

void registerNavyFunctions(lua_State* this_state) {
    lua_pushstring(this_state, "Navy");
    lua_newtable(this_state);
    registerFunction(this_state, "setScreenPenalty", setScreenPenalty);
    registerFunction(this_state, "setScreensPerCapitalRatio", setScreensPerCapitalRatio);
    lua_settable(this_state, -3);
    return;
}

void registerPatchFunctions(lua_State* this_state) {
    lua_pushstring(this_state, "BytePatches");
    lua_newtable(this_state);
    registerFunction(this_state, "fixMinisterTechDecay", fixMinisterTechDecay);
    registerFunction(this_state, "disableWarExhaustionNeutralityReset", disableWarExhaustionNeutralityReset);
    registerFunction(this_state, "disableInterAiExpeditionaries", disableInterAiExpeditionaries);
    lua_settable(this_state, -3);
    return;
}

void registerComplexPatchFunctions(lua_State* this_state) {
    lua_pushstring(this_state, "ComplexPatches");
    lua_newtable(this_state);
    registerFunction(this_state, "fixOffMapIC", fixOffMapIC);
    registerFunction(this_state, "enablePlacingNonResearchedBuildings", enablePlacingNonResearchedBuildings);
    lua_settable(this_state, -3);
    return;
}

void registerInspectorFunctions(lua_State* this_state) {
    lua_pushstring(this_state, "Inspector");
    lua_newtable(this_state);
    registerFunction(this_state, "getSelectedEntity", getSelectedEntity);
    lua_settable(this_state, -3);
    return;
}

extern "C"
__declspec(dllexport) int luaopen_BiceLib(lua_State* this_state)
{
    if (LUA_STATE == nullptr) {
        // Set main lua state
        LUA_STATE = this_state;
        utils::LUA_STATE = this_state;
    }
    DEBUG_OUT(printf("this_state: %#010x\n", (uintptr_t)this_state));
    LUA_STATES->push_back(this_state);
    DEBUG_OUT(printf("LUA_STATES: %i\n", LUA_STATES->size()));

    lua_newtable(this_state);
    luaL_register(this_state, "BiceLib", BiceLib);
    registerGameInfoFunctions(this_state);
    registerLeaderFunctions(this_state);
    registerUnitFunctions(this_state);
    registerNavyFunctions(this_state);
    registerPatchFunctions(this_state);
    registerComplexPatchFunctions(this_state);
    registerInspectorFunctions(this_state);

    utils::logInLua(this_state,"Loaded BiceLib");
    char buf[100];
    snprintf(buf, 100, "LUA_STATES: %i", LUA_STATES->size());
    utils::logInLua(this_state, buf);
    return 1;
}
