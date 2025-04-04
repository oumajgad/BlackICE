
--Reference for the index numbers of laws
--
local _OPEN_SOCIETY_ = 1
local _LIMITED_RESTRICTIONS_ = 2
local _LEGALISTIC_RESTRICIONS_ = 3
local _REPRESSION_ = 4
local _TOTALITARIAN_SYSTEM_ = 5

local _VOLUNTEER_ARMY_ = 6
local _ONE_YEAR_DRAFT_ = 7
local _TWO_YEAR_DRAFT_ = 8
local _THREE_YEAR_DRAFT_ = 9
local _SERVICE_BY_REQUIREMENT_ = 10

local _FULL_CIVILIAN_ECONOMY_ = 11
local _BASIC_MOBILISATION_ = 12
local _FULL_MOBILISATION_ = 13
local _WAR_ECONOMY_ = 14
local _TOTAL_ECONOMIC_MOBILISATION_ = 15

local _MINIMAL_EDUCATION_INVESTMENT_ = 16
local _AVERAGE_EDUCATION_INVESTMENT_ = 17
local _MEDIUM_LARGE_EDUCATION_INVESTMENT_ = 18
local _BIG_EDUCATION_INVESTMENT_ = 19
--
local _CONSUMER_PRODUCT_ORIENTATION_ = 20
local _MIXED_INDUSTRY_ = 21
local _HEAVY_INDUSTRY_EMPHASIS_ = 22

local _FREE_PRESS_ = 23
local _CENSORED_PRESS_ = 24
local _STATE_PRESS_ = 25
local _PROPAGANDA_PRESS_ = 26

local _MINIMAL_TRAINING_ = 27
local _BASIC_TRAINING_ = 28
local _ADVANCED_TRAINING_ = 29
local _SPECIALIST_TRAINING_ = 30

local volunteer_recruitment = 31
local standard_conscription = 32
local extended_conscription = 33
local massive_conscription = 34
local emergency_conscription = 35

local _HEAD_OF_STATE_ = 1
local _HEAD_OF_GOVERNMENT_ = 2
local _FOREIGN_MINISTER_ = 3
local _ARMAMENT_MINISTER_ = 4
local _MINISTER_OF_SECURITY_ = 5
local _MINISTER_OF_SCIENCE_ = 6
local _MINISTER_OF_INTELLIGENCE_ = 7
local _CHIEF_OF_STAFF_ = 8
local _CHIEF_OF_ARMY_ = 9
local _CHIEF_OF_NAVY_ = 10
local _CHIEF_OF_AIR_ = 11

