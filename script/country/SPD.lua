local P = {}
AI_SPD = P

-- #######################################
-- Start of Trade Weights
function P.TradeWeights(voResourceData)
	local laResouces = {
		RARE_MATERIALS = {
			Buffer = 5,
			BufferSaleCap = 10000},
		CRUDE_OIL = {
			Buffer = 2,
			BufferSaleCap = 10000},
		FUEL = {
			Buffer = 2,
			BufferSaleCap = 10000}}
	
	return laResouces
end

-- #######################################
-- Start of Tech Research

-- Tech weights
--   1.0 = 100% the total needs to equal 1.0
function P.TechWeights(voTechnologyData)
	local laTechWeights = {
		0.22, -- landBasedWeight
		0.22, -- landDoctrinesWeight
		0.12, -- airBasedWeight
		0.10, -- airDoctrinesWeight
		0.04, -- navalBasedWeight
		0.05, -- navalDoctrinesWeight
		0.14, -- industrialWeight
		0.04, -- secretWeaponsWeight
		0.07}; -- otherWeight
	
	return laTechWeights
end

-- Techs that are used in the main file to be ignored
--   techname|level (level must be 1-9 a 0 means ignore all levels
--   use as the first tech name the word "all" and it will cause the AI to ignore all the techs
function P.LandTechs(voTechnologyData)
	local lbArmor = voTechnologyData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("armor_brigade"))
	local ignoreTech
	
	if lbArmor then
		ignoreTech = {
			{"cavalry_motorization", 0},
			{"garrison_deployment", 0},			
			{"emergency_recruitment_legislation", 0},
			{"jungle_warfare_equipment", 0}, 
			{"airlanding_infantry_brigade_activation", 0},
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
			{"SS_security_increase", 0},
			{"SS_infantry_increase", 0},
			{"SS_special_forces_increase", 0},
			{"SS_mobile_increase", 0},
			{"SS_armor_increase", 0},
			{"SS_artillery_increase", 0},
			{"SS_armorsupport_increase", 0}, 
			{"SS_aa_at_increase", 0},
			{"SS_engineers_increase", 0},
			{"SS_security_decrease", 0},
			{"SS_infantry_decrease", 0},
			{"SS_special_forces_decrease", 0},
			{"SS_mobile_decrease", 0},
			{"SS_armor_decrease", 0},
			{"SS_artillery_decrease", 0},
			{"SS_armorsupport_decrease", 0}, 
			{"SS_aa_at_decrease", 0},
			{"SS_engineers_decrease", 0},
			{"air_commando_brigade_activation", 0}};	
	else
		ignoreTech = {
			{"cavalry_motorization", 0},
			{"garrison_deployment", 0},	
			{"emergency_recruitment_legislation", 0},
			{"jungle_warfare_equipment", 0}, 
			{"airlanding_infantry_brigade_activation", 0},
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
			{"SS_security_increase", 0},
			{"SS_infantry_increase", 0},
			{"SS_special_forces_increase", 0},
			{"SS_mobile_increase", 0},
			{"SS_armor_increase", 0},
			{"SS_artillery_increase", 0},
			{"SS_armorsupport_increase", 0}, 
			{"SS_aa_at_increase", 0},
			{"SS_engineers_increase", 0},
			{"SS_security_decrease", 0},
			{"SS_infantry_decrease", 0},
			{"SS_special_forces_decrease", 0},
			{"SS_mobile_decrease", 0},
			{"SS_armor_decrease", 0},
			{"SS_artillery_decrease", 0},
			{"SS_armorsupport_decrease", 0}, 
			{"SS_aa_at_decrease", 0},
			{"SS_engineers_decrease", 0},
			{"air_commando_brigade_activation", 0}};
	end

	local preferTech = {
		"motorized_infantry",
		"mechanised_infantry",
		"Support_battalions_motorization",
		"infantry_guns",
		"light_infantry_brigade_activation",
		"infantry_at",
		"infantry_support",
		"intergrated_AFV_battalions",
		"engineer_brigade_activation",
		"engineer_bridging_equipment",
		"engineer_assault_equipment",
		"smallarms_technology",
		"art_barrell_ammo",
		"gun_carriage",
		"range_finding",
		"small_calibre_gun_design",
		"medium_velocity_gun",
		"high_velocity_gun",
		"at_aa_ammo",
		"Artillery_motorization",
		"tank_chassis_design",
		"advanced_tank_chassis_design",
		"light_armor_brigade_design",
		"armor_brigade_design",
		"heavy_armor_brigade_design",
		"armor_thickness"};
		
	return ignoreTech, preferTech
end

function P.LandDoctrinesTechs(voTechnologyData)
	local ignoreTech = {
		{"resistance_support", 0},
		{"jungle_warfare_equipment", 0},
		{"human_wave", 0},
		{"banzai", 0},
		{"jungle_training", 0},
		{"jungle_command_and_control", 0}
		};
		
	local preferTech = {
		"infantry_integration",
		"infantry_training",
		"infantry_command_and_control",
		"mobile_integration",
		"mobile_training",
		"mobile_command_and_control",
		"artillery_integration",
		"artillery_training",
		"artillery_command_and_control",
		"combined_arms_integration",
		"interservice_coordination",
		"interservice_communication",
		"homefront_coordination",
		"special_forces_integration",
		"amphibious_training",
		"amphibious_command_and_control",
		"airborne_training",
		"airborne_command_and_control",
		"artillery_barrage",
		"artillery_flexiblity",
		"assault_concentration",
		"superior_firepower",
		"superior_strength",
		"spearhead",
		"blitzkrieg",
		"schwerpunkt",
		"divisonal_command_structure",
		"armygroup_command_structure",
		"supreme_command_coordination",
		"interservice_HQ_structure",
		"elastic_defense"};
		
	return ignoreTech, preferTech
end

