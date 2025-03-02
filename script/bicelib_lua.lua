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

    -- Leaders
    -- BiceLib.Leaders.activateLeaderPromotionSkillLoss()
    BiceLib.Leaders.activateLeaderListShowMaxSkill()
    BiceLib.Leaders.activateLeaderListShowMaxSkillSelected()

    -- Rank Specific traits
    BiceLib.Leaders.activateRankSpecificTraits()
    BiceLib.Leaders.addRankSpecificTrait("rankSpecificTrait_test_active", "rankSpecificTrait_test_inactive", 2, 4)
    BiceLib.Leaders.checkRankSpecificTraitsConsistency()

    -- Units
    -- BiceLib.Units.setCorpsUnitLimit(6, false)
    -- BiceLib.Units.setArmyUnitLimit(7, false)
    -- BiceLib.Units.setArmyGroupUnitLimit(8, false)
    -- BiceLib.Units.addCommandLimitTrait("pskill_1", -1)
    -- BiceLib.Units.addCommandLimitTrait("pskill_4", 1)

    -- Byte Patches
    BiceLib.BytePatches.fixMinisterTechDecay()
    BiceLib.BytePatches.disableWarExhaustionNeutralityReset()
    BiceLib.BytePatches.disableInterAiExpeditionaries()

    -- Complex Patches
    BiceLib.ComplexPatches.fixOffMapIC()
    BiceLib.ComplexPatches.enablePlacingNonResearchedBuildings()
end
