local P = {}

local gc_counter = 100
local function updateImage(path)
    UI.m_bitmap_GameInfo_UnitModels_Selected:SetBitmap(wx.wxBitmap( path, wx.wxBITMAP_TYPE_ANY ))
    UI.m_bitmap_GameInfo_UnitModels_Selected:Refresh()
    UI.m_bitmap_GameInfo_UnitModels_Selected:Update()

    if gc_counter < 0 then
        Utils.LUA_DEBUGOUT("gc_counter < 0")
        collectgarbage()
        collectgarbage()
        gc_counter = 100
    else
        gc_counter = gc_counter - 1
    end

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
    UI.m_textCtrl_GameInfo_UnitModels_Triggers:SetValue(Utils.Dump(P.UnitModelsData[G_PlayerCountry][unit_type][level]))

    local base_path = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\gfx\\models\\"
    local file_name = unit_type .. "_" .. level .. ".tga"
    if G_PlayerCountry ~= nil then
        local tag = string.upper(G_PlayerCountry)
        local path_a = base_path .. tag .. "_" .. file_name
        local path_b = base_path .. file_name
        local path_c = base_path .. "\\templates\\Unit template.tga"
        if CheckFileExists(path_a) then
            updateImage(path_a)
        elseif CheckFileExists(path_b) then
            updateImage(path_b)
        else
            updateImage(path_c)
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
    UI.m_textCtrl_GameInfo_UnitModels_Triggers:Clear()
    UI.m_panel_GameInfo_UnitModels:Thaw()
end

return P