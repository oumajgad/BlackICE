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