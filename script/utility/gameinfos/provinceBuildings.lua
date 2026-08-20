-- Province buildings tab.
--
-- The building list, the walk over the country's provinces and the province details all
-- live in BiceData.ProvinceBuildings, shared with the ImGui utility. This keeps the wx
-- half: the two lists, the sort choice, and holding the selection across a refresh.

local P = {}

function P.FillData()
    -- Parsing happens in the provider, on demand. Kept because the utility calls it.
    BiceData.ProvinceBuildings.Choices()
end

function P.FillwxChoice()
    UI.m_choice_GameInfo_ProvinceBuildings_Buildings:Freeze()
    UI.m_choice_GameInfo_ProvinceBuildings_Buildings:Clear()
    UI.m_choice_GameInfo_ProvinceBuildings_Buildings:Append(BiceData.ProvinceBuildings.Choices())
    UI.m_choice_GameInfo_ProvinceBuildings_Buildings:Thaw()
end

function P.FillProvinceList(building_key)
    local provinces = BiceData.ProvinceBuildings.Provinces(building_key)
    if #provinces == 0 then
        UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Append("Please set your country.")
        return
    end

    local sortSelection = UI.m_choice_GameInfo_ProvinceBuildings_Sort:GetSelection()
    local sortAlgo = UI.m_choice_GameInfo_ProvinceBuildings_Sort:GetString(sortSelection)

    -- Owned first and occupied after, each sorted by the chosen key, which is how this
    -- list has always read: you build in what you own.
    table.sort(provinces, function(a, b)
        if a.occupied ~= b.occupied then
            return not a.occupied
        end
        if sortAlgo == "Level" and a.level ~= b.level then
            return a.level > b.level
        end
        return string.upper(a.name) < string.upper(b.name)
    end)

    local lines = {}
    for _, province in ipairs(provinces) do
        table.insert(lines, tostring(province.level) .. " - " .. province.name ..
            " [" .. tostring(province.id) .. "]")
    end
    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Append(lines)
end

function P.HandleSortUpdate()
    P.HandleBuildingSelection()
end

function P.FillProvinceDetails(province_id)
    local details, reason = BiceData.ProvinceBuildings.Details(province_id)
    if details == nil then
        UI.m_textCtrl_GameInfo_ProvinceBuildings_Details:SetValue(
            (reason or "No details") .. ". Can't get province details.")
        return
    end

    local lines = { "id: " .. details.id }
    for _, row in ipairs(details.values) do
        table.insert(lines, row.label .. ": " .. row.value)
    end
    if #details.modifiers > 0 then
        table.insert(lines, "")
        table.insert(lines, "Modifiers")
        for _, row in ipairs(details.modifiers) do
            table.insert(lines, row.label .. ": " .. row.value)
        end
    end

    table.insert(lines, "")
    table.insert(lines, "These are base values!")
    table.insert(lines, "Modifiers are only local! National and global modifiers are not accounted for here.")

    UI.m_textCtrl_GameInfo_ProvinceBuildings_Details:SetValue(table.concat(lines, "\n"))
end

local function getProvincePositionById(id)
    local count = UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetCount()
    for i = 0, count, 1 do
        local selectionString = UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetString(i)
        if BiceData.Translations.KeyFromChoice(selectionString) == id then
            return i
        end
    end
    return nil
end

function P.HandleBuildingSelection()
    local prevProvinceSelection = UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetSelection()
    local prevProvinceScroll = UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetScrollPos(wx.wxVERTICAL)
    local prevProvinceId = nil
    if prevProvinceSelection > 0 then
        prevProvinceId = BiceData.Translations.KeyFromChoice(
            UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetString(prevProvinceSelection))
    end

    local selection = UI.m_choice_GameInfo_ProvinceBuildings_Buildings:GetSelection()
    if selection == -1 then
        return
    end
    local selectionString = UI.m_choice_GameInfo_ProvinceBuildings_Buildings:GetString(selection)
    local building_key = BiceData.Translations.KeyFromChoice(selectionString)

    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Freeze()
    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Clear()
    if building_key ~= nil then
        P.FillProvinceList(building_key)
    end

    if prevProvinceId ~= nil then
        local prevProvincePosition = getProvincePositionById(prevProvinceId)
        UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:ScrollLines(prevProvinceScroll)
        UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:SetSelection(prevProvincePosition)
        P.HandleProvinceSelection()
    end

    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Thaw()
end

function P.HandleProvinceSelection()
    local selectionString = UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetString(
        UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetSelection())
    local province_id = BiceData.Translations.KeyFromChoice(selectionString)

    UI.m_textCtrl_GameInfo_ProvinceBuildings_Details:Freeze()
    UI.m_textCtrl_GameInfo_ProvinceBuildings_Details:Clear()
    if province_id ~= nil then
        P.FillProvinceDetails(province_id)
    end
    UI.m_textCtrl_GameInfo_ProvinceBuildings_Details:Thaw()
end

function P.ClearText()
    UI.m_panel_GameInfo_ProvinceBuildings:Freeze()
    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Clear()
    UI.m_textCtrl_GameInfo_ProvinceBuildings_Details:Clear()
    UI.m_panel_GameInfo_ProvinceBuildings:Thaw()
end

function P.Refresh()
    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Freeze()
    local prevProvinceSelection = UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetSelection()
    local prevProvinceScroll = UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetScrollPos(wx.wxVERTICAL)

    P.ClearText()
    P.HandleBuildingSelection()

    if UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetCount() >= prevProvinceSelection
        and prevProvinceSelection ~= -1 then
        UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:ScrollLines(prevProvinceScroll)
        UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:SetSelection(prevProvinceSelection)
        P.HandleProvinceSelection()
    end
    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Thaw()
end

return P
