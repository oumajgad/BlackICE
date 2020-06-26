
-- #######################################
-- Production Overides the main LUA with country specific ones

-- Handle special Build Unit, the @@@ is the Unit type in string format
-- Build_@@@@@(ic, voProductionData, viUnitsNeeded)

-- #####################
-- Exepected Returns
-- IC = How much IC is left after execution
-- Boolean = Flag indicating weather to execute generic code as well for the building type
-- #####################
-- Build_Underground(ic, voProductionData)
-- Build_NuclearReactor(ic, voProductionData)
-- Build_RocketTest(ic, voProductionData)
-- Build_Industry(ic, voProductionData)
-- Build_CoastalFort(ic, voProductionData)
-- Build_Fort(ic, voProductionData)
-- Build_AntiAir(ic, voProductionData)
-- Build_Radar(ic, voProductionData)
-- Build_Infrastructure(ic, voProductionData)
-- Build_AirBase(ic, voProductionData)

-- must return how much IC is left


-- #######################################
-- Diplomacy Hooks
-- These all must return a numeric score (100 being 100% chance of success)

-- DiploScore_OfferTrade(voDiploScoreObj)
-- DiploScore_Alliance(voDiploScoreObj)
-- DiploScore_InviteToFaction(viScore, ai, actor, recipient, observer)
-- DiploScore_JoinFaction(viScore, minister, faction)
-- DiploScore_JoinFactionGoal(viScore, ai, actor, recipient, observer, goal )
-- DiploScore_InfluenceNation(voDiploScoreObj)
-- DiploScore_Guarantee(voDiploScoreObj)
-- DiploScore_Embargo(voDiploScoreObj)
-- DiploScore_NonAgression(voAI, voCountryOne, voCountryTwo,observer)
-- DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)
-- DiploScore_CallAlly(viScore, ai, actor, recipient, observer)
-- DiploScore_RequestLendLease(viScore, ai, actor, recipient, observer)
-- DiploScore_Debt(voDiploScoreObj)
-- EvaluateLimitedWar(viScore, minister, target, warDesirability)


--##########################
-- Foreign Minister Hooks

-- ForeignMinister_EvaluateDecision(voDecision, voForeignMinisterData)
-- ForeignMinister_CallAlly(voForeignMinisterData)
-- ForeignMinister_Alignment(voForeignMinisterData)
-- ForeignMinister_MilitaryAccess(voForeignMinisterData)
-- ForeignMinister_Influence(voForeignMinisterData)
-- ForeignMinister_ProposeWar(voForeignMinisterData)

--##########################
-- Politics Minister Hooks

-- HandleMobilization(minister)
-- HandlePuppets(minister)

-- Handle special Law cases, the @@@ is the law group name in string format
-- CallLaw_@@@@@(minister, loCurrentLaw)

-- Changing of Ministers
--    Each method is passed an array of ministers that can be put into the position
-- Call_ChiefOfAir(ministerCountry, vaMinisters)
-- Call_ChiefOfNavy(ministerCountry, vaMinisters)
-- Call_ChiefOfArmy(ministerCountry, vaMinisters)
-- Call_MinisterOfIntelligence(ministerCountry, vaMinisters)
-- Call_ChiefOfStaff(ministerCountry, vaMinisters)
-- Call_ForeignMinister(ministerCountry, vaMinisters)
-- Call_ArmamentMinister(ministerCountry, vaMinisters)
-- Call_MinisterOfSecurity(ministerCountry, vaMinisters)

-- #######################################
-- Intelligence Hooks

-- Intel_Home(voIntelligenceData)
-- Intel_Priority(voIntelligenceData, voIntelCountry)
-- Intel_Mission(voIntelligenceData, voIntelCountry)
-- Intel_Priority_Ally(voIntelligenceData, voIntelCountry)
-- Intel_Mission_Ally(voIntelligenceData, voIntelCountry)


local P = {}
AI_DEFAULT_LAND = P


-- #######################################
-- Start of Tech Research

