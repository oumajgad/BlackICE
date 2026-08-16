-- Modifiers page for the in-game ImGui utility.
--
-- Parsing and translation live in BiceData.Modifiers; this only shapes the data for
-- the overlay.

BiceLibGui = BiceLibGui or {}
BiceLibGui.Modifiers = {}

function BiceLibGui.Modifiers.Collect()
    local ok, result = pcall(function()
        return { available = true, modifiers = BiceData.Modifiers.Choices() }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

function BiceLibGui.Modifiers.Details(choice)
    local ok, result = pcall(function()
        local key = BiceData.Translations.KeyFromChoice(choice)
        if BiceData.Modifiers.Get(key) == nil then
            return { available = false, reason = "Unknown modifier: " .. tostring(choice) }
        end
        return {
            available = true,
            key = key,
            kind = BiceData.Modifiers.Kind(key) or "",
            effects = BiceData.Modifiers.DumpEffects(key),
            triggers = BiceData.Modifiers.DumpTriggers(key),
        }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
