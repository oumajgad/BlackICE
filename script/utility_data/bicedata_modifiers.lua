-- Event and triggered modifier definitions.
--
-- Port of the pure logic in utility/gameinfos/modifiers.lua, with the wx calls
-- removed. Parsed lazily and cached for the session.

BiceData = BiceData or {}
BiceData.Modifiers = {}

local SOURCE_FILES = {
    { file = "event_modifiers.txt",     kind = "Event" },
    { file = "triggered_modifiers.txt", kind = "Triggered" },
}

-- These describe when a modifier applies rather than what it does, so they are shown
-- separately from the effects.
local TRIGGER_KEYS = { "potential", "trigger" }

local modifiers = nil -- key -> raw definition
local kinds = nil     -- key -> "Event" / "Triggered"
local choices = nil   -- sorted "Translated name [key]"

local function fillData()
    if modifiers ~= nil then
        return
    end

    modifiers = {}
    kinds = {}
    choices = {}

    for _, source in ipairs(SOURCE_FILES) do
        local path = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\common\\" .. source.file
        for name, values in pairs(PdxParser.parseFile(path)) do
            modifiers[name] = values
            kinds[name] = source.kind
            table.insert(choices, BiceData.Translations.Choice(name))
        end
    end

    table.sort(choices, function(a, b)
        return string.upper(a) < string.upper(b)
    end)
end

-- Modifier keys use a mix of prefixes and suffixes across the localisation files, so
-- several spellings have to be tried before falling back to the raw key.
local SPECIAL_CASES = {
    global_manpower_modifier = "GLOBAL_MANPOWER",
    local_manpower_modifier = "LOCAL_MANPOWER",
    casualty_trickleback = "CASUALTY_TRICKLEBACK_TECH",
}

function BiceData.Modifiers.TranslateEffectKey(key)
    local translated = BiceData.Translations.Get(string.upper(key), "MODIFIER_")
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
    return translated or key
end

--- Sorted "Translated name [key]" for every modifier.
function BiceData.Modifiers.Choices()
    fillData()
    return choices
end

--- Raw definition for a modifier key, or nil.
function BiceData.Modifiers.Get(key)
    fillData()
    return modifiers[key]
end

--- "Event" or "Triggered", or nil for an unknown key.
function BiceData.Modifiers.Kind(key)
    fillData()
    return kinds[key]
end

--- Formatted effect text, with the trigger blocks and the icon removed.
function BiceData.Modifiers.DumpEffects(key)
    fillData()
    if modifiers[key] == nil then
        return ""
    end

    local data = table.deepcopy(modifiers[key])
    for _, triggerKey in ipairs(TRIGGER_KEYS) do
        data[triggerKey] = nil
    end
    data["icon"] = nil

    local translated = {}
    for effect, value in pairs(data) do
        local name = BiceData.Modifiers.TranslateEffectKey(effect)
        if type(value) == "table" then
            -- The game tolerates a key appearing twice in one modifier; the parser
            -- turns that into a list, and the last one is what applies.
            translated[name] = BiceData.Translations.ConvertEffect(effect, value[#value])
        else
            translated[name] = BiceData.Translations.ConvertEffect(effect, value)
        end
    end

    local order = {}
    for name, value in Utils.OrderedTable(translated) do
        if type(value) ~= "table" and table.getIndex(order, name) == nil then
            table.insert(order, name)
        end
    end

    return Utils.DumpCustomOrder(translated, order)
end

--- Formatted text for the potential/trigger blocks.
function BiceData.Modifiers.DumpTriggers(key)
    fillData()
    if modifiers[key] == nil then
        return ""
    end

    local source = table.deepcopy(modifiers[key])
    local data = {}
    for _, triggerKey in ipairs(TRIGGER_KEYS) do
        data[triggerKey] = source[triggerKey]
    end
    return Utils.DumpCustomOrder(data, TRIGGER_KEYS)
end
