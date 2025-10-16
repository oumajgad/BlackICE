local P = {}
AI_FRA = P

-- #######################################

-- Tech weights
--   1.0 = 100% the total needs to equal 1.0
function P.TechWeights(voTechnologyData)
	local laTechWeights = {
		0.20, -- landBasedWeight
		0.11, -- landDoctrinesWeight
		0.15, -- airBasedWeight
		0.10, -- airDoctrinesWeight
		0.10, -- navalBasedWeight
		0.10, -- navalDoctrinesWeight
		0.12, -- industrialWeight
		0.00, -- secretWeaponsWeight
		0.12}; -- otherWeight

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
			{"improved_police_brigade", 0},
			{"garrison_deployment", 0},
			{"officer_recruitment_program", 0},
			{"emergency_recruitment_legislation", 0},
			{"jungle_warfare_equipment", 0},
			{"airlanding_infantry_brigade_activation", 0},
			{"airborne_artillery_brigade_activation", 0},
			{"rocket_art", 0},
			{"rocket_art_ammo", 0},
			{"assault_gun_brigade_activation", 0},
			{"sp_rct_art_brigade_design", 0},
			{"sp_anti_air_design", 0},
			{"AFV_AA_defense", 0},
			{"heavy_assault_gun_brigade_activation", 0},
			{"armor_alloy", 0},
			{"interlocked_armour", 0},
			{"heavy_tank_destroyer_brigade_activation", 0},
			{"Tenacious_defense", 0},
			{"machine_gun_doctrine", 0},
			{"asymmetric_warfare_dev", 0},
			{"urban_Fighting_Equipment_and_Training", 0},
			{"ski_brigade_activation", 0},
			{"militia_increase", 1},
			{"infantry_increase", 1},
			{"special_forces_increase", 1},
			{"mobile_increase", 1},
			{"armor_increase", 1},
			{"recon_increase", 1},
			{"artillery_increase", 1},
			{"armorsupport_increase", 1},
			{"aa_at_increase", 1},
			{"engineers_increase", 1},
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
			{"desert_warfare_equipment", 0},
			{"jungle_warfare_equipment", 0},
			{"artic_warfare_equipment", 0},
			{"amphibious_warfare_equipment", 0},
			{"airborne_warfare_equipment ", 0},
			{"airlanding_infantry_brigade_activation", 0},
			{"air_commando_brigade_activation ", 0},
			{"amphibious_invasion_focus", 0},
			{"extreme_terrain_combat_tactics", 0},
			{"airbourne_warfare_research", 0}};
	else
		ignoreTech = {
			{"improved_police_brigade", 0},
			{"garrison_deployment", 0},
			{"officer_recruitment_program", 0},
			{"emergency_recruitment_legislation", 0},
			{"jungle_warfare_equipment", 0},
			{"airlanding_infantry_brigade_activation", 0},
			{"airborne_artillery_brigade_activation", 0},
			{"rocket_art", 0},
			{"rocket_art_ammo", 0},
			{"assault_gun_brigade_activation", 0},
			{"sp_rct_art_brigade_design", 0},
			{"sp_anti_air_design", 0},
			{"AFV_AA_defense", 0},
			{"heavy_assault_gun_brigade_activation", 0},
			{"armor_alloy", 0},
			{"interlocked_armour", 0},
			{"heavy_tank_destroyer_brigade_activation", 0},
			{"Tenacious_defense", 0},
			{"machine_gun_doctrine", 0},
			{"asymmetric_warfare_dev", 0},
			{"urban_Fighting_Equipment_and_Training", 0},
			{"ski_brigade_activation", 0},
			{"desert_warfare_equipment", 0},
			{"jungle_warfare_equipment", 0},
			{"artic_warfare_equipment", 0},
			{"amphibious_warfare_equipment", 0},
			{"airborne_warfare_equipment ", 0},
			{"airlanding_infantry_brigade_activation", 0},
			{"air_commando_brigade_activation ", 0},
			{"amphibious_invasion_focus", 0},
			{"extreme_terrain_combat_tactics", 0},
			{"airbourne_warfare_research", 0}};
	end

	local preferTech = {
		"armor_brigade_design",
		"infantry_activation",
		"light_infantry_brigade_activation",
		"special_forces_upgrade",
		"Vehicle_reliability",
		"semi_motorization",
		"smallarms_technology",
		"infantry_support",
		"infantry_guns",
		"infantry_at",
		"small_calibre_gun_design",
		"artillery_support_gun_design",
		"gasoline_engine_design",
		"infantry_tank_design",
		"tank_chassis_design",
		"light_armor_brigade_design",
		"heavy_armor_brigade_design",
		"mountain_infantry",
		"mountain_warfare_equipment",
		"cast_armour"};

	return ignoreTech, preferTech
