function BiceLibLuaLog(toLog)
    local f = io.open("lua_output.txt", "a")
    if f ~= nil then
        f:write("BiceLib: '" .. toLog .. "' \n")
        f:close()
    end
end
function ResetBiceLibLuaLog()
    local f = io.open("lua_output.txt", "a")
    if f ~= nil then
        f:write("")
        f:close()
    end
end

local ok, mod = pcall(require, "BiceLib")
if not ok then
    Utils.LUA_DEBUGOUT("Failed to load BiceLib.dll. Some features are not available")
    Utils.LUA_DEBUGOUT(mod)
    mod = nil
end
if mod then
    BiceLib = mod
    -- BiceLib.startConsole() -- Creates a console for debug information
    BiceLib.setModuleBase()
    BiceLib.cacheCountries()
    BiceLib.hookCountryConstructor()

    -- Leaders
    -- BiceLib.Leaders.activateLeaderPromotionSkillLoss()
    BiceLib.Leaders.activateLeaderListShowMaxSkill()
    BiceLib.Leaders.activateLeaderListShowMaxSkillSelected()

    -- Rank Specific traits
    -- BiceLib.Leaders.activateRankSpecificTraits()
    -- BiceLib.Leaders.addRankSpecificTrait("rankSpecificTrait_test_active", "rankSpecificTrait_test_inactive", 2, 4)
    -- BiceLib.Leaders.checkRankSpecificTraitsConsistency()

    -- Units
    BiceLib.Units.setCorpsUnitLimit(4, "---")
    BiceLib.Units.setArmyUnitLimit(4, "---")
    BiceLib.Units.setArmyGroupUnitLimit(4, "---")
    -- BiceLib.Units.setArmyGroupUnitLimit(10, "GER")
    -- BiceLib.Units.addCommandLimitTrait("pskill_1", -1)
    -- BiceLib.Units.addCommandLimitTrait("pskill_4", 1)

    -- Navy
    -- BiceLib.Navy.setScreenPenalty(500)
    -- BiceLib.Navy.setScreensPerCapitalRatio(2)

    -- Byte Patches
    BiceLib.BytePatches.fixMinisterTechDecay()
    BiceLib.BytePatches.disableWarExhaustionNeutralityReset()
    BiceLib.BytePatches.disableInterAiExpeditionaries()

    -- Complex Patches
    BiceLib.ComplexPatches.fixOffMapIC()
    BiceLib.ComplexPatches.enablePlacingNonResearchedBuildings()
end

function HasLoadedBiceLibSuccessfully()
    if ok then
        return true
    end
    return false
end

function RunBiceLibPeriodicsManually()
    if BiceLib ~= nil then
        BiceLib.cacheCountries()
		CheckOobUnitLimitTechnologyStatus(true)
    end
end

function MultiplayerBiceLibJob()
    local playerTag = CCurrentGameState.GetPlayer()
    Utils.LUA_DEBUGOUT("MultiplayerBiceLibJob: " .. tostring(playerTag))
    if HasLoadedBiceLibSuccessfully() then
        Utils.LUA_DEBUGOUT("HasLoadedBiceLibSuccessfully(): " .. tostring(playerTag))
        RunBiceLibPeriodicsManually()

        local command = CSetVariableCommand(playerTag, CString("ran_bicelib_periodics_manually"), CFixedPoint(1))
        CCurrentGameState.Post(command)
        local command = CSetVariableCommand(playerTag, CString("failed_to_load_bicelib"), CFixedPoint(0))
        CCurrentGameState.Post(command)
    else
        local command = CSetVariableCommand(playerTag, CString("failed_to_load_bicelib"), CFixedPoint(1))
        CCurrentGameState.Post(command)
        local command = CSetVariableCommand(playerTag, CString("ran_bicelib_periodics_manually"), CFixedPoint(0))
        CCurrentGameState.Post(command)
    end
end


-- Sets the variable which will trigger the OMG decision for the periodic event to tell the player to press the "Refresh Values" button
-- After that the triggers for the decision are handled entirely in decisons/events scripts
function MultiplayerBiceLibCheckInitialSetup()
    Utils.LUA_DEBUGOUT("MultiplayerBiceLibCheckInitialSetup")
    if #G_PlayerCountries > 1 then
        Utils.LUA_DEBUGOUT("#G_PlayerCountries > 1")
        local omgTag = CCountryDataBase.GetTag("OMG")
        local command = CSetVariableCommand(omgTag, CString("needs_to_run_multiplayer_bicelib_check"), CFixedPoint(1))
        CCurrentGameState.Post(command)
    end
end
