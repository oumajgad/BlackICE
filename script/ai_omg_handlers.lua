function IntelligenceMinisterUtilityThings()
	-- local tOmg = os.clock()
	-- Utils.LUA_DEBUGOUT('OMG var handler start')

	if G_UtilityEnabled ~= true then
		return
	end

	-- One time setup stuff for the GUI
	if SaveLoaded ~= true then
		-- Utils.LUA_DEBUGOUT("SAVELOADED")
		SaveLoaded = true
		G_DaysSinceLastUpdate = 0
		DeterminePlayers()
		-- DetermineExePatchStatus()
		DetermineSpriteDeletionStatus()
		DetermineBiceLibLoadStatus()
		Stats.SetUpStatCollectionPage()
		RunBiceLibPeriodicsManually()
		MultiplayerBiceLibCheckInitialSetup()
	end

	-- t = os.clock()
	GuiRefreshLoop()
	-- Utils.LUA_DEBUGOUT(os.clock() - t .. " - GuiRefreshLoop")

	-- Utils.LUA_DEBUGOUT("Day: " .. CCurrentGameState.GetCurrentDate():GetDayOfMonth() .. " OMG var handler time: " .. string.format("%.04f", os.clock() - tOmg))

end

function OMGMinisterHandler(minister_tick, minister)
	-- local tOmg = os.clock()
	-- Utils.LUA_DEBUGOUT("OMGHandler '" .. minister_tick .. "' start")
	for index, func in ipairs(G_LUA_SCHEDULE[minister_tick]) do
		-- local t = nil
		-- t = os.clock()
		---@diagnostic disable-next-line:redundant-parameter
		func(minister)
		-- Utils.LUA_DEBUGOUT("  " .. index .. " - " .. os.clock() - t)
	end
	-- Utils.LUA_DEBUGOUT(
		-- "Day: " .. CCurrentGameState.GetCurrentDate():GetDayOfMonth() .. " OMGHandler '" .. minister_tick .. "' time: "
		-- .. string.format("%.04f", os.clock() - tOmg))
end

-- Holds which scripts run in which minister_tick
G_LUA_SCHEDULE = {
	-- 01:00
	["IntelligenceMinister_Tick"] = {
		IntelligenceMinisterUtilityThings,
		-- CalculateLogisticsNeed
		-- CalculateHeavyIcEffect,
		CheckForIntraFactionMilitaryAccess,
		CheckOobUnitLimitTechnologyStatus,
	},
	-- 03:00
	["TechMinister_Tick"] = {
		BuildingsCount,
		BaseICbyMinister,
		GreaterEastAsiaCoProsperitySphere,
		RandomNumberGenerator,
		PuppetMoneyAndFuelCheck,
	},
	-- 05:00
	["ProductionMinister_Tick"] = {
		ControlledMinesCheck,
		ResourceCount,
		StratResourceBalance,
		RealStratResourceBalance,
	},
	-- 13:00
	["ForeignMinister_Tick"] = {
		CheckCountryWantsToChangeCustomTradeAi,
		CountryModifiers,
		ICDaysSpentCalculation,
		CalculateMinisters,
	},
	-- 17:00
	["PoliticsMinister_Tick"] = {
		Stats.CollectPlayerStatistics,
		InitTradingData,
		CheckPendingTrades,
		CheckExpiredTrades,
		CheckTradeBuySellConsistency,
		CalculateFocuses,
	},
}