--Default Land Training
local defaultLandTraining = {}
defaultLandTraining["CGX"] = 27
defaultLandTraining["CHC"] = 27
defaultLandTraining["CHI"] = 27
defaultLandTraining["CSX"] = 27
defaultLandTraining["CXB"] = 27
defaultLandTraining["CYN"] = 27
defaultLandTraining["ETH"] = 27
defaultLandTraining["GEO"] = 27
defaultLandTraining["LIB"] = 27
defaultLandTraining["MAD"] = 27
defaultLandTraining["MON"] = 27
defaultLandTraining["NJG"] = 27
defaultLandTraining["PRK"] = 27
defaultLandTraining["SIK"] = 27
defaultLandTraining["SOM"] = 27
defaultLandTraining["SUD"] = 27
defaultLandTraining["SUR"] = 27
defaultLandTraining["TAN"] = 27
defaultLandTraining["TIB"] = 27
defaultLandTraining["TIM"] = 27
defaultLandTraining["AFG"] = 28
defaultLandTraining["ALB"] = 28
defaultLandTraining["ARM"] = 28
defaultLandTraining["BHU"] = 28
defaultLandTraining["BLR"] = 28
defaultLandTraining["COS"] = 28
defaultLandTraining["CRO"] = 28
defaultLandTraining["CUB"] = 28
defaultLandTraining["CYP"] = 28
defaultLandTraining["DOM"] = 28
defaultLandTraining["ECU"] = 28
defaultLandTraining["EST"] = 28
defaultLandTraining["GRE"] = 28
defaultLandTraining["GUA"] = 28
defaultLandTraining["GUY"] = 28
defaultLandTraining["HON"] = 28
defaultLandTraining["IDC"] = 28
defaultLandTraining["ITA"] = 28
defaultLandTraining["JOR"] = 28
defaultLandTraining["KOR"] = 28
defaultLandTraining["KWT"] = 28
defaultLandTraining["LAT"] = 28
defaultLandTraining["LEB"] = 28
defaultLandTraining["LIT"] = 28
defaultLandTraining["MEX"] = 28
defaultLandTraining["MTN"] = 28
defaultLandTraining["NIC"] = 28
defaultLandTraining["OMN"] = 28
defaultLandTraining["PAK"] = 28
defaultLandTraining["PAL"] = 28
defaultLandTraining["PAN"] = 28
defaultLandTraining["PAP"] = 28
defaultLandTraining["PAR"] = 28
defaultLandTraining["PER"] = 28
defaultLandTraining["PHI"] = 28
defaultLandTraining["POL"] = 28
defaultLandTraining["PRU"] = 28
defaultLandTraining["RSI"] = 28
defaultLandTraining["RUR"] = 28
defaultLandTraining["SAL"] = 28
defaultLandTraining["SAU"] = 28
defaultLandTraining["SER"] = 28
defaultLandTraining["SIA"] = 28
defaultLandTraining["SLV"] = 28
defaultLandTraining["SOV"] = 28
defaultLandTraining["SPR"] = 28
defaultLandTraining["SYR"] = 28
defaultLandTraining["UKR"] = 28
defaultLandTraining["YEM"] = 28
defaultLandTraining["YUG"] = 28
defaultLandTraining["ARG"] = 29
defaultLandTraining["AST"] = 29
defaultLandTraining["AUS"] = 29
defaultLandTraining["BBU"] = 29
defaultLandTraining["BEL"] = 29
defaultLandTraining["BIN"] = 29
defaultLandTraining["BOL"] = 29
defaultLandTraining["BRA"] = 29
defaultLandTraining["BUL"] = 29
defaultLandTraining["CAN"] = 29
defaultLandTraining["CHL"] = 29
defaultLandTraining["COL"] = 29
defaultLandTraining["CZE"] = 29
defaultLandTraining["DEN"] = 29
defaultLandTraining["FRA"] = 29
defaultLandTraining["HOL"] = 29
defaultLandTraining["HUN"] = 29
defaultLandTraining["ICL"] = 29
defaultLandTraining["IND"] = 29
defaultLandTraining["INO"] = 29
defaultLandTraining["IRE"] = 29
defaultLandTraining["IRQ"] = 29
defaultLandTraining["ISR"] = 29
defaultLandTraining["ITA"] = 29
defaultLandTraining["LUX"] = 29
defaultLandTraining["MAN"] = 29
defaultLandTraining["MEN"] = 29
defaultLandTraining["MTA"] = 29
defaultLandTraining["NOR"] = 29
defaultLandTraining["NZL"] = 29
defaultLandTraining["POR"] = 29
defaultLandTraining["RKK"] = 29
defaultLandTraining["RKM"] = 29
defaultLandTraining["RKO"] = 29
defaultLandTraining["RKU"] = 29
defaultLandTraining["ROM"] = 29
defaultLandTraining["SAF"] = 29
defaultLandTraining["SLO"] = 29
defaultLandTraining["SPA"] = 29
defaultLandTraining["TUR"] = 29
defaultLandTraining["URU"] = 29
defaultLandTraining["VEN"] = 29
defaultLandTraining["VIC"] = 29
defaultLandTraining["DDR"] = 30
defaultLandTraining["DFR"] = 30
defaultLandTraining["ENG"] = 30
defaultLandTraining["FIN"] = 30
defaultLandTraining["GER"] = 30
defaultLandTraining["JAP"] = 30
defaultLandTraining["NEP"] = 30
defaultLandTraining["SCH"] = 30
defaultLandTraining["SWE"] = 30
defaultLandTraining["USA"] = 30


-- ##################################
-- # Called by the EXE
-- ##################################
-- # Happens around 17:00 each day
-- ##################################
function PoliticsMinister_Tick(minister)

	local isOMG = false
	if tostring(minister:GetCountryTag()) == "OMG" then
		isOMG = true
	end

	local t = nil
	if benchmarkLUA then
		t = os.clock()
	end

	if isOMG then
		OMGMinisterHandler("PoliticsMinister_Tick", minister)
	end

    if math.mod( CCurrentGameState.GetAIRand(), 7) == 0 then
		Mobilization(minister)
	end

	if benchmarkLUA then
		Utils.addTime("Mobilization", os.clock() - t, isOMG)
		t = os.clock()
	end

	if math.mod( CCurrentGameState.GetAIRand(), 10) == 0 then
		Laws(minister)
	end

	if benchmarkLUA then
		Utils.addTime("Laws", os.clock() - t, isOMG)
		t = os.clock()
	end

	if math.mod( CCurrentGameState.GetAIRand(), 11) == 0 then
		OfficeManagement(minister)
	end

	if benchmarkLUA then
		Utils.addTime("Office", os.clock() - t, isOMG)
		t = os.clock()
	end

	if math.mod( CCurrentGameState.GetAIRand(), 12) == 0 then
		local ministerTag = minister:GetCountryTag()
		local ministerCountry = ministerTag:GetCountry()

		Puppets(minister, ministerTag, ministerCountry)
		Liberation(minister:GetOwnerAI(), minister, ministerTag, ministerCountry)
	end

	if benchmarkLUA then
		Utils.addTime("Puppets/Liberation", os.clock() - t, isOMG)
		t = os.clock()
	end
