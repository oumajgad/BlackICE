function BiceLibLuaLog(toLog)
    local f = io.open("lua_output.txt", "a")
    if f ~= nil then
        f:write("BiceLib: '" .. toLog .. "' \n")
        f:close()
    end
end
function ResetBiceLibLuaLog()
    local f = io.open("lua_output.txt", "w")
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

    -- Leaders
    -- BiceLib.Leaders.activateLeaderPromotionSkillLoss()
    BiceLib.Leaders.activateLeaderListShowMaxSkill()
    BiceLib.Leaders.activateLeaderListShowMaxSkillSelected()

    -- Rank Specific traits
    -- BiceLib.Leaders.activateRankSpecificTraits()
    -- BiceLib.Leaders.addRankSpecificTrait("rankSpecificTrait_test_active", "rankSpecificTrait_test_inactive", 2, 4)
    -- BiceLib.Leaders.checkRankSpecificTraitsConsistency()

    -- Units
    BiceLib.Units.setCorpsUnitLimit(G_BASE_COC_LIMIT, "---")
    BiceLib.Units.setArmyUnitLimit(G_BASE_COC_LIMIT, "---")
    BiceLib.Units.setArmyGroupUnitLimit(G_BASE_COC_LIMIT, "---")
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
    BiceLib.BytePatches.historicalModelLogicFix()
    BiceLib.BytePatches.seaTerrainColourInSimplifiedMapMode()

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
		CheckOobUnitLimitTechnologyStatus(true)
    end
end

-- Called by BiceLib.dll itself once a game day, in every game of a session - in
-- multiplayer the clients too, which run none of the scheduled scripts. The checks keep
-- their own days, so a client changes its values on the same days the host does.
-- firstDay is 1 on the first day after a load, which sets everything up at once.
-- Answers what it did, which BiceLib prints to its console.
function BiceLibDailyPeriodics(firstDay)
    local report = {
        bicelib_loaded = BiceLib ~= nil,
        first_day = firstDay == 1,
        day_of_month = CCurrentGameState.GetCurrentDate():GetDayOfMonth(),
    }
    -- The same day rule CheckOobUnitLimitTechnologyStatus applies to itself, for the report
    report.oob_limits_checked = report.bicelib_loaded
        and (report.first_day or report.day_of_month % 5 == 0)

    if report.bicelib_loaded then
        CheckOobUnitLimitTechnologyStatus(report.first_day)
    end
    return report
end
