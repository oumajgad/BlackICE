-----------------------------------------------------------
-- NOTES: This file is run on app start after exports are done inside
-- 		  the engine (once per context created)
-----------------------------------------------------------

-- Keep this at line #7 !!!!
G_MOD_VERSION = "GitHub"


-- set up path
package.path = package.path .. ";script\\?.lua"
package.path = package.path .. ";script\\country\\?.lua"
package.path = package.path .. ";common\\?.lua"
package.cpath = package.cpath..";./tfh/mod/?.dll;"

-- BICE packages paths
package.cpath = package.cpath..";.\\tfh\\mod\\BlackICE ".. G_MOD_VERSION .. "\\script\\?.dll"
package.path = package.path .. ";.\\tfh\\mod\\BlackICE ".. G_MOD_VERSION .. "\\script\\utility\\main\\?.lua"
package.path = package.path .. ";.\\tfh\\mod\\BlackICE ".. G_MOD_VERSION .. "\\script\\utility\\help\\?.lua"
package.path = package.path .. ";.\\tfh\\mod\\BlackICE ".. G_MOD_VERSION .. "\\script\\utility\\options\\?.lua"
package.path = package.path .. ";.\\tfh\\mod\\BlackICE ".. G_MOD_VERSION .. "\\script\\utility\\gameinfos\\?.lua"
package.path = package.path .. ";.\\tfh\\mod\\BlackICE ".. G_MOD_VERSION .. "\\script\\utility\\stats\\?.lua"



--require('hoi') -- already imported by game, contains all exported classes
require('ai_globals')
require('file-io')
require('utils')
require('stats')
require('defines')
require('ai_country')
require('ai_foreign_minister')
require('ai_intelligence_minister')
require('ai_politics_minister')
require('ai_production_minister')
require('ai_support_functions')
require('ai_tech_minister')
require('ai_trade')
require('ai_license')
require('ai_variable')
require('csvParser')
require('pdxParser')

-- BICE custom LUA Module
BiceLib = require("BiceLib")
BiceLib.startConsole() -- Creates a console for debug information // Maybe comment out for releases?
BiceLib.setModuleBase()

-- Leaders
BiceLib.activateLeaderPromotionSkillLoss()
BiceLib.activateLeaderListShowMaxSkill()
BiceLib.activateLeaderListShowMaxSkillSelected()

-- Rank Specific traits
-- BiceLib.activateRankSpecificTraits()
-- BiceLib.addRankSpecificTrait("rankSpecificTrait_test_active", "rankSpecificTrait_test_inactive", 2, 4)

-- Units
-- BiceLib.setCorpsUnitLimit(6, false)
-- BiceLib.setArmyUnitLimit(7, false)
-- BiceLib.setArmyGroupUnitLimit(8, false)

-- BiceLib.addCommandLimitTrait("pskill_1", -1)
-- BiceLib.addCommandLimitTrait("pskill_4", 1)

-- Patches
BiceLib.activateOffmapICPatch()
BiceLib.activateMinisterTechDecayPatch()
BiceLib.activateWarExhaustionNeutralityResetPatch()


-- Make sure these exist, if something is require() but doesnt exist LUA dies and doesn't load the rest!
-- Defaults are at the bottom so it's easier to spot if something is wrong (some nations won't do anything since defaults wont be loaded)

-- load country specific AI modules.
-- Majors
require('GER')
require('ENG')
require('SOV')
require('USA')
require('ITA')
require('JAP')
require('FRA')

-- Minors (Alphabetized)
require('AST')
require('BBU')
require('BEL')
require('BHU')
require('BRA')
require('BUL')
require('CAN')
require('CGX')
require('CHC')
require('CHI')
require('CSX')
require('CXB')
require('CYN')
require('FIN')
require('GRE')
require('HOL')
require('HUN')
require('LUX')
require('MAN')
require('MEN')
require('MEX')
require('NJG')
require('NOR')
require('NZL')
require('PER')
require('POL')
require('POR')
require('PHI')
require('ROM')
require('SAF')
require('SCH')
require('SIA')
require('SIK')
require('SPA')
require('SPR')
require('SWE')
require('TIB')
require('TUR')
require('VIC')
require('YUG')

require('OMG')

-- Default Files
require('DEFAULT_LAND')
require('DEFAULT_MIXED')


-- Hoi 3 Utility
require('gui-utility')
require('gui-utility-help')
require('gui-utility-options')
require('gui-utility-gameinfo')
require('gui-utility-stats')
require('gui-auxilliary')
require('utility-extras')

-- Statistics
require('stats')

require('ai_omg_handlers')

-- Commented to prevent security patch bugs
--Utils.resetLog()

-- Activate LUA performance benchmarking
benchmarkLUA = false