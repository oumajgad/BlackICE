-- National focus: which focus a country is running and how long each has been active.
--
-- Port of utility/main/nat_focus.lua, with the wx text controls removed. The wx page
-- had a button and a days box per focus; here it is one table.

BiceData = BiceData or {}
BiceData.NatFocus = {}

-- The focus is a single country variable, "national_focus", holding an index into this
-- list (0 meaning none). ai_variable.lua's CalculateFocuses counts the days using the
-- same order, so these must stay where they are - reordering them would silently point
-- every focus at the wrong day counter.
local FOCUSES = {
    { key = "ground_forces",        name = "Ground Forces" },
    { key = "air_force",            name = "Air Force" },
    { key = "navy",                 name = "Navy" },
    { key = "economy",              name = "Economy" },
    { key = "science",              name = "Science" },
    { key = "health_and_education", name = "Health + Education" },
    { key = "natural_resources",    name = "Natural Resources" },
}

-- Bonuses step up once a focus has been active for this many days.
local TIERS = { 90, 360, 720 }

--- The day counts at which each bonus tier is reached.
function BiceData.NatFocus.Tiers()
    return TIERS
end

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

local function tierOf(days)
    local tier = 0
    for index, threshold in ipairs(TIERS) do
        if days >= threshold then
            tier = index
        end
    end
    return tier
end

--- The active focus and the days banked against every focus.
function BiceData.NatFocus.Collect()
    local vars, tag = variables()
    if vars == nil then
        return nil, "No country selected"
    end

    local active = vars:GetVariable(CString("national_focus")):Get()

    local rows = {}
    for index, focus in ipairs(FOCUSES) do
        -- The counter decays towards zero after a focus is dropped, and can be left
        -- slightly negative by the rounding in CalculateFocuses.
        local days = vars:GetVariable(CString(focus.key .. "_national_focus_days_active")):Get()
        if days < 0 then
            days = 0
        end

        local tier = tierOf(days)
        table.insert(rows, {
            index = index,
            key = focus.key,
            name = focus.name,
            days = days,
            tier = tier,
            -- 0 once the top tier is reached, so the page knows there is nothing left
            -- to count towards.
            nextTier = TIERS[tier + 1] or 0,
            active = (index == active),
        })
    end

    return { tag = tag, active = active, rows = rows }, nil
end

--- Switches the focus. Index 0 clears it.
function BiceData.NatFocus.Set(index)
    local tag = BiceData.Players.CurrentTag()
    if tag == nil or index == nil then
        return
    end

    local command = CSetVariableCommand(CCountryDataBase.GetTag(tag),
        CString("national_focus"), CFixedPoint(index))
    CCurrentGameState.Post(command)
end
