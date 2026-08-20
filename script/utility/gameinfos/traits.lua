-- Traits tab.
--
-- Parsing, translation and the effect and trigger dumps live in BiceData.Traits, shared
-- with the ImGui utility, so traits.txt is read once for both. This keeps the wx half:
-- the choice control, its filter and the two text boxes.
--
-- DumpEffects stays on this module because the generals tab calls it for a leader's
-- traits.

local P = {}

--- The choice strings, held so the filter has something to filter.
P.TraitsChoices = {}
P.TraitsChoicesFiltered = {}

local dataFilled = false

--- Puts a list into the choice control and selects the first of it.
local function showChoices(choices)
    UI.m_choice_GameInfo_Traits:Freeze()
    UI.m_choice_GameInfo_Traits:Clear()
    UI.m_choice_GameInfo_Traits:Append(choices)
    UI.m_choice_GameInfo_Traits:Thaw()

    if UI.m_choice_GameInfo_Traits:GetCount() >= 1 then
        UI.m_choice_GameInfo_Traits:SetSelection(0)
        P.HandleSelection()
    end
end

function P.FillData()
    if dataFilled then
        return
    end

    P.TraitsChoices = BiceData.Traits.Choices()

    UI.m_choice_GameInfo_Traits:Freeze()
    UI.m_choice_GameInfo_Traits:Clear()
    UI.m_choice_GameInfo_Traits:Append(P.TraitsChoices)
    UI.m_choice_GameInfo_Traits:Thaw()

    dataFilled = true
end

--- One trait's effects, for this tab and for the generals tab.
function P.DumpEffects(key, noAllowedLeader)
    return BiceData.Traits.DumpEffects(key, noAllowedLeader)
end

function P.HandleSelection()
    local selectionString = UI.m_choice_GameInfo_Traits:GetString(
        UI.m_choice_GameInfo_Traits:GetSelection())
    local traitName = BiceData.Translations.KeyFromChoice(selectionString)
    if BiceData.Traits.Get(traitName) == nil then
        return
    end

    UI.m_textCtrl_GameInfo_Traits_Effects:SetValue(BiceData.Traits.DumpEffects(traitName))
    UI.m_textCtrl_GameInfo_Traits_Triggers:SetValue(BiceData.Traits.DumpTriggers(traitName))
end

function P.HandleFilter()
    P.ClearText()

    local filterString = UI.m_textCtrl_GameInfo_Traits_Filter:GetValue()
    if filterString == nil or filterString == "" then
        showChoices(P.TraitsChoices)
        return
    end

    P.TraitsChoicesFiltered = {}
    for _, choice in pairs(P.TraitsChoices) do
        if string.find(string.lower(choice), string.lower(filterString)) then
            table.insert(P.TraitsChoicesFiltered, choice)
        end
    end

    showChoices(P.TraitsChoicesFiltered)
end

function P.ClearText()
    UI.m_panel_GameInfo_Traits:Freeze()
    UI.m_textCtrl_GameInfo_Traits_Effects:Clear()
    UI.m_textCtrl_GameInfo_Traits_Triggers:Clear()
    UI.m_panel_GameInfo_Traits:Thaw()
end

return P
