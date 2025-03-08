local P = {}

P.ActiveEventModifierChoices = {}
P.ExpiryDates = {}
function P.Refresh()
    if G_PlayerCountry == nil then
        return
    end
    if BiceLib == nil then
        return
    end

    local activeModifiers = BiceLib.GameInfo.getCountryActiveEventModifiers(G_PlayerCountry)
    if activeModifiers == nil then
        Utils.LUA_DEBUGOUT("activeModifiers nil")
        return
    end

    P.ExpiryDates = {}
    P.ActiveEventModifierChoices = {}
    for modifier, expiry in pairs(activeModifiers) do
        local trans = Parsing.GetTranslation(modifier)
        if trans ~= nil then
            table.insert(P.ActiveEventModifierChoices, trans .. " [" .. modifier .. "]")
        else
            table.insert(P.ActiveEventModifierChoices,"[" .. modifier .. "]")
        end
        P.ExpiryDates[modifier] = expiry
    end

    table.sort(P.ActiveEventModifierChoices, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_GameInfo_ActiveModifiers1:Freeze()
    UI.m_choice_GameInfo_ActiveModifiers1:Clear()
    UI.m_choice_GameInfo_ActiveModifiers1:Append(P.ActiveEventModifierChoices)
    UI.m_choice_GameInfo_ActiveModifiers1:Thaw()

    P.ClearText()
end

function P.HandleSelection()
    local selectionString = UI.m_choice_GameInfo_ActiveModifiers1:GetString(UI.m_choice_GameInfo_ActiveModifiers1:GetSelection())
    local modifierIdent = Parsing.GetKeyFromChoice(selectionString)

    local s = Parsing.Modifiers.DumpEffects(modifierIdent)
    UI.m_textCtrl_GameInfo_ActiveModifiers_Effects1:SetValue(s)

    local expiry = P.ExpiryDates[modifierIdent]
    UI.m_textCtrl_GameInfo_ActiveModifiers_Expiry:SetValue(expiry)
end

P.ActiveModifierChoicesFiltered = {}
function P.HandleFilter()
    P.ClearText()
    local filterString = UI.m_textCtrl_GameInfo_ActiveModifiers_Filter:GetValue()
    if filterString == nil or filterString == "" then   -- Reset to default
        UI.m_choice_GameInfo_ActiveModifiers1:Freeze()
        UI.m_choice_GameInfo_ActiveModifiers1:Clear()
        UI.m_choice_GameInfo_ActiveModifiers1:Append(P.ActiveEventModifierChoices)
        UI.m_choice_GameInfo_ActiveModifiers1:Thaw()
        if UI.m_choice_GameInfo_ActiveModifiers1:GetCount() >= 1 then
            UI.m_choice_GameInfo_ActiveModifiers1:SetSelection(0)
            P.HandleSelection()
        end
        return
    end

    P.ActiveModifierChoicesFiltered = {} -- reset the list

    for k, v in pairs(P.ActiveEventModifierChoices) do
        if string.find(string.lower(v), string.lower(filterString)) then
            table.insert(P.ActiveModifierChoicesFiltered, v)
        end
    end

    table.sort(P.ActiveModifierChoicesFiltered, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_GameInfo_ActiveModifiers1:Freeze()
    UI.m_choice_GameInfo_ActiveModifiers1:Clear()
    UI.m_choice_GameInfo_ActiveModifiers1:Append(P.ActiveModifierChoicesFiltered)
    UI.m_choice_GameInfo_ActiveModifiers1:Thaw()
    if UI.m_choice_GameInfo_ActiveModifiers1:GetCount() >= 1 then
        UI.m_choice_GameInfo_ActiveModifiers1:SetSelection(0)
        P.HandleSelection()
    end
end

function P.ClearText()
    UI.m_panel_GameInfo_ActiveModifiers:Freeze()
    UI.m_textCtrl_GameInfo_ActiveModifiers_Effects1:Clear()
    UI.m_textCtrl_GameInfo_ActiveModifiers_Expiry:Clear()
    UI.m_panel_GameInfo_ActiveModifiers:Thaw()
end

return P