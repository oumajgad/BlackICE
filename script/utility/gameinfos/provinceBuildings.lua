local P = {}

P.BuildingsData = {}
local dataFilled = false
function P.FillData()
    if dataFilled then
        return
    end
    local path = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\common\\buildings.txt"
    local res = PdxParser.parseFile(path)
    for building_key, values in pairs(res) do
        P.BuildingsData[building_key] = values
    end
    dataFilled = true
    -- Utils.INSPECT_TABLE(P.BuildingsData)
end

function P.FillwxChoice()
    if not dataFilled then
        P.FillData()
    end
    local buildings = {}

    for building_key, vals in spairs(P.BuildingsData) do
        local choice = "[" .. building_key .. "]"
        local trans = Parsing.GetTranslation(building_key)
        if trans ~= nil then
            choice = trans .. " " .. choice
        end
        -- Utils.LUA_DEBUGOUT(choice)
        table.insert(buildings, choice)
    end
    table.sort(buildings, function(a, b) return a:upper() < b:upper() end)


    UI.m_choice_GameInfo_ProvinceBuildings_Buildings:Freeze()
    UI.m_choice_GameInfo_ProvinceBuildings_Buildings:Clear()
    UI.m_choice_GameInfo_ProvinceBuildings_Buildings:Append(buildings)
    UI.m_choice_GameInfo_ProvinceBuildings_Buildings:Thaw()
end

local SortProvincesByName = function(t,a,b) return t[b]["name"] > t[a]["name"] end
local SortProvincesByBuildingLevel = function(t,a,b) return t[b]["level"] < t[a]["level"] end
function P.FillProvinceList(building_key)
    if G_PlayerCountry == nil then
        UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Append("Please set your country.")
        return
    end
    local countryTag = CCountryDataBase.GetTag(G_PlayerCountry)

    local provinces = {}
    local occupiedProvinces = {}
    for provinceID in countryTag:GetCountry():GetControlledProvinces() do
        -- Utils.LUA_DEBUGOUT(tostring(provinceID))
        local cProvince = CCurrentGameState.GetProvince(provinceID)
        local cBuilding = CBuildingDataBase.GetBuilding(building_key)
        local level = cProvince:GetBuilding(cBuilding):GetMax():Get()
        if level >= 0 then
            local name = Parsing.GetTranslation(tostring(provinceID),"PROV", nil)
            if name == nil then
                name = tostring(provinceID)
            end
            local province = {
                id = provinceID,
                level = level,
                name = name,
            }
            if cProvince:GetOwner() == countryTag then
                provinces[provinceID] = province
            else
                occupiedProvinces[provinceID] = province
            end
        end
    end

    local sortSelection = UI.m_choice_GameInfo_ProvinceBuildings_Sort:GetSelection()
    local sortAlgo = UI.m_choice_GameInfo_ProvinceBuildings_Sort:GetString(sortSelection)
    if sortAlgo == "Name" then
        sortAlgo = SortProvincesByName
    elseif sortAlgo == "Level" then
        sortAlgo = SortProvincesByBuildingLevel
    end

    local sorted = {}
    for i, province in spairs(provinces, sortAlgo) do
        table.insert(sorted, tostring(province.level) .. " - " .. province.name .. " [" .. tostring(province.id) .. "]")
    end
    for i, province in spairs(occupiedProvinces, sortAlgo) do
        table.insert(sorted, tostring(province.level) .. " - " .. province.name .. " [" .. tostring(province.id) .. "]")
    end
    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Append(sorted)
end

function P.HandleSortUpdate()
    P.HandleBuildingSelection()
end

local detailsMetatable = {
    ["order"] = {
        "id",
        "energy",
        "metal",
        "rares",
        "oil",
        "leadership",
        "manpower",
        "supply_pool",
        "fuel_pool",
        "modifiers"
    }
}

local modifiersMetatable = {
    ["order"] = {
        "local_energy",
        "local_metal",
        "local_rares",
        "local_oil",
        "local_ic",
        "local_leadership",
    }
}

function P.FillProvinceDetails(province_id)
    if BiceLib == nil then
        UI.m_textCtrl_GameInfo_ProvinceBuildings_Details:SetValue("Bicelib.dll was not loaded. Can't get province details.")
        return
    end
    local details = BiceLib.GameInfo.getProvinceDetails(tonumber(province_id))
    setmetatable(details, detailsMetatable)
    setmetatable(details["modifiers"], modifiersMetatable)

    details["energy"] = string.format('%.02f',details["energy"] / 1000)
    details["metal"] = string.format('%.02f',details["metal"] / 1000)
    details["rares"] = string.format('%.02f',details["rares"] / 1000)
    details["oil"] = string.format('%.02f',details["oil"] / 1000)
    details["leadership"] = string.format('%.02f',details["leadership"] / 1000)
    details["manpower"] = string.format('%.02f',details["manpower"] / 1000)
    details["supply_pool"] = string.format('%.02f',details["supply_pool"] / 1000)
    details["fuel_pool"] = string.format('%.02f',details["fuel_pool"] / 1000)
    details["modifiers"]["local_energy"] = string.format('%.02f%%', details["modifiers"]["local_energy"] / 10)
    details["modifiers"]["local_metal"] = string.format('%.02f%%', details["modifiers"]["local_metal"] / 10)
    details["modifiers"]["local_rares"] = string.format('%.02f%%', details["modifiers"]["local_rares"] / 10)
    details["modifiers"]["local_oil"] = string.format('%.02f%%', details["modifiers"]["local_oil"] / 10)
    details["modifiers"]["local_ic"] = string.format('%.02f%%', details["modifiers"]["local_ic"] / 10)
    details["modifiers"]["local_leadership"] = string.format('%.02f%%', details["modifiers"]["local_leadership"] / 10)

    local s = Utils.DumpByMetatableOrder(details)
    s = s .. "\nThese are base values!\nModifiers are only local! National and global modifiers are not accounted for here."

    UI.m_textCtrl_GameInfo_ProvinceBuildings_Details:SetValue(s)
end

local function getProvincePositionById(id)
    local count = UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetCount()
    for i = 0, count, 1 do
        local selectionString = UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetString(i)
        local provinceId = Parsing.GetKeyFromChoice(selectionString)
        if id == provinceId then
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
        prevProvinceId = Parsing.GetKeyFromChoice(UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetString(prevProvinceSelection))
    end

    local selection = UI.m_choice_GameInfo_ProvinceBuildings_Buildings:GetSelection()
    if selection == -1 then
        return
    end
    local selectionString = UI.m_choice_GameInfo_ProvinceBuildings_Buildings:GetString(selection)
    local building_key = Parsing.GetKeyFromChoice(selectionString)
    -- Utils.LUA_DEBUGOUT("building_key: " .. building_key)
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
    local selectionString = UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetString(UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetSelection())
    local province_id = Parsing.GetKeyFromChoice(selectionString)
    -- Utils.LUA_DEBUGOUT("province_id: " .. province_id)
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
    if UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:GetCount() >= prevProvinceSelection and prevProvinceSelection ~= -1 then
        UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:ScrollLines(prevProvinceScroll)
        UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:SetSelection(prevProvinceSelection)
        P.HandleProvinceSelection()
    end
    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Thaw()
end

return P
