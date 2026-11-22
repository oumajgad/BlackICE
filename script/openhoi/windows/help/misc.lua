-- The Help tab's Misc page: the mod's own notes on strategic resources, airdroppable units, unit training and
-- units that events spawn.
--
-- A page of the mod's own windows for OpenHOI3's enhanced mode (docs/openhoi/README.md). The text is the mod's
-- own, shared with the overlay on the original engine: the section "misc" of BiceData.Help
-- (script/utility_data/bicedata_help.lua), drawn by the pages' shared kit.

local Kit = require('openhoi/pagekit')

return Kit.HelpPage("OPENHOI_WIN_HELP_MISC", 10, "misc")
