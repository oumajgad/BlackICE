local P = {}
AI_SOV = P

-- #######################################
-- Tech weights
--   1.0 = 100% the total needs to equal 1.0
function P.TechWeights(voTechnologyData)
	local laTechWeights
	local liCYear = CCurrentGameState.GetCurrentDate():GetYear()
	local lbAtWarGER = voTechnologyData.ministerCountry:GetRelation(CCountryDataBase.GetTag("GER")):HasWar()

	-- If we are at war with Germany or the year is less than 1941 and not wat war
	if lbAtWarGER or (liCYear < 1942 and not(voTechnologyData.IsAtWar)) then
		local lbControlMoscow = (CCurrentGameState.GetProvince(1409):GetController() == voTechnologyData.ministerTag)

		-- We still control Moscow and the year is greater than 1943 spread out research
		if lbControlMoscow and liCYear > 1942 then
			laTechWeights = {
				0.30, -- landBasedWeight
				0.15, -- landDoctrinesWeight
				0.10, -- airBasedWeight
				0.10, -- airDoctrinesWeight
				0.02, -- navalBasedWeight
				0.02, -- navalDoctrinesWeight
				0.12, -- industrialWeight
				0.05, -- secretWeaponsWeight
				0.14}; -- otherWeight
		else
			laTechWeights = {
				0.30, -- landBasedWeight
				0.20, -- landDoctrinesWeight
				0.05, -- airBasedWeight
				0.05, -- airDoctrinesWeight
				0.00, -- navalBasedWeight
				0.00, -- navalDoctrinesWeight
				0.15, -- industrialWeight
				0.05, -- secretWeaponsWeight
				0.20}; -- otherWeight
		end
	else
		laTechWeights = {
			0.20, -- landBasedWeight
			0.15, -- landDoctrinesWeight
			0.10, -- airBasedWeight
			0.10, -- airDoctrinesWeight
			0.03, -- navalBasedWeight
			0.03, -- navalDoctrinesWeight
			0.22, -- industrialWeight
			0.02, -- secretWeaponsWeight
			0.15}; -- otherWeight
	end

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
			--{"garrison_deployment", 0},
			{"jungle_warfare_equipment", 0},
			{"airlanding_infantry_brigade_activation", 0},
			{"air_commando_brigade_activation ", 0},
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
			{"NKVD_increase", 0},
			{"Guards_infantry_increase", 0},
			{"Guards_special_forces_increase", 0},
			{"Guards_mobile_increase", 0},
			{"Guards_armor_increase", 0},
			{"Guards_artillery_increase", 0},
			{"NKVD_decrease", 0},
			{"Guards_infantry_decrease", 0},
			{"Guards_special_forces_decrease", 0},
			{"Guards_mobile_decrease", 0},
			{"Guards_armor_decrease", 0},
			{"Guards_artillery_decrease", 0},
			{"paratrooper_infantry", 0}};
	else
		ignoreTech = {
			--{"garrison_deployment", 0},
			{"jungle_warfare_equipment", 0},
			{"airlanding_infantry_brigade_activation", 0},
			{"air_commando_brigade_activation", 0},
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
			{"NKVD_increase", 0},
			{"Guards_infantry_increase", 0},
			{"Guards_special_forces_increase", 0},
			{"Guards_mobile_increase", 0},
			{"Guards_armor_increase", 0},
			{"Guards_artillery_increase", 0},
			{"NKVD_decrease", 0},
			{"Guards_infantry_decrease", 0},
			{"Guards_special_forces_decrease", 0},
			{"Guards_mobile_decrease", 0},
			{"Guards_armor_decrease", 0},
			{"Guards_artillery_decrease", 0},
			{"paratrooper_infantry", 0}};
	end

	local preferTech = {
		"infantry_activation",
		"light_infantry_brigade_activation",
		"special_forces_upgrade",
		"Vehicle_reliability",
		"semi_motorization",
		"motorized_infantry",
		"Support_battalions_motorization",
		"infantry_guns",
		"infantry_at",
		"infantry_support",
		"smallarms_technology",
		"art_barrel_ammo",
		"gun_carriage",
		"range_finding",
		"small_calibre_gun_design",
		"medium_velocity_gun",
		"high_velocity_gun",
		"Artillery_motorization",
		"Artillery_fire_control_technics_dev",
		"tremendous_firepower_dev",
		"diesel_engine_design",
		"tank_chassis_design",
		"advanced_tank_chassis_design",
		"armor_brigade_design",
		"heavy_armor_brigade_design",
		"armor_thickness",
		"armor_plate_design",
		"cast_armour"};

	return ignoreTech, preferTech
