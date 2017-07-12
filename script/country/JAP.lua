local P = {}
AI_JAP = P

-- #######################################
-- Start of Trade Weights
function P.TradeWeights(voResourceData)
	local laResouces = {
		METAL = {
			Buffer = 2,
			BufferSaleCap = 5000},
		ENERGY = {
			BufferSaleCap = 5000},
		RARE_MATERIALS = {
			Buffer = 2,
			BufferSaleCap = 5000},
		CRUDE_OIL = {
			Buffer = 2,
			BufferSaleCap = 10000},
		FUEL = {
			Buffer = 2,
			BufferSaleCap = 10000}}
	
	return laResouces
end

-- #######################################
-- Static Production Variables overide

-- Techs that are used in the main file to be ignored
--   techname|level (level must be 1-9 a 0 means ignore all levels
--   use as the first tech name the word "all" and it will cause the AI to ignore all the techs
function P.LandToAirRatio(voProductionData)
	local laArray = {
		5, -- Land Brigades
		1}; -- Air
	
	return laArray
end

-- Tech weights
--   1.0 = 100% the total needs to equal 1.0
function P.TechWeights(voTechnologyData)
	local laTechWeights = {
		0.10, -- landBasedWeight
		0.14, -- landDoctrinesWeight
		0.12, -- airBasedWeight
		0.11, -- airDoctrinesWeight
		0.18, -- navalBasedWeight
		0.10, -- navalDoctrinesWeight
		0.10, -- industrialWeight
		0.03, -- secretWeaponsWeight
		0.12}; -- otherWeight
	
	return laTechWeights
end

-- Techs that are used in the main file to be ignored
--   techname|level (level must be 1-9 a 0 means ignore all levels
--   use as the first tech name the word "all" and it will cause the AI to ignore all the techs
function P.LandTechs(voTechnologyData)
	local ignoreTech = {
		{"airlanding_infantry_brigade_activation", 0}, 
		{"air_commando_brigade_activation", 0},
		{"paratrooper_infantry", 0}, 
		{"sp_artillery_brigade_design", 0},
		{"sp_rct_art_brigade_design", 0},
		{"militia_increase", 0},
		{"infantry_increase", 0},
		{"special_forces_increase", 0},
		{"mobile_increase", 0},
		{"armor_increase", 0},
		{"recon_increase", 0},
		{"artillery_increase", 0},
		{"armorsupport_increase", 0},
		{"aa_at_increase", 0},
		{"engineers_increase", 0},
		{"militia_decrease", 0},
		{"infantry_decrease", 0},
		{"special_forces_decrease", 0},
		{"mobile_decrease", 0},
		{"armor_decrease", 0}, 
		{"recon_decrease", 0},
		{"artillery_decrease", 0},
		{"armorsupport_decrease", 0},
		{"aa_at_decrease", 0},
		{"engineers_decrease", 0},
		{"sp_anti_air_design", 0},
		{"ski_brigade_activation", 0},
		{"airborne_warfare_equipment", 0},
		--{"garrison_deployment", 0}
		};
		
	local preferTech = {
		"jungle_warfare_equipment",
		"mountain_warfare_equipment",
		"extreme_terrain_combat_tactics",
		"infantry_activation",
		"light_infantry_brigade_activation",
		"special_forces_upgrade",
		"Vehicle_reliability",
		"semi_motorization",
		"infantry_at",
		"marine_infantry",
		"infantry_guns",
		"smallarms_technology",
		"extreme_terrain_combat_tactics",
		"light_armor_brigade_design",
		"medium_velocity_gun",
		"art_barrell_ammo"};
		
	return ignoreTech, preferTech
end

function P.LandDoctrinesTechs(voTechnologyData)
	local ignoreTech = {
		{"combined_arms_integration", 0},
		{"interservice_coordination", 0},
		{"interservice_communication", 0},
		{"political_integration", 0},
		{"mixed_support_artillery_upgrade", 0},
		{"mixed_support_medium_artillery_upgrade", 0},
		{"mixed_support_heavy_artillery_upgrade", 0},
		{"mixed_support_rocket_artillery_upgrade", 0}
		};
		
	local preferTech = {
		"banzai",
		"amphibious_command_and_control",
		"amphibious_training",
		"special_forces_integration",
		"jungle_training",
		"infantry_integration",
		"infantry_training",
		"infantry_command_and_control",
		"mountain_training",
		"mountain_command_and_control",
		"military_police",
		"jungle_command_and_control",
		"partisan_suppression",
		"stormtrooper_tactics",
		"supreme_command_coordination",
		"brigade_command_structure",
		"interservice_HQ_structure",
		"artillery_integration",
		"artillery_training",
		"artillery_command_and_control",
		"combined_arms_integration",
		"homefront_coordination",
		"airborne_training",
		"airborne_command_and_control",
		"artillery_barrage",
		"artillery_flexiblity",
		"assault_concentration",
		"superior_firepower",
		"spearhead",
		"blitzkrieg",
		"schwerpunkt",
		"divisonal_command_structure",
		"Corps_command_structure",
		"army_command_structure",
		"armygroup_command_structure",
		"supreme_command_coordination",
		"interservice_HQ_structure",
		"elastic_defense"
		"mixed_support_pack_artillery_upgrade"
		};
		
	return ignoreTech, preferTech
end

function P.AirTechs(voTechnologyData)
	local ignoreTech = {
		{"basic_strategic_bomber", 0},
		{"four_engine_airframe", 0},
		{"cargo_hold", 0},
		{"large_bomb", 0},
		{"four_engine_bomber_design", 0},
		{"four_engine_bombbay", 0},
		{"large_fueltank", 0},
		{"basic_four_engine_airframe", 0},
		{"four_engine_airframe", 0},
		{"four_engine_bomber_crew_layout", 0},
		{"air_refueling_plane_design", 0},
		{"AA_ordnance", 0},
		{"four_engine_gunner_pos", 0},
		{"four_engine_gunner_strength", 0},
		{"gun_turrets", 0},
		{"dam_bust_bomb", 0},
		{"tallboy_bomb", 0},
		{"grandslam_bomb", 0},
		{"in_air_refueling", 0},
		{"strategic_bomber_armament", 0},
		{"advanced_aircraft_development", 0},
		{"glider_activation", 0}
	};

	local preferTech = {
		"basic_aeroengine",
		"basic_small_fueltank",
		"basic_single_engine_airframe",
		"basic_aircraft_machinegun",
		"basic_medium_fueltank",
		"basic_twin_engine_airframe",
		"basic_aircraft_design",
		"single_engine_aircraft_design",
		"single_engine_airframe",
		"cas_design",
		"multirole_fighter_design",
		"twin_engine_aircraft_design",
		"twin_engine_bomber_design",
		"twin_engine_aircraft_armament", 
		"twin_engine_airframe",
		"naval_bomber_design",
		"single_engine_aircraft_armament",
		"aeroengine",
		"small_fueltank",
		"medium_fueltank",
		"retractable_undercarriage",
		"cag_design",
		"cag_fighter", 
		"cag_bomber",
		"cag_torpedo",
		"tailhook",
		"folding_wings",
		"basic_bomb",
		"small_bomb",
		"medium_bomb",		
		"air_launched_torpedo",
		"aerodyn_fuselage",
		"aerodyn_wings",
		"engine_boost",
		"self_sealing_fueltanks",
		"air_cooling_sys",
		"drop_shaped_cockpit",
		"wing_guns",
		"ammo_capacity",
		"auto_cannons"
	};
		
	return ignoreTech, preferTech
end

function P.AirDoctrineTechs(voTechnologyData)
	local ignoreTech = {
		{"forward_air_control", 0},
		{"battlefield_interdiction", 0},
		{"bomber_targerting_focus", 0},
		{"fighter_targerting_focus", 0}, 
		{"airborne_assault_tactics", 0}};

	local preferTech = {
		"fighter_pilot_training",
		"interception_tactics",
		"ground_attack_tactics",
		"tac_pilot_training",
		"interdiction_tactics",
		"tactical_air_command",
		"nav_pilot_training",
		"portstrike_tactics",
		"navalstrike_tactics",
		"naval_air_targeting",
		"naval_tactics"};		
		
	return ignoreTech, preferTech
end
		
function P.NavalTechs(voTechnologyData)
	local ignoreTech = {
		{"battlecruiser_technology", 0},
		{"battleship_technology", 0},
		{"battlecruiser_antiaircraft", 0},
		{"battlecruiser_engine", 0},
		{"battlecruiser_armour", 0}};

	local preferTech = {
		"transport_ship_activation",
		"transport_ship_hull",
		"transport_ship_engine",
		"amphibious_invasion_craft",
		"advanced_invasion_craft",
		"amphibious_invasion_tactics",
		"amphibious_ship_defenses",
		"cag_development",
		"escort_carrier_technology",
		"carrier_technology",
		"carrier_antiaircraft",
		"torpedo_upgrade",
		"carrier_engine",
		"carrier_armour",
		"carrier_hanger"};		
		
	return ignoreTech, preferTech
end
		
function P.NavalDoctrineTechs(voTechnologyData)
	local ignoreTech = {};

	local preferTech = {
		"fleet_auxiliary_carrier_doctrine",
		"light_cruiser_escort_role",
		"carrier_group_doctrine",
		"light_cruiser_crew_training",
		"carrier_crew_training",
		"carrier_task_force",
		"naval_underway_replenishment",
		"radar_training",
		"sea_lane_defence",
		"destroyer_escort_role",
		"battlefleet_concentration_doctrine",
		"destroyer_crew_training",
		"battleship_crew_training",
		"commerce_defence",
		"fire_control_system_training",
		"commander_decision_making",
		"cruiser_warfare",
		"cruiser_crew_training",
		"spotting",
		"basing"};
		
	return ignoreTech, preferTech
end

function P.IndustrialTechs(voTechnologyData)
	local ignoreTech = {
		{"atomic_research", 0},
		{"nuclear_research", 0},
		{"isotope_seperation", 0},
		{"civil_nuclear_research", 0}};

	local preferTech = {
		"construction_engineering",
		"supply_transportation",
		"supply_organisation",
		"secretary_of_public_information_and_education",
		"mass_events",
		"monumental_architecture",
		"broadcasting",
		"university",
		"gigant_infrastructure_projects",
		"agriculture",
		"industral_production",
		"industral_efficiency",
		"industry_tech",
		"civil_medicine",
		"Ship_Building_Technologies",
		"long_range_aircraft_production",
		"short_range_aircraft_production",
		"oil_refinning",
		"steel_production",
		"coal_processing_technologies",
		"supply_production",
		"university",
		"raremetal_refinning_techniques",
		"civil_defence",
		"logistical_warfare_focus",
		"home_front_focus",
		"combat_medicine",
		"first_aid",
		"medical_evacuation",
		"secretary_of_public_information_and_education",
		"broadcasting",
		"monumental_architecture",
		"expand_airbases",
		"Hangar_Maintenance",
		"hardended_airstrip",
		"control_tower",
		"basic_education"};
			
	return ignoreTech, preferTech
end
		
function P.SecretWeaponTechs(voTechnologyData)
	local ignoreTech = {}
	
	return ignoreTech
end

function P.OtherTechs(voTechnologyData)
	local ignoreTech = {
		{"large_airsearch_radar", 0},
		{"emergency_recruitment_legislation", 0},
		{"large_navagation_radar", 0}};

	local preferTech = {
		"radio_technology",
		"amphibious_invasion_focus",
		"Ship_Building_Technologies",
		"supply_transportation",
		"supply_organisation",
		"banzai",
		"stormtrooper_tactics",
		"supreme_command_coordination",
		"brigade_command_structure",
		"interservice_HQ_structure",
		"political_indoctrination",
		"civil_defence",
		"electronic_computing_machine",
		"mechnical_computing_machine"};			

	return ignoreTech, preferTech
end

-- END OF TECH RESEARCH OVERIDES
-- #######################################

-- #######################################
-- Production Overides the main LUA with country specific ones

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray
	
	-- Check to see if manpower is to low
	-- More than 150 brigades so build stuff that does not use manpower
	if voProductionData.ManpowerTotal < 250 then
		laArray = {
			0.0, -- Land
			0.54, -- Air
			0.45, -- Sea
			0.01}; -- Other	
	elseif (voProductionData.ManpowerTotal < 500 and voProductionData.LandCountTotal > 250) then
		laArray = {
			0.10, -- Land
			0.47, -- Air
			0.42, -- Sea
			0.01}; -- Other	
	
	elseif voProductionData.Year <= 1939 then
		laArray = {
			0.50, -- Land
			0.15, -- Air
			0.30, -- Sea
			0.05}; -- Other
	else
		laArray = {
			0.40, -- Land
			0.15, -- Air
			0.40, -- Sea
			0.05}; -- Other
	end
	
	return laArray
end
-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray = {
		garrison_brigade = 1,
		cavalry_brigade = 1,
		infantry_brigade = 8};
	
	return laArray
end



-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laUnits = nil
	local lbMarine = voProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("marine_brigade"))
	local laRatio = {
		6, -- Land
		2}; -- Special Force Unit
	
	if lbMarine then
		laUnits = {
				marine_brigade = 5,
				bergsjaeger_brigade = 0.2};
	end

	-- Returning a nul for laUnits means no Special forces will be built
	return laRatio, laUnits
end

-- Elite Units


-- Which units should get 1 more Support unit with Superior Firepower tech
--- Firepower is on ignore list but just in case human player researches it
function P.FirePower(voProductionData)
	local laArray = {
		"marine_brigade",
		"infantry_brigade"};
		
	return laArray
end

-- Air ratio distribution
function P.AirRatio(voProductionData)
	local laArray = {
		interceptor = 3,
		multi_role = 4,
		cas = 0,
		tactical_bomber = 2,
		naval_bomber = 4,
		Flying_boat = 0.1,
		rocket_interceptor = 1,
		twin_engine_fighters = 1};
	
	return laArray
end

-- Naval ratio distribution
function P.NavalRatio(voProductionData)
	local laArray = {
		destroyer_actual = 10,
		submarine = 4,
		nuclear_submarine = 1,
		light_cruiser = 9,
		heavy_cruiser = 4,
		battleship = 1.5,
		escort_carrier = 1,
		seaplane_tender = 0.5,
		carrier = 3};
	
	return laArray
end

-- Transport to Land unit distribution
function P.TransportLandRatio(voProductionData)
	local laArray = {
		25, -- Land
		1,  -- transport
		1}  -- invasion craft
  
	return laArray
end

-- Convoy Ratio control
--- NOTE: If goverment is in Exile these parms are ignored
function P.ConvoyRatio(voProductionData)
	local laArray = {
		10, -- Percentage extra (adds to 100 percent so if you put 10 it will make it 110% of needed amount)
		100, -- If Percentage extra is less than this it will force it up to the amount entered
		200, -- If Percentage extra is greater than this it will force it down to this
		5} -- Escort to Convoy Ratio (Number indicates how many convoys needed to build 1 escort)
  
	return laArray
end

function P.Build_Industry(vIC, voProductionData)
	if voProductionData.Year > 1942 then
		return vIC, false
	end

	return vIC, true	
end

function P.Build_CoastalFort(vIC, voProductionData)

		return vIC, false
	
end

function P.Build_AirBase(vIC, voProductionData)

	return vIC, true	
end

function P.Build_NavalBase(vIC, voProductionData)
	if voProductionData.Year < 1942 then
		return vIC, false
	end

	return vIC, true	
end

function P.Build_Radar(vIC, voProductionData)


	return vIC, true	
end

function P.Build_AntiAir(vIC, voProductionData)

	return vIC, false	
end

function P.Build_Infrastructure(vIC, voProductionData)
	if voProductionData.Year < 1942 then
		return vIC, false
	end

	return vIC, true	
end

function P.Build_Fort(vIC, voProductionData)
	if voProductionData.Year < 1942 then
		return vIC, false
	end

	return vIC, true	
end
		
-- END OF PRODUTION OVERIDES
-- #######################################

function P.DiploScore_InfluenceNation(voDiploScoreObj)
	-- Only do this if we are in the allies
	if voDiploScoreObj.FactionName == "axis" then
		local loInfluences = {
			SIA = {Score = 100}}	
	
		-- Are they on our list
		if loInfluences[voDiploScoreObj.TargetName] then
			return (voDiploScoreObj.Score + loInfluences[voDiploScoreObj.TargetName].Score)
		end
	end

	return voDiploScoreObj.Score	
end

function P.DiploScore_Embargo(voDiploScoreObj)
	if tostring(voDiploScoreObj.EmbargoTag) == "SOV" then
		-- We must be in the Axis
		if voDiploScoreObj.Faction == CCurrentGameState.GetFaction("axis") then
			-- They must be in the comintern
			if voDiploScoreObj.EmbargoCountry:GetFaction() == CCurrentGameState.GetFaction("comintern") then
				-- Do not embargo Russia under any circumstances other than war
				voDiploScoreObj.Score = 0
			end
		end
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		SIA = {Score = 100},
		USA = {Score = 150},
		ENG = {Score = 150},
		FRA = {Score = 50},
		HOL = {Score = 150}}
	
	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	else
		-- If we are the buyer dont bother as we wont get our stuff but we can sell to them
		if tostring(voDiploScoreObj.BuyerTag) == voDiploScoreObj.TagName then
			-- If we are atwar dont do buy trades (sell is ok)
			if voDiploScoreObj.BuyerCountry:IsAtWar() then
				if voDiploScoreObj.SellerContinent ~= voDiploScoreObj.BuyerContinent and not(voDiploScoreObj.IsNeighbor) then
					return 0
				end
			end
		end
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	-- If we are not part of the same ideology as the requesting country do not even consider it
	if not(voDiploScoreObj.IdeologyGroup == voDiploScoreObj.TargetIdeologyGroup) then
		voDiploScoreObj.Score = 0
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_Alliance(voDiploScoreObj)
	-- If we are not part of the same ideology as the requesting country do not even consider it
	if not(voDiploScoreObj.IdeologyGroup == voDiploScoreObj.TargetIdeologyGroup) then
		voDiploScoreObj.Score = 0
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_NonAgression(viScore, voAI, voCountryOne, voCountryTwo, voObserverTag)
	-- If we are at war
	if voCountryOne.IsAtWar then
		local loAxis = CCurrentGameState.GetFaction("axis")
		
		-- If we are part of the Axis
		if voCountryOne.Faction == loAxis then
			local loComintern = CCurrentGameState.GetFaction("comintern")
			
			-- If Soviets are in the Comintern
			if tostring(voCountryTwo.ministerTag) == "SOV"
			and voCountryTwo.Faction == loComintern then
				local chiTag = CCountryDataBase.GetTag("CHI")
				local loChiCountry = chiTag:GetCountry()
				local loChiJapRelation = voCountryOne.ministerCountry:GetRelation(chiTag)
				
				-- If we are at war with China sign a pact with Russia
				if loChiJapRelation:HasWar()
				and not(loChiCountry:IsGovernmentInExile())
				and loChiCountry:Exists() then
					viScore = 100
				else
					-- Go through our current wars if we are atwar with another major power stay away from the Soviets
					for loEnemyTag in voCountryOne.ministerCountry:GetCurrentAtWarWith() do
						local loEnemyCountry = loEnemyTag:GetCountry()
						
						-- We are atwar with another major power so yes we want a NAP
						if loEnemyCountry:IsMajor() then
							viScore = 100
							break
						end
					end
				end
			end
		end
	end
	
	return viScore
