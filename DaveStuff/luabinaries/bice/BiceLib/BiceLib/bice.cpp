#include <lua.hpp>
#include <MemScan.hpp> // pulls in Windows.h, which has to precede processthreadsapi.h

#include <string>
#include <iostream>
#include <processthreadsapi.h>
#include <vector>

#include <utils.hpp>
#include <Diagnostics.hpp>
#include <CrashReport.hpp>
#include <Overlay.hpp>
#include <HoiDataStructures.hpp>
#include <Patches.hpp>

#include <Commands/BiceCommandExample.hpp>
#include <Commands/CBiceCommands.hpp>
#include <GameClasses/CCountry.hpp>
#include <GameClasses/CCountryTag.hpp>
#include <GameClasses/CTrait.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/CSubUnitDefinition.hpp>
#include <GameClasses/CTerrain.hpp>
#include <GameClasses/CMapProvince.hpp>
#include <GameClasses/CCurrentGameState.hpp>
#include <GameClasses/CLeader.hpp>
#include <GameClasses/CInGameIdler.hpp>
#include <GameClasses/GameMessage.hpp>
#include <GameClasses/CCountryDataBase.hpp>
#include <GameState/AutoSave.hpp>
#include <GameState/EventCandidates.hpp>
#include <GameState/MapEdgeScroll.hpp>
#include <GameState/PureCall.hpp>
#include <Gui/LuaBridge.hpp>
#include <Hooks/Hooks.hpp>
#include <Hooks/EffectText/KillLeaderText.hpp>
#include <Hooks/EffectText/LoadOobText.hpp>
#include <Hooks/HistoryLeaderRanks.hpp>
#include <Hooks/LeaderListSkill.hpp>
#include <Hooks/MaxInfrastructure.hpp>
#include <Hooks/NavyScreenPenalty.hpp>
#include <Hooks/OffmapIc.hpp>
#include <Hooks/OobLeaderRanks.hpp>
#include <Hooks/PlaceUnresearchedBuildings.hpp>
#include <Hooks/QueuedHistoricalModel.hpp>
#include <Hooks/RankSpecificTraits.hpp>
#include <Hooks/ResourceConversion.hpp>
#include <Hooks/Tooltips/CombatUnitStats.hpp>
#include <Hooks/Tooltips/ManpowerText.hpp>
#include <Hooks/TriggerText/TriggerIndentText.hpp>
#include <Hooks/TriggerText/TriggerScrollText.hpp>
#include <Hooks/UnassignSelected.hpp>
#include <Hooks/UnitAttachmentLimit.hpp>
#include <Reversing/Counters.hpp>
#include <Reversing/MessageProbe.hpp>
#include <Reversing/Watch.hpp>
#include <Reversing/WriteWatch.hpp>
#include <Settings.hpp>

// Every Lua state that has loaded BiceLib; the overlay's memory page reads it
std::vector<lua_State*> *LUA_STATES = new std::vector<lua_State*>;

namespace {
    /**
    @brief what every switch below does with the outcome: says so, and hands Lua a boolean

    @param status why it failed, from the feature's own status(); not printed on success
    */
    int reportInstall(lua_State* L, const char* name, bool ok, const char* status) {
        if (ok) {
            INFO_OUT(printf("'%s' succeeded \n", name));
        }
        else {
            ERROR_OUT(printf("'%s' failed: %s \n", name, status != nullptr ? status : "?"));
        }
        lua_pushboolean(L, ok);
        return 1;
    }

    /**@brief the same for a byte patch, which says what went wrong itself*/
    int reportPatch(lua_State* L, const char* name, bool (*patch)(uintptr_t)) {
        return reportInstall(L, name, patch(Hooks::MODULE_BASE), "see the line above");
    }

    /**@brief the country named by the tag at \p index, or 0*/
    uintptr_t countryArg(lua_State* L, int index) {
        return CCountry::findByTag(luaL_checkstring(L, index));
    }
}

/////////////////////////////////////
//       GAME INFO FUNCTIONS       //
/////////////////////////////////////

// Countries come from the game state, which is the game's own list - CCountry::all().

__declspec(dllexport) int getProvinceDetails(lua_State* L)
{
    Diagnostics::LuaScope luaScope(L);
    const int provinceId = static_cast<int>(luaL_checkinteger(L, 1));

    // Nil for an id the map does not have, which the one caller -
    // BiceData.ProvinceBuildings.Details - already reports as "no details"
    if (CCurrentGameState::province(provinceId) == 0) {
        lua_pushnil(L);
        return 1;
    }
    CMapProvince::PushCMapProvinceToStack(L, CMapProvince::GetMapProvinceById(provinceId));
    return 1;
}

__declspec(dllexport) int getCountryActiveEventModifiers(lua_State* L)
{
    const uintptr_t country = countryArg(L, 1);
    if (country == 0) {
        lua_pushnil(L);
        return 1;
    }
    const auto modifiers = CCountry::getActiveEventModifiers(country);
    lua_createtable(L, 0, static_cast<int>(modifiers.size()));
    for (const auto& modifier : modifiers) {
        lua_pushstring(L, modifier.second.c_str());
        lua_setfield(L, -2, modifier.first.c_str());
    }
    return 1;
}

__declspec(dllexport) int getCountryGeneralModifiers(lua_State* L)
{
    const uintptr_t country = countryArg(L, 1);
    if (country == 0) {
        lua_pushnil(L);
        return 1;
    }
    const auto values = CCountry::getGeneralModifiers(country);
    lua_createtable(L, 0, static_cast<int>(values.size()));
    for (const auto& value : values) {
        lua_pushnumber(L, value.second);
        lua_setfield(L, -2, value.first.c_str());
    }
    return 1;
}

__declspec(dllexport) int getCountryFlags(lua_State* L)
{
    const uintptr_t country = countryArg(L, 1);
    if (country == 0) {
        lua_pushnil(L);
        return 1;
    }
    const auto flags = CCountry::getFlags(country);
    lua_createtable(L, static_cast<int>(flags.size()), 0);
    for (size_t i = 0; i < flags.size(); i++) {
        lua_pushstring(L, flags[i].c_str());
        lua_rawseti(L, -2, static_cast<int>(i + 1));
    }
    return 1;
}

