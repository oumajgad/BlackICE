
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

function table.removeEntryByKey(table, key)
    local element = table[key]
    table[key] = nil
    return element
end

function table.sum(table)
	local s = 0
	for k, v in pairs(table) do
		s = s + v
	end
	return s
end

function table.shallow_copy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end

function table.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[table.deepcopy(orig_key)] = table.deepcopy(orig_value)
        end
        setmetatable(copy, table.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local countryIterCacheDict = {}
local countryIterCacheCheck = 0
-- Cache the Country Tags once at the start of a session so we dont have to use API calls a million times each time
function GetCountryIterCacheDict()
	if countryIterCacheCheck == 0 then
		for dip in CCountryDataBase.GetTag("OMG"):GetCountry():GetDiplomacy() do
			local countryTag = dip:GetTarget()
			local tag = tostring(countryTag)
			if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
				--Utils.LUA_DEBUGOUT("Tag - " .. tag)
				countryIterCacheDict[tag] = countryTag
			end
		end
		countryIterCacheCheck = 1
	end
	return countryIterCacheDict
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
	for k, v in pairs(GetCountryIterCacheDict()) do
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

function BaseICbyMinister()

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 0 and dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 15 and dayOfMonth ~= 16 and dayOfMonth ~= 17 and G_DateOverride ~= true then
		return
	end

	-- Utils.LUA_DEBUGOUT("BaseIC_minister")
	for k, v in pairs(GetCountryIterCacheDict()) do
		local countryTag = v
		local tag = k

		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---"  and (
		(
			((dayOfMonth == 0 or dayOfMonth == 15) and table.true_check(CountryListA, tag)) or
			((dayOfMonth == 1 or dayOfMonth == 16) and table.true_check(CountryListB, tag)) or
			((dayOfMonth == 2 or dayOfMonth == 17) and table.true_check(CountryListC, tag))
		) or G_DateOverride == true )
		then
			local totalIC = countryTag:GetCountry():GetMaxIC()

			-- Utils.LUA_DEBUGOUT(tag)
			-- Utils.LUA_DEBUGOUT(totalIC)

			-- local command = CSetVariableCommand(countryTag, CString("BaseIC_minister"), CFixedPoint(totalIC))
			local command = CSetVariableCommand(countryTag, CString("BaseIC"), CFixedPoint(totalIC))
			CCurrentGameState.Post(command)

		end
	end
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
local buildingsCountSetupNeeded = true

-- Get all the Variables from the Save, save them in local LUA arrays.
-- LUA variables/arrays get lost each restart, so this only needs to run once at the start of a session.
local function buildingsCountSetup()
	local buildings = {
		"air_base",
		"naval_base",
		"coastal_fort",
		"beach_defence",
		"land_fort",
		"fortress",
		"anti_air",
		"radar_station",
		"industry",
		"heavy_industry",
		"steel_factory",
		"coal_mining",
		"sourcing_rares",
		"oil_well",
		"oil_refinery",
		"supplies_factory",
		"military_college",
		"#urbanisation",
		"research_lab",
		"hospital",
		"police_station",
		"infra",
		"rail_terminous",
		"nuclear_reactor",
		"rocket_test",
		"small_ship_shipyard",
		"medium_ship_shipyard",
		"capital_ship_shipyard",
		"submarine_shipyard",
		"smallarms_factory",
		"automotive_factory",
		"artillery_factory",
		"tank_factory",
		"light_aircraft_factory",
		"medium_aircraft_factory",
		"heavy_aircraft_factory",
		"underground",
		"desperate_defence",
		"weather_fort",
		"fake_air_base",
		"chromite_building",
		"aluminium_building",
		"rubber_building",
		"synthetic_rubber_building",
		"tungsten_building",
		"uranium_building",
		"gold_building",
		"nickel_building",
		"copper_building",
		"zinc_building",
		"manganese_building",
		"molybdenum_building",
		"graphite_nuclear_reactor",
		"heavy_water_nuclear_reactor"
	}

	for k, v in pairs(buildings) do
		buildingsData[v] = CBuildingDataBase.GetBuilding(v)
	end

	-- Iterate each country (using Cached TAGs)
	for k, v in pairs(GetCountryIterCacheDict()) do
		local countryTag = v
		local tag = k

		--Utils.LUA_DEBUGOUT("Building count Country " .. tag)
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
			country_current_count[tag] = {}
			country_cumulative_gain_count[tag] = {}
			country_cumulative_loss_count[tag] = {}
			local countryVars = countryTag:GetCountry():GetVariables()
			for i, z in pairs(buildings) do
				-- Current count
				country_current_count[tag][z] = countryVars:GetVariable(CString(z .. "_count")):Get()

				-- Cumulative gain
				country_cumulative_gain_count[tag][z] = countryVars:GetVariable(CString(z .. "_count_TECH")):Get()

				-- Cumulative loss
				country_cumulative_loss_count[tag][z] = countryVars:GetVariable(CString(z .. "_count_TECH_MALUS")):Get()
			end
		end
	end
	buildingsCountSetupNeeded = false
