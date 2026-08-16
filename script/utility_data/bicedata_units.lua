-- Unit definitions and their technology upgrades.
--
-- Port of the pure logic in utility/gameinfos/units.lua, with the wx calls removed.
--
-- This is a what-if calculator as much as a viewer: a unit's displayed stats are its
-- base definition plus every applicable tech scaled to its level, and those levels can
-- be adjusted to see what a unit would look like with more research.

BiceData = BiceData or {}
BiceData.Units = {}

-- Present on techs but not a unit stat.
local TECH_KEY_BLACKLIST = { activate = true }

-- Present on units but not worth showing as a stat.
local UNIT_KEY_BLACKLIST = {
    active = true, priority = true, sprite = true,
    available_trigger = true, usable_by = true,
}

local units = nil        -- key -> raw definition
local choices = nil      -- sorted "Translated name [key]"
local unitTechs = nil    -- unit -> tech -> { raw_effects, level, index }

local function buildUnitTechs()
    unitTechs = {}
    for unit in pairs(units) do
        unitTechs[unit] = {}
    end

    -- Techs name the units they upgrade as nested blocks, so the mapping is built by
    -- walking every tech and picking out keys that happen to be unit names.
    local indexes = BiceData.Techs.Indexes()
    for tech, values in pairs(BiceData.Techs.All()) do
        for key, effects in pairs(values) do
            if unitTechs[key] ~= nil then
                unitTechs[key][tech] = {
                    raw_effects = effects,
                    level = BiceData.Techs.PlayerLevel(tech),
                    index = indexes[tech] or 0,
                }
            end
        end
    end
end

local function fillData()
    if units ~= nil then
        return
    end

    units = {}
    local path = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\units"
    for _, file in pairs(GetFilesFromPath(path)) do
        for name, values in pairs(PdxParser.parseFile(path .. "\\" .. file)) do
            units[name] = values
        end
    end

    choices = {}
    for key in pairs(units) do
        table.insert(choices, BiceData.Translations.Choice(key))
    end
    table.sort(choices, function(a, b)
        return string.upper(a) < string.upper(b)
    end)

    buildUnitTechs()
end

--- Sorted "Translated name [key]" for every unit.
function BiceData.Units.Choices()
    fillData()
    return choices
end

--- Raw definition for a unit key, or nil.
function BiceData.Units.Get(key)
    fillData()
    return units[key]
end

--- Techs upgrading a unit, sorted by translated name, as
--- { key = tech, label = "level - Name [tech]", level = n }.
function BiceData.Units.TechList(unit)
    fillData()
    if unitTechs[unit] == nil then
        return {}
    end

    local sorted = {}
    for tech, values in pairs(unitTechs[unit]) do
        table.insert(sorted, { key = tech, level = values.level })
    end

    -- Untranslated techs sort to the end, then alphabetically by internal name.
    table.sort(sorted, function(a, b)
        local nameA = BiceData.Translations.Get(a.key) or ("zzzzz" .. a.key)
        local nameB = BiceData.Translations.Get(b.key) or ("zzzzz" .. b.key)
        return string.upper(nameA) < string.upper(nameB)
    end)

    local res = {}
    for _, entry in ipairs(sorted) do
        table.insert(res, {
            key = entry.key,
            level = entry.level,
            label = entry.level .. " - " .. BiceData.Translations.Choice(entry.key),
        })
    end
    return res
end

--- The unit's model string: every tech level in tech file order, which is how the
--- game itself numbers unit models.
function BiceData.Units.ModelString(unit)
    fillData()
    if unitTechs[unit] == nil then
        return ""
    end

    local sorted = {}
    for tech, values in pairs(unitTechs[unit]) do
        table.insert(sorted, { index = values.index, level = values.level })
    end
    table.sort(sorted, function(a, b) return a.index < b.index end)

    local parts = {}
    for _, entry in ipairs(sorted) do
        table.insert(parts, tostring(entry.level))
    end
    return table.concat(parts, " ")
end

--- Current level assumed for one of a unit's techs.
function BiceData.Units.TechLevel(unit, tech)
    fillData()
    if unitTechs[unit] == nil or unitTechs[unit][tech] == nil then
        return 0
    end
    return unitTechs[unit][tech].level
end

--- Adjusts an assumed tech level, never below zero. Affects the unit's stats.
function BiceData.Units.SetTechLevel(unit, tech, level)
    fillData()
    if unitTechs[unit] == nil or unitTechs[unit][tech] == nil then
        return
    end
    unitTechs[unit][tech].level = math.max(0, math.floor(level))
end

--- Puts every assumed level back to what the selected country has researched.
function BiceData.Units.ResetTechLevels()
    fillData()
    buildUnitTechs()
end

local function mergeTechIntoUnit(stats, techValues)
    local effects = BiceData.Techs.ApplyLevel(table.deepcopy(techValues.raw_effects), techValues.level)
    for key, value in pairs(effects) do
        if TECH_KEY_BLACKLIST[key] == nil then
            if stats[key] == nil then
                stats[key] = value
            elseif type(value) ~= "table" then
                stats[key] = tostring(tonumber(value) + tonumber(stats[key]))
            else
                -- Terrain blocks merge per terrain rather than as a whole.
                for terrain, terrainValue in pairs(value) do
                    if stats[key][terrain] ~= nil then
                        stats[key][terrain] = tostring(tonumber(terrainValue) + tonumber(stats[key][terrain]))
                    else
                        stats[key][terrain] = terrainValue
                    end
                end
            end
        end
    end
    return stats
end

--- The unit's stats with every tech applied at its assumed level.
function BiceData.Units.DumpStats(unit)
    fillData()
    if units[unit] == nil then
        return ""
    end

    local stats = table.deepcopy(units[unit])
    for _, values in pairs(unitTechs[unit] or {}) do
        stats = mergeTechIntoUnit(stats, values)
    end

    local translated = BiceData.Techs.TranslateEffects(stats)
    local sorted = Utils.PushTablesToEndAndSort(translated)

    local order = getmetatable(sorted)["order"]
    for key in pairs(UNIT_KEY_BLACKLIST) do
        local index = table.getIndex(order, key)
        if index ~= nil then
            table.remove(order, index)
            sorted[key] = nil
        end
    end

    return Utils.DumpByMetatableOrder(sorted)
end

--- Effects one tech contributes to a unit at its assumed level.
--- @return text, appliedToStats. At level 0 the effects of level 1 are shown for
---         reference but contribute nothing, which the page has to make clear.
function BiceData.Units.DumpTechEffects(unit, tech)
    fillData()
    if unitTechs[unit] == nil or unitTechs[unit][tech] == nil then
        return "", true
    end

    local values = unitTechs[unit][tech]
    local level = values.level
    if level == 0 then
        return BiceData.Techs.DumpEffectsFor(values.raw_effects, 1), false
    end
    return BiceData.Techs.DumpEffectsFor(values.raw_effects, level), true
end
