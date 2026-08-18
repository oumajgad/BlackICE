-- Province Buildings page for the in-game ImGui utility.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.ProvinceBuildings = {}

function BiceLibGui.ProvinceBuildings.Collect()
    return Page.Guard(function()
        return { available = true, buildings = BiceData.ProvinceBuildings.Choices() }
    end)
end

-- Provinces holding the building. Sorting and grouping are left to the caller.
function BiceLibGui.ProvinceBuildings.Provinces(buildingChoice)
    return Page.Guard(function()
        local tag = BiceData.Players.CurrentTag()
        if tag == nil then
            return { available = false, reason = "No country selected" }
        end

        local key = BiceData.Translations.KeyFromChoice(buildingChoice)
        return {
            available = true,
            tag = tag,
            key = key,
            provinces = BiceData.ProvinceBuildings.Provinces(key),
        }
    end)
end

function BiceLibGui.ProvinceBuildings.Details(provinceId)
    return Page.Guard(function()
        local details, reason = BiceData.ProvinceBuildings.Details(provinceId)
        if details == nil then
            return { available = false, reason = reason or "unavailable" }
        end
        return {
            available = true,
            id = details.id,
            values = details.values,
            modifiers = details.modifiers,
        }
    end)
end
