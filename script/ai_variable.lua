
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

function table.true_check(table, tag)
	for k,v in pairs(table) do
		if k == tag then
			return v
		end
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
]]

local country_base_ic = {}
local setupBaseICCount = true
function BaseICCount(minister)

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 0 and dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 15 and dayOfMonth ~= 16 and dayOfMonth ~= 17 then
		return
	end

	-- Setup initial LUA storage (GetVariable doesnt work)
	if setupBaseICCount then
		for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
			local countryTag = dip:GetTarget()

			local tag = tostring(countryTag)

			if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" and
			(
				((dayOfMonth == 0 or dayOfMonth == 15) and table.true_check(CountryListA, tag)) or
				((dayOfMonth == 1 or dayOfMonth == 16) and table.true_check(CountryListB, tag)) or
				((dayOfMonth == 2 or dayOfMonth == 17) and table.true_check(CountryListC, tag))
			)
			then

				country_base_ic[tostring(countryTag)] = 0
			end
		end
		setupBaseICCount = false
	end

	-- Setup buildings
	local industry = CBuildingDataBase.GetBuilding("industry" )
	local heavy_industry = CBuildingDataBase.GetBuilding("heavy_industry")

	-- Iterate each country (using CDiplomacyStatus)
	for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
		local countryTag = dip:GetTarget()

		local tag = tostring(countryTag)

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

			country_base_ic[tag] = totalIC

			-- Set Variable
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

