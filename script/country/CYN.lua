local P = {}
AI_CYN = P

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

-- #######################################
-- Production Overides the main LUA with country specific ones

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray

	-- Check to see if manpower is to low
	-- More than 30 brigades so build stuff that does not use manpower
		local japTag = CCountryDataBase.GetTag("JAP")
	-- Check to see if manpower is to low
	-- More than 30 brigades so build stuff that does not use manpower
	
	if (voProductionData.humanTag == japTag) then
		if (voProductionData.ManpowerTotal < 350 and voProductionData.LandCountTotal > 30) or voProductionData.ManpowerTotal < 10 then
			laArray = {
			0.0, -- Land
			0.50, -- Air
			0.0, -- Sea
			0.50}; -- Other
		else
			laArray = {
			0.75, -- Land
			0.15, -- Air
			0.05, -- Sea
			0.05}; -- Other	
		end	
	
	
	elseif (voProductionData.ManpowerTotal < 50 and voProductionData.LandCountTotal > 50)
	or voProductionData.ManpowerTotal < 25 then
		laArray = {
			0.0, -- Land
			0.50, -- Air
			0.0, -- Sea
			0.50}; -- Other	
	elseif voProductionData.Year <= 1937 then
		laArray = {
			0.10, -- Land
			0.10, -- Air
			0.0, -- Sea
			0.80}; -- Other
			
	else
		laArray = {
			0.80, -- Land
			0.10, -- Air
			0.0, -- Sea
			0.10}; -- Other
	end
	
	return laArray
end
-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray

	laArray = {
		infantry_brigade = 1,
		garrison_brigade = 1,
		cavalry_brigade = 1,
		militia_brigade = 4
	};

	return laArray
end
-- Special Forces ratio distribution
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

-- Do not build coastal forts
function P.Build_CoastalFort(ic, voProductionData)
	return ic, false
end

function P.Build_Fort(ic, voProductionData)
	-- Only build the forts if its 1938 or less

		return ic, true

end

-- END OF PRODUTION OVERIDES
-- #######################################

function P.DiploScore_Alliance(voDiploScoreObj)
	-- Make sure we are not in a faction already and China is the one asking
	if not(voDiploScoreObj.TargetHasFaction) and tostring(voDiploScoreObj.ministerTag) == "CHI" then
		-- If China and Japan are atwar then come to their help
		if voDiploScoreObj.ministerCountry:GetRelation(CCountryDataBase.GetTag("JAP")):HasWar() then
			voDiploScoreObj.Score = voDiploScoreObj.Score + 50
		end
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_Guarantee(voDiploScoreObj)
	local liYear = CCurrentGameState.GetCurrentDate():GetYear()
	
	-- We are not part of any faction and they are not in any wars
	if not(voDiploScoreObj.HasFaction)
	and not(voDiploScoreObj.IsAtWar)
	and not(voDiploScoreObj.TargetIsAtWar)
	and liYear <= 1938 then
		local lsTargetTag = tostring(voDiploScoreObj.TargetTag)
		
		if lsTargetTag == "CSX" 
		or lsTargetTag == "CHI" then
			voDiploScoreObj.Score = 100
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

return AI_CYN 