-- Tech weights
--   1.0 = 100% the total needs to equal 1.0
function P.TechWeights(voTechnologyData)
	local laArray = {
		0.20, -- _RESEARCH_LAND_
		0.20, -- _RESEARCH_LAND_DOC_
		0.17, -- _RESEARCH_AIR_
		0.16, -- _RESEARCH_AIR_DOC_
		0.0, -- _RESEARCH_NAVAL_
		0.0, -- _RESEARCH_NAVAL_DOC_
		0.12, -- _RESEARCH_INDUSTRIAL_
		0.00, -- _RESEARCH_SECRET_
		0.15}; -- _RESEARCH_UNKNOWN_
	
	return laArray
end

function P.LandTechs(voTechnologyData)
	local ignoreTech = {
		{"garrison_deployment", 0},
		{"officer_recruitment_program", 0},
		{"emergency_recruitment_legislation", 0},
		{"airlanding_infantry_brigade_activation", 0},
		{"air_defense_network", 0},
		{"pack_artillery_brigade_activation", 0}, 
		{"airborne_artillery_brigade_activation", 0},
		{"rocket_art", 0}, 
		{"rocket_art_ammo", 0},
		{"sp_rct_art_brigade_design", 0},
		{"sp_anti_air_design", 0},
		{"AFV_AA_defense", 0},
		{"AA_AT_Rotation", 0},
		{"Artillery_fire_control_technics_dev", 0}, 
		{"tremendous_firepower_dev", 0},
		{"heavy_assault_gun_brigade_activation", 0}, 
		{"advanced_tank_chassis_design", 0},
		{"heavy_armor_brigade_design", 0},
		{"super_heavy_tank_design", 0},
		{"armor_alloy", 0},
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
		{"armor_sloped_design", 0},
		{"interlocked_armour", 0}, 
		{"tank_optics", 0},
		{"heavy_tank_destroyer_brigade_activation", 0}, 
		{"amph_armour_brigade_activation", 0},
		{"armored_engineers_brigade_activation", 0},
		{"machine_gun_doctrine", 0},
		{"urban_Fighting_Equipment_and_Training", 0},
		{"air_cavalry_brigade_activation", 0},
		{"ski_brigade_activation", 0},
		{"artic_warfare_equipment", 0},
		{"commando_brigade_activation", 0},
		{"air_commando_brigade_activation", 0},
		{"extreme_terrain_combat_tactics", 0},
		{"airbourne_warfare_research", 0},
		{"airborne_warfare_equipment", 0},
		{"anti_personel", 0}};	

	local preferTech = {
		"infantry_activation",
		"light_infantry_brigade_activation",
		"special_forces_upgrade",
		"Vehicle_reliability",
		"smallarms_technology",
		"infantry_support",
		"infantry_guns",
		"infantry_at",
		"semi_motorization"};
		
	return ignoreTech, preferTech
end

function P.LandDoctrinesTechs(voTechnologyData)
	local ignoreTech = {
		{"banzai", 0}, 
		{"human_wave", 0},
		{"mass_assault", 0}, 
		{"Auftragstaktik", 0},
		{"Befehlstaktik", 0},
		{"combined_arms_integration", 0},
		{"interservice_coordination", 0},
		{"interservice_communication", 0},
		{"pakfront", 0}, 
		{"superior_strength", 0},
		{"political_indoctrination", 0}, 
		{"political_integration", 0}};	
		
	local preferTech = {
		"infantry_integration",
		"infantry_training",
		"infantry_command_and_control",
		"homefront_coordination",
		"ww1_warfare"};
		
	return ignoreTech, preferTech
end