end

function P.LandDoctrinesTechs(voTechnologyData)
	local ignoreTech = {
		{"banzai", 0},
		{"jungle_training", 0},
		{"jungle_command_and_control", 0},
		{"combined_arms_integration ", 0},
		{"interservice_communication", 0}
		};

	local preferTech = {
		"infantry_integration",
		"artillery_integration",
		"artillery_training",
		"artillery_command_and_control",
		"direct_fire_integration",
		"combined_arms_integration",
		"armor_integration",
		"partisan_suppression",
		"divisonal_command_structure",
		"Corps_command_structure",
		"army_command_structure",
		"armygroup_command_structure",
		"supreme_command_coordination",
		"interservice_HQ_structure",
		"homefront_coordination"};

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
		"light_bomber_design",
		"twin_engine_bomber_design",
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
		{"forward_air_control", 0},
		{"battlefield_interdiction", 0},
		{"bomber_targerting_focus", 0},
		{"fighter_targerting_focus", 0},
		{"heavy_bomber_pilot_training", 0},
		{"nav_pilot_training", 0},
		{"nav_groundcrew_training", 0},
		{"portstrike_tactics", 0},
		{"navalstrike_tactics", 0},
		{"naval_air_targeting", 0},
		{"naval_tactics", 0},
		{"heavy_bomber_groundcrew_training", 0}};

	local preferTech = {
		"fighter_pilot_training",
		"interception_tactics",
		"cas_pilot_training",
		"cas_groundcrew_training",
		"ground_attack_tactics",
		"tac_pilot_training",
		"interdiction_tactics",
		"WWI_dogfights",
		"tactical_air_command"};

	return ignoreTech, preferTech
end

function P.NavalTechs(voTechnologyData)
	local ignoreTech = {
		{"lightcruiser_technology", 0},
		{"light_cruiser_naval_guns", 0},
		{"lightcruiser_armour_thickness", 0},
		{"battlecruiser_technology", 0},
		{"battlecruiser_class", 0},
		{"battlecruiser_armour_thickness", 0},
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
		{"super_heavy_battleship_technology", 0},
		{"cag_development", 0},
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
		{"carrier_hanger", 0}};

	local preferTech = {
		"heavycruiser_technology",
		"heavycruiser_armour"};

	return ignoreTech, preferTech
end

function P.NavalDoctrineTechs(voTechnologyData)
	local ignoreTech = {
		{"fleet_auxiliary_carrier_doctrine", 0},
		{"naval_underway_repleshment", 0}};

	local preferTech = {
		"fleet_auxiliary_submarine_doctrine",
		"trade_interdiction_submarine_doctrine",
		"spotting"};

	return ignoreTech, preferTech
end

function P.IndustrialTechs(voTechnologyData)
	local ignoreTech = {
		{"fuel_conservation", 0},
		{"octane_conservation", 0},
		{"atomic_research", 0}};

	local preferTech = {
		"industral_production",
		"industral_efficiency",
		"agriculture",
		"industry_tech",
		"mass_events",
		"supply_production",
		"steel_production",
		"raremetal_refinning_techniques",
		"steel_casting_capability",
		"steel_electro_welding_technology",
		"supply_transportation",
		"supply_organisation",
		"logistical_warfare_focus",
		"home_front_focus",
		"broadcasting",
		"university",
		"expand_airbases",
		"Hangar_Maintenance",
		"hardended_airstrip",
		"control_tower",
		"education"};

	return ignoreTech, preferTech
end

function P.AntiTankTechs(voTechnologyData)
	local ignoreTech = {};

	local preferTech = {
		"artillery_support_gun_design",
		"small_calibre_gun_design",
		"medium_velocity_gun",
		"high_velocity_gun",
		"basic_at_ammo",
		"APC_ammo",
		"heat_ammo",
		"APCBC_ammo",
		"apds_ammo",
		"AA_AT_Rotation",
		"high_density_alloys",
		"munroes_effect"};

	return ignoreTech, preferTech
end

