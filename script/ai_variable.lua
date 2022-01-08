
CountryListA = {
	["AFG"]=true;	["ALB"]=true;	["ARG"]=true;	["ARM"]=true;	["AST"]=true;	["AUS"]=true;	["AZB"]=true;	["BBU"]=true;
	["BEL"]=true;	["BHU"]=true;	["BIN"]=true;	["BLR"]=true;	["BOL"]=true;	["BRA"]=true;	["BUL"]=true;	["CAN"]=true;
	["CGX"]=true;	["CHC"]=true;	["CHI"]=true;	["CHL"]=true;	["COL"]=true;	["COS"]=true;	["CRO"]=true;	["CSX"]=true;
	["CUB"]=true;	["CXB"]=true;	["CYN"]=true;	["CYP"]=true;	["CZE"]=true;	["DDR"]=true;	["DEN"]=true;	["DFR"]=true;
	["DOM"]=true;	["ECU"]=true;	["EGY"]=true;	["ENG"]=true;	["EST"]=true;	["ETH"]=true;	["FIN"]=true;	["FRA"]=true;
	["GEO"]=true;	["GER"]=true;
}
CountryListB = {
	["GRE"]=true;	["GUA"]=true;	["GUY"]=true;	["HAI"]=true;	["HOL"]=true;	["HON"]=true;	["HUN"]=true;	["ICL"]=true;
	["IDC"]=true;	["IND"]=true;	["INO"]=true;	["IRE"]=true;	["IRQ"]=true;	["ISR"]=true;	["ITA"]=true;	["JAP"]=true;
	["JOR"]=true;	["KOR"]=true;	["KWT"]=true;	["LAT"]=true;	["LEB"]=true;	["LIB"]=true;	["LIT"]=true;	["LUX"]=true;
	["MAD"]=true;	["MAN"]=true;	["MEN"]=true;	["MEX"]=true;	["MON"]=true;	["MTA"]=true;	["MTN"]=true;	["NEP"]=true;
	["NIC"]=true;	["NJG"]=true;	["NOR"]=true;	["NZL"]=true;	["OMG"]=true;	["OMN"]=true;	["PAK"]=true;	["PAL"]=true;
	["PAN"]=true;	["PAP"]=true;
}
CountryListC = {
	["PAR"]=true;	["PER"]=true;	["PHI"]=true;	["POL"]=true;	["POR"]=true;	["PRK"]=true;	["PRU"]=true;	["REB"]=true;
	["RKK"]=true;	["RKM"]=true;	["RKO"]=true;	["RKU"]=true;	["ROM"]=true;	["RSI"]=true;	["RUR"]=true;	["SAF"]=true;
	["SAL"]=true;	["SAU"]=true;	["SCH"]=true;	["SER"]=true;	["SIA"]=true;	["SIK"]=true;	["SLO"]=true;	["SLV"]=true;
	["SOM"]=true;	["SOV"]=true;	["SPA"]=true;	["SPR"]=true;	["SUD"]=true;	["SUR"]=true;	["SWE"]=true;	["SYR"]=true;
	["TAN"]=true;	["TIB"]=true;	["TIM"]=true;	["TUR"]=true;	["UKR"]=true;	["URU"]=true;	["USA"]=true;	["VEN"]=true;
	["VIC"]=true;	["YEM"]=true;	["YUG"]=true;
}

-- LUA is stupid - This is needed so I can check if a country is in the list
function table.true_check(table, tag)
	for k,v in pairs(table) do
		if k == tag then
			return v
		end
	end
end

function table.getIndex(table, value)
    for i, v in ipairs(table) do
        if v == value then
            return i
        end
    end
    return nil
end


CountryIterCacheDict = {}
CountryIterCacheCheck = 0
-- Cache the Country Tags once at the start of a session so we dont have to use API calls a million times each time
function CountryIterCache(minister)
	if CountryIterCacheCheck == 0 then
		for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
			local countryTag = dip:GetTarget()
			local tag = tostring(countryTag)
			if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
				--Utils.LUA_DEBUGOUT("Tag - " .. tag)
				CountryIterCacheDict[tag] = countryTag
			end
		end
		CountryIterCacheCheck = 1
	end
end

--[[
	Count number of valid puppets JAP has for GreaterEastAsiaCoProsperitySphere
	Valid puppets are of specific tag and must hold a specific province (typically a valuable capital) to avoid exploits
	The count number is used for triggered modifiers and a few events
]]

function GreaterEastAsiaCoProsperitySphere(minister)

	local jap = CCountryDataBase.GetTag("JAP")

	local man = CCountryDataBase.GetTag("MAN")
	local men = CCountryDataBase.GetTag("MEN")
	local kor = CCountryDataBase.GetTag("KOR")
	local sia = CCountryDataBase.GetTag("SIA")
	local ind = CCountryDataBase.GetTag("IND")
	local ino = CCountryDataBase.GetTag("INO")
	local phi = CCountryDataBase.GetTag("PHI")
	local njg = CCountryDataBase.GetTag("NJG")
	local idc = CCountryDataBase.GetTag("IDC")
	local bbu = CCountryDataBase.GetTag("BBU")

	local manC = CCountryDataBase.GetTag("MAN"):GetCountry()
	local menC = CCountryDataBase.GetTag("MEN"):GetCountry()
	local korC = CCountryDataBase.GetTag("KOR"):GetCountry()
	local siaC = CCountryDataBase.GetTag("SIA"):GetCountry()
	local indC = CCountryDataBase.GetTag("IND"):GetCountry()
	local inoC = CCountryDataBase.GetTag("INO"):GetCountry()
	local phiC = CCountryDataBase.GetTag("PHI"):GetCountry()
	local njgC = CCountryDataBase.GetTag("NJG"):GetCountry()
	local idcC = CCountryDataBase.GetTag("IDC"):GetCountry()
	local bbuC = CCountryDataBase.GetTag("BBU"):GetCountry()

	local relMAN = minister:GetOwnerAI():GetRelation(jap, man)
	local relMEN = minister:GetOwnerAI():GetRelation(jap, men)
	local relKOR = minister:GetOwnerAI():GetRelation(jap, kor)
	local relSIA = minister:GetOwnerAI():GetRelation(jap, sia)
	local relIND = minister:GetOwnerAI():GetRelation(jap, ind)
	local relINO = minister:GetOwnerAI():GetRelation(jap, ino)
	local relPHI = minister:GetOwnerAI():GetRelation(jap, phi)
	local relNJG = minister:GetOwnerAI():GetRelation(jap, njg)
	local relIDC = minister:GetOwnerAI():GetRelation(jap, idc)
	local relBBU = minister:GetOwnerAI():GetRelation(jap, bbu)

	local puppetCount = 0

	if manC:IsPuppet() and relMAN:HasAnyAgreement() and man == CCurrentGameState.GetProvince(4685):GetController() then
		puppetCount = puppetCount + 1
	end
	if menC:IsPuppet() and relMEN:HasAnyAgreement() and men == CCurrentGameState.GetProvince(7326):GetController() then
		puppetCount = puppetCount + 1
	end
	if korC:IsPuppet() and relKOR:HasAnyAgreement() and kor == CCurrentGameState.GetProvince(5056):GetController() then
		puppetCount = puppetCount + 1
	end
	if siaC:IsPuppet() and relSIA:HasAnyAgreement() and sia == CCurrentGameState.GetProvince(6148):GetController() then
		puppetCount = puppetCount + 1
	end
	if indC:IsPuppet() and relIND:HasAnyAgreement() and ind == CCurrentGameState.GetProvince(5875):GetController() then
		puppetCount = puppetCount + 1
	end
	if inoC:IsPuppet() and relINO:HasAnyAgreement() and ino == CCurrentGameState.GetProvince(6507):GetController() then
		puppetCount = puppetCount + 1
	end
	if phiC:IsPuppet() and relPHI:HasAnyAgreement() and phi == CCurrentGameState.GetProvince(6142):GetController() then
		puppetCount = puppetCount + 1
	end
	if njgC:IsPuppet() and relNJG:HasAnyAgreement() and njg == CCurrentGameState.GetProvince(9478):GetController() then
		puppetCount = puppetCount + 1
	end
	if idcC:IsPuppet() and relIDC:HasAnyAgreement() and idc == CCurrentGameState.GetProvince(6236):GetController() then
		puppetCount = puppetCount + 1
	end
	if bbuC:IsPuppet() and relBBU:HasAnyAgreement() and bbu == CCurrentGameState.GetProvince(6070):GetController() then
		puppetCount = puppetCount + 1
	end

	local command = CSetVariableCommand(jap, CString("Greater_East_Asia_Co_Prosperity_Sphere_Size"), CFixedPoint(puppetCount))
	local ai = minister:GetOwnerAI()
	ai:Post(command)