__declspec(dllexport) int getCountryVariables(lua_State* L)
{
    const uintptr_t country = countryArg(L, 1);
    if (country == 0) {
        lua_pushnil(L);
        return 1;
    }
    const auto variables = CCountry::getVars(country);
    lua_createtable(L, 0, static_cast<int>(variables.size()));
    for (const auto& variable : variables) {
        lua_pushinteger(L, variable.value);
        lua_setfield(L, -2, variable.name.c_str());
    }
    return 1;
}

/**@brief the offmap IC the last daily pass worked out for the country; see Hooks/OffmapIc.hpp*/
__declspec(dllexport) int getCountryOffmapIc(lua_State* L)
{
    const uintptr_t country = countryArg(L, 1);
    if (country == 0) {
        lua_pushnil(L);
        return 1;
    }
    lua_pushinteger(L, Hooks::OffmapIc::offmapIc(country));
    return 1;
}

/**
 * What a country may convert today under customResourceConversion, in stockpile units:
 * `oil_rate` the crude oil one energy makes, `energy_cap` the energy it may spend,
 * `energy_floor` what industry needs and is never converted, `crude_cap` the crude oil it
 * may refine, `played` whether its own settings apply. nil when the patch is not on or
 * the tag names nothing. See Hooks/ResourceConversion.hpp.
 */
__declspec(dllexport) int getCountryResourceConversion(lua_State* L)
{
    Hooks::ResourceConversion::Capacity capacity;
    if (!Hooks::ResourceConversion::capacity(countryArg(L, 1), capacity)) {
        lua_pushnil(L);
        return 1;
    }
    lua_createtable(L, 0, 5);
    lua_pushnumber(L, static_cast<lua_Number>(capacity.oilRate) / 1000.0);
    lua_setfield(L, -2, "oil_rate");
    lua_pushnumber(L, static_cast<lua_Number>(capacity.energyCap) / 1000.0);
    lua_setfield(L, -2, "energy_cap");
    lua_pushnumber(L, static_cast<lua_Number>(capacity.energyFloor) / 1000.0);
    lua_setfield(L, -2, "energy_floor");
    lua_pushnumber(L, static_cast<lua_Number>(capacity.crudeCap) / 1000.0);
    lua_setfield(L, -2, "crude_cap");
    lua_pushboolean(L, capacity.played);
    lua_setfield(L, -2, "played");
    return 1;
}


/////////////////////////////////////
//        LEADER FUNCTIONS         //
/////////////////////////////////////
// Traits come from the game's own list - CTrait::all() and CTrait::findByName(). It is
// empty until the mod's traits are loaded, which is what the deferrals are waiting for.

__declspec(dllexport) int getLeaderDetails(lua_State* L) {
    Diagnostics::LuaScope luaScope(L);
    const unsigned int leaderId = static_cast<unsigned int>(luaL_checkinteger(L, 1));
    const CLeader::CLeader leader = CLeader::GetLeaderById(leaderId);
    if (leader._address == 0) {
        lua_pushnil(L);
        return 1;
    }
    CLeader::PushCLeaderToStack(L, leader);
    return 1;
}

/**@brief `addTraitToLeader(leaderId, traitName)`, through the game's own CLeader::AddTrait*/
__declspec(dllexport) int addTraitToLeader(lua_State* L) {
    const unsigned int leaderId = static_cast<unsigned int>(luaL_checkinteger(L, 1));
    const std::string traitName = luaL_checkstring(L, 2);

    const CLeader::CLeader leader = CLeader::GetLeaderById(leaderId);
    const uintptr_t trait = CTrait::findByName(traitName);
    if (leader._address == 0) {
        ERROR_OUT(printf("addTraitToLeader: no leader with id %u\n", leaderId));
        lua_pushboolean(L, false);
        return 1;
    }
    if (trait == 0) {
        ERROR_OUT(printf("addTraitToLeader: no trait called '%s'\n", traitName.c_str()));
        lua_pushboolean(L, false);
        return 1;
    }

    typedef void(__stdcall* AddTrait)(uintptr_t leader, uintptr_t trait);
    reinterpret_cast<AddTrait>(Hooks::MODULE_BASE + CLeader::GameFunction::AddTrait)(
        leader._address, trait);
    lua_pushboolean(L, true);
    return 1;
}

/**
 * `addRankSpecificTrait(activeName, inactiveName, lowestRank, highestRank)` declares a pair;
 * false until the traits are loaded, which a later Lua state answers. See
 * Hooks/RankSpecificTraits.hpp.
 */
__declspec(dllexport) int addRankSpecificTrait(lua_State* L) {
    const std::string activeName = luaL_checkstring(L, 1);
    const std::string inactiveName = luaL_checkstring(L, 2);
    const int lowestRank = static_cast<int>(luaL_checkinteger(L, 3));
    const int highestRank = static_cast<int>(luaL_checkinteger(L, 4));
    lua_pushboolean(L, Hooks::RankSpecificTraits::add(activeName, inactiveName, lowestRank, highestRank));
    return 1;
}

/**@brief installs the two hooks and starts swapping once the traits are loaded*/
__declspec(dllexport) int activateRankSpecificTraits(lua_State* L)
{
    if (!Hooks::RankSpecificTraits::install()) {
        return reportInstall(L, "activateRankSpecificTraits", false,
            Hooks::RankSpecificTraits::status());
    }
    lua_pushboolean(L, Hooks::RankSpecificTraits::activate());
    return 1;
}

/**@brief swaps every leader's pair to match his rank now*/
__declspec(dllexport) int checkRankSpecificTraitsConsistency(lua_State* L)
{
    Hooks::RankSpecificTraits::checkAllLeaders();
    return 0;
}

/**
 * Shows a leader's maximum skill beside his skill in the leader window, in the list and for
 * the selected leader. Either name installs both; see Hooks/LeaderListSkill.hpp.
 */
