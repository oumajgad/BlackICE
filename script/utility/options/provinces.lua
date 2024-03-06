local P = {}

local provinceLocsFile = "tfh/mod/BlackICE "..UI.version.."/localisation/province_names.csv"
local templatesFile = "tfh/mod/BlackICE "..UI.version.."/localisation/province_name_templates.tmpl"

local provincesDataSetup = false
local provincesData = {}
local choiceData = {}
local currentEdits = {}
local templates = {}
local selectedProvinceId = nil

local function updateCurrentEditsListBox()
    UI.m_listBox_OptionProvinceName_CurrentProvs:Freeze()
    UI.m_listBox_OptionProvinceName_CurrentProvs:Clear()
    local provincesStrings = {}
    for _, province in spairs(currentEdits) do
        local x = "[".. province.id .."] ".. province.currentName .." (".. province.originalName ..")"
        UI.m_listBox_OptionProvinceName_CurrentProvs:Append(x)
    end
    UI.m_listBox_OptionProvinceName_CurrentProvs:Thaw()
end

local function updateProvincesData()
    local lines, err = ReadLines(provinceLocsFile)
    if err then
        Utils.LUA_DEBUGOUT(err)
    end

    provincesData = {}
    currentEdits = {}

    local id = 1
    ---@diagnostic disable-next-line: param-type-mismatch
    for _, line in ipairs(lines) do
        local res = CsvParser.ParseCSVLine(line, ";", 3)
        local province = {
            id = id,
            currentName = res[2],
            originalName = res[3]
        }
        provincesData[id] = province
        if province.currentName ~= province.originalName then
            currentEdits[id] = province
        end
        id = id + 1
    end
    updateCurrentEditsListBox()
end

local function writeProvincesFile()
    local csvLines = {}
    for id, province in ipairs(provincesData) do
        local stringRes = ""
        ---@diagnostic disable-next-line: param-type-mismatch
        stringRes = "PROV" .. province.id .. ";" .. province.currentName .. ";" .. province.originalName .. ";;;;;;;;;;;x"
        table.insert(csvLines, stringRes)
    end
    WriteLines(provinceLocsFile, csvLines)
end

local function addNewProvinceInner(id, newName)
    provincesData[id].currentName = newName
    writeProvincesFile()
    updateProvincesData()
    local withFilter = false
    if UI.m_textCtrl__OptionProvinceNames_Filter:GetValue() ~= "" and UI.m_textCtrl__OptionProvinceNames_Filter:GetValue() ~= "name filter (press enter)" then
        withFilter = true
    end
    P.UpdateChoice(withFilter)
end

local function writeTemplatesData()
    local csvLines = {}
    for templateName, values in spairs(templates) do
        for id, provinceTemplate in spairs(values) do
            local x = templateName .. ";" .. id .. ";" .. provinceTemplate.newName .. ";" .. provinceTemplate.originalName .. ";"
            table.insert(csvLines, x)
        end
    end
    WriteLines(templatesFile, csvLines)
end

local function updateTemplatesListBox(templateName)
    UI.m_listBox_OptionProvinceName_TemplateProvs:Freeze()
    UI.m_listBox_OptionProvinceName_TemplateProvs:Clear()
    for id, province in spairs(templates[templateName]) do
        local x = "["..id.."] ".. province.newName .." (".. province.originalName ..")"
        UI.m_listBox_OptionProvinceName_TemplateProvs:Append(x)
    end
    UI.m_listBox_OptionProvinceName_TemplateProvs:Thaw()
end

local function updateTemplatesChoice()
    local selection = UI.m_choice_OptionProvinceName_Template:GetSelection()
    UI.m_choice_OptionProvinceName_Template:Freeze()
    UI.m_choice_OptionProvinceName_Template:Clear()
    local choiceStrings = {}
    for k, v in spairs(templates) do
        local x = "[" .. k .. "] (" .. table.getLength(v) .. ")"
        table.insert(choiceStrings, x)
    end
    UI.m_choice_OptionProvinceName_Template:Append(choiceStrings)
    UI.m_choice_OptionProvinceName_Template:Thaw()
    if selection ~= nil and selection >= 0 then
        Utils.LUA_DEBUGOUT(selection)
        UI.m_choice_OptionProvinceName_Template:SetSelection(selection)
        P.HandleTemplateChoiceSelection()
    end