function P.AirTechs(voTechnologyData)
	local ignoreTech = {
		{"four_engine_bomber_design", 0},
		{"air_commando_brigade_activation", 0},
		{"four_engine_bombbay", 0},
		{"large_fueltank", 0},
		{"basic_four_engine_airframe", 0},
		{"four_engine_airframe", 0},
		{"four_engine_bomber_crew_layout", 0},
		{"cag_design", 0},
		{"cag_fighter", 0},
		{"cag_bomber", 0},
		{"cag_torpedo", 0},
		{"tailhook", 0},
		{"folding_wings", 0},
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
		{"glider_activation", 0}
	};

	local preferTech = {
		"aerodyn_fuselage",
		"aerodyn_wings",
		"advanced_aircraft_development",
		"single_engine_fighter_design",
		"cas_design",
		"single_engine_airframe",
		"single_engine_aircraft_armament",
		"single_engine_aircraft_machinegun",
		"small_fueltank",
		"medium_fueltank",
		"aeroengine",
		"twin_engine_bomber_design",
		"light_bomber_design",
		"multirole_fighter_design",
		"twin_engine_aircraft_armament", 
		"twin_engine_airframe",
		"retractable_undercarriage",
		"engine_boost",
		"small_bomb",
		"medium_bomb",
		"wing_guns",
		"ammo_capacity",
		"auto_cannons",
		"self_sealing_fueltanks",
		"air_cooling_sys",
		"drop_shaped_cockpit",
		"drop_tanks"
	};
		
	return ignoreTech, preferTech
end

function P.AirDoctrineTechs(voTechnologyData)
	local ignoreTech = {
		{"installation_strike_tactics", 0},
		{"bomber_targerting_focus", 0},
		{"battlefield_interdict	ion", 0},
		{"heavy_bomber_pilot_training", 0},
		{"heavy_bomber_groundcrew_training", 0},
		{"forward_air_control", 0},
		{"fighter_targerting_focus", 0}};

	local preferTech = {
		"fighter_pilot_training",
		"interception_tactics",
		"cas_pilot_training",
		"cas_groundcrew_training",
		"ground_attack_tactics",
		"tac_pilot_training",
		"fighter_ground_control",
		"tactical_air_command"};
		
	return ignoreTech, preferTech
end
		
function P.NavalTechs(voTechnologyData)
	local ignoreTech = {
		{"carrier_antiaircraft", 0},
		{"carrier_engine", 0},
		{"carrier_armour", 0},
		{"carrier_hanger", 0},
		{"carrier_technology", 0},
		{"escort_carrier_technology", 0}
		};

	local preferTech = {
		"submarine_technology",
		"submarine_antiaircraft",
		"submarine_engine",
		"submarine_hull",
		"torpedo_upgrade",
		"submarine_electroboat",
		"milch_submarine",
		"electric_powered_torpedo",
		"submarine_snorkel"}		
		
	return ignoreTech, preferTech
end
		
function P.NavalDoctrineTechs(voTechnologyData)
	local ignoreTech = {
			{"fleet_auxiliary_carrier_doctrine", 0}
			};

	local preferTech = {
	    "submarine_crew_training",
		"unrestricted_submarine_warfare_doctrine",
		"trade_interdiction_submarine_doctrine"
		};		
		
	return ignoreTech, preferTech
end

