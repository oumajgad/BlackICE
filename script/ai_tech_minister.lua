
-- Techs that are used in the main file to be ignored
--   techname|level (level must be 1-9 a 0 means ignore all
--   these local variables can be overiden in the country specific files
--   use as the first tech name the word "all" and it will cause the AI to ignore all the techs

-- Index IDs for the main Research areas
local _RESEARCH_LAND_ = 1
local _RESEARCH_LAND_DOC_ = 2
local _RESEARCH_AIR_ = 3
local _RESEARCH_AIR_DOC_ = 4
local _RESEARCH_NAVAL_ = 5
local _RESEARCH_NAVAL_DOC_ = 6
local _RESEARCH_INDUSTRIAL_ = 7
local _RESEARCH_SECRET_ = 8
local _RESEARCH_UNKNOWN_ = 9

local TechnologyData = {}

-- ##################################
-- # Called by the EXE
-- ##################################
-- # Happens around 03:00 each day
-- ##################################
function TechMinister_Tick(minister, vbSliders, vbResearch)

	local isOMG = false
	if tostring(minister:GetCountryTag()) == "OMG" then
		isOMG = true
	end

	local t = nil
	if benchmarkLUA then
		t = os.clock()
	end

	if isOMG then
		OMGMinisterHandler("TechMinister_Tick", minister)
	end

	-- Reset Global Array Container
	TechnologyData = {
		minister = minister,
		ministerAI = minister:GetOwnerAI(),
		ministerTag = minister:GetCountryTag(),
		ministerCountry = nil,
		humanTag = CCurrentGameState.GetPlayer(),
		IsAtWar = nil, -- Boolean are they atwar with someone
		IsMajor = nil, -- Boolean are they a major power
		IsNaval = nil, -- Boolean do they have the min requirements to build ships
		TechStatus = nil, -- TechStatus Object
		icTotal = 0, -- Total Amount of IC they have
		PortsTotal = 0, -- Total amount of ports
		AirfieldsTotal = 0} -- Total amount of airfields

	-- Initialize Production Object
	--   only the ones that are used for the slider
	-- #################
	TechnologyData.ministerCountry = TechnologyData.ministerTag:GetCountry()
	TechnologyData.IsMajor = TechnologyData.ministerCountry:IsMajor()
	-- End Initialize Production Object
	-- #################

	local ResearchSlotsAllowed = 0

	if vbSliders then
		if Stats.CollectStats == true and Stats.CustomListCheck(tostring(TechnologyData.ministerTag)) then
			-- Utils.LUA_DEBUGOUT("HandleTechMinisterStats: " .. tostring(TechnologyData.ministerTag))
			Stats.HandleTechMinisterStats(TechnologyData.ministerTag, TechnologyData.ministerCountry)
		end
	end

	if vbSliders then
		-- Calling balance sliders like this allows me to get what the new Research slot count would be
		--    once the sliders are shifted
		local loLeaderSliders = BalanceLeadershipSliders(TechnologyData, vbSliders)
		ResearchSlotsAllowed = math.ceil(loLeaderSliders.Slots_Research)
	else
		-- Sliders already set by player
		ResearchSlotsAllowed = TechnologyData.ministerCountry:GetAllowedResearchSlots()
	end

	if vbResearch then
		local ResearchSlotsNeeded = ResearchSlotsAllowed - TechnologyData.ministerCountry:GetNumberOfCurrentResearch()
		-- Performance check, exit if there are no slots available
		if ResearchSlotsNeeded >= 0.01 then
			-- Initialize Production Object
			--   add the ones used for Tech Research
			-- #################
			TechnologyData.TechStatus = TechnologyData.ministerCountry:GetTechnologyStatus()
			TechnologyData.PortsTotal = TechnologyData.ministerCountry:GetNumOfPorts()
			TechnologyData.AirfieldsTotal = TechnologyData.ministerCountry:GetNumOfAirfields()
			TechnologyData.icTotal = TechnologyData.ministerCountry:GetTotalIC()
			TechnologyData.IsAtWar = TechnologyData.ministerCountry:IsAtWar()
			TechnologyData.IsNaval = (TechnologyData.PortsTotal > 0 and TechnologyData.icTotal >= 20)
			-- End Initialize Production Object
			-- #################

			local liMaxTechYear = CTechnologyDataBase.GetLatestTechYear() + 1
			Process_Tech((CCurrentGameState.GetCurrentDate():GetYear()), liMaxTechYear, ResearchSlotsAllowed, ResearchSlotsNeeded, 0)
		end
	end

	if benchmarkLUA then
		Utils.addTime("Tech", os.clock() - t, isOMG)
	end
end


function CustomBalanceLeadershipSliders(standardDataObject, leadership, variables)
	local freePercent = 1
	local upperBound = {
		spies = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_spiesUpper")):Get(),
		diplo = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_diploUpper")):Get(),
		ncoRatio = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_officersUpper")):Get() / 100,
	}
	local lowerBound = {
		spies = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_spiesLower")):Get(),
		diplo = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_diploLower")):Get(),
		ncoRatio = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_officersLower")):Get() / 100,
	}
	local activeStates = {
		spies = true,
		diplo = true,
		nco = true,
	}
	local investing = {
		spies = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_investingSpies")):Get(),
		diplo = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_investingDiplo")):Get(),
		nco = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_investingNco")):Get(),
	}
	local previous = {
		spies = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_previousSpies")):Get(),
		diplo = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_previousDiplo")):Get(),
		nco = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_previousNco")):Get(),
	}
	local allocations = {
		research = 0,
		spies = 0,
		diplo = 0,
		nco = 0,
	}

	-- Utils.LUA_DEBUGOUT("upperBound: ")
	-- Utils.INSPECT_TABLE(upperBound)
	-- Utils.LUA_DEBUGOUT("lowerBound: ")
	-- Utils.INSPECT_TABLE(lowerBound)
	-- Utils.LUA_DEBUGOUT("investing: ")
	-- Utils.INSPECT_TABLE(investing)
	-- Utils.LUA_DEBUGOUT("previous: ")
	-- Utils.INSPECT_TABLE(previous)

	local officer_ratio = standardDataObject.ministerCountry:GetOfficerRatio():Get()
	local freeSpies = TechnologyData.ministerCountry:GetNumberOfFreeSpies()
	-- Utils.LUA_DEBUGOUT("officer_ratio: " .. tostring(officer_ratio))
	-- Utils.LUA_DEBUGOUT("freeSpies: " .. tostring(freeSpies))

	-- don't execute if we haven't set needed variables yet
	if previous.diplo ~= 0 and previous.spies ~= 0 then
		-- Utils.LUA_DEBUGOUT(" --- Executing CustomBalanceLeadershipSliders --- ")

		-- Officers
		if activeStates.nco and (officer_ratio < lowerBound.ncoRatio or investing.nco == 1) then
			-- we need to remember if we are trying to raise amounts so we don't stop investing once we are above the lower threshold
			CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_investingNco"), CFixedPoint(1)))
			local dateReached = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_dateReachedNco")):Get()
			local currentDate = CCurrentGameState.GetCurrentDate():GetTotalDays()
			if officer_ratio >= upperBound.ncoRatio then
				if variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_bufferProdNco")):Get() == 1 then
					-- Keep producing for 10 more days
					if dateReached == 0 then
						-- This is the first day and no dateReached has been set yet
						-- Utils.LUA_DEBUGOUT("Set - dateReached: " .. currentDate)
						CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_dateReachedNco"), CFixedPoint(currentDate)))
					elseif currentDate - dateReached >= 10 then
						-- Utils.LUA_DEBUGOUT("Stop extended production")
						CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_investingNco"), CFixedPoint(0)))
						CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_dateReachedNco"), CFixedPoint(0)))
						CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_bonusNco"), CFixedPoint(0)))
					end
					-- Keep the same allocation
					allocations.nco = math.min(
						freePercent, standardDataObject.ministerCountry:GetLeadershipDistributionAt(CDistributionSetting._LEADERSHIP_NCO_):GetPercentage():Get())
					freePercent = freePercent - allocations.nco
				else
					CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_investingNco"), CFixedPoint(0)))
					CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_dateReachedNco"), CFixedPoint(0)))
					CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_bonusNco"), CFixedPoint(0)))
				end
			else
				if dateReached ~= 0 then
					-- reset dateReached for the case where we were in the 10 day extension but sank below threshold
					CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_dateReachedNco"), CFixedPoint(0)))
				end

				-- bonus which will increase each day that we are still loosing officers even when we are investing
				local bonus = variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_bonusNco")):Get()
				if previous.nco > officer_ratio then
					bonus = bonus + 1
					CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_bonusNco"), CFixedPoint(bonus)))
				end

				local officerModifier = 1 + standardDataObject.ministerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_OFFICER_RECRUITMENT_):Get()
				local distance = (upperBound.ncoRatio - officer_ratio) * 100
				local allocateLS = (1 / (defines.economy.LEADERSHIP_TO_OFFICERS * officerModifier) * 50)
									* math.max(1, distance + bonus) -- first ls for 50 officers , then multiply for distance + bonus
				allocations.nco = math.min(freePercent, allocateLS / leadership.TotalLeadership)
				freePercent = freePercent - allocations.nco

				-- Utils.LUA_DEBUGOUT("officerModifier: " .. officerModifier)
				-- Utils.LUA_DEBUGOUT("officer_ratio: ".. officer_ratio)
				-- Utils.LUA_DEBUGOUT("previous.nco: ".. previous.nco)
				-- Utils.LUA_DEBUGOUT("bonus: ".. bonus)
				-- Utils.LUA_DEBUGOUT("distance: ".. distance)
				-- Utils.LUA_DEBUGOUT("allocateLS: " .. allocateLS)
				-- Utils.LUA_DEBUGOUT("allocations.nco: " .. allocations.nco)
				-- Utils.LUA_DEBUGOUT("freePercent: " .. freePercent)
			end
		end

		-- Spies
		if activeStates.spies and (freeSpies < lowerBound.spies or investing.spies == 1) then
			CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_investingSpies"), CFixedPoint(1)))
			if freeSpies >= upperBound.spies then
				-- stop investing once above the upper threshold
				CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_investingSpies"), CFixedPoint(0)))
			else
				-- if this is positive we arent allocating enough
				local delta = previous.spies - freeSpies
				local allocateLS = (1 / defines.economy.LEADERSHIP_TO_SPIES) * math.max(1, delta + 1) -- first part is LS needed for 1 spy/day, 2nd part is multiplier if we are losing any
				allocations.spies = math.min(freePercent, allocateLS / leadership.TotalLeadership)
				freePercent = freePercent - allocations.spies
				-- Utils.LUA_DEBUGOUT("freeSpies: ".. freeSpies)
				-- Utils.LUA_DEBUGOUT("previous.spies: ".. previous.spies)
				-- Utils.LUA_DEBUGOUT("delta: ".. delta)
				-- Utils.LUA_DEBUGOUT("allocateLS: " .. allocateLS)
				-- Utils.LUA_DEBUGOUT("allocations.spies: " .. allocations.spies)
				-- Utils.LUA_DEBUGOUT("freePercent: " .. freePercent)
			end
		end

		-- Diplo
		if activeStates.diplo and (leadership.Diplomats < lowerBound.diplo or investing.diplo == 1) then
			CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_investingDiplo"), CFixedPoint(1)))
			if leadership.Diplomats >= upperBound.diplo then
				CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_investingDiplo"), CFixedPoint(0)))
			else
				local allocateLS = 1 / defines.economy.LEADERSHIP_TO_DIPLOMACY * (5 + leadership.ActiveInfluence) -- flat 5 diplo + diplo influences should be enough
				allocations.diplo = math.min(freePercent, allocateLS / leadership.TotalLeadership)
				freePercent = freePercent - allocations.diplo
			-- 	Utils.LUA_DEBUGOUT("leadership.ActiveInfluence: " .. leadership.ActiveInfluence)
			-- 	Utils.LUA_DEBUGOUT("leadership.TotalLeadership: " .. leadership.TotalLeadership)
			-- 	Utils.LUA_DEBUGOUT("allocateLS: " .. allocateLS)
			-- 	Utils.LUA_DEBUGOUT("allocations.diplo: " .. allocations.diplo)
			-- 	Utils.LUA_DEBUGOUT("freePercent: " .. freePercent)
			end
		end

		-- Research
		allocations.research = math.max(0, freePercent)
		-- Utils.LUA_DEBUGOUT("allocations: ")
		-- Utils.INSPECT_TABLE(allocations)
	else
		-- Utils.LUA_DEBUGOUT(" --- Skipped CustomBalanceLeadershipSliders --- ")
	end

	CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_previousSpies"), CFixedPoint(freeSpies + 1)))
	CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_previousDiplo"), CFixedPoint(leadership.Diplomats + 1)))
	CCurrentGameState.Post(CSetVariableCommand(standardDataObject.ministerTag, CString("zzDsafe_CustomLeadershipSliders_previousNco"), CFixedPoint(officer_ratio)))

	-- Utils.LUA_DEBUGOUT("allocations: ")
	-- Utils.INSPECT_TABLE(allocations)
	return allocations.research, allocations.spies, allocations.diplo, allocations.nco, math.floor(leadership.TotalLeadership * allocations.research)
