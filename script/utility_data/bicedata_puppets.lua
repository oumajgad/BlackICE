-- Puppets: the country's vassals and the production focus each has been given.
--
-- Port of utility/main/puppets.lua, with the wx choice controls removed.

BiceData = BiceData or {}
BiceData.Puppets = {}

-- Index order is the game's: the variable stores these positions, so the list must
-- not be reordered.
local FOCUS_NAMES = {
    [1] = "Rares",
    [2] = "Energy",
    [3] = "Metal",
    [4] = "Navy",
    [5] = "Air",
    [6] = "Army",
    [7] = "Oil",
    [8] = "None",
}

function BiceData.Puppets.FocusNames()
    return FOCUS_NAMES
end

--- Name for a focus index, "None" for anything unrecognised.
function BiceData.Puppets.FocusName(index)
    return FOCUS_NAMES[index] or "None"
end

--- The selected country's vassals, as tag strings.
function BiceData.Puppets.List()
    local country = BiceData.Country.Selected()
    if country == nil then
        return {}
    end

    local vassals = country:GetVassals()
    if not vassals then
        return {}
    end

    local res = {}
    for vassal in vassals do
        table.insert(res, tostring(vassal:GetCountry():GetCountryTag()))
    end
    table.sort(res)
    return res
end

--- The focus index currently set on a puppet, 0 when it has none.
function BiceData.Puppets.Focus(puppetTag)
    if puppetTag == nil or puppetTag == "" then
        return 0
    end

    return BiceData.Country.Get(BiceData.Country.VariablesOf(puppetTag), "puppet_focus_variable")
end

--- Sets a puppet's production focus.
function BiceData.Puppets.SetFocus(puppetTag, focusIndex)
    if puppetTag == nil or puppetTag == "" then
        return
    end

    BiceData.Country.Set(puppetTag, "puppet_focus_variable", focusIndex)
end

--- Whether the in-game decision for setting puppet focus is available to the player.
--- The variable is inverted: 1 means disabled.
function BiceData.Puppets.FocusDecisionEnabled()
    local vars = BiceData.Country.Variables()
    if vars == nil then
        return false
    end
    return BiceData.Country.Get(vars, "disable_pupped_focus_decision") ~= 1
end

function BiceData.Puppets.SetFocusDecisionEnabled(enabled)
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return
    end

    BiceData.Country.Set(tag, "disable_pupped_focus_decision", enabled and 0 or 1)
end
