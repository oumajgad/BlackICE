-- Unit Models page for the in-game ImGui utility.
--
-- Lists a country's unit models, the techs each requires next to what the country has
-- researched, and which sprite file the game will draw for it.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.UnitModels = {}

function BiceLibGui.UnitModels.Collect()
    return Page.Guard(function()
        local tag = BiceData.Players.CurrentTag()
        if tag == nil then
            return { available = false, reason = "No country selected" }
        end

        local choices = BiceData.UnitModels.Choices(tag)
        if #choices == 0 then
            return { available = false, reason = "No unit models for " .. tag }
        end
        return { available = true, tag = tag, models = choices }
    end)
end

function BiceLibGui.UnitModels.Details(choice)
    return Page.Guard(function()
        local tag = BiceData.Players.CurrentTag()
        if tag == nil then
            return { available = false, reason = "No country selected" }
        end

        local ident = BiceData.Translations.KeyFromChoice(choice)
        local imagePath, imageStatus = BiceData.UnitModels.Image(tag, ident)

        return {
            available = true,
            key = ident,
            techs = BiceData.UnitModels.TechList(tag, ident),
            image_path = imagePath or "",
            image_status = imageStatus or "",
        }
    end)
end
