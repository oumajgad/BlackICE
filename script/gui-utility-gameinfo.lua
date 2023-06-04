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

	UI.m_panel_GameInfo1 = wx.wxPanel( UI.m_notebook5, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTAB_TRAVERSAL )
	UI.bSizer_GameInfo1 = wx.wxBoxSizer( wx.wxVERTICAL )

	UI.m_choice_TraitsChoices = {}
	UI.m_choice_Traits = wx.wxChoice( UI.m_panel_GameInfo1, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 350,-1 ), UI.m_choice_TraitsChoices, 0 )
	UI.m_choice_Traits:SetSelection( 0 )
	UI.bSizer_GameInfo1:Add( UI.m_choice_Traits, 0, wx.wxALL + wx.wxEXPAND, 5 )

	UI.m_textCtrl_Trait = wx.wxTextCtrl( UI.m_panel_GameInfo1, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize( -1,-1 ), wx.wxTE_MULTILINE + wx.wxTE_WORDWRAP )
	UI.m_textCtrl_Trait:SetMinSize( wx.wxSize( -1,395 ) )

	UI.bSizer_GameInfo1:Add( UI.m_textCtrl_Trait, 1, wx.wxALL + wx.wxEXPAND, 5 )


	UI.m_panel_GameInfo1:SetSizer( UI.bSizer_GameInfo1 )
	UI.m_panel_GameInfo1:Layout()
	UI.bSizer_GameInfo1:Fit( UI.m_panel_GameInfo1 )
	UI.m_notebook5:AddPage(UI.m_panel_GameInfo1, "Traits", False )


	UI.MyFrame4 .m_mgr:Update()
	UI.MyFrame4:Centre( wx.wxBOTH )

	UI.MyFrame4:Show(false)
	-- Connect Events

    UI.m_choice_Traits:Connect( wx. wxEVT_COMMAND_CHOICE_SELECTED, function(event)
        local selectionString = UI.m_choice_Traits:GetString(UI.m_choice_Traits:GetSelection())
        local traitName = Parsing.GetTraitFromChoice(selectionString)
        local trait = Parsing.Traits[traitName]
        if trait ~= nil then
            local s = Utils.Dump(trait)
            if Parsing.TraitsTriggers[traitName] ~= nil then
                s = s .. "\n -------- Triggers -------- \n"
                s = s .. Utils.Dump(Parsing.TraitsTriggers[traitName])
            end
            UI.m_textCtrl_Trait:SetValue(s)
        end
    end )
end