end

function P.LandDoctrinesTechs(voTechnologyData)
	local ignoreTech = {
		{"political_integration", 0},
		{"political_indoctrination", 0},
		{"pakfront", 0},
		{"superior_strength", 0},
		{"banzai", 0},
		{"human_wave", 0},
		{"combined_arms_integration", 0},
		{"interservice_coordination", 0},
		{"interservice_communication", 0},
		{"partisan_suppression", 0},
		{"army_command_structure", 0},
		{"armygroup_command_structure", 0},
		{"supreme_command_coordination", 0}};

	local preferTech = {
		"Befehlstaktik",
		"mountain_training ",
		"mountain_command_and_control",
		"commando_training",
		"commando_command_and_control",
		"resistance_support",
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
		"spearhead",
		"blitzkrieg",
		"schwerpunkt",
		"divisonal_command_structure",
		"interservice_HQ_structure",
		"elastic_defense"
		};

	return ignoreTech, preferTech
end

function P.AirTechs(voTechnologyData)
	local ignoreTech = {
		{"air_refueling_plane_design", 0},
		{"AA_ordnance", 0},
		{"four_engine_gunner_pos", 0},
		{"four_engine_gunner_strength", 0},
		{"gun_turrets", 0},
		{"dam_bust_bomb", 0},
		{"tallboy_bomb", 0},
		{"grandslam_bomb", 0},
		{"in_air_refueling", 0},
		{"strategic_bomber_armament", 0}};

	local preferTech = {
		"single_engine_fighter_design",
		"aeroengine",
		"retractable_undercarriage",
		"advanced_aircraft_development",
		"engine_boost",
		"aerodyn_fuselage",
		"aerodyn_wings",
		"small_fueltank",
		"single_engine_airframe",
		"single_engine_aircraft_machinegun",
		"multirole_fighter_design",
		"small_bomb",
		"medium_bomb",
		"basic_medium_fueltank",
		"basic_twin_engine_airframe",
		"wing_guns",
		"ammo_capacity",
		"auto_cannons",
		"Rocket_ordnance",
		"drop_tanks",
		"basic_aircraft_design",
		"basic_aircraft_machinegun",
		"basic_engine",
		"single_engine_aircraft_armament",
		"self_sealing_fueltanks",
		"air_cooling_sys",
		"drop_shaped_cockpit",
		"twin_engine_bomber_design",
		"twin_engine_aircraft_armament",
		"twin_engine_airframe",
		"medium_fueltank",
		"cas_design"};

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
		{"strategic_air_command", 0}};

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
		{"carrier_bulkheads_thickness", 0},
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
		{"carrier_safety_procedures", 0},
		{"double_hangar", 0},
		{"deck_park", 0},
		{"milch_submarine", 0},
		{"super_heavy_battleship_technology", 0},
		{"cag_development", 0},
		{"pocket_battleship_activation ", 0},
		{"submarine_snorkel ", 0},
		{"submarine_electroboat ", 0},
		{"midget_submarine_activation ", 0},
		{"carrier_hanger", 0}};

	local preferTech = {
		"destroyer_technology",
		"destroyer_class",
		"light_naval_guns",
		"light_warship_engine",
		"light_warship_screws_rudder_optimisation",
		"hydrophone_dev",
		"smallwarship_asw",
		"smallwarship_damage_control",
		"hdfd_radio_dev",
		"depth_charge",
		"heavy_antiaircraft_light_ships",
		"light_antiaircraft_light_ships",
		"lightcruiser_technology",
		"lightcruiser_class",
		"heavycruiser_class",
		"heavycruiser_technology",
		"heavy_cruiser_naval_guns",
		"light_cruiser_naval_guns",
		"cruiser_naval_guns_AP_ammo",
		"cruiser_naval_guns_HE_ammo",
		"cruiser_engine_and_boilers",
		"cruiser_screws_and_rudder_optimisation",
		"cruiser_hull_shape_optimisation",
		"lightcruiser_armour_thickness",
		"heavy_cruiser_armour_thickness",
		"cruiser_bulkheads_thickness",
		"cruiser_horizontal_protection_layout",
		"cruiser_vertical_protection_layout",
		"cruiser_damage_control",
		"cruiser_light_anti_air_artillery",
		"cruiser_medium_anti_air_artillery",
		"cruiser_heavy_anti_air_artillery"};
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
		{"naval_underway_replenishment", 0},
		{"radar_training", 0}};

	local preferTech = {
		"destroyer_escort_role",
		"fire_control_system_training",
		"commander_decision_making"};

	return ignoreTech, preferTech
