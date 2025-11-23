
-- #######################################
-- Production Overides the main LUA with country specific ones

-- Handle special Build Unit, the @@@ is the Unit type in string format
-- Build_@@@@@(ic, voProductionData, viUnitsNeeded)

-- #####################
-- Exepected Returns
-- IC = How much IC is left after execution
-- Boolean = Flag indicating weather to execute generic code as well for the building type
-- #####################
-- Build_Underground(ic, voProductionData)
-- Build_NuclearReactor(ic, voProductionData)
-- Build_RocketTest(ic, voProductionData)
-- Build_Industry(ic, voProductionData)
-- Build_CoastalFort(ic, voProductionData)
-- Build_Fort(ic, voProductionData)
-- Build_AntiAir(ic, voProductionData)
-- Build_Radar(ic, voProductionData)
-- Build_Infrastructure(ic, voProductionData)
-- Build_AirBase(ic, voProductionData)

-- must return how much IC is left


-- #######################################
-- Diplomacy Hooks
-- These all must return a numeric score (100 being 100% chance of success)

-- DiploScore_OfferTrade(voDiploScoreObj)
-- DiploScore_Alliance(voDiploScoreObj)
-- DiploScore_InviteToFaction(viScore, ai, actor, recipient, observer)
-- DiploScore_JoinFaction(viScore, minister, faction)
-- DiploScore_JoinFactionGoal(viScore, ai, actor, recipient, observer, goal )
-- DiploScore_InfluenceNation(voDiploScoreObj)
-- DiploScore_Guarantee(voDiploScoreObj)
-- DiploScore_Embargo(voDiploScoreObj)
-- DiploScore_NonAgression(voAI, voCountryOne, voCountryTwo,observer)
-- DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)
-- DiploScore_CallAlly(viScore, ai, actor, recipient, observer)
-- DiploScore_RequestLendLease(viScore, ai, actor, recipient, observer)
-- DiploScore_Debt(voDiploScoreObj)
-- EvaluateLimitedWar(viScore, minister, target, warDesirability)


--##########################
-- Foreign Minister Hooks

-- ForeignMinister_EvaluateDecision(voDecision, voForeignMinisterData)
-- ForeignMinister_CallAlly(voForeignMinisterData)
-- ForeignMinister_Alignment(voForeignMinisterData)
-- ForeignMinister_MilitaryAccess(voForeignMinisterData)
-- ForeignMinister_Influence(voForeignMinisterData)
-- ForeignMinister_ProposeWar(voForeignMinisterData)

--##########################
-- Politics Minister Hooks

-- HandleMobilization(minister)
-- HandlePuppets(minister)

-- Handle special Law cases, the @@@ is the law group name in string format
-- CallLaw_@@@@@(minister, loCurrentLaw)

-- Changing of Ministers
--    Each method is passed an array of ministers that can be put into the position
-- Call_ChiefOfAir(ministerCountry, vaMinisters)
-- Call_ChiefOfNavy(ministerCountry, vaMinisters)
-- Call_ChiefOfArmy(ministerCountry, vaMinisters)
-- Call_MinisterOfIntelligence(ministerCountry, vaMinisters)
-- Call_ChiefOfStaff(ministerCountry, vaMinisters)
-- Call_ForeignMinister(ministerCountry, vaMinisters)
-- Call_ArmamentMinister(ministerCountry, vaMinisters)
-- Call_MinisterOfSecurity(ministerCountry, vaMinisters)

-- #######################################
-- Intelligence Hooks

-- Intel_Home(voIntelligenceData)
-- Intel_Priority(voIntelligenceData, voIntelCountry)
-- Intel_Mission(voIntelligenceData, voIntelCountry)
-- Intel_Priority_Ally(voIntelligenceData, voIntelCountry)
-- Intel_Mission_Ally(voIntelligenceData, voIntelCountry)

local P = {}
AI_DEFAULT_MIXED = P

-- #######################################
-- Start of Tech Research

-- Tech weights
--   1.0 = 100% the total needs to equal 1.0
function P.TechWeights(voTechnologyData)
	local laArray = {
		0.12, -- _RESEARCH_LAND_
		0.20, -- _RESEARCH_LAND_DOC_
		0.13, -- _RESEARCH_AIR_
		0.10, -- _RESEARCH_AIR_DOC_
		0.12, -- _RESEARCH_NAVAL_
		0.10, -- _RESEARCH_NAVAL_DOC_
		0.23, -- _RESEARCH_INDUSTRIAL_
		0.00, -- _RESEARCH_SECRET_
		0.00}; -- _RESEARCH_UNKNOWN_

	return laArray
end

