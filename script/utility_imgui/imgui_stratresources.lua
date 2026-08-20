-- Strategic Resources page for the in-game ImGui utility.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.StratResources = {}

local function snapshot()
    local data, reason = BiceData.StratResources.Collect()
    if data == nil then
        return { available = false, reason = reason or "unavailable" }
    end
    return { available = true, tag = data.tag, rows = data.rows }
end

function BiceLibGui.StratResources.Collect()
    return Page.Guard(snapshot)
end

-- Toggles selling for one resource and returns the refreshed table, so the page shows
-- what the game holds rather than assuming the command landed.
function BiceLibGui.StratResources.SetSelling(resource, enabled)
    return Page.Guard(function()
        BiceData.StratResources.SetSelling(resource, enabled ~= 0)
        return snapshot()
    end)
end
