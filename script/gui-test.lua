------------------------------------------------------
-- https://wxlua.sourceforge.net/docs/wxluaref.html --
------------------------------------------------------

package.cpath = package.cpath..";./tfh/mod/?.dll;"
require("wx")

if wx ~= nil then -- wx is not initialized until a few ticks have gone by. Do this to prevent log spam.

    -- Frame = Literally just the window. Program name, minimize, maximize, close. Thats it.
    frame = wx.wxFrame(wx.NULL, wx.wxID_ANY, "Hoi3 Utility",
                        wx.wxDefaultPosition, wx.wxDefaultSize)

    notebook = wx.wxNotebook(frame, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize)

    -- Panel = The canvas on which we build our gui.
    panel = wx.wxPanel(notebook, wx.wxID_ANY)

    -- Sizers take care of the arrangement and size (duh) of our buttons and/or the whole window/panel.
    local mainSizer         = wx.wxBoxSizer(wx.wxVERTICAL)
    local staticBox         = wx.wxStaticBox(panel, wx.wxID_ANY, "Cool Text")
    local staticBoxSizer    = wx.wxStaticBoxSizer(staticBox, wx.wxVERTICAL)
    local flexGridSizer     = wx.wxFlexGridSizer( 2, 2, 3, 3 )


    button_left_ID = 1
    button_right_ID = 2
    button_3_ID = 3
    button_4_ID = 4
    button_5_ID = 5
    button_6_ID = 6

    local ButtonLeft = wx.wxButton( panel, button_left_ID, "Almost Daily Resource Count OFF")
    local ButtonRight = wx.wxButton( panel, button_right_ID, "Almost Daily Resource Count ON")
    local Button3 = wx.wxButton( panel, button_3_ID, "333")
    local Button4 = wx.wxButton( panel, button_4_ID, "444")
    local Button5 = wx.wxButton( panel, button_5_ID, "555")
    local Button6 = wx.wxButton( panel, button_6_ID, "666")
    flexGridSizer:Add( ButtonLeft, 0, wx.wxALIGN_CENTER+wx.wxALL, 0 )
    flexGridSizer:Add( ButtonRight, 0, wx.wxALIGN_CENTER+wx.wxALL, 50 )
    flexGridSizer:Add( Button3, 0, wx.wxALIGN_CENTER+wx.wxALL, 0 )
    flexGridSizer:Add( Button4, 0, wx.wxALIGN_CENTER+wx.wxALL, 0 )
    flexGridSizer:Add( Button5, 0, wx.wxALIGN_CENTER+wx.wxALL, 0 )
    flexGridSizer:Add( Button6, 0, wx.wxALIGN_CENTER+wx.wxALL, 0 )


    staticBoxSizer:Add( flexGridSizer,  0, wx.wxGROW+wx.wxALIGN_CENTER+wx.wxALL, 5 )
    mainSizer:Add(   staticBoxSizer, 0, wx.wxALIGN_CENTER+wx.wxALL, 10 )

    notebook:AddPage(panel, "Page 1")

    panel:SetSizer( mainSizer )
    mainSizer:SetSizeHints( frame )
    frame:SetSizeHints(notebook:GetBestSize():GetWidth(), notebook:GetBestSize():GetHeight())


    panel:Connect(button_left_ID, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function(event)
            if saveLoaded == true then
                DateOverride = false
                Utils.LUA_DEBUGOUT(tostring(DateOverride))
            else
                Utils.LUA_DEBUGOUT("NO SAVE LOADED")
            end
        end)
    --
    panel:Connect(button_right_ID, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function(event)
            if saveLoaded == true then
                DateOverride = true
                Utils.LUA_DEBUGOUT(tostring(DateOverride))
            else
                Utils.LUA_DEBUGOUT("NO SAVE LOADED")
            end
        end)
    --

    frame:Centre()
    frame:Show(true)

end