end

function P.IndustrialTechs(voTechnologyData)
	local ignoreTech = {
		{"civil_nuclear_research ", 0},
		{"isotope_seperation", 0},
		{"advanced_resource_substitution ", 0},
		{"nuclear_research", 0},
		{"atomic_research ", 0},
		{"heavy_aa_guns", 0},
		{"fuel_conservation ", 0},
		{"octane_conservation ", 0},
		{"Ship_Building_Technologies", 0},
		{"light_weight_construction ", 0},
		{"submarine_construction_technolgies ", 0}};

	local preferTech = {
		"construction_engineering",
		"supply_transportation",
		"supply_organisation",
		"secretary_of_public_information_and_education",
		"mass_events",
		"monumental_architecture",
		"broadcasting",
		"university",
		"agriculture",
		"industral_production",
		"industral_efficiency",
		"industry_tech",
		"civil_medicine",
		"long_range_aircraft_production",
		"short_range_aircraft_production",
		"oil_refinning",
		"steel_production",
		"coal_processing_technologies",
		"supply_production",
		"raremetal_refinning_techniques",
		"civil_defence",
		"logistical_warfare_focus",
		"home_front_focus",
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
		{"emergency_recruitment_legislation", 0}};

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
	-- More than 150 brigades so build stuff that does not use manpower
	if (voProductionData.ManpowerTotal < 100 and voProductionData.LandCountTotal > 200)
	or voProductionData.ManpowerTotal < 75 then
		laArray = {
			0.0, -- Land
			0.60, -- Air
			0.30, -- Sea
			0.10}; -- Other
	elseif voProductionData.Year >= 1940 then
		laArray = {
			0.65, -- Land
			0.25, -- Air
			0.10, -- Sea
			0.00}; -- Other
	else
		laArray = {
			0.70, -- Land
			0.30, -- Air
			0.00, -- Sea
			0.00}; -- Other
	end

	return laArray
end

-- Land ratio distribution

function P.LandRatio(voProductionData)
	local laArray
	if voProductionData.Year < 1939 then
		laArray = {
			garrison_brigade = 7,
			infantry_brigade = 5,
			semi_motorized_brigade = 3,
			mechanized_brigade = 1,
			light_armor_brigade = 1,
			armor_brigade = 1,
			--heavy_armor_brigade = 1
		};
	else
		laArray = {
			garrison_brigade = 2,
			infantry_brigade = 5,
			semi_motorized_brigade = 3,
			mechanized_brigade = 1,
			armor_brigade = 3,
			--heavy_armor_brigade = 1
		};
	end

	laArray.bergsjaeger_brigade = 2

	return laArray
