local P = {}
AI_USA = P

-- #######################################

-- Tech weights
--   1.0 = 100% the total needs to equal 1.0
function P.TechWeights(voTechnologyData)
	local laTechWeights = {
		0.11, -- landBasedWeight
		0.14, -- SuperiorFirepowerWeight
		0.11, -- landDoctrinesWeight
		0.10, -- airBasedWeight
		0.10, -- airDoctrinesWeight
		0.10, -- navalBasedWeight
		0.10, -- navalDoctrinesWeight
		0.10, -- industrialWeight
		0.04, -- secretWeaponsWeight
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
		ignoreTech = {{"improved_police_brigade", 0}, 
			--{"garrison_deployment", 0},
			{"officer_recruitment_program", 0}, 
			{"emergency_recruitment_legislation", 0},
			{"air_defense_network", 0},
			{"assault_gun_brigade_activation", 0},
			{"heavy_aa_guns", 0},
			{"heavy_assault_gun_brigade_activation", 0},
			{"super_heavy_tank_design", 0},
			{"interlocked_armour", 0},
			{"mountain_infantry", 0},
			{"heavy_tank_destroyer_brigade_activation", 0},
			{"ski_brigade_activation", 0},
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
			{"desert_warfare_equipment", 0},
			{"mountain_warfare_equipment", 0},
			{"artic_warfare_equipment", 0},
			{"air_commando_brigade_activation", 0},
			{"extreme_terrain_combat_tactics", 0},
			{"asymmetric_warfare_dev", 0},
			{"urban_Fighting_Equipment_and_Training", 0},
			{"Tenacious_defense", 0},
			{"AFV_AA_defense", 0}};
	else
		ignoreTech = {{"improved_police_brigade", 0}, 
			--{"garrison_deployment", 0},
			{"officer_recruitment_program", 0}, 
			{"emergency_recruitment_legislation", 0},
			{"air_defense_network", 0},
			{"assault_gun_brigade_activation", 0},
			{"heavy_aa_guns", 0},
			{"heavy_assault_gun_brigade_activation", 0},
			{"super_heavy_tank_design", 0},
			{"interlocked_armour", 0},
			{"mountain_infantry", 0},
			{"heavy_tank_destroyer_brigade_activation", 0},
			{"ski_brigade_activation", 0},
			{"desert_warfare_equipment", 0},
			{"mountain_warfare_equipment", 0},
			{"artic_warfare_equipment", 0},
			{"air_commando_brigade_activation", 0},
			{"extreme_terrain_combat_tactics", 0},
			{"heavy_tank_destroyer_brigade_activation", 0},
			{"asymmetric_warfare_dev", 0},
			{"urban_Fighting_Equipment_and_Training", 0},
			{"Tenacious_defense", 0},
			{"AFV_AA_defense", 0}};
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
		"smallarms_technology",
		"infantry_guns",
		"infantry_at",
		"infantry_support",
		"intergrated_AFV_battalions",
		"engineer_brigade_activation",
		"engineer_bridging_equipment",
		"engineer_assault_equipment",
		"jungle_warfare_equipment",
		"airlanding_infantry_brigade_activation",
		"art_barrell_ammo",
		"gun_carriage",
		"armor_brigade_design",
		"range_finding",
		"small_calibre_gun_design",
		"artillery_support_gun_design",
		"medium_velocity_gun",
		"high_velocity_gun",
		"at_aa_ammo",
		"Artillery_motorization",
		"pack_artillery_brigade_activation",
		"airborne_artillery_brigade_activation",
		"sp_artillery_brigade_design",
		"Artillery_fire_control_technics_dev",
		"tremendous_firepower_dev",
		"tank_chassis_design",
		"gasoline_engine_design",
		"advanced_tank_chassis_design",
		"light_armor_brigade_design",
		"tank_destroyer_brigade_activation",
		"armor_brigade_design",
		"armor_thickness",
		"cast_armour",
		"amph_armour_brigade_activation",
		"armored_engineers_brigade_activation",
		"Panzerfaust_Bazooka_AT_Tech",
		"armor_plate_design",
		"medium_tank_destroyer_brigade_activation"};
	
	return ignoreTech, preferTech
