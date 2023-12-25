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

    UI.m_choice_Techs:Freeze()
    UI.m_choice_Techs:Clear()
    UI.m_choice_Techs:Append(P.TechsChoices)
    UI.m_choice_Techs:Thaw()

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
            data[k] = string.format('%.03f', tonumber(v) * level)
        end
    end
    return data
end

function P.DumpEffects(selection)
    local data = table.deepcopy(P.TechsData[selection])
    for k, v in pairs(triggerKeys) do
        data[v] = nil
    end
    data = applyLevelToTech(data, shownLevel)
    -- All non-unit (table) values get put at the start
    local order = {"activate_unit", "on_completion"}
    -- Insert the remaining keys into the order table alphabetically
    for k, v in Utils.OrderedTable(data) do
        if type(v) ~= "table" then
            if table.getIndex(order, k) == nil then
                table.insert(order, k)
            end
        end
    end
    return Utils.DumpCustomOrder(data, order)
end


function P.HandleSelection(shownLevelOverride)
    local selectionString = UI.m_choice_Techs:GetString(UI.m_choice_Techs:GetSelection())
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

return P