end

--[[
	Count base IC available to country in core controlled provinces (takes into consideration 25% bonus from HIC)

	*** OLD *** IT IS BETTER TO USE THE BUILT IN FUNCTION USED BY THE baseICbyMinister FUNCTION

function BaseICCount(minister)

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 0 and dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 15 and dayOfMonth ~= 16 and dayOfMonth ~= 17 then
		return
	end

	-- Utils.LUA_DEBUGOUT("BaseIC")

	-- Setup buildings
	local industry = CBuildingDataBase.GetBuilding("industry" )
	local heavy_industry = CBuildingDataBase.GetBuilding("heavy_industry")

	-- Iterate each country (using Cached TAGs)
	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local tag = k

		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---"  and
		(
			((dayOfMonth == 0 or dayOfMonth == 15) and table.true_check(CountryListA, tag)) or
			((dayOfMonth == 1 or dayOfMonth == 16) and table.true_check(CountryListB, tag)) or
			((dayOfMonth == 2 or dayOfMonth == 17) and table.true_check(CountryListC, tag))
		)
		then

		-- Each province
			local totalIC = 10 -- Every nation has 10 free IC
			for provinceID in countryTag:GetCountry():GetOwnedProvinces() do
				-- Get province
				local province = CCurrentGameState.GetProvince(provinceID)

				-- Check under control
				if province:GetController() == countryTag then
					-- Add province IC with HIC bonus
					totalIC = totalIC + province:GetBuilding(industry):GetMax():Get() * (1 + province:GetBuilding(heavy_industry):GetMax():Get() * 0.25)
				end
			end

			-- Floor result
			totalIC = math.floor(totalIC)

			-- Utils.LUA_DEBUGOUT(tag)
			-- Utils.LUA_DEBUGOUT(totalIC)
			-- Set Variable
			local command = CSetVariableCommand(countryTag, CString("BaseIC"), CFixedPoint(totalIC))
			local ai = minister:GetOwnerAI()
			ai:Post(command)
		end
	end
end
]]

function baseICbyMinister(minister)

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 0 and dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 15 and dayOfMonth ~= 16 and dayOfMonth ~= 17 and DateOverride ~= true then
		return
	end

	-- Utils.LUA_DEBUGOUT("BaseIC_minister")
	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local tag = k

		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---"  and (
		(
			((dayOfMonth == 0 or dayOfMonth == 15) and table.true_check(CountryListA, tag)) or
			((dayOfMonth == 1 or dayOfMonth == 16) and table.true_check(CountryListB, tag)) or
			((dayOfMonth == 2 or dayOfMonth == 17) and table.true_check(CountryListC, tag))
		) or DateOverride == true )
		then
			local totalIC = countryTag:GetCountry():GetMaxIC()

			-- Utils.LUA_DEBUGOUT(tag)
			-- Utils.LUA_DEBUGOUT(totalIC)

			-- local command = CSetVariableCommand(countryTag, CString("BaseIC_minister"), CFixedPoint(totalIC))
			local command = CSetVariableCommand(countryTag, CString("BaseIC"), CFixedPoint(totalIC))
			local ai = minister:GetOwnerAI()
			ai:Post(command)

		end
	end
end

function table.shallow_copy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end

--[[
	Count buildings each country has in controlled core provinces
	Used for techs based on amount of specific buildings

	_current_count -> Current building count
	_cumulative_gain_count -> Cumulative gained building
	_cumulative_loss_count -> Cumulative lost building

	_cumulative_gain_count used for tech bonus
	_cumulative_loss_count used for tech malus (equal and opposite of tech bonus)
]]



local country_current_count = {}
local country_cumulative_gain_count = {}
local country_cumulative_loss_count = {}
local buildingsData = {}
local buildingsCountSetup = true