__declspec(dllexport) int activateLeaderListShowMaxSkill(lua_State* L)
{
    return reportInstall(L, "activateLeaderListShowMaxSkill",
        Hooks::LeaderListSkill::install(), Hooks::LeaderListSkill::status());
}

__declspec(dllexport) int activateLeaderListShowMaxSkillSelected(lua_State* L)
{
    return activateLeaderListShowMaxSkill(L);
}

/**
 * Makes holding Ctrl while confirming `CONFIRM_REMOVEAll` - the "unassign all leaders"
 * dialog - unassign only the leaders of the units that are currently selected.
 *
 * With Ctrl up the dialog does exactly what it always did. The hook sits on the skip
 * test the game's own unassign loop already makes per unit, so an unselected unit is
 * passed over by the same path that passes over a unit on loan to another country. See
 * Hooks/UnassignSelected.hpp.
 */
__declspec(dllexport) int activateCtrlUnassignSelected(lua_State* L)
{
    const bool ok = Hooks::UnassignSelected::install();
    if (ok) {
        Hooks::UnassignSelected::setActive(true);
    }
    return reportInstall(L, "activateCtrlUnassignSelected", ok, Hooks::UnassignSelected::status());
}

/**
 * Gives a leader an order of battle puts on a land unit the rank the game itself would
 * want for that unit - division 1, corps 2, army 3, army group and theatre 4 - raising or
 * lowering him, and puts him in service if he is not yet. Only while an order of battle
 * file is read (`load_oob`, a new game's history, the custom game setup), never a save;
 * another country's leader is left alone. See Hooks/OobLeaderRanks.hpp.
 */
__declspec(dllexport) int activateOobLeaderRanks(lua_State* L)
{
    return reportInstall(L, "activateOobLeaderRanks",
        Hooks::OobLeaderRanks::install(), Hooks::OobLeaderRanks::status());
}

/**
 * Brings a leader whose history dates his first rank after the start into service at the
 * rank that line names, where the game gives rank 1 whatever it says. One store in the
 * daily pass. See Hooks/HistoryLeaderRanks.hpp.
 */
__declspec(dllexport) int activateHistoryLeaderRanks(lua_State* L)
{
    return reportInstall(L, "activateHistoryLeaderRanks",
        Hooks::HistoryLeaderRanks::install(), Hooks::HistoryLeaderRanks::status());
}

/////////////////////////////////////
//          UNIT FUNCTIONS         //
/////////////////////////////////////

namespace {
    /**
    @brief `set*UnitLimit(limit, tag)`: the default with the tag `---`, a country's own
           otherwise; installs the hook on first use. See Hooks/UnitAttachmentLimit.hpp
    */
    int setUnitLimit(lua_State* L, Hooks::UnitAttachmentLimit::Level level) {
        if (!Hooks::UnitAttachmentLimit::install()) {
            return reportInstall(L, "UnitAttachmentLimit", false, Hooks::UnitAttachmentLimit::status());
        }
        const int limit = static_cast<int>(luaL_checkinteger(L, 1));
        const std::string tag = luaL_checkstring(L, 2);
        if (tag == "---") {
            Hooks::UnitAttachmentLimit::setDefault(level, limit);
            return 0;
        }
        const uintptr_t country = CCountry::findByTag(tag);
        if (country != 0) {
            Hooks::UnitAttachmentLimit::setForCountry(level,
                Mem::readOr<int32_t>(country + CCountry::Offsets::tag + CCountryTag::Offsets::id, -1),
                limit);
        }
        return 0;
    }
}

__declspec(dllexport) int setCorpsUnitLimit(lua_State* L)
{
    return setUnitLimit(L, Hooks::UnitAttachmentLimit::Level::Corps);
}

__declspec(dllexport) int setArmyUnitLimit(lua_State* L)
{
    return setUnitLimit(L, Hooks::UnitAttachmentLimit::Level::Army);
}

__declspec(dllexport) int setArmyGroupUnitLimit(lua_State* L)
{
    return setUnitLimit(L, Hooks::UnitAttachmentLimit::Level::ArmyGroup);
}

/**@brief `addCommandLimitTrait(traitName, effect)`: what a leader with it adds to the limit*/
__declspec(dllexport) int addCommandLimitTrait(lua_State* L)
{
    const std::string traitName = luaL_checkstring(L, 1);
    const int effect = static_cast<int>(luaL_checkinteger(L, 2));
    if (!Hooks::UnitAttachmentLimit::install()) {
        return reportInstall(L, "UnitAttachmentLimit", false, Hooks::UnitAttachmentLimit::status());
    }
    Hooks::UnitAttachmentLimit::addCommandLimitTrait(traitName, effect);
    return 0;
}


/////////////////////////////////////
//         NAVY FUNCTIONS          //
/////////////////////////////////////
// See Hooks/NavyScreenPenalty.hpp. Each figure is set once; later calls are ignored.

__declspec(dllexport) int setScreenPenalty(lua_State* L)
{
    const int penalty = static_cast<int>(luaL_checkinteger(L, 1));
    if (!Hooks::NavyScreenPenalty::install()) {
        return reportInstall(L, "setScreenPenalty", false, Hooks::NavyScreenPenalty::status());
    }
    Hooks::NavyScreenPenalty::setPenalty(penalty);
    return 0;
}

__declspec(dllexport) int setScreensPerCapitalRatio(lua_State* L)
{
    const int ratio = static_cast<int>(luaL_checkinteger(L, 1));
    if (!Hooks::NavyScreenPenalty::install()) {
        return reportInstall(L, "setScreensPerCapitalRatio", false, Hooks::NavyScreenPenalty::status());
    }
    Hooks::NavyScreenPenalty::setScreensPerCapital(ratio);
    return 0;
}


/////////////////////////////////////
//        COMPLEX PATCHES          //
/////////////////////////////////////

/**@brief counts offmap IC once, whatever local_ic does; see Hooks/OffmapIc.hpp*/
__declspec(dllexport) int fixOffMapIC(lua_State* L)
{
    return reportInstall(L, "fixOffMapIC", Hooks::OffmapIc::install(), Hooks::OffmapIc::status());
}

