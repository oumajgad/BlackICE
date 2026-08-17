-- Custom production slider AI: how the AI splits IC between the production categories.
--
-- Port of utility/main/prod_sliders_ai.lua, with the wx controls removed.
--
-- As with the trade AI, values are staged and Commit posts them as one set. Commit is
-- also where the priority rule is enforced: the AI walks the categories in priority
-- order, so two categories sharing a priority makes the order undefined.

BiceData = BiceData or {}
BiceData.ProdSliders = {}

local PREFIX = "zzDsafe_CustomProductionSliders_"
local USES = "zzDsafe_usesCustomProductionSliders"
local ACTIVE = "zzDsafe_CustomProductionSliders_isActive"

-- Defaults are the values the wx controls started with. "extra" names the per category
-- option the page shows next to the mode.
local CATEGORIES = {
    { key = "upgrade",    name = "Upgrades",       prio = 4, amount = 100, mode = 0, extra = "limit", limit = 50 },
    { key = "reinforce",  name = "Reinforcement",  prio = 2, amount = 100, mode = 0, extra = "limit", limit = 50 },
    { key = "supply",     name = "Supply",         prio = 3, amount = 100, mode = 0, extra = "goal",  goal = 50000 },
    { key = "production", name = "Production",     prio = 5, amount = 25,  mode = 1 },
    -- Lend lease is IC only; the wx page showed its mode fixed and disabled.
    { key = "consumer",   name = "Consumer Goods", prio = 1, amount = 100, mode = 0, extra = "dissent" },
    { key = "lendLease",  name = "Lend Lease",     prio = 6, amount = 0,   mode = 0, fixedMode = true },
}

local fields = nil

local function knownFields()
    if fields ~= nil then
        return fields
    end

    fields = {}
    for _, category in ipairs(CATEGORIES) do
        fields[category.key .. "Prio"] = true
        fields[category.key .. "Amount"] = true
        fields[category.key .. "InvestMode"] = true
        if category.extra == "limit" then
            fields[category.key .. "Limit"] = true
            fields[category.key .. "Limit_active"] = true
        end
    end
    fields["supplyGoal"] = true
    fields["supplyGoal_active"] = true
    fields["reduceDissent"] = true
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
function BiceData.ProdSliders.Categories()
    return CATEGORIES
end

--- Current settings, or the wx defaults if this country has never been configured.
function BiceData.ProdSliders.Collect()
    local vars, tag = variables()
    if vars == nil then
        return nil, "No country selected"
    end

    local configured = vars:GetVariable(CString(USES)):Get() == 1

    local function read(name)
        return vars:GetVariable(CString(PREFIX .. name)):Get()
    end

    local rows = {}
    for _, category in ipairs(CATEGORIES) do
        local row = {
            key = category.key,
            name = category.name,
            extra = category.extra or "",
            fixedMode = category.fixedMode == true,
        }

        if configured then
            row.prio = read(category.key .. "Prio")
            row.amount = read(category.key .. "Amount")
            row.mode = read(category.key .. "InvestMode")
        else
            row.prio = category.prio
            row.amount = category.amount
            row.mode = category.mode
        end

        if category.extra == "limit" then
            if configured then
                row.limit = read(category.key .. "Limit")
                row.limitActive = read(category.key .. "Limit_active") == 1
            else
                row.limit = category.limit
                row.limitActive = false
            end
        elseif category.extra == "goal" then
            if configured then
                row.goal = read("supplyGoal")
                row.goalActive = read("supplyGoal_active") == 1
            else
                row.goal = category.goal
                row.goalActive = false
            end
        elseif category.extra == "dissent" then
            row.reduceDissent = configured and read("reduceDissent") == 1 or false
        end

        table.insert(rows, row)
    end

    return {
        tag = tag,
        active = vars:GetVariable(CString(ACTIVE)):Get() == 1,
        configured = configured,
        rows = rows,
    }, nil
end

--- Stages one field. Nothing reaches the game until Commit.
function BiceData.ProdSliders.SetValue(field, value)
    if field == nil or not knownFields()[field] then
        return false, "Unknown field: " .. tostring(field)
    end
    staged[field] = value
    return true, nil
end

--- Posts everything staged, once the priorities check out.
function BiceData.ProdSliders.Commit()
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return false, "No country selected"
    end

    -- Only checked when a full set has been staged; a partial stage cannot be judged
    -- against priorities that were never sent.
    local seen = {}
    for _, category in ipairs(CATEGORIES) do
        local prio = staged[category.key .. "Prio"]
        if prio ~= nil then
            if seen[prio] ~= nil then
                return false, "Priority " .. tostring(prio) .. " used by both " ..
                    seen[prio] .. " and " .. category.name
            end
            seen[prio] = category.name
        end
    end

    local countryTag = CCountryDataBase.GetTag(tag)
    for field, value in pairs(staged) do
        CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(PREFIX .. field), CFixedPoint(value)))
    end
    staged = {}

    CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(USES), CFixedPoint(1)))
    return true, nil
end

--- Discards anything staged but not committed.
function BiceData.ProdSliders.Discard()
    staged = {}
end

--- Switches the custom production slider AI on or off.
function BiceData.ProdSliders.SetActive(enabled)
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