end

-- Balances the research sliders
-- NOTE: This method is called from the following files
--     ai_foreign_minister.lua
--     ai_tech_minister.lua
function BalanceLeadershipSliders(StandardDataObject, vbSliders)
	local liInfluenceCap = 25 -- Cap based on total leadership, if below this do not influence at all
	local liDiplomacyNoFaction = 0.5 -- Major or Minor not in a faction or does not meet influence cap
	local liDiplomacyInFaction = 4.5 -- Majors that are in a faction and exceed influence cap

    local Leadership = {
		NCONeeded = false,
		CanInfluence = false,	-- needed by other functions
		ActiveInfluence = StandardDataObject.ministerCountry:CalculateNumberOfActiveInfluences(),	-- needed by other functions
		Diplomats = StandardDataObject.ministerCountry:GetDiplomaticInfluence():Get(),	-- needed by other functions
		TotalLeadership = StandardDataObject.ministerCountry:GetTotalLeadership():Get(),	-- needed by other functions
		FreeSpies = TechnologyData.ministerCountry:GetNumberOfFreeSpies(),
		OfficerRatio = StandardDataObject.ministerCountry:GetOfficerRatio():Get(),
		Default_Research = 0,
		Default_Espionage = 0.10,
		Default_Diplomacy = 0.15,	-- needed by other functions
		Default_NCO = 0.1,
		Percent_Research = 0,
		Percent_Espionage = 0.0,
		Percent_Diplomacy = 0.0,
		Percent_NCO = 0.0,
		Slots_Research = 0,	-- needed by other functions
		Slots_Espionage = 0,
		Slots_Diplomacy = 0,
		Slots_NCO = 0,
		TotalSpiesAbroad  = GetTotalSpiesAbroad(StandardDataObject.ministerCountry, StandardDataObject.ministerTag)
	}

	Leadership.CanInfluence = (StandardDataObject.ministerCountry:HasFaction() and Leadership.TotalLeadership >= liInfluenceCap)

	local variables = StandardDataObject.ministerCountry:GetVariables()
	if variables:GetVariable(CString("zzDsafe_CustomLeadershipSliders_isActive")):Get() == 1 then
	-- if CCurrentGameState.IsPlayer( StandardDataObject.ministerTag ) then
		-- Utils.LUA_DEBUGOUT("IsPlayer: " .. tostring(StandardDataObject.ministerTag))
		-- Utils.LUA_DEBUGOUT("CustomBalanceLeadershipSliders")
		-- local t = os.clock()

		Leadership.Percent_Research,
		Leadership.Percent_Espionage,
		Leadership.Percent_Diplomacy,
		Leadership.Percent_NCO,
		Leadership.Slots_Research = CustomBalanceLeadershipSliders(StandardDataObject, Leadership, variables)
		if vbSliders then
			local command = CChangeLeadershipCommand(StandardDataObject.ministerTag, Leadership.Percent_NCO, Leadership.Percent_Diplomacy, Leadership.Percent_Espionage, Leadership.Percent_Research)
			StandardDataObject.ministerAI:Post(command)
		end
		-- Utils.LUA_DEBUGOUT("CustomBalanceLeadershipSliders: " .. os.clock() - t)
		return Leadership
	end

	local domSpy1 = TechnologyData.ministerCountry:GetSpyPresence(TechnologyData.ministerTag)
	local domSpy = domSpy1:GetLevel():Get()

	local freePercentage = 1

	-- Officers
	local funRef = Utils.HasCountryAIFunction(StandardDataObject.ministerTag, "TechMinister_OfficerRatio")
	if funRef then
		Leadership.Percent_NCO = funRef(StandardDataObject, Leadership, freePercentage)
	else
		if Leadership.OfficerRatio < 0.5 then
			Leadership.Percent_NCO = math.min(1, freePercentage)
		elseif Leadership.OfficerRatio < 0.8 then
			Leadership.Percent_NCO = math.min(0.95, freePercentage)
		elseif Leadership.OfficerRatio  < 0.99 then
			Leadership.Percent_NCO = math.min(0.85, freePercentage)
		elseif Leadership.OfficerRatio  < 1.099 then
			Leadership.Percent_NCO = math.min(0.4, freePercentage)
		else
			Leadership.Percent_NCO = math.min(0.025, freePercentage)
		end
	end
	freePercentage = freePercentage - Leadership.Percent_NCO

	-- Spies
	if Leadership.TotalLeadership < Leadership.TotalSpiesAbroad then
		Leadership.Percent_Espionage = 0
	else
		if Leadership.FreeSpies >= 3 then
			Leadership.Percent_Espionage = 0
		elseif Leadership.FreeSpies >= 1 then
			Leadership.Percent_Espionage = math.min((0.75 / defines.economy.LEADERSHIP_TO_SPIES) / 100, freePercentage)
		elseif domSpy >= 8 then
			Leadership.Percent_Espionage = math.min((2 / defines.economy.LEADERSHIP_TO_SPIES) / 100, freePercentage)
		else
			Leadership.Percent_Espionage = math.min((4 / defines.economy.LEADERSHIP_TO_SPIES) / 100, freePercentage)
		end
	end
	freePercentage = freePercentage - Leadership.Percent_Espionage

	-- Diplos
	if Leadership.Diplomats >= 100 then
		Leadership.Percent_Diplomacy = 0
	elseif Leadership.Diplomats > 20 then
		Leadership.Percent_Diplomacy = math.min(0.05, freePercentage)
	elseif Leadership.Diplomats > 10 then
		Leadership.Percent_Diplomacy = math.min(0.1, freePercentage)
	else
		local allocateLS = 1 / defines.economy.LEADERSHIP_TO_DIPLOMACY * (2 + Leadership.ActiveInfluence)
		Leadership.Percent_Diplomacy = math.min(freePercentage, allocateLS / Leadership.TotalLeadership)
	end
	freePercentage = freePercentage - Leadership.Percent_Diplomacy

	-- Research is whatever is left over
	Leadership.Percent_Research = freePercentage

	Leadership.Slots_Research = Leadership.TotalLeadership * Leadership.Percent_Research
	Leadership.Slots_Espionage = Leadership.TotalLeadership * Leadership.Percent_Espionage
	Leadership.Slots_Diplomacy = Leadership.TotalLeadership * Leadership.Percent_Diplomacy
	Leadership.Slots_NCO = Leadership.TotalLeadership * Leadership.Percent_NCO

	-- if StandardDataObject.IsMajor then
	-- 	Utils.LUA_DEBUGOUT(tostring(StandardDataObject.ministerTag))
	-- 	Utils.INSPECT_TABLE(Leadership)
	-- end

	-- Do not post unless set to true as this could be a call from other AIs to get information on the sliders
	if vbSliders then
		local command = CChangeLeadershipCommand(StandardDataObject.ministerTag, Leadership.Percent_NCO, Leadership.Percent_Diplomacy, Leadership.Percent_Espionage, Leadership.Percent_Research)
		StandardDataObject.ministerAI:Post(command)
	end

	return Leadership
