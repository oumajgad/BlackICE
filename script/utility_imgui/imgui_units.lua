-- Units page for the in-game ImGui utility.
--
-- Parsing, tech merging and translation live in BiceData.Units; this only shapes the
-- data for the overlay.
--
-- The selected unit is remembered here rather than passed to every call. Tech
-- operations need unit + tech + level, and threading all three through the bridge
-- would mean a new call shape per argument combination; the page always selects a
-- unit before touching its techs, so holding it is both simpler and safe.

BiceLibGui = BiceLibGui or {}
BiceLibGui.Units = {}

local selectedUnit = nil

local function details()
    if selectedUnit == nil then
        return { available = false, reason = "No unit selected" }
    end

    local techs = {}
    for _, entry in ipairs(BiceData.Units.TechList(selectedUnit)) do
        table.insert(techs, { key = entry.key, label = entry.label, level = entry.level })
    end

    return {
        available = true,
        key = selectedUnit,
        model = BiceData.Units.ModelString(selectedUnit),
        stats = BiceData.Units.DumpStats(selectedUnit),
        techs = techs,
    }
end

function BiceLibGui.Units.Collect()
    local ok, result = pcall(function()
        return { available = true, units = BiceData.Units.Choices() }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Selects a unit and returns its stats, model string and tech list.
function BiceLibGui.Units.Select(choice)
    local ok, result = pcall(function()
        local key = BiceData.Translations.KeyFromChoice(choice)
        if BiceData.Units.Get(key) == nil then
            return { available = false, reason = "Unknown unit: " .. tostring(choice) }
        end
        selectedUnit = key
        return details()
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Effects one tech contributes to the selected unit at its assumed level.
function BiceLibGui.Units.TechDetails(techChoice)
    local ok, result = pcall(function()
        if selectedUnit == nil then
            return { available = false, reason = "No unit selected" }
        end
        local techKey = BiceData.Translations.KeyFromChoice(techChoice)
        local effects, applied = BiceData.Units.DumpTechEffects(selectedUnit, techKey)
        return {
            available = true,
            key = techKey,
            -- level is what the page is assuming; researched is what the country
            -- actually has, so an adjusted level can be told apart from a real one.
            level = BiceData.Units.TechLevel(selectedUnit, techKey),
            researched = BiceData.Techs.PlayerLevel(techKey),
            applied = applied,
            effects = effects,
        }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Adjusts one tech's assumed level and returns the refreshed unit details: stats,
-- model string and the tech list all change with it.
function BiceLibGui.Units.ChangeTechLevel(techChoice, delta)
    local ok, result = pcall(function()
        if selectedUnit == nil then
            return { available = false, reason = "No unit selected" }
        end
        local techKey = BiceData.Translations.KeyFromChoice(techChoice)
        local current = BiceData.Units.TechLevel(selectedUnit, techKey)
        BiceData.Units.SetTechLevel(selectedUnit, techKey, current + delta)
        return details()
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Puts every assumed level back to what the country has actually researched.
function BiceLibGui.Units.ResetTechLevels()
    local ok, result = pcall(function()
        BiceData.Units.ResetTechLevels()
        return details()
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
