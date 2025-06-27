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

    local sorted = {}
    for i, province in spairs(provinces, SortProvincesByName) do
        table.insert(sorted, tostring(province.level) .. " - " .. province.name .. " [" .. tostring(province.id) .. "]")
    end
    for i, province in spairs(occupiedProvinces, SortProvincesByName) do
        table.insert(sorted, tostring(province.level) .. " - " .. province.name .. " [" .. tostring(province.id) .. "]")
    end
    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Append(sorted)
end

function P.HandleBuildingSelection()
    local selectionString = UI.m_choice_GameInfo_ProvinceBuildings_Buildings:GetString(UI.m_choice_GameInfo_ProvinceBuildings_Buildings:GetSelection())
    local building_key = Parsing.GetKeyFromChoice(selectionString)
    -- Utils.LUA_DEBUGOUT("building_key: " .. building_key)
    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Freeze()
    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Clear()
    if building_key ~= nil then
        P.FillProvinceList(building_key)
    end

    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Thaw()
end


function P.ClearText()
    UI.m_panel_GameInfo_ProvinceBuildings:Freeze()
    UI.m_listBox_GameInfo_ProvinceBuildings_Provinces:Clear()
    UI.m_textCtrl_GameInfo_ProvinceBuildings_Details:Clear()
    UI.m_panel_GameInfo_ProvinceBuildings:Thaw()
end

function P.Refresh()
    P.ClearText()
    P.HandleBuildingSelection()
end

return P