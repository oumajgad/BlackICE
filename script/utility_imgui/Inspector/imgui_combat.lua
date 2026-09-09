-- Combat Reports page for the in-game ImGui utility.
--
-- The page reads its combats out of memory itself; what it needs from Lua is which
-- campaign is being played, so it knows which file its record belongs to, and which
-- session within it, so it knows which of the timelines in that file is the one being
-- played. See utility_data/bicedata_combat.lua for what a session is.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.Combat = {}

--- The campaign's number, claiming one if this campaign has none yet.
--- Answers 0 while a freshly claimed number is still queued, which the caller handles
--- by asking again rather than by waiting.
function BiceLibGui.Combat.Campaign()
    return Page.Guard(function()
        local tag = BiceData.Players.CurrentTag()
        if tag == nil then
            return { available = false, reason = "No player country yet" }
        end

        return {
            available = true,
            tag = tag,
            id = BiceData.Combat.EnsureId(),
        }
    end)
end

--- The session number the game is holding, and a nudge to keep holding it.
---
--- `expected` is the session the caller believes it is in; pass 0 to only read. A
--- mismatch means either that a claim has not landed yet or that a savegame from
--- another branch was loaded, and the caller tells those apart, not this.
function BiceLibGui.Combat.Session(expected)
    return Page.Guard(function()
        return {
            available = true,
            id = BiceData.Combat.HoldSession(expected),
        }
    end)
end

--- Starts a new session, answering with it and with the one it descends from.
function BiceLibGui.Combat.NewSession()
    return Page.Guard(function()
        local tag = BiceData.Players.CurrentTag()
        if tag == nil then
            return { available = false, reason = "No player country yet" }
        end

        local id, previous = BiceData.Combat.NewSession()
        return {
            available = true,
            id = id,
            previous = previous,
        }
    end)
end