end

function Liberation(ai, minister, ministerTag, ministerCountry)

	-- VIC dont liberate
	if tostring(ministerTag) == "VIC" then
		return
	end
	if tostring(ministerTag) == "GER" then
		return
	end

	-- liberate countries if we can
	if ministerCountry:MayLiberateCountries() then
		for loMember in ministerCountry:GetPossibleLiberations() do
			if tostring(ministerTag) == "SOV" and tostring(loMember) == "FIN" then
				return
			end
			if minister:IsCapitalSafeToLiberate(loMember) then
				ai:Post(CLiberateCountryCommand(loMember, ministerTag))
			end
		end
	end

end
function Mobilization(minister)
	local ministerTag =  minister:GetCountryTag()
	local ministerCountry = ministerTag:GetCountry()

	-- Performance check
	if not(ministerCountry:IsMobilized()) then
		local ai = minister:GetOwnerAI()
		local loStrategy = ministerCountry:GetStrategy()

		-- If the country is part of a faction
		if ministerCountry:HasFaction() then
			local loFaction = ministerCountry:GetFaction()

			-- Faction leader is atwar so mobilize
			if loFaction:GetFactionLeader():GetCountry():IsAtWar() then
				ai:Post(CToggleMobilizationCommand(ministerTag, true))
				return
			end
		end

		-- Note: we are automatically mobilized when war breaks out, so this is for kicking off mobilization early.
		if loStrategy:IsPreparingWar() then
			local liNeutrality = ministerCountry:GetNeutrality():Get() * 0.9

			for loCountry in CCurrentGameState.GetCountries() do
				local loCountryTag = loCountry:GetCountryTag()

				if not(loCountryTag == ministerTag) then
					if loCountryTag:IsValid() and loCountry:Exists() and loCountryTag:IsReal() then
						if loStrategy:IsPreparingWarWith(loCountryTag) and liNeutrality < ministerCountry:GetMaxNeutralityForWarWith(loCountryTag):Get() then
							ai:Post(CToggleMobilizationCommand(ministerTag, true))
							break
						end
					end
				end
			end
		else
			if Utils.HasCountryAIFunction( ministerTag, "HandleMobilization") then
				Utils.CallCountryAI(ministerTag, "HandleMobilization", minister)
			else
				-- check if a neighbor is starting to look threatening
				local liTotalIC = ministerCountry:GetTotalIC()
				local liNeutrality = ministerCountry:GetNeutrality():Get() * 0.9

				for loCountryTag in ministerCountry:GetNeighbours() do
					local liThreat = ministerCountry:GetRelation(loCountryTag):GetThreat():Get()

					if (liNeutrality - liThreat) < 10 then
						local loCountry = loCountryTag:GetCountry()

						liThreat = liThreat * CalculateAlignmentFactor(ai, ministerCountry, loCountry)

						if liTotalIC > 50 and loCountry:GetTotalIC() < liTotalIC then
							liThreat = liThreat / 2 -- we can handle them if they descide to attack anyway
						end

						if liThreat > 30 then
							if CalculateWarDesirability(ai, loCountry, ministerTag) > 70 then
								ai:Post(CToggleMobilizationCommand(ministerTag, true))
							end
						end
					end
				end
			end
		end
	end
end
function Puppets(minister, ministerTag, ministerCountry)
	-- Puppets are country specific AI countries will not release them automatically and must be scripted
    if ministerCountry:CanCreatePuppet() then
        Utils.CallCountryAI( ministerTag, "HandlePuppets", minister )
    end
