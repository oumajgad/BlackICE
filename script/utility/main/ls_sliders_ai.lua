-- Leadership sliders AI tab.
--
-- The categories, the defaults and the two rules - the engine's 110 officer limit and
-- a lower threshold never above its upper - live in BiceData.LsSliders, shared with the
-- ImGui utility. This keeps the wx half: which control holds which threshold.
--
-- The clamps happen in Commit, which reports what it had to change; those corrections
-- are written back into the controls so the page shows what the game was actually told.

local function control(name)
    return UI[name]
end

local function thresholdControl(category, bound)
    return control("m_textCtrl_customLsSliderAi_" .. category .. bound)
end

function SetCustomLsSliderAiStatusText(status)
    UI.m_textCtrl_customLsSliderAi_state:SetValue(status and "Active" or "Inactive")
end

function DetermineCustomLsSliderAiStatus()
    local data = BiceData.LsSliders.Collect()
    if data == nil then
        return
    end
    SetCustomLsSliderAiStatusText(data.active)
end

function SetCustomLsSliderValues()
    local data = BiceData.LsSliders.Collect()
    if data == nil then
        return
    end

    BiceData.LsSliders.Discard()

    for _, row in ipairs(data.rows) do
        local lower = thresholdControl(row.key, "Lower")
        local upper = thresholdControl(row.key, "Upper")
        BiceData.LsSliders.SetValue(row.key .. "Lower",
            tonumber(lower ~= nil and lower:GetValue() or nil) or row.lower)
        BiceData.LsSliders.SetValue(row.key .. "Upper",
            tonumber(upper ~= nil and upper:GetValue() or nil) or row.upper)
    end

    local buffer = control("m_checkBox_customLsSliderAi_bufferNco")
    BiceData.LsSliders.SetValue("bufferProdNco",
        buffer ~= nil and Utils.BoolToNumber(buffer:GetValue()) or 0)

    local ok, _, corrections = BiceData.LsSliders.Commit()
    if not ok then
        return
    end

    -- A value the provider had to clamp is put back on screen, so the page never shows
    -- a threshold the game did not get.
    for field, value in pairs(corrections or {}) do
        local widget = control("m_textCtrl_customLsSliderAi_" .. field)
        if widget ~= nil then
            widget:SetValue(string.format('%.0f', value))
        end
    end
end

function SetCustomLsSliderAiStatus()
    local data = BiceData.LsSliders.Collect()
    if data == nil then
        return
    end

    if data.active then
        BiceData.LsSliders.SetActive(false)
        SetCustomLsSliderAiStatusText(false)
        return
    end

    SetCustomLsSliderValues()
    BiceData.LsSliders.SetActive(true)
    SetCustomLsSliderAiStatusText(true)
end

function ReadCustomLsSliderValues()
    local data = BiceData.LsSliders.Collect()
    if data == nil or not data.configured then
        return -- leaves the defaults the controls start with
    end

    for _, row in ipairs(data.rows) do
        thresholdControl(row.key, "Lower"):SetValue(string.format('%.0f', row.lower))
        thresholdControl(row.key, "Upper"):SetValue(string.format('%.0f', row.upper))
    end
    control("m_checkBox_customLsSliderAi_bufferNco"):SetValue(data.bufferNco)
end
