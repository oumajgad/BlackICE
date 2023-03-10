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
function SetICInvestmentValue(investmentMult)
    if PlayerCountry ~= nil then
        local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
        local playerCountry = playerCountryTag:GetCountry()
        local baseIC = playerCountry:GetVariables():GetVariable(CString("BaseIC")):Get()

        local command = CSetVariableCommand(playerCountryTag, CString("event_unit_investment"), CFixedPoint(investmentMult))
        CCurrentGameState.Post(command)
        SetCurrentInvestmentText(investmentMult)
        SetCurrentDailyICDaysReductionText(Utils.Round((baseIC * investmentMult) / 100))
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