/**@brief lets a building be placed up to its max_level unresearched; see
   Hooks/PlaceUnresearchedBuildings.hpp, which says what else it skips*/
__declspec(dllexport) int enablePlacingNonResearchedBuildings(lua_State* L)
{
    return reportInstall(L, "enablePlacingNonResearchedBuildings",
        Hooks::PlaceUnresearchedBuildings::install(), Hooks::PlaceUnresearchedBuildings::status());
}

/**@brief a queued brigade's historical_model gets a level for every technology; see
   Hooks/QueuedHistoricalModel.hpp*/
__declspec(dllexport) int fixQueuedHistoricalModel(lua_State* L)
{
    return reportInstall(L, "fixQueuedHistoricalModel",
        Hooks::QueuedHistoricalModel::install(), Hooks::QueuedHistoricalModel::status());
}

/**
 * Keeps a province's MaxInfrastructure the figure of its `infra` building. The game writes
 * the figure of whichever building with the `infrastructure` effect it handles last, so
 * BlackICE's `extra_infra` left ~1,600 provinces in no area after every load and crashed
 * the AI's sealift pass. Three stores, each followed by infra's own figure. Must be on
 * before a save is loaded. See Hooks/MaxInfrastructure.hpp.
 */
__declspec(dllexport) int fixMaxInfrastructure(lua_State* L)
{
    return reportInstall(L, "fixMaxInfrastructure",
        Hooks::MaxInfrastructure::install(), Hooks::MaxInfrastructure::status());
}

/**
 * Lets a played country set its own daily conversion of energy into crude oil and of
 * crude oil into fuel, through `zzDsafe_` country variables an event, a decision or the
 * overlay sets; capped at the game's own capacity, and energy never taken below what
 * industry needs. A country nobody plays converts as the game does. See
 * Hooks/ResourceConversion.hpp.
 */
__declspec(dllexport) int customResourceConversion(lua_State* L)
{
    return reportInstall(L, "customResourceConversion",
        Hooks::ResourceConversion::install(), Hooks::ResourceConversion::status());
}


/////////////////////////////////////
//          BYTE PATCHES           //
/////////////////////////////////////
// Each checks every byte it changes first and is safe to call again; see Patches.hpp.

__declspec(dllexport) int fixMinisterTechDecay(lua_State* L)
{
    return reportPatch(L, "fixMinisterTechDecay", &Patches::fixMinisterTechDecay);
}

__declspec(dllexport) int disableWarExhaustionNeutralityReset(lua_State* L)
{
    return reportPatch(L, "disableWarExhaustionNeutralityReset",
        &Patches::disableWarExhaustionNeutralityReset);
}

__declspec(dllexport) int disableInterAiExpeditionaries(lua_State* L)
{
    return reportPatch(L, "disableInterAiExpeditionaries", &Patches::disableInterAiExpeditionaries);
}

__declspec(dllexport) int historicalModelLogicFix(lua_State* L)
{
    return reportPatch(L, "historicalModelLogicFix", &Patches::historicalModelLogicFix);
}

__declspec(dllexport) int seaTerrainColourInSimplifiedMapMode(lua_State* L)
{
    return reportPatch(L, "seaTerrainColourInSimplifiedMapMode",
        &Patches::seaTerrainColourInSimplifiedMapMode);
}


/////////////////////////////////////
//     EFFECT TEXT FUNCTIONS      //
/////////////////////////////////////

/**
 * Adds `$UNIT$`, `$LOCATION$` and `$WHERE$` to what the `kill_leader` effect shows, so
 * `KILL_LEADER_EFFECT` can say which unit the leader commands and where it is.
 *
 * Switched on from Lua rather than at startup because it is a change to what the game
 * displays, like every other hook here - and because the localisation has to ask for
 * the variables before any of it shows. See Hooks/EffectText/KillLeaderText.hpp.
 */
__declspec(dllexport) int activateKillLeaderVariables(lua_State* L)
{
    return reportInstall(L, "activateKillLeaderVariables",
        Hooks::EffectText::KillLeader::install(), Hooks::EffectText::KillLeader::status());
}

/**
 * Replaces what `load_oob` shows - a file path and nothing else - with what the file
 * would actually do: how many units appear and where, what they are made of, and which
 * leaders it takes, with what each of those commands now.
 *
 * The file is read off disk, because nothing about it is in memory until the effect
 * fires. See Hooks/EffectText/LoadOobText.hpp and GameState/OobFile.hpp.
 */
__declspec(dllexport) int activateLoadOobDetails(lua_State* L)
{
    return reportInstall(L, "activateLoadOobDetails",
        Hooks::EffectText::LoadOob::install(), Hooks::EffectText::LoadOob::status());
}

/**
 * Indents what is inside an `and` or an `or` in a requirement tooltip.
 *
 * The game renders a requirement tree one line per trigger, three spaces per level, and
 * both container triggers pass a constant for their children instead of their own depth
 * plus one - so a condition inside an `and` or an `or` is drawn flush left whatever it
 * is nested in. See Hooks/TriggerText/TriggerIndentText.hpp.
 */
__declspec(dllexport) int activateTriggerIndent(lua_State* L)
{
    return reportInstall(L, "activateTriggerIndent",
        Hooks::TriggerText::TriggerIndent::install(), Hooks::TriggerText::TriggerIndent::status());
}

/**
 * Lets a requirement tooltip too tall for the screen be scrolled with Alt and the
 * arrow keys.
 *
 * Nothing about the tooltip window is touched: the text itself is shortened from the
 * front, which works because the game rebuilds it continuously while it is hovered.
 * See Hooks/TriggerText/TriggerScrollText.hpp.
 */
__declspec(dllexport) int activateTriggerScroll(lua_State* L)
{
    return reportInstall(L, "activateTriggerScroll",
        Hooks::TriggerText::TriggerScroll::install(), Hooks::TriggerText::TriggerScroll::status());
}

/////////////////////////////////////
//      REVERSING FUNCTIONS        //
/////////////////////////////////////