end
function P.SuperiorFirepowerTechs(voTechnologyData)
	local ignoreTech = {};
		
	local preferTech = {
		"superior_firepower",
		"artillery_firepower_focus",
		"infantry_firepower_focus",
		"mobile_firepower_focus",
		"mobile_defense",
		"stand_off",
		"mechanised_offensive",
		"combined_arms_defence",
		"integrated_support",
		"artillery_preparation_and_training",
		"pre_calculating_artillery",
		"time_on_target_SF",
		"tactical_command",
		"brigade_command_structure_SF",
		"division_HQ_SF",
		"corps_HQ_SF",
		"army_HQ_SF",
		"rct"};
		
	return ignoreTech, preferTech
end

function P.LandDoctrinesTechs(voTechnologyData)
	local ignoreTech = {
		{"partisan_suppression", 0},
		{"political_indoctrination", 0},
		{"political_integration", 0},
		{"mountain_training", 0},
		{"mountain_command_and_control", 0}};
		
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
		"jungle_training",
		"jungle_command_and_control",
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
		{"air_commando_brigade_activation", 0}
	};
	local preferTech = {
		"engine_boost",
		"advanced_aircraft_development",
		"self_sealing_fueltanks",
		"air_cooling_sys",
		"retractable_undercarriage",
		"aerodyn_fuselage",
		"aerodyn_wings",
		"single_engine_fighter_design",
		"single_engine_airframe",
		"single_engine_aircraft_armament",
		"cas_design",
		"cag_design",
		"basic_bomb",
		"small_bomb",
		"medium_bomb",
		"air_launched_torpedo",
		"four_engine_bomber_design",
		"aeroengine",
		"small_fueltank",
		"medium_fueltank",
		"large_fueltank",
		"drop_shaped_cockpit",
		"ammo_capacity",
		"auto_cannons",
		"basic_four_engine_airframe",
		"four_engine_airframe",
		"multirole_fighter_design",
		"twin_engine_fighter_design",
		"naval_bomber_design",
		"strategic_bomber_armament",
		"twin_engine_bomber_crew_layout",
		"twin_engine_airframe",
		"twin_engine_bomber_design",
		"light_bomber_design",
		"twin_engine_aircraft_armament"};
		
	return ignoreTech, preferTech
end

function P.AirDoctrineTechs(voTechnologyData)
	local ignoreTech = {
		{"logistical_strike_tactics", 0}};

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
		"strategic_bombardment_tactics",
		"strategic_air_command",
		"naval_tactics"};		
		
	return ignoreTech, preferTech
end
		
