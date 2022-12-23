
function GuiRefreshLoop(skipInterval)
    DaysSinceLastUpdate = DaysSinceLastUpdate + 1
    if wx ~= nil and PlayerCountry ~= nil and (skipInterval == true or DaysSinceLastUpdate >= UpdateInterval) then
        DaysSinceLastUpdate = 0
        GetAndAddPuppets()
        GetPlayerModifiers()
        GetStratResourceValues()
        SetICDaysLeftText()
        DetermineICInvestmentValue()
        GetAndSetResourceSaleStates()
        GetNatFocusDays()
        GetMinisterBuildingsProgress()
        FillTradesGrid()
    end
end

-- Function to check if a player has disabled the hosts ability to check out his country during a MP game
-- will return false if disabled
function CheckPlayerAllowsSelection(player)
    local playerCountry = CCountryDataBase.GetTag(player)
    if playerCountry:GetCountry():GetVariables():GetVariable(CString("disable_gui_access")):Get() == 1 then
        PlayerCountry = nil
        return false
    end

    return true
end

-- Called from button press
function UpdateDailyCountsTextCtrl()
    UI.m_textCtrlDailyCount:SetValue(tostring(DateOverride))
end

-- Called from button press
function SetNatFocus(focus)
    if PlayerCountry ~= nil then
        local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
        local command = CSetVariableCommand(playerCountryTag, CString("national_focus"), CFixedPoint(focus))
        CCurrentGameState.Post(command)
    end
end

-- Called once when player is chosen
function SetTradeDecisionHiddenText()
    local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
    if playerCountry:GetCountry():GetVariables():GetVariable(CString("disable_resource_trade_decision")):Get() == 1 then
        UI.m_textCtrl_TradeDecisionHide:SetValue("Hidden")
    else
        UI.m_textCtrl_TradeDecisionHide:SetValue("Visible")
    end
end

-- Called from internal and each day
function SetICDaysLeftText()
    local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
    local icDaysleft = playerCountryTag:GetCountry():GetVariables():GetVariable(CString("IC_days_spent")):Get()
    local baseIC = playerCountryTag:GetCountry():GetVariables():GetVariable(CString("BaseIC")):Get()
    local investmentMult = playerCountryTag:GetCountry():GetVariables():GetVariable(CString("event_unit_investment")):Get()
    local reductionValue = Utils.Round((baseIC * investmentMult) / 100)
    SetCurrentDailyICDaysReductionText(reductionValue)
    if icDaysleft > 0 then
        UI.m_textCtrl_ICDaysLeft:SetValue(string.format('%.02f', tostring(icDaysleft)))
    else
        UI.m_textCtrl_ICDaysLeft:SetValue("0")
    end
end

-- Called from internal
function SetCurrentInvestmentText(value)
    UI.m_textCtrl_CurrentICInvestment:SetValue(tostring(value))
end

-- Called from internal
function SetCurrentDailyICDaysReductionText(value)
    UI.m_textCtrl_currentDailyICDaysReduction:SetValue(tostring(value))
end

-- Called from button press
function SetICInvestmentValue(value)
    if PlayerCountry ~= nil then
        local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)

        local command = CSetVariableCommand(playerCountryTag, CString("event_unit_investment"), CFixedPoint(value))
        CCurrentGameState.Post(command)
        SetCurrentInvestmentText(value)
    end
end

-- Called once at start
function DetermineICInvestmentValue()
    local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
    local currentInvestment = playerCountryTag:GetCountry():GetVariables():GetVariable(CString("event_unit_investment")):Get()
    if currentInvestment > 0 then
        SetCurrentInvestmentText(currentInvestment)
    else
        SetICInvestmentValue(20)
    end
end

