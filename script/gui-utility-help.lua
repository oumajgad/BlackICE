
package.cpath = package.cpath..";./tfh/mod/?.dll;"
require("wx")


-- UI = {}

if wx ~= nil then

	UI.MyFrame2 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "Hoi3 Utility Help", wx.wxDefaultPosition, wx.wxSize( 800,700 ), wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxMAXIMIZE_BOX + wx.wxMINIMIZE_BOX + wx.wxRESIZE_BORDER + wx.wxSTAY_ON_TOP + wx.wxSYSTEM_MENU+wx.wxTAB_TRAVERSAL )
	UI.MyFrame2:SetSizeHints( wx.wxDefaultSize, wx.wxDefaultSize )
	UI.MyFrame2.m_mgr = wxaui.wxAuiManager()
	UI.MyFrame2.m_mgr:SetManagedWindow( UI.MyFrame2 )

	UI.m_notebook2 = wx.wxNotebook( UI.MyFrame2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,100 ), wx.wxNB_MULTILINE )
	UI.MyFrame2.m_mgr:AddPane( UI.m_notebook2, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):CloseButton( False ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.m_scrolledWindow_HelpTraining = wx.wxScrolledWindow( UI.m_notebook2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxHSCROLL + wx.wxVSCROLL )
	UI.m_scrolledWindow_HelpTraining:SetScrollRate( 5, 5 )
	UI.bSizer50 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText60 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "In BlackICE, unit training level has a permanent effect on the unit performance.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText60:Wrap( 700 )

	UI.m_staticText60:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, True, "" ) )

	UI.bSizer50:Add( UI.m_staticText60, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText601 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "Units trained with basic training law will always perform as such, even if the law is changed. \nTo increase their training level they have to be properly retrained with the new training law in place.\nCombat Experience is properly distinguished from training level and can only be obtained through combat. \nThe training level impacts the unit's stats while combat experience has a direct impact on combat as a modifier. \nThe effect of each level of training laws can be seen in the Training folder of the Technology screen. \nCombinations of training and conscription laws also trigger certain effects which can be checked in Triggered Modifiers.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText601:Wrap( 700 )

	UI.m_staticText601:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizer50:Add( UI.m_staticText601, 0, wx.wxALIGN_CENTER + wx.wxALL, 0 )

	UI.m_staticText6011 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "Wait at least 2 days after changing the training law before you begin the units training!", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText6011:Wrap( 700 )

	UI.m_staticText6011:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizer50:Add( UI.m_staticText6011, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer35 = wx.wxGridSizer( 4, 2, 10, 100 )

	UI.m_staticText69 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "Minimum Training", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText69:Wrap( -1 )

	UI.m_staticText69:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer35:Add( UI.m_staticText69, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText75 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "-10% general stats", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText75:Wrap( -1 )

	UI.gSizer35:Add( UI.m_staticText75, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText63 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "Basic Training", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText63:Wrap( -1 )

	UI.gSizer35:Add( UI.m_staticText63, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText64 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "no change", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText64:Wrap( -1 )

	UI.gSizer35:Add( UI.m_staticText64, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText65 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "Advanced Training", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText65:Wrap( -1 )

	UI.gSizer35:Add( UI.m_staticText65, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText66 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "+5% general stats", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText66:Wrap( -1 )

	UI.gSizer35:Add( UI.m_staticText66, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText67 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "Specialist Training", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText67:Wrap( -1 )

	UI.gSizer35:Add( UI.m_staticText67, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText68 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "+10% general stats", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText68:Wrap( -1 )

	UI.gSizer35:Add( UI.m_staticText68, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizer50:Add( UI.gSizer35, 0, wx.wxALIGN_CENTER, 5 )


	UI.m_scrolledWindow_HelpTraining:SetSizer( UI.bSizer50 )
	UI.m_scrolledWindow_HelpTraining:Layout()
	UI.bSizer50:Fit( UI.m_scrolledWindow_HelpTraining )
	UI.m_notebook2:AddPage(UI.m_scrolledWindow_HelpTraining, "Unit Training", False )


	UI.MyFrame2 .m_mgr:Update()
	UI.MyFrame2:Centre( wx.wxBOTH )

	UI.MyFrame2:Show(false)

end