function P.SecretWeaponTechs(voTechnologyData)
	local ignoreTech = {}

	return ignoreTech, nil
end

function P.OtherTechs(voTechnologyData)
	local ignoreTech = {
		{"large_airsearch_radar", 0},
		{"medium_ship_radar", 0},
		{"emergency_recruitment_legislation", 0},
		{"big_ship_radar", 0},
		{"active_sonar", 0},
		{"large_navagation_radar", 0}};

	local preferTech = {
		"mechnical_computing_machine",
		"supply_transportation",
		"supply_organisation",
		"civil_defence",
		"automotive_construction_industry",
		"small_arms_manufacturing",
		"human_wave",
		"pakfront",
		"radio_technology",
		"radio",
		"radar",
		"infantry_radios",
		"tank_radios",
		"air_radios",
		"deep_battle_doctrine",
		"supreme_command_coordination",
		"operational_level_organisation",
		"electronic_computing_machine"};

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
	local gerTag = CCountryDataBase.GetTag("GER")
	local loGerCountry = gerTag:GetCountry()
	local loGerSovDiplo = voProductionData.ministerCountry:GetRelation(gerTag)

	-- Check to see if manpower is to low
	-- More than 400 brigades so build stuff that does not use manpower
	if voProductionData.ManpowerTotal < 500 then
		laArray = {
			0.0, -- Land
			0.70, -- Air
			0.00, -- Sea
			0.30}; -- Other

	elseif (voProductionData.ManpowerTotal < 1000 and voProductionData.LandCountTotal > 1000) then
		laArray = {
			0.30, -- Land
			0.30, -- Air
			0.00, -- Sea
			0.4}; -- Other
	elseif loGerSovDiplo:HasWar() then
		local lbControlMoscow = (CCurrentGameState.GetProvince(1409):GetController() == voProductionData.ministerTag)

		-- War is less than 10 months or we lost Moscow build massive land units
		if not(lbControlMoscow) then
			laArray = {
				0.90, -- Land
				0.10, -- Air
				0.0, -- Sea
				0.0}; -- Other

		-- War has been going on for atleast 2 years and we still have Moscow
		elseif lbControlMoscow and voProductionData.Year >= 1943 then
			laArray = {
				0.6, -- Land
				0.2, -- Air
				0.0, -- Sea
				0.2}; -- Other
		else
			laArray = {
				0.8, -- Land
				0.2, -- Air
				0.0, -- Sea
				0.00}; -- Other
		end
	-- We are atwar with someone other than Germany
	elseif voProductionData.IsAtWar then
		laArray = {
			0.70, -- Land
			0.20, -- Air
			0.00, -- Sea
			0.10}; -- Other

	-- 1936 just build up
	elseif voProductionData.Year <= 1936 then
		laArray = {
			0.0, -- Land
			0.0, -- Air
			0.00, -- Sea
			1.0}; -- Other

	elseif voProductionData.Year <= 1937 then
		laArray = {
			0.1, -- Land
			0.05, -- Air
			0.00, -- Sea
			0.85}; -- Other

elseif voProductionData.Year <= 1938 then
		laArray = {
			0.1, -- Land
			0.1, -- Air
			0.00, -- Sea
			0.8}; -- Other
		-- Produce lots of industry in the early years
	--   as long as Germany is not at war with anyone
	elseif voProductionData.Year <= 1939 and not(loGerCountry:IsAtWar()) then
		laArray = {
			0.2, -- Land
			0.1, -- Air
			0.00, -- Sea
			0.7};

	else
		laArray = {
			0.65, -- Land
			0.25, -- Air
			0.00, -- Sea
			0.10}; -- Other
	end

	return laArray
end

function P.LandRatio(voProductionData)
	local laArray

	local itaTag = CCountryDataBase.GetTag("ITA")
	local gerTag = CCountryDataBase.GetTag("GER")

	if (voProductionData.humanTag == gerTag) or (voProductionData.humanTag == itaTag) then
		laArray = {
			garrison_brigade = 3,
			infantry_brigade = 15,

			NKVD_brigade = 0.5,

			mechanized_brigade = 2,
			motorized_brigade = 4,
			semi_motorized_brigade = 1,

			armor_brigade = 7,
			heavy_armor_brigade = 1
		};
	else
		laArray = {
			garrison_brigade = 3,
			infantry_brigade = 16,

			mechanized_brigade = 2,
			motorized_brigade = 4,
			semi_motorized_brigade = 1,

			armor_brigade = 7,
			heavy_armor_brigade = 1
		};
	end

	laArray.ski_brigade = 1
	laArray.bergsjaeger_brigade = 1

	return laArray
