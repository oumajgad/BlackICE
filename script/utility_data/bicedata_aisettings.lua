-- Staging shared by the three custom AI settings pages.
--
-- Trade AI, production sliders and leadership sliders all work the same way: a block of
-- country variables under one prefix, a "uses" flag saying the country has been
-- configured, an "active" flag saying the AI should run, and an edit that is collected
-- in full before any of it is posted.
--
-- Only that scaffolding lives here. What the fields are, what they default to and what
-- counts as a valid set stays with each page, because no two of them agree on it.

BiceData = BiceData or {}
BiceData.AiSettings = {}

--- Stages one field after checking it against the page's whitelist.
---
--- The whitelist is what keeps a mistyped field from quietly creating a variable the
--- AI never reads, which would look exactly like a setting that does not work.
function BiceData.AiSettings.Stage(staged, known, field, value)
    if field == nil or not known[field] then
        return false, "Unknown field: " .. tostring(field)
    end
    staged[field] = value
    return true, nil
end

--- Posts every staged value and marks the country as configured.
---
--- afterField, if given, is called as afterField(countryTag, field, value) for each
--- one - for the odd variable that has to be kept in step with another.
---
--- The caller is expected to empty the staging table afterwards; it is left alone here
--- so a page can keep it if a later step fails.
function BiceData.AiSettings.Post(prefix, staged, usesVariable, afterField)
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return false, "No country selected"
    end

    local countryTag = CCountryDataBase.GetTag(tag)
    for field, value in pairs(staged) do
        BiceData.Country.Set(countryTag, prefix .. field, value)
        if afterField ~= nil then
            afterField(countryTag, field, value)
        end
    end

    BiceData.Country.Set(countryTag, usesVariable, 1)
    return true, nil
end

--- Switches one of the AI blocks on or off.
---
--- Enabling also marks the country configured, so the values on the page - which the
--- caller is expected to have posted first - are the ones the AI starts from.
function BiceData.AiSettings.SetActive(usesVariable, activeVariable, enabled)
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return
    end

    local countryTag = CCountryDataBase.GetTag(tag)
    if enabled then
        BiceData.Country.Set(countryTag, usesVariable, 1)
    end
    BiceData.Country.Set(countryTag, activeVariable, enabled and 1 or 0)
end
