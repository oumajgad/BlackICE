-- Order of battle pages for the in-game ImGui utility.
--
-- The OOB browser reads its units straight out of the game's memory, so unlike the
-- other pages it needs almost nothing from Lua. The exception is province names:
-- those are not in memory at all, they are localisation, and the translation table
-- lives here.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.Oob = {}

--- The name of a province, from its id.
--- Answers with the empty string rather than a reason when there is no localisation
--- for it: the page falls back to showing the id on its own, which is still useful.
function BiceLibGui.Oob.ProvinceName(provinceId)
    return Page.Guard(function()
        local id = tonumber(provinceId)
        if id == nil then
            return { available = false, reason = "not a province id" }
        end

        return {
            available = true,
            name = BiceData.Translations.Get(tostring(id), "PROV") or "",
        }
    end)
end
