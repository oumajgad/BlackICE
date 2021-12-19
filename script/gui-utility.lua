
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

	UI.m_staticText41 = wx.wxStaticText( UI.m_panel_Setup, wx.wxID_ANY, "1. Start a game.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
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

	UI.m_textCtrl6 = wx.wxTextCtrl( UI.m_panel_Setup, wx.wxID_ANY, "10", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
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
	UI.gSizer2 = wx.wxGridSizer( 5, 2, 0, 0 )

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

	UI.m_staticText34 = wx.wxStaticText( UI.m_panel_C_Info, wx.wxID_ANY, "War exhaustion", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText34:Wrap( -1 )

	UI.gSizer2:Add( UI.m_staticText34, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_WarExhaustion = wx.wxTextCtrl( UI.m_panel_C_Info, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_WarExhaustion:Enable( False )

	UI.gSizer2:Add( UI.m_textCtrl_WarExhaustion, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


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
	UI.gSizer6 = wx.wxGridSizer( 10, 4, 0, 0 )

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

	UI.m_staticText33 = wx.wxStaticText( UI.m_panelStratResources, wx.wxID_ANY, "Molybdenum", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
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


	UI.m_panelStratResources:SetSizer( UI.gSizer6 )
	UI.m_panelStratResources:Layout()
	UI.gSizer6:Fit( UI.m_panelStratResources )
	UI.m_notebook4:AddPage(UI.m_panelStratResources, "Strat. Res.", False )
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

	UI.gSizer8 = wx.wxGridSizer( 2, 3, 0, 0 )

	UI.m_button_ICInvest_10 = wx.wxButton( UI.m_panel_IC, wx.wxID_ANY, "10%", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer8:Add( UI.m_button_ICInvest_10, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

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
	UI.m_panel_Misc = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.gSizer4 = wx.wxGridSizer( 3, 4, 0, 0 )

	UI.m_staticText15 = wx.wxStaticText( UI.m_panel_Misc, wx.wxID_ANY, "Daily building and resource counts.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
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
		if UI.player_choice:GetSelection() >= 0 then
			PlayerCountry = UI.player_choice:GetString(UI.player_choice:GetSelection())
			UI.m_textCtrl3:SetValue("Country set to " .. PlayerCountry)

			-- Things to run when a country is selected
			SetTradeDecisionHiddenText()
			SetMinesDecisionHiddenText()
			SetICPanelTexts()
			DetermineICInvestmentValue()
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

	UI.m_button_TradeDecisionShow:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		ToggleTradeDecisions(false)
	end )

	UI.m_button_TradeDecisionHide:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		ToggleTradeDecisions(true)
	end )

	UI.m_button_MinesDecisionShow:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		ToggleMinesDecisions(false)
	end )

	UI.m_button_MinesDecisionHide:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		ToggleMinesDecisions(true)
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

	UI.m_buttonRemoveSprites:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)

		if SaveLoaded == nil then
			os.execute("mkdir gfx\\anims\\backup" )
			os.execute("for %x in (gfx/anims/*) do (if not %x == Thumbs.db if not %x == GenericTankDiffuse.dds if not %x == GenericTankSpecular.dds if not %x == GenericTank.xac if not %x == TankIdleA.xsm (move gfx\\anims\\%x gfx\\anims\\backup\\) )")
		end
    end )

	UI.m_buttonRestoreSprites:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)

		if SaveLoaded == nil then
			os.execute("for %x in (gfx/anims/backup/*) do (move gfx\\anims\\backup\\%x gfx\\anims\\ )")
		end
	end )

	UI.m_button_ICInvest_10:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		SetICInvestmentValue(10)
	end )

	UI.m_button_ICInvest_20:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		SetICInvestmentValue(20)
	end )

	UI.m_button_ICInvest_30:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		SetICInvestmentValue(30)
	end )

	UI.m_button_ICInvest_40:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		SetICInvestmentValue(40)
	end )

	UI.m_button_ICInvest_50:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		SetICInvestmentValue(50)
	end )

	UI.m_button_ICInvest_60:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		SetICInvestmentValue(60)
	end )

	UI.MyFrame1:Show(true)

end