end

-- Which units should get 1 more Support unit with Superior Firepower tech
function P.FirePower(voProductionData)
	local laArray = {

		"motorized_brigade",
		"mechanized_brigade",
		"armor_brigade"};

	return laArray
end

-- Air ratio distribution
function P.AirRatio(voProductionData)
	local laArray = {
		interceptor = 6,
		multi_role = 2,
		twin_engine_fighters = 1,
		cas = 2,
		tactical_bomber = 5,
		naval_bomber = 1};

	return laArray
end


-- Naval ratio distribution
function P.NavalRatio(voProductionData)
	local laArray = {
		destroyer_actual = 12,
		submarine = 4,
		carrier = 1,
		heavy_cruiser = 2,
		battleship = 1};

	return laArray
end

-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		40, -- Land
		1,  -- transport
		1}  -- invasion craft

	return laArray
end

-- Convoy Ratio control
--- NOTE: If goverment is in Exile these parms are ignored
function P.ConvoyRatio(voProductionData)
	local laArray

	if voProductionData.Year < 1940 and not(voProductionData.IsExile) then
		laArray = {
			5, -- Percentage extra (adds to 100 percent so if you put 10 it will make it 110% of needed amount)
			5, -- If Percentage extra is less than this it will force it up to the amount entered
			10, -- If Percentage extra is greater than this it will force it down to this
			10} -- Escort to Convoy Ratio (Number indicates how many convoys needed to build 1 escort)
	else
		laArray = {
			5, -- Percentage extra (adds to 100 percent so if you put 10 it will make it 110% of needed amount)
			5, -- If Percentage extra is less than this it will force it up to the amount entered
			10, -- If Percentage extra is greater than this it will force it down to this
			5} -- Escort to Convoy Ratio (Number indicates how many convoys needed to build 1 escort)
	end

	return laArray
end

function P.Build_motorized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	if (voProductionData.Year <= 1940) then

		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "anti_tank_brigade"
		voType.second = "medium_artillery_brigade"
		voType.third = "motorcycle_recon_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

		else


		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "tank_destroyer_brigade"
		voType.second = "medium_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.fourth = "motorized_engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end


	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

function P.Build_mechanized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	if (voProductionData.Year <= 1941) then

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
		voType.second = "medium_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.fourth = "motorized_engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

function P.Build_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	local sovTag = CCountryDataBase.GetTag("GER")


	if voProductionData.humanTag == sovTag then
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "mechanized_infantry_bat"
		voType.second = "sp_artillery_brigade"
		voType.fourth = "armored_engineers_brigade"
		voType.sixth = "medium_tank_destroyer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

	elseif (voProductionData.Year <= 1939) then

		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "motorized_infantry_bat"
		voType.second = "medium_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"

		voType.Support = 0
		voType.SupportVariation = 0

	else


		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "mechanized_infantry_bat"
		voType.second = "sp_artillery_brigade"
		voType.fourth = "armored_engineers_brigade"
		voType.sixth = "tank_destroyer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end


function P.Build_heavy_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	local sovTag = CCountryDataBase.GetTag("GER")


	if voProductionData.humanTag == sovTag then
		voType.SecondaryMain = "mechanized_infantry_bat"
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.second = "sp_artillery_brigade"
		voType.fourth = "armored_engineers_brigade"
		voType.sixth = "medium_tank_destroyer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

	else
		voType.SecondaryMain = "semi_motorized_brigade"
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.second = "sp_artillery_brigade"
		voType.fourth = "armored_engineers_brigade"
		voType.sixth = "medium_tank_destroyer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end


	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

function P.Build_light_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)


		voType.SecondaryMain = "armored_engineers_brigade"
		voType.TransportMain = "light_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "motorized_infantry_bat"
		voType.second = "medium_artillery_brigade"
		voType.fourth = "motorized_engineer_brigade"


		voType.Support = 0
		voType.SupportVariation = 0

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end


