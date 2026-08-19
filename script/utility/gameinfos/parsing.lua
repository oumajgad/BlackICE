-- The wx utility's parsing layer.
--
-- Almost nothing is parsed here any more: the game info tabs read from BiceData, which
-- the ImGui utility uses as well, so the mod's files are read once rather than once per
-- utility. What is left is the translation lookup this utility calls by its old names,
-- and the tabs BiceData has no counterpart for - flags, variables, active event
-- modifiers and the inspector, whose ImGui versions are written in C++ instead.

local P = {}

Parsing = P

--- The whole localisation table. Parsed and cached by BiceData.Translations.
function P.GetTranslationTable()
    return BiceData.Translations.GetTable()
end

--- The translation for a key, or nil. Prefix and suffix are optional.
function P.GetTranslation(key, prefix, suffix)
    return BiceData.Translations.Get(key, prefix, suffix)
end

--- Choices read "Translated name [key]"; this gets the key back out.
function P.GetKeyFromChoice(choice)
    return BiceData.Translations.KeyFromChoice(choice)
end

--- Lists regions with no translation, for whoever is checking the localisation.
function P.DoRegionsthing()
    local regionsData = PdxParser.parseFile("tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\map\\region.txt")
    local missing = {}
    for name, provinces in pairs(regionsData) do
        if P.GetTranslation(name) == nil and table.getLength(provinces) > 6 then
            table.insert(missing, name)
        end
    end
    Utils.INSPECT_TABLE(missing)
end

-- Thin wrappers over BiceData: the wx controls, with the data coming from there.
P.Traits = require('traits')
P.Generals = require('generals')
P.Techs = require('techs')
P.Units = require('units')
P.UnitModels = require('unitModels')
P.Modifiers = require('modifiers')
P.ProvinceBuildings = require('provinceBuildings')

-- No BiceData counterpart: these read live game state through BiceLib, and the ImGui
-- utility does the same in C++ rather than through a provider.
P.ActiveEventModifiers = require('activeEventModifiers')
P.Flags = require('flags')
P.Vars = require('vars')
P.Inspector = require('inspector')

return Parsing
