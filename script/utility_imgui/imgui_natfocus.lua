-- National Focus page for the in-game ImGui utility.

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
    local ok, result = pcall(snapshot)
    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Sets the focus and returns the refreshed table, so the page shows what the game
-- holds rather than assuming the command landed.
function BiceLibGui.NatFocus.Set(index)
    local ok, result = pcall(function()
        BiceData.NatFocus.Set(index)
        return snapshot()
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