end

-- Which units should get 1 more Support unit with Superior Firepower tech
function P.FirePower(voProductionData)
	local laArray = {
		"guard_infantry_brigade",
		"motorized_brigade",
		"mechanized_brigade",
		"armor_brigade",
		"heavy_armor_brigade"};

	return laArray
end

-- Air ratio distribution
function P.AirRatio(voProductionData)
	local laArray
	--local itaTag = CCountryDataBase.GetTag("ITA")
	--local gerTag = CCountryDataBase.GetTag("GER")
	--local loGerCountry = gerTag:GetCountry()
	--local loGerSovDiplo = voProductionData.ministerCountry:GetRelation(gerTag)

	laArray = {
		interceptor = 7,
		multi_role = 3,
		rocket_interceptor = 2,
		cas = 2,
		light_bomber = 2,
		tactical_bomber = 3
	};

	return laArray

end

-- Naval ratio distribution
function P.NavalRatio(voProductionData)
	local laArray = {
		transport_ship = 1,
		destroyer_actual = 4,
		submarine = 4,
		nuclear_submarine = 0,
		heavy_cruiser = 1,
		seaplane_tender = 0.25,
		battleship = 0.5};

	return laArray
end

-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		0, -- Land
		0,  -- Transport
		0}; -- Invasion

	if voProductionData.Year > 1942 then
		-- No need to make these checks till later so performance pushed inside the if statement
		local lbAtWarGER = voProductionData.ministerCountry:GetRelation(CCountryDataBase.GetTag("GER")):HasWar()

		if not(lbAtWarGER) or voProductionData.IsAtWar then
			laArray = {
				120, -- Land
				1,  -- Transport
				1}; -- Invasion
		end
	end

	return laArray
end

-- Convoy Ratio control
--- NOTE: If goverment is in Exile these parms are ignored
function P.ConvoyRatio(voProductionData)
	local laArray = {
		5, -- Percentage extra (adds to 100 percent so if you put 10 it will make it 110% of needed amount)
		20, -- If Percentage extra is less than this it will force it up to the amount entered
		30, -- If Percentage extra is greater than this it will force it down to this
		3} -- Escort to Convoy Ratio (Number indicates how many convoys needed to build 1 escort)

	return laArray
end

function P.Build_motorized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	if (voProductionData.Year <= 1942) then

		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "tank_destroyer_brigade"
		voType.second = "artillery_brigade"
		voType.third = "motorcycle_recon_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

		else


		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "medium_tank_destroyer_brigade"
		voType.second = "artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.fourth = "motorized_engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

function P.Build_mechanized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	if (voProductionData.Year <= 1942) then

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
		voType.second = "sp_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

function P.Build_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	local sovTag = CCountryDataBase.GetTag("GER")



	if voProductionData.humanTag == sovTag then
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_veteran"
		voType.SecondaryMain = "mechanized_infantry_bat"
		voType.first = "sp_artillery_brigade"
		voType.second = "armored_engineers_brigade"
		voType.third = "medium_tank_destroyer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

	elseif (voProductionData.Year <= 1940) then

		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "motorized_infantry_bat"
		voType.second = "artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"

		voType.Support = 0
		voType.SupportVariation = 0

	else


		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "mechanized_infantry_bat"
		voType.second = "sp_artillery_brigade"
		voType.SecondaryMain = "armored_engineers_brigade"
		voType.third = "medium_tank_destroyer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end


function P.Build_heavy_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	local sovTag = CCountryDataBase.GetTag("GER")
	--local check1 = voProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("armored_engineers_brigade"))
	--local check2 = voProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("sp_artillery_brigade"))

	if voProductionData.humanTag == sovTag then
		voType.SecondaryMain = "guard_mechanized_brigade"
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_guard_veteran"
		voType.second = "sp_artillery_brigade"
		voType.third = "assault_gun_brigade"
		voType.fourth = "armored_engineers_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

	else
		voType.SecondaryMain = "motorized_brigade"
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.second = "sp_artillery_brigade"
		voType.third = "armored_engineers_brigade"
		voType.fourth = "assault_gun_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end


	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

