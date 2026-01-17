local P = {}

local gc_counter = 100
local function updateImage(path)
    UI.m_bitmap_GameInfo_UnitModels_Selected:SetBitmap(wx.wxBitmap( path, wx.wxBITMAP_TYPE_ANY ))
    UI.m_bitmap_GameInfo_UnitModels_Selected:Refresh()
    UI.m_bitmap_GameInfo_UnitModels_Selected:Update()

    if gc_counter < 0 then
        -- Utils.LUA_DEBUGOUT("gc_counter < 0")
        collectgarbage()
        collectgarbage()
        gc_counter = 100
    else
        gc_counter = gc_counter - 1
    end
    UI.m_panel_GameInfo_UnitModels:Layout()
end

-- Check for previous models since the game will use them if an explicit image is missing for later levels
local function getLatestModelImage(base_path, unit_type, _level)
    local res = nil
    local is_exact_level = false
    local level = tonumber(_level)
    for i=0, tonumber(level) do
        local path = base_path .. unit_type .. "_" .. tostring(i) .. ".tga"
        if CheckFileExists(path) then
            res = path
            if i == level then
                is_exact_level = true
            end
        end
    end
    return res, is_exact_level
end

local function getLatestCountrySpecificModelImage(base_path, _tag, unit_type, _level)
    local res = nil
    local is_exact_level = false
    local tag_lower = string.lower(_tag) .. "_"
    local tag_upper = string.upper(_tag) .. "_"
    local level = tonumber(_level)
    for i=0, level do
        local path = base_path .. tag_lower .. unit_type .. "_" .. tostring(i) .. ".tga"
        if CheckFileExists(path) then
            res = path
            if i == level then
                is_exact_level = true
            end
        end
        path = base_path .. tag_upper .. unit_type .. "_" .. tostring(i) .. ".tga"
        if CheckFileExists(path) then
            res = path
            if i == level then
                is_exact_level = true
            end
        end
    end
    return res, is_exact_level
end

P.UnitModelsData = {}
local dataFilled = false
function P.FillData()
    if dataFilled then
        return
    end

    local path = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\units\\models"
    for i, file in pairs(GetFilesFromPath(path)) do
        local res = PdxParser.parseFile(path .. "\\" .. file)
        local tag = string.sub(file, 1, 3)
        for name, values in pairs(res) do
            local split = Utils.SplitString(name, ".")
            local unit_type = split[1]
            local level = split[2]
            if P.UnitModelsData[tag] == nil then
                P.UnitModelsData[tag] = {}
            end
            if P.UnitModelsData[tag][unit_type] == nil then
                P.UnitModelsData[tag][unit_type] = {}
            end
            P.UnitModelsData[tag][unit_type][level] = values
        end
    end
end

P.UnitModelsChoices = {}
P.UnitModelsChoicesFiltered = {}
function P.HandleSelection()
    local selectionString = UI.m_choice_GameInfo_UnitModels_1:GetString(UI.m_choice_GameInfo_UnitModels_1:GetSelection())
    local modelIdent = Parsing.GetKeyFromChoice(selectionString)
    local split = Utils.SplitString(modelIdent, ".")
    local unit_type = split[1]
    local level = split[2]
    if string.sub(level, 1, 1) == "0" then -- remove the leading 0 we inserted for sorting purposes
        level = string.sub(level, 2, 2)
    end

    -- Build Tech list
    local techlist = {}
    local techs = P.UnitModelsData[G_PlayerCountry][unit_type][level]
    local translationTable = Parsing.GetTranslationTable()
    local sort_by_name = function(t,a,b)
        -- Sorts by translated name, if not found places them at the end and sorts by internal name
        local temp_a = translationTable[a]
        local temp_b = translationTable[b]
        if temp_a == nil then temp_a = "zzzzz" .. a end
        if temp_b == nil then temp_b = "zzzzz" .. b end
        return string.upper(temp_b) > string.upper(temp_a)
    end
    for tech, tech_level in spairs(techs, sort_by_name) do
        local trans = translationTable[tech]
        if trans ~= nil then
            table.insert(techlist, tech_level .. " - " .. trans .. " [" .. tech .. "]")
        else
            table.insert(techlist, tech_level .. " - " .. "[" .. tech .. "]")
        end
    end

    UI.m_listBox_GameInfo_UnitModels_Techs:Clear()
    UI.m_listBox_GameInfo_UnitModels_Techs:Append(techlist)

    -- Get Model Image
    local base_path = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\gfx\\models\\"
    if G_PlayerCountry ~= nil then
        local path_country_specific, is_exact_country = getLatestCountrySpecificModelImage(base_path, G_PlayerCountry, unit_type, level)
        local path_generic, is_exact_generic = getLatestModelImage(base_path, unit_type, level)
        local path_blank = base_path .. "\\templates\\Unit template.tga"

        if path_country_specific ~= nil and is_exact_country then
            updateImage(path_country_specific)
            UI.m_textCtrl_GameInfo_UnitModels_Status:SetValue("Country Specific (exact level)")
        elseif path_generic ~= nil then
            updateImage(path_generic)
            if is_exact_generic then
                UI.m_textCtrl_GameInfo_UnitModels_Status:SetValue("Generic (exact level)")
            else
                UI.m_textCtrl_GameInfo_UnitModels_Status:SetValue("Generic (fallback level)")
            end
        else
            updateImage(path_blank)
            UI.m_textCtrl_GameInfo_UnitModels_Status:SetValue("No Image")
        end
    end
