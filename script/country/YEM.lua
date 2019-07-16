-----------------------------------------------------------
-- LUA Hearts of Iron 3 Yemen File
-- Created By: Dr Johnson 12/06/11
-----------------------------------------------------------

local P = {}
AI_YEM = P

function P.TechWeights(minister)
	local laTechWeights = {
		0.30, -- landBasedWeight
		0.30, -- landDoctrinesWeight
		0.00, -- airBasedWeight
		0.00, -- airDoctrinesWeight
		0.00, -- navalBasedWeight
		0.00, -- navalDoctrinesWeight
		0.20, -- industrialWeight
		0.00, -- secretWeaponsWeight
		0.20}; -- otherWeight
	
	return laTechWeights
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
		{"Panzerfaust_Bazooka_AT_Tech", 0},
		{"urban_Fighting_Equipment_and_Training", 0},
		{"air_cavalry_brigade_activation", 0},
		{"ski_brigade_activation", 0},
		{"artic_warfare_equipment", 0},
		{"commando_brigade_activation", 0},
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

function P.AirTechs(minister)
	local ignoreTech
	local preferTech
	
		ignoreTech = {{"basic_four_engine_airframe", 0},
			{"basic_strategic_bomber", 0},
			{"large_fueltank", 0},
			{"four_engine_airframe", 0},
			{"strategic_bomber_armament", 0},
			{"cargo_hold", 0},
			{"large_bomb", 0},
			{"advanced_aircraft_design", 0},
			{"small_airsearch_radar", 0},
			{"medium_airsearch_radar", 0},
			{"large_airsearch_radar", 0},
			{"small_navagation_radar", 0},
			{"medium_navagation_radar", 0},
			{"large_navagation_radar", 0},
			{"rocket_interceptor_tech", 0},
			{"drop_tanks", 0},
			{"single_engine_aircraft_design", 0},
			{"basic_aeroengine", 0},
			{"basic_small_fueltank", 0},
			{"basic_single_engine_airframe", 0},
			{"basic_aircraft_machinegun", 0},
			{"multirole_fighter_design", 0},
			{"twin_engine_aircraft_design", 0},
			{"basic_medium_fueltank", 0},
			{"basic_twin_engine_airframe", 0},
			{"basic_bomb", 0},
			{"jet_engine", 0}};

		preferTech = {"single_engine_aircraft_design",
			"basic_aeroengine",
			"basic_small_fueltank",
			"basic_single_engine_airframe",
			"basic_aircraft_machinegun",
			"multirole_fighter_design",
			"twin_engine_aircraft_design",
			"basic_medium_fueltank",
			"basic_twin_engine_airframe",
			"basic_bomb"};

	return ignoreTech, preferTech
end

function P.AirDoctrineTechs(minister)
	local ignoreTech
	local preferTech
	
		ignoreTech = {{"forward_air_control", 0},
			{"fighter_groundcrew_training", 0},
			{"fighter_ground_control", 0},
			{"tac_groundcrew_training", 0},
			{"logistical_strike_tactics", 0},
			{"installation_strike_tactics", 0},
			{"airbase_strike_tactics", 0},
			{"nav_pilot_training", 0},
			{"nav_groundcrew_training", 0},
			{"portstrike_tactics", 0},
			{"navalstrike_tactics", 0},
			{"naval_air_targeting", 0},
			{"naval_tactics", 0},
			{"battlefield_interdiction", 0},
			{"bomber_targerting_focus", 0},
			{"fighter_targerting_focus", 0}, 
			{"heavy_bomber_pilot_training", 0},
			{"heavy_bomber_groundcrew_training", 0},
			{"strategic_bombardment_tactics", 0},
			{"airborne_assault_tactics", 0},
			{"fighter_pilot_training", 0},
			{"interception_tactics", 0},
			{"cas_pilot_training", 0},
			{"cas_groundcrew_training", 0},
			{"ground_attack_tactics", 0},
			{"tac_pilot_training", 0},
			{"interdiction_tactics", 0},
			{"tactical_air_command", 0},
			{"strategic_air_command", 0}};

		preferTech = {"fighter_pilot_training",
			"interception_tactics",
			"cas_pilot_training",
			"cas_groundcrew_training",
			"ground_attack_tactics",
			"tac_pilot_training",
			"interdiction_tactics",
			"tactical_air_command"};



	return ignoreTech, preferTech
end

