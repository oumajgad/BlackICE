package.cpath = package.cpath..";./tfh/mod/?.dll;"
require("wx")

local True = true
local False = false

if wx ~= nil then
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


	UI.MyFrame3 .m_mgr:Update()
	UI.MyFrame3:Centre( wx.wxBOTH )

	UI.MyFrame3:Show(false)

	-- Connect Events

	UI.m_button_OptionActions_LeftPopups:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        SetDialogPopUpLeft()
    end )

	UI.m_button_OptionActions_CenterPopups:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        SetDialogPopUpCenter()
    end )

	UI.m_button_OptionActions_LeftEvents:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		SetEventPopUpLeft()
	end )

	UI.m_button_OptionActions_CenterEvent:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		SetEventPopUpCenter()
	end )

	UI.m_button_OptionActions_DecreaseFont:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		DecreaseFontSize()
	end )

	UI.m_button_OptionActions_IncreaseFont:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		IncreaseFontSize()
	end )

end