function P.NavalTechs(voTechnologyData)
	local ignoreTech = {
		{"battlecruiser_technology", 0},
		{"pocket_battleship_activation", 0},
		{"floatplane_dev_torpedo", 0},
		{"floatplane_dev_fighter", 0},
		{"closed_hangar", 0},
		{"closed_hangar_safety_procedures", 0},
		{"double_hangar", 0},
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
        {"submarine_electroboat", 0},
        {"milch_submarine", 0}};

	local preferTech = {
		"destroyer_technology",
		"destroyer_class",
		"frigate_class",
		"torpedo_boat_class",
		"motor_torpedo_boat_class",
		"light_naval_guns",
		"light_warship_engine",
		"light_warship_screws_rudder_optimalisation",
		"hydrophone_dev",
		"small_warship_surface_radar",
		"small_warship_airsearch_radar",
		"smallwarship_asw",
		"smallwarship_damage_control",
		"smallwarship_fire_control_computer",
		"smallwarship_AAA_control_computer",
		"hdfd_radio_dev",
		"depth_charge",
		"hedgehog_dev",
		"asw_counter_measures",
		"heavy_antiaircraft_light_ships",
		"light_antiaircraft_light_ships",
		"lightcruiser_technology",
		"lightcruiser_class",
		"anti_air_cruiser_activation",
		"heavycruiser_class",
		"heavy_cruiser_naval_guns",
		"light_cruiser_naval_guns",
		"cruiser_naval_guns_AP_ammo",
		"cruiser_naval_guns_HE_ammo",
		"cruiser_naval_guns_autoloader",
		"cruiser_engine_and_boilers",
		"cruiser_screws_and_rudder_optimalisation",
		"cruiser_hull_shape_optimalisation",
		"lightcruiser_armour_thickness",
		"heavy_cruiser_armour_thickness",
		"cruiser_bulkheads_layout",
		"cruiser_horizontal_protection_layout",
		"cruiser_vertical_protection_layout",
		"mediumwarship_surface_radar",
		"mediumwarship_airsearch_radar",
		"cruiser_damage_control",
		"cruiser_fire_control_computer",
		"cruiser_AAA_control_computer",
		"cruiser_light_anti_air_artilery",
		"cruiser_medium_anti_air_artilery",
		"cruiser_anti_air_artilery_focus",
		"cruiser_heavy_anti_air_artilery",
		"transport_ship_activation",
		"transport_ship_hull",
		"transport_ship_engine",
		"amphibious_invasion_craft",
		"advanced_invasion_craft",		
		"amphibious_invasion_tactics",
		"amphibious_ship_defenses",
		"light_carrier_technology",
		"carrier_class",
		"carrier_technology",
		"carrier_light_anti_air_artilery",
		"carrier_medium_anti_air_artilery",
		"carrier_heavy_anti_air_artilery",
		"carrier_screws_optimalisation",
		"carrier_rudder_optimalisation",
		"carrier_hull_shape_optimalisation",
		"carrier_armour_thickness",
		"light_carrier_armour_thickness",
		"super_carrier_armour_thickness",
		"carrier_vertical_protection",
		"carrier_horizontal_protection",
		"carrier_torpedo_protection",
		"carrier_bulkheads_layout",
		"carrier_hanger",
		"escort_carrier_technology",
		"seaplane_tender_technology",
		"carrier_flight_deck_optimisation",
		"super_carrier_technology",
		"carrier_damage_control",
		"cag_fighter",
		"cag_bomber",
		"cag_torpedo",
		"off_center_elevators",
		"carrier_catapults",
		"open_hangar",
		"deck_park",
		"capital_ship_engine",
		"capital_ship_boilers",
		"capital_ship_turbines",
		"midget_submarine_activation",
		"cag_fighter",
		"cag_bomber",
		"cag_torpedo",
		"tailhook",
		"folding_wings"};		
		
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
		{"light_weight_construction", 0}};

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
		"atomic_research",
		"nuclear_research",
		"isotope_seperation",
		"civil_nuclear_research",
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
	
	return ignoreTech, nil
end

function P.OtherTechs(voTechnologyData)
	local ignoreTech = {
			};

	local preferTech = {
		"air_radios",
		"tank_radios",
		"infantry_radios",
		"small_ship_radar",
		"medium_ship_radar",
		"big_ship_radar",
		"radar",
		"radio",
		"large_navagation_radar",
		"large_airsearch_radar",
		"electronic_computing_machine",
		"decryption_machine",
		"active_sonar"};			

	return ignoreTech, preferTech
end

-- END OF TECH RESEARCH OVERIDES
-- #######################################

-- #######################################
-- Production Overides the main LUA with country specific ones

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)

	-- Set the default in the array incase no condition is met
	local laArray = {
			0.28, -- Land
			0.25, -- Air
			0.47, -- Sea
			0.00}; -- Other	         

	
	-- Not atwar so
	if not(voProductionData.IsAtWar) and voProductionData.Year < 1942 then
		if voProductionData.Year <= 1939 then
			laArray = {
				0.05, -- Land 
				0.05, -- Air
				0.05, -- Sea
				0.85}; -- Other
		elseif voProductionData.Year <= 1941 then
			laArray = {
				0.20, -- Land 
				0.25, -- Air
				0.30, -- Sea
				0.25}; -- Other
		elseif voProductionData.ManpowerTotal < 400 then
			laArray = {
				0.00, -- Land
				0.50, -- Air
				0.40, -- Sea
				0.10}; -- Other
		end
	else
		local loGerUsaDiplo = voProductionData.ministerCountry:GetRelation(CCountryDataBase.GetTag("GER"))
		local loJapUsaDiplo = voProductionData.ministerCountry:GetRelation(CCountryDataBase.GetTag("JAP"))
		local lbGERWar = loGerUsaDiplo:HasWar() 
		local lbJAPWar = loJapUsaDiplo:HasWar()
	
		if lbGERWar or lbJAPWar then
			local liGERWar = 12
			local liJAPWar = 12
			
			if lbGERWar then
				liGERWar = loGerUsaDiplo:GetWar():GetCurrentRunningTimeInMonths()
			end
				
			if lbJAPWar then
				liJAPWar = loJapUsaDiplo:GetWar():GetCurrentRunningTimeInMonths()
			end
			
			local liWarMonths = math.min(liGERWar, liJAPWar)
			
			if liWarMonths < 48 then
				laArray = {
					0.25, -- Land
					0.3, -- Air
					0.45, -- Sea
					0.00}; -- Other
			end
		end
	end
	
	return laArray
