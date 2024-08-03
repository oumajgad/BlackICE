local P = {}

function P.FillGrid()
    if G_PlayerCountry == nil then
        return
    end

    local flags = BiceLib.getCountryFlags(G_PlayerCountry)

    if flags == nil then
        Utils.LUA_DEBUGOUT("flags nil")
        return
    end

    -- Utils.INSPECT_TABLE(flags)

    UI.m_grid_GameInfo_Flags1:ClearGrid()
    UI.m_grid_GameInfo_Flags1:DeleteRows(0, UI.m_grid_GameInfo_Flags1:GetNumberRows(), true )
    for i, flag in ipairs(flags) do
        -- Utils.LUA_DEBUGOUT(flag)
        UI.m_grid_GameInfo_Flags1:AppendRows(1, true)
        UI.m_grid_GameInfo_Flags1:SetCellValue(i-1, 0, flag)
        UI.m_grid_GameInfo_Flags1:SetCellBackgroundColour(i-1, 0, wx.wxColour( 208, 208, 208 ) )
    end
    -- UI.m_grid_GameInfo_Flags1:AutoSizeColumns()
end

return P