end

function P.BuildCountryChoices(playerTag)
    if not dataFilled then
        P.FillData()
    end

    P.UnitModelsChoices = {}
    for unit, levels in pairs(P.UnitModelsData[playerTag]) do
        for _level, values in pairs(levels) do
            local level = _level
            if tonumber(_level) < 10 then
                level = "0" .. level -- prepend 0 so it can be sorted more easily later
            end
            local s = "[" .. unit .. "." .. level .. "]"
            local trans = Parsing.GetTranslation(G_PlayerCountry .. "_" .. unit .. "_" .. _level)
            if trans == nil then
                trans =  Parsing.GetTranslation(unit)
            end
            if trans ~= nil then
                s = s .. " " .. trans
            end
            table.insert(P.UnitModelsChoices, s)
        end
    end

    table.sort(P.UnitModelsChoices, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_GameInfo_UnitModels_1:Freeze()
    UI.m_choice_GameInfo_UnitModels_1:Clear()
    UI.m_choice_GameInfo_UnitModels_1:Append(P.UnitModelsChoices)
    UI.m_choice_GameInfo_UnitModels_1:Thaw()
end

function P.HandleFilter()
    P.ClearText()
    local filterString = UI.m_textCtrl_GameInfo_UnitModels_Filter:GetValue()
    if filterString == nil or filterString == "" then   -- Reset to default
        UI.m_choice_GameInfo_UnitModels_1:Freeze()
        UI.m_choice_GameInfo_UnitModels_1:Clear()
        UI.m_choice_GameInfo_UnitModels_1:Append(P.UnitModelsChoices)
        UI.m_choice_GameInfo_UnitModels_1:Thaw()
        if UI.m_choice_GameInfo_UnitModels_1:GetCount() >= 1 then
            UI.m_choice_GameInfo_UnitModels_1:SetSelection(0)
            P.HandleSelection()
        end
        return
    end

    P.UnitModelsChoicesFiltered = {} -- reset the list

    for k, v in pairs(P.UnitModelsChoices) do
        if string.find(string.lower(v), string.lower(filterString)) then
            table.insert(P.UnitModelsChoicesFiltered, v)
        end
    end

    table.sort(P.UnitModelsChoicesFiltered, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_GameInfo_UnitModels_1:Freeze()
    UI.m_choice_GameInfo_UnitModels_1:Clear()
    UI.m_choice_GameInfo_UnitModels_1:Append(P.UnitModelsChoicesFiltered)
    UI.m_choice_GameInfo_UnitModels_1:Thaw()
    if UI.m_choice_GameInfo_UnitModels_1:GetCount() >= 1 then
        UI.m_choice_GameInfo_UnitModels_1:SetSelection(0)
        P.HandleSelection()
    end
end

function P.ClearText()
    UI.m_panel_GameInfo_UnitModels:Freeze()
    UI.m_listBox_GameInfo_UnitModels_Techs:Clear()
    UI.m_panel_GameInfo_UnitModels:Thaw()
end

return P