-- Traits page for the in-game ImGui utility.
--
-- Data comes from parsing common/traits.txt and common/gainable_traits.txt, so it is
-- static for the session: parsed once, lazily, on the first Collect().
--
-- The effect translation in utility/gameinfos/traits.lua is pure logic with no wx in
-- it, so DumpEffects is reused from there rather than duplicated. require() rather
-- than reaching through Parsing, so this works even with the wx utility disabled.

BiceLibGui = BiceLibGui or {}
BiceLibGui.Traits = {}

local WxTraits = require('traits')

local traitsData = {}
local traitsChoices = {}
local traitsTriggers = {}
local dataFilled = false

local function modPath(file)
    return "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\common\\" .. file
end

-- Same mapping as traits.lua's local mapTriggersToTraits, kept here because that one
-- is local and because it mutates the tables it parses.
local function mapTriggersToTraits()
    traitsTriggers = {}
    local parsed = PdxParser.parseFile(modPath("gainable_traits.txt"))
    local triggersList = parsed ~= nil and parsed["gainable_trait"] or nil
    if triggersList == nil then
        return
    end

    for _, entry in pairs(triggersList) do
        if entry["trait"] ~= nil then
            local name = entry["trait"]
            if traitsTriggers[name] == nil then
                traitsTriggers[name] = {}
            end
            table.insert(traitsTriggers[name], entry)
            table.removeEntryByKey(entry, "trait")
        end
    end
end

local function fillData()
    if dataFilled then
        return
    end

    local translationTable = Parsing.GetTranslationTable()
    traitsData = PdxParser.parseFile(modPath("traits.txt"))
    traitsChoices = {}

    for key in pairs(traitsData) do
        local translated = translationTable[key]
        if translated ~= nil then
            table.insert(traitsChoices, translated .. " [" .. key .. "]")
        else
            table.insert(traitsChoices, "[" .. key .. "]")
        end
    end

    table.sort(traitsChoices, function(a, b)
        return string.upper(a) < string.upper(b)
    end)

    mapTriggersToTraits()
    dataFilled = true
end

local function dumpTriggers(traitName)
    if traitsTriggers[traitName] == nil then
        return ""
    end
    local sorted = {}
    for key, value in Utils.OrderedTable(traitsTriggers[traitName]) do
        sorted[key] = value
    end
    return Utils.Dump(sorted)
end

-- Returns the list of "Translated name [key]" choices. Parsing happens on the first
-- call, which is why the page does not poll this.
function BiceLibGui.Traits.Collect()
    local ok, result = pcall(function()
        fillData()
        return { available = true, traits = traitsChoices }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Effects and triggers for one choice string, fetched when the selection changes.
function BiceLibGui.Traits.Details(choice)
    local ok, result = pcall(function()
        fillData()
        local key = Parsing.GetKeyFromChoice(choice)
        local trait = traitsData[key]
        if trait == nil then
            return { available = false, reason = "Unknown trait: " .. tostring(choice) }
        end
        return {
            available = true,
            key = key,
            effects = WxTraits.DumpEffects(trait),
            triggers = dumpTriggers(key),
        }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