/**
 * Counts how often the game reaches each address named in BiceLibCounters.txt, and
 * writes the totals to BiceLibCounters.csv once a game day.
 *
 * A workbench tool for reverse engineering: the disassembly says what code would do,
 * not whether the game ever goes there. Without the file this does nothing and says so.
 * See Reversing/Counters.hpp for the file's shape and for the two checks that have to be
 * made outside the game first.
 */
__declspec(dllexport) int activateCounters(lua_State* L)
{
    const bool ok = Reversing::Counters::install();
    if (ok) {
        INFO_OUT(printf("'activateCounters': %s \n", Reversing::Counters::status()));
        lua_pushboolean(L, ok);
        return 1;
    }
    return reportInstall(L, "activateCounters", ok, Reversing::Counters::status());
}

/**
 * Traps writes to the combat modifier list of the unit the last battle tooltip was about,
 * and reports which instruction made them.
 *
 * For a field nothing in the image appears to store to - `CUnit + 0xDC` is reached by a
 * pointer computed somewhere a byte search cannot follow. Have a combat running, hover a
 * unit in it, then call this and let the combat tick. See Reversing/WriteWatch.hpp.
 */
__declspec(dllexport) int watchCombatModifiers(lua_State* L)
{
    const uintptr_t offset = lua_gettop(L) >= 1
        ? static_cast<uintptr_t>(lua_tonumber(L, 1)) : 0xDC;
    const bool ok = Reversing::WriteWatch::armCombatModifiers(offset);
    if (!ok) {
        ERROR_OUT(printf("'watchCombatModifiers' failed: %s \n", Reversing::WriteWatch::status()));
    }
    lua_pushboolean(L, ok);
    return 1;
}

/**
 * Traps writes to a field of the first subunit of the unit the last battle tooltip was
 * about - `watchSubunit(offset)`, defaulting to 0xAC.
 *
 * For a pending total whose consumer cannot be found by reading: whatever spends one has
 * to clear it, and that clear is a write. See Reversing/WriteWatch.hpp.
 */
__declspec(dllexport) int watchSubunit(lua_State* L)
{
    const uintptr_t offset = lua_gettop(L) >= 1
        ? static_cast<uintptr_t>(lua_tonumber(L, 1)) : 0xAC;
    const bool ok = Reversing::WriteWatch::armSubunit(offset);
    if (!ok) {
        ERROR_OUT(printf("'watchSubunit' failed: %s \n", Reversing::WriteWatch::status()));
    }
    lua_pushboolean(L, ok);
    return 1;
}

/**@brief the same watch on any address: watchWrite(address, size), size 1, 2 or 4*/
__declspec(dllexport) int watchWrite(lua_State* L)
{
    const uintptr_t address = static_cast<uintptr_t>(lua_tonumber(L, 1));
    const int size = lua_gettop(L) >= 2 ? static_cast<int>(lua_tonumber(L, 2)) : 4;
    const bool ok = Reversing::WriteWatch::arm(address, size, "address");
    if (!ok) {
        ERROR_OUT(printf("'watchWrite' failed: %s \n", Reversing::WriteWatch::status()));
    }
    lua_pushboolean(L, ok);
    return 1;
}

/**@brief clears the watch and writes what it saw to BiceLibWrites.csv*/
__declspec(dllexport) int stopWatching(lua_State* L)
{
    Reversing::WriteWatch::disarm();
    INFO_OUT(printf("WriteWatch: disarmed \n"));
    lua_pushboolean(L, 1);
    return 1;
}

/**
 * Records what the game state fields named in BiceLibWatch.txt hold, writing a row to
 * BiceLibWatch.csv whenever one of them changes.
 *
 * Hooks nothing: it reads through CCurrentGameState::current() once a frame and refuses
 * an offset outside the object, so a wrong line in the file costs a wrong number in a
 * csv rather than the game. See Reversing/Watch.hpp.
 */
__declspec(dllexport) int activateWatch(lua_State* L)
{
    const bool ok = Reversing::Watch::install();
    if (ok) {
        INFO_OUT(printf("'activateWatch': %s \n", Reversing::Watch::status()));
        lua_pushboolean(L, ok);
        return 1;
    }
    return reportInstall(L, "activateWatch", ok, Reversing::Watch::status());
}

/////////////////////////////////////
//       TOOLTIP FUNCTIONS         //
/////////////////////////////////////

/**
 * Splits the manpower tooltip's "needs X manpower to reinforce" into land, air and
 * naval, and offers each as a variable `MANPOWER_DETAILS_IRO` can place.
 *
 * The three are taken from the one instruction that builds the total, so they add up to
 * it rather than merely ought to. Nothing shows until the localisation asks for
 * `$LAND$`, `$AIR$` and `$NAVY$`. See Hooks/Tooltips/ManpowerText.hpp.
 */
__declspec(dllexport) int activateManpowerBreakdown(lua_State* L)
{
    return reportInstall(L, "activateManpowerBreakdown",
        Hooks::Tooltips::Manpower::install(), Hooks::Tooltips::Manpower::status());
}

/**
 * @brief offers a battle tooltip the stats its percentages are percentages of
 *
 * The modifier list a unit shows in a battle says `Attack Modifier: 44.70%` and never
 * what of. This adds `$SOFTATTACK$`, `$HARDATTACK$`, `$PIERCING$`, `$DEFENSIVENESS$`,
 * `$TOUGHNESS$`, `$ARMOR$` and `$AIRATTACK$` to `BATTLE_ATTACKMOD`, totalled over the
 * division's brigades from each one's own definition - which already has its technology
 * in it. Nothing shows until the localisation asks. See Hooks/Tooltips/CombatUnitStats.hpp.
 */
__declspec(dllexport) int activateCombatUnitStats(lua_State* L)
{
    return reportInstall(L, "activateCombatUnitStats",
        Hooks::Tooltips::CombatUnitStats::install(), Hooks::Tooltips::CombatUnitStats::status());
}

/////////////////////////////////////
//        MESSAGE FUNCTIONS        //
/////////////////////////////////////

