-- Techs page for the in-game ImGui utility.
--
-- Parsing, level scaling and translation live in BiceData.Techs; this only shapes the
-- data for the overlay.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.Techs = {}

function BiceLibGui.Techs.Collect()
    return Page.Guard(function()
        return { available = true, techs = BiceData.Techs.Choices() }
    end)
end

-- Effects depend on the level being shown, so this takes the level as well as the
-- tech. A level of 0 means "use the player's researched level, or 1 if they have
-- none", which is what the page wants when the selection first changes.
function BiceLibGui.Techs.Details(choice, level)
    return Page.Guard(function()
        local key = BiceData.Translations.KeyFromChoice(choice)
        if BiceData.Techs.Get(key) == nil then
            return { available = false, reason = "Unknown tech: " .. tostring(choice) }
        end

        local playerLevel = BiceData.Techs.PlayerLevel(key)

        local shownLevel = tonumber(level) or 0
        if shownLevel <= 0 then
            shownLevel = playerLevel > 0 and playerLevel or 1
        end

        return {
            available = true,
            key = key,
            player_level = playerLevel,
            shown_level = shownLevel,
            effects = BiceData.Techs.DumpEffects(key, shownLevel),
            requirements = BiceData.Techs.DumpRequirements(key),
        }
    end)
end