function P.Build_light_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)


		voType.SecondaryMain = "armored_engineers_brigade"
		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "motorized_infantry_bat"
		voType.second = "artillery_brigade"
		voType.third = "motorized_engineer_brigade"


		voType.Support = 0
		voType.SupportVariation = 0

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end


function P.Build_infantry_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	if (voProductionData.Year <= 1940) then

		voType.TransportMain = "horse_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "anti_tank_brigade"
		voType.second = "medium_artillery_brigade"
		voType.third = "Recon_cavalry_brigade"
		voType.SecondaryMain = "engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

		else


		voType.TransportMain = "horse_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "heavy_anti_tank_brigade"

		if math.random(100) < 50 then
			voType.second = "medium_artillery_brigade"
		else
			voType.second = "rocket_artillery_brigade"
		end

		voType.third = "Recon_cavalry_brigade"
		voType.SecondaryMain = "engineer_brigade"

		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end


function P.Build_semi_motorized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)



	-- voType.TertiaryMain = "division_hq"

	if (voProductionData.Year <= 1940) then

		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "anti_tank_brigade"
		voType.second = "medium_artillery_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		voType.sixth = "heavy_armor_brigade"
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

--[[
function P.Build_Industry(ic, voProductionData)
	local gerTag = CCountryDataBase.GetTag("GER")
	local loGerCountry = gerTag:GetCountry()
	-- Mass Build Industry in the Urals
	if voProductionData.Year <= 1940 and not(loGerCountry:IsAtWar()) then
		ic = Support.Build_Industry(ic, voProductionData, 8595, 10) -- Kemerovo
		ic = Support.Build_Industry(ic, voProductionData, 1330, 10) -- Kaznan
		ic = Support.Build_Industry(ic, voProductionData, 8191, 10) -- Perm
		ic = Support.Build_Industry(ic, voProductionData, 6632, 10) -- Syktyukar
		ic = Support.Build_Industry(ic, voProductionData, 8151, 10) -- Nizhnaya Tura
		ic = Support.Build_Industry(ic, voProductionData, 6727, 10) -- Krasnojarskij
		ic = Support.Build_Industry(ic, voProductionData, 8393, 10) -- Kurgan
		ic = Support.Build_Industry(ic, voProductionData, 968, 10) -- Kologriv
		ic = Support.Build_Industry(ic, voProductionData, 8529, 10) -- Blinkovo
		ic = Support.Build_Industry(ic, voProductionData, 8762, 10) -- Akshtau
		ic = Support.Build_Industry(ic, voProductionData, 8928, 10) -- Matay
		ic = Support.Build_Industry(ic, voProductionData, 6746, 10) -- Orenburg
		ic = Support.Build_Industry(ic, voProductionData, 6768, 10) -- Orsk
		ic = Support.Build_Industry(ic, voProductionData, 6788, 10) -- Aktobe
		ic = Support.Build_Industry(ic, voProductionData, 8211, 10) -- Kemerovo
		ic = Support.Build_Industry(ic, voProductionData, 6669, 10) -- Kaznan
		ic = Support.Build_Industry(ic, voProductionData, 8828, 10) -- Perm
		ic = Support.Build_Industry(ic, voProductionData, 8594, 10) -- Syktyukar
		ic = Support.Build_Industry(ic, voProductionData, 8743, 10) -- Nizhnaya Tura
		ic = Support.Build_Industry(ic, voProductionData, 7307, 10) -- Krasnojarskij
		ic = Support.Build_Industry(ic, voProductionData, 7287, 10) -- Kurgan
		ic = Support.Build_Industry(ic, voProductionData, 3464, 10) -- Kologriv
		ic = Support.Build_Industry(ic, voProductionData, 2859, 10) -- Blinkovo
		ic = Support.Build_Industry(ic, voProductionData, 2068, 10) -- Akshtau
		ic = Support.Build_Industry(ic, voProductionData, 6708, 10) -- Matay
		ic = Support.Build_Industry(ic, voProductionData, 311, 10) -- Orenburg
		ic = Support.Build_Industry(ic, voProductionData, 1201, 10) -- Krasnojarskij
		ic = Support.Build_Industry(ic, voProductionData, 1589, 10) -- Kurgan
		ic = Support.Build_Industry(ic, voProductionData, 46, 10) -- Kologriv
		ic = Support.Build_Industry(ic, voProductionData, 1409, 10) -- Blinkovo
		ic = Support.Build_Industry(ic, voProductionData, 1275, 10) -- Akshtau
		ic = Support.Build_Industry(ic, voProductionData, 1072, 10) -- Matay
		ic = Support.Build_Industry(ic, voProductionData, 1231, 10) -- Orenburg

		return ic, false
	end

	return ic, true
end
]]

