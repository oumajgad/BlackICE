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
    local vars, tag = BiceData.Country.Variables()
    if vars == nil then
        return nil, "No country selected"
    end

    local active = BiceData.Country.Get(vars, "national_focus")

    local rows = {}
    for index, focus in ipairs(FOCUSES) do
        -- The counter decays towards zero after a focus is dropped, and can be left
        -- slightly negative by the rounding in CalculateFocuses.
        local days = BiceData.Country.Get(vars, focus.key .. "_national_focus_days_active")
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

-- What each focus gives at each tier, read once from the mod's triggered modifiers.
local effects = nil

--- Builds focus key -> tier -> { key, label, value } rows.
---
--- The modifiers are named Nat_focus_<focus>_one / _two / _three, and a tier holding
--- more than five effects is split across _I and _II entries, because five is all the
--- game's own modifier tooltip shows. Both halves apply at once, so they are merged
--- here - and matched by prefix rather than by an assumed suffix, since the naming is
--- not consistent from one focus to the next.
local function collectEffects()
    if effects ~= nil then
        return effects
    end

    local words = { "one", "two", "three" }
    effects = {}

    for _, focus in ipairs(FOCUSES) do
        effects[focus.key] = { {}, {}, {} }

        for tier, word in ipairs(words) do
            local prefix = "Nat_focus_" .. focus.key .. "_" .. word
            local merged = {}

            for _, choice in ipairs(BiceData.Modifiers.Choices()) do
                local name = BiceData.Translations.KeyFromChoice(choice)
                -- Either the whole name or a variant of it, never a longer word that
                -- merely starts the same way.
                if name == prefix or string.sub(name, 1, #prefix + 1) == prefix .. "_" then
                    for key, value in pairs(BiceData.Modifiers.Get(name) or {}) do
                        if key ~= "potential" and key ~= "trigger" and key ~= "icon" then
                            -- A key repeated in one modifier parses as a list, and the
                            -- last one is what the game applies.
                            merged[key] = (type(value) == "table") and value[#value] or value
                        end
                    end
                end
            end

            local rows = {}
            for key, value in pairs(merged) do
                table.insert(rows, {
                    key = key,
                    label = BiceData.Modifiers.TranslateEffectKey(key),
                    value = BiceData.Translations.ConvertEffect(key, value),
                })
            end
            table.sort(rows, function(a, b) return a.label < b.label end)
            effects[focus.key][tier] = rows
        end
    end

    return effects
end

--- Every focus with its three tiers of effects, for the help table.
function BiceData.NatFocus.Effects()
    local all = collectEffects()

    local rows = {}
    for index, focus in ipairs(FOCUSES) do
        table.insert(rows, {
            index = index,
            key = focus.key,
            name = focus.name,
            tiers = all[focus.key],
        })
    end
    return rows
end

--- The effects one focus grants at a tier, 1 to 3. Empty for anything else.
function BiceData.NatFocus.EffectsAt(focusKey, tier)
    local all = collectEffects()
    if all[focusKey] == nil or tier == nil or tier < 1 or tier > #TIERS then
        return {}
    end
    return all[focusKey][tier]
end

--- Switches the focus. Index 0 clears it.
function BiceData.NatFocus.Set(index)
    local tag = BiceData.Players.CurrentTag()
    if tag == nil or index == nil then
        return
    end

    BiceData.Country.Set(tag, "national_focus", index)
end