function P.LandTechs(voTechnologyData)
	local ignoreTech = {
		-- Unwanted officer recruiting
		{"officer_recruitment_program", 0},
		{"emergency_recruitment_legislation", 0},

		-- Unused infantry activation
		{"airlanding_infantry_brigade_activation", 0},
		{"motorized_infantry", 0},
		{"mechanised_infantry_desc", 0},

		-- Unused support activation
		{"pack_artillery_brigade_activation", 0},
		{"airborne_artillery_brigade_activation", 0},

		-- Unused artillery
		{"rocket_art", 0},
		{"rocket_art_ammo", 0},
		{"sp_rct_art_brigade_design", 0},
		{"sp_anti_air_design", 0},
		{"sp_artillery_brigade_design_desc", 0},

		-- Unused Heavy AA
		{"AA_AT_Rotation", 0},

		-- Unused vehicles
		{"heavy_assault_gun_brigade_activation", 0},
		{"heavy_armor_brigade_design", 0},
		{"super_heavy_tank_design", 0},
		{"amph_armour_brigade_activation", 0},
		{"assault_gun_brigade_activation_desc", 0},
		{"medium_tank_destroyer_brigade_activation", 0},
		{"heavy_tank_destroyer_brigade_activation", 0},
		{"tank_destroyer_brigade_activation", 0},

		-- Unused Armored Engineer
		{"armored_engineers_brigade_activation", 0},

		-- Unused Air Cavalry
		{"air_cavalry_brigade_activation", 0},

		};

	local preferTech = {
		"infantry_activation",
		"light_infantry_brigade_activation",
		"special_forces_upgrade",
		"Vehicle_reliability",
		"smallarms_technology",
		"infantry_support",
		"infantry_guns",
		"infantry_at",
		"semi_motorization",
		"engineer_brigade_activation",
		"engineer_bridging_equipment",
		"engineer_assault_equipment",
		"Support_battalions_motorization",
		"munroes_effect",
		"high_density_alloys",
		"basic_at_ammo",
		"APC_ammo",
		"heat_ammo",
		"APCBC_ammo",
		"apds_ammo",
		"range_finding",
		"art_barrel_ammo",
		"gun_carriage",
		"aa_ammo",
		"artillery_activation"
	};

	return ignoreTech, preferTech
end

function P.LandDoctrinesTechs(voTechnologyData)
	local ignoreTech = {
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
		{"engineers_decrease", 0}
	};

	-- Techs that unlock other important
	local preferTech = {
		"cavalry_pursuit_tactics",
		"ww1_warfare",
		"artillery_barrage"};

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
		};

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
		{"three_three_reverse", 0},
		{"four_two_reverse", 0},
		{"four_three_reverse", 0},
		{"three_four_reverse", 0},
		{"five_two_reverse", 0}
	};

	local preferTech = {
		"transport_ship_activation",
		"transport_ship_hull",
		"transport_ship_engine",
		"destroyer_technology",
		"destroyer_armament",
		"destroyer_antiaircraft",
		"destroyer_engine",
		"destroyer_armour"};

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
		{"Ship_Building_Technologies", 0},
		{"submarine_construction_technolgies", 0},
		{"fuel_conservation", 0},
		{"octane_conservation", 0},
		};

	local preferTech = {
		"construction_engineering",
		"oil_refinning",
		"steel_production",
		"raremetal_refinning_techniques",
		"coal_processing_technologies",
		"oil_to_coal_conversion",
		"steel_casting_capability",
		"land_defence_engineering",
		"airfield_construction",
		"port_construction",
		"agriculture",
		"industral_production",
		"industral_efficiency",
		"supply_production",
		"ammo_production",
		"food_rations_production",
		"basic_education",
		"university",
		"supply_transportation",
		"supply_organisation",
		"civil_defence",
		"electronic_mechanical_egineering",
		"census_tabulation_machine",
		"mechnical_computing_machine",
		"industry_tech",
		"heavy_industry_tech",
		"road_highway",
		"railway",
		"radar",
		"land_based_radar",
		"radio_technology",
		"radio_detection_equipment",
		"civil_medicine",
		"combat_medicine",
		"first_aid"
	};

	return ignoreTech, preferTech
end

function P.SecretWeaponTechs(voTechnologyData)
	local ignoreTech = {"all"}

	return ignoreTech, nil
end

function P.OtherTechs(voTechnologyData)
	local ignoreTech = {};

	local preferTech = {};

	return ignoreTech, preferTech
end

-- END OF TECH RESEARCH OVERIDES
-- #######################################

-- Land Brigades vs Air Units ratio
--   If Air Ratio is met AI will shift its Air IC to build land units
function P.LandToAirRatio(voProductionData)
	local laArray = {
		10, -- Land Brigades
		1}; -- Air

	return laArray
end