end

-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray
	
	if voProductionData.Year < 1941 or not(voProductionData.IsAtWar) then
		laArray = {
			garrison_brigade = 1,
			semi_motorized_brigade = 5,
			motorized_brigade = 1,
			light_armor_brigade = 1,
			infantry_brigade = 7};
	else
		laArray = {
			garrison_brigade = 1,
			infantry_brigade = 1,
			semi_motorized_brigade = 1,
			motorized_brigade = 7,
			mechanized_brigade = 2,
			armor_brigade = 4};
	end
	
	return laArray
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = {
		10, -- Land
		5}; -- Special Force Unit

	local laUnits = {
				bergsjaeger_brigade = 1,
				marine_brigade = 20};
	
	return laRatio, laUnits	
end



-- Which units should get 1 more Support unit with Superior Firepower tech
function P.FirePower(voProductionData)
	local laArray = {
		"infantry_brigade",
		"semi_motorized_brigade",
		--"infantry_brigade",
		"mechanized_brigade",
		"armor_brigade"};
		
	return laArray
end

-- Air ratio distribution
function P.AirRatio(voProductionData)
	local laArray = {
		interceptor = 8,
		multi_role = 5,
		cas = 1,
		tactical_bomber = 3,
		naval_bomber = 1,
		strategic_bomber = 5,
		rocket_interceptor = 1,
		Flying_boat = 0.5,
		twin_engine_fighters = 0.5};
	
	return laArray
end
-- Naval ratio distribution
function P.NavalRatio(voProductionData)
	local laArray = {
		destroyer_actual = 25,
		submarine = 6,
		nuclear_submarine = 0.5,
		light_cruiser = 9,
		heavy_cruiser = 2,
		battleship = 1,
		escort_carrier = 2,
		seaplane_tender = 0.5,
		carrier = 6};
	
	return laArray
end

-- Transport to Land unit distribution
function P.TransportLandRatio(voProductionData)
	local laArray = {
		14, -- Land
		2,  -- transport
		8}  -- invasion craft
  
	return laArray
end

-- Convoy Ratio control
--- NOTE: If goverment is in Exile these parms are ignored
function P.ConvoyRatio(voProductionData)
	local laArray = {
		40, -- Percentage extra (adds to 100 percent so if you put 10 it will make it 110% of needed amount)
		100, -- If Percentage extra is less than this it will force it up to the amount entered
		200, -- If Percentage extra is greater than this it will force it down to this
		7} -- Escort to Convoy Ratio (Number indicates how many convoys needed to build 1 escort)
  
	return laArray
end

-- Garrison builds - GAR+(ART|HVYART)+SUPPORTSx2 ("Garrison" Support Group)

function P.Build_garrison_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	
	
		voType.first = "artillery_brigade"
		
		voType.Support = 0
	

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

function P.Build_motorized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	
	if (voProductionData.Year <= 1940) then
		
		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "tank_destroyer_brigade"
		voType.second = "artillery_brigade"
		voType.third = "motorcycle_recon_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		voType.Support = 0
		
		else
		
		
		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "tank_destroyer_brigade"
		voType.second = "sp_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.forth = "motorized_engineer_brigade"
		voType.SecondaryMain = "sp_anti_air_brigade"
		voType.Support = 0
	end


	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

function P.Build_mechanized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	
	if (voProductionData.Year <= 1941) then
		
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "tank_destroyer_brigade"
		voType.second = "sp_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.forth = "armored_engineers_brigade"
		voType.SecondaryMain = "sp_anti_air_brigade"
		voType.Support = 0
		
	else
		
		
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "medium_tank_destroyer_brigade"
		voType.second = "medium_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.forth = "armored_engineers_brigade"
		voType.SecondaryMain = "sp_anti_air_brigade"
		voType.Support = 0
	end
	
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