function P.NavalTechs(minister)
	local ignoreTech
	local preferTech
	
		ignoreTech = {
			{"light_carrier_technology", 0},
			{"carrier_class", 0},
			{"carrier_technology", 0},
			{"carrier_light_anti_air_artilery", 0},
			{"carrier_medium_anti_air_artilery", 0},
			{"carrier_heavy_anti_air_artilery", 0},
			{"carrier_screws_optimalisation", 0},
			{"carrier_rudder_optimalisation", 0},
			{"carrier_hull_shape_optimalisation", 0},
			{"carrier_armour_thickness", 0},
			{"light_carrier_armour_thickness", 0},
			{"super_carrier_armour_thickness", 0},
			{"carrier_vertical_protection", 0},
			{"carrier_horizontal_protection", 0},
			{"carrier_torpedo_protection", 0},
			{"carrier_bulkheads_layout", 0},
			{"carrier_hanger", 0},
			{"escort_carrier_technology", 0},
			{"seaplane_tender_technology", 0},
			{"carrier_deck_armour_optimisation", 0},
			{"carrier_flight_deck_optimisation", 0},
			{"super_carrier_technology", 0},
			{"carrier_damage_control", 0},
			{"cag_fighter", 0},
			{"cag_bomber", 0},
			{"cag_torpedo", 0},
			{"off_center_elevators", 0},
			{"carrier_catapults", 0},
			{"open_hangar", 0},
			{"closed_hangar", 0},
			{"closed_hangar_safety_procedures", 0},
			{"double_hangar", 0},
			{"deck_park", 0},
			{"battleship_technology", 0},
			{"battleship_class", 0},
			{"battlecruiser_technology", 0},
			{"battlecruiser_class", 0},
			{"pocket_battleship_activation", 0},
			{"capitalship_armament", 0},
			{"capitalship_armament_AP_ammo", 0},
			{"capitalship_armament_HE_ammo", 0},
			{"capitalship_secondary", 0},
			{"capital_ship_engine", 0},
			{"capital_ship_boilers", 0},
			{"capital_ship_turbines", 0},
			{"capital_ship_screws_optimalisation", 0},
			{"capital_ship_rudder_optimalisation", 0},
			{"capital_ship_hull_shape_optimalisation", 0},
			{"battlecruiser_armour_thickness", 0},
			{"battleship_armour_thickness", 0},
			{"super_heavy_battleship_armour_thickness", 0},
			{"capital_ship_vertical_protection", 0},
			{"capital_ship_horizontal_protection", 0},
			{"capital_ship_torpedo_protection", 0},
			{"capital_ship_bulkheads_layout", 0},
			{"super_heavy_battleship_technology", 0},
			{"fast_battleship", 0},
			{"largewarship_surface_radar", 0},
			{"largewarship_air_detection_radar", 0},
			{"capitalship_damage_control", 0},
			{"fire_control_computer", 0},
			{"AAA_control_computer", 0},
			{"floatplane_dev_scout", 0},
			{"floatplane_dev_torpedo", 0},
			{"floatplane_dev_fighter", 0},
			{"capital_ship_light_anti_air_artilery", 0},
			{"capital_ship_medium_anti_air_artilery", 0},
			{"capital_ship_heavy_anti_air_artilery", 0},
			{"lightcruiser_technology", 0},
			{"lightcruiser_class", 0},
			{"anti_air_cruiser_activation", 0},
			{"heavycruiser_class", 0},
			{"heavycruiser_technology", 0},
			{"heavy_cruiser_naval_guns", 0},
			{"light_cruiser_naval_guns", 0},
			{"cruiser_naval_guns_AP_ammo", 0},
			{"cruiser_naval_guns_HE_ammo", 0},
			{"cruiser_naval_guns_autoloader", 0},
			{"cruiser_engine_and_boilers", 0},
			{"cruiser_screws_and_rudder_optimalisation", 0},
			{"cruiser_hull_shape_optimalisation", 0},
			{"lightcruiser_armour_thickness", 0},
			{"heavy_cruiser_armour_thickness", 0},
			{"cruiser_bulkheads_layout", 0},
			{"cruiser_horizontal_protection_layout", 0},
			{"cruiser_vertical_protection_layout", 0},
			{"mediumwarship_surface_radar", 0},
			{"mediumwarship_airsearch_radar", 0},
			{"cruiser_damage_control", 0},
			{"cruiser_fire_control_computer", 0},
			{"cruiser_AAA_control_computer", 0},
			{"cruiser_light_anti_air_artilery", 0},
			{"cruiser_medium_anti_air_artilery", 0},
			{"cruiser_anti_air_artilery_focus", 0},
			{"cruiser_heavy_anti_air_artilery", 0}};

		preferTech = {
			"destroyer_technology",
			"destroyer_class",
			"light_naval_guns",
			"light_warship_engine",
			"hydrophone_dev",
			"smallwarship_asw",
			"smallwarship_damage_control",
			"smallwarship_fire_control_computer",
			"depth_charge",
			"asw_counter_measures",
			"light_antiaircraft_light_ships"};

	return ignoreTech, preferTech



end

