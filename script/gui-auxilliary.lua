
function GuiRefreshLoop()
    DaysSinceLastUpdate = DaysSinceLastUpdate + 1
    if wx ~= nil and PlayerCountry ~= nil and DaysSinceLastUpdate >= UpdateInterval then
        DaysSinceLastUpdate = 0
        GetAndAddPuppets()
        GetPlayerModifiers()
    end
end

function NotifySaveLoaded()
    -- Utils.LUA_DEBUGOUT("SAVELOADED")
    UI.m_textCtrl3:SetValue("Save Loaded")
    UI.m_textCtrl6:SetValue("1")
end

function UpdateDailyCountsTextCtrl()
    UI.m_textCtrlDailyCount:SetValue(tostring(DateOverride))
end

function TogglePuppetFocusDecision(desiredState)
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