end

local buildingsCountCount = 0
function BuildingsCount()
	buildingsCountCount = buildingsCountCount + 1
	if buildingsCountSetupNeeded then
		buildingsCountSetup()
	end

	for k, v in pairs(GetCountryIterCacheDict()) do
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
				-- Utils.LUA_DEBUGOUT(tag .. " - " .. buildingtype .. " : " .. count)
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
				-- always on the 4th run because when we skipped the earlier iterations due to the inaccuracies we now have no variaton
				-- so just ignore that on the 4th and set the variables
				if variation ~= 0 or buildingsCountCount == 4 then
					-- Update local variables -- set to Variables later
					country_current_count[tag][buildingtype] = buildingcount
					country_cumulative_gain_count[tag][buildingtype] = cumulativeGainBuildings[buildingtype]
					country_cumulative_loss_count[tag][buildingtype] = cumulativeLoseBuildings[buildingtype]

					--Utils.LUA_DEBUGOUT("buildingcount " .. buildingtype .. " : " .. buildingcount)
					-- Set Variables
					-- Only after a few times because the values are wrong in the beginning
					if buildingsCountCount > 3 then
						--Count for Triggered Effect
						local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count"), CFixedPoint(buildingcount))
						CCurrentGameState.Post(command)
						--Count for bonus tech
						local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count_TECH"), CFixedPoint(cumulativeGainBuildings[buildingtype]))
						CCurrentGameState.Post(command)
						--Count for malus tech
						local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count_TECH_MALUS"), CFixedPoint(cumulativeLoseBuildings[buildingtype]))
						CCurrentGameState.Post(command)
					end
				end
			end
		end
	end
end

--Copy of BuildingsCount, only for the resource buildings since they get counted by controlled provinces not core
function ResourceCount()
	-- count daily for players only
	for i, playerTag in pairs(PlayerCountries) do
		local countryTag = CCountryDataBase.GetTag(playerTag)
		ResourceCountInner(countryTag, playerTag)
	end

	-- Exit early for AI countries, unless its the defined date
	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 0 and dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 15 and dayOfMonth ~= 16 and dayOfMonth ~= 17 and G_DateOverride ~= true then
		return
	end

	-- Iterate each country (using the Cached TAGs)
	for tag, countryTag in pairs(GetCountryIterCacheDict()) do
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---"  and (
		(
			((dayOfMonth == 0 or dayOfMonth == 15) and table.true_check(CountryListA, tag)) or
			((dayOfMonth == 1 or dayOfMonth == 16) and table.true_check(CountryListB, tag)) or
			((dayOfMonth == 2 or dayOfMonth == 17) and table.true_check(CountryListC, tag))
		) or G_DateOverride == true )
		then
			ResourceCountInner(countryTag, tag)
		end
	end
end

function ResourceCountInner(countryTag, tag)
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
			--Count for Triggered Effect
			local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count"), CFixedPoint(buildingcount))
			CCurrentGameState.Post(command)
			--Count for bonus tech
			local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count_TECH"), CFixedPoint(cumulativeGainBuildings[buildingtype]))
			CCurrentGameState.Post(command)
			--Count for malus tech
			local command = CSetVariableCommand(countryTag, CString(buildingtype .. "_count_TECH_MALUS"), CFixedPoint(cumulativeLoseBuildings[buildingtype]))
			CCurrentGameState.Post(command)
		end
	end
end

