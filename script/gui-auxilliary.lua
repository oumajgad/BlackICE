
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
    if icDaysleft > 0 then
        UI.m_textCtrl_ICDaysLeft:SetValue(tostring(icDaysleft))
    else
        UI.m_textCtrl_ICDaysLeft:SetValue("0")
    end
end

-- Called from internal
function SetCurrentInvestmentText(value)
    UI.m_textCtrl_CurrentICInvestment:SetValue(tostring(value))
end

-- Called from internal
function SetCurrentDailyICDaysReduction(value)
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
    local icEffRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_INDUSTRIAL_EFFICIENCY_):Get() * 100

    -- Research efficiency
    local researchEffRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_RESEARCH_EFFICIENCY_):Get() * 100

    -- War exhaustion
    local warExhautionRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_WAR_EXHAUSTION_):Get()
    if playerCountry:IsAtWar() then
        warExhautionRaw = warExhautionRaw + 20
    end

    UI.m_textCtrl_IcEff:SetValue(string.format('%.02f', icEffRaw))
    UI.m_textCtrl_ResEff:SetValue(string.format('%.02f', researchEffRaw))
    UI.m_textCtrl_WarExhaustion:SetValue(string.format('%.02f', warExhautionRaw))
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