function P.Build_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	
	local sovTag = CCountryDataBase.GetTag("GER")

	
	if voProductionData.humanTag == sovTag then
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "mechanized_infantry_bat"
		voType.second = "sp_artillery_brigade"
		voType.third = "medium_tank_destroyer_brigade"
		voType.forth = "armored_engineers_brigade"
		voType.SecondaryMain = "sp_anti_air_brigade"
		voType.Support = 0

	elseif (voProductionData.Year <= 1941) then
		
		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "motorized_infantry_bat"
		voType.second = "artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		voType.fifth = "sp_anti_air_brigade"
		
		voType.Support = 0
		
	else
		
		
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "mechanized_infantry_bat"
		voType.second = "sp_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.forth = "armored_engineers_brigade"
		voType.SecondaryMain = "sp_anti_air_brigade"
		voType.sith = "medium_tank_destroyer_brigade"
		voType.Support = 0
	end
	
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end


function P.Build_heavy_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	local sovTag = CCountryDataBase.GetTag("GER")


	if voProductionData.humanTag == sovTag then
		voType.SecondaryMain = "mechanized_infantry_bat"
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.second = "sp_artillery_brigade"
		voType.third = "medium_tank_destroyer_brigade"
		voType.forth = "armored_engineers_brigade"
		voType.fifth = "sp_anti_air_brigade"
		voType.Support = 0
		
	else
		voType.SecondaryMain = "motorized_brigade"
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.second = "sp_artillery_brigade"
		voType.third = "medium_tank_destroyer_brigade"
		voType.forth = "armored_engineers_brigade"
		voType.fifth = "sp_anti_air_brigade"
		voType.Support = 0
	end	
	
		
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

function P.Build_light_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

		
		voType.SecondaryMain = "armored_engineers_brigade"
		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "motorized_infantry_bat"
		voType.second = "artillery_brigade"
		voType.third = "motorcycle_recon_brigade"
		voType.forth = "motorized_engineer_brigade"


		voType.Support = 0

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
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
		
		else
		
		
		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "medium_tank_destroyer_brigade"
		voType.second = "medium_artillery_brigade"
		voType.third = "Recon_cavalry_brigade"
		voType.forth = "anti_air_brigade"
		voType.SecondaryMain = "engineer_brigade"
		voType.Support = 0
	end
		
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end


function P.Build_semi_motorized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	local check1 = voProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("armored_engineers_brigade"))
	local check2 = voProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("sp_artillery_brigade"))
	
	-- voType.TertiaryMain = "division_hq"
	
	if (voProductionData.Year <= 1940) then
		
		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "anti_tank_brigade"
		voType.second = "artillery_brigade"
		voType.third = "Recon_cavalry_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		voType.sith = "heavy_armor_brigade"
		voType.Support = 0
		
		else
		
		
		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "medium_tank_destroyer_brigade"
		voType.second = "artillery_brigade"
		voType.third = "Recon_cavalry_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		voType.Support = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end





function P.Build_CoastalFort(ic, voProductionData)


	if voProductionData.Year < 1943 then
		return ic, false
	end
	
	return ic, true
end

function P.Build_AirBase(ic, voProductionData)
	ic = Support.Build_AirBase(ic, voProductionData, 10669, 10) --Midway
	ic = Support.Build_AirBase(ic, voProductionData, 5825, 10) --Honolulu
	ic = Support.Build_AirBase(ic, voProductionData, 5712, 10) -- AmamiOshima 
	ic = Support.Build_AirBase(ic, voProductionData, 5720, 10) -- TokunoShima
	ic = Support.Build_AirBase(ic, voProductionData, 5748, 10) -- Nago
	ic = Support.Build_AirBase(ic, voProductionData, 5759, 10) -- Naha
	ic = Support.Build_AirBase(ic, voProductionData, 10642, 10) -- Iwo Jima
	ic = Support.Build_AirBase(ic, voProductionData, 14129, 10) -- Bonin Islands
	ic = Support.Build_AirBase(ic, voProductionData, 10664, 10) --Wake island

	if voProductionData.Year < 1942 then
		return ic, false
	end
	
	return ic, true
end

