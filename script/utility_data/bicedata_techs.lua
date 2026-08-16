-- Technology definitions, level scaled effects and requirements.
--
-- Port of the pure logic in utility/gameinfos/techs.lua, with the wx calls removed.
--
-- Effects are per level values: a tech that gives 0.05 gives 0.25 at level 5, so
-- every number is scaled by the level being shown before it is formatted.

BiceData = BiceData or {}
BiceData.Techs = {}

-- These describe when a tech can be researched rather than what it does, so they are
-- shown separately and stripped out of the effects.
local REQUIREMENT_KEYS = {
    "start_year", "first_offset", "additional_offset", "difficulty",
    "max_level", "change", "research_bonus_from", "allow",
}

-- Shown as they are: flags and hooks rather than numeric effects, so they must not be
-- level scaled or unit converted. Also pulled to the top of the dump.
local RAW_KEYS = {
    stealable = true, can_upgrade = true, on_completion = true,
    activate_building = true, activate_unit = true, is_nuclear = true,
    change = true, max_level = true, difficulty = true, start_year = true,
    first_offset = true, additional_offset = true, listening_station = true,
    has_country_flag = true,
}

-- Terrain effects are plain multipliers rather than anything in unitConversion.csv.
local TERRAIN_KEYS = {
    movement = true, attack = true, defence = true, attrition = true,
}

-- Keys whose localisation cannot be derived by any of the prefix/suffix rules below.
local SPECIAL_CASES = {
    manpower_gain = "GLOBAL_MANPOWER",
    ic_efficiency = "MODIFIER_INDUSTRIAL_EFFICIENCY",
    casualty_trickleback = "CASUALTY_TRICKLEBACK_TECH",
    refinery_efficiency = "MODIFIER_FUEL_CONVERSION",
    energy_to_oil_conversion = "ENERGY_TO_OIL_TECH",
    energy_production = "ENERGY_PROD_TECH",
    metal_production = "METAL_PROD_TECH",
    rares_production = "RARES_PROD_TECH",
    research_efficiency = "RESEARC_EFF_TECH",
    unit_cooperation = "UNIT_COOP_TECH",
    provincial_aa_efficiency = "PROV_AA_TECH",
    default_organisation = "DEFAULT_ORG",
    build_cost_manpower = "BUILD_COST_MP",
}

-- Has no localisation key at all.
local LITERAL_CASES = {
    attack_delay = "Delay between attacks",
}

local techs = nil          -- key -> raw definition
local choices = nil        -- sorted "Translated name [key]"
local indexes = nil        -- key -> position in file order
local modifierValues = nil -- effect -> { tech -> value }

local function translateKey(key)
    local translated = BiceData.Translations.Get(key)
    if translated == nil then
        translated = BiceData.Translations.Get(string.upper(key), "MODIFIER_")
    end
    if translated == nil then
        translated = BiceData.Translations.Get(string.upper(key), nil, "_TECH")
    end
    if translated == nil then
        -- e.g. "air_intercept_eff"
        translated = BiceData.Translations.Get(string.lower(key), nil, "_eff")
    end
    if translated == nil then
        -- e.g. "global_revolt_risk"
        translated = BiceData.Translations.Get(string.upper(key))
    end
    if translated == nil and SPECIAL_CASES[key] ~= nil then
        translated = BiceData.Translations.Get(SPECIAL_CASES[key])
    end
    if translated == nil and LITERAL_CASES[key] ~= nil then
        translated = LITERAL_CASES[key]
    end
    return translated or key
end

local function fillData()
    if techs ~= nil then
        return
    end

    techs = {}
    choices = {}
    indexes = {}

    local index = 0
    local path = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\technologies"
    for _, file in pairs(GetFilesFromPath(path)) do
        -- true: keep file order, which gives a list of single key tables rather than
        -- one merged table, so techs sharing a name across files are not lost.
        local parsed = PdxParser.parseFile(path .. "\\" .. file, true)
        for _, entry in ipairs(parsed) do
            for name, values in pairs(entry) do
                values["folder"] = nil
                techs[name] = values
                -- File order is the order the game writes unit model strings in, so
                -- it has to be preserved even though the choice list is alphabetical.
                indexes[name] = index
                index = index + 1
                table.insert(choices, BiceData.Translations.Choice(name))
            end
        end
    end

    table.sort(choices, function(a, b)
        return string.upper(a) < string.upper(b)
    end)
end

--- Multiplies every number in the tech by the level, recursing into nested blocks.
local function applyLevel(data, level)
    for key, value in pairs(data) do
        if type(value) == "table" then
            data[key] = applyLevel(value, level)
        elseif tonumber(value) ~= nil then
            data[key] = string.format('%.02f', tonumber(value) * level)
        end
    end
    return data
end

