-- Statistics collection: the switches, the country list and where the data lands.
--
-- Collection itself is not here. It runs from the OMG handlers on the game's own tick
-- (utility/stats/stats.lua) and must stay there - the overlay draws on the render
-- thread and has no business owning a daily loop. This only reports and flips switches.
--
-- The switches live on the OMG country so every Lua context sees the same values.

BiceData = BiceData or {}
BiceData.Stats = {}

local OMG = "OMG"
local TOGGLE = "StatisticsToggle"
local CUSTOM_LIST = "StatisticsCustomList"
local CUSTOM_LIST_VERSION = "StatisticsCustomListVersion"
local IDENT = "StatisticsIdent"
local PER_COUNTRY = "zStatsCustomList_"

local function omgVariables()
    return BiceData.Country.VariablesOf(OMG)
end

--- Every country tag in the game, sorted.
local function countryTags()
    local tags = {}
    for country in CCurrentGameState.GetCountries() do
        local tag = tostring(country:GetCountryTag())
        -- The rebel placeholder, which has no statistics worth collecting.
        if tag ~= "---" then
            table.insert(tags, tag)
        end
    end
    table.sort(tags)
    return tags
end

--- The switches, the run number and the countries being collected.
function BiceData.Stats.Collect()
    local vars = omgVariables()
    if vars == nil then
        return nil, "No game session"
    end

    local tags = countryTags()
    local custom = {}
    for _, tag in ipairs(tags) do
        if BiceData.Country.Get(vars, PER_COUNTRY .. tag) == 1 then
            table.insert(custom, tag)
        end
    end

    -- Read, never assigned: assigning it writes files and spawns a command prompt, and
    -- a page being drawn should not do that. The collection loop assigns it on its
    -- first pass, which is also the first moment there is anything to number.
    local ident = BiceData.Country.Get(vars, IDENT)

    return {
        collecting = BiceData.Country.Get(vars, TOGGLE) == 1,
        customListActive = BiceData.Country.Get(vars, CUSTOM_LIST) == 1,
        ident = ident,
        -- Relative to the game directory, as the collection loop writes it.
        path = "tfh/mod/BlackICE " .. tostring(G_MOD_VERSION) .. "/stats",
        -- The plotting tool takes it as an argument, so it is passed rather than
        -- picked back out of the path.
        version = tostring(G_MOD_VERSION),
        countries = tags,
        custom = custom,
    }, nil
end

--- Switches collection on or off for every context.
function BiceData.Stats.SetCollecting(enabled)
    BiceData.Country.Set(OMG, TOGGLE, enabled and 1 or 0)
end

--- Switches between collecting for every player and only the custom list.
function BiceData.Stats.SetCustomListActive(enabled)
    BiceData.Country.Set(OMG, CUSTOM_LIST, enabled and 1 or 0)
end

--- Bumped on every edit so a context caching the list knows to rebuild it.
local function bumpListVersion()
    local vars = omgVariables()
    local version = (vars ~= nil) and BiceData.Country.Get(vars, CUSTOM_LIST_VERSION) or 0
    BiceData.Country.Set(OMG, CUSTOM_LIST_VERSION, version + 1)
end

--- Adds or removes one country from the custom collection list.
function BiceData.Stats.SetCountryCollected(tag, collected)
    if tag == nil or tag == "" then
        return
    end

    BiceData.Country.Set(OMG, PER_COUNTRY .. tag, collected and 1 or 0)
    bumpListVersion()

    -- Keeps this context's own cache honest; other contexts follow the version.
    if Stats ~= nil and Stats.CustomCountryList ~= nil then
        Stats.CustomCountryList[tag] = collected and true or false
    end
end