function P.AirTechs(voTechnologyData)
	local ignoreTech = {
		{"Flying_boat_activation", 0}, 
		{"naval_bomber_design", 0},
		{"air_commando_brigade_activation", 0},
		{"glider_activation", 0}, 
		{"jet_fighter_activation", 0},
		{"jet_airframe", 0},
		{"jet_engine", 0},
		{"jet_bomber_activation", 0},
		{"rocket_interceptor_tech", 0},
		{"advanced_aircraft_design", 0}, 
		{"self_sealing_tanks", 0},
		{"basic_four_engine_airframe", 0},  
		{"four_engine_bomber_crew_layout", 0},  
		{"gun_turrets",  0}, 
		{"four_engine_gunner_pos",  0}, 
		{"four_engine_gunner_strength", 0},
		{"four_engine_bomber_design",  0}, 
		{"four_engine_bombbay", 0},
		{"aircraft_armour", 0}};	

	local preferTech = {
		"single_engine_aircraft_design",
		"basic_aeroengine",
		"basic_small_fueltank",
		"basic_single_engine_airframe",
		"basic_aircraft_machinegun",
		"multirole_fighter_design",
		"twin_engine_aircraft_design",
		"basic_medium_fueltank",
		"basic_twin_engine_airframe",
		"basic_bomb",
		"small_bomb",
		"medium_bomb",
		"drop_tanks",
		"large_bomb",
		"large_fueltank",
		"basic_aircraft_design",
		"basic_aircraft_machinegun",
		"basic_engine",
		"aerodyn_fuselage",
		"aerodyn_wings",
		"engine_boost",
		"single_engine_aircraft_armament",
		"self_sealing_fueltanks",
		"air_cooling_sys",
		"drop_shaped_cockpit"};
		
	return ignoreTech, preferTech
end

function P.AirDoctrineTechs(voTechnologyData)
	local ignoreTech = {
		{"strategic_air_command", 0}, 
		{"airborne_assault_tactics", 0},
		{"naval_tactics", 0}, 
		{"naval_air_targeting", 0},
		{"navalstrike_tactics", 0},
		{"portstrike_tactics", 0},
		{"nav_groundcrew_training", 0},
		{"nav_pilot_training", 0},
		{"jet_groundcrew_training", 0}, 
		{"jet_pilot_training", 0},
		{"strategic_bombardment_tactics", 0}};	

	local preferTech = {
		"fighter_pilot_training",
		"interception_tactics",
		"cas_pilot_training",
		"cas_groundcrew_training",
		"ground_attack_tactics",
		"tac_pilot_training",
		"interdiction_tactics",
		"tactical_air_command"};		
		
	return ignoreTech, preferTech
end

function P.NavalTechs(voTechnologyData)
	local ignoreTech = {"all"};

	return ignoreTech, nil
end

function P.NavalDoctrineTechs(voTechnologyData)
	local ignoreTech = {"all"};
		
	return ignoreTech, nil
end

function P.IndustrialTechs(voTechnologyData)
	local ignoreTech = {
		{"atomic_research", 0}, 
		{"nuclear_research", 0},
		{"isotope_seperation", 0}, 
		{"civil_nuclear_research", 0},
		{"Ship_Building_Technologies", 0},
		{"submarine_construction_technolgies", 0},
		{"fuel_conservation", 0},
		{"octane_conservation", 0},
		{"advanced_resource_substitution", 0}, 
		{"advanced_construction_engineering", 0},
		{"gigant_infrastructure_projects", 0}, 
		{"monumental_architecture", 0},
		{"automotive_construction_industry", 0}};	

	local preferTech = {
		"agriculture",
		"industral_production",
		"industral_efficiency",
		"supply_production",
		"basic_education",
		"supply_transportation",
		"supply_organisation",
		"army_command_structure",
		"Corps_command_structure",
		"divisonal_command_structure",
		"brigade_command_structure",
		"schwerpunkt",
		"blitzkrieg",
		"civil_defence"};
		
	return ignoreTech, preferTech
end

function P.SecretWeaponTechs(voTechnologyData)
	local ignoreTech = {"all"}

	return ignoreTech, nil
end

function P.OtherTechs(voTechnologyData)
	local ignoreTech = {
		{"garrison_deployment", 0},
		{"emergency_recruitment_legislation", 0}};

		local preferTech = {
		"agriculture",
		"industral_production",
		"industral_efficiency",
		"supply_production",
		"education",
		"supply_transportation",
		"supply_organisation",
		"army_command_structure",
		"Corps_command_structure",
		"divisonal_command_structure",
		"brigade_command_structure",
		"schwerpunkt",
		"blitzkrieg ",
		"civil_defence"};
	return ignoreTech, preferTech
