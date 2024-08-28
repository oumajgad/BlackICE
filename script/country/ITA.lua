
local P = {}
AI_ITA = P

-- #######################################
-- Start of Trade Weights
function P.TechWeights(voTechnologyData)
	local laTechWeights = {
		0.15, -- landBasedWeight
		0.15, -- landDoctrinesWeight
		0.10, -- airBasedWeight
		0.10, -- airDoctrinesWeight
		0.18, -- navalBasedWeight
		0.10, -- navalDoctrinesWeight
		0.10, -- industrialWeight
		0.00, -- secretWeaponsWeight
		0.12}; -- otherWeight

	return laTechWeights
end

-- Techs that are used in the main file to be ignored
--   techname|level (level must be 1-9 a 0 means ignore all levels
--   use as the first tech name the word "all" and it will cause the AI to ignore all the techs
function P.LandTechs(voTechnologyData)
	local ignoreTech = {
		{"sp_anti_air_design", 0},
		{"garrison_deployment", 0},
		{"sp_rct_art_brigade_design", 0},
		{"jungle_warfare_equipment", 0},
		{"airlanding_infantry_brigade_activation", 0},
		{"heavy_assault_gun_brigade_activation", 0},
		{"heavy_armor_brigade_design", 0},
		{"heavy_tank_destroyer_brigade_activation", 0},
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
		{"paratrooper_infantry", 0}};

	local preferTech = {
	    "infantry_activation",
		"light_infantry_brigade_activation",
		"special_forces_upgrade",
		"Vehicle_reliability",
		"semi_motorization",
	    "air_defense_network",
		"desert_warfare_equipment",
		"infantry_guns",
		"infantry_at",
		"infantry_support",
		"smallarms_technology",
		"armor_brigade_design",
		"light_armor_brigade_design",
		"tank_chassis_design",
		"high_velocity_gun",
		"medium_velocity_gun"};

	return ignoreTech, preferTech
end

function P.LandDoctrinesTechs(voTechnologyData)
	local ignoreTech = {
		{"combined_arms_integration", 0},
		{"interservice_coordination", 0},
		{"interservice_communication", 0},
		{"resistance_support", 0},
		{"human_wave", 0},
		{"banzai", 0},
		{"jungle_training", 0},
		{"jungle_command_and_control", 0},
		{"political_indoctrination", 0},
		{"political_integration", 0}};

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
		"elastic_defense"};

	return ignoreTech, preferTech
end

function P.AirTechs(voTechnologyData)
	local ignoreTech = {
		{"four_engine_bomber_design", 0},
		{"four_engine_bombbay", 0},
		{"large_fueltank", 0},
		{"basic_four_engine_airframe", 0},
		{"four_engine_airframe", 0},
		{"four_engine_bomber_crew_layout", 0},
		{"air_refueling_plane_design", 0},
		{"AA_ordnance", 0},
		{"four_engine_gunner_pos", 0},
		{"four_engine_gunner_strength", 0},
		{"gun_turrets", 0},
		{"dam_bust_bomb", 0},
		{"tallboy_bomb", 0},
		{"grandslam_bomb", 0},
		{"twin_engine_fighter_design", 0},
		{"in_air_refueling", 0},
		{"strategic_bomber_armament", 0}
	};

	local preferTech = {
		"single_engine_fighter_design",
		"single_engine_aircraft_armament",
		"single_engine_airframe",
		"single_engine_aircraft_machinegun",
		"advanced_aircraft_development",
		"aeroengine",
		"retractable_undercarriage",
		"aerodyn_fuselage",
		"aerodyn_wings",
		"small_fueltank",
		"medium_fueltank",
		"multirole_fighter_design",
		"naval_bomber_design",
		"small_bomb",
		"wing_guns",
		"ammo_capacity",
		"aerodyn_fuselage",
		"aerodyn_wings",
		"engine_boost",
		"self_sealing_fueltanks",
		"air_cooling_sys",
		"drop_shaped_cockpit",
		"light_bomber_design",
		"twin_engine_bomber_design",
		"twin_engine_aircraft_armament",
		"twin_engine_airframe",
		"cas_design"
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
		{"heavy_bomber_groundcrew_training", 0}};

	local preferTech = {
		"fighter_pilot_training",
		"interception_tactics",
		"nav_pilot_training",
		"nav_groundcrew_training",
		"ground_attack_tactics",
		"tac_pilot_training",
		"interdiction_tactics",
		"tactical_air_command"};

	return ignoreTech, preferTech
