package.cpath = package.cpath..";./tfh/mod/?.dll;"
require("wx")

if wx ~= nil then -- wx is not initialized until a few ticks have gone by. Do this to prevent log spam.

    -- Frame = Literally just the window. Program name, minimize, maximize, close. Thats it.
    frame = wx.wxFrame(wx.NULL, wx.wxID_ANY, "Hoi3 Utility",
                        wx.wxDefaultPosition, wx.wxDefaultSize)

    -- Panel = The canvas on which we build our gui.
    panel = wx.wxPanel(frame, wx.wxID_ANY)

    -- Sizers take care of the arrangement and size (duh) of our buttons and/or the whole window/panel.
    local mainSizer = wx.wxBoxSizer(wx.wxVERTICAL)
    local staticBox      = wx.wxStaticBox(panel, wx.wxID_ANY, "Cool Text")
    local staticBoxSizer = wx.wxStaticBoxSizer(staticBox, wx.wxVERTICAL)
    local flexGridSizer  = wx.wxFlexGridSizer( 0, 3, 0, 0 )
    flexGridSizer:AddGrowableCol(1, 0)

    staticBoxSizer:Add( flexGridSizer,  0, wx.wxGROW+wx.wxALIGN_CENTER+wx.wxALL, 5 )
    mainSizer:Add(      staticBoxSizer, 1, wx.wxGROW+wx.wxALIGN_CENTER+wx.wxALL, 5 )

    button_left_ID = 1
    button_right_ID = 2

    local buttonSizer = wx.wxBoxSizer( wx.wxHORIZONTAL )
    local ButtonLeft = wx.wxButton( panel, button_left_ID, "Almost Daily Resource Count OFF")
    local ButtonRight = wx.wxButton( panel, button_right_ID, "Almost Daily Resource Count ON")
    flexGridSizer:Add( ButtonLeft, 0, wx.wxALIGN_CENTER+wx.wxALL, 5 )
    buttonSizer:Add( ButtonRight, 0, wx.wxALIGN_CENTER+wx.wxALL, 5 )

    mainSizer:Add(   buttonSizer, 0, wx.wxALIGN_CENTER+wx.wxALL, 5 )


    panel:SetSizer( mainSizer )
    mainSizer:SetSizeHints( frame )


    panel:Connect(button_left_ID, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function(event)
            DateOverride = false
            Utils.LUA_DEBUGOUT(tostring(DateOverride))
        end)
    --
    panel:Connect(button_right_ID, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function(event)
            DateOverride = true
            Utils.LUA_DEBUGOUT(tostring(DateOverride))
        end)
    --


    frame:Centre()
    frame:Show(true)

end