-- Uses the resource count and baseIC to set the variable which has the reduction due to IC demand baked in.
function StratResourceBalance()
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

	-- count daily for players only
	for i, playerTag in pairs(PlayerCountries) do
		local countryTag = CCountryDataBase.GetTag(playerTag)
		StratResourceBalanceInner(countryTag, playerTag, resourceBuildings)
	end

	-- Exit early for AI countries, unless its the defined date
	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 3 and dayOfMonth ~= 16 and dayOfMonth ~= 17 and dayOfMonth ~= 18 and G_DateOverride ~= true then
		return
	end

	for k, v in pairs(GetCountryIterCacheDict()) do
		local countryTag = v
		local tag = k

		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" and (
		(
			((dayOfMonth == 1 or dayOfMonth == 16) and table.true_check(CountryListA, tag)) or
			((dayOfMonth == 2 or dayOfMonth == 17) and table.true_check(CountryListB, tag)) or
			((dayOfMonth == 3 or dayOfMonth == 18) and table.true_check(CountryListC, tag))
		) or G_DateOverride == true)
		then
			StratResourceBalanceInner(countryTag, tag, resourceBuildings)
		end
	end
end

function StratResourceBalanceInner(countryTag, tag, resourceBuildings)
	-- Utils.LUA_DEBUGOUT("StratResourceBalance Country " .. tag)
	local BaseIC = countryTag:GetCountry():GetVariables():GetVariable(CString("BaseIC")):Get()
	-- Each resource building
	for k, building in pairs(resourceBuildings) do

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
		CCurrentGameState.Post(command)
	end
end

-- Calculates the actual bonus from the resources with sales and buys accounted
function RealStratResourceBalance()
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

	-- count daily for players only
	for i, playerTag in pairs(PlayerCountries) do
		local countryTag = CCountryDataBase.GetTag(playerTag)
		RealStratResourceBalanceInner(countryTag, playerTag, resources)
	end

	-- Exit early for AI countries, unless its the defined date
	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 1 and dayOfMonth ~= 6 and dayOfMonth ~= 11 and dayOfMonth ~= 16 and dayOfMonth ~= 21 and dayOfMonth ~= 26 and G_DateOverride ~= true then
		return
	end

	for tag, countryTag in pairs(GetCountryIterCacheDict()) do
		RealStratResourceBalanceInner(countryTag, tag, resources)
	end
end

function RealStratResourceBalanceInner(countryTag, tag, resources)
	-- Utils.LUA_DEBUGOUT("RealStratResourceBalance Country " .. tag)
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
			CCurrentGameState.Post(command)
			-- Set Variable for sell limit
			local command = CSetVariableCommand(countryTag, CString(resource .. "_MaxSells"), CFixedPoint(MaxSells))
			CCurrentGameState.Post(command)
		end
	end
end

function RandomNumberGenerator()

	-- Set a Variable to use in events to get a truly random experience.

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 0 and dayOfMonth ~= 1 and dayOfMonth ~= 2 and dayOfMonth ~= 15 and dayOfMonth ~= 16 and dayOfMonth ~= 17 then
		return
	end

	-- Iterate each country (using CDiplomacyStatus)
	for k, v in pairs(GetCountryIterCacheDict()) do
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
			CCurrentGameState.Post(command)
		end
	end

end

function PuppetMoneyAndFuelCheck(minister)

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 20 then
		return
	end

	for k, v in pairs(GetCountryIterCacheDict()) do
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

function ControlledMinesCheck()

	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 5 and dayOfMonth ~= 20 and G_DateOverride ~= true then
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
	for tag, countryTag in pairs(GetCountryIterCacheDict()) do
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
			CCurrentGameState.Post(command)
			end
		end
	end

end


