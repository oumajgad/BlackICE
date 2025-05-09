local P = {}

P.TechsData = nil
P.TechsChoices = {}
P.TechsIndexes = {}
function P.FillData()
    if P.TechsData ~= nil then
        return
    end
    P.TechsData = {}
    local translationTable = Parsing.GetTranslationTable()
    local path = "tfh\\mod\\BlackICE " .. G_MOD_VERSION .. "\\technologies"
    local i = 0
    for x, file in pairs(GetFilesFromPath(path)) do
        local res = PdxParser.parseFile(path .. "\\" .. file, true)
        for y, entry in ipairs(res) do
            local name, values
            for k, v in pairs(entry) do
                name = k
                values = v
            end
            P.TechsData[name] = values
            P.TechsIndexes[name] = i
            values["folder"] = nil
            local trans = translationTable[name]
            if trans ~= nil then
                table.insert(P.TechsChoices, trans .. " [" .. name .. "]")
            else
                table.insert(P.TechsChoices, "[" .. name .. "]")
            end
            i = i + 1
        end
    end
    table.sort(P.TechsChoices, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_GameInfo_Techs:Freeze()
    UI.m_choice_GameInfo_Techs:Clear()
    UI.m_choice_GameInfo_Techs:Append(P.TechsChoices)
    UI.m_choice_GameInfo_Techs:Thaw()
end

local shownLevel = 0
local countryLevel = 0
local function setCountryLevel(techIdent)
    countryLevel = P.GetPlayerTechLevel(techIdent)
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

function P.ApplyLevelToTech(data, level)
    for k, v in pairs(data) do
        if type(v) == "table" then
            data[k] = P.ApplyLevelToTech(v, level)
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
        elseif key == "default_organisation" then
            trans = Parsing.GetTranslation("DEFAULT_ORG")
        elseif key == "build_cost_manpower" then
            trans = Parsing.GetTranslation("BUILD_COST_MP")
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
function P.TranslateTechEffect(data)
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
            res[translatedKey] = P.TranslateTechEffect(v)
        end
    end

    return res
end

function P.DumpEffects(selection)
    local data = table.deepcopy(P.TechsData[selection])
    for k, v in pairs(triggerKeys) do
        data[v] = nil
    end
    data = P.ApplyLevelToTech(data, shownLevel)
    local translatedTech = {}
    for k, v in pairs(P.TranslateTechEffect(data)) do
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

-- Takes in a prepared tech table which it sorts and translates
function P.DumpEffectsForUnitTab(tech, level)
    local copy = table.deepcopy(tech)
    for k, v in pairs(triggerKeys) do
        copy[v] = nil
    end
    copy = P.ApplyLevelToTech(copy, level)
    local translatedTech = {}
    for k, v in pairs(P.TranslateTechEffect(copy)) do
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

function P.GetPlayerTechLevel(tech)
    local level = 0
    if G_PlayerCountry ~= nil then
        local cTech = CTechnologyDataBase.GetTechnology(tech)
        local techStatus = CCountryDataBase.GetTag(G_PlayerCountry):GetCountry():GetTechnologyStatus()
        level = techStatus:GetLevel(cTech)
    end
    return level
end

function P.HandleSelection(shownLevelOverride)
    local selectionString = UI.m_choice_GameInfo_Techs:GetString(UI.m_choice_GameInfo_Techs:GetSelection())
    local techIdent = Parsing.GetKeyFromChoice(selectionString)

    local level = 0
    if G_PlayerCountry ~= nil then
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
    P.ClearText()
    local filterString = UI.m_textCtrl_GameInfo_Techs_Filter:GetValue()
    if filterString == nil or filterString == "" then   -- Reset to default
        UI.m_choice_GameInfo_Techs:Freeze()
        UI.m_choice_GameInfo_Techs:Clear()
        UI.m_choice_GameInfo_Techs:Append(P.TechsChoices)
        UI.m_choice_GameInfo_Techs:Thaw()
        if UI.m_choice_GameInfo_Techs:GetCount() >= 1 then
            UI.m_choice_GameInfo_Techs:SetSelection(0)
            P.HandleSelection()
        end
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
    if UI.m_choice_GameInfo_Techs:GetCount() >= 1 then
        UI.m_choice_GameInfo_Techs:SetSelection(0)
        P.HandleSelection()
    end
end


P.TechModifierValues = nil  -- these are the modifiers which we show in the utility, but for which the LUA endpoint is missing the tech levels
local function loadTechModifiers()
    local techModifierValues = {
        ["ic_efficiency"] = {},
        ["ic_modifier"] = {},
        ["research_efficiency"] = {},
        ["supply_throughput"] = {},
        ["repair_rate"] = {},
        ["org_regain"] = {},
        ["attack_delay"] = {},
    }
    if P.TechsData == nil then
        P.FillData()
    end

    for techName, techValues in pairs(P.TechsData) do
        for k, v in pairs(techValues) do
            if techModifierValues[k] ~= nil then
                techModifierValues[k][techName] = tonumber(v)
            end
        end
    end
    P.TechModifierValues = techModifierValues
end

function P.GetTechModifierValues()
    if P.TechModifierValues == nil then
        P.TechModifierValues = {}
        loadTechModifiers()
    end
    return P.TechModifierValues
end

function P.ClearText()
    UI.m_panel_GameInfo_Tech:Freeze()
    UI.m_textCtrl_GameInfo_Techs_Triggers:Clear()
    UI.m_textCtrl_GameInfo_Techs_Effects:Clear()
    UI.m_panel_GameInfo_Tech:Thaw()
end

return P