-- Called each refresh
function GetPlayerModifiers()
    local playerCountry = CCountryDataBase.GetTag(PlayerCountry):GetCountry()

    local baseIC = playerCountry:GetMaxIC()
    local baseICWithOffmap = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_IC_):Get()
    local icModifier = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_GLOBAL_IC_):Get()
    for tech, effect in pairs(G_TechsIcModValues) do
        local level = playerCountry:GetTechnologyStatus():GetLevel(CTechnologyDataBase.GetTechnology(tech))
        icModifier = icModifier + (effect*level)
        -- Utils.LUA_DEBUGOUT(tech .. ":\n    Level: " .. level .. "\n    Effect:" .. (effect*level*100))
    end

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

    UI.m_textCtrl_baseIc:SetValue(string.format('%.0f', baseIC))
    UI.m_textCtrl_offmapIc:SetValue(string.format('%.0f', (baseICWithOffmap - baseIC)))
    UI.m_textCtrl_icModifier:SetValue(string.format('%.02f', (icModifier * 100)))

    UI.m_textCtrl_IcEff:SetValue(string.format('%.02f', icEffRaw))
    UI.m_textCtrl_ResEff:SetValue(string.format('%.02f', researchEffRaw))
    UI.m_textCtrl_SuppThrou:SetValue(string.format('%.02f', supplyEffRaw))
    UI.m_textCtrl_WarExhaustion:SetValue(string.format('%.02f', warExhautionRaw))
    UI.m_textCtrl_currentWarExhaustion:SetValue(string.format('%.1f', currentWarExhaustion))
end
