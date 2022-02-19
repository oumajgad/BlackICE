
package.cpath = package.cpath..";./tfh/mod/?.dll;"
require("wx")


UI = {}

if wx ~= nil then


	UI.MyFrame2 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "Hoi3 Utility Help", wx.wxDefaultPosition, wx.wxSize( 800,700 ), wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxMAXIMIZE_BOX + wx.wxMINIMIZE_BOX + wx.wxRESIZE_BORDER + wx.wxSTAY_ON_TOP + wx.wxSYSTEM_MENU+wx.wxTAB_TRAVERSAL )
	UI.MyFrame2:SetSizeHints( wx.wxDefaultSize, wx.wxDefaultSize )
	UI.MyFrame2.m_mgr = wxaui.wxAuiManager()
	UI.MyFrame2.m_mgr:SetManagedWindow( UI.MyFrame2 )

	UI.m_notebook2 = wx.wxNotebook( UI.MyFrame2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,100 ), wx.wxNB_MULTILINE )
	UI.MyFrame2.m_mgr:AddPane( UI.m_notebook2, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):CloseButton( False ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.m_panel10 = wx.wxPanel( UI.m_notebook2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.gSizer31 = wx.wxGridSizer( 0, 2, 0, 0 )

	UI.m_bitmap3 = wx.wxStaticBitmap( UI.m_panel10, wx.wxID_ANY, wx.wxBitmap( "tfh/mod/BlackICE-utility-resources/6516aa6d68f99525.jpg", wx.wxBITMAP_TYPE_ANY ), wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.gSizer31:Add( UI.m_bitmap3, 0, wx.wxALL, 5 )


	UI.m_panel10:SetSizer( UI.gSizer31 )
	UI.m_panel10:Layout()
	UI.gSizer31:Fit( UI.m_panel10 )
	UI.m_notebook2:AddPage(UI.m_panel10, "a page", False )


	UI.MyFrame2 .m_mgr:Update()
	UI.MyFrame2:Centre( wx.wxBOTH )

	UI.MyFrame2:Show(false)

end