/**
 * **The type a caller's own text is shown through.** Declared in
 * `interface/messagetypes.txt` and written in `localisation/BiceLib_messages.csv`, where its
 * lines are nothing but `$HEADER$`, `$TEXT$`, `$TEXT2$` and `$TEXT3$` - a message's text
 * comes from the localisation for its type, so the only way to show arbitrary text is to
 * make the type's text a set of variables and fill them here.
 *
 * All four are always set, empty where the caller left them out: a variable the text
 * mentions and nothing supplies has never been tested, and an empty line is a known
 * quantity.
 */
static const char* const FREE_TEXT_TYPE = "BICE_MESSAGE";
static const char* const DEFAULT_HEADER = "BlackICE reports that";

/**
 * `Messages.show(text, header, provinceId, line2, line3)` puts a popup in front of the
 * player with that text. Only `text` is needed: the header defaults, the province defaults
 * to the player's capital (CCountry::capitalLocation), and the two extra lines to nothing.
 *
 * **Queued, not raised**, so it works from anywhere - the utility's GUI, the Lua console, an
 * event effect, a tick hook. A message raised directly from inside the overlay's Present
 * hook comes up as an empty window; see GameClasses/GameMessage.hpp.
 */
__declspec(dllexport) int showMessage(lua_State* L)
{
    const char* const text = (lua_gettop(L) > 0 && lua_isstring(L, 1))
        ? lua_tostring(L, 1) : "";
    if (*text == '\0') {
        ERROR_OUT(printf("'Messages.show' needs some text \n"));
        lua_pushboolean(L, 0);
        return 1;
    }
    const char* const header = (lua_gettop(L) > 1 && lua_isstring(L, 2))
        ? lua_tostring(L, 2) : DEFAULT_HEADER;
    const int provinceId = lua_gettop(L) > 2 ? static_cast<int>(lua_tointeger(L, 3)) : 0;
    const char* const line2 = (lua_gettop(L) > 3 && lua_isstring(L, 4))
        ? lua_tostring(L, 4) : "";
    const char* const line3 = (lua_gettop(L) > 4 && lua_isstring(L, 5))
        ? lua_tostring(L, 5) : "";

    const uintptr_t country = Game::playerCountry();
    if (country == 0) {
        ERROR_OUT(printf("'Messages.show' needs a running game \n"));
        lua_pushboolean(L, 0);
        return 1;
    }

    const uintptr_t province = (provinceId > 0)
        ? CCurrentGameState::province(provinceId)
        : CCountry::capitalLocation(country);

    Game::Message message(FREE_TEXT_TYPE);
    message.with("HEADER", header);
    message.with("TEXT", text);
    message.with("TEXT2", line2);
    message.with("TEXT3", line3);
    const bool ok = message.queue(country, province);
    if (!ok) {
        ERROR_OUT(printf("'Messages.show' failed: %s \n", Game::Message::status()));
    }
    lua_pushboolean(L, ok ? 1 : 0);
    return 1;
}

/**
 * @brief prints the arguments of the next few messages the game posts
 *
 * For comparing a message raised by hand against one the game raised itself, which is
 * the only way to tell which field of a 0x78 byte object passed by value is wrong. Arm
 * it, let a division shatter, raise one with `Messages.show`, and diff the two frames.
 * It stands on the popup's text builder as well as on the post, so it also says whether
 * a popup was filled in at all. See Reversing/MessageProbe.hpp.
 */
__declspec(dllexport) int probeMessages(lua_State* L)
{
    const bool on = lua_gettop(L) < 1 || lua_toboolean(L, 1) != 0;
    if (!on) {
        Reversing::MessageProbe::disarm();
        INFO_OUT(printf("'probeMessages' off \n"));
        lua_pushboolean(L, 1);
        return 1;
    }
    const bool ok = Reversing::MessageProbe::arm();
    if (!ok) {
        ERROR_OUT(printf("'probeMessages' failed: %s \n", Reversing::MessageProbe::status()));
    }
    lua_pushboolean(L, ok);
    return 1;
}


/////////////////////////////////////
//      INSPECTOR FUNCTIONS        //
/////////////////////////////////////

// The in game screen is read from the game state through CInGameIdler::current(), not
// cached: the object belongs to the session.

__declspec(dllexport) int getSelectedEntity(lua_State* L)
{
    Diagnostics::LuaScope luaScope(L);
    const uintptr_t idler = CInGameIdler::current();

    // Each unit's terrain stats are indexed by the terrains, which the map holds
    CTerrain::CacheTerrains();
    if (idler == 0 || CTerrain::Terrains.empty()) {
        lua_pushnil(L);
        return 1;
    }

    const uintptr_t base = Hooks::MODULE_BASE;
    const uintptr_t army = base + CUnit::VFTable::CArmy;
    const uintptr_t navy = base + CUnit::VFTable::CNavy;
    const uintptr_t air = base + CUnit::VFTable::CAir;
    const uintptr_t province = base + CMapProvince::VFTable::CMapProvince;

    lua_newtable(L);
    int index = 1;
    for (uintptr_t entity : HDS::walkList(idler + CInGameIdler::Offsets::selection)) {
        const uintptr_t vftable = Mem::readOr<uint32_t>(entity);
        const char* type = "Unknown";
        bool isUnit = false;
        if (vftable == army) {
            type = "Army";
            isUnit = true;
        }
        else if (vftable == navy) {
            type = "Navy";
            isUnit = true;
        }
        else if (vftable == air) {
            type = "Air";
            isUnit = true;
        }
        else if (vftable == province) {
            type = "Province";
        }

        lua_newtable(L);
        lua_pushstring(L, type);
        lua_setfield(L, -2, "type");
        if (isUnit) {
            CUnit::pushCUnitToStack(L, entity);
            CSubUnitDefinition::pushCSubUnitDefinitionToStack(L, entity);
        }
        lua_rawseti(L, -2, index++);
    }
    return 1;
}

/////////////////////////////////////
//         MISC FUNCTIONS          //
/////////////////////////////////////

/**
 * Prints the module base. It used to set it, and every hook depended on this being called
 * first; Hooks::MODULE_BASE is now set as the DLL loads. Kept so a script that still calls
 * it keeps working.
 */