-- Called from button press
function ToggleTradeDecisions(desiredState)
    if PlayerCountry ~= nil then
        local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
        if desiredState == true then
            local command = CSetVariableCommand(playerCountry, CString("disable_resource_trade_decision"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            UI.m_textCtrl_TradeDecisionHide:SetValue("Hidden")
        elseif desiredState == false then
            local command = CSetVariableCommand(playerCountry, CString("disable_resource_trade_decision"), CFixedPoint(0))
            CCurrentGameState.Post(command)
            UI.m_textCtrl_TradeDecisionHide:SetValue("Visible")
        end
    end
end

-- Called once when player is chosen
function SetMinesDecisionHiddenText()
    local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
    if playerCountry:GetCountry():GetVariables():GetVariable(CString("disable_mines_expansion_decision")):Get() == 1 then
        UI.m_textCtrl_MinesDecisionHide:SetValue("Hidden")
    else
        UI.m_textCtrl_MinesDecisionHide:SetValue("Visible")
    end
end

-- Called from button press
function ToggleMinesDecisions(desiredState)
    if PlayerCountry ~= nil then
        local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
        if desiredState == true then
            local command = CSetVariableCommand(playerCountry, CString("disable_mines_expansion_decision"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            UI.m_textCtrl_MinesDecisionHide:SetValue("Hidden")
        elseif desiredState == false then
            local command = CSetVariableCommand(playerCountry, CString("disable_mines_expansion_decision"), CFixedPoint(0))
            CCurrentGameState.Post(command)
            UI.m_textCtrl_MinesDecisionHide:SetValue("Visible")
        end
    end
end

-- Called from button press
function TogglePuppetFocusDecision(desiredState)
    if PlayerCountry ~= nil then
        local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
        if desiredState == true then
            local command = CSetVariableCommand(playerCountry, CString("disable_pupped_focus_decision"), CFixedPoint(0))
            CCurrentGameState.Post(command)
        elseif desiredState == false then
            local command = CSetVariableCommand(playerCountry, CString("disable_pupped_focus_decision"), CFixedPoint(1))
            CCurrentGameState.Post(command)
        end
    end
end

-- Called each refresh
function GetAndAddPuppets()
    local playerVassals = {}
    local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
    local puppets = playerCountry:GetCountry():GetVassals()
    if puppets then
        for puppet in puppets do
            local puppetTag = tostring(puppet:GetCountry():GetCountryTag())
            -- Utils.LUA_DEBUGOUT(puppetTag)
            table.insert(playerVassals, puppetTag)
        end
        UI.puppet_choice:Clear()
        UI.puppet_choice:Append(playerVassals)
    end
end

-- Called from button press
function SetPuppetSelection()
    if UI.puppet_choice:GetSelection() >= 0 then
        SelectedPuppet = UI.puppet_choice:GetString(UI.puppet_choice:GetSelection())
        SelectedPuppetCountryTag = CCountryDataBase.GetTag(SelectedPuppet)
        UI.set_puppet_text:SetValue(SelectedPuppet)
        SetPuppetFocusText(99)
    end
end

-- Called from button press
function SetPuppetFocus()
    if UI.puppet_focus_choice:GetSelection() >= 0 and SelectedPuppetCountryTag ~= nil then
        local selectedFocusIndex = UI.puppet_focus_choice:GetSelection() + 1
        local command = CSetVariableCommand(SelectedPuppetCountryTag, CString("puppet_focus_variable"), CFixedPoint(selectedFocusIndex))
        CCurrentGameState.Post(command)
        SetPuppetFocusText(selectedFocusIndex)
    end
end

-- Called from internal
function SetPuppetFocusText(selection)
    local selectedFocusStr = "None"
    local activeFocusIndex = SelectedPuppetCountryTag:GetCountry():GetVariables():GetVariable(CString("puppet_focus_variable")):Get()
    if selection == 1 then
        selectedFocusStr = "Rares"
    elseif selection == 2 then
        selectedFocusStr = "Energy"
    elseif selection == 3 then
        selectedFocusStr = "Metal"
    elseif selection == 4 then
        selectedFocusStr = "Navy"
    elseif selection == 5 then
        selectedFocusStr = "Air"
    elseif selection == 6 then
        selectedFocusStr = "Army"
    elseif selection == 7 then
        selectedFocusStr = "Oil"
    elseif selection == 8 then
        selectedFocusStr = "None"
    elseif selection == 99 and activeFocusIndex then
        SetPuppetFocusText(activeFocusIndex)
        return
    end
    UI.m_textCtrl4:SetValue(selectedFocusStr)
end

-- Called once at start
function DeterminePlayers()
    if CountryIterCacheCheck == 0 then
        CountryIterCache()
    end
    PlayerCountries = {}
    local playercount = 0
    for tag, countryTag in pairs(CountryIterCacheDict) do
        if CCurrentGameState.IsPlayer( countryTag ) then
            -- Utils.LUA_DEBUGOUT("Player --- " .. playercount .. " --- " .. tag )
            playercount = playercount + 1
            table.insert(PlayerCountries, tag)
        end
    end
    UI.player_choice:Clear()
    UI.player_choice:Append(PlayerCountries)
end

-- Called each refresh
function GetPlayerModifiers()
    local playerCountry = CCountryDataBase.GetTag(PlayerCountry):GetCountry()

    -- IC efficiency
    local icEffRaw = playerCountry:GetVariables():GetVariable(CString("IcEffVariable")):Get()

    -- Research efficiency
    local researchEffRaw = playerCountry:GetVariables():GetVariable(CString("ResEffVariable")):Get()

    -- Supply throughput
    local supplyEffRaw = playerCountry:GetVariables():GetVariable(CString("SuppThrouVariable")):Get()

    -- War exhaustion monthly
    local warExhautionRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_WAR_EXHAUSTION_):Get()
    if playerCountry:IsAtWar() then
        warExhautionRaw = warExhautionRaw + 20
    end

    -- War exhaustion current
    local currentWarExhaustion = playerCountry:GetVariables():GetVariable(CString("war_exhaustion")):Get()


    UI.m_textCtrl_IcEff:SetValue(string.format('%.02f', icEffRaw))
    UI.m_textCtrl_ResEff:SetValue(string.format('%.02f', researchEffRaw))
    UI.m_textCtrl_SuppThrou:SetValue(string.format('%.02f', supplyEffRaw))
    UI.m_textCtrl_WarExhaustion:SetValue(string.format('%.02f', warExhautionRaw))
    UI.m_textCtrl_currentWarExhaustion:SetValue(string.format('%.1f', currentWarExhaustion))
end

-- Called each update
function GetStratResourceValues()
    local resources = {
		["chromite"] = 0;
		["aluminium"] = 0;
		["rubber"] = 0;
		["tungsten"] = 0;
		["nickel"] = 0;
		["copper"] = 0;
		["zinc"] = 0;
		["manganese"] = 0;
		["molybdenum"] = 0
	}
    local resourcesSell = {
		["chromite"] = 0;
		["aluminium"] = 0;
		["rubber"] = 0;
		["tungsten"] = 0;
		["nickel"] = 0;
		["copper"] = 0;
		["zinc"] = 0;
		["manganese"] = 0;
		["molybdenum"] = 0
	}
    local resourcesBuy = {
		["chromite"] = 0;
		["aluminium"] = 0;
		["rubber"] = 0;
		["tungsten"] = 0;
		["nickel"] = 0;
		["copper"] = 0;
		["zinc"] = 0;
		["manganese"] = 0;
		["molybdenum"] = 0
	}

    if PlayerCountry ~= nil then
        local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
        local variables = playerCountry:GetCountry():GetVariables()
        for resource, count in pairs(resources) do
            resources[resource] = variables:GetVariable(CString(resource .. "_ActualBalance")):Get() - 1000
            resourcesSell[resource] = variables:GetVariable(CString(resource .. "_trade_sell")):Get()
            resourcesBuy[resource] = variables:GetVariable(CString(resource .. "_trade_buy")):Get()
        end
        SetStratResourceValues(resources, resourcesSell, resourcesBuy)
    end
end

-- Called each update
function GetNatFocusDays()
	local focuses = {
		"ground_forces",
		"air_force",
		"navy",
		"economy",
		"science",
		"health_and_education",
		"natural_resources"
	}

    if PlayerCountry ~= nil then
        local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
        local variables = playerCountry:GetCountry():GetVariables()
        for i, focus in pairs(focuses) do
            local days = variables:GetVariable(CString(focus .. "_national_focus_days_active")):Get()
            if days > 1 then
                SetFocusActiveDaysText(focus, tostring(days))
            else
                SetFocusActiveDaysText(focus, "0")
            end
        end
    end
end

-- Called from internal
function SetStratResourceValues(resources, resourcesSell, resourcesBuy)
    UI.m_textCtrlChromiteBalance:SetValue(tostring(resources["chromite"]))
    UI.m_textCtrlChromiteSales:SetValue(tostring(resourcesSell["chromite"]))
    UI.m_textCtrlChromiteBuys:SetValue(tostring(resourcesBuy["chromite"]))
    UI.m_textCtrlAluminiumBalance:SetValue(tostring(resources["aluminium"]))
    UI.m_textCtrlAluminiumSales:SetValue(tostring(resourcesSell["aluminium"]))
    UI.m_textCtrlAluminiumBuys:SetValue(tostring(resourcesBuy["aluminium"]))
    UI.m_textCtrlRubberBalance:SetValue(tostring(resources["rubber"]))
    UI.m_textCtrlRubberSales:SetValue(tostring(resourcesSell["rubber"]))
    UI.m_textCtrlRubberBuys:SetValue(tostring(resourcesBuy["rubber"]))
    UI.m_textCtrlTungstenBalance:SetValue(tostring(resources["tungsten"]))
    UI.m_textCtrlTungstenSales:SetValue(tostring(resourcesSell["tungsten"]))
    UI.m_textCtrlTungstenBuys:SetValue(tostring(resourcesBuy["tungsten"]))
    UI.m_textCtrlNickelBalance:SetValue(tostring(resources["nickel"]))
    UI.m_textCtrlNickelSales:SetValue(tostring(resourcesSell["nickel"]))
    UI.m_textCtrlNickelBuys:SetValue(tostring(resourcesBuy["nickel"]))
    UI.m_textCtrlCopperBalance:SetValue(tostring(resources["copper"]))
    UI.m_textCtrlCopperSales:SetValue(tostring(resourcesSell["copper"]))
    UI.m_textCtrlCopperBuys:SetValue(tostring(resourcesBuy["copper"]))
    UI.m_textCtrlZincBalance:SetValue(tostring(resources["zinc"]))
    UI.m_textCtrlZincSales:SetValue(tostring(resourcesSell["zinc"]))
    UI.m_textCtrlZincBuys:SetValue(tostring(resourcesBuy["zinc"]))
    UI.m_textCtrlManganeseBalance:SetValue(tostring(resources["manganese"]))
    UI.m_textCtrlManganeseSales:SetValue(tostring(resourcesSell["manganese"]))
    UI.m_textCtrlManganeseBuys:SetValue(tostring(resourcesBuy["manganese"]))
    UI.m_textCtrlMolybdenumBalance:SetValue(tostring(resources["molybdenum"]))
    UI.m_textCtrlMolybdenumSales:SetValue(tostring(resourcesSell["molybdenum"]))
    UI.m_textCtrlMolybdenumBuys:SetValue(tostring(resourcesBuy["molybdenum"]))
end

-- Called from button press
function DeactivateResourceSelling(desiredState, resource)
    if PlayerCountry ~= nil then
        local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
        if desiredState == true then
            local command = CSetVariableCommand(playerCountryTag, CString(resource .. "_deactivate_sales"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            SetResourceSaleStatesText("Stopped", resource)
        elseif desiredState == false then
            local command = CSetVariableCommand(playerCountryTag, CString(resource .. "_deactivate_sales"), CFixedPoint(0))
            CCurrentGameState.Post(command)
            SetResourceSaleStatesText("Selling",resource)
        end
    end
end

-- Called each refresh and once at country selection
function GetAndSetResourceSaleStates()
    local resources = {"chromite","aluminium","rubber","tungsten","nickel","copper","zinc","manganese","molybdenum"}
    local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
    local playerVariables = playerCountryTag:GetCountry():GetVariables()
    for index, resource in pairs(resources) do
        if playerVariables:GetVariable(CString(resource .. "_deactivate_sales")):Get() == 1 then
            SetResourceSaleStatesText("Stopped", resource)
        else
            SetResourceSaleStatesText("Selling",resource)
        end
    end
end

-- Called from internal
function SetResourceSaleStatesText(state, resource)
    if resource == "chromite" then
        UI.m_textCtrlChromiteSaleActive:SetValue(state)
    end
    if resource == "aluminium" then
        UI.m_textCtrlAluminiumSaleActive:SetValue(state)
    end
    if resource == "rubber" then
        UI.m_textCtrlRubberSaleActive:SetValue(state)
    end
    if resource == "tungsten" then
        UI.m_textCtrlTungstenSaleActive:SetValue(state)
    end
    if resource == "nickel" then
        UI.m_textCtrlNickelSaleActive:SetValue(state)
    end
    if resource == "copper" then
        UI.m_textCtrlCopperSaleActive:SetValue(state)
    end
    if resource == "zinc" then
        UI.m_textCtrlZincSaleActive:SetValue(state)
    end
    if resource == "manganese" then
        UI.m_textCtrlManganeseSaleActive:SetValue(state)
    end
    if resource == "molybdenum" then
        UI.m_textCtrlMolybdenumSaleActive:SetValue(state)
    end
end

-- Called from internal
function SetFocusActiveDaysText(focus, days)
    if focus == "ground_forces" then
        UI.m_textCtrl_FocusGroundDays:SetValue(days)
    end
    if focus == "air_force" then
        UI.m_textCtrl_FocusAirDays:SetValue(days)
    end
    if focus == "navy" then
        UI.m_textCtrl_FocusNavyDays:SetValue(days)
    end
    if focus == "economy" then
        UI.m_textCtrl_FocusEconDays:SetValue(days)
    end
    if focus == "science" then
        UI.m_textCtrl_FocusScienceDays:SetValue(days)
    end
    if focus == "health_and_education" then
        UI.m_textCtrl_FocusHealthEduDays:SetValue(days)
    end
    if focus == "natural_resources" then
        UI.m_textCtrl_FocusResourceDays:SetValue(days)
    end
end


-- Called each refresh and once at country selection
function GetMinisterBuildingsProgress()
    local buildings = {
        ["hospital"] = 40,
        ["rail_terminous"] = 30,
        ["resource_buildings"] = 54,
        ["automotive_factory"] = 54,
        ["radar_station"] = 40,
        ["artillery_factory"] = 65,
        ["military_college"] = 50,
        ["research_lab"] = 42,
        ["supplies_factory"] = 30,
        ["heavy_industry"] = 70,
        ["submarine_shipyard"] = 110,
        ["capital_ship_shipyard"] = 80,
        ["medium_ship_shipyard"] = 54,
        ["small_ship_shipyard"] = 30,
        ["heavy_aircraft_factory"] = 110,
        ["medium_aircraft_factory"] = 110,
        ["light_aircraft_factory"] = 110,
        ["tank_factory"] = 110,
        ["smallarms_factory"] = 80
    }
    local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
    local playerVariables = playerCountryTag:GetCountry():GetVariables()
    for building, trigger in pairs(buildings) do
        local count = playerVariables:GetVariable(CString(building .. "_variable_count_minister")):Get()
        if count > 0 then
            local percent = (count / trigger) * 100
            SetMinisterBuildingsProgressText(building, string.format('%.01f', percent))
        else
            SetMinisterBuildingsProgressText(building, "0")
        end
    end
end

-- Called from internal
function SetMinisterBuildingsProgressText(building, progress)
    if building == "hospital" then
        UI.m_textCtrl_Hospital:SetValue(progress .. "%")
    end
    if building == "rail_terminous" then
        UI.m_textCtrl_RailTerminus:SetValue(progress .. "%")
    end
    if building == "resource_buildings" then
        UI.m_textCtrl_ResourceBuildings:SetValue(progress .. "%")
    end
    if building == "automotive_factory" then
        UI.m_textCtrl_AutomotiveFactory:SetValue(progress .. "%")
    end
    if building == "radar_station" then
        UI.m_textCtrl_RadarStation:SetValue(progress .. "%")
    end
    if building == "artillery_factory" then
        UI.m_textCtrl_ArtilleryFactory:SetValue(progress .. "%")
    end
    if building == "military_college" then
        UI.m_textCtrl_TrainingCenters:SetValue(progress .. "%")
    end
    if building == "research_lab" then
        UI.m_textCtrl_ResearchCenters:SetValue(progress .. "%")
    end
    if building == "supplies_factory" then
        UI.m_textCtrl_SupplyFactory:SetValue(progress .. "%")
    end
    if building == "heavy_industry" then
        UI.m_textCtrl_HeavyIndustry:SetValue(progress .. "%")
    end
    if building == "submarine_shipyard" then
        UI.m_textCtrl_SubmarineShipyard:SetValue(progress .. "%")
    end
    if building == "capital_ship_shipyard" then
        UI.m_textCtrl_CapitalShipyard:SetValue(progress .. "%")
    end
    if building == "medium_ship_shipyard" then
        UI.m_textCtrl_MediumShipyard:SetValue(progress .. "%")
    end
    if building == "small_ship_shipyard" then
        UI.m_textCtrl_SmallShipyard:SetValue(progress .. "%")
    end
    if building == "heavy_aircraft_factory" then
        UI.m_textCtrl_HeavyAircraftFactory:SetValue(progress .. "%")
    end
    if building == "medium_aircraft_factory" then
        UI.m_textCtrl_MediumAircraftFactory:SetValue(progress .. "%")
    end
    if building == "light_aircraft_factory" then
        UI.m_textCtrl_LightAircraftFactory:SetValue(progress .. "%")
    end
    if building == "tank_factory" then
        UI.m_textCtrl_TankFactory:SetValue(progress .. "%")
    end
    if building == "smallarms_factory" then
        UI.m_textCtrl_SmlArmsFactory:SetValue(progress .. "%")
    end
end

function FillTradesGrid()
    UI.m_grid_trades_1:ClearGrid()
    UI.m_grid_trades_1:DeleteRows(0, UI.m_grid_trades_1:GetNumberRows(), true )
    local row = 0
    local currentDate = CCurrentGameState.GetCurrentDate():GetTotalDays()
    local buys = {}
    local sales = {}
    for tag, trades in pairs(GlobalTradesData) do
        for tradeName, trade in pairs(GlobalTradesData[tag]["trades"]) do
            if trade["buyer"] == PlayerCountry then
                table.insert(buys, trade)
            end
            if trade["seller"] == PlayerCountry then
                table.insert(sales, trade)
            end
        end
    end
    -- BUYS
    table.sort(buys, function (k1, k2) return k1.expiryDate < k2.expiryDate end )
    UI.m_grid_trades_1:AppendRows(1, true)
    -- insert buys marking row
    for i=0,3,1 do
        UI.m_grid_trades_1:SetCellValue(row, i, "-BUYS-")
        UI.m_grid_trades_1:SetCellBackgroundColour( row, i, wx.wxColour( 224, 224, 224 ) )
    end
    row = row + 1
    for i, trade in ipairs(buys) do
        UI.m_grid_trades_1:AppendRows(1, true)
        -- Buyer
        UI.m_grid_trades_1:SetCellValue(row, 0, trade["buyer"])
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 0, wx.wxColour( 208, 208, 208 ) )
        -- Seller
        UI.m_grid_trades_1:SetCellValue(row, 1, trade["seller"])
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 1, wx.wxColour( 208, 208, 208 ) )
        -- Resource
        UI.m_grid_trades_1:SetCellValue(row, 2, trade["resource"])
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 2, wx.wxColour( 208, 208, 208 ) )
        -- Expires in
        local expiresInDays = trade["expiryDate"] - currentDate
        UI.m_grid_trades_1:SetCellValue(row, 3, string.format('%.0f', expiresInDays))
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 3, wx.wxColour( 208, 208, 208 ) )
        row = row + 1
    end
    -- SALES
    table.sort(sales, function (k1, k2) return k1.expiryDate < k2.expiryDate end )
    UI.m_grid_trades_1:AppendRows(1, true)
    -- insert sales marking row
    for j=0,3,1 do
        UI.m_grid_trades_1:SetCellValue(row, j, "-SALES-")
        UI.m_grid_trades_1:SetCellBackgroundColour( row, j, wx.wxColour( 224, 224, 224 ) )
    end
    row = row + 1
    for i, trade in ipairs(sales) do
        UI.m_grid_trades_1:AppendRows(1, true)
        -- Buyer
        UI.m_grid_trades_1:SetCellValue(row, 0, trade["buyer"])
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 0, wx.wxColour( 208, 208, 208 ) )
        -- Seller
        UI.m_grid_trades_1:SetCellValue(row, 1, trade["seller"])
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 1, wx.wxColour( 208, 208, 208 ) )
        -- Resource
        UI.m_grid_trades_1:SetCellValue(row, 2, trade["resource"])
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 2, wx.wxColour( 208, 208, 208 ) )
        -- Expires in
        local expiresInDays = trade["expiryDate"] - currentDate
        UI.m_grid_trades_1:SetCellValue(row, 3, string.format('%.0f', expiresInDays))
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 3, wx.wxColour( 208, 208, 208 ) )
        row = row + 1
    end
