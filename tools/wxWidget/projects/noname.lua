----------------------------------------------------------------------------
-- Lua code generated with wxFormBuilder (version 3.10.1-0-g8feb16b3)
-- http://www.wxformbuilder.org/
----------------------------------------------------------------------------

-- Load the wxLua module, does nothing if running from wxLua, wxLuaFreeze, or wxLuaEdit
package.cpath = package.cpath..";./?.dll;./?.so;../lib/?.so;../lib/vc_dll/?.dll;../lib/bcc_dll/?.dll;../lib/mingw_dll/?.dll;"
require("wx")

UI = {}


-- create MyFrame1
UI.MyFrame1 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "Hoi3 Utility", wx.wxDefaultPosition, wx.wxSize( 550,550 ), wx.wxCAPTION + wx.wxMAXIMIZE_BOX + wx.wxMINIMIZE_BOX + wx.wxRESIZE_BORDER + wx.wxSYSTEM_MENU+wx.wxTAB_TRAVERSAL, "Hoi3 Utility" )
	UI.MyFrame1:SetSizeHints( wx.wxSize( 550,550 ), wx.wxDefaultSize )
	UI.MyFrame1.m_mgr = wxaui.wxAuiManager()
	UI.MyFrame1.m_mgr:SetManagedWindow( UI.MyFrame1 )

	UI.m_notebook4 = wx.wxNotebook( UI.MyFrame1, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,100 ), wx.wxNB_MULTILINE )
	UI.MyFrame1.m_mgr:AddPane( UI.m_notebook4, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):CloseButton( False ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.m_panel_Setup = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( -1,-1 ), wx.wxTAB_TRAVERSAL )
	UI.bSizer2 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText41 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "1. Start a game.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText41:Wrap( -1 )

	UI.bSizer2:Add( UI.m_staticText41, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxTOP, 5 )

	UI.m_staticText5 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "2. Press the \"Get players\" button.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText5:Wrap( -1 )

	UI.bSizer2:Add( UI.m_staticText5, 0, wx.wxALIGN_CENTER_HORIZONTAL, 5 )

	UI.m_staticText61 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "3. Select your country and set it.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText61:Wrap( -1 )

	UI.bSizer2:Add( UI.m_staticText61, 0, wx.wxALIGN_CENTER_HORIZONTAL, 5 )

	UI.m_textCtrl3 = wx.wxTextCtrl( UI.m_panel_Setup, wx.wxID_ANY, "Setting up...", wx.wxDefaultPosition, wx.wxSize( 130,-1 ), 0 )
	UI.m_textCtrl3:Enable( False )

	UI.bSizer2:Add( UI.m_textCtrl3, 0, wx.wxALIGN_CENTER + wx.wxALL, 10 )

	UI.set_player_button = wx.wxButton( UI.m_panel_Setup, wx.wxID_ANY, "Set Player", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.set_player_button:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizer2:Add( UI.set_player_button, 0, wx.wxALIGN_CENTER + wx.wxALL, 10 )

	UI.player_choiceChoices = {}
	UI.player_choice = wx.wxComboBox( UI.m_panel_Setup, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, UI.player_choiceChoices, 0 )
	UI.bSizer2:Add( UI.player_choice, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_button_GetPlayers = wx.wxButton( UI.m_panel_Setup, wx.wxID_ANY, "Get players", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer2:Add( UI.m_button_GetPlayers, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText7 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "This tool can be used in multiplayer, however the automatic refreshing of values does only work for the host.\nNon-hosts have to manually refresh them using the \"Refresh values\" button.\nAll actions from the utility can also be found in the covert ops menu of your capital province, you can also disable the hosts access to your country there.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText7:Wrap( 405 )

	UI.m_staticText7:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizer2:Add( UI.m_staticText7, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_button_manualRefresh = wx.wxButton( UI.m_panel_Setup, wx.wxID_ANY, "Refresh values", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer2:Add( UI.m_button_manualRefresh, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer31 = wx.wxGridSizer( 0, 4, 0, 0 )

	UI.m_staticText11 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "Refresh every", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText11:Wrap( -1 )

	UI.gSizer31:Add( UI.m_staticText11, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl6 = wx.wxTextCtrl( UI.m_panel_Setup, wx.wxID_ANY, "3", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl6:SetMinSize( wx.wxSize( 25,-1 ) )

	UI.gSizer31:Add( UI.m_textCtrl6, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText12 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "days.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText12:Wrap( -1 )

	UI.gSizer31:Add( UI.m_staticText12, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.set_Interval_Button = wx.wxButton( UI.m_panel_Setup, wx.wxID_ANY, "Set Interval", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer31:Add( UI.set_Interval_Button, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer2:Add( UI.gSizer31, 1, wx.wxEXPAND, 5 )

	UI.gSizer_Setup38 = wx.wxGridSizer( 1, 4, 0, 0 )

	UI.m_button_ShowHelpWindow = wx.wxButton( UI.m_panel_Setup, wx.wxID_ANY, "Help window", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_button_ShowHelpWindow:SetToolTip( "A window with useful information about the mod and game" )

	UI.gSizer_Setup38:Add( UI.m_button_ShowHelpWindow, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_ShowOptionsWindow = wx.wxButton( UI.m_panel_Setup, wx.wxID_ANY, "Options window", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Setup38:Add( UI.m_button_ShowOptionsWindow, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_ShowStatsWindow = wx.wxButton( UI.m_panel_Setup, wx.wxID_ANY, "Stats window", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Setup38:Add( UI.m_button_ShowStatsWindow, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_ShowGameInfoWindow = wx.wxButton( UI.m_panel_Setup, wx.wxID_ANY, "Game infos", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Setup38:Add( UI.m_button_ShowGameInfoWindow, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer2:Add( UI.gSizer_Setup38, 1, wx.wxEXPAND, 5 )


	UI.m_panel_Setup:SetSizer( UI.bSizer2 )
	UI.m_panel_Setup:Layout()
	UI.bSizer2:Fit( UI.m_panel_Setup )
	UI.m_notebook4:AddPage(UI.m_panel_Setup, "Setup", True )
	UI.m_panel_C_Info = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.gSizer2 = wx.wxGridSizer( 4, 4, 0, 0 )

	UI.m_staticText_cInfo_baseIc = wx.wxStaticText( UI.m_panel_C_Info, wx.wxID_ANY, "Base IC", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_cInfo_baseIc:Wrap( -1 )

	UI.gSizer2:Add( UI.m_staticText_cInfo_baseIc, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_baseIc = wx.wxTextCtrl( UI.m_panel_C_Info, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_baseIc:Enable( False )

	UI.gSizer2:Add( UI.m_textCtrl_baseIc, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_cInfo_offmapIc = wx.wxStaticText( UI.m_panel_C_Info, wx.wxID_ANY, "Offmap IC", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_cInfo_offmapIc:Wrap( -1 )

	UI.gSizer2:Add( UI.m_staticText_cInfo_offmapIc, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_offmapIc = wx.wxTextCtrl( UI.m_panel_C_Info, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_offmapIc:Enable( False )

	UI.gSizer2:Add( UI.m_textCtrl_offmapIc, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_cInfo_icModifier = wx.wxStaticText( UI.m_panel_C_Info, wx.wxID_ANY, "IC Modifier", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_cInfo_icModifier:Wrap( -1 )

	UI.gSizer2:Add( UI.m_staticText_cInfo_icModifier, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_icModifier = wx.wxTextCtrl( UI.m_panel_C_Info, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_icModifier:Enable( False )

	UI.gSizer2:Add( UI.m_textCtrl_icModifier, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

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

	UI.m_staticText126 = wx.wxStaticText( UI.m_panel_C_Info, wx.wxID_ANY, "Supply Throughput", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText126:Wrap( -1 )

	UI.gSizer2:Add( UI.m_staticText126, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_SuppThrou = wx.wxTextCtrl( UI.m_panel_C_Info, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_SuppThrou:Enable( False )

	UI.gSizer2:Add( UI.m_textCtrl_SuppThrou, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText34 = wx.wxStaticText( UI.m_panel_C_Info, wx.wxID_ANY, "Monthly war exhaustion \n(only increases during war)", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText34:Wrap( 150 )

	UI.gSizer2:Add( UI.m_staticText34, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_WarExhaustion = wx.wxTextCtrl( UI.m_panel_C_Info, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_WarExhaustion:Enable( False )

	UI.gSizer2:Add( UI.m_textCtrl_WarExhaustion, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_currentWarExhaustion = wx.wxStaticText( UI.m_panel_C_Info, wx.wxID_ANY, "Current war exhaustion", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_currentWarExhaustion:Wrap( -1 )

	UI.gSizer2:Add( UI.m_staticText_currentWarExhaustion, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_currentWarExhaustion = wx.wxTextCtrl( UI.m_panel_C_Info, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_currentWarExhaustion:Enable( False )

	UI.gSizer2:Add( UI.m_textCtrl_currentWarExhaustion, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


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
	UI.m_panelStratResources = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.gSizer6 = wx.wxGridSizer( 10, 7, 0, 0 )

	UI.m_staticText21_empty = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText21_empty:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText21_empty, 0, wx.wxALL, 5 )

	UI.m_staticText22 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Balance", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText22:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText22, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText23 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Sales", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText23:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText23, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText24 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Buys", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText24:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText24, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText39 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Selling?", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText39:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText39, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText40_empty = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText40_empty:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText40_empty, 0, wx.wxALL, 5 )

	UI.m_staticText411_empty = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText411_empty:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText411_empty, 0, wx.wxALL, 5 )

	UI.m_staticText25 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Chromite", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText25:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText25, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlChromiteBalance = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlChromiteBalance:Enable( False )
	UI.m_textCtrlChromiteBalance:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlChromiteBalance, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlChromiteSales = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlChromiteSales:Enable( False )
	UI.m_textCtrlChromiteSales:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlChromiteSales, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlChromiteBuys = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlChromiteBuys:Enable( False )
	UI.m_textCtrlChromiteBuys:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlChromiteBuys, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlChromiteSaleActive = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlChromiteSaleActive:Enable( False )
	UI.m_textCtrlChromiteSaleActive:SetMinSize( wx.wxSize( 50,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlChromiteSaleActive, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonChromiteSaleActivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Activate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonChromiteSaleActivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonChromiteSaleDeactivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Deactivate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonChromiteSaleDeactivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText26 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Aluminium", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText26:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText26, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlAluminiumBalance = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlAluminiumBalance:Enable( False )
	UI.m_textCtrlAluminiumBalance:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlAluminiumBalance, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlAluminiumSales = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlAluminiumSales:Enable( False )
	UI.m_textCtrlAluminiumSales:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlAluminiumSales, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlAluminiumBuys = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlAluminiumBuys:Enable( False )
	UI.m_textCtrlAluminiumBuys:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlAluminiumBuys, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlAluminiumSaleActive = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlAluminiumSaleActive:Enable( False )
	UI.m_textCtrlAluminiumSaleActive:SetMinSize( wx.wxSize( 50,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlAluminiumSaleActive, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonAluminiumSaleActivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Activate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonAluminiumSaleActivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonAluminiumSaleDeactivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Deactivate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonAluminiumSaleDeactivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText27 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Rubber", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText27:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText27, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlRubberBalance = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlRubberBalance:Enable( False )
	UI.m_textCtrlRubberBalance:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlRubberBalance, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlRubberSales = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlRubberSales:Enable( False )
	UI.m_textCtrlRubberSales:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlRubberSales, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlRubberBuys = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlRubberBuys:Enable( False )
	UI.m_textCtrlRubberBuys:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlRubberBuys, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlRubberSaleActive = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlRubberSaleActive:Enable( False )
	UI.m_textCtrlRubberSaleActive:SetMinSize( wx.wxSize( 50,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlRubberSaleActive, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonRubberSaleActivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Activate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonRubberSaleActivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonRubberSaleDeactivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Deactivate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonRubberSaleDeactivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText28 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Tungsten", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText28:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText28, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlTungstenBalance = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlTungstenBalance:Enable( False )
	UI.m_textCtrlTungstenBalance:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlTungstenBalance, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlTungstenSales = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlTungstenSales:Enable( False )
	UI.m_textCtrlTungstenSales:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlTungstenSales, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlTungstenBuys = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlTungstenBuys:Enable( False )
	UI.m_textCtrlTungstenBuys:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlTungstenBuys, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlTungstenSaleActive = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlTungstenSaleActive:Enable( False )
	UI.m_textCtrlTungstenSaleActive:SetMinSize( wx.wxSize( 50,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlTungstenSaleActive, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonTungstenSaleActivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Activate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonTungstenSaleActivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonTungstenSaleDeactivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Deactivate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonTungstenSaleDeactivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText29 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Nickel", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText29:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText29, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlNickelBalance = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlNickelBalance:Enable( False )
	UI.m_textCtrlNickelBalance:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlNickelBalance, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlNickelSales = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlNickelSales:Enable( False )
	UI.m_textCtrlNickelSales:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlNickelSales, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlNickelBuys = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlNickelBuys:Enable( False )
	UI.m_textCtrlNickelBuys:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlNickelBuys, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlNickelSaleActive = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlNickelSaleActive:Enable( False )
	UI.m_textCtrlNickelSaleActive:SetMinSize( wx.wxSize( 50,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlNickelSaleActive, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonNickelSaleActivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Activate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonNickelSaleActivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonNickelSaleDeactivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Deactivate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonNickelSaleDeactivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText30 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Copper", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText30:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText30, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlCopperBalance = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlCopperBalance:Enable( False )
	UI.m_textCtrlCopperBalance:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlCopperBalance, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlCopperSales = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlCopperSales:Enable( False )
	UI.m_textCtrlCopperSales:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlCopperSales, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlCopperBuys = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlCopperBuys:Enable( False )
	UI.m_textCtrlCopperBuys:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlCopperBuys, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlCopperSaleActive = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlCopperSaleActive:Enable( False )
	UI.m_textCtrlCopperSaleActive:SetMinSize( wx.wxSize( 50,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlCopperSaleActive, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonCopperSaleActivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Activate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonCopperSaleActivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonCopperSaleDeactivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Deactivate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonCopperSaleDeactivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText31 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Zinc", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText31:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText31, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlZincBalance = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlZincBalance:Enable( False )
	UI.m_textCtrlZincBalance:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlZincBalance, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlZincSales = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlZincSales:Enable( False )
	UI.m_textCtrlZincSales:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlZincSales, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlZincBuys = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlZincBuys:Enable( False )
	UI.m_textCtrlZincBuys:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlZincBuys, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlZincSaleActive = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlZincSaleActive:Enable( False )
	UI.m_textCtrlZincSaleActive:SetMinSize( wx.wxSize( 50,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlZincSaleActive, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonZincSaleActivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Activate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonZincSaleActivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonZincSaleDeactivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Deactivate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonZincSaleDeactivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText32 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Manganese", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText32:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText32, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlManganeseBalance = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlManganeseBalance:Enable( False )
	UI.m_textCtrlManganeseBalance:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlManganeseBalance, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlManganeseSales = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlManganeseSales:Enable( False )
	UI.m_textCtrlManganeseSales:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlManganeseSales, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlManganeseBuys = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlManganeseBuys:Enable( False )
	UI.m_textCtrlManganeseBuys:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlManganeseBuys, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlManganeseSaleActive = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlManganeseSaleActive:Enable( False )
	UI.m_textCtrlManganeseSaleActive:SetMinSize( wx.wxSize( 50,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlManganeseSaleActive, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonManganeseSaleActivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Activate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonManganeseSaleActivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonManganeseSaleDeactivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Deactivate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonManganeseSaleDeactivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText33 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Molybdenum", wx.wxPoint( -1,-1 ), wx.wxDefaultSize, 0 )
	UI.m_staticText33:Wrap( -1 )

	UI.gSizer6:Add( UI.m_staticText33, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlMolybdenumBalance = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlMolybdenumBalance:Enable( False )
	UI.m_textCtrlMolybdenumBalance:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlMolybdenumBalance, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlMolybdenumSales = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlMolybdenumSales:Enable( False )
	UI.m_textCtrlMolybdenumSales:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlMolybdenumSales, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlMolybdenumBuys = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlMolybdenumBuys:Enable( False )
	UI.m_textCtrlMolybdenumBuys:SetMinSize( wx.wxSize( 40,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlMolybdenumBuys, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlMolybdenumSaleActive = wx.wxTextCtrl( UI.m_panelStratResources, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrlMolybdenumSaleActive:Enable( False )
	UI.m_textCtrlMolybdenumSaleActive:SetMinSize( wx.wxSize( 50,-1 ) )

	UI.gSizer6:Add( UI.m_textCtrlMolybdenumSaleActive, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonMolybdenumSaleActivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Activate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonMolybdenumSaleActivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonMolybdenumSaleDeactivate = wx.wxButton( UI.m_panelStratResources, wx.wxID_ANY, "Deactivate", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.gSizer6:Add( UI.m_buttonMolybdenumSaleDeactivate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_panelStratResources:SetSizer( UI.gSizer6 )
	UI.m_panelStratResources:Layout()
	UI.gSizer6:Fit( UI.m_panelStratResources )
	UI.m_notebook4:AddPage(UI.m_panelStratResources, "Strategic Res.", False )
	UI.m_panel_trades = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_trades_1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText_trades_1 = wx.wxStaticText( UI.m_panel_trades, wx.wxID_ANY, "Active Trades", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_trades_1:Wrap( -1 )

	UI.m_staticText_trades_1:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizer_trades_1:Add( UI.m_staticText_trades_1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_grid_trades_1 = wx.wxGrid( UI.m_panel_trades, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 425,-1 ), 0 )

	-- Grid
	UI.m_grid_trades_1:CreateGrid( 15, 4 )
	UI.m_grid_trades_1:EnableEditing( False )
	UI.m_grid_trades_1:EnableGridLines( True )
	UI.m_grid_trades_1:EnableDragGridSize( False )
	UI.m_grid_trades_1:SetMargins( 0, 0 )

	-- Columns
	UI.m_grid_trades_1:SetColSize( 0, 100 )
	UI.m_grid_trades_1:SetColSize( 1, 100 )
	UI.m_grid_trades_1:SetColSize( 2, 100 )
	UI.m_grid_trades_1:SetColSize( 3, 100 )
	UI.m_grid_trades_1:EnableDragColSize( True )
	UI.m_grid_trades_1:SetColLabelValue( 0, "Buyer" )
	UI.m_grid_trades_1:SetColLabelValue( 1, "Seller" )
	UI.m_grid_trades_1:SetColLabelValue( 2, "Resource" )
	UI.m_grid_trades_1:SetColLabelValue( 3, "Expires in" ) col_label_size {
	UI.m_grid_trades_1:SetColLabelSize( 30 ) }
	UI.m_grid_trades_1:SetColLabelAlignment( wx.wxALIGN_CENTER, wx.wxALIGN_CENTER )

	-- Rows
	UI.m_grid_trades_1:EnableDragRowSize( False )
	UI.m_grid_trades_1:SetRowLabelSize( 1 )
	UI.m_grid_trades_1:SetRowLabelAlignment( wx.wxALIGN_LEFT, wx.wxALIGN_CENTER )

	-- Label Appearance
	UI.m_grid_trades_1:SetLabelBackgroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_MENU ) )

	-- Cell Defaults
	UI.m_grid_trades_1:SetDefaultCellBackgroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_MENU ) )
	UI.m_grid_trades_1:SetDefaultCellAlignment( wx.wxALIGN_CENTER, wx.wxALIGN_TOP )
	UI.m_grid_trades_1:SetMaxSize( wx.wxSize( 425,250 ) )

	UI.bSizer_trades_1:Add( UI.m_grid_trades_1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_trade_1 = wx.wxButton( UI.m_panel_trades, wx.wxID_ANY, "Refresh", wx.wxDefaultPosition, wx.wxSize( -1,-1 ), 0 )
	UI.bSizer_trades_1:Add( UI.m_button_trade_1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_panel_trades:SetSizer( UI.bSizer_trades_1 )
	UI.m_panel_trades:Layout()
	UI.bSizer_trades_1:Fit( UI.m_panel_trades )
	UI.m_notebook4:AddPage(UI.m_panel_trades, "Strategic Trades", False )
	UI.m_panel_IC = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer3 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText35 = wx.wxStaticText( UI.m_panel_IC, wx.wxID_ANY, "On this page you can set the amount of IC you want to invest into event spawned units.\nFor each event spawned unit a counter of the total IcDays that unit would have cost gets counted up.\nDepending on how big your investment is, it gets counted down faster or slower. So you get to choose between a low but longer lasting effect, or short but higher effect.\nThe investment level can be changed anytime, and the reduction value gets scaled with your IC.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText35:Wrap( 350 )

	UI.bSizer3:Add( UI.m_staticText35, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer7 = wx.wxGridSizer( 3, 2, 0, 0 )

	UI.m_staticText36 = wx.wxStaticText( UI.m_panel_IC, wx.wxID_ANY, "IC days left", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText36:Wrap( -1 )

	UI.gSizer7:Add( UI.m_staticText36, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_ICDaysLeft = wx.wxTextCtrl( UI.m_panel_IC, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_ICDaysLeft:Enable( False )

	UI.gSizer7:Add( UI.m_textCtrl_ICDaysLeft, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText37 = wx.wxStaticText( UI.m_panel_IC, wx.wxID_ANY, "Current investment in %", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText37:Wrap( -1 )

	UI.gSizer7:Add( UI.m_staticText37, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_CurrentICInvestment = wx.wxTextCtrl( UI.m_panel_IC, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_CurrentICInvestment:Enable( False )

	UI.gSizer7:Add( UI.m_textCtrl_CurrentICInvestment, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText38 = wx.wxStaticText( UI.m_panel_IC, wx.wxID_ANY, "Current daily reduction", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText38:Wrap( -1 )

	UI.gSizer7:Add( UI.m_staticText38, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_currentDailyICDaysReduction = wx.wxTextCtrl( UI.m_panel_IC, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_currentDailyICDaysReduction:Enable( False )

	UI.gSizer7:Add( UI.m_textCtrl_currentDailyICDaysReduction, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer3:Add( UI.gSizer7, 1, wx.wxEXPAND, 5 )

	UI.gSizer8 = wx.wxGridSizer( 1, 5, 0, 0 )

	UI.m_button_ICInvest_20 = wx.wxButton( UI.m_panel_IC, wx.wxID_ANY, "20%", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer8:Add( UI.m_button_ICInvest_20, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_ICInvest_30 = wx.wxButton( UI.m_panel_IC, wx.wxID_ANY, "30%", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer8:Add( UI.m_button_ICInvest_30, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_ICInvest_40 = wx.wxButton( UI.m_panel_IC, wx.wxID_ANY, "40%", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer8:Add( UI.m_button_ICInvest_40, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_ICInvest_50 = wx.wxButton( UI.m_panel_IC, wx.wxID_ANY, "50%", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer8:Add( UI.m_button_ICInvest_50, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_ICInvest_60 = wx.wxButton( UI.m_panel_IC, wx.wxID_ANY, "60%", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer8:Add( UI.m_button_ICInvest_60, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer3:Add( UI.gSizer8, 1, wx.wxEXPAND, 5 )


	UI.m_panel_IC:SetSizer( UI.bSizer3 )
	UI.m_panel_IC:Layout()
	UI.bSizer3:Fit( UI.m_panel_IC )
	UI.m_notebook4:AddPage(UI.m_panel_IC, "IC Days", False )
	UI.m_panel_customTradeAi = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_customTradeAi1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_htmlWin_CustomTradeAi = wx.wxHtmlWindow( UI.m_panel_customTradeAi, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxHW_SCROLLBAR_AUTO )
	UI.m_htmlWin_CustomTradeAi:SetMinSize( wx.wxSize( 520,250 ) )

	UI.bSizer_customTradeAi1:Add( UI.m_htmlWin_CustomTradeAi, 1, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.gSizer_customTradeAi2 = wx.wxGridSizer( 7, 4, 0, 0 )

	UI.m_button_customTradeAi1 = wx.wxButton( UI.m_panel_customTradeAi, wx.wxID_ANY, "toggle custom trade Ai", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_customTradeAi2:Add( UI.m_button_customTradeAi1, 0, wx.wxALIGN_CENTER + wx.wxALL, 0 )

	UI.m_textCtrl_customTradeAi1 = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi1:Enable( False )
	UI.m_textCtrl_customTradeAi1:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi1, 0, wx.wxALIGN_CENTER + wx.wxALL, 0 )

	UI.m_button_customTradeAi_setValues = wx.wxButton( UI.m_panel_customTradeAi, wx.wxID_ANY, "set values", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_customTradeAi2:Add( UI.m_button_customTradeAi_setValues, 0, wx.wxALIGN_CENTER + wx.wxALL, 0 )

	UI.gSizer35 = wx.wxGridSizer( 0, 2, 0, 0 )

	UI.m_staticText_customTradeAi_MaxDailySell = wx.wxStaticText( UI.m_panel_customTradeAi, wx.wxID_ANY, "maxDailyDeficit", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customTradeAi_MaxDailySell:Wrap( -1 )

	UI.gSizer35:Add( UI.m_staticText_customTradeAi_MaxDailySell, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_CustomTradeAi_MaxDailySell = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "50", wx.wxDefaultPosition, wx.wxSize( 30,-1 ), 0 )
	UI.gSizer35:Add( UI.m_textCtrl_CustomTradeAi_MaxDailySell, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer_customTradeAi2:Add( UI.gSizer35, 1, wx.wxEXPAND, 5 )

	UI.m_textCtrl_customTradeAi6 = wx.wxStaticText( UI.m_panel_customTradeAi, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi6:Wrap( -1 )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi6, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi7 = wx.wxStaticText( UI.m_panel_customTradeAi, wx.wxID_ANY, "Daily surplus", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi7:Wrap( -1 )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi7, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi8 = wx.wxStaticText( UI.m_panel_customTradeAi, wx.wxID_ANY, "Sell above", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi8:Wrap( -1 )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi8, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi10 = wx.wxStaticText( UI.m_panel_customTradeAi, wx.wxID_ANY, "Stockpile", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi10:Wrap( -1 )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi10, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_customTradeAi1 = wx.wxStaticText( UI.m_panel_customTradeAi, wx.wxID_ANY, "Money", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customTradeAi1:Wrap( -1 )

	UI.gSizer_customTradeAi2:Add( UI.m_staticText_customTradeAi1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Money_Buffer = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "1", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Money_Buffer:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Money_Buffer, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Money_BufferSaleCap = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Money_BufferSaleCap:Enable( False )
	UI.m_textCtrl_customTradeAi_Money_BufferSaleCap:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Money_BufferSaleCap, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Money_BufferCancelCap = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Money_BufferCancelCap:Enable( False )
	UI.m_textCtrl_customTradeAi_Money_BufferCancelCap:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Money_BufferCancelCap, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi12 = wx.wxStaticText( UI.m_panel_customTradeAi, wx.wxID_ANY, "Fuel", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi12:Wrap( -1 )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi12, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Fuel_Buffer = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "1", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Fuel_Buffer:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Fuel_Buffer, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Fuel_BufferSaleCap = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "30000", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Fuel_BufferSaleCap:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Fuel_BufferSaleCap, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Fuel_BufferCancelCap = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "20000", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Fuel_BufferCancelCap:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Fuel_BufferCancelCap, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi13 = wx.wxStaticText( UI.m_panel_customTradeAi, wx.wxID_ANY, "Energy", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi13:Wrap( -1 )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi13, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Energy_Buffer = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "5", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Energy_Buffer:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Energy_Buffer, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Energy_BufferSaleCap = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "40000", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Energy_BufferSaleCap:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Energy_BufferSaleCap, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Energy_BufferCancelCap = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "30000", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Energy_BufferCancelCap:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Energy_BufferCancelCap, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi14 = wx.wxStaticText( UI.m_panel_customTradeAi, wx.wxID_ANY, "Metal", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi14:Wrap( -1 )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi14, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Metal_Buffer = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "2.5", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Metal_Buffer:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Metal_Buffer, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Metal_BufferSaleCap = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "20000", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Metal_BufferSaleCap:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Metal_BufferSaleCap, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Metal_BufferCancelCap = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "15000", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Metal_BufferCancelCap:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Metal_BufferCancelCap, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi15 = wx.wxStaticText( UI.m_panel_customTradeAi, wx.wxID_ANY, "Rares", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi15:Wrap( -1 )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi15, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Rares_Buffer = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "1", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Rares_Buffer:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Rares_Buffer, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Rares_BufferSaleCap = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "10000", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Rares_BufferSaleCap:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Rares_BufferSaleCap, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Rares_BufferCancelCap = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "7500", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Rares_BufferCancelCap:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Rares_BufferCancelCap, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi16 = wx.wxStaticText( UI.m_panel_customTradeAi, wx.wxID_ANY, "Crude Oil", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi16:Wrap( -1 )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi16, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Oil_Buffer = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "0.25", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Oil_Buffer:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Oil_Buffer, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Oil_BufferSaleCap = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "20000", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Oil_BufferSaleCap:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Oil_BufferSaleCap, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customTradeAi_Oil_BufferCancelCap = wx.wxTextCtrl( UI.m_panel_customTradeAi, wx.wxID_ANY, "15000", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customTradeAi_Oil_BufferCancelCap:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customTradeAi2:Add( UI.m_textCtrl_customTradeAi_Oil_BufferCancelCap, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_customTradeAi1:Add( UI.gSizer_customTradeAi2, 1, wx.wxEXPAND, 5 )


	UI.m_panel_customTradeAi:SetSizer( UI.bSizer_customTradeAi1 )
	UI.m_panel_customTradeAi:Layout()
	UI.bSizer_customTradeAi1:Fit( UI.m_panel_customTradeAi )
	UI.m_notebook4:AddPage(UI.m_panel_customTradeAi, "Trade AI", False )
	UI.m_panel_customProdSliderAi = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_customProdSliderAi1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_customProdSlider_htmlWin1 = wx.wxHtmlWindow( UI.m_panel_customProdSliderAi, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxHW_SCROLLBAR_AUTO )
	UI.m_customProdSlider_htmlWin1:SetMinSize( wx.wxSize( 520,200 ) )

	UI.bSizer_customProdSliderAi1:Add( UI.m_customProdSlider_htmlWin1, 1, wx.wxALL + wx.wxEXPAND, 5 )

	UI.gSizer_customProdSlider1 = wx.wxGridSizer( 1, 3, 0, 0 )

	UI.m_button_ProductionSliderAi_toggle = wx.wxButton( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "toggle custom Slider Ai", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_customProdSlider1:Add( UI.m_button_ProductionSliderAi_toggle, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_state = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customProdSlider_state:Enable( False )
	UI.m_textCtrl_customProdSlider_state:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customProdSlider1:Add( UI.m_textCtrl_customProdSlider_state, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_ProductionSliderAi_setValues = wx.wxButton( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "set values", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_customProdSlider1:Add( UI.m_button_ProductionSliderAi_setValues, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_customProdSliderAi1:Add( UI.gSizer_customProdSlider1, 0, wx.wxEXPAND, 5 )

	UI.gSizer_customProdSlider2 = wx.wxGridSizer( 7, 5, 0, 0 )


	UI.gSizer_customProdSlider2:Add( 0, 0, 1, wx.wxEXPAND, 5 )

	UI.m_staticText_customProdSlider1 = wx.wxStaticText( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Priority", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customProdSlider1:Wrap( -1 )

	UI.gSizer_customProdSlider2:Add( UI.m_staticText_customProdSlider1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_customProdSlider2 = wx.wxStaticText( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Amount", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customProdSlider2:Wrap( -1 )

	UI.gSizer_customProdSlider2:Add( UI.m_staticText_customProdSlider2, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_customProdSlider3 = wx.wxStaticText( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Mode", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customProdSlider3:Wrap( -1 )

	UI.gSizer_customProdSlider2:Add( UI.m_staticText_customProdSlider3, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer_customProdSlider2:Add( 0, 0, 1, wx.wxEXPAND, 5 )

	UI.m_staticText_customProdSlider4 = wx.wxStaticText( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Upgrades", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customProdSlider4:Wrap( -1 )

	UI.gSizer_customProdSlider2:Add( UI.m_staticText_customProdSlider4, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_upgradePrio = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "4", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_upgradePrio:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider2:Add( UI.m_textCtrl_customProdSlider_upgradePrio, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_upgradeAmount = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "100", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_upgradeAmount:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider2:Add( UI.m_textCtrl_customProdSlider_upgradeAmount, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_choice_customProdSlider_upgradeModeChoices = { "Percentage", "Flat IC" }
	UI.m_choice_customProdSlider_upgradeMode = wx.wxChoice( UI.m_panel_customProdSliderAi, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 90,-1 ), UI.m_choice_customProdSlider_upgradeModeChoices, 0 )
	UI.m_choice_customProdSlider_upgradeMode:SetSelection( 0 )
	UI.gSizer_customProdSlider2:Add( UI.m_choice_customProdSlider_upgradeMode, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer_customProdSlider5 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_checkBox_customProdSlider_upgradeLimit = wx.wxCheckBox( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Limit", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_RIGHT )
	UI.gSizer_customProdSlider5:Add( UI.m_checkBox_customProdSlider_upgradeLimit, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_upgradeLimit = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "50", wx.wxDefaultPosition, wx.wxSize( 30,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_upgradeLimit:SetMaxSize( wx.wxSize( 30,-1 ) )

	UI.gSizer_customProdSlider5:Add( UI.m_textCtrl_customProdSlider_upgradeLimit, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer_customProdSlider2:Add( UI.gSizer_customProdSlider5, 1, wx.wxEXPAND, 5 )

	UI.m_staticText_customProdSlider5 = wx.wxStaticText( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Reinforcement", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customProdSlider5:Wrap( -1 )

	UI.gSizer_customProdSlider2:Add( UI.m_staticText_customProdSlider5, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_reinforcePrio = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "2", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_reinforcePrio:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider2:Add( UI.m_textCtrl_customProdSlider_reinforcePrio, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_reinforceAmount = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "100", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_reinforceAmount:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider2:Add( UI.m_textCtrl_customProdSlider_reinforceAmount, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_choice_customProdSlider_reinforceModeChoices = { "Percentage", "Flat IC" }
	UI.m_choice_customProdSlider_reinforceMode = wx.wxChoice( UI.m_panel_customProdSliderAi, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 90,-1 ), UI.m_choice_customProdSlider_reinforceModeChoices, 0 )
	UI.m_choice_customProdSlider_reinforceMode:SetSelection( 0 )
	UI.gSizer_customProdSlider2:Add( UI.m_choice_customProdSlider_reinforceMode, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer_customProdSlider4 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_checkBox_customProdSlider_reinforceLimit = wx.wxCheckBox( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Limit", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_RIGHT )
	UI.gSizer_customProdSlider4:Add( UI.m_checkBox_customProdSlider_reinforceLimit, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_reinforceLimit = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "50", wx.wxDefaultPosition, wx.wxSize( 30,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_reinforceLimit:SetMaxSize( wx.wxSize( 30,-1 ) )

	UI.gSizer_customProdSlider4:Add( UI.m_textCtrl_customProdSlider_reinforceLimit, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer_customProdSlider2:Add( UI.gSizer_customProdSlider4, 1, wx.wxEXPAND, 5 )

	UI.m_staticText_customProdSlider6 = wx.wxStaticText( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Supply", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customProdSlider6:Wrap( -1 )

	UI.gSizer_customProdSlider2:Add( UI.m_staticText_customProdSlider6, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_supplyPrio = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "3", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_supplyPrio:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider2:Add( UI.m_textCtrl_customProdSlider_supplyPrio, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_supplyAmount = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "100", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_supplyAmount:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider2:Add( UI.m_textCtrl_customProdSlider_supplyAmount, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_choice_customProdSlider_supplyModeChoices = { "Percentage", "Flat IC" }
	UI.m_choice_customProdSlider_supplyMode = wx.wxChoice( UI.m_panel_customProdSliderAi, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 90,-1 ), UI.m_choice_customProdSlider_supplyModeChoices, 0 )
	UI.m_choice_customProdSlider_supplyMode:SetSelection( 0 )
	UI.gSizer_customProdSlider2:Add( UI.m_choice_customProdSlider_supplyMode, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer_customProdSlider3 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_checkBox_customProdSlider_supplyGoal = wx.wxCheckBox( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Goal", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_RIGHT )
	UI.gSizer_customProdSlider3:Add( UI.m_checkBox_customProdSlider_supplyGoal, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_supplyGoal = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "50000", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_supplyGoal:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider3:Add( UI.m_textCtrl_customProdSlider_supplyGoal, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer_customProdSlider2:Add( UI.gSizer_customProdSlider3, 1, wx.wxEXPAND, 5 )

	UI.m_staticText_customProdSlider7 = wx.wxStaticText( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Production", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customProdSlider7:Wrap( -1 )

	UI.gSizer_customProdSlider2:Add( UI.m_staticText_customProdSlider7, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_productionPrio = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "5", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_productionPrio:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider2:Add( UI.m_textCtrl_customProdSlider_productionPrio, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_productionAmount = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "25", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_productionAmount:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider2:Add( UI.m_textCtrl_customProdSlider_productionAmount, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_choice_customProdSlider_productionModeChoices = { "Percentage", "Flat IC" }
	UI.m_choice_customProdSlider_productionMode = wx.wxChoice( UI.m_panel_customProdSliderAi, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 90,-1 ), UI.m_choice_customProdSlider_productionModeChoices, 0 )
	UI.m_choice_customProdSlider_productionMode:SetSelection( 1 )
	UI.gSizer_customProdSlider2:Add( UI.m_choice_customProdSlider_productionMode, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer_customProdSlider2:Add( 0, 0, 1, wx.wxEXPAND, 5 )

	UI.m_staticText_customProdSlider8 = wx.wxStaticText( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Consumer Goods", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customProdSlider8:Wrap( -1 )

	UI.gSizer_customProdSlider2:Add( UI.m_staticText_customProdSlider8, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_consumerPrio = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "1", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_consumerPrio:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider2:Add( UI.m_textCtrl_customProdSlider_consumerPrio, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_consumerAmount = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "100", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_consumerAmount:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider2:Add( UI.m_textCtrl_customProdSlider_consumerAmount, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_choice_customProdSlider_consumerModeChoices = { "Percentage", "Flat IC" }
	UI.m_choice_customProdSlider_consumerMode = wx.wxChoice( UI.m_panel_customProdSliderAi, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 90,-1 ), UI.m_choice_customProdSlider_consumerModeChoices, 0 )
	UI.m_choice_customProdSlider_consumerMode:SetSelection( 0 )
	UI.gSizer_customProdSlider2:Add( UI.m_choice_customProdSlider_consumerMode, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_checkBox_customProdSlider_reduceDissent = wx.wxCheckBox( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Reduce Dissent", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_customProdSlider2:Add( UI.m_checkBox_customProdSlider_reduceDissent, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_customProdSlider9 = wx.wxStaticText( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "Lend Lease", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customProdSlider9:Wrap( -1 )

	UI.gSizer_customProdSlider2:Add( UI.m_staticText_customProdSlider9, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_lendLeasePrio = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "6", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_lendLeasePrio:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider2:Add( UI.m_textCtrl_customProdSlider_lendLeasePrio, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customProdSlider_lendLeaseAmount = wx.wxTextCtrl( UI.m_panel_customProdSliderAi, wx.wxID_ANY, "0", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customProdSlider_lendLeaseAmount:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customProdSlider2:Add( UI.m_textCtrl_customProdSlider_lendLeaseAmount, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_choice_customProdSlider_lendLeaseModeChoices = { "Flat IC" }
	UI.m_choice_customProdSlider_lendLeaseMode = wx.wxChoice( UI.m_panel_customProdSliderAi, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 90,-1 ), UI.m_choice_customProdSlider_lendLeaseModeChoices, 0 )
	UI.m_choice_customProdSlider_lendLeaseMode:SetSelection( 0 )
	UI.m_choice_customProdSlider_lendLeaseMode:Enable( False )

	UI.gSizer_customProdSlider2:Add( UI.m_choice_customProdSlider_lendLeaseMode, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer_customProdSlider2:Add( 0, 0, 1, wx.wxEXPAND, 5 )


	UI.bSizer_customProdSliderAi1:Add( UI.gSizer_customProdSlider2, 1, wx.wxEXPAND, 5 )


	UI.m_panel_customProdSliderAi:SetSizer( UI.bSizer_customProdSliderAi1 )
	UI.m_panel_customProdSliderAi:Layout()
	UI.bSizer_customProdSliderAi1:Fit( UI.m_panel_customProdSliderAi )
	UI.m_notebook4:AddPage(UI.m_panel_customProdSliderAi, "Prod. Sliders AI", False )
	UI.m_panel_customLsSliderAi = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_customLsSliderAi1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_htmlWin_customLsSliderAi1 = wx.wxHtmlWindow( UI.m_panel_customLsSliderAi, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxHW_SCROLLBAR_AUTO )
	UI.m_htmlWin_customLsSliderAi1:SetMinSize( wx.wxSize( 520,200 ) )

	UI.bSizer_customLsSliderAi1:Add( UI.m_htmlWin_customLsSliderAi1, 1, wx.wxALL + wx.wxEXPAND, 5 )

	UI.gSizer_customLsSliderAi1 = wx.wxGridSizer( 1, 3, 0, 0 )

	UI.m_button_customLsSliderAi_toggle = wx.wxButton( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "toggle custom LS Slider Ai", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_customLsSliderAi1:Add( UI.m_button_customLsSliderAi_toggle, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customLsSliderAi_state = wx.wxTextCtrl( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_customLsSliderAi_state:Enable( False )
	UI.m_textCtrl_customLsSliderAi_state:SetMinSize( wx.wxSize( 75,-1 ) )

	UI.gSizer_customLsSliderAi1:Add( UI.m_textCtrl_customLsSliderAi_state, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_customLsSliderAi_setValues = wx.wxButton( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "set values", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_customLsSliderAi1:Add( UI.m_button_customLsSliderAi_setValues, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_customLsSliderAi1:Add( UI.gSizer_customLsSliderAi1, 0, wx.wxEXPAND, 5 )

	UI.gSizer_customLsSliderAi2 = wx.wxGridSizer( 4, 4, 0, 0 )


	UI.gSizer_customLsSliderAi2:Add( 0, 0, 1, wx.wxEXPAND, 5 )

	UI.m_staticText_customLsSliderAi1 = wx.wxStaticText( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "Lower", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customLsSliderAi1:Wrap( -1 )

	UI.gSizer_customLsSliderAi2:Add( UI.m_staticText_customLsSliderAi1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_customLsSliderAi2 = wx.wxStaticText( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "Upper", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customLsSliderAi2:Wrap( -1 )

	UI.gSizer_customLsSliderAi2:Add( UI.m_staticText_customLsSliderAi2, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer_customLsSliderAi2:Add( 0, 0, 1, wx.wxEXPAND, 5 )

	UI.m_staticText_customLsSliderAi3 = wx.wxStaticText( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "Officers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customLsSliderAi3:Wrap( -1 )

	UI.gSizer_customLsSliderAi2:Add( UI.m_staticText_customLsSliderAi3, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customLsSliderAi_officersLower = wx.wxTextCtrl( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "110", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customLsSliderAi_officersLower:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customLsSliderAi2:Add( UI.m_textCtrl_customLsSliderAi_officersLower, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customLsSliderAi_officersUpper = wx.wxTextCtrl( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "110", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customLsSliderAi_officersUpper:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customLsSliderAi2:Add( UI.m_textCtrl_customLsSliderAi_officersUpper, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_checkBox_customLsSliderAi_bufferNco = wx.wxCheckBox( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "Buffer NCOs", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_checkBox_customLsSliderAi_bufferNco:SetValue(True)
	UI.gSizer_customLsSliderAi2:Add( UI.m_checkBox_customLsSliderAi_bufferNco, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_customLsSliderAi4 = wx.wxStaticText( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "Spies", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customLsSliderAi4:Wrap( -1 )

	UI.gSizer_customLsSliderAi2:Add( UI.m_staticText_customLsSliderAi4, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customLsSliderAi_spiesLower = wx.wxTextCtrl( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "10", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customLsSliderAi_spiesLower:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customLsSliderAi2:Add( UI.m_textCtrl_customLsSliderAi_spiesLower, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customLsSliderAi_spiesUpper = wx.wxTextCtrl( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "20", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customLsSliderAi_spiesUpper:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customLsSliderAi2:Add( UI.m_textCtrl_customLsSliderAi_spiesUpper, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer_customLsSliderAi2:Add( 0, 0, 1, wx.wxEXPAND, 5 )

	UI.m_staticText_customLsSliderAi5 = wx.wxStaticText( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "Diplo", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_customLsSliderAi5:Wrap( -1 )

	UI.gSizer_customLsSliderAi2:Add( UI.m_staticText_customLsSliderAi5, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customLsSliderAi_diploLower = wx.wxTextCtrl( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "10", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customLsSliderAi_diploLower:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customLsSliderAi2:Add( UI.m_textCtrl_customLsSliderAi_diploLower, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_customLsSliderAi_diploUpper = wx.wxTextCtrl( UI.m_panel_customLsSliderAi, wx.wxID_ANY, "20", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.m_textCtrl_customLsSliderAi_diploUpper:SetMaxSize( wx.wxSize( 40,-1 ) )

	UI.gSizer_customLsSliderAi2:Add( UI.m_textCtrl_customLsSliderAi_diploUpper, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_customLsSliderAi1:Add( UI.gSizer_customLsSliderAi2, 1, wx.wxEXPAND, 5 )


	UI.m_panel_customLsSliderAi:SetSizer( UI.bSizer_customLsSliderAi1 )
	UI.m_panel_customLsSliderAi:Layout()
	UI.bSizer_customLsSliderAi1:Fit( UI.m_panel_customLsSliderAi )
	UI.m_notebook4:AddPage(UI.m_panel_customLsSliderAi, "LS Sliders AI", False )
	UI.m_panel_NatFocus = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer31 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText40 = wx.wxStaticText( UI.m_panel_NatFocus, wx.wxID_ANY, "You can set and change your national focus at any time,\n but the effects are not instant.\nWhen changing focus it takes about 90 days for you to get any benefits. The old focus will wear off in the same amount of time it was active.\nBonuses are tiered depending on the time the focus was active.\nThere are 3 tiers, each achieved after 90, 360 and 720 days.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText40:Wrap( 350 )

	UI.bSizer31:Add( UI.m_staticText40, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer9 = wx.wxGridSizer( 0, 2, 0, 0 )

	UI.bSizer4 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_button_FocusGround = wx.wxButton( UI.m_panel_NatFocus, wx.wxID_ANY, "Ground Forces", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer4:Add( UI.m_button_FocusGround, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_FocusGroundDays = wx.wxTextCtrl( UI.m_panel_NatFocus, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_FocusGroundDays:Enable( False )

	UI.bSizer4:Add( UI.m_textCtrl_FocusGroundDays, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer9:Add( UI.bSizer4, 1, wx.wxEXPAND, 5 )

	UI.bSizer5 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_button_FocusAir = wx.wxButton( UI.m_panel_NatFocus, wx.wxID_ANY, "Air", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer5:Add( UI.m_button_FocusAir, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_FocusAirDays = wx.wxTextCtrl( UI.m_panel_NatFocus, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_FocusAirDays:Enable( False )

	UI.bSizer5:Add( UI.m_textCtrl_FocusAirDays, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer9:Add( UI.bSizer5, 1, wx.wxEXPAND, 5 )

	UI.bSizer9 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_button_FocusNavy = wx.wxButton( UI.m_panel_NatFocus, wx.wxID_ANY, "Navy", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer9:Add( UI.m_button_FocusNavy, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_FocusNavyDays = wx.wxTextCtrl( UI.m_panel_NatFocus, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_FocusNavyDays:Enable( False )

	UI.bSizer9:Add( UI.m_textCtrl_FocusNavyDays, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer9:Add( UI.bSizer9, 1, wx.wxEXPAND, 5 )

	UI.bSizer11 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_button_FocusEcon = wx.wxButton( UI.m_panel_NatFocus, wx.wxID_ANY, "Economy", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer11:Add( UI.m_button_FocusEcon, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_FocusEconDays = wx.wxTextCtrl( UI.m_panel_NatFocus, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_FocusEconDays:Enable( False )

	UI.bSizer11:Add( UI.m_textCtrl_FocusEconDays, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer9:Add( UI.bSizer11, 1, wx.wxEXPAND, 5 )

	UI.bSizer12 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_button_FocusScience = wx.wxButton( UI.m_panel_NatFocus, wx.wxID_ANY, "Science", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer12:Add( UI.m_button_FocusScience, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_FocusScienceDays = wx.wxTextCtrl( UI.m_panel_NatFocus, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_FocusScienceDays:Enable( False )

	UI.bSizer12:Add( UI.m_textCtrl_FocusScienceDays, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer9:Add( UI.bSizer12, 1, wx.wxEXPAND, 5 )

	UI.bSizer13 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_button_FocusHealthEdu = wx.wxButton( UI.m_panel_NatFocus, wx.wxID_ANY, "Health + Education", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer13:Add( UI.m_button_FocusHealthEdu, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_FocusHealthEduDays = wx.wxTextCtrl( UI.m_panel_NatFocus, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_FocusHealthEduDays:Enable( False )

	UI.bSizer13:Add( UI.m_textCtrl_FocusHealthEduDays, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer9:Add( UI.bSizer13, 1, wx.wxEXPAND, 5 )

	UI.bSizer14 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_button_FocusResource = wx.wxButton( UI.m_panel_NatFocus, wx.wxID_ANY, "Resources", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer14:Add( UI.m_button_FocusResource, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_FocusResourceDays = wx.wxTextCtrl( UI.m_panel_NatFocus, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_FocusResourceDays:Enable( False )

	UI.bSizer14:Add( UI.m_textCtrl_FocusResourceDays, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer9:Add( UI.bSizer14, 1, wx.wxEXPAND, 5 )

	UI.m_button_FocusNone = wx.wxButton( UI.m_panel_NatFocus, wx.wxID_ANY, "No Focus", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer9:Add( UI.m_button_FocusNone, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer31:Add( UI.gSizer9, 1, wx.wxEXPAND, 5 )


	UI.m_panel_NatFocus:SetSizer( UI.bSizer31 )
	UI.m_panel_NatFocus:Layout()
	UI.bSizer31:Fit( UI.m_panel_NatFocus )
	UI.m_notebook4:AddPage(UI.m_panel_NatFocus, "National Focus", False )
	UI.m_panel_MinisterBuildings = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer27 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText43 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "This window shows the current progress towards buildings being built by your ministers.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText43:Wrap( -1 )

	UI.bSizer27:Add( UI.m_staticText43, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.gSizer12 = wx.wxGridSizer( 0, 2, 0, 0 )

	UI.gSizerMBuildings = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Small Arms Factory ", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings:Wrap( -1 )

	UI.gSizerMBuildings:Add( UI.m_staticTextMBuildings, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_SmlArmsFactory = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_SmlArmsFactory:Enable( False )

	UI.gSizerMBuildings:Add( UI.m_textCtrl_SmlArmsFactory, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings1 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings1 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Tank Factory ", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings1:Wrap( -1 )

	UI.gSizerMBuildings1:Add( UI.m_staticTextMBuildings1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_TankFactory = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_TankFactory:Enable( False )

	UI.gSizerMBuildings1:Add( UI.m_textCtrl_TankFactory, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings1, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings2 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings2 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Light Aircraft Factory ", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings2:Wrap( -1 )

	UI.gSizerMBuildings2:Add( UI.m_staticTextMBuildings2, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_LightAircraftFactory = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_LightAircraftFactory:Enable( False )

	UI.gSizerMBuildings2:Add( UI.m_textCtrl_LightAircraftFactory, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings2, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings3 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings3 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Medium Aircraft Factory ", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings3:Wrap( -1 )

	UI.gSizerMBuildings3:Add( UI.m_staticTextMBuildings3, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_MediumAircraftFactory = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_MediumAircraftFactory:Enable( False )

	UI.gSizerMBuildings3:Add( UI.m_textCtrl_MediumAircraftFactory, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings3, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings4 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings4 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Heavy Aircraft Factory ", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings4:Wrap( -1 )

	UI.gSizerMBuildings4:Add( UI.m_staticTextMBuildings4, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_HeavyAircraftFactory = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_HeavyAircraftFactory:Enable( False )

	UI.gSizerMBuildings4:Add( UI.m_textCtrl_HeavyAircraftFactory, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings4, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings5 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings5 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Small Shipyard", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings5:Wrap( -1 )

	UI.gSizerMBuildings5:Add( UI.m_staticTextMBuildings5, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_SmallShipyard = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_SmallShipyard:Enable( False )

	UI.gSizerMBuildings5:Add( UI.m_textCtrl_SmallShipyard, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings5, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings6 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings6 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Medium Shipyard", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings6:Wrap( -1 )

	UI.gSizerMBuildings6:Add( UI.m_staticTextMBuildings6, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_MediumShipyard = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_MediumShipyard:Enable( False )

	UI.gSizerMBuildings6:Add( UI.m_textCtrl_MediumShipyard, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings6, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings7 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings7 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Capital Shipyard", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings7:Wrap( -1 )

	UI.gSizerMBuildings7:Add( UI.m_staticTextMBuildings7, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_CapitalShipyard = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_CapitalShipyard:Enable( False )

	UI.gSizerMBuildings7:Add( UI.m_textCtrl_CapitalShipyard, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings7, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings8 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings8 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Submarine Shipyard", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings8:Wrap( -1 )

	UI.gSizerMBuildings8:Add( UI.m_staticTextMBuildings8, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_SubmarineShipyard = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_SubmarineShipyard:Enable( False )

	UI.gSizerMBuildings8:Add( UI.m_textCtrl_SubmarineShipyard, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings8, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings9 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings9 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Heavy Industry", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings9:Wrap( -1 )

	UI.gSizerMBuildings9:Add( UI.m_staticTextMBuildings9, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_HeavyIndustry = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_HeavyIndustry:Enable( False )

	UI.gSizerMBuildings9:Add( UI.m_textCtrl_HeavyIndustry, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings9, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings10 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings10 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Manufacturing (Supply)", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings10:Wrap( -1 )

	UI.gSizerMBuildings10:Add( UI.m_staticTextMBuildings10, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_SupplyFactory = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_SupplyFactory:Enable( False )

	UI.gSizerMBuildings10:Add( UI.m_textCtrl_SupplyFactory, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings10, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings11 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings11 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Research Centers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings11:Wrap( -1 )

	UI.gSizerMBuildings11:Add( UI.m_staticTextMBuildings11, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_ResearchCenters = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_ResearchCenters:Enable( False )

	UI.gSizerMBuildings11:Add( UI.m_textCtrl_ResearchCenters, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings11, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings12 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings12 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Training Centers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings12:Wrap( -1 )

	UI.gSizerMBuildings12:Add( UI.m_staticTextMBuildings12, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_TrainingCenters = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_TrainingCenters:Enable( False )

	UI.gSizerMBuildings12:Add( UI.m_textCtrl_TrainingCenters, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings12, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings13 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings13 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Artillery Factory", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings13:Wrap( -1 )

	UI.gSizerMBuildings13:Add( UI.m_staticTextMBuildings13, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_ArtilleryFactory = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_ArtilleryFactory:Enable( False )

	UI.gSizerMBuildings13:Add( UI.m_textCtrl_ArtilleryFactory, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings13, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings14 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings14 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Radar Station", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings14:Wrap( -1 )

	UI.gSizerMBuildings14:Add( UI.m_staticTextMBuildings14, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_RadarStation = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_RadarStation:Enable( False )

	UI.gSizerMBuildings14:Add( UI.m_textCtrl_RadarStation, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings14, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings15 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings15 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Automotive Factory", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings15:Wrap( -1 )

	UI.gSizerMBuildings15:Add( UI.m_staticTextMBuildings15, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_AutomotiveFactory = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_AutomotiveFactory:Enable( False )

	UI.gSizerMBuildings15:Add( UI.m_textCtrl_AutomotiveFactory, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings15, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings16 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings16 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Resource Mines", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings16:Wrap( -1 )

	UI.gSizerMBuildings16:Add( UI.m_staticTextMBuildings16, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_ResourceBuildings = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_ResourceBuildings:Enable( False )

	UI.gSizerMBuildings16:Add( UI.m_textCtrl_ResourceBuildings, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings16, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings17 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings17 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Railway Terminus", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings17:Wrap( -1 )

	UI.gSizerMBuildings17:Add( UI.m_staticTextMBuildings17, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_RailTerminus = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_RailTerminus:Enable( False )

	UI.gSizerMBuildings17:Add( UI.m_textCtrl_RailTerminus, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings17, 1, wx.wxEXPAND, 5 )

	UI.gSizerMBuildings18 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_staticTextMBuildings18 = wx.wxStaticText( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "Hospital", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextMBuildings18:Wrap( -1 )

	UI.gSizerMBuildings18:Add( UI.m_staticTextMBuildings18, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_Hospital = wx.wxTextCtrl( UI.m_panel_MinisterBuildings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_Hospital:Enable( False )

	UI.gSizerMBuildings18:Add( UI.m_textCtrl_Hospital, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer12:Add( UI.gSizerMBuildings18, 1, wx.wxEXPAND, 5 )


	UI.bSizer27:Add( UI.gSizer12, 1, wx.wxEXPAND, 5 )


	UI.m_panel_MinisterBuildings:SetSizer( UI.bSizer27 )
	UI.m_panel_MinisterBuildings:Layout()
	UI.bSizer27:Fit( UI.m_panel_MinisterBuildings )
	UI.m_notebook4:AddPage(UI.m_panel_MinisterBuildings, "Minister Buildings", False )
	UI.m_panel_Misc = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.gSizer4 = wx.wxGridSizer( 3, 4, 0, 0 )

	UI.m_staticText15 = wx.wxStaticText( UI.m_panel_Misc, wx.wxID_ANY, "Daily strategic resource counts.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText15:Wrap( 100 )

	UI.gSizer4:Add( UI.m_staticText15, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrlDailyCount = wx.wxTextCtrl( UI.m_panel_Misc, wx.wxID_ANY, "false", wx.wxDefaultPosition, wx.wxSize( -1,-1 ), 0 )
	UI.m_textCtrlDailyCount:Enable( False )

	UI.gSizer4:Add( UI.m_textCtrlDailyCount, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonDailyOn = wx.wxButton( UI.m_panel_Misc, wx.wxID_ANY, "On", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer4:Add( UI.m_buttonDailyOn, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonDailyOff = wx.wxButton( UI.m_panel_Misc, wx.wxID_ANY, "Off", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer4:Add( UI.m_buttonDailyOff, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText17 = wx.wxStaticText( UI.m_panel_Misc, wx.wxID_ANY, "Hide Trading decisions", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText17:Wrap( 100 )

	UI.gSizer4:Add( UI.m_staticText17, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_TradeDecisionHide = wx.wxTextCtrl( UI.m_panel_Misc, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_TradeDecisionHide:Enable( False )

	UI.gSizer4:Add( UI.m_textCtrl_TradeDecisionHide, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_TradeDecisionHide = wx.wxButton( UI.m_panel_Misc, wx.wxID_ANY, "Hide", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer4:Add( UI.m_button_TradeDecisionHide, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_TradeDecisionShow = wx.wxButton( UI.m_panel_Misc, wx.wxID_ANY, "Show", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer4:Add( UI.m_button_TradeDecisionShow, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText18 = wx.wxStaticText( UI.m_panel_Misc, wx.wxID_ANY, "Hide Mines decisions", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText18:Wrap( 100 )

	UI.gSizer4:Add( UI.m_staticText18, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_MinesDecisionHide = wx.wxTextCtrl( UI.m_panel_Misc, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_MinesDecisionHide:Enable( False )

	UI.gSizer4:Add( UI.m_textCtrl_MinesDecisionHide, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_MinesDecisionHide = wx.wxButton( UI.m_panel_Misc, wx.wxID_ANY, "Hide", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer4:Add( UI.m_button_MinesDecisionHide, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_MinesDecisionShow = wx.wxButton( UI.m_panel_Misc, wx.wxID_ANY, "Show", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer4:Add( UI.m_button_MinesDecisionShow, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_panel_Misc:SetSizer( UI.gSizer4 )
	UI.m_panel_Misc:Layout()
	UI.gSizer4:Fit( UI.m_panel_Misc )
	UI.m_notebook4:AddPage(UI.m_panel_Misc, "Misc", False )
	UI.m_panel_Special = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.gSizer5 = wx.wxGridSizer( 2, 2, 0, 0 )

	UI.m_buttonRemoveSprites = wx.wxButton( UI.m_panel_Special, wx.wxID_ANY, "Remove Sprites", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer5:Add( UI.m_buttonRemoveSprites, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText19 = wx.wxStaticText( UI.m_panel_Special, wx.wxID_ANY, "In order to save about 300mb of RAM you can (and should) delete the 3d sprites of units.\nYou can only do this in the main menu right after starting the game!\n\nWhen pressing the button a LUA script will move all of the sprites we don't need into a backup folder.\nA windows command prompt will open and you will see some fast logs of the files being moved.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText19:Wrap( 200 )

	UI.gSizer5:Add( UI.m_staticText19, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_buttonRestoreSprites = wx.wxButton( UI.m_panel_Special, wx.wxID_ANY, "Restore Sprites", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer5:Add( UI.m_buttonRestoreSprites, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText20 = wx.wxStaticText( UI.m_panel_Special, wx.wxID_ANY, "If you want to play any other mod or vanilla you need to restore the sprites to their original location.\nTo do that just press the restore button. Again there will be a command prompt window opening and logs will fly by.\n\n\nAfter either of the 2 actions is finished you need to restart the game.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText20:Wrap( 200 )

	UI.gSizer5:Add( UI.m_staticText20, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_panel_Special:SetSizer( UI.gSizer5 )
	UI.m_panel_Special:Layout()
	UI.gSizer5:Fit( UI.m_panel_Special )
	UI.m_notebook4:AddPage(UI.m_panel_Special, "Special", False )


	UI.MyFrame1 .m_mgr:Update()
	UI.MyFrame1:Centre( wx.wxBOTH )

	-- Connect Events

	UI.set_player_button:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button8OnButtonClick

	event:Skip()
	end )

	UI.m_button_ShowOptionsWindow:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_ShowOptionsWindowOnButtonClick

	event:Skip()
	end )

	UI.m_button_ShowStatsWindow:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_ShowOptionsWindowOnButtonClick

	event:Skip()
	end )

	UI.m_button_ShowGameInfoWindow:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_ShowGameInfoWindowOnButtonClick

	event:Skip()
	end )

	UI.m_buttonEnablePuppetDecision:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_buttonEnablePuppetDecisionOnButtonClick

	event:Skip()
	end )

	UI.m_buttonDisablePuppetDecision:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_buttonDisablePuppetDecisionOnButtonClick

	event:Skip()
	end )

	UI.m_buttonChromiteSaleActivate:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_buttonChromiteSaleActivateOnButtonClick

	event:Skip()
	end )

	UI.m_buttonChromiteSaleDeactivate:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_buttonChromiteSaleDeactivateOnButtonClick

	event:Skip()
	end )

	UI.m_button_ICInvest_20:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_ICInvest_20OnButtonClick

	event:Skip()
	end )

	UI.m_button_ICInvest_30:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_ICInvest_30OnButtonClick

	event:Skip()
	end )

	UI.m_button_ICInvest_40:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_ICInvest_40OnButtonClick

	event:Skip()
	end )

	UI.m_button_ICInvest_50:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_ICInvest_50OnButtonClick

	event:Skip()
	end )

	UI.m_button_ICInvest_60:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_ICInvest_60OnButtonClick

	event:Skip()
	end )

	UI.m_button_ProductionSliderAi_toggle:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_ProductionSliderAi_toggleOnButtonClick

	event:Skip()
	end )

	UI.m_button_ProductionSliderAi_setValues:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_ProductionSliderAi_setValuesOnButtonClick

	event:Skip()
	end )

	UI.m_button_customLsSliderAi_toggle:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_customLsSliderAi_toggle

	event:Skip()
	end )

	UI.m_button_customLsSliderAi_setValues:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_customLsSliderAi_setValues

	event:Skip()
	end )

	UI.m_button_FocusGround:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_FocusGroundOnButtonClick

	event:Skip()
	end )

	UI.m_button_FocusAir:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_FocusAirOnButtonClick

	event:Skip()
	end )

	UI.m_button_FocusNavy:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_FocusNavyOnButtonClick

	event:Skip()
	end )

	UI.m_button_FocusEcon:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_FocusEconOnButtonClick

	event:Skip()
	end )

	UI.m_button_FocusScience:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_FocusScienceOnButtonClick

	event:Skip()
	end )

	UI.m_button_FocusHealthEdu:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_FocusHealthEduOnButtonClick

	event:Skip()
	end )

	UI.m_button_FocusResource:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_FocusResourceOnButtonClick

	event:Skip()
	end )

	UI.m_button_FocusNone:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_FocusNoneOnButtonClick

	event:Skip()
	end )

	UI.m_buttonDailyOn:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_buttonDailyOnOnButtonClick

	event:Skip()
	end )

	UI.m_buttonDailyOff:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_buttonDailyOffOnButtonClick

	event:Skip()
	end )

	UI.m_buttonRemoveSprites:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_buttonRemoveSpritesOnButtonClick

	event:Skip()
	end )

	UI.m_buttonRestoreSprites:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_buttonRestoreSpritesOnButtonClick

	event:Skip()
	end )


-- create MyFrame2
UI.MyFrame2 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "Hoi3 Utility Help", wx.wxDefaultPosition, wx.wxSize( 800,700 ), wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxMAXIMIZE_BOX + wx.wxMINIMIZE_BOX + wx.wxRESIZE_BORDER + wx.wxSTAY_ON_TOP + wx.wxSYSTEM_MENU+wx.wxTAB_TRAVERSAL )
	UI.MyFrame2:SetSizeHints( wx.wxDefaultSize, wx.wxDefaultSize )
	UI.MyFrame2.m_mgr = wxaui.wxAuiManager()
	UI.MyFrame2.m_mgr:SetManagedWindow( UI.MyFrame2 )

	UI.m_notebook2 = wx.wxNotebook( UI.MyFrame2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,100 ), wx.wxNB_MULTILINE )
	UI.MyFrame2.m_mgr:AddPane( UI.m_notebook2, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):CloseButton( False ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.m_scrolledWindow_HelpMisc = wx.wxScrolledWindow( UI.m_notebook2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxHSCROLL + wx.wxVSCROLL )
	UI.m_scrolledWindow_HelpMisc:SetScrollRate( 5, 5 )
	UI.m_scrolledWindow_HelpMisc:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizerHelpMisc0 = wx.wxGridSizer( 2, 2, 0, 5 )

	UI.bSizerHelpMisc1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticTextHelpMisc = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Strategic Resources", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelpMisc:Wrap( -1 )

	UI.m_staticTextHelpMisc:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizerHelpMisc1:Add( UI.m_staticTextHelpMisc, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticTextHelpMisc1 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Strategic Resources are crucial for the military production of any nation. If you do not have access to these resources other nations may be open to selling them for a price, if you have them there is much money to be made as an exporter of them. \nTrade deals last for 1 year. \nEach 200 IC requires a resource level to avoid maluses, below 100IC there are no maluses. Puppets give their excess resource to the master, who can also decide to sell it.\nEach trade costs the player 2000 money, between allies the price is halved.\n", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelpMisc1:Wrap( 370 )

	UI.m_staticTextHelpMisc1:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizerHelpMisc1:Add( UI.m_staticTextHelpMisc1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizerHelpMisc0:Add( UI.bSizerHelpMisc1, 1, wx.wxEXPAND, 5 )

	UI.bSizerHelpMisc2 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticTextHelpMisc2 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Airdroppable Units", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelpMisc2:Wrap( -1 )

	UI.m_staticTextHelpMisc2:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizerHelpMisc2:Add( UI.m_staticTextHelpMisc2, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizerHelpMisc1 = wx.wxGridSizer( 0, 2, 0, 0 )

	UI.m_staticTextHelp30 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Garrision detachment", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp30:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp30, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp22 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Motorcycle Recon", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp22:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp22, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp31 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Light Transport", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp31:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp31, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp32 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Gurkhas", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp32:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp32, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp33 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Elite Light Infantry Battalion", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp33:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp33, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp34 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Airborne Engineers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp34:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp34, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp35 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Airborne Mixed Support", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp35:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp35, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp36 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Commandos", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp36:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp36, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp37 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Airlanding Infantry", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp37:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp37, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp38 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Paratroopers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp38:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp38, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp39 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Player Unit (\"YOU\" brigade)", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp39:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp39, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp40 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Political Leader", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp40:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp40, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp41 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Battle Commander", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp41:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp41, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Division HQs", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp:Wrap( -1 )

	UI.m_staticTextHelp:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp, 0, wx.wxALL, 5 )


	UI.bSizerHelpMisc2:Add( UI.gSizerHelpMisc1, 1, wx.wxALIGN_CENTER, 5 )


	UI.gSizerHelpMisc0:Add( UI.bSizerHelpMisc2, 1, wx.wxEXPAND, 5 )

	UI.bSizerHelp50 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticTextHelp23 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Unit Training", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp23:Wrap( 650 )

	UI.m_staticTextHelp23:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, True, "" ) )

	UI.bSizerHelp50:Add( UI.m_staticTextHelp23, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticTextHelp24 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "In BlackICE, unit training level has been reworked slightly. \nSame as in Vanilla, Training Laws are responsible for how much starting experience unit has, but what was changed is the speed at which units reinforce.\nPenalties (or bonuses) are now much higher, resulting in much slower Strength regain with Advanced or Specialist Training. As in reality - it takes far longer to get highly trained reinforcements. It might not be possible to keep Specialised or even Advanced Training on for extensive periods of time during war, expecially during long periods of combat.", wx.wxDefaultPosition, wx.wxSize( -1,-1 ), wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp24:Wrap( 370 )

	UI.m_staticTextHelp24:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizerHelp50:Add( UI.m_staticTextHelp24, 0, wx.wxALIGN_CENTER + wx.wxALL, 0 )


	UI.gSizerHelpMisc0:Add( UI.bSizerHelp50, 1, wx.wxEXPAND, 5 )


	UI.gSizerHelpMisc0:Add( 0, 0, 1, wx.wxEXPAND, 5 )


	UI.m_scrolledWindow_HelpMisc:SetSizer( UI.gSizerHelpMisc0 )
	UI.m_scrolledWindow_HelpMisc:Layout()
	UI.gSizerHelpMisc0:Fit( UI.m_scrolledWindow_HelpMisc )
	UI.m_notebook2:AddPage(UI.m_scrolledWindow_HelpMisc, "Misc", True )
	UI.m_scrolledWindow_Ministers = wx.wxScrolledWindow( UI.m_notebook2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxHSCROLL + wx.wxVSCROLL )
	UI.m_scrolledWindow_Ministers:SetScrollRate( 30, 30 )
	UI.bSizerHelp1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticTextHelp1 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "In BlackICE, ministers don't only give flat effects, but they are now also responsible for your country's civilian and war economy.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp1:Wrap( 500 )

	UI.m_staticTextHelp1:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, True, "" ) )

	UI.bSizerHelp1:Add( UI.m_staticTextHelp1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticTextHelp2 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "Depending on your choice of ministers for each position you will gain different types of buildings from time to time which are not normally buildable.\nYou only need one type of minister to get the matching building, but having multiple ministers for the same building increases the amount gained.\nSome ministers also give 2x for certain buildings.\nIf the selected national focus matches the minister the building speed will be doubled.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp2:Wrap( 650 )

	UI.m_staticTextHelp2:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizerHelp1:Add( UI.m_staticTextHelp2, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer38 = wx.wxGridSizer( 0, 3, 0, 0 )

	UI.m_staticTextHelp9 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Smallarms Factory---\n--Army focus--\n2x Infantry Proponent\n2x School of mass combat\n1x Old General\n1x Military Entrepreneur\n1x Guns and butter doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp9:Wrap( -1 )

	UI.m_staticTextHelp9:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp9, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp10 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Artillery Factory---\n--Army focus--\n2x School of fire support\n1x Old General\n1x Military Entrepreneur\n1x Guns and butter doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp10:Wrap( -1 )

	UI.m_staticTextHelp10:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp10, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp11 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Tank Factory---\n--Army focus--\n2x Tank Proponent\n2x Armoured Spearhead Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp11:Wrap( -1 )

	UI.m_staticTextHelp11:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp11, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp18 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Automotive Factory---\n--Army focus--\n2x School of Manoeuvre\n1x Logistics Specialist", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp18:Wrap( -1 )

	UI.m_staticTextHelp18:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp18, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp3 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Light Aircraft Factory---\n--Air focus--\n2x Single Engine Aircraft Proponent\n2x Air Superiority Doctrine\n1x Old Air Marshal\n1x Air Superiority Proponent\n1x Naval Aviation Doctrine\n1x Army Aviation Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp3:Wrap( -1 )

	UI.m_staticTextHelp3:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp3, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp4 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Medium Aircraft Factory---\n--Air focus--\n2x Twin Engine Aircraft Proponent\n2x Vertical Envelopment Doctrine\n1x Naval Aviation Doctrine\n1x Army Aviation Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp4:Wrap( -1 )

	UI.m_staticTextHelp4:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp4, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp5 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Heavy Aircraft Factory---\n--Air focus--\n2x Strategic Air Proponent\n2x Carpet Bombing Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp5:Wrap( -1 )

	UI.m_staticTextHelp5:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp5, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp16 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Radar Station---\n--Air focus--\n2x Air Superiority Proponent", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp16:Wrap( -1 )

	UI.m_staticTextHelp16:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp16, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp12 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Capital Shipyard---\n--Navy focus--\n2x Decisive Naval Battle Doctrine\n1x Old Admiral\n1x Battle fleet proponent", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp12:Wrap( -1 )

	UI.m_staticTextHelp12:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp12, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp13 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Medium Shipyard---\n--Navy focus--\n1x Open Seas Doctrine\n1x Old Admiral\n1x Battle fleet proponent", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp13:Wrap( -1 )

	UI.m_staticTextHelp13:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp13, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp14 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Small Shipyard---\n--Navy focus--\n1x Open Seas Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp14:Wrap( -1 )

	UI.m_staticTextHelp14:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp14, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp15 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Submarine Shipyard---\n--Navy focus--\n2x Submarine Proponent\n2x Indirect Approach Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp15:Wrap( -1 )

	UI.m_staticTextHelp15:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp15, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp7 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Heavy Industry---\n--Economic focus--\n2x Silent Workhorse\n2x Administrative Genius", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp7:Wrap( -1 )

	UI.m_staticTextHelp7:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp7, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp8 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Manufacturing Plant---\n--Economic focus--\n1x Military Entrepreneur\n1x Logistics Specialist", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp8:Wrap( -1 )

	UI.m_staticTextHelp8:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp8, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp20 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Rail Terminous---\n--Economy focus--\n2x Logistics Specialist", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp20:Wrap( -1 )

	UI.m_staticTextHelp20:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp20, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp17 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Research Lab---\n--Science focus--\n2x Theoretical Scientist\n1x Biased Intellectual\n1x Silent Lawyer\n1x Technical Specialist\n3x Research Specialist (only focus)", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp17:Wrap( -1 )

	UI.m_staticTextHelp17:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp17, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp6 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Training Base---\n--Health + Education focus--\n2x General Staffer\n2x School of Psychology", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp6:Wrap( -1 )

	UI.m_staticTextHelp6:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp6, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp21 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Hospital---\n--Health + Education focus--\n2x Man of the People\n1x School of Psychology", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp21:Wrap( -1 )

	UI.m_staticTextHelp21:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp21, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp19 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Resource buildings---\n--Resource focus--\n2x Resource Industrialist", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp19:Wrap( -1 )

	UI.m_staticTextHelp19:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp19, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )


	UI.bSizerHelp1:Add( UI.gSizer38, 1, wx.wxALIGN_CENTER, 5 )


	UI.m_scrolledWindow_Ministers:SetSizer( UI.bSizerHelp1 )
	UI.m_scrolledWindow_Ministers:Layout()
	UI.bSizerHelp1:Fit( UI.m_scrolledWindow_Ministers )
	UI.m_notebook2:AddPage(UI.m_scrolledWindow_Ministers, "Ministers + Buildings", False )
	UI.m_scrolledWindow_EventUnits = wx.wxScrolledWindow( UI.m_notebook2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxHSCROLL + wx.wxVSCROLL )
	UI.m_scrolledWindow_EventUnits:SetScrollRate( 5, 5 )
	UI.bSizerHelp2 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticTextHelp27 = wx.wxStaticText( UI.m_scrolledWindow_EventUnits, wx.wxID_ANY, "Due to game engine limitations, event spawned units are spawned directly on the map instead of in the production queue. ", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp27:Wrap( 500 )

	UI.m_staticTextHelp27:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizerHelp2:Add( UI.m_staticTextHelp27, 0, wx.wxALIGN_CENTER + wx.wxALL, 0 )

	UI.m_staticTextHelp26 = wx.wxStaticText( UI.m_scrolledWindow_EventUnits, wx.wxID_ANY, "Each unit adds its cost to the ICDays variable, which, if it is greater than 1, will activate an IC penalty.\nThat IC penalty represents your countries investment into building those units and each week the ICDays variable gets counted down, scaled to your IC and investment value, until it reaches 0.\nAt that point the penalty will disappear.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp26:Wrap( 650 )

	UI.m_staticTextHelp26:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizerHelp2:Add( UI.m_staticTextHelp26, 0, wx.wxALIGN_CENTER + wx.wxALL, 0 )

	UI.m_staticTextHelp29 = wx.wxStaticText( UI.m_scrolledWindow_EventUnits, wx.wxID_ANY, "\nUnits that will be removed by events will have coloured names.\n", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp29:Wrap( 650 )

	UI.m_staticTextHelp29:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizerHelp2:Add( UI.m_staticTextHelp29, 0, wx.wxALIGN_CENTER + wx.wxALL, 0 )

	UI.m_staticTextHelp28 = wx.wxStaticText( UI.m_scrolledWindow_EventUnits, wx.wxID_ANY, "Event spawned ships will have a dummy unit placed it the production queue. Once you finish it and deploy it on the map you can activate a decision that will replace it with the real ship.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp28:Wrap( 650 )

	UI.m_staticTextHelp28:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizerHelp2:Add( UI.m_staticTextHelp28, 0, wx.wxALIGN_CENTER + wx.wxALL, 0 )


	UI.m_scrolledWindow_EventUnits:SetSizer( UI.bSizerHelp2 )
	UI.m_scrolledWindow_EventUnits:Layout()
	UI.bSizerHelp2:Fit( UI.m_scrolledWindow_EventUnits )
	UI.m_notebook2:AddPage(UI.m_scrolledWindow_EventUnits, "Event Units", False )
	UI.m_scrolledWindow_NatFocus = wx.wxScrolledWindow( UI.m_notebook2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxHSCROLL + wx.wxVSCROLL )
	UI.m_scrolledWindow_NatFocus:SetScrollRate( 30, 30 )
	UI.bSizerHelpNatFocus1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_bitmap4 = wx.wxStaticBitmap( UI.m_scrolledWindow_NatFocus, wx.wxID_ANY, wx.wxBitmap( "tfh/mod/BlackICE-utility-resources/Nat Focus table.png", wx.wxBITMAP_TYPE_ANY ), wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizerHelpNatFocus1:Add( UI.m_bitmap4, 0, wx.wxALL, 5 )


	UI.m_scrolledWindow_NatFocus:SetSizer( UI.bSizerHelpNatFocus1 )
	UI.m_scrolledWindow_NatFocus:Layout()
	UI.bSizerHelpNatFocus1:Fit( UI.m_scrolledWindow_NatFocus )
	UI.m_notebook2:AddPage(UI.m_scrolledWindow_NatFocus, "National Focus", False )


	UI.MyFrame2 .m_mgr:Update()
	UI.MyFrame2:Centre( wx.wxBOTH )

-- create MyFrame3
UI.MyFrame3 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 550,550 ), wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxMAXIMIZE_BOX + wx.wxMINIMIZE_BOX + wx.wxSYSTEM_MENU+wx.wxTAB_TRAVERSAL )
	UI.MyFrame3:SetSizeHints( wx.wxSize( 550,550 ), wx.wxDefaultSize )
	UI.MyFrame3.m_mgr = wxaui.wxAuiManager()
	UI.MyFrame3.m_mgr:SetManagedWindow( UI.MyFrame3 )

	UI.m_notebook3 = wx.wxNotebook( UI.MyFrame3, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxNB_MULTILINE )
	UI.MyFrame3.m_mgr:AddPane( UI.m_notebook3, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):CloseButton( False ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.m_panel_OptionActions = wx.wxPanel( UI.m_notebook3, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_OptionActions1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_textCtrl_OptionActions_Output = wx.wxTextCtrl( UI.m_panel_OptionActions, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_OptionActions_Output:Enable( False )
	UI.m_textCtrl_OptionActions_Output:SetMinSize( wx.wxSize( 400,-1 ) )

	UI.bSizer_OptionActions1:Add( UI.m_textCtrl_OptionActions_Output, 0, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_staticText_OptionActions1 = wx.wxStaticText( UI.m_panel_OptionActions, wx.wxID_ANY, "Here you can find settings to change some GUI elements of the game.\nIn order for the changes to take effect you need to restart the game.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText_OptionActions1:Wrap( -1 )

	UI.bSizer_OptionActions1:Add( UI.m_staticText_OptionActions1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer_OptionActions1 = wx.wxGridSizer( 2, 2, 0, 0 )

	UI.m_button_OptionActions_LeftPopups = wx.wxButton( UI.m_panel_OptionActions, wx.wxID_ANY, "Leftside message popups", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_OptionActions1:Add( UI.m_button_OptionActions_LeftPopups, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionActions_CenterPopups = wx.wxButton( UI.m_panel_OptionActions, wx.wxID_ANY, "Center message popups", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_OptionActions1:Add( UI.m_button_OptionActions_CenterPopups, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionActions_LeftEvents = wx.wxButton( UI.m_panel_OptionActions, wx.wxID_ANY, "Leftside event popups", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_OptionActions1:Add( UI.m_button_OptionActions_LeftEvents, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionActions_CenterEvent = wx.wxButton( UI.m_panel_OptionActions, wx.wxID_ANY, "Center event popups", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_OptionActions1:Add( UI.m_button_OptionActions_CenterEvent, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_OptionActions1:Add( UI.gSizer_OptionActions1, 1, wx.wxEXPAND, 5 )


	UI.m_panel_OptionActions:SetSizer( UI.bSizer_OptionActions1 )
	UI.m_panel_OptionActions:Layout()
	UI.bSizer_OptionActions1:Fit( UI.m_panel_OptionActions )
	UI.m_notebook3:AddPage(UI.m_panel_OptionActions, "Actions", True )


	UI.MyFrame3 .m_mgr:Update()
	UI.MyFrame3:Centre( wx.wxBOTH )

	-- Connect Events

	UI.m_button_OptionActions_LeftPopups:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_OptionActions_LeftPopupsOnButtonClick

	event:Skip()
	end )

	UI.m_button_OptionActions_CenterPopups:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_OptionActions_CenterPopupsOnButtonClick

	event:Skip()
	end )

	UI.m_button_OptionActions_LeftEvents:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_OptionActions_LeftEventsOnButtonClick

	event:Skip()
	end )

	UI.m_button_OptionActions_CenterEvent:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_OptionActions_CenterEventOnButtonClick

	event:Skip()
	end )


-- create MyFrame4
UI.MyFrame4 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "Hoi3 Utility Game Info", wx.wxDefaultPosition, wx.wxSize( 650,600 ), wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxMAXIMIZE_BOX + wx.wxMINIMIZE_BOX + wx.wxRESIZE_BORDER + wx.wxSYSTEM_MENU+wx.wxTAB_TRAVERSAL )
	UI.MyFrame4:SetSizeHints( wx.wxSize( 650,600 ), wx.wxDefaultSize )
	UI.MyFrame4.m_mgr = wxaui.wxAuiManager()
	UI.MyFrame4.m_mgr:SetManagedWindow( UI.MyFrame4 )

	UI.m_notebook5 = wx.wxNotebook( UI.MyFrame4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,100 ), wx.wxNB_MULTILINE )
	UI.MyFrame4.m_mgr:AddPane( UI.m_notebook5, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):CloseButton( False ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.m_panel_GameInfo_Traits = wx.wxPanel( UI.m_notebook5, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_GameInfo1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_choice_TraitsChoices = {}
	UI.m_choice_Traits = wx.wxChoice( UI.m_panel_GameInfo_Traits, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 350,-1 ), UI.m_choice_TraitsChoices, 0 )
	UI.m_choice_Traits:SetSelection( 0 )
	UI.bSizer_GameInfo1:Add( UI.m_choice_Traits, 0, wx.wxALL + wx.wxEXPAND, 5 )

	UI.gSizer_GameInfo_Traits1 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.fgSizer_GameInfo_Traits1 = wx.wxFlexGridSizer( 2, 1, 0, 0 )
	UI.fgSizer_GameInfo_Traits1:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Traits1:AddGrowableRow( 1 )
	UI.fgSizer_GameInfo_Traits1:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Traits1:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_GameInfo_Traits1 = wx.wxStaticText( UI.m_panel_GameInfo_Traits, wx.wxID_ANY, "Triggers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Traits1:Wrap( -1 )

	UI.fgSizer_GameInfo_Traits1:Add( UI.m_staticText_GameInfo_Traits1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_Traits_Triggers = wx.wxTextCtrl( UI.m_panel_GameInfo_Traits, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE )
	UI.fgSizer_GameInfo_Traits1:Add( UI.m_textCtrl_GameInfo_Traits_Triggers, 0, wx.wxALL + wx.wxEXPAND, 5 )


	UI.gSizer_GameInfo_Traits1:Add( UI.fgSizer_GameInfo_Traits1, 1, wx.wxEXPAND, 5 )

	UI.fgSizer_GameInfo_Traits2 = wx.wxFlexGridSizer( 2, 1, 0, 0 )
	UI.fgSizer_GameInfo_Traits2:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Traits2:AddGrowableRow( 1 )
	UI.fgSizer_GameInfo_Traits2:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Traits2:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_GameInfo_Traits3 = wx.wxStaticText( UI.m_panel_GameInfo_Traits, wx.wxID_ANY, "Effects", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Traits3:Wrap( -1 )

	UI.fgSizer_GameInfo_Traits2:Add( UI.m_staticText_GameInfo_Traits3, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_Traits_Effects = wx.wxTextCtrl( UI.m_panel_GameInfo_Traits, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE )
	UI.fgSizer_GameInfo_Traits2:Add( UI.m_textCtrl_GameInfo_Traits_Effects, 0, wx.wxALL + wx.wxEXPAND, 5 )


	UI.gSizer_GameInfo_Traits1:Add( UI.fgSizer_GameInfo_Traits2, 1, wx.wxEXPAND, 5 )


	UI.bSizer_GameInfo1:Add( UI.gSizer_GameInfo_Traits1, 1, wx.wxEXPAND, 5 )


	UI.m_panel_GameInfo_Traits:SetSizer( UI.bSizer_GameInfo1 )
	UI.m_panel_GameInfo_Traits:Layout()
	UI.bSizer_GameInfo1:Fit( UI.m_panel_GameInfo_Traits )
	UI.m_notebook5:AddPage(UI.m_panel_GameInfo_Traits, "Traits", True )
	UI.m_panel_GameInfo_Generals = wx.wxPanel( UI.m_notebook5, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_GameInfo2 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_choice_GeneralsChoices = {}
	UI.m_choice_Generals = wx.wxChoice( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 350,-1 ), UI.m_choice_GeneralsChoices, 0 )
	UI.m_choice_Generals:SetSelection( 0 )
	UI.bSizer_GameInfo2:Add( UI.m_choice_Generals, 0, wx.wxALL + wx.wxEXPAND, 5 )

	UI.gSizer_Generals_1 = wx.wxGridSizer( 1, 4, 0, 0 )

	UI.m_radioBtn_Generals_all = wx.wxRadioButton( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "all", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_radioBtn_Generals_all:SetValue( True )
	UI.gSizer_Generals_1:Add( UI.m_radioBtn_Generals_all, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_radioBtn_Generals_land = wx.wxRadioButton( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "land", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Generals_1:Add( UI.m_radioBtn_Generals_land, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_radioBtn_Generals_sea = wx.wxRadioButton( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "sea", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Generals_1:Add( UI.m_radioBtn_Generals_sea, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_radioBtn_Generals_air = wx.wxRadioButton( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "air", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_Generals_1:Add( UI.m_radioBtn_Generals_air, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_GameInfo2:Add( UI.gSizer_Generals_1, 0, wx.wxEXPAND, 5 )

	UI.m_textCtrl_Generals = wx.wxTextCtrl( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( -1,-1 ), wx.wxTE_MULTILINE + wx.wxTE_WORDWRAP )
	UI.m_textCtrl_Generals:SetMinSize( wx.wxSize( -1,395 ) )

	UI.bSizer_GameInfo2:Add( UI.m_textCtrl_Generals, 1, wx.wxALL + wx.wxEXPAND, 5 )


	UI.m_panel_GameInfo_Generals:SetSizer( UI.bSizer_GameInfo2 )
	UI.m_panel_GameInfo_Generals:Layout()
	UI.bSizer_GameInfo2:Fit( UI.m_panel_GameInfo_Generals )
	UI.m_notebook5:AddPage(UI.m_panel_GameInfo_Generals, "Generals", False )
	UI.m_panel_GameInfo_Tech = wx.wxPanel( UI.m_notebook5, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_GameInfo3 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.fgSizer_GameInfo_Techs_3 = wx.wxFlexGridSizer( 1, 3, 0, 0 )
	UI.fgSizer_GameInfo_Techs_3:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Techs_3:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Techs_3:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_choice_GameInfo_TechsChoices = {}
	UI.m_choice_GameInfo_Techs = wx.wxChoice( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 350,-1 ), UI.m_choice_GameInfo_TechsChoices, 0 )
	UI.m_choice_GameInfo_Techs:SetSelection( 0 )
	UI.fgSizer_GameInfo_Techs_3:Add( UI.m_choice_GameInfo_Techs, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_textCtrl_GameInfo_Techs_Filter = wx.wxTextCtrl( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "name filter (press enter)", wx.wxDefaultPosition, wx.wxSize( 135,-1 ), 0 )
	UI.fgSizer_GameInfo_Techs_3:Add( UI.m_textCtrl_GameInfo_Techs_Filter, 1, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_button_GameInfo_Techs_Filter_Clear = wx.wxButton( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "Clear", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.fgSizer_GameInfo_Techs_3:Add( UI.m_button_GameInfo_Techs_Filter_Clear, 0, wx.wxALL, 5 )


	UI.bSizer_GameInfo3:Add( UI.fgSizer_GameInfo_Techs_3, 0, wx.wxEXPAND, 5 )

	UI.gSizer_GameInfo_Techs_1 = wx.wxGridSizer( 1, 5, 0, 0 )

	UI.m_staticText_GameInfo_Techs_1 = wx.wxStaticText( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "Your level", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Techs_1:Wrap( -1 )

	UI.gSizer_GameInfo_Techs_1:Add( UI.m_staticText_GameInfo_Techs_1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_Techs_PlayerLevel = wx.wxTextCtrl( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_GameInfo_Techs_PlayerLevel:Enable( False )

	UI.gSizer_GameInfo_Techs_1:Add( UI.m_textCtrl_GameInfo_Techs_PlayerLevel, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_GameInfo_Techs_2 = wx.wxStaticText( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "Shown level", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Techs_2:Wrap( -1 )

	UI.gSizer_GameInfo_Techs_1:Add( UI.m_staticText_GameInfo_Techs_2, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_Techs_LevelShown = wx.wxTextCtrl( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_GameInfo_Techs_LevelShown:Enable( False )

	UI.gSizer_GameInfo_Techs_1:Add( UI.m_textCtrl_GameInfo_Techs_LevelShown, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer47 = wx.wxGridSizer( 0, 2, 0, 0 )

	UI.m_button_GameInfo_Tech_increase = wx.wxButton( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "+", wx.wxDefaultPosition, wx.wxSize( 25,-1 ), 0 )
	UI.gSizer47:Add( UI.m_button_GameInfo_Tech_increase, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_GameInfo_Tech_decrease = wx.wxButton( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "-", wx.wxDefaultPosition, wx.wxSize( 25,-1 ), 0 )
	UI.gSizer47:Add( UI.m_button_GameInfo_Tech_decrease, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizer_GameInfo_Techs_1:Add( UI.gSizer47, 0, wx.wxEXPAND, 5 )


	UI.bSizer_GameInfo3:Add( UI.gSizer_GameInfo_Techs_1, 0, wx.wxEXPAND, 5 )

	UI.gSizer_GameInfo_Techs_2 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.fgSizer_GameInfo_Techs_1 = wx.wxFlexGridSizer( 2, 1, 0, 0 )
	UI.fgSizer_GameInfo_Techs_1:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Techs_1:AddGrowableRow( 1 )
	UI.fgSizer_GameInfo_Techs_1:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Techs_1:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_GameInfo_Techs_3 = wx.wxStaticText( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "Triggers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Techs_3:Wrap( -1 )

	UI.fgSizer_GameInfo_Techs_1:Add( UI.m_staticText_GameInfo_Techs_3, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_Techs_Triggers = wx.wxTextCtrl( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE )
	UI.fgSizer_GameInfo_Techs_1:Add( UI.m_textCtrl_GameInfo_Techs_Triggers, 1, wx.wxALL + wx.wxEXPAND, 5 )


	UI.gSizer_GameInfo_Techs_2:Add( UI.fgSizer_GameInfo_Techs_1, 1, wx.wxEXPAND, 5 )

	UI.fgSizer_GameInfo_Techs_2 = wx.wxFlexGridSizer( 2, 1, 0, 0 )
	UI.fgSizer_GameInfo_Techs_2:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Techs_2:AddGrowableRow( 1 )
	UI.fgSizer_GameInfo_Techs_2:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Techs_2:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_GameInfo_Techs_5 = wx.wxStaticText( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "Effects", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Techs_5:Wrap( -1 )

	UI.fgSizer_GameInfo_Techs_2:Add( UI.m_staticText_GameInfo_Techs_5, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_Techs_Effects = wx.wxTextCtrl( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE )
	UI.fgSizer_GameInfo_Techs_2:Add( UI.m_textCtrl_GameInfo_Techs_Effects, 1, wx.wxALL + wx.wxEXPAND, 5 )


	UI.gSizer_GameInfo_Techs_2:Add( UI.fgSizer_GameInfo_Techs_2, 1, wx.wxEXPAND, 5 )


	UI.bSizer_GameInfo3:Add( UI.gSizer_GameInfo_Techs_2, 1, wx.wxEXPAND, 5 )


	UI.m_panel_GameInfo_Tech:SetSizer( UI.bSizer_GameInfo3 )
	UI.m_panel_GameInfo_Tech:Layout()
	UI.bSizer_GameInfo3:Fit( UI.m_panel_GameInfo_Tech )
	UI.m_notebook5:AddPage(UI.m_panel_GameInfo_Tech, "Techs", False )
	UI.m_panel_GameInfo_Modifiers = wx.wxPanel( UI.m_notebook5, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_GameInfo_Modifiers1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.fgSizer_GameInfo_Modifiers1 = wx.wxFlexGridSizer( 1, 3, 0, 0 )
	UI.fgSizer_GameInfo_Modifiers1:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Modifiers1:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Modifiers1:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_choice_GameInfo_Modifiers1Choices = {}
	UI.m_choice_GameInfo_Modifiers1 = wx.wxChoice( UI.m_panel_GameInfo_Modifiers, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 300,-1 ), UI.m_choice_GameInfo_Modifiers1Choices, 0 )
	UI.m_choice_GameInfo_Modifiers1:SetSelection( 0 )
	UI.fgSizer_GameInfo_Modifiers1:Add( UI.m_choice_GameInfo_Modifiers1, 5, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_textCtrl_GameInfo_Modifiers_Filter = wx.wxTextCtrl( UI.m_panel_GameInfo_Modifiers, wx.wxID_ANY, "name filter (press enter)", wx.wxDefaultPosition, wx.wxSize( 135,-1 ), 0 )
	UI.fgSizer_GameInfo_Modifiers1:Add( UI.m_textCtrl_GameInfo_Modifiers_Filter, 1, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_button_GameInfo_Modifiers_Filter_Clear = wx.wxButton( UI.m_panel_GameInfo_Modifiers, wx.wxID_ANY, "Clear", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.fgSizer_GameInfo_Modifiers1:Add( UI.m_button_GameInfo_Modifiers_Filter_Clear, 0, wx.wxALL, 5 )


	UI.bSizer_GameInfo_Modifiers1:Add( UI.fgSizer_GameInfo_Modifiers1, 0, wx.wxEXPAND, 5 )

	UI.gSizer_GameInfo_Modifiers1 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.fgSizer_GameInfo_Modifiers2 = wx.wxFlexGridSizer( 2, 1, 0, 0 )
	UI.fgSizer_GameInfo_Modifiers2:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Modifiers2:AddGrowableRow( 1 )
	UI.fgSizer_GameInfo_Modifiers2:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Modifiers2:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_GameInfo_Modifiers1 = wx.wxStaticText( UI.m_panel_GameInfo_Modifiers, wx.wxID_ANY, "Triggers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Modifiers1:Wrap( -1 )

	UI.fgSizer_GameInfo_Modifiers2:Add( UI.m_staticText_GameInfo_Modifiers1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_Modifiers_Triggers1 = wx.wxTextCtrl( UI.m_panel_GameInfo_Modifiers, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE )
	UI.fgSizer_GameInfo_Modifiers2:Add( UI.m_textCtrl_GameInfo_Modifiers_Triggers1, 0, wx.wxALL + wx.wxEXPAND, 5 )


	UI.gSizer_GameInfo_Modifiers1:Add( UI.fgSizer_GameInfo_Modifiers2, 1, wx.wxEXPAND, 5 )

	UI.fgSizer_GameInfo_Modifiers3 = wx.wxFlexGridSizer( 2, 1, 0, 0 )
	UI.fgSizer_GameInfo_Modifiers3:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Modifiers3:AddGrowableRow( 1 )
	UI.fgSizer_GameInfo_Modifiers3:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Modifiers3:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_GameInfo_Modifiers3 = wx.wxStaticText( UI.m_panel_GameInfo_Modifiers, wx.wxID_ANY, "Effects", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Modifiers3:Wrap( -1 )

	UI.fgSizer_GameInfo_Modifiers3:Add( UI.m_staticText_GameInfo_Modifiers3, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_Modifiers_Effects1 = wx.wxTextCtrl( UI.m_panel_GameInfo_Modifiers, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE )
	UI.fgSizer_GameInfo_Modifiers3:Add( UI.m_textCtrl_GameInfo_Modifiers_Effects1, 0, wx.wxALL + wx.wxEXPAND, 5 )


	UI.gSizer_GameInfo_Modifiers1:Add( UI.fgSizer_GameInfo_Modifiers3, 1, wx.wxEXPAND, 5 )


	UI.bSizer_GameInfo_Modifiers1:Add( UI.gSizer_GameInfo_Modifiers1, 1, wx.wxEXPAND, 5 )


	UI.m_panel_GameInfo_Modifiers:SetSizer( UI.bSizer_GameInfo_Modifiers1 )
	UI.m_panel_GameInfo_Modifiers:Layout()
	UI.bSizer_GameInfo_Modifiers1:Fit( UI.m_panel_GameInfo_Modifiers )
	UI.m_notebook5:AddPage(UI.m_panel_GameInfo_Modifiers, "Modifiers", False )


	UI.MyFrame4 .m_mgr:Update()
	UI.MyFrame4:Centre( wx.wxBOTH )

	-- Connect Events

	UI.m_choice_Traits:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
	--implements m_choice_TraitsOnChoice

	event:Skip()
	end )

	UI.m_choice_Generals:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
	--implements m_choice_GeneralsOnChoice

	event:Skip()
	end )

	UI.m_radioBtn_Generals_all:Connect( wx.wxEVT_COMMAND_RADIOBUTTON_SELECTED, function(event)
	--implements m_radioBtn_Generals_allOnRadioButton

	event:Skip()
	end )

	UI.m_radioBtn_Generals_land:Connect( wx.wxEVT_COMMAND_RADIOBUTTON_SELECTED, function(event)
	--implements m_radioBtn_Generals_landOnRadioButton

	event:Skip()
	end )

	UI.m_radioBtn_Generals_sea:Connect( wx.wxEVT_COMMAND_RADIOBUTTON_SELECTED, function(event)
	--implements m_radioBtn_Generals_seaOnRadioButton

	event:Skip()
	end )

	UI.m_radioBtn_Generals_air:Connect( wx.wxEVT_COMMAND_RADIOBUTTON_SELECTED, function(event)
	--implements m_radioBtn_Generals_airOnRadioButton

	event:Skip()
	end )

	UI.m_choice_GameInfo_Techs:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
	--implements m_choice_GameInfo_TechsOnChoice

	event:Skip()
	end )

	UI.m_textCtrl_GameInfo_Techs_Filter:Connect( wx.wxEVT_COMMAND_TEXT_ENTER, function(event)
	--implements m_textCtrl_GameInfo_Techs_FilterOnTextEnter

	event:Skip()
	end )

	UI.m_button_GameInfo_Techs_Filter_Clear:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_GameInfo_Techs_Filter_ClearOnButtonClick

	event:Skip()
	end )

	UI.m_button_GameInfo_Tech_increase:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_GameInfo_Tech_increaseOnButtonClick

	event:Skip()
	end )

	UI.m_button_GameInfo_Tech_decrease:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_GameInfo_Tech_decreaseOnButtonClick

	event:Skip()
	end )

	UI.m_choice_GameInfo_Modifiers1:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
	--implements m_choice_GameInfo_Modifiers1OnChoice

	event:Skip()
	end )

	UI.m_textCtrl_GameInfo_Modifiers_Filter:Connect( wx.wxEVT_COMMAND_TEXT_ENTER, function(event)
	--implements m_textCtrl_GameInfo_Modifiers_FilterOnTextEnter

	event:Skip()
	end )

	UI.m_button_GameInfo_Modifiers_Filter_Clear:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_GameInfo_Modifiers_Filter_ClearOnButtonClick

	event:Skip()
	end )


-- create MyFrame5
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

	-- Connect Events

	UI.m_button_Statistics_setup_toggle:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_Statistics_setup_toggleOnButtonClick

	event:Skip()
	end )

	UI.m_button_Statistics_setup_toggle_custom_list:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_Statistics_setup_toggle_custom_listOnButtonClick

	event:Skip()
	end )

	UI.m_button_Statistics_setup_add:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_Statistics_setup_addOnButtonClick

	event:Skip()
	end )

	UI.m_button_Statistics_setup_remove:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_Statistics_setup_removeOnButtonClick

	event:Skip()
	end )

	UI.m_button_Statistics_main_add:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_Statistics_main_addOnButtonClick

	event:Skip()
	end )

	UI.m_button_Statistics_main_remove:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_Statistics_main_removeOnButtonClick

	event:Skip()
	end )

	UI.m_button_Statistics_main_plot:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_Statistics_main_plotOnButtonClick

	event:Skip()
	end )



--wx.wxGetApp():MainLoop()
