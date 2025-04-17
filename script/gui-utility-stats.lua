require("wx")

local True = true
local False = false

if wx ~= nil then
	UI.MyFrame5 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "Hoi3 Utility Statistics", wx.wxDefaultPosition, wx.wxSize( 500,500 ), wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxMAXIMIZE_BOX + wx.wxMINIMIZE_BOX + wx.wxRESIZE_BORDER + wx.wxSYSTEM_MENU+wx.wxTAB_TRAVERSAL )
	UI.MyFrame5:SetSizeHints( wx.wxSize( 500,500 ), wx.wxDefaultSize )
	UI.MyFrame5.m_mgr = wxaui.wxAuiManager()
	UI.MyFrame5.m_mgr:SetManagedWindow( UI.MyFrame5 )

	UI.m_notebook_Statistics = wx.wxNotebook( UI.MyFrame5, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxNB_MULTILINE )
	UI.MyFrame5.m_mgr:AddPane( UI.m_notebook_Statistics, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):CloseButton( False ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.m_panel_Statistics_setup = wx.wxPanel( UI.m_notebook_Statistics, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_Statistics_setup1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText_Statistics_setup2 = wx.wxStaticText( UI.m_panel_Statistics_setup, wx.wxID_ANY, "Here you can enable the collection of statistics.\nTo find out which values will be collected check the \"Statistics\" page.\nThis feature is intended for development purposes, as the stat collection will slow down the game, especially when not limiting it to a custom country list.\n\nOnce activated quite a few command prompts will open for a split second in the next days. They are needed to set up folders and such.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText_Statistics_setup2:Wrap( 410 )

	UI.bSizer_Statistics_setup1:Add( UI.m_staticText_Statistics_setup2, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer_Statistics_setup1 = wx.wxGridSizer( 2, 2, 0, 0 )

	UI.m_button_Statistics_setup_toggle = wx.wxButton( UI.m_panel_Statistics_setup, wx.wxID_ANY, "Toggle stat collection", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Statistics_setup1:Add( UI.m_button_Statistics_setup_toggle, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_Statistics_setup_toggle = wx.wxTextCtrl( UI.m_panel_Statistics_setup, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_Statistics_setup_toggle:Enable( False )

	UI.gSizer_Statistics_setup1:Add( UI.m_textCtrl_Statistics_setup_toggle, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_Statistics_setup_toggle_custom_list = wx.wxButton( UI.m_panel_Statistics_setup, wx.wxID_ANY, "Toggle custom list", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Statistics_setup1:Add( UI.m_button_Statistics_setup_toggle_custom_list, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_Statistics_setup_toggle_custom_list = wx.wxTextCtrl( UI.m_panel_Statistics_setup, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_Statistics_setup_toggle_custom_list:Enable( False )

	UI.gSizer_Statistics_setup1:Add( UI.m_textCtrl_Statistics_setup_toggle_custom_list, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_Statistics_setup1:Add( UI.gSizer_Statistics_setup1, 0, wx.wxEXPAND, 5 )

	UI.gSizer_Statistics_setup2 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.gSizer_Statistics_setup3 = wx.wxGridSizer( 2, 1, 0, 0 )

	UI.m_comboBox_Statistics_setup1Choices = {}
	UI.m_comboBox_Statistics_setup1 = wx.wxComboBox( UI.m_panel_Statistics_setup, wx.wxID_ANY, "Enter/select TAG", wx.wxDefaultPosition, wx.wxDefaultSize, UI.m_comboBox_Statistics_setup1Choices, 0 )
	UI.gSizer_Statistics_setup3:Add( UI.m_comboBox_Statistics_setup1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer_Statistics_setup4 = wx.wxGridSizer( 0, 2, 0, 0 )

	UI.m_button_Statistics_setup_add = wx.wxButton( UI.m_panel_Statistics_setup, wx.wxID_ANY, "Add", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Statistics_setup4:Add( UI.m_button_Statistics_setup_add, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_Statistics_setup_remove = wx.wxButton( UI.m_panel_Statistics_setup, wx.wxID_ANY, "Remove", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Statistics_setup4:Add( UI.m_button_Statistics_setup_remove, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer_Statistics_setup3:Add( UI.gSizer_Statistics_setup4, 1, wx.wxEXPAND, 5 )


	UI.gSizer_Statistics_setup2:Add( UI.gSizer_Statistics_setup3, 1, wx.wxEXPAND, 5 )

	UI.fgSizer_Statistics_setup1 = wx.wxFlexGridSizer( 2, 1, 0, 0 )
	UI.fgSizer_Statistics_setup1:AddGrowableCol( 0 )
	UI.fgSizer_Statistics_setup1:AddGrowableRow( 1 )
	UI.fgSizer_Statistics_setup1:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_Statistics_setup1:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_Statistics_setup3 = wx.wxStaticText( UI.m_panel_Statistics_setup, wx.wxID_ANY, "Country list", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_Statistics_setup3:Wrap( -1 )

	UI.fgSizer_Statistics_setup1:Add( UI.m_staticText_Statistics_setup3, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_listBox_Statistics_country_listChoices = {}
	UI.m_listBox_Statistics_country_list = wx.wxListBox( UI.m_panel_Statistics_setup, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,-1 ), UI.m_listBox_Statistics_country_listChoices, wx.wxLB_ALWAYS_SB )
	UI.m_listBox_Statistics_country_list:SetMinSize( wx.wxSize( 100,150 ) )

	UI.fgSizer_Statistics_setup1:Add( UI.m_listBox_Statistics_country_list, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 2 )


	UI.gSizer_Statistics_setup2:Add( UI.fgSizer_Statistics_setup1, 1, wx.wxEXPAND, 5 )


	UI.bSizer_Statistics_setup1:Add( UI.gSizer_Statistics_setup2, 1, wx.wxEXPAND, 5 )

	UI.m_staticText_Statistics_setup1 = wx.wxStaticText( UI.m_panel_Statistics_setup, wx.wxID_ANY, "Ident:", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_Statistics_setup1:Wrap( -1 )

	UI.bSizer_Statistics_setup1:Add( UI.m_staticText_Statistics_setup1, 0, wx.wxALIGN_CENTER + wx.wxALL, 0 )

	UI.m_textCtrl_Statistics_setup_ident = wx.wxTextCtrl( UI.m_panel_Statistics_setup, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_Statistics_setup_ident:Enable( False )

	UI.bSizer_Statistics_setup1:Add( UI.m_textCtrl_Statistics_setup_ident, 0, wx.wxALIGN_CENTER + wx.wxALL, 10 )


	UI.m_panel_Statistics_setup:SetSizer( UI.bSizer_Statistics_setup1 )
	UI.m_panel_Statistics_setup:Layout()
	UI.bSizer_Statistics_setup1:Fit( UI.m_panel_Statistics_setup )
	UI.m_notebook_Statistics:AddPage(UI.m_panel_Statistics_setup, "Setup", False )
	UI.m_panel_Statistics_main = wx.wxPanel( UI.m_notebook_Statistics, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_Statistics_main1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText_Statistics_main2 = wx.wxStaticText( UI.m_panel_Statistics_main, wx.wxID_ANY, "Select countries and stats for which to show the statistic", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_Statistics_main2:Wrap( -1 )

	UI.bSizer_Statistics_main1:Add( UI.m_staticText_Statistics_main2, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer_Statistics_main1 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.gSizer_Statistics_main2 = wx.wxGridSizer( 2, 1, 0, 0 )

	UI.m_comboBox_Statistics_main1Choices = {}
	UI.m_comboBox_Statistics_main1 = wx.wxComboBox( UI.m_panel_Statistics_main, wx.wxID_ANY, "Enter/select TAG", wx.wxDefaultPosition, wx.wxDefaultSize, UI.m_comboBox_Statistics_main1Choices, 0 )
	UI.gSizer_Statistics_main2:Add( UI.m_comboBox_Statistics_main1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer_Statistics_main4 = wx.wxGridSizer( 0, 2, 0, 0 )

	UI.m_button_Statistics_main_add = wx.wxButton( UI.m_panel_Statistics_main, wx.wxID_ANY, "Add", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Statistics_main4:Add( UI.m_button_Statistics_main_add, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_Statistics_main_remove = wx.wxButton( UI.m_panel_Statistics_main, wx.wxID_ANY, "Remove", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Statistics_main4:Add( UI.m_button_Statistics_main_remove, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer_Statistics_main2:Add( UI.gSizer_Statistics_main4, 1, wx.wxEXPAND, 5 )


	UI.gSizer_Statistics_main1:Add( UI.gSizer_Statistics_main2, 1, wx.wxEXPAND, 5 )

	UI.m_listBox_Statistics_main_countriesChoices = {}
	UI.m_listBox_Statistics_main_countries = wx.wxListBox( UI.m_panel_Statistics_main, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,-1 ), UI.m_listBox_Statistics_main_countriesChoices, wx.wxLB_ALWAYS_SB )
	UI.m_listBox_Statistics_main_countries:SetMinSize( wx.wxSize( 100,95 ) )

	UI.gSizer_Statistics_main1:Add( UI.m_listBox_Statistics_main_countries, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )


	UI.bSizer_Statistics_main1:Add( UI.gSizer_Statistics_main1, 1, wx.wxEXPAND, 5 )

	UI.gSizer_Statistics_main5 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_listBox_Statistics_main_statsChoices = {}
	UI.m_listBox_Statistics_main_stats = wx.wxListBox( UI.m_panel_Statistics_main, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, UI.m_listBox_Statistics_main_statsChoices, wx.wxLB_ALWAYS_SB + wx.wxLB_MULTIPLE )
	UI.gSizer_Statistics_main5:Add( UI.m_listBox_Statistics_main_stats, 0, wx.wxALL + wx.wxEXPAND, 5 )

	UI.gSizer_Statistics_main6 = wx.wxGridSizer( 4, 1, 0, 0 )


	UI.gSizer_Statistics_main6:Add( 0, 0, 1, wx.wxEXPAND, 5 )

	UI.m_button_Statistics_main_plot = wx.wxButton( UI.m_panel_Statistics_main, wx.wxID_ANY, "Show graph", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Statistics_main6:Add( UI.m_button_Statistics_main_plot, 0, wx.wxALIGN_BOTTOM + wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticText_Statistics_main3 = wx.wxStaticText( UI.m_panel_Statistics_main, wx.wxID_ANY, "This will take a few seconds.\nTooltip can be removed by right-clicking.\nYou can select multiple stats. If no data exists for a stat it will not appear in the graph.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText_Statistics_main3:Wrap( 240 )

	UI.gSizer_Statistics_main6:Add( UI.m_staticText_Statistics_main3, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALIGN_TOP + wx.wxALL, 5 )


	UI.gSizer_Statistics_main6:Add( 0, 0, 1, wx.wxEXPAND, 5 )


	UI.gSizer_Statistics_main5:Add( UI.gSizer_Statistics_main6, 1, wx.wxEXPAND, 5 )


	UI.bSizer_Statistics_main1:Add( UI.gSizer_Statistics_main5, 3, wx.wxEXPAND, 5 )


	UI.m_panel_Statistics_main:SetSizer( UI.bSizer_Statistics_main1 )
	UI.m_panel_Statistics_main:Layout()
	UI.bSizer_Statistics_main1:Fit( UI.m_panel_Statistics_main )
	UI.m_notebook_Statistics:AddPage(UI.m_panel_Statistics_main, "Statistics", False )




	UI.MyFrame5 .m_mgr:Update()
	UI.MyFrame5:Centre( wx.wxBOTH )


    local statChoices = {
        'intel_DomesticSpies', 'intel_FreeSpies', 'ls_Percent_Diplomacy', 'ls_Percent_Espionage', 'ls_Percent_NCO', 'ls_Percent_Research',
        'pol_Popularity_fascistic', 'pol_Popularity_Group_communism', 'pol_Popularity_Group_democracy', 'pol_Popularity_Group_fascism',
        'pol_Popularity_Group_noIdeologygroup', 'pol_Popularity_left_wing_radical', 'pol_Popularity_leninist', 'pol_Popularity_market_liberal',
        'pol_Popularity_national_socialist', 'pol_Popularity_noIdeology', 'pol_Popularity_paternal_autocrat', 'pol_Popularity_social_conservative',
        'pol_Popularity_social_democrat', 'pol_Popularity_social_liberal', 'pol_Popularity_stalinist', 'prod__TotalIc', 'prod__IcEff', 'ls_TotalLeadership',
        'intel_TotalSpiesAbroad', 'diplo_Neutrality', 'diplo_EffectiveNeutrality', 'prod_Consumer_%', 'prod_Consumer_IC', 'prod_LendLease_%',
		'prod_LendLease_IC', 'prod_Production_%', 'prod_Production_IC', 'prod_Reinforce_%', 'prod_Reinforce_IC', 'prod_Supply_%', 'prod_Supply_IC',
		'prod_Upgrade_%', 'prod_Upgrade_IC', 'pool_energy', 'pool_metals', 'pool_rares', 'pool_oil', 'pool_supplies', 'pool_fuel', 'pool_money',
		'other_u_LandCountTotal', 'other_u_AirCountTotal', 'other_u_NavalCountTotal', 'other_u_TotalDivisions',
		'other_ManpowerTotal'
    }
    table.sort(statChoices)
    UI.m_listBox_Statistics_main_stats:Clear()
    UI.m_listBox_Statistics_main_stats:Append(statChoices)
	-- Connect Events

	UI.m_button_Statistics_setup_toggle:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        Stats.ToggleStatCollection()
	end )

	UI.m_button_Statistics_setup_toggle_custom_list:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        Stats.ToggleStatCollectionCustomList()
		if Stats.CustomCountryListActive == true then
			Stats.UpdateCustomCountryListInStatSelection()
		end
	end )

	UI.m_button_Statistics_setup_add:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        local tag = UI.m_comboBox_Statistics_setup1:GetValue()
        -- Utils.LUA_DEBUGOUT(tag)
        if tag ~= "" then
			tag = string.upper(tag)
            UI.m_listBox_Statistics_country_list:Append(tag)
			local omgTag = CCountryDataBase.GetTag("OMG")
			local command = CSetVariableCommand(omgTag, CString("zStatsCustomList_" .. tag), CFixedPoint(1))
			CCurrentGameState.Post(command)

			if Stats.CustomCountryListActive == true then
				Stats.UpdateCustomCountryListInStatSelection()
			end
        end
	end )

	UI.m_button_Statistics_setup_remove:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        local selection = UI.m_listBox_Statistics_country_list:GetSelection()
        -- Utils.LUA_DEBUGOUT(selection)
        if selection ~= nil then
			local tag = UI.m_listBox_Statistics_country_list:GetString(selection)
			local omgTag = CCountryDataBase.GetTag("OMG")
			local command = CSetVariableCommand(omgTag, CString("zStatsCustomList_" .. tag), CFixedPoint(0))
			CCurrentGameState.Post(command)
            UI.m_listBox_Statistics_country_list:Delete(selection)

			if Stats.CustomCountryListActive == true then
				Stats.UpdateCustomCountryListInStatSelection()
			end
        end
	end )

	UI.m_button_Statistics_main_add:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        local tag = UI.m_comboBox_Statistics_main1:GetValue()
        -- Utils.LUA_DEBUGOUT(tag)
        if tag ~= "" then
			tag = string.upper(tag)
            UI.m_listBox_Statistics_main_countries:Append(tag)
        end
	end )

	UI.m_button_Statistics_main_remove:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        local selection = UI.m_listBox_Statistics_main_countries:GetSelection()
        -- Utils.LUA_DEBUGOUT(selection)
        if selection ~= nil then
            UI.m_listBox_Statistics_main_countries:Delete(selection)
        end
    end )

	UI.m_button_Statistics_main_plot:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		local statsSelected = UI.m_listBox_Statistics_main_stats:GetSelections()
		-- Utils.LUA_DEBUGOUT(statsSelected)
		local statsString = ""
		local added = 0
		for i = 0, #statChoices do
			if UI.m_listBox_Statistics_main_stats:IsSelected(i) then
				statsString = statsString .. UI.m_listBox_Statistics_main_stats:GetString(i) .. ","
				added = added + 1
			end
			if added >= statsSelected then
				i = #statChoices
			end
		end
		local tags = UI.m_listBox_Statistics_main_countries:GetCount()
		-- Utils.LUA_DEBUGOUT(tags)
		local tagsString = ""
		for i = 0, tags - 1 do
			tagsString = tagsString .. UI.m_listBox_Statistics_main_countries:GetString(i) .. ","
		end
		Stats.StatsIdent = Stats.GetCurrentIdent()
		-- Utils.LUA_DEBUGOUT(statsString)
		-- Utils.LUA_DEBUGOUT(tagsString)
		if statsSelected >= 1 and tags >= 1 then
			local command = 'start "" "tfh\\mod\\BlackICE ' .. G_MOD_VERSION ..'\\stats\\visualizeStatisticCLI.exe" ' ..
							G_MOD_VERSION .. ' ' .. Stats.StatsIdent .. ' ' .. tagsString .. ' ' .. statsString
			-- Utils.LUA_DEBUGOUT(command)
			os.execute(command)
		end
	end )
end