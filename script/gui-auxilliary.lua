function GuiRefreshLoop(skipInterval)
    G_DaysSinceLastUpdate = G_DaysSinceLastUpdate + 1
    if wx ~= nil then
        if G_PlayerCountry ~= nil and (skipInterval == true or G_DaysSinceLastUpdate >= G_UpdateInterval) then
            G_DaysSinceLastUpdate = 0
            GetAndAddPuppets()
            GetPlayerModifiers()
            GetStratResourceValues()
            SetICDaysLeftText()
            DetermineICInvestmentValue()
            GetAndSetResourceSaleStates()
            GetNatFocusDays()
            GetMinisterBuildingsProgress()
            FillTradesGrid()
        end

        if UI.GlobalMarket:IsShown() then
            GlobalMarketGridUpdate()
        end
    end
end