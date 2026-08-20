function GuiRefreshLoop(skipInterval)
    -- Both are set when a country is picked on the wx Setup tab, and this loop only ran
    -- after that had happened. The ImGui utility also sets G_PlayerCountry - by itself,
    -- as soon as a page needs a country - so the loop can now be reached before the wx
    -- tab has ever been touched, leaving nothing to compare the day count against.
    G_DaysSinceLastUpdate = G_DaysSinceLastUpdate or 0
    G_UpdateInterval = G_UpdateInterval or 1

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