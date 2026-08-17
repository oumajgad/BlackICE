-- Minister buildings: how close each minister is to placing his next building.
--
-- Port of utility/main/minister_buildings.lua, with the wx text controls removed.
--
-- Each building type has a counter variable that ticks up, and a trigger it has to
-- reach before the minister builds. The counters are set by the AI code, so this page
-- only reads them.

BiceData = BiceData or {}
BiceData.MinisterBuildings = {}

-- Listed in the order the wx page showed them: military production first, then
-- infrastructure. The triggers come straight from the AI's own thresholds.
local BUILDINGS = {
    { key = "smallarms_factory",       name = "Small Arms Factory",     trigger = 80 },
    { key = "tank_factory",            name = "Tank Factory",           trigger = 110 },
    { key = "light_aircraft_factory",  name = "Light Aircraft Factory", trigger = 110 },
    { key = "medium_aircraft_factory", name = "Medium Aircraft Factory",trigger = 110 },
    { key = "heavy_aircraft_factory",  name = "Heavy Aircraft Factory", trigger = 110 },
    { key = "small_ship_shipyard",     name = "Small Shipyard",         trigger = 30 },
    { key = "medium_ship_shipyard",    name = "Medium Shipyard",        trigger = 54 },
    { key = "capital_ship_shipyard",   name = "Capital Shipyard",       trigger = 80 },
    { key = "submarine_shipyard",      name = "Submarine Shipyard",     trigger = 110 },
    { key = "heavy_industry",          name = "Heavy Industry",         trigger = 70 },
    { key = "supplies_factory",        name = "Manufacturing (Supply)", trigger = 30 },
    { key = "research_lab",            name = "Research Centers",       trigger = 42 },
    { key = "military_college",        name = "Training Centers",       trigger = 50 },
    { key = "artillery_factory",       name = "Artillery Factory",      trigger = 65 },
    { key = "radar_station",           name = "Radar Station",          trigger = 40 },
    { key = "automotive_factory",      name = "Automotive Factory",     trigger = 54 },
    { key = "resource_buildings",      name = "Resource Mines",         trigger = 54 },
    { key = "rail_terminus",           name = "Railway Terminus",       trigger = 30 },
    { key = "hospital",                name = "Hospital",               trigger = 40 },
}

local function variables()
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return nil, nil
    end

    local country = CCountryDataBase.GetTag(tag):GetCountry()
    if country == nil then
        return nil, nil
    end
    return country:GetVariables(), tag
end

--- Progress towards every minister built building.
function BiceData.MinisterBuildings.Collect()
    local vars, tag = variables()
    if vars == nil then
        return nil, "No country selected"
    end

    local rows = {}
    for index, building in ipairs(BUILDINGS) do
        local count = vars:GetVariable(CString(building.key .. "_variable_count_minister")):Get()
        if count < 0 then
            count = 0
        end

        table.insert(rows, {
            key = building.key,
            name = building.name,
            order = index,
            count = count,
            trigger = building.trigger,
            percent = (count / building.trigger) * 100,
        })
    end

    return { tag = tag, rows = rows }, nil
end
