local P = {}
AI_GER = P

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
		0.20, -- landBasedWeight
		0.20, -- landDoctrinesWeight
		0.11, -- airBasedWeight
		0.10, -- airDoctrinesWeight
		0.03, -- navalBasedWeight
		0.04, -- navalDoctrinesWeight
		0.14, -- industrialWeight
		0.08, -- secretWeaponsWeight
		0.10}; -- otherWeight

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
			--{"garrison_deployment", 0},
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
			--{"garrison_deployment", 0},
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
		"infantry_activation",
		"light_infantry_brigade_activation",
		"special_forces_upgrade",
		"Vehicle_reliability",
		"semi_motorization",
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
		"art_barrel_ammo",
		"gun_carriage",
		"range_finding",
		"small_calibre_gun_design",
		"medium_velocity_gun",
		"high_velocity_gun",
		"Artillery_motorization",
		"gasoline_engine_design",
		"tank_chassis_design",
		"advanced_tank_chassis_design",
		"light_armor_brigade_design",
		"armor_brigade_design",
		"heavy_armor_brigade_design",
		"armor_plate_design",
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
		"superior_strength",
		"divisonal_command_structure",
		"Corps_command_structure",
		"army_command_structure",
		"armygroup_command_structure",
		"supreme_command_coordination",
		"interservice_HQ_structure"};

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
		{"battlefield_interdiction", 0},
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
		{"three_three", 0},
		{"three_three_reverse", 0},
		{"four_two", 0},
		{"four_two_reverse", 0},
		{"four_three", 0},
		{"four_three_reverse", 0},
		{"three_four", 0},
		{"three_four_reverse", 0},
		{"five_two", 0},
		{"five_two_reverse", 0},
		{"six_two", 0},
		{"two_four", 0},
		{"four_two_four", 0},
		{"three_three_front", 0},
		{"three_two_two_three", 0},
		{"light_carrier_technology", 0},
		{"carrier_class", 0},
		{"carrier_technology", 0},
		{"carrier_light_anti_air_artillery", 0},
		{"carrier_medium_anti_air_artillery", 0},
		{"carrier_heavy_anti_air_artillery", 0},
		{"carrier_screws_optimisation", 0},
		{"carrier_rudder_optimisation", 0},
		{"carrier_hull_shape_optimisation", 0},
		{"carrier_armour_thickness", 0},
		{"light_carrier_armour_thickness", 0},
		{"carrier_vertical_protection", 0},
		{"carrier_horizontal_protection", 0},
		{"carrier_torpedo_protection", 0},
		{"carrier_bulkheads_layout", 0},
		{"carrier_hanger", 0},
		{"escort_carrier_technology", 0},
		{"seaplane_tender_technology", 0},
		{"carrier_deck_armour_optimisation", 0},
		{"carrier_flight_deck_optimisation", 0},
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
		{"deck_park", 0}};

	local preferTech = {
		"battleship_technology",
		"battleship_class",
		"battlecruiser_technology",
		"battlecruiser_class",
		"pocket_battleship_activation",
		"capitalship_armament",
		"capitalship_armament_AP_ammo",
		"capitalship_armament_HE_ammo",
		"capitalship_secondary",
		"capital_ship_engine",
		"capital_ship_boilers",
		"capital_ship_turbines",
		"capital_ship_screws_optimisation",
		"capital_ship_rudder_optimisation",
		"capital_ship_hull_shape_optimisation",
		"battlecruiser_armour_thickness",
		"battleship_armour_thickness",
		"super_heavy_battleship_armour_thickness",
		"capital_ship_vertical_protection",
		"capital_ship_horizontal_protection",
		"capital_ship_torpedo_protection",
		"capital_ship_bulkheads_layout",
		"super_heavy_battleship_technology",
		"fast_battleship",
		"largewarship_surface_radar",
		"largewarship_air_detection_radar",
		"capitalship_damage_control",
		"fire_control_computer",
		"AAA_control_computer",
		"floatplane_dev_scout",
		"floatplane_dev_torpedo",
		"floatplane_dev_fighter",
		"capital_ship_light_anti_air_artillery",
		"capital_ship_medium_anti_air_artillery",
		"capital_ship_heavy_anti_air_artillery",
		"transport_ship_activation",
		"transport_ship_hull",
		"transport_ship_engine",
		"amphibious_invasion_craft",
		"advanced_invasion_craft",
		"amphibious_invasion_tactics",
		"amphibious_ship_defenses",
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
		"steel_casting_capability",
		"steel_electro_welding_technology",
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

	if  voProductionData.Year <= 1938 then
		laArray = {
			0.60, -- Land
			0.325, -- Air
			0.05, -- Sea
			0.025}; -- Other
	elseif  voProductionData.Year >= 1938 then
		laArray = {
			0.65, -- Land
			0.225, -- Air
			0.10, -- Sea
			0.025}; -- Other
	-- War time
	elseif voProductionData.IsAtWar then
		laArray = {
			0.60, -- Land
			0.25, -- Air
			0.10, -- Sea
			0.05}; -- Other
	end

	-- Less navy if player isn't an Ally Major (otherwise subs wreck ENG navy and favor player) (IC is diverted to land)
	local engTag = CCountryDataBase.GetTag("ENG")
	local sovTag = CCountryDataBase.GetTag("SOV")
	local usaTag = CCountryDataBase.GetTag("USA")
	local fraTag = CCountryDataBase.GetTag("FRA")
	if not (voProductionData.humanTag == engTag) and not (voProductionData.humanTag == usaTag) and not (voProductionData.humanTag == fraTag) then
		-- fraction of less navy, diverted to land
		local fraction = laArray[3] * 0.75
		laArray[1] = laArray[1] + fraction
		laArray[3] = laArray[3] - fraction
	end

	-- Manpower check
	if voProductionData.ManpowerTotal < 600 then
		laArray = {
			0.00, -- Land
			0.40, -- Air
			0.40, -- Sea
			0.20}; -- Other
	end

	return laArray
end
-- Land ratio distribution

-- Lots of armor at the beginning for the Blitzkrieg, lots of infantry later to invade the USSR
function P.LandRatio(voProductionData)
	local laArray
		local sovTag = CCountryDataBase.GetTag("SOV")

	if voProductionData.humanTag == sovTag then
		if voProductionData.Year <= 1939 or (voProductionData.Year ==1940 and voProductionData.Month <= 5) then
			laArray = {
				garrison_brigade = 8,
				infantry_brigade = 16,
				motorized_brigade = 2,
				light_armor_brigade = 2,
				armor_brigade = 6,
				heavy_armor_brigade = 1};


		else
			laArray = {
				garrison_brigade = 6,
				infantry_brigade = 20,
				ss_motorized_brigade = 0.4,
				ss_infantry_brigade = 1,
				ss_armor_brigade = 0.2,
				light_armor_brigade = 1,
				motorized_brigade = 1,
				mechanized_brigade = 4,
				armor_brigade = 4,
				heavy_armor_brigade = 1};
		end


	elseif voProductionData.Year <= 1939 or (voProductionData.Year ==1940 and voProductionData.Month <= 5) then
		laArray = {
			garrison_brigade = 7,
			infantry_brigade = 12,
			motorized_brigade = 1,
			light_armor_brigade = 1,
			armor_brigade = 3,
			heavy_armor_brigade = 0.5};


	elseif voProductionData.Year <= 1943 then
		laArray = {
			garrison_brigade = 3,
			infantry_brigade = 16,
			ss_motorized_brigade = 0.1,
			ss_infantry_brigade = 0.1,
			ss_armor_brigade = 0.1,
			motorized_brigade = 1,
			mechanized_brigade = 1.5,
			armor_brigade = 2.5,
			heavy_armor_brigade = 0.5};
	else
		laArray = {
			garrison_brigade = 3,
			infantry_brigade = 4,
			ss_motorized_brigade = 0.1,
			ss_infantry_brigade = 0.1,
			ss_armor_brigade = 0.15,
			motorized_brigade = 1,
			mechanized_brigade = 2,
			armor_brigade = 3,
			heavy_armor_brigade = 0.5};


	end

	laArray.bergsjaeger_brigade = 0.2
	laArray.paratrooper_brigade = 0.1

	return laArray
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
		interceptor = 10,
		multi_role = 1,
		rocket_interceptor = 1,
		cas = 5,
		light_bomber = 5,
		tactical_bomber = 3,
		naval_bomber = 1};

	return laArray