end
function Laws(minister)
	local ministerTag = minister:GetCountryTag()
	local ministerCountry = ministerTag:GetCountry()

	for loGroup in CLawDataBase.GetGroups() do
		local loGroupName = tostring(loGroup:GetKey())
		local loNewLaw = nil
		local loCurrentLaw = ministerCountry:GetLaw(loGroup)
		local lsMethodCall = "CallLaw_" .. loGroupName

		if Utils.HasCountryAIFunction(ministerTag, lsMethodCall) then
			loNewLaw = Utils.CallCountryAI(ministerTag, lsMethodCall, minister, loCurrentLaw)

		elseif (loGroupName == "civil_law") then
			loNewLaw = CivilLaw(ministerTag, ministerCountry, loCurrentLaw)

		elseif (loGroupName == "conscription_law") then
			loNewLaw = ConscriptionLaw(ministerTag, ministerCountry, loCurrentLaw)

		elseif loGroupName == "economic_law" then
			loNewLaw = EconomicLaw(ministerTag, ministerCountry, loCurrentLaw)

		elseif loGroupName == "education_investment_law" then
			loNewLaw = EducationInvestment(ministerTag, ministerCountry, loCurrentLaw)

		elseif loGroupName == "industrial_policy_laws" then
			loNewLaw = IndustrialPolicies(ministerTag, ministerCountry, loCurrentLaw)

		elseif loGroupName == "press_laws" then
			loNewLaw = PressLaws(ministerTag, ministerCountry, loCurrentLaw)

		elseif loGroupName == "training_laws" then
			loNewLaw = TrainingLaws(ministerTag, ministerCountry, loCurrentLaw)

		elseif loGroupName == "conscription_law_two" then
			loNewLaw = ConscriptionLaws2(ministerTag, ministerCountry, loCurrentLaw)

		-- Unknown Law so just increase it by 1
		else
			-- Try to increase by 1 if the group is different do not do anything!
			local liLawIndex = loCurrentLaw:GetIndex() + 1
			if liLawIndex < CLawDataBase.GetNumberOfLaws() then
				loNewLaw = CLawDataBase.GetLaw(liLawIndex)
				if not (loGroup:GetIndex() == loNewLaw:GetGroup():GetIndex()) then
					loNewLaw = nil
				end
			end
		end

		-- Execute the new law
		if not(loNewLaw == nil) then
			if not(loNewLaw:GetIndex() == loCurrentLaw:GetIndex()) then
				if loNewLaw:ValidFor(ministerTag) then
					local loCommand = CChangeLawCommand(ministerTag, loNewLaw, loGroup)
					loCommand:SetEnablePostMessage(true)
					CCurrentGameState.Post(loCommand)
				end
			end
		end
	end
end

function OfficeManagement(minister)
	local ai = minister:GetOwnerAI()
	local ministerTag = minister:GetCountryTag()
	local ministerCountry = ministerTag:GetCountry()
	local loGroup = ministerCountry:GetRulingIdeology():GetGroup()

	-- Positions definitions
	-- Each position has an index, a callback function, a government position index, and a list of available CMinister objects
	-- We assert the existance of 8 changeable positions, and bind them to a lua callback function
	local laPositions = {}
	laPositions[_CHIEF_OF_AIR_] = {Callback=ChiefOfAir, GovPosition = nil, AvailableMinisters = {}}
	laPositions[_CHIEF_OF_NAVY_] = {Callback=ChiefOfNavy, GovPosition = nil, AvailableMinisters = {}}
	laPositions[_CHIEF_OF_ARMY_] = {Callback=ChiefOfArmy, GovPosition = nil, AvailableMinisters = {}}
	laPositions[_CHIEF_OF_STAFF_] = {Callback=ChiefOfStaff, GovPosition = nil, AvailableMinisters = {}}
	laPositions[_MINISTER_OF_INTELLIGENCE_] = {Callback=MinisterOfIntelligence, GovPosition = nil, AvailableMinisters = {}}
	laPositions[_MINISTER_OF_SECURITY_] = {Callback=MinisterOfSecurity, GovPosition = nil, AvailableMinisters = {}}
	laPositions[_ARMAMENT_MINISTER_] = {Callback=ArmamentMinister, GovPosition = nil, AvailableMinisters = {}}
	laPositions[_FOREIGN_MINISTER_] = {Callback=ForeignMinister, GovPosition = nil, AvailableMinisters = {}}

	-- Recover CGovernmentPosition for each index (k is a number)
	for k, v in pairs(laPositions) do
		laPositions[k].GovPosition = CGovernmentPositionDataBase.GetGovernmentPositionByIndex(k)
	end

	-- Organize the ministers by positions they can take
	for loMinister in ministerCountry:GetPossibleMinisters() do
		-- Make sure we are the same Ideology
		if loGroup == loMinister:GetIdeology():GetGroup() then
			-- Cycle through positions
			for k, v in pairs(laPositions) do
				-- If current minister can take current position, append it to current position AvailableMinisters
				if loMinister:CanTakePosition(v.GovPosition) then
					table.insert(laPositions[k].AvailableMinisters, loMinister)
				end
			end
		end
	end

	-- Now that we have all available ministers for each positions, cycle through position and use callback function
	for k, v in pairs(laPositions) do
		if table.getn(v.AvailableMinisters) > 0 then
			v.Callback(ai, ministerTag, ministerCountry, v.AvailableMinisters, v.GovPosition)
		end
	end
end

