local True = true
local False = false

if wx ~= nil then
    -- create GlobalMarket
    UI.GlobalMarket = wx.wxFrame (wx.NULL, wx.wxID_ANY, "Global Market", wx.wxDefaultPosition, wx.wxSize( 500,500 ), wx.wxDEFAULT_FRAME_STYLE+wx.wxTAB_TRAVERSAL )
	UI.GlobalMarket:SetSizeHints( wx.wxDefaultSize, wx.wxDefaultSize )
	UI.GlobalMarket :SetBackgroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_MENU ) )
	UI.GlobalMarket.m_mgr = wxaui.wxAuiManager()
	UI.GlobalMarket.m_mgr:SetManagedWindow( UI.GlobalMarket )

	UI.m_panel_GlobalMarket = wx.wxPanel( UI.GlobalMarket, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.GlobalMarket.m_mgr:AddPane( UI.m_panel_GlobalMarket, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):PinButton( True ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.bSizer_GlobalMarket_1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_choice_GlobalMarket_ResourceChoices = { "Chromite", "Aluminium", "Rubber", "Tungsten", "Nickel", "Copper", "Zinc", "Manganese", "Molybdenum" }
	UI.m_choice_GlobalMarket_Resource = wx.wxChoice( UI.m_panel_GlobalMarket, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,-1 ), UI.m_choice_GlobalMarket_ResourceChoices, 0 )
	UI.m_choice_GlobalMarket_Resource:SetSelection( 0 )
	UI.bSizer_GlobalMarket_1:Add( UI.m_choice_GlobalMarket_Resource, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_grid_GlobalMarket_1 = wx.wxGrid( UI.m_panel_GlobalMarket, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 450,200 ), 0 )

	-- Grid
	UI.m_grid_GlobalMarket_1:CreateGrid( 5, 5 )
	UI.m_grid_GlobalMarket_1:EnableEditing( False )
	UI.m_grid_GlobalMarket_1:EnableGridLines( True )
	UI.m_grid_GlobalMarket_1:EnableDragGridSize( False )
	UI.m_grid_GlobalMarket_1:SetMargins( 0, 0 )

	-- Columns
	UI.m_grid_GlobalMarket_1:SetColSize( 0, 70 )
	UI.m_grid_GlobalMarket_1:SetColSize( 1, 70 )
	UI.m_grid_GlobalMarket_1:SetColSize( 2, 70 )
	UI.m_grid_GlobalMarket_1:SetColSize( 3, 70 )
	UI.m_grid_GlobalMarket_1:SetColSize( 4, 145 )
	UI.m_grid_GlobalMarket_1:EnableDragColSize( True )
	UI.m_grid_GlobalMarket_1:SetColLabelValue( 0, "Country" )
	UI.m_grid_GlobalMarket_1:SetColLabelValue( 1, "Potential" )
	UI.m_grid_GlobalMarket_1:SetColLabelValue( 2, "Sales" )
	UI.m_grid_GlobalMarket_1:SetColLabelValue( 3, "Available" )
	UI.m_grid_GlobalMarket_1:SetColLabelValue( 4, "Next Expiry" )
	UI.m_grid_GlobalMarket_1:SetColLabelSize( 30 )
	UI.m_grid_GlobalMarket_1:SetColLabelAlignment( wx.wxALIGN_CENTER, wx.wxALIGN_CENTER )

	-- Rows
	UI.m_grid_GlobalMarket_1:EnableDragRowSize( False )
	UI.m_grid_GlobalMarket_1:SetRowLabelSize( 1 )
	UI.m_grid_GlobalMarket_1:SetRowLabelAlignment( wx.wxALIGN_LEFT, wx.wxALIGN_CENTER )

	-- Label Appearance
	UI.m_grid_GlobalMarket_1:SetLabelBackgroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_MENU ) )

	-- Cell Defaults
	UI.m_grid_GlobalMarket_1:SetDefaultCellBackgroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_MENU ) )
	UI.m_grid_GlobalMarket_1:SetDefaultCellAlignment( wx.wxALIGN_CENTER, wx.wxALIGN_TOP )
	UI.m_grid_GlobalMarket_1:SetMaxSize( wx.wxSize( 450,200 ) )

	UI.bSizer_GlobalMarket_1:Add( UI.m_grid_GlobalMarket_1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_GlobalMarket_Refresh = wx.wxButton( UI.m_panel_GlobalMarket, wx.wxID_ANY, "Refresh", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer_GlobalMarket_1:Add( UI.m_button_GlobalMarket_Refresh, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_GlobalMarket_1 = wx.wxStaticText( UI.m_panel_GlobalMarket, wx.wxID_ANY, "Trade decisions may be unavailable even if a country has resources available. This is because after each trade, a 2 day cooldown is applied, blocking the buy decision, in order to properly handle the trade.\nSimply wait and monitor your decisions.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText_GlobalMarket_1:Wrap( 300 )

	UI.bSizer_GlobalMarket_1:Add( UI.m_staticText_GlobalMarket_1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_panel_GlobalMarket:SetSizer( UI.bSizer_GlobalMarket_1 )
	UI.m_panel_GlobalMarket:Layout()
	UI.bSizer_GlobalMarket_1:Fit( UI.m_panel_GlobalMarket )

	UI.GlobalMarket .m_mgr:Update()
	UI.GlobalMarket:Centre( wx.wxBOTH )

    UI.GlobalMarket:Show(false)

    local function updateTable(content)
        UI.m_grid_GlobalMarket_1:ClearGrid()
        UI.m_grid_GlobalMarket_1:DeleteRows(0, UI.m_grid_GlobalMarket_1:GetNumberRows(), true )
        table.sort(content, function (k1, k2) return k1.potential > k2.potential end )
        local row = 0
        for i, values in ipairs(content) do
            UI.m_grid_GlobalMarket_1:AppendRows(1, true)
            -- tag
            UI.m_grid_GlobalMarket_1:SetCellValue(row, 0, values.tag)
            UI.m_grid_GlobalMarket_1:SetCellBackgroundColour( row, 0, wx.wxColour( 208, 208, 208 ) )
            -- potential
            UI.m_grid_GlobalMarket_1:SetCellValue(row, 1, tostring(values.potential))
            UI.m_grid_GlobalMarket_1:SetCellBackgroundColour( row, 1, wx.wxColour( 208, 208, 208 ) )
            -- sales
            UI.m_grid_GlobalMarket_1:SetCellValue(row, 2, tostring(values.sales))
            UI.m_grid_GlobalMarket_1:SetCellBackgroundColour( row, 2, wx.wxColour( 208, 208, 208 ) )
            -- available
            UI.m_grid_GlobalMarket_1:SetCellValue(row, 3, tostring(values.available))
            UI.m_grid_GlobalMarket_1:SetCellBackgroundColour( row, 3, wx.wxColour( 208, 208, 208 ) )
            -- next expiry
            UI.m_grid_GlobalMarket_1:SetCellValue(row, 4, values.nextExpiry .. " days")
            UI.m_grid_GlobalMarket_1:SetCellBackgroundColour( row, 4, wx.wxColour( 208, 208, 208 ) )
            row = row + 1
        end
    end

    local function findTrade(searchTag, searchResource)
        for tag, trades in pairs(GlobalTradesData) do
            for tradeName, trade in pairs(GlobalTradesData[tag]["trades"]) do
                if trade["seller"] == searchTag and trade["resource"] == searchResource then
                    return trade
                end
            end
        end
        return {expiryDate = 0}
    end

    function GlobalMarketGridUpdate()
        local selection = UI.m_choice_GlobalMarket_Resource:GetSelection()
        local resource = string.lower(UI.m_choice_GlobalMarket_Resource:GetString(selection))
        local result = {}
        local currentDate = CCurrentGameState.GetCurrentDate():GetTotalDays()
        for tag, countryTag in pairs(GetCountryIterCacheDict()) do
            local potential = countryTag:GetCountry():GetVariables():GetVariable(CString(resource .. "_building_balance")):Get() - 1000 -- includes puppets
            local sales = countryTag:GetCountry():GetVariables():GetVariable(CString(resource .. "_trade_sell")):Get()
            if potential > 0 then
                local x = {}
                x.tag = tag
                x.potential = potential
                x.sales = sales
                x.available = potential - sales
                if sales > 0 then
                    local oldestTrade = findTrade(tag, resource)
                    x.nextExpiry = string.format('%.0f', oldestTrade["expiryDate"] - currentDate)
                else
                    x.nextExpiry = "-1"
                end
                table.insert(result, x)
            end
        end
        updateTable(result)
    end

    UI.m_button_GlobalMarket_Refresh:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        GlobalMarketGridUpdate()
    end )

	UI.m_choice_GlobalMarket_Resource:Connect( wx.wxEVT_COMMAND_CHOICE_SELECTED, function(event)
        GlobalMarketGridUpdate()
	end )

end