end

function SetCustomTradeAiStatus()
    if wx ~= nil and PlayerCountry ~= nil then
        local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
		if UI.m_textCtrl_customTradeAi1:GetValue() == "Active" then
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_CustomTradeAiActive"), CFixedPoint(0))
            CCurrentGameState.Post(command)
            SetCustomTradeAiStatusText(false)
        else
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_CustomTradeAiActive"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_usesCustomTradeAi"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            SetCustomTradeAiStatusText(true)
            SetCustomTradeAiValues()
		end
    end
end

function SetCustomTradeAiStatusText(status)
    if status then
		UI.m_textCtrl_customTradeAi1:SetValue("Active")
    else
        UI.m_textCtrl_customTradeAi1:SetValue("Inactive")
    end
end

function DetermineCustomTradeAiStatus()
    local countryTag = CCountryDataBase.GetTag(PlayerCountry)
    local country = countryTag:GetCountry()
    local variables = country:GetVariables()

    if variables:GetVariable(CString("zzDsafe_CustomTradeAiActive")):Get() == 1 then
        SetCustomTradeAiStatusText(true)
    else
        SetCustomTradeAiStatusText(false)
    end
end

function SetCustomTradeAiValues()
    local Values = {
        MONEY = {
            MaxDailySell = tonumber(UI.m_textCtrl_CustomTradeAi_MaxDailySell:GetValue()),
            Buffer = tonumber(UI.m_textCtrl_customTradeAi_Money_Buffer:GetValue()),
            BufferSaleCap = 20 -- ignored
        },
        METAL = {
            Buffer = tonumber(UI.m_textCtrl_customTradeAi_Metal_Buffer:GetValue()), 			-- Amount extra to keep abouve our needs
            BufferSaleCap = tonumber(UI.m_textCtrl_customTradeAi_Metal_BufferSaleCap:GetValue()), 	-- Amount we need in reserve before we sell the resource
            BufferBuyCap = tonumber(UI.m_textCtrl_customTradeAi_Metal_BufferCancelCap:GetValue()), 	-- not used by me! (Amount we need before we stop actively buying (existing trades are NOT cancelled))
            BufferCancelCap = tonumber(UI.m_textCtrl_customTradeAi_Metal_BufferCancelCap:GetValue()), -- Amount we need before we cancel trades simply because we have to much
        },
        ENERGY = {
            Buffer = tonumber(UI.m_textCtrl_customTradeAi_Energy_Buffer:GetValue()),
            BufferSaleCap = tonumber(UI.m_textCtrl_customTradeAi_Energy_BufferSaleCap:GetValue()),
            BufferBuyCap = tonumber(UI.m_textCtrl_customTradeAi_Energy_BufferCancelCap:GetValue()),
            BufferCancelCap = tonumber(UI.m_textCtrl_customTradeAi_Energy_BufferCancelCap:GetValue()),
        },
        RARE_MATERIALS = {
            Buffer = tonumber(UI.m_textCtrl_customTradeAi_Rares_Buffer:GetValue()),
            BufferSaleCap = tonumber(UI.m_textCtrl_customTradeAi_Rares_BufferSaleCap:GetValue()),
            BufferBuyCap = tonumber(UI.m_textCtrl_customTradeAi_Rares_BufferCancelCap:GetValue()),
            BufferCancelCap = tonumber(UI.m_textCtrl_customTradeAi_Rares_BufferCancelCap:GetValue()),
        },
        CRUDE_OIL = {
            Buffer = tonumber(UI.m_textCtrl_customTradeAi_Oil_Buffer:GetValue()),
            BufferSaleCap = tonumber(UI.m_textCtrl_customTradeAi_Oil_BufferSaleCap:GetValue()),
            BufferBuyCap = tonumber(UI.m_textCtrl_customTradeAi_Oil_BufferCancelCap:GetValue()),
            BufferCancelCap = tonumber(UI.m_textCtrl_customTradeAi_Oil_BufferCancelCap:GetValue()),
        },
        SUPPLIES = {
            Buffer = 1000,          -- Ignored for supplies
            BufferSaleCap = 5000,   -- Ignored for supplies
            BufferBuyCap = 5000,    -- Ignored for supplies
            BufferCancelCap = 5000, -- Ignored for supplies
        },
        FUEL = {
            Buffer = tonumber(UI.m_textCtrl_customTradeAi_Fuel_Buffer:GetValue()),
            BufferSaleCap = tonumber(UI.m_textCtrl_customTradeAi_Fuel_BufferSaleCap:GetValue()),
            BufferBuyCap = tonumber(UI.m_textCtrl_customTradeAi_Fuel_BufferCancelCap:GetValue()),
            BufferCancelCap = tonumber(UI.m_textCtrl_customTradeAi_Fuel_BufferCancelCap:GetValue()),
        }
    }
    local countryTag = CCountryDataBase.GetTag(PlayerCountry)
    local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_MaxDailySell"), CFixedPoint(Values.MONEY.MaxDailySell))
    CCurrentGameState.Post(command)
    local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_MONEY_Buffer"), CFixedPoint(Values.MONEY.Buffer))
    CCurrentGameState.Post(command)
    local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_MONEY_BufferSaleCap"), CFixedPoint(Values.MONEY.BufferSaleCap))
    CCurrentGameState.Post(command)
    for k, v in pairs(Values) do
        if k ~= "MONEY" then
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_"..k.."_Buffer"), CFixedPoint(Values[k].Buffer))
            CCurrentGameState.Post(command)
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_"..k.."_BufferSaleCap"), CFixedPoint(Values[k].BufferSaleCap))
            CCurrentGameState.Post(command)
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_"..k.."_BufferBuyCap"), CFixedPoint(Values[k].BufferBuyCap))
            CCurrentGameState.Post(command)
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_"..k.."_BufferCancelCap"), CFixedPoint(Values[k].BufferCancelCap))
            CCurrentGameState.Post(command)
        end
    end
    local command = CSetVariableCommand(countryTag, CString("zzDsafe_WantsToChangeCustomTradeAi"), CFixedPoint(1))
    CCurrentGameState.Post(command)
