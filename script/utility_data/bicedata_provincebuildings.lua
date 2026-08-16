-- Province buildings: which of the country's provinces have a given building, at what
-- level, and what the selected province produces.
--
-- Port of the pure logic in utility/gameinfos/provinceBuildings.lua.
--
-- Unlike the other Game Info data this is live: building levels change as they are
-- built and provinces change hands, so nothing here is cached beyond the building
-- list itself.

BiceData = BiceData or {}
BiceData.ProvinceBuildings = {}

local buildings = nil -- key -> definition
local choices = nil   -- sorted "Translated name [key]"

local function fillData()
    if buildings ~= nil then
        return
    end

    buildings = PdxParser.parseFile("tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\common\\buildings.txt")

    choices = {}
    for key in pairs(buildings) do
        table.insert(choices, BiceData.Translations.Choice(key))
    end
    table.sort(choices, function(a, b)
        return string.upper(a) < string.upper(b)
    end)
end

--- Sorted "Translated name [key]" for every building.
function BiceData.ProvinceBuildings.Choices()
    fillData()
    return choices
end

--- Every province the country controls that could hold the building, with its level.
--- Occupied provinces are flagged rather than filtered so the page can group them.
function BiceData.ProvinceBuildings.Provinces(buildingKey)
    local tag = BiceData.Players.CurrentTag()
    if tag == nil or buildingKey == nil then
        return {}
    end

    local countryTag = CCountryDataBase.GetTag(tag)
    local country = countryTag:GetCountry()
    if country == nil then
        return {}
    end

    local building = CBuildingDataBase.GetBuilding(buildingKey)
    if building == nil then
        return {}
    end

    local rows = {}
    for provinceId in country:GetControlledProvinces() do
        local province = CCurrentGameState.GetProvince(provinceId)
        if province ~= nil then
            local level = province:GetBuilding(building):GetMax():Get()
            if level >= 0 then
                local name = BiceData.Translations.Get(tostring(provinceId), "PROV")
                    or tostring(provinceId)
                table.insert(rows, {
                    id = tostring(provinceId),
                    name = name,
                    level = level,
                    -- Controlled but not owned: still shown, but after the owned ones.
                    occupied = (province:GetOwner() ~= countryTag),
                })
            end
        end
    end
    return rows
end

-- The order these read best in, rather than alphabetical.
local VALUE_FIELDS = {
    { key = "energy", label = "Energy" },
    { key = "metal", label = "Metal" },
    { key = "rares", label = "Rares" },
    { key = "oil", label = "Oil" },
    { key = "leadership", label = "Leadership" },
    { key = "manpower", label = "Manpower" },
    { key = "supply_pool", label = "Supply pool" },
    { key = "fuel_pool", label = "Fuel pool" },
}

local MODIFIER_FIELDS = {
    { key = "local_energy", label = "Local energy" },
    { key = "local_metal", label = "Local metal" },
    { key = "local_rares", label = "Local rares" },
    { key = "local_oil", label = "Local oil" },
    { key = "local_ic", label = "Local IC" },
    { key = "local_leadership", label = "Local leadership" },
}

--- Base production and local modifiers for one province.
function BiceData.ProvinceBuildings.Details(provinceId)
    if BiceLib == nil then
        return nil, "BiceLib.dll was not loaded"
    end

    local details = BiceLib.GameInfo.getProvinceDetails(tonumber(provinceId))
    if details == nil then
        return nil, "No details for province " .. tostring(provinceId)
    end

    local values = {}
    for _, field in ipairs(VALUE_FIELDS) do
        local raw = details[field.key]
        if raw ~= nil then
            -- Fixed point: the game stores 12.05 as 12050.
            table.insert(values, { label = field.label, value = string.format('%.02f', raw / 1000) })
        end
    end

    local modifiers = {}
    if details["modifiers"] ~= nil then
        for _, field in ipairs(MODIFIER_FIELDS) do
            local raw = details["modifiers"][field.key]
            if raw ~= nil then
                -- Modifiers are tenths of a percent.
                table.insert(modifiers, { label = field.label, value = string.format('%.02f%%', raw / 10) })
            end
        end
    end

    return { id = tostring(details["id"] or provinceId), values = values, modifiers = modifiers }, nil
end
