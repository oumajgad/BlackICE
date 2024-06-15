local P = {}

P.UnitsData = nil
P.UnitsChoices = {}
P.UnitsChoicesFiltered = {}
P.UnitsToTechs = {}

local selected_unit_name = nil
local selected_tech = nil

function P.FillData()
    if P.UnitsData ~= nil then
        return
    end
    P.UnitsData = {}
    local path = "tfh\\mod\\BlackICE " .. UI.version .. "\\units"
    for i, file in pairs(GetFilesFromPath(path)) do
        local res = PdxParser.parseFile(path .. "\\" .. file)
        for name, values in pairs(res) do
            P.UnitsData[name] = values
        end
    end
    P.UpdateChoices()
    P.BuildUnitsToTechsMapping()
end

function P.UpdateChoices()
    local translationTable = Parsing.GetTranslationTable()
    for k, v in pairs(P.UnitsData) do
        local trans = translationTable[k]
        if trans ~= nil then
            table.insert(P.UnitsChoices, trans .. " [" .. k .. "]")
        else
            table.insert(P.UnitsChoices, "[" .. k .. "]")
        end
    end

    table.sort(P.UnitsChoices, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_GameInfo_Units_1:Freeze()
    UI.m_choice_GameInfo_Units_1:Clear()
    UI.m_choice_GameInfo_Units_1:Append(P.UnitsChoices)
    UI.m_choice_GameInfo_Units_1:Thaw()
end

function P.HandleFilter()
    UI.m_panel_GameInfo_Units:Freeze()

    selected_unit_name = nil
    selected_tech = nil
    P.ClearText()

    local filterString = UI.m_textCtrl_GameInfo_Units_Filter:GetValue()
    if filterString == nil or filterString == "" then   -- Reset to default
        UI.m_choice_GameInfo_Units_1:Clear()
        UI.m_choice_GameInfo_Units_1:Append(P.UnitsChoices)
        if UI.m_choice_GameInfo_Units_1:GetCount() >= 1 then
            UI.m_choice_GameInfo_Units_1:SetSelection(0)
            P.HandleUnitSelection()
        end
        UI.m_panel_GameInfo_Units:Thaw()
        return
    end

    P.UnitsChoicesFiltered = {} -- reset the list

    for k, v in pairs(P.UnitsChoices) do
        if string.find(string.lower(v), string.lower(filterString)) then
            table.insert(P.UnitsChoicesFiltered, v)
        end
    end

    table.sort(P.UnitsChoicesFiltered, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_GameInfo_Units_1:Clear()
    UI.m_choice_GameInfo_Units_1:Append(P.UnitsChoicesFiltered)
    if UI.m_choice_GameInfo_Units_1:GetCount() >= 1 then
        UI.m_choice_GameInfo_Units_1:SetSelection(0)
        P.HandleUnitSelection()
    end

    UI.m_panel_GameInfo_Units:Thaw()
end

function P.ClearText()
    UI.m_textCtrl_GameInfo_Units_Stats:Clear()
    UI.m_textCtrl_GameInfo_Units_Tech_Effects:Clear()
    UI.m_listBox_GameInfo_Units_Techs:Clear()
end

function P.BuildUnitsToTechsMapping()
    for unit, unit_values in pairs(P.UnitsData) do
        P.UnitsToTechs[unit] = {}
    end
    for tech, tech_values in pairs(Parsing.Techs.TechsData) do
        for tech_unit, tech_unit_effects in pairs(tech_values) do
            if P.UnitsToTechs[tech_unit] ~= nil then
                P.UnitsToTechs[tech_unit][tech] = {
                    raw_effects = tech_unit_effects,
                    level = Parsing.Techs.GetPlayerTechLevel(tech),
                    index = Parsing.Techs.TechsIndexes[tech]
                }
            end
        end
    end
end

function P.HandleUnitSelection()
    local selection = UI.m_choice_GameInfo_Units_1:GetString(UI.m_choice_GameInfo_Units_1:GetSelection())
    local unit = Parsing.GetKeyFromChoice(selection)
    P.BuildTechList(unit)
    selected_unit_name = unit
    P.DumpUnitStats()
    UI.m_textCtrl_GameInfo_Units_Tech_Effects:Clear()
end

function P.BuildTechList(unit)
    local res = {}
    local translationTable = Parsing.GetTranslationTable()
    local sort_by_name = function(t,a,b)
        -- Sorts by translated name, if not found places them at the end and sorts by internal name
        local temp_a = translationTable[a]
        local temp_b = translationTable[b]
        if temp_a == nil then temp_a = "zzzzz" .. a end
        if temp_b == nil then temp_b = "zzzzz" .. b end
        return string.upper(temp_b) > string.upper(temp_a)
    end
    for tech, values in spairs(P.UnitsToTechs[unit], sort_by_name) do
        local level = values.level
        local trans = translationTable[tech]
        if trans ~= nil then
            table.insert(res, level .. " - " .. trans .. " [" .. tech .. "]")
        else
            table.insert(res, level .. " - " .. "[" .. tech .. "]")
        end
    end

    UI.m_listBox_GameInfo_Units_Techs:Clear()
    UI.m_listBox_GameInfo_Units_Techs:Append(res)
    P.BuildModelString(unit)
end

function P.BuildModelString(unit)
    local res = ""
    local sort_by_index = function(t,a,b)
        return t[a].index < t[b].index
    end
    for tech, values in spairs(P.UnitsToTechs[unit], sort_by_index) do
        res = res .. tostring(values.level) .. " "
    end
    UI.m_textCtrl_GameInfo_Units_Model:SetValue(res)
end

function P.HandleTechSelection()
    local _selection = UI.m_listBox_GameInfo_Units_Techs:GetSelection()
    if _selection < 0 then
        return
    end
    local selection = UI.m_listBox_GameInfo_Units_Techs:GetString(_selection)
    local techIdent = Parsing.GetKeyFromChoice(selection)
    local tech = P.UnitsToTechs[selected_unit_name][techIdent]
    selected_tech = {
        name = techIdent,
        values = tech
    }
    local tech_level = tech.level
    if tech.level == 0 then
        tech_level = 1
    end
    local s = Parsing.Techs.DumpEffectsForUnitTab(tech.raw_effects, tech_level)
    if tech.level == 0 then
        s = "! Your tech level is 0.\nEffect for level 1 is shown but not applied to total unit stats.\n" .. s
    end
    UI.m_textCtrl_GameInfo_Units_Tech_Effects:SetValue(s)
end

local tech_key_blacklist = {
    ["activate"] = true
}
local unit_key_blacklist = {
    ["active"] = true,
    ["priority"] = true,
    ["sprite"] = true,
    ["available_trigger"] = true,
    ["usable_by"] = true
}

local function mergeUnitWithTech(unit, tech)
    local tech_effects = Parsing.Techs.ApplyLevelToTech(tech.raw_effects, tech.level)
    for k, v in pairs(tech_effects) do
        if tech_key_blacklist[k] == nil then
            if unit[k] ~= nil then
                if type(v) ~= "table" then
                    unit[k] = tostring(tonumber(v) + tonumber(unit[k]))
                else -- terrain
                    for terrain_stat, stat_value in pairs(v) do
                        if unit[k][terrain_stat] ~= nil then
                            unit[k][terrain_stat] = tostring(tonumber(stat_value) + tonumber(unit[k][terrain_stat]))
                        else
                            unit[k][terrain_stat] = stat_value
                        end
                    end
                end
            else
                unit[k] = v
            end
        end
    end
    return unit
end

function P.BuildUnitStats()
    local unit_stats = table.deepcopy(P.UnitsData[selected_unit_name])
    for tech, values in pairs(P.UnitsToTechs[selected_unit_name]) do
        local tech_values = table.deepcopy(values)
        unit_stats = mergeUnitWithTech(unit_stats, tech_values)
    end
    return unit_stats
end

function P.DumpUnitStats()
    local unit_stats = P.BuildUnitStats()

    local translated = Parsing.Techs.TranslateTechEffect(unit_stats)

    local sortedViaMetatable = Utils.PushTablesToEndAndSort(translated)

    -- sort some values to the top so its easier to read
    local orderMetaTable = getmetatable(sortedViaMetatable)["order"]
    for k, v in pairs(unit_key_blacklist) do
        local index = table.getIndex(orderMetaTable, k)
        if index ~= nil then
            table.remove(orderMetaTable, index)
            sortedViaMetatable[k] = nil
            -- table.insert(orderMetaTable, 1, k)
        end
    end
    local s = Utils.DumpByMetatableOrder(sortedViaMetatable)
    UI.m_textCtrl_GameInfo_Units_Stats:SetValue(s)
end

function P.ChangeTechLevel(change)
    if selected_tech == nil then
        return
    end
    UI.m_panel_GameInfo_Units:Freeze()

    local selection_int = UI.m_listBox_GameInfo_Units_Techs:GetSelection()
    local scrollpos = UI.m_listBox_GameInfo_Units_Techs:GetScrollPos(wx.wxVERTICAL)

    selected_tech.values.level = selected_tech.values.level + change
    P.HandleUnitSelection()

    UI.m_listBox_GameInfo_Units_Techs:ScrollLines(scrollpos)
    UI.m_listBox_GameInfo_Units_Techs:SetSelection(selection_int)

    P.HandleTechSelection()
    UI.m_panel_GameInfo_Units:Thaw()
end

function P.ResetTechLevels()
    UI.m_panel_GameInfo_Units:Freeze()

    local selection_int = UI.m_listBox_GameInfo_Units_Techs:GetSelection()
    local scrollpos = UI.m_listBox_GameInfo_Units_Techs:GetScrollPos(wx.wxVERTICAL)

    P.BuildUnitsToTechsMapping()
    P.HandleUnitSelection()

    UI.m_listBox_GameInfo_Units_Techs:ScrollLines(scrollpos)
    UI.m_listBox_GameInfo_Units_Techs:SetSelection(selection_int)

    P.HandleTechSelection()
    UI.m_panel_GameInfo_Units:Thaw()
end

return P
