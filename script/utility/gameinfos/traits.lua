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

    local sortedViaMetatable = Utils.PushTablesToEndAndSort(translatedTrait)

    -- push "allowed_leader" back to the top again so its easier to read
    local orderMetaTable = getmetatable(sortedViaMetatable)["order"]
    for k, v in ipairs(orderMetaTable) do
        if v == "allowed_leader" then
            orderMetaTable[v] = nil
        end
    end
    table.insert(orderMetaTable, 1, "allowed_leader")
    return Utils.DumpByMetatableOrder(sortedViaMetatable)
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

    UI.m_choice_GameInfo_Traits:Freeze()
    UI.m_choice_GameInfo_Traits:Clear()
    UI.m_choice_GameInfo_Traits:Append(P.TraitsChoices)
    UI.m_choice_GameInfo_Traits:Thaw()

    mapTriggersToTraits()

    dataFilled = true
end

P.TraitsChoicesFiltered = {}
function P.HandleFilter()
    local filterString = UI.m_textCtrl_GameInfo_Traits_Filter:GetValue()
    if filterString == nil or filterString == "" then   -- Reset to default
        UI.m_choice_GameInfo_Traits:Freeze()
        UI.m_choice_GameInfo_Traits:Clear()
        UI.m_choice_GameInfo_Traits:Append(P.TraitsChoices)
        UI.m_choice_GameInfo_Traits:Thaw()
        return
    end

    P.TraitsChoicesFiltered = {} -- reset the list

    for k, v in pairs(P.TraitsChoices) do
        if string.find(string.lower(v), string.lower(filterString)) then
            table.insert(P.TraitsChoicesFiltered, v)
        end
    end

    table.sort(P.TraitsChoicesFiltered, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_GameInfo_Traits:Freeze()
    UI.m_choice_GameInfo_Traits:Clear()
    UI.m_choice_GameInfo_Traits:Append(P.TraitsChoicesFiltered)
    UI.m_choice_GameInfo_Traits:Thaw()
end

return P