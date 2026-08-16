-- Unit model definitions: which techs a country's unit model requires, and which
-- sprite the game will draw for it.
--
-- Port of the pure logic in utility/gameinfos/unitModels.lua, with the wx image
-- widget removed. Image resolution stays here because it is file lookup rather than
-- rendering: the page is told which file to draw.

BiceData = BiceData or {}
BiceData.UnitModels = {}

local function modPath(relative)
    return "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\" .. relative
end

local models = nil -- tag -> unit type -> level -> { tech -> required level }

local function fillData()
    if models ~= nil then
        return
    end

    models = {}
    local path = modPath("units\\models")
    for _, file in pairs(GetFilesFromPath(path)) do
        -- Model files are named after the country they belong to, e.g. "GER.txt".
        local tag = string.sub(file, 1, 3)
        for name, values in pairs(PdxParser.parseFile(path .. "\\" .. file)) do
            local split = Utils.SplitString(name, ".")
            local unitType, level = split[1], split[2]

            models[tag] = models[tag] or {}
            models[tag][unitType] = models[tag][unitType] or {}
            models[tag][unitType][level] = values
        end
    end
end

--- Sorted "[unit.NN] Translated name" for one country.
--- The level is zero padded so a plain string sort keeps 2 before 10.
function BiceData.UnitModels.Choices(tag)
    fillData()
    if tag == nil or models[tag] == nil then
        return {}
    end

    local choices = {}
    for unitType, levels in pairs(models[tag]) do
        for level in pairs(levels) do
            local padded = level
            if tonumber(level) ~= nil and tonumber(level) < 10 then
                padded = "0" .. level
            end

            local text = "[" .. unitType .. "." .. padded .. "]"
            local translated = BiceData.Translations.Get(tag .. "_" .. unitType .. "_" .. level)
                or BiceData.Translations.Get(unitType)
            if translated ~= nil then
                text = text .. " " .. translated
            end
            table.insert(choices, text)
        end
    end

    table.sort(choices, function(a, b)
        return string.upper(a) < string.upper(b)
    end)
    return choices
end

--- Splits "unit.NN" into its parts, undoing the zero padding used for sorting.
local function splitIdent(ident)
    local split = Utils.SplitString(ident, ".")
    local unitType, level = split[1], split[2]
    if level ~= nil and string.sub(level, 1, 1) == "0" then
        level = string.sub(level, 2)
    end
    return unitType, level
end

--- Techs the model requires, with the country's researched level alongside.
function BiceData.UnitModels.TechList(tag, ident)
    fillData()
    local unitType, level = splitIdent(ident)
    if tag == nil or models[tag] == nil or models[tag][unitType] == nil then
        return {}
    end

    local required = models[tag][unitType][level]
    if required == nil then
        return {}
    end

    local rows = {}
    for tech, requiredLevel in pairs(required) do
        table.insert(rows, {
            key = tech,
            required = requiredLevel,
            researched = BiceData.Techs.PlayerLevel(tech),
        })
    end

    -- Untranslated techs sort to the end, then alphabetically by internal name.
    table.sort(rows, function(a, b)
        local nameA = BiceData.Translations.Get(a.key) or ("zzzzz" .. a.key)
        local nameB = BiceData.Translations.Get(b.key) or ("zzzzz" .. b.key)
        return string.upper(nameA) < string.upper(nameB)
    end)

    for _, row in ipairs(rows) do
        row.label = row.required .. " (" .. row.researched .. ") - " ..
                    BiceData.Translations.Choice(row.key)
    end
    return rows
end

--- Finds the highest numbered sprite at or below \p level, because the game falls
--- back to an earlier model's image when a level has none of its own.
local function latestImage(basePath, prefix, unitType, level)
    local found, exact = nil, false
    for i = 0, tonumber(level) or 0 do
        local path = basePath .. prefix .. unitType .. "_" .. tostring(i) .. ".tga"
        if CheckFileExists(path) then
            found = path
            exact = (i == tonumber(level))
        end
    end
    return found, exact
end

--- The sprite the game will draw, and why.
--- @return path, status
function BiceData.UnitModels.Image(tag, ident)
    fillData()
    local unitType, level = splitIdent(ident)
    if tag == nil or unitType == nil or level == nil then
        return nil, "No model selected"
    end

    local basePath = modPath("gfx\\models\\")

    -- A country specific sprite only wins when it exists for this exact level;
    -- otherwise the generic one is more accurate than an older country sprite.
    local countryPath, countryExact = latestImage(basePath, string.lower(tag) .. "_", unitType, level)
    if countryPath == nil or not countryExact then
        local upperPath, upperExact = latestImage(basePath, string.upper(tag) .. "_", unitType, level)
        if upperPath ~= nil and (countryPath == nil or upperExact) then
            countryPath, countryExact = upperPath, upperExact
        end
    end

    if countryPath ~= nil and countryExact then
        return countryPath, "Country specific (exact level)"
    end

    local genericPath, genericExact = latestImage(basePath, "", unitType, level)
    if genericPath ~= nil then
        return genericPath, genericExact and "Generic (exact level)" or "Generic (fallback level)"
    end

    return nil, "No image"
end
