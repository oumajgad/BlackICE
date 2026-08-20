-- Units tab.
--
-- Parsing, the unit to technology mapping, the model string and the stat and effect
-- dumps live in BiceData.Units, shared with the ImGui utility. This keeps the wx half:
-- the choice control, its filter, the tech list and the text boxes.
--
-- The edited technology levels live in the provider too, so a level nudged here and a
-- level nudged in the ImGui utility are the same number.

local P = {}

P.UnitsChoices = {}
P.UnitsChoicesFiltered = {}

local selected_unit_name = nil
local selected_tech_key = nil

local function showChoices(choices)
    UI.m_choice_GameInfo_Units_1:Freeze()
    UI.m_choice_GameInfo_Units_1:Clear()
    UI.m_choice_GameInfo_Units_1:Append(choices)
    UI.m_choice_GameInfo_Units_1:Thaw()
end

function P.FillData()
    P.UnitsChoices = BiceData.Units.Choices()
end

function P.UpdateChoices()
    P.UnitsChoices = BiceData.Units.Choices()
    showChoices(P.UnitsChoices)
end

--- Kept because the utility calls it; the mapping is the provider's now.
function P.BuildUnitsToTechsMapping()
    BiceData.Units.ResetTechLevels()
end

function P.BuildTechList(unit)
    local res = {}
    for _, entry in ipairs(BiceData.Units.TechList(unit)) do
        table.insert(res, entry.label)
    end

    UI.m_listBox_GameInfo_Units_Techs:Clear()
    UI.m_listBox_GameInfo_Units_Techs:Append(res)
    P.BuildModelString(unit)
end

function P.BuildModelString(unit)
    UI.m_textCtrl_GameInfo_Units_Model:SetValue(BiceData.Units.ModelString(unit))
end

function P.HandleUnitSelection()
    local selection = UI.m_choice_GameInfo_Units_1:GetString(UI.m_choice_GameInfo_Units_1:GetSelection())
    local unit = BiceData.Translations.KeyFromChoice(selection)
    if unit == nil then
        return
    end

    selected_unit_name = unit
    P.BuildTechList(unit)
    P.DumpUnitStats()
    UI.m_textCtrl_GameInfo_Units_Tech_Effects:Clear()
end

function P.DumpUnitStats()
    if selected_unit_name == nil then
        return
    end
    UI.m_textCtrl_GameInfo_Units_Stats:SetValue(BiceData.Units.DumpStats(selected_unit_name))
end

function P.HandleTechSelection()
    local _selection = UI.m_listBox_GameInfo_Units_Techs:GetSelection()
    if _selection < 0 or selected_unit_name == nil then
        return
    end

    local selection = UI.m_listBox_GameInfo_Units_Techs:GetString(_selection)
    selected_tech_key = BiceData.Translations.KeyFromChoice(selection)

    -- The provider says whether the effects shown are actually applied: a technology at
    -- level 0 still has effects worth reading, they are just not in the unit's stats.
    local effects, applied = BiceData.Units.DumpTechEffects(selected_unit_name, selected_tech_key)
    if not applied then
        effects = "NOT APPLIED - the unit does not have this technology yet\n\n" .. effects
    end
    UI.m_textCtrl_GameInfo_Units_Tech_Effects:SetValue(effects)
end

function P.HandleFilter()
    P.ClearText()

    local filterString = UI.m_textCtrl_GameInfo_Units_Filter:GetValue()
    if filterString == nil or filterString == "" then
        showChoices(P.UnitsChoices)
        if UI.m_choice_GameInfo_Units_1:GetCount() >= 1 then
            UI.m_choice_GameInfo_Units_1:SetSelection(0)
            P.HandleUnitSelection()
        end
        return
    end

    P.UnitsChoicesFiltered = {}
    for _, choice in pairs(P.UnitsChoices) do
        if string.find(string.lower(choice), string.lower(filterString)) then
            table.insert(P.UnitsChoicesFiltered, choice)
        end
    end

    showChoices(P.UnitsChoicesFiltered)
    if UI.m_choice_GameInfo_Units_1:GetCount() >= 1 then
        UI.m_choice_GameInfo_Units_1:SetSelection(0)
        P.HandleUnitSelection()
    end
end

--- Rebuilds the tab while holding the list where it was, so nudging a level does not
--- scroll the list back to the top.
local function rebuildKeepingPosition(work)
    UI.m_panel_GameInfo_Units:Freeze()

    local selection_int = UI.m_listBox_GameInfo_Units_Techs:GetSelection()
    local scrollpos = UI.m_listBox_GameInfo_Units_Techs:GetScrollPos(wx.wxVERTICAL)

    work()
    P.HandleUnitSelection()

    UI.m_listBox_GameInfo_Units_Techs:ScrollLines(scrollpos)
    UI.m_listBox_GameInfo_Units_Techs:SetSelection(selection_int)

    P.HandleTechSelection()
    UI.m_panel_GameInfo_Units:Thaw()
end

function P.ChangeTechLevel(change)
    if selected_tech_key == nil or selected_unit_name == nil then
        return
    end

    rebuildKeepingPosition(function()
        local current = BiceData.Units.TechLevel(selected_unit_name, selected_tech_key)
        BiceData.Units.SetTechLevel(selected_unit_name, selected_tech_key, current + change)
    end)
end

function P.ResetTechLevels()
    rebuildKeepingPosition(BiceData.Units.ResetTechLevels)
end

function P.ClearText()
    UI.m_panel_GameInfo_Units:Freeze()
    UI.m_listBox_GameInfo_Units_Techs:Clear()
    UI.m_textCtrl_GameInfo_Units_Stats:Clear()
    UI.m_textCtrl_GameInfo_Units_Tech_Effects:Clear()
    UI.m_textCtrl_GameInfo_Units_Model:Clear()
    UI.m_panel_GameInfo_Units:Thaw()
end

return P
