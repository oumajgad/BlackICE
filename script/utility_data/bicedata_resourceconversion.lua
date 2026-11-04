-- The player's own resource conversion, for the Resource Conversion page.
--
-- BiceLib's customResourceConversion lets a played country set how much energy it turns
-- into crude oil, and crude oil into fuel, each day, through the country variables below
-- (DaveStuff/luabinaries/bice/BiceLib/BiceLib/Hooks/ResourceConversion.hpp). The covert
-- operation set_resource_conversion and events 1553 to 1555 set the same variables from
-- presets; this page sets any value.
--
-- Every value is in stockpile units, and 0 means off or no limit: a save drops a variable
-- that is exactly 0, so 0 has to mean the same as never set.

BiceData = BiceData or {}
BiceData.ResourceConversion = {}

-- The page's name for each value, and the variable it is kept in. The whitelist is what
-- keeps a mistyped field from quietly making a variable the DLL never reads.
local VARIABLES = {
    usesOil = "zzDsafe_usesCustomOilConversion",
    energyPerDay = "zzDsafe_CustomConversion_energyPerDay",
    energyKeep = "zzDsafe_CustomConversion_energyKeep",
    oilTarget = "zzDsafe_CustomConversion_oilTarget",

    usesFuel = "zzDsafe_usesCustomFuelConversion",
    crudePerDay = "zzDsafe_CustomConversion_crudePerDay",
    crudeKeep = "zzDsafe_CustomConversion_crudeKeep",
    fuelTarget = "zzDsafe_CustomConversion_fuelTarget",
}

--- Each value as the game holds it now, and what the country may convert today.
---
--- `installed` is false when the DLL's patch is not on, in which case the values are
--- shown but do nothing.
function BiceData.ResourceConversion.Collect()
    local vars, tag = BiceData.Country.Variables()
    if vars == nil then
        return nil, "No country selected"
    end

    local data = { tag = tag }
    for field, name in pairs(VARIABLES) do
        data[field] = BiceData.Country.Get(vars, name)
    end

    local capacity = BiceLib.GameInfo.getCountryResourceConversion(tag)
    data.installed = capacity ~= nil
    if capacity ~= nil then
        data.played = capacity.played
        data.oil_rate = capacity.oil_rate
        data.energy_cap = capacity.energy_cap
        data.energy_floor = capacity.energy_floor
        data.crude_cap = capacity.crude_cap
    end
    return data, nil
end

--- Posts one value. A negative one is posted as 0, which the DLL reads as none anyway.
function BiceData.ResourceConversion.Set(field, value)
    local name = VARIABLES[field]
    if name == nil then
        return false, "Unknown field: " .. tostring(field)
    end
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return false, "No country selected"
    end
    if value == nil or value < 0 then
        value = 0
    end
    BiceData.Country.Set(tag, name, value)
    return true, nil
end