function P.ProductionWeights(voProductionData)
	local laArray

	-- Develop pre 1937
	if voProductionData.Year == 1936 then
		laArray = {
			0.4, -- Land
			0.1, -- Air
			0.0, -- Sea
			0.5}; -- Other
	elseif voProductionData.Year == 1937 then
		laArray = {
			0.50, -- Land
			0.10, -- Air
			0.10, -- Sea
			0.30}; -- Other
	elseif voProductionData.Year == 1938 then
		laArray = {
			0.60, -- Land
			0.10, -- Air
			0.10, -- Sea
			0.20}; -- Other
	else
		laArray = {
			0.60, -- Land
			0.20, -- Air
			0.15, -- Sea
			0.05}; -- Other
	end

	-- War check
	if voProductionData.IsAtWar then
		laArray = {
			0.8, -- Land
			0.2, -- Air
			0.0, -- Sea
			0.0}; -- Other
	end

	-- Manpower check
	if voProductionData.ManpowerTotal < 100 then
		laArray = {
			0.10, -- Land
			0.30, -- Air
			0.30, -- Sea
			0.30}; -- Other
	end

	-- Puppet Check
	if voProductionData.ministerCountry:IsPuppet() then
		laArray = {
			0.4, -- Land
			0.1, -- Air
			0.1, -- Sea
			0.4}; -- Other
	end

	return laArray
end

-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray

	-- IC tiers
	if voProductionData.icTotal < 25 then
		laArray = {
			infantry_brigade = 1,
			infantry_bat = 1,
			militia_brigade = 3,
			garrison_brigade = 2,
			cavalry_brigade = 1
		};
	elseif voProductionData.icTotal < 50 then
		laArray = {
			infantry_brigade = 2,
			light_infantry_brigade = 2,
			militia_brigade = 1,
			garrison_brigade = 1,
			cavalry_brigade = 1
		};
	elseif voProductionData.icTotal < 100 then
		laArray = {
			infantry_brigade = 4,
			light_infantry_brigade = 1,
			semi_motorized_brigade = 1,
			garrison_brigade = 2,
			light_armor_brigade = 1
		};
	else
		laArray = {
			infantry_brigade = 5,
			semi_motorized_brigade = 2,
			garrison_brigade = 1,
			light_armor_brigade = 2
		};
	end

	if voProductionData.Year >= 1941 then
		if laArray.semi_motorized_brigade ~= nil then
			laArray.motorized_brigade = laArray.semi_motorized_brigade
			laArray.semi_motorized_brigade = 0
		end
		if laArray.light_armor_brigade ~= nil then
			laArray.armor_brigade = laArray.light_armor_brigade
			laArray.light_armor_brigade = 0
		end
	end

	-- No militia during peace (countries that want it should specify it in own file)
	if not voProductionData.IsAtWar then
		laArray.militia_brigade = 0
	end

	-- Use special militia if flag set

	if voProductionData.ministerCountry:GetFlags():IsFlagSet("Communist_militia_brigade_activation") and laArray.militia_brigade ~= nil then
		laArray.Communist_militia_brigade = laArray.militia_brigade
		laArray.militia_brigade = 0
	end

	if voProductionData.ministerCountry:GetFlags():IsFlagSet("fascist_militia_brigade_activation") and laArray.militia_brigade ~= nil then
		laArray.fascist_militia_brigade = laArray.militia_brigade
		laArray.militia_brigade = 0
	end

	-- Use colonials if low IC and have flag

	if voProductionData.icTotal < 50 then

		-- Colonial group 1 (militia, garrison, cavalry, light infantry)
		if voProductionData.ministerCountry:GetFlags():IsFlagSet("colonial_cavalry_brigade_activation") then

			-- Colonial Militia
			if  laArray.militia_brigade ~= nil then
				laArray.colonial_militia_brigade = laArray.militia_brigade + (laArray.fascist_militia_brigade or 0) + (laArray.Communist_militia_brigade or 0)
				laArray.militia_brigade = 0
			end

			-- Colonial Light Infantry (replace infantry batallion, light infantry and infantry brigade)
			if  laArray.infantry_bat ~= nil then
				laArray.colonial_light_infantry_brigade = laArray.infantry_bat + (laArray.colonial_light_infantry_brigade or 0)
				laArray.infantry_bat = 0
			end

			if  laArray.light_infantry_brigade ~= nil then
				laArray.colonial_light_infantry_brigade = laArray.light_infantry_brigade + (laArray.colonial_light_infantry_brigade or 0)
				laArray.light_infantry_brigade = 0
			end

			if  laArray.infantry_brigade ~= nil then
				laArray.colonial_light_infantry_brigade = laArray.infantry_brigade + (laArray.colonial_light_infantry_brigade or 0)
				laArray.infantry_brigade = 0
			end

			-- Colonial Garrison
			if  laArray.garrison_brigade ~= nil then
				laArray.colonial_garrison_brigade = laArray.garrison_brigade
				laArray.garrison_brigade = 0
			end

			-- Colonial Cavalry
			if  laArray.cavalry_brigade ~= nil then
				laArray.colonial_cavalry_brigade = laArray.cavalry_brigade
				laArray.cavalry_brigade = 0
			end
		end

		-- Colonial group 2 (infantry, mountain infantry)
		if voProductionData.ministerCountry:GetFlags():IsFlagSet("colonial_infantry_brigade_activation") then

			-- Colonial Infantry (Already changed from Colonial group 1, just improve colonial_light_infantry_brigade to colonial_infantry_brigade)
			if  laArray.colonial_light_infantry_brigade ~= nil then
				laArray.colonial_infantry_brigade = laArray.colonial_light_infantry_brigade
				laArray.colonial_light_infantry_brigade = 0
			end

		end

	end

	return laArray