-- Get all the Variables from the Save, save them in local LUA arrays.
-- LUA variables/arrays get lost each restart, so this only needs to run once at the start of a session.
function BuildingsCountSetup(minister)
	-- Setup buildings
	if buildingsCountSetup then
		--buildingsData["air_base"] = CBuildingDataBase.GetBuilding("air_base")
		--buildingsData["naval_base"] = CBuildingDataBase.GetBuilding("naval_base")
		--buildingsData["coastal_fort"] = CBuildingDataBase.GetBuilding("coastal_fort")
		--buildingsData["beach_defence"] = CBuildingDataBase.GetBuilding("beach_defence")
		--buildingsData["land_fort"] = CBuildingDataBase.GetBuilding("land_fort")
		--buildingsData["fortress"] = CBuildingDataBase.GetBuilding("fortress")
		--buildingsData["anti_air"] = CBuildingDataBase.GetBuilding("anti_air")
		--buildingsData["radar_station"] = CBuildingDataBase.GetBuilding("radar_station")
		--buildingsData["industry"] = CBuildingDataBase.GetBuilding("industry")
		--buildingsData["heavy_industry"] = CBuildingDataBase.GetBuilding("heavy_industry")
		--buildingsData["steel_factory"] = CBuildingDataBase.GetBuilding("steel_factory")
		--buildingsData["coal_mining"] = CBuildingDataBase.GetBuilding("coal_mining")
		--buildingsData["sourcing_rares"] = CBuildingDataBase.GetBuilding("sourcing_rares")
		--buildingsData["oil_well"] = CBuildingDataBase.GetBuilding("oil_well")
		--buildingsData["oil_refinery"] = CBuildingDataBase.GetBuilding("oil_refinery")
		buildingsData["supplies_factory"] = CBuildingDataBase.GetBuilding("supplies_factory")
		buildingsData["military_college"] = CBuildingDataBase.GetBuilding("military_college")
		--buildingsData["urbanisation"] = CBuildingDataBase.GetBuilding("urbanisation")
		buildingsData["research_lab"] = CBuildingDataBase.GetBuilding("research_lab")
		buildingsData["hospital"] = CBuildingDataBase.GetBuilding("hospital")
		--buildingsData["police_station"] = CBuildingDataBase.GetBuilding("police_station")
		--buildingsData["infra"] = CBuildingDataBase.GetBuilding("infra")
		buildingsData["rail_terminous"] = CBuildingDataBase.GetBuilding("rail_terminous")
		--buildingsData["nuclear_reactor"] = CBuildingDataBase.GetBuilding("nuclear_reactor")
		--buildingsData["rocket_test"] = CBuildingDataBase.GetBuilding("rocket_test")
		buildingsData["small_ship_shipyard"] = CBuildingDataBase.GetBuilding("small_ship_shipyard")
		buildingsData["medium_ship_shipyard"] = CBuildingDataBase.GetBuilding("medium_ship_shipyard")
		buildingsData["capital_ship_shipyard"] = CBuildingDataBase.GetBuilding("capital_ship_shipyard")
		buildingsData["submarine_shipyard"] = CBuildingDataBase.GetBuilding("submarine_shipyard")
		buildingsData["smallarms_factory"] = CBuildingDataBase.GetBuilding("smallarms_factory")
		buildingsData["automotive_factory"] = CBuildingDataBase.GetBuilding("automotive_factory")
		buildingsData["artillery_factory"] = CBuildingDataBase.GetBuilding("artillery_factory")
		buildingsData["tank_factory"] = CBuildingDataBase.GetBuilding("tank_factory")
		buildingsData["light_aircraft_factory"] = CBuildingDataBase.GetBuilding("light_aircraft_factory")
		buildingsData["medium_aircraft_factory"] = CBuildingDataBase.GetBuilding("medium_aircraft_factory")
		buildingsData["heavy_aircraft_factory"] = CBuildingDataBase.GetBuilding("heavy_aircraft_factory")
		--buildingsData["underground"] = CBuildingDataBase.GetBuilding("underground")
		--buildingsData["desperate_defence"] = CBuildingDataBase.GetBuilding("desperate_defence")
		--buildingsData["weather_fort"] = CBuildingDataBase.GetBuilding("weather_fort")
		--buildingsData["fake_air_base"] = CBuildingDataBase.GetBuilding("fake_air_base")
		buildingsData["chromite_building"] = CBuildingDataBase.GetBuilding("chromite_building")
		buildingsData["aluminium_building"] = CBuildingDataBase.GetBuilding("aluminium_building")
		buildingsData["rubber_building"] = CBuildingDataBase.GetBuilding("rubber_building")
		buildingsData["synthetic_rubber_building"] = CBuildingDataBase.GetBuilding("synthetic_rubber_building")
		buildingsData["tungsten_building"] = CBuildingDataBase.GetBuilding("tungsten_building")
		buildingsData["uranium_building"] = CBuildingDataBase.GetBuilding("uranium_building")
		buildingsData["gold_building"] = CBuildingDataBase.GetBuilding("gold_building")
		buildingsData["nickel_building"] = CBuildingDataBase.GetBuilding("nickel_building")
		buildingsData["copper_building"] = CBuildingDataBase.GetBuilding("copper_building")
		buildingsData["zinc_building"] = CBuildingDataBase.GetBuilding("zinc_building")
		buildingsData["manganese_building"] = CBuildingDataBase.GetBuilding("manganese_building")
		buildingsData["molybdenum_building"] = CBuildingDataBase.GetBuilding("molybdenum_building")


		-- Iterate each country (using Cached TAGs)
		for k, v in pairs(CountryIterCacheDict) do
			local countryTag = v
			local tag = k

			--Utils.LUA_DEBUGOUT("Building count Country " .. tag)
			if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then


			local countryVars = countryTag:GetCountry():GetVariables()
			--Current Count
			country_current_count[tag] = {} -- Make sure LUA understands we are building a Multidimensional Array
			country_current_count[tag]["supplies_factory"] = countryVars:GetVariable(CString("supplies_factory_count")):Get()
			country_current_count[tag]["military_college"] = countryVars:GetVariable(CString("military_college_count")):Get()
			country_current_count[tag]["research_lab"] = countryVars:GetVariable(CString("research_lab_count")):Get()
			country_current_count[tag]["hospital"] = countryVars:GetVariable(CString("hospital_count")):Get()
			country_current_count[tag]["rail_terminous"] = countryVars:GetVariable(CString("rail_terminous_count")):Get()
			country_current_count[tag]["small_ship_shipyard"] = countryVars:GetVariable(CString("small_ship_shipyard_count")):Get()
			country_current_count[tag]["medium_ship_shipyard"] = countryVars:GetVariable(CString("medium_ship_shipyard_count")):Get()
			country_current_count[tag]["capital_ship_shipyard"] = countryVars:GetVariable(CString("capital_ship_shipyard_count")):Get()
			country_current_count[tag]["submarine_shipyard"] = countryVars:GetVariable(CString("submarine_shipyard_count")):Get()
			country_current_count[tag]["smallarms_factory"] = countryVars:GetVariable(CString("smallarms_factory_count")):Get()
			country_current_count[tag]["automotive_factory"] = countryVars:GetVariable(CString("automotive_factory_count")):Get()
			country_current_count[tag]["artillery_factory"] = countryVars:GetVariable(CString("artillery_factory_count")):Get()
			country_current_count[tag]["tank_factory"] = countryVars:GetVariable(CString("tank_factory_count")):Get()
			country_current_count[tag]["light_aircraft_factory"] = countryVars:GetVariable(CString("light_aircraft_factory_count")):Get()
			country_current_count[tag]["medium_aircraft_factory"] = countryVars:GetVariable(CString("medium_aircraft_factory_count")):Get()
			country_current_count[tag]["heavy_aircraft_factory"] = countryVars:GetVariable(CString("heavy_aircraft_factory_count")):Get()

			--Cumulative Gain
			country_cumulative_gain_count[tag] = {} -- Make sure LUA understands we are building a Multidimensional Array
			country_cumulative_gain_count[tag]["supplies_factory"] = countryVars:GetVariable(CString("supplies_factory_count_TECH")):Get()
			country_cumulative_gain_count[tag]["military_college"] = countryVars:GetVariable(CString("military_college_count_TECH")):Get()
			country_cumulative_gain_count[tag]["research_lab"] = countryVars:GetVariable(CString("research_lab_count_TECH")):Get()
			country_cumulative_gain_count[tag]["hospital"] = countryVars:GetVariable(CString("hospital_count_TECH")):Get()
			country_cumulative_gain_count[tag]["rail_terminous"] = countryVars:GetVariable(CString("rail_terminous_count_TECH")):Get()
			country_cumulative_gain_count[tag]["small_ship_shipyard"] = countryVars:GetVariable(CString("small_ship_shipyard_count_TECH")):Get()
			country_cumulative_gain_count[tag]["medium_ship_shipyard"] = countryVars:GetVariable(CString("medium_ship_shipyard_count_TECH")):Get()
			country_cumulative_gain_count[tag]["capital_ship_shipyard"] = countryVars:GetVariable(CString("capital_ship_shipyard_count_TECH")):Get()
			country_cumulative_gain_count[tag]["submarine_shipyard"] = countryVars:GetVariable(CString("submarine_shipyard_count_TECH")):Get()
			country_cumulative_gain_count[tag]["smallarms_factory"] = countryVars:GetVariable(CString("smallarms_factory_count_TECH")):Get()
			country_cumulative_gain_count[tag]["automotive_factory"] = countryVars:GetVariable(CString("automotive_factory_count_TECH")):Get()
			country_cumulative_gain_count[tag]["artillery_factory"] = countryVars:GetVariable(CString("artillery_factory_count_TECH")):Get()
			country_cumulative_gain_count[tag]["tank_factory"] = countryVars:GetVariable(CString("tank_factory_count_TECH")):Get()
			country_cumulative_gain_count[tag]["light_aircraft_factory"] = countryVars:GetVariable(CString("light_aircraft_factory_count_TECH")):Get()
			country_cumulative_gain_count[tag]["medium_aircraft_factory"] = countryVars:GetVariable(CString("medium_aircraft_factory_count_TECH")):Get()
			country_cumulative_gain_count[tag]["heavy_aircraft_factory"] = countryVars:GetVariable(CString("heavy_aircraft_factory_count_TECH")):Get()

			--Cumulative Loss
			country_cumulative_loss_count[tag] = {} -- Make sure LUA understands we are building a Multidimensional Array
			country_cumulative_loss_count[tag]["supplies_factory"] = countryVars:GetVariable(CString("supplies_factory_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["military_college"] = countryVars:GetVariable(CString("military_college_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["research_lab"] = countryVars:GetVariable(CString("research_lab_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["hospital"] = countryVars:GetVariable(CString("hospital_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["rail_terminous"] = countryVars:GetVariable(CString("rail_terminous_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["small_ship_shipyard"] = countryVars:GetVariable(CString("small_ship_shipyard_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["medium_ship_shipyard"] = countryVars:GetVariable(CString("medium_ship_shipyard_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["capital_ship_shipyard"] = countryVars:GetVariable(CString("capital_ship_shipyard_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["submarine_shipyard"] = countryVars:GetVariable(CString("submarine_shipyard_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["smallarms_factory"] = countryVars:GetVariable(CString("smallarms_factory_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["automotive_factory"] = countryVars:GetVariable(CString("automotive_factory_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["artillery_factory"] = countryVars:GetVariable(CString("artillery_factory_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["tank_factory"] = countryVars:GetVariable(CString("tank_factory_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["light_aircraft_factory"] = countryVars:GetVariable(CString("light_aircraft_factory_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["medium_aircraft_factory"] = countryVars:GetVariable(CString("medium_aircraft_factory_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["heavy_aircraft_factory"] = countryVars:GetVariable(CString("heavy_aircraft_factory_count_TECH_MALUS")):Get()

			-- Resource Buildings
			--Current Count
			country_current_count[tag]["chromite_building"] = countryVars:GetVariable(CString("chromite_building_count")):Get()
			country_current_count[tag]["aluminium_building"] = countryVars:GetVariable(CString("aluminium_building_count")):Get()
			country_current_count[tag]["rubber_building"] = countryVars:GetVariable(CString("rubber_building_count")):Get()
			country_current_count[tag]["synthetic_rubber_building"] = countryVars:GetVariable(CString("synthetic_rubber_building_count")):Get()
			country_current_count[tag]["tungsten_building"] = countryVars:GetVariable(CString("tungsten_building_count")):Get()
			country_current_count[tag]["uranium_building"] = countryVars:GetVariable(CString("uranium_building_count")):Get()
			country_current_count[tag]["gold_building"] = countryVars:GetVariable(CString("gold_building_count")):Get()
			country_current_count[tag]["nickel_building"] = countryVars:GetVariable(CString("nickel_building_count")):Get()
			country_current_count[tag]["copper_building"] = countryVars:GetVariable(CString("copper_building_count")):Get()
			country_current_count[tag]["zinc_building"] = countryVars:GetVariable(CString("zinc_building_count")):Get()
			country_current_count[tag]["manganese_building"] = countryVars:GetVariable(CString("manganese_building_count")):Get()
			country_current_count[tag]["molybdenum_building"] = countryVars:GetVariable(CString("molybdenum_building_count")):Get()

			--Cumulative Gain
			country_cumulative_gain_count[tag]["chromite_building"] = countryVars:GetVariable(CString("chromite_building_count_TECH")):Get()
			country_cumulative_gain_count[tag]["aluminium_building"] = countryVars:GetVariable(CString("aluminium_building_count_TECH")):Get()
			country_cumulative_gain_count[tag]["rubber_building"] = countryVars:GetVariable(CString("rubber_building_count_TECH")):Get()
			country_cumulative_gain_count[tag]["synthetic_rubber_building"] = countryVars:GetVariable(CString("synthetic_rubber_building_count_TECH")):Get()
			country_cumulative_gain_count[tag]["tungsten_building"] = countryVars:GetVariable(CString("tungsten_building_count_TECH")):Get()
			country_cumulative_gain_count[tag]["uranium_building"] = countryVars:GetVariable(CString("uranium_building_count_TECH")):Get()
			country_cumulative_gain_count[tag]["gold_building"] = countryVars:GetVariable(CString("gold_building_count_TECH")):Get()
			country_cumulative_gain_count[tag]["nickel_building"] = countryVars:GetVariable(CString("nickel_building_count_TECH")):Get()
			country_cumulative_gain_count[tag]["copper_building"] = countryVars:GetVariable(CString("copper_building_count_TECH")):Get()
			country_cumulative_gain_count[tag]["zinc_building"] = countryVars:GetVariable(CString("zinc_building_count_TECH")):Get()
			country_cumulative_gain_count[tag]["manganese_building"] = countryVars:GetVariable(CString("manganese_building_count_TECH")):Get()
			country_cumulative_gain_count[tag]["molybdenum_building"] = countryVars:GetVariable(CString("molybdenum_building_count_TECH")):Get()

			--Cumulative Loss
			country_cumulative_loss_count[tag]["chromite_building"] = countryVars:GetVariable(CString("chromite_building_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["aluminium_building"] = countryVars:GetVariable(CString("aluminium_building_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["rubber_building"] = countryVars:GetVariable(CString("rubber_building_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["synthetic_rubber_building"] = countryVars:GetVariable(CString("synthetic_rubber_building_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["tungsten_building"] = countryVars:GetVariable(CString("tungsten_building_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["uranium_building"] = countryVars:GetVariable(CString("uranium_building_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["gold_building"] = countryVars:GetVariable(CString("gold_building_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["nickel_building"] = countryVars:GetVariable(CString("nickel_building_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["copper_building"] = countryVars:GetVariable(CString("copper_building_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["zinc_building"] = countryVars:GetVariable(CString("zinc_building_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["manganese_building"] = countryVars:GetVariable(CString("manganese_building_count_TECH_MALUS")):Get()
			country_cumulative_loss_count[tag]["molybdenum_building"] = countryVars:GetVariable(CString("molybdenum_building_count_TECH_MALUS")):Get()
			end
		end
		buildingsCountSetup = false
	end
end

BuildingsCountCount = 0
function BuildingsCount(minister)
	BuildingsCountCount = BuildingsCountCount + 1

	--Utils.LUA_DEBUGOUT("Enter building count")

	-- No need to make it spread out over many days. It takes less than 0.01 seconds!
	-- local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	-- if dayOfMonth ~= 0 and dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 15 and dayOfMonth ~= 16 and dayOfMonth ~= 17 and DateOverride ~= true then
	-- 	return
	-- end

	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local tag = k
		local country = countryTag:GetCountry()

		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
			-- Reset this one for each Country else things get funny, since we reuse the same array in the ResourceCount()
			local currentBuildings = {}
			currentBuildings["supplies_factory"] = 0
			currentBuildings["military_college"] = 0
			currentBuildings["research_lab"] = 0
			currentBuildings["hospital"] = 0
			--currentBuildings["police_station"] = 0
			--currentBuildings["infra"] = 0
			currentBuildings["rail_terminous"] = 0
			--currentBuildings["nuclear_reactor"] = 0
			--currentBuildings["rocket_test"] = 0
			currentBuildings["small_ship_shipyard"] = 0
			currentBuildings["medium_ship_shipyard"] = 0
			currentBuildings["capital_ship_shipyard"] = 0
			currentBuildings["submarine_shipyard"] = 0
			currentBuildings["smallarms_factory"] = 0
			currentBuildings["automotive_factory"] = 0
			currentBuildings["artillery_factory"] = 0
			currentBuildings["tank_factory"] = 0
			currentBuildings["light_aircraft_factory"] = 0
			currentBuildings["medium_aircraft_factory"] = 0
			currentBuildings["heavy_aircraft_factory"] = 0
			--currentBuildings["underground"] = 0
			--currentBuildings["desperate_defence"] = 0
			--currentBuildings["weather_fort"] = 0
			--currentBuildings["fake_air_base"] = 0

			-- Previous count - Previous as in the count before counting and updating the values this tick
			--Utils.LUA_DEBUGOUT("Getting previous count")
			local previousBuildings = {}
			for buildingtype, buildingcount in pairs(currentBuildings) do
				previousBuildings[buildingtype] = country_current_count[tag][buildingtype]
				--Utils.LUA_DEBUGOUT("Previous count " .. buildingtype .. ":" .. previousBuildings[buildingtype])
			end

			-- Cumulative gain count
			local cumulativeGainBuildings = {}
			for buildingtype, buildingcount in pairs(currentBuildings) do
				cumulativeGainBuildings[buildingtype] = country_cumulative_gain_count[tag][buildingtype]
				--Utils.LUA_DEBUGOUT("Cumulative gain " .. buildingtype .. ":" .. cumulativeGainBuildings[buildingtype])
			end

			-- Cumulative lost count
			local cumulativeLoseBuildings = {}
			for buildingtype, buildingcount in pairs(currentBuildings) do
				cumulativeLoseBuildings[buildingtype] = country_cumulative_loss_count[tag][buildingtype]
				--Utils.LUA_DEBUGOUT("Cumulative lost " .. buildingtype .. ":" .. cumulativeLoseBuildings[buildingtype])
			end

			--Utils.LUA_DEBUGOUT("Pre Set")

			for buildingtype, buildingcount in pairs(currentBuildings) do
				local count = country:GetTotalCoreBuildingLevels(buildingsData[buildingtype]:GetIndex()):Get()
				if count > 20 then
					count = 20 + ((count - 20) * 0.5)
				end
				currentBuildings[buildingtype] = count
			end

			-- Each building
			for buildingtype, buildingcount in pairs(currentBuildings) do

				-- Variation
				local variation = buildingcount - previousBuildings[buildingtype]
				--Utils.LUA_DEBUGOUT("Variation " .. buildingtype .. ":" .. variation)
				if variation > 0 then
					cumulativeGainBuildings[buildingtype] = cumulativeGainBuildings[buildingtype] + variation
				elseif variation < 0 then
					cumulativeLoseBuildings[buildingtype] = cumulativeLoseBuildings[buildingtype] - variation
				end

				-- ONLY set things IF we have a Variation
				if variation ~= 0 then
					-- Update local variables -- set to Variables later
					country_current_count[tag][buildingtype] = buildingcount
					country_cumulative_gain_count[tag][buildingtype] = cumulativeGainBuildings[buildingtype]
					country_cumulative_loss_count[tag][buildingtype] = cumulativeLoseBuildings[buildingtype]

					--Utils.LUA_DEBUGOUT("buildingcount " .. buildingtype .. " : " .. buildingcount)
					-- Set Variables
					-- Only after a few times because the values are wrong in the beginning
					if BuildingsCountCount > 3 then
						local ai = minister:GetOwnerAI()
						--Count for Triggered Effect
						local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count"), CFixedPoint(buildingcount))
						ai:Post(command)
						--Count for bonus tech
						local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count_TECH"), CFixedPoint(cumulativeGainBuildings[buildingtype]))
						ai:Post(command)
						--Count for malus tech
						local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count_TECH_MALUS"), CFixedPoint(cumulativeLoseBuildings[buildingtype]))
						ai:Post(command)
					end
				end
			end
		end
	end
end

--Copy of BuildingsCount, only for the resource buildings since they get counted by controlled provinces not core
function ResourceCount(minister)


	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 0 and dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 15 and dayOfMonth ~= 16 and dayOfMonth ~= 17 and DateOverride ~= true then
		return
	end

	-- Setup buildings



	-- Iterate each country (using the Cached TAGs)
	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local tag = k

		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---"  and (
		(
			((dayOfMonth == 0 or dayOfMonth == 15) and table.true_check(CountryListA, tag)) or
			((dayOfMonth == 1 or dayOfMonth == 16) and table.true_check(CountryListB, tag)) or
			((dayOfMonth == 2 or dayOfMonth == 17) and table.true_check(CountryListC, tag))
		) or DateOverride == true )
		then
			-- Utils.LUA_DEBUGOUT("ResourceCount Country " .. tag)
			-- Reset this one for each Country else things get funny
			local currentResourceBuildings = {}
			currentResourceBuildings["chromite_building"] = 0
			currentResourceBuildings["aluminium_building"] = 0
			currentResourceBuildings["rubber_building"] = 0
			currentResourceBuildings["synthetic_rubber_building"] = 0
			currentResourceBuildings["tungsten_building"] = 0
			currentResourceBuildings["uranium_building"] = 0
			currentResourceBuildings["gold_building"] = 0
			currentResourceBuildings["nickel_building"] = 0
			currentResourceBuildings["copper_building"] = 0
			currentResourceBuildings["zinc_building"] = 0
			currentResourceBuildings["manganese_building"] = 0
			currentResourceBuildings["molybdenum_building"] = 0

			-- Previous count
			--Utils.LUA_DEBUGOUT("Getting previous count")
			local previousBuildings = {}
			for buildingtype, buildingcount in pairs(currentResourceBuildings) do
				previousBuildings[buildingtype] = country_current_count[tag][buildingtype]
				--Utils.LUA_DEBUGOUT("Previous count " .. buildingtype .. ":" .. previousBuildings[buildingtype])
			end

			-- Cumulative gain count
			local cumulativeGainBuildings = {}
			for buildingtype, buildingcount in pairs(currentResourceBuildings) do
				cumulativeGainBuildings[buildingtype] = country_cumulative_gain_count[tag][buildingtype]
				--Utils.LUA_DEBUGOUT("Cumulative gain " .. buildingtype .. ":" .. cumulativeGainBuildings[buildingtype])
			end

			-- Cumulative lost count
			local cumulativeLoseBuildings = {}
			for buildingtype, buildingcount in pairs(currentResourceBuildings) do
				cumulativeLoseBuildings[buildingtype] = country_cumulative_loss_count[tag][buildingtype]
				--Utils.LUA_DEBUGOUT("Cumulative lost " .. buildingtype .. ":" .. cumulativeLoseBuildings[buildingtype])
			end

			-- Count current buildings
			for provinceID in countryTag:GetCountry():GetControlledProvinces() do

				-- Get province data
				local provinceStruct = CCurrentGameState.GetProvince(provinceID)

				-- Check under control
				if provinceStruct:GetController() == countryTag then

					-- Each building
					for buildingtype, buildingcount in pairs(currentResourceBuildings) do
						-- Increment building count
						currentResourceBuildings[buildingtype] = currentResourceBuildings[buildingtype] + provinceStruct:GetBuilding(buildingsData[buildingtype]):GetCurrent():Get()
					end

				end

			end

			-- Each building
			for buildingtype, buildingcount in pairs(currentResourceBuildings) do

				-- Variation
				local variation = buildingcount - previousBuildings[buildingtype]
				--Utils.LUA_DEBUGOUT("Variation " .. buildingtype .. ":" .. variation)
				if variation > 0 then
					cumulativeGainBuildings[buildingtype] = cumulativeGainBuildings[buildingtype] + variation
				elseif variation < 0 then
					cumulativeLoseBuildings[buildingtype] = cumulativeLoseBuildings[buildingtype] - variation
				end

				-- Check for Variation and only set Variables if there are.
				if variation ~= 0 or buildingtype == "rubber_building" then	-- rubber_building needs to get set if synthetic_rubber_building changes, so just set it always
					-- Update local variables

					country_current_count[tag][buildingtype] = buildingcount
					country_cumulative_gain_count[tag][buildingtype] = cumulativeGainBuildings[buildingtype]
					country_cumulative_loss_count[tag][buildingtype] = cumulativeLoseBuildings[buildingtype]

					if buildingtype == "rubber_building" then
						buildingcount = buildingcount + currentResourceBuildings["synthetic_rubber_building"]
					end
					-- Set Variables
					local ai = minister:GetOwnerAI()
					--Count for Triggered Effect
					local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count"), CFixedPoint(buildingcount))
					ai:Post(command)
					--Count for bonus tech
					local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count_TECH"), CFixedPoint(cumulativeGainBuildings[buildingtype]))
					ai:Post(command)
					--Count for malus tech
					local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count_TECH_MALUS"), CFixedPoint(cumulativeLoseBuildings[buildingtype]))
					ai:Post(command)
				end
			end
		end
	end

end

function StratResourceBalance(minister)

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 3 and dayOfMonth ~= 16 and dayOfMonth ~= 17 and dayOfMonth ~= 18 and DateOverride ~= true then
		return
	end

	local resourceBuildings = {
		"chromite";
		"aluminium";
		"rubber";
		"tungsten";
		"uranium";
		"gold";
		"nickel";
		"copper";
		"zinc";
		"manganese";
		"molybdenum"
	}


	local ai = minister:GetOwnerAI()
	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local tag = k

		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" and (
		(
			((dayOfMonth == 1 or dayOfMonth == 16) and table.true_check(CountryListA, tag)) or
			((dayOfMonth == 2 or dayOfMonth == 17) and table.true_check(CountryListB, tag)) or
			((dayOfMonth == 3 or dayOfMonth == 18) and table.true_check(CountryListC, tag))
		) or DateOverride == true)
		then
			-- Utils.LUA_DEBUGOUT("StratResourceBalance Country " .. tag)
			local BaseIC = countryTag:GetCountry():GetVariables():GetVariable(CString("BaseIC")):Get()
			-- Each resource building
			for k,building in pairs(resourceBuildings) do

				-- Calculate balance
				-- Each 200 IC needs 1 resource, no need below 100 IC
				-- TODO later can have different requirements per resource
				local count = countryTag:GetCountry():GetVariables():GetVariable(CString(building .. "_building_count")):Get()
				-- Puppets don't sell their resources. Their resources get added to the Masters and he can sell them.
				local puppets = countryTag:GetCountry():GetVassals()
				local puppet_count = 0
				if puppets then
					for puppet in puppets do
						--Utils.LUA_DEBUGOUT("Building Puppet Tag  " .. tostring(puppet:GetCountry():GetCountryTag()))
						puppet_count = puppet_count + puppet:GetCountry():GetVariables():GetVariable(CString(building .. "_building_balance")):Get() - 1000
						--Utils.LUA_DEBUGOUT("Building count puppets " .. puppet_count)
					end
					if puppet_count < 0 then
						puppet_count = 0
					end
				end
				--Utils.LUA_DEBUGOUT("Building Tag  " .. tostring(countryTag))
				--Utils.LUA_DEBUGOUT("Building count  " .. count)

				count = (count + puppet_count) * 200
				--Utils.LUA_DEBUGOUT("Building count  " .. count)

				local balance = 0
				if BaseIC <= 100 then
					balance = math.ceil((count - BaseIC ) / 200)
				end
				if BaseIC > 100 then
					balance = math.floor((count - BaseIC ) / 200)
				end
				--Utils.LUA_DEBUGOUT("Building balance  " .. balance)
				balance = balance + 1000
				-- 1000 as the 0 (cant set variables with value 0...)


				-- Set variable
				local command = CSetVariableCommand(countryTag, CString(building .. "_building_balance"), CFixedPoint(balance))
				ai:Post(command)
			end

		end

	end

end

function RealStratResourceBalance(minister)

	local resources = {
		"chromite";
		"aluminium";
		"rubber";
		"tungsten";
		"uranium";
		"gold";
		"nickel";
		"copper";
		"zinc";
		"manganese";
		"molybdenum"
	}

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 1 and dayOfMonth ~= 6 and dayOfMonth ~= 11 and dayOfMonth ~= 16 and dayOfMonth ~= 21 and dayOfMonth ~= 26 and DateOverride ~= true then
		return
	end

	local ai = minister:GetOwnerAI()
	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local tag = k

		--Utils.LUA_DEBUGOUT("Building count Country " .. tag)
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---"  then

			-- Utils.LUA_DEBUGOUT("RealStratResourceBalance Country " .. tag)
			local overlord = countryTag:GetCountry():GetOverlord()
			local overlord_country = overlord:GetCountry()
			local overlord_tag = overlord_country:GetCountryTag()

			for k,resource in pairs(resources) do

				--local BuildingCount = countryTag:GetCountry():GetVariables():GetVariable(CString(resource .. "_building_count")):Get()
				local BaseValue = countryTag:GetCountry():GetVariables():GetVariable(CString(resource .. "_building_balance")):Get()
				local SellValue = countryTag:GetCountry():GetVariables():GetVariable(CString(resource .. "_trade_sell")):Get()
				local BuyValue = countryTag:GetCountry():GetVariables():GetVariable(CString(resource .. "_trade_buy")):Get()

				local ActualBalance = BaseValue + BuyValue - SellValue	-- Value used for Industry effects

				local MaxSells = BaseValue - SellValue - 1000	-- Only allow domestic resources to be sold, after substracting industry needs(BaseValue has that baked in).

				if SellValue >= 18 then
					MaxSells = 0
				end

				-- Logic to determine how if the master has sold any of the puppets resources
				if tostring(overlord_tag) ~= "---" then
					local overlord_balance = overlord_country:GetVariables():GetVariable(CString(resource .. "_building_balance")):Get()
					if overlord_balance < 1000 then
						overlord_balance = 1000
					end
					local overlord_sell = overlord_country:GetVariables():GetVariable(CString(resource .. "_trade_sell")):Get()

					local overlord_base_actual = overlord_balance - BaseValue 		-- Get the actual resource balance of the master without the puppet
					local overlord_actual = overlord_base_actual - overlord_sell	-- Now substract how much the master sold
					local sold_from_puppet = overlord_actual						-- If the master sold resources from the puppet this will be negative
					if sold_from_puppet > 0 then									-- If the master still has some leftover sold_from_puppet will be positive
						sold_from_puppet = 0										-- this would cause the puppet to gain the bonuses of the masters resources
					end																-- we dont want that

					ActualBalance = ActualBalance + sold_from_puppet
					-- Set MaxSells to 0 so puppets dont sell stuff
					MaxSells = 0

					-- Utils.LUA_DEBUGOUT("LUA_DEBUGOUT Overlord " .. tostring(overlord_tag) )
					-- Utils.LUA_DEBUGOUT("LUA_DEBUG_countryTag '" .. tostring(countryTag) .. " -- " .. tostring(resource) .. "' \n")
					-- Utils.LUA_DEBUGOUT("LUA_DEBUG_BaseValue '" .. tostring(BaseValue) .. "' \n")
					-- Utils.LUA_DEBUGOUT("LUA_DEBUG_SellValue '" .. tostring(SellValue) .. "' \n")
					-- Utils.LUA_DEBUGOUT("LUA_DEBUG_BuyValue '" .. tostring(BuyValue) .. "' \n")
					-- Utils.LUA_DEBUGOUT("LUA_DEBUG_ActualBalance '" .. tostring(ActualBalance) .. "' \n")
					-- Utils.LUA_DEBUGOUT("LUA_DEBUG_overlord_balance '" .. tostring(overlord_balance) .. "' \n")
					-- Utils.LUA_DEBUGOUT("LUA_DEBUG_overlord_sell '" .. tostring(overlord_sell) .. "' \n")
					-- Utils.LUA_DEBUGOUT("LUA_DEBUG_overlord_base_actual '" .. tostring(overlord_base_actual) .. "' \n")
					-- Utils.LUA_DEBUGOUT("LUA_DEBUG_overlord_actual '" .. tostring(overlord_actual) .. "' \n")
					-- Utils.LUA_DEBUGOUT("LUA_DEBUG_sold_from_puppet '" .. tostring(sold_from_puppet) .. "' \n")
				end

				-- Utils.LUA_DEBUGOUT("LUA_DEBUG_countryTag '" .. tostring(countryTag) .. " -- " .. tostring(resource) .. "' \n")
				-- Utils.LUA_DEBUGOUT("LUA_DEBUG_BaseValue '" .. tostring(BaseValue) .. "' \n")
				-- Utils.LUA_DEBUGOUT("LUA_DEBUG_SellValue '" .. tostring(SellValue) .. "' \n")
				-- Utils.LUA_DEBUGOUT("LUA_DEBUG_BuyValue '" .. tostring(BuyValue) .. "' \n")
				-- Utils.LUA_DEBUGOUT("LUA_DEBUG_ActualBalance '" .. tostring(ActualBalance) .. "' \n")

				-- Check if sales have been disabled by the player
				if PlayerCountries ~= nil then
					-- only check for playercountries since AI doesnt get the effects
					for index,player in pairs(PlayerCountries) do
						if player == tag then
							local isDeactivated = countryTag:GetCountry():GetVariables():GetVariable(CString(resource .. "_deactivate_sales")):Get()
							if isDeactivated == 1 then
								MaxSells = 0
							end
							-- Utils.LUA_DEBUGOUT(tag .. " - ".. resource .. " - " .. MaxSells)
						end
					end
				end
				-- Set ActualBalance Variable
				local command = CSetVariableCommand(countryTag, CString(resource .. "_ActualBalance"), CFixedPoint(ActualBalance))
				ai:Post(command)
				-- Set Variable for sell limit
				local command = CSetVariableCommand(countryTag, CString(resource .. "_MaxSells"), CFixedPoint(MaxSells))
				ai:Post(command)
			end
		end
	end
end



function RandomNumberGenerator(minister)

	-- Set a Variable to use in events to get a truly random experience.

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 0 and dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 15 and dayOfMonth ~= 16 and dayOfMonth ~= 17 then
		return
	end

	-- Iterate each country (using CDiplomacyStatus)
	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local tag = k

		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---"  and
		(
			((dayOfMonth == 0 or dayOfMonth == 15) and table.true_check(CountryListA, tag)) or
			((dayOfMonth == 1 or dayOfMonth == 16) and table.true_check(CountryListB, tag)) or
			((dayOfMonth == 2 or dayOfMonth == 17) and table.true_check(CountryListC, tag))
		)
		then

			local RandomNumber = math.random(100)

			local command = CSetVariableCommand(countryTag, CString("RandomNumber"), CFixedPoint(RandomNumber))
			local ai = minister:GetOwnerAI()
			ai:Post(command)
		end
	end

end

function PuppetMoneyAndFuelCheck(minister)

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 20 then
		return
	end

	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local tag = k
		local puppet_country = countryTag:GetCountry()
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" and puppet_country:IsSubject() then

			local puppet_has_money = false
			local puppet_has_fuel = false
			local puppet_fuel_level = 0
			if puppet_country:GetPool():Get(CGoodsPool._MONEY_ ):Get() > 5000 then
				puppet_has_money = true

			end
			-- The "fuel =" trigger in events doesn't work, so I need to set a variable that represents the fuel level
			if puppet_country:GetPool():Get(CGoodsPool._FUEL_):Get() >= 15000 then
				puppet_has_fuel = true
				local fuel_amount = puppet_country:GetPool():Get(CGoodsPool._FUEL_):Get()
				if fuel_amount >= 15000 and fuel_amount < 20000 then
					puppet_fuel_level = 1
				end
				if fuel_amount >= 20000 and fuel_amount < 30000 then
					puppet_fuel_level = 2
				end
				if fuel_amount >= 30000 and fuel_amount < 40000 then
					puppet_fuel_level = 3
				end
				if fuel_amount >= 40000 and fuel_amount < 50000 then
					puppet_fuel_level = 4
				end
				if fuel_amount >= 50000 then
					puppet_fuel_level = 5
				end
			end
				if puppet_has_fuel or puppet_has_money then
					local ai = minister:GetOwnerAI()
					local overlord = countryTag:GetCountry():GetOverlord()
					local overlord_country = overlord:GetCountry()
					local overlord_tag = overlord_country:GetCountryTag()

				if puppet_has_money then
					local command = CSetVariableCommand(overlord_tag, CString("puppet_has_money"), CFixedPoint(1))
					local ai = minister:GetOwnerAI()
					ai:Post(command)
				end
				if puppet_has_fuel then
					local command = CSetVariableCommand(overlord_tag, CString("puppet_has_fuel"), CFixedPoint(1))
					ai:Post(command)

					local command = CSetVariableCommand(countryTag, CString("puppet_fuel_level"), CFixedPoint(puppet_fuel_level))
					ai:Post(command)
				end
			end
		end
	end
end

function ControlledMinesCheck(minister)

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 5 and dayOfMonth ~= 20 and DateOverride ~= true then
		return
	end


	-- Setup buildings
	local minesData = {}
	minesData["chromite_building"] = CBuildingDataBase.GetBuilding("chromite_building")
	minesData["aluminium_building"] = CBuildingDataBase.GetBuilding("aluminium_building")
	minesData["rubber_building"] = CBuildingDataBase.GetBuilding("rubber_building")
	minesData["synthetic_rubber_building"] = CBuildingDataBase.GetBuilding("synthetic_rubber_building")
	minesData["tungsten_building"] = CBuildingDataBase.GetBuilding("tungsten_building")
	minesData["uranium_building"] = CBuildingDataBase.GetBuilding("uranium_building")
	minesData["gold_building"] = CBuildingDataBase.GetBuilding("gold_building")
	minesData["nickel_building"] = CBuildingDataBase.GetBuilding("nickel_building")
	minesData["copper_building"] = CBuildingDataBase.GetBuilding("copper_building")
	minesData["zinc_building"] = CBuildingDataBase.GetBuilding("zinc_building")
	minesData["manganese_building"] = CBuildingDataBase.GetBuilding("manganese_building")
	minesData["molybdenum_building"] = CBuildingDataBase.GetBuilding("molybdenum_building")

	-- Iterate each country (using Cached TAGs)
	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local tag = k

		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then

		local minesFound = false

		-- Each province
			for provinceID in countryTag:GetCountry():GetControlledProvinces() do

				-- Get province
				local province = CCurrentGameState.GetProvince(provinceID)

				if province:GetOwner() ~= countryTag then
					for mine, mineData in pairs(minesData) do
						if province:GetBuilding(mineData):GetMax():Get() >= 1 then
							minesFound = true
							break
						end
					end
				end
			end

			if minesFound == true then
			-- Set Variable
			local command = CSetVariableCommand(countryTag, CString("ControlsEnemyMines"), CFixedPoint(1))
			local ai = minister:GetOwnerAI()
			ai:Post(command)
			end
		end
	end

end



function GetIcEff(minister)

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 5 and dayOfMonth ~= 15 and dayOfMonth ~= 25 then
		return
	end

	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local tag = k

		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
			local icEffraw = countryTag:GetCountry():GetGlobalModifier():GetValue(CModifier._MODIFIER_INDUSTRIAL_EFFICIENCY_):Get()
			local icEffclean = Utils.RoundDecimal(icEffraw, 2) * 100
			-- Utils.LUA_DEBUGOUT(tag)
			-- Utils.LUA_DEBUGOUT(tostring(icEffraw))
			-- Utils.LUA_DEBUGOUT(icEffclean)

			local command = CSetVariableCommand(countryTag, CString("IcEffVariable"), CFixedPoint(icEffclean))
			local ai = minister:GetOwnerAI()
			ai:Post(command)
		end
	end
end



function ICDaysSpentCalculation(minister)
	if PlayerCountries ~= nil then
		-- only check for playercountries since AI doesnt get the effects
		for index,player in pairs(PlayerCountries) do
			local playerTag = CCountryDataBase.GetTag(player)
			local playerCountry = playerTag:GetCountry()
			local icDaysSpent = playerCountry:GetVariables():GetVariable(CString("IC_days_spent")):Get()
			local baseIC = playerCountry:GetVariables():GetVariable(CString("BaseIC")):Get()
			local investmentMult = playerCountry:GetVariables():GetVariable(CString("event_unit_investment")):Get()
			-- if no value has been set yet default to 20
			if investmentMult < 20 then
				local command = CSetVariableCommand(playerTag, CString("event_unit_investment"), CFixedPoint(20))
				local ai = OMGMinister:GetOwnerAI()
				ai:Post(command)
			end

			if icDaysSpent > 0 then
				local reductionValue = GetReductionValue(baseIC, investmentMult)
				icDaysSpent = icDaysSpent - reductionValue

				local command = CSetVariableCommand(playerTag, CString("IC_days_spent"), CFixedPoint(icDaysSpent))
				local ai = minister:GetOwnerAI()
				ai:Post(command)

				if player == PlayerCountry then
					SetCurrentDailyICDaysReduction(reductionValue)
				end
			end
			if icDaysSpent <= 0 and player == PlayerCountry then
				SetCurrentDailyICDaysReduction("0")
			end
		end
	end
end


function GetReductionValue(baseIC, mult)
	local reductionValue = 10

	if baseIC < 150 then
		reductionValue = 10
	elseif baseIC >= 150 and baseIC < 200 then
		reductionValue = 15
	elseif baseIC >= 200 and baseIC < 250 then
		reductionValue = 20
	elseif baseIC >= 250 and baseIC < 300 then
		reductionValue = 25
	elseif baseIC >= 300 and baseIC < 350 then
		reductionValue = 30
	elseif baseIC >= 350 and baseIC < 400 then
		reductionValue = 35
	elseif baseIC >= 400 and baseIC < 450 then
		reductionValue = 40
	elseif baseIC >= 450 and baseIC < 500 then
		reductionValue = 45
	elseif baseIC >= 500 and baseIC < 550 then
		reductionValue = 50
	elseif baseIC >= 550 and baseIC < 600 then
		reductionValue = 55
	elseif baseIC >= 600 and baseIC < 650 then
		reductionValue = 60
	elseif baseIC >= 650 and baseIC < 700 then
		reductionValue = 65
	elseif baseIC >= 700 then
		reductionValue = 70
	end

	if mult == 10 then
		reductionValue = reductionValue
	elseif mult == 20 then
		reductionValue = reductionValue * 2
	elseif mult == 30 then
		reductionValue = reductionValue * 3
	elseif mult == 40 then
		reductionValue = reductionValue * 4
	elseif mult == 50 then
		reductionValue = reductionValue * 5
	elseif mult == 60 then
		reductionValue = reductionValue * 6
	end

	return reductionValue
end

-- Focus is set to a single variable called "national_focus"
-- Mapped as follows:
--   1 = ground_forces
--   2 = air_force
--   3 = navy
--   4 = economy
--   5 = science
--   6 = health_education
--   7 = natural_resources
function CalculateFocuses(minister)
	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 2 and  dayOfMonth ~= 7 and dayOfMonth ~= 12 and dayOfMonth ~= 17 and dayOfMonth ~= 22 and dayOfMonth ~= 27 then
		return
	end
	local focuses = {
		"ground_forces",
		"air_force",
		"navy",
		"economy",
		"science",
		"health_and_education",
		"natural_resources"
	}
	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local playerCountry = countryTag:GetCountry()
		local variables = playerCountry:GetVariables()
		local activeFocus = variables:GetVariable(CString("national_focus")):Get()
		for focusIndex, focus in pairs(focuses) do
			local daysActive = variables:GetVariable(CString(focus .. "_national_focus_days_active")):Get()
			if focusIndex == activeFocus then
				daysActive = daysActive + 5
			elseif focusIndex ~= daysActive then
				daysActive = daysActive - 5
				if daysActive < 0 then
					daysActive = 0
				end
			end
			local command = CSetVariableCommand(countryTag, CString(focus .. "_national_focus_days_active"), CFixedPoint(daysActive))
			local ai = minister:GetOwnerAI()
			ai:Post(command)
		end
	end
end

MinisterTypes = {
	"VIC_no_faction_leader";
	"power_hungry_demagogue";
	"barking_buffoon";
	"stern_imperialist";
	"ruthless_powermonger";
	"autocratic_charmer";
	"resigned_generalissimo";
	"benevolent_gentleman";
	"weary_stiff_neck";
	"insignificant_layman";
	"die_hard_reformer";
	"pig_headed_isolationist";
	"popular_figurehead";
	"father_his_country";
	"flamboyant_tough_guy";
	"silent_workhorse";
	"naive_optimist";
	"happy_amateur";
	"backroom_backstabber";
	"smiling_oilman";
	"old_general";
	"old_admiral";
	"old_air_marshal";
	"political_protege";
	"ambitious_union_boss";
	"corporate_suit";
	"great_compromiser";
	"biased_intellectual";
	"ideological_crusader";
	"apologetic_clerk";
	"iron_fisted_brute";
	"general_staffer";
	"the_cloak_n_dagger_schemer";
	"master_of_smears";
	"administrative_genius";
	"resource_industrialist";
	"corrupt_kleptocrat";
	"mad_proponent";
	"laissez_faires_capitalist";
	"infantry_proponent";
	"military_entrepreneur";
	"tank_proponent";
	"battle_fleet_proponent";
	"submarine_proponent";
	"single_engine_aircraft_proponent";
	"twin_engine_aircraft_proponent";
	"strategic_air_proponent";
	"air_superiority_proponent";
	"theoretical_scientist";
	"research_specialist";
	"technical_specialist";
	"medium_tank_specialist";
	"heavy_tank_specialist";
	"artillery_specialist";
	"infantry_specialist";
	"rocket_specialist";
	"destroyer_specialist";
	"cruiser_specialist";
	"capitalship_specialist";
	"carrier_specialist";
	"submarine_specialist";
	"electronics_specialist";
	"decryption_specialist";
	"smallplane_specialist";
	"mediumplane_specialist";
	"largeplane_specialist";
	"jet_specialist";
	"nuclear_specialist";
	"silent_lawyer";
	"compassionate_gentleman";
	"crime_fighter";
	"prince_of_terror";
	"back_stabber";
	"man_of_the_people";
	"efficient_sociopath";
	"crooked_kleptocrat";
	"political_specialist";
	"dismal_enigma";
	"industrial_specialist";
	"naval_intelligence_specialist";
	"ideological_fanatic";
	"ruthless_monster";
	"school_of_manoeuvre";
	"school_of_fire_support";
	"school_of_mass_combat";
	"school_of_psychology";
	"school_of_defence";
	"logistics_specialist";
	"decisive_battle_doctrine";
	"elastic_defence_doctrine";
	"static_defence_doctrine";
	"armoured_spearhead_doctrine";
	"guns_and_butter_doctrine";
	"open_seas_doctrine";
	"decisive_naval_battle_doctrine";
	"power_projection_doctrine";
	"indirect_approach_doctrine";
	"base_control_doctrine";
	"air_superiority_doctrine";
	"naval_aviation_doctrine";
	"army_aviation_doctrine";
	"carpet_bombing_doctrine";
	"vertical_envelopment_doctrine";
	"undistinguished_suit";
	"Yuzuru_Hiraga";
	"Willy_Messerschmitt";
}
function CalculateMinisters(minister)
	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 2 and  dayOfMonth ~= 7 and dayOfMonth ~= 12 and dayOfMonth ~= 17 and dayOfMonth ~= 22 and dayOfMonth ~= 27 then
		return
	end
	
	for k, v in pairs(CountryIterCacheDict) do
		local tag = k
		local countryTag = v
		local country = countryTag:GetCountry()
		local cVariables = country:GetVariables()
		local x = 0
		local previousMinisters = {}
		local removedMinisters = {}
		local currentMinisters = {}
		-- Get already set ministers
		for i, ministerType in pairs(MinisterTypes) do
			if cVariables:GetVariable(CString(ministerType .. "_minister")):Get() == 1 then
				-- Utils.LUA_DEBUGOUT(tag .. " - Inserting: " .. ministerType .. "_minister")
				table.insert(previousMinisters, ministerType .. "_minister")
			end
		end
		-- Get current ingame ministers
		for curMinister in country:GetMinisters() do
			if x ~= 0 then -- "0th" minister is always noMinisterType / 0th minister does not exist ingame, it starts at 1 with Head of Government
				local typeFound = false -- debug flag to check if the type was found
				local curMinisterType = tostring(curMinister:GetPersonality(CGovernmentPositionDataBase.GetGovernmentPositionByIndex(x)):GetKey())
				for i, ministerType in pairs(MinisterTypes) do
					if curMinisterType == ministerType then
						-- Utils.LUA_DEBUGOUT(tag .. " - Matched - " .. curMinisterType .. " + " .. ministerType)
						typeFound = true
						table.insert(currentMinisters, curMinisterType .. "_minister")
					end
				end
				-- if typeFound == false then
					-- Utils.LUA_DEBUGOUT(tag .. " - Could not match: " .. curMinisterType .. " - Position:" .. x)
				-- end
			end
			x = x + 1
		end
		removedMinisters = table.shallow_copy(previousMinisters)
		-- ministers will get removed from the list if they are found to be already set
		-- leaving us with a list of ministers that were removed from their position ingame
		-- so we can remove the variable
		for i, currentMinister in pairs(currentMinisters) do
			local ministerAlreadySet = false
			for j, previousMinister in pairs(previousMinisters) do
				-- Utils.LUA_DEBUGOUT("Previous: " .. previousMinister .. " - Current: " .. currentMinister)
				if previousMinister == currentMinister then
					-- Utils.LUA_DEBUGOUT("Match!")
					ministerAlreadySet = true
					-- Utils.LUA_DEBUGOUT("Removing from list - " .. removedMinisters[table.getIndex(removedMinisters, previousMinister)])
					table.remove(removedMinisters, table.getIndex(removedMinisters, previousMinister))
				end
			end
			-- No need to set the variable again
			if ministerAlreadySet == false then
				-- Utils.LUA_DEBUGOUT(tag .. " - Setting: " .. currentMinister)
				local command = CSetVariableCommand(countryTag, CString(currentMinister), CFixedPoint(1))
				local ai = minister:GetOwnerAI()
				ai:Post(command)
			end
		end
		-- Remove the variable for the ministers remaining in removedMinisters
		for i, removedMinister in pairs(removedMinisters) do
			-- Utils.LUA_DEBUGOUT(tag .. " - Removing: " .. removedMinister)
			local command = CSetVariableCommand(countryTag, CString(removedMinister), CFixedPoint(0))
			local ai = minister:GetOwnerAI()
			ai:Post(command)
		end
	end
end