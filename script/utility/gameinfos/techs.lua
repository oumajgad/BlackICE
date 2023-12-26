local P = {}

local techsFiles = {
    '00_unique_unit_techs.txt', '01_Aircraft Technologies.txt', '01_Armor Technologies.txt', '01_ArtilleryTechnologies.txt',
    '01_Infantry Technologies.txt', '01_Special_Forces Technologies.txt', '02_Naval_Technology_TP_LC_AS.txt', 'Aircraftsystems Technologies.txt',
    'Aircraftz Doctrines.txt', 'Aircraft_Armament Technologies.txt', 'Aircraft_Payload Technologies.txt', 'Antitank.txt',
    'ArmourII Technologies.txt', 'Avionics Technologies.txt', 'Command-structure Technologies.txt', 'Construction Technologies.txt',
    'Division_size Technologies.txt', 'Electronics Technolgies.txt', 'Industry Technologies.txt', 'Jet Technologies.txt', 'Land Doctrines.txt',
    'Nation Technologies.txt', 'Naval Techs.txt', 'Secret Weapons.txt', 'Special Forces Doctrines.txt', 'strategic_doctrines.txt', 'Theories.txt',
    'zDD-invisible_techs.txt', 'zNaval Doctrines.txt', 'zOMGtechs.txt'
}


