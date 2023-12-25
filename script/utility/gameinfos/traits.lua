local P = {}

local function mapTriggersToTraits()
    local triggersList = PdxParser.parseFile("tfh\\mod\\BlackICE " .. UI.version .. "\\common\\gainable_traits.txt")["gainable_trait"]
    for k, v in pairs(triggersList) do
        if v["trait"] ~= nil then
            if P.TraitsTriggers[v["trait"]] == nil then
                P.TraitsTriggers[v["trait"]] = {}
            end
            table.insert(P.TraitsTriggers[v["trait"]], v)
            table.removeEntryByKey(v, "trait")
        end
    end
end

local function translateTerrainEffects(terrainEffects)
    local res = {}
    for k, v in pairs(terrainEffects) do
        local typeTranslation = Parsing.GetTranslation(v["type"])
        if typeTranslation == nil then
            typeTranslation = v["type"]
        end
        local translatedTerrain = {
            ["type"] = typeTranslation,
            ["value"] = string.format("%.2f", v["value"] * 100) .. "%"
        }
        table.insert(res, translatedTerrain)
    end
    table.sort(res, function (a, b)
        return string.upper(a["type"]) < string.upper(b["type"])
    end)
    return res
end

-- special translations for the terrain effects because the ones used by the game dont fit the utility
local terrainEffectsTranslation = {
    ["terrain_speed"] = "Speed",
    ["terrain_attack"] = "Attack",
    ["terrain_defence"] = "Defence",
}
local function translateTraitEffects(trait)
    local res = {}
    for k, v in pairs(trait) do
        if k ~= "allowed_leader" then
            if type(v) ~= "table" then  -- normal key-value effects
                local trans = Parsing.GetTranslation(string.upper(k), "TRAIT_")
                if trans == nil then
                    trans = k
                end
                res[trans] = Parsing.UnitConversions.GetAndConvertEffect(k, v)
            else -- terrain effects
                local temp = v
                for _k, _v in pairs(v) do -- if there is only 1 terrain the "temp" needs to be converted to a list
                    if type(_v) ~= "table" then
                        temp = { v }
                        break
                    end
                end
                res[terrainEffectsTranslation[k]] = translateTerrainEffects(temp)
            end
        end
    end
    return res
end

local function dumpTriggers(traitName)
    if P.TraitsTriggers[traitName] ~= nil then
        local sortedTriggers = {}
        for k, v in Utils.OrderedTable(P.TraitsTriggers[traitName]) do
            sortedTriggers[k] = v
        end
        return Utils.Dump(sortedTriggers)
    else
        return Utils.Dump({})
    end
end

local function dumpEffects(trait)
    local translatedTrait = {}
    translatedTrait["allowed_leader"] = trait["allowed_leader"]
    for k, v in pairs(translateTraitEffects(trait)) do
        translatedTrait[k] = v
    end

    -- establish order, allowed_leader first, then the terrain stuff
    local order = {"allowed_leader", "Attack", "Defence", "Speed"}
    for k, v in Utils.OrderedTable(translatedTrait) do
        if table.getIndex(order, k) == nil then
            table.insert(order, 2, k)
        end
    end
    return Utils.DumpCustomOrder(translatedTrait, order)
end

function P.HandleSelection(selectionString)
    local traitName = Parsing.GetKeyFromChoice(selectionString)
    local trait = P.TraitsData[traitName]
    if trait ~= nil then
        local s = dumpEffects(trait)
        UI.m_textCtrl_GameInfo_Traits_Effects:SetValue(s)
        s = dumpTriggers(traitName)
        UI.m_textCtrl_GameInfo_Traits_Triggers:SetValue(s)
    end
end

P.TraitsData = {}
P.TraitsChoices = {}
P.TraitsTriggers = {}
local dataFilled = false
function P.FillData()
    if dataFilled then
        return
    end
    local translationTable = Parsing.GetTranslationTable()
	P.TraitsData = PdxParser.parseFile("tfh\\mod\\BlackICE " .. UI.version .. "\\common\\traits.txt")
    for k, v in pairs(P.TraitsData) do
        local trans = translationTable[k]
        if trans ~= nil then
            table.insert(P.TraitsChoices, trans .. " [" .. k .. "]")
        else
            table.insert(P.TraitsChoices, "[" .. k .. "]")
        end
    end
    table.sort(P.TraitsChoices, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_Traits:Freeze()
    UI.m_choice_Traits:Clear()
    UI.m_choice_Traits:Append(P.TraitsChoices)
    UI.m_choice_Traits:Thaw()

    mapTriggersToTraits()

    dataFilled = true
end


return P