-- Picks the minister with the highest score for the job
function OfficeManagement_PickMinister(ai, ministerTag, ministerCountry, vaMinisters, voPosition, vaPersonalityScore, vsAiFunction)
	local loSelectedMinister = nil
	local liCurrentScore = 0

	if Utils.HasCountryAIFunction(ministerTag, vsAiFunction) then
		loSelectedMinister = Utils.CallCountryAI(ministerTag,  vsAiFunction, ministerCountry, vaMinisters)
	else
		for liIndex, loMinister in pairs(vaMinisters) do
			local liScore = 0
			local lsMinisterType = tostring(loMinister:GetPersonality(voPosition):GetKey())

			-- Check to make sure its a minister whose trait gets a score
			if vaPersonalityScore[lsMinisterType] ~= nil then
				liScore = vaPersonalityScore[lsMinisterType]

				if liScore > liCurrentScore then
					liCurrentScore = liScore
					loSelectedMinister = loMinister
				end
			end
		end
	end

	if loSelectedMinister ~= nil then
		if ministerCountry:GetMinister(voPosition) ~= loSelectedMinister then
			ai:Post(CChangeMinisterCommand(ministerTag, loSelectedMinister, voPosition))
		end
	end
 end
--################
-- Office Management sub-methods
--################
function MinisterOfSecurity(ai, ministerTag, ministerCountry, vaMinisters, voPosition)
	local laPersonalityScore = {}

	if not(Utils.HasCountryAIFunction(ministerTag, "Call_MinisterOfSecurity")) then
		if ministerCountry:IsAtWar() then
			laPersonalityScore["man_of_the_people"] = 70
			laPersonalityScore["efficient_sociopath"] = 60
			laPersonalityScore["crime_fighter"] = 50
			laPersonalityScore["compassionate_gentleman"] = 40
			laPersonalityScore["silent_lawyer"] = 30
			laPersonalityScore["prince_of_terror"] = 20
			laPersonalityScore["back_stabber"] = 10
		else
			laPersonalityScore["man_of_the_people"] = 70
			laPersonalityScore["compassionate_gentleman"] = 60
			laPersonalityScore["silent_lawyer"] = 50
			laPersonalityScore["efficient_sociopath"] = 40
			laPersonalityScore["crime_fighter"] = 30
			laPersonalityScore["prince_of_terror"] = 20
			laPersonalityScore["back_stabber"] = 10
		end
	end

	OfficeManagement_PickMinister(ai, ministerTag, ministerCountry, vaMinisters, voPosition, laPersonalityScore, "Call_MinisterOfSecurity")
end
function ArmamentMinister(ai, ministerTag, ministerCountry, vaMinisters, voPosition)
	local laPersonalityScore = {}

	local lbResourceShort = false
	local liExpenseFactor, liHomeFactor = Support.CalculateExpenseResourceFactor(ministerCountry)

	-- We are short on resources
	if liExpenseFactor > liHomeFactor then
		lbResourceShort = true
	end

	if not(Utils.HasCountryAIFunction(ministerTag, "Call_ArmamentMinister")) then
		if lbResourceShort then
			laPersonalityScore["military_entrepreneur"] = 150
			laPersonalityScore["resource_industrialist"] = 140
			laPersonalityScore["administrative_genius"] = 130
			laPersonalityScore["laissez_faires_capitalist"] = 120
			laPersonalityScore["theoretical_scientist"] = 110
			laPersonalityScore["infantry_proponent"] = 100
			laPersonalityScore["air_to_ground_proponent"] = 90
			laPersonalityScore["air_superiority_proponent"] = 80
			laPersonalityScore["battle_fleet_proponent"] = 70
			laPersonalityScore["air_to_sea_proponent"] = 60
			laPersonalityScore["strategic_air_proponent"] = 50
			laPersonalityScore["submarine_proponent"] = 40
			laPersonalityScore["tank_proponent"] = 30
			laPersonalityScore["corrupt_kleptocrat"] = 20
			laPersonalityScore["crooked_kleptocrat"] = 10
		else
			laPersonalityScore["administrative_genius"] = 150
			laPersonalityScore["resource_industrialist"] = 140
			laPersonalityScore["laissez_faires_capitalist"] = 130
			laPersonalityScore["military_entrepreneur"] = 120
			laPersonalityScore["theoretical_scientist"] = 110
			laPersonalityScore["infantry_proponent"] = 100
			laPersonalityScore["air_to_ground_proponent"] = 90
			laPersonalityScore["air_superiority_proponent"] = 80
			laPersonalityScore["battle_fleet_proponent"] = 70
			laPersonalityScore["air_to_sea_proponent"] = 60
			laPersonalityScore["strategic_air_proponent"] = 50
			laPersonalityScore["submarine_proponent"] = 40
			laPersonalityScore["tank_proponent"] = 30
			laPersonalityScore["corrupt_kleptocrat"] = 20
			laPersonalityScore["crooked_kleptocrat"] = 10
		end
	end

	OfficeManagement_PickMinister(ai, ministerTag, ministerCountry, vaMinisters, voPosition, laPersonalityScore, "Call_ArmamentMinister")
