-- Help pages for the in-game ImGui utility.
--
-- The text is data in BiceData.Help; this only hands one page's worth to the overlay.
-- The National Focus help page is not here - it is a table of the focus effects, which
-- BiceLibGui.NatFocus.Effects already provides for the National Focus page itself.

local Page = require('imgui_page')

BiceLibGui = BiceLibGui or {}
BiceLibGui.Help = {}

function BiceLibGui.Help.Section(name)
    return Page.Guard(function()
        return { available = true, entries = BiceData.Help.Section(name) }
    end)
end