function P.IndustrialTechs(voTechnologyData)
	local ignoreTech = {
		{"light_weight_construction", 0}};

	local preferTech = { 			
		"construction_engineering",
		"supply_transportation",
		"supply_organisation",
		"secretary_of_public_information_and_education",
		"mass_events",
		"monumental_architecture",
		"broadcasting",
		"road_highway",
		"railway",
		"university",
		"gigant_infrastructure_projects",
		"agriculture",
		"industral_production",
		"industral_efficiency",
		"industry_tech",
		"civil_medicine",
		"short_range_aircraft_production",
		"oil_refinning",
		"steel_production",
		"supply_production",
		"university",
		"raremetal_refinning_techniques",
		"civil_defence",
		"logistical_warfare_focus",
		"home_front_focus",
		"atomic_research",
		"nuclear_research",
		"isotope_seperation",
		"civil_nuclear_research",
		"combat_medicine",
		"first_aid",
		"medical_evacuation",
		"secretary_of_public_information_and_education",
		"gigant_infrastructure_projects",
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

	return ignoreTech, nil
end

function P.OtherTechs(voTechnologyData)
	local ignoreTech = {
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
			{"SS_security_increase", 0},
			{"SS_infantry_increase", 0},
			{"SS_special_forces_increase", 0},
			{"SS_mobile_increase", 0},
			{"SS_armor_increase", 0},
			{"SS_artillery_increase", 0},
			{"SS_armorsupport_increase", 0}, 
			{"SS_aa_at_increase", 0},
			{"SS_engineers_increase", 0},
			{"SS_security_decrease", 0},
			{"SS_infantry_decrease", 0},
			{"SS_special_forces_decrease", 0},
			{"SS_mobile_decrease", 0},
			{"SS_armor_decrease", 0},
			{"SS_artillery_decrease", 0},
			{"SS_armorsupport_decrease", 0}, 
			{"SS_aa_at_decrease", 0},
			{"SS_engineers_decrease", 0},
	{"large_airsearch_radar", 0},
	{"large_navagation_radar", 0}};

	local preferTech = {
	    "tank_radios",
		"electronic_computing_machine",
		"infantry_radios"};		
			

	return ignoreTech, preferTech
end

-- END OF TECH RESEARCH OVERIDES
-- #######################################

-- #######################################
-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray
	
	-- Check to see if manpower is to low
	if voProductionData.Year > 1941 and voProductionData.Year < 1945 and voProductionData.ManpowerTotal < 1800 then 
		laArray = {
			0.07, -- Land
			0.42, -- Air
			0.13, -- Sea
			0.38}; -- Other	
	elseif voProductionData.ManpowerTotal < 500 then
		laArray = {
			0.12, -- Land
			0.40, -- Air
			0.13, -- Sea
			0.35}; -- Other
	-- More than 400 brigades so build stuff that does not use manpower
	elseif  (voProductionData.Year > 1940) and (voProductionData.ManpowerTotal < 1800 and voProductionData.LandCountTotal > 800) then
		laArray = {
			0.30, -- Land
			0.35, -- Air
			0.10, -- Sea
			0.25}; -- Other
			
	elseif voProductionData.IsAtWar then
		-- Desperation check and if so heavy production of land forces
		if voProductionData.ministerCountry:CalcDesperation():Get() > 0.4 then
			laArray = {
				0.65, -- Land
				0.25, -- Air
				0.07, -- Sea
				0.03}; -- Other
		else
			laArray = {
				0.70, -- Land
				0.20, -- Air
				0.07, -- Sea
				0.03}; -- Other
		end
	else
		-- Check to see if the fort line is finished and if so take some production away
		local land_fort = CBuildingDataBase.GetBuilding( "land_fort" )
		local loProvince = CCurrentGameState.GetProvince(2490) -- Saarlouis
		local loBuilding = loProvince:GetBuilding(land_fort)

		-- Province 2490 is last of the Siegfriend line if done then adjust build ratio
		if loBuilding:GetMax():Get() > 0 then
			laArray = {
				0.68, -- Land
				0.20, -- Air
				0.10, -- Sea
				0.02}; -- Other
		else
			laArray = {
				0.65, -- Land
				0.20, -- Air
				0.10, -- Sea
				0.05}; -- Other
		end
	end
	
	return laArray
end
-- Land ratio distribution

-- Lots of armor at the beginning for the Blitzkrieg, lots of infantry later to invade the USSR
function P.LandRatio(voProductionData)
	local laArray
		local sovTag = CCountryDataBase.GetTag("SOV")
	
	-- Build lots of infantry in the early years
	-- Build lots of infantry in the early years
	if voProductionData.humanTag == sovTag then
		if voProductionData.Year <= 1939 or (voProductionData.Year ==1940 and voProductionData.Month <= 5) then
			laArray = {
				garrison_brigade = 3,
				infantry_brigade = 6,
				motorized_brigade = 1,
				light_armor_brigade = 1,
				armor_brigade = 2,
				heavy_armor_brigade = 1};


		else
			laArray = {
				garrison_brigade = 1,
				infantry_brigade = 6,
				ss_motorized_brigade = 0.2,
				ss_infantry_brigade = 0.2,
				ss_armor_brigade = 0.1,
				motorized_brigade = 1,
				mechanized_brigade = 1,
				armor_brigade = 2,
				heavy_armor_brigade = 1};
		end
			
	
	elseif voProductionData.Year <= 1939 or (voProductionData.Year ==1940 and voProductionData.Month <= 5) then
		laArray = {
			garrison_brigade = 3,
			infantry_brigade = 6,
			motorized_brigade = 2,
			light_armor_brigade = 1,
			armor_brigade = 2,
			heavy_armor_brigade = 1};


	elseif voProductionData.Year < 1943 then
		laArray = {
			garrison_brigade = 1,
			infantry_brigade = 8,
			ss_motorized_brigade = 0.2,
			ss_infantry_brigade = 0.2,
			ss_armor_brigade = 0.1,
			motorized_brigade = 2,
			mechanized_brigade = 2,
			armor_brigade = 2,
			heavy_armor_brigade = 1};
	else
		laArray = {
			garrison_brigade = 1,
			infantry_brigade = 6,
			ss_motorized_brigade = 0.2,
			ss_infantry_brigade = 0.2,
			ss_armor_brigade = 0.15,
			motorized_brigade = 2,
			mechanized_brigade = 2,
			armor_brigade = 2,
			heavy_armor_brigade = 1};

	
	end
	return laArray
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = nil
	local laUnits = nil
	local lbPara = voProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("paratrooper_brigade"))

	if lbPara then
		laRatio = {
			40, -- Land
			1}; -- Special Force Unit

		laUnits = {
			bergsjaeger_brigade = 1,
			paratrooper_brigade = 0.1};
	end
	
	return laRatio, laUnits
end



-- Which units should get 1 more Support unit with Superior Firepower tech
function P.FirePower(voProductionData)
	local laArray = {
		"infantry_brigade",
		"ss_motorized_brigade",
		"ss_armor_brigade",
		"ss_infantry_brigade",
		"motorized_brigade",
		"mechanized_brigade",
		"armor_brigade",
		"heavy_armor_brigade"};
		
	return laArray
end

-- Air ratio distribution
function P.AirRatio(voProductionData)
	local laArray = {
		interceptor = 7,
		multi_role = 2,
		rocket_interceptor = 1,
		cas = 2,
		light_bomber = 3,
		tactical_bomber = 4,
		naval_bomber = 1};
	
	return laArray
end

-- Naval ratio distribution
function P.NavalRatio(voProductionData)
	local laArray = {
		destroyer_actual = 4, -- Destroyers
		submarine = 6, -- Submarines
		heavy_cruiser = 1, -- Heavy Cruisers
		battleship = 1}; -- Battleship
	
	return laArray
end

-- Transport to Land unit distribution
function P.TransportLandRatio(voProductionData)
	local laArray
	local norTag = CCountryDataBase.GetTag('NOR')
	local loNorwayCountry = norTag:GetCountry()
	
	-- If Norway is present build more transports to invade it with
	if loNorwayCountry:Exists()
	and not(voProductionData.ministerCountry:GetRelation(norTag):HasAlliance()) then
		laArray = {
			80, -- Land
			1, -- Transport
			1}; -- Invasion
	else
		laArray = {
			120, -- Land
			1, -- Transport
			1}; -- Invasion
	end
	
	return laArray
end

-- Convoy Ratio control
--- NOTE: If goverment is in Exile these parms are ignored
function P.ConvoyRatio(voProductionData)
	local laArray = {
		10, -- Percentage extra (adds to 100 percent so if you put 10 it will make it 110% of needed amount)
		30, -- If Percentage extra is less than this it will force it up to the amount entered
		50, -- If Percentage extra is greater than this it will force it down to this
		3} -- Escort to Convoy Ratio (Number indicates how many convoys needed to build 1 escort)
  
	return laArray
end

