-- Called from button press
function SetNatFocus(focus)
    if PlayerCountry ~= nil then
        local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
        local command = CSetVariableCommand(playerCountryTag, CString("national_focus"), CFixedPoint(focus))
        CCurrentGameState.Post(command)
    end
end

-- Called each update
function GetNatFocusDays()
	local focuses = {
		"ground_forces",
		"air_force",
		"navy",
		"economy",
		"science",
		"health_and_education",
		"natural_resources"
	}

    if PlayerCountry ~= nil then
        local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
        local variables = playerCountry:GetCountry():GetVariables()
        for i, focus in pairs(focuses) do
            local days = variables:GetVariable(CString(focus .. "_national_focus_days_active")):Get()
            if days > 1 then
                SetFocusActiveDaysText(focus, tostring(days))
            else
                SetFocusActiveDaysText(focus, "0")
            end
        end
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

