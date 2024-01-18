package.cpath = package.cpath..";./tfh/mod/?.dll;"
require("wx")

local True = true
local False = false

if wx ~= nil then
	UI.MyFrame2 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "Hoi3 Utility Help", wx.wxDefaultPosition, wx.wxSize( 800,700 ), wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxMAXIMIZE_BOX + wx.wxMINIMIZE_BOX + wx.wxRESIZE_BORDER + wx.wxSTAY_ON_TOP + wx.wxSYSTEM_MENU+wx.wxTAB_TRAVERSAL )
	UI.MyFrame2:SetSizeHints( wx.wxDefaultSize, wx.wxDefaultSize )
	UI.MyFrame2.m_mgr = wxaui.wxAuiManager()
	UI.MyFrame2.m_mgr:SetManagedWindow( UI.MyFrame2 )

	UI.m_notebook2 = wx.wxNotebook( UI.MyFrame2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 100,100 ), wx.wxNB_MULTILINE )
	UI.MyFrame2.m_mgr:AddPane( UI.m_notebook2, wxaui.wxAuiPaneInfo() :Left() :CaptionVisible( False ):CloseButton( False ):Dock():Resizable():FloatingSize( wx.wxDefaultSize ):CentrePane() )

	UI.m_scrolledWindow_HelpMisc = wx.wxScrolledWindow( UI.m_notebook2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxHSCROLL + wx.wxVSCROLL )
	UI.m_scrolledWindow_HelpMisc:SetScrollRate( 5, 5 )
	UI.m_scrolledWindow_HelpMisc:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizerHelpMisc0 = wx.wxGridSizer( 2, 2, 0, 5 )

	UI.bSizerHelpMisc1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticTextHelpMisc = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Strategic Resources", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelpMisc:Wrap( -1 )

	UI.m_staticTextHelpMisc:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizerHelpMisc1:Add( UI.m_staticTextHelpMisc, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticTextHelpMisc1 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Strategic Resources are crucial for the military production of any nation. If you do not have access to these resources other nations may be open to selling them for a price, if you have them there is much money to be made as an exporter of them. \nTrade deals last for 1 year. \nEach 200 IC requires a resource level to avoid maluses, below 100IC there are no maluses. Puppets give their excess resource to the master, who can also decide to sell it.\nEach trade costs the player 2000 money, between allies the price is halved.\n", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelpMisc1:Wrap( 370 )

	UI.m_staticTextHelpMisc1:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizerHelpMisc1:Add( UI.m_staticTextHelpMisc1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.gSizerHelpMisc0:Add( UI.bSizerHelpMisc1, 1, wx.wxEXPAND, 5 )

	UI.bSizerHelpMisc2 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticTextHelpMisc2 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Airdroppable Units", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelpMisc2:Wrap( -1 )

	UI.m_staticTextHelpMisc2:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizerHelpMisc2:Add( UI.m_staticTextHelpMisc2, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizerHelpMisc1 = wx.wxGridSizer( 0, 2, 0, 0 )

	UI.m_staticTextHelp30 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Garrision detachment", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp30:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp30, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp22 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Motorcycle Recon", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp22:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp22, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp31 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Light Transport", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp31:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp31, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp32 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Gurkhas", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp32:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp32, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp33 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Elite Light Infantry Battalion", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp33:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp33, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp34 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Airborne Engineers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp34:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp34, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp35 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Airborne Mixed Support", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp35:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp35, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp36 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Commandos", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp36:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp36, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp37 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Airlanding Infantry", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp37:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp37, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp38 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Paratroopers", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp38:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp38, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp39 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Player Unit (\"YOU\" brigade)", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp39:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp39, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp40 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Political Leader", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp40:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp40, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp41 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Battle Commander", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp41:Wrap( -1 )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp41, 0, wx.wxALL, 5 )

	UI.m_staticTextHelp = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Division HQs", wx.wxDefaultPosition, wx.wxDefaultSize, 0 )
	UI.m_staticTextHelp:Wrap( -1 )

	UI.m_staticTextHelp:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizerHelpMisc1:Add( UI.m_staticTextHelp, 0, wx.wxALL, 5 )


	UI.bSizerHelpMisc2:Add( UI.gSizerHelpMisc1, 1, wx.wxALIGN_CENTER, 5 )


	UI.gSizerHelpMisc0:Add( UI.bSizerHelpMisc2, 1, wx.wxEXPAND, 5 )

	UI.bSizerHelp50 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticTextHelp23 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Unit Training", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp23:Wrap( 650 )

	UI.m_staticTextHelp23:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, True, "" ) )

	UI.bSizerHelp50:Add( UI.m_staticTextHelp23, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticTextHelp24 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "In BlackICE, unit training level has been reworked slightly. \nSame as in Vanilla, Training Laws are responsible for how much starting experience unit has, but what was changed is the speed at which units reinforce.\nPenalties (or bonuses) are now much higher, resulting in much slower Strength regain with Advanced or Specialist Training. As in reality - it takes far longer to get highly trained reinforcements. It might not be possible to keep Specialised or even Advanced Training on for extensive periods of time during war, expecially during long periods of combat.", wx.wxDefaultPosition, wx.wxSize( -1,-1 ), wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp24:Wrap( 370 )

	UI.m_staticTextHelp24:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizerHelp50:Add( UI.m_staticTextHelp24, 0, wx.wxALIGN_CENTER + wx.wxALL, 0 )


	UI.gSizerHelpMisc0:Add( UI.bSizerHelp50, 1, wx.wxEXPAND, 5 )

	UI.bSizerHelp51 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticTextHelp271 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Event Spawned Units", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp271:Wrap( 650 )

	UI.m_staticTextHelp271:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, True, "" ) )

	UI.bSizerHelp51:Add( UI.m_staticTextHelp271, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticTextHelp27 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Due to game engine limitations, event spawned units are spawned directly on the map instead of in the production queue. ", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp27:Wrap( 320 )

	UI.m_staticTextHelp27:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizerHelp51:Add( UI.m_staticTextHelp27, 0, wx.wxALIGN_CENTER + wx.wxALL, 1 )

	UI.m_staticTextHelp26 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "Each unit adds its cost to the ICDays variable, which, if it is greater than 1, will activate an IC penalty.\nThat IC penalty represents your countries investment into building those units and each week the ICDays variable gets counted down, scaled to your IC and investment value, until it reaches 0.\nAt that point the penalty will disappear.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp26:Wrap( 320 )

	UI.m_staticTextHelp26:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizerHelp51:Add( UI.m_staticTextHelp26, 0, wx.wxALIGN_CENTER + wx.wxALL, 1 )

	UI.m_staticTextHelp29 = wx.wxStaticText( UI.m_scrolledWindow_HelpMisc, wx.wxID_ANY, "\nUnits that will be removed by events have yellow coloured names.\n", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp29:Wrap( 320 )

	UI.m_staticTextHelp29:SetFont( wx.wxFont( wx.wxNORMAL_FONT:GetPointSize(), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, False, "" ) )

	UI.bSizerHelp51:Add( UI.m_staticTextHelp29, 0, wx.wxALIGN_CENTER + wx.wxALL, 1 )


	UI.gSizerHelpMisc0:Add( UI.bSizerHelp51, 1, wx.wxEXPAND, 5 )


	UI.m_scrolledWindow_HelpMisc:SetSizer( UI.gSizerHelpMisc0 )
	UI.m_scrolledWindow_HelpMisc:Layout()
	UI.gSizerHelpMisc0:Fit( UI.m_scrolledWindow_HelpMisc )
	UI.m_notebook2:AddPage(UI.m_scrolledWindow_HelpMisc, "Misc", True )
	UI.m_scrolledWindow_Ministers = wx.wxScrolledWindow( UI.m_notebook2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxHSCROLL + wx.wxVSCROLL )
	UI.m_scrolledWindow_Ministers:SetScrollRate( 30, 30 )
	UI.bSizerHelp1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_staticTextHelp1 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "In BlackICE, ministers don't only give flat effects, but they are now also responsible for your country's civilian and war economy.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp1:Wrap( 500 )

	UI.m_staticTextHelp1:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD, True, "" ) )

	UI.bSizerHelp1:Add( UI.m_staticTextHelp1, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.m_staticTextHelp2 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "Depending on your choice of ministers for each position you will gain different types of buildings from time to time which are not normally buildable.\nYou only need one type of minister to get the matching building, but having multiple ministers for the same building increases the amount gained.\nSome ministers also give 2x for certain buildings.\nIf the selected national focus matches the minister the building speed will be doubled.", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp2:Wrap( 650 )

	UI.m_staticTextHelp2:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.bSizerHelp1:Add( UI.m_staticTextHelp2, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )

	UI.gSizer38 = wx.wxGridSizer( 0, 3, 0, 0 )

	UI.m_staticTextHelp9 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Smallarms Factory---\n--Army focus--\n2x Infantry Proponent\n2x School of mass combat\n1x Old General\n1x Military Entrepreneur\n1x Guns and butter doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp9:Wrap( -1 )

	UI.m_staticTextHelp9:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp9, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp10 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Artillery Factory---\n--Army focus--\n2x School of fire support\n1x Old General\n1x Military Entrepreneur\n1x Guns and butter doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp10:Wrap( -1 )

	UI.m_staticTextHelp10:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp10, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp11 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Tank Factory---\n--Army focus--\n2x Tank Proponent\n2x Armoured Spearhead Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp11:Wrap( -1 )

	UI.m_staticTextHelp11:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp11, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp18 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Automotive Factory---\n--Army focus--\n2x School of Manoeuvre\n1x Logistics Specialist", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp18:Wrap( -1 )

	UI.m_staticTextHelp18:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp18, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp3 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Light Aircraft Factory---\n--Air focus--\n2x Single Engine Aircraft Proponent\n2x Air Superiority Doctrine\n1x Old Air Marshal\n1x Air Superiority Proponent\n1x Naval Aviation Doctrine\n1x Army Aviation Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp3:Wrap( -1 )

	UI.m_staticTextHelp3:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp3, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp4 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Medium Aircraft Factory---\n--Air focus--\n2x Twin Engine Aircraft Proponent\n2x Vertical Envelopment Doctrine\n1x Naval Aviation Doctrine\n1x Army Aviation Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp4:Wrap( -1 )

	UI.m_staticTextHelp4:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp4, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp5 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Heavy Aircraft Factory---\n--Air focus--\n2x Strategic Air Proponent\n2x Carpet Bombing Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp5:Wrap( -1 )

	UI.m_staticTextHelp5:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp5, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp16 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Radar Station---\n--Air focus--\n2x Air Superiority Proponent", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp16:Wrap( -1 )

	UI.m_staticTextHelp16:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp16, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp12 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Capital Shipyard---\n--Navy focus--\n2x Decisive Naval Battle Doctrine\n1x Old Admiral\n1x Battle fleet proponent", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp12:Wrap( -1 )

	UI.m_staticTextHelp12:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp12, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp13 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Medium Shipyard---\n--Navy focus--\n1x Open Seas Doctrine\n1x Old Admiral\n1x Battle fleet proponent", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp13:Wrap( -1 )

	UI.m_staticTextHelp13:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp13, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp14 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Small Shipyard---\n--Navy focus--\n1x Open Seas Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp14:Wrap( -1 )

	UI.m_staticTextHelp14:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp14, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp15 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Submarine Shipyard---\n--Navy focus--\n2x Submarine Proponent\n2x Indirect Approach Doctrine", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp15:Wrap( -1 )

	UI.m_staticTextHelp15:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp15, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp7 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Heavy Industry---\n--Economic focus--\n2x Silent Workhorse\n2x Administrative Genius", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp7:Wrap( -1 )

	UI.m_staticTextHelp7:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp7, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp8 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Manufacturing Plant---\n--Economic focus--\n1x Military Entrepreneur\n1x Logistics Specialist", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp8:Wrap( -1 )

	UI.m_staticTextHelp8:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp8, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp20 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Rail Terminous---\n--Economy focus--\n2x Logistics Specialist", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp20:Wrap( -1 )

	UI.m_staticTextHelp20:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp20, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp17 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Research Lab---\n--Science focus--\n2x Theoretical Scientist\n1x Biased Intellectual\n1x Silent Lawyer\n1x Technical Specialist\n3x Research Specialist (only focus)", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp17:Wrap( -1 )

	UI.m_staticTextHelp17:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp17, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp6 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Training Base---\n--Health + Education focus--\n2x General Staffer\n2x School of Psychology", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp6:Wrap( -1 )

	UI.m_staticTextHelp6:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp6, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp21 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Hospital---\n--Health + Education focus--\n2x Man of the People\n1x School of Psychology", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp21:Wrap( -1 )

	UI.m_staticTextHelp21:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp21, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )

	UI.m_staticTextHelp19 = wx.wxStaticText( UI.m_scrolledWindow_Ministers, wx.wxID_ANY, "---Resource buildings---\n--Resource focus--\n2x Resource Industrialist", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxALIGN_CENTER_HORIZONTAL )
	UI.m_staticTextHelp19:Wrap( -1 )

	UI.m_staticTextHelp19:SetFont( wx.wxFont( 10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, False, "" ) )

	UI.gSizer38:Add( UI.m_staticTextHelp19, 0, wx.wxALIGN_CENTER_HORIZONTAL + wx.wxALL, 5 )


	UI.bSizerHelp1:Add( UI.gSizer38, 1, wx.wxALIGN_CENTER, 5 )


	UI.m_scrolledWindow_Ministers:SetSizer( UI.bSizerHelp1 )
	UI.m_scrolledWindow_Ministers:Layout()
	UI.bSizerHelp1:Fit( UI.m_scrolledWindow_Ministers )
	UI.m_notebook2:AddPage(UI.m_scrolledWindow_Ministers, "Ministers + Buildings", False )
	UI.m_scrolledWindow_NatFocus = wx.wxScrolledWindow( UI.m_notebook2, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxHSCROLL + wx.wxVSCROLL )
	UI.m_scrolledWindow_NatFocus:SetScrollRate( 30, 30 )
	UI.bSizerHelpNatFocus1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_grid_nat_focuses = wx.wxGrid( UI.m_scrolledWindow_NatFocus, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( -1,-1 ), 0 )

	-- Grid
	UI.m_grid_nat_focuses:CreateGrid( 1, 7 )
	UI.m_grid_nat_focuses:EnableEditing( False )
	UI.m_grid_nat_focuses:EnableGridLines( True )
	UI.m_grid_nat_focuses:SetGridLineColour( wx.wxColour( 0, 0, 0 ) )
	UI.m_grid_nat_focuses:EnableDragGridSize( False )
	UI.m_grid_nat_focuses:SetMargins( 1, 1 )

	-- Columns
	UI.m_grid_nat_focuses:AutoSizeColumns()
	UI.m_grid_nat_focuses:EnableDragColSize( True )
	UI.m_grid_nat_focuses:SetColLabelValue( 0, "-" )
	UI.m_grid_nat_focuses:SetColLabelValue( 1, "-" )
	UI.m_grid_nat_focuses:SetColLabelValue( 2, "-" )
	UI.m_grid_nat_focuses:SetColLabelValue( 3, "-" )
	UI.m_grid_nat_focuses:SetColLabelValue( 4, "-" )
	UI.m_grid_nat_focuses:SetColLabelValue( 5, "-" )
	UI.m_grid_nat_focuses:SetColLabelValue( 6, "-" )
	UI.m_grid_nat_focuses:SetColLabelValue( 7, "-" )
	UI.m_grid_nat_focuses:SetColLabelSize( 1 )
	UI.m_grid_nat_focuses:SetColLabelAlignment( wx.wxALIGN_CENTER, wx.wxALIGN_CENTER )

	-- Rows
	UI.m_grid_nat_focuses:EnableDragRowSize( True )
	UI.m_grid_nat_focuses:SetRowLabelSize( 1 )
	UI.m_grid_nat_focuses:SetRowLabelAlignment( wx.wxALIGN_CENTER, wx.wxALIGN_CENTER )

	-- Label Appearance
	UI.m_grid_nat_focuses:SetLabelBackgroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_MENU ) )

	-- Cell Defaults
	UI.m_grid_nat_focuses:SetDefaultCellBackgroundColour( wx.wxSystemSettings.GetColour( wx.wxSYS_COLOUR_MENU ) )
	UI.m_grid_nat_focuses:SetDefaultCellAlignment( wx.wxALIGN_CENTER, wx.wxALIGN_CENTER )
	UI.bSizerHelpNatFocus1:Add( UI.m_grid_nat_focuses, 0, wx.wxALIGN_CENTER + wx.wxALL, 5 )


	UI.m_scrolledWindow_NatFocus:SetSizer( UI.bSizerHelpNatFocus1 )
	UI.m_scrolledWindow_NatFocus:Layout()
	UI.bSizerHelpNatFocus1:Fit( UI.m_scrolledWindow_NatFocus )
	UI.m_notebook2:AddPage(UI.m_scrolledWindow_NatFocus, "National Focus", False )


	UI.MyFrame2 .m_mgr:Update()
	UI.MyFrame2:Centre( wx.wxBOTH )

	UI.MyFrame2:Show(false)

end