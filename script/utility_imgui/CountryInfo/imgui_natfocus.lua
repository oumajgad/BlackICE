-- National Focus page for the in-game ImGui utility.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.NatFocus = {}

local function snapshot()
    local data, reason = BiceData.NatFocus.Collect()
    if data == nil then
        return { available = false, reason = reason or "unavailable" }
    end
    return { available = true, tag = data.tag, active = data.active, rows = data.rows }
end

function BiceLibGui.NatFocus.Collect()
    return Page.Guard(snapshot)
end

-- Sets the focus and returns the refreshed table, so the page shows what the game
-- holds rather than assuming the command landed.
function BiceLibGui.NatFocus.Set(index)
    return Page.Guard(function()
        BiceData.NatFocus.Set(index)
        return snapshot()
    end)
end

-- Every focus effect, flattened to one row each so the bridge can read it without
-- nesting: the focus, which tier grants it, and the effect itself.
--
-- Static once the mod's files are parsed, so a page fetches this once rather than on
-- every refresh. Feeds both the Effect column here and the National Focus help page.
function BiceLibGui.NatFocus.Effects()
    return Page.Guard(function()
        local rows = {}
        for _, focus in ipairs(BiceData.NatFocus.Effects()) do
            for tier, entries in ipairs(focus.tiers) do
                for _, effect in ipairs(entries) do
                    table.insert(rows, {
                        key = focus.key,
                        name = focus.name,
                        tier = tier,
                        label = effect.label,
                        value = effect.value,
                    })
                end
            end
        end

        -- As strings, because the bridge reads arrays of those but not of numbers.
        local tierLabels = {}
        for _, days in ipairs(BiceData.NatFocus.Tiers()) do
            table.insert(tierLabels, tostring(days) .. " days")
        end

        return { available = true, rows = rows, tierLabels = tierLabels }
    end)
end
