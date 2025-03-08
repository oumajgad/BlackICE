local P = {}

Parsing = P

local translationTable = nil
local function createTranslationTable()
    translationTable = {}
    local folder = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\localisation"
    for i, file in pairs(GetFilesFromPath(folder)) do
        local path = folder .. "\\" .. file
        local temp = CsvParser.parseFile(path, ";", 2)
        for k, v in pairs(temp) do
            translationTable[k] = v[1]
        end
    end
end

function P.GetTranslationTable()
    if translationTable == nil then
        createTranslationTable()
    end
    if translationTable ~= nil then
        return translationTable
    end
    return {}
end

-- Get the translation from the locs.
-- May return nil if none was found
function P.GetTranslation(key, prefix, suffix)
    if prefix == nil then
        prefix = ""
    end
    if suffix == nil then
        suffix = ""
    end
    local translations = P.GetTranslationTable()
    local res = translations[prefix .. key .. suffix]
    return res
end

-- Keys will be inside parentheses in the choice elements
function P.GetKeyFromChoice(choice)
    local start = string.find(choice, "%[")
    local stop = string.find(choice, "%]")
    if start ~= nil and stop ~= nil then
        return choice:sub(start + 1, stop - 1)
    end
    return choice
end


P.Traits = require('traits')
P.Generals = require('generals')
P.Techs = require('techs')
P.Units = require('units')
P.Modifiers = require('modifiers')
P.ActiveEventModifiers = require('activeEventModifiers')
P.UnitConversions = require('unitConversion')
P.Flags = require('flags')
P.Vars = require('vars')
return Parsing
