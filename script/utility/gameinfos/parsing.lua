local P = {}

Parsing = P

local translation_files = {
    '00_historia_events.csv', 'Backstory.csv', 'bi_version.csv', 'BlackIce_Air_ENG.csv', 'BlackIce_Air_FRA.csv',
    'BlackIce_Air_GER.csv', 'BlackIce_Air_ITA.csv', 'BlackIce_Air_JAP.csv', 'BlackICE_Air_SOV.csv',
    'BlackIce_Air_USA.csv', 'BlackIce_Land_AST.csv', 'BlackIce_Land_CAN.csv', 'BlackIce_Land_ENG.csv',
    'BlackIce_Land_FRA.csv', 'BlackIce_Land_GER.csv', 'BlackIce_Land_GER_SS.csv', 'BlackIce_Land_ITA.csv',
    'BlackIce_Land_JAP.csv', 'BlackIce_Land_Other.csv', 'BlackIce_Land_SAF.csv', 'BlackIce_Land_SOV.csv',
    'BlackIce_Land_SPA-SPR.csv', 'BlackIce_Land_USA.csv', 'BlackIce_Naval_ENG.csv', 'BlackIce_Naval_FRA.csv',
    'BlackIce_Naval_GER.csv', 'BlackIce_Naval_ITA.csv', 'BlackIce_Naval_JAP.csv', 'BlackIce_Naval_Minors.csv',
    'BlackIce_Naval_SOV.csv', 'BlackIce_Naval_Techs_ENG.csv', 'BlackIce_Naval_Techs_GER.csv',
    'BlackIce_Naval_Techs_JAP.csv', 'BlackIce_Naval_Techs_USA.csv', 'BlackIce_Naval_USA.csv', 'BlackIce_OOB_AST.csv',
    'BlackIce_OOB_CAN.csv', 'BlackIce_OOB_ENG.csv', 'BlackIce_OOB_FRA.csv', 'BlackIce_OOB_GER.csv',
    'BlackIce_OOB_GER_SS.csv', 'BlackIce_OOB_JAP.csv', 'BlackIce_OOB_Other.csv', 'BlackIce_OOB_SOV.csv',
    'BlackIce_OOB_USA.csv', 'BlackICE_tech_completion_values.csv', 'BlackIce_TUR_Events.csv', 'bookmarks.csv',
    'Build_airbases.csv', 'Colonial_recruiting_events.csv', 'community_map_project.csv', 'Continents.csv',
    'countries.csv', 'Decisions_other.csv', 'diplomacy.csv', 'diplomatic_messages.csv', 'effects.csv', 'espionage.csv',
    'events.csv', 'FRA_new_events.csv', 'frontend.csv', 'ftm_3_02.csv', 'ftm_3_04.csv', 'ftm_3_05.csv', 'ftm_3_06.csv',
    'gold.csv', 'Hotjoin.csv', 'interface.csv', 'ITA_AdditionHQ_Events.csv', 'ITA_new_events.csv', 'JAP_new_events.csv',
    'ledger.csv', 'libik-events.csv', 'messages.csv', 'misc.csv', 'Models.csv', 'Motherland.csv', 'NSM-tech.csv',
    'NSM-Units.csv', 'orders.csv', 'outliner.csv', 'Parties.csv', 'politics.csv', 'province_names.csv', 'Ranks.csv',
    'regions.csv', 'resource_trading.csv', 'rewrittenpavostuff.csv', 'SemperFi.csv', 'sf_2_04.csv',
    'technology-names.csv', 'technology.csv', 'temp.csv', 'tfh.csv', 'tfh_4_0.csv', 'tfh_4_01.csv', 'tfh_4_02.csv',
    'Traits.csv', 'triggers.csv', 'triggersandeffects.csv', 'tutorial.csv', 'units.csv', 'unit_messages.csv', 'v1.csv',
    'v2.1.csv', 'v2.csv', 'v3.csv', 'v4.csv', 'Wargoals.csv', 'website.csv', 'zDD-Decisions.csv', 'zDD-events.csv',
    'zDD-events_new.csv', 'zDD-Flags.csv', 'zDD-misc.csv', 'zDD-Puppets.csv', 'zDD-tech.csv', 'zDD-Unit.csv'
}

P.TranslationTable = nil
local function createTranslationTable()
    P.TranslationTable = {}
    for i, file in pairs(translation_files) do
        local path = "tfh\\mod\\BlackICE " .. UI.version .. "\\localisation\\" .. file
        local temp = CsvParser.parseFile(path)
        for k, v in pairs(temp) do
            P.TranslationTable[k] = v
        end
    end
end

local function mapTriggersToTraits()
    local triggersList = PdxParser.parseFileWithList("tfh\\mod\\BlackICE " .. UI.version .. "\\common\\gainable_traits.txt")
    triggersList = triggersList[1]
    for k, v in pairs(triggersList) do
        if P.TraitsTriggers[v["trait"]] == nil then
            P.TraitsTriggers[v["trait"]] = {}
        end
        table.insert(P.TraitsTriggers[v["trait"]], v)
        table.removeEntryByKey(v, "trait")
    end
end

P.Traits = {}
P.TraitsChoices = {}
P.TraitsTriggers = {}
local traitsFilled = false
function P.FillTraits()
    if traitsFilled then
        return
    end
    if P.TranslationTable == nil then
        createTranslationTable()
    end
	P.Traits = PdxParser.parseFile("tfh\\mod\\BlackICE " .. UI.version .. "\\common\\traits.txt")
    for k, v in pairs(P.Traits) do
        local trans = P.TranslationTable[k]
        if trans ~= nil then
            table.insert(P.TraitsChoices, trans .. " (" .. k .. ")")
        else
            table.insert(P.TraitsChoices, "(" .. k .. ")")
        end
    end
    table.sort(P.TraitsChoices)
    UI.m_choice_Traits:Clear()
    UI.m_choice_Traits:Append(P.TraitsChoices)

    mapTriggersToTraits()

    traitsFilled = true
end

function P.GetTraitFromChoice(choice)
    local start = string.find(choice, "%(")
    local stop = string.find(choice, "%)")
    if start ~= nil and stop ~= nil then
        return choice:sub(start + 1, stop - 1)
    end
    return choice
end

return Parsing