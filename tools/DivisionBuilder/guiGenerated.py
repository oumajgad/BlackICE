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
        wx.Frame.__init__ ( self, parent, id = wx.ID_ANY, title = u"Division Builder", pos = wx.DefaultPosition, size = wx.Size( 1100,700 ), style = wx.CAPTION|wx.CLOSE_BOX|wx.MAXIMIZE_BOX|wx.MINIMIZE_BOX|wx.RESIZE_BORDER|wx.SYSTEM_MENU|wx.TAB_TRAVERSAL )

        self.SetSizeHints( wx.Size( 1100,700 ), wx.DefaultSize )
        self.SetBackgroundColour( wx.SystemSettings.GetColour( wx.SYS_COLOUR_WINDOW ) )
        self.m_mgr = wx.aui.AuiManager()
        self.m_mgr.SetManagedWindow( self )
        self.m_mgr.SetFlags(wx.aui.AUI_MGR_DEFAULT)

        self.m_panel4 = wx.Panel( self, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, wx.TAB_TRAVERSAL )
        self.m_mgr.AddPane( self.m_panel4, wx.aui.AuiPaneInfo() .Left() .CaptionVisible( False ).CloseButton( False ).Dock().Resizable().FloatingSize( wx.DefaultSize ).CentrePane() )

        fgSizer3 = wx.FlexGridSizer( 4, 4, 10, 10 )
        fgSizer3.AddGrowableCol( 0 )
        fgSizer3.AddGrowableCol( 1 )
        fgSizer3.AddGrowableCol( 2 )
        fgSizer3.AddGrowableCol( 3 )
        fgSizer3.AddGrowableRow( 1 )
        fgSizer3.SetFlexibleDirection( wx.BOTH )
        fgSizer3.SetNonFlexibleGrowMode( wx.FLEX_GROWMODE_SPECIFIED )

        self.m_staticText1 = wx.StaticText( self.m_panel4, wx.ID_ANY, u"Techlist", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText1.Wrap( -1 )

        fgSizer3.Add( self.m_staticText1, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_staticText2 = wx.StaticText( self.m_panel4, wx.ID_ANY, u"Selected Tech", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText2.Wrap( -1 )

        fgSizer3.Add( self.m_staticText2, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_staticText3 = wx.StaticText( self.m_panel4, wx.ID_ANY, u"Brigade", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText3.Wrap( -1 )

        fgSizer3.Add( self.m_staticText3, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_staticText4 = wx.StaticText( self.m_panel4, wx.ID_ANY, u"Current Division", wx.DefaultPosition, wx.DefaultSize, 0 )
        self.m_staticText4.Wrap( -1 )

        fgSizer3.Add( self.m_staticText4, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        bSizer1 = wx.BoxSizer( wx.VERTICAL )

        m_listBox_techsChoices = []
        self.m_listBox_techs = wx.ListBox( self.m_panel4, wx.ID_ANY, wx.DefaultPosition, wx.Size( -1,-1 ), m_listBox_techsChoices, wx.LB_SINGLE )
        self.m_listBox_techs.SetMinSize( wx.Size( 100,520 ) )

        bSizer1.Add( self.m_listBox_techs, 1, wx.ALL|wx.EXPAND, 5 )


        fgSizer3.Add( bSizer1, 1, wx.EXPAND, 5 )

        bSizer2 = wx.BoxSizer( wx.VERTICAL )

        self.m_textCtrl_selected_tech = wx.TextCtrl( self.m_panel4, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        self.m_textCtrl_selected_tech.SetMinSize( wx.Size( 200,520 ) )

        bSizer2.Add( self.m_textCtrl_selected_tech, 1, wx.ALL|wx.EXPAND, 5 )


        fgSizer3.Add( bSizer2, 1, wx.EXPAND, 5 )

        bSizer3 = wx.BoxSizer( wx.VERTICAL )

        m_choice_brigadesChoices = []
        self.m_choice_brigades = wx.Choice( self.m_panel4, wx.ID_ANY, wx.DefaultPosition, wx.DefaultSize, m_choice_brigadesChoices, 0 )
        self.m_choice_brigades.SetSelection( 0 )
        bSizer3.Add( self.m_choice_brigades, 0, wx.ALL|wx.EXPAND, 5 )

        self.m_textCtrl_selected_brigade = wx.TextCtrl( self.m_panel4, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        self.m_textCtrl_selected_brigade.SetMinSize( wx.Size( 200,490 ) )

        bSizer3.Add( self.m_textCtrl_selected_brigade, 1, wx.ALL|wx.EXPAND, 5 )


        fgSizer3.Add( bSizer3, 1, wx.EXPAND, 5 )

        bSizer4 = wx.BoxSizer( wx.VERTICAL )

        m_listBox_division_brigadesChoices = []
        self.m_listBox_division_brigades = wx.ListBox( self.m_panel4, wx.ID_ANY, wx.DefaultPosition, wx.Size( -1,-1 ), m_listBox_division_brigadesChoices, wx.LB_SINGLE )
        self.m_listBox_division_brigades.SetMinSize( wx.Size( 200,150 ) )

        bSizer4.Add( self.m_listBox_division_brigades, 0, wx.ALL|wx.EXPAND, 5 )

        self.m_textCtrl_current_division_stats = wx.TextCtrl( self.m_panel4, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_MULTILINE )
        self.m_textCtrl_current_division_stats.SetMinSize( wx.Size( 200,300 ) )

        bSizer4.Add( self.m_textCtrl_current_division_stats, 1, wx.ALL|wx.EXPAND, 5 )


        fgSizer3.Add( bSizer4, 1, wx.EXPAND, 5 )


        fgSizer3.Add( ( 0, 0), 1, wx.EXPAND, 5 )

        gSizer2 = wx.GridSizer( 1, 2, 0, 0 )

        self.m_button_tech_increase = wx.Button( self.m_panel4, wx.ID_ANY, u"Increase Level", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer2.Add( self.m_button_tech_increase, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_button_tech_decrease = wx.Button( self.m_panel4, wx.ID_ANY, u"Decrease Level", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer2.Add( self.m_button_tech_decrease, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        fgSizer3.Add( gSizer2, 1, wx.EXPAND, 5 )

        gSizer4 = wx.GridSizer( 0, 0, 0, 0 )

        self.m_button_add_to_div = wx.Button( self.m_panel4, wx.ID_ANY, u"Add to Division", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer4.Add( self.m_button_add_to_div, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        fgSizer3.Add( gSizer4, 1, wx.EXPAND, 5 )

        gSizer3 = wx.GridSizer( 0, 2, 0, 0 )

        self.m_button_edit_brigade = wx.Button( self.m_panel4, wx.ID_ANY, u"Edit Brigade", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer3.Add( self.m_button_edit_brigade, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_button_division_reset = wx.Button( self.m_panel4, wx.ID_ANY, u"Reset", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer3.Add( self.m_button_division_reset, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        fgSizer3.Add( gSizer3, 1, wx.EXPAND, 5 )


        fgSizer3.Add( ( 0, 30), 1, wx.EXPAND, 5 )


        self.m_panel4.SetSizer( fgSizer3 )
        self.m_panel4.Layout()
        fgSizer3.Fit( self.m_panel4 )

        self.m_mgr.Update()
        self.Centre( wx.BOTH )

        # Connect Events
        self.Bind( wx.EVT_CLOSE, self.MyFrame1OnClose )
        self.m_listBox_techs.Bind( wx.EVT_LISTBOX, self.m_listBox_techsOnListBox )
        self.m_choice_brigades.Bind( wx.EVT_CHOICE, self.m_choice_brigadesOnChoice )
        self.m_listBox_division_brigades.Bind( wx.EVT_LISTBOX, self.m_listBox_division_brigadesOnListBox )
        self.m_button_tech_increase.Bind( wx.EVT_BUTTON, self.m_button_tech_increaseOnButtonClick )
        self.m_button_tech_decrease.Bind( wx.EVT_BUTTON, self.m_button_tech_decreaseOnButtonClick )
        self.m_button_add_to_div.Bind( wx.EVT_BUTTON, self.m_button_add_to_divOnButtonClick )
        self.m_button_edit_brigade.Bind( wx.EVT_BUTTON, self.m_button_edit_brigadeOnButtonClick )
        self.m_button_division_reset.Bind( wx.EVT_BUTTON, self.m_button_division_resetOnButtonClick )

    def __del__( self ):
        self.m_mgr.UnInit()



    # Virtual event handlers, override them in your derived class
    def MyFrame1OnClose( self, event ):
        event.Skip()

    def m_listBox_techsOnListBox( self, event ):
        event.Skip()

    def m_choice_brigadesOnChoice( self, event ):
        event.Skip()

    def m_listBox_division_brigadesOnListBox( self, event ):
        event.Skip()

    def m_button_tech_increaseOnButtonClick( self, event ):
        event.Skip()

    def m_button_tech_decreaseOnButtonClick( self, event ):
        event.Skip()

    def m_button_add_to_divOnButtonClick( self, event ):
        event.Skip()

    def m_button_edit_brigadeOnButtonClick( self, event ):
        event.Skip()

    def m_button_division_resetOnButtonClick( self, event ):
        event.Skip()


