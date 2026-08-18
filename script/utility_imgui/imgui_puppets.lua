-- Puppets page for the in-game ImGui utility.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.Puppets = {}

-- The puppet the page is acting on. Held here so setting a focus needs only the
-- index, which keeps it to a call shape the bridge already has.
local selectedPuppet = nil

local function snapshot()
    local puppets = {}
    for _, tag in ipairs(BiceData.Puppets.List()) do
        table.insert(puppets, {
            tag = tag,
            focus = BiceData.Puppets.FocusName(BiceData.Puppets.Focus(tag)),
        })
    end

    -- Drop a stale selection so the page does not act on a country that is no longer
    -- a vassal.
    local stillVassal = false
    for _, entry in ipairs(puppets) do
        if entry.tag == selectedPuppet then
            stillVassal = true
        end
    end
    if not stillVassal then
        selectedPuppet = nil
    end

    local focusNames = {}
    for i = 1, 8 do
        table.insert(focusNames, BiceData.Puppets.FocusName(i))
    end

    return {
        available = true,
        puppets = puppets,
        focus_names = focusNames,
        selected = selectedPuppet or "",
        selected_focus = selectedPuppet ~= nil and BiceData.Puppets.Focus(selectedPuppet) or 0,
        decision_enabled = BiceData.Puppets.FocusDecisionEnabled(),
    }
end

function BiceLibGui.Puppets.Collect()
    return Page.Guard(snapshot)
end

function BiceLibGui.Puppets.Select(tag)
    return Page.Guard(function()
        selectedPuppet = (tag ~= nil and tag ~= "") and tag or nil
        return snapshot()
    end)
end

function BiceLibGui.Puppets.SetFocus(focusIndex)
    return Page.Guard(function()
        if selectedPuppet == nil then
            return { available = false, reason = "No puppet selected" }
        end
        BiceData.Puppets.SetFocus(selectedPuppet, focusIndex)
        return snapshot()
    end)
end

function BiceLibGui.Puppets.SetDecisionEnabled(enabled)
    return Page.Guard(function()
        BiceData.Puppets.SetFocusDecisionEnabled(enabled ~= 0)
        return snapshot()
    end)
end