function P.PrvForBuildingIndustry(voProductionData)

	-- Provinces to build in (less likely to fall in German hands)
	local provinces = {
		1201,
		968,
		1291,
		1421,
		1601,
		6690,
		1330,
		6708,
		1960,
		2131,
		2864,
		6746,
		6788,
		6727,
		8191,
		6669,
		6727,
		6827,
		8151,
		8213,
		8366,
		8393,
		7335,
		8999,
		9025,
		8903,
		9002,
		8952,
		8762,
		8528,
		8529,
		8658,
		8594,
		8595
	}

	-- Replace
	return provinces, true

end

-- Make SOV Fortify some key positions
function P.Build_Fort(ic, voProductionData)
 --   if voProductionData.Year > 1940 then
	--	ic = Support.Build_Fort(ic, voProductionData, 3309, 2) -- Odessa
		--ic = Support.Build_Fort(ic, voProductionData, 782, 5)  -- Leningrad
--		ic = Support.Build_Fort(ic, voProductionData, 1409, 5) -- Moskva
--		ic = Support.Build_Fort(ic, voProductionData, 3581, 2) -- Sevastopol
--		ic = Support.Build_Fort(ic, voProductionData, 2401, 1) -- Kharkov
--		ic = Support.Build_Fort(ic, voProductionData, 2857, 2) -- Stalingrad
--	end

	return ic, false
end

function P.Build_AntiAir(ic, voProductionData)
	return ic, false
end

function P.Build_CoastalFort(ic, voProductionData)
	return ic, false
end

function P.Build_NavalBase(ic, voProductionData)
	return ic, false
end

function P.Build_AirBase(vIC, voProductionData)
	return vIC, true
end

function P.Build_Infrastructure(vIC, voProductionData)
	return vIC, true
end

--[[
function P.Build_Radar(ic, voProductionData)
	if voProductionData.Year > 1938 then
		-- Ok to build a few
		ic = Support.Build_Radar(ic, voProductionData, 1409, 10) -- Moskva
		ic = Support.Build_Radar(ic, voProductionData, 782, 10) -- Leningrad
		ic = Support.Build_Radar(ic, voProductionData, 1991, 10) -- Homel
		ic = Support.Build_Radar(ic, voProductionData, 2401, 10) -- Kharkov

		return ic, true
	end

	return ic, false
end
]]

function P.Build_Radar(ic, voProductionData)
	return ic, false
end

-- Do not build Rocket Sites
function P.Build_RocketTest(ic, voProductionData)
	if voProductionData.Year > 1942 then
		local lbControlMoscow = (CCurrentGameState.GetProvince(1409):GetController() == voProductionData.ministerTag)
		if lbControlMoscow then
			return ic, true
		end
	end
	return ic, false
end
-- END OF PRODUTION OVERIDES
-- #######################################


function P.HandleMobilization(minister)
	local ministerTag = minister:GetCountryTag()
	local ministerCountry = ministerTag:GetCountry()
	local gerTag = CCountryDataBase.GetTag("GER")
	local loGerCountry = gerTag:GetCountry()

	-- Make sure Germany is at war and has a border with us
	if loGerCountry:IsAtWar() and ministerCountry:IsNonExileNeighbour(gerTag) and not(ministerCountry:IsAtWar()) then
		local ai = minister:GetOwnerAI()
		local fraTag = CCountryDataBase.GetTag("FRA")
		local year = ai:GetCurrentDate():GetYear()

		-- Check to see if France no longer controls Paris
		if not(CCurrentGameState.GetProvince(2613):GetController() == fraTag) then
			local liGermanFrontWarsCount = 0
			local norTag = CCountryDataBase.GetTag("NOR")

			for neighborTag in loGerCountry:GetNeighbours() do
				if loGerCountry:GetRelation(neighborTag):HasWar() then

					-- Do not count Norway as we are invading them
					if not(norTag == neighborTag) then
						liGermanFrontWarsCount = liGermanFrontWarsCount + 1
					end
				end
			end

			-- 10% random Chance if Germany is in a war and no fronts if the year is 1941 or better then mobilize
			if math.random(100) < 11 and liGermanFrontWarsCount == 0 then
				ai:Post(CToggleMobilizationCommand( ministerTag, true ))
			elseif math.random(100) < 26 and year >= 1941 then
				ai:Post(CToggleMobilizationCommand( ministerTag, true ))
			end

		-- Germany is atwar and has a front with us so go ahead and mobilize
		elseif year >= 1942 then
			ai:Post(CToggleMobilizationCommand( ministerTag, true ))
		end
	end
