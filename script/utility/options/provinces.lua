local P = {}

local filePath = "tfh/mod/BlackICE "..UI.version.."/localisation/province_names.csv"

local function buildNewProvinceName(id, newName)
    return "PROV"..id..";"..newName..";;;;;;;;;;;x"
end

local provincesDataSetup = false
local provincesData = {} -- [ID] = { [1] = key; [2] = province name; [3] = original name }
local choiceData = {}

local function updateProvincesData()
    local lines, err = ReadLines(filePath)
    if err then
        Utils.LUA_DEBUGOUT(err)
    end

    provincesData = {}
    local id = 1
    ---@diagnostic disable-next-line: param-type-mismatch
    for _, line in ipairs(lines) do
        local res = CsvParser.ParseCSVLine(line, ";", 3)
        res[3] = res[2]
        provincesData[id] = res
        id = id + 1
    end
end

local function writeProvincesFile()
    local csvLines = {}
    for id, data in ipairs(provincesData) do
        local stringRes = ""
        ---@diagnostic disable-next-line: param-type-mismatch
        for _, val in ipairs(data) do
            stringRes = stringRes .. val .. ";"
        end
        stringRes = stringRes .. ";;;;;;;;;;;x"
        table.insert(csvLines, stringRes)
    end
    WriteLines(filePath, csvLines)
end

local selectedProvince = nil
local function updateSelectedProvince(id)
    local data = provincesData[tonumber(id)]
    UI.m_textCtrl_OptionProvinceNames_ID:SetValue(id)
    UI.m_textCtrl_OptionProvinceNames_OriginalName:SetValue(tostring(data[3]))
    UI.m_textCtrl_OptionProvinceNames_CurrentName:SetValue(tostring(data[2]))
end

function P.UpdateChoice()
    choiceData = {}
    for id, data in ipairs(provincesData) do
        local x = "["..id.."] "..data[2].." ("..data[3]..")"
        table.insert(choiceData, x)
    end

    UI.m_choice_OptionProvinceNames_Search:Freeze()
    UI.m_choice_OptionProvinceNames_Search:Clear()
    UI.m_choice_OptionProvinceNames_Search:Append(choiceData)
    UI.m_choice_OptionProvinceNames_Search:Thaw()
end

function P.Setup()
    if provincesDataSetup == false then
        updateProvincesData()
        provincesDataSetup = true
        P.UpdateChoice()
    end
end

function P.HandleProvinceSelection()
    local selection = UI.m_choice_OptionProvinceNames_Search:GetString(UI.m_choice_OptionProvinceNames_Search:GetSelection())
    local id = Parsing.GetKeyFromChoice(selection)
    updateSelectedProvince(id)
end

function Test()
    -- local newNames = {
    --     [14188] = buildNewProvinceName(14188, "Mount Alfa")
    -- }
    -- ReplaceLines(filePath, newNames)

end


return P