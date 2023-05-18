function DetermineCustomLsSliderAiStatus()
    local countryTag = CCountryDataBase.GetTag(PlayerCountry)
    local country = countryTag:GetCountry()
    local variables = country:GetVariables()

    if variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_isActive")):Get() == 1 then
        SetCustomLsSliderAiStatusText(true)
    else
        SetCustomLsSliderAiStatusText(false)
    end
end

function SetCustomLsSliderAiStatusText(status)
    if status then
		UI.m_textCtrl_customLsSliderAi_state:SetValue("Active")
    else
        UI.m_textCtrl_customLsSliderAi_state:SetValue("Inactive")
    end
end

function SetCustomLsSliderAiStatus()
    if wx ~= nil and PlayerCountry ~= nil then
        local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
		if UI.m_textCtrl_customLsSliderAi_state:GetValue() == "Active" then
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_CustomLeadershipSliders_isActive"), CFixedPoint(0))
            CCurrentGameState.Post(command)
            SetCustomLsSliderAiStatusText(false)
        else
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_usesCustomLsSliders"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            SetCustomLsSliderValues()
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_CustomLeadershipSliders_isActive"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            SetCustomLsSliderAiStatusText(true)
		end
    end
end

function SetCustomLsSliderValues()
    if wx ~= nil and PlayerCountry ~= nil then
        local countryTag = CCountryDataBase.GetTag(PlayerCountry)
        local categories = {
            "officers",
            "spies",
            "diplo"
        }
        -- Check for values above 110 due to engine limit
        if tonumber(UI.m_textCtrl_customLsSliderAi_officersLower:GetValue()) > 110 then
            UI.m_textCtrl_customLsSliderAi_officersLower:SetValue("110")
        end
        if tonumber(UI.m_textCtrl_customLsSliderAi_officersUpper:GetValue()) > 110 then
            UI.m_textCtrl_customLsSliderAi_officersUpper:SetValue("110")
        end
        for k, category in pairs(categories) do
            local lower = tonumber(UI["m_textCtrl_customLsSliderAi_" .. category .. "Lower"]:GetValue())
            local upper = tonumber(UI["m_textCtrl_customLsSliderAi_" .. category .. "Upper"]:GetValue())
            if lower > upper then
                lower = upper
                UI["m_textCtrl_customLsSliderAi_" .. category .. "Lower"]:SetValue(tostring(upper))
            end
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomLeadershipSliders_".. category .."Lower"), CFixedPoint(lower))
            CCurrentGameState.Post(command)
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomLeadershipSliders_".. category .."Upper"), CFixedPoint(upper))
            CCurrentGameState.Post(command)
        end
        local bufferNcoBool = UI.m_checkBox_customLsSliderAi_bufferNco:GetValue()
        local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomLeadershipSliders_bufferProdNco"), CFixedPoint(Utils.BoolToNumber(bufferNcoBool)))
        CCurrentGameState.Post(command)
    end
end

function ReadCustomLsSliderValues()
    if wx ~= nil and PlayerCountry ~= nil then
        local countryTag = CCountryDataBase.GetTag(PlayerCountry)
        local country = countryTag:GetCountry()
        local variables = country:GetVariables()
        local categories = {
            "officers",
            "spies",
            "diplo"
        }

        if variables:GetVariable(CString("zzDsafe_usesCustomLsSliders")):Get() == 0 then
            return
        end

        for k, category in pairs(categories) do
            UI["m_textCtrl_customLsSliderAi_" .. category .. "Lower"]:SetValue(
                string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_".. category .."Lower")):Get()))
            )
            UI["m_textCtrl_customLsSliderAi_" .. category .. "Upper"]:SetValue(
                string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_".. category .."Upper")):Get()))
            )
        end
        UI.m_checkBox_customLsSliderAi_bufferNco:SetValue(
            variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_bufferProdNco")):Get()
        )
    end
end
