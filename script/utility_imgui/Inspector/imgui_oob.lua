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

--- The names of a run of sub unit types, given their keys joined by semicolons.
---
--- In bulk because the caller knows the whole set at once: a country fields a few
--- dozen kinds of regiment, and asking for them one at a time would be a few dozen
--- calls across the boundary for one table. Semicolons because that is what the
--- localisation files themselves separate on, so no key can contain one.
---
--- The answer is an array in the order asked, holding the empty string where a key
--- has no localisation - the caller shows the key itself in that case, which says
--- plainly that the entry is missing rather than leaving a blank.
function BiceLibGui.Oob.TypeNames(joinedKeys)
    return Page.Guard(function()
        local names = {}

        for key in string.gmatch(tostring(joinedKeys or ""), "([^;]+)") do
            table.insert(names, BiceData.Translations.Get(key) or "")
        end

        return { available = true, names = names }
    end)
end