end

-- Naval ratio distribution
function P.NavalRatio(voProductionData)
	local laArray = {
		transport_ship = 2,
		destroyer_actual = 1, -- Destroyers
		submarine = 6.5, -- Submarines
		long_range_submarine = 3.5
	};

	return laArray
end

-- Transport to Land unit distribution
-- UNUSED
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

-- Garrison builds - GAR+(ART|HVYART)+SUPPORTSx2 ("Garrison" Support Group)

function P.Build_motorized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	if (voProductionData.Year <= 1938) then

		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "anti_tank_brigade"
		voType.second = "artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

		else


		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "tank_destroyer_brigade"
		voType.second = "artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.fourth = "motorized_engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end


	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

function P.Build_mechanized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	if (voProductionData.Year <= 1940) then

		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "tank_destroyer_brigade"
		voType.second = "sp_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.fourth = "motorized_engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

	else


		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "medium_tank_destroyer_brigade"
		voType.second = "artillery_brigade"
		voType.third = "assault_gun_brigade"
		voType.fourth = "motorized_engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

function P.Build_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	local sovTag = CCountryDataBase.GetTag("SOV")



	if voProductionData.humanTag == sovTag then
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "mechanized_infantry_bat"
		voType.SecondaryMain = "sp_artillery_brigade"
		voType.third = "armored_engineers_brigade"
		voType.fifth = "medium_tank_destroyer_brigade"

		voType.Support = 0
		voType.SupportVariation = 0

	elseif (voProductionData.Year <= 1939) then

		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "motorized_infantry_bat"
		voType.second = "artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.SecondaryMain = "anti_tank_brigade"

		voType.Support = 0
		voType.SupportVariation = 0

	else


		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "mechanized_infantry_bat"
		voType.second = "sp_artillery_brigade"
		voType.third = "tank_destroyer_brigade"
		voType.SecondaryMain = "assault_gun_brigade"

		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end