end

function P.DiploScore_Embargo(voDiploScoreObj)
	if tostring(voDiploScoreObj.EmbargoTag) == "JAP" then
		-- We must be in the cominterm
		if voDiploScoreObj.Faction == CCurrentGameState.GetFaction("comintern") then
			-- They must be in the Axis
			if voDiploScoreObj.EmbargoCountry:GetFaction() == CCurrentGameState.GetFaction("axis") then
				-- Do not embargo Japan under any circumstances other than war
				voDiploScoreObj.Score = 0
			end
		end
	end

	return voDiploScoreObj.Score
end

function P.DiploScore_NonAgression(viScore, voAI, voCountryOne, voCountryTwo, voObserver)
	-- If we are at war
	if voCountryOne.IsAtWar then
		local loComintern = CCurrentGameState.GetFaction("comintern")

		-- If we are part of the cominterm
		if voCountryOne.Faction == loComintern then
			local loAxis = CCurrentGameState.GetFaction("axis")

			-- If Japan is in the Axis
			if tostring(voCountryTwo.ministerTag) == "JAP"
			and voCountryTwo.Faction == loAxis then
				local gerTag = CCountryDataBase.GetTag("GER")
				local loGerCountry = gerTag:GetCountry()
				local loSovGerRelation = voCountryOne.ministerCountry:GetRelation(gerTag)

				-- If we are atwar with Germany then heavily consider a non aggression pact with Japan
				if loSovGerRelation:HasWar()
				and not(loGerCountry:IsGovernmentInExile())
				and loGerCountry:Exists() then
					viScore = 100
				end
			end
		end
	end

	return viScore
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		GER = {Score = 100},
		ITA = {Score = 75},
		CHC = {Score = 20},
		SPR = {Score = 20},
		SIK = {Score = 20},
		CHI = {Score = 20}
	}

	-- Calculate total german imports and refuse trades above the limit
	if voDiploScoreObj.TagName == "GER" then
		local germanTradedForResources = voDiploScoreObj.BuyerCountry:GetTradedForSansAlliedSupply()
		local icLimit = 300
		local energyLimit = icLimit * 2
		local metalLimit = icLimit
		local raresLimit = icLimit / 2

		if voDiploScoreObj.ResourceRequest.vEnergy then
			local gerTradedEnergy = germanTradedForResources:GetFloat(CGoodsPool._ENERGY_)
			if voDiploScoreObj.ResourceRequest.vEnergy + gerTradedEnergy > energyLimit then
				return -100
			end
		end
		if voDiploScoreObj.ResourceRequest.vMetal then
			local gerTradedMetal = germanTradedForResources:GetFloat(CGoodsPool._METAL_)
			if voDiploScoreObj.ResourceRequest.vMetal + gerTradedMetal > metalLimit then
				return -100
			end
		end
		if voDiploScoreObj.ResourceRequest.vRareMaterials then
			local gerTradedRares = germanTradedForResources:GetFloat(CGoodsPool._RARE_MATERIALS_)
			if voDiploScoreObj.ResourceRequest.vRareMaterials + gerTradedRares > raresLimit then
				return -100
			end
		end
	end

	-- Add base score

	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end

	return voDiploScoreObj.Score
end