function P.Build_infantry_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	if (voProductionData.Year <= 1940) then

		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "anti_tank_brigade"
		voType.second = "medium_artillery_brigade"
		voType.third = "Recon_cavalry_brigade"
		voType.SecondaryMain = "engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

		else


		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "medium_tank_destroyer_brigade"
		voType.second = "medium_artillery_brigade"
		voType.third = "Recon_cavalry_brigade"
		voType.SecondaryMain = "engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end


function P.Build_semi_motorized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	local check1 = voProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("armored_engineers_brigade"))
	local check2 = voProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("sp_artillery_brigade"))

	-- voType.TertiaryMain = "division_hq"

	if (voProductionData.Year <= 1940) then

		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "anti_tank_brigade"
		voType.second = "medium_artillery_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		--voType.sixth = "heavy_armor_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

		else


		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "medium_tank_destroyer_brigade"
		voType.second = "medium_artillery_brigade"
		voType.third = "Recon_cavalry_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end


-- Do not build coastal forts
function P.Build_CoastalFort(vIC, voProductionData)
	return vIC, false
end

function P.Build_RocketTest(vIC, voProductionData)
	if voProductionData.Year <= 1942 then
		return vIC, false
	else
		if voProductionData.IsExile then
			return vIC, false
		elseif (voProductionData.icTotal < 50 and voProductionData.Year <= 1945) then
			return vIC, false
		end
	end

	return vIC, true
end

function P.Build_AntiAir(vIC, voProductionData)
	if voProductionData.Year < 1942 then
		return vIC, false
	elseif voProductionData.IsExile then
		return vIC, false
	end

	return vIC, true
end

function P.Build_Infrastructure(vIC, voProductionData)
	if voProductionData.Year < 1942 then
		return vIC, false
	elseif voProductionData.IsExile then
		return vIC, false
	end

	return vIC, true
end

function P.Build_Fort(vIC, voProductionData)
	if voProductionData.Year < 1942 then
		return vIC, false
	elseif voProductionData.IsExile then
		return vIC, false
	end

	return vIC, true
end

function P.Build_NavalBase(vIC, voProductionData)
	if voProductionData.IsExile then
		return vIC, false
	end

	return vIC, true
end

function P.Build_Radar(vIC, voProductionData)
	if voProductionData.IsExile then
		return vIC, false
	end

	return vIC, true
end

function P.Build_Underground(vIC, voProductionData)
	if voProductionData.IsExile then
		return vIC, true
	end

	return vIC, false
end

-- END OF PRODUTION OVERIDES
-- #######################################

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		ENG = {Score = 20},
		AST = {Score = 20},
		SAF = {Score = 20},
		NZL = {Score = 20},
		USA = {Score = 20},
		JAP = {Score = 50},
		GER = {Score = -20},
		ITA = {Score = -20},
		CAN = {Score = 20}}

	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end

	return voDiploScoreObj.Score
end

function P.DiploScore_Debt(voDiploScoreObj)
	local lsToTag = tostring(voDiploScoreObj.ToTag)

	if lsToTag == "CHI" then
		local loAllyFaction = CCurrentGameState.GetFaction("allies")

		-- We must be in the allies before we do this
		if voDiploScoreObj.FromCountry:GetFaction() == loAllyFaction then
			local japTag = CCountryDataBase.GetTag("JAP")

			-- If China and Japan are at war then let China be allowed debt even if not in the Allies
			if voDiploScoreObj.ToCountry:GetRelation(japTag):HasWar() then
				voDiploScoreObj.Score = 100
			end
		end
	end

	return voDiploScoreObj.Score
end

function P.DiploScore_InfluenceNation(voDiploScoreObj)
	-- Only do this if we are in the allies
	if voDiploScoreObj.FactionName == "allies" then
		local loInfluences = {
			AST = {Score = 70},
			CAN = {Score = 70},
			SAF = {Score = 70},
			NZL = {Score = 70},
			USA = {Score = 70},
			BRA = {Score = 40},
			YUG = {Score = 20},
			GRE = {Score = 20}}

		-- Are they on our list
		if loInfluences[voDiploScoreObj.TargetName] then
			return (voDiploScoreObj.Score + loInfluences[voDiploScoreObj.TargetName].Score)
		end
	end

	return voDiploScoreObj.Score