end
-- END OF TECH RESEARCH OVERIDES
-- #######################################

-- Land Brigades vs Air Units ratio
--   If Air Ratio is met AI will shift its Air IC to build land units
function P.LandToAirRatio(voProductionData)
	local laArray = {
		5, -- Land Briages
		1}; -- Air
	
	return laArray
end

function P.ProductionWeights(voProductionData)
	local laArray
	if (voProductionData.ManpowerTotal < 40 and voProductionData.LandCountTotal > 60)
	or voProductionData.ManpowerTotal < 10 then
		laArray = {
			0.0, -- Land
			0.70, -- Air
			0.0, -- Sea
			0.30}; -- Other	
	elseif voProductionData.IsAtWar then
		laArray = {
			0.60, -- Land
			0.35, -- Air
			0.0, -- Sea
			0.05}; -- Other
	else
		laArray = {
			0.40, -- Land
			0.20, -- Air
			0.0, -- Sea
			0.40}; -- Other
	end
	
	return laArray
end

-- Land ratio distribution
function P.LandRatio(voProductionData)
local laArray
	if voProductionData.Year < 1940 then
		laArray = {
			infantry_brigade = 3,
			semi_motorized_brigade = 1,
			garrison_brigade = 2,
			armor_brigade = 1,
			cavalry_brigade = 1,
			light_armor_brigade = 1};
	else
		laArray = {
			infantry_brigade = 3,
			semi_motorized_brigade = 1,
			garrison_brigade = 2,
			armor_brigade = 1};
	end

	-- If very low IC dont produce expensive divisions
	if voProductionData.icAvailable < 40 then
		laArray.armor_brigade = 0
		laArray.semi_motorized_brigade = 0
		laArray.light_armor_brigade = 0
	end

	return laArray
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = {
		40, -- Land
		1}; -- Special Force Unit

	local laUnits = {
		bergsjaeger_brigade = 1,
		paratrooper_brigade = 0.5};
	
	return laRatio, laUnits	
end

-- Which units should get 1 more Support unit with Superior Firepower tech
--- Firepower is on ignore list but just in case human player researches it
function P.FirePower(voProductionData)
	local laArray = {"infantry_brigade"};
		
	return laArray
end

-- Air ratio distribution
function P.AirRatio(voProductionData)
	local laArray = {
		interceptor = 5,
		multi_role = 3,
		cas = 1,
		tactical_bomber = 3};
		--twin_engine_fighters = 1};
	
	return laArray
end

-- Flying Bomb/Rocket distribution against total Air Power
function P.RocketRatio(voProductionData)
	local laArray = {
		20, -- Air
		1}; -- Bomb/Rockety
	
	return laArray
end

-- Naval ratio distribution
function P.NavalRatio(voProductionData)
	local laArray = {}
	
	return laArray
end

-- Transport to Land unit distribution
function P.TransportLandRatio(voProductionData)
	local laArray = {
		0, -- Land
		0,  -- transport
		0}  -- invasion craft
  
	return laArray
end

-- Convoy Ratio control
--- NOTE: If goverment is in Exile these parms are ignored
function P.ConvoyRatio(voProductionData)
	local laArray = {
		0, -- Percentage extra (adds to 100 percent so if you put 10 it will make it 110% of needed amount)
		5, -- If Percentage extra is less than this it will force it up to the amount entered
		10, -- If Percentage extra is greater than this it will force it down to this
		5} -- Escort to Convoy Ratio

  
	return laArray
end



-- Do not build Rocket Sites
function P.Build_RocketTest(ic, voProductionData)
	-- Only build Rocket Sites if 1943 or greater
	if voProductionData.Year <= 1942 then
		return ic, false
	else
		-- Small Country so wait till 1945 before we worry about this
		if (voProductionData.icTotal < 50 and voProductionData.Year <= 1945) then
			return ic, false
		end
	end
	
	return ic, true	
end

return AI_DEFAULT_LAND
