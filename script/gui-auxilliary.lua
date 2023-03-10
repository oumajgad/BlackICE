function GuiRefreshLoop(skipInterval)
    DaysSinceLastUpdate = DaysSinceLastUpdate + 1
    if wx ~= nil and PlayerCountry ~= nil and (skipInterval == true or DaysSinceLastUpdate >= UpdateInterval) then
        DaysSinceLastUpdate = 0
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
end