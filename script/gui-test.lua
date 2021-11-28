
package.cpath = package.cpath..";./tfh/mod/?.dll;"
require("wx")


UI = {}

if wx ~= nil then


	UI.MyFrame1 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "Hoi3 Utility", wx.wxDefaultPosition, wx.wxSize( 500,500 ), wx.wxCAPTION + wx.wxMAXIMIZE_BOX + wx.wxMINIMIZE_BOX + wx.wxRESIZE_BORDER + wx.wxSYSTEM_MENU+wx.wxTAB_TRAVERSAL, "Hoi3 Utility" )
	UI.MyFrame1:SetSizeHints( wx.wxSize( 500,500 ), wx.wxDefaultSize )
	UI.MyFrame1.m_mgr = wxaui.wxAuiManager()
	UI.MyFrame1.m_mgr:SetManagedWindow( UI.MyFrame1 )

	UI.m_notebook4 = wx.wxNotebook( UI.MyFrame1, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,100 ), 0 )
	UI.MyFrame1.m_mgr:AddPane( UI.m_notebook4, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):CloseButton( False ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.m_panel_Setup = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( -1,-1 ), wx.wxTAB_TRAVERSAL )
	UI.bSizer2 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText41 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "1. Load a save.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText41:Wrap( -1 )

	UI.bSizer2:Add( UI.m_staticText41, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxTOP, 5 )

	UI.m_staticText5 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "2. Let time start running.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText5:Wrap( -1 )

	UI.bSizer2:Add( UI.m_staticText5, 0, wx.wxALIGN_CENTER_HORIZONTAL, 5 )

	UI.m_staticText10 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "3. Wait for the text to say \"Save loaded\"", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText10:Wrap( -1 )

	UI.bSizer2:Add( UI.m_staticText10, 0, wx.wxALIGN_CENTER_HORIZONTAL, 5 )

	UI.m_staticText61 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "4. Select your country and set it.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText61:Wrap( -1 )

	UI.bSizer2:Add( UI.m_staticText61, 0, wx.wxALIGN_CENTER_HORIZONTAL, 5 )

	UI.m_textCtrl3 = wx.wxTextCtrl( UI.m_panel_Setup, wx.wxID_ANY, "Setting up...", wx.wxDefaultPosition, wx.wxSize( 130,-1 ), 0 )
	UI.m_textCtrl3:Enable( False )

	UI.bSizer2:Add( UI.m_textCtrl3, 0, wx.wxALIGN_CENTER + wx.wxALL, 10 )

	UI.set_player_button = wx.wxButton( UI.m_panel_Setup, wx.wxID_ANY, "Set Player", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.set_player_button:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizer2:Add( UI.set_player_button, 0, wx.wxALIGN_CENTER + wx.wxALL, 10 )

	UI.player_choiceChoices = {}
	UI.player_choice = wx.wxChoice( UI.m_panel_Setup, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, UI.player_choiceChoices, 0 )
	UI.player_choice:SetSelection( 0 )
	UI.bSizer2:Add( UI.player_choice, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticText7 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "This tool can be used in multiplayer, however only the host can select countries and make changes.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText7:Wrap( 400 )

	UI.m_staticText7:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizer2:Add( UI.m_staticText7, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.gSizer31 = wx.wxGridSizer( 0, 4, 0, 0 )

	UI.m_staticText11 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "Refresh every", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText11:Wrap( -1 )

	UI.gSizer31:Add( UI.m_staticText11, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl6 = wx.wxTextCtrl( UI.m_panel_Setup, wx.wxID_ANY, "1", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl6:SetMinSize( wx.wxSize( 20,-1 ) )

	UI.gSizer31:Add( UI.m_textCtrl6, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText12 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "days.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText12:Wrap( -1 )

	UI.gSizer31:Add( UI.m_staticText12, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.set_Interval_Button = wx.wxButton( UI.m_panel_Setup, wx.wxID_ANY, "Set Interval", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer31:Add( UI.set_Interval_Button, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer2:Add( UI.gSizer31, 1, wx.wxEXPAND, 5 )


	UI.m_panel_Setup:SetSizer( UI.bSizer2 )
	UI.m_panel_Setup:Layout()
	UI.bSizer2:Fit( UI.m_panel_Setup )
	UI.m_notebook4:AddPage(UI.m_panel_Setup, "Setup", True )
	UI.m_panel_C_Info = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.gSizer2 = wx.wxGridSizer( 4, 2, 0, 0 )

	UI.m_staticText8 = wx.wxStaticText( UI.m_panel_C_Info, wx.wxID_ANY, "IC Efficiency", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText8:Wrap( -1 )

	UI.gSizer2:Add( UI.m_staticText8, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_IcEff = wx.wxTextCtrl( UI.m_panel_C_Info, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_IcEff:Enable( False )

	UI.gSizer2:Add( UI.m_textCtrl_IcEff, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText9 = wx.wxStaticText( UI.m_panel_C_Info, wx.wxID_ANY, "Research Efficiency", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText9:Wrap( -1 )

	UI.gSizer2:Add( UI.m_staticText9, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_ResEff = wx.wxTextCtrl( UI.m_panel_C_Info, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_ResEff:Enable( False )

	UI.gSizer2:Add( UI.m_textCtrl_ResEff, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText13 = wx.wxStaticText( UI.m_panel_C_Info, wx.wxID_ANY, "Supply throughput", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText13:Wrap( -1 )

	UI.gSizer2:Add( UI.m_staticText13, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_SupplyThr = wx.wxTextCtrl( UI.m_panel_C_Info, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_SupplyThr:Enable( False )

	UI.gSizer2:Add( UI.m_textCtrl_SupplyThr, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText14 = wx.wxStaticText( UI.m_panel_C_Info, wx.wxID_ANY, "Supply consumption", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText14:Wrap( -1 )

	UI.gSizer2:Add( UI.m_staticText14, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_SupplyCons = wx.wxTextCtrl( UI.m_panel_C_Info, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_SupplyCons:Enable( False )

	UI.gSizer2:Add( UI.m_textCtrl_SupplyCons, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_panel_C_Info:SetSizer( UI.gSizer2 )
	UI.m_panel_C_Info:Layout()
	UI.gSizer2:Fit( UI.m_panel_C_Info )
	UI.m_notebook4:AddPage(UI.m_panel_C_Info, "Country Info", False )
	UI.m_panel_Puppets = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.gSizer3 = wx.wxGridSizer( 5, 3, 0, 0 )

	UI.m_staticText3 = wx.wxStaticText( UI.m_panel_Puppets, wx.wxID_ANY, "Select a Puppet", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText3:Wrap( -1 )

	UI.gSizer3:Add( UI.m_staticText3, 0, wx.wxALIGN_CENTER, 5 )

	UI.puppet_choiceChoices = {}
	UI.puppet_choice = wx.wxChoice( UI.m_panel_Puppets, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, UI.puppet_choiceChoices, 0 )
	UI.puppet_choice:SetSelection( 0 )
	UI.gSizer3:Add( UI.puppet_choice, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.button_set_puppet = wx.wxButton( UI.m_panel_Puppets, wx.wxID_ANY, "Set Puppet", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer3:Add( UI.button_set_puppet, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText4 = wx.wxStaticText( UI.m_panel_Puppets, wx.wxID_ANY, "Selected Puppet", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText4:Wrap( -1 )

	UI.gSizer3:Add( UI.m_staticText4, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.set_puppet_text = wx.wxTextCtrl( UI.m_panel_Puppets, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.set_puppet_text:Enable( False )

	UI.gSizer3:Add( UI.set_puppet_text, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_textCtrl4 = wx.wxTextCtrl( UI.m_panel_Puppets, wx.wxID_ANY, "Current Focus", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl4:Enable( False )

	UI.gSizer3:Add( UI.m_textCtrl4, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticText6 = wx.wxStaticText( UI.m_panel_Puppets, wx.wxID_ANY, "Select a Focus", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText6:Wrap( -1 )

	UI.gSizer3:Add( UI.m_staticText6, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.puppet_focus_choiceChoices = { "Rares", "Energy", "Metal", "Navy", "Air", "Army", "Oil", "None" }
	UI.puppet_focus_choice = wx.wxChoice( UI.m_panel_Puppets, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, UI.puppet_focus_choiceChoices, 0 )
	UI.puppet_focus_choice:SetSelection( 0 )
	UI.gSizer3:Add( UI.puppet_focus_choice, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.puppet_set_focus = wx.wxButton( UI.m_panel_Puppets, wx.wxID_ANY, "Set Focus", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer3:Add( UI.puppet_set_focus, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticText16 = wx.wxStaticText( UI.m_panel_Puppets, wx.wxID_ANY, "Ingame decision", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText16:Wrap( -1 )

	UI.gSizer3:Add( UI.m_staticText16, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonEnablePuppetDecision = wx.wxButton( UI.m_panel_Puppets, wx.wxID_ANY, "Enable", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer3:Add( UI.m_buttonEnablePuppetDecision, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonDisablePuppetDecision = wx.wxButton( UI.m_panel_Puppets, wx.wxID_ANY, "Disable", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer3:Add( UI.m_buttonDisablePuppetDecision, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_panel_Puppets:SetSizer( UI.gSizer3 )
	UI.m_panel_Puppets:Layout()
	UI.gSizer3:Fit( UI.m_panel_Puppets )
	UI.m_notebook4:AddPage(UI.m_panel_Puppets, "Puppets", False )
	UI.m_panel_Misc = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.gSizer4 = wx.wxGridSizer( 1, 4, 0, 0 )

	UI.m_staticText15 = wx.wxStaticText( UI.m_panel_Misc, wx.wxID_ANY, "Daily building and resource counts.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText15:Wrap( 100 )

	UI.gSizer4:Add( UI.m_staticText15, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlDailyCount = wx.wxTextCtrl( UI.m_panel_Misc, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( -1,-1 ), 0 )
	UI.m_textCtrlDailyCount:Enable( False )

	UI.gSizer4:Add( UI.m_textCtrlDailyCount, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonDailyOn = wx.wxButton( UI.m_panel_Misc, wx.wxID_ANY, "On", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer4:Add( UI.m_buttonDailyOn, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonDailyOff = wx.wxButton( UI.m_panel_Misc, wx.wxID_ANY, "Off", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer4:Add( UI.m_buttonDailyOff, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_panel_Misc:SetSizer( UI.gSizer4 )
	UI.m_panel_Misc:Layout()
	UI.gSizer4:Fit( UI.m_panel_Misc )
	UI.m_notebook4:AddPage(UI.m_panel_Misc, "Misc", False )

	UI.MyFrame1 .m_mgr:Update()
	UI.MyFrame1:Centre( wx.wxBOTH )

	-- Connect Events

	UI.set_player_button:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		if UI.player_choice:GetSelection() >= 0 then
			PlayerCountry = UI.player_choice:GetString(UI.player_choice:GetSelection())
			UI.m_textCtrl3:SetValue("Country set to " .. PlayerCountry)
		else
			UI.m_textCtrl3:SetValue("No country selected")
		end
	end )

	UI.m_buttonEnablePuppetDecision:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		TogglePuppetFocusDecision(true)
	end )

	UI.m_buttonDisablePuppetDecision:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		TogglePuppetFocusDecision(false)
	end )

	UI.set_Interval_Button:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		UpdateInterval = tonumber(UI.m_textCtrl6:GetValue())
	end )

	UI.button_set_puppet:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		SetPuppetSelection()
	end )

	UI.puppet_set_focus:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		SetPuppetFocus()
	end )

	UI.m_buttonDailyOn:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		DateOverride = true
		UpdateDailyCountsTextCtrl()
	end )

	UI.m_buttonDailyOff:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		DateOverride = false
		UpdateDailyCountsTextCtrl()
	end )

	UI.MyFrame1:Show(true)

end