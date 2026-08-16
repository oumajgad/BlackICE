-- Setup page for the in-game ImGui utility.
--
-- Owns G_PlayerCountry, the country every other page reports on. In multiplayer the
-- host can inspect another player's country, subject to that player's opt out.
--
-- The wx Setup tab also owned a refresh interval for its single global refresh loop.
-- That has no equivalent here: each ImGui page refreshes itself.

BiceLibGui = BiceLibGui or {}
BiceLibGui.Setup = {}

local function collect()
    -- G_PlayerCountries is filled by DeterminePlayers() in utility/main/setup.lua.
    local players = {}
    if G_PlayerCountries ~= nil then
        for _, tag in ipairs(G_PlayerCountries) do
            table.insert(players, tostring(tag))
        end
    end

    local current = G_PlayerCountry
    local actual = CCurrentGameState.GetPlayer()

    return {
        available = true,
        players = players,
        selected = current or "",
        actual_player = actual ~= nil and tostring(actual) or "",
    }
end

function BiceLibGui.Setup.Collect()
    local ok, result = pcall(collect)
    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Just the country every page reports on. Kept separate from Collect() because the
-- overlay polls this centrally for all pages, so it has to stay as cheap as possible.
function BiceLibGui.Setup.CurrentTag()
    local ok, result = pcall(function()
        if G_PlayerCountry ~= nil then
            return { available = true, tag = tostring(G_PlayerCountry), source = "Setup" }
        end
        local actual = CCurrentGameState.GetPlayer()
        if actual == nil then
            return { available = false, reason = "No player country" }
        end
        return { available = true, tag = tostring(actual), source = "current player" }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Rescans for human players. Shared with the wx page, which keeps both UIs agreeing.
function BiceLibGui.Setup.RefreshPlayers()
    pcall(DeterminePlayers)
end

function BiceLibGui.Setup.SelectPlayer(tag)
    local ok, err = pcall(function()
        if tag == nil or tag == "" then
            return
        end
        tag = string.upper(tag)

        -- A player can block the host from inspecting their country.
        if not CheckPlayerAllowsSelection(tag) then
            return
        end

        G_PlayerCountry = tag

        -- Keep the wx utility consistent while both UIs exist. Guarded because these
        -- only exist when G_UtilityEnabled loaded the wx pages.
        if GuiRefreshLoop ~= nil then
            G_DaysSinceLastUpdate = 0
            GuiRefreshLoop(true)
        end
    end)

    if not ok and BiceLibLuaLog ~= nil then
        BiceLibLuaLog("Setup.SelectPlayer failed: " .. tostring(err))
    end
end
