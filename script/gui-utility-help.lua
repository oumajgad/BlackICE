
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
	UI.bSizerHelp50 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticText60 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "In BlackICE, unit training level has a permanent effect on the unit performance.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText60:Wrap( 650 )

	UI.m_staticText60:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, True, "" ) )

	UI.bSizerHelp50:Add( UI.m_staticText60, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText601 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "Units trained with basic training law will always perform as such, even if the law is changed. \nTo increase their training level they have to be properly retrained with the new training law in place.\nCombat Experience is properly distinguished from training level and can only be obtained through combat. \nThe training level impacts the unit's stats while combat experience has a direct impact on combat as a modifier. \nThe effect of each level of training laws can be seen in the Training folder of the Technology screen. \nCombinations of training and conscription laws also trigger certain effects which can be checked in Triggered Modifiers.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText601:Wrap( 650 )

	UI.m_staticText601:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizerHelp50:Add( UI.m_staticText601, 0, wx.wxALIGN_CENTER + wx.wxALL, 0 )

	UI.m_staticText6011 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "Wait at least 2 days after changing the training law before you begin the units training!", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticText6011:Wrap( 650 )

	UI.m_staticText6011:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizerHelp50:Add( UI.m_staticText6011, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizerHelp35 = wx.wxGridSizer( 4, 2, 10, 100 )

	UI.m_staticText69 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "Minimum Training", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText69:Wrap( -1 )

	UI.m_staticText69:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizerHelp35:Add( UI.m_staticText69, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText75 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "-10% unit stats", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText75:Wrap( -1 )

	UI.gSizerHelp35:Add( UI.m_staticText75, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText63 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "Basic Training", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText63:Wrap( -1 )

	UI.gSizerHelp35:Add( UI.m_staticText63, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText64 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "no change", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText64:Wrap( -1 )

	UI.gSizerHelp35:Add( UI.m_staticText64, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText65 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "Advanced Training", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText65:Wrap( -1 )

	UI.gSizerHelp35:Add( UI.m_staticText65, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText66 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "+5% unit stats", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText66:Wrap( -1 )

	UI.gSizerHelp35:Add( UI.m_staticText66, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText67 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "Specialist Training", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText67:Wrap( -1 )

	UI.gSizerHelp35:Add( UI.m_staticText67, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticText68 = wx.wxStaticText( UI.m_scrolledWindow_HelpTraining, wx.wxID_ANY, "+10% unit stats", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticText68:Wrap( -1 )

	UI.gSizerHelp35:Add( UI.m_staticText68, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.bSizerHelp50:Add( UI.gSizerHelp35, 0, wx.wxALIGN_CENTER, 5 )


	UI.m_scrolledWindow_HelpTraining:SetSizer( UI.bSizerHelp50 )
	UI.m_scrolledWindow_HelpTraining:Layout()
	UI.bSizerHelp50:Fit( UI.m_scrolledWindow_HelpTraining )
	UI.m_notebook2:AddPage(UI.m_scrolledWindow_HelpTraining, "Unit Training", False )
	UI.m_scrolledWindow4 = wx.wxScrolledWindow( UI.m_notebook2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxHSCROLL + wx.wxVSCROLL )
	UI.m_scrolledWindow4:SetScrollRate( 5, 5 )
	UI.bSizer15 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticTextHelp1 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "In BlackICE, ministers don't only give flat effects, but they are now also responsible for your country's civilian and war economy.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp1:Wrap( 500 )

	UI.m_staticTextHelp1:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, True, "" ) )

	UI.bSizer15:Add( UI.m_staticTextHelp1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticTextHelp2 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "Depending on your choice of ministers for each position you will gain different types of buildings from time to time which are not normally buildable.\nYou only need one type of minister to get the matching building, but having multiple ministers for the same building increases the amount gained.\nSome ministers also give 2x for certain buildings.\nIf the selected national focus matches the minister the building speed will be doubled.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp2:Wrap( 650 )

	UI.m_staticTextHelp2:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizer15:Add( UI.m_staticTextHelp2, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer38 = wx.wxGridSizer( 0, 3, 0, 0 )

	UI.m_staticTextHelp9 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Smallarms Factory---\n--Army focus--\n2x Infantry Proponent\n2x School of mass combat\n1x Old General\n1x Military Entrepreneur\n1x Guns and butter doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp9:Wrap( -1 )

	UI.m_staticTextHelp9:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp9, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp10 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Artillery Factory---\n--Army focus--\n2x School of fire support\n1x Old General\n1x Military Entrepreneur\n1x Guns and butter doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp10:Wrap( -1 )

	UI.m_staticTextHelp10:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp10, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp11 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Tank Factory---\n--Army focus--\n2x Tank Proponent\n2x Armoured Spearhead Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp11:Wrap( -1 )

	UI.m_staticTextHelp11:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp11, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp18 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Automotive Factory---\n--Army focus--\n2x School of Manoeuvre\n1x Logistics Specialist", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp18:Wrap( -1 )

	UI.m_staticTextHelp18:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp18, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp3 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Light Aircraft Factory---\n--Air Force national focus--\n2x Single Engine Aircraft Proponent\n2x Air Superiority Doctrine\n1x Old Air Marshal\n1x Air Superiority Proponent\n1x Naval Aviation Doctrine\n1x Army Aviation Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp3:Wrap( -1 )

	UI.m_staticTextHelp3:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp3, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp4 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Medium Aircraft Factory---\n--Air Force national focus--\n2x Twin Engine Aircraft Proponent\n2x Vertical Envelopment Doctrine\n1x Naval Aviation Doctrine\n1x Army Aviation Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp4:Wrap( -1 )

	UI.m_staticTextHelp4:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp4, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp5 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Heavy Aircraft Factory---\n--Air Force national focus--\n2x Strategic Air Proponent\n2x Carpet Bombing Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp5:Wrap( -1 )

	UI.m_staticTextHelp5:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp5, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp16 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Radar Station---\n--Air focus--\n2x Air Superiority Proponent", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp16:Wrap( -1 )

	UI.m_staticTextHelp16:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp16, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp12 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Capital Shipyard---\n--Navy focus--\n2x Decisive Naval Battle Doctrine\n1x Old Admiral\n1x Battle fleet proponent", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp12:Wrap( -1 )

	UI.m_staticTextHelp12:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp12, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp13 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Medium Shipyard---\n--Navy focus--\n1x Open Seas Doctrine\n1x Old Admiral\n1x Battle fleet proponent", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp13:Wrap( -1 )

	UI.m_staticTextHelp13:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp13, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp14 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Small Shipyard---\n--Navy focus--\n1x Open Seas Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp14:Wrap( -1 )

	UI.m_staticTextHelp14:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp14, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp15 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Submarine Shipyard---\n--Navy focus--\n2x Submarine Proponent\n2x Indirect Approach Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp15:Wrap( -1 )

	UI.m_staticTextHelp15:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp15, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp7 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Heavy Industry---\n--Economic focus--\n2x Silent Workhorse\n2x Administrative Genius", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp7:Wrap( -1 )

	UI.m_staticTextHelp7:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp7, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp8 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Manufacturing Plant---\n--Economic focus--\n1x Military Entrepreneur\n1x Logistics Specialist", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp8:Wrap( -1 )

	UI.m_staticTextHelp8:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp8, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp20 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Rail Terminous---\n--Economy focus--\n2x Logistics Specialist", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp20:Wrap( -1 )

	UI.m_staticTextHelp20:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp20, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp17 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Research Lab---\n--Science focus--\n2x Theoretical Scientist\n1x Biased Intellectual\n1x Silent Lawyer\n1x Technical Specialist\n3x Research Specialist (only focus)", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp17:Wrap( -1 )

	UI.m_staticTextHelp17:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp17, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp6 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Training Base---\n--Health & Education focus--\n2x General Staffer\n2x School of Psychology", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp6:Wrap( -1 )

	UI.m_staticTextHelp6:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp6, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp21 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Hospital---\n--Health & Education focus--\n2x Man of the People\n1x School of Psychology", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp21:Wrap( -1 )

	UI.m_staticTextHelp21:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp21, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp19 = wx.wxStaticText( UI.m_scrolledWindow4, wx.wxID_ANY, "---Resource buildings---\n--Resource focus--\n2x Resource Industrialist", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp19:Wrap( -1 )

	UI.m_staticTextHelp19:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp19, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )


	UI.bSizer15:Add( UI.gSizer38, 1, wx.wxALIGN_CENTER, 5 )


	UI.m_scrolledWindow4:SetSizer( UI.bSizer15 )
	UI.m_scrolledWindow4:Layout()
	UI.bSizer15:Fit( UI.m_scrolledWindow4 )
	UI.m_notebook2:AddPage(UI.m_scrolledWindow4, "Ministers", True )


	UI.MyFrame2 .m_mgr:Update()
	UI.MyFrame2:Centre( wx.wxBOTH )

	UI.MyFrame2:Show(false)

end