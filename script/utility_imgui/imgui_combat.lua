-- Combat Reports page for the in-game ImGui utility.
--
-- The page reads its combats out of memory itself; the only thing it needs from Lua is
-- which campaign is being played, so it knows which file its record belongs to.

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