P.TechsData = {}
P.TechsChoices = {}
local dataFilled = false
function P.FillData()
    if dataFilled then
        return
    end
    local translationTable = Parsing.GetTranslationTable()
    for i, file in pairs(techsFiles) do
        local res = PdxParser.parseFile("tfh\\mod\\BlackICE " .. UI.version .. "\\technologies\\" .. file)
        for name, values in pairs(res) do
            P.TechsData[name] = values
            values["folder"] = nil
            local trans = translationTable[name]
            if trans ~= nil then
                table.insert(P.TechsChoices, trans .. " [" .. name .. "]")
            else
                table.insert(P.TechsChoices, "[" .. name .. "]")
            end
        end
    end
    table.sort(P.TechsChoices, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_GameInfo_Techs:Freeze()
    UI.m_choice_GameInfo_Techs:Clear()
    UI.m_choice_GameInfo_Techs:Append(P.TechsChoices)
    UI.m_choice_GameInfo_Techs:Thaw()

    dataFilled = true
end

local shownLevel = 0
local countryLevel = 0
local function setCountryLevel(techIdent)
    local cTech = CTechnologyDataBase.GetTechnology(techIdent)
    local techStatus = CCountryDataBase.GetTag(PlayerCountry):GetCountry():GetTechnologyStatus()
    countryLevel = techStatus:GetLevel(cTech)
    return countryLevel
end

local function setShownLevel(level)
    shownLevel = level
    return shownLevel
end

local triggerKeys = {"start_year", "first_offset", "additional_offset", "difficulty", "max_level", "change", "research_bonus_from", "allow"}
function P.DumpTriggers(selection)
    local temp = table.deepcopy(P.TechsData[selection])
    local order = triggerKeys
    local data = {}
    for k, v in pairs(order) do
        data[v] = temp[v]
    end
    return Utils.DumpCustomOrder(data, order)
end

local function applyLevelToTech(data, level)
    for k, v in pairs(data) do
        if type(v) == "table" then
            data[k] = applyLevelToTech(v, level)
        elseif tonumber(v) ~= nil then
            data[k] = string.format('%.02f', tonumber(v) * level)
        end
    end
    return data
end

-- special logic to cover the different pre/post-fixes
local function getTranslation(key)
    local trans = Parsing.GetTranslation(key)
    if trans == nil then
        trans = Parsing.GetTranslation(string.upper(key), "MODIFIER_")
    end
    if trans == nil then
        trans = Parsing.GetTranslation(string.upper(key), nil, "_TECH")
    end
    if trans == nil then
        -- "air_intercept_eff"
        trans = Parsing.GetTranslation(string.lower(key), nil, "_eff")
    end
    if trans == nil then
        -- "global_revolt_risk"
        trans = Parsing.GetTranslation(string.upper(key))
    end
    -- manual overrides
    if trans == nil then
        if key == "manpower_gain" then
            trans = Parsing.GetTranslation("GLOBAL_MANPOWER")
        elseif key == "ic_efficiency" then
            trans = Parsing.GetTranslation("MODIFIER_INDUSTRIAL_EFFICIENCY")
        elseif key == "casualty_trickleback" then
            trans = Parsing.GetTranslation("CASUALTY_TRICKLEBACK_TECH")
        elseif key == "refinery_efficiency" then
            trans = Parsing.GetTranslation("MODIFIER_FUEL_CONVERSION")
        elseif key == "energy_to_oil_conversion" then
            trans = Parsing.GetTranslation("ENERGY_TO_OIL_TECH")
        elseif key == "energy_production" then
            trans = Parsing.GetTranslation("ENERGY_PROD_TECH")
        elseif key == "metal_production" then
            trans = Parsing.GetTranslation("METAL_PROD_TECH")
        elseif key == "rares_production" then
            trans = Parsing.GetTranslation("RARES_PROD_TECH")
        elseif key == "research_efficiency" then
            trans = Parsing.GetTranslation("RESEARC_EFF_TECH")
        elseif key == "unit_cooperation" then
            trans = Parsing.GetTranslation("UNIT_COOP_TECH")
        elseif key == "provincial_aa_efficiency" then
            trans = Parsing.GetTranslation("PROV_AA_TECH")
        elseif key == "attack_delay" then
            trans = "Delay between attacks"
        end
    end

    -- fallback to the key if no translation was found
    if trans == nil then
        return key
    end
    return trans
end


local techEffectKeyBlacklist = {
    ["stealable"] = true,
    ["can_upgrade"] = true,
    ["on_completion"] = true,
    ["activate_building"] = true,
    ["activate_unit"] = true,
    ["is_nuclear"] = true,
    ["change"] = true,
    ["max_level"] = true,
    ["difficulty"] = true,
    ["start_year"] = true,
    ["first_offset"] = true,
    ["additional_offset"] = true,
    ["listening_station"] = true,
    ["has_country_flag"] = true,
}
local terrainEffectsKeywords = {
    ["movement"] = true,
    ["attack"] = true,
    ["defence"] = true,
    ["attrition"] = true,
}
local function translateTechEffect(data)
    local res = {}
    for k, v in pairs(data) do
        local translatedKey = getTranslation(k)
        if type(v) ~= "table" then
            if terrainEffectsKeywords[k] ~= nil then
                -- special case for the terrain effects
                if k == "attrition" then -- super special case for attrition
                    res[translatedKey] = string.format("%.2f", v) .. "%"
                else
                    res[translatedKey] = string.format("%.2f", v * 100) .. "%"
                end
            elseif techEffectKeyBlacklist[k] ~= nil then
                res[translatedKey] = v
            else
                res[translatedKey] = Parsing.UnitConversions.GetAndConvertEffect(
                    k .. "_tech", v) -- add special key suffix because the key from techs and modifiers are the same but different
            end
        else
            res[translatedKey] = translateTechEffect(v)
        end
    end

    return res
end

function P.DumpEffects(selection)
    local data = table.deepcopy(P.TechsData[selection])
    for k, v in pairs(triggerKeys) do
        data[v] = nil
    end
    data = applyLevelToTech(data, shownLevel)
    local translatedTech = {}
    for k, v in pairs(translateTechEffect(data)) do
        translatedTech[k] = v
    end
    local sortedViaMetatable = Utils.PushTablesToEndAndSort(translatedTech)

    -- sort some values to the top so its easier to read
    local orderMetaTable = getmetatable(sortedViaMetatable)["order"]
    for k, v in pairs(techEffectKeyBlacklist) do
        local index = table.getIndex(orderMetaTable, k)
        if index ~= nil then
            table.remove(orderMetaTable, index)
            table.insert(orderMetaTable, 1, k)
        end
    end
    return Utils.DumpByMetatableOrder(sortedViaMetatable)
end


function P.HandleSelection(shownLevelOverride)
    local selectionString = UI.m_choice_GameInfo_Techs:GetString(UI.m_choice_GameInfo_Techs:GetSelection())
    local techIdent = Parsing.GetKeyFromChoice(selectionString)

    local level = 0
    if PlayerCountry ~= nil then
        level = setCountryLevel(techIdent)
        UI.m_textCtrl_GameInfo_Techs_PlayerLevel:SetValue(tostring(level))
    end

    if shownLevelOverride == nil then
        if level == 0 then
            shownLevelOverride = 1
        else
            shownLevelOverride = level
        end
    end

    setShownLevel(shownLevelOverride)
    UI.m_textCtrl_GameInfo_Techs_LevelShown:SetValue(tostring(shownLevelOverride))

    local s = Parsing.Techs.DumpTriggers(techIdent)
    UI.m_textCtrl_GameInfo_Techs_Triggers:SetValue(s)
    local s = Parsing.Techs.DumpEffects(techIdent)
    UI.m_textCtrl_GameInfo_Techs_Effects:SetValue(s)
end

P.TechsChoicesFiltered = {}
function P.HandleFilter()
    local filterString = UI.m_textCtrl_GameInfo_Techs_Filter:GetValue()
    if filterString == nil or filterString == "" then   -- Reset to default
        UI.m_choice_GameInfo_Techs:Freeze()
        UI.m_choice_GameInfo_Techs:Clear()
        UI.m_choice_GameInfo_Techs:Append(P.TechsChoices)
        UI.m_choice_GameInfo_Techs:Thaw()
        return
    end

    P.TechsChoicesFiltered = {} -- reset the list

    for k, v in pairs(P.TechsChoices) do
        if string.find(string.lower(v), string.lower(filterString)) then
            table.insert(P.TechsChoicesFiltered, v)
        end
    end

    table.sort(P.TechsChoicesFiltered, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_GameInfo_Techs:Freeze()
    UI.m_choice_GameInfo_Techs:Clear()
    UI.m_choice_GameInfo_Techs:Append(P.TechsChoicesFiltered)
    UI.m_choice_GameInfo_Techs:Thaw()
end


return P