end

function ReadCustomTradeAiValues()
    local countryTag = CCountryDataBase.GetTag(PlayerCountry)
    local country = countryTag:GetCountry()
    local variables = country:GetVariables()
    if variables:GetVariable(CString("zzDsafe_usesCustomTradeAi")):Get() == 0 then
        return
    end

    UI.m_textCtrl_CustomTradeAi_MaxDailySell:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_MaxDailySell")):Get())))

    UI.m_textCtrl_customTradeAi_Money_Buffer:SetValue(
        string.format('%.2f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_MONEY_Buffer")):Get())))

    UI.m_textCtrl_customTradeAi_Metal_Buffer:SetValue(
        string.format('%.2f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_METAL_Buffer")):Get())))
    UI.m_textCtrl_customTradeAi_Metal_BufferSaleCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_METAL_BufferSaleCap")):Get())))
    UI.m_textCtrl_customTradeAi_Metal_BufferCancelCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_METAL_BufferCancelCap")):Get())))

    UI.m_textCtrl_customTradeAi_Energy_Buffer:SetValue(
        string.format('%.2f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_ENERGY_Buffer")):Get())))
    UI.m_textCtrl_customTradeAi_Energy_BufferSaleCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_ENERGY_BufferSaleCap")):Get())))
    UI.m_textCtrl_customTradeAi_Energy_BufferCancelCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_ENERGY_BufferCancelCap")):Get())))

    UI.m_textCtrl_customTradeAi_Rares_Buffer:SetValue(
        string.format('%.2f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_RARE_MATERIALS_Buffer")):Get())))
    UI.m_textCtrl_customTradeAi_Rares_BufferSaleCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_RARE_MATERIALS_BufferSaleCap")):Get())))
    UI.m_textCtrl_customTradeAi_Rares_BufferCancelCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_RARE_MATERIALS_BufferCancelCap")):Get())))

    UI.m_textCtrl_customTradeAi_Oil_Buffer:SetValue(
        string.format('%.2f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_CRUDE_OIL_Buffer")):Get())))
    UI.m_textCtrl_customTradeAi_Oil_BufferSaleCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_CRUDE_OIL_BufferSaleCap")):Get())))
    UI.m_textCtrl_customTradeAi_Oil_BufferCancelCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_CRUDE_OIL_BufferCancelCap")):Get())))

    UI.m_textCtrl_customTradeAi_Fuel_Buffer:SetValue(
        string.format('%.2f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_FUEL_Buffer")):Get())))
    UI.m_textCtrl_customTradeAi_Fuel_BufferSaleCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_FUEL_BufferSaleCap")):Get())))
    UI.m_textCtrl_customTradeAi_Fuel_BufferCancelCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_FUEL_BufferCancelCap")):Get())))

end


function SetDialogPopUpCenter()
    local text = "Center popups - "
    local ret = nil
    local name1 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark1 = "# _UtilityMark_DefaultPopup_position"
    local new1 = "		position = { x=-250 y=-450 } # _UtilityMark_DefaultPopup_position"
    ret = ReplaceLineAtCommentMark(name1, mark1, new1)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)

    local name2 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark2 = "# _UtilityMark_DefaultPopup_orientation"
    local new2 = "		orientation=\"CENTER\" # _UtilityMark_DefaultPopup_orientation"
    ret = ReplaceLineAtCommentMark(name2, mark2, new2)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)

    local name3 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark3 = "# _UtilityMark_CombatStartPopup_position"
    local new3 = "		position = { x=-250 y=-280 } # _UtilityMark_CombatStartPopup_position"
    ret = ReplaceLineAtCommentMark(name3, mark3, new3)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)

    local name4 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark4 = "# _UtilityMark_CombatStartPopup_orientation"
    local new4 = "		orientation=\"CENTER\" # _UtilityMark_CombatStartPopup_orientation"
    ret = ReplaceLineAtCommentMark(name4, mark4, new4)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)
end

function SetDialogPopUpLeft()
    local text = "Leftside popups - "
    local ret = nil
    local name1 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark1 = "# _UtilityMark_DefaultPopup_position"
    local new1 = "		position = { x=50 y=100 } # _UtilityMark_DefaultPopup_position"
    ret = ReplaceLineAtCommentMark(name1, mark1, new1)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)

    local name2 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark2 = "# _UtilityMark_DefaultPopup_orientation"
    local new2 = "		orientation=\"CENTER_RIGHT\" # _UtilityMark_DefaultPopup_orientation"
    ret = ReplaceLineAtCommentMark(name2, mark2, new2)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)

    local name3 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark3 = "# _UtilityMark_CombatStartPopup_position"
    local new3 = "		position = { x=50 y=100 } # _UtilityMark_CombatStartPopup_position"
    ret = ReplaceLineAtCommentMark(name3, mark3, new3)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)

    local name4 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eu3dialog.gui"
    local mark4 = "# _UtilityMark_CombatStartPopup_orientation"
    local new4 = "		orientation=\"CENTER_RIGHT\" # _UtilityMark_CombatStartPopup_orientation"
    ret = ReplaceLineAtCommentMark(name4, mark4, new4)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)
end

function SetEventPopUpCenter()
    local text = "Center events - "
    local ret = nil
    local name1 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eventwindow.gui"
    local mark1 = "# _UtilityMark_EventPopup_position"
    local new1 = "		position = { x=700 y=255 } # _UtilityMark_EventPopup_position"
    ret = ReplaceLineAtCommentMark(name1, mark1, new1)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)
end

function SetEventPopUpLeft()
    local text = "Leftside events - "
    local ret = nil
    local name1 = "tfh/mod/BlackICE ".. UI.version .. "/interface/eventwindow.gui"
    local mark1 = "# _UtilityMark_EventPopup_position"
    local new1 = "		position = { x=0 y=255 } # _UtilityMark_EventPopup_position"
    ret = ReplaceLineAtCommentMark(name1, mark1, new1)
    UI.m_textCtrl_OptionActions_Output:SetValue(text .. ret)
end

function SetCustomProductionSliderAiStatus()
    if wx ~= nil and PlayerCountry ~= nil then
        local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
		if UI.m_textCtrl_customProdSlider_state:GetValue() == "Active" then
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_CustomProductionSliders_isActive"), CFixedPoint(0))
            CCurrentGameState.Post(command)
            SetCustomProductionSliderAiStatusText(false)
        else
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_usesCustomProductionSliders"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            SetCustomProductionSliderValues()
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_CustomProductionSliders_isActive"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            SetCustomProductionSliderAiStatusText(true)
		end
    end
end

function SetCustomProductionSliderAiStatusText(status)
    if status then
		UI.m_textCtrl_customProdSlider_state:SetValue("Active")
    else
        UI.m_textCtrl_customProdSlider_state:SetValue("Inactive")
    end
end

function DetermineCustomProductionSliderAiStatus()
    local countryTag = CCountryDataBase.GetTag(PlayerCountry)
    local country = countryTag:GetCountry()
    local variables = country:GetVariables()

    if variables:GetVariable(CString("zzDsafe_CustomProductionSliders_isActive")):Get() == 1 then
        SetCustomProductionSliderAiStatusText(true)
    else
        SetCustomProductionSliderAiStatusText(false)
    end
end

function CheckCustomProductionSliderPrioConflict()
    local categories = {
        "upgrade",
        "reinforce",
        "supply",
        "production",
        "consumer",
        "lendLease"
    }
    local priorities = {}
    for k, category in pairs(categories) do
        local prio = tonumber(UI["m_textCtrl_customProdSlider_" .. category .. "Prio"]:GetValue())
        if prio ~= nil then
            if priorities[prio] then
                UI["m_textCtrl_customProdSlider_" .. category .. "Prio"]:SetValue("CONFLICT")
                return true
            else
                priorities[prio] = true
            end
        else
            return true
        end
    end
    return false
end

function SetCustomProductionSliderValues()
    if wx ~= nil and PlayerCountry ~= nil then
        local countryTag = CCountryDataBase.GetTag(PlayerCountry)
        -- local country = countryTag:GetCountry()
        -- local variables = country:GetVariables()
        local categories = {
            "upgrade",
            "reinforce",
            "supply",
            "production",
            "consumer",
            "lendLease"
        }

        if CheckCustomProductionSliderPrioConflict() then
            return
        end

        for k, category in pairs(categories) do
            local amount = tonumber(UI["m_textCtrl_customProdSlider_" .. category .. "Amount"]:GetValue())
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_" .. category .. "Amount"), CFixedPoint(amount))
            CCurrentGameState.Post(command)
            local prio = tonumber(UI["m_textCtrl_customProdSlider_" .. category .. "Prio"]:GetValue())
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_" .. category .. "Prio"), CFixedPoint(prio))
            CCurrentGameState.Post(command)
            local mode = UI["m_choice_customProdSlider_" .. category .. "Mode"]:GetSelection()
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_" .. category .. "InvestMode"), CFixedPoint(mode))
            CCurrentGameState.Post(command)

            if category == "upgrade" or category == "reinforce" then
                local limitActive = UI["m_checkBox_customProdSlider_" .. category .. "Limit"]:GetValue()
                local command = CSetVariableCommand(
                    countryTag, CString("zzDsafe_CustomProductionSliders_" .. category .. "Limit_active"), CFixedPoint(Utils.BoolToNumber(limitActive)))
                CCurrentGameState.Post(command)
                local limit = tonumber(UI["m_textCtrl_customProdSlider_" .. category .. "Limit"]:GetValue())
                local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_" .. category .. "Limit"), CFixedPoint(limit))
                CCurrentGameState.Post(command)
            elseif category == "consumer" then
                local reduceDissent = UI.m_checkBox_customProdSlider_reduceDissent:GetValue()
                local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_reduceDissent"), CFixedPoint(Utils.BoolToNumber(reduceDissent)))
                CCurrentGameState.Post(command)
            elseif category == "supply" then
                local supplyGoal = tonumber(UI.m_textCtrl_customProdSlider_supplyGoal:GetValue())
                local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_supplyGoal"), CFixedPoint(supplyGoal))
                CCurrentGameState.Post(command)
                local supplyGoalActive = UI.m_checkBox_customProdSlider_supplyGoal:GetValue()
                local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_supplyGoal_active"), CFixedPoint(Utils.BoolToNumber(supplyGoalActive)))
                CCurrentGameState.Post(command)
            end
        end
    end
end

function ReadCustomProductionSliderValues()
    if wx ~= nil and PlayerCountry ~= nil then
        local countryTag = CCountryDataBase.GetTag(PlayerCountry)
        local country = countryTag:GetCountry()
        local variables = country:GetVariables()
        local categories = {
            "upgrade",
            "reinforce",
            "supply",
            "production",
            "consumer",
            "lendLease"
        }

        if variables:GetVariable(CString("zzDsafe_usesCustomProductionSliders")):Get() == 0 then
            return
        end

        for k, category in pairs(categories) do
            UI["m_textCtrl_customProdSlider_" .. category .. "Amount"]:SetValue(
                string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_CustomProductionSliders_" .. category .. "Amount")):Get())))
            UI["m_textCtrl_customProdSlider_" .. category .. "Prio"]:SetValue(
                string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_CustomProductionSliders_" .. category .. "Prio")):Get())))
            UI["m_choice_customProdSlider_" .. category .. "Mode"]:SetSelection(
                variables:GetVariable(CString("zzDsafe_CustomProductionSliders_" .. category .. "InvestMode")):Get())
            if category == "upgrade" or category == "reinforce" then
                UI["m_checkBox_customProdSlider_" .. category .. "Limit"]:SetValue(Utils.NumberToBool(
                    variables:GetVariable(CString("zzDsafe_CustomProductionSliders_" .. category .. "Limit_active")):Get()))
                UI["m_textCtrl_customProdSlider_" .. category .. "Limit"]:SetValue(
                    string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_CustomProductionSliders_" .. category .. "Limit")):Get())))
            elseif category == "consumer" then
                UI.m_checkBox_customProdSlider_reduceDissent:SetValue(
                    variables:GetVariable(CString("zzDsafe_CustomProductionSliders_reduceDissent")):Get())
            elseif category == "supply" then
                UI.m_checkBox_customProdSlider_supplyGoal:SetValue(
                    variables:GetVariable(CString("zzDsafe_CustomProductionSliders_supplyGoal_active")):Get())
                UI.m_textCtrl_customProdSlider_supplyGoal:SetValue(
                    string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_CustomProductionSliders_supplyGoal")):Get())))
            end
        end
    end
end