function P.Build_motorized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	
	if (math.random(100) < 33) then
		voType.SecondaryMain = "heavy_tank_destroyer_brigade"
		voType.Support = 3
	elseif (math.random(100) < 33) then
		voType.SecondaryMain = "medium_tank_destroyer_brigade"
		voType.Support = 3

	else
		voType.SecondaryMain = "tank_destroyer_brigade"
		voType.Support = 3
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

function P.Build_mechanized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	
	if (math.random(100) < 33) then
		voType.SecondaryMain = "armor_bat"
		voType.Support = 3
	elseif (math.random(100) < 33) then
		voType.SecondaryMain = "medium_tank_destroyer_brigade"
		voType.Support = 3
	else
		voType.SecondaryMain = "tank_destroyer_brigade"
		voType.Support = 3
	end
	
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

function P.Build_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	
	local sovTag = CCountryDataBase.GetTag("SOV")
	local check1 = voProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("armored_engineers_brigade"))
	local check2 = voProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("sp_artillery_brigade"))

	
	if sovTag and check1 and check2 then
		voType.SupportGroup = "grind"
		voType.SecondaryMain = "sp_anti_air_brigade"
		voType.Support = 3

	else
		return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
	end
	
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end


function P.Build_heavy_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	local sovTag = CCountryDataBase.GetTag("SOV")
	local check1 = voProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("armored_engineers_brigade"))
	local check2 = voProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("sp_artillery_brigade"))

	if voProductionData.humanTag == sovTag and check1 and check2 then	
		voType.SecondaryMain = "ss_motorized_brigade"
		voType.SupportGroup = "grind"
		
	else
		voType.SecondaryMain = "semi_motorized_brigade"
	end	
	
		
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

function P.Build_light_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

		voType.SupportGroup = "Blitz"
		voType.SecondaryMain = "armored_engineers_brigade"

		loSecUnitType = CSubUnitDataBase.GetSubUnit(voType.SecondaryMain)
		--Utils.LUA_DEBUGOUT("Country: " .. tostring(voType.SecondaryMain))
		-- If secondary main can not be built then too bad
		if voProductionData.ministerTag == voProductionData.humanTag then
			if not(voProductionData.TechStatus:IsUnitAvailable(loSecUnitType)) then
				voType.SecondaryMain = nil
			end
		end
		voType.Support = 3

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end


function P.Build_infantry_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
		
		voType.SupportGroup = "GINF"
		voType.SecondaryMain = "engineer_brigade"
		voType.Support = 3
		
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

function P.Build_ss_infantry_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	
	if (math.random(100) < 33) then
		voType.SecondaryMain = "ss_heavy_armor_brigade"
	else
		voType.SecondaryMain = "ss_anti_tank_brigade"
	end	

		voType.Support = 3
		
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

-- Build Atleast 1 rocket test site
function P.Build_RocketTest(ic, voProductionData)
	if voProductionData.Year <= 1938 then
		ic = Support.Build_RocketTest(ic, voProductionData, 1681, 1) -- Wolgast
	end
	return ic, true	
end

-- Never build and underground
function P.Build_Underground(ic, voProductionData)
	return ic, false
end

-- Have Germany Fortify the French Line
-- NOTE: if 2490 Province is not the last one please update the land production ratio
function P.Build_Fort(ic, voProductionData)
	-- Only build the forts if its 1938 or less
	if voProductionData.Year <= 1938 then
		ic = Support.Build_Fort(ic, voProductionData, 2751, 1) -- Karlsruhe
		ic = Support.Build_Fort(ic, voProductionData, 2882, 1) -- Baden
		ic = Support.Build_Fort(ic, voProductionData, 2948, 1) -- Offenburg
		ic = Support.Build_Fort(ic, voProductionData, 3016, 1) -- Freiburg
		ic = Support.Build_Fort(ic, voProductionData, 3084, 1) -- Lörrach (See Note)
		return ic, false
	end
	
	return ic, true
end

function P.Build_CoastalFort(vIC, voProductionData)
	if voProductionData.Year > 1947 then
		return vIC, true
	end
	
	return vIC, false
end

function P.Build_Industry(vIC, voProductionData)
	-- Do not build factories till 1939 or if we go to war early
	if voProductionData.Year > 1940 then
		return vIC, true
	end
	
	return vIC, false
end

function P.Build_Heavy_Industry(vIC, voProductionData)
	-- Do not build heavy factories till 1939 or if we go to war early
	if voProductionData.Year > 1940 then
		return vIC, true
	end
	
	return vIC, false
end

function P.Build_Infrastructure(vIC, voProductionData)
	if voProductionData.Year > 1937 then
		return vIC, true
	end
	
	return vIC, false
end

function P.Build_Railroad(vIC, voProductionData)
	if voProductionData.Year > 1938 then
		return vIC, true
	end
	
	return vIC, false
end

function P.Build_NavalBase(vIC, voProductionData)
	if voProductionData.Year > 1940 then
		return vIC, true
	end
	
	return vIC, false
end

function P.Build_AirBase(vIC, voProductionData)
	return vIC, true
end

function P.Build_AntiAir(vIC, voProductionData)
	if voProductionData.Year > 1940 then
		return vIC, true
	end
	
	return vIC, false
end

function P.Build_Radar(vIC, voProductionData)

	return vIC, true
end

-- END OF PRODUTION OVERIDES
-- #######################################


-- #######################################
-- Diplomacy Hooks


function P.DiploScore_InfluenceNation(voDiploScoreObj)
	-- Only do this if we are in the axis
	if voDiploScoreObj.FactionName == "axis" then
		local loInfluences = {
			JAP = {Score = 500},
			ITA = {Score = 500},
			ROM = {Score = 200, Province = 3377, Year = 1942},
			BUL = {Score = 200, Province = 4058, Year = 1942},
			FIN = {Score = 200, Province = 698, Year = 1942},
			HUN = {Score = 300}}
	
		-- Are they on our list
		if loInfluences[voDiploScoreObj.TargetName] then
			if loInfluences[voDiploScoreObj.TargetName].Province then
				if loInfluences[voDiploScoreObj.TargetName].Year <= voDiploScoreObj.Year then
					if CCurrentGameState.GetProvince(loInfluences[voDiploScoreObj.TargetName].Province):GetOwner() ~= voDiploScoreObj.TargetTag then
						return 0 -- No need to influence, assume they will align
					end
				end
			end

			return (voDiploScoreObj.Score + loInfluences[voDiploScoreObj.TargetName].Score)
		end
	end

	return voDiploScoreObj.Score