end

--##########################
-- Foreign Minister Hooks
function P.ForeignMinister_EvaluateDecision(voDecision, voForeignMinisterData)
	if voDecision.Name == "marco_polo_bridge_incident" then
		local loCYNTag = CCountryDataBase.GetTag("CYN") -- Yunan
		local loCGXTag = CCountryDataBase.GetTag("CGX") -- Guang Cliquxe
		local loCSXTag = CCountryDataBase.GetTag("CSX") -- Shanxi
		local loCHITag = CCountryDataBase.GetTag("CHI") -- China
		local lolCHCTag = CCountryDataBase.GetTag("CHC") -- Communist China
		
		voForeignMinisterData.Strategy:PrepareWarDecision(loCSXTag, 100, voDecision.Decision, false)
		voForeignMinisterData.Strategy:PrepareWarDecision(loCHITag, 100, voDecision.Decision, false)
		voForeignMinisterData.Strategy:PrepareWarDecision(lolCHCTag, 100, voDecision.Decision, false)
		voForeignMinisterData.Strategy:PrepareWarDecision(loCGXTag, 100, voDecision.Decision, false)
		voForeignMinisterData.Strategy:PrepareWarDecision(loCYNTag, 100, voDecision.Decision, false)
		voDecision.Score = voDecision.Score + 100
	
	end
	
	return voDecision.Score
