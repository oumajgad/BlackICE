-- Localisation lookups and unit conversion.
--
-- Port of the pure parts of utility/gameinfos/parsing.lua and unitConversion.lua.
-- Those live inside the wxWidgets utility and are only reachable once it has been
-- loaded, which made every ImGui page depend on the old UI being enabled.

BiceData = BiceData or {}
BiceData.Translations = {}

local function modPath(relative)
    return "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\" .. relative
end

local translationTable = nil

-- Every localisation csv merged into one key -> text map. Parsed on first use: it is
-- a few hundred kilobytes of csv and most sessions never need it.
function BiceData.Translations.GetTable()
    if translationTable ~= nil then
        return translationTable
    end

    translationTable = {}
    local folder = modPath("localisation")
    for _, file in pairs(GetFilesFromPath(folder)) do
        local parsed = CsvParser.parseFile(folder .. "\\" .. file, ";", 2)
        for key, values in pairs(parsed) do
            translationTable[key] = values[1]
        end
    end
    return translationTable
end

--- Returns nil when there is no localisation for the key.
function BiceData.Translations.Get(key, prefix, suffix)
    prefix = prefix or ""
    suffix = suffix or ""
    return BiceData.Translations.GetTable()[prefix .. key .. suffix]
end

--- Choice strings are "Translated name [key]"; this pulls the key back out.
function BiceData.Translations.KeyFromChoice(choice)
    local first = string.find(choice, "%[")
    local last = string.find(choice, "%]")
    if first ~= nil and last ~= nil then
        return choice:sub(first + 1, last - 1)
    end
    return choice
end

--- "Translated name [key]", or "[key]" when there is no localisation.
function BiceData.Translations.Choice(key)
    local translated = BiceData.Translations.GetTable()[key]
    if translated ~= nil then
        return translated .. " [" .. key .. "]"
    end
    return "[" .. key .. "]"
end

local conversions = nil

--- Applies the per effect multiplier and unit from unitConversion.csv.
function BiceData.Translations.ConvertEffect(key, value)
    if conversions == nil then
        conversions = {}
        local path = modPath("script\\utility\\gameinfos\\unitConversion.csv")
        for effect, values in pairs(CsvParser.parseFile(path, ";")) do
            conversions[effect] = { multiplier = values[1], unit = values[2] }
        end
    end

    local conversion = conversions[key]
    if conversion ~= nil then
        return string.format("%.2f", tostring(value * conversion.multiplier)) .. conversion.unit
    end
    return tostring(value)
end
