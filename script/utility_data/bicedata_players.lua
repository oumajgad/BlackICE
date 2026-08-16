-- Which countries are human controlled, and which one the utility reports on.
--
-- Port of utility/main/setup.lua without the wx choice control. G_PlayerCountry stays
-- a global because the wxWidgets pages still read it; once they are gone it can move
-- in here.

BiceData = BiceData or {}
BiceData.Players = {}

--- Human players in the current game, as tag strings.
function BiceData.Players.Determine()
    local players = {}
    for tag, countryTag in pairs(GetCountryIterCacheDict()) do
        if CCurrentGameState.IsPlayer(countryTag) then
            table.insert(players, tostring(tag))
        end
    end
    table.sort(players)

    -- Kept in sync so the wx Setup tab and this one agree while both exist.
    G_PlayerCountries = players
    return players
end

--- A player can stop the multiplayer host inspecting their country.
function BiceData.Players.AllowsSelection(tag)
    local country = CCountryDataBase.GetTag(tag)
    if country == nil then
        return false
    end
    return country:GetCountry():GetVariables():GetVariable(CString("disable_gui_access")):Get() ~= 1
end

--- The country pages report on: the Setup selection, else the actual player.
function BiceData.Players.CurrentTag()
    if G_PlayerCountry ~= nil then
        return tostring(G_PlayerCountry), "Setup"
    end
    local actual = CCurrentGameState.GetPlayer()
    if actual == nil then
        return nil, nil
    end
    return tostring(actual), "current player"
end

--- Sets the country pages report on. Returns false if that player opted out.
function BiceData.Players.Select(tag)
    if tag == nil or tag == "" then
        return false
    end
    tag = string.upper(tag)

    if not BiceData.Players.AllowsSelection(tag) then
        return false
    end
    G_PlayerCountry = tag

    -- Keep the wx utility consistent while both UIs exist.
    if GuiRefreshLoop ~= nil then
        G_DaysSinceLastUpdate = 0
        GuiRefreshLoop(true)
    end
    return true
end
