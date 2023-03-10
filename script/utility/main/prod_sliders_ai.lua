function SetCustomProductionSliderAiStatus()
    if wx ~= nil and PlayerCountry ~= nil then
        local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
		if UI.m_textCtrl_customProdSlider_state:GetValue() == "Active" then
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_CustomProductionSliders_isActive"), CFixedPoint(0))
            CCurrentGameState.Post(command)
            SetCustomProductionSliderAiStatusText(false)
        else
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_usesCustomProductionSliders"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            SetCustomProductionSliderValues()
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_CustomProductionSliders_isActive"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            SetCustomProductionSliderAiStatusText(true)
		end
    end
end

function SetCustomProductionSliderAiStatusText(status)
    if status then
		UI.m_textCtrl_customProdSlider_state:SetValue("Active")
    else
        UI.m_textCtrl_customProdSlider_state:SetValue("Inactive")
    end
end

function DetermineCustomProductionSliderAiStatus()
    local countryTag = CCountryDataBase.GetTag(PlayerCountry)
    local country = countryTag:GetCountry()
    local variables = country:GetVariables()

    if variables:GetVariable(CString("zzDsafe_CustomProductionSliders_isActive")):Get() == 1 then
        SetCustomProductionSliderAiStatusText(true)
    else
        SetCustomProductionSliderAiStatusText(false)
    end
end

function CheckCustomProductionSliderPrioConflict()
    local categories = {
        "upgrade",
        "reinforce",
        "supply",
        "production",
        "consumer",
        "lendLease"
    }
    local priorities = {}
    for k, category in pairs(categories) do
        local prio = tonumber(UI["m_textCtrl_customProdSlider_" .. category .. "Prio"]:GetValue())
        if prio ~= nil then
            if priorities[prio] then
                UI["m_textCtrl_customProdSlider_" .. category .. "Prio"]:SetValue("CONFLICT")
                return true
            else
                priorities[prio] = true
            end
        else
            return true
        end
    end
    return false
end

function SetCustomProductionSliderValues()
    if wx ~= nil and PlayerCountry ~= nil then
        local countryTag = CCountryDataBase.GetTag(PlayerCountry)
        -- local country = countryTag:GetCountry()
        -- local variables = country:GetVariables()
        local categories = {
            "upgrade",
            "reinforce",
            "supply",
            "production",
            "consumer",
            "lendLease"
        }

        if CheckCustomProductionSliderPrioConflict() then
            return
        end

        for k, category in pairs(categories) do
            local amount = tonumber(UI["m_textCtrl_customProdSlider_" .. category .. "Amount"]:GetValue())
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_" .. category .. "Amount"), CFixedPoint(amount))
            CCurrentGameState.Post(command)
            local prio = tonumber(UI["m_textCtrl_customProdSlider_" .. category .. "Prio"]:GetValue())
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_" .. category .. "Prio"), CFixedPoint(prio))
            CCurrentGameState.Post(command)
            local mode = UI["m_choice_customProdSlider_" .. category .. "Mode"]:GetSelection()
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_" .. category .. "InvestMode"), CFixedPoint(mode))
            CCurrentGameState.Post(command)

            if category == "upgrade" or category == "reinforce" then
                local limitActive = UI["m_checkBox_customProdSlider_" .. category .. "Limit"]:GetValue()
                local command = CSetVariableCommand(
                    countryTag, CString("zzDsafe_CustomProductionSliders_" .. category .. "Limit_active"), CFixedPoint(Utils.BoolToNumber(limitActive)))
                CCurrentGameState.Post(command)
                local limit = tonumber(UI["m_textCtrl_customProdSlider_" .. category .. "Limit"]:GetValue())
                local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_" .. category .. "Limit"), CFixedPoint(limit))
                CCurrentGameState.Post(command)
            elseif category == "consumer" then
                local reduceDissent = UI.m_checkBox_customProdSlider_reduceDissent:GetValue()
                local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_reduceDissent"), CFixedPoint(Utils.BoolToNumber(reduceDissent)))
                CCurrentGameState.Post(command)
            elseif category == "supply" then
                local supplyGoal = tonumber(UI.m_textCtrl_customProdSlider_supplyGoal:GetValue())
                local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_supplyGoal"), CFixedPoint(supplyGoal))
                CCurrentGameState.Post(command)
                local supplyGoalActive = UI.m_checkBox_customProdSlider_supplyGoal:GetValue()
                local command = CSetVariableCommand(countryTag, CString("zzDsafe_CustomProductionSliders_supplyGoal_active"), CFixedPoint(Utils.BoolToNumber(supplyGoalActive)))
                CCurrentGameState.Post(command)
            end
        end
    end
end

function ReadCustomProductionSliderValues()
    if wx ~= nil and PlayerCountry ~= nil then
        local countryTag = CCountryDataBase.GetTag(PlayerCountry)
        local country = countryTag:GetCountry()
        local variables = country:GetVariables()
        local categories = {
            "upgrade",
            "reinforce",
            "supply",
            "production",
            "consumer",
            "lendLease"
        }

        if variables:GetVariable(CString("zzDsafe_usesCustomProductionSliders")):Get() == 0 then
            return
        end

        for k, category in pairs(categories) do
            UI["m_textCtrl_customProdSlider_" .. category .. "Amount"]:SetValue(
                string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_CustomProductionSliders_" .. category .. "Amount")):Get())))
            UI["m_textCtrl_customProdSlider_" .. category .. "Prio"]:SetValue(
                string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_CustomProductionSliders_" .. category .. "Prio")):Get())))
            UI["m_choice_customProdSlider_" .. category .. "Mode"]:SetSelection(
                variables:GetVariable(CString("zzDsafe_CustomProductionSliders_" .. category .. "InvestMode")):Get())
            if category == "upgrade" or category == "reinforce" then
                UI["m_checkBox_customProdSlider_" .. category .. "Limit"]:SetValue(
                    variables:GetVariable(CString("zzDsafe_CustomProductionSliders_" .. category .. "Limit_active")):Get())
                UI["m_textCtrl_customProdSlider_" .. category .. "Limit"]:SetValue(
                    string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_CustomProductionSliders_" .. category .. "Limit")):Get())))
            elseif category == "consumer" then
                UI.m_checkBox_customProdSlider_reduceDissent:SetValue(
                    variables:GetVariable(CString("zzDsafe_CustomProductionSliders_reduceDissent")):Get())
            elseif category == "supply" then
                UI.m_checkBox_customProdSlider_supplyGoal:SetValue(
                    variables:GetVariable(CString("zzDsafe_CustomProductionSliders_supplyGoal_active")):Get())
                UI.m_textCtrl_customProdSlider_supplyGoal:SetValue(
                    string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_CustomProductionSliders_supplyGoal")):Get())))
            end
        end
    end
end
