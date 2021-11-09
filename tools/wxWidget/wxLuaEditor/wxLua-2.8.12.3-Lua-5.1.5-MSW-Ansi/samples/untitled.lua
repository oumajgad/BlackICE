----------------------------------------------------------------------------
-- Lua code generated with wxFormBuilder (version 3.10.1-0-g8feb16b3)
-- http://www.wxformbuilder.org/
----------------------------------------------------------------------------

-- Load the wxLua module, does nothing if running from wxLua, wxLuaFreeze, or wxLuaEdit
package.cpath = package.cpath..";./?.dll;./?.so;../lib/?.so;../lib/vc_dll/?.dll;../lib/bcc_dll/?.dll;../lib/mingw_dll/?.dll;"
require("wx")


UI = {}


-- create MyFrame1
UI.MyFrame1 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( 500,500 ), wx.wxDEFAULT_FRAME_STYLE+wx.wxTAB_TRAVERSAL, "Hoi3 Utility" )
	UI.MyFrame1:SetSizeHints( wx.wxSize( 500,500 ), wx.wxDefaultSize )
	UI.MyFrame1.m_mgr = wxaui.wxAuiManager()
	UI.MyFrame1.m_mgr:SetManagedWindow( UI.MyFrame1 )

	UI.m_notebook4 = wx.wxNotebook( UI.MyFrame1, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,100 ), 0 )
	UI.MyFrame1.m_mgr:AddPane( UI.m_notebook4, wxaui.wxAuiPaneInfo() :Left() :PinButton( True ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ) )

	UI.m_panel8 = wx.wxPanel( UI.m_notebook4, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.fgSizer1 = wx.wxFlexGridSizer( 2, 2, 0, 0 )
	UI.fgSizer1:SetFlexibleDirection( wx.wxBOTH )
	UI.fgSizer1:SetNonFlexibleGrowMode( wx.wxFLEX_GROWMODE_SPECIFIED )

	UI.button_getPlayer = wx.wxButton( UI.m_panel8, 1, "GetPlayer", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.fgSizer1:Add( UI.button_getPlayer, 0, wx.wxALL, 5 )

	UI.m_textCtrl1 = wx.wxTextCtrl( UI.m_panel8, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.fgSizer1:Add( UI.m_textCtrl1, 0, wx.wxALL, 5 )

	UI.m_button6 = wx.wxButton( UI.m_panel8, wx.wxID_ANY, "MyButton", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.fgSizer1:Add( UI.m_button6, 0, wx.wxALL, 5 )

	UI.m_textCtrl2 = wx.wxTextCtrl( UI.m_panel8, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.fgSizer1:Add( UI.m_textCtrl2, 0, wx.wxALL, 5 )


	UI.m_panel8:SetSizer( UI.fgSizer1 )
	UI.m_panel8:Layout()
	UI.fgSizer1:Fit( UI.m_panel8 )
	UI.m_notebook4:AddPage(UI.m_panel8, "Page 1", False )


	UI.MyFrame1 .m_mgr:Update()
	UI.MyFrame1:Centre( wx.wxBOTH )
    UI.MyFrame1:Show(true)
    
	UI.button_getPlayer:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
        UI.m_textCtrl1:SetValue("Hallo")
    end )
    
wx.wxGetApp():MainLoop()