end

function P.DiploScore_Embargo(voDiploScoreObj)
	-- If west hem then do some special checks
	if (tostring(voDiploScoreObj.EmbargoTag) == "USA") or (tostring(voDiploScoreObj.EmbargoTag) == "ARG") or (tostring(voDiploScoreObj.EmbargoTag) == "VEN") or (tostring(voDiploScoreObj.EmbargoTag) == "CHL") or (tostring(voDiploScoreObj.EmbargoTag) == "BRA") then

		if voDiploScoreObj.IsAtWar then
				voDiploScoreObj.Score = 100

			-- Do not embargo unless at war
		else
				voDiploScoreObj.Score = 0
		end
	else
		voDiploScoreObj.Score = 0

	end

	return voDiploScoreObj.Score
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		SOV = {Score = 50},
		SWE = {Score = 100},
		ITA = {Score = 200},
		TUR = {Score = 50},
		FIN = {Score = 100},
		BUL = {Score = 100},
		ROM = {Score = 100},
		HUN = {Score = 100},
		VIC = {Score = 50},
		SPA = {Score = 50},
		SPR = {Score = 50},
		ENG = {Score = -20},
		FRA = {Score = -20},
		POR = {Score = 30}}
	
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

--function P.DiploScore_Alliance( viScore, ai, actor, recipient, observer)
function P.DiploScore_Alliance(voDiploScoreObj)
	local loAxis = CCurrentGameState.GetFaction("axis")

	-- Make sure we are part of the Axis
	if voDiploScoreObj.Faction == loAxis then
		local lsTargetTag = voDiploScoreObj.TargetTag
		
		if lsTargetTag == 'AUS' then -- we got better plans for you...
			voDiploScoreObj.Score = 0
		end
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_JoinFactionGoal(viScore, ai, actor, recipient, observer, goal )
	local lsSender = tostring(actor)
	local ministerCountry = observer:GetCountry()
	
	if lsSender == 'AUS' then -- we got better plans for you...
		return 0
	elseif lsSender == 'FIN' then
		return 0
	end
    
    return viScore
end

function P.DiploScore_SendExpeditionaryForce(voForeignMinisterData)
Utils.LUA_DEBUGOUT("SPD exp ")
		local  score = 0

		return score
end

--##########################
-- Foreign Minister Hooks
function P.ForeignMinister_Influence(voForeignMinisterData)
	local laIgnoreWatch -- Ignore this country but monitor them if they are about to join someone else
	local laWatch -- Monitor them and also fi their score is high enough they can be influenced normally
	local laIgnore -- Ignore them completely

	if voForeignMinisterData.FactionName == "axis" then
		laWatch = {
			"BUL", -- Bulgaria
			"FIN", -- Finland
			"ROM", -- Romania
			"HUN"};	 -- Hungary
			
		laIgnoreWatch = {
			"SPA", -- Spain
			"SPR", -- Republic Spain
			"POR", -- Portugal
			"BEL", -- Belgium
			"HOL", -- Holland
			"SWE", -- Sweden
			"CHI"} -- China
						
		laIgnore = {
			"AST", -- Australia
			"NOR", -- Norway
			"CAN", -- Canada
			"SAF", -- South Africa
			"NZL", -- New Zealand
			"AUS", -- Austria
			"CZE", -- Czechoslovakia
			"SCH", -- Switzerland
			"LAT", -- Lativia
			"LIT", -- Lithuania
			"EST", -- Estonia
			"LUX", -- Luxemburg
			"VIC", -- Vichy
			"DEN", -- Denmark
			"POL", -- Poland
			"ETH", -- Ethiopia			
			"CYN", -- Yunnan
			"SIK", -- Sikiang
			"CGX", -- Guangxi Clique
			"CSX", -- Shanxi
			"TIB", -- Tibet
			"AFG", -- Afghanistan
			"CHC"};	-- Communist China
	end
	
	return laWatch, laIgnoreWatch, laIgnore
end

function P.ForeignMinister_EvaluateDecision(voDecision, voForeignMinisterData)
Utils.LUA_DEBUGOUT("SPD decides on: " .. tostring(voDecision.Name))
	local loDecisions = {
		molotov_ribbentrop_pact = {Year = 1939, Month = 7, Day = 5, Score = 100},
		danzig_or_war = {Year = 1939, Month = 8, Day = 0, War = true, Country = "POL", Score = 100 },
--		anschluss_of_austria = {Year = 1938, Month = 2, Day = 8, Score = 100 },
--		the_treaty_of_munich = {Year = 1938, Month = 8, Day = 8, Score = 100 },
--		first_vienna_award = {Year = 1939, Month = 2, Day = 25, Score = 100 },
		operation_barbarossa_aufmarsch_befehl = {Year = 1941, Month = 4, Day = 21, War = true, Country = "SOV", Score = 100 }, -- Give a month to dow.
		independent_croatia = {Year = 1936, Month = 0, Day = 0, Score = 0 }}

	if loDecisions[voDecision.Name] then
		if (voForeignMinisterData.Year == loDecisions[voDecision.Name].Year
		and voForeignMinisterData.Month >= loDecisions[voDecision.Name].Month
		and voForeignMinisterData.Day >= loDecisions[voDecision.Name].Day )
		or
		(voForeignMinisterData.Year == loDecisions[voDecision.Name].Year
		and voForeignMinisterData.Month > loDecisions[voDecision.Name].Month)
		or
		(voForeignMinisterData.Year > loDecisions[voDecision.Name].Year) then
			if loDecisions[voDecision.Name].War then
				Utils.LUA_DEBUGOUT("SPD prep war: " .. tostring(voDecision.Name))
				voForeignMinisterData.Strategy:PrepareWarDecision(CCountryDataBase.GetTag(loDecisions[voDecision.Name].Country), 100, voDecision.Decision, false)
			else
				return loDecisions[voDecision.Name].Score
			end
		else
			return 0
		end
	end
	
	return voDecision.Score
