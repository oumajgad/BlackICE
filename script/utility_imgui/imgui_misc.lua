-- Misc page for the in-game ImGui utility.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.Misc = {}

local function snapshot()
    local data, reason = BiceData.Misc.Collect()
    if data == nil then
        return { available = false, reason = reason or "unavailable" }
    end

    data.available = true
    return data
end

function BiceLibGui.Misc.Collect()
    return Page.Guard(snapshot)
end

-- Each setter returns the refreshed state, so the page shows what the game holds
-- rather than assuming the command landed.
function BiceLibGui.Misc.SetTradeHidden(hidden)
    return Page.Guard(function()
        BiceData.Misc.SetTradeHidden(hidden ~= 0)
        return snapshot()
    end)
end

function BiceLibGui.Misc.SetMinesHidden(hidden)
    return Page.Guard(function()
        BiceData.Misc.SetMinesHidden(hidden ~= 0)
        return snapshot()
    end)
end
