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
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return {}
    end

    local country = CCountryDataBase.GetTag(tag):GetCountry()
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

    local country = CCountryDataBase.GetTag(puppetTag):GetCountry()
    if country == nil then
        return 0
    end
    return country:GetVariables():GetVariable(CString("puppet_focus_variable")):Get()
end

--- Sets a puppet's production focus.
function BiceData.Puppets.SetFocus(puppetTag, focusIndex)
    if puppetTag == nil or puppetTag == "" then
        return
    end

    local target = CCountryDataBase.GetTag(puppetTag)
    local command = CSetVariableCommand(target, CString("puppet_focus_variable"), CFixedPoint(focusIndex))
    CCurrentGameState.Post(command)
end

--- Whether the in-game decision for setting puppet focus is available to the player.
--- The variable is inverted: 1 means disabled.
function BiceData.Puppets.FocusDecisionEnabled()
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return false
    end

    local country = CCountryDataBase.GetTag(tag):GetCountry()
    if country == nil then
        return false
    end
    return country:GetVariables():GetVariable(CString("disable_pupped_focus_decision")):Get() ~= 1
end

function BiceData.Puppets.SetFocusDecisionEnabled(enabled)
    local tag = BiceData.Players.CurrentTag()
    if tag == nil then
        return
    end

    local command = CSetVariableCommand(CCountryDataBase.GetTag(tag),
        CString("disable_pupped_focus_decision"), CFixedPoint(enabled and 0 or 1))
    CCurrentGameState.Post(command)
end