end

function P.ForeignMinister_CallAlly(voForeignMinisterData)
	-- Make sure Germany is in the Axis and if not let default code run
	if voForeignMinisterData.FactionName ~= "axis" then
		return true
	end
	local loMonth = CCurrentGameState.GetCurrentDate():GetMonthOfYear()
	local loYear = CCurrentGameState.GetCurrentDate():GetYear()
	if not (loMonth < 6 and loYear == 1941) or loYear > 1941 then
	-- Get a list of all your allies
		local laAllies = {}
		for loAllyTag in voForeignMinisterData.ministerCountry:GetAllies() do
			local loAllyCountry = loAllyTag:GetCountry()

		-- Exclude Puppets from this list
			if not(loAllyCountry:IsPuppet()) then
				local loAlly = {
					AllyTag = loAllyTag,
					AllyCountry = loAllyCountry,
					Continent = tostring(loAllyCountry:GetActingCapitalLocation():GetContinent():GetTag()),
				}
			
				laAllies[tostring(loAllyTag)] = loAlly
			end
		end
	
		local loSOVtag = CCountryDataBase.GetTag("SOV")
	
	-- Go through our Wars
		for loDiploStatus in voForeignMinisterData.ministerCountry:GetDiplomacy() do
			local loTargetTag = loDiploStatus:GetTarget()
		
			if loTargetTag:IsValid() and loDiploStatus:HasWar() then
				local loWar = loDiploStatus:GetWar()
			
				if loWar:IsLimited() then
					local lsTargetTag = tostring(loTargetTag)
					local liWarMonths = loWar:GetCurrentRunningTimeInMonths()
					local loTargetCountry = loTargetTag:GetCountry()
				
				-- Call in all potential allies
					for k, v in pairs(laAllies) do
					-- Check to see if the two are already at war?
						if not(v.AllyCountry:GetRelation(loTargetTag):HasWar()) then
						-- Call noone whose capital is in Asia and the target is not USA
							if v.Continent ~= "asia" and lsTargetTag ~= "USA" then
							-- We are desperate so overide all else statements
								if lsTargetTag == "SOV" then
									if (liWarMonths > 5) or voForeignMinisterData.humanTag == loSOVtag then
										Support.ExecuteCallAlly(voForeignMinisterData.ministerAI, voForeignMinisterData.ministerTag, v, loTargetTag)
									end
								
							-- When to Call Italy into the war
								elseif k == "ITA" then
									local loParisFaction = CCurrentGameState.GetProvince(2613):GetController():GetCountry():GetFaction()
								
									if loParisFaction == voForeignMinisterData.Faction 	then --paris
										Support.ExecuteCallAlly(voForeignMinisterData.ministerAI, voForeignMinisterData.ministerTag, v, loTargetTag)
									end
							-- Standard catch all call anyone on our enemies border
								elseif lsTargetTag ~= "POL" then
									if voForeignMinisterData.Year <= 1941 then
									-- Do not call Allies who are on the border with Russia
										if not(v.AllyCountry:IsNonExileNeighbour(loSOVtag)) then
										-- Call in Allies that are neighbors to our enemy
											if loTargetCountry:IsNonExileNeighbour(v.AllyTag) then
												Support.ExecuteCallAlly(voForeignMinisterData.ministerAI, voForeignMinisterData.ministerTag, v, loTargetTag)
											end
										end
									else
										-- Call in Allies that are neighbors to our enemy
										if loTargetCountry:IsNonExileNeighbour(v.AllyTag) then
											Support.ExecuteCallAlly(voForeignMinisterData.ministerAI, voForeignMinisterData.ministerTag, v, loTargetTag)
										end
									end
								end
							elseif lsTargetTag == "USA" then
							-- It is USA so call everyone
								Support.ExecuteCallAlly(voForeignMinisterData.ministerAI, voForeignMinisterData.ministerTag, v, loTargetTag)
							end
						end
					end
				end
			end
		end
	end
	return false
end

function P.ForeignMinister_MilitaryAccess(voForeignMinisterData)
	-- Make sure Germany is in the Axis and if not let default code run
	if voForeignMinisterData.FactionName == "axis" then
		-- Special Access Checks for Sweden
		if voForeignMinisterData.IsAtWar then
			local loSWETag = CCountryDataBase.GetTag("SWE")
			local loRelationSwe = voForeignMinisterData.ministerAI:GetRelation(voForeignMinisterData.ministerTag, loSWETag)
			
			if not(loRelationSwe:HasMilitaryAccess()) then
				if not(voForeignMinisterData.Strategy:IsPreparingWarWith(loSWETag)) then
					local loOsloFaction = CCurrentGameState.GetProvince(812):GetController():GetCountry():GetFaction()
					
					-- Ask Sweden for Access if Oslo is controlled by someone in the Axis
					if loOsloFaction == voForeignMinisterData.Faction then
						local loCommand = CMilitaryAccessAction(voForeignMinisterData.ministerTag, loSWETag)

						if loCommand:IsSelectable() then
							local liScore = DiploScore_DemandMilitaryAccess(voForeignMinisterData.ministerAI, voForeignMinisterData.ministerTag, loSWETag, voForeignMinisterData.ministerTag)

							if liScore > 50 then
								voForeignMinisterData.minister:Propose(loCommand, liScore)
							end
						end
					end
				end
			end
		end
	end
	
	return true
end

function P.Intel_Priority(voIntelligenceData, voIntelCountry)
	local liReturn = 0
	
	if not(voIntelCountry.IsExiled) then
		-- Annexation of Austria has an or clause so support our party 
		if not(voIntelligenceData.IsAtWar) and voIntelligenceData.Year <= 1938 then
			if tostring(voIntelCountry.ministerTag) == "AUS" then
				liReturn = 3
			end
		end
	end
	
	return liReturn
