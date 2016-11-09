
local P = {}
AI_NZL = P
-- #######################################
-- Start of Tech Research
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
		{"armored_engineers_brigade_activation", 0},
		{"machine_gun_doctrine", 0},
		{"Panzerfaust_Bazooka_AT_Tech", 0},
		{"urban_Fighting_Equipment_and_Training", 0},
		{"air_cavalry_brigade_activation", 0},
		{"ski_brigade_activation", 0},
		{"artic_warfare_equipment", 0},
		{"air_commando_brigade_activation", 0},
		{"extreme_terrain_combat_tactics", 0},
		{"airbourne_warfare_research", 0},
		{"airborne_warfare_equipment", 0},
		{"medium_tank_destroyer_brigade_activation", 0},
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
		{"basic_strategic_bomber", 0},
		{"large_fueltank", 0},
		{"four_engine_airframe", 0},
		{"basic_strategic_bomber", 0},
		{"cargo_hold", 0},
		{"air_commando_brigade_activation", 0},
		{"large_bomb", 0}};

	local preferTech = {
		"large_fueltank", 
		"cag_design",
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
		"nav_development",
		"large_bomb",
		"large_fueltank",
		"air_launched_torpedo",
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
		{"forward_air_control", 0},
		{"battlefield_interdiction", 0},
		{"bomber_targerting_focus", 0},
		{"fighter_targerting_focus", 0}, 
		{"heavy_bomber_pilot_training", 0},
		{"heavy_bomber_groundcrew_training", 0},
		{"strategic_bombardment_tactics", 0},
		{"airborne_assault_tactics", 0},
		{"strategic_air_command", 0}};

	local preferTech = {
		"fighter_pilot_training",
		"interception_tactics",
		"cas_pilot_training",
		"cas_groundcrew_training",
		"ground_attack_tactics",
		"tac_pilot_training",
		"interdiction_tactics",
		"naval_tactics",  
		"naval_air_targeting",
		"navalstrike_tactics", 
		"portstrike_tactics",
		"nav_groundcrew_training", 
		"nav_pilot_training", 
		"tactical_air_command"};		
		
	return ignoreTech, preferTech
end

function P.NavalTechs(voTechnologyData)
	local ignoreTech = {
		{"battlecruiser_technology", 0},
		{"milch_submarine", 0},
		{"battlecruiser_engine", 0},
		{"battlecruiser_armour", 0},
		{"super_heavy_battleship_technology", 0},
		{"cag_development", 0},
		{"escort_carrier_technology", 0},
		{"carrier_technology", 0},
		{"carrier_antiaircraft", 0},
		{"carrier_engine", 0},
		{"carrier_armour", 0},
		{"AAA_control_computer", 0},
		{"pocket_battleship_activation", 0},
		{"carrier_deck_armour_optimisation", 0},
		{"carrier_flight_deck_optimisation", 0}, 
		{"submarine_snorkel", 0},
		{"submarine_electroboat", 0},
		{"midget_submarine_activation", 0},
		{"carrier_hanger", 0}};

	local preferTech = {
		"destroyer_technology",
		"destroyer_armament",
		"destroyer_antiaircraft",
		"destroyer_engine",
		"destroyer_armour"};		
		
	return ignoreTech, preferTech
end

function P.NavalDoctrineTechs(voTechnologyData)
	local ignoreTech = {
		{"fleet_auxiliary_carrier_doctrine", 0},
		{"light_cruiser_escort_role", 0},
		{"light_cruiser_crew_training", 0},
		{"carrier_group_doctrine", 0},
		{"carrier_crew_training", 0},
		{"carrier_task_force", 0},
		{"naval_underway_repleshment", 0},
		{"radar_training", 0},
		{"battlefleet_concentration_doctrine", 0},
		{"battleship_crew_training", 0},
		{"basing", 0}};

	local preferTech = {
		"sea_lane_defence",
		"destroyer_escort_role",
		"destroyer_crew_training",
		"commerce_defence",
		"fire_control_system_training",
		"commander_decision_making"};		
		
	return ignoreTech, preferTech
end

function P.IndustrialTechs(voTechnologyData)
	local ignoreTech = {
		{"atomic_research", 0}, 
		{"nuclear_research", 0},
		{"isotope_seperation", 0}, 
		{"civil_nuclear_research", 0},
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
	return ignoreTech, nil
end

-- END OF TECH RESEARCH OVERIDES
-- #######################################

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray
	
	-- Check to see if manpower is to low
	-- More than 100 brigades build stuff that does not use manpower
	if (voProductionData.ManpowerTotal < 60 and voProductionData.LandCountTotal > 30)
	or voProductionData.ManpowerTotal < 30 then
		laArray = {
			0.0, -- Land
			0.40, -- Air
			0.60, -- Sea
			0.00}; -- Other	
	elseif voProductionData.Year <= 1939 and not(voProductionData.IsAtWar) then
		laArray = {
			0.10, -- Land
			0.40, -- Air
			0.50, -- Sea
			0.00}; -- Other
	elseif voProductionData.IsAtWar then
		if voProductionData.Year <= 1941 then
			laArray = {
				0.20, -- Land
				0.35, -- Air
				0.45, -- Sea
				0.00}; -- Other
		else
			laArray = {
				0.50, -- Land
				0.20, -- Air
				0.30, -- Sea
				0.00}; -- Other
		end
	else
		laArray = {
			0.30, -- Land
			0.30, -- Air
			0.40, -- Sea
			0.00}; -- Other
	end
	
	return laArray
end
-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray = {
		garrison_brigade = 1,
		infantry_brigade = 4};
		
	return laArray
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = {
		5, -- Land
		1}; -- Special Force Unit

	local laUnits = {marine_brigade = 1,
		bergsjaeger_brigade = 1};
	
	return laRatio, laUnits	
end

-- Transport to Land unit distribution
function P.TransportLandRatio(voProductionData)
	local laArray = {
		12, -- Land
		1,  -- transport
		1}  -- invasion craft
  
	return laArray
end

function P.AirRatio(voProductionData)
	local laArray = {
		interceptor = 4,
		multi_role = 2,
		cas = 3,
		tactical_bomber = 7,
		naval_bomber = 10};	
	return laArray
end


function P.ForeignMinister_Alignment(...)
	return Support.AlignmentPush("allies", ...)
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		ENG = {Score = 20},
		AST = {Score = 20},
		SAF = {Score = 20},
		CAN = {Score = 20},
		FRA = {Score = 20}}
	
	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

return AI_NZL

