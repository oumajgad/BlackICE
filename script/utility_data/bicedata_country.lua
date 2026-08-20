-- Country variable access, shared by the provider modules.
--
-- Reading live game state always went through the same steps: resolve the country the
-- pages report on, take its variable set, then read or post one variable at a time.
-- Six providers had grown their own copy of that, so it lives here once.

BiceData = BiceData or {}
BiceData.Country = {}

--- The country a tag names, or nil.
function BiceData.Country.Of(tag)
    if tag == nil or tag == "" then
        return nil
    end
    return CCountryDataBase.GetTag(tag):GetCountry()
end

--- The country the pages report on, and its tag.
function BiceData.Country.Selected()
    local tag = BiceData.Players.CurrentTag()
    local country = BiceData.Country.Of(tag)
    if country == nil then
        return nil, nil
    end
    return country, tag
end

--- Variables of one country, or nil if the tag names no country.
function BiceData.Country.VariablesOf(tag)
    local country = BiceData.Country.Of(tag)
    if country == nil then
        return nil
    end
    return country:GetVariables()
end

--- Variables of the country the pages report on, and its tag.
---
--- Returns nil, nil when there is nothing to report on - at the main menu, or before a
--- country has been selected and none could be picked automatically.
function BiceData.Country.Variables()
    local country, tag = BiceData.Country.Selected()
    if country == nil then
        return nil, nil
    end
    return country:GetVariables(), tag
end

--- Reads a numeric country variable. One that was never set reads as 0.
function BiceData.Country.Get(vars, name)
    if vars == nil then
        return 0
    end
    return vars:GetVariable(CString(name)):Get()
end

--- Queues a change to a country variable.
---
--- Takes either a tag string or a country tag object, so a caller posting a run of
--- variables can resolve the tag once.
---
--- Posting queues rather than applies: reading the variable straight afterwards still
--- returns the old value, so pages have to show the request as pending until the game
--- catches up.
function BiceData.Country.Set(tag, name, value)
    if tag == nil then
        return
    end

    local countryTag = tag
    if type(tag) == "string" then
        countryTag = CCountryDataBase.GetTag(tag)
    end
    CCurrentGameState.Post(CSetVariableCommand(countryTag, CString(name), CFixedPoint(value)))
end
