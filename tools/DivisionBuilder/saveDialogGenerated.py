# -*- coding: utf-8 -*-

###########################################################################
## Python code generated with wxFormBuilder (version 3.10.1-0-g8feb16b3)
## http://www.wxformbuilder.org/
##
## PLEASE DO *NOT* EDIT THIS FILE!
###########################################################################

import wx
import wx.xrc

###########################################################################
## Class MyDialog1
###########################################################################

class MyDialog1 ( wx.Dialog ):

    def __init__( self, parent ):
        wx.Dialog.__init__ ( self, parent, id = wx.ID_ANY, title = wx.EmptyString, pos = wx.DefaultPosition, size = wx.DefaultSize, style = wx.DEFAULT_DIALOG_STYLE )

        self.SetSizeHints( wx.Size( 400,200 ), wx.DefaultSize )

        bSizer6 = wx.BoxSizer( wx.VERTICAL )

        self.m_staticText_save = wx.StaticText( self, wx.ID_ANY, u"Do you want to load tech levels from a savegame?\nDoing so will automatically apply them when creating a brigade.", wx.DefaultPosition, wx.DefaultSize, wx.ALIGN_CENTER_HORIZONTAL )
        self.m_staticText_save.Wrap( -1 )

        bSizer6.Add( self.m_staticText_save, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        gSizer4 = wx.GridSizer( 2, 2, 0, 0 )

        self.m_textCtrl_save_tag = wx.TextCtrl( self, wx.ID_ANY, u"Enter TAG", wx.DefaultPosition, wx.DefaultSize, wx.TE_CENTER )
        gSizer4.Add( self.m_textCtrl_save_tag, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_filePicker1 = wx.FilePickerCtrl( self, wx.ID_ANY, wx.EmptyString, u"Select the saave from which to load tech levels", u"*.*", wx.DefaultPosition, wx.DefaultSize, wx.FLP_DEFAULT_STYLE )
        gSizer4.Add( self.m_filePicker1, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_button_save_ok = wx.Button( self, wx.ID_ANY, u"Yes, I selected a save and TAG", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer4.Add( self.m_button_save_ok, 0, wx.ALIGN_CENTER|wx.ALL, 5 )

        self.m_button_save_no = wx.Button( self, wx.ID_ANY, u"No, let's skip this", wx.DefaultPosition, wx.DefaultSize, 0 )
        gSizer4.Add( self.m_button_save_no, 0, wx.ALIGN_CENTER|wx.ALL, 5 )


        bSizer6.Add( gSizer4, 1, wx.EXPAND, 5 )


        self.SetSizer( bSizer6 )
        self.Layout()
        bSizer6.Fit( self )

        self.Centre( wx.BOTH )

        # Connect Events
        self.Bind( wx.EVT_CHAR_HOOK, self.MyDialog1OnCharHook )
        self.Bind( wx.EVT_CLOSE, self.MyDialog1OnClose )
        self.m_button_save_ok.Bind( wx.EVT_BUTTON, self.m_button_save_okOnButtonClick )
        self.m_button_save_no.Bind( wx.EVT_BUTTON, self.m_button_save_noOnButtonClick )

    def __del__( self ):
        pass


    # Virtual event handlers, override them in your derived class
    def MyDialog1OnCharHook( self, event ):
        event.Skip()

    def MyDialog1OnClose( self, event ):
        event.Skip()

    def m_button_save_okOnButtonClick( self, event ):
        event.Skip()

    def m_button_save_noOnButtonClick( self, event ):
        event.Skip()


