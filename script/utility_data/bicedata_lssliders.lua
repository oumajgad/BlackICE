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

--- The categories and their display names, in page order.
function BiceData.LsSliders.Categories()
    return CATEGORIES
end

--- Current settings, or the wx defaults if this country has never been configured.
function BiceData.LsSliders.Collect()
    local vars, tag = BiceData.Country.Variables()
    if vars == nil then
        return nil, "No country selected"
    end

    local configured = BiceData.Country.Get(vars, USES) == 1

    local rows = {}
    for _, category in ipairs(CATEGORIES) do
        local row = {
            key = category.key,
            name = category.name,
            -- 0 means no cap; only officers have one.
            maximum = category.maximum or 0,
        }

        if configured then
            row.lower = BiceData.Country.Get(vars, PREFIX .. category.key .. "Lower")
            row.upper = BiceData.Country.Get(vars, PREFIX .. category.key .. "Upper")
        else
            row.lower = category.lower
            row.upper = category.upper
        end

        table.insert(rows, row)
    end

    local bufferNco = true -- the wx checkbox started ticked
    if configured then
        bufferNco = BiceData.Country.Get(vars, PREFIX .. BUFFER_NCO) == 1
    end

    return {
        tag = tag,
        active = BiceData.Country.Get(vars, ACTIVE) == 1,
        configured = configured,
        bufferNco = bufferNco,
        rows = rows,
    }, nil
end

--- Stages one field. Nothing reaches the game until Commit.
function BiceData.LsSliders.SetValue(field, value)
    return BiceData.AiSettings.Stage(staged, knownFields(), field, value)
end

--- Posts everything staged, clamped to what the engine and the AI can work with.
---
--- Returns ok, reason, corrections - corrections being the fields whose staged value
--- was changed, so the caller can show what was actually applied.
function BiceData.LsSliders.Commit()
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

    local ok, reason = BiceData.AiSettings.Post(PREFIX, staged, USES)
    if not ok then
        return false, reason, nil
    end

    staged = {}
    return true, nil, corrections
end

--- Discards anything staged but not committed.
function BiceData.LsSliders.Discard()
    staged = {}
end

--- Switches the custom leadership slider AI on or off.
function BiceData.LsSliders.SetActive(enabled)
    BiceData.AiSettings.SetActive(USES, ACTIVE, enabled)
end