end

function GetTotalSpiesAbroad(ministerCountry, ministerTag)
	-- Utils.LUA_DEBUGOUT("GetTotalSpiesAbroad: " .. tostring(ministerTag))
	local totalLevel = 0
	for country in CCurrentGameState.GetCountries() do
		if country:Exists() then
			local targetTag = country:GetCountryTag()
			if targetTag ~= ministerTag then
				local level = ministerCountry:GetSpyPresence(targetTag):GetLevel():Get()
				if level > 0 then
					totalLevel = totalLevel + level
					-- Utils.LUA_DEBUGOUT(tostring(targetTag) .. ": " .. tostring(level))
				end
			end
		end
	end
	-- Utils.LUA_DEBUGOUT(tostring(ministerTag) .. " - totalLevel: " .. tostring(totalLevel))
	return totalLevel
end

-- Processes the main tech reasearch for the specified country
--   designed to be a recursive call in case the AI needs to research in the future
function Process_Tech(pYear, pMaxYear, ResearchSlotsAllowed, ResearchSlotsNeeded, recursion)
	-- Performance check, exit if there are no slots available
	if ResearchSlotsNeeded < 0.01 then
		return
	end
	if pYear >= pMaxYear then
		return
	end
	-- No point in searching for techs 15 years in the future
	if recursion > 5 then
		return
	end

	-- Utils.LUA_DEBUGOUT(tostring(TechnologyData.ministerTag) .. " --- Process_Tech called --- recoursion: " .. recursion)
	--Utils.LUA_DEBUGOUT("Country: " .. tostring(ministerTag))

	local laPrimeTechAreas = {}
	laPrimeTechAreas[_RESEARCH_LAND_] = {
								Folder = {
									"infantry_folder",
									"special_forces_folder",
									"armour_folder",
									"artillery_folder",
									"armourII_folder",
									"antitank_folder"
								},
								ResearchWeight = 0,
								CurrentSlots = 0,
								ResearchSlots = 0,
								RegularTech = {},
								PreferTech = {},
								ListName = "LandTechs",
								ListIgnore = {},
								ListPrefer = {}}
	laPrimeTechAreas[_RESEARCH_LAND_DOC_] = {
								Folder = {
									"land_doctrine_folder",
									"deep_battle_folder",
									"grand_battle_plan_folder",
									"superior_firepower_folder",
									"blitzkrieg_folder",
									"command_structure_folder"
								},
								ResearchWeight = 0,
								CurrentSlots = 0,
								ResearchSlots = 0,
								RegularTech = {},
								PreferTech = {},
								ListName = "LandDoctrinesTechs",
								ListIgnore = {},
								ListPrefer = {}}
	laPrimeTechAreas[_RESEARCH_AIR_] = {
								Folder = {
									"aircraft_folder",
									"payload_folder",
									"armament_folder",
									"aircraftsystems_folder",
									"avionics_folder",
									"jet_folder",
								},
								ResearchWeight = 0,
								CurrentSlots = 0,
								ResearchSlots = 0,
								RegularTech = {},
								PreferTech = {},
								ListName = "AirTechs",
								ListIgnore = {},
								ListPrefer = {}
	}
	laPrimeTechAreas[_RESEARCH_AIR_DOC_] = {
								Folder = {
									"air_doctrine_folder"
								},
								ResearchWeight = 0,
								CurrentSlots = 0,
								ResearchSlots = 0,
								RegularTech = {},
								PreferTech = {},
								ListName = "AirDoctrineTechs",
								ListIgnore = {},
								ListPrefer = {}}
	laPrimeTechAreas[_RESEARCH_NAVAL_] = {
								Folder = {
									"smallship_folder",
									"cruiser_folder",
									"submarine_folder",
									"transports_folder",
									"carrier_folder",
									"capitalship_folder",
									"capitalship_II_folder"
								},
								ResearchWeight = 0,
								CurrentSlots = 0,
								ResearchSlots = 0,
								RegularTech = {},
								PreferTech = {},
								ListName = "NavalTechs",
								ListIgnore = {},
								ListPrefer = {}}
	laPrimeTechAreas[_RESEARCH_NAVAL_DOC_] = {
								Folder = {
									"naval_doctrine_folder"
								},
								ResearchWeight = 0,
								CurrentSlots = 0,
								ResearchSlots = 0,
								RegularTech = {},
								PreferTech = {},
								ListName = "NavalDoctrineTechs",
								ListIgnore = {},
								ListPrefer = {}}
	laPrimeTechAreas[_RESEARCH_INDUSTRIAL_] = {
								Folder = {
									"industry_folder",
									"nation_folder",
									"construction_folder",
									"theory_folder"
								},
								ResearchWeight = 0,
								CurrentSlots = 0,
								ResearchSlots = 0,
								RegularTech = {},
								PreferTech = {},
								ListName = "IndustrialTechs",
								ListIgnore = {},
								ListPrefer = {}}
	laPrimeTechAreas[_RESEARCH_SECRET_] = {
								Folder = {
									"secretweapon_folder"
								},
								ResearchWeight = 0,
								CurrentSlots = 0,
								ResearchSlots = 0,
								RegularTech = {},
								PreferTech = {},
								ListName = "SecretWeaponTechs",
								ListIgnore = {},
								ListPrefer = {}}
	laPrimeTechAreas[_RESEARCH_UNKNOWN_] = {
								Folder = {
									"unknown"
								},
								ResearchWeight = 0,
								CurrentSlots = 0,
								ResearchSlots = 0,
								RegularTech = {},
								PreferTech = {},
								ListName = "OtherTechs",
								ListIgnore = {},
								ListPrefer = {}}

	-- Prio research Industry and Infra above everything else

		local laTechWeights

		if Utils.HasCountryAIFunction(TechnologyData.ministerTag, "TechWeights") then
			laTechWeights = Utils.CallCountryAI(TechnologyData.ministerTag, "TechWeights", TechnologyData)
		elseif TechnologyData.IsNaval then
			laTechWeights = Utils.CallCountryAI("DEFAULT_MIXED", "TechWeights", TechnologyData)
		else
			laTechWeights = Utils.CallCountryAI("DEFAULT_LAND", "TechWeights", TechnologyData)
		end

		for i = 1, _RESEARCH_UNKNOWN_ do
			laPrimeTechAreas[i].ResearchWeight = laTechWeights[i]
		end




	-- Figure out what the AI currently is researching and count how many slots each category already uses
	for tech in TechnologyData.ministerCountry:GetCurrentResearch() do
		local lbFound = false
		local lsFolder = tostring(tech:GetFolder():GetKey())

		for i = 1, (_RESEARCH_UNKNOWN_ - 1) do
			local subLength = table.getn(laPrimeTechAreas[i].Folder)

			for subI = 1, subLength do
				-- If Tech folder found now exit both loops
				if lsFolder == laPrimeTechAreas[i].Folder[subI] then
					laPrimeTechAreas[i].CurrentSlots = laPrimeTechAreas[i].CurrentSlots + 1
					lbFound = true
					-- Set iteration vars to end values to break the loops
					subI = subLength
					i = _RESEARCH_UNKNOWN_
				end
			end
		end

		-- It is Uknown so process it special
	    if lbFound == false then
			laPrimeTechAreas[_RESEARCH_UNKNOWN_].CurrentSlots = laPrimeTechAreas[_RESEARCH_UNKNOWN_].CurrentSlots + 1
		end
	end



	for k, v in pairs(laPrimeTechAreas) do
		-- Retrieve Tech Ignore and Prefer Lists
		if Utils.HasCountryAIFunction(TechnologyData.ministerTag, v.ListName) then
			v.ListIgnore, v.ListPrefer =  Utils.CallCountryAI(TechnologyData.ministerTag, v.ListName, TechnologyData)
		else
			-- If their tech weights are land based and not country specific
			if TechnologyData.IsNaval then
				v.ListIgnore, v.ListPrefer =  Utils.CallCountryAI("DEFAULT_MIXED", v.ListName, TechnologyData)
			else
				v.ListIgnore, v.ListPrefer =  Utils.CallCountryAI("DEFAULT_LAND", v.ListName, TechnologyData)
			end
		end

		-- Calculate what the AI wants to research in each category based on the weights
		---  AI may put more slots in that it can research but thats no big deal
		v.ResearchSlots = math.max(0, Utils.Round((ResearchSlotsAllowed * v.ResearchWeight) - v.CurrentSlots))
	end

	-- Figure out what the AI can research
	for tech in CTechnologyDataBase.GetTechnologies() do
		if  TechnologyData.minister:CanResearch(tech) and tech:IsValid() then
			local nYear = TechnologyData.TechStatus:GetYear(tech, (TechnologyData.TechStatus:GetLevel(tech) + 1))

			-- Concentrate only on techs for the year requested or less
			--- Penalties are way to high to go into the future
			if nYear <= pYear then
				local liPrimeIndex = _RESEARCH_UNKNOWN_
				local lsFolder = tostring(tech:GetFolder():GetKey())

				for i = 1, (_RESEARCH_UNKNOWN_ - 1) do
					local subLength = table.getn(laPrimeTechAreas[i].Folder)

					for subI = 1, subLength do
						-- If Tech folder found now exit both loops
						if lsFolder == laPrimeTechAreas[i].Folder[subI] then
							subI = subLength
							liPrimeIndex = i
							i = _RESEARCH_UNKNOWN_
						end
					end
				end

				local lsTechName = tostring(tech:GetKey())
				local lsTechLevel = TechnologyData.TechStatus:GetLevel(tech)

				-- Fill up the research arrays
				if TechIgnore(lsTechLevel, lsTechName, laPrimeTechAreas[liPrimeIndex].ListIgnore) == false then
					if TechPrefer(lsTechName, laPrimeTechAreas[liPrimeIndex].ListPrefer) == false then
						table.insert(laPrimeTechAreas[liPrimeIndex].RegularTech, tech )
					else
						table.insert(laPrimeTechAreas[liPrimeIndex].PreferTech, tech )
					end
				end
			end
		end
	end

	-- Holds extra research slots that the AI is unable to use
	local liExtraSlots = ResearchSlotsNeeded

	for k, v in pairs(laPrimeTechAreas) do
		-- Calculate to see if we are going to have extra research slots left over
		liExtraSlots = liExtraSlots - v.ResearchSlots

		-- Perform the research and recapture the returning object
		v = ResearchTech(false, v)

		-- Recalculate now because it the ResearchSlots tells you how many
		--    have not been used so you need to re-add them into the ExtraSlots
		liExtraSlots = liExtraSlots + v.ResearchSlots
	end

	if liExtraSlots > 0 then
		for k, v in pairs(laPrimeTechAreas) do
			-- Use the RsearchSlots parm to control how many to research
			v.ResearchSlots = liExtraSlots

			-- Perform the research and recapture the returning object
			--   stick to prefer techs first
			v = ResearchTech(true, v)

			-- Grab the extra slots for the next set
			liExtraSlots = v.ResearchSlots
		end

		if liExtraSlots > 0 then
			for k, v in pairs(laPrimeTechAreas) do
				-- Use the RsearchSlots parm to control how many to research
				v.ResearchSlots = liExtraSlots

				-- Perform the research and recapture the returning object
				v = ResearchTech(false, v)

				-- Grab the extra slots for the next set
				liExtraSlots = v.ResearchSlots
			end

			-- There are still slots so jump into future techs
			if liExtraSlots > 0 then
				-- We have extra slots and no techs to research so go ahead and look into the future.
				Process_Tech((pYear + 3), pMaxYear, ResearchSlotsAllowed, liExtraSlots, recursion + 1)
			end
		end
	end
