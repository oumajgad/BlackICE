package.cpath = package.cpath..";./tfh/mod/?.dll;"
require("wx")


-- UI = {}

if wx ~= nil then
	UI.MyFrame4 = wx.wxFrame (wx.NULL, wx.wxID_ANY, "Hoi3 Utility Game Info", wx.wxDefaultPosition, wx.wxSize( 500,500 ), wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxMAXIMIZE_BOX + wx.wxMINIMIZE_BOX + wx.wxRESIZE_BORDER + wx.wxSYSTEM_MENU+wx.wxTAB_TRAVERSAL )
	UI.MyFrame4:SetSizeHints( wx.wxSize( 500,500 ), wx.wxDefaultSize )
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

	UI.m_textCtrl_Trait = wx.wxTextCtrl( UI.m_panel_GameInfo_Traits, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( -1,-1 ), wx.wxTE_MULTILINE + wx.wxTE_WORDWRAP )
	UI.m_textCtrl_Trait:SetMinSize( wx.wxSize( -1,395 ) )

	UI.bSizer_GameInfo1:Add( UI.m_textCtrl_Trait, 1, wx.wxALL + wx.wxEXPAND, 5 )


	UI.m_panel_GameInfo_Traits:SetSizer( UI.bSizer_GameInfo1 )
	UI.m_panel_GameInfo_Traits:Layout()
	UI.bSizer_GameInfo1:Fit( UI.m_panel_GameInfo_Traits )
	UI.m_notebook5:AddPage(UI.m_panel_GameInfo_Traits, "Traits", False )
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


	UI.MyFrame4 .m_mgr:Update()
	UI.MyFrame4:Centre( wx.wxBOTH )

	UI.MyFrame4:Show(false)
	-- Connect Events

    UI.m_choice_Traits:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
        local selectionString = UI.m_choice_Traits:GetString(UI.m_choice_Traits:GetSelection())
        local traitName = Parsing.GetKeyFromChoice(selectionString)
        local trait = Parsing.Traits.TraitsData[traitName]
        if trait ~= nil then
            local s = Utils.Dump(trait)
            if Parsing.Traits.TraitsTriggers[traitName] ~= nil then
                s = s .. "\n -------- Triggers -------- \n"
                s = s .. Utils.Dump(Parsing.Traits.TraitsTriggers[traitName])
            end
            UI.m_textCtrl_Trait:SetValue(s)
        end
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
end