local function translateEffects(data)
    local res = {}
    for key, value in pairs(data) do
        local name = translateKey(key)
        if type(value) == "table" then
            res[name] = translateEffects(value)
        elseif TERRAIN_KEYS[key] ~= nil then
            if key == "attrition" then
                -- Already a percentage, unlike the other three.
                res[name] = string.format("%.2f", value) .. "%"
            else
                res[name] = string.format("%.2f", value * 100) .. "%"
            end
        elseif RAW_KEYS[key] ~= nil then
            res[name] = value
        else
            -- The _tech suffix separates these from the identically named modifier
            -- keys, which convert differently.
            res[name] = BiceData.Translations.ConvertEffect(key .. "_tech", value)
        end
    end
    return res
end

--- Sorted "Translated name [key]" for every technology.
function BiceData.Techs.Choices()
    fillData()
    return choices
end

--- Raw definition for a tech key, or nil.
function BiceData.Techs.Get(key)
    fillData()
    return techs[key]
end

--- Every tech definition, for callers that need to scan them (the Units page).
function BiceData.Techs.All()
    fillData()
    return techs
end

--- key -> position in file order. Unit model strings list tech levels in this order.
function BiceData.Techs.Indexes()
    fillData()
    return indexes
end

--- Scales every number in a tech block by a level. Exposed for the Units page, which
--- merges scaled tech effects into a unit's base stats.
function BiceData.Techs.ApplyLevel(data, level)
    return applyLevel(data, level)
end

--- Translates and formats effect keys. Exposed for the Units page, which translates a
--- merged unit + tech table rather than a tech on its own.
function BiceData.Techs.TranslateEffects(data)
    return translateEffects(data)
end

--- The selected country's researched level, 0 outside a game.
function BiceData.Techs.PlayerLevel(key)
    -- Through Players.CurrentTag rather than G_PlayerCountry directly, so this agrees
    -- with the rest of the utility and works before anything visits the Setup page.
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return 0
    end

    local ok, level = pcall(function()
        -- Not every key that looks like a tech is one: unit model definitions carry
        -- marker keys such as divisonal_command_structure_hidden. GetLevel(nil)
        -- dereferences the null inside the game's own code, which pcall cannot catch,
        -- so the lookup has to be checked rather than attempted.
        local technology = CTechnologyDataBase.GetTechnology(key)
        if technology == nil then
            return 0
        end

        local status = CCountryDataBase.GetTag(tag):GetCountry():GetTechnologyStatus()
        return status:GetLevel(technology)
    end)
    return ok and level or 0
end

--- Effect text for a tech, with every value scaled to \p level.
--- Takes the definition rather than a key so the Units page can pass a prepared one.
function BiceData.Techs.DumpEffectsFor(definition, level)
    if definition == nil then
        return ""
    end

    local data = table.deepcopy(definition)
    for _, key in ipairs(REQUIREMENT_KEYS) do
        data[key] = nil
    end
    data = applyLevel(data, level)

    local translated = {}
    for name, value in pairs(translateEffects(data)) do
        translated[name] = value
    end

    local sorted = Utils.PushTablesToEndAndSort(translated)

    -- The raw keys are flags rather than effects, so they read better at the top.
    local order = getmetatable(sorted)["order"]
    for key in pairs(RAW_KEYS) do
        local index = table.getIndex(order, key)
        if index ~= nil then
            table.remove(order, index)
            table.insert(order, 1, key)
        end
    end

    return Utils.DumpByMetatableOrder(sorted)
end

--- Effect text for a tech key at a level.
function BiceData.Techs.DumpEffects(key, level)
    fillData()
    return BiceData.Techs.DumpEffectsFor(techs[key], level or 1)
end

--- The start year, difficulty and prerequisites block.
function BiceData.Techs.DumpRequirements(key)
    fillData()
    if techs[key] == nil then
        return ""
    end

    local source = table.deepcopy(techs[key])
    local data = {}
    for _, requirementKey in ipairs(REQUIREMENT_KEYS) do
        data[requirementKey] = source[requirementKey]
    end
    return Utils.DumpCustomOrder(data, REQUIREMENT_KEYS)
end

--- effect -> { tech -> per level value }, for the handful of modifiers whose tech
--- contribution the game's Lua API does not expose. Used by the AI's CountryModifiers.
function BiceData.Techs.ModifierValues()
    if modifierValues ~= nil then
        return modifierValues
    end
    fillData()

    modifierValues = {
        ic_efficiency = {}, ic_modifier = {}, research_efficiency = {},
        supply_throughput = {}, repair_rate = {}, org_regain = {},
        attack_delay = {}, ic_to_supplies = {}, casualty_trickleback = {},
    }

    for techName, values in pairs(techs) do
        for key, value in pairs(values) do
            if modifierValues[key] ~= nil then
                modifierValues[key][techName] = tonumber(value)
            end
        end
    end
    return modifierValues
end