end

-- Decide if the tech is to be ignored or not
function TechIgnore(viTechLevel, vsTechName, vaIgnoreTechs)
	local lbIgnoreTech = false

	local i = 1
	local TableLength = table.getn(vaIgnoreTechs)

	-- Performance check
	if TableLength > 0 then
		-- Ignores every tech in teh category if set to "all"
		if vaIgnoreTechs[1] == "all" then
			lbIgnoreTech = true
		else
			-- Loop through the ignore list see if the tech is on it
			while i <= TableLength do
				if vsTechName == vaIgnoreTechs[i][1] then
					local TechLevel = vaIgnoreTechs[i][2]

					-- If the tech is the level specified or has it been marked for all levels
					---   then ignore it
					if viTechLevel >= TechLevel or TechLevel == 0 then
						lbIgnoreTech = true
						i = TableLength
					end
				end

				i = i + 1
			end
		end
	end

	return lbIgnoreTech
end

-- Check to see if the tech is on the prefer list
--   The number being returned is used to tell it which array to place it in
function TechPrefer(vsTechName, vaPreferTechs)
	-- 0 = normal research tech
	-- 1 = prefered research tech
	local lbPreferTech = false

	-- Performance check, if nil get out
	if not(vaPreferTechs == nil) then
		local i = 1
		local TableLength = table.getn(vaPreferTechs)

		-- Performance check
		if TableLength > 0 then
			-- Loop through the ignore list see if the tech is on it
			while i <= TableLength do
				-- Prefer Research tech now get out of the loop
				if vsTechName == vaPreferTechs[i] then
					lbPreferTech = true
					i = TableLength
				end
				i = i + 1
			end
		end
	end

	return lbPreferTech