-- Get and correct the IC and Reseach efficiency values
function CountryModifiers()

	-- local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	-- if dayOfMonth ~= 5 and dayOfMonth ~= 15 and dayOfMonth ~= 25 then
	-- 	return
	-- end
	local techModifierValues = Parsing.Techs.GetTechModifierValues()
	for tag, countryTag in pairs(GetCountryIterCacheDict()) do
		-- local countryTag = CCountryDataBase.GetTag(player)
		local country = countryTag:GetCountry()
		if country:Exists() == true then

			--- IC EFFICIENCY ---
			local icEffraw = country:GetGlobalModifier():GetValue(CModifier._MODIFIER_INDUSTRIAL_EFFICIENCY_):Get()
			-- Utils.LUA_DEBUGOUT(player)
			-- Utils.LUA_DEBUGOUT("icEffraw: " .. icEffraw)
			for tech, effect in pairs(techModifierValues["ic_efficiency"]) do
				local level = country:GetTechnologyStatus():GetLevel(CTechnologyDataBase.GetTechnology(tech))
				icEffraw = icEffraw + (effect*level)
				-- Utils.LUA_DEBUGOUT(tech .. ":\n    Level: " .. level .. "\n    Effect:" .. (effect*level*100))
			end
			local icEffclean = Utils.RoundDecimal(icEffraw, 3) * 100
			local command = CSetVariableCommand(countryTag, CString("IcEffVariable"), CFixedPoint(icEffclean))
			CCurrentGameState.Post(command)

			--- RESEARCH EFFICIENCY ---
			local resEffraw = country:GetGlobalModifier():GetValue(CModifier._MODIFIER_RESEARCH_EFFICIENCY_):Get()
			-- Utils.LUA_DEBUGOUT(player)
			-- Utils.LUA_DEBUGOUT("resEffraw: " .. resEffraw)
			for tech, effect in pairs(techModifierValues["research_efficiency"]) do
				local level = country:GetTechnologyStatus():GetLevel(CTechnologyDataBase.GetTechnology(tech))
				resEffraw = resEffraw + (effect*level)
				-- Utils.LUA_DEBUGOUT(tech .. ":\n    Level: " .. level .. "\n    Effect:" .. (effect*level*100))
			end
			local resEffclean = Utils.RoundDecimal(resEffraw, 3) * 100
			local command = CSetVariableCommand(countryTag, CString("ResEffVariable"), CFixedPoint(resEffclean))
			CCurrentGameState.Post(command)

			--- SUPPLY THROUGHPUT ---
			local suppthrouRaw = country:GetGlobalModifier():GetValue(CModifier._MODIFIER_SUPPLY_THROUGHPUT_):Get()
			-- Utils.LUA_DEBUGOUT(player)
			-- Utils.LUA_DEBUGOUT("supplythrouRaw: " .. supplythrouRaw)
			for tech, effect in pairs(techModifierValues["supply_throughput"]) do
				local level = country:GetTechnologyStatus():GetLevel(CTechnologyDataBase.GetTechnology(tech))
				suppthrouRaw = suppthrouRaw + (effect*level)
				-- Utils.LUA_DEBUGOUT(tech .. ":\n    Level: " .. level .. "\n    Effect:" .. (effect*level*100))
			end
			local suppthrouClean = Utils.RoundDecimal(suppthrouRaw, 3) * 100
			local command = CSetVariableCommand(countryTag, CString("SuppThrouVariable"), CFixedPoint(suppthrouClean))
			CCurrentGameState.Post(command)
		end
	end

end


function ICDaysSpentCalculation()
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
				CCurrentGameState.Post(command)
				investmentMult = 20
			end

			if icDaysSpent > 0 then
				local reductionValue = Utils.Round((baseIC * investmentMult) / 100)
				icDaysSpent = icDaysSpent - reductionValue

				local command = CSetVariableCommand(playerTag, CString("IC_days_spent"), CFixedPoint(icDaysSpent))
				CCurrentGameState.Post(command)

				if player == G_PlayerCountry then
					SetCurrentDailyICDaysReductionText(reductionValue)
				end
			end
		end
	end
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
function CalculateFocuses()
	local date = CCurrentGameState.GetCurrentDate()
	-- local dayOfMonth = date:GetDayOfMonth()

	-- if dayOfMonth % 3 ~= 0 then
	-- 	return
	-- end

	local currentDate = date:GetTotalDays()
	local omgTag = CCountryDataBase.GetTag("OMG")
	local lastDate = omgTag:GetCountry():GetVariables():GetVariable(CString("last_focus_count_day")):Get()
	-- Very first iteration has lastDate == 0
	if lastDate == 0 then
		lastDate = currentDate
	end
	local command = CSetVariableCommand(omgTag, CString("last_focus_count_day"), CFixedPoint(currentDate))
	CCurrentGameState.Post(command)

	local focuses = {
		"ground_forces",
		"air_force",
		"navy",
		"economy",
		"science",
		"health_and_education",
		"natural_resources"
	}

	for k, countryTag in pairs(GetCountryIterCacheDict()) do
		local playerCountry = countryTag:GetCountry()
		local variables = playerCountry:GetVariables()
		local activeFocus = variables:GetVariable(CString("national_focus")):Get()
		for focusIndex, focus in pairs(focuses) do
			local daysActive = variables:GetVariable(CString(focus .. "_national_focus_days_active")):Get()
			if focusIndex == activeFocus then
				daysActive = daysActive + (currentDate - lastDate)
			else
				if daysActive > 0 then
					daysActive = daysActive - (currentDate - lastDate)
				elseif daysActive < 0 then
					daysActive = 0
				end
			end
			daysActive = Utils.Round(daysActive)
			local command = CSetVariableCommand(countryTag, CString(focus .. "_national_focus_days_active"), CFixedPoint(daysActive))
			CCurrentGameState.Post(command)
		end
	end
