-- National focus tab.
--
-- Reading and writing live in BiceData.NatFocus, shared with the ImGui utility. What
-- is left here is the wx half: which control shows which focus.

-- Called from button press
function SetNatFocus(focus)
    BiceData.NatFocus.Set(focus)
end

-- Called each update
function GetNatFocusDays()
    local data = BiceData.NatFocus.Collect()
    if data == nil then
        return
    end

    for _, row in ipairs(data.rows) do
        -- Shown as 0 below a day, as this page always did: the counter is not
        -- meaningful until it has been running for one.
        local days = (row.days > 1) and row.days or 0
        SetFocusActiveDaysText(row.key, tostring(days))
    end
end

-- Called from internal
function SetFocusActiveDaysText(focus, days)
    if focus == "ground_forces" then
        UI.m_textCtrl_FocusGroundDays:SetValue(days)
    end
    if focus == "air_force" then
        UI.m_textCtrl_FocusAirDays:SetValue(days)
    end
    if focus == "navy" then
        UI.m_textCtrl_FocusNavyDays:SetValue(days)
    end
    if focus == "economy" then
        UI.m_textCtrl_FocusEconDays:SetValue(days)
    end
    if focus == "science" then
        UI.m_textCtrl_FocusScienceDays:SetValue(days)
    end
    if focus == "health_and_education" then
        UI.m_textCtrl_FocusHealthEduDays:SetValue(days)
    end
    if focus == "natural_resources" then
        UI.m_textCtrl_FocusResourceDays:SetValue(days)
    end
end
