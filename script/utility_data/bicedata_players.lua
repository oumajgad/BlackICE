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
    local vars = BiceData.Country.VariablesOf(tag)
    if vars == nil then
        return false
    end
    return BiceData.Country.Get(vars, "disable_gui_access") ~= 1
end

-- True while G_PlayerCountry holds an automatic choice rather than a deliberate one.
local autoSelected = false

--- The country pages report on.
---
--- Selects the player's own country automatically when nothing has been chosen, so
--- every page has a country to work with without visiting Setup first. Pages that read
--- G_PlayerCountry directly (tech levels, for one) would otherwise report nothing while
--- pages with their own fallback reported correctly, which looked like a bug.
function BiceData.Players.CurrentTag()
    local actual = CCurrentGameState.GetPlayer()
    local actualTag = actual ~= nil and tostring(actual) or nil

    if G_PlayerCountry == nil then
        if actualTag == nil then
            return nil, nil
        end
        G_PlayerCountry = actualTag
        autoSelected = true
    elseif autoSelected and actualTag ~= nil and actualTag ~= G_PlayerCountry then
        -- Loading a different save leaves the automatic choice pointing at the
        -- previous game's country. A deliberate choice is left alone.
        G_PlayerCountry = actualTag
    end

    return tostring(G_PlayerCountry), autoSelected and "auto" or "Setup"
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
    autoSelected = false -- A deliberate choice; stop re-syncing it to the player

    -- Keep the wx utility consistent while both UIs exist.
    if GuiRefreshLoop ~= nil then
        G_DaysSinceLastUpdate = 0
        GuiRefreshLoop(true)
    end
    return true
end
