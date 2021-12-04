
function GuiRefreshLoop()
    DaysSinceLastUpdate = DaysSinceLastUpdate + 1
    if wx ~= nil and PlayerCountry ~= nil and DaysSinceLastUpdate >= UpdateInterval then
        DaysSinceLastUpdate = 0
        GetAndAddPuppets()
        GetPlayerModifiers()
        GetStratResourceValues()
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
    local PlayerCountries = {}
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
    local icEffRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_INDUSTRIAL_EFFICIENCY_):Get()
    local icEffClean = Utils.RoundDecimal(icEffRaw, 2) * 100

    -- Research efficiency
    local researchEffRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_RESEARCH_EFFICIENCY_):Get()
    local researchEffClean = Utils.RoundDecimal(researchEffRaw, 2) * 100

    -- Supply throughput
    local supplyEffRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_SUPPLY_THROUGHPUT_):Get()
    local supplyEffClean = Utils.RoundDecimal(supplyEffRaw, 2) * 100

    -- Supply consumption
    local supplyConsRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_SUPPLY_CONSUMPTION_):Get()
    local supplyConsClean = Utils.RoundDecimal(supplyConsRaw, 2) * 100

    UI.m_textCtrl_IcEff:SetValue(tostring(icEffClean))
    UI.m_textCtrl_ResEff:SetValue(tostring(researchEffClean))
    UI.m_textCtrl_SupplyThr:SetValue(tostring(supplyEffClean))
    UI.m_textCtrl_SupplyCons:SetValue(tostring(supplyConsClean))
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
