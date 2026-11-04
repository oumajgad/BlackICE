-- Resource Conversion page for the in-game ImGui utility.
--
-- Shows and sets the player's own energy-to-crude-oil and crude-oil-to-fuel conversion.
-- The game state is read and written in BiceData.ResourceConversion; this only shapes
-- it for the overlay.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.ResourceConversion = {}

local function collect()
    local data, reason = BiceData.ResourceConversion.Collect()
    if data == nil then
        return { available = false, reason = reason or "unavailable" }
    end
    data.available = true
    return data
end

function BiceLibGui.ResourceConversion.Collect()
    return Page.Guard(collect)
end

function BiceLibGui.ResourceConversion.Set(field, value)
    return Page.Guard(function()
        local ok, reason = BiceData.ResourceConversion.Set(field, value)
        return { ok = ok == true, reason = reason or "" }
    end)
end