end

function P.NavalTechs(voTechnologyData)
	local ignoreTech = {
		{"pocket_battleship_activation", 0},
		{"super_heavy_battleship_technology", 0}};

	local preferTech = {
		};

	return ignoreTech, preferTech
end

function P.NavalDoctrineTechs(voTechnologyData)
	local ignoreTech = {
		};

	local preferTech = {
		"basing",
	    "battlefleet_concentration_doctrine",
		"commander_decision_making"
		};

	return ignoreTech, preferTech
end

function P.IndustrialTechs(voTechnologyData)
	local ignoreTech = {
		{"civil_nuclear_research ", 0},
		{"isotope_seperation", 0},
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
		"raremetal_refinning_techniques",
		"steel_casting_capability",
		"steel_electro_welding_technology",
		"civil_defence",
		"logistical_warfare_focus",
		"home_front_focus",
		"combat_medicine",
		"first_aid",
		"medical_evacuation",
		"secretary_of_public_information_and_education",
		"expand_airbases",
		"Hangar_Maintenance",
		"hardended_airstrip",
		"control_tower",
		"basic_education"};

	return ignoreTech, preferTech
end

function P.SecretWeaponTechs(voTechnologyData)
	local ignoreTech = {"all"}

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
		{"large_airsearch_radar", 0},
		{"emergency_recruitment_legislation", 0},
		{"large_navagation_radar", 0}};

	local preferTech = {
		"mechnical_computing_machine",
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

	-- Build up
	if voProductionData.Year == 1936 then
		laArray = {
			0.50, -- Land
			0.20, -- Air
			0.00, -- Sea
			0.30}; -- Other
	end
	if voProductionData.Year == 1937 then
		laArray = {
			0.20, -- Land
			0.10, -- Air
			0.50, -- Sea
			0.20}; -- Other
	end
	if voProductionData.Year >= 1938 then
		laArray = {
			0.50, -- Land
			0.30, -- Air
			0.18, -- Sea
			0.02}; -- Other
	end

	-- War check
	if voProductionData.IsAtWar then
		laArray = {
			0.50, -- Land
			0.30, -- Air
			0.18, -- Sea
			0.02}; -- Other
	end

	-- Manpower check
	if (voProductionData.ManpowerTotal < 300) then
		laArray = {
			0.0, -- Land
			0.55, -- Air
			0.35, -- Sea
			0.10}; -- Other
	end

	return laArray
end
-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray = {
		garrison_brigade = 4,
		infantry_brigade = 9,
		semi_motorized_brigade = 2,
		mechanized_brigade = 1,
		light_armor_brigade = 3,
		bergsjaeger_brigade = 1};

	return laArray
end
-- Air ratio distribution
function P.AirRatio(voProductionData)
	local laArray = {
		interceptor = 6,
		cas = 2,
		light_bomber = 2,
		multi_role = 4,
		tactical_bomber = 2,
		naval_bomber = 2};

	return laArray
end
-- Naval ratio distribution
function P.NavalRatio(voProductionData)
	local laArray = {
		transport_ship = 8,
		landing_craft = 1,
		destroyer_actual = 8,
		light_cruiser = 6,
		submarine = 6,
		heavy_cruiser = 2
	};

	return laArray
end

-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		12, -- Land
		1,  -- transport
		1}  -- invasion craft

	return laArray
end

-- Convoy Ratio control
--- NOTE: If goverment is in Exile these parms are ignored
function P.ConvoyRatio(voProductionData)
	local laArray = {
		100, -- Percentage extra (adds to 100 percent so if you put 10 it will make it 110% of needed amount)
		100, -- If Percentage extra is less than this it will force it up to the amount entered
		100, -- If Percentage extra is greater than this it will force it down to this
		5} -- Escort to Convoy Ratio (Number indicates how many convoys needed to build 1 escort)

	return laArray
end