--##########################
-- Foreign Minister Hooks
function P.ForeignMinister_ProposeWar(voForeignMinisterData)
	-- If we are pat of the Comintern then process this
	if not(voForeignMinisterData.Strategy:IsPreparingWar()) then
		if voForeignMinisterData.FactionName == "comintern" then
			-- We will not consider DOWing Germany if we are in a war already
			if not(voForeignMinisterData.IsAtWar) then
				-- Make sure we control Moscow
				if CCurrentGameState.GetProvince(1409):GetController() == voForeignMinisterData.ministerTag then
					local loAxisFaction = CCurrentGameState.GetFaction("axis")
					local loAxisTag = loAxisFaction:GetFactionLeader()
					local loAxisCountry = loAxisTag:GetCountry()

					-- Make sure we never surrendered in the past
					if not(loAxisCountry:GetFlags():IsFlagSet("su_signs_peace")) then
						local loAlliesTag = CCurrentGameState.GetFaction("allies"):GetFactionLeader()
						local loAxisAlliesRelation = loAxisCountry:GetRelation(loAlliesTag)
						local lbSealion = P.SealionCheck(loAxisAlliesRelation, loAxisFaction)

						-- Can we DOW the Axis Leader
						if lbSealion then
							if math.random(100) < 99 then
								voForeignMinisterData.Strategy:PrepareLimitedWar(loAxisTag, 100)
							end
						else
							local lbDOW = Support.GoodToWarCheck(loAxisTag, loAxisCountry, voForeignMinisterData, false, true)

							if lbDOW then
								if voForeignMinisterData.Year >= 1942 then
									if math.random(100) < 10 then
										voForeignMinisterData.Strategy:PrepareLimitedWar(loAxisTag, 100)
									end
								end
							elseif voForeignMinisterData.Year >= 1942 then
								-- Poland Check if we can go through them
								local loPOLTag = CCountryDataBase.GetTag("POL")
								local loPolandCountry = loPOLTag:GetCountry()
								lbDOW = Support.GoodToWarCheck(loPOLTag, loPolandCountry, voForeignMinisterData, false, true)

								if lbDOW then
									if math.random(100) < 30 then
										voForeignMinisterData.Strategy:PrepareLimitedWar(loPOLTag, 100)
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

function P.SealionCheck(voAxisAlliesRelation, voAxisFaction)
	-- Check for Sea Lion or Baltic and if so lets get involved before its to late
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
		2018,
		1262,
		1221} -- bristol

	local ger = CCountryDataBase.GetTag("GER")
	local human = CCurrentGameState.GetPlayer()
	if (human == ger) then
		if voAxisAlliesRelation:HasWar() then
			for i = 1, table.getn(laProvinceCheck) do
				local loProvinceFaction = CCurrentGameState.GetProvince(laProvinceCheck[i]):GetController():GetCountry():GetFaction()

				-- Is the province controlled by the Axis
				if loProvinceFaction == voAxisFaction then
					return true
				end
			end
		end
	end
	return false
end

function P.ForeignMinister_EvaluateDecision(voDecision, voForeignMinisterData)
	if voDecision.Name == "ultimatum_to_the_baltic_states" then
		if voForeignMinisterData.Year >= 1940 then
			return 100
		else
			return 0
		end
	end

	return voDecision.Score
end

function P.ForeignMinister_Influence(voForeignMinisterData)
	local laIgnoreWatch -- Ignore this country but monitor them if they are about to join someone else
	local laWatch -- Monitor them and also find their score is high enough they can be influenced normally
	local laIgnore -- Ignore them completely

	if voForeignMinisterData.FactionName == "comintern" then
		laIgnore = {
			"AUS", -- Austria
			"CZE", -- Czechoslovakia
			"SCH", -- Switzerland
			"LAT", -- Lativia
			"LIT", -- Lithuania
			"EST", -- Estonia
			"LUX", -- Luxemburg
			"VIC", -- Vichy
			"DEN", -- Denmark
			"ITA", -- Italy
			"JAP"} -- Japan
	end

	return laWatch, laIgnoreWatch, laIgnore
end

function P.DiploScore_RequestLendLease(liScore, voAI, voSenderTag)
	if tostring(voSenderTag) == "USA" and voSenderTag:GetCountry():GetFlags():IsFlagSet("lend_lease_act") then
		liScore = 200
	end
	return liScore
end

-- Always Heavy Industry Emphasis
function P.CallLaw_industrial_policy_laws(minister, voCurrentLaw)

	return CLawDataBase.GetLaw(22) -- _HEAVY_INDUSTRY_EMPHASIS_

end

return AI_SOV