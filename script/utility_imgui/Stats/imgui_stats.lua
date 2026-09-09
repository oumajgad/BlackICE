-- Statistics pages for the in-game ImGui utility.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.Stats = {}

local function snapshot()
    local data, reason = BiceData.Stats.Collect()
    if data == nil then
        return { available = false, reason = reason or "unavailable" }
    end

    data.available = true
    return data
end

function BiceLibGui.Stats.Collect()
    return Page.Guard(snapshot)
end

function BiceLibGui.Stats.SetCollecting(enabled)
    return Page.Guard(function()
        BiceData.Stats.SetCollecting(enabled ~= 0)
        return snapshot()
    end)
end

function BiceLibGui.Stats.SetCustomListActive(enabled)
    return Page.Guard(function()
        BiceData.Stats.SetCustomListActive(enabled ~= 0)
        return snapshot()
    end)
end

-- Takes the tag and a 1/0, which is the call shape the bridge has for a string plus a
-- number.
function BiceLibGui.Stats.SetCountryCollected(tag, collected)
    return Page.Guard(function()
        BiceData.Stats.SetCountryCollected(tag, collected ~= 0)
        return snapshot()
    end)
end
