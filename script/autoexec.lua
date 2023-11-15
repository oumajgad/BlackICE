-----------------------------------------------------------
-- NOTES: This file is run on app start after exports are done inside
-- 		  the engine (once per context created)
-----------------------------------------------------------

-- set up path
package.path = package.path .. ";script\\?.lua"
package.path = package.path .. ";script\\country\\?.lua"
package.path = package.path .. ";common\\?.lua"

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

-- Commented to prevent security patch bugs
--Utils.resetLog()

-- Activate LUA performance benchmarking
benchmarkLUA = false