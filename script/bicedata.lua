-- Data provider for the BlackICE utilities.
--
-- Pure data: parsing mod files, localisation lookups and game state queries, with no
-- UI of any kind. The ImGui utility is built on this, and the wxWidgets utility can
-- be moved onto it later so the two stop duplicating logic.
--
-- Everything is parsed lazily and cached, so requiring this costs almost nothing:
-- a session that never opens the utility never reads a file.

BiceData = BiceData or {}

-- Shared plumbing first: the page providers are all built on these.
require('bicedata_country')
require('bicedata_aisettings')

require('bicedata_translations')
require('bicedata_traits')
require('bicedata_modifiers')
require('bicedata_techs')
require('bicedata_units')
require('bicedata_unitmodels')
require('bicedata_provincebuildings')
require('bicedata_countryinfo')
require('bicedata_puppets')
require('bicedata_stratresources')
require('bicedata_trades')
require('bicedata_natfocus')
require('bicedata_ministerbuildings')
require('bicedata_tradeai')
require('bicedata_prodsliders')
require('bicedata_lssliders')
require('bicedata_misc')
require('bicedata_options')
require('bicedata_help')
require('bicedata_generals')
require('bicedata_players')

return BiceData