end

MinisterListFilled = false
MinisterTypes = {}
function CalculateMinisters()
	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 2 and  dayOfMonth ~= 7 and dayOfMonth ~= 12 and dayOfMonth ~= 17 and dayOfMonth ~= 22 and dayOfMonth ~= 27 then
		return
	end
	if MinisterListFilled ~= true then
		for CMinister in CMinisterTypeDataBase.GetMinisterTypeList() do
			table.insert(MinisterTypes, tostring(CMinister:GetKey()))
			MinisterListFilled = true
		end
	end

	for tag, countryTag in pairs(GetCountryIterCacheDict()) do
		local country = countryTag:GetCountry()
		local cVariables = country:GetVariables()
		local previousMinisters = {}
		local removedMinisters = {}
		local currentMinisters = {}
		local ministersAdded = 0


		if country:Exists() == true then
			-- Get current ingame ministers
			local x = 0
			for curMinister in country:GetMinisters() do
				if x ~= 0 then -- "0th" minister is always noMinisterType / 0th minister does not exist ingame, it starts at 1 with Head of Government
					local curMinisterType = tostring(curMinister:GetPersonality(CGovernmentPositionDataBase.GetGovernmentPositionByIndex(x)):GetKey())
					table.insert(currentMinisters, curMinisterType .. "_minister_" .. x)
					-- Utils.LUA_DEBUGOUT(tag .. " - Added - " .. curMinisterType .. "_minister_" .. x)
				end
				x = x + 1
			end
			-- Get already set ministers
			-- First check if the current ministers are in position because they will most likely still be (Fast!)
			for i, ministerType in pairs(currentMinisters) do
				-- No need to continue checking for potential ministers in the variables if we already have 11 counted
				if ministersAdded == 11 then
					break
				end
				if cVariables:GetVariable(CString(ministerType)):Get() == 1 then
					ministersAdded = ministersAdded + 1
					table.insert(previousMinisters, ministerType)
					-- Utils.LUA_DEBUGOUT(tag .. " - Inserted into previousMinisters: " .. ministerType)
				end
			end

			-- Then if we didnt find all ministers, meaning one was replaced, check against the list of all ministertypes (Slow!)
			for i, ministerType in pairs(MinisterTypes) do
				-- No need to continue checking for potential ministers in the variables if we already have 11 counted
				if ministersAdded == 11 then
					break
				end
				for y = 1, 11, 1 do
					if cVariables:GetVariable(CString(ministerType .. "_minister_" .. y)):Get() == 1 then
						-- Do not insert a minister again if it was already found by the first faster search and thus is currently still in place
						if table.getIndex(previousMinisters, ministerType .. "_minister_" .. y) == nil then
							ministersAdded = ministersAdded + 1
							table.insert(removedMinisters, ministerType .. "_minister_" .. y)
							-- Utils.LUA_DEBUGOUT(tag .. " - Inserted into removedMinisters: " .. ministerType .. "_minister_" .. y)
							break
						end
					end
				end
			end
			-- check if the currentMinisters were already set to variables by comparing with the previousMinisters list
			-- only set set variables if they have not been set yet
			for i, currentMinister in pairs(currentMinisters) do
				local ministerAlreadySet = false
				for j, previousMinister in pairs(previousMinisters) do
					if previousMinister == currentMinister then
						-- Utils.LUA_DEBUGOUT("Previous: " .. previousMinister .. " - Current: " .. currentMinister)
						ministerAlreadySet = true
						break
					end
				end
				-- No need to set the variable again
				if ministerAlreadySet == false then
					-- Utils.LUA_DEBUGOUT(tag .. " - Setting: " .. currentMinister)
					local command = CSetVariableCommand(countryTag, CString(currentMinister), CFixedPoint(1))
					CCurrentGameState.Post(command)
				end
			end
			-- Remove the variable for the ministers remaining in removedMinisters
			for i, removedMinister in pairs(removedMinisters) do
				-- Utils.LUA_DEBUGOUT(tag .. " - Removing: " .. removedMinister)
				local command = CSetVariableCommand(countryTag, CString(removedMinister), CFixedPoint(0))
				CCurrentGameState.Post(command)
			end
		end
	end