end

function P.Build_garrison_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

	if (math.random(100) < 50) then
        voType.TertiaryMain = "anti_air_brigade"
        voType.SupportGroup = "Garrison"
        voType.Support = 0
        voType.SupportVariation = 0
    else
        voType.TertiaryMain = "artillery_brigade"
        voType.SupportGroup = "Garrison"
        voType.Support = 0
        voType.SupportVariation = 0
    end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = {
		8, -- Land
		1}; -- Special Force Unit

	local laUnits = {
		bergsjaeger_brigade = 1
	}

	-- Use colonial mountain infantry if low IC
	if voProductionData.icTotal < 50 and voProductionData.ministerCountry:GetFlags():IsFlagSet("colonial_infantry_brigade_activation") then
		laUnits = {
			colonial_bergsjaeger_brigade = 1
		}
	end

	return laRatio, laUnits
end

-- Which units should get 1 more Support unit with Superior Firepower tech
--- Firepower is on ignore list but just in case human player researches it
function P.FirePower(voProductionData)
	local laArray = {"infantry_brigade"};

	return laArray
end

-- Air ratio distribution
function P.AirRatio(voProductionData)
	local laArray

	if voProductionData.icTotal < 25 then
		laArray = {
			interceptor = 1
		};
	elseif voProductionData.icTotal < 50 then
		laArray = {
			multi_role = 1
		};
	elseif voProductionData.icTotal < 100 then
		laArray = {
			interceptor = 2,
			multi_role = 1,
			cas = 1,
			light_bomber = 1
		};
	else
		laArray = {
			interceptor = 2,
			multi_role = 1,
			cas = 1,
			light_bomber = 1,
			tactical_bomber = 1,
			naval_bomber = 1
		};
	end

	return laArray
end

-- Flying Bomb/Rocket distribution against total Air Power
function P.RocketRatio(voProductionData)
	local laArray = {
		10, -- Air
		1}; -- Bomb/Rockety

	return laArray
end

function P.NavalRatio(voProductionData)
	local laArray

	if voProductionData.icTotal < 25 then
		laArray = {
			transport_ship = 1,
			destroyer_actual = 2,
			submarine = 1,
		};
	elseif voProductionData.icTotal < 50 then
		laArray = {
			transport_ship = 2,
			destroyer_actual = 3,
			light_cruiser = 1,
			submarine = 1,
		};
	elseif voProductionData.icTotal < 150 then
		laArray = {
			transport_ship = 3,
			destroyer_actual = 5,
			light_cruiser = 2,
			heavy_cruiser = 1,
			submarine = 3,
		};
	else
		laArray = {
			transport_ship = 12,
			destroyer_actual = 20,
			light_cruiser = 8,
			heavy_cruiser = 3,
			submarine = 8,
			light_carrier = 1,
			battleship = 1,
		};
	end

	return laArray
end

-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		20, -- Land
		1,  -- transport
		0}  -- invasion craft

	return laArray
end

-- Convoy Ratio control
--- NOTE: If goverment is in Exile these parms are ignored
function P.ConvoyRatio(voProductionData)
	local laArray = {
		5, -- Percentage extra (adds to 100 percent so if you put 10 it will make it 110% of needed amount)
		10, -- If Percentage extra is less than this it will force it up to the amount entered
		20, -- If Percentage extra is greater than this it will force it down to this
		20} -- Escort to Convoy Ratio (Number indicates how many convoys needed to build 1 escort)

	return laArray
end


-- Do not build Rocket Sites
function P.Build_RocketTest(ic, voProductionData)
	-- Only build Rocket Sites if 1943 or greater
	if voProductionData.Year <= 1942 then
		return ic, false
	else
		-- Small Country so wait till 1945 before we worry about this
		if (voProductionData.icTotal < 50 and voProductionData.Year <= 1945) then
			return ic, false
		end
	end

	return ic, true
end

return AI_DEFAULT_MIXED