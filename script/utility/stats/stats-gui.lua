function SetStatCollectionStatus()
	local omgTag = CCountryDataBase.GetTag("OMG")
	local omgCountry = omgTag:GetCountry()
	local statisticsToggle = omgCountry:GetVariables():GetVariable(CString("StatisticsToggle")):Get()
	local statisticsMajors = omgCountry:GetVariables():GetVariable(CString("StatisticsMajors")):Get()
    if statisticsToggle == 1 then
        UI.m_textCtrl_Statistics_setup_ident:SetValue(tostring(Stats.GetCurrentIdent()))
        Stats.CollectStats = true
        UI.m_textCtrl_Statistics_setup_toggle:SetValue("on")
    else
        UI.m_textCtrl_Statistics_setup_toggle:SetValue("off")
    end
    if statisticsMajors == 1 then
        Stats.MajorOnly = true
        UI.m_textCtrl_Statistics_setup_toggle_majors:SetValue("on")
    else
        UI.m_textCtrl_Statistics_setup_toggle_majors:SetValue("off")
    end
    local countries = {}
    for dip in CCountryDataBase.GetTag("OMG"):GetCountry():GetDiplomacy() do
        local countryTag = dip:GetTarget()
        local tag = tostring(countryTag)
        if tag ~= "REB" and tag ~= "---" then
            table.insert(countries, tag)
        end
    end
    table.sort(countries)
    UI.m_comboBox_Statistics_main1:Clear()
    UI.m_comboBox_Statistics_main1:Append(countries)
end


function ToggleStatCollection()
	local omgTag = CCountryDataBase.GetTag("OMG")
	local omgCountry = omgTag:GetCountry()
	local statisticsToggle = omgCountry:GetVariables():GetVariable(CString("StatisticsToggle")):Get()
    if statisticsToggle == 1 then
        local command = CSetVariableCommand(omgTag, CString("StatisticsToggle"), CFixedPoint(0))
        CCurrentGameState.Post(command)
        UI.m_textCtrl_Statistics_setup_toggle:SetValue("off")
        Stats.CollectStats = false
    else
        UI.m_textCtrl_Statistics_setup_ident:SetValue(tostring(Stats.GetCurrentIdent()))
        local command = CSetVariableCommand(omgTag, CString("StatisticsToggle"), CFixedPoint(1))
        CCurrentGameState.Post(command)
        UI.m_textCtrl_Statistics_setup_toggle:SetValue("on")
        Stats.CollectStats = true
    end
end


function ToggleStatCollectionMajors()
	local omgTag = CCountryDataBase.GetTag("OMG")
	local omgCountry = omgTag:GetCountry()
	local statisticsMajors = omgCountry:GetVariables():GetVariable(CString("StatisticsMajors")):Get()
    if statisticsMajors == 1 then
        local command = CSetVariableCommand(omgTag, CString("StatisticsMajors"), CFixedPoint(0))
        CCurrentGameState.Post(command)
        UI.m_textCtrl_Statistics_setup_toggle_majors:SetValue("off")
        Stats.MajorOnly = false
    else
        local command = CSetVariableCommand(omgTag, CString("StatisticsMajors"), CFixedPoint(1))
        CCurrentGameState.Post(command)
        UI.m_textCtrl_Statistics_setup_toggle_majors:SetValue("on")
        Stats.MajorOnly = true
    end
end