end

function P.Intel_Mission(voIntelligenceData, voIntelCountry)
	local liReturn = nil
	
	if not(voIntelCountry.IsExiled) then
		-- Annexation of Austria has an or clause so support our party 
		if not(voIntelligenceData.IsAtWar) and voIntelligenceData.Year <= 1938 then
			if tostring(voIntelCountry.ministerTag) == "AUS" then
				liReturn = SpyMission.SPYMISSION_BOOST_OUR_PARTY
			end
		end
	end
	
	return liReturn
end

function P.ForeignMinister_ProposeWar(voForeignMinisterData)
				
  if voForeignMinisterData.Year > 1939 then
	if not(voForeignMinisterData.Strategy:IsPreparingWar()) then
		if voForeignMinisterData.FactionName == "axis" then	
			local loSOVTag = CCountryDataBase.GetTag("SOV")
			local loSpdSovRelation = voForeignMinisterData.ministerCountry:GetRelation(loSOVTag)
			
			-- If we are atwar with Russia then do not even think of DOWing anyone else
			if not(loSpdSovRelation:HasWar()) then
				local laWarTags = {}
				local laPeaceTags = {}
				local liTotalNeighborWars = 0
				
				local loUSATag = CCountryDataBase.GetTag("USA")
				local loUsaSovRelation = voForeignMinisterData.ministerCountry:GetRelation(loUSATag)
				local loUSAWar = loUsaSovRelation:HasWar()
				
				-- Since atwar figure out how many fronts we have
				for loNeighborTag in voForeignMinisterData.ministerCountry:GetControllerNeighbours() do
					local lsNeighborTag = tostring(loNeighborTag)
					local loNeighborRelation = voForeignMinisterData.ministerCountry:GetRelation(loNeighborTag)
					local loNeighborCountry = loNeighborTag:GetCountry()
					
					if loNeighborRelation:HasWar() then
						laWarTags[lsNeighborTag] = {
							Tag = loNeighborTag,
							Country = loNeighborCountry,
							Realtion = loNeighborRelation}

						-- If we are at war with USA count everyone
						if loUSAWar then
							liTotalNeighborWars = liTotalNeighborWars + 1
						else
							if lsNeighborTag ~= "NOR" then
								-- Do not count these as a front
								if lsNeighborTag ~= "ENG"
								or lsNeighborTag ~= "LUX"
								or lsNeighborTag ~= "BEL" 
								or lsNeighborTag ~= "HOL" then
									if lsNeighborTag == "SPA" or lsNeighborTag == "SPR" then
										local loGibraltarTag = CCurrentGameState.GetProvince(5191):GetController()
										local loGibraltarRelation = voForeignMinisterData.ministerCountry:GetRelation(loGibraltarTag)
										
										-- Gibraltar check, if Germany is not at war with the owner in case something weird happens
										if loGibraltarRelation:HasWar() then 
											liTotalNeighborWars = liTotalNeighborWars + 1
										end
									else
										liTotalNeighborWars = liTotalNeighborWars + 1
									end
								end
							end
						end
					else
						if lsNeighborTag == "SOV" then
							if not(voForeignMinisterData.ministerCountry:GetFlags():IsFlagSet("su_signs_peace")) then
								if Support.GoodToWarCheck(loNeighborTag, loNeighborCountry, voForeignMinisterData, true, true, true) then
									-- Add them to an array in case we do not have neighbors and need a target
									laPeaceTags[lsNeighborTag] = {
										Tag = loNeighborTag,
										Name = lsNeighborTag,
										Country = loNeighborCountry,
										IsFriend = Support.IsFriend(voForeignMinisterData.ministerAI, voForeignMinisterData.Faction, loNeighborCountry),
										Realtion = loNeighborRelation}
								end
							end
						else
							-- Make sure they are ok for us to DOW
							if Support.GoodToWarCheck(loNeighborTag, loNeighborCountry, voForeignMinisterData, true) then
								laPeaceTags[lsNeighborTag] = {
									Tag = loNeighborTag,
									Name = lsNeighborTag,
									Country = loNeighborCountry,
									IsFriend = Support.IsFriend(voForeignMinisterData.ministerAI, voForeignMinisterData.Faction, loNeighborCountry),
									Realtion = loNeighborRelation}
							end
						end
					end
				end		

				-- Only process these requests if prior to 1941 for performance reasons
				--   no reason for Germany to constantly monitor countries after this time
				if voForeignMinisterData.IsAtWar and voForeignMinisterData.Year <= 1941 then
					-- If we have more than one front do nothing
					if liTotalNeighborWars <= 3 then
						P.DenmarkCheck(voForeignMinisterData, laPeaceTags)
						P.NorwayCheck(voForeignMinisterData)
						
						-- Plan the Low Countries, Denmark and Norway invasions
						if laWarTags["FRA"] then
							P.LowCountriesCheck(voForeignMinisterData, laPeaceTags)
						else
							-- Check if we need to invade Low Countries
							if not(P.LowCountriesCheck(voForeignMinisterData, laPeaceTags, true)) then
								if liTotalNeighborWars < 3	and (math.random(100) < 95) then
									if not(P.YugoslaviaCheck(voForeignMinisterData, laPeaceTags)) then
										P.GreeceCheck(voForeignMinisterData, laPeaceTags)
									end
								end
							end
						end
					end
					
				-- Something happend and no war so start one in 1940
				elseif not(voForeignMinisterData.IsAtWar) and voForeignMinisterData.Year == 1940 then
					-- Declare random war on one of our neighbors
					for k, v in pairs(laPeaceTags) do
						if math.random(100) < 85 and not(v.IsFriend) then
							voForeignMinisterData.Strategy:PrepareLimitedWar(laPeaceTags[k].Tag, 100)
						end
					end
					
				-- We have no fronts
				elseif liTotalNeighborWars == 0 then
					-- Only look at this if we are at war or the year is 1941 or greater
					if voForeignMinisterData.IsAtWar or voForeignMinisterData.Year > 1940 then
						local lbYugoWar = false
						local lbGreeceWar = false
						
						P.DenmarkCheck(voForeignMinisterData, laPeaceTags)
						P.NorwayCheck(voForeignMinisterData)
						
						-- Low Countries check
						if not(P.LowCountriesCheck(voForeignMinisterData, laPeaceTags, true)) then
							-- Look at the Baklans for a war
							if voForeignMinisterData.IsAtWar then
								lbYugoWar = P.YugoslaviaCheck(voForeignMinisterData, laPeaceTags)
								
								-- Do not do the Greece check if Yugo is starting as it already called GreeceCheck
								if lbYugoWar then
									lbGreeceWar = P.GreeceCheck(voForeignMinisterData, laPeaceTags)
								end
							end
						
							if not(lbYugoWar) and not(lbGreeceWar) then
								-- Potential Wars with neighbors
								for k, v in pairs(laPeaceTags) do
									if math.random(100) < 85 and not(v.IsFriend) then
										if v.Name == "SOV" then
											if voForeignMinisterData.Month >= 4 and voForeignMinisterData.Month <= 7 then
												local loParisFaction = CCurrentGameState.GetProvince(2613):GetController():GetCountry():GetFaction()
												-- If an Axis member controls Paris then consider DOWing Soviets
												if loParisFaction == voForeignMinisterData.Faction then
													voForeignMinisterData.Strategy:PrepareLimitedWar(laPeaceTags[k].Tag, 100)
												end
											end
										else
											voForeignMinisterData.Strategy:PrepareLimitedWar(laPeaceTags[k].Tag, 100)
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
  end	
