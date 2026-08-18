-- Country Info page for the in-game ImGui utility.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.CountryInfo = {}

function BiceLibGui.CountryInfo.Collect()
    return Page.Guard(function()
        local info, reason = BiceData.CountryInfo.Collect()
        if info == nil then
            return { available = false, reason = reason or "unavailable" }
        end
        return { available = true, tag = info.tag, sections = info.sections }
    end)
end
