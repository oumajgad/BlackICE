# -*- coding: utf-8 -*-

###########################################################################
## Python code generated with wxFormBuilder (version 3.10.1-0-g8feb16b3)
## http://www.wxformbuilder.org/
##
## PLEASE DO *NOT* EDIT THIS FILE!
###########################################################################

import wx
import wx.xrc
import wx.aui

###########################################################################
## Class MyFrame1
###########################################################################

class MyFrame1 ( wx.Frame ):

    def __init__( self, parent ):
        wx.Frame.__init__ ( self, parent, id = wx.ID_ANY, title = u"Division Builder", pos = wx.DefaultPosition, size = wx.Size( 1400,800 ), style = wx.CAPTION|wx.CLOSE_BOX|wx.MAXIMIZE_BOX|wx.MINIMIZE_BOX|wx.RESIZE_BORDER|wx.SYSTEM_MENU|wx.TAB_TRAVERSAL )

        self.SetSizeHints( wx.Size( 1400,800 ), wx.DefaultSize )
        self.SetBackgroundColour( wx.SystemSettings.GetColour( wx.SYS_COLOUR_WINDOW ) )
        self.m_mgr = wx.aui.AuiManager()
        self.m_mgr.SetManagedWindow( self )
        self.m_mgr.SetFlags(wx.aui.AUI_MGR_DEFAULT)

        self.m_notebook1 = wx.Notebook( self, wx.ID_ANY, wx.DefaultPosition, wx.Size( -1,-1 ), wx.NB_MULTILINE )
        self.m_notebook1.SetMinSize( wx.Size( 1400,800 ) )

        self.m_mgr.AddPane( self.m_notebook1, wx.aui.AuiPaneInfo() .Left() .CaptionVisible( False ).CloseButton( False ).Dock().Resizable().FloatingSize( wx.DefaultSize ).MinSize( wx.Size( 1400,800 ) ).CentrePane() )

        self.m_panel_builder = wx.Panel( self.m_notebook1, wx.ID_ANY, wx.DefaultPosition, wx.Size( -1,-1 ), wx.TAB_TRAVERSAL )
        fgSizer3 = wx.FlexGridSizer( 4, 5, 10, 10 )
        fgSizer3.AddGrowableCol( 0 )
        fgSizer3.AddGrowableCol( 1 )
        fgSizer3.AddGrowableCol( 2 )
        fgSizer3.AddGrowableCol( 3 )
        fgSizer3.AddGrowableCol( 4 )
        fgSizer3.AddGrowableRow( 1 )
        fgSizer3.SetFlexibleDirection( wx.BOTH )
        fgSizer3.SetNonFlexibleGrowMode( wx.FLEX_GROWMODE_SPECIFIED )

        self.m_staticText1 = wx.StaticText( self.m_panel_builder, wx.ID_ANY, u"Techlist", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText1.Wrap( -1 )

        fgSizer3.Add( self.m_staticText1, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_staticText2 = wx.StaticText( self.m_panel_builder, wx.ID_ANY, u"Selected Tech", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText2.Wrap( -1 )

        fgSizer3.Add( self.m_staticText2, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_staticText3 = wx.StaticText( self.m_panel_builder, wx.ID_ANY, u"Selected Brigade", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText3.Wrap( -1 )

        fgSizer3.Add( self.m_staticText3, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_staticText4 = wx.StaticText( self.m_panel_builder, wx.ID_ANY, u"Current Division", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText4.Wrap( -1 )

        fgSizer3.Add( self.m_staticText4, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_staticText6 = wx.StaticText( self.m_panel_builder, wx.ID_ANY, u"Saved Templates", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText6.Wrap( -1 )

        fgSizer3.Add( self.m_staticText6, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        bSizer1 = wx.BoxSizer( wx.VERTICAL )

        m_listBox_techsChoices = []
        self.m_listBox_techs = wx.ListBox( self.m_panel_builder, wx.ID_ANY, wx.DefaultPosition, wx.Size( -1,-1 ), m_listBox_techsChoices, wx.LB_SINGLE )
        self.m_listBox_techs.SetMinSize( wx.Size( 150,520 ) )

        bSizer1.Add( self.m_listBox_techs, 1, wx.ALL|wx.EXPAND, 5 )


        fgSizer3.Add( bSizer1, 1, wx.EXPAND, 5 )

        bSizer2 = wx.BoxSizer( wx.VERTICAL )

        self.m_textCtrl_selected_tech = wx.TextCtrl( self.m_panel_builder, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        self.m_textCtrl_selected_tech.SetMinSize( wx.Size( 100,520 ) )

        bSizer2.Add( self.m_textCtrl_selected_tech, 1, wx.ALL|wx.EXPAND, 5 )


        fgSizer3.Add( bSizer2, 1, wx.EXPAND, 5 )

        bSizer3 = wx.BoxSizer( wx.VERTICAL )

        m_choice_brigadesChoices = []
        self.m_choice_brigades = wx.Choice( self.m_panel_builder, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, m_choice_brigadesChoices, 0 )
        self.m_choice_brigades.SetSelection( 0 )
        bSizer3.Add( self.m_choice_brigades, 0, wx.ALL|wx.EXPAND, 5 )

        fgSizer2 = wx.FlexGridSizer( 1, 2, 0, 0 )
        fgSizer2.AddGrowableCol( 0 )
        fgSizer2.AddGrowableRow( 0 )
        fgSizer2.SetFlexibleDirection( wx.BOTH )
        fgSizer2.SetNonFlexibleGrowMode( wx.FLEX_GROWMODE_SPECIFIED )

        m_choice_brigades_searchedChoices = []
        self.m_choice_brigades_searched = wx.Choice( self.m_panel_builder, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, m_choice_brigades_searchedChoices, 0 )
        self.m_choice_brigades_searched.SetSelection( 0 )
        fgSizer2.Add( self.m_choice_brigades_searched, 0, wx.ALIGN_CENTER_VERTICAL|wx.ALL|wx.EXPAND, 5 )

        self.m_textCtrl_brigade_search = wx.TextCtrl( self.m_panel_builder, wx.ID_ANY, u"Brigade Search", wx.DefaultPosition, wx.DefaultSize, wx.TE_PROCESS_ENTER )
        fgSizer2.Add( self.m_textCtrl_brigade_search, 0, wx.ALIGN_CENTER|wx.ALL, 0 )


        bSizer3.Add( fgSizer2, 0, wx.EXPAND, 5 )

        self.m_textCtrl_selected_brigade = wx.TextCtrl( self.m_panel_builder, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        bSizer3.Add( self.m_textCtrl_selected_brigade, 1, wx.ALL|wx.EXPAND, 5 )


        fgSizer3.Add( bSizer3, 1, wx.EXPAND, 5 )

        bSizer4 = wx.BoxSizer( wx.VERTICAL )

        m_listBox_division_brigadesChoices = []
        self.m_listBox_division_brigades = wx.ListBox( self.m_panel_builder, wx.ID_ANY, wx.DefaultPosition, wx.Size( -1,-1 ), m_listBox_division_brigadesChoices, wx.LB_SINGLE )
        self.m_listBox_division_brigades.SetMinSize( wx.Size( 200,150 ) )

        bSizer4.Add( self.m_listBox_division_brigades, 0, wx.ALL|wx.EXPAND, 5 )

        self.m_textCtrl_current_division_stats = wx.TextCtrl( self.m_panel_builder, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        self.m_textCtrl_current_division_stats.SetMinSize( wx.Size( 200,300 ) )

        bSizer4.Add( self.m_textCtrl_current_division_stats, 1, wx.ALL|wx.EXPAND, 5 )


        fgSizer3.Add( bSizer4, 1, wx.EXPAND, 5 )

        bSizer6 = wx.BoxSizer( wx.VERTICAL )

        m_listBox_templatesChoices = []
        self.m_listBox_templates = wx.ListBox( self.m_panel_builder, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, m_listBox_templatesChoices, wx.LB_SINGLE )
        self.m_listBox_templates.SetMinSize( wx.Size( 200,350 ) )

        bSizer6.Add( self.m_listBox_templates, 0, wx.ALL|wx.EXPAND, 5 )

        gSizer5 = wx.GridSizer( 1, 2, 0, 0 )

        self.m_button_template_load = wx.Button( self.m_panel_builder, wx.ID_ANY, u"Load Selected", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer5.Add( self.m_button_template_load, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_button_templates_delete = wx.Button( self.m_panel_builder, wx.ID_ANY, u"Delete Selected", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer5.Add( self.m_button_templates_delete, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        bSizer6.Add( gSizer5, 0, wx.ALIGN_CENTER, 5 )

        self.m_staticText7 = wx.StaticText( self.m_panel_builder, wx.ID_ANY, u"Name:", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText7.Wrap( -1 )

        bSizer6.Add( self.m_staticText7, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_textCtrl_template_name = wx.TextCtrl( self.m_panel_builder, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_textCtrl_template_name.SetMinSize( wx.Size( 200,-1 ) )

        bSizer6.Add( self.m_textCtrl_template_name, 0, wx.ALL|wx.EXPAND, 5 )

        self.m_button_template_save = wx.Button( self.m_panel_builder, wx.ID_ANY, u"Save current Division", wx.DefaultPosition, wx.DefaultSize, 0 )
        bSizer6.Add( self.m_button_template_save, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_staticText8 = wx.StaticText( self.m_panel_builder, wx.ID_ANY, u"* Build cost and build time are affected by ingame effects (such as modifiers and laws) which are not calculated in this tool. The real values will be different.\n** Terrain modifiers ingame also get the base modifiers of the terrain added to them. These are only added to the division in this tool.", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText8.Wrap( 250 )

        bSizer6.Add( self.m_staticText8, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        fgSizer3.Add( bSizer6, 1, wx.EXPAND, 5 )


        fgSizer3.Add( ( 0, 0), 1, wx.EXPAND, 5 )

        gSizer2 = wx.GridSizer( 1, 2, 0, 0 )

        self.m_button_tech_increase = wx.Button( self.m_panel_builder, wx.ID_ANY, u"Increase Level", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer2.Add( self.m_button_tech_increase, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_button_tech_decrease = wx.Button( self.m_panel_builder, wx.ID_ANY, u"Decrease Level", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer2.Add( self.m_button_tech_decrease, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        fgSizer3.Add( gSizer2, 1, wx.EXPAND, 5 )

        gSizer4 = wx.GridSizer( 0, 0, 0, 0 )

        self.m_button_add_to_div = wx.Button( self.m_panel_builder, wx.ID_ANY, u"Add to Division", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer4.Add( self.m_button_add_to_div, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        fgSizer3.Add( gSizer4, 1, wx.EXPAND, 5 )

        gSizer3 = wx.GridSizer( 0, 2, 0, 0 )

        self.m_button_delete_brigade = wx.Button( self.m_panel_builder, wx.ID_ANY, u"Delete Brigade", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer3.Add( self.m_button_delete_brigade, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_button_division_reset = wx.Button( self.m_panel_builder, wx.ID_ANY, u"Reset", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer3.Add( self.m_button_division_reset, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        fgSizer3.Add( gSizer3, 1, wx.EXPAND, 5 )

        self.m_staticText9 = wx.StaticText( self.m_panel_builder, wx.ID_ANY, u"v1.5.0\nBy @dsafe", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText9.Wrap( -1 )

        fgSizer3.Add( self.m_staticText9, 0, wx.ALIGN_RIGHT|wx.ALL, 5 )


        self.m_panel_builder.SetSizer( fgSizer3 )
        self.m_panel_builder.Layout()
        fgSizer3.Fit( self.m_panel_builder )
        self.m_notebook1.AddPage( self.m_panel_builder, u"Builder", True )
        self.m_panel_compare = wx.Panel( self.m_notebook1, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, wx.TAB_TRAVERSAL )
        fgSizer31 = wx.FlexGridSizer( 2, 5, 0, 0 )
        fgSizer31.AddGrowableCol( 0 )
        fgSizer31.AddGrowableCol( 1 )
        fgSizer31.AddGrowableCol( 2 )
        fgSizer31.AddGrowableCol( 3 )
        fgSizer31.AddGrowableCol( 4 )
        fgSizer31.AddGrowableRow( 1 )
        fgSizer31.SetFlexibleDirection( wx.VERTICAL )
        fgSizer31.SetNonFlexibleGrowMode( wx.FLEX_GROWMODE_SPECIFIED )

        bSizer8 = wx.BoxSizer( wx.VERTICAL )

        self.m_staticText10 = wx.StaticText( self.m_panel_compare, wx.ID_ANY, u"Division A", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText10.Wrap( -1 )

        bSizer8.Add( self.m_staticText10, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        fgSizer4a = wx.FlexGridSizer( 1, 3, 0, 0 )
        fgSizer4a.AddGrowableCol( 1 )
        fgSizer4a.SetFlexibleDirection( wx.BOTH )
        fgSizer4a.SetNonFlexibleGrowMode( wx.FLEX_GROWMODE_SPECIFIED )

        self.m_button_div_a_clear = wx.Button( self.m_panel_compare, wx.ID_ANY, u"X", wx.DefaultPosition, wx.Size( 20,-1 ), 0 )
        self.m_button_div_a_clear.SetFont( wx.Font( wx.NORMAL_FONT.GetPointSize(), wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD, False, wx.EmptyString ) )
        self.m_button_div_a_clear.SetMinSize( wx.Size( 20,-1 ) )
        self.m_button_div_a_clear.SetMaxSize( wx.Size( 20,-1 ) )

        fgSizer4a.Add( self.m_button_div_a_clear, 0, wx.ALL, 5 )

        m_choice_div_aChoices = []
        self.m_choice_div_a = wx.Choice( self.m_panel_compare, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, m_choice_div_aChoices, 0 )
        self.m_choice_div_a.SetSelection( 0 )
        fgSizer4a.Add( self.m_choice_div_a, 0, wx.ALL|wx.EXPAND, 5 )

        self.m_checkBox_comp_sync_a = wx.CheckBox( self.m_panel_compare, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_checkBox_comp_sync_a.SetToolTip( u"Sync this scrollbar to the others." )

        fgSizer4a.Add( self.m_checkBox_comp_sync_a, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        bSizer8.Add( fgSizer4a, 1, wx.EXPAND, 5 )


        fgSizer31.Add( bSizer8, 1, wx.EXPAND, 5 )

        bSizer9 = wx.BoxSizer( wx.VERTICAL )

        self.m_staticText11 = wx.StaticText( self.m_panel_compare, wx.ID_ANY, u"Division B", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText11.Wrap( -1 )

        bSizer9.Add( self.m_staticText11, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        fgSizer4b = wx.FlexGridSizer( 1, 3, 0, 0 )
        fgSizer4b.AddGrowableCol( 1 )
        fgSizer4b.SetFlexibleDirection( wx.BOTH )
        fgSizer4b.SetNonFlexibleGrowMode( wx.FLEX_GROWMODE_SPECIFIED )

        self.m_button_div_b_clear = wx.Button( self.m_panel_compare, wx.ID_ANY, u"X", wx.DefaultPosition, wx.Size( 20,-1 ), 0 )
        self.m_button_div_b_clear.SetFont( wx.Font( wx.NORMAL_FONT.GetPointSize(), wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD, False, wx.EmptyString ) )
        self.m_button_div_b_clear.SetMinSize( wx.Size( 20,-1 ) )
        self.m_button_div_b_clear.SetMaxSize( wx.Size( 20,-1 ) )

        fgSizer4b.Add( self.m_button_div_b_clear, 0, wx.ALL, 5 )

        m_choice_div_bChoices = []
        self.m_choice_div_b = wx.Choice( self.m_panel_compare, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, m_choice_div_bChoices, 0 )
        self.m_choice_div_b.SetSelection( 0 )
        fgSizer4b.Add( self.m_choice_div_b, 0, wx.ALL|wx.EXPAND, 5 )

        self.m_checkBox_comp_sync_b = wx.CheckBox( self.m_panel_compare, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_checkBox_comp_sync_b.SetToolTip( u"Sync this scrollbar to the others." )

        fgSizer4b.Add( self.m_checkBox_comp_sync_b, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        bSizer9.Add( fgSizer4b, 1, wx.EXPAND, 5 )


        fgSizer31.Add( bSizer9, 1, wx.EXPAND, 5 )

        bSizer10 = wx.BoxSizer( wx.VERTICAL )

        self.m_staticText12 = wx.StaticText( self.m_panel_compare, wx.ID_ANY, u"Division C", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText12.Wrap( -1 )

        bSizer10.Add( self.m_staticText12, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        fgSizer4c = wx.FlexGridSizer( 1, 3, 0, 0 )
        fgSizer4c.AddGrowableCol( 1 )
        fgSizer4c.SetFlexibleDirection( wx.BOTH )
        fgSizer4c.SetNonFlexibleGrowMode( wx.FLEX_GROWMODE_SPECIFIED )

        self.m_button_div_c_clear = wx.Button( self.m_panel_compare, wx.ID_ANY, u"X", wx.DefaultPosition, wx.Size( 20,-1 ), 0 )
        self.m_button_div_c_clear.SetFont( wx.Font( wx.NORMAL_FONT.GetPointSize(), wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD, False, wx.EmptyString ) )
        self.m_button_div_c_clear.SetMinSize( wx.Size( 20,-1 ) )
        self.m_button_div_c_clear.SetMaxSize( wx.Size( 20,-1 ) )

        fgSizer4c.Add( self.m_button_div_c_clear, 0, wx.ALL, 5 )

        m_choice_div_cChoices = []
        self.m_choice_div_c = wx.Choice( self.m_panel_compare, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, m_choice_div_cChoices, 0 )
        self.m_choice_div_c.SetSelection( 0 )
        fgSizer4c.Add( self.m_choice_div_c, 0, wx.ALL|wx.EXPAND, 5 )

        self.m_checkBox_comp_sync_c = wx.CheckBox( self.m_panel_compare, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_checkBox_comp_sync_c.SetToolTip( u"Sync this scrollbar to the others." )

        fgSizer4c.Add( self.m_checkBox_comp_sync_c, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        bSizer10.Add( fgSizer4c, 1, wx.EXPAND, 5 )


        fgSizer31.Add( bSizer10, 1, wx.EXPAND, 5 )

        bSizer11 = wx.BoxSizer( wx.VERTICAL )

        self.m_staticText13 = wx.StaticText( self.m_panel_compare, wx.ID_ANY, u"Division D", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText13.Wrap( -1 )

        bSizer11.Add( self.m_staticText13, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        fgSizer4d = wx.FlexGridSizer( 1, 3, 0, 0 )
        fgSizer4d.AddGrowableCol( 1 )
        fgSizer4d.SetFlexibleDirection( wx.BOTH )
        fgSizer4d.SetNonFlexibleGrowMode( wx.FLEX_GROWMODE_SPECIFIED )

        self.m_button_div_d_clear = wx.Button( self.m_panel_compare, wx.ID_ANY, u"X", wx.DefaultPosition, wx.Size( 20,-1 ), 0 )
        self.m_button_div_d_clear.SetFont( wx.Font( wx.NORMAL_FONT.GetPointSize(), wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD, False, wx.EmptyString ) )
        self.m_button_div_d_clear.SetMinSize( wx.Size( 20,-1 ) )
        self.m_button_div_d_clear.SetMaxSize( wx.Size( 20,-1 ) )

        fgSizer4d.Add( self.m_button_div_d_clear, 0, wx.ALL, 5 )

        m_choice_div_dChoices = []
        self.m_choice_div_d = wx.Choice( self.m_panel_compare, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, m_choice_div_dChoices, 0 )
        self.m_choice_div_d.SetSelection( 0 )
        fgSizer4d.Add( self.m_choice_div_d, 0, wx.ALL|wx.EXPAND, 5 )

        self.m_checkBox_comp_sync_d = wx.CheckBox( self.m_panel_compare, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_checkBox_comp_sync_d.SetToolTip( u"Sync this scrollbar to the others." )

        fgSizer4d.Add( self.m_checkBox_comp_sync_d, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        bSizer11.Add( fgSizer4d, 1, wx.EXPAND, 5 )


        fgSizer31.Add( bSizer11, 1, wx.EXPAND, 5 )

        bSizer12 = wx.BoxSizer( wx.VERTICAL )

        self.m_staticText15 = wx.StaticText( self.m_panel_compare, wx.ID_ANY, u"Division E", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText15.Wrap( -1 )

        bSizer12.Add( self.m_staticText15, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        fgSizer4e = wx.FlexGridSizer( 1, 3, 0, 0 )
        fgSizer4e.AddGrowableCol( 1 )
        fgSizer4e.SetFlexibleDirection( wx.BOTH )
        fgSizer4e.SetNonFlexibleGrowMode( wx.FLEX_GROWMODE_SPECIFIED )

        self.m_button_div_e_clear = wx.Button( self.m_panel_compare, wx.ID_ANY, u"X", wx.DefaultPosition, wx.Size( 20,-1 ), 0 )
        self.m_button_div_e_clear.SetFont( wx.Font( wx.NORMAL_FONT.GetPointSize(), wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_BOLD, False, wx.EmptyString ) )
        self.m_button_div_e_clear.SetMinSize( wx.Size( 20,-1 ) )
        self.m_button_div_e_clear.SetMaxSize( wx.Size( 20,-1 ) )

        fgSizer4e.Add( self.m_button_div_e_clear, 0, wx.ALL, 5 )

        m_choice_div_eChoices = []
        self.m_choice_div_e = wx.Choice( self.m_panel_compare, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, m_choice_div_eChoices, 0 )
        self.m_choice_div_e.SetSelection( 0 )
        fgSizer4e.Add( self.m_choice_div_e, 0, wx.ALL|wx.EXPAND, 5 )

        self.m_checkBox_comp_sync_e = wx.CheckBox( self.m_panel_compare, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_checkBox_comp_sync_e.SetToolTip( u"Sync this scrollbar to the others." )

        fgSizer4e.Add( self.m_checkBox_comp_sync_e, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        bSizer12.Add( fgSizer4e, 1, wx.EXPAND, 5 )


        fgSizer31.Add( bSizer12, 1, wx.EXPAND, 5 )

        self.m_textCtrl_compare_div_a = wx.TextCtrl( self.m_panel_compare, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.Size( -1,-1 ), wx.TE_MULTILINE )
        fgSizer31.Add( self.m_textCtrl_compare_div_a, 1, wx.ALL|wx.EXPAND, 5 )

        self.m_textCtrl_compare_div_b = wx.TextCtrl( self.m_panel_compare, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        fgSizer31.Add( self.m_textCtrl_compare_div_b, 1, wx.ALL|wx.EXPAND, 5 )

        self.m_textCtrl_compare_div_c = wx.TextCtrl( self.m_panel_compare, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        fgSizer31.Add( self.m_textCtrl_compare_div_c, 1, wx.ALL|wx.EXPAND, 5 )

        self.m_textCtrl_compare_div_d = wx.TextCtrl( self.m_panel_compare, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        fgSizer31.Add( self.m_textCtrl_compare_div_d, 1, wx.ALL|wx.EXPAND, 5 )

        self.m_textCtrl_compare_div_e = wx.TextCtrl( self.m_panel_compare, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        fgSizer31.Add( self.m_textCtrl_compare_div_e, 1, wx.ALL|wx.EXPAND, 5 )


        self.m_panel_compare.SetSizer( fgSizer31 )
        self.m_panel_compare.Layout()
        fgSizer31.Fit( self.m_panel_compare )
        self.m_notebook1.AddPage( self.m_panel_compare, u"Compare", False )
        self.m_panel_search = wx.Panel( self.m_notebook1, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, wx.TAB_TRAVERSAL )
        fgSizer9 = wx.FlexGridSizer( 2, 4, 0, 5 )
        fgSizer9.AddGrowableCol( 0 )
        fgSizer9.AddGrowableCol( 1 )
        fgSizer9.AddGrowableCol( 2 )
        fgSizer9.AddGrowableCol( 3 )
        fgSizer9.AddGrowableRow( 1 )
        fgSizer9.SetFlexibleDirection( wx.BOTH )
        fgSizer9.SetNonFlexibleGrowMode( wx.FLEX_GROWMODE_SPECIFIED )

        self.m_staticText151 = wx.StaticText( self.m_panel_search, wx.ID_ANY, u"Brigade Search", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText151.Wrap( -1 )

        fgSizer9.Add( self.m_staticText151, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_staticText16 = wx.StaticText( self.m_panel_search, wx.ID_ANY, u"Searched Brigade", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText16.Wrap( -1 )

        fgSizer9.Add( self.m_staticText16, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_staticText18 = wx.StaticText( self.m_panel_search, wx.ID_ANY, u"Selected Brigade", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText18.Wrap( -1 )

        fgSizer9.Add( self.m_staticText18, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_staticText17 = wx.StaticText( self.m_panel_search, wx.ID_ANY, u"Current Division", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText17.Wrap( -1 )

        fgSizer9.Add( self.m_staticText17, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        bSizer121 = wx.BoxSizer( wx.VERTICAL )

        fgSizer21 = wx.FlexGridSizer( 1, 2, 0, 0 )
        fgSizer21.AddGrowableCol( 0 )
        fgSizer21.AddGrowableRow( 0 )
        fgSizer21.SetFlexibleDirection( wx.BOTH )
        fgSizer21.SetNonFlexibleGrowMode( wx.FLEX_GROWMODE_SPECIFIED )

        self.m_textCtrl15_search_stat_name = wx.TextCtrl( self.m_panel_search, wx.ID_ANY, u"Enter stat name", wx.DefaultPosition, wx.DefaultSize, wx.TE_PROCESS_ENTER )
        self.m_textCtrl15_search_stat_name.SetMinSize( wx.Size( 150,-1 ) )

        fgSizer21.Add( self.m_textCtrl15_search_stat_name, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_button17_search_sort = wx.Button( self.m_panel_search, wx.ID_ANY, u"Sort", wx.DefaultPosition, wx.DefaultSize, 0 )
        fgSizer21.Add( self.m_button17_search_sort, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        bSizer121.Add( fgSizer21, 0, wx.EXPAND, 5 )

        self.m_staticText20 = wx.StaticText( self.m_panel_search, wx.ID_ANY, u"Terrain can sorted by entering like:\n \"mountain:defence\"", wx.DefaultPosition, wx.DefaultSize, wx.ALIGN_CENTER_HORIZONTAL )
        self.m_staticText20.Wrap( -1 )

        bSizer121.Add( self.m_staticText20, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        gSizer6 = wx.GridSizer( 2, 2, 0, 0 )

        self.m_checkBox_search_filter_army = wx.CheckBox( self.m_panel_search, wx.ID_ANY, u"Remove Army", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer6.Add( self.m_checkBox_search_filter_army, 0, wx.ALIGN_CENTER|wx.ALL, 1 )

        self.m_checkBox_search_filter_planes = wx.CheckBox( self.m_panel_search, wx.ID_ANY, u"Remove Planes", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_checkBox_search_filter_planes.SetValue(True)
        gSizer6.Add( self.m_checkBox_search_filter_planes, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_checkBox_search_filter_ships = wx.CheckBox( self.m_panel_search, wx.ID_ANY, u"Remove Ships", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_checkBox_search_filter_ships.SetValue(True)
        gSizer6.Add( self.m_checkBox_search_filter_ships, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_checkBox_search_filter_hqs = wx.CheckBox( self.m_panel_search, wx.ID_ANY, u"Remove HQs", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_checkBox_search_filter_hqs.SetValue(True)
        gSizer6.Add( self.m_checkBox_search_filter_hqs, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        bSizer121.Add( gSizer6, 0, wx.EXPAND, 0 )

        m_listBox_searched_brigadesChoices = []
        self.m_listBox_searched_brigades = wx.ListBox( self.m_panel_search, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, m_listBox_searched_brigadesChoices, wx.LB_SINGLE )
        self.m_listBox_searched_brigades.SetMinSize( wx.Size( -1,400 ) )

        bSizer121.Add( self.m_listBox_searched_brigades, 1, wx.ALL|wx.EXPAND, 5 )


        fgSizer9.Add( bSizer121, 1, wx.EXPAND, 5 )

        bSizer13 = wx.BoxSizer( wx.VERTICAL )

        self.m_textCtrl_search_searched_brigade_stats = wx.TextCtrl( self.m_panel_search, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        self.m_textCtrl_search_searched_brigade_stats.SetMinSize( wx.Size( 300,590 ) )

        bSizer13.Add( self.m_textCtrl_search_searched_brigade_stats, 1, wx.ALL|wx.EXPAND, 5 )

        self.m_button_search_searched_brigade_add = wx.Button( self.m_panel_search, wx.ID_ANY, u"Add to Division", wx.DefaultPosition, wx.DefaultSize, 0 )
        bSizer13.Add( self.m_button_search_searched_brigade_add, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        fgSizer9.Add( bSizer13, 1, wx.EXPAND, 5 )

        bSizer15 = wx.BoxSizer( wx.VERTICAL )

        self.m_textCtrl_search_selected_brigade_stats = wx.TextCtrl( self.m_panel_search, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        self.m_textCtrl_search_selected_brigade_stats.SetMinSize( wx.Size( 300,590 ) )

        bSizer15.Add( self.m_textCtrl_search_selected_brigade_stats, 1, wx.ALL|wx.EXPAND, 5 )

        self.m_button_search_selected_brigade_remove = wx.Button( self.m_panel_search, wx.ID_ANY, u"Remove from Division", wx.DefaultPosition, wx.DefaultSize, 0 )
        bSizer15.Add( self.m_button_search_selected_brigade_remove, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        fgSizer9.Add( bSizer15, 1, wx.EXPAND, 5 )

        bSizer41 = wx.BoxSizer( wx.VERTICAL )

        m_listBox_search_division_brigadesChoices = []
        self.m_listBox_search_division_brigades = wx.ListBox( self.m_panel_search, wx.ID_ANY, wx.DefaultPosition, wx.Size( -1,-1 ), m_listBox_search_division_brigadesChoices, wx.LB_SINGLE )
        self.m_listBox_search_division_brigades.SetMinSize( wx.Size( 300,150 ) )

        bSizer41.Add( self.m_listBox_search_division_brigades, 0, wx.ALL|wx.EXPAND, 5 )

        self.m_textCtrl_search_current_division_stats = wx.TextCtrl( self.m_panel_search, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        self.m_textCtrl_search_current_division_stats.SetMinSize( wx.Size( 300,300 ) )

        bSizer41.Add( self.m_textCtrl_search_current_division_stats, 1, wx.ALL|wx.EXPAND, 5 )


        fgSizer9.Add( bSizer41, 1, wx.EXPAND, 5 )


        self.m_panel_search.SetSizer( fgSizer9 )
        self.m_panel_search.Layout()
        fgSizer9.Fit( self.m_panel_search )
        self.m_notebook1.AddPage( self.m_panel_search, u"Search and Sort", False )


        self.m_mgr.Update()
        self.Centre( wx.BOTH )

        # Connect Events
        self.Bind( wx.EVT_CLOSE, self.MyFrame1OnClose )
        self.m_listBox_techs.Bind( wx.EVT_LISTBOX, self.m_listBox_techsOnListBox )
        self.m_choice_brigades.Bind( wx.EVT_CHOICE, self.m_choice_brigadesOnChoice )
        self.m_choice_brigades_searched.Bind( wx.EVT_CHOICE, self.m_choice_brigades_searchedOnChoice )
        self.m_textCtrl_brigade_search.Bind( wx.EVT_TEXT_ENTER, self.m_textCtrl_brigade_searchOnTextEnter )
        self.m_listBox_division_brigades.Bind( wx.EVT_LISTBOX, self.m_listBox_division_brigadesOnListBox )
        self.m_button_template_load.Bind( wx.EVT_BUTTON, self.m_button_template_loadOnButtonClick )
        self.m_button_templates_delete.Bind( wx.EVT_BUTTON, self.m_button_templates_deleteOnButtonClick )
        self.m_button_template_save.Bind( wx.EVT_BUTTON, self.m_button_template_saveOnButtonClick )
        self.m_button_tech_increase.Bind( wx.EVT_BUTTON, self.m_button_tech_increaseOnButtonClick )
        self.m_button_tech_decrease.Bind( wx.EVT_BUTTON, self.m_button_tech_decreaseOnButtonClick )
        self.m_button_add_to_div.Bind( wx.EVT_BUTTON, self.m_button_add_to_divOnButtonClick )
        self.m_button_delete_brigade.Bind( wx.EVT_BUTTON, self.m_button_delete_brigadeOnButtonClick )
        self.m_button_division_reset.Bind( wx.EVT_BUTTON, self.m_button_division_resetOnButtonClick )
        self.m_button_div_a_clear.Bind( wx.EVT_BUTTON, self.m_button_div_a_clearOnButtonClick )
        self.m_choice_div_a.Bind( wx.EVT_CHOICE, self.m_choice_div_aOnChoice )
        self.m_button_div_b_clear.Bind( wx.EVT_BUTTON, self.m_button_div_b_clearOnButtonClick )
        self.m_choice_div_b.Bind( wx.EVT_CHOICE, self.m_choice_div_bOnChoice )
        self.m_button_div_c_clear.Bind( wx.EVT_BUTTON, self.m_button_div_c_clearOnButtonClick )
        self.m_choice_div_c.Bind( wx.EVT_CHOICE, self.m_choice_div_cOnChoice )
        self.m_button_div_d_clear.Bind( wx.EVT_BUTTON, self.m_button_div_d_clearOnButtonClick )
        self.m_choice_div_d.Bind( wx.EVT_CHOICE, self.m_choice_div_dOnChoice )
        self.m_button_div_e_clear.Bind( wx.EVT_BUTTON, self.m_button_div_e_clearOnButtonClick )
        self.m_choice_div_e.Bind( wx.EVT_CHOICE, self.m_choice_div_eOnChoice )
        self.m_textCtrl_compare_div_a.Bind( wx.EVT_UPDATE_UI, self.m_textCtrl_compare_div_aOnUpdateUI )
        self.m_textCtrl_compare_div_b.Bind( wx.EVT_UPDATE_UI, self.m_textCtrl_compare_div_bOnUpdateUI )
        self.m_textCtrl_compare_div_c.Bind( wx.EVT_UPDATE_UI, self.m_textCtrl_compare_div_cOnUpdateUI )
        self.m_textCtrl_compare_div_d.Bind( wx.EVT_UPDATE_UI, self.m_textCtrl_compare_div_dOnUpdateUI )
        self.m_textCtrl_compare_div_e.Bind( wx.EVT_UPDATE_UI, self.m_textCtrl_compare_div_eOnUpdateUI )
        self.m_textCtrl15_search_stat_name.Bind( wx.EVT_TEXT_ENTER, self.m_textCtrl15_search_stat_nameOnTextEnter )
        self.m_button17_search_sort.Bind( wx.EVT_BUTTON, self.m_button17_search_sortOnButtonClick )
        self.m_listBox_searched_brigades.Bind( wx.EVT_LISTBOX, self.m_listBox_searched_brigadesOnListBox )
        self.m_button_search_searched_brigade_add.Bind( wx.EVT_BUTTON, self.m_button_search_searched_brigade_addOnButtonClick )
        self.m_button_search_selected_brigade_remove.Bind( wx.EVT_BUTTON, self.m_button_search_selected_brigade_removeOnButtonClick )
        self.m_listBox_search_division_brigades.Bind( wx.EVT_LISTBOX, self.m_listBox_search_division_brigadesOnListBox )

    def __del__( self ):
        self.m_mgr.UnInit()



    # Virtual event handlers, override them in your derived class
    def MyFrame1OnClose( self, event ):
        event.Skip()

    def m_listBox_techsOnListBox( self, event ):
        event.Skip()

    def m_choice_brigadesOnChoice( self, event ):
        event.Skip()

    def m_choice_brigades_searchedOnChoice( self, event ):
        event.Skip()

    def m_textCtrl_brigade_searchOnTextEnter( self, event ):
        event.Skip()

    def m_listBox_division_brigadesOnListBox( self, event ):
        event.Skip()

    def m_button_template_loadOnButtonClick( self, event ):
        event.Skip()

    def m_button_templates_deleteOnButtonClick( self, event ):
        event.Skip()

    def m_button_template_saveOnButtonClick( self, event ):
        event.Skip()

    def m_button_tech_increaseOnButtonClick( self, event ):
        event.Skip()

    def m_button_tech_decreaseOnButtonClick( self, event ):
        event.Skip()

    def m_button_add_to_divOnButtonClick( self, event ):
        event.Skip()

    def m_button_delete_brigadeOnButtonClick( self, event ):
        event.Skip()

    def m_button_division_resetOnButtonClick( self, event ):
        event.Skip()

    def m_button_div_a_clearOnButtonClick( self, event ):
        event.Skip()

    def m_choice_div_aOnChoice( self, event ):
        event.Skip()

    def m_button_div_b_clearOnButtonClick( self, event ):
        event.Skip()

    def m_choice_div_bOnChoice( self, event ):
        event.Skip()

    def m_button_div_c_clearOnButtonClick( self, event ):
        event.Skip()

    def m_choice_div_cOnChoice( self, event ):
        event.Skip()

    def m_button_div_d_clearOnButtonClick( self, event ):
        event.Skip()

    def m_choice_div_dOnChoice( self, event ):
        event.Skip()

    def m_button_div_e_clearOnButtonClick( self, event ):
        event.Skip()

    def m_choice_div_eOnChoice( self, event ):
        event.Skip()

    def m_textCtrl_compare_div_aOnUpdateUI( self, event ):
        event.Skip()

    def m_textCtrl_compare_div_bOnUpdateUI( self, event ):
        event.Skip()

    def m_textCtrl_compare_div_cOnUpdateUI( self, event ):
        event.Skip()

    def m_textCtrl_compare_div_dOnUpdateUI( self, event ):
        event.Skip()

    def m_textCtrl_compare_div_eOnUpdateUI( self, event ):
        event.Skip()

    def m_textCtrl15_search_stat_nameOnTextEnter( self, event ):
        event.Skip()

    def m_button17_search_sortOnButtonClick( self, event ):
        event.Skip()

    def m_listBox_searched_brigadesOnListBox( self, event ):
        event.Skip()

    def m_button_search_searched_brigade_addOnButtonClick( self, event ):
        event.Skip()

    def m_button_search_selected_brigade_removeOnButtonClick( self, event ):
        event.Skip()

    def m_listBox_search_division_brigadesOnListBox( self, event ):
        event.Skip()