function P.NavalDoctrineTechs(minister)
	local ignoreTech
	local preferTech
	
		ignoreTech = {{"carrier_group_doctrine", 0},
			{"carrier_crew_training", 0},
			{"carrier_task_force", 0},
			{"fleet_auxiliary_carrier_doctrine", 0},
			{"light_cruiser_escort_role", 0},
			{"light_cruiser_crew_training", 0},
			{"carrier_task_force", 0},
			{"fleet_auxiliary_submarine_doctrine", 0},
			{"trade_interdiction_submarine_doctrine", 0},
			{"submarine_crew_training", 0},
			{"unrestricted_submarine_warfare_doctrine", 0},
			{"spotting", 0},
			{"naval_underway_repleshment", 0},
			{"radar_training", 0},
			{"battlefleet_concentration_doctrine", 0},
			{"battleship_crew_training", 0},
			{"cruiser_warfare", 0},
			{"cruiser_crew_training", 0},
			{"sea_lane_defence", 0},
			{"destroyer_escort_role", 0},
			{"destroyer_crew_training", 0},
			{"commerce_defence", 0},
			{"fire_control_system_training", 0},
			{"commander_decision_making", 0},
			{"basing", 0}};

		preferTech = {"sea_lane_defence",
			"destroyer_escort_role",
			"destroyer_crew_training",
			"commerce_defence",
			"fire_control_system_training",
			"commander_decision_making"};

	return ignoreTech, preferTech
end

function P.IndustrialTechs(minister)
	local ignoreTech
	local preferTech
	
		ignoreTech = {{"oil_to_coal_conversion", 0},
			{"heavy_aa_guns", 0},
			{"radio_detection_equipment", 0},
			{"radar", 0},
			{"decryption_machine", 0},
			{"encryption_machine", 0},
			{"rocket_tests", 0},
			{"rocket_engine", 0},
			{"theorical_jet_engine", 0},
			{"atomic_research", 0},
			{"nuclear_research", 0},
			{"isotope_seperation", 0},
			{"civil_nuclear_research", 0},
			{"oil_refinning", 0},
			{"steel_production", 0},
			{"raremetal_refinning_techniques", 0},
			{"advanced_construction_engineering", 0},
			{"coal_processing_technologies", 0}};

		preferTech = {
			"education"};

	return ignoreTech, preferTech
end

function P.SecretWeaponTechs(minister)
	local ignoreTech = {}
	
	return ignoreTech, nil
end

function P.OtherTechs(minister)
	local ignoreTech
	local preferTech

	ignoreTech = {{"naval_supremacy_research", 0},
		{"submarine_operations_research", 0},
		{"heavy_bomber_research", 0},
		{"light_bomber_research", 0},
		{"militia_research", 0},
		{"mobile_research", 0},
		{"artillery_research", 0},
		{"automotive_research", 0},
		{"invasion_planning_research", 0},
		{"rugged_terrain_combat_tactics", 0},
		{"airbourne_warfare_research", 0},
		{"national_recruitment_methods_research", 0}};

	preferTech = {"infantry_warfare_research"};

	return ignoreTech, preferTech
end

function P.ProductionWeights(minister)
	local rValue
	
	if minister:GetCountry():IsAtWar() then
		local laArray = {
			1.00, -- Land
			0.00, -- Air
			0.00, -- Sea
			0.00}; -- Other
		
		rValue = laArray	
	else
		local laArray = {
			0.80, -- Land
			0.00, -- Air
			0.00, -- Sea
			0.20}; -- Other
		
		rValue = laArray
	end
	
	return rValue
end
-- Land ratio distribution
function P.LandRatio(minister)
	local laArray = {
		1, -- Garrison
		0, -- Infantry
		0, -- Motorized
		0, -- Mechanized
		0, -- Armor
		0, -- Militia
		5}; -- Cavalry
	
	return laArray
end

function P.Build_Fort(ic, minister, vbGoOver)
	return ic
end

function P.Build_CoastalFort(ic, minister, vbGoOver)
	return ic
end

function P.DiploScore_OfferTrade(score, ai, actor, recipient, observer, voTradedFrom, voTradedTo)
	local lsActorTag = tostring(actor)
	
	if lsActorTag == "AST"
	or lsActorTag == "BEL" 
	or lsActorTag == "BBU" 
	or lsActorTag == "BHU" 
	or lsActorTag == "IND"
	or lsActorTag == "CAN"
	or lsActorTag == "DEN"
	or lsActorTag == "EGY" 
	or lsActorTag == "FRA" 
	or lsActorTag == "GRE"
	or lsActorTag == "HOL"
	or lsActorTag == "NEP"
	or lsActorTag == "NOR" 
	or lsActorTag == "NZL" 
	or lsActorTag == "OMN"
	or lsActorTag == "SAF" then
		score = score + 20

	elseif lsActorTag == "ENG" 
	or lsActorTag == "USA" then
		score = score + 50
	end
	
	return score
end

function P.DiploScore_InfluenceNation( score, ai, actor, recipient, observer )
	local lsRepTag = tostring(recipient)
	
	if lsRepTag == "SAF" then
		score = score + 100
	end

	return score
end

return AI_YEM