end

function P.ForeignMinister_ProposeWar(voForeignMinisterData)
	local lsIdeology = voForeignMinisterData.ministerCountry:GetRulingIdeology():GetGroup():GetKey()

	-- Japan just make sure their Ideology is leaning toward Fascist as they may not be part of the Axis
	if lsIdeology == "fascist" or voForeignMinisterData.FactionName == "axis" then
		local liMajorWars = 0
		local laMajorWars = {}
	
		-- Which Major powers are we at war with
		for loTargetCountry in CCurrentGameState.GetCountries() do
			local loTargetTag = loTargetCountry:GetCountryTag()
			
			-- If we are already at war with another major power save the information
			if loTargetCountry:IsMajor() then
				local loRelation = voForeignMinisterData.ministerCountry:GetRelation(loTargetTag)
				
				if loRelation:HasWar() then
					liMajorWars = liMajorWars + 1
					laMajorWars[tostring(loTargetTag)] = {
						Tag = loTargetTag,
						Country = loTargetCountry,
						Relation = loRelation}
				end
			end
		end
		
		local loAxisTag = CCurrentGameState.GetFaction("axis"):GetFactionLeader()
		local loCominternTag = CCurrentGameState.GetFaction("cominterm"):GetFactionLeader()
		local lbPreparingWar = false -- Make sure that we do not check other war conditions
		
		-- If we are not at war with any Major powers consider this
		if liMajorWars == 0 then
			local loCominternCountry = loCominternTag:GetCountry()
				
			-- Make sure Axis and Cominterm are at war
			if loCominternCountry:GetRelation(loAxisTag):HasWar() then
				
				-- Now check if we actually can DOW the Soviets
				local lbDOW = Support.GoodToWarCheck(loCominternTag, loCominternCountry, voForeignMinisterData, false, true)
			
				if lbDOW then
					-- Are the communist in trouble and if so lets DOW
					if loCominternCountry:CalcDesperation():Get() > 0.4 then
						voForeignMinisterData.Strategy:PrepareLimitedWar(loCominternTag, 100)
						lbPreparingWar = true
					end
				end
			end
			
			-- Check to see if USA is in the war early
			if not(lbPreparingWar) then
				local loUSATag = CCountryDataBase.GetTag("USA")
				local loUSACountry = loUSATag:GetCountry()
				
				-- Check to see if the USA is at war with the axis
				if loUSACountry:GetRelation(loAxisTag):HasWar() then
					-- They are at war with the Axis so come help them
					if Support.GoodToWarCheck(loUSATag, loUSACountry, voForeignMinisterData, true, true) then
						voForeignMinisterData.Strategy:PrepareLimitedWar(loUSATag, 100)
					end
				end
			end
		end
		
		-- We are not at war with Axis or Comintern
		if not(lbPreparingWar) then
			if not(laMajorWars[tostring(loCominternTag)]) and not(laMajorWars[tostring(loAxisTag)]) then
				if ((voForeignMinisterData.Year >= 1942) and (voForeignMinisterData.Month >= 10)) or (voForeignMinisterData.Year >= 1943) then
					for k, v in pairs(P.WarTargetList(voForeignMinisterData)) do
						-- DOW Everyone we can
						if Support.GoodToWarCheck(v.Tag, v.Country, voForeignMinisterData, true, true) then
							voForeignMinisterData.Strategy:PrepareLimitedWar(v.Tag, 100)
						end
					end		
				
				-- Early War if we are Embargo lets do it!
				elseif ((voForeignMinisterData.Year >= 1941) and (voForeignMinisterData.Month >= 10)) or (voForeignMinisterData.Year >= 1942) then
					-- Do any of them have me on Embargo
					for k, v in pairs(P.WarTargetList(voForeignMinisterData)) do
						local loTargetRelation = v.Country:GetRelation(voForeignMinisterData.ministerTag)
						
						-- DOW the ones who have us on Embargo
						if loTargetRelation:HasEmbargo() and not(loTargetRelation:HasWar()) then
							if Support.GoodToWarCheck(v.Tag, v.Country, voForeignMinisterData, true, true) then
								voForeignMinisterData.Strategy:PrepareLimitedWar(v.Tag, 100)
							end
						end
					end
				end
			end
		end
	end
