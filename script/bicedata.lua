-- Data provider for the BlackICE utilities.
--
-- Pure data: parsing mod files, localisation lookups and game state queries, with no
-- UI of any kind. The ImGui utility is built on this, and the wxWidgets utility can
-- be moved onto it later so the two stop duplicating logic.
--
-- Everything is parsed lazily and cached, so requiring this costs almost nothing:
-- a session that never opens the utility never reads a file.

BiceData = BiceData or {}

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
require('bicedata_generals')
require('bicedata_players')

return BiceData
