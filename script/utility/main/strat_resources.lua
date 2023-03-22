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

-- Called from button press
function DeactivateResourceSelling(desiredState, resource)
    if PlayerCountry ~= nil then
        local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
        if desiredState == true then
            local command = CSetVariableCommand(playerCountryTag, CString(resource .. "_deactivate_sales"), CFixedPoint(1))
            CCurrentGameState.Post(command)
            SetResourceSaleStatesText("Stopped", resource)
        elseif desiredState == false then
            local command = CSetVariableCommand(playerCountryTag, CString(resource .. "_deactivate_sales"), CFixedPoint(0))
            CCurrentGameState.Post(command)
            SetResourceSaleStatesText("Selling",resource)
        end
    end
end

-- Called each refresh and once at country selection
function GetAndSetResourceSaleStates()
    local resources = {"chromite","aluminium","rubber","tungsten","nickel","copper","zinc","manganese","molybdenum"}
    local playerCountryTag = CCountryDataBase.GetTag(PlayerCountry)
    local playerVariables = playerCountryTag:GetCountry():GetVariables()
    for index, resource in pairs(resources) do
        if playerVariables:GetVariable(CString(resource .. "_deactivate_sales")):Get() == 1 then
            SetResourceSaleStatesText("Stopped", resource)
        else
            SetResourceSaleStatesText("Selling",resource)
        end
    end
end

-- Called from internal
function SetResourceSaleStatesText(state, resource)
    if resource == "chromite" then
        UI.m_textCtrlChromiteSaleActive:SetValue(state)
    end
    if resource == "aluminium" then
        UI.m_textCtrlAluminiumSaleActive:SetValue(state)
    end
    if resource == "rubber" then
        UI.m_textCtrlRubberSaleActive:SetValue(state)
    end
    if resource == "tungsten" then
        UI.m_textCtrlTungstenSaleActive:SetValue(state)
    end
    if resource == "nickel" then
        UI.m_textCtrlNickelSaleActive:SetValue(state)
    end
    if resource == "copper" then
        UI.m_textCtrlCopperSaleActive:SetValue(state)
    end
    if resource == "zinc" then
        UI.m_textCtrlZincSaleActive:SetValue(state)
    end
    if resource == "manganese" then
        UI.m_textCtrlManganeseSaleActive:SetValue(state)
    end
    if resource == "molybdenum" then
        UI.m_textCtrlMolybdenumSaleActive:SetValue(state)
    end
end