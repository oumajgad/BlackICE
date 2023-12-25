local P = {}


local modifierFiles = {
    "event_modifiers.txt", "triggered_modifiers.txt"
}

P.ModifierData = {}
P.ModifierChoices = {}
local dataFilled = false
function P.FillData()
    if dataFilled then
        return
    end

    for i, file in pairs(modifierFiles) do
        local res = PdxParser.parseFile("tfh\\mod\\BlackICE " .. UI.version .. "\\common\\" .. file)
        for name, values in pairs(res) do
            P.ModifierData[name] = values
            local trans = Parsing.GetTranslation(name)
            if trans ~= nil then
                table.insert(P.ModifierChoices, trans .. " [" .. name .. "]")
            else
                table.insert(P.ModifierChoices, "[" .. name .. "]")
            end
        end
    end
    table.sort(P.ModifierChoices, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_GameInfo_Modifiers1:Freeze()
    UI.m_choice_GameInfo_Modifiers1:Clear()
    UI.m_choice_GameInfo_Modifiers1:Append(P.ModifierChoices)
    UI.m_choice_GameInfo_Modifiers1:Thaw()

    dataFilled = true
end

local triggerKeys = {"potential", "trigger"}
local function dumpTriggers(selection)
    local temp = table.deepcopy(P.ModifierData[selection])
    local order = triggerKeys
    local data = {}
    for k, v in pairs(order) do
        data[v] = temp[v]
    end
    return Utils.DumpCustomOrder(data, order)
end


-- special logic to cover the different pre/post-fixes
local function getTranslation(key)
    local trans = Parsing.GetTranslation(string.upper(key), "MODIFIER_")
    if trans == nil then
        -- "air_intercept_eff"
        trans = Parsing.GetTranslation(string.lower(key), nil, "_eff")
    end
    if trans == nil then
        -- "global_revolt_risk"
        trans = Parsing.GetTranslation(string.upper(key))
    end
    if trans == nil then
        if key == "global_manpower_modifier" then
            trans = Parsing.GetTranslation("GLOBAL_MANPOWER")
        elseif key == "local_manpower_modifier" then
            trans = Parsing.GetTranslation("LOCAL_MANPOWER")
        elseif key == "casualty_trickleback" then
            trans = Parsing.GetTranslation("CASUALTY_TRICKLEBACK_TECH")
        end
    end

    -- fallback to the key if no translation was found
    if trans == nil then
        return key
    end
    return trans
end


local function dumpEffects(selection)
    local data = table.deepcopy(P.ModifierData[selection])
    -- remove the triggerKeys
    for k, v in pairs(triggerKeys) do
        data[v] = nil
    end
    data["icon"] = nil

    local res = {}
    -- Replace the keys with their translations
    for k, v in pairs(data) do
        local trans = getTranslation(k)
        res[trans] = Parsing.UnitConversions.GetAndConvertEffect(k, v)
    end

    -- Insert the remaining keys into the order table alphabetically
    local order = {}
    for k, v in Utils.OrderedTable(res) do
        if type(v) ~= "table" then
            if table.getIndex(order, k) == nil then
                table.insert(order, k)
            end
        end
    end

    return Utils.DumpCustomOrder(res, order)
end

function P.HandleSelection()
    local selectionString = UI.m_choice_GameInfo_Modifiers1:GetString(UI.m_choice_GameInfo_Modifiers1:GetSelection())
    local modifierIdent = Parsing.GetKeyFromChoice(selectionString)

    local s = dumpTriggers(modifierIdent)
    UI.m_textCtrl_GameInfo_Modifiers_Triggers1:SetValue(s)
    local s = dumpEffects(modifierIdent)
    UI.m_textCtrl_GameInfo_Modifiers_Effects1:SetValue(s)
end

P.ModifierChoicesFiltered = {}
function P.HandleFilter()
    local filterString = UI.m_textCtrl_GameInfo_Modifiers_Filter:GetValue()
    if filterString == nil or filterString == "" then   -- Reset to default
        UI.m_choice_GameInfo_Modifiers1:Freeze()
        UI.m_choice_GameInfo_Modifiers1:Clear()
        UI.m_choice_GameInfo_Modifiers1:Append(P.ModifierChoices)
        UI.m_choice_GameInfo_Modifiers1:Thaw()
        return
    end

    P.ModifierChoicesFiltered = {} -- reset the list

    for k, v in pairs(P.ModifierChoices) do
        if string.find(string.lower(v), string.lower(filterString)) then
            table.insert(P.ModifierChoicesFiltered, v)
        end
    end

    table.sort(P.ModifierChoicesFiltered, function (a, b)
        return string.upper(a) < string.upper(b)
    end)

    UI.m_choice_GameInfo_Modifiers1:Freeze()
    UI.m_choice_GameInfo_Modifiers1:Clear()
    UI.m_choice_GameInfo_Modifiers1:Append(P.ModifierChoicesFiltered)
    UI.m_choice_GameInfo_Modifiers1:Thaw()
end



return P