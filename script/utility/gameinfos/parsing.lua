local P = {}

Parsing = P

local translationFiles = {
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

local translationTable = nil
local function createTranslationTable()
    translationTable = {}
    for i, file in pairs(translationFiles) do
        local path = "tfh\\mod\\BlackICE " .. UI.version .. "\\localisation\\" .. file
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

function P.GetTranslation(key, prefix, postfix)
    if prefix == nil then
        prefix = ""
    end
    if postfix == nil then
        postfix = ""
    end
    local translations = P.GetTranslationTable()
    local res = translations[prefix .. key .. postfix]
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
P.Modifiers = require('modifiers')
P.UnitConversions = require('unitConversion')
return Parsing