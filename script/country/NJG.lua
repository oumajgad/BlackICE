local P = {}
AI_NJG = P

-- Tech weights
--   1.0 = 100% the total needs to equal 1.0
function P.TechWeights(voTechnologyData)
	local laTechWeights = {
		0.2, -- landBasedWeight
		0.5, -- landDoctrinesWeight
		0.0, -- airBasedWeight
		0.0, -- airDoctrinesWeight
		0.0, -- navalBasedWeight
		0.0, -- navalDoctrinesWeight
		0.3, -- industrialWeight
		0.0, -- secretWeaponsWeight
		0.0}; -- otherWeight
	
	return laTechWeights
end

-- Techs that are used in the main file to be ignored
--   techname|level (level must be 1-9 a 0 means ignore all levels
--   use as the first tech name the word "all" and it will cause the AI to ignore all the techs
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
		{"cruiser_heavy_anti_air_artilery", 0},
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
		{"carrier_hanger", 0}};

	local preferTech = {
		"destroyer_technology",
		"destroyer_class",
		"torpedo_boat_class",
		"motor_torpedo_boat_class",
		"light_naval_guns",
		"light_warship_engine",
		"hydrophone_dev",
		"smallwarship_asw",
		"smallwarship_damage_control",
		"depth_charge",
		"light_antiaircraft_light_ships"};
		
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


-- #######################################
-- Production Overides the main LUA with country specific ones

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray

	-- Check to see if manpower is to low
	-- More than 30 brigades so build stuff that does not use manpower
	if (voProductionData.ManpowerTotal < 350 and voProductionData.LandCountTotal > 30)
	or voProductionData.ManpowerTotal < 10 then
		laArray = {
			0.0, -- Land
			0.50, -- Air
			0.0, -- Sea
			0.50}; -- Other
	elseif voProductionData.IsAtWar then
		laArray = {
			0.70, -- Land
			0.15, -- Air
			0.05, -- Sea
			0.10}; -- Other
	
	else
		laArray = {
			0.50, -- Land
			0.20, -- Air
			0.10, -- Sea
			0.20}; -- Other
		
	end
	
	return laArray
end
-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray = {
		infantry_brigade = 1,
		garrison_brigade = 2,
		cavalry_brigade = 1,
		militia_brigade = 6};
	
	return laArray
end
-- Special Forces ratio distribution
-- Make sure China does not build any special forces
function P.SpecialForcesRatio(voProductionData)
	local laArray = {
		0, -- Land
		0}; -- Special Forces Unit
	
	return laArray, nil
end
-- Air ratio distribution
function P.AirRatio(voProductionData)
	local laArray = {
		interceptor = 3, 
		cas = 1, 
		tactical_bomber = 2};
	
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
		0} -- Escort to Convoy Ratio (Number indicates how many convoys needed to build 1 escort)
  
	return laArray
end

-- Do not build Coastal Forts
function P.Build_CoastalFort(ic, voProductionData)
	return ic, false
end

-- Do not build Land forts
function P.Build_Fort(ic, voProductionData)
	return ic, false
end

-- END OF PRODUTION OVERIDES
-- #######################################
function P.DiploScore_InviteToFaction(voDiploScoreObj)
	local japTag = CCountryDataBase.GetTag("JAP")
	
	-- if we are not at war with JAP, only join if we lost previously and they are busy with allies
	if not (voDiploScoreObj.TargetCountry:GetRelation(japTag):HasWar()) then
		if voDiploScoreObj.Faction == CCurrentGameState.GetFaction("allies") then
			if japTag:GetCountry():GetSurrenderLevel():Get() < 0.06 then -- they must have lost islands
				if (CCurrentGameState.GetProvince(5405):GetController() == japTag) then
					voDiploScoreObj.Score = 0
				end
			end
		end
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)
	local lsCountry = tostring(voCountry)

	-- Do not let Japan in our territory
	if lsCountry == "JAP" then
		viScore = 0
	end
	
	return viScore
end

-- Want more troops, let them learn on the battlefield.
--   helps them produce troops faster
function P.CallLaw_training_laws(minister, voCurrentLaw)
	local _MINIMAL_TRAINING_ = 27
	return CLawDataBase.GetLaw(_MINIMAL_TRAINING_)
end


return AI_NJG

