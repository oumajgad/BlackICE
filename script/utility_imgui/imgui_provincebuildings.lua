-- Province Buildings page for the in-game ImGui utility.

BiceLibGui = BiceLibGui or {}
BiceLibGui.ProvinceBuildings = {}

function BiceLibGui.ProvinceBuildings.Collect()
    local ok, result = pcall(function()
        return { available = true, buildings = BiceData.ProvinceBuildings.Choices() }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Provinces holding the building. Sorting and grouping are left to the caller.
function BiceLibGui.ProvinceBuildings.Provinces(buildingChoice)
    local ok, result = pcall(function()
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

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

function BiceLibGui.ProvinceBuildings.Details(provinceId)
    local ok, result = pcall(function()
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

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
