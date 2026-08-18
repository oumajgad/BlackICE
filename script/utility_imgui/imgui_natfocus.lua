-- National Focus page for the in-game ImGui utility.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.NatFocus = {}

local function snapshot()
    local data, reason = BiceData.NatFocus.Collect()
    if data == nil then
        return { available = false, reason = reason or "unavailable" }
    end
    return { available = true, tag = data.tag, active = data.active, rows = data.rows }
end

function BiceLibGui.NatFocus.Collect()
    return Page.Guard(snapshot)
end

-- Sets the focus and returns the refreshed table, so the page shows what the game
-- holds rather than assuming the command landed.
function BiceLibGui.NatFocus.Set(index)
    return Page.Guard(function()
        BiceData.NatFocus.Set(index)
        return snapshot()
    end)
end