end

function P.HandleMobilization(minister)
	local ai = minister:GetOwnerAI()

	local ministerTag = minister:GetCountryTag()
	local gerTag = CCountryDataBase.GetTag("GER")

	-- If Germany Controls Czechoslovakia then
	if CCurrentGameState.GetProvince(2562):GetController() == gerTag then -- Praha check
		ai:Post(CToggleMobilizationCommand( ministerTag, true ))
	else
		-- Check if a neighbor is starting to look threatening
		-- This code should be idential to the one in ai_politics_minsiter.lua
		local ministerCountry = ministerTag:GetCountry()
		local liTotalIC = ministerCountry:GetTotalIC()
		local liNeutrality = ministerCountry:GetNeutrality():Get() * 0.9

		for loCountryTag in ministerCountry:GetNeighbours() do
			local liThreat = ministerCountry:GetRelation(loCountryTag):GetThreat():Get()

			if (liNeutrality - liThreat) < 10 then
				local loCountry = loCountryTag:GetCountry()

				liThreat = liThreat * CalculateAlignmentFactor(ai, ministerCountry, loCountry)

				if liTotalIC > 50 and loCountry:GetTotalIC() < liTotalIC then
					liThreat = liThreat / 2 -- we can handle them if they descide to attack anyway
				end

				if liThreat > 30 then
					if CalculateWarDesirability(ai, loCountry, ministerTag) > 70 then
						ai:Post(CToggleMobilizationCommand( ministerTag, true ))
					end
				end
			end
		end
	end
end

--##########################
-- Foreign Minister Hooks
function P.ForeignMinister_Influence(voForeignMinisterData)
	local laIgnoreWatch -- Ignore this country but monitor them if they are about to join someone else
	local laWatch -- Monitor them and also fi their score is high enough they can be influenced normally
	local laIgnore -- Ignore them completely

	if voForeignMinisterData.FactionName == "allies" then
		laWatch = {
			"BEL", -- Belgium
			"HOL", -- Holland
			"SWE", -- Sweden
			"CHI", -- China
			"NOR"} -- Norway

		laIgnoreWatch = {
			"TUR", -- Turkey
			"SPA", -- Spain
			"SPR", -- Republic Spain
			"POR", -- Portugal
			"AFG", -- Afghanistan
			"PER", -- Persia
			"SAU", -- Saudi Arabia
			"ARG", -- South America
			"BOL",
			"BRA",
			"CHL",
			"COL",
			"ECU",
			"GUY",
			"PAR",
			"PRU",
			"URU",
			"VEN",
			"CUB", -- Central America
			"COS",
			"DOM",
			"GUA",
			"HAI",
			"HON",
			"MEX",
			"NIC",
			"PAN",
			"SAL"}

		laIgnore = {
			"HUN", -- Hungary
			"ROM", -- Romania
			"BUL", -- Bulgaria
			"FIN", -- Finland
			"CYN", -- Yunnan
			"SIK", -- Sikiang
			"CGX", -- Guangxi Clique
			"CSX", -- Shanxi
			"TIB", -- Tibet
			"CHC", -- Communist China
			"LAT", -- Lativia
			"LIT", -- Lithuania
			"EST", -- Estonia
			"LUX", -- Luxemburg
			"VIC", -- Vichy
			"DEN", -- Denmark
			"ETH", -- Ethiopia
			"AUS", -- Austria
			"CZE", -- Czechoslovakia
			"SCH", -- Switzerland
			"VIC", -- Vichy
			"JAP", -- Japan
			"ITA"} -- Italy
	end

	return laWatch, laIgnoreWatch, laIgnore
end


return AI_FRA