end
function ForeignMinister(ai, ministerTag, ministerCountry, vaMinisters, voPosition)
	local laPersonalityScore = {}

	if not(Utils.HasCountryAIFunction(ministerTag, "Call_ForeignMinister")) then
		local lsFaction = tostring(ministerCountry:GetFaction():GetTag())
		local lbIsArwar = ministerCountry:IsAtWar()

		-- Foreign minister pick depends mainly on current faction
		if lsFaction == "comintern" then
			laPersonalityScore["biased_intellectual"] = 50
		elseif lsFaction == "allies" then
			laPersonalityScore["the_cloak_n_dagger_schemer"] = 50
		elseif lsFaction == "axis" then
			laPersonalityScore["great_compromiser"] = 50
		end

		laPersonalityScore["apologetic_clerk"] = 40
		laPersonalityScore["ideological_crusader"] = 30

		-- Some foreign minister are irrelevant while at war
		if not(lbIsArwar) then
			laPersonalityScore["general_staffer"] = 20
		end

		laPersonalityScore["iron_fisted_brute"] = 10
	end

	OfficeManagement_PickMinister(ai, ministerTag, ministerCountry, vaMinisters, voPosition, laPersonalityScore, "Call_ForeignMinister")
end
function ChiefOfStaff(ai, ministerTag, ministerCountry, vaMinisters, voPosition)
	local laPersonalityScore = {}

	if not(Utils.HasCountryAIFunction(ministerTag, "Call_ChiefOfStaff")) then
		if ministerCountry:IsAtWar() then
			local liManpower = ministerCountry:GetManpower():Get()

			if liManpower < 200 then
				laPersonalityScore["school_of_mass_combat"] = 60
				laPersonalityScore["school_of_psychology"] = 50
			else
				laPersonalityScore["school_of_psychology"] = 60
				laPersonalityScore["school_of_mass_combat"] = 50
			end

			laPersonalityScore["logistics_specialist"] = 40
			laPersonalityScore["school_of_fire_support"] = 30
			laPersonalityScore["school_of_defence"] = 20
			laPersonalityScore["school_of_manoeuvre"] = 10
		else
			laPersonalityScore["school_of_mass_combat"] = 60
			laPersonalityScore["logistics_specialist"] = 50
			laPersonalityScore["school_of_fire_support"] = 40
			laPersonalityScore["school_of_defence"] = 30
			laPersonalityScore["school_of_manoeuvre"] = 20
			laPersonalityScore["school_of_psychology"] = 10
		end
	end

	OfficeManagement_PickMinister(ai, ministerTag, ministerCountry, vaMinisters, voPosition, laPersonalityScore, "Call_ChiefOfStaff")
end
function MinisterOfIntelligence(ai, ministerTag, ministerCountry, vaMinisters, voPosition)
	local laPersonalityScore = {}

	if not(Utils.HasCountryAIFunction(ministerTag, "Call_MinisterOfIntelligence")) then
		laPersonalityScore["dismal_enigma"] = 60
		laPersonalityScore["research_specialist"] = 50
		laPersonalityScore["naval_intelligence_specialist"] = 40
		laPersonalityScore["technical_specialist"] = 30
		laPersonalityScore["industrial_specialist"] = 20
		laPersonalityScore["political_specialist"] = 10
	end

	OfficeManagement_PickMinister(ai, ministerTag, ministerCountry, vaMinisters, voPosition, laPersonalityScore, "Call_MinisterOfIntelligence")
end
function ChiefOfArmy(ai, ministerTag, ministerCountry, vaMinisters, voPosition)
	local laPersonalityScore = {}

	if not(Utils.HasCountryAIFunction(ministerTag, "Call_ChiefOfArmy")) then
		laPersonalityScore["guns_and_butter_doctrine"] = 50
		laPersonalityScore["static_defence_doctrine"] = 40
		laPersonalityScore["decisive_battle_doctrine"] = 30
		laPersonalityScore["elastic_defence_doctrine"] = 20
		laPersonalityScore["armoured_spearhead_doctrine"] = 10
	end

	OfficeManagement_PickMinister(ai, ministerTag, ministerCountry, vaMinisters, voPosition, laPersonalityScore, "Call_ChiefOfArmy")
end
function ChiefOfNavy(ai, ministerTag, ministerCountry, vaMinisters, voPosition)
	local laPersonalityScore = {}

	if not(Utils.HasCountryAIFunction(ministerTag, "Call_ChiefOfNavy")) then
		laPersonalityScore["decisive_naval_battle_doctrine"] = 50
		laPersonalityScore["indirect_approach_doctrine"] = 40
		laPersonalityScore["open_seas_doctrine"] = 30
		laPersonalityScore["base_control_doctrine"] = 20
		laPersonalityScore["power_projection_doctrine"] = 10
	end

	OfficeManagement_PickMinister(ai, ministerTag, ministerCountry, vaMinisters, voPosition, laPersonalityScore, "Call_ChiefOfNavy")
