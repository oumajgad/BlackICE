local P = {}

local generalBranches = {
    all = 1, land = "land", sea = "sea", air = "air"
}

local function getGeneralBranchChoice()
    if UI.m_radioBtn_Generals_all:GetValue() then
        return generalBranches.all
    end
    if UI.m_radioBtn_Generals_land:GetValue() then
        return generalBranches.land
    end
    if UI.m_radioBtn_Generals_sea:GetValue() then
        return generalBranches.sea
    end
    if UI.m_radioBtn_Generals_air:GetValue() then
        return generalBranches.air
    end
end

-- Generals availability is deterimined by their "history".
-- There can be multiple history blocks in the definition since the base game has different starting dates.
-- This function finds the earliest date
local function getGeneralDate(leader)
    local earliest_date = nil
    --utils.INSPECT_TABLE(leader)
    if leader["history"] == nil then
        return earliest_date
    end
    for current_date, rank in pairs(leader["history"]) do
        if earliest_date == nil then
            earliest_date = current_date
        else
            local current_date_split = Utils.SplitString(current_date, ".")
            local earliest_date_split = Utils.SplitString(earliest_date, ".")
            --utils.INSPECT_TABLE(current_date_split)
            --utils.INSPECT_TABLE(earliest_date_split)
            -- Year
            if current_date_split[1] < earliest_date_split[1] then
                earliest_date = current_date
            -- Months
            elseif  current_date_split[1] == earliest_date_split[1] and
                    current_date_split[2] < earliest_date_split[2]
            then
                earliest_date = current_date
            -- Days
            elseif  current_date_split[1] == earliest_date_split[1] and
                    current_date_split[2] == earliest_date_split[2] and
                    current_date_split[3] < earliest_date_split[3]
            then
                earliest_date = current_date
            end
        end
    end
    return earliest_date
end

local function translateTraits(traits)
    if traits == nil then
        return {}
    end
    local res = {}
    if type(traits) == "string" then
        table.insert(res, Parsing.GetTranslation(traits))
    else
        for k, v in pairs(traits) do
            table.insert(res, Parsing.GetTranslation(v))
        end
    end

    return res
end

local function createGeneral(values)
    local general = {
        name = values["name"],
        starting_skill = values["skill"],
        max_skill = values["max_skill"],
        traits = translateTraits(values["add_trait"]),
        available_date = getGeneralDate(values),
        type = values["type"],
        country = values["country"]
    }
    return general
end

local SortGeneralsBySkill = function(t,a,b) return t[b]["starting_skill"] < t[a]["starting_skill"] end

local function checkNameFilter(general, filterString)
    if filterString ~= "" then
        if string.find(string.lower(general.name), string.lower(filterString)) then
            return true
        end
        return false
    else -- no filter
        return true

    end
end

local function createFilteredGeneralsList(playertag, filterOverride)
    local filterString = UI.m_textCtrl_GameInfo_Generals_Filter:GetValue()
    if filterOverride ~= nil then
        -- since the filter textctrl has a default value it has to be overriden so it doesn't interfere with with the list creation when choosing a country
        filterString = ""
    end
    local selectedBranch = getGeneralBranchChoice()
    local unsorted = {}
    for id, general in pairs(P.GeneralsData) do
        if (
            general.country == playertag
            and (selectedBranch == generalBranches.all or general.type == selectedBranch)
            and checkNameFilter(general, filterString)
        ) then
            if general.starting_skill ~= nil then
                unsorted[id] = general
            else
                Utils.LUA_DEBUGOUT(id)
                Utils.INSPECT_TABLE(general)
            end
        end
    end
    local sorted = {}
    for id, general in spairs(unsorted, SortGeneralsBySkill) do
        local choice_string = (
            general.starting_skill .. " (" .. general.max_skill .. ") \t" ..
            general.type .. " '" .. general.name .. "' " .. general.available_date .. " [" .. id .. "]"
        )
        table.insert(sorted, choice_string)
        P.CountryGeneralsData[id] = general
    end
    return sorted
end

P.GeneralsData = {}
P.CountryGeneralsData = {}
local dataFilled = false
function P.FillData()
    if dataFilled then
        return
    end
    local path = "tfh\\mod\\BlackICE " .. UI.version .. "\\history\\leaders"
    for i, file in pairs(GetFilesFromPath(path)) do
        local res = PdxParser.parseFile(path .. "\\" .. file)
        for id, values in pairs(res) do
            P.GeneralsData[id] = createGeneral(values)
        end
    end
    dataFilled = true
end

function P.FillwxChoice(playertag, filterOverride)
    if not dataFilled then
        P.FillData()
    end
    local generals = createFilteredGeneralsList(playertag, filterOverride)
    UI.m_choice_GameInfo_Generals:Freeze()
    UI.m_choice_GameInfo_Generals:Clear()
    UI.m_choice_GameInfo_Generals:Append(generals)
    UI.m_choice_GameInfo_Generals:Thaw()
end

return P