function BuildingsCount(minister)

	--Utils.LUA_DEBUGOUT("Enter building count")

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 0 and dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 15 and dayOfMonth ~= 16 and dayOfMonth ~= 17 then
		return
	end

	-- Setup buildings

	local buildingsData = {}
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
	buildingsData["tungsten_building"] = CBuildingDataBase.GetBuilding("tungsten_building")
	buildingsData["uranium_building"] = CBuildingDataBase.GetBuilding("uranium_building")
	buildingsData["gold_building"] = CBuildingDataBase.GetBuilding("gold_building")
	buildingsData["nickel_building"] = CBuildingDataBase.GetBuilding("nickel_building")
	buildingsData["copper_building"] = CBuildingDataBase.GetBuilding("copper_building")
	buildingsData["zinc_building"] = CBuildingDataBase.GetBuilding("zinc_building")
	buildingsData["manganese_building"] = CBuildingDataBase.GetBuilding("manganese_building")
	buildingsData["molybdenum_building"] = CBuildingDataBase.GetBuilding("molybdenum_building")


	-- Iterate each country (using CDiplomacyStatus)
	for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
		local countryTag = dip:GetTarget()

		local tag = tostring(countryTag)
		--Utils.LUA_DEBUGOUT("Building count Country " .. tag)
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---"  and
		(
			((dayOfMonth == 0 or dayOfMonth == 15) and table.true_check(CountryListA, tag)) or
			((dayOfMonth == 1 or dayOfMonth == 16) and table.true_check(CountryListB, tag)) or
			((dayOfMonth == 2 or dayOfMonth == 17) and table.true_check(CountryListC, tag))
		)
		then

			local currentBuildings = {}
			--currentBuildings["air_base"] = 0
			--currentBuildings["naval_base"] = 0
			--currentBuildings["coastal_fort"] = 0
			--currentBuildings["beach_defence"] = 0
			--currentBuildings["land_fort"] = 0
			--currentBuildings["fortress"] = 0
			--currentBuildings["anti_air"] = 0
			--currentBuildings["radar_station"] = 0
			--currentBuildings["industry"] = 0
			--currentBuildings["heavy_industry"] = 0
			--currentBuildings["steel_factory"] = 0
			--currentBuildings["coal_mining"] = 0
			--currentBuildings["sourcing_rares"] = 0
			--currentBuildings["oil_well"] = 0
			--currentBuildings["oil_refinery"] = 0
			currentBuildings["supplies_factory"] = 0
			currentBuildings["military_college"] = 0
			--currentBuildings["urbanisation"] = 0
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
			currentBuildings["chromite_building"] = 0
			currentBuildings["aluminium_building"] = 0
			currentBuildings["rubber_building"] = 0
			currentBuildings["tungsten_building"] = 0
			currentBuildings["uranium_building"] = 0
			currentBuildings["gold_building"] = 0
			currentBuildings["nickel_building"] = 0
			currentBuildings["copper_building"] = 0
			currentBuildings["zinc_building"] = 0
			currentBuildings["manganese_building"] = 0
			currentBuildings["molybdenum_building"] = 0
			
			local country_current_count = {}
			--currentBuildings["air_base"] = 0
			--currentBuildings["naval_base"] = 0
			--currentBuildings["coastal_fort"] = 0
			--currentBuildings["beach_defence"] = 0
			--currentBuildings["land_fort"] = 0
			--currentBuildings["fortress"] = 0
			--currentBuildings["anti_air"] = 0
			--currentBuildings["radar_station"] = 0
			--currentBuildings["industry"] = 0
			--currentBuildings["heavy_industry"] = 0
			--currentBuildings["steel_factory"] = 0
			--currentBuildings["coal_mining"] = 0
			--currentBuildings["sourcing_rares"] = 0
			--currentBuildings["oil_well"] = 0
			--currentBuildings["oil_refinery"] = 0
			country_current_count["supplies_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("supplies_factory_count")):Get()
			country_current_count["military_college"] = countryTag:GetCountry():GetVariables():GetVariable(CString("military_college_count")):Get()
			--currentBuildings["urbanisation"] = 0
			country_current_count["research_lab"] = countryTag:GetCountry():GetVariables():GetVariable(CString("research_lab_count")):Get()
			country_current_count["hospital"] = countryTag:GetCountry():GetVariables():GetVariable(CString("hospital_count")):Get()
			--currentBuildings["police_station"] = 0
			--currentBuildings["infra"] = 0
			country_current_count["rail_terminous"] = countryTag:GetCountry():GetVariables():GetVariable(CString("rail_terminous_count")):Get()
			--currentBuildings["nuclear_reactor"] = 0
			--currentBuildings["rocket_test"] = 0
			country_current_count["small_ship_shipyard"] = countryTag:GetCountry():GetVariables():GetVariable(CString("small_ship_shipyard_count")):Get()
			country_current_count["medium_ship_shipyard"] = countryTag:GetCountry():GetVariables():GetVariable(CString("medium_ship_shipyard_count")):Get()
			country_current_count["capital_ship_shipyard"] = countryTag:GetCountry():GetVariables():GetVariable(CString("capital_ship_shipyard_count")):Get()
			country_current_count["submarine_shipyard"] = countryTag:GetCountry():GetVariables():GetVariable(CString("submarine_shipyard_count")):Get()
			country_current_count["smallarms_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("smallarms_factory_count")):Get()
			country_current_count["automotive_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("automotive_factory_count")):Get()
			country_current_count["artillery_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("artillery_factory_count")):Get()
			country_current_count["tank_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("tank_factory_count")):Get()
			country_current_count["light_aircraft_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("light_aircraft_factory_count")):Get()
			country_current_count["medium_aircraft_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("medium_aircraft_factory_count")):Get()
			country_current_count["heavy_aircraft_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("heavy_aircraft_factory_count")):Get()
			--currentBuildings["underground"] = 0
			--currentBuildings["desperate_defence"] = 0
			--currentBuildings["weather_fort"] = 0
			--currentBuildings["fake_air_base"] = 0
			country_current_count["chromite_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("chromite_building_count")):Get()
			country_current_count["aluminium_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("aluminium_building_count")):Get()
			country_current_count["rubber_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("rubber_building_count")):Get()
			country_current_count["tungsten_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("tungsten_building_count")):Get()
			country_current_count["uranium_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("uranium_building_count")):Get()
			country_current_count["gold_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("gold_building_count")):Get()
			country_current_count["nickel_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("nickel_building_count")):Get()
			country_current_count["copper_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("copper_building_count")):Get()
			country_current_count["zinc_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("zinc_building_count")):Get()
			country_current_count["manganese_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("manganese_building_count")):Get()
			country_current_count["molybdenum_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("molybdenum_building_count")):Get()
			
			local country_cumulative_gain_count = {}
			--currentBuildings["air_base"] = 0
			--currentBuildings["naval_base"] = 0
			--currentBuildings["coastal_fort"] = 0
			--currentBuildings["beach_defence"] = 0
			--currentBuildings["land_fort"] = 0
			--currentBuildings["fortress"] = 0
			--currentBuildings["anti_air"] = 0
			--currentBuildings["radar_station"] = 0
			--currentBuildings["industry"] = 0
			--currentBuildings["heavy_industry"] = 0
			--currentBuildings["steel_factory"] = 0
			--currentBuildings["coal_mining"] = 0
			--currentBuildings["sourcing_rares"] = 0
			--currentBuildings["oil_well"] = 0
			--currentBuildings["oil_refinery"] = 0
			country_cumulative_gain_count["supplies_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("supplies_factory_cumulative_gain_count")):Get()
			country_cumulative_gain_count["military_college"] = countryTag:GetCountry():GetVariables():GetVariable(CString("military_college_cumulative_gain_count")):Get()
			--currentBuildings["urbanisation"] = 0
			country_cumulative_gain_count["research_lab"] = countryTag:GetCountry():GetVariables():GetVariable(CString("research_lab_cumulative_gain_count")):Get()
			country_cumulative_gain_count["hospital"] = countryTag:GetCountry():GetVariables():GetVariable(CString("hospital_cumulative_gain_count")):Get()
			--currentBuildings["police_station"] = 0
			--currentBuildings["infra"] = 0
			country_cumulative_gain_count["rail_terminous"] = countryTag:GetCountry():GetVariables():GetVariable(CString("rail_terminous_cumulative_gain_count")):Get()
			--currentBuildings["nuclear_reactor"] = 0
			--currentBuildings["rocket_test"] = 0
			country_cumulative_gain_count["small_ship_shipyard"] = countryTag:GetCountry():GetVariables():GetVariable(CString("small_ship_shipyard_cumulative_gain_count")):Get()
			country_cumulative_gain_count["medium_ship_shipyard"] = countryTag:GetCountry():GetVariables():GetVariable(CString("medium_ship_shipyard_cumulative_gain_count")):Get()
			country_cumulative_gain_count["capital_ship_shipyard"] = countryTag:GetCountry():GetVariables():GetVariable(CString("capital_ship_shipyard_cumulative_gain_count")):Get()
			country_cumulative_gain_count["submarine_shipyard"] = countryTag:GetCountry():GetVariables():GetVariable(CString("submarine_shipyard_cumulative_gain_count")):Get()
			country_cumulative_gain_count["smallarms_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("smallarms_factory_cumulative_gain_count")):Get()
			country_cumulative_gain_count["automotive_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("automotive_factory_cumulative_gain_count")):Get()
			country_cumulative_gain_count["artillery_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("artillery_factory_cumulative_gain_count")):Get()
			country_cumulative_gain_count["tank_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("tank_factory_cumulative_gain_count")):Get()
			country_cumulative_gain_count["light_aircraft_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("light_aircraft_factory_cumulative_gain_count")):Get()
			country_cumulative_gain_count["medium_aircraft_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("medium_aircraft_factory_cumulative_gain_count")):Get()
			country_cumulative_gain_count["heavy_aircraft_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("heavy_aircraft_factory_cumulative_gain_count")):Get()
			--currentBuildings["underground"] = 0
			--currentBuildings["desperate_defence"] = 0
			--currentBuildings["weather_fort"] = 0
			--currentBuildings["fake_air_base"] = 0
			country_cumulative_gain_count["chromite_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("chromite_building_cumulative_gain_count")):Get()
			country_cumulative_gain_count["aluminium_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("aluminium_building_cumulative_gain_count")):Get()
			country_cumulative_gain_count["rubber_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("rubber_building_cumulative_gain_count")):Get()
			country_cumulative_gain_count["tungsten_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("tungsten_building_cumulative_gain_count")):Get()
			country_cumulative_gain_count["uranium_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("uranium_building_cumulative_gain_count")):Get()
			country_cumulative_gain_count["gold_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("gold_building_cumulative_gain_count")):Get()
			country_cumulative_gain_count["nickel_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("nickel_building_cumulative_gain_count")):Get()
			country_cumulative_gain_count["copper_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("copper_building_cumulative_gain_count")):Get()
			country_cumulative_gain_count["zinc_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("zinc_building_cumulative_gain_count")):Get()
			country_cumulative_gain_count["manganese_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("manganese_building_cumulative_gain_count")):Get()
			country_cumulative_gain_count["molybdenum_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("molybdenum_building_cumulative_gain_count")):Get()
			
			local country_cumulative_loss_count = {}
			--currentBuildings["air_base"] = 0
			--currentBuildings["naval_base"] = 0
			--currentBuildings["coastal_fort"] = 0
			--currentBuildings["beach_defence"] = 0
			--currentBuildings["land_fort"] = 0
			--currentBuildings["fortress"] = 0
			--currentBuildings["anti_air"] = 0
			--currentBuildings["radar_station"] = 0
			--currentBuildings["industry"] = 0
			--currentBuildings["heavy_industry"] = 0
			--currentBuildings["steel_factory"] = 0
			--currentBuildings["coal_mining"] = 0
			--currentBuildings["sourcing_rares"] = 0
			--currentBuildings["oil_well"] = 0
			--currentBuildings["oil_refinery"] = 0
			country_cumulative_loss_count["supplies_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("supplies_factory_cumulative_loss_count")):Get()
			country_cumulative_loss_count["military_college"] = countryTag:GetCountry():GetVariables():GetVariable(CString("military_college_cumulative_loss_count")):Get()
			--currentBuildings["urbanisation"] = 0
			country_cumulative_loss_count["research_lab"] = countryTag:GetCountry():GetVariables():GetVariable(CString("research_lab_cumulative_loss_count")):Get()
			country_cumulative_loss_count["hospital"] = countryTag:GetCountry():GetVariables():GetVariable(CString("hospital_cumulative_loss_count")):Get()
			--currentBuildings["police_station"] = 0
			--currentBuildings["infra"] = 0
			country_cumulative_loss_count["rail_terminous"] = countryTag:GetCountry():GetVariables():GetVariable(CString("rail_terminous_cumulative_loss_count")):Get()
			--currentBuildings["nuclear_reactor"] = 0
			--currentBuildings["rocket_test"] = 0
			country_cumulative_loss_count["small_ship_shipyard"] = countryTag:GetCountry():GetVariables():GetVariable(CString("small_ship_shipyard_cumulative_loss_count")):Get()
			country_cumulative_loss_count["medium_ship_shipyard"] = countryTag:GetCountry():GetVariables():GetVariable(CString("medium_ship_shipyard_cumulative_loss_count")):Get()
			country_cumulative_loss_count["capital_ship_shipyard"] = countryTag:GetCountry():GetVariables():GetVariable(CString("capital_ship_shipyard_cumulative_loss_count")):Get()
			country_cumulative_loss_count["submarine_shipyard"] = countryTag:GetCountry():GetVariables():GetVariable(CString("submarine_shipyard_cumulative_loss_count")):Get()
			country_cumulative_loss_count["smallarms_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("smallarms_factory_cumulative_loss_count")):Get()
			country_cumulative_loss_count["automotive_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("automotive_factory_cumulative_loss_count")):Get()
			country_cumulative_loss_count["artillery_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("artillery_factory_cumulative_loss_count")):Get()
			country_cumulative_loss_count["tank_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("tank_factory_cumulative_loss_count")):Get()
			country_cumulative_loss_count["light_aircraft_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("light_aircraft_factory_cumulative_loss_count")):Get()
			country_cumulative_loss_count["medium_aircraft_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("medium_aircraft_factory_cumulative_loss_count")):Get()
			country_cumulative_loss_count["heavy_aircraft_factory"] = countryTag:GetCountry():GetVariables():GetVariable(CString("heavy_aircraft_factory_cumulative_loss_count")):Get()
			--currentBuildings["underground"] = 0
			--currentBuildings["desperate_defence"] = 0
			--currentBuildings["weather_fort"] = 0
			--currentBuildings["fake_air_base"] = 0
			country_cumulative_loss_count["chromite_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("chromite_building_cumulative_loss_count")):Get()
			country_cumulative_loss_count["aluminium_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("aluminium_building_cumulative_loss_count")):Get()
			country_cumulative_loss_count["rubber_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("rubber_building_cumulative_loss_count")):Get()
			country_cumulative_loss_count["tungsten_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("tungsten_building_cumulative_loss_count")):Get()
			country_cumulative_loss_count["uranium_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("uranium_building_cumulative_loss_count")):Get()
			country_cumulative_loss_count["gold_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("gold_building_cumulative_loss_count")):Get()
			country_cumulative_loss_count["nickel_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("nickel_building_cumulative_loss_count")):Get()
			country_cumulative_loss_count["copper_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("copper_building_cumulative_loss_count")):Get()
			country_cumulative_loss_count["zinc_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("zinc_building_cumulative_loss_count")):Get()
			country_cumulative_loss_count["manganese_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("manganese_building_cumulative_loss_count")):Get()
			country_cumulative_loss_count["molybdenum_building"] = countryTag:GetCountry():GetVariables():GetVariable(CString("molybdenum_building_cumulative_loss_count")):Get()
			
			-- Previous count
			--Utils.LUA_DEBUGOUT("Getting previous count")
			local previousBuildings = {}
			for buildingtype, buildingcount in pairs(currentBuildings) do
				previousBuildings[buildingtype] = country_current_count[buildingtype]
				--Utils.LUA_DEBUGOUT("Previous count " .. buildingtype .. ":" .. previousBuildings[buildingtype])
			end

			-- Cumulative gain count
			local cumulativeGainBuildings = {}
			for buildingtype, buildingcount in pairs(currentBuildings) do
				cumulativeGainBuildings[buildingtype] = country_cumulative_gain_count[buildingtype]
				--Utils.LUA_DEBUGOUT("Cumulative gain " .. buildingtype .. ":" .. cumulativeGainBuildings[buildingtype])
			end

			-- Cumulative lost count
			local cumulativeLoseBuildings = {}
			for buildingtype, buildingcount in pairs(currentBuildings) do
				cumulativeLoseBuildings[buildingtype] = country_cumulative_loss_count[buildingtype]
				--Utils.LUA_DEBUGOUT("Cumulative lost " .. buildingtype .. ":" .. cumulativeLoseBuildings[buildingtype])
			end

			-- Count current buildings
			for provinceID in countryTag:GetCountry():GetCoreProvinces() do

				-- Get province data
				local provinceStruct = CCurrentGameState.GetProvince(provinceID)

				-- Check under control
				if provinceStruct:GetController() == countryTag then

					-- Each building
					for buildingtype, buildingcount in pairs(currentBuildings) do
						-- Increment building count

						-- Base value
						local increment = 1

						-- Effect reduced by half above 20 levels
						if currentBuildings[buildingtype] > 20 then
							increment = 0.5
						end

						currentBuildings[buildingtype] = currentBuildings[buildingtype] + provinceStruct:GetBuilding(buildingsData[buildingtype]):GetMax():Get() * increment
					end

				end

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

				-- Update local variables -- set to Variables later
				country_current_count[buildingtype] = buildingcount
				country_cumulative_gain_count[buildingtype] = cumulativeGainBuildings[buildingtype]
				country_cumulative_loss_count[buildingtype] = cumulativeLoseBuildings[buildingtype]

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
			-- Set cumulative_count Variables
			for buildingtype, buildingcount in pairs(country_cumulative_gain_count) do

				local ai = minister:GetOwnerAI()
				local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_cumulative_gain_count"), CFixedPoint(buildingcount))
				ai:Post(command)
			end
			for buildingtype, buildingcount in pairs(country_cumulative_loss_count) do

				local ai = minister:GetOwnerAI()
				local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_cumulative_loss_count"), CFixedPoint(buildingcount))
				ai:Post(command)
			end
		end
	end

end

function StratResourceBalance(minister)

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 3 and dayOfMonth ~= 16 and dayOfMonth ~= 17 and dayOfMonth ~= 18 then
		return
	end

	local resourceBuildings = {
		"chromite_building";
		"aluminium_building";
		"rubber_building";
		"tungsten_building";
		"uranium_building";
		"gold_building";
		"nickel_building";
		"copper_building";
		"zinc_building";
		"manganese_building";
		"molybdenum_building"
	}


	local ai = minister:GetOwnerAI()
	for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
		local countryTag = dip:GetTarget()

		local tag = tostring(countryTag)
		--Utils.LUA_DEBUGOUT("Building count Country " .. tag)
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---"  and
		(
			((dayOfMonth == 1 or dayOfMonth == 16) and table.true_check(CountryListA, tag)) or
			((dayOfMonth == 2 or dayOfMonth == 17) and table.true_check(CountryListB, tag)) or
			((dayOfMonth == 3 or dayOfMonth == 18) and table.true_check(CountryListC, tag))
		)
		then

			local BaseIC = countryTag:GetCountry():GetVariables():GetVariable(CString("BaseIC")):Get()
			-- Each resource building
			for k,building in pairs(resourceBuildings) do

				-- Calculate balance
				-- Each 200 IC needs 1 resource, no need below 100 IC
				-- TODO later can have different requirements per resource
				local value = countryTag:GetCountry():GetVariables():GetVariable(CString(building .. "_count")):Get() * 200
				local balance = 0

				if BaseIC < 100 then
					balance = math.ceil((value - BaseIC ) / 200)
				end
				if BaseIC > 100 then
					balance = math.floor((value - BaseIC ) / 200)
				end

				balance = balance + 1000
				-- 1000 as the 0 (cant set variables with value 0...)


				-- Set variable
				local command = CSetVariableCommand(countryTag, CString(building .. "_balance"), CFixedPoint(balance))
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
	if dayOfMonth ~= 5 then
		return
	end

	local ai = minister:GetOwnerAI()
	for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
		local countryTag = dip:GetTarget()

		local tag = tostring(countryTag)
		--Utils.LUA_DEBUGOUT("Building count Country " .. tag)
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---"  then

			for k,resource in pairs(resources) do

				local BaseValue = countryTag:GetCountry():GetVariables():GetVariable(CString(resource .. "_building_balance")):Get()
				local SellValue = countryTag:GetCountry():GetVariables():GetVariable(CString(resource .. "_trade_sell")):Get()
				local BuyValue = countryTag:GetCountry():GetVariables():GetVariable(CString(resource .. "_trade_buy")):Get()

				local ActualBalance = BaseValue + BuyValue - SellValue

				--Utils.LUA_DEBUGOUT("LUA_DEBUG_countryTag '" .. tostring(countryTag) .. " -- " .. tostring(resource) .. "' \n")
				--Utils.LUA_DEBUGOUT("LUA_DEBUG_BaseValue '" .. tostring(BaseValue) .. "' \n")
				--Utils.LUA_DEBUGOUT("LUA_DEBUG_SellValue '" .. tostring(SellValue) .. "' \n")
				--Utils.LUA_DEBUGOUT("LUA_DEBUG_BuyValue '" .. tostring(BuyValue) .. "' \n")
				--Utils.LUA_DEBUGOUT("LUA_DEBUG_ActualBalance '" .. tostring(ActualBalance) .. "' \n")

				local command = CSetVariableCommand(countryTag, CString(resource .. "_ActualBalance"), CFixedPoint(ActualBalance))
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

	local RandomNumber = math.random(100)

	-- Iterate each country (using CDiplomacyStatus)
	for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
		local countryTag = dip:GetTarget()

		local tag = tostring(countryTag)
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---"  and
		(
			((dayOfMonth == 0 or dayOfMonth == 15) and table.true_check(CountryListA, tag)) or
			((dayOfMonth == 1 or dayOfMonth == 16) and table.true_check(CountryListB, tag)) or
			((dayOfMonth == 2 or dayOfMonth == 17) and table.true_check(CountryListC, tag))
		)
		then

			-- Set Variable
			local command = CSetVariableCommand(countryTag, CString("RandomNumber"), CFixedPoint(RandomNumber))
			local ai = minister:GetOwnerAI()
			ai:Post(command)
		end
	end

end


function VariableTest(minister)

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 100 then
		return
	end

	for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
		local countryTag = dip:GetTarget()

		local tag = tostring(countryTag)
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---"  then

			local BaseIC = countryTag:GetCountry():GetVariables():GetVariable(CString("BaseIC")):Get()
			Utils.LUA_DEBUGOUT("LUA_DEBUG_Country '" .. tostring(countryTag) .. "' \n")
			Utils.LUA_DEBUGOUT("LUA_DEBUG_BaseIC '" .. tostring(BaseIC) .. "' \n")

		end
	end

end