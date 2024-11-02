local P = {}

function P.FillGrid()
    if G_PlayerCountry == nil then
        return
    end

    local vars = BiceLib.getCountryVariables(G_PlayerCountry)

    if vars == nil then
        Utils.LUA_DEBUGOUT("vars nil")
        return
    end

    -- Utils.INSPECT_TABLE(vars)

    UI.m_grid_GameInfo_Vars1:ClearGrid()
    UI.m_grid_GameInfo_Vars1:DeleteRows(0, UI.m_grid_GameInfo_Vars1:GetNumberRows(), true )
    local i = 1
    for k, v in spairs(vars, SortByKeyAscendingCaseInsensitive) do
        if v ~= 0 then
            v = v/1000
        end
        -- Utils.LUA_DEBUGOUT(k)
        -- Utils.LUA_DEBUGOUT(v)
        UI.m_grid_GameInfo_Vars1:AppendRows(1, true)
        UI.m_grid_GameInfo_Vars1:SetCellValue(i-1, 0, k)
        UI.m_grid_GameInfo_Vars1:SetCellValue(i-1, 1, string.format('%.0f', v))
        UI.m_grid_GameInfo_Vars1:SetCellBackgroundColour(i-1, 0, wx.wxColour( 208, 208, 208 ) )
        UI.m_grid_GameInfo_Vars1:SetCellBackgroundColour(i-1, 1, wx.wxColour( 208, 208, 208 ) )
        i = i + 1
    end
    -- UI.m_grid_GameInfo_Flags1:AutoSizeColumns()
end

return P