end

local function updateTemplatesData()
    local lines, err = ReadLines(templatesFile)
    if err then
        Utils.LUA_DEBUGOUT(err)
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    for _, line in ipairs(lines) do
        local res = CsvParser.ParseCSVLine(line, ";", 4)
        local templateName = res[1]
        local provinceTemplate = {
            id = tonumber(res[2]),
            newName = res[3],
            originalName = res[4]
        }
        if templates[templateName] == nil then
            templates[templateName] = {}
        end
        templates[templateName][provinceTemplate.id] = provinceTemplate
    end
    -- Utils.INSPECT_TABLE(templates)
    updateTemplatesChoice()
end

function P.HandleTemplateChoiceSelection()
    local selection = UI.m_choice_OptionProvinceName_Template:GetString(UI.m_choice_OptionProvinceName_Template:GetSelection())
    local templateName = Parsing.GetKeyFromChoice(selection)
    updateTemplatesListBox(templateName)
end

local function getTemplateNameFromChoice()
    local selection = UI.m_choice_OptionProvinceName_Template:GetString(UI.m_choice_OptionProvinceName_Template:GetSelection())
    local name = Parsing.GetKeyFromChoice(selection)
    return name
end

function P.AddSingleFromTemplate()
    local function getTemplateListBoxSelection()
        local count = UI.m_listBox_OptionProvinceName_TemplateProvs:GetCount()
        for i = 0, count - 1 do
            if UI.m_listBox_OptionProvinceName_TemplateProvs:IsSelected(i) then
                local selection = UI.m_listBox_OptionProvinceName_TemplateProvs:GetString(i)
                local id = Parsing.GetKeyFromChoice(selection)
                return id
            end
        end
    end

    local selectedProvinceId = getTemplateListBoxSelection()
    local selectedTemplateName = getTemplateNameFromChoice()
    if selectedProvinceId == nil or selectedTemplateName == nil then
        return
    end
    local newProvince = templates[selectedTemplateName][tonumber(selectedProvinceId)]
    addNewProvinceInner(newProvince.id, newProvince.newName)
end

function P.AddAllFromTemplate()
    local selectedTemplateName = getTemplateNameFromChoice()
    local count = UI.m_listBox_OptionProvinceName_TemplateProvs:GetCount()
    for i = 0, count - 1 do
        local selection = UI.m_listBox_OptionProvinceName_TemplateProvs:GetString(i)
        local selectedProvinceId = Parsing.GetKeyFromChoice(selection)
        if selectedProvinceId == nil or selectedTemplateName == nil then
            return
        end
        local newProvince = templates[selectedTemplateName][tonumber(selectedProvinceId)]
        addNewProvinceInner(newProvince.id, newProvince.newName)        
    end
end

function P.AddSingleToTemplate()
    local function getCurrentEditListBoxSelection()
        local count = UI.m_listBox_OptionProvinceName_CurrentProvs:GetCount()
        for i = 0, count - 1 do
            if UI.m_listBox_OptionProvinceName_CurrentProvs:IsSelected(i) then
                local selection = UI.m_listBox_OptionProvinceName_CurrentProvs:GetString(i)
                local id = Parsing.GetKeyFromChoice(selection)
                return id
            end
        end
    end

    local selectedProvinceId = getCurrentEditListBoxSelection()
    local selectedTemplateName = getTemplateNameFromChoice()
    Utils.LUA_DEBUGOUT(selectedProvinceId)
    Utils.LUA_DEBUGOUT(selectedTemplateName)
    if selectedProvinceId == nil or selectedTemplateName == nil then
        return
    end
    selectedProvinceId = tonumber(selectedProvinceId)
    local selectedProvince = currentEdits[selectedProvinceId]
    templates[selectedTemplateName][selectedProvinceId] = {
        id = selectedProvinceId,
        newName = selectedProvince.currentName,
        originalName = selectedProvince.originalName
    }
    writeTemplatesData()
    updateTemplatesData()
end