end

GlobalTradesData = {}
InitTradingDataDone = false
function InitTradingData()
	if InitTradingDataDone then
		return
	end

	for k, v in pairs(GetCountryIterCacheDict()) do
		local countryTag = v
		local tag = k
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
			local totalTrades = countryTag:GetCountry():GetVariables():GetVariable(CString("zDsafe_totalTrades")):Get()
			local activeTrades = countryTag:GetCountry():GetVariables():GetVariable(CString("zDsafe_activeTrades")):Get()
			GlobalTradesData[tag] = {
				["totalTrades"] = totalTrades;
				["activeTrades"] = activeTrades;
				["trades"] = {};
			}
			if activeTrades then
				for i = totalTrades - (activeTrades - 1), totalTrades do
					local buyer = countryTag:GetCountry():GetVariables():GetVariable(CString("zDsafe_trade_" .. i .. "_buyer")):Get()
					local seller = countryTag:GetCountry():GetVariables():GetVariable(CString("zDsafe_trade_" .. i .. "_seller")):Get()
					local resource = countryTag:GetCountry():GetVariables():GetVariable(CString("zDsafe_trade_" .. i .. "_resource")):Get()
					local expiryDate = countryTag:GetCountry():GetVariables():GetVariable(CString("zDsafe_trade_" .. i .. "_expiryDate")):Get()
					GlobalTradesData[tag]["trades"]["trade_"..i] = {
						["buyer"] = G_CountryListAll[buyer];
						["seller"] = G_CountryListAll[seller];
						["resource"] = G_StratResourceListGlobal[resource];
						["expiryDate"] = expiryDate;
					}
				end
			end
		end
	end
	-- Utils.LUA_DEBUGOUT("Init GlobalTradesData")
	-- Utils.INSPECT_TABLE(GlobalTradesData)
	InitTradingDataDone = true
end

function CheckPendingTrades()
	-- local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	-- if dayOfMonth % 4 ~= 0 then -- every 4 days
	-- 	return
	-- end

	for k, v in pairs(GetCountryIterCacheDict()) do
		local countryTag = v
		local tag = k

		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
			local wantsToBuyFromIndex = countryTag:GetCountry():GetVariables():GetVariable(CString("pending_trade_wants_to_buy_from")):Get()
			if wantsToBuyFromIndex ~= 0 then
				-- the country is saved as a number which is the index in the "CountryListAll" global list
				local wantsToBuyFromTag = G_CountryListAll[wantsToBuyFromIndex]
				-- same for the resource
				local tradedResourceIndex = countryTag:GetCountry():GetVariables():GetVariable(CString("pending_trade_wants_to_buy_resource")):Get()
				if tradedResourceIndex ~= 0 then
					-- reset the trigger variables
					local command = CSetVariableCommand(countryTag, CString("pending_trade_wants_to_buy_from"), CFixedPoint(0))
					CCurrentGameState.Post(command)
					local command = CSetVariableCommand(countryTag, CString("pending_trade_wants_to_buy_resource"), CFixedPoint(0))
					CCurrentGameState.Post(command)
					-- insert the trades into the GlobalTradesData and set the country variables
					-- Utils.LUA_DEBUGOUT("HandlePendingTrade: " .. tag .. " - " .. wantsToBuyFromTag .. " - " .. tradedResourceIndex)
					HandlePendingTrade(tag, wantsToBuyFromTag, tradedResourceIndex)
				end
			end
		end
	end
end