function P.Build_NavalBase(ic, voProductionData)
	ic = Support.Build_NavalBase(ic, voProductionData, 10669, 10) --Midway
	ic = Support.Build_NavalBase(ic, voProductionData, 5825, 10) --Honolulu
	ic = Support.Build_NavalBase(ic, voProductionData, 5712, 6) -- AmamiOshima
	ic = Support.Build_NavalBase(ic, voProductionData, 5720, 6) -- TokunoShima
	ic = Support.Build_NavalBase(ic, voProductionData, 5748, 6) -- Nago
	ic = Support.Build_NavalBase(ic, voProductionData, 5759, 6) -- Naha
	ic = Support.Build_NavalBase(ic, voProductionData, 10642, 6) -- Iwo Jima
	ic = Support.Build_NavalBase(ic, voProductionData, 14129, 6) -- Bonin Islands
	ic = Support.Build_NavalBase(ic, voProductionData, 10664, 10) --Wake island

	-- Ports in Spain in case Germany takes them over
	ic = Support.Build_NavalBase(ic, voProductionData, 3884, 10) 
	ic = Support.Build_NavalBase(ic, voProductionData, 3814, 10) 
	ic = Support.Build_NavalBase(ic, voProductionData, 3676, 10) 
	ic = Support.Build_NavalBase(ic, voProductionData, 3877, 10) 
	ic = Support.Build_NavalBase(ic, voProductionData, 3679, 10) 
	ic = Support.Build_NavalBase(ic, voProductionData, 3610, 10) 
	ic = Support.Build_NavalBase(ic, voProductionData, 3675, 10) 
		
	if voProductionData.Year < 1942 then
		return ic, false
	end
	
	return ic, true
end

function P.Build_Radar(ic, voProductionData)
	ic = Support.Build_Radar(ic, voProductionData, 10669, 10) --Midway
	ic = Support.Build_Radar(ic, voProductionData, 5825, 10) --Honolulu
	ic = Support.Build_Radar(ic, voProductionData, 5712, 10) -- AmamiOshima
	ic = Support.Build_Radar(ic, voProductionData, 5720, 10) -- TokunoShima
	ic = Support.Build_Radar(ic, voProductionData, 5748, 10) -- Nago
	ic = Support.Build_Radar(ic, voProductionData, 5759, 10) -- Naha
	ic = Support.Build_Radar(ic, voProductionData, 10642, 10) -- Iwo Jima
	ic = Support.Build_Radar(ic, voProductionData, 14129, 10) -- Bonin Islands
	ic = Support.Build_Radar(ic, voProductionData, 10664, 10) --Wake island

	if voProductionData.Year < 1942 then
		return ic, false
	end
	
	return ic, true
end

function P.Build_AntiAir(ic, voProductionData)
	return ic, false
end

function P.Build_Infrastructure(ic, voProductionData)
	if voProductionData.Year <= 1942 then
		return ic, false
	end

	return ic, true
end

function P.Build_Fort(ic, voProductionData)
 	if voProductionData.Year < 1944 then
		return ic, false
	end
	
	return ic, true
end

-- END OF PRODUTION OVERIDES
-- #######################################

function P.ForeignMinister_Alignment(...)
	return Support.AlignmentPush("allies", ...)
end