end

-- Select a random tech from the array
function ResearchTech(vbPrioTechOnly, vaTechObject)
	-- Performance check make sure there is something to do
	if vaTechObject.ResearchSlots > 0 then
		local liNonPreferCount = table.getn(vaTechObject.RegularTech)
		local liPreferCount = 0

		-- Make sure there is a prefered tech option to process
		if not(vaTechObject.PreferTech == nil) then
			liPreferCount = table.getn(vaTechObject.PreferTech)
		end

		-- Ok first check now make sure one of the two main arrays has something
		if (liNonPreferCount > 0) or (liPreferCount > 0) then
			-- Normalize the max count for the loop as the request amount of techs can exceed what it has
			local liMainCount = math.min(vaTechObject.ResearchSlots, liPreferCount)

			-- Subtract what you are about to process
			vaTechObject.ResearchSlots = vaTechObject.ResearchSlots - liMainCount

			-- First process the Prefer techs
			local i = 0
			while i < liMainCount do
				local liTechSelected = math.random(liPreferCount - i)
				TechnologyData.ministerAI:Post(CStartResearchCommand(TechnologyData.ministerTag, vaTechObject.PreferTech[liTechSelected]))

				-- Remove the tech from the array
				table.remove(vaTechObject.PreferTech, liTechSelected)
				i = i + 1
			end

			-- If the vbPrioTechOnly is set to true then only process priority
			if vbPrioTechOnly == false then
				-- Now process the non-porefered techs
				--    normalize the loop count variable
				liMainCount = math.min(vaTechObject.ResearchSlots, liNonPreferCount)

				-- Subtract what you are about to process
				vaTechObject.ResearchSlots = vaTechObject.ResearchSlots - liMainCount

				i = 0
				while i < liMainCount do
					local liTechSelected = math.random(liNonPreferCount - i)
					TechnologyData.ministerAI:Post(CStartResearchCommand(TechnologyData.ministerTag, vaTechObject.RegularTech[liTechSelected]))
					-- Remove the tech from the array
					table.remove(vaTechObject.RegularTech, liTechSelected)

					i = i + 1
				end
			end
		end
	end

	return vaTechObject
end
