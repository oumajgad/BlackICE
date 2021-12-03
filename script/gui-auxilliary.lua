
function GuiRefreshLoop()
    DaysSinceLastUpdate = DaysSinceLastUpdate + 1
    if wx ~= nil and PlayerCountry ~= nil and DaysSinceLastUpdate >= UpdateInterval then
        DaysSinceLastUpdate = 0
        GetAndAddPuppets()
        GetPlayerModifiers()
        GetStratResourceValues()
    end
end

-- Called once at start
function NotifySaveLoaded()
    -- Utils.LUA_DEBUGOUT("SAVELOADED")
    UI.m_textCtrl3:SetValue("Save Loaded")
    UI.m_textCtrl6:SetValue("10")
end

-- Called from button press
function UpdateDailyCountsTextCtrl()
    UI.m_textCtrlDailyCount:SetValue(tostring(DateOverride))
end

-- Called once when player is chosen
function SetTradeDecisionHiddenText()
    local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
    if playerCountry:GetCountry():GetVariables():GetVariable(CString("disable_resource_trade_decision")):Get() == 1 then
        UI.m_textCtrl_TradeDecisionHide:SetValue("Hidden")
    else
        UI.m_textCtrl_TradeDecisionHide:SetValue("Visible")
    end
end

-- Called from button press
function ToggleTradeDecisions(desiredState)
    if PlayerCountry ~= nil then
        local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
        if desiredState == true then
            local command = CSetVariableCommand(playerCountry, CString("disable_resource_trade_decision"), CFixedPoint(1))
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
            UI.m_textCtrl_TradeDecisionHide:SetValue("Hidden")
        elseif desiredState == false then
            local command = CSetVariableCommand(playerCountry, CString("disable_resource_trade_decision"), CFixedPoint(0))
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
            UI.m_textCtrl_TradeDecisionHide:SetValue("Visible")
        end
    end
end

-- Called once when player is chosen
function SetMinesDecisionHiddenText()
    local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
    if playerCountry:GetCountry():GetVariables():GetVariable(CString("disable_mines_expansion_decision")):Get() == 1 then
        UI.m_textCtrl_MinesDecisionHide:SetValue("Hidden")
    else
        UI.m_textCtrl_MinesDecisionHide:SetValue("Visible")
    end
end

-- Called from button press
function ToggleMinesDecisions(desiredState)
    if PlayerCountry ~= nil then
        local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
        if desiredState == true then
            local command = CSetVariableCommand(playerCountry, CString("disable_mines_expansion_decision"), CFixedPoint(1))
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
            UI.m_textCtrl_MinesDecisionHide:SetValue("Hidden")
        elseif desiredState == false then
            local command = CSetVariableCommand(playerCountry, CString("disable_mines_expansion_decision"), CFixedPoint(0))
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
            UI.m_textCtrl_MinesDecisionHide:SetValue("Visible")
        end
    end
end

-- Called from button press
function TogglePuppetFocusDecision(desiredState)
    if PlayerCountry ~= nil then
        local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
        if desiredState == true then
            local command = CSetVariableCommand(playerCountry, CString("disable_pupped_focus_decision"), CFixedPoint(0))
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
        elseif desiredState == false then
            local command = CSetVariableCommand(playerCountry, CString("disable_pupped_focus_decision"), CFixedPoint(1))
            local ai = OMGMinister:GetOwnerAI()
            ai:Post(command)
        end
    end
end

-- Called each refresh
function GetAndAddPuppets()
    local playerVassals = {}
    local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
    local puppets = playerCountry:GetCountry():GetVassals()
    if puppets then
        for puppet in puppets do
            local puppetTag = tostring(puppet:GetCountry():GetCountryTag())
            -- Utils.LUA_DEBUGOUT(puppetTag)
            table.insert(playerVassals, puppetTag)
        end
        UI.puppet_choice:Clear()
        UI.puppet_choice:Append(playerVassals)
    end
end

-- Called from button press
function SetPuppetSelection()
    if UI.puppet_choice:GetSelection() >= 0 then
        SelectedPuppet = UI.puppet_choice:GetString(UI.puppet_choice:GetSelection())
        SelectedPuppetCountryTag = CCountryDataBase.GetTag(SelectedPuppet)
        UI.set_puppet_text:SetValue(SelectedPuppet)
        SetPuppetFocusText(99)
    end
end

-- Called from button press
function SetPuppetFocus()
    if UI.puppet_focus_choice:GetSelection() >= 0 and SelectedPuppetCountryTag ~= nil then
        local selectedFocusIndex = UI.puppet_focus_choice:GetSelection() + 1
        local command = CSetVariableCommand(SelectedPuppetCountryTag, CString("puppet_focus_variable"), CFixedPoint(selectedFocusIndex))
        local ai = OMGMinister:GetOwnerAI()
        ai:Post(command)
        SetPuppetFocusText(selectedFocusIndex)
    end
end

-- Called from internal
function SetPuppetFocusText(selection)
    local selectedFocusStr = "None"
    local activeFocusIndex = SelectedPuppetCountryTag:GetCountry():GetVariables():GetVariable(CString("puppet_focus_variable")):Get()
    if selection == 1 then
        selectedFocusStr = "Rares"
    elseif selection == 2 then
        selectedFocusStr = "Energy"
    elseif selection == 3 then
        selectedFocusStr = "Metal"
    elseif selection == 4 then
        selectedFocusStr = "Navy"
    elseif selection == 5 then
        selectedFocusStr = "Air"
    elseif selection == 6 then
        selectedFocusStr = "Army"
    elseif selection == 7 then
        selectedFocusStr = "Oil"
    elseif selection == 8 then
        selectedFocusStr = "None"
    elseif selection == 99 and activeFocusIndex then
        SetPuppetFocusText(activeFocusIndex)
        return
    end
    UI.m_textCtrl4:SetValue(selectedFocusStr)
end

-- Called once at start
function DeterminePlayers()
    local PlayerCountries = {}
    local playercount = 0
    for tag, countryTag in pairs(CountryIterCacheDict) do
        if CCurrentGameState.IsPlayer( countryTag ) then
            -- Utils.LUA_DEBUGOUT("Player --- " .. playercount .. " --- " .. tag )
            playercount = playercount + 1
            table.insert(PlayerCountries, tag)
        end
    end
    UI.player_choice:Clear()
    UI.player_choice:Append(PlayerCountries)
end

-- Called each refresh
function GetPlayerModifiers()
    local playerCountry = CCountryDataBase.GetTag(PlayerCountry):GetCountry()

    -- IC efficiency
    local icEffRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_INDUSTRIAL_EFFICIENCY_):Get()
    local icEffClean = Utils.RoundDecimal(icEffRaw, 2) * 100

    -- Research efficiency
    local researchEffRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_RESEARCH_EFFICIENCY_):Get()
    local researchEffClean = Utils.RoundDecimal(researchEffRaw, 2) * 100

    -- Supply throughput
    local supplyEffRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_SUPPLY_THROUGHPUT_):Get()
    local supplyEffClean = Utils.RoundDecimal(supplyEffRaw, 2) * 100

    -- Supply consumption
    local supplyConsRaw = playerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_SUPPLY_CONSUMPTION_):Get()
    local supplyConsClean = Utils.RoundDecimal(supplyConsRaw, 2) * 100

    UI.m_textCtrl_IcEff:SetValue(tostring(icEffClean))
    UI.m_textCtrl_ResEff:SetValue(tostring(researchEffClean))
    UI.m_textCtrl_SupplyThr:SetValue(tostring(supplyEffClean))
    UI.m_textCtrl_SupplyCons:SetValue(tostring(supplyConsClean))
end

-- Called each update
function GetStratResourceValues()
    local resources = {
		["chromite"] = 0;
		["aluminium"] = 0;
		["rubber"] = 0;
		["tungsten"] = 0;
		["nickel"] = 0;
		["copper"] = 0;
		["zinc"] = 0;
		["manganese"] = 0;
		["molybdenum"] = 0
	}
    local resourcesSell = {
		["chromite"] = 0;
		["aluminium"] = 0;
		["rubber"] = 0;
		["tungsten"] = 0;
		["nickel"] = 0;
		["copper"] = 0;
		["zinc"] = 0;
		["manganese"] = 0;
		["molybdenum"] = 0
	}
    local resourcesBuy = {
		["chromite"] = 0;
		["aluminium"] = 0;
		["rubber"] = 0;
		["tungsten"] = 0;
		["nickel"] = 0;
		["copper"] = 0;
		["zinc"] = 0;
		["manganese"] = 0;
		["molybdenum"] = 0
	}

    if PlayerCountry ~= nil then
        local playerCountry = CCountryDataBase.GetTag(PlayerCountry)
        local variables = playerCountry:GetCountry():GetVariables()
        for resource, count in pairs(resources) do
            resources[resource] = variables:GetVariable(CString(resource .. "_ActualBalance")):Get() - 1000
            resourcesSell[resource] = variables:GetVariable(CString(resource .. "_trade_sell")):Get()
            resourcesBuy[resource] = variables:GetVariable(CString(resource .. "_trade_buy")):Get()
        end
        SetStratResourceValues(resources, resourcesSell, resourcesBuy)
    end
end

-- Called from internal
function SetStratResourceValues(resources, resourcesSell, resourcesBuy)
    UI.m_textCtrlChromiteBalance:SetValue(tostring(resources["chromite"]))
    UI.m_textCtrlChromiteSales:SetValue(tostring(resourcesSell["chromite"]))
    UI.m_textCtrlChromiteBuys:SetValue(tostring(resourcesBuy["chromite"]))
    UI.m_textCtrlAluminiumBalance:SetValue(tostring(resources["aluminium"]))
    UI.m_textCtrlAluminiumSales:SetValue(tostring(resourcesSell["aluminium"]))
    UI.m_textCtrlAluminiumBuys:SetValue(tostring(resourcesBuy["aluminium"]))
    UI.m_textCtrlRubberBalance:SetValue(tostring(resources["rubber"]))
    UI.m_textCtrlRubberSales:SetValue(tostring(resourcesSell["rubber"]))
    UI.m_textCtrlRubberBuys:SetValue(tostring(resourcesBuy["rubber"]))
    UI.m_textCtrlTungstenBalance:SetValue(tostring(resources["tungsten"]))
    UI.m_textCtrlTungstenSales:SetValue(tostring(resourcesSell["tungsten"]))
    UI.m_textCtrlTungstenBuys:SetValue(tostring(resourcesBuy["tungsten"]))
    UI.m_textCtrlNickelBalance:SetValue(tostring(resources["nickel"]))
    UI.m_textCtrlNickelSales:SetValue(tostring(resourcesSell["nickel"]))
    UI.m_textCtrlNickelBuys:SetValue(tostring(resourcesBuy["nickel"]))
    UI.m_textCtrlCopperBalance:SetValue(tostring(resources["copper"]))
    UI.m_textCtrlCopperSales:SetValue(tostring(resourcesSell["copper"]))
    UI.m_textCtrlCopperBuys:SetValue(tostring(resourcesBuy["copper"]))
    UI.m_textCtrlZincBalance:SetValue(tostring(resources["zinc"]))
    UI.m_textCtrlZincSales:SetValue(tostring(resourcesSell["zinc"]))
    UI.m_textCtrlZincBuys:SetValue(tostring(resourcesBuy["zinc"]))
    UI.m_textCtrlManganeseBalance:SetValue(tostring(resources["manganese"]))
    UI.m_textCtrlManganeseSales:SetValue(tostring(resourcesSell["manganese"]))
    UI.m_textCtrlManganeseBuys:SetValue(tostring(resourcesBuy["manganese"]))
    UI.m_textCtrlMolybdenumBalance:SetValue(tostring(resources["molybdenum"]))
    UI.m_textCtrlMolybdenumSales:SetValue(tostring(resourcesSell["molybdenum"]))
    UI.m_textCtrlMolybdenumBuys:SetValue(tostring(resourcesBuy["molybdenum"]))
end

