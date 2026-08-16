-- Traits page for the in-game ImGui utility.
--
-- All parsing and effect translation lives in BiceData.Traits, so this page works
-- with the wxWidgets utility disabled. It is only the shape of the data the overlay
-- wants, nothing more.

BiceLibGui = BiceLibGui or {}
BiceLibGui.Traits = {}

-- Sorted "Translated name [key]" for every trait.
function BiceLibGui.Traits.Collect()
    local ok, result = pcall(function()
        return { available = true, traits = BiceData.Traits.Choices() }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Effects for a bare trait key. Shared with the Generals page, which lists a
-- leader's traits and shows the effects of the selected one.
function BiceLibGui.Traits.EffectsForKey(key)
    local ok, result = pcall(function()
        if BiceData.Traits.Get(key) == nil then
            return { available = false, reason = "Unknown trait: " .. tostring(key) }
        end
        -- true: skip allowed_leader, it is noise when looking at a specific leader
        return { available = true, effects = BiceData.Traits.DumpEffects(key, true) }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

-- Effects and triggers for one choice string, fetched when the selection changes.
function BiceLibGui.Traits.Details(choice)
    local ok, result = pcall(function()
        local key = BiceData.Translations.KeyFromChoice(choice)
        if BiceData.Traits.Get(key) == nil then
            return { available = false, reason = "Unknown trait: " .. tostring(choice) }
        end
        return {
            available = true,
            key = key,
            effects = BiceData.Traits.DumpEffects(key),
            triggers = BiceData.Traits.DumpTriggers(key),
        }
    end)

    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end