end
function ChiefOfAir(ai, ministerTag, ministerCountry, vaMinisters, voPosition)
	local laPersonalityScore = {}

	if not(Utils.HasCountryAIFunction(ministerTag, "Call_ChiefOfAir")) then
		laPersonalityScore["air_superiority_doctrine"] = 50
		laPersonalityScore["army_aviation_doctrine"] = 40
		laPersonalityScore["naval_aviation_doctrine"] = 30
		laPersonalityScore["carpet_bombing_doctrine"] = 20
		laPersonalityScore["vertical_envelopment_doctrine"] = 10
	end

	OfficeManagement_PickMinister(ai, ministerTag, ministerCountry, vaMinisters, voPosition, laPersonalityScore, "Call_ChiefOfAir")
end
--################
-- End of Office Management sub-methods
--################


--################
-- Law sub-methods
--################
function ConscriptionLaw(ministerTag, ministerCountry, voCurrentLaw)
	local liIndex = voCurrentLaw:GetIndex() + 1
	local loNewLaw = nil

	if liIndex < CLawDataBase.GetNumberOfLaws() then
		loNewLaw = CLawDataBase.GetLaw(liIndex)
		if not(voCurrentLaw:GetGroup():GetIndex() == loNewLaw:GetGroup():GetIndex()) then
			return nil
		end
	end

	if loNewLaw:ValidFor(ministerTag) then
		return loNewLaw
	else
		return nil
	end
end
function CivilLaw(ministerTag, ministerCountry, voCurrentLaw)
	-- Performance Check do we really need to do anything?
	-- Switch Democracies back to Open Society if no longer atwar!
	if not(ministerCountry:IsAtWar()) and tostring(ministerCountry:GetRulingIdeology():GetGroup():GetKey()) == "democracy" then
		return CLawDataBase.GetLaw(_OPEN_SOCIETY_)
	end

	local liIndex = voCurrentLaw:GetIndex() + 1
	local loNewLaw = nil

	if liIndex < CLawDataBase.GetNumberOfLaws() then
		loNewLaw = CLawDataBase.GetLaw(liIndex)
		if not(voCurrentLaw:GetGroup():GetIndex() == loNewLaw:GetGroup():GetIndex()) then
			return nil
		end
	end

	if loNewLaw:ValidFor(ministerTag) then
		return loNewLaw
	else
		return nil
	end
end
function EconomicLaw(ministerTag, ministerCountry, voCurrentLaw)
	local liIndex = voCurrentLaw:GetIndex() + 1
	local loNewLaw = nil

	-- No War Economy when at Peace
	if liIndex >= 14 and not ministerCountry:IsAtWar() then
		liIndex = 13
	end

	if liIndex < CLawDataBase.GetNumberOfLaws() then
		loNewLaw = CLawDataBase.GetLaw(liIndex)
		if not(voCurrentLaw:GetGroup():GetIndex() == loNewLaw:GetGroup():GetIndex()) then
			return nil
		end
	end

	if loNewLaw:ValidFor(ministerTag) then
		return loNewLaw
	else
		return nil
	end
end
function EducationInvestment(ministerTag, ministerCountry, voCurrentLaw)
	-- Performance Check do we really need to do anything?
	if voCurrentLaw:GetIndex() == _BIG_EDUCATION_INVESTMENT_ then
		return nil
	else
		local loNewLaw = CLawDataBase.GetLaw(_BIG_EDUCATION_INVESTMENT_)

		if loNewLaw:ValidFor(ministerTag) then
			return loNewLaw
		end
	end

	return nil
end
function IndustrialPolicies(ministerTag, ministerCountry, voCurrentLaw)
	-- Performance Check do we really need to do anything?
	if voCurrentLaw:GetIndex() == _HEAVY_INDUSTRY_EMPHASIS_ and ministerCountry:IsAtWar() then
		return nil
	end

	-- Peace get the break from the CG hit
	if not(ministerCountry:IsAtWar()) then
		return CLawDataBase.GetLaw(_CONSUMER_PRODUCT_ORIENTATION_)
	else
		-- Try Heavy first if not then try Mixed
		local loNewLaw = CLawDataBase.GetLaw(_HEAVY_INDUSTRY_EMPHASIS_)

		if loNewLaw:ValidFor(ministerTag) then
			return loNewLaw
		else
			loNewLaw = CLawDataBase.GetLaw(_MIXED_INDUSTRY_)

			if loNewLaw:ValidFor(ministerTag) then
				return loNewLaw
			end
		end
	end

	return nil
