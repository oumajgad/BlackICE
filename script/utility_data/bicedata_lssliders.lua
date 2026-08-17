-- Custom leadership slider AI: the thresholds it produces officers, spies and diplomats
-- between.
--
-- Port of utility/main/ls_sliders_ai.lua, with the wx controls removed.
--
-- Staged like the other two AI pages. Commit is also where the two rules live: the
-- engine refuses an officer ratio above 110, and a lower threshold above its upper one
-- would have the AI producing to a target it is already past.

BiceData = BiceData or {}
BiceData.LsSliders = {}

local PREFIX = "zzDsafe_CustomLeadershipSliders_"
local USES = "zzDsafe_usesCustomLsSliders"
local ACTIVE = "zzDsafe_CustomLeadershipSliders_isActive"

-- Defaults are the values the wx controls started with.
local CATEGORIES = {
    { key = "officers", name = "Officers", lower = 110, upper = 110, maximum = 110 },
    { key = "spies",    name = "Spies",    lower = 10,  upper = 20 },
    { key = "diplo",    name = "Diplo",    lower = 10,  upper = 20 },
}

local BUFFER_NCO = "bufferProdNco"

local fields = nil

local function knownFields()
    if fields ~= nil then
        return fields
    end

    fields = { [BUFFER_NCO] = true }
    for _, category in ipairs(CATEGORIES) do
        fields[category.key .. "Lower"] = true
        fields[category.key .. "Upper"] = true
    end
    return fields
end

local staged = {}

local function variables()
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return nil, nil
    end

    local country = CCountryDataBase.GetTag(tag):GetCountry()
    if country == nil then
        return nil, nil
    end
    return country:GetVariables(), tag
end

--- The categories and their display names, in page order.
function BiceData.LsSliders.Categories()
    return CATEGORIES
end

--- Current settings, or the wx defaults if this country has never been configured.
function BiceData.LsSliders.Collect()
    local vars, tag = variables()
    if vars == nil then
        return nil, "No country selected"
    end

    local configured = vars:GetVariable(CString(USES)):Get() == 1

    local rows = {}
    for _, category in ipairs(CATEGORIES) do
        local row = {
            key = category.key,
            name = category.name,
            -- 0 means no cap; only officers have one.
            maximum = category.maximum or 0,
        }

        if configured then
            row.lower = vars:GetVariable(CString(PREFIX .. category.key .. "Lower")):Get()
            row.upper = vars:GetVariable(CString(PREFIX .. category.key .. "Upper")):Get()
        else
            row.lower = category.lower
            row.upper = category.upper
        end

        table.insert(rows, row)
    end

    local bufferNco = true -- the wx checkbox started ticked
    if configured then
        bufferNco = vars:GetVariable(CString(PREFIX .. BUFFER_NCO)):Get() == 1
    end

    return {
        tag = tag,
        active = vars:GetVariable(CString(ACTIVE)):Get() == 1,
        configured = configured,
        bufferNco = bufferNco,
        rows = rows,
    }, nil
end

--- Stages one field. Nothing reaches the game until Commit.
function BiceData.LsSliders.SetValue(field, value)
    if field == nil or not knownFields()[field] then
        return false, "Unknown field: " .. tostring(field)
    end
    staged[field] = value
    return true, nil
end

--- Posts everything staged, clamped to what the engine and the AI can work with.
---
--- Returns ok, reason, corrections - corrections being the fields whose staged value
--- was changed, so the caller can show what was actually applied.
function BiceData.LsSliders.Commit()
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return false, "No country selected", nil
    end

    local corrections = {}
    for _, category in ipairs(CATEGORIES) do
        local lowerField = category.key .. "Lower"
        local upperField = category.key .. "Upper"
        local lower = staged[lowerField]
        local upper = staged[upperField]

        if category.maximum ~= nil then
            if lower ~= nil and lower > category.maximum then
                lower = category.maximum
                staged[lowerField] = lower
                corrections[lowerField] = lower
            end
            if upper ~= nil and upper > category.maximum then
                upper = category.maximum
                staged[upperField] = upper
                corrections[upperField] = upper
            end
        end

        if lower ~= nil and upper ~= nil and lower > upper then
            staged[lowerField] = upper
            corrections[lowerField] = upper
        end
    end

    local countryTag = CCountryDataBase.GetTag(tag)
    for field, value in pairs(staged) do
        CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(PREFIX .. field), CFixedPoint(value)))
    end
    staged = {}

    CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(USES), CFixedPoint(1)))
    return true, nil, corrections
end

--- Discards anything staged but not committed.
function BiceData.LsSliders.Discard()
    staged = {}
end

--- Switches the custom leadership slider AI on or off.
function BiceData.LsSliders.SetActive(enabled)
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return
    end

    local countryTag = CCountryDataBase.GetTag(tag)
    if enabled then
        CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(USES), CFixedPoint(1)))
    end
    CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(ACTIVE),
        CFixedPoint(enabled and 1 or 0)))
end
