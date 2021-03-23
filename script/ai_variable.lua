
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

function BaseICCount(minister)

	-- Setup buildings
	local industry = CBuildingDataBase.GetBuilding("industry" )
	local heavy_industry = CBuildingDataBase.GetBuilding("heavy_industry")

	-- Iterate each country (using CDiplomacyStatus)
	for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
		local countryTag = dip:GetTarget()

		local tag = tostring(countryTag)
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then

			-- Each province
			local totalIC = 10 -- Every nation has 10 free IC
			for provinceID in countryTag:GetCountry():GetCoreProvinces() do
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

local country_current_count = {}
local country_cumulative_gain_count = {}
local country_cumulative_loss_count = {}
local setup = true
function BuildingsCount(minister)

	--Utils.LUA_DEBUGOUT("Enter building count")

	-- Only run at 1st and 14th of each month
	-- TODO improve this to spread country calculations through multiple days, do x countries per day
	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 0 and dayOfMonth ~= 14 then
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

	-- Setup initial LUA storage (GetVariable doesnt work)
	if setup then

		--Utils.LUA_DEBUGOUT("First building count setup start")

		local buildings = {}
		--buildings["air_base"] = 0
		--buildings["naval_base"] = 0
		--buildings["coastal_fort"] = 0
		--buildings["beach_defence"] = 0
		--buildings["land_fort"] = 0
		--buildings["fortress"] = 0
		--buildings["anti_air"] = 0
		--buildings["radar_station"] = 0
		--buildings["industry"] = 0
		--buildings["heavy_industry"] = 0
		--buildings["steel_factory"] = 0
		--buildings["coal_mining"] = 0
		--buildings["sourcing_rares"] = 0
		--buildings["oil_well"] = 0
		--buildings["oil_refinery"] = 0
		buildings["supplies_factory"] = 0
		buildings["military_college"] = 0
		--buildings["urbanisation"] = 0
		buildings["research_lab"] = 0
		buildings["hospital"] = 0
		--buildings["police_station"] = 0
		--buildings["infra"] = 0
		buildings["rail_terminous"] = 0
		--buildings["nuclear_reactor"] = 0
		--buildings["rocket_test"] = 0
		buildings["small_ship_shipyard"] = 0
		buildings["medium_ship_shipyard"] = 0
		buildings["capital_ship_shipyard"] = 0
		buildings["submarine_shipyard"] = 0
		buildings["smallarms_factory"] = 0
		buildings["automotive_factory"] = 0
		buildings["artillery_factory"] = 0
		buildings["tank_factory"] = 0
		buildings["light_aircraft_factory"] = 0
		buildings["medium_aircraft_factory"] = 0
		buildings["heavy_aircraft_factory"] = 0
		--buildings["underground"] = 0
		--buildings["desperate_defence"] = 0
		--buildings["weather_fort"] = 0
		--buildings["fake_air_base"] = 0

		for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
			local countryTag = dip:GetTarget()

			local tag = tostring(countryTag)
			if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
				country_current_count[tostring(countryTag)] = table.shallow_copy(buildings)
				country_cumulative_gain_count[tostring(countryTag)] = table.shallow_copy(buildings)
				country_cumulative_loss_count[tostring(countryTag)] = table.shallow_copy(buildings)
			end
		end

		setup = false

		--Utils.LUA_DEBUGOUT("First building count setup end")

	end

	-- Iterate each country (using CDiplomacyStatus)
	for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
		local countryTag = dip:GetTarget()

		local tag = tostring(countryTag)
		--Utils.LUA_DEBUGOUT("Building count Country " .. tag)
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then

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

			-- Previous count
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

			-- Count current buildings
			for provinceID in countryTag:GetCountry():GetCoreProvinces() do

				-- Get province data
				local provinceStruct = CCurrentGameState.GetProvince(provinceID)

				-- Check under control
				if provinceStruct:GetController() == countryTag then

					-- Each building
					for buildingtype, buildingcount in pairs(currentBuildings) do
						-- Increment building count
						currentBuildings[buildingtype] = currentBuildings[buildingtype] + provinceStruct:GetBuilding(buildingsData[buildingtype]):GetMax():Get()
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

				-- Update local variables
				country_current_count[tag][buildingtype] = buildingcount
				country_cumulative_gain_count[tag][buildingtype] = cumulativeGainBuildings[buildingtype]
				country_cumulative_loss_count[tag][buildingtype] = cumulativeLoseBuildings[buildingtype]

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