function P.Build_motorized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	if (voProductionData.Year <= 1938) then

		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "anti_tank_brigade"
		voType.second = "artillery_brigade"
		voType.third = "motorcycle_recon_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

		else


		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "tank_destroyer_brigade"
		voType.second = "artillery_brigade"
		voType.fourth = "motorized_engineer_brigade"
		voType.fifth = "light_armor_bat"
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
		voType.second = "artillery_brigade"
		voType.fourth = "motorized_engineer_brigade"
		voType.fifth = "light_armor_bat"
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
		voType.second = "sp_artillery_brigade"
		voType.fourth = "armored_engineers_brigade"
		voType.sixth = "medium_tank_destroyer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0

	elseif (voProductionData.Year <= 1939) then

		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "motorized_infantry_bat"
		voType.second = "artillery_brigade"
		voType.fourth = "motorized_engineer_brigade"
		voType.fifth = "tank_destroyer_brigade"

		voType.Support = 0
		voType.SupportVariation = 0

	else


		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "mechanized_infantry_bat"
		voType.second = "sp_artillery_brigade"
		voType.SecondaryMain = "armored_engineers_brigade"
		voType.sixth = "tank_destroyer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end


function P.Build_heavy_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	local sovTag = CCountryDataBase.GetTag("SOV")


	if voProductionData.humanTag == sovTag then
		voType.SecondaryMain = "ss_motorized_brigade"
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
		voType.first = "medium_tank_destroyer_brigade"
		voType.second = "medium_artillery_brigade"
		voType.fourth = "heavy_anti_air_brigade"
		voType.SecondaryMain = "engineer_brigade"
		voType.Support = 0
		voType.SupportVariation = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

function P.Build_NavalBase(vIC, voProductionData)
	return vIC, false
end

function P.Build_AntiAir(vIC, voProductionData)
	if voProductionData.Year > 1940 then
		return vIC, true
	end

	return vIC, false
end

function P.Build_CoastalFort(vIC, voProductionData)
	if voProductionData.Year > 1940 then
		return vIC, true
	end

	return vIC, false
end

-- END OF PRODUTION OVERIDES
-- #######################################

--function P.HandlePuppets(minister)
--	local ministerTag =  minister:GetCountryTag()
--	local ministerCountry = ministerTag:GetCountry()

--	for loPuppetTag in ministerCountry:GetPossiblePuppets() do
--		if tostring(loPuppetTag) == "ETH" then
--			minister:GetOwnerAI():Post(CCreateVassalCommand(loPuppetTag, ministerTag))
--		end
--	end
--end

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

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		SOV = {Score = 50},
		SWE = {Score = 100},
		GER = {Score = 100},
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

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	-- If we are not part of the same ideology as the requesting country do not even consider it
	if not(voDiploScoreObj.IdeologyGroup == voDiploScoreObj.TargetIdeologyGroup) then
		voDiploScoreObj.Score = 0
	end

	return voDiploScoreObj.Score
end

function P.DiploScore_Alliance(voDiploScoreObj)
	-- If we are not part of the same ideology as the requesting country do not even consider it
	if not(voDiploScoreObj.IdeologyGroup == voDiploScoreObj.TargetIdeologyGroup) then
		voDiploScoreObj.Score = 0
	end

	return voDiploScoreObj.Score
end

--##########################
-- Foreign Minister Hooks
function P.ForeignMinister_EvaluateDecision(voDecision, voForeignMinisterData)
	return voDecision.Score
end

function P.ForeignMinister_Influence(voForeignMinisterData)
	local laIgnoreWatch -- Ignore this country but monitor them if they are about to join someone else
	local laWatch -- Monitor them and also fi their score is high enough they can be influenced normally
	local laIgnore -- Ignore them completely

	if voForeignMinisterData.FactionName == "axis" then
		laWatch = {
			"NOR", -- Norway
			"BUL", -- Bulgaria
			"FIN", -- Finland
			"ROM", -- Romania
			"BEL", -- Belgium
			"HOL", -- Holland
			"HUN"};	 -- Hungary

		laIgnoreWatch = {
			"TUR", -- Turkey
			"SPA", -- Spain
			"SPR", -- Republic Spain
			"POR", -- Portugal
			"SWE", -- Sweden
			"CHI"} -- China

		laIgnore = {
			"AST", -- Australia
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

return AI_ITA