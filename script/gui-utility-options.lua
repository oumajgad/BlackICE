package.cpath = package.cpath..";./tfh/mod/?.dll;"
require("wx")

local True = true
local False = false

if wx ~= nil then
	UI.MyFrame3 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 600,600 ), wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxMAXIMIZE_BOX + wx.wxMINIMIZE_BOX + wx.wxRESIZE_BORDER + wx.wxSYSTEM_MENU+wx.wxTAB_TRAVERSAL )
	UI.MyFrame3:SetSizeHints( wx.wxSize( 600,600 ), wx.wxDefaultSize )
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

	UI.m_staticText_OptionActions1 = wx.wxStaticText( UI.m_panel_OptionActions, wx.wxID_ANY, "In order for the changes to take effect you may need to restart the game.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText_OptionActions1:Wrap( -1 )

	UI.bSizer_OptionActions1:Add( UI.m_staticText_OptionActions1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer_OptionActions1 = wx.wxGridSizer( 3, 2, 0, 0 )

	UI.m_button_OptionActions_LeftPopups = wx.wxButton( UI.m_panel_OptionActions, wx.wxID_ANY, "Leftside message popups", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_OptionActions1:Add( UI.m_button_OptionActions_LeftPopups, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionActions_CenterPopups = wx.wxButton( UI.m_panel_OptionActions, wx.wxID_ANY, "Center message popups", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_OptionActions1:Add( UI.m_button_OptionActions_CenterPopups, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionActions_LeftEvents = wx.wxButton( UI.m_panel_OptionActions, wx.wxID_ANY, "Leftside event popups", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_OptionActions1:Add( UI.m_button_OptionActions_LeftEvents, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionActions_CenterEvent = wx.wxButton( UI.m_panel_OptionActions, wx.wxID_ANY, "Center event popups", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_OptionActions1:Add( UI.m_button_OptionActions_CenterEvent, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionActions_DecreaseFont = wx.wxButton( UI.m_panel_OptionActions, wx.wxID_ANY, "Decrease utility font size", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_OptionActions1:Add( UI.m_button_OptionActions_DecreaseFont, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionActions_IncreaseFont = wx.wxButton( UI.m_panel_OptionActions, wx.wxID_ANY, "Increase utility font size", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer_OptionActions1:Add( UI.m_button_OptionActions_IncreaseFont, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_OptionActions1:Add( UI.gSizer_OptionActions1, 1, wx.wxEXPAND, 5 )


	UI.m_panel_OptionActions:SetSizer( UI.bSizer_OptionActions1 )
	UI.m_panel_OptionActions:Layout()
	UI.bSizer_OptionActions1:Fit( UI.m_panel_OptionActions )
	UI.m_notebook3:AddPage(UI.m_panel_OptionActions, "Actions", True )
	UI.m_panel_OptionProvinceNames = wx.wxPanel( UI.m_notebook3, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_OptionProvinceNames1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.fgSizer_OptionProvinceNames1 = wx.wxFlexGridSizer( 1, 3, 0, 0 )
	UI.fgSizer_OptionProvinceNames1:AddGrowableCol( 0 )
	UI.fgSizer_OptionProvinceNames1:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_OptionProvinceNames1:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_choice_OptionProvinceNames_SearchChoices = {}
	UI.m_choice_OptionProvinceNames_Search = wx.wxChoice( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 250,-1 ), UI.m_choice_OptionProvinceNames_SearchChoices, 0 )
	UI.m_choice_OptionProvinceNames_Search:SetSelection( 0 )
	UI.fgSizer_OptionProvinceNames1:Add( UI.m_choice_OptionProvinceNames_Search, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_textCtrl__OptionProvinceNames_Filter = wx.wxTextCtrl( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "name filter (press enter)", wx.wxDefaultPosition, wx.wxSize( 135,-1 ), 0 )
	UI.fgSizer_OptionProvinceNames1:Add( UI.m_textCtrl__OptionProvinceNames_Filter, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionProvinceNames_Clear = wx.wxButton( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "clear", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.fgSizer_OptionProvinceNames1:Add( UI.m_button_OptionProvinceNames_Clear, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_OptionProvinceNames1:Add( UI.fgSizer_OptionProvinceNames1, 0, wx.wxEXPAND, 5 )

	UI.fgSizer_OptionProvinceNames2 = wx.wxFlexGridSizer( 2, 6, 0, 0 )
	UI.fgSizer_OptionProvinceNames2:AddGrowableCol( 0 )
	UI.fgSizer_OptionProvinceNames2:AddGrowableCol( 1 )
	UI.fgSizer_OptionProvinceNames2:AddGrowableCol( 2 )
	UI.fgSizer_OptionProvinceNames2:AddGrowableCol( 3 )
	UI.fgSizer_OptionProvinceNames2:AddGrowableCol( 4 )
	UI.fgSizer_OptionProvinceNames2:AddGrowableCol( 5 )
	UI.fgSizer_OptionProvinceNames2:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_OptionProvinceNames2:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_staticText_OptionProvinceNames_ID = wx.wxStaticText( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "ID", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_OptionProvinceNames_ID:Wrap( -1 )

	UI.fgSizer_OptionProvinceNames2:Add( UI.m_staticText_OptionProvinceNames_ID, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_OptionProvinceNames_OriginalName = wx.wxStaticText( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "original name", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_OptionProvinceNames_OriginalName:Wrap( -1 )

	UI.fgSizer_OptionProvinceNames2:Add( UI.m_staticText_OptionProvinceNames_OriginalName, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_OptionProvinceNames_CurrentName = wx.wxStaticText( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "current name", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_OptionProvinceNames_CurrentName:Wrap( -1 )

	UI.fgSizer_OptionProvinceNames2:Add( UI.m_staticText_OptionProvinceNames_CurrentName, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText_OptionProvinceNames_NewName = wx.wxStaticText( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "new name", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_OptionProvinceNames_NewName:Wrap( -1 )

	UI.fgSizer_OptionProvinceNames2:Add( UI.m_staticText_OptionProvinceNames_NewName, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.fgSizer_OptionProvinceNames2:Add( 0, 0, 1, wx.wxEXPAND, 5 )


	UI.fgSizer_OptionProvinceNames2:Add( 0, 0, 1, wx.wxEXPAND, 5 )

	UI.m_textCtrl_OptionProvinceNames_ID = wx.wxTextCtrl( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.m_textCtrl_OptionProvinceNames_ID:Enable( False )

	UI.fgSizer_OptionProvinceNames2:Add( UI.m_textCtrl_OptionProvinceNames_ID, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_textCtrl_OptionProvinceNames_OriginalName = wx.wxTextCtrl( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 100,-1 ), 0 )
	UI.m_textCtrl_OptionProvinceNames_OriginalName:Enable( False )
	UI.m_textCtrl_OptionProvinceNames_OriginalName:SetMinSize( wx.wxSize( 100,-1 ) )

	UI.fgSizer_OptionProvinceNames2:Add( UI.m_textCtrl_OptionProvinceNames_OriginalName, 1, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_textCtrl_OptionProvinceNames_CurrentName = wx.wxTextCtrl( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 100,-1 ), 0 )
	UI.m_textCtrl_OptionProvinceNames_CurrentName:Enable( False )
	UI.m_textCtrl_OptionProvinceNames_CurrentName:SetMinSize( wx.wxSize( 100,-1 ) )

	UI.fgSizer_OptionProvinceNames2:Add( UI.m_textCtrl_OptionProvinceNames_CurrentName, 1, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_textCtrl_OptionProvinceNames_NewName = wx.wxTextCtrl( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 100,-1 ), 0 )
	UI.m_textCtrl_OptionProvinceNames_NewName:SetMinSize( wx.wxSize( 100,-1 ) )

	UI.fgSizer_OptionProvinceNames2:Add( UI.m_textCtrl_OptionProvinceNames_NewName, 1, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_button_OptionProvinceNames_AddSingle = wx.wxButton( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "add", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.fgSizer_OptionProvinceNames2:Add( UI.m_button_OptionProvinceNames_AddSingle, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionProvinceNames_ResetSingle = wx.wxButton( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "reset", wx.wxDefaultPosition, wx.wxSize( 50,-1 ), 0 )
	UI.fgSizer_OptionProvinceNames2:Add( UI.m_button_OptionProvinceNames_ResetSingle, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer_OptionProvinceNames1:Add( UI.fgSizer_OptionProvinceNames2, 0, wx.wxEXPAND, 5 )

	UI.fgSizer_OptionProvinceNames3 = wx.wxFlexGridSizer( 0, 3, 0, 0 )
	UI.fgSizer_OptionProvinceNames3:AddGrowableCol( 0 )
	UI.fgSizer_OptionProvinceNames3:AddGrowableCol( 2 )
	UI.fgSizer_OptionProvinceNames3:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_OptionProvinceNames3:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_choice_OptionProvinceName_TemplateChoices = {}
	UI.m_choice_OptionProvinceName_Template = wx.wxChoice( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 200,-1 ), UI.m_choice_OptionProvinceName_TemplateChoices, 0 )
	UI.m_choice_OptionProvinceName_Template:SetSelection( 0 )
	UI.fgSizer_OptionProvinceNames3:Add( UI.m_choice_OptionProvinceName_Template, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.fgSizer_OptionProvinceNames3:Add( 0, 0, 1, wx.wxEXPAND, 5 )

	UI.m_staticText_OptionProvinceName_CurrentSituation = wx.wxStaticText( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "current edits", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText_OptionProvinceName_CurrentSituation:Wrap( -1 )

	UI.fgSizer_OptionProvinceNames3:Add( UI.m_staticText_OptionProvinceName_CurrentSituation, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_listBox_OptionProvinceName_TemplateProvsChoices = {}
	UI.m_listBox_OptionProvinceName_TemplateProvs = wx.wxListBox( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 200,300 ), UI.m_listBox_OptionProvinceName_TemplateProvsChoices, 0 )
	UI.fgSizer_OptionProvinceNames3:Add( UI.m_listBox_OptionProvinceName_TemplateProvs, 1, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )

	UI.fgSizer_OptionProvinceName4 = wx.wxFlexGridSizer( 4, 1, 0, 0 )
	UI.fgSizer_OptionProvinceName4:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer_OptionProvinceName4:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.m_button_OptionProvinceName_AddSingleFromTemplate = wx.wxButton( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "move >", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.fgSizer_OptionProvinceName4:Add( UI.m_button_OptionProvinceName_AddSingleFromTemplate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionProvinceName_AddAllFromTemplate = wx.wxButton( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "move all >>", wx.wxDefaultPosition, wx.wxSize( 70,-1 ), 0 )
	UI.fgSizer_OptionProvinceName4:Add( UI.m_button_OptionProvinceName_AddAllFromTemplate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionProvinceName_AddSingleToTemplate = wx.wxButton( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "< move", wx.wxDefaultPosition, wx.wxSize( 60,-1 ), 0 )
	UI.fgSizer_OptionProvinceName4:Add( UI.m_button_OptionProvinceName_AddSingleToTemplate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_button_OptionProvinceName_AddAllToTemplate = wx.wxButton( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, "<< move all", wx.wxDefaultPosition, wx.wxSize( 70,-1 ), 0 )
	UI.fgSizer_OptionProvinceName4:Add( UI.m_button_OptionProvinceName_AddAllToTemplate, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.fgSizer_OptionProvinceNames3:Add( UI.fgSizer_OptionProvinceName4, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_listBox_OptionProvinceName_CurrentProvsChoices = {}
	UI.m_listBox_OptionProvinceName_CurrentProvs = wx.wxListBox( UI.m_panel_OptionProvinceNames, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 200,300 ), UI.m_listBox_OptionProvinceName_CurrentProvsChoices, 0 )
	UI.fgSizer_OptionProvinceNames3:Add( UI.m_listBox_OptionProvinceName_CurrentProvs, 1, wx.wxALIGN_CENTER + wx.wxALL + wx.wxEXPAND, 5 )


	UI.bSizer_OptionProvinceNames1:Add( UI.fgSizer_OptionProvinceNames3, 1, wx.wxEXPAND, 5 )


	UI.m_panel_OptionProvinceNames:SetSizer( UI.bSizer_OptionProvinceNames1 )
	UI.m_panel_OptionProvinceNames:Layout()
	UI.bSizer_OptionProvinceNames1:Fit( UI.m_panel_OptionProvinceNames )
	UI.m_notebook3:AddPage(UI.m_panel_OptionProvinceNames, "Province Names", False )


	UI.MyFrame3 .m_mgr:Update()
	UI.MyFrame3:Centre( wx.wxBOTH )

	UI.MyFrame3:Show(false)

	-- Connect Events

	UI.m_button_OptionActions_LeftPopups:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        Options.SetDialogPopUpLeft()
    end )

	UI.m_button_OptionActions_CenterPopups:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        Options.SetDialogPopUpCenter()
    end )

	UI.m_button_OptionActions_LeftEvents:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		Options.SetEventPopUpLeft()
	end )

	UI.m_button_OptionActions_CenterEvent:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		Options.SetEventPopUpCenter()
	end )

	UI.m_button_OptionActions_DecreaseFont:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		Options.DecreaseFontSize()
	end )

	UI.m_button_OptionActions_IncreaseFont:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		Options.IncreaseFontSize()
	end )

	UI.m_choice_OptionProvinceNames_Search:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
		Options.Provinces.HandleProvinceSelection()
	end )

	UI.m_textCtrl__OptionProvinceNames_Filter:Connect( wx.wxEVT_COMMAND_TEXT_ENTER, function(event)
	--implements m_textCtrl__OptionProvinceNames_FilterOnTextEnter

	event:Skip()
	end )

	UI.m_button_OptionProvinceNames_Clear:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_OptionProvinceNames_ClearOnButtonClick

	event:Skip()
	end )

	UI.m_button_OptionProvinceNames_AddSingle:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_OptionProvinceNames_AddSingleOnButtonClick

	event:Skip()
	end )

	UI.m_button_OptionProvinceNames_ResetSingle:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_OptionProvinceNames_ResetSingleOnButtonClick

	event:Skip()
	end )

	UI.m_choice_OptionProvinceName_Template:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
	--implements m_choice_OptionProvinceName_TemplateOnChoice

	event:Skip()
	end )

	UI.m_button_OptionProvinceName_AddSingleFromTemplate:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_OptionProvinceName_AddSingleFromTemplateOnButtonClick

	event:Skip()
	end )

	UI.m_button_OptionProvinceName_AddAllFromTemplate:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_OptionProvinceName_AddAllFromTemplateOnButtonClick

	event:Skip()
	end )

	UI.m_button_OptionProvinceName_AddSingleToTemplate:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_OptionProvinceName_AddSingleToTemplateOnButtonClick

	event:Skip()
	end )

	UI.m_button_OptionProvinceName_AddAllToTemplate:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button_OptionProvinceName_AddAllToTemplateOnButtonClick

	event:Skip()
	end )
end
