function SetUpStatCollectionPage()
	local omgTag = CCountryDataBase.GetTag("OMG")
	local omgCountry = omgTag:GetCountry()
    local variables = omgCountry:GetVariables()
	local statisticsToggle = variables:GetVariable(CString("StatisticsToggle")):Get()
	local statisticsCustomList = variables:GetVariable(CString("StatisticsCustomList")):Get()
    if statisticsToggle == 1 then
        UI.m_textCtrl_Statistics_setup_ident:SetValue(tostring(Stats.GetCurrentIdent()))
        Stats.CollectStats = true
        UI.m_textCtrl_Statistics_setup_toggle:SetValue("on")
    else
        UI.m_textCtrl_Statistics_setup_toggle:SetValue("off")
    end
    if statisticsCustomList == 1 then
        Stats.MajorOnly = true
        UI.m_textCtrl_Statistics_setup_toggle_custom_list:SetValue("on")
    else
        UI.m_textCtrl_Statistics_setup_toggle_custom_list:SetValue("off")
    end
    local countries = {}
    local customCollectionCountries = {}
    for country in CCurrentGameState.GetCountries() do
        local countryTag = country:GetCountryTag()
        local tag = tostring(countryTag)
        if tag ~= "---" then
            table.insert(countries, tag)
            if variables:GetVariable(CString("zStatsCustomList_" .. tag)):Get() == 1 then
                table.insert(customCollectionCountries, tag)
            end
        end
    end
    table.sort(countries)
    table.sort(customCollectionCountries)
    UI.m_comboBox_Statistics_main1:Clear()
    UI.m_comboBox_Statistics_main1:Append(countries)
    UI.m_comboBox_Statistics_setup1:Clear()
    UI.m_comboBox_Statistics_setup1:Append(countries)
    UI.m_listBox_Statistics_country_list:Clear()
    UI.m_listBox_Statistics_country_list:Append(customCollectionCountries)
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


function ToggleStatCollectionCustomList()
	local omgTag = CCountryDataBase.GetTag("OMG")
	local omgCountry = omgTag:GetCountry()
	local statisticsCustomList = omgCountry:GetVariables():GetVariable(CString("StatisticsCustomList")):Get()
    if statisticsCustomList == 1 then
        local command = CSetVariableCommand(omgTag, CString("StatisticsCustomList"), CFixedPoint(0))
        CCurrentGameState.Post(command)
        UI.m_textCtrl_Statistics_setup_toggle_custom_list:SetValue("off")
        Stats.CustomCountryListActive = false
    else
        local command = CSetVariableCommand(omgTag, CString("StatisticsCustomList"), CFixedPoint(1))
        CCurrentGameState.Post(command)
        UI.m_textCtrl_Statistics_setup_toggle_custom_list:SetValue("on")
        Stats.CustomCountryListActive = true
    end
end
