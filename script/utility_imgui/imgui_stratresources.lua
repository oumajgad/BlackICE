-- Strategic Resources page for the in-game ImGui utility.

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
    local ok, result = pcall(snapshot)
    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Toggles selling for one resource and returns the refreshed table, so the page shows
-- what the game holds rather than assuming the command landed.
function BiceLibGui.StratResources.SetSelling(resource, enabled)
    local ok, result = pcall(function()
        BiceData.StratResources.SetSelling(resource, enabled ~= 0)
        return snapshot()
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
