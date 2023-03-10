function SetCustomTradeAiStatus()
    if wx ~= nil and PlayerCountry ~= nil then
        local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
		if UI.m_textCtrl_customTradeAi1:GetValue() == "Active" then
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_CustomTradeAiActive"), CFixedPoint(0))
            CCurrentGameState.Post(command)
            SetCustomTradeAiStatusText(false)
        else
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_CustomTradeAiActive"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            local command = CSetVariableCommand(playerCountryTag, CString("zzDsafe_usesCustomTradeAi"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            SetCustomTradeAiStatusText(true)
            SetCustomTradeAiValues()
		end
    end
end

function SetCustomTradeAiStatusText(status)
    if status then
		UI.m_textCtrl_customTradeAi1:SetValue("Active")
    else
        UI.m_textCtrl_customTradeAi1:SetValue("Inactive")
    end
end

function DetermineCustomTradeAiStatus()
    local countryTag = CCountryDataBase.GetTag(PlayerCountry)
    local country = countryTag:GetCountry()
    local variables = country:GetVariables()

    if variables:GetVariable(CString("zzDsafe_CustomTradeAiActive")):Get() == 1 then
        SetCustomTradeAiStatusText(true)
    else
        SetCustomTradeAiStatusText(false)
    end
end

function SetCustomTradeAiValues()
    local Values = {
        MONEY = {
            MaxDailySell = tonumber(UI.m_textCtrl_CustomTradeAi_MaxDailySell:GetValue()),
            Buffer = tonumber(UI.m_textCtrl_customTradeAi_Money_Buffer:GetValue()),
            BufferSaleCap = 20 -- ignored
        },
        METAL = {
            Buffer = tonumber(UI.m_textCtrl_customTradeAi_Metal_Buffer:GetValue()), 			-- Amount extra to keep abouve our needs
            BufferSaleCap = tonumber(UI.m_textCtrl_customTradeAi_Metal_BufferSaleCap:GetValue()), 	-- Amount we need in reserve before we sell the resource
            BufferBuyCap = tonumber(UI.m_textCtrl_customTradeAi_Metal_BufferCancelCap:GetValue()), 	-- not used by me! (Amount we need before we stop actively buying (existing trades are NOT cancelled))
            BufferCancelCap = tonumber(UI.m_textCtrl_customTradeAi_Metal_BufferCancelCap:GetValue()), -- Amount we need before we cancel trades simply because we have to much
        },
        ENERGY = {
            Buffer = tonumber(UI.m_textCtrl_customTradeAi_Energy_Buffer:GetValue()),
            BufferSaleCap = tonumber(UI.m_textCtrl_customTradeAi_Energy_BufferSaleCap:GetValue()),
            BufferBuyCap = tonumber(UI.m_textCtrl_customTradeAi_Energy_BufferCancelCap:GetValue()),
            BufferCancelCap = tonumber(UI.m_textCtrl_customTradeAi_Energy_BufferCancelCap:GetValue()),
        },
        RARE_MATERIALS = {
            Buffer = tonumber(UI.m_textCtrl_customTradeAi_Rares_Buffer:GetValue()),
            BufferSaleCap = tonumber(UI.m_textCtrl_customTradeAi_Rares_BufferSaleCap:GetValue()),
            BufferBuyCap = tonumber(UI.m_textCtrl_customTradeAi_Rares_BufferCancelCap:GetValue()),
            BufferCancelCap = tonumber(UI.m_textCtrl_customTradeAi_Rares_BufferCancelCap:GetValue()),
        },
        CRUDE_OIL = {
            Buffer = tonumber(UI.m_textCtrl_customTradeAi_Oil_Buffer:GetValue()),
            BufferSaleCap = tonumber(UI.m_textCtrl_customTradeAi_Oil_BufferSaleCap:GetValue()),
            BufferBuyCap = tonumber(UI.m_textCtrl_customTradeAi_Oil_BufferCancelCap:GetValue()),
            BufferCancelCap = tonumber(UI.m_textCtrl_customTradeAi_Oil_BufferCancelCap:GetValue()),
        },
        SUPPLIES = {
            Buffer = 1000,          -- Ignored for supplies
            BufferSaleCap = 5000,   -- Ignored for supplies
            BufferBuyCap = 5000,    -- Ignored for supplies
            BufferCancelCap = 5000, -- Ignored for supplies
        },
        FUEL = {
            Buffer = tonumber(UI.m_textCtrl_customTradeAi_Fuel_Buffer:GetValue()),
            BufferSaleCap = tonumber(UI.m_textCtrl_customTradeAi_Fuel_BufferSaleCap:GetValue()),
            BufferBuyCap = tonumber(UI.m_textCtrl_customTradeAi_Fuel_BufferCancelCap:GetValue()),
            BufferCancelCap = tonumber(UI.m_textCtrl_customTradeAi_Fuel_BufferCancelCap:GetValue()),
        }
    }
    local countryTag = CCountryDataBase.GetTag(PlayerCountry)
    local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_MaxDailySell"), CFixedPoint(Values.MONEY.MaxDailySell))
    CCurrentGameState.Post(command)
    local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_MONEY_Buffer"), CFixedPoint(Values.MONEY.Buffer))
    CCurrentGameState.Post(command)
    local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_MONEY_BufferSaleCap"), CFixedPoint(Values.MONEY.BufferSaleCap))
    CCurrentGameState.Post(command)
    for k, v in pairs(Values) do
        if k ~= "MONEY" then
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_"..k.."_Buffer"), CFixedPoint(Values[k].Buffer))
            CCurrentGameState.Post(command)
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_"..k.."_BufferSaleCap"), CFixedPoint(Values[k].BufferSaleCap))
            CCurrentGameState.Post(command)
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_"..k.."_BufferBuyCap"), CFixedPoint(Values[k].BufferBuyCap))
            CCurrentGameState.Post(command)
            local command = CSetVariableCommand(countryTag, CString("zzDsafe_TradeAi_"..k.."_BufferCancelCap"), CFixedPoint(Values[k].BufferCancelCap))
            CCurrentGameState.Post(command)
        end
    end
    local command = CSetVariableCommand(countryTag, CString("zzDsafe_WantsToChangeCustomTradeAi"), CFixedPoint(1))
    CCurrentGameState.Post(command)
