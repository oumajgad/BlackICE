-- Misc tab.
--
-- The decision switches live in BiceData.Misc, shared with the ImGui utility. The
-- daily counts switch stays here: it is a Lua global the AI reads, and the ImGui
-- utility does not offer it.

-- Called from button press
function UpdateDailyCountsTextCtrl()
    UI.m_textCtrlDailyCount:SetValue(tostring(G_DateOverride))
end

--- Both decision switches at once, since one read covers them.
local function refreshDecisionText()
    local data = BiceData.Misc.Collect()
    if data == nil then
        return
    end

    UI.m_textCtrl_TradeDecisionHide:SetValue(data.tradeHidden and "Hidden" or "Visible")
    UI.m_textCtrl_MinesDecisionHide:SetValue(data.minesHidden and "Hidden" or "Visible")
end

-- Called once when player is chosen
function SetTradeDecisionHiddenText()
    refreshDecisionText()
end

-- Called from button press
function ToggleTradeDecisions(desiredState)
    if desiredState ~= true and desiredState ~= false then
        return
    end

    BiceData.Misc.SetTradeHidden(desiredState)
    -- Shown straight away rather than read back: the command is only queued, so the
    -- game still reports the old value for a moment.
    UI.m_textCtrl_TradeDecisionHide:SetValue(desiredState and "Hidden" or "Visible")
end

-- Called once when player is chosen
function SetMinesDecisionHiddenText()
    refreshDecisionText()
end

-- Called from button press
function ToggleMinesDecisions(desiredState)
    if desiredState ~= true and desiredState ~= false then
        return
    end

    BiceData.Misc.SetMinesHidden(desiredState)
    UI.m_textCtrl_MinesDecisionHide:SetValue(desiredState and "Hidden" or "Visible")
end