function P.Build_heavy_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	local sovTag = CCountryDataBase.GetTag("SOV")


	if voProductionData.humanTag == sovTag then
		voType.SecondaryMain = "mechanized_brigade"
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_veteran"
		voType.second = "sp_artillery_brigade"
		voType.third = "medium_tank_destroyer_brigade"
		voType.fourth = "armored_engineers_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

	else
		voType.SecondaryMain = "mechanized_brigade"
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_veteran"
		voType.second = "sp_artillery_brigade"
		voType.third = "medium_tank_destroyer_brigade"
		voType.fourth = "armored_engineers_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end


	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

function P.Build_light_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)


		voType.SecondaryMain = "tank_destroyer_brigade"
		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "motorized_infantry_bat"
		voType.second = "artillery_brigade"
		voType.fourth = "motorized_engineer_brigade"

		voType.Support = 0
		voType.SupportVariation = 0

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end


function P.Build_infantry_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	if (voProductionData.Year <= 1938) then

		voType.TransportMain = "horse_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "anti_tank_brigade"
		voType.second = "medium_artillery_brigade"
		voType.third = "heavy_anti_air_brigade"
		voType.SecondaryMain = "engineer_brigade"

		voType.Support = 0
		voType.SupportVariation = 0

		else


		voType.TransportMain = "horse_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "medium_tank_destroyer_brigade"
		voType.second = "medium_artillery_brigade"
		voType.SecondaryMain = "engineer_brigade"
		voType.fourth = "mixed_support_brigade"

		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

function P.Build_ss_infantry_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	if (math.random(100) < 33) then
		voType.SecondaryMain = "ss_heavy_armor_brigade"
		voType.TransportMain = "horse_transport"
		voType.TertiaryMain = "division_hq_SS_standard"
	else
		voType.SecondaryMain = "ss_anti_tank_brigade"
		voType.TransportMain = "horse_transport"
		voType.TertiaryMain = "division_hq_SS_standard"
	end

		voType.Support = 3
		voType.SupportVariation = 0

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

-- Build Atleast 1 rocket test site
function P.Build_RocketTest(ic, voProductionData)

	local rocket_test = CBuildingDataBase.GetBuilding( "rocket_test" )
	local loProvince = CCurrentGameState.GetProvince(1681) -- Wolgast
	local loBuilding = loProvince:GetBuilding(rocket_test)

	if loBuilding:GetMax():Get() < 2 then
		ic = Support.Build_RocketTest(ic, voProductionData, 1681, 1) -- Wolgast
	end

	return ic, false
