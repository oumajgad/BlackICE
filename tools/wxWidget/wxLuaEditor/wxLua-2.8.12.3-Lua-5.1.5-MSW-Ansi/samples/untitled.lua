----------------------------------------------------------------------------
-- Lua code generated with wxFormBuilder (version 3.10.1-0-g8feb16b3)
-- http://www.wxformbuilder.org/
----------------------------------------------------------------------------

-- Load the wxLua module, does nothing if running from wxLua, wxLuaFreeze, or wxLuaEdit
package.cpath = package.cpath..";./?.dll;./?.so;../lib/?.so;../lib/vc_dll/?.dll;../lib/bcc_dll/?.dll;../lib/mingw_dll/?.dll;"
require("wx")

UI = {}


-- create MyFrame1
UI.MyFrame1 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "Hoi3 Utility", wx.wxDefaultPosition, wx.wxSize( 500,500 ), wx.wxDEFAULT_FRAME_STYLE+wx.wxTAB_TRAVERSAL, "Hoi3 Utility" )
	UI.MyFrame1:SetSizeHints( wx.wxSize( 500,500 ), wx.wxDefaultSize )
	UI.MyFrame1.m_mgr = wxaui.wxAuiManager()
	UI.MyFrame1.m_mgr:SetManagedWindow( UI.MyFrame1 )

	UI.m_notebook4 = wx.wxNotebook( UI.MyFrame1, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,100 ), 0 )
	UI.MyFrame1.m_mgr:AddPane( UI.m_notebook4, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):CloseButton( False ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.m_panel8 = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( -1,-1 ), wx.wxTAB_TRAVERSAL )
	UI.bSizer2 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_textCtrl3 = wx.wxTextCtrl( UI.m_panel8, wx.wxID_ANY, "Setting up...", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl3:Enable( False )

	UI.bSizer2:Add( UI.m_textCtrl3, 0, wx.wxALIGN_CENTER + wx.wxALL, 10 )

	UI.get_player_button = wx.wxButton( UI.m_panel8, wx.wxID_ANY, "Get Player", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.bSizer2:Add( UI.get_player_button, 0, wx.wxALIGN_CENTER + wx.wxALL, 10 )


	UI.m_panel8:SetSizer( UI.bSizer2 )
	UI.m_panel8:Layout()
	UI.bSizer2:Fit( UI.m_panel8 )
	UI.m_notebook4:AddPage(UI.m_panel8, "Setup", False )
	UI.m_panel9 = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.gSizer3 = wx.wxGridSizer( 5, 3, 0, 0 )

	UI.m_staticText3 = wx.wxStaticText( UI.m_panel9, wx.wxID_ANY, "Select a Puppet", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText3:Wrap( -1 )

	UI.gSizer3:Add( UI.m_staticText3, 0, wx.wxALIGN_CENTER, 5 )

	UI.puppet_choiceChoices = {}
	UI.puppet_choice = wx.wxChoice( UI.m_panel9, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, UI.puppet_choiceChoices, 0 )
	UI.puppet_choice:SetSelection( 0 )
	UI.gSizer3:Add( UI.puppet_choice, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.button_set_puppet = wx.wxButton( UI.m_panel9, wx.wxID_ANY, "Set Puppet", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer3:Add( UI.button_set_puppet, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText4 = wx.wxStaticText( UI.m_panel9, wx.wxID_ANY, "Selected Puppet", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText4:Wrap( -1 )

	UI.gSizer3:Add( UI.m_staticText4, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.set_puppet_text = wx.wxTextCtrl( UI.m_panel9, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.set_puppet_text:Enable( False )

	UI.gSizer3:Add( UI.set_puppet_text, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_textCtrl4 = wx.wxTextCtrl( UI.m_panel9, wx.wxID_ANY, "Current Focus", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_textCtrl4:Enable( False )

	UI.gSizer3:Add( UI.m_textCtrl4, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticText6 = wx.wxStaticText( UI.m_panel9, wx.wxID_ANY, "Select a Focus", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText6:Wrap( -1 )

	UI.gSizer3:Add( UI.m_staticText6, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.puppet_focus_choiceChoices = {"Rares", "Energy", "Metal", "Navy", "Air", "Army", "Oil", "None"}
	UI.puppet_focus_choice = wx.wxChoice( UI.m_panel9, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, UI.puppet_focus_choiceChoices, 0 )
	UI.puppet_focus_choice:SetSelection( 0 )
	UI.gSizer3:Add( UI.puppet_focus_choice, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.puppet_set_focus = wx.wxButton( UI.m_panel9, wx.wxID_ANY, "Set Focus", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer3:Add( UI.puppet_set_focus, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )


	UI.m_panel9:SetSizer( UI.gSizer3 )
	UI.m_panel9:Layout()
	UI.gSizer3:Fit( UI.m_panel9 )
	UI.m_notebook4:AddPage(UI.m_panel9, "Puppets", True )


	UI.MyFrame1 .m_mgr:Update()
	UI.MyFrame1:Centre( wx.wxBOTH )

	-- Connect Events

	UI.get_player_button:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
	--implements m_button8OnButtonClick

	event:Skip()
	end )

	UI.MyFrame1:Show(true)


wx.wxGetApp():MainLoop()