function P.AddAllToTemplate()
    local selectedTemplateName = getTemplateNameFromChoice()
    local count = UI.m_listBox_OptionProvinceName_CurrentProvs:GetCount()
    for i = 0, count - 1 do
        local selection = UI.m_listBox_OptionProvinceName_CurrentProvs:GetString(i)
        local selectedProvinceId = Parsing.GetKeyFromChoice(selection)
        if selectedProvinceId == nil or selectedTemplateName == nil then
            return
        end
        selectedProvinceId = tonumber(selectedProvinceId)
        local selectedProvince = currentEdits[selectedProvinceId]
        templates[selectedTemplateName][selectedProvinceId] = {
            id = selectedProvinceId,
            newName = selectedProvince.currentName,
            originalName = selectedProvince.originalName
        }
    end
    writeTemplatesData()
    updateTemplatesData()
end

local function updateSelectedProvince(id)
    selectedProvinceId = tonumber(id)
    if id ~= nil then
        local province = provincesData[tonumber(id)]
        UI.m_textCtrl_OptionProvinceNames_ID:SetValue(tostring(id))
        UI.m_textCtrl_OptionProvinceNames_OriginalName:SetValue(province.originalName)
        UI.m_textCtrl_OptionProvinceNames_CurrentName:SetValue(province.currentName)
        UI.m_textCtrl_OptionProvinceNames_NewName:SetValue(province.currentName)
    else
        UI.m_textCtrl_OptionProvinceNames_ID:SetValue("")
        UI.m_textCtrl_OptionProvinceNames_OriginalName:SetValue("")
        UI.m_textCtrl_OptionProvinceNames_CurrentName:SetValue("")
    end
end

function P.UpdateChoice(withFilter)
    local selection = UI.m_choice_OptionProvinceNames_Search:GetSelection()
    choiceData = {}
    for id, province in ipairs(provincesData) do
        if withFilter == true then
            local filterValue = UI.m_textCtrl__OptionProvinceNames_Filter:GetValue()
            if string.find(string.lower(province.originalName), string.lower(filterValue))
            or string.find(string.lower(province.currentName), string.lower(filterValue)) then
                local x = "["..id.."] ".. province.currentName .." (".. province.originalName ..")"
                table.insert(choiceData, x)
            end
        else
            local x = "["..id.."] ".. province.currentName .." (".. province.originalName ..")"
            table.insert(choiceData, x)
        end
    end

    UI.m_choice_OptionProvinceNames_Search:Freeze()
    UI.m_choice_OptionProvinceNames_Search:Clear()
    UI.m_choice_OptionProvinceNames_Search:Append(choiceData)
    UI.m_choice_OptionProvinceNames_Search:Thaw()
    if selection >= 0 then
        UI.m_choice_OptionProvinceNames_Search:SetSelection(selection)
    end
end

function P.Setup()
    if provincesDataSetup == false then
        updateProvincesData()
        provincesDataSetup = true
        P.UpdateChoice(false)
        updateTemplatesData()
    end
end

function P.HandleProvinceSelection()
    local selection = UI.m_choice_OptionProvinceNames_Search:GetString(UI.m_choice_OptionProvinceNames_Search:GetSelection())
    local id = Parsing.GetKeyFromChoice(selection)
    updateSelectedProvince(id)
end

function P.HandleCurrentEditSelection()
    local count = UI.m_listBox_OptionProvinceName_CurrentProvs:GetCount()
    for i = 0, count - 1 do
        if UI.m_listBox_OptionProvinceName_CurrentProvs:IsSelected(i) then
            local selection = UI.m_listBox_OptionProvinceName_CurrentProvs:GetString(i)
            local id = Parsing.GetKeyFromChoice(selection)
            updateSelectedProvince(id)
            i = #currentEdits
        end
    end
end

function P.AddNewProvince()
    if selectedProvinceId == nil then
        return
    end

    local newName = UI.m_textCtrl_OptionProvinceNames_NewName:GetValue()
    if newName ~= "" then
        addNewProvinceInner(selectedProvinceId, newName)
    end
end

function P.ResetProvince()
    if selectedProvinceId == nil then
        return
    end

    provincesData[selectedProvinceId].currentName = provincesData[selectedProvinceId].originalName
    writeProvincesFile()
    updateProvincesData()
    updateSelectedProvince(selectedProvinceId)
end

return P