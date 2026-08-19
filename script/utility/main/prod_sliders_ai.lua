-- Production sliders AI tab.
--
-- The categories, their defaults and the rule that no two may share a priority live in
-- BiceData.ProdSliders, shared with the ImGui utility. This keeps the wx half: which
-- control holds which field.
--
-- The priority check now happens inside Commit, so a clash leaves the game untouched
-- rather than posting the categories that happened to be checked first.

local function control(name)
    return UI[name]
end

local function readNumber(widget, fallback)
    if widget == nil then
        return fallback
    end
    return tonumber(widget:GetValue()) or fallback
end

local function readFlag(widget, fallback)
    if widget == nil then
        return fallback
    end
    return Utils.BoolToNumber(widget:GetValue())
end

function SetCustomProductionSliderAiStatusText(status)
    UI.m_textCtrl_customProdSlider_state:SetValue(status and "Active" or "Inactive")
end

function DetermineCustomProductionSliderAiStatus()
    local data = BiceData.ProdSliders.Collect()
    if data == nil then
        return
    end
    SetCustomProductionSliderAiStatusText(data.active)
end

--- True when two categories claim the same priority, and marks the offenders.
---
--- Commit refuses such a set on its own; this is only so the page still says which
--- control to look at, as it always did.
function CheckCustomProductionSliderPrioConflict()
    local data = BiceData.ProdSliders.Collect()
    if data == nil then
        return true
    end

    local seen = {}
    for _, row in ipairs(data.rows) do
        local widget = control("m_textCtrl_customProdSlider_" .. row.key .. "Prio")
        local prio = tonumber(widget ~= nil and widget:GetValue() or nil)

        if prio == nil then
            return true
        end
        if seen[prio] then
            widget:SetValue("CONFLICT")
            return true
        end
        seen[prio] = true
    end
    return false
end

function SetCustomProductionSliderValues()
    local data = BiceData.ProdSliders.Collect()
    if data == nil or CheckCustomProductionSliderPrioConflict() then
        return
    end

    BiceData.ProdSliders.Discard()

    for _, row in ipairs(data.rows) do
        local prefix = "m_textCtrl_customProdSlider_" .. row.key
        BiceData.ProdSliders.SetValue(row.key .. "Prio", readNumber(control(prefix .. "Prio"), row.prio))
        BiceData.ProdSliders.SetValue(row.key .. "Amount", readNumber(control(prefix .. "Amount"), row.amount))

        local mode = control("m_choice_customProdSlider_" .. row.key .. "Mode")
        BiceData.ProdSliders.SetValue(row.key .. "InvestMode",
            mode ~= nil and mode:GetSelection() or row.mode)

        if row.extra == "limit" then
            BiceData.ProdSliders.SetValue(row.key .. "Limit",
                readNumber(control(prefix .. "Limit"), row.limit))
            BiceData.ProdSliders.SetValue(row.key .. "Limit_active",
                readFlag(control("m_checkBox_customProdSlider_" .. row.key .. "Limit"), 0))
        elseif row.extra == "goal" then
            BiceData.ProdSliders.SetValue("supplyGoal",
                readNumber(control("m_textCtrl_customProdSlider_supplyGoal"), row.goal))
            BiceData.ProdSliders.SetValue("supplyGoal_active",
                readFlag(control("m_checkBox_customProdSlider_supplyGoal"), 0))
        elseif row.extra == "dissent" then
            BiceData.ProdSliders.SetValue("reduceDissent",
                readFlag(control("m_checkBox_customProdSlider_reduceDissent"), 0))
        end
    end

    BiceData.ProdSliders.Commit()
end

function SetCustomProductionSliderAiStatus()
    local data = BiceData.ProdSliders.Collect()
    if data == nil then
        return
    end

    if data.active then
        BiceData.ProdSliders.SetActive(false)
        SetCustomProductionSliderAiStatusText(false)
        return
    end

    SetCustomProductionSliderValues()
    BiceData.ProdSliders.SetActive(true)
    SetCustomProductionSliderAiStatusText(true)
end

function ReadCustomProductionSliderValues()
    local data = BiceData.ProdSliders.Collect()
    if data == nil or not data.configured then
        return -- leaves the defaults the controls start with
    end

    for _, row in ipairs(data.rows) do
        local prefix = "m_textCtrl_customProdSlider_" .. row.key
        control(prefix .. "Prio"):SetValue(string.format('%.0f', row.prio))
        control(prefix .. "Amount"):SetValue(string.format('%.0f', row.amount))
        control("m_choice_customProdSlider_" .. row.key .. "Mode"):SetSelection(row.mode)

        if row.extra == "limit" then
            control(prefix .. "Limit"):SetValue(string.format('%.0f', row.limit))
            control("m_checkBox_customProdSlider_" .. row.key .. "Limit"):SetValue(row.limitActive)
        elseif row.extra == "goal" then
            control("m_textCtrl_customProdSlider_supplyGoal"):SetValue(string.format('%.0f', row.goal))
            control("m_checkBox_customProdSlider_supplyGoal"):SetValue(row.goalActive)
        elseif row.extra == "dissent" then
            control("m_checkBox_customProdSlider_reduceDissent"):SetValue(row.reduceDissent)
        end
    end
end
