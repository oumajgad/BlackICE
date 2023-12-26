package.cpath = package.cpath..";./tfh/mod/?.dll;"
require("wx")


-- UI = {}

if wx ~= nil then
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

	UI.fgSizer_GameInfo_Traits1 = wx.wxFlexGridSizer( 3, 1, 0, 0 )
	UI.fgSizer_GameInfo_Traits1:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Traits1:AddGrowableRow( 1 )
	UI.fgSizer_GameInfo_Traits1:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Traits1:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_GameInfo_Traits1 = wx.wxStaticText( UI.m_panel_GameInfo_Traits, wx.wxID_ANY, "Triggers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Traits1:Wrap( -1 )

	UI.fgSizer_GameInfo_Traits1:Add( UI.m_staticText_GameInfo_Traits1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_Traits_Triggers = wx.wxTextCtrl( UI.m_panel_GameInfo_Traits, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE )
	UI.fgSizer_GameInfo_Traits1:Add( UI.m_textCtrl_GameInfo_Traits_Triggers, 0, wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_staticText_GameInfo_Traits2 = wx.wxStaticText( UI.m_panel_GameInfo_Traits, wx.wxID_ANY, "Note that triggers may be combined. E.g. 2 \"OR\" clauses can be combined and show as 1 clause with multiple grouped conditions. This only happens if the 2 clauses are identical in the code, i.e.: \"or\" and \"OR\" will not be combined.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Traits2:Wrap( 230 )

	UI.fgSizer_GameInfo_Traits1:Add( UI.m_staticText_GameInfo_Traits2, 0, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )


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

	UI.fgSizer_GameInfo_Techs_1 = wx.wxFlexGridSizer( 3, 1, 0, 0 )
	UI.fgSizer_GameInfo_Techs_1:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Techs_1:AddGrowableRow( 1 )
	UI.fgSizer_GameInfo_Techs_1:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Techs_1:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_GameInfo_Techs_3 = wx.wxStaticText( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "Triggers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Techs_3:Wrap( -1 )

	UI.fgSizer_GameInfo_Techs_1:Add( UI.m_staticText_GameInfo_Techs_3, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_Techs_Triggers = wx.wxTextCtrl( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE )
	UI.fgSizer_GameInfo_Techs_1:Add( UI.m_textCtrl_GameInfo_Techs_Triggers, 1, wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_staticText_GameInfo_Techs_4 = wx.wxStaticText( UI.m_panel_GameInfo_Tech, wx.wxID_ANY, "Note that triggers may be combined. E.g. 2 \"OR\" clauses can be combined and show as 1 clause with multiple grouped conditions. This only happens if the 2 clauses are identical in the code, i.e.: \"or\" and \"OR\" will not be combined.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Techs_4:Wrap( 230 )

	UI.fgSizer_GameInfo_Techs_1:Add( UI.m_staticText_GameInfo_Techs_4, 0, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )


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

	UI.fgSizer_GameInfo_Modifiers2 = wx.wxFlexGridSizer( 3, 1, 0, 0 )
	UI.fgSizer_GameInfo_Modifiers2:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Modifiers2:AddGrowableRow( 1 )
	UI.fgSizer_GameInfo_Modifiers2:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Modifiers2:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_GameInfo_Modifiers1 = wx.wxStaticText( UI.m_panel_GameInfo_Modifiers, wx.wxID_ANY, "Triggers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Modifiers1:Wrap( -1 )

	UI.fgSizer_GameInfo_Modifiers2:Add( UI.m_staticText_GameInfo_Modifiers1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_Modifiers_Triggers1 = wx.wxTextCtrl( UI.m_panel_GameInfo_Modifiers, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE )
	UI.fgSizer_GameInfo_Modifiers2:Add( UI.m_textCtrl_GameInfo_Modifiers_Triggers1, 0, wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_staticText_GameInfo_Modifiers2 = wx.wxStaticText( UI.m_panel_GameInfo_Modifiers, wx.wxID_ANY, "Note that triggers may be combined. E.g. 2 \"OR\" clauses can be combined and show as 1 clause with multiple grouped conditions. This only happens if the 2 clauses are identical in the code, i.e.: \"or\" and \"OR\" will not be combined.", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Modifiers2:Wrap( 230 )

	UI.fgSizer_GameInfo_Modifiers2:Add( UI.m_staticText_GameInfo_Modifiers2, 0, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )


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

	UI.MyFrame4:Show(false)
	-- Connect Events

    UI.m_choice_Traits:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
        local selectionString = UI.m_choice_Traits:GetString(UI.m_choice_Traits:GetSelection())
		Parsing.Traits.HandleSelection(selectionString)
    end )

	UI.m_choice_Generals:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
        local selectionString = UI.m_choice_Generals:GetString(UI.m_choice_Generals:GetSelection())
		local generalId = Parsing.GetKeyFromChoice(selectionString)
		local general = Parsing.Generals.CountryGeneralsData[generalId]
		if general ~= nil then
			local s = Utils.Dump(general)
			UI.m_textCtrl_Generals:SetValue(s)
		end
	end )

	UI.m_radioBtn_Generals_all:Connect( wx.wxEVT_COMMAND_RADIOBUTTON_SELECTED, function(event)
		if PlayerCountry ~= nil then
			Parsing.Generals.FillwxChoice(PlayerCountry)
			UI.m_textCtrl_Generals:Clear()
		end
	end )

	UI.m_radioBtn_Generals_land:Connect( wx.wxEVT_COMMAND_RADIOBUTTON_SELECTED, function(event)
		if PlayerCountry ~= nil then
			Parsing.Generals.FillwxChoice(PlayerCountry)
			UI.m_textCtrl_Generals:Clear()
		end
	end )

	UI.m_radioBtn_Generals_sea:Connect( wx.wxEVT_COMMAND_RADIOBUTTON_SELECTED, function(event)
		if PlayerCountry ~= nil then
			Parsing.Generals.FillwxChoice(PlayerCountry)
			UI.m_textCtrl_Generals:Clear()
		end
	end )

	UI.m_radioBtn_Generals_air:Connect( wx.wxEVT_COMMAND_RADIOBUTTON_SELECTED, function(event)
		if PlayerCountry ~= nil then
			Parsing.Generals.FillwxChoice(PlayerCountry)
			UI.m_textCtrl_Generals:Clear()
		end
	end )

	UI.m_choice_GameInfo_Techs:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
		Parsing.Techs.HandleSelection()
	end )

	UI.m_textCtrl_GameInfo_Techs_Filter:Connect( wx.wxEVT_COMMAND_TEXT_ENTER, function(event)
		Parsing.Techs.HandleFilter()
	end )

	UI.m_button_GameInfo_Techs_Filter_Clear:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		UI.m_textCtrl_GameInfo_Techs_Filter:SetValue("")
		Parsing.Techs.HandleFilter()
	end )

	UI.m_button_GameInfo_Tech_increase:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		local currentShownLevel = tonumber(UI.m_textCtrl_GameInfo_Techs_LevelShown:GetValue())
		Parsing.Techs.HandleSelection(currentShownLevel + 1)
	end )

	UI.m_button_GameInfo_Tech_decrease:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		local currentShownLevel = tonumber(UI.m_textCtrl_GameInfo_Techs_LevelShown:GetValue())
		if currentShownLevel > 1 then
			Parsing.Techs.HandleSelection(currentShownLevel - 1)
		end
	end )
	UI.m_choice_GameInfo_Modifiers1:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
		Parsing.Modifiers.HandleSelection()
	end )

	UI.m_textCtrl_GameInfo_Modifiers_Filter:Connect( wx.wxEVT_COMMAND_TEXT_ENTER, function(event)
		Parsing.Modifiers.HandleFilter()
	end )

	UI.m_button_GameInfo_Modifiers_Filter_Clear:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		UI.m_textCtrl_GameInfo_Modifiers_Filter:SetValue("")
		Parsing.Modifiers.HandleFilter()
	end )
end