-- creates the trade entry for the GlobalTradesData map, sets the variables associated with the map and sets the variables for the ingame effect
function HandlePendingTrade(buyerTag, sellerTag, resourceIndex)
	local buyerCountryTag = CCountryDataBase.GetTag(buyerTag)
	local sellerCountryTag = CCountryDataBase.GetTag(sellerTag)

	-- increase counters
	GlobalTradesData[buyerTag]["totalTrades"] = GlobalTradesData[buyerTag]["totalTrades"] + 1
	GlobalTradesData[buyerTag]["activeTrades"] = GlobalTradesData[buyerTag]["activeTrades"] + 1
	local command = CSetVariableCommand(buyerCountryTag, CString("zDsafe_totalTrades"), CFixedPoint(GlobalTradesData[buyerTag]["totalTrades"]))
	CCurrentGameState.Post(command)
	local command = CSetVariableCommand(buyerCountryTag, CString("zDsafe_activeTrades"), CFixedPoint(GlobalTradesData[buyerTag]["activeTrades"]))
	CCurrentGameState.Post(command)

	-- fill the map
	local expiryDate = CCurrentGameState.GetCurrentDate():GetTotalDays() + 365
	local thisTradeNumber = GlobalTradesData[buyerTag]["totalTrades"]
	GlobalTradesData[buyerTag]["trades"]["trade_" .. thisTradeNumber] = {
		["buyer"] = buyerTag;
		["seller"] = sellerTag;
		["resource"] = G_StratResourceListGlobal[resourceIndex];
		["expiryDate"] = expiryDate;
	}

	-- set the variables needed to recreate the map
	local command = CSetVariableCommand(buyerCountryTag, CString("zDsafe_trade_" .. thisTradeNumber .. "_buyer"), CFixedPoint(table.getIndex(G_CountryListAll, buyerTag)))
	CCurrentGameState.Post(command)
	local command = CSetVariableCommand(buyerCountryTag, CString("zDsafe_trade_" .. thisTradeNumber .. "_seller"), CFixedPoint(table.getIndex(G_CountryListAll, sellerTag)))
	CCurrentGameState.Post(command)
	local command = CSetVariableCommand(buyerCountryTag, CString("zDsafe_trade_" .. thisTradeNumber .. "_resource"), CFixedPoint(resourceIndex))
	CCurrentGameState.Post(command)
	local command = CSetVariableCommand(buyerCountryTag, CString("zDsafe_trade_" .. thisTradeNumber .. "_expiryDate"), CFixedPoint(expiryDate))
	CCurrentGameState.Post(command)

	-- increment the variables for the strategic effects
	-- buyer
	local buyerVariableString = CString(G_StratResourceListGlobal[resourceIndex] .. "_trade_buy")
	local buyerCurrentBuys = buyerCountryTag:GetCountry():GetVariables():GetVariable(buyerVariableString):Get()
	local command = CSetVariableCommand(buyerCountryTag, buyerVariableString, CFixedPoint(buyerCurrentBuys + 1))
	CCurrentGameState.Post(command)
	-- seller
	local sellerVariableString = CString(G_StratResourceListGlobal[resourceIndex] .. "_trade_sell")
	local sellerCurrentSells = sellerCountryTag:GetCountry():GetVariables():GetVariable(sellerVariableString):Get()
	local command = CSetVariableCommand(sellerCountryTag, sellerVariableString, CFixedPoint(sellerCurrentSells + 1))
	CCurrentGameState.Post(command)
end