end

function P.DenmarkCheck(voForeignMinisterData, vaPeaceTags)
	if vaPeaceTags["DEN"] then
		voForeignMinisterData.Strategy:PrepareLimitedWar(vaPeaceTags["DEN"].Tag, 100)
		return true
	end
	
	return false
end

function P.NorwayCheck(voForeignMinisterData)
	-- Took to long to DOW so don't do it or we are desperate
	if voForeignMinisterData.Year > 1940 or voForeignMinisterData.Desperation > 0.4 then
		return false
	end
	
	-- Wait for Good Weather
	if voForeignMinisterData.Month >= 2 and voForeignMinisterData.Month <= 8 then
		-- Check to see if we have the Invasion Craft for this
		local laTempCurrent = voForeignMinisterData.ministerAI:GetDeployedSubUnitCounts()
		
		for loUnit in CSubUnitDataBase.GetSubUnitList() do
			local lsUnitType = loUnit:GetKey():GetString() 

			if lsUnitType == "transport_ship" then
				if laTempCurrent:GetAt(loUnit:GetIndex()) < 3 then
					return false
				end
			end
		end
		-- End of Transport check
		
		local loCopenhagenFaction = CCurrentGameState.GetProvince(1482):GetController():GetCountry():GetFaction()

		-- If someone in our Faction controls Copenhagen
		if loCopenhagenFaction == voForeignMinisterData.Faction then
			local loNORTag = CCountryDataBase.GetTag("NOR")
			local loNorwayCountry = loNORTag:GetCountry()
			local lbDOW = Support.GoodToWarCheck(loNORTag, loNorwayCountry, voForeignMinisterData, true)
			
			if lbDOW then
				voForeignMinisterData.Strategy:PrepareLimitedWar(loNORTag, 100)
			end			
			
			return lbDOW
		end
	end
	
	return false
end

function P.LowCountriesCheck(voForeignMinisterData, vaPeaceTags, vbOveride)
	local lbDOW = false

	-- Wait for good weather months to attack
	if (voForeignMinisterData.Month >= 3 and voForeignMinisterData.Month <= 7) or vbOveride then
		-- Belgium Check
		if vaPeaceTags["BEL"] then
			voForeignMinisterData.Strategy:PrepareLimitedWar(vaPeaceTags["BEL"].Tag, 100)
			lbDOW = true
		end
		
		-- Netherlands Check
		if vaPeaceTags["HOL"] then
			voForeignMinisterData.Strategy:PrepareLimitedWar(vaPeaceTags["HOL"].Tag, 100)
			lbDOW = true
		end
		
		-- Luxemburg Check
		if vaPeaceTags["LUX"] then
			voForeignMinisterData.Strategy:PrepareLimitedWar(vaPeaceTags["LUX"].Tag, 100)
			lbDOW = true
		end
	end
	
	return lbDOW
end

function P.YugoslaviaCheck(voForeignMinisterData, vaPeaceTags)
	if vaPeaceTags["YUG"] then
		voForeignMinisterData.Strategy:PrepareLimitedWar(vaPeaceTags["YUG"].Tag, 100)
		P.GreeceCheck(voForeignMinisterData, vaPeaceTags, true)
		return true
	end
	
	return false
end

function P.GreeceCheck(voForeignMinisterData, vaPeaceTags, vbYugoDOW)
	if not(vaPeaceTags["GRE"]) then
		local loGRETag = CCountryDataBase.GetTag("GRE")
		local loGreeceCountry = loGRETag:GetCountry()

		if Support.GoodToWarCheck(loGRETag, loGreeceCountry, voForeignMinisterData, vbYugoDOW) then
			voForeignMinisterData.Strategy:PrepareLimitedWar(loGRETag, 100)
			return true
		end
	else
		voForeignMinisterData.Strategy:PrepareLimitedWar(vaPeaceTags["GRE"].Tag, 100)
		return true
	end
	
	return false
end

--##########################
-- Politics Minister Hooks

-- Create very highly trained troops
function P.CallLaw_training_laws(minister, voCurrentLaw)
	local _SPECIALIST_TRAINING_ = 30
	return CLawDataBase.GetLaw(_SPECIALIST_TRAINING_)
end

-- we dont bother accepting for LL to JAP, its too dangerous and not very historical
function P.DiploScore_RequestLendLease( liScore, voAI, voActorTag )
	if tostring(voActorTag) == "JAP" then
		return 0
	end
	return liScore
end

return AI_SPD
