-- Called each refresh
function GetPlayerModifiers()
    local playerCountry = CCountryDataBase.GetTag(PlayerCountry):GetCountry()

    -- IC efficiency
    local icEffRaw = playerCountry:GetVariables():GetVariable(CString("IcEffVariable")):Get()

    -- Research efficiency
    local researchEffRaw = playerCountry:GetVariables():GetVariable(CString("ResEffVariable")):Get()

    -- Supply throughput
    local supplyEffRaw = playerCountry:GetVariables():GetVariable(CString("SuppThrouVariable")):Get()

    -- War exhaustion monthly
    local warExhautionRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_WAR_EXHAUSTION_):Get()
    if playerCountry:IsAtWar() then
        warExhautionRaw = warExhautionRaw + 20
    end

    -- War exhaustion current
    local currentWarExhaustion = playerCountry:GetVariables():GetVariable(CString("war_exhaustion")):Get()


    UI.m_textCtrl_IcEff:SetValue(string.format('%.02f', icEffRaw))
    UI.m_textCtrl_ResEff:SetValue(string.format('%.02f', researchEffRaw))
    UI.m_textCtrl_SuppThrou:SetValue(string.format('%.02f', supplyEffRaw))
    UI.m_textCtrl_WarExhaustion:SetValue(string.format('%.02f', warExhautionRaw))
    UI.m_textCtrl_currentWarExhaustion:SetValue(string.format('%.1f', currentWarExhaustion))
end