__declspec(dllexport) int setModuleBase(lua_State* L)
{
    INFO_OUT(std::cout << "MODULE_BASE at: " << Mem::toHex(Hooks::MODULE_BASE) << std::endl);
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

    // Selecting text in the console freezes everything writing to it until the selection
    // is cleared, so quick edit is switched off
    HANDLE handle = GetStdHandle(STD_INPUT_HANDLE);
    SetConsoleMode(handle, ENABLE_EXTENDED_FLAGS);

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

/////////////////////////////////////
//        OVERLAY FUNCTIONS        //
/////////////////////////////////////

__declspec(dllexport) int enableOverlay(lua_State* L)
{
    // Both of these go in before the overlay, so a crash while installing it is
    // still caught. A pure virtual call aborts the process where it stands, so the
    // handler has to be in place before anything that could raise one - and unlike
    // the out of memory watch, which is a poll and lives in the frame loop, this is
    // installed once and then works on any thread whether frames are running or not.
    // Nothing is patched; see GameState/PureCall.hpp.
    CrashReport::install();
    PureCall::install();

    const bool ok = Overlay::install();
    if (!ok) {
        ERROR_OUT(printf("Could not install the ImGui overlay\n"));
    }

    // Features that keep a setting have to be back in place whether or not their
    // page is ever opened, so they are asked for here rather than on a first draw.
    AutoSave::restore();
    MapEdgeScroll::restore();

    lua_pushboolean(L, ok);
    return 1;
}

__declspec(dllexport) int toggleOverlay(lua_State* L)
{
    Overlay::toggle();
    lua_pushboolean(L, Overlay::isVisible());
    return 1;
}

/////////////////////////////////////
//        COMMAND FUNCTIONS        //
/////////////////////////////////////

/**
 * Puts the one BiceCommand prototype in the game's persistent registry, and declares the
 * kinds that ride on it.
 *
 * **Call this before posting, in single player as much as in multiplayer, and as early as you
 * like - it needs no game session.** The single player post serialises the command and
 * rebuilds it through the registry, so an unregistered type id is not a harmless no-op: the
 * factory answers nothing and the post carries on regardless. And because the receive path
 * drops a command whose id is not registered yet, every moment before this runs is a window
 * in which a peer's command is silently ignored here.
 *
 * Registering a *kind* is the framework's own, token-free namespace - see
 * Commands/CBiceCommands.hpp for why there is one game-level command class and a payload
 * rather than one class per action.
 *
 * "Cannot reach Lua: no game session" from the overlay console is that console's gate, not
 * this refusing; it has a "Needs a session" checkbox.
 */
__declspec(dllexport) int registerBiceCommands(lua_State* L)
{
    if (!CBiceCommands::Register()) {
        return reportInstall(L, "registerBiceCommands", false, CBiceCommands::status());
    }
    // The framework knows nothing about kinds until something declares one. The example
    // is a kind like any other, which is the point of it.
    return reportInstall(L, "registerBiceCommands", BiceCommandExample::install(),
        "the example kind did not register");
}

/**
 * Posts one of the **example** "ping" commands, carrying whatever numbers are handed to it.
 *
 * What comes back out of the channel is executed on **every** machine in the game, through the
 * same ordered pump every other command goes through. In single player the object that runs is
 * the factory's clone of the registered prototype rather than the one posted, so an Execute
 * line at all means the whole round trip is sound - and the arguments coming back unchanged
 * means the payload survived it.
 *
 * Takes a **table** of numbers, so a caller is not boxed into a fixed arity: `{}` or no
 * argument posts none, `{1, -2, 3}` posts three. Up to CBiceCommands::MAX_ARGS.
 *
 * A non-number in the table is refused rather than coerced. A silent 0 would be a different
 * command from the one that was asked for, and it would be that different command on every
 * machine at once.
 */
__declspec(dllexport) int postExampleCommand(lua_State* L)
{
    int32_t args[CBiceCommands::MAX_ARGS] = {};
    int count = 0;

    if (!lua_isnoneornil(L, 1)) {
        if (!lua_istable(L, 1)) {
            ERROR_OUT(printf("'postExampleCommand' wants a table of numbers\n"));
            lua_pushboolean(L, false);
            return 1;
        }
        // Lua 5.1, arrays from 1 - the same walk Gui/LuaBridge.cpp makes.
        const int length = static_cast<int>(lua_objlen(L, 1));
        if (length > CBiceCommands::MAX_ARGS) {
            ERROR_OUT(printf("'postExampleCommand': %d arguments, %d is the limit\n",
                length, CBiceCommands::MAX_ARGS));
            lua_pushboolean(L, false);
            return 1;
        }
        for (int i = 1; i <= length; i++) {
            lua_rawgeti(L, 1, i);
            if (!lua_isnumber(L, -1)) {
                ERROR_OUT(printf("'postExampleCommand': entry %d is not a number\n", i));
                lua_pop(L, 1);
                lua_pushboolean(L, false);
                return 1;
            }
            args[count++] = static_cast<int32_t>(lua_tonumber(L, -1));
            lua_pop(L, 1);
        }
    }

    lua_pushboolean(L, BiceCommandExample::post(count > 0 ? args : nullptr, count));
    return 1;
}

/////////////////////////////////////
//         EVENT FUNCTIONS         //
/////////////////////////////////////

__declspec(dllexport) int rebuildEventCandidates(lua_State* L)
{
    lua_pushboolean(L, EventCandidates::rebuildNow() ? 1 : 0);
    return 1;
}

/////////////////////////////////////
//          REGISTRATION           //
/////////////////////////////////////

__declspec(dllexport) luaL_Reg BiceLib[] = {
    {"startConsole", startConsole},
    {"stopConsole", stopConsole},
    {"setModuleBase", setModuleBase},
    {NULL, NULL}
};

namespace {
    struct Function
    {
        const char* name;
        lua_CFunction function;
    };

    /**@brief `BiceLib.<table>` holding \p functions, on the module table at the top*/
    template <size_t N>
    void registerTable(lua_State* L, const char* table, const Function (&functions)[N]) {
        lua_createtable(L, 0, static_cast<int>(N));
        for (const Function& entry : functions) {
            lua_pushcfunction(L, entry.function);
            lua_setfield(L, -2, entry.name);
        }
        lua_setfield(L, -2, table);
    }

    const Function GAME_INFO[] = {
        {"getProvinceDetails", getProvinceDetails},
        {"getCountryFlags", getCountryFlags},
        {"getCountryVariables", getCountryVariables},
        {"getCountryOffmapIc", getCountryOffmapIc},
        {"getCountryResourceConversion", getCountryResourceConversion},
        {"getCountryActiveEventModifiers", getCountryActiveEventModifiers},
        {"getCountryGeneralModifiers", getCountryGeneralModifiers},
    };

    const Function LEADERS[] = {
        {"addRankSpecificTrait", addRankSpecificTrait},
        {"activateRankSpecificTraits", activateRankSpecificTraits},
        {"checkRankSpecificTraitsConsistency", checkRankSpecificTraitsConsistency},
        {"activateLeaderListShowMaxSkill", activateLeaderListShowMaxSkill},
        {"activateLeaderListShowMaxSkillSelected", activateLeaderListShowMaxSkillSelected},
        {"activateCtrlUnassignSelected", activateCtrlUnassignSelected},
        {"activateOobLeaderRanks", activateOobLeaderRanks},
        {"activateHistoryLeaderRanks", activateHistoryLeaderRanks},
        {"addTraitToLeader", addTraitToLeader},
        {"getLeaderDetails", getLeaderDetails},
    };

    const Function UNITS[] = {
        {"setCorpsUnitLimit", setCorpsUnitLimit},
        {"setArmyUnitLimit", setArmyUnitLimit},
        {"setArmyGroupUnitLimit", setArmyGroupUnitLimit},
        {"addCommandLimitTrait", addCommandLimitTrait},
    };

    const Function NAVY[] = {
        {"setScreenPenalty", setScreenPenalty},
        {"setScreensPerCapitalRatio", setScreensPerCapitalRatio},
    };

    const Function BYTE_PATCHES[] = {
        {"fixMinisterTechDecay", fixMinisterTechDecay},
        {"disableWarExhaustionNeutralityReset", disableWarExhaustionNeutralityReset},
        {"disableInterAiExpeditionaries", disableInterAiExpeditionaries},
        {"historicalModelLogicFix", historicalModelLogicFix},
        {"seaTerrainColourInSimplifiedMapMode", seaTerrainColourInSimplifiedMapMode},
    };

    const Function COMPLEX_PATCHES[] = {
        {"fixOffMapIC", fixOffMapIC},
        {"enablePlacingNonResearchedBuildings", enablePlacingNonResearchedBuildings},
        {"fixQueuedHistoricalModel", fixQueuedHistoricalModel},
        {"fixMaxInfrastructure", fixMaxInfrastructure},
        {"customResourceConversion", customResourceConversion},
    };

    const Function EVENTS[] = {
        {"rebuildCandidates", rebuildEventCandidates},
    };

    const Function EFFECT_TEXTS[] = {
        {"activateKillLeaderVariables", activateKillLeaderVariables},
        {"activateLoadOobDetails", activateLoadOobDetails},
        {"activateTriggerIndent", activateTriggerIndent},
        {"activateTriggerScroll", activateTriggerScroll},
    };

    const Function TOOLTIPS[] = {
        {"activateManpowerBreakdown", activateManpowerBreakdown},
        {"activateCombatUnitStats", activateCombatUnitStats},
    };

    const Function MESSAGES[] = {
        {"show", showMessage},
    };

    const Function REVERSING[] = {
        {"activateCounters", activateCounters},
        {"watchCombatModifiers", watchCombatModifiers},
        {"watchSubunit", watchSubunit},
        {"watchWrite", watchWrite},
        {"stopWatching", stopWatching},
        {"activateWatch", activateWatch},
        {"probeMessages", probeMessages},
    };

    const Function COMMANDS[] = {
        {"registerBiceCommands", registerBiceCommands},
        {"postExampleCommand", postExampleCommand},
    };

    const Function INSPECTOR[] = {
        {"getSelectedEntity", getSelectedEntity},
    };

    const Function OVERLAY[] = {
        {"enable", enableOverlay},
        {"toggle", toggleOverlay},
    };
}

extern "C"
__declspec(dllexport) int luaopen_BiceLib(lua_State* this_state)
{
    Diagnostics::LuaScope luaScope(this_state);
    DEBUG_OUT(printf("this_state: %#010x\n", (uintptr_t)this_state));
    LUA_STATES->push_back(this_state);

    // Leaves the module table on top, which is what require hands back
    luaL_register(this_state, "BiceLib", BiceLib);
    const int moduleTop = lua_gettop(this_state);

    registerTable(this_state, "GameInfo", GAME_INFO);
    registerTable(this_state, "Leaders", LEADERS);
    registerTable(this_state, "Units", UNITS);
    registerTable(this_state, "Navy", NAVY);
    registerTable(this_state, "BytePatches", BYTE_PATCHES);
    registerTable(this_state, "ComplexPatches", COMPLEX_PATCHES);
    registerTable(this_state, "Events", EVENTS);
    registerTable(this_state, "EffectTexts", EFFECT_TEXTS);
    registerTable(this_state, "Tooltips", TOOLTIPS);
    registerTable(this_state, "Messages", MESSAGES);
    registerTable(this_state, "Reversing", REVERSING);
    registerTable(this_state, "Commands", COMMANDS);
    registerTable(this_state, "Inspector", INSPECTOR);
    registerTable(this_state, "Overlay", OVERLAY);

    utils::logInLua(this_state, "Loaded BiceLib");
    char buf[100];
    snprintf(buf, sizeof(buf), "LUA_STATES: %u", static_cast<unsigned>(LUA_STATES->size()));
    utils::logInLua(this_state, buf);

    // Whatever else happened, the module is what is returned
    lua_settop(this_state, moduleTop);
    return 1;
}
