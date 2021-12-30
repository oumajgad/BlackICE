
function GuiRefreshLoop()
    DaysSinceLastUpdate = DaysSinceLastUpdate + 1
    if wx ~= nil and PlayerCountry ~= nil and DaysSinceLastUpdate >= UpdateInterval then
        local playerTag = CCountryDataBase.GetTag(PlayerCountry)
        DaysSinceLastUpdate = 0
        GetAndAddPuppets()
        GetPlayerModifiers()
        GetStratResourceValues()
        SetICDaysLeftText(playerTag)
    end
end

-- Called once at start
function NotifySaveLoaded()
    -- Utils.LUA_DEBUGOUT("SAVELOADED")
    UI.m_textCtrl3:SetValue("Save Loaded")
    UI.m_textCtrl6:SetValue("10")
end

-- Called from button press
function UpdateDailyCountsTextCtrl()
    UI.m_textCtrlDailyCount:SetValue(tostring(DateOverride))
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

-- Called once when player is chosen
function SetICPanelTexts()
    local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
    SetICDaysLeftText(playerCountryTag)
    SetICInvestmentValue(10)
end

-- Called from internal and each day
function SetICDaysLeftText(playerCountryTag)
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
        local ai = OMGMinister:GetOwnerAI()
        ai:Post(command)
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
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
            UI.m_textCtrl_TradeDecisionHide:SetValue("Hidden")
        elseif desiredState == false then
            local command = CSetVariableCommand(playerCountry, CString("disable_resource_trade_decision"), CFixedPoint(0))
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
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
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
            UI.m_textCtrl_MinesDecisionHide:SetValue("Hidden")
        elseif desiredState == false then
            local command = CSetVariableCommand(playerCountry, CString("disable_mines_expansion_decision"), CFixedPoint(0))
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
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
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
        elseif desiredState == false then
            local command = CSetVariableCommand(playerCountry, CString("disable_pupped_focus_decision"), CFixedPoint(1))
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
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
        local ai = OMGMinister:GetOwnerAI()
        ai:Post(command)
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
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
            SetResourceSaleStatesText("Stopped", resource)
        elseif desiredState == false then
            local command = CSetVariableCommand(playerCountryTag, CString(resource .. "_deactivate_sales"), CFixedPoint(0))
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
            SetResourceSaleStatesText("Selling",resource)
        end
    end
end

-- Called once at start
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