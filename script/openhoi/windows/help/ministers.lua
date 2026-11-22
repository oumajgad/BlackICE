-- The Help tab's Ministers + Buildings page: which minister types grant which building, and the national focus
-- that doubles its building speed - a table of building, focus and ministers.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The text is the mod's
-- own, shared with the overlay on the original engine: the section "ministers" of BiceData.Help
-- (script/utility_data/bicedata_help.lua), drawn by the pages' shared kit.

local Kit = require('openhoi/pagekit')

return Kit.HelpPage("OPENHOI_WIN_HELP_MINISTERS_PAGE", 20, "ministers")
