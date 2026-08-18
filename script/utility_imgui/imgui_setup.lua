-- Setup page for the in-game ImGui utility.
--
-- Owns G_PlayerCountry, the country every other page reports on. In multiplayer the
-- host can inspect another player's country, subject to that player's opt out.
--
-- Player queries live in BiceData.Players, so this page works with the wxWidgets
-- utility disabled - its own setup.lua touches the wx choice control directly.
--
-- The wx Setup tab also owned a refresh interval for its single global refresh loop.
-- That has no equivalent here: each ImGui page refreshes itself.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.Setup = {}

local function collect()
    local tag, source = BiceData.Players.CurrentTag()
    local actual = CCurrentGameState.GetPlayer()

    return {
        available = true,
        players = G_PlayerCountries or {},
        selected = G_PlayerCountry or "",
        current = tag or "",
        source = source or "",
        actual_player = actual ~= nil and tostring(actual) or "",
    }
end

function BiceLibGui.Setup.Collect()
    return Page.Guard(collect)
end

-- Just the country every page reports on. Kept separate from Collect() because the
-- overlay polls this centrally for all pages, so it has to stay as cheap as possible.
function BiceLibGui.Setup.CurrentTag()
    return Page.Guard(function()
        local tag, source = BiceData.Players.CurrentTag()
        if tag == nil then
            return { available = false, reason = "No player country" }
        end
        return { available = true, tag = tag, source = source }
    end)
end

function BiceLibGui.Setup.RefreshPlayers()
    pcall(BiceData.Players.Determine)
end

function BiceLibGui.Setup.SelectPlayer(tag)
    local ok, err = pcall(BiceData.Players.Select, tag)
    if not ok and BiceLibLuaLog ~= nil then
        BiceLibLuaLog("Setup.SelectPlayer failed: " .. tostring(err))
    end
end