function P.DiploScore_Embargo(voDiploScoreObj)
	if voDiploScoreObj.EmbargoHasFaction then
		local loAllyFaction = CCurrentGameState.GetFaction("allies")

		-- If USA is leaning toward the allies and UK then embargo their enemies
		if Support.IsFriend(voDiploScoreObj.ministerAI, loAllyFaction, voDiploScoreObj.ministerCountry) then
			local allyTag = loAllyFaction:GetFactionLeader()
			local loAllyCountry = allyTag:GetCountry()
			
			if loAllyCountry:GetRelation(voDiploScoreObj.EmbargoTag):HasWar() then
				voDiploScoreObj.Score = voDiploScoreObj.Score + 100
			end
			
			-- Push Japan to the top of the que if they are in the Axis
			if tostring(voDiploScoreObj.EmbargoTag) == "JAP" then
				local loAxisFaction = CCurrentGameState.GetFaction("axis")
				local chiTag = CCountryDataBase.GetTag("CHI")
				
				if voDiploScoreObj.EmbargoCountry:GetFaction() == loAxisFaction
				or voDiploScoreObj.EmbargoCountry:GetRelation(chiTag):HasWar() then
					voDiploScoreObj.Score = voDiploScoreObj.Score + 100
				end
			end
		end
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_Debt(voDiploScoreObj)
	local loAllyFaction = CCurrentGameState.GetFaction("allies")
	
	-- If the requesting country is part of the Allies then
	if voDiploScoreObj.ToCountry:GetFaction() == loAllyFaction then
		-- Make sure the USA is not part of a faction already
		if not(voDiploScoreObj.FromCountry:HasFaction()) then
			if Support.IsFriend(voDiploScoreObj.ministerAI, loAllyFaction, voDiploScoreObj.FromCountry) then
				-- Check to see if they are at war
				if voDiploScoreObj.ToCountry:IsAtWar() then
					-- Calculate the score based on USA neutrality the lower it is the more likely they will allow the debt
					local liNeutrality = voDiploScoreObj.FromCountry:GetEffectiveNeutrality():Get()
					voDiploScoreObj.Score = 110 - liNeutrality
				end
			end
		end
	else
		local lsToTag = tostring(voDiploScoreObj.ToTag)
		
		-- If it is China do a special check
		if lsToTag == "CHI" then
			-- If we are friendly to the Allied faction
			if Support.IsFriend(voDiploScoreObj.ministerAI, loAllyFaction, voDiploScoreObj.FromCountry) then
				local japTag = CCountryDataBase.GetTag("JAP")
				
				-- If China and Japan are at war then let China be allowed debt even if not in the Allies
				if voDiploScoreObj.ToCountry:GetRelation(japTag):HasWar() then
					voDiploScoreObj.Score = 100
				end
			end
		end
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		JAP = {Score = 100},
		ENG = {Score = 50},
		FRA = {Score = 50},
		GER = {Score = -10},
		ITA = {Score = -10},
		SOV = {Score = -10},
		CHI = {Score = 50},
		CHC = {Score = 50},
		CGX = {Score = 50},
		CSX = {Score = 50},
		CXB = {Score = 50},
		CYN = {Score = 50},
		SIK = {Score = 50}}
	
	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	local loAllies = CCurrentGameState.GetFaction("allies")
	
	-- Only go through these checks if we are being asked to join the Allies
	if voDiploScoreObj.Faction == loAllies then
		local liYear = CCurrentGameState.GetCurrentDate():GetYear()
		local liMonth = CCurrentGameState.GetCurrentDate():GetMonthOfYear()
		local chiTag = CCountryDataBase.GetTag("CHI")
		local lochiTagCountry = chiTag:GetCountry()
		local lbChinaExists = lochiTagCountry:Exists() 
		
		-- Date check to make sure they come in within resonable time
		if liYear >= 1943 then
			voDiploScoreObj.Score = voDiploScoreObj.Score + 30
		elseif liYear >= 1942 then
			voDiploScoreObj.Score = voDiploScoreObj.Score + 20
		elseif liYear == 1941 and liMonth >= 10 then
			voDiploScoreObj.Score = voDiploScoreObj.Score + 10
		end
		
		-- China check see if Japan is being aggressive in China
		if lbChinaExists then
			local japTag = CCountryDataBase.GetTag("JAP")
			local loChiJapRelation = lochiTagCountry:GetRelation(japTag)
			
			-- Check to see who they are a puppet of
			if lochiTagCountry:IsPuppet() then
				local lojapTagCountry = japTag:GetCountry()
			
				-- China has been taken over by Japan
				if (loChiJapRelation:HasAlliance())
				or (lochiTagCountry:HasFaction() and lochiTagCountry:GetFaction() == lojapTagCountry:GetFaction()) then
					voDiploScoreObj.Score = voDiploScoreObj.Score + 50
				end
			else
				local lbChiJapHasWar = loChiJapRelation:HasWar()
				
				if lochiTagCountry:IsGovernmentInExile() and lbChiJapHasWar then
					voDiploScoreObj.Score = voDiploScoreObj.Score + 50
				elseif lbChiJapHasWar then
					voDiploScoreObj.Score = voDiploScoreObj.Score + 10
				end
			end
		else
			-- China is out of the war for some reason
			voDiploScoreObj.Score = voDiploScoreObj.Score + 50
		end
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_Guarantee(voDiploScoreObj)

	local recipientCountry = voDiploScoreObj.TargetTag:GetCountry()
	if not voDiploScoreObj.HasFaction then
		local continent = tostring( recipientCountry:GetCapitalLocation():GetContinent():GetTag() )
		if (continent == "north_america" or continent == "south_america")
		and not (tostring(voDiploScoreObj.TargetTag) == 'CAN') then
			return 100
		end
	end
	
	return voDiploScoreObj.Score

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
			"POR"} -- Portugal
			
		laIgnore = {
			"HUN", -- Hungary
			"ROM", -- Romania
			"BUL", -- Bulgaria
			"FIN", -- Finland
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
			"VIC"} -- Vichy
			
		-- Make a list of countries that are not in Asia and ignore them
		for loTCountry in CCurrentGameState.GetCountries() do
			if loTCountry:Exists() then
				local lsContinent = tostring(loTCountry:GetActingCapitalLocation():GetContinent():GetTag())
				-- If they are not in Asia then ignore them
				if lsContinent == "north_america" or lsContinent == "south_america" then
					table.insert(laWatch, tostring(loTCountry:GetCountryTag()))
				end
			end
		end				
	end
	
	return laWatch, laIgnoreWatch, laIgnore
