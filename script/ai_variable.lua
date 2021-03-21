
function GreaterEastAsiaCoProsperitySphere(minister)

	-- Greater East Asia Co-Prosperity Sphere
	-- Indonesia and Phillipines would be historical but just pure bad decision, woud lose proper control of important naval bases/air bases
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

function BaseICCount(minister)

	-- Setup buildings
	local industry = CBuildingDataBase.GetBuilding("industry" )
	local heavy_industry = CBuildingDataBase.GetBuilding("heavy_industry")

	-- Iterate each country (using CDiplomacyStatus)
	for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
		local countryTag = dip:GetTarget()

		local tag = tostring(countryTag)
		if not tag == "REB" and not tag == "OMG" then

			-- Each province
			local totalIC = 10 -- Every nation has 10 free IC
			for provinceID in countryTag:GetCountry():GetOwnedProvinces() do
				-- Get province
				local province = CCurrentGameState.GetProvince(provinceID)

				-- Add province IC with HIC bonus
				totalIC = totalIC + province:GetBuilding(industry):GetMax():Get() * (1 + province:GetBuilding(heavy_industry):GetMax():Get() * 0.25)
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

function BuildingsCount(minister)

	-- Setup buildings
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

	local buildinsStruct = {}
	--buildinsStruct["air_base"] = CBuildingDataBase.GetBuilding("air_base")
	--buildinsStruct["naval_base"] = CBuildingDataBase.GetBuilding("naval_base")
	--buildinsStruct["coastal_fort"] = CBuildingDataBase.GetBuilding("coastal_fort")
	--buildinsStruct["beach_defence"] = CBuildingDataBase.GetBuilding("beach_defence")
	--buildinsStruct["land_fort"] = CBuildingDataBase.GetBuilding("land_fort")
	--buildinsStruct["fortress"] = CBuildingDataBase.GetBuilding("fortress")
	--buildinsStruct["anti_air"] = CBuildingDataBase.GetBuilding("anti_air")
	--buildinsStruct["radar_station"] = CBuildingDataBase.GetBuilding("radar_station")
	--buildinsStruct["industry"] = CBuildingDataBase.GetBuilding("industry")
	--buildinsStruct["heavy_industry"] = CBuildingDataBase.GetBuilding("heavy_industry")
	--buildinsStruct["steel_factory"] = CBuildingDataBase.GetBuilding("steel_factory")
	--buildinsStruct["coal_mining"] = CBuildingDataBase.GetBuilding("coal_mining")
	--buildinsStruct["sourcing_rares"] = CBuildingDataBase.GetBuilding("sourcing_rares")
	--buildinsStruct["oil_well"] = CBuildingDataBase.GetBuilding("oil_well")
	--buildinsStruct["oil_refinery"] = CBuildingDataBase.GetBuilding("oil_refinery")
	buildinsStruct["supplies_factory"] = CBuildingDataBase.GetBuilding("supplies_factory")
	buildinsStruct["military_college"] = CBuildingDataBase.GetBuilding("military_college")
	--buildinsStruct["urbanisation"] = CBuildingDataBase.GetBuilding("urbanisation")
	buildinsStruct["research_lab"] = CBuildingDataBase.GetBuilding("research_lab")
	buildinsStruct["hospital"] = CBuildingDataBase.GetBuilding("hospital")
	--buildinsStruct["police_station"] = CBuildingDataBase.GetBuilding("police_station")
	--buildinsStruct["infra"] = CBuildingDataBase.GetBuilding("infra")
	buildinsStruct["rail_terminous"] = CBuildingDataBase.GetBuilding("rail_terminous")
	--buildinsStruct["nuclear_reactor"] = CBuildingDataBase.GetBuilding("nuclear_reactor")
	--buildinsStruct["rocket_test"] = CBuildingDataBase.GetBuilding("rocket_test")
	buildinsStruct["small_ship_shipyard"] = CBuildingDataBase.GetBuilding("small_ship_shipyard")
	buildinsStruct["medium_ship_shipyard"] = CBuildingDataBase.GetBuilding("medium_ship_shipyard")
	buildinsStruct["capital_ship_shipyard"] = CBuildingDataBase.GetBuilding("capital_ship_shipyard")
	buildinsStruct["submarine_shipyard"] = CBuildingDataBase.GetBuilding("submarine_shipyard")
	buildinsStruct["smallarms_factory"] = CBuildingDataBase.GetBuilding("smallarms_factory")
	buildinsStruct["automotive_factory"] = CBuildingDataBase.GetBuilding("automotive_factory")
	buildinsStruct["artillery_factory"] = CBuildingDataBase.GetBuilding("artillery_factory")
	buildinsStruct["tank_factory"] = CBuildingDataBase.GetBuilding("tank_factory")
	buildinsStruct["light_aircraft_factory"] = CBuildingDataBase.GetBuilding("light_aircraft_factory")
	buildinsStruct["medium_aircraft_factory"] = CBuildingDataBase.GetBuilding("medium_aircraft_factory")
	buildinsStruct["heavy_aircraft_factory"] = CBuildingDataBase.GetBuilding("heavy_aircraft_factory")
	--buildinsStruct["underground"] = CBuildingDataBase.GetBuilding("underground")
	--buildinsStruct["desperate_defence"] = CBuildingDataBase.GetBuilding("desperate_defence")
	--buildinsStruct["weather_fort"] = CBuildingDataBase.GetBuilding("weather_fort")
	--buildinsStruct["fake_air_base"] = CBuildingDataBase.GetBuilding("fake_air_base")

	-- Iterate each country (using CDiplomacyStatus)
	for dip in minister:GetCountryTag():GetCountry():GetDiplomacy() do
		local countryTag = dip:GetTarget()

		local tag = tostring(countryTag)
		if not tag == "REB" and not tag == "OMG" then
			-- Each province
			for provinceID in countryTag:GetCountry():GetOwnedProvinces() do

				-- Get province data
				local provinceStruct = CCurrentGameState.GetProvince(provinceID)

				-- Each building
				for buildingtype, buildingcount in pairs(buildings) do
					-- Increment building count
					buildings[buildingtype] = buildings[buildingtype] +  provinceStruct:GetBuilding(buildinsStruct[buildingtype]):GetMax():Get()
				end

			end

			for buildingtype, buildingcount in pairs(buildings) do
				-- Set Variable
				local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count"), CFixedPoint(buildingcount))
				local ai = minister:GetOwnerAI()
				ai:Post(command)
			end
		end
	end

end