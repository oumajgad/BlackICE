require("wx")

local True = true
local False = false

if wx ~= nil then
	UI.MyFrame4 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "Hoi3 Utility Game Info", wx.wxDefaultPosition, wx.wxSize( 650,600 ), wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxMAXIMIZE_BOX + wx.wxMINIMIZE_BOX + wx.wxRESIZE_BORDER + wx.wxSYSTEM_MENU+wx.wxTAB_TRAVERSAL )
	UI.MyFrame4:SetSizeHints( wx.wxSize( 650,600 ), wx.wxDefaultSize )
	UI.MyFrame4.m_mgr = wxaui.wxAuiManager()
	UI.MyFrame4.m_mgr:SetManagedWindow( UI.MyFrame4 )

	UI.m_notebook5 = wx.wxNotebook( UI.MyFrame4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,100 ), wx.wxNB_MULTILINE )
	UI.MyFrame4.m_mgr:AddPane( UI.m_notebook5, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):CloseButton( False ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.m_panel_GameInfo_Traits = wx.wxPanel( UI.m_notebook5, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_GameInfo1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.fgSizer_GameInfo_Traits3 = wx.wxFlexGridSizer( 1, 3, 0, 0 )
	UI.fgSizer_GameInfo_Traits3:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Traits3:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Traits3:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_choice_GameInfo_TraitsChoices = {}
	UI.m_choice_GameInfo_Traits = wx.wxChoice( UI.m_panel_GameInfo_Traits, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 350,-1 ), UI.m_choice_GameInfo_TraitsChoices, 0 )
	UI.m_choice_GameInfo_Traits:SetSelection( 0 )
	UI.fgSizer_GameInfo_Traits3:Add( UI.m_choice_GameInfo_Traits, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_textCtrl_GameInfo_Traits_Filter = wx.wxTextCtrl( UI.m_panel_GameInfo_Traits, wx.wxID_ANY, "name filter (press enter)", wx.wxDefaultPosition, wx.wxSize( 135,-1 ), 0 )
	UI.fgSizer_GameInfo_Traits3:Add( UI.m_textCtrl_GameInfo_Traits_Filter, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_GameInfo_Traits_Filter_Clear = wx.wxButton( UI.m_panel_GameInfo_Traits, wx.wxID_ANY, "Clear", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.fgSizer_GameInfo_Traits3:Add( UI.m_button_GameInfo_Traits_Filter_Clear, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_GameInfo1:Add( UI.fgSizer_GameInfo_Traits3, 0, wx.wxEXPAND, 5 )

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

	UI.fgSizer_GameInfo_Generals_1 = wx.wxFlexGridSizer( 1, 3, 0, 0 )
	UI.fgSizer_GameInfo_Generals_1:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Generals_1:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Generals_1:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_choice_GameInfo_GeneralsChoices = {}
	UI.m_choice_GameInfo_Generals = wx.wxChoice( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 350,-1 ), UI.m_choice_GameInfo_GeneralsChoices, 0 )
	UI.m_choice_GameInfo_Generals:SetSelection( 0 )
	UI.fgSizer_GameInfo_Generals_1:Add( UI.m_choice_GameInfo_Generals, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_textCtrl_GameInfo_Generals_Filter = wx.wxTextCtrl( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "name filter (press enter)", wx.wxDefaultPosition, wx.wxSize( 135,-1 ), 0 )
	UI.fgSizer_GameInfo_Generals_1:Add( UI.m_textCtrl_GameInfo_Generals_Filter, 0, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_button_GameInfo_Generals_Filter_Clear = wx.wxButton( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "Clear", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.fgSizer_GameInfo_Generals_1:Add( UI.m_button_GameInfo_Generals_Filter_Clear, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_GameInfo2:Add( UI.fgSizer_GameInfo_Generals_1, 0, wx.wxEXPAND, 5 )

	UI.gSizer_GameInfo_Generals_1 = wx.wxGridSizer( 1, 4, 0, 0 )

	UI.m_radioBtn_Generals_all = wx.wxRadioButton( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "all", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_radioBtn_Generals_all:SetValue( True )
	UI.gSizer_GameInfo_Generals_1:Add( UI.m_radioBtn_Generals_all, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_radioBtn_Generals_land = wx.wxRadioButton( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "land", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_GameInfo_Generals_1:Add( UI.m_radioBtn_Generals_land, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_radioBtn_Generals_sea = wx.wxRadioButton( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "sea", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_GameInfo_Generals_1:Add( UI.m_radioBtn_Generals_sea, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_radioBtn_Generals_air = wx.wxRadioButton( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "air", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_GameInfo_Generals_1:Add( UI.m_radioBtn_Generals_air, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_GameInfo2:Add( UI.gSizer_GameInfo_Generals_1, 0, wx.wxEXPAND, 5 )

	UI.gSizer_GameInfo_Generals_2 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.m_textCtrl_Generals = wx.wxTextCtrl( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( -1,-1 ), wx.wxTE_MULTILINE + wx.wxTE_WORDWRAP )
	UI.m_textCtrl_Generals:SetMinSize( wx.wxSize( -1,395 ) )

	UI.gSizer_GameInfo_Generals_2:Add( UI.m_textCtrl_Generals, 1, wx.wxALL + wx.wxEXPAND, 5 )

	UI.fgSizer12 = wx.wxFlexGridSizer( 3, 1, 0, 0 )
	UI.fgSizer12:AddGrowableCol( 0 )
	UI.fgSizer12:AddGrowableRow( 2 )
	UI.fgSizer12:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer12:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_GameInfo_Generals_1 = wx.wxStaticText( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "Traits", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Generals_1:Wrap( -1 )

	UI.fgSizer12:Add( UI.m_staticText_GameInfo_Generals_1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_choice_GameInfo_Generals_TraitsChoices = {}
	UI.m_choice_GameInfo_Generals_Traits = wx.wxChoice( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, UI.m_choice_GameInfo_Generals_TraitsChoices, 0 )
	UI.m_choice_GameInfo_Generals_Traits:SetSelection( 0 )
	UI.m_choice_GameInfo_Generals_Traits:SetMinSize( wx.wxSize( 200,-1 ) )

	UI.fgSizer12:Add( UI.m_choice_GameInfo_Generals_Traits, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_Generals_Traits = wx.wxTextCtrl( UI.m_panel_GameInfo_Generals, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE + wx.wxTE_WORDWRAP )
	UI.m_textCtrl_GameInfo_Generals_Traits:SetMinSize( wx.wxSize( -1,300 ) )

	UI.fgSizer12:Add( UI.m_textCtrl_GameInfo_Generals_Traits, 0, wx.wxALL + wx.wxEXPAND, 5 )


	UI.gSizer_GameInfo_Generals_2:Add( UI.fgSizer12, 1, wx.wxEXPAND, 5 )


	UI.bSizer_GameInfo2:Add( UI.gSizer_GameInfo_Generals_2, 1, wx.wxEXPAND, 5 )


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
	UI.fgSizer_GameInfo_Techs_3:Add( UI.m_button_GameInfo_Techs_Filter_Clear, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


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
	UI.m_panel_GameInfo_Units = wx.wxPanel( UI.m_notebook5, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_GameInfo_Units_1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.fgSizer_GameInfo_Units_1 = wx.wxFlexGridSizer( 1, 3, 0, 0 )
	UI.fgSizer_GameInfo_Units_1:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_Units_1:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_Units_1:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_choice_GameInfo_Units_1Choices = {}
	UI.m_choice_GameInfo_Units_1 = wx.wxChoice( UI.m_panel_GameInfo_Units, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 350,-1 ), UI.m_choice_GameInfo_Units_1Choices, 0 )
	UI.m_choice_GameInfo_Units_1:SetSelection( 0 )
	UI.fgSizer_GameInfo_Units_1:Add( UI.m_choice_GameInfo_Units_1, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_textCtrl_GameInfo_Units_Filter = wx.wxTextCtrl( UI.m_panel_GameInfo_Units, wx.wxID_ANY, "name filter (press enter)", wx.wxDefaultPosition, wx.wxSize( 135,-1 ), 0 )
	UI.fgSizer_GameInfo_Units_1:Add( UI.m_textCtrl_GameInfo_Units_Filter, 0, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_button_GameInfo_Units_Filter_Clear = wx.wxButton( UI.m_panel_GameInfo_Units, wx.wxID_ANY, "Clear", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.fgSizer_GameInfo_Units_1:Add( UI.m_button_GameInfo_Units_Filter_Clear, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_GameInfo_Units_1:Add( UI.fgSizer_GameInfo_Units_1, 0, wx.wxEXPAND, 5 )

	UI.gSizer_GameInfo_Units_1 = wx.wxGridSizer( 1, 2, 0, 0 )

	UI.bSizer_GameInfo_Units_2 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_listBox_GameInfo_Units_TechsChoices = {}
	UI.m_listBox_GameInfo_Units_Techs = wx.wxListBox( UI.m_panel_GameInfo_Units, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, UI.m_listBox_GameInfo_Units_TechsChoices, wx.wxLB_ALWAYS_SB + wx.wxLB_SINGLE )
	UI.bSizer_GameInfo_Units_2:Add( UI.m_listBox_GameInfo_Units_Techs, 1, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_textCtrl_GameInfo_Units_Tech_Effects = wx.wxTextCtrl( UI.m_panel_GameInfo_Units, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE + wx.wxTE_WORDWRAP )
	UI.bSizer_GameInfo_Units_2:Add( UI.m_textCtrl_GameInfo_Units_Tech_Effects, 1, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.g_Sizer_GameInfo_Units_2 = wx.wxGridSizer( 1, 3, 0, 0 )

	UI.m_button_GameInfo_Units_Tech_Reset = wx.wxButton( UI.m_panel_GameInfo_Units, wx.wxID_ANY, "reset levels", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.g_Sizer_GameInfo_Units_2:Add( UI.m_button_GameInfo_Units_Tech_Reset, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_GameInfo_Units_Tech_Increase = wx.wxButton( UI.m_panel_GameInfo_Units, wx.wxID_ANY, "increase level", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.g_Sizer_GameInfo_Units_2:Add( UI.m_button_GameInfo_Units_Tech_Increase, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_GameInfo_Units_Tech_Decrease = wx.wxButton( UI.m_panel_GameInfo_Units, wx.wxID_ANY, "decrease level", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.g_Sizer_GameInfo_Units_2:Add( UI.m_button_GameInfo_Units_Tech_Decrease, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_GameInfo_Units_2:Add( UI.g_Sizer_GameInfo_Units_2, 0, wx.wxEXPAND, 5 )

	UI.m_textCtrl_GameInfo_Units_Model = wx.wxTextCtrl( UI.m_panel_GameInfo_Units, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer_GameInfo_Units_2:Add( UI.m_textCtrl_GameInfo_Units_Model, 0, wx.wxALL + wx.wxEXPAND, 5 )


	UI.gSizer_GameInfo_Units_1:Add( UI.bSizer_GameInfo_Units_2, 1, wx.wxEXPAND, 5 )

	UI.m_textCtrl_GameInfo_Units_Stats = wx.wxTextCtrl( UI.m_panel_GameInfo_Units, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE + wx.wxTE_WORDWRAP )
	UI.gSizer_GameInfo_Units_1:Add( UI.m_textCtrl_GameInfo_Units_Stats, 0, wx.wxALL + wx.wxEXPAND, 5 )


	UI.bSizer_GameInfo_Units_1:Add( UI.gSizer_GameInfo_Units_1, 1, wx.wxEXPAND, 5 )


	UI.m_panel_GameInfo_Units:SetSizer( UI.bSizer_GameInfo_Units_1 )
	UI.m_panel_GameInfo_Units:Layout()
	UI.bSizer_GameInfo_Units_1:Fit( UI.m_panel_GameInfo_Units )
	UI.m_notebook5:AddPage(UI.m_panel_GameInfo_Units, "Units", False )
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
	UI.m_panel_GameInfo_Flags = wx.wxPanel( UI.m_notebook5, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_GameInfo_Flags1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText_GameInfo_Flags1 = wx.wxStaticText( UI.m_panel_GameInfo_Flags, wx.wxID_ANY, "Active Country Flags", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Flags1:Wrap( -1 )

	UI.m_staticText_GameInfo_Flags1:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizer_GameInfo_Flags1:Add( UI.m_staticText_GameInfo_Flags1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_grid_GameInfo_Flags1 = wx.wxGrid( UI.m_panel_GameInfo_Flags, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 450,400 ), wx.wxALWAYS_SHOW_SB + wx.wxVSCROLL )

	-- Grid
	UI.m_grid_GameInfo_Flags1:CreateGrid( 10, 1 )
	UI.m_grid_GameInfo_Flags1:EnableEditing( False )
	UI.m_grid_GameInfo_Flags1:EnableGridLines( True )
	UI.m_grid_GameInfo_Flags1:EnableDragGridSize( False )
	UI.m_grid_GameInfo_Flags1:SetMargins( 0, 0 )

	-- Columns
	UI.m_grid_GameInfo_Flags1:SetColSize( 0, 430 )
	UI.m_grid_GameInfo_Flags1:EnableDragColSize( True )
	UI.m_grid_GameInfo_Flags1:SetColLabelValue( 0, "Flag Name" )
	UI.m_grid_GameInfo_Flags1:SetColLabelSize( 30 )
	UI.m_grid_GameInfo_Flags1:SetColLabelAlignment( wx.wxALIGN_CENTER, wx.wxALIGN_CENTER )

	-- Rows
	UI.m_grid_GameInfo_Flags1:EnableDragRowSize( False )
	UI.m_grid_GameInfo_Flags1:SetRowLabelSize( 1 )
	UI.m_grid_GameInfo_Flags1:SetRowLabelAlignment( wx.wxALIGN_LEFT, wx.wxALIGN_CENTER )

	-- Label Appearance
	UI.m_grid_GameInfo_Flags1:SetLabelBackgroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_MENU ) )

	-- Cell Defaults
	UI.m_grid_GameInfo_Flags1:SetDefaultCellBackgroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_MENU ) )
	UI.m_grid_GameInfo_Flags1:SetDefaultCellAlignment( wx.wxALIGN_LEFT, wx.wxALIGN_TOP )
	UI.m_grid_GameInfo_Flags1:SetMaxSize( wx.wxSize( 450,400 ) )

	UI.bSizer_GameInfo_Flags1:Add( UI.m_grid_GameInfo_Flags1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_GameInfo_Flags = wx.wxButton( UI.m_panel_GameInfo_Flags, wx.wxID_ANY, "Refresh", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer_GameInfo_Flags1:Add( UI.m_button_GameInfo_Flags, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_panel_GameInfo_Flags:SetSizer( UI.bSizer_GameInfo_Flags1 )
	UI.m_panel_GameInfo_Flags:Layout()
	UI.bSizer_GameInfo_Flags1:Fit( UI.m_panel_GameInfo_Flags )
	UI.m_notebook5:AddPage(UI.m_panel_GameInfo_Flags, "Active Flags", False )
	UI.m_panel_GameInfo_Vars = wx.wxPanel( UI.m_notebook5, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_GameInfo_Vars1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText_GameInfo_Flags1 = wx.wxStaticText( UI.m_panel_GameInfo_Vars, wx.wxID_ANY, "Active Country Variables", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Flags1:Wrap( -1 )

	UI.m_staticText_GameInfo_Flags1:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizer_GameInfo_Vars1:Add( UI.m_staticText_GameInfo_Flags1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_grid_GameInfo_Vars1 = wx.wxGrid( UI.m_panel_GameInfo_Vars, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 450,400 ), wx.wxALWAYS_SHOW_SB + wx.wxVSCROLL )

	-- Grid
	UI.m_grid_GameInfo_Vars1:CreateGrid( 10, 2 )
	UI.m_grid_GameInfo_Vars1:EnableEditing( False )
	UI.m_grid_GameInfo_Vars1:EnableGridLines( True )
	UI.m_grid_GameInfo_Vars1:EnableDragGridSize( False )
	UI.m_grid_GameInfo_Vars1:SetMargins( 0, 0 )

	-- Columns
	UI.m_grid_GameInfo_Vars1:SetColSize( 0, 330 )
	UI.m_grid_GameInfo_Vars1:SetColSize( 1, 100 )
	UI.m_grid_GameInfo_Vars1:EnableDragColSize( True )
	UI.m_grid_GameInfo_Vars1:SetColLabelValue( 0, "Country Variables" )
	UI.m_grid_GameInfo_Vars1:SetColLabelValue( 1, "Value" )
	UI.m_grid_GameInfo_Vars1:SetColLabelSize( 30 )
	UI.m_grid_GameInfo_Vars1:SetColLabelAlignment( wx.wxALIGN_CENTER, wx.wxALIGN_CENTER )

	-- Rows
	UI.m_grid_GameInfo_Vars1:EnableDragRowSize( False )
	UI.m_grid_GameInfo_Vars1:SetRowLabelSize( 1 )
	UI.m_grid_GameInfo_Vars1:SetRowLabelAlignment( wx.wxALIGN_LEFT, wx.wxALIGN_CENTER )

	-- Label Appearance
	UI.m_grid_GameInfo_Vars1:SetLabelBackgroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_MENU ) )

	-- Cell Defaults
	UI.m_grid_GameInfo_Vars1:SetDefaultCellBackgroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_MENU ) )
	UI.m_grid_GameInfo_Vars1:SetDefaultCellAlignment( wx.wxALIGN_LEFT, wx.wxALIGN_TOP )
	UI.m_grid_GameInfo_Vars1:SetMaxSize( wx.wxSize( 450,400 ) )

	UI.bSizer_GameInfo_Vars1:Add( UI.m_grid_GameInfo_Vars1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_GameInfo_Vars1 = wx.wxButton( UI.m_panel_GameInfo_Vars, wx.wxID_ANY, "Refresh", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer_GameInfo_Vars1:Add( UI.m_button_GameInfo_Vars1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_panel_GameInfo_Vars:SetSizer( UI.bSizer_GameInfo_Vars1 )
	UI.m_panel_GameInfo_Vars:Layout()
	UI.bSizer_GameInfo_Vars1:Fit( UI.m_panel_GameInfo_Vars )
	UI.m_notebook5:AddPage(UI.m_panel_GameInfo_Vars, "Active Variables", False )
	UI.m_panel_GameInfo_ActiveModifiers = wx.wxPanel( UI.m_notebook5, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_GameInfo_ActiveModifiers1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText_GameInfo_ActiveModifiers1 = wx.wxStaticText( UI.m_panel_GameInfo_ActiveModifiers, wx.wxID_ANY, "Currently Active Event Modifiers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_ActiveModifiers1:Wrap( -1 )

	UI.m_staticText_GameInfo_ActiveModifiers1:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizer_GameInfo_ActiveModifiers1:Add( UI.m_staticText_GameInfo_ActiveModifiers1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.fgSizer_GameInfo_ActiveModifiers1 = wx.wxFlexGridSizer( 1, 3, 0, 0 )
	UI.fgSizer_GameInfo_ActiveModifiers1:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_ActiveModifiers1:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_ActiveModifiers1:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_choice_GameInfo_ActiveModifiers1Choices = {}
	UI.m_choice_GameInfo_ActiveModifiers1 = wx.wxChoice( UI.m_panel_GameInfo_ActiveModifiers, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 300,-1 ), UI.m_choice_GameInfo_ActiveModifiers1Choices, 0 )
	UI.m_choice_GameInfo_ActiveModifiers1:SetSelection( 0 )
	UI.fgSizer_GameInfo_ActiveModifiers1:Add( UI.m_choice_GameInfo_ActiveModifiers1, 5, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_textCtrl_GameInfo_ActiveModifiers_Filter = wx.wxTextCtrl( UI.m_panel_GameInfo_ActiveModifiers, wx.wxID_ANY, "name filter (press enter)", wx.wxDefaultPosition, wx.wxSize( 135,-1 ), 0 )
	UI.fgSizer_GameInfo_ActiveModifiers1:Add( UI.m_textCtrl_GameInfo_ActiveModifiers_Filter, 1, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_button_GameInfo_ActiveModifiers_Filter_Clear = wx.wxButton( UI.m_panel_GameInfo_ActiveModifiers, wx.wxID_ANY, "Clear", wx.wxDefaultPosition, wx.wxSize( 40,-1 ), 0 )
	UI.fgSizer_GameInfo_ActiveModifiers1:Add( UI.m_button_GameInfo_ActiveModifiers_Filter_Clear, 0, wx.wxALL, 5 )


	UI.bSizer_GameInfo_ActiveModifiers1:Add( UI.fgSizer_GameInfo_ActiveModifiers1, 0, wx.wxEXPAND, 5 )

	UI.fgSizer_GameInfo_ActiveModifiers3 = wx.wxFlexGridSizer( 2, 1, 0, 0 )
	UI.fgSizer_GameInfo_ActiveModifiers3:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_ActiveModifiers3:AddGrowableRow( 1 )
	UI.fgSizer_GameInfo_ActiveModifiers3:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_GameInfo_ActiveModifiers3:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_GameInfo_ActiveModifiers3 = wx.wxStaticText( UI.m_panel_GameInfo_ActiveModifiers, wx.wxID_ANY, "Effects", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_ActiveModifiers3:Wrap( -1 )

	UI.fgSizer_GameInfo_ActiveModifiers3:Add( UI.m_staticText_GameInfo_ActiveModifiers3, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_ActiveModifiers_Effects1 = wx.wxTextCtrl( UI.m_panel_GameInfo_ActiveModifiers, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_MULTILINE )
	UI.fgSizer_GameInfo_ActiveModifiers3:Add( UI.m_textCtrl_GameInfo_ActiveModifiers_Effects1, 0, wx.wxALL + wx.wxEXPAND, 5 )


	UI.bSizer_GameInfo_ActiveModifiers1:Add( UI.fgSizer_GameInfo_ActiveModifiers3, 7, wx.wxEXPAND, 5 )

	UI.fgSizer_GameInfo_ActiveModifiers2 = wx.wxFlexGridSizer( 1, 2, 0, 0 )
	UI.fgSizer_GameInfo_ActiveModifiers2:AddGrowableCol( 0 )
	UI.fgSizer_GameInfo_ActiveModifiers2:AddGrowableCol( 1 )
	UI.fgSizer_GameInfo_ActiveModifiers2:AddGrowableRow( 0 )
	UI.fgSizer_GameInfo_ActiveModifiers2:SetFlexibleDirection( wx.wxVERTICAL )
	UI.fgSizer_GameInfo_ActiveModifiers2:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_GameInfo_ActiveModifiers_ExpiryText = wx.wxStaticText( UI.m_panel_GameInfo_ActiveModifiers, wx.wxID_ANY, "Expires:", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_ActiveModifiers_ExpiryText:Wrap( -1 )

	UI.fgSizer_GameInfo_ActiveModifiers2:Add( UI.m_staticText_GameInfo_ActiveModifiers_ExpiryText, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALIGN_RIGHT + wx.wxALL, 5 )

	UI.m_textCtrl_GameInfo_ActiveModifiers_Expiry = wx.wxTextCtrl( UI.m_panel_GameInfo_ActiveModifiers, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl_GameInfo_ActiveModifiers_Expiry:Enable( False )

	UI.fgSizer_GameInfo_ActiveModifiers2:Add( UI.m_textCtrl_GameInfo_ActiveModifiers_Expiry, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALIGN_LEFT + wx.wxALL, 5 )


	UI.bSizer_GameInfo_ActiveModifiers1:Add( UI.fgSizer_GameInfo_ActiveModifiers2, 1, wx.wxEXPAND, 5 )

	UI.m_button_GameInfo_ActiveModifiers_Refresh = wx.wxButton( UI.m_panel_GameInfo_ActiveModifiers, wx.wxID_ANY, "Refresh", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer_GameInfo_ActiveModifiers1:Add( UI.m_button_GameInfo_ActiveModifiers_Refresh, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_panel_GameInfo_ActiveModifiers:SetSizer( UI.bSizer_GameInfo_ActiveModifiers1 )
	UI.m_panel_GameInfo_ActiveModifiers:Layout()
	UI.bSizer_GameInfo_ActiveModifiers1:Fit( UI.m_panel_GameInfo_ActiveModifiers )
	UI.m_notebook5:AddPage(UI.m_panel_GameInfo_ActiveModifiers, "Active Event Modifiers", False )
	UI.m_panel_GameInfo_Inspector = wx.wxPanel( UI.m_notebook5, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_GameInfo_Inspector1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText_GameInfo_Inspector1 = wx.wxStaticText( UI.m_panel_GameInfo_Inspector, wx.wxID_ANY, "Selection Inspector", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_GameInfo_Inspector1:Wrap( -1 )

	UI.m_staticText_GameInfo_Inspector1:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizer_GameInfo_Inspector1:Add( UI.m_staticText_GameInfo_Inspector1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_GameInfo_Inspector2 = wx.wxStaticText( UI.m_panel_GameInfo_Inspector, wx.wxID_ANY, "The selection inspector will create a window with detail information about the entities you have currently selected ingame.\nAs an example you can use it to see the exact stats of a deployed unit, something which is not posssible ingame.\nSupported entites are:\nLand Units\nNaval Units\nAir Units", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText_GameInfo_Inspector2:Wrap( 400 )

	UI.bSizer_GameInfo_Inspector1:Add( UI.m_staticText_GameInfo_Inspector2, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_GameInfo_Inspector_ShowDetails = wx.wxButton( UI.m_panel_GameInfo_Inspector, wx.wxID_ANY, "Show details", wx.wxDefaultPosition, wx.wxSize( 100,-1 ), 0 )
	UI.bSizer_GameInfo_Inspector1:Add( UI.m_button_GameInfo_Inspector_ShowDetails, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_panel_GameInfo_Inspector:SetSizer( UI.bSizer_GameInfo_Inspector1 )
	UI.m_panel_GameInfo_Inspector:Layout()
	UI.bSizer_GameInfo_Inspector1:Fit( UI.m_panel_GameInfo_Inspector )
	UI.m_notebook5:AddPage(UI.m_panel_GameInfo_Inspector, "Inspector", False )


	UI.MyFrame4 .m_mgr:Update()
	UI.MyFrame4:Centre( wx.wxBOTH )

	UI.MyFrame4:Show(false)
	-- Connect Events

    UI.m_choice_GameInfo_Traits:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
		Parsing.Traits.HandleSelection()
    end )

	UI.m_textCtrl_GameInfo_Traits_Filter:Connect( wx.wxEVT_COMMAND_TEXT_ENTER, function(event)
		Parsing.Traits.HandleFilter()
	end )

	UI.m_button_GameInfo_Traits_Filter_Clear:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		UI.m_textCtrl_GameInfo_Traits_Filter:SetValue("")
		Parsing.Traits.ClearText()
		Parsing.Traits.HandleFilter()
	end )

	UI.m_choice_GameInfo_Generals:Connect( wx.wxEVT_COMMAND_CHOICE_SELECTED, function(event)
		Parsing.Generals.HandleSelection()
	end )

	UI.m_textCtrl_GameInfo_Generals_Filter:Connect( wx.wxEVT_COMMAND_TEXT_ENTER, function(event)
		if G_PlayerCountry ~= nil then
			Parsing.Generals.ClearText()
			Parsing.Generals.HandleFilter(G_PlayerCountry)
		end
	end )

	UI.m_button_GameInfo_Generals_Filter_Clear:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		UI.m_textCtrl_GameInfo_Generals_Filter:SetValue("")
		if G_PlayerCountry ~= nil then
			Parsing.Generals.ClearText()
			Parsing.Generals.HandleFilter(G_PlayerCountry)
		end
	end )

	UI.m_radioBtn_Generals_all:Connect( wx.wxEVT_COMMAND_RADIOBUTTON_SELECTED, function(event)
		if G_PlayerCountry ~= nil then
			Parsing.Generals.ClearText()
			Parsing.Generals.FillwxChoice(G_PlayerCountry, true)
		end
	end )

	UI.m_radioBtn_Generals_land:Connect( wx.wxEVT_COMMAND_RADIOBUTTON_SELECTED, function(event)
		if G_PlayerCountry ~= nil then
			Parsing.Generals.ClearText()
			Parsing.Generals.FillwxChoice(G_PlayerCountry, true)
		end
	end )

	UI.m_radioBtn_Generals_sea:Connect( wx.wxEVT_COMMAND_RADIOBUTTON_SELECTED, function(event)
		if G_PlayerCountry ~= nil then
			Parsing.Generals.ClearText()
			Parsing.Generals.FillwxChoice(G_PlayerCountry, true)
		end
	end )

	UI.m_radioBtn_Generals_air:Connect( wx.wxEVT_COMMAND_RADIOBUTTON_SELECTED, function(event)
		if G_PlayerCountry ~= nil then
			Parsing.Generals.ClearText()
			Parsing.Generals.FillwxChoice(G_PlayerCountry, true)
		end
	end )

	UI.m_choice_GameInfo_Generals_Traits:Connect( wx.wxEVT_COMMAND_CHOICE_SELECTED, function(event)
		Parsing.Generals.HandleTraitSelection()
	end )

	UI.m_choice_GameInfo_Techs:Connect( wx.wxEVT_COMMAND_CHOICE_SELECTED, function(event)
		Parsing.Techs.HandleSelection()
	end )

	UI.m_textCtrl_GameInfo_Techs_Filter:Connect( wx.wxEVT_COMMAND_TEXT_ENTER, function(event)
		Parsing.Techs.HandleFilter()
	end )

	UI.m_button_GameInfo_Techs_Filter_Clear:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		UI.m_textCtrl_GameInfo_Techs_Filter:SetValue("")
		Parsing.Techs.ClearText()
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

	UI.m_choice_GameInfo_Units_1:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
		Parsing.Units.HandleUnitSelection()
	end )

	UI.m_textCtrl_GameInfo_Units_Filter:Connect( wx.wxEVT_COMMAND_TEXT_ENTER, function(event)
		Parsing.Units.HandleFilter()
	end )

	UI.m_button_GameInfo_Units_Filter_Clear:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		UI.m_textCtrl_GameInfo_Units_Filter:SetValue("")
		Parsing.Units.HandleFilter()
	end )

	UI.m_listBox_GameInfo_Units_Techs:Connect( wx.wxEVT_COMMAND_LISTBOX_SELECTED, function(event)
		Parsing.Units.HandleTechSelection()
	end )

	UI.m_button_GameInfo_Units_Tech_Reset:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		Parsing.Units.ResetTechLevels()
	end )

	UI.m_button_GameInfo_Units_Tech_Increase:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		Parsing.Units.ChangeTechLevel(1)
	end )

	UI.m_button_GameInfo_Units_Tech_Decrease:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		Parsing.Units.ChangeTechLevel(-1)
	end )

	UI.m_choice_GameInfo_Modifiers1:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
		Parsing.Modifiers.HandleSelection()
	end )

	UI.m_textCtrl_GameInfo_Modifiers_Filter:Connect( wx.wxEVT_COMMAND_TEXT_ENTER, function(event)
		Parsing.Modifiers.HandleFilter()
	end )

	UI.m_button_GameInfo_Modifiers_Filter_Clear:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		UI.m_textCtrl_GameInfo_Modifiers_Filter:SetValue("")
		Parsing.Modifiers.ClearText()
		Parsing.Modifiers.HandleFilter()
	end )

	UI.m_choice_GameInfo_ActiveModifiers1:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
		Parsing.ActiveEventModifiers.HandleSelection()
	end )

	UI.m_textCtrl_GameInfo_ActiveModifiers_Filter:Connect( wx.wxEVT_COMMAND_TEXT_ENTER, function(event)
		Parsing.ActiveEventModifiers.HandleFilter()
	end )

	UI.m_button_GameInfo_ActiveModifiers_Filter_Clear:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		UI.m_textCtrl_GameInfo_ActiveModifiers_Filter:SetValue("")
		Parsing.ActiveEventModifiers.ClearText()
		Parsing.ActiveEventModifiers.HandleFilter()
	end )

	UI.m_button_GameInfo_ActiveModifiers_Refresh:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		Parsing.ActiveEventModifiers.Refresh()
	end )

	UI.m_button_GameInfo_Flags:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		Parsing.Flags.FillGrid()
	end )

	UI.m_button_GameInfo_Vars1:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		Parsing.Vars.FillGrid()
	end )

	UI.m_button_GameInfo_Inspector_ShowDetails:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		Parsing.Inspector.createDetailsPageForSelection()
	end )
end