end

-- Never build and underground
function P.Build_Underground(ic, voProductionData)
	return ic, false
end

-- Have Germany Fortify the French Line
-- NOTE: if 2490 Province is not the last one please update the land production ratio
function P.Build_Fort(ic, voProductionData)

	-- Only build Siegfried Line if its 1938 or less
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

	-- After France, build Coastal Fort in general
	if voProductionData.Year >= 1942 then
		return vIC, true
	end

	return vIC, false
end

function P.Build_NavalBase(vIC, voProductionData)

	return vIC, false
end

function P.Build_AirBase(vIC, voProductionData)
	return vIC, true
end

function P.Build_AntiAir(vIC, voProductionData)

	-- After France, build AA in general
	if voProductionData.Year >= 1940 then
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

	-- Embargo Americas if at war
	if voDiploScoreObj.IsAtWar then
		local continent = tostring(voDiploScoreObj.EmbargoCountry:GetCapitalLocation():GetContinent():GetTag())
		local isPlayer = CCurrentGameState.IsPlayer(voDiploScoreObj.EmbargoCountry:GetCountryTag())
		if (continent == "north_america" or continent == "south_america") and not isPlayer then
			voDiploScoreObj.Score = 200
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
Utils.LUA_DEBUGOUT("GER exp ")
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
			"BEL", -- Belgium
			"HOL", -- Holland
			"HUN"};	 -- Hungary

		laIgnoreWatch = {
			"SPA", -- Spain
			"SPR", -- Republic Spain
			"POR", -- Portugal
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
--Utils.LUA_DEBUGOUT("GER decides on: " .. tostring(voDecision.Name))
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
				-- Utils.LUA_DEBUGOUT("GER prep war: " .. tostring(voDecision.Name))
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

			local loAlly = {
				AllyTag = loAllyTag,
				AllyCountry = loAllyCountry,
				Continent = tostring(loAllyCountry:GetActingCapitalLocation():GetContinent():GetTag()),
			}

			laAllies[tostring(loAllyTag)] = loAlly
		end

		local loSOVtag = CCountryDataBase.GetTag("SOV")

		-- Go through our Wars
		for loDiploStatus in voForeignMinisterData.ministerCountry:GetDiplomacy() do
			local loTargetTag = loDiploStatus:GetTarget()

			if loTargetTag:IsValid() and loDiploStatus:HasWar() then
				local loWar = loDiploStatus:GetWar()

				if loWar:IsLimited() then
					local lsTargetTag = tostring(loTargetTag)
					local loTargetCountry = loTargetTag:GetCountry()

					--Utils.LUA_DEBUGOUT("Calling Allies for war with " .. lsTargetTag)

					-- Call in all potential allies
					for k, v in pairs(laAllies) do

						--Utils.LUA_DEBUGOUT("Checking with " .. k)

						-- Check to see if the two are already at war?
						if not(v.AllyCountry:GetRelation(loTargetTag):HasWar()) then
							-- Call noone whose capital is in Asia and the target is not USA
							--Utils.LUA_DEBUGOUT("Not at war already")
							if v.Continent ~= "asia" and lsTargetTag ~= "USA" then
								--Utils.LUA_DEBUGOUT("Not in asia")
								-- Call all against SOV
								if lsTargetTag == "SOV" then
									--Utils.LUA_DEBUGOUT("Against SOV")
									Support.ExecuteCallAlly(voForeignMinisterData.ministerAI, voForeignMinisterData.ministerTag, v, loTargetTag)

								-- When to Call Italy into the war
								elseif k == "ITA" then
									local loParisFaction = CCurrentGameState.GetProvince(2613):GetController():GetCountry():GetFaction() -- Paris

									if loParisFaction == voForeignMinisterData.Faction or v.AllyCountry:GetFlags():IsFlagSet("join_germanys_war_yes") then
										Support.ExecuteCallAlly(voForeignMinisterData.ministerAI, voForeignMinisterData.ministerTag, v, loTargetTag)
									end

								-- Standard catch all call anyone on our enemies border (not target POL)
								elseif lsTargetTag ~= "POL" then
									--Utils.LUA_DEBUGOUT("Against other")
									if voForeignMinisterData.Year < 1941 then
										--Utils.LUA_DEBUGOUT("Before 1941")
										-- Do not call Allies who are on the border with Russia
										if not(v.AllyCountry:IsNonExileNeighbour(loSOVtag)) then
											--Utils.LUA_DEBUGOUT("Call not bordering SOV")
											-- Call in Allies that are neighbors to our enemy
											if loTargetCountry:IsNonExileNeighbour(v.AllyTag) then
												Support.ExecuteCallAlly(voForeignMinisterData.ministerAI, voForeignMinisterData.ministerTag, v, loTargetTag)
											end
										end
									else
										--Utils.LUA_DEBUGOUT("After 1941 just call")
										Support.ExecuteCallAlly(voForeignMinisterData.ministerAI, voForeignMinisterData.ministerTag, v, loTargetTag)
									end
								end
							elseif lsTargetTag == "USA" then
								--Utils.LUA_DEBUGOUT("Against USA call all")
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
			local loGerSovRelation = voForeignMinisterData.ministerCountry:GetRelation(loSOVTag)

			-- If we are atwar with Russia then do not even think of DOWing anyone else
			if not(loGerSovRelation:HasWar()) then
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
						end
						local loAxis = CCurrentGameState.GetFaction("axis")
						local lobelgradeFaction = CCurrentGameState.GetProvince(3912):GetController():GetCountry():GetFaction()
						local loBordeauxFaction = CCurrentGameState.GetProvince(3479):GetController():GetCountry():GetFaction() --make sure France is beat

						if voForeignMinisterData.Year == 1941 and voForeignMinisterData.Month >= 2 and not(lobelgradeFaction == loAxis) and loBordeauxFaction == loAxis then
							P.YugoslaviaCheck(voForeignMinisterData, laPeaceTags)
						end
					end
				end
			end
			local loSchTag = CCountryDataBase.GetTag('SCH')
			local loSpaTag = CCountryDataBase.GetTag('SPA')
			local loSweTag = CCountryDataBase.GetTag('SWE')

			if not(voForeignMinisterData.ministerCountry:GetRelation(loSchTag):HasWar()) and voForeignMinisterData.ministerCountry:GetFlags():IsFlagSet("lua_war_swiss")  then
				voForeignMinisterData.Strategy:PrepareWar(loSchTag, 100)
			end
			if not(voForeignMinisterData.ministerCountry:GetRelation(loSpaTag):HasWar()) and voForeignMinisterData.ministerCountry:GetFlags():IsFlagSet("lua_war_spain")  then
				voForeignMinisterData.Strategy:PrepareWar(loSpaTag, 100)
			end
			if not(voForeignMinisterData.ministerCountry:GetRelation(loSweTag):HasWar()) and voForeignMinisterData.ministerCountry:GetFlags():IsFlagSet("lua_war_sweden")  then
				voForeignMinisterData.Strategy:PrepareWar(loSweTag, 100)
			end
		end
	end
  end
end

function P.DenmarkCheck(voForeignMinisterData, vaPeaceTags)
	if vaPeaceTags["DEN"] then
		--voForeignMinisterData.Strategy:PrepareLimitedWar(vaPeaceTags["DEN"].Tag, 100)
		return false	--was true, not sure if it has any effect
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
	if (voForeignMinisterData.Month >= 4 and voForeignMinisterData.Month <= 7) or vbOveride then
		-- Belgium Check
		if vaPeaceTags["BEL"] then
			--voForeignMinisterData.Strategy:PrepareLimitedWar(vaPeaceTags["BEL"].Tag, 100)
			lbDOW = true
		end

		-- Netherlands Check
		if vaPeaceTags["HOL"] then
			--voForeignMinisterData.Strategy:PrepareLimitedWar(vaPeaceTags["HOL"].Tag, 100)
			lbDOW = true
		end

		-- Luxemburg Check
		if vaPeaceTags["LUX"] then
			--voForeignMinisterData.Strategy:PrepareLimitedWar(vaPeaceTags["LUX"].Tag, 100)
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

		voForeignMinisterData.Strategy:PrepareLimitedWar(loGRETag, 100)
		return true
	end

	return false
end

--##########################
-- Politics Minister Hooks

return AI_GER