end

function P.WarTargetList(voForeignMinisterData)
	local laTargetProvinces = {
		CCurrentGameState.GetProvince(5825):GetController(), -- Honolulu
		CCurrentGameState.GetProvince(6394):GetController(), -- Singapore
		CCurrentGameState.GetProvince(6236):GetController(), -- Saigon
		CCurrentGameState.GetProvince(6142):GetController(), -- Manila
		CCurrentGameState.GetProvince(6507):GetController(), -- Batavia
		CCurrentGameState.GetProvince(5868):GetController(), -- Hong Kong
		CCurrentGameState.GetProvince(6467):GetController()} -- Raboul
	
	local laTargetTags = {}
	
	for i = 1, table.getn(laTargetProvinces) do
		-- Make sure no duplicate country stored in array
		if voForeignMinisterData.ministerTag ~= laTargetProvinces[i] then
			if not(laTargetTags[tostring(laTargetProvinces[i])]) then
				laTargetTags[tostring(laTargetProvinces[i])] = {
					Tag = laTargetProvinces[i],
					Country = laTargetProvinces[i]:GetCountry()}
			end
		end
	end
	
	return laTargetTags
end

function P.ForeignMinister_Influence(voForeignMinisterData)
	local laIgnoreWatch -- Ignore this country but monitor them if they are about to join someone else
	local laWatch -- Monitor them and also find their score is high enough they can be influenced normally
	local laIgnore -- Ignore them completely

	if voForeignMinisterData.FactionName == "axis" then
		laWatch = { "SIA",
					"BEL", -- Belgium
					"HOL"} -- Holland
		laIgnore = {}
		
		-- Make a list of countries that are not in Asia and ignore them
		for loTCountry in CCurrentGameState.GetCountries() do
			if loTCountry:Exists() then
				-- If they are not in Asia then ignore them
				if tostring(loTCountry:GetActingCapitalLocation():GetContinent():GetTag()) ~= "asia" then
					table.insert(laIgnore, tostring(loTCountry:GetCountryTag()))
				end
			end
		end	
	end
	
	return laWatch, laIgnoreWatch, laIgnore
end


-- Garrison builds - GAR+(ART|HVYART)+SUPPORTSx2 ("Garrison" Support Group)

function P.Build_garrison_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	
	if (math.random(100) < 15) then
		voType.TertiaryMain = "heavy_artillery_brigade"
		voType.SupportGroup = "Garrison"
		voType.Support = 2
	else
		voType.TertiaryMain = "artillery_brigade"
		voType.SupportGroup = "Garrison"
		voType.Support = 2
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end


return AI_JAP
