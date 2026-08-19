-- Generals tab.
--
-- Parsing the leader files, working out when each becomes available and from which rank,
-- and translating their traits all live in BiceData.Generals, shared with the ImGui
-- utility, so history\leaders is read once for both. This keeps the wx half: the branch
-- radio buttons, the name filter, the choice control and the live leader details.

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

--- The leaders currently listed, by id, so a selection can be looked back up.
P.CountryGeneralsData = {}

local function matchesName(general, filterString)
    if filterString == "" then
        return true
    end
    return string.find(string.lower(tostring(general.name)), string.lower(filterString)) ~= nil
end

--- The choice strings for one country, filtered by branch and name.
--- Already ordered by starting skill, highest first, by the provider.
local function createFilteredGeneralsList(playertag, filterOverride)
    local filterString = UI.m_textCtrl_GameInfo_Generals_Filter:GetValue()
    if filterOverride ~= nil then
        -- The filter box has a default value in it, which must not narrow the list when
        -- a country is picked.
        filterString = ""
    end

    local selectedBranch = getGeneralBranchChoice()
    local choices = {}
    P.CountryGeneralsData = {}

    for _, general in ipairs(BiceData.Generals.ForCountry(playertag)) do
        if (selectedBranch == generalBranches.all or general.type == selectedBranch)
            and matchesName(general, filterString) then
            table.insert(choices,
                general.starting_skill .. " (" .. general.max_skill .. ") \t" ..
                general.type .. " '" .. general.name .. "' " ..
                tostring(general.available_date) .. " [" .. general.id .. "]")
            P.CountryGeneralsData[tostring(general.id)] = general
        end
    end
    return choices
end

function P.FillData()
    -- Parsed on demand by the provider. Kept because the utility calls it.
    BiceData.Generals.ForCountry(G_PlayerCountry)
end

function P.FillwxChoice(playertag, filterOverride)
    local generals = createFilteredGeneralsList(playertag, filterOverride)

    UI.m_choice_GameInfo_Generals:Freeze()
    UI.m_choice_GameInfo_Generals:Clear()
    UI.m_choice_GameInfo_Generals:Append(generals)
    UI.m_choice_GameInfo_Generals:Thaw()
end

function P.HandleFilter(playertag)
    P.FillwxChoice(playertag)
    if UI.m_choice_GameInfo_Generals:GetCount() >= 1 then
        UI.m_choice_GameInfo_Generals:SetSelection(0)
        P.HandleSelection()
    end
end

--- Whatever the running game knows about a leader, which the definition cannot say.
local function fillLiveDetails(generalId)
    if BiceLib == nil then
        UI.m_textCtrl_GameInfo_Generals_Location:SetValue("BiceLib")
        UI.m_textCtrl_GameInfo_Generals_Location_Id:SetValue("failed")
        return
    end

    local cLeader = BiceLib.Leaders.getLeaderDetails(tonumber(generalId))
    if cLeader == nil then
        UI.m_textCtrl_GameInfo_Generals_Location:SetValue("cLeader")
        UI.m_textCtrl_GameInfo_Generals_Location_Id:SetValue("nil")
        return
    end

    local provinceId = cLeader["province_id"]
    if provinceId ~= nil then
        local provinceName = BiceData.Translations.Get(tostring(provinceId), "PROV", nil) or "unknown"
        UI.m_textCtrl_GameInfo_Generals_Location:SetValue(provinceName)
        UI.m_textCtrl_GameInfo_Generals_Location_Id:SetValue(tostring(provinceId))
    else
        UI.m_textCtrl_GameInfo_Generals_Location:SetValue("unknown")
        UI.m_textCtrl_GameInfo_Generals_Location_Id:SetValue("unknown")
    end

    UI.m_textCtrl_GameInfo_Generals_Unit_Name:SetValue(cLeader["unit_name"] or "unknown")
end

function P.HandleSelection()
    local selectionString = UI.m_choice_GameInfo_Generals:GetString(
        UI.m_choice_GameInfo_Generals:GetSelection())
    local generalId = BiceData.Translations.KeyFromChoice(selectionString)
    local general = P.CountryGeneralsData[generalId]

    UI.m_textCtrl_GameInfo_Generals_Traits:Clear()
    UI.m_choice_GameInfo_Generals_Traits:Freeze()
    UI.m_choice_GameInfo_Generals_Traits:Clear()

    if general ~= nil then
        UI.m_textCtrl_Generals:SetValue(Utils.Dump(general))
        UI.m_choice_GameInfo_Generals_Traits:Append(general.traits)
        if UI.m_choice_GameInfo_Generals_Traits:GetCount() >= 1 then
            UI.m_choice_GameInfo_Generals_Traits:SetSelection(0)
            P.HandleTraitSelection()
        end
    end

    fillLiveDetails(generalId)
    UI.m_choice_GameInfo_Generals_Traits:Thaw()
end

function P.HandleTraitSelection()
    local selectionString = UI.m_choice_GameInfo_Generals_Traits:GetString(
        UI.m_choice_GameInfo_Generals_Traits:GetSelection())
    local trait = BiceData.Translations.KeyFromChoice(selectionString)

    -- Takes the trait's key: the dump comes from BiceData.Traits, which looks the
    -- definition up itself. True drops the allowed_leader block, which is about who may
    -- have the trait rather than what it does.
    UI.m_textCtrl_GameInfo_Generals_Traits:SetValue(BiceData.Traits.DumpEffects(trait, true))
end

function P.ClearText()
    UI.m_panel_GameInfo_Generals:Freeze()
    UI.m_textCtrl_Generals:Clear()
    UI.m_choice_GameInfo_Generals_Traits:Clear()
    UI.m_textCtrl_GameInfo_Generals_Traits:Clear()
    UI.m_panel_GameInfo_Generals:Thaw()
end

return P
