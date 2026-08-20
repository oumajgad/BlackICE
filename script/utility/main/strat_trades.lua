-- Strategic trades tab.
--
-- Which trades the country is party to, and how soon each expires, live in
-- BiceData.Trades and are shared with the ImGui utility. This keeps the wx half:
-- filling the grid, with its heading rows and shading.

local HEADING_COLOUR = { 224, 224, 224 }
local ROW_COLOUR = { 208, 208, 208 }

local function fillRow(row, values, colour)
    UI.m_grid_trades_1:AppendRows(1, true)
    for column = 0, 3, 1 do
        UI.m_grid_trades_1:SetCellValue(row, column, values[column + 1])
        UI.m_grid_trades_1:SetCellBackgroundColour(row, column,
            wx.wxColour(colour[1], colour[2], colour[3]))
    end
    return row + 1
end

local function fillSection(row, heading, trades)
    row = fillRow(row, { heading, heading, heading, heading }, HEADING_COLOUR)

    for _, trade in ipairs(trades) do
        row = fillRow(row, {
            trade.buyer,
            trade.seller,
            trade.resource,
            string.format('%.0f', trade.expires_in),
        }, ROW_COLOUR)
    end
    return row
end

function FillTradesGrid()
    UI.m_grid_trades_1:ClearGrid()
    UI.m_grid_trades_1:DeleteRows(0, UI.m_grid_trades_1:GetNumberRows(), true)

    local data = BiceData.Trades.ForPlayer()
    if data == nil then
        return
    end

    -- Already ordered by how soon they expire, which is how this grid always read.
    local row = fillSection(0, "-BUYS-", data.buys)
    fillSection(row, "-SALES-", data.sales)
end