end

function ReadCustomTradeAiValues()
    local countryTag = CCountryDataBase.GetTag(PlayerCountry)
    local country = countryTag:GetCountry()
    local variables = country:GetVariables()
    if variables:GetVariable(CString("zzDsafe_usesCustomTradeAi")):Get() == 0 then
        return
    end

    UI.m_textCtrl_CustomTradeAi_MaxDailySell:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_MaxDailySell")):Get())))

    UI.m_textCtrl_customTradeAi_Money_Buffer:SetValue(
        string.format('%.2f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_MONEY_Buffer")):Get())))

    UI.m_textCtrl_customTradeAi_Metal_Buffer:SetValue(
        string.format('%.2f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_METAL_Buffer")):Get())))
    UI.m_textCtrl_customTradeAi_Metal_BufferSaleCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_METAL_BufferSaleCap")):Get())))
    UI.m_textCtrl_customTradeAi_Metal_BufferCancelCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_METAL_BufferCancelCap")):Get())))

    UI.m_textCtrl_customTradeAi_Energy_Buffer:SetValue(
        string.format('%.2f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_ENERGY_Buffer")):Get())))
    UI.m_textCtrl_customTradeAi_Energy_BufferSaleCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_ENERGY_BufferSaleCap")):Get())))
    UI.m_textCtrl_customTradeAi_Energy_BufferCancelCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_ENERGY_BufferCancelCap")):Get())))

    UI.m_textCtrl_customTradeAi_Rares_Buffer:SetValue(
        string.format('%.2f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_RARE_MATERIALS_Buffer")):Get())))
    UI.m_textCtrl_customTradeAi_Rares_BufferSaleCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_RARE_MATERIALS_BufferSaleCap")):Get())))
    UI.m_textCtrl_customTradeAi_Rares_BufferCancelCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_RARE_MATERIALS_BufferCancelCap")):Get())))

    UI.m_textCtrl_customTradeAi_Oil_Buffer:SetValue(
        string.format('%.2f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_CRUDE_OIL_Buffer")):Get())))
    UI.m_textCtrl_customTradeAi_Oil_BufferSaleCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_CRUDE_OIL_BufferSaleCap")):Get())))
    UI.m_textCtrl_customTradeAi_Oil_BufferCancelCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_CRUDE_OIL_BufferCancelCap")):Get())))

    UI.m_textCtrl_customTradeAi_Fuel_Buffer:SetValue(
        string.format('%.2f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_FUEL_Buffer")):Get())))
    UI.m_textCtrl_customTradeAi_Fuel_BufferSaleCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_FUEL_BufferSaleCap")):Get())))
    UI.m_textCtrl_customTradeAi_Fuel_BufferCancelCap:SetValue(
        string.format('%.0f',tostring(variables:GetVariable(CString("zzDsafe_TradeAi_FUEL_BufferCancelCap")):Get())))

end
