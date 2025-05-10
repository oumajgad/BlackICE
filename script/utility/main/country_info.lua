-- Called each refresh
function GetPlayerModifiers()
    local techModifierValues = Parsing.Techs.GetTechModifierValues()

    local playerCountry = CCountryDataBase.GetTag(G_PlayerCountry):GetCountry()

    local baseIC = playerCountry:GetMaxIC()
    local offmapIC = 0
    if BiceLib ~= nil then
        offmapIC = BiceLib.GameInfo.getCountryOffmapIc(G_PlayerCountry)
    end
    local icModifier = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_GLOBAL_IC_):Get()
    for tech, effect in pairs(techModifierValues["ic_modifier"]) do
        local level = playerCountry:GetTechnologyStatus():GetLevel(CTechnologyDataBase.GetTechnology(tech))
        icModifier = icModifier + (effect*level)
        -- Utils.LUA_DEBUGOUT(tech .. ":\n    Level: " .. level .. "\n    Effect:" .. (effect*level*100))
    end

    local repairModifier = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_UNIT_REPAIR_):Get()
    for tech, effect in pairs(techModifierValues["repair_rate"]) do
        local level = playerCountry:GetTechnologyStatus():GetLevel(CTechnologyDataBase.GetTechnology(tech))
        repairModifier = repairModifier + (effect*level)
        -- Utils.LUA_DEBUGOUT(tech .. ":\n    Level: " .. level .. "\n    Effect:" .. (effect*level*100))
    end

    local orgRegain = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_ORG_REGAIN_):Get()
    for tech, effect in pairs(techModifierValues["org_regain"]) do
        local level = playerCountry:GetTechnologyStatus():GetLevel(CTechnologyDataBase.GetTechnology(tech))
        orgRegain = orgRegain + (effect*level)
        -- Utils.LUA_DEBUGOUT(tech .. ":\n    Level: " .. level .. "\n    Effect:" .. (effect*level*100))
    end

    local attackDelay = defines.military.UNIT_ATTACK_DELAY
    for tech, effect in pairs(techModifierValues["attack_delay"]) do
        local level = playerCountry:GetTechnologyStatus():GetLevel(CTechnologyDataBase.GetTechnology(tech))
        attackDelay = attackDelay - (effect*level)
        -- Utils.LUA_DEBUGOUT(tech .. ":\n    Level: " .. level .. "\n    Effect:" .. (effect*level))
    end

    local icToSupplies = 1
    for tech, effect in pairs(techModifierValues["ic_to_supplies"]) do
        local level = playerCountry:GetTechnologyStatus():GetLevel(CTechnologyDataBase.GetTechnology(tech))
        icToSupplies = icToSupplies + (effect*level)
        -- Utils.LUA_DEBUGOUT(tech .. ":\n    Level: " .. level .. "\n    Effect:" .. (effect*level))
    end
    local supplyFactoriesEffect = playerCountry:GetVariables():GetVariable(CString("supplies_factory_count")):Get() * 0.035
    local suppliesPerIc = (icToSupplies + supplyFactoriesEffect) * defines.economy.IC_TO_SUPPLIES
    -- Utils.LUA_DEBUGOUT("suppliesPerIc: " .. suppliesPerIc)

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

    local startingExp = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_UNIT_START_EXPERIENCE_):Get()

    UI.m_textCtrl_baseIc:SetValue(string.format('%.0f', baseIC))
    UI.m_textCtrl_offmapIc:SetValue(string.format('%.0f', (offmapIC)))
    UI.m_textCtrl_icModifier:SetValue(string.format('%.02f', (icModifier * 100)))

    UI.m_textCtrl_IcEff:SetValue(string.format('%.02f', icEffRaw))
    UI.m_textCtrl_ResEff:SetValue(string.format('%.02f', researchEffRaw))
    UI.m_textCtrl_SuppThrou:SetValue(string.format('%.02f', supplyEffRaw))
    UI.m_textCtrl_RepairEff:SetValue(string.format('%.02f', repairModifier * 100))
    UI.m_textCtrl_StartingExp:SetValue(string.format('%.02f', startingExp))
    UI.m_textCtrl_orgRegain:SetValue(string.format('%.02f', orgRegain * 100))
    UI.m_textCtrl_attackDelay:SetValue(string.format('%.0f', attackDelay))
    UI.m_textCtrl_suppliesPerIc:SetValue(string.format('%.2f', suppliesPerIc))
    UI.m_textCtrl_WarExhaustion:SetValue(string.format('%.02f', warExhautionRaw))
    UI.m_textCtrl_currentWarExhaustion:SetValue(string.format('%.1f', currentWarExhaustion))
end