end

function P.ForeignMinister_ProposeWar(voForeignMinisterData)
	local loAxisFaction = CCurrentGameState.GetFaction("axis")
	local loAxisTag = loAxisFaction:GetFactionLeader()
	local loAxisCountry = loAxisTag:GetCountry()
	local loAlliesTag = CCurrentGameState.GetFaction("allies"):GetFactionLeader()
	local loAxisAlliesRelation = loAxisCountry:GetRelation(loAlliesTag)
	local lbSealion = P.SealionCheck(loAxisAlliesRelation, loAxisFaction)
						
						-- Can we DOW the Axis Leader
	if lbSealion then
		if math.random(100) < 90 then
			voForeignMinisterData.Strategy:PrepareLimitedWar(loAxisTag, 100)
		end							
	elseif not(voForeignMinisterData.Strategy:IsPreparingWar()) then
		if voForeignMinisterData.FactionName == "allies" then
	
			-- Generic DOW for countries not part of the same faction
			if not(voForeignMinisterData.IsAtWar) then
				for loDiploStatus in voForeignMinisterData.ministerCountry:GetDiplomacy() do
					local loTargetTag = loDiploStatus:GetTarget()

					if loTargetTag:IsValid() then
						local loTargetCountry = loTargetTag:GetCountry()
						
						if loDiploStatus:GetThreat():Get() > voForeignMinisterData.ministerCountry:GetMaxNeutralityForWarWith(loTargetTag):Get()  then
							if Support.GoodToWarCheck(loTargetTag, loTargetCountry, voForeignMinisterData, true) then
								voForeignMinisterData.Strategy:PrepareWar(loTargetTag, 100 )
							end
						end
					end
				end
			end

			-- Special Checks Start after this point
			
			
			
			
		end
	end
end

function P.SealionCheck(voAxisAlliesRelation, voAxisFaction)
	-- Check for Sea Lion and if so lets get involved before its to late
	local laProvinceCheck = {
		1964, -- london
		2250, -- plymouth
		2135, -- bornmouth
		2021, -- dover
		1790, -- lowestoft
		1616, -- grimsby
		1524, -- hull
		1255, --newcastle
		1128, -- edinburgh
		894, -- aberdeen
		604, -- scapa flow
		2018} -- bristol
	
	local ger = CCountryDataBase.GetTag("GER")
	local human = CCurrentGameState.GetPlayer()
	if (human == ger) then
		if voAxisAlliesRelation:HasWar() then	
			for i = 1, table.getn(laProvinceCheck) do
				loProvinceFaction = CCurrentGameState.GetProvince(laProvinceCheck[i]):GetController():GetCountry():GetFaction()
			
				-- Is the province controlled by the Axis
				if loProvinceFaction == voAxisFaction then
					return true
				end
			end
		end
	end
	return false
end

function P.ForeignMinister_Alignment(...)

		return Support.AlignmentPush("allies", ...)
	
end

-- Produce slightly better trained troops
function P.CallLaw_training_laws(minister, voCurrentLaw)
	local _ADVANCED_TRAINING_ = 29
	return CLawDataBase.GetLaw(_ADVANCED_TRAINING_)
end

return AI_USA