function CheckExpiredTrades()
	-- local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	-- if dayOfMonth % 5 ~= 0 then -- every 5 days
	-- 	return
	-- end

	-- Utils.LUA_DEBUGOUT("GlobalTradesData before CheckExpiredTrades")
	-- Utils.INSPECT_TABLE(GlobalTradesData)

	local currentDate = CCurrentGameState.GetCurrentDate():GetTotalDays()
	for tag, countryTag in pairs(GetCountryIterCacheDict()) do
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" and next(GlobalTradesData[tag]["trades"]) ~= nil then
			-- Utils.LUA_DEBUGOUT("Checking: " .. tag)
			for tradeName, trade in pairs(GlobalTradesData[tag]["trades"]) do
				-- Utils.LUA_DEBUGOUT("tradeName: " .. tradeName)
				-- Utils.INSPECT_TABLE(trade)

				-- God knows why but sometimes a trade entry exists with ONLY the expiryDate and nothing else, and that date is 0
				-- so lets just delete the memory of that trade ever existing (actually just decrement the active trade counter and delete by key again)
				if trade["expiryDate"] == 0 then
					-- Utils.LUA_DEBUGOUT("REMOVING 0 DATE TRADE")
					table.removeEntryByKey(GlobalTradesData[tag]["trades"], tradeName)
					-- decrement trade counter
					GlobalTradesData[tag]["activeTrades"] = GlobalTradesData[tag]["activeTrades"] - 1
					local command = CSetVariableCommand(countryTag, CString("zDsafe_activeTrades"), CFixedPoint(GlobalTradesData[tag]["activeTrades"]))
					CCurrentGameState.Post(command)
				elseif trade["expiryDate"] < currentDate then
					-- Utils.LUA_DEBUGOUT("GlobalTradesData pre removal")
					-- Utils.INSPECT_TABLE(GlobalTradesData[tag])
					local buyerCountryTag = CCountryDataBase.GetTag(trade["buyer"])
					local sellerCountryTag = CCountryDataBase.GetTag(trade["seller"])
					local resource = trade["resource"]
					-- remove the entry from the GlobalTradesData
					table.removeEntryByKey(GlobalTradesData[tag]["trades"], tradeName)
					-- remove expired trade variables
					local tradeIndex = tradeName:match "%d+"
					local command = CSetVariableCommand(countryTag, CString("zDsafe_trade_" .. tradeIndex .. "_buyer"), CFixedPoint(0))
					CCurrentGameState.Post(command)
					local command = CSetVariableCommand(countryTag, CString("zDsafe_trade_" .. tradeIndex .. "_seller"), CFixedPoint(0))
					CCurrentGameState.Post(command)
					local command = CSetVariableCommand(countryTag, CString("zDsafe_trade_" .. tradeIndex .. "_resource"), CFixedPoint(0))
					CCurrentGameState.Post(command)
					local command = CSetVariableCommand(countryTag, CString("zDsafe_trade_" .. tradeIndex .. "_expiryDate"), CFixedPoint(0))
					CCurrentGameState.Post(command)
					-- decrement trade counter
					GlobalTradesData[tag]["activeTrades"] = GlobalTradesData[tag]["activeTrades"] - 1
					local command = CSetVariableCommand(countryTag, CString("zDsafe_activeTrades"), CFixedPoint(GlobalTradesData[tag]["activeTrades"]))
					CCurrentGameState.Post(command)
					-- decrement the variables for the strategic effects
					-- buyer
					local buyerVariableString = CString(resource .. "_trade_buy")
					local buyerCurrentBuys = buyerCountryTag:GetCountry():GetVariables():GetVariable(buyerVariableString):Get()
					if buyerCurrentBuys <= 0 then
						buyerCurrentBuys = 1	-- stop the values from going into the negatives if the game has miscounted at some point
					end
					local command = CSetVariableCommand(buyerCountryTag, buyerVariableString, CFixedPoint(buyerCurrentBuys - 1))
					CCurrentGameState.Post(command)
					-- seller
					local sellerVariableString = CString(resource .. "_trade_sell")
					local sellerCurrentSells = sellerCountryTag:GetCountry():GetVariables():GetVariable(sellerVariableString):Get()
					if sellerCurrentSells <= 0 then
						sellerCurrentSells = 1	-- stop the values from going into the negatives if the game has miscounted at some point
					end
					local command = CSetVariableCommand(sellerCountryTag, sellerVariableString, CFixedPoint(sellerCurrentSells - 1))
					CCurrentGameState.Post(command)
					-- Utils.LUA_DEBUGOUT("GlobalTradesData post removal")
					-- Utils.INSPECT_TABLE(GlobalTradesData[tag])
				end
			end
		end
	end
end

function CheckNegativeTradeCounts()
	local dayOfMonth = CCurrentGameState.GetCurrentDate():GetDayOfMonth()
	if dayOfMonth ~= 11 then
		return
	end

	local resources = {
		"chromite";
		"aluminium";
		"rubber";
		"tungsten";
		"nickel";
		"copper";
		"zinc";
		"manganese";
		"molybdenum"
	}

	for tag, countryTag in pairs(GetCountryIterCacheDict()) do
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
			for i, resource in pairs(resources) do
				local buysString = CString(resource .. "_trade_buy")
				local currentBuys = countryTag:GetCountry():GetVariables():GetVariable(buysString):Get()
				if currentBuys < 0 then
					local command = CSetVariableCommand(countryTag, buysString, CFixedPoint(0))
					CCurrentGameState.Post(command)
				end
				local salesString = CString(resource .. "_trade_sell")
				local currentSells = countryTag:GetCountry():GetVariables():GetVariable(salesString):Get()
				if currentSells < 0 then
					local command = CSetVariableCommand(countryTag, salesString, CFixedPoint(0))
					CCurrentGameState.Post(command)
				end
			end
		end
	end
end
