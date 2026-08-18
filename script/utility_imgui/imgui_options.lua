-- Options page for the in-game ImGui utility.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.Options = {}

local function snapshot()
    local data = BiceData.Options.Collect()
    data.available = true
    return data
end

function BiceLibGui.Options.Collect()
    return Page.Guard(snapshot)
end

-- 0 is left, 1 is center: the bridge passes a number, and a mode name would need a
-- call shape that carries a string as well as identifying which setting to change.
local function modeName(value)
    if value == 0 then
        return "left"
    end
    return "center"
end

local function applied(ok, reason)
    local result = snapshot()
    result.ok = (ok == true)
    result.reason = reason or ""
    return result
end

function BiceLibGui.Options.SetMessagePopups(mode)
    return Page.Guard(function()
        return applied(BiceData.Options.SetMessagePopups(modeName(mode)))
    end)
end

function BiceLibGui.Options.SetEventPopups(mode)
    return Page.Guard(function()
        return applied(BiceData.Options.SetEventPopups(modeName(mode)))
    end)
end
