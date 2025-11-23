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

-- END OF TECH RESEARCH OVERIDES
-- #######################################


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

function P.Build_Fort(ic, minister, vbGoOver)
	return ic
end

function P.Build_CoastalFort(ic, minister, vbGoOver)
	return ic
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local lsActorTag = tostring(voDiploScoreObj.TagName)

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
		voDiploScoreObj.Score = voDiploScoreObj.Score + 20

	elseif lsActorTag == "ENG"
	or lsActorTag == "USA" then
		voDiploScoreObj.Score = voDiploScoreObj.Score + 50
	end

	return voDiploScoreObj.Score
end

function P.DiploScore_InfluenceNation( score, ai, actor, recipient, observer )
	local lsRepTag = tostring(recipient)

	if lsRepTag == "SAF" then
		score = score + 100
	end

	return score
end

return AI_YEM