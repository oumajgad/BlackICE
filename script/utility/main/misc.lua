-- Called from button press
function UpdateDailyCountsTextCtrl()
    UI.m_textCtrlDailyCount:SetValue(tostring(G_DateOverride))
end

-- Called once when player is chosen
function SetTradeDecisionHiddenText()
    local playerCountry = CCountryDataBase.GetTag(G_PlayerCountry)
    if playerCountry:GetCountry():GetVariables():GetVariable(CString("disable_resource_trade_decision")):Get() == 1 then
        UI.m_textCtrl_TradeDecisionHide:SetValue("Hidden")
    else
        UI.m_textCtrl_TradeDecisionHide:SetValue("Visible")
    end
end

-- Called from button press
function ToggleTradeDecisions(desiredState)
    if G_PlayerCountry ~= nil then
        local playerCountry = CCountryDataBase.GetTag(G_PlayerCountry)
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
    local playerCountry = CCountryDataBase.GetTag(G_PlayerCountry)
    if playerCountry:GetCountry():GetVariables():GetVariable(CString("disable_mines_expansion_decision")):Get() == 1 then
        UI.m_textCtrl_MinesDecisionHide:SetValue("Hidden")
    else
        UI.m_textCtrl_MinesDecisionHide:SetValue("Visible")
    end
end

-- Called from button press
function ToggleMinesDecisions(desiredState)
    if G_PlayerCountry ~= nil then
        local playerCountry = CCountryDataBase.GetTag(G_PlayerCountry)
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