SpriteFilesList = {
    ["A7VAttack.xsm"]=true; ["A7Vidle.xsm"]=true; ["A7Vmove.xsm"]=true; 
    ["alliedtransportspec.dds"]=true; ["axistransportspec.dds"]=true; ["AXMV_BUL_Arm0.xac"]=true; 
    ["AXMV_BUL_arm0attack.xsm"]=true; ["AXMV_BUL_arm0idle.xsm"]=true; ["AXMV_BUL_arm0move.xsm"]=true; 
    ["AXMV_BUL_Arm2.xac"]=true; ["AXMV_BUL_Arm3.xac"]=true; ["AXMV_BUL_arm3attack.xsm"]=true; 
    ["AXMV_BUL_arm3idle.xsm"]=true; ["AXMV_BUL_arm3move.xsm"]=true; ["AXMV_BUL_Arm4.xac"]=true; 
    ["AXMV_BUL_arm4attack.xsm"]=true; ["AXMV_BUL_arm4idle.xsm"]=true; ["AXMV_BUL_arm4move.xsm"]=true; 
    ["AXMV_BUL_Interceptor3.xac"]=true; ["AXMV_BUL_Larm0.xac"]=true; ["AXMV_BUL_Larm0_attack.xsm"]=true; 
    ["AXMV_BUL_Larm0_idle.xsm"]=true; ["AXMV_BUL_Larm0_move.xsm"]=true; ["AXMV_BUL_Larm1.xac"]=true; 
    ["AXMV_BUL_Larm1_attack.xsm"]=true; ["AXMV_BUL_Larm1_diffuse.dds"]=true; ["AXMV_BUL_Larm1_idle.xsm"]=true; 
    ["AXMV_BUL_Larm1_move.xsm"]=true; ["AXMV_BUL_Larm1_spec.dds"]=true; ["AXMV_BUL_Multirole1.xac"]=true; 
    ["AXMV_BUL_Multirole1_attack.xsm"]=true; ["AXMV_BUL_Multirole1_idle.xsm"]=true; ["AXMV_HUN_Arm0.xac"]=true; 
    ["AXMV_HUN_Arm2.xac"]=true; ["AXMV_HUN_Arm4.xac"]=true; ["AXMV_HUN_Cas1.xac"]=true; 
    ["AXMV_HUN_Larm0.xac"]=true; ["AXMV_HUN_Multirole1.xac"]=true; ["AXMV_HUN_Tactical2.xac"]=true; 
    ["AXMV_ROM_Arm0.xac"]=true; ["AXMV_ROM_Arm2.xac"]=true; ["AXMV_ROM_Arm3.xac"]=true; 
    ["AXMV_ROM_Arm4.xac"]=true; ["AXMV_ROM_Cas1.xac"]=true; ["AXMV_ROM_cas_1_idle.xsm"]=true; 
    ["AXMV_ROM_Larm1.xac"]=true; ["AXMV_ROM_Larm1_diffuse.dds"]=true; ["AXMV_ROM_Larm1_spec.dds"]=true; 
    ["AXMV_ROM_Multirole1.xac"]=true; ["AXMV_ROM_Tactical2.xac"]=true; ["AXMV_SLO_Cas1.xac"]=true; 
    ["AXMV_SLO_Interceptor1.xac"]=true; ["AXMV_SLO_Interceptor2.xac"]=true; ["AXMV_SLO_Larm0.xac"]=true; 
    ["AXMV_SLO_Larm0_attack.xsm"]=true; ["AXMV_SLO_Larm0_idle.xsm"]=true; ["AXMV_SLO_Larm0_move.xsm"]=true; 
    ["AXMV_SLO_Larm1.xac"]=true; ["AXMV_SLO_Larm1_diffuse.dds"]=true; ["AXMV_SLO_Larm1_spec.dds"]=true; 
    ["AXM_BUL_arm2attack.xsm"]=true; ["AXM_BUL_arm2idle.xsm"]=true; ["AXM_BUL_arm2move.xsm"]=true; 
    ["AXM_HUN_arm2attack.xsm"]=true; ["AXM_HUN_arm2idle.xsm"]=true; ["AXM_HUN_arm2move.xsm"]=true; 
    ["Bandage.xac"]=true; ["BandageDiffuse.dds"]=true; ["BandageSpecular.dds"]=true; 
    ["Battlecruiser.xac"]=true; ["BattlecruiserDiffuse.dds"]=true; ["BattlecruiserSpecular.dds"]=true; 
    ["Battleship.xac"]=true; ["BattleshipDiffuse.dds"]=true; ["BattleshipSpecular.dds"]=true; 
    ["bomberflying.xsm"]=true; ["bomberunderattack.xsm"]=true; ["BritishBomber.xac"]=true; 
    ["britishbomberdiffuse.dds"]=true; ["britishbomberspec.dds"]=true; ["BritishCas.xac"]=true; 
    ["britishcasdiffuse.dds"]=true; ["britishcasspec.dds"]=true; ["BritishCavalry.xac"]=true; 
    ["BritishCavalryDiffuse.dds"]=true; ["BritishFighter.xac"]=true; ["BritishFighterDiffuse.dds"]=true; 
    ["BritishFighterSpec.dds"]=true; ["BritishGun1.xac"]=true; ["BritishGun2.xac"]=true; 
    ["BritishHelmet1.xac"]=true; ["BritishHelmet2.xac"]=true; ["BritishInfantry.xac"]=true; 
    ["BritishInfantryDiffuse.dds"]=true; ["BritishInfantrySpecular.dds"]=true; ["BritishNaval.xac"]=true; 
    ["britishnavaldiffuse.dds"]=true; ["britishnavalspec.dds"]=true; ["BritishTactical.xac"]=true; 
    ["britishtacticaldiffuse.dds"]=true; ["britishtacticalspec.dds"]=true; ["BritishTank.xac"]=true; 
    ["BritishTankDiffuse.dds"]=true; ["BritishTankSpecular.dds"]=true; ["BritishTransport.xac"]=true; 
    ["britishtransportdiffuse.dds"]=true; ["BUL_armor_brigade_0_diffuse.dds"]=true; ["BUL_armor_brigade_0_spec.dds"]=true; 
    ["BUL_armor_brigade_2_diffuse.dds"]=true; ["BUL_armor_brigade_2_spec.dds"]=true; ["BUL_armor_brigade_3_diffuse.dds"]=true; 
    ["BUL_armor_brigade_3_spec.dds"]=true; ["BUL_armor_brigade_4_diffuse.dds"]=true; ["BUL_armor_brigade_4_spec.dds"]=true; 
    ["BUL_interceptor_3_diffuse.dds"]=true; ["BUL_interceptor_3_spec.dds"]=true; ["BUL_light_armor_brigade_0_diffuse.dds"]=true; 
    ["BUL_light_armor_brigade_0_spec.dds"]=true; ["BUL_multi_role_1_diffuse.dds"]=true; ["BUL_multi_role_1_spec.dds"]=true; 
    ["Carrier.xac"]=true; ["CarrierDiffuse.dds"]=true; ["CarrierSpecular.dds"]=true; 
    ["CavalryAttack.xsm"]=true; ["CavalryIdle.xsm"]=true; ["CavalryWalking.xsm"]=true; 
    ["Destroyer.xac"]=true; ["DestroyerDiffuse.dds"]=true; ["DestroyerSpecular.dds"]=true; 
    ["EquipmentObject.xac"]=true; ["FighterAirAttack.xsm"]=true; ["FighterBombAttack.xsm"]=true; 
    ["FighterMove.xsm"]=true; ["FrenchBomber.xac"]=true; ["frenchbomberdiffuse.dds"]=true; 
    ["frenchbomberspec.dds"]=true; ["FrenchCas.xac"]=true; ["frenchcasdiffuse.dds"]=true; 
    ["frenchcasspec.dds"]=true; ["FrenchCavalry.xac"]=true; ["FrenchCavalryDiffuse.dds"]=true; 
    ["FrenchFighter.xac"]=true; ["FrenchFighterDiffuse.dds"]=true; ["FrenchFighterSpec.dds"]=true; 
    ["FrenchGun1.xac"]=true; ["FrenchGun2.xac"]=true; ["FrenchHelmet1.xac"]=true; 
    ["FrenchHelmet2.xac"]=true; ["FrenchInfantry.xac"]=true; ["FrenchInfantryDiffuse.dds"]=true; 
    ["FrenchInfantrySpecular.dds"]=true; ["FrenchNaval.xac"]=true; ["frenchnavaldiffuse.dds"]=true; 
    ["frenchnavalspec.dds"]=true; ["FrenchTactical.xac"]=true; ["frenchtacticaldiffuse.dds"]=true; 
    ["frenchtacticalspec.dds"]=true; ["FrenchTank.xac"]=true; ["FrenchTankDiffuse.dds"]=true; 
    ["FrenchTankSpecular.dds"]=true; ["FrenchTransport.xac"]=true; ["frenchtransportdiffuse.dds"]=true; 
    ["GenericBomber.xac"]=true; ["genericbomberdiffuse.dds"]=true; ["genericbomberspec.dds"]=true; 
    ["GenericCas.xac"]=true; ["genericcasdiffuse.dds"]=true; ["genericcaspec.dds"]=true; 
    ["GenericCavalry.xac"]=true; ["GenericCavalryDiffuse.dds"]=true; ["GenericFighter.xac"]=true; 
    ["GenericFighterDiffuse.dds"]=true; ["GenericFighterSpecular.dds"]=true; ["GenericGun1.xac"]=true; 
    ["GenericGun2.xac"]=true; ["GenericHelmet1.xac"]=true; ["GenericHelmet2.xac"]=true; 
    ["GenericInfantry.xac"]=true; ["GenericInfantryDiffuse.dds"]=true; ["GenericInfantrySpecular.dds"]=true; 
    ["GenericMech.xac"]=true; ["GenericMechAttack.xsm"]=true; ["genericmechdiffuse.dds"]=true; 
    ["GenericMechIdle.xsm"]=true; ["GenericMechMove.xsm"]=true; ["genericmechspec.dds"]=true; 
    ["GenericMotor.xac"]=true; ["genericmotordiffuse.dds"]=true; ["GenericMotorIdle.xsm"]=true; 
    ["GenericMotorMoving.xsm"]=true; ["genericmotorspec.dds"]=true; ["GenericNaval.xac"]=true; 
    ["genericnavaldiffuse.dds"]=true; ["genericnavalspec.dds"]=true; ["GenericTactical.xac"]=true; 
    ["generictacticaldiffuse.dds"]=true; ["generictacticalspec.dds"]=true; ["GenericTank.xac"]=true; 
    ["GenericTankDiffuse.dds"]=true; ["GenericTankSpecular.dds"]=true; ["GenericTransport.xac"]=true; 
    ["generictransportdiffuse.dds"]=true; ["GermanA7V.xac"]=true; ["GermanA7VDiffuse.dds"]=true; 
    ["GermanA7VSpecular.dds"]=true; ["GermanAAG_1936.xac"]=true; ["GermanAAG_1936Diffuse.dds"]=true; 
    ["GermanAAG_1936Specular.dds"]=true; ["GermanAAG_1940.xac"]=true; ["GermanAAG_1940Diffuse.dds"]=true; 
    ["GermanAAG_1940Specular.dds"]=true; ["GermanAntiAir_1934.xac"]=true; ["GermanAntiAir_1934Diffuse.dds"]=true; 
    ["GermanAntiAir_1934Specular.dds"]=true; ["GermanAntiAir_1936.xac"]=true; ["GermanAntiAir_1936Diffuse.dds"]=true; 
    ["GermanAntiAir_1936Specular.dds"]=true; ["GermanAntiAir_1938.xac"]=true; ["GermanAntiAir_1938Diffuse.dds"]=true; 
    ["GermanAntiAir_1938Specular.dds"]=true; ["GermanAntiAir_1940.xac"]=true; ["GermanAntiAir_1940Diffuse.dds"]=true; 
    ["GermanAntiAir_1940Specular.dds"]=true; ["GermanAntiAir_1942.xac"]=true; ["GermanAntiAir_1942Diffuse.dds"]=true; 
    ["GermanAntiAir_1942Specular.dds"]=true; ["GermanAntiAir_1944.xac"]=true; ["GermanAntiAir_1944Diffuse.dds"]=true; 
    ["GermanAntiAir_1944Specular.dds"]=true; ["GermanAntiTank_1934.xac"]=true; ["GermanAntiTank_1934Diffuse.dds"]=true; 
    ["GermanAntiTank_1934Specular.dds"]=true; ["GermanAntiTank_1936.xac"]=true; ["GermanAntiTank_1936Diffuse.dds"]=true; 
    ["GermanAntiTank_1936Specular.dds"]=true; ["GermanAntiTank_1938.xac"]=true; ["GermanAntiTank_1938Diffuse.dds"]=true; 
    ["GermanAntiTank_1938Specular.dds"]=true; ["GermanAntiTank_1940.xac"]=true; ["GermanAntiTank_1940Diffuse.dds"]=true; 
    ["GermanAntiTank_1940Specular.dds"]=true; ["GermanAntiTank_1942.xac"]=true; ["GermanAntiTank_1942Diffuse.dds"]=true; 
    ["GermanAntiTank_1942Specular.dds"]=true; ["GermanAntiTank_1944.xac"]=true; ["GermanAntiTank_1944Diffuse.dds"]=true; 
    ["GermanAntiTank_1944Specular.dds"]=true; ["GermanArtillery_1934.xac"]=true; ["GermanArtillery_1934Diffuse.dds"]=true; 
    ["GermanArtillery_1934Specular.dds"]=true; ["GermanArtillery_1936.xac"]=true; ["GermanArtillery_1936Diffuse.dds"]=true; 
    ["GermanArtillery_1936Specular.dds"]=true; ["GermanArtillery_1938.xac"]=true; ["GermanArtillery_1938Diffuse.dds"]=true; 
    ["GermanArtillery_1938Specular.dds"]=true; ["GermanArtillery_1940.xac"]=true; ["GermanArtillery_1940Diffuse.dds"]=true; 
    ["GermanArtillery_1940Specular.dds"]=true; ["GermanArtillery_1942.xac"]=true; ["GermanArtillery_1942Diffuse.dds"]=true; 
    ["GermanArtillery_1942Specular.dds"]=true; ["GermanArtillery_1944.xac"]=true; ["GermanArtillery_1944Diffuse.dds"]=true; 
    ["GermanArtillery_1944Specular.dds"]=true; ["GermanArt_1936.xac"]=true; ["GermanArt_1936Diffuse.dds"]=true; 
    ["GermanArt_1936Specular.dds"]=true; ["GermanArt_1938.xac"]=true; ["GermanArt_1938Diffuse.dds"]=true; 
    ["GermanArt_1938Specular.dds"]=true; ["GermanArt_1940.xac"]=true; ["GermanArt_1940diffuse.dds"]=true; 
    ["GermanArt_1940Specular.dds"]=true; ["GermanArt_1944.xac"]=true; ["GermanArt_1944Diffuse.dds"]=true; 
    ["GermanArt_1944Specular.dds"]=true; ["germanbcdiffuse.dds"]=true; ["germanbcspec.dds"]=true; 
    ["GermanBergsjaeger_1934.xac"]=true; ["GermanBergsjaeger_1934Diffuse.dds"]=true; ["GermanBergsjaeger_1934Specular.dds"]=true; 
    ["GermanBergsjaeger_1936.xac"]=true; ["GermanBergsjaeger_1936Diffuse.dds"]=true; ["GermanBergsjaeger_1936Specular.dds"]=true; 
    ["GermanBergsjaeger_1938.xac"]=true; ["GermanBergsjaeger_1938Diffuse.dds"]=true; ["GermanBergsjaeger_1938Specular.dds"]=true; 
    ["GermanBergsjaeger_1940.xac"]=true; ["GermanBergsjaeger_1940Diffuse.dds"]=true; ["GermanBergsjaeger_1940Specular.dds"]=true; 
    ["GermanBergsjaeger_1942.xac"]=true; ["GermanBergsjaeger_1942Diffuse.dds"]=true; ["GermanBergsjaeger_1942Specular.dds"]=true; 
    ["GermanBergsjaeger_1944.xac"]=true; ["GermanBergsjaeger_1944Diffuse.dds"]=true; ["GermanBergsjaeger_1944Specular.dds"]=true; 
    ["GermanBerg_1936.xac"]=true; ["GermanBerg_1936Diffuse.dds"]=true; ["GermanBerg_1936Specular.dds"]=true; 
    ["GermanBerg_1940.xac"]=true; ["GermanBerg_1940Diffuse.dds"]=true; ["GermanBerg_1940Specular.dds"]=true; 
    ["GermanBerg_1944.xac"]=true; ["GermanBerg_1944Diffuse.dds"]=true; ["GermanBerg_1944Specular.dds"]=true; 
    ["GermanBomber.xac"]=true; ["germanbomberdiffuse.dds"]=true; ["germanbomberspec.dds"]=true; 
    ["GermanCas.xac"]=true; ["germancasdiffuse.dds"]=true; ["germancasspec.dds"]=true; 
    ["GermanCavalry.xac"]=true; ["GermanCavalryDiffuse.dds"]=true; ["GermanCavalryspec.dds"]=true; 
    ["GermanCa_1936.xac"]=true; ["GermanCa_1936Diffuse.dds"]=true; ["GermanCa_1936spec.dds"]=true; 
    ["GermanCa_1938.xac"]=true; ["GermanCa_1938Diffuse.dds"]=true; ["GermanCa_1938spec.dds"]=true; 
    ["GermanCa_1940.xac"]=true; ["GermanCa_1940Diffuse.dds"]=true; ["GermanCa_1940spec.dds"]=true; 
    ["GermanCa_1944.xac"]=true; ["GermanCa_1944Diffuse.dds"]=true; ["GermanCa_1944spec.dds"]=true; 
    ["GermanCv_1936.xac"]=true; ["GermanCv_1936Diffuse.dds"]=true; ["GermanCv_1936spec.dds"]=true; 
    ["GermanCv_1938.xac"]=true; ["GermanCv_1938Diffuse.dds"]=true; ["GermanCv_1938spec.dds"]=true; 
    ["GermanCv_1940.xac"]=true; ["GermanCv_1940Diffuse.dds"]=true; ["GermanCv_1940spec.dds"]=true; 
    ["GermanCv_1942.xac"]=true; ["GermanCv_1942Diffuse.dds"]=true; ["GermanCv_1942spec.dds"]=true; 
    ["GermanCv_1944.xac"]=true; ["GermanCv_1944Diffuse.dds"]=true; ["GermanCv_1944spec.dds"]=true; 
    ["GermanCv_Equip.xac"]=true; ["GermanCv_Equip2.xac"]=true; ["GermanCv_EquipDiffuse.dds"]=true; 
    ["GermanCv_EquipSpecular.dds"]=true; ["GermanEngineer_1936.xac"]=true; ["GermanEngineer_1936Diffuse.dds"]=true; 
    ["GermanEngineer_1936Specular.dds"]=true; ["GermanEngineer_1939.xac"]=true; ["GermanEngineer_1939Diffuse.dds"]=true; 
    ["GermanEngineer_1939Specular.dds"]=true; ["GermanEngineer_1940.xac"]=true; ["GermanEngineer_1940Diffuse.dds"]=true; 
    ["GermanEngineer_1940Specular.dds"]=true; ["GermanEngineer_1942.xac"]=true; ["GermanEngineer_1942Diffuse.dds"]=true; 
    ["GermanEngineer_1942Specular.dds"]=true; ["GermanEngineer_1944.xac"]=true; ["GermanEngineer_1944Diffuse.dds"]=true; 
    ["GermanEngineer_1944Specular.dds"]=true; ["GermanFernglasAttack.xsm"]=true; ["GermanFernglasIdle.xsm"]=true; 
    ["GermanFernglasMove.xsm"]=true; ["GermanFernglasMove2.xsm"]=true; ["GermanFG42Attack.xsm"]=true; 
    ["GermanFG42Idle.xsm"]=true; ["GermanFG42Move.xsm"]=true; ["GermanFighter.xac"]=true; 
    ["GermanFighterDiffuse.dds"]=true; ["GermanFighterSpecular.dds"]=true; ["GermanGarrison_1934.xac"]=true; 
    ["GermanGarrison_1934Diffuse.dds"]=true; ["GermanGarrison_1934Specular.dds"]=true; ["GermanGarrison_1936.xac"]=true; 
    ["GermanGarrison_1936Diffuse.dds"]=true; ["GermanGarrison_1936Specular.dds"]=true; ["GermanGarrison_1938.xac"]=true; 
    ["GermanGarrison_1938Diffuse.dds"]=true; ["GermanGarrison_1938Specular.dds"]=true; ["GermanGarrison_1940.xac"]=true; 
    ["GermanGarrison_1940Diffuse.dds"]=true; ["GermanGarrison_1940Specular.dds"]=true; ["GermanGarrison_1942.xac"]=true; 
    ["GermanGarrison_1942Diffuse.dds"]=true; ["GermanGarrison_1942Specular.dds"]=true; ["GermanGarrison_1944.xac"]=true; 
    ["GermanGarrison_1944Diffuse.dds"]=true; ["GermanGarrison_1944Specular.dds"]=true; ["GermanGar_1936.xac"]=true; 
    ["GermanGar_1936Diffuse.dds"]=true; ["GermanGar_1936Specular.dds"]=true; ["GermanGun1.xac"]=true; 
    ["GermanGun2.xac"]=true; ["GermanGun3.xac"]=true; ["GermanHelmet1.xac"]=true; 
    ["GermanHelmet2.xac"]=true; ["GermanHelmet3.xac"]=true; ["GermanHelmet4.xac"]=true; 
    ["GermanHQG_1936.xac"]=true; ["GermanHQG_1936Diffuse.dds"]=true; ["GermanHQG_1936Specular.dds"]=true; 
    ["GermanHQ_1944.xac"]=true; ["GermanHQ_1944Diffuse.dds"]=true; ["GermanHQ_1944Specular.dds"]=true; 
    ["GermanInfantry.xac"]=true; ["GermanInfantryDiffuse.dds"]=true; ["GermanInfantrySpecular.dds"]=true; 
    ["GermanInfantry_1934.xac"]=true; ["GermanInfantry_1934Diffuse.dds"]=true; ["GermanInfantry_1934Specular.dds"]=true; 
    ["GermanInfantry_1936.xac"]=true; ["GermanInfantry_1936Diffuse.dds"]=true; ["GermanInfantry_1936Specular.dds"]=true; 
    ["GermanInfantry_1938.xac"]=true; ["GermanInfantry_1938Diffuse.dds"]=true; ["GermanInfantry_1938Specular.dds"]=true; 
    ["GermanInfantry_1940.xac"]=true; ["GermanInfantry_1940Diffuse.dds"]=true; ["GermanInfantry_1940Specular.dds"]=true; 
    ["GermanInfantry_1942.xac"]=true; ["GermanInfantry_1942Diffuse.dds"]=true; ["GermanInfantry_1942Specular.dds"]=true; 
    ["GermanInfantry_1944.xac"]=true; ["GermanInfantry_1944Diffuse.dds"]=true; ["GermanInfantry_1944Specular.dds"]=true; 
    ["GermanInf_1936.xac"]=true; ["GermanInf_1936Diffuse.dds"]=true; ["GermanInf_1936Specular.dds"]=true; 
    ["GermanInf_1938.xac"]=true; ["GermanInf_1938Diffuse.dds"]=true; ["GermanInf_1938Specular.dds"]=true; 
    ["GermanInf_1940.xac"]=true; ["GermanInf_1940diffuse.dds"]=true; ["GermanInf_1940Specular.dds"]=true; 
    ["GermanInf_1944.xac"]=true; ["GermanInf_1944diffuse.dds"]=true; ["GermanInf_1944Specular.dds"]=true; 
    ["GermanK98kAttack.xsm"]=true; ["GermanK98kIdle.xsm"]=true; ["GermanK98kIdle2.xsm"]=true; 
    ["GermanK98kIdle3.xsm"]=true; ["GermanK98kMove.xsm"]=true; ["GermanK98kMove2.xsm"]=true; 
    ["GermanK98kMove3.xsm"]=true; ["GermanKomet.xac"]=true; ["GermanKometDiff.dds"]=true; 
    ["GermanKometSpec.dds"]=true; ["GermanLeopard1.xac"]=true; ["GermanLeopard1Diff.dds"]=true; 
    ["GermanLeopard1Spec.dds"]=true; ["GermanLuger08Attack.xsm"]=true; ["GermanLuger08Attack2.xsm"]=true; 
    ["GermanLuger08Idle.xsm"]=true; ["GermanLuger08Idle2.xsm"]=true; ["GermanLuger08Idle3.xsm"]=true; 
    ["GermanLuger08Move.xsm"]=true; ["GermanLuger08Move2.xsm"]=true; ["GermanMarine_1936.xac"]=true; 
    ["GermanMarine_1936Diffuse.dds"]=true; ["GermanMarine_1936Specular.dds"]=true; ["GermanMarine_1938.xac"]=true; 
    ["GermanMarine_1938Diffuse.dds"]=true; ["GermanMarine_1938Specular.dds"]=true; ["GermanMarine_1940.xac"]=true; 
    ["GermanMarine_1940Diffuse.dds"]=true; ["GermanMarine_1940Specular.dds"]=true; ["GermanMarine_1942.xac"]=true; 
    ["GermanMarine_1942Diffuse.dds"]=true; ["GermanMarine_1942Specular.dds"]=true; ["GermanMarine_1944.xac"]=true; 
    ["GermanMarine_1944Diffuse.dds"]=true; ["GermanMarine_1944Specular.dds"]=true; ["GermanMar_1936.xac"]=true; 
    ["GermanMar_1936Diffuse.dds"]=true; ["GermanMar_1936Specular.dds"]=true; ["GermanMar_1940.xac"]=true; 
    ["GermanMar_1940Diffuse.dds"]=true; ["GermanMar_1940Specular.dds"]=true; ["GermanMech.xac"]=true; 
    ["GermanMechAttack.xsm"]=true; ["germanmechdiffuse.dds"]=true; ["GermanMechIdle.xsm"]=true; 
    ["GermanMechMove.xsm"]=true; ["germanmechspec.dds"]=true; ["GermanMG34Attack.xsm"]=true; 
    ["GermanMG34Idle.xsm"]=true; ["GermanMG34Move.xsm"]=true; ["GermanMG42Attack.xsm"]=true; 
    ["GermanMilitia_1934.xac"]=true; ["GermanMilitia_1934Diffuse.dds"]=true; ["GermanMilitia_1934Specular.dds"]=true; 
    ["GermanMilitia_1936.xac"]=true; ["GermanMilitia_1936Diffuse.dds"]=true; ["GermanMilitia_1936Specular.dds"]=true; 
    ["GermanMilitia_1938.xac"]=true; ["GermanMilitia_1938Diffuse.dds"]=true; ["GermanMilitia_1938Specular.dds"]=true; 
    ["GermanMilitia_1940.xac"]=true; ["GermanMilitia_1940Diffuse.dds"]=true; ["GermanMilitia_1940Specular.dds"]=true; 
    ["GermanMilitia_1942.xac"]=true; ["GermanMilitia_1942Diffuse.dds"]=true; ["GermanMilitia_1942Specular.dds"]=true; 
    ["GermanMilitia_1944.xac"]=true; ["GermanMilitia_1944Diffuse.dds"]=true; ["GermanMilitia_1944Specular.dds"]=true; 
    ["GermanMil_1936.xac"]=true; ["GermanMil_1936Diffuse.dds"]=true; ["GermanMil_1936Specular.dds"]=true; 
    ["GermanMil_1942.xac"]=true; ["GermanMil_1942diffuse.dds"]=true; ["GermanMil_1942Specular.dds"]=true; 
    ["GermanMil_1944.xac"]=true; ["GermanMil_1944Diffuse.dds"]=true; ["GermanMil_1944Specular.dds"]=true; 
    ["GermanMotor.xac"]=true; ["germanmotordiffuse.dds"]=true; ["GermanMotorIdle.xsm"]=true; 
    ["GermanMotorMoving.xsm"]=true; ["germanmotorspec.dds"]=true; ["GermanMP38Attack.xsm"]=true; 
    ["GermanMP38Idle.xsm"]=true; ["GermanMP38Idle2.xsm"]=true; ["GermanMP38Move.xsm"]=true; 
    ["GermanNaval.xac"]=true; ["germannavaldiffuse.dds"]=true; ["germannavalspec.dds"]=true; 
    ["GermanParatrooper_1939.xac"]=true; ["GermanParatrooper_1939Diffuse.dds"]=true; ["GermanParatrooper_1939Specular.dds"]=true; 
    ["GermanParatrooper_1940.xac"]=true; ["GermanParatrooper_1940Diffuse.dds"]=true; ["GermanParatrooper_1940Specular.dds"]=true; 
    ["GermanParatrooper_1942.xac"]=true; ["GermanParatrooper_1942Diffuse.dds"]=true; ["GermanParatrooper_1942Specular.dds"]=true; 
    ["GermanParatrooper_1944.xac"]=true; ["GermanParatrooper_1944Diffuse.dds"]=true; ["GermanParatrooper_1944Specular.dds"]=true; 
    ["GermanPartisan_1934.xac"]=true; ["GermanPartisan_1934Diffuse.dds"]=true; ["GermanPartisan_1934Specular.dds"]=true; 
    ["GermanPartisan_1936.xac"]=true; ["GermanPartisan_1936Diffuse.dds"]=true; ["GermanPartisan_1936Specular.dds"]=true; 
    ["GermanPartisan_1938.xac"]=true; ["GermanPartisan_1938Diffuse.dds"]=true; ["GermanPartisan_1938Specular.dds"]=true; 
    ["GermanPartisan_1940.xac"]=true; ["GermanPartisan_1940Diffuse.dds"]=true; ["GermanPartisan_1940Specular.dds"]=true; 
    ["GermanPartisan_1942.xac"]=true; ["GermanPartisan_1942Diffuse.dds"]=true; ["GermanPartisan_1942Specular.dds"]=true; 
    ["GermanPartisan_1944.xac"]=true; ["GermanPartisan_1944Diffuse.dds"]=true; ["GermanPartisan_1944Specular.dds"]=true; 
    ["GermanPar_1940.xac"]=true; ["GermanPar_1940diffuse.dds"]=true; ["GermanPar_1940Specular.dds"]=true; 
    ["GermanPar_1944.xac"]=true; ["GermanPar_1944diffuse.dds"]=true; ["GermanPar_1944Specular.dds"]=true; 
    ["GermanPat_1936.xac"]=true; ["GermanPat_1936Diffuse.dds"]=true; ["GermanPat_1936Specular.dds"]=true; 
    ["GermanPio_1936.xac"]=true; ["GermanPio_1936Diffuse.dds"]=true; ["GermanPio_1936Specular.dds"]=true; 
    ["GermanPio_1939.xac"]=true; ["GermanPio_1939Diffuse.dds"]=true; ["GermanPio_1939Specular.dds"]=true; 
    ["GermanPio_1940.xac"]=true; ["GermanPio_1940Diffuse.dds"]=true; ["GermanPio_1940Specular.dds"]=true; 
    ["GermanPio_1944.xac"]=true; ["GermanPio_1944Diffuse.dds"]=true; ["GermanPio_1944Specular.dds"]=true; 
    ["GermanPolice_1936.xac"]=true; ["GermanPolice_1936Diffuse.dds"]=true; ["GermanPolice_1936Specular.dds"]=true; 
    ["GermanPolice_1939.xac"]=true; ["GermanPolice_1939Diffuse.dds"]=true; ["GermanPolice_1939Specular.dds"]=true; 
    ["GermanPolice_1942.xac"]=true; ["GermanPolice_1942Diffuse.dds"]=true; ["GermanPolice_1942Specular.dds"]=true; 
    ["GermanPolice_1945.xac"]=true; ["GermanPolice_1945Diffuse.dds"]=true; ["GermanPolice_1945Specular.dds"]=true; 
    ["GermanPol_1936.xac"]=true; ["GermanPol_1936diffuse.dds"]=true; ["GermanPol_1936Specular.dds"]=true; 
    ["GermanPol_1939.xac"]=true; ["GermanPol_1939diffuse.dds"]=true; ["GermanPol_1939Specular.dds"]=true; 
    ["GermanPol_1942.xac"]=true; ["GermanPol_1942diffuse.dds"]=true; ["GermanPol_1942Specular.dds"]=true; 
    ["GermanPol_1945.xac"]=true; ["GermanPol_1945diffuse.dds"]=true; ["GermanPol_1945Specular.dds"]=true; 
    ["GermanReconAttack.xsm"]=true; ["GermanReconIdle.xsm"]=true; ["GermanReconMove.xsm"]=true; 
    ["GermanRecon_1935.xac"]=true; ["GermanRecon_1935Diffuse.dds"]=true; ["GermanRecon_1935Specular.dds"]=true; 
    ["GermanRecon_1938.xac"]=true; ["GermanRecon_1938Diffuse.dds"]=true; ["GermanRecon_1938Specular.dds"]=true; 
    ["GermanRecon_1941.xac"]=true; ["GermanRecon_1941Diffuse.dds"]=true; ["GermanRecon_1941Specular.dds"]=true; 
    ["GermanRecon_1944.xac"]=true; ["GermanRecon_1944Diffuse.dds"]=true; ["GermanRecon_1944Specular.dds"]=true; 
    ["GermanRec_1936.xac"]=true; ["GermanRec_1936Diffuse.dds"]=true; ["GermanRec_1936Specular.dds"]=true; 
    ["GermanRec_1944.xac"]=true; ["GermanRec_1944Diffuse.dds"]=true; ["GermanRec_1944Specular.dds"]=true; 
    ["GermanRocket_Artillery_1938.xac"]=true; ["GermanRocket_Artillery_1938Diffuse.dds"]=true; ["GermanRocket_Artillery_1938Specular.dds"]=true; 
    ["GermanRocket_Artillery_1940.xac"]=true; ["GermanRocket_Artillery_1940Diffuse.dds"]=true; ["GermanRocket_Artillery_1940Specular.dds"]=true; 
    ["GermanRocket_Artillery_1942.xac"]=true; ["GermanRocket_Artillery_1942Diffuse.dds"]=true; ["GermanRocket_Artillery_1942Specular.dds"]=true; 
    ["GermanRocket_Artillery_1944.xac"]=true; ["GermanRocket_Artillery_1944Diffuse.dds"]=true; ["GermanRocket_Artillery_1944Specular.dds"]=true; 
    ["GermanSchleswig.xac"]=true; ["GermanSPA_1940.xac"]=true; ["GermanSPA_1940Diffuse.dds"]=true; 
    ["GermanSPA_1940Specular.dds"]=true; ["GermanSp_Artillery_1938.xac"]=true; ["GermanSp_Artillery_1938Diffuse.dds"]=true; 
    ["GermanSp_Artillery_1938Specular.dds"]=true; ["GermanSp_Artillery_1940.xac"]=true; ["GermanSp_Artillery_1940Diffuse.dds"]=true; 
    ["GermanSp_Artillery_1940Specular.dds"]=true; ["GermanSp_Artillery_1942.xac"]=true; ["GermanSp_Artillery_1942Diffuse.dds"]=true; 
    ["GermanSp_Artillery_1942Specular.dds"]=true; ["GermanSp_Artillery_1944.xac"]=true; ["GermanSp_Artillery_1944Diffuse.dds"]=true; 
    ["GermanSp_Artillery_1944Specular.dds"]=true; ["GermanSp_Rct_Artillery_1940.xac"]=true; ["GermanSp_Rct_Artillery_1940Diffuse.dds"]=true; 
    ["GermanSp_Rct_Artillery_1940Specular.dds"]=true; ["GermanSp_Rct_Artillery_1942.xac"]=true; ["GermanSp_Rct_Artillery_1942Diffuse.dds"]=true; 
    ["GermanSp_Rct_Artillery_1942Specular.dds"]=true; ["GermanSp_Rct_Artillery_1944.xac"]=true; ["GermanSp_Rct_Artillery_1944Diffuse.dds"]=true; 
    ["GermanSp_Rct_Artillery_1944Specular.dds"]=true; ["GermanSTG44Attack.xsm"]=true; ["GermanSTG44Idle.xsm"]=true; 
    ["GermanSTG44Move.xsm"]=true; ["GermanStielgranateAttack.xsm"]=true; ["GermanStielgranateIdle.xsm"]=true; 
    ["GermanStielgranateMove.xsm"]=true; ["GermanT107.xac"]=true; ["GermanT107Diffuse.dds"]=true; 
    ["GermanT107Specular.dds"]=true; ["GermanTactical.xac"]=true; ["germantacticaldiffuse.dds"]=true; 
    ["germantacticalspec.dds"]=true; ["GermanTank.xac"]=true; ["GermanTankAttack.xsm"]=true; 
    ["GermanTankDiffuse.dds"]=true; ["GermanTankIdle.xsm"]=true; ["GermanTankMove.xsm"]=true; 
    ["germantankspec.dds"]=true; ["GermanTransport.xac"]=true; ["germantransportdiffuse.dds"]=true; 
    ["GermanU-IIA.xac"]=true; ["GermanU-IIB.xac"]=true; ["GermanU-XXI.xac"]=true; 
    ["GermanUAttack.xsm"]=true; ["GermanUmove.xsm"]=true; ["GermanWeaponsDiffuse.dds"]=true; 
    ["GermanWeaponsSpecular.dds"]=true; ["GermanZeppelin.xac"]=true; ["GermanZeppelindiff.dds"]=true; 
    ["GermanZeppelinspec.dds"]=true; ["Heavycruiser.xac"]=true; ["HeavycruiserDiffuse.dds"]=true; 
    ["HeavycruiserSpecular.dds"]=true; ["HUN_armor_brigade_0_diffuse.dds"]=true; ["HUN_armor_brigade_2_diffuse.dds"]=true; 
    ["HUN_armor_brigade_2_spec.dds"]=true; ["HUN_armor_brigade_4_diffuse.dds"]=true; ["HUN_cas_1_diffuse.dds"]=true; 
    ["HUN_cas_1_spec.dds"]=true; ["HUN_light_armor_brigade_0_diffuse.dds"]=true; ["HUN_light_armor_brigade_0_spec.dds"]=true; 
    ["HUN_multi_role_1_diffuse.dds"]=true; ["HUN_multi_role_1_spec.dds"]=true; ["HUN_tactical_bomber_2_diffuse.dds"]=true; 
    ["HUN_tactical_bomber_2_spec.dds"]=true; ["import os.py"]=true; ["InfantryAttackA.xsm"]=true; 
    ["InfantryAttackB.xsm"]=true; ["InfantryAttackC.xsm"]=true; ["InfantryAttackD.xsm"]=true; 
    ["InfantryAttackMove.xsm"]=true; ["InfantryIdleA.xsm"]=true; ["InfantryMove.xsm"]=true; 
    ["InfantryRetreat.xsm"]=true; ["ItalianBomber.xac"]=true; ["italianbomberdiffuse.dds"]=true; 
    ["italianbomberspec.dds"]=true; ["ItalianCas.xac"]=true; ["italiancasdiffuse.dds"]=true; 
    ["italiancasspec.dds"]=true; ["ItalianCavalry.xac"]=true; ["ItalianCavalryDiffuse.dds"]=true; 
    ["ItalianFighter.xac"]=true; ["ItalianFighterDiffuse.dds"]=true; ["ItalianFighterSpec.dds"]=true; 
    ["ItalianGun1.xac"]=true; ["ItalianGun2.xac"]=true; ["ItalianHelmet1.xac"]=true; 
    ["ItalianHelmet2.xac"]=true; ["ItalianInfantry.xac"]=true; ["ItalianInfantryDiffuse.dds"]=true; 
    ["ItalianInfantrySpecular.dds"]=true; ["ItalianNaval.xac"]=true; ["italiannavaldiffuse.dds"]=true; 
    ["italiannavalspec.dds"]=true; ["ItalianTactical.xac"]=true; ["italiantacticaldiffuse.dds"]=true; 
    ["italiantacticalspec.dds"]=true; ["ItalianTank.xac"]=true; ["ItalianTankDiffuse.dds"]=true; 
    ["ItalianTankSpecular.dds"]=true; ["ItalianTransport.xac"]=true; ["italiantransportdiffuse.dds"]=true; 
    ["ITAV_Arm1.xac"]=true; ["ITAV_Arm1Attack.xsm"]=true; ["ITAV_Arm1Idle.xsm"]=true; 
    ["ITAV_Arm1Move.xsm"]=true; ["ITAV_Arm1_Diffuse.dds"]=true; ["ITAV_Arm1_Specular.dds"]=true; 
    ["ITAV_Arm3.xac"]=true; ["ITAV_Arm3Attack.xsm"]=true; ["ITAV_Arm3Idle.xsm"]=true; 
    ["ITAV_Arm3Move.xsm"]=true; ["ITAV_Arm3_Diffuse.dds"]=true; ["ITAV_Arm3_Specular.dds"]=true; 
    ["ITAV_BattleshipLittorio.xac"]=true; ["ITAV_BattleshipLittorioattack.xsm"]=true; ["ITAV_BattleshipLittorioidle.xsm"]=true; 
    ["ITAV_BattleshipLittorio_Diffuse.dds"]=true; ["ITAV_BattleshipLittorio_Specular.dds"]=true; ["ITAV_Bragadin.xac"]=true; 
    ["ITAV_Bragadinidle.xsm"]=true; ["ITAV_Bragadin_Diffuse.dds"]=true; ["ITAV_Bragadin_Specular.dds"]=true; 
    ["ITAV_CasBa65.xac"]=true; ["ITAV_CasBa65Idle.xsm"]=true; ["ITAV_CasBa65_Diffuse.dds"]=true; 
    ["ITAV_CasBa65_Specular.dds"]=true; ["ITAV_DestroyerNavigator.xac"]=true; ["ITAV_DestroyerNavigatorattack.xsm"]=true; 
    ["ITAV_DestroyerNavigatoridle.xsm"]=true; ["ITAV_DestroyerNavigator_Diffuse.dds"]=true; ["ITAV_DestroyerNavigator_Specular.dds"]=true; 
    ["ITAV_Harm0.xac"]=true; ["ITAV_Harm0Attack.xsm"]=true; ["ITAV_Harm0Idle.xsm"]=true; 
    ["ITAV_Harm0Move.xsm"]=true; ["ITAV_Harm0_Diffuse.dds"]=true; ["ITAV_Harm0_Specular.dds"]=true; 
    ["ITAV_HeavycruiserZara.xac"]=true; ["ITAV_HeavycruiserZaraAttack.xsm"]=true; ["ITAV_HeavycruiserZaraIdle.xsm"]=true; 
    ["ITAV_HeavycruiserZara_Diffuse.dds"]=true; ["ITAV_HeavycruiserZara_Spec.dds"]=true; ["ITAV_InterceptorMC200.xac"]=true; 
    ["ITAV_InterceptorMC200attack.xsm"]=true; ["ITAV_InterceptorMC200idle.xsm"]=true; ["ITAV_InterceptorMC200_Diffuse.dds"]=true; 
    ["ITAV_InterceptorMC200_Specular.dds"]=true; ["ITAV_InterceptorRe2001.xac"]=true; ["ITAV_InterceptorRe2001attack.xsm"]=true; 
    ["ITAV_InterceptorRe2001idle.xsm"]=true; ["ITAV_InterceptorRe2001_Diffuse.dds"]=true; ["ITAV_InterceptorRe2001_Specular.dds"]=true; 
    ["ITAV_Larm0.xac"]=true; ["ITAV_Larm0Attack.xsm"]=true; ["ITAV_Larm0Idle.xsm"]=true; 
    ["ITAV_Larm0Move.xsm"]=true; ["ITAV_Larm0_Diffuse.dds"]=true; ["ITAV_Larm0_Specular.dds"]=true; 
    ["ITAV_Larm2.xac"]=true; ["ITAV_Larm2Attack.xsm"]=true; ["ITAV_Larm2Idle.xsm"]=true; 
    ["ITAV_Larm2Move.xsm"]=true; ["ITAV_Larm2_Diffuse.dds"]=true; ["ITAV_Larm2_Specular.dds"]=true; 
    ["ITAV_LightcruiserAbruzzi.xac"]=true; ["ITAV_LightcruiserAbruzziattack.xsm"]=true; ["ITAV_LightcruiserAbruzziidle.xsm"]=true; 
    ["ITAV_LightcruiserAbruzzi_Diffuse.dds"]=true; ["ITAV_LightcruiserAbruzzi_Specular.dds"]=true; ["ITAV_mech0.xac"]=true; 
    ["ITAV_Mech0Attack.xsm"]=true; ["ITAV_mech0idle.xsm"]=true; ["ITAV_Mech0Move.xsm"]=true; 
    ["ITAV_mech0_Diffuse.dds"]=true; ["ITAV_mech0_Specular.dds"]=true; ["ITAV_MultiroleRe2005.xac"]=true; 
    ["ITAV_MultiroleRe2005Attack.xsm"]=true; ["ITAV_MultiroleRe2005Idle.xsm"]=true; ["ITAV_MultiroleRe2005_Diffuse.dds"]=true; 
    ["ITAV_MultiroleRe2005_Specular.dds"]=true; ["ITAV_TacticalZ1007.xac"]=true; ["ITAV_TacticalZ1007idle.xsm"]=true; 
    ["ITAV_TacticalZ1007_Diffuse.dds"]=true; ["ITAV_TacticalZ1007_Specular.dds"]=true; ["JapaneseAAG_1936.xac"]=true; 
    ["JapaneseAAG_1936Diffuse.dds"]=true; ["JapaneseAAG_1936Specular.dds"]=true; ["JapaneseAAG_1938.xac"]=true; 
    ["JapaneseAAG_1938Diffuse.dds"]=true; ["JapaneseAAG_1938Specular.dds"]=true; ["JapaneseAAG_1942.xac"]=true; 
    ["JapaneseAAG_1942Diffuse.dds"]=true; ["JapaneseAAG_1942Specular.dds"]=true; ["JapaneseArt_1936.xac"]=true; 
    ["JapaneseArt_1936Diffuse.dds"]=true; ["JapaneseArt_1936Specular.dds"]=true; ["JapaneseArt_1938.xac"]=true; 
    ["JapaneseArt_1938Diffuse.dds"]=true; ["JapaneseArt_1938Specular.dds"]=true; ["JapaneseArt_1942.xac"]=true; 
    ["JapaneseArt_1942Diffuse.dds"]=true; ["JapaneseArt_1942Specular.dds"]=true; ["JapaneseBomber.xac"]=true; 
    ["japanesebomberdiffuse.dds"]=true; ["japanesebomberspec.dds"]=true; ["JapaneseCas.xac"]=true; 
    ["japanesecasdiffuse.dds"]=true; ["japanesecasspec.dds"]=true; ["JapaneseCavalry.xac"]=true; 
    ["JapaneseCavalryDiffuse.dds"]=true; ["JapaneseCa_1936.xac"]=true; ["JapaneseCa_1936Diffuse.dds"]=true; 
    ["JapaneseCa_1938.xac"]=true; ["JapaneseCa_1938Diffuse.dds"]=true; ["JapaneseCa_1942.xac"]=true; 
    ["JapaneseCa_1942Diffuse.dds"]=true; ["JapaneseFighter.xac"]=true; ["JapaneseFighterDiffuse.dds"]=true; 
    ["JapaneseFighterSpecular.dds"]=true; ["JapaneseGar_1936.xac"]=true; ["JapaneseGar_1936Diffuse.dds"]=true; 
    ["JapaneseGar_1936Specular.dds"]=true; ["JapaneseGun1.xac"]=true; ["JapaneseGun2.xac"]=true; 
    ["JapaneseHelmet1.xac"]=true; ["JapaneseHelmet2.xac"]=true; ["JapaneseHelmet3.xac"]=true; 
    ["JapaneseHelmet4.xac"]=true; ["JapaneseHelmetDiffuse.dds"]=true; ["JapaneseHelmetSpecular.dds"]=true; 
    ["JapaneseHQG_1936.xac"]=true; ["JapaneseHQG_1936Diffuse.dds"]=true; ["JapaneseHQG_1936Specular.dds"]=true; 
    ["JapaneseInfantry.xac"]=true; ["JapaneseInfantryDiffuse.dds"]=true; ["JapaneseInfantrySpecular.dds"]=true; 
    ["JapaneseInf_1936.xac"]=true; ["JapaneseInf_1936Diffuse.dds"]=true; ["JapaneseInf_1936Specular.dds"]=true; 
    ["JapaneseInf_1938.xac"]=true; ["JapaneseInf_1938Diffuse.dds"]=true; ["JapaneseInf_1938Specular.dds"]=true; 
    ["JapaneseInf_1942.xac"]=true; ["JapaneseInf_1942Diffuse.dds"]=true; ["JapaneseInf_1942Specular.dds"]=true; 
    ["JapaneseMar_1936.xac"]=true; ["JapaneseMar_1936Diffuse.dds"]=true; ["JapaneseMar_1936Specular.dds"]=true; 
    ["JapaneseMar_1938.xac"]=true; ["JapaneseMar_1938Diffuse.dds"]=true; ["JapaneseMar_1938Specular.dds"]=true; 
    ["JapaneseMar_1942.xac"]=true; ["JapaneseMar_1942Diffuse.dds"]=true; ["JapaneseMar_1942Specular.dds"]=true; 
    ["JapaneseMil_1936.xac"]=true; ["JapaneseMil_1936Diffuse.dds"]=true; ["JapaneseMil_1936Specular.dds"]=true; 
    ["JapaneseMil_1938.xac"]=true; ["JapaneseMil_1938Diffuse.dds"]=true; ["JapaneseMil_1938Specular.dds"]=true; 
    ["JapaneseMil_1942.xac"]=true; ["JapaneseMil_1942Diffuse.dds"]=true; ["JapaneseMil_1942Specular.dds"]=true; 
    ["JapaneseMnt_1936.xac"]=true; ["JapaneseMnt_1936Diffuse.dds"]=true; ["JapaneseMnt_1936Specular.dds"]=true; 
    ["JapaneseNaval.xac"]=true; ["JapaneseNavelDiffuse.dds"]=true; ["JapaneseNavelSpec.dds"]=true; 
    ["JapanesePar_1942.xac"]=true; ["JapanesePar_1942Diffuse.dds"]=true; ["JapanesePar_1942Specular.dds"]=true; 
    ["JapanesePar_1944.xac"]=true; ["JapanesePar_1944Diffuse.dds"]=true; ["JapanesePar_1944Specular.dds"]=true; 
    ["JapanesePat_1936.xac"]=true; ["JapanesePat_1936diffuse.dds"]=true; ["JapanesePat_1936Specular.dds"]=true; 
    ["JapanesePio_1936.xac"]=true; ["JapanesePio_1936Diffuse.dds"]=true; ["JapanesePio_1936Specular.dds"]=true; 
    ["JapanesePio_1939.xac"]=true; ["JapanesePio_1939Diffuse.dds"]=true; ["JapanesePio_1939Specular.dds"]=true; 
    ["JapanesePio_1942.xac"]=true; ["JapanesePio_1942Diffuse.dds"]=true; ["JapanesePio_1942Specular.dds"]=true; 
    ["JapanesePol_1936.xac"]=true; ["JapanesePol_1936Diffuse.dds"]=true; ["JapanesePol_1936Specular.dds"]=true; 
    ["JapanesePol_1939.xac"]=true; ["JapanesePol_1939Diffuse.dds"]=true; ["JapanesePol_1939Specular.dds"]=true; 
    ["JapanesePol_1942.xac"]=true; ["JapanesePol_1942Diffuse.dds"]=true; ["JapanesePol_1942Specular.dds"]=true; 
    ["JapaneseRec_1936.xac"]=true; ["JapaneseRec_1936Diffuse.dds"]=true; ["JapaneseRec_1936Specular.dds"]=true; 
    ["JapaneseRec_1938.xac"]=true; ["JapaneseRec_1938Diffuse.dds"]=true; ["JapaneseRec_1938Specular.dds"]=true; 
    ["JapaneseSPA_1938.xac"]=true; ["JapaneseSPA_1938Diffuse.dds"]=true; ["JapaneseSPA_1938Specular.dds"]=true; 
    ["JapaneseTactical.xac"]=true; ["japanesetacticaldiffuse.dds"]=true; ["japanesetacticalspec.dds"]=true; 
    ["JapaneseTank.xac"]=true; ["JapaneseTankDiffuse.dds"]=true; ["JapaneseTankSpecular.dds"]=true; 
    ["JapaneseTransport.xac"]=true; ["japanesetransportdiffuse.dds"]=true; ["japanesetransportspec.dds"]=true; 
    ["Japan_Cavalryspec.dds"]=true; ["jb2.xac"]=true; ["jb2diffuse.dds"]=true; 
    ["jb2spec.dds"]=true; ["KometAttack.xsm"]=true; ["KometMove.xsm"]=true; 
    ["Leopard1Attack.xsm"]=true; ["Leopard1idle.xsm"]=true; ["Leopard1move.xsm"]=true; 
    ["Lightcruiser.xac"]=true; ["LightCruiserDiffuse.dds"]=true; ["LightCruiserSpecular.dds"]=true; 
    ["Move.xsm"]=true; ["output.txt"]=true; ["rank1.xac"]=true; 
    ["rank2.xac"]=true; ["rank3.xac"]=true; ["rank4.xac"]=true; 
    ["rank5.xac"]=true; ["rank6.xac"]=true; ["rankstar.xac"]=true; 
    ["ROM_armor_brigade_0_diffuse.dds"]=true; ["ROM_armor_brigade_2_diffuse.dds"]=true; ["ROM_armor_brigade_2_spec.dds"]=true; 
    ["ROM_armor_brigade_3_diffuse.dds"]=true; ["ROM_armor_brigade_4_diffuse.dds"]=true; ["ROM_cas_1_diffuse.dds"]=true; 
    ["ROM_cas_1_spec.dds"]=true; ["ROM_multi_role_1_diffuse.dds"]=true; ["ROM_multi_role_1_spec.dds"]=true; 
    ["ROM_tactical_bomber_2_diffuse.dds"]=true; ["ROM_tactical_bomber_2_spec.dds"]=true; ["SchleswigAttack.xsm"]=true; 
    ["SchleswigDiffuse.dds"]=true; ["Schleswigmove.xsm"]=true; ["SchleswigSpecular.dds"]=true; 
    ["seamove.xsm"]=true; ["ShipAttackA.xsm"]=true; ["ShipBigIdle.xsm"]=true; 
    ["ShipRetreat.xsm"]=true; ["SLO_cas_1_diffuse.dds"]=true; ["SLO_cas_1_spec.dds"]=true; 
    ["SLO_interceptor_2_diffuse.dds"]=true; ["SLO_interceptor_2_spec.dds"]=true; ["SLO_interceptor_3_diffuse.dds"]=true; 
    ["SLO_interceptor_3_spec.dds"]=true; ["SLO_light_armor_brigade_0_diffuse.dds"]=true; ["SLO_light_armor_brigade_0_spec.dds"]=true; 
    ["SovietAAG_1936.xac"]=true; ["SovietAAG_1936Diffuse.dds"]=true; ["SovietAAG_1936Specular.dds"]=true; 
    ["SovietAAG_1942.xac"]=true; ["SovietAAG_1942Diffuse.dds"]=true; ["SovietAAG_1942Specular.dds"]=true; 
    ["SovietAAG_1944.xac"]=true; ["SovietAAG_1944Diffuse.dds"]=true; ["SovietAAG_1944Specular.dds"]=true; 
    ["SovietArt_1936.xac"]=true; ["SovietArt_1936Diffuse.dds"]=true; ["SovietArt_1936Specular.dds"]=true; 
    ["SovietArt_1942.xac"]=true; ["SovietArt_1942Diffuse.dds"]=true; ["SovietArt_1942Specular.dds"]=true; 
    ["SovietArt_1944.xac"]=true; ["SovietArt_1944Diffuse.dds"]=true; ["SovietArt_1944Specular.dds"]=true; 
    ["SovietBomber.xac"]=true; ["sovietbomberdiffuse.dds"]=true; ["sovietbomberspec.dds"]=true; 
    ["SovietCas.xac"]=true; ["SovietCasDiffuse.dds"]=true; ["SovietCasSpec.dds"]=true; 
    ["SovietCavalry.xac"]=true; ["SovietCavalryDiffuse.dds"]=true; ["SovietCa_1936.xac"]=true; 
    ["SovietCa_1936Diffuse.dds"]=true; ["SovietCa_1936spec.dds"]=true; ["SovietCa_1942.xac"]=true; 
    ["SovietCa_1942Diffuse.dds"]=true; ["SovietCa_1942spec.dds"]=true; ["SovietCa_1944.xac"]=true; 
    ["SovietCa_1944Diffuse.dds"]=true; ["SovietCa_1944spec.dds"]=true; ["SovietFighter.xac"]=true; 
    ["SovietFighterDiffuse.dds"]=true; ["SovietFighterSpec.dds"]=true; ["SovietGar_1936.xac"]=true; 
    ["SovietGar_1936Diffuse.dds"]=true; ["SovietGar_1936Specular.dds"]=true; ["SovietGar_1942.xac"]=true; 
    ["SovietGar_1942Diffuse.dds"]=true; ["SovietGar_1942Specular.dds"]=true; ["SovietGun1.xac"]=true; 
    ["SovietGun1Bone.xac"]=true; ["SovietGun2.xac"]=true; ["SovietHelmet1.xac"]=true; 
    ["SovietHelmet1Bone.xac"]=true; ["SovietHelmet2.xac"]=true; ["SovietHelmet3.xac"]=true; 
    ["SovietHelmet3b.xac"]=true; ["SovietHelmet4.xac"]=true; ["SovietHelmet_3bDiffuse.dds"]=true; 
    ["SovietHelmet_3bSpecular.dds"]=true; ["SovietHelmet_3Diffuse.dds"]=true; ["SovietHelmet_3Specular.dds"]=true; 
    ["SovietHelmet_4Diffuse.dds"]=true; ["SovietHelmet_4Specular.dds"]=true; ["SovietHQG_1936.xac"]=true; 
    ["SovietHQG_1936Diffuse.dds"]=true; ["SovietHQG_1936Specular.dds"]=true; ["SovietInfantry.xac"]=true; 
    ["SovietInfantryDiffuse.dds"]=true; ["SovietInfantrySpecular.dds"]=true; ["SovietInf_1936.xac"]=true; 
    ["SovietInf_1936Diffuse.dds"]=true; ["SovietInf_1936Specular.dds"]=true; ["SovietInf_1942.xac"]=true; 
    ["SovietInf_1942Diffuse.dds"]=true; ["SovietInf_1942Specular.dds"]=true; ["SovietInf_1944.xac"]=true; 
    ["SovietInf_1944Diffuse.dds"]=true; ["SovietInf_1944Specular.dds"]=true; ["SovietMaInf_1936.xac"]=true; 
    ["SovietMaInf_1936Diffuse.dds"]=true; ["SovietMaInf_1936Specular.dds"]=true; ["SovietMaInf_1942.xac"]=true; 
    ["SovietMaInf_1942Diffuse.dds"]=true; ["SovietMaInf_1942Specular.dds"]=true; ["SovietMar_1944.xac"]=true; 
    ["SovietMar_1944Diffuse.dds"]=true; ["SovietMar_1944Specular.dds"]=true; ["SovietMil_1936.xac"]=true; 
    ["SovietMil_1936Diffuse.dds"]=true; ["SovietMil_1936Specular.dds"]=true; ["SovietMil_1942.xac"]=true; 
    ["SovietMil_1942Diffuse.dds"]=true; ["SovietMil_1942Specular.dds"]=true; ["SovietMil_1944.xac"]=true; 
    ["SovietMil_1944Diffuse.dds"]=true; ["SovietMil_1944Specular.dds"]=true; ["SovietMnt_1936.xac"]=true; 
    ["SovietMnt_1936Diffuse.dds"]=true; ["SovietMnt_1936Specular.dds"]=true; ["SovietNaval.xac"]=true; 
    ["sovietnavaldiffuse.dds"]=true; ["sovietnavalspec.dds"]=true; ["SovietPar_1942.xac"]=true; 
    ["SovietPar_1942Diffuse.dds"]=true; ["SovietPar_1942Specular.dds"]=true; ["SovietPar_1944.xac"]=true; 
    ["SovietPar_1944Diffuse.dds"]=true; ["SovietPar_1944Specular.dds"]=true; ["SovietPat_1936.xac"]=true; 
    ["SovietPat_1936Diffuse.dds"]=true; ["SovietPat_1936Specular.dds"]=true; ["SovietPio_1936.xac"]=true; 
    ["SovietPio_1936Diffuse.dds"]=true; ["SovietPio_1936Specular.dds"]=true; ["SovietPio_1942.xac"]=true; 
    ["SovietPio_1942Diffuse.dds"]=true; ["SovietPio_1942Specular.dds"]=true; ["SovietPio_1944.xac"]=true; 
    ["SovietPio_1944Diffuse.dds"]=true; ["SovietPio_1944Specular.dds"]=true; ["SovietPol_1936.xac"]=true; 
    ["SovietPol_1936Diffuse.dds"]=true; ["SovietPol_1936Specular.dds"]=true; ["SovietPol_1942.xac"]=true; 
    ["SovietPol_1942Diffuse.dds"]=true; ["SovietPol_1942Specular.dds"]=true; ["SovietRec_1936.xac"]=true; 
    ["SovietRec_1936Diffuse.dds"]=true; ["SovietRec_1936Specular.dds"]=true; ["SovietRec_1942.xac"]=true; 
    ["SovietRec_1942Diffuse.dds"]=true; ["SovietRec_1942Specular.dds"]=true; ["SovietSPA_1942.xac"]=true; 
    ["SovietSPA_1942Diffuse.dds"]=true; ["SovietSPA_1942Specular.dds"]=true; ["SovietTactical.xac"]=true; 
    ["soviettacticaldiffuse.dds"]=true; ["soviettacticalspec.dds"]=true; ["SovietTank.xac"]=true; 
    ["SovietTankDiffuse.dds"]=true; ["SovietTankSpecular.dds"]=true; ["SovietTransport.xac"]=true; 
    ["soviettransportdiffuse.dds"]=true; ["SP_GermanBismarck.xac"]=true; ["SP_GermanBismarckattack.xsm"]=true; 
    ["sp_germanbismarckdiffuse.dds"]=true; ["SP_GermanBismarckidle.xsm"]=true; ["sp_germanbismarckspec.dds"]=true; 
    ["SP_GermanCruiser.xac"]=true; ["SP_GermanCruiserAttack.xsm"]=true; ["sp_germancruiserdiffuse.dds"]=true; 
    ["SP_GermanCruiserIdle.xsm"]=true; ["sp_germancruiserspec.dds"]=true; ["Sp_GermanGraf.xac"]=true; 
    ["SP_GermanGrafattack.xsm"]=true; ["sp_germangrafdiffuse.dds"]=true; ["SP_GermanGrafidle.xsm"]=true; 
    ["sp_germangrafspec.dds"]=true; ["SP_GermanInterceptor.xac"]=true; ["sp_germaninterceptordiffuse.dds"]=true; 
    ["sp_germaninterceptorspec.dds"]=true; ["SP_GermanKclass.xac"]=true; ["SP_GermanKclassattack.xsm"]=true; 
    ["SP_GermanKclassidle.xsm"]=true; ["SP_GermanMultirole.xac"]=true; ["sp_germanmultirolediffuse.dds"]=true; 
    ["SP_GermanMultiroleFw.xac"]=true; ["sp_germanmultirolefwdiffuse.dds"]=true; ["sp_germanmultirolefwspec.dds"]=true; 
    ["sp_germanmultirolespec.dds"]=true; ["SP_GermanPanzar1.xac"]=true; ["SP_GermanPanzar1attack.xsm"]=true; 
    ["sp_germanpanzar1diffuse.dds"]=true; ["SP_GermanPanzar1idle.xsm"]=true; ["SP_GermanPanzar1moving.xsm"]=true; 
    ["sp_germanpanzar1spec.dds"]=true; ["sp_germanpanzar2diffuse.dds"]=true; ["sp_germanpanzar2spec.dds"]=true; 
    ["sp_germanpanzar3diffuse.dds"]=true; ["sp_germanpanzar3spec.dds"]=true; ["sp_germanpanzar4diffuse.dds"]=true; 
    ["sp_germanpanzar4spec.dds"]=true; ["SP_GermanPanzar5.xac"]=true; ["sp_germanpanzar5diffuse.dds"]=true; 
    ["sp_germanpanzar5spec.dds"]=true; ["SP_GermanPanzar6B.xac"]=true; ["sp_germanpanzar6bdiffuse.dds"]=true; 
    ["sp_germanpanzar6bspec.dds"]=true; ["SP_GermanPanzarattack.xsm"]=true; ["SP_GermanPanzarmove.xsm"]=true; 
    ["SP_GermanPanzer2.xac"]=true; ["SP_GermanPanzer3.xac"]=true; ["SP_GermanPanzer4.xac"]=true; 
    ["SP_GermanScharnhorst.xac"]=true; ["SP_GermanScharnhorstattack.xsm"]=true; ["SP_GermanScharnhorstidle.xsm"]=true; 
    ["SP_GermanSubmarine.xac"]=true; ["sp_germansubmarinediffuse.dds"]=true; ["sp_germansubmarinespec.dds"]=true; 
    ["SP_GermanTactical.xac"]=true; ["sp_germantacticaldiffuse.dds"]=true; ["sp_germantacticalspec.dds"]=true; 
    ["SP_GermanZclass.xac"]=true; ["SP_GermanZclassAttack.xsm"]=true; ["SP_GermanZclassIdle.xsm"]=true; 
    ["SP_german_destroyer_diffuse.dds"]=true; ["SP_german_destroyer_spec.dds"]=true; ["sp_soviet28_move.xsm"]=true; 
    ["sp_sovietbt5.xac"]=true; ["sp_sovietbt5diffuse.dds"]=true; ["sp_sovietbt5spec.dds"]=true; 
    ["sp_sovietBT7.xac"]=true; ["sp_sovietbt7diffuse.dds"]=true; ["sp_sovietbt7spec.dds"]=true; 
    ["sp_sovietBTattack.xsm"]=true; ["sp_sovietBTidle.xsm"]=true; ["sp_sovietBTmoving.xsm"]=true; 
    ["sp_sovietgangutdiffuse.dds"]=true; ["sp_sovietgangutspec.dds"]=true; ["sp_sovietis2diffuse.dds"]=true; 
    ["sp_sovietis2spec.dds"]=true; ["sp_sovietkirov.xac"]=true; ["sp_sovietkirovdiffuse.dds"]=true; 
    ["sp_sovietkirovspec.dds"]=true; ["sp_sovietkirov_attack.xsm"]=true; ["sp_sovietkirov_idle.xsm"]=true; 
    ["sp_sovietKv.xac"]=true; ["sp_sovietkv1diffuse.dds"]=true; ["sp_sovietkv1spec.dds"]=true; 
    ["sp_sovietKv2.xac"]=true; ["sp_sovietkv2diffuse.dds"]=true; ["sp_sovietkv2spec.dds"]=true; 
    ["sp_sovietkv_attack.xsm"]=true; ["sp_sovietKv_idle.xsm"]=true; ["sp_sovietKv_move.xsm"]=true; 
    ["SP_SovietLagg3.xac"]=true; ["SP_SovietLagg3diffuse.dds"]=true; ["SP_SovietLagg3spec.dds"]=true; 
    ["SP_SovietMig3.xac"]=true; ["sp_sovietmig3diffuse.dds"]=true; ["sp_sovietmig3spec.dds"]=true; 
    ["SP_SovietMig9.xac"]=true; ["sp_sovietmig9diffuse.dds"]=true; ["sp_sovietmig9spec.dds"]=true; 
    ["SP_SovietSu2.xac"]=true; ["SP_SovietSu2diffuse.dds"]=true; ["SP_SovietSu2spec.dds"]=true; 
    ["sp_sovietT28.xac"]=true; ["sp_soviett28_attack.xsm"]=true; ["sp_soviett28_idle.xsm"]=true; 
    ["sp_sovietT34.xac"]=true; ["sp_sovietT34attack.xsm"]=true; ["sp_sovietT34idle.xsm"]=true; 
    ["sp_sovietT34move.xsm"]=true; ["sp_sovietT44.xac"]=true; ["sp_sovietT44attack.xsm"]=true; 
    ["sp_sovietT44diffuse.dds"]=true; ["sp_sovietT44idle.xsm"]=true; ["sp_sovietT44move.xsm"]=true; 
    ["sp_sovietT44spec.dds"]=true; ["SP_SovietYak4.xac"]=true; ["SP_SovietYak4Diffuse.dds"]=true; 
    ["SP_SovietYak4Spec.dds"]=true; ["sp_soviet_gangut.xac"]=true; ["sp_soviet_gangut_attack.xsm"]=true; 
    ["sp_soviet_gangut_idle.xsm"]=true; ["sp_soviet_is2.xac"]=true; ["sp_soviet_is2_attack.xsm"]=true; 
    ["sp_soviet_is2_idle.xsm"]=true; ["sp_soviet_is2_move.xsm"]=true; ["sp_soviet_leningradC_destroyer.xac"]=true; 
    ["sp_soviet_leningradC_destroyer_attack.xsm"]=true; ["sp_soviet_leningradC_destroyer_diffuse.dds"]=true; ["sp_soviet_leningradC_destroyer_idle.xsm"]=true; 
    ["sp_soviet_leningradC_destroyer_spec.dds"]=true; ["sp_soviet_submarine.xac"]=true; ["sp_soviet_submarine_diffuse.dds"]=true; 
    ["sp_soviet_submarine_spec.dds"]=true; ["sp_t28diffuse.dds"]=true; ["sp_t28spec.dds"]=true; 
    ["sp_t34diffuse.dds"]=true; ["sp_t34spec.dds"]=true; ["SP_UsBaltimore.xac"]=true; 
    ["SP_UsBaltimoreAttack.xsm"]=true; ["SP_UsBaltimoreIdle.xsm"]=true; ["sp_usbattleshipiowadiffuse.dds"]=true; 
    ["sp_usbattleshipiowaspec.dds"]=true; ["sp_usbattleshipncdiffuse.dds"]=true; ["sp_usbattleshipncspec.dds"]=true; 
    ["SP_UsBrooklyn.xac"]=true; ["SP_UsBrooklynAttack.xsm"]=true; ["SP_UsBrooklynIdle.xsm"]=true; 
    ["sp_uscarrieressexdiffuse.dds"]=true; ["sp_uscarrieressexspec.dds"]=true; ["sp_uscarrierlexdiffuse.dds"]=true; 
    ["sp_uscarrierlexspec.dds"]=true; ["sp_uscruiserbrookdiffuse.dds"]=true; ["sp_uscruiserbrookspec.dds"]=true; 
    ["sp_usdestroyerdiffuse.dds"]=true; ["sp_usdestroyerspec.dds"]=true; ["SP_UsEssex.xac"]=true; 
    ["SP_UsFletcher.xac"]=true; ["SP_UsFletcherAttack.xsm"]=true; ["SP_UsFletcherIdle.xsm"]=true; 
    ["SP_UsGato.xac"]=true; ["SP_UsIntercepterSaber.xac"]=true; ["SP_UsInterceptorHellcat.xac"]=true; 
    ["sp_usinterceptorhellcatdiffuse.dds"]=true; ["sp_usinterceptorhellcatspec.dds"]=true; ["sp_usinterceptorsaberdiffuse.dds"]=true; 
    ["sp_usinterceptorsaberspec.dds"]=true; ["SP_UsInterceptorWildcat.xac"]=true; ["sp_usinterceptorwildcatdiffuse.dds"]=true; 
    ["sp_usinterceptorwildcatspec.dds"]=true; ["SP_UsIowa.xac"]=true; ["SP_UsIowaattack.xsm"]=true; 
    ["SP_UsIowaidle.xsm"]=true; ["SP_UsLeeTank.xac"]=true; ["SP_UsLexington.xac"]=true; 
    ["sp_uslightcruiserdiffuse.dds"]=true; ["sp_uslightcruiserspec.dds"]=true; ["SP_UsNorthCarolina.xac"]=true; 
    ["SP_UsNorthCarolinaAttack.xsm"]=true; ["SP_UsNorthCarolinaIdle.xsm"]=true; ["SP_UsPershingTank.xac"]=true; 
    ["SP_UsShermanTank.xac"]=true; ["SP_UsStrategic.xac"]=true; ["sp_usstrategicdiffuse.dds"]=true; 
    ["sp_usstrategicspec.dds"]=true; ["SP_UsStuart.xac"]=true; ["SP_UsStuartAttack.xsm"]=true; 
    ["SP_UsStuartIdle.xsm"]=true; ["SP_UsStuartMove.xsm"]=true; ["sp_ussubmarinediffuse.dds"]=true; 
    ["sp_ussubmarinespec.dds"]=true; ["SP_UsTactical.xac"]=true; ["sp_ustacticaldiffuse.dds"]=true; 
    ["sp_ustacticalspec.dds"]=true; ["sp_ustank03diffuse.dds"]=true; ["sp_ustank03spec.dds"]=true; 
    ["sp_ustank04diffuse.dds"]=true; ["sp_ustank04spec.dds"]=true; ["SP_UsTankAttack.xsm"]=true; 
    ["SP_UsTankIdle.xsm"]=true; ["SP_UsTankMove.xsm"]=true; ["stardiffuse.dds"]=true; 
    ["staridle.xsm"]=true; ["starspec.dds"]=true; ["Submarine.xac"]=true; 
    ["SubmarineAttackA.xsm"]=true; ["SubmarineDiffuse.dds"]=true; ["SubmarineMove.xsm"]=true; 
    ["SubmarineRetreat.xsm"]=true; ["SubmarineSpecular.dds"]=true; ["T107Attack.xsm"]=true; 
    ["T107move.xsm"]=true; ["tactical_flying.xsm"]=true; ["TankAttackA.xsm"]=true; 
    ["TankAttackB.xsm"]=true; ["TankAttackC.xsm"]=true; ["TankAttackD.xsm"]=true; 
    ["TankAttackF.xsm"]=true; ["TankAttackG.xsm"]=true; ["TankAttackMove.xsm"]=true; 
    ["TankAttackMoveItalian.xsm"]=true; ["TankIdleA.xsm"]=true; ["TankMove.xsm"]=true; 
    ["TankTurret.xsm"]=true; ["Thumbs.db"]=true; ["Track.dds"]=true; 
    ["TrackB.dds"]=true; ["Transportship.xac"]=true; ["TransportshipDiffuse.dds"]=true; 
    ["TransportshipSpecular.dds"]=true; ["U-IIADiffuse.dds"]=true; ["U-IIASpecular.dds"]=true; 
    ["U-IIBDiffuse.dds"]=true; ["U-IIBSpecular.dds"]=true; ["UsAAG_1936.xac"]=true; 
    ["UsAAG_1936diffuse.dds"]=true; ["UsAAG_1936Specular.dds"]=true; ["UsAAG_1942.xac"]=true; 
    ["UsAAG_1942diffuse.dds"]=true; ["UsAAG_1942Specular.dds"]=true; ["UsAAG_1944.xac"]=true; 
    ["UsAAG_1944diffuse.dds"]=true; ["UsAAG_1944Specular.dds"]=true; ["USAHelmet2.xac"]=true; 
    ["USAmericanCavspec.dds"]=true; ["UsArt_1936.xac"]=true; ["UsArt_1936diffuse.dds"]=true; 
    ["UsArt_1936Specular.dds"]=true; ["UsArt_1942.xac"]=true; ["UsArt_1942diffuse.dds"]=true; 
    ["UsArt_1942Specular.dds"]=true; ["UsArt_1944.xac"]=true; ["UsArt_1944diffuse.dds"]=true; 
    ["UsArt_1944Specular.dds"]=true; ["UsBomber.xac"]=true; ["usbomberdiffuse.dds"]=true; 
    ["usbomberspec.dds"]=true; ["UsCas.xac"]=true; ["uscasdiffuse.dds"]=true; 
    ["uscasspec.dds"]=true; ["UsCavalry.xac"]=true; ["UsCavalryDiffuse.dds"]=true; 
    ["UsCavalryHelmetDiffuse.dds"]=true; ["UsCavalryHelmetSpecular.dds"]=true; ["UsCa_1936.xac"]=true; 
    ["UsCa_1936Diffuse.dds"]=true; ["UsCa_1942.xac"]=true; ["UsCa_1942Diffuse.dds"]=true; 
    ["UsCa_1944.xac"]=true; ["UsCa_1944Diffuse.dds"]=true; ["UsFighter.xac"]=true; 
    ["USFighterDiffuse.dds"]=true; ["USFighterSpec.dds"]=true; ["UsGar_1936.xac"]=true; 
    ["UsGar_1936diffuse.dds"]=true; ["UsGar_1936Specular.dds"]=true; ["UsGun1.xac"]=true; 
    ["UsGun2.xac"]=true; ["UsHelmet1.xac"]=true; ["UsHelmet3.xac"]=true; 
    ["UsHQG_1936.xac"]=true; ["UsHQG_1936Diffuse.dds"]=true; ["UsHQG_1936Specular.dds"]=true; 
    ["UsInfantry.xac"]=true; ["UsInfantryDiffuse.dds"]=true; ["UsInfantrySpecular.dds"]=true; 
    ["UsInf_1936.xac"]=true; ["Usinf_1936diffuse.dds"]=true; ["UsInf_1936Specular.dds"]=true; 
    ["UsInf_1942.xac"]=true; ["UsInf_1942diffuse.dds"]=true; ["UsInf_1942Specular.dds"]=true; 
    ["UsInf_1944.xac"]=true; ["UsInf_1944diffuse.dds"]=true; ["UsInf_1944Specular.dds"]=true; 
    ["UsMar_1936.xac"]=true; ["UsMar_1936diffuse.dds"]=true; ["UsMar_1936Specular.dds"]=true; 
    ["UsMar_1942.xac"]=true; ["UsMar_1942diffuse.dds"]=true; ["UsMar_1942Specular.dds"]=true; 
    ["UsMar_1944.xac"]=true; ["UsMar_1944diffuse.dds"]=true; ["UsMar_1944Specular.dds"]=true; 
    ["UsMech.xac"]=true; ["UsMechAttack.xsm"]=true; ["usmechdiffuse.dds"]=true; 
    ["UsMechIdle.xsm"]=true; ["UsMechMove.xsm"]=true; ["usmechspec.dds"]=true; 
    ["UsMil_1936.xac"]=true; ["UsMil_1936diffuse.dds"]=true; ["UsMil_1936Specular.dds"]=true; 
    ["UsMil_1942.xac"]=true; ["UsMil_1942diffuse.dds"]=true; ["UsMil_1942Specular.dds"]=true; 
    ["UsMil_1944.xac"]=true; ["UsMil_1944diffuse.dds"]=true; ["UsMil_1944Specular.dds"]=true; 
    ["UsMotor.xac"]=true; ["usmotordiffuse.dds"]=true; ["UsMotorIdle.xsm"]=true; 
    ["UsMotorMoving.xsm"]=true; ["usmotorspec.dds"]=true; ["USMountain_1942.xac"]=true; 
    ["USMountain_1942Diffuse.dds"]=true; ["USMountain_1942Specular.dds"]=true; ["UsNaval.xac"]=true; 
    ["usnavaldiffuse.dds"]=true; ["usnavalspec.dds"]=true; ["UsPar_1942.xac"]=true; 
    ["UsPar_1942diffuse.dds"]=true; ["UsPar_1942Specular.dds"]=true; ["UsPar_1944.xac"]=true; 
    ["UsPar_1944diffuse.dds"]=true; ["UsPar_1944Specular.dds"]=true; ["UsPat_1936.xac"]=true; 
    ["UsPat_1936diffuse.dds"]=true; ["UsPat_1936Specular.dds"]=true; ["UsPio_1936.xac"]=true; 
    ["UsPio_1936diffuse.dds"]=true; ["UsPio_1936Specular.dds"]=true; ["UsPio_1942.xac"]=true; 
    ["UsPio_1942diffuse.dds"]=true; ["UsPio_1942Specular.dds"]=true; ["UsPio_1944.xac"]=true; 
    ["UsPio_1944diffuse.dds"]=true; ["UsPio_1944Specular.dds"]=true; ["UsPol_1936.xac"]=true; 
    ["UsPol_1936diffuse.dds"]=true; ["UsPol_1936Specular.dds"]=true; ["UsPol_1942.xac"]=true; 
    ["UsPol_1942diffuse.dds"]=true; ["UsPol_1942Specular.dds"]=true; ["UsPol_1944.xac"]=true; 
    ["UsPol_1944diffuse.dds"]=true; ["UsPol_1944Specular.dds"]=true; ["UsRec_1936.xac"]=true; 
    ["UsRec_1936diffuse.dds"]=true; ["UsRec_1936Specular.dds"]=true; ["UsRec_1942.xac"]=true; 
    ["UsRec_1942diffuse.dds"]=true; ["UsRec_1942Specular.dds"]=true; ["UsRec_1944.xac"]=true; 
    ["UsRec_1944diffuse.dds"]=true; ["UsRec_1944Specular.dds"]=true; ["UsSPA_1942.xac"]=true; 
    ["UsSPA_1942diffuse.dds"]=true; ["UsSPA_1942Specular.dds"]=true; ["UsSPA_1944.xac"]=true; 
    ["UsSPA_1944diffuse.dds"]=true; ["UsSPA_1944Specular.dds"]=true; ["UsTactical.xac"]=true; 
    ["ustacticaldiffuse.dds"]=true; ["ustacticalspec.dds"]=true; ["UsTank.xac"]=true; 
    ["UsTankDiffuse.dds"]=true; ["UsTankSpecular.dds"]=true; ["UsTransport.xac"]=true; 
    ["ustransportdiffuse.dds"]=true; ["UXXIDiffuse.dds"]=true; ["UXXISpecular.dds"]=true; 
    ["v1.xac"]=true; ["v1diffuse.dds"]=true; ["v1spec.dds"]=true; 
    ["V2A10.xac"]=true; ["V2A10Diffuse.dds"]=true; ["V2A10Specular.dds"]=true; 
    ["V2A4.xac"]=true; ["V2A4Diffuse.dds"]=true; ["V2A4Specular.dds"]=true; 
    ["V2A9.xac"]=true; ["V2A9Diffuse.dds"]=true; ["V2A9Specular.dds"]=true; 
    ["ZeppelinAttack.xsm"]=true; ["Zeppelinmove.xsm"]=true; 
}