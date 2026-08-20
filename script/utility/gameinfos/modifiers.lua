-- Modifiers tab.
--
-- Parsing, translation and the effect and trigger dumps live in BiceData.Modifiers,
-- shared with the ImGui utility, so event_modifiers.txt and triggered_modifiers.txt are
-- read once for both. This keeps the wx half: the choice control, its filter and the
-- two text boxes.
--
-- GetTranslation stays on this module because the help tab uses it to name the effects
-- in the national focus table.

local P = {}

P.ModifierChoices = {}
P.ModifierChoicesFiltered = {}

local dataFilled = false

local function showChoices(choices)
    UI.m_choice_GameInfo_Modifiers1:Freeze()
    UI.m_choice_GameInfo_Modifiers1:Clear()
    UI.m_choice_GameInfo_Modifiers1:Append(choices)
    UI.m_choice_GameInfo_Modifiers1:Thaw()

    if UI.m_choice_GameInfo_Modifiers1:GetCount() >= 1 then
        UI.m_choice_GameInfo_Modifiers1:SetSelection(0)
        P.HandleSelection()
    end
end

function P.FillData()
    if dataFilled then
        return
    end

    P.ModifierChoices = BiceData.Modifiers.Choices()

    UI.m_choice_GameInfo_Modifiers1:Freeze()
    UI.m_choice_GameInfo_Modifiers1:Clear()
    UI.m_choice_GameInfo_Modifiers1:Append(P.ModifierChoices)
    UI.m_choice_GameInfo_Modifiers1:Thaw()

    dataFilled = true
end

--- One modifier's raw definition, for the help tab's national focus table.
function P.Get(key)
    return BiceData.Modifiers.Get(key)
end

--- An effect key as the player should read it, for the same table.
function P.GetTranslation(key)
    return BiceData.Modifiers.TranslateEffectKey(key)
end

function P.DumpEffects(selection)
    return BiceData.Modifiers.DumpEffects(selection)
end

function P.DumpTriggers(selection)
    return BiceData.Modifiers.DumpTriggers(selection)
end

function P.HandleSelection()
    local selectionString = UI.m_choice_GameInfo_Modifiers1:GetString(
        UI.m_choice_GameInfo_Modifiers1:GetSelection())
    local modifierIdent = BiceData.Translations.KeyFromChoice(selectionString)

    UI.m_textCtrl_GameInfo_Modifiers_Triggers1:SetValue(BiceData.Modifiers.DumpTriggers(modifierIdent))
    UI.m_textCtrl_GameInfo_Modifiers_Effects1:SetValue(BiceData.Modifiers.DumpEffects(modifierIdent))
end

function P.HandleFilter()
    P.ClearText()

    local filterString = UI.m_textCtrl_GameInfo_Modifiers_Filter:GetValue()
    if filterString == nil or filterString == "" then
        showChoices(P.ModifierChoices)
        return
    end

    P.ModifierChoicesFiltered = {}
    for _, choice in pairs(P.ModifierChoices) do
        if string.find(string.lower(choice), string.lower(filterString)) then
            table.insert(P.ModifierChoicesFiltered, choice)
        end
    end

    showChoices(P.ModifierChoicesFiltered)
end

function P.ClearText()
    UI.m_panel_GameInfo_Modifiers:Freeze()
    UI.m_textCtrl_GameInfo_Modifiers_Triggers1:Clear()
    UI.m_textCtrl_GameInfo_Modifiers_Effects1:Clear()
    UI.m_panel_GameInfo_Modifiers:Thaw()
end

return P
