function IntelligenceMinisterUtilityThings()
	-- local tOmg = os.clock()
	-- Utils.LUA_DEBUGOUT('OMG var handler start')


	-- One time setup stuff for the GUI
	if SaveLoaded ~= true then
		-- Utils.LUA_DEBUGOUT("SAVELOADED")
		SaveLoaded = true
		DaysSinceLastUpdate = 0
		DeterminePlayers()
		DetermineExePatchStatus()
		DetermineSpriteDeletionStatus()
		SetUpStatCollectionPage()
	end

	-- t = os.clock()
	GuiRefreshLoop()
	-- Utils.LUA_DEBUGOUT(os.clock() - t .. " - GuiRefreshLoop")

	-- Utils.LUA_DEBUGOUT("Day: " .. CCurrentGameState.GetCurrentDate():GetDayOfMonth() .. " OMG var handler time: " .. string.format("%.04f", os.clock() - tOmg))

end

function OMGHandlerIntelligenceMinister(minister)
	local tOmg = os.clock()
	-- Utils.LUA_DEBUGOUT("OMGHandler 'IntelligenceMinister_Tick' start")
	for index, func in ipairs(G_LUA_SCHEDULE["IntelligenceMinister_Tick"]) do
		-- local t = nil
		-- t = os.clock()
		func(minister)
		-- Utils.LUA_DEBUGOUT(os.clock() - t .. " - " .. index)
	end
	-- Utils.LUA_DEBUGOUT(
	-- 	"Day: " .. CCurrentGameState.GetCurrentDate():GetDayOfMonth() .. " OMGHandler 'IntelligenceMinister_Tick' time: "
	-- 	.. string.format("%.04f", os.clock() - tOmg))
end

function OMGHandlerForeignMinister(minister)
	local tOmg = os.clock()
	-- Utils.LUA_DEBUGOUT("OMGHandler 'ForeignMinister_Tick' start")
	for index, func in ipairs(G_LUA_SCHEDULE["ForeignMinister_Tick"]) do
		-- local t = nil
		-- t = os.clock()
		func(minister)
		-- Utils.LUA_DEBUGOUT(os.clock() - t .. " - " .. index)
	end
	-- Utils.LUA_DEBUGOUT(
	-- 	"Day: " .. CCurrentGameState.GetCurrentDate():GetDayOfMonth() .. " OMGHandler 'ForeignMinister_Tick' time: "
	-- 	.. string.format("%.04f", os.clock() - tOmg))
end

function OMGHandlerPoliticsMinister(minister)
	local tOmg = os.clock()
	-- Utils.LUA_DEBUGOUT("OMGHandler 'PoliticsMinister_Tick' start")
	for index, func in ipairs(G_LUA_SCHEDULE["PoliticsMinister_Tick"]) do
		-- local t = nil
		-- t = os.clock()
		func(minister)
		-- Utils.LUA_DEBUGOUT(os.clock() - t .. " - " .. index)
	end
	-- Utils.LUA_DEBUGOUT(
	-- 	"Day: " .. CCurrentGameState.GetCurrentDate():GetDayOfMonth() .. " OMGHandler 'PoliticsMinister_Tick' time: "
	-- 	.. string.format("%.04f", os.clock() - tOmg))
end

function OMGHandlerProductionMinister(minister)
	local tOmg = os.clock()
	-- Utils.LUA_DEBUGOUT("OMGHandler 'ProductionMinister_Tick' start")
	for index, func in ipairs(G_LUA_SCHEDULE["ProductionMinister_Tick"]) do
		-- local t = nil
		-- t = os.clock()
		func(minister)
		-- Utils.LUA_DEBUGOUT(os.clock() - t .. " - " .. index)
	end
	-- Utils.LUA_DEBUGOUT(
	-- 	"Day: " .. CCurrentGameState.GetCurrentDate():GetDayOfMonth() .. " OMGHandler 'ProductionMinister_Tick' time: "
	-- 	.. string.format("%.04f", os.clock() - tOmg))
end

function OMGHandlerTechMinister(minister)
	local tOmg = os.clock()
	-- Utils.LUA_DEBUGOUT("OMGHandler 'TechMinister_Tick' start")
	for index, func in ipairs(G_LUA_SCHEDULE["TechMinister_Tick"]) do
		-- local t = nil
		-- t = os.clock()
		func(minister)
		-- Utils.LUA_DEBUGOUT(os.clock() - t .. " - " .. index)
	end
	-- Utils.LUA_DEBUGOUT(
	-- 	"Day: " .. CCurrentGameState.GetCurrentDate():GetDayOfMonth() .. " OMGHandler 'TechMinister_Tick' time: "
	-- 	.. string.format("%.04f", os.clock() - tOmg))
end

-- Holds which scripts run in which minister_tick
G_LUA_SCHEDULE = {
	-- 01:00
	["IntelligenceMinister_Tick"] = {
		CountryIterCache,
		IntelligenceMinisterUtilityThings,
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
		CheckNegativeTradeCounts,
		CalculateFocuses,
	},
}
