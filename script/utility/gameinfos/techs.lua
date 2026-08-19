-- Technologies tab.
--
-- Parsing, applying a level to a technology's effects, translating them and the dumps
-- all live in BiceData.Techs, shared with the ImGui utility, so the technology files
-- are read once for both. This keeps the wx half: the choice control, its filter, the
-- level boxes and the two text boxes.
--
-- GetTechModifierValues stays on this module because the statistics collector calls it.

local P = {}

P.TechsChoices = {}
P.TechsChoicesFiltered = {}

local function showChoices(choices)
    UI.m_choice_GameInfo_Techs:Freeze()
    UI.m_choice_GameInfo_Techs:Clear()
    UI.m_choice_GameInfo_Techs:Append(choices)
    UI.m_choice_GameInfo_Techs:Thaw()

    if UI.m_choice_GameInfo_Techs:GetCount() >= 1 then
        UI.m_choice_GameInfo_Techs:SetSelection(0)
        P.HandleSelection()
    end
end

function P.FillData()
    P.TechsChoices = BiceData.Techs.Choices()

    UI.m_choice_GameInfo_Techs:Freeze()
    UI.m_choice_GameInfo_Techs:Clear()
    UI.m_choice_GameInfo_Techs:Append(P.TechsChoices)
    UI.m_choice_GameInfo_Techs:Thaw()
end

--- The player's level in a technology, guarding the keys that only look like ones.
function P.GetPlayerTechLevel(tech)
    return BiceData.Techs.PlayerLevel(tech)
end

--- The technology modifier values the game's Lua API does not expose levels for. Used
--- by the statistics collector.
function P.GetTechModifierValues()
    return BiceData.Techs.ModifierValues()
end

function P.DumpEffects(selection, level)
    return BiceData.Techs.DumpEffects(selection, level)
end

function P.DumpTriggers(selection)
    return BiceData.Techs.DumpRequirements(selection)
end

--- Effects for the units tab, which shows a technology at a level of its own.
function P.DumpEffectsForUnitTab(definition, level)
    return BiceData.Techs.DumpEffectsFor(definition, level)
end

function P.HandleSelection(shownLevelOverride)
    local selectionString = UI.m_choice_GameInfo_Techs:GetString(
        UI.m_choice_GameInfo_Techs:GetSelection())
    local techIdent = BiceData.Translations.KeyFromChoice(selectionString)
    if techIdent == nil then
        return
    end

    local level = 0
    if G_PlayerCountry ~= nil then
        level = BiceData.Techs.PlayerLevel(techIdent)
        UI.m_textCtrl_GameInfo_Techs_PlayerLevel:SetValue(tostring(level))
    end

    -- Shown at the researched level, or at level 1 for one not researched yet: its
    -- effects are still worth reading.
    if shownLevelOverride == nil then
        shownLevelOverride = (level == 0) and 1 or level
    end
    UI.m_textCtrl_GameInfo_Techs_LevelShown:SetValue(tostring(shownLevelOverride))

    UI.m_textCtrl_GameInfo_Techs_Triggers:SetValue(BiceData.Techs.DumpRequirements(techIdent))
    UI.m_textCtrl_GameInfo_Techs_Effects:SetValue(
        BiceData.Techs.DumpEffects(techIdent, shownLevelOverride))
end

function P.HandleFilter()
    P.ClearText()

    local filterString = UI.m_textCtrl_GameInfo_Techs_Filter:GetValue()
    if filterString == nil or filterString == "" then
        showChoices(P.TechsChoices)
        return
    end

    P.TechsChoicesFiltered = {}
    for _, choice in pairs(P.TechsChoices) do
        if string.find(string.lower(choice), string.lower(filterString)) then
            table.insert(P.TechsChoicesFiltered, choice)
        end
    end

    showChoices(P.TechsChoicesFiltered)
end

function P.ClearText()
    UI.m_panel_GameInfo_Tech:Freeze()
    UI.m_textCtrl_GameInfo_Techs_Triggers:Clear()
    UI.m_textCtrl_GameInfo_Techs_Effects:Clear()
    UI.m_panel_GameInfo_Tech:Thaw()
end

return P
