function FillTradesGrid()
    UI.m_grid_trades_1:ClearGrid()
    UI.m_grid_trades_1:DeleteRows(0, UI.m_grid_trades_1:GetNumberRows(), true )
    local row = 0
    local currentDate = CCurrentGameState.GetCurrentDate():GetTotalDays()
    local buys = {}
    local sales = {}
    for tag, trades in pairs(GlobalTradesData) do
        for tradeName, trade in pairs(GlobalTradesData[tag]["trades"]) do
            if trade["buyer"] == PlayerCountry then
                table.insert(buys, trade)
            end
            if trade["seller"] == PlayerCountry then
                table.insert(sales, trade)
            end
        end
    end
    -- BUYS
    table.sort(buys, function (k1, k2) return k1.expiryDate < k2.expiryDate end )
    UI.m_grid_trades_1:AppendRows(1, true)
    -- insert buys marking row
    for i=0,3,1 do
        UI.m_grid_trades_1:SetCellValue(row, i, "-BUYS-")
        UI.m_grid_trades_1:SetCellBackgroundColour( row, i, wx.wxColour( 224, 224, 224 ) )
    end
    row = row + 1
    for i, trade in ipairs(buys) do
        UI.m_grid_trades_1:AppendRows(1, true)
        -- Buyer
        UI.m_grid_trades_1:SetCellValue(row, 0, trade["buyer"])
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 0, wx.wxColour( 208, 208, 208 ) )
        -- Seller
        UI.m_grid_trades_1:SetCellValue(row, 1, trade["seller"])
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 1, wx.wxColour( 208, 208, 208 ) )
        -- Resource
        UI.m_grid_trades_1:SetCellValue(row, 2, trade["resource"])
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 2, wx.wxColour( 208, 208, 208 ) )
        -- Expires in
        local expiresInDays = trade["expiryDate"] - currentDate
        UI.m_grid_trades_1:SetCellValue(row, 3, string.format('%.0f', expiresInDays))
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 3, wx.wxColour( 208, 208, 208 ) )
        row = row + 1
    end
    -- SALES
    table.sort(sales, function (k1, k2) return k1.expiryDate < k2.expiryDate end )
    UI.m_grid_trades_1:AppendRows(1, true)
    -- insert sales marking row
    for j=0,3,1 do
        UI.m_grid_trades_1:SetCellValue(row, j, "-SALES-")
        UI.m_grid_trades_1:SetCellBackgroundColour( row, j, wx.wxColour( 224, 224, 224 ) )
    end
    row = row + 1
    for i, trade in ipairs(sales) do
        UI.m_grid_trades_1:AppendRows(1, true)
        -- Buyer
        UI.m_grid_trades_1:SetCellValue(row, 0, trade["buyer"])
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 0, wx.wxColour( 208, 208, 208 ) )
        -- Seller
        UI.m_grid_trades_1:SetCellValue(row, 1, trade["seller"])
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 1, wx.wxColour( 208, 208, 208 ) )
        -- Resource
        UI.m_grid_trades_1:SetCellValue(row, 2, trade["resource"])
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 2, wx.wxColour( 208, 208, 208 ) )
        -- Expires in
        local expiresInDays = trade["expiryDate"] - currentDate
        UI.m_grid_trades_1:SetCellValue(row, 3, string.format('%.0f', expiresInDays))
        UI.m_grid_trades_1:SetCellBackgroundColour( row, 3, wx.wxColour( 208, 208, 208 ) )
        row = row + 1
    end
end
