-- Options tab.
--
-- Which lines to rewrite in the mod's interface files, and where, lives in
-- BiceData.Options and is shared with the ImGui utility. The font size functions stay
-- here: they resize wxWidgets controls, which the other utility has no equivalent of.

local function reportPopups(what, ok, reason)
    UI.m_textCtrl_OptionActions_Output:SetValue(
        what .. " - " .. (ok and "done" or ("failed: " .. tostring(reason))))
end

function SetDialogPopUpCenter()
    reportPopups("Center popups", BiceData.Options.SetMessagePopups("center"))
end

function SetDialogPopUpLeft()
    reportPopups("Leftside popups", BiceData.Options.SetMessagePopups("left"))
end

function SetEventPopUpCenter()
    reportPopups("Center events", BiceData.Options.SetEventPopups("center"))
end

function SetEventPopUpLeft()
    reportPopups("Leftside events", BiceData.Options.SetEventPopups("left"))
end

function ApplyFontRecursivelyToWxWindows(_wx_window, change)
    _wx_window:Freeze()
    local children = _wx_window:GetChildren()
    local count = children:GetCount() - 1
    for i = 0, count do
        local item = children:Item(i):GetData():DynamicCast("wxWindow")

        if _wx_window:GetChildren() ~= nil then
            ApplyFontRecursivelyToWxWindows(item, change)
        end

        local font = item:GetFont()
        font:SetPointSize(font:GetPointSize() + change)
        item:SetFont(font)
    end
    _wx_window:Layout()
    _wx_window:Thaw()
end

--- Every window the utility owns, so a font change reaches all of them.
local function applyFontToAllWindows(change)
    for _, frame in ipairs({ UI.MyFrame1, UI.MyFrame2, UI.MyFrame3, UI.MyFrame4, UI.MyFrame5 }) do
        if frame ~= nil then
            ApplyFontRecursivelyToWxWindows(frame, change)
        end
    end
    for _, window in ipairs(Parsing.Inspector.ActiveWindows) do
        ApplyFontRecursivelyToWxWindows(window, change)
    end
end

function DecreaseFontSize()
    applyFontToAllWindows(-1)
end

function IncreaseFontSize()
    applyFontToAllWindows(1)
end
