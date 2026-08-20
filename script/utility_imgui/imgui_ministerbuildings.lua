-- Minister Buildings page for the in-game ImGui utility.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.MinisterBuildings = {}

local function snapshot()
    local data, reason = BiceData.MinisterBuildings.Collect()
    if data == nil then
        return { available = false, reason = reason or "unavailable" }
    end
    return { available = true, tag = data.tag, rows = data.rows }
end

function BiceLibGui.MinisterBuildings.Collect()
    return Page.Guard(snapshot)
end
