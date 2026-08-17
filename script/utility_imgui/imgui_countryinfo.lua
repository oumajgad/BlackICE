-- Country Info page for the in-game ImGui utility.

BiceLibGui = BiceLibGui or {}
BiceLibGui.CountryInfo = {}

function BiceLibGui.CountryInfo.Collect()
    local ok, result = pcall(function()
        local info, reason = BiceData.CountryInfo.Collect()
        if info == nil then
            return { available = false, reason = reason or "unavailable" }
        end
        return { available = true, tag = info.tag, sections = info.sections }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