end
function PressLaws(ministerTag, ministerCountry, voCurrentLaw)
	-- Performance Check do we really need to do anything?
	-- Switch Democracies back to Free Press if no longer atwar!
	if not(ministerCountry:IsAtWar()) and tostring(ministerCountry:GetRulingIdeology():GetGroup():GetKey()) == "democracy" then
		return CLawDataBase.GetLaw(_FREE_PRESS_)
	end

	local liIndex = voCurrentLaw:GetIndex() + 1
	local loNewLaw = nil

	if liIndex < CLawDataBase.GetNumberOfLaws() then
		loNewLaw = CLawDataBase.GetLaw(liIndex)
		if not(voCurrentLaw:GetGroup():GetIndex() == loNewLaw:GetGroup():GetIndex()) then
			return nil
		end
	end

	if loNewLaw:ValidFor(ministerTag) then
		return loNewLaw
	else
		return nil
	end
end
function TrainingLaws(ministerTag, ministerCountry, voCurrentLaw)

	local default = defaultLandTraining[tostring(ministerTag)]

	if default ~= nil then
		if not ministerCountry:GetFlags():IsFlagSet("training_laws_check") then
			return CLawDataBase.GetLaw(default)
		end

		local totalIc = ministerCountry:GetTotalIC()
		local reinforcementsIC = ministerCountry:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_REINFORCEMENT_):GetNeeded():Get()
		local reinforcementsPercent = reinforcementsIC/totalIc
		local vars = ministerCountry:GetVariables()
		local want_land_training_law_change_date = vars:GetVariable(CString("want_land_training_law_change_date")):Get()
		local date = CCurrentGameState.GetCurrentDate():GetTotalDays()
		local diff = date - want_land_training_law_change_date

		local TRAINING_LAW_CHANGE_HYSTERESIS = 40	-- need at least X days of fullfilling trigger conditions
		local TRAINING_LAW_IC_TRIGGER_PERCENT = 0.150
		if Utils.HasCountryAIFunction(ministerTag, "TrainingLaws_IcTriggerPercent") then
			TRAINING_LAW_IC_TRIGGER_PERCENT = Utils.CallCountryAI(ministerTag, "TrainingLaws_IcTriggerPercent")
		end

		-- we are spending alot on reinforcement -> consider lowering training laws
		if reinforcementsPercent >= TRAINING_LAW_IC_TRIGGER_PERCENT then
			if	-- validate the law change variable
				-- no date set yet
				(want_land_training_law_change_date == 0)
				or
				-- the saved date is too old because we recovered before triggering a change -> reset
				(diff > (3 * TRAINING_LAW_CHANGE_HYSTERESIS))
			then
				-- set starting date
				local command = CSetVariableCommand(ministerTag, CString("want_land_training_law_change_date"), CFixedPoint(date))
				CCurrentGameState.Post(command)
				return nil
			elseif diff > TRAINING_LAW_CHANGE_HYSTERESIS then
				local new = voCurrentLaw:GetIndex() - 1
				new = math.max(new, _MINIMAL_TRAINING_) -- cant go lower than minimal training

				-- reset the starting date to 0
				local command = CSetVariableCommand(ministerTag, CString("want_land_training_law_change_date"), CFixedPoint(0))
				CCurrentGameState.Post(command)

				return CLawDataBase.GetLaw(new)
			end
		-- we are not spending too much but are on a different law? -> go back to default
		elseif default ~= voCurrentLaw:GetIndex() then
			return CLawDataBase.GetLaw(default)
		end
	end
	return nil
end
function ConscriptionLaws2(ministerTag, ministerCountry, voCurrentLaw)

	-- Calculate manpower ratio to fielded (assume 8 manpower per division)
	local mpRatio = ministerCountry:GetManpower():Get() / (ministerCountry:GetUnits():GetTotalAmountOfDivisions() * 8)
	--Utils.LUA_DEBUGOUT(tostring(ministerTag) .. " Manpower Replaceability " .. mpRatio)

	-- Can fully replace, use volunteer
	if mpRatio > 1 then
		return CLawDataBase.GetLaw(volunteer_recruitment)
	end

	-- Starting to worry
	if mpRatio > 0.75 then
		return CLawDataBase.GetLaw(standard_conscription)
	end

	-- Worrisome situation
	if mpRatio > 0.3 and not ministerCountry:IsAtWar() then
		return CLawDataBase.GetLaw(extended_conscription)
	end

	-- Worrisome situation and at war
	if mpRatio > 0.3 and ministerCountry:IsAtWar() then
		return CLawDataBase.GetLaw(massive_conscription)
	end

	-- Emergency situation and at war
	if mpRatio <= 0.30 and ministerCountry:IsAtWar() then
		return CLawDataBase.GetLaw(emergency_conscription)
	end

	return nil
end
--################
-- End of Law sub-methods
--################
