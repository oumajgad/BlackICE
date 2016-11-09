local P = {}
AI_FIN = P
function P.TechWeights(voTechnologyData)
	local laTechWeights = {
		0.22, -- landBasedWeight
		0.22, -- landDoctrinesWeight
		0.14, -- airBasedWeight
		0.12, -- airDoctrinesWeight
		0.04, -- navalBasedWeight
		0.04, -- navalDoctrinesWeight
		0.13, -- industrialWeight
		0.00, -- secretWeaponsWeight
		0.09}; -- otherWeight
	
	return laTechWeights
end

-- Techs that are used in the main file to be ignored
--   techname|level (level must be 1-9 a 0 means ignore all levels
--   use as the first tech name the word "all" and it will cause the AI to ignore all the techs
function P.LandTechs(voTechnologyData)
	local ignoreTech = {
			{"sp_anti_air_design", 0}, 
			{"sp_rct_art_brigade_design", 0},
			{"jungle_warfare_equipment", 0},
			{"airlanding_infantry_brigade_activation", 0},
			{"heavy_assault_gun_brigade_activation", 0},
			{"mechanised_infantry", 0},
			{"emergency_recruitment_legislation", 0},
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
			{"paratrooper_infantry", 0},
			{"air_commando_brigade_activation", 0},
			{"paratrooper_infantry", 0}};
		
	local preferTech = {
			"infantry_activation",
			"light_infantry_brigade_activation",
			"special_forces_upgrade",
			"Vehicle_reliability",
			"semi_motorization",
		    "air_defense_network",
			"pack_artillery_brigade_activation",
			"infantry_guns",
			"infantry_at",
			"infantry_support",
			"smallarms_technology",
			"extreme_terrain_combat_tactics",
			"mountain_warfare_equipment",
			"mountain_infantry"};
		
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
		{"interservice_communication", 0},
		{"interservice_coordination", 0},
		{"combined_arms_integration", 0},
		{"political_indoctrination", 0},
		{"political_integration ", 0}};
		
	local preferTech = {
		"infantry_integration",
		"infantry_training",
		"infantry_command_and_control",
		"mountain_training",
		"mountain_command_and_control"};		
		
	return ignoreTech, preferTech
end

function P.AirTechs(voTechnologyData)
	local ignoreTech = {
		{"basic_four_engine_airframe", 0},
		{"basic_strategic_bomber", 0},
		{"large_fueltank", 0},
		{"four_engine_airframe", 0},
		{"Flying_boat_activation", 0},
		{"glider_activation", 0},
		{"strategic_bomber_armament", 0},
		{"cargo_hold", 0},
		{"large_bomb", 0},
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
		"basic_bomb"};
		
	return ignoreTech, preferTech
end

function P.AirDoctrineTechs(voTechnologyData)
	local ignoreTech = {
		{"forward_air_control", 0},
		{"battlefield_interdiction", 0},
		{"bomber_targerting_focus", 0},
		{"fighter_targerting_focus", 0}, 
		{"heavy_bomber_pilot_training", 0},
		{"strategic_bombardment_tactics", 0},
		{"airborne_assault_tactics", 0},
		{"strategic_air_command", 0},
		{"heavy_bomber_groundcrew_training", 0}};

	local preferTech = {
		"fighter_pilot_training",
		"interception_tactics",
		"ground_attack_tactics",
		"tac_pilot_training",
		"interdiction_tactics",
		"tactical_air_command"};	
		
	return ignoreTech, preferTech
end
		
function P.NavalTechs(voTechnologyData)
	local ignoreTech = {
		{"battleship_technology", 0},
		{"battlecruiser_technology", 0},
		{"pocket_battleship_activation", 0},
		{"capitalship_armament", 0},
		{"capitalship_secondary", 0},
		{"cag_development", 0},
		{"super_heavy_battleship_technology", 0}};

	local preferTech = {
		};		
		
	return ignoreTech, preferTech
end
		
function P.NavalDoctrineTechs(voTechnologyData)
	local ignoreTech = {
	     {"fleet_auxiliary_carrier_doctrine", 0}
		};

	local preferTech = {
		};	
		
	return ignoreTech, preferTech
end

function P.IndustrialTechs(voTechnologyData)
	local ignoreTech = {
	    {"atomic_research", 0},
		{"pocket_battleship_activation", 0},
		{"monumental_architecture", 0},
		{"oil_refinning", 0}};

	local preferTech = {
		"secretary_of_public_information_and_education",
		"industral_production",
		"industral_efficiency",
		"agriculture",
		"industry_tech",
		"university",
		"basic_education"};
		
	return ignoreTech, preferTech
end
		
function P.SecretWeaponTechs(voTechnologyData)
	local ignoreTech = {"all"}
	
	return ignoreTech, nil
end

function P.OtherTechs(voTechnologyData)
	local ignoreTech = {
		{"large_airsearch_radar", 0},
		{"large_airsearch_radar", 0},
		{"tank_radios", 0}};

	local preferTech = {
		"mechnical_computing_machine",
		"electronic_computing_machine"};			

	return ignoreTech, preferTech
end


-- END OF TECH RESEARCH OVERIDES
-- ######################################
function P.LandRation(voProductionData)
	local laArray
	if voProductioData.Year < 1939 then
		laArray = {infantry_brigade = 4,
			semi_motorized_brigade = 2,
			garrison_brigade = 0.5,
			light_armor_brigade = 1,
			armor_brigade = 1};
	else
		laArray = {infantry_brigade = 4,
			garrison_brigade = 0.5,
			semi_motorized_brigade = 2,
			armor_brigade = 1};
	end
	return laArray
end
function P.HandleMobilization( minister )
	local ministerTag = minister:GetCountryTag()
	local ministerCountry = ministerTag:GetCountry()
	local ai = minister:GetOwnerAI()

	-- mobilize before winter war
	local sovTag = CCountryDataBase.GetTag('SOV')
	local estTag = CCountryDataBase.GetTag('EST')
	
	--if (not sovTag:GetCountry():IsAtWar())
	--and
	if ((not estTag:GetCountry():Exists()) or estTag:GetCountry():IsGovernmentInExile())	     
	then
		local command = CToggleMobilizationCommand( ministerTag, true )
		ai:Post( command )
		return
	end
	
	
	local year = ai:GetCurrentDate():GetYear()
	local month = ai:GetCurrentDate():GetMonthOfYear()
	local gerTag = CCountryDataBase.GetTag('GER')
	
	local warTime = ( year >= 1940 ) or ( year == 1939 and month >= 6 )

	if warTime
	and ( not ministerCountry:HasFaction() )
	and ( not ministerCountry:IsFriend( sovTag, false ) )
	and ( not ministerCountry:IsFriend( gerTag, false ) )
	then
		local finnishBorder = { [0] = 377, 353, 329, 286, 268, 253, 237, 210, 183 }
		local troupCount = 0
		for tmpIndex, provID in pairs(finnishBorder) do
			local province = CCurrentGameState.GetProvince( provID )
			troupCount = troupCount + province:GetNumberOfUnits()
		end
				
		if troupCount > 5
		then
			local command = CToggleMobilizationCommand( ministerTag, true )
			ai:Post( command )
			return
		end
	end
	
	-- general check of neighbors
	for neighborCountry in ministerCountry:GetNeighbours() do
		local threat = ministerCountry:GetRelation(neighborCountry):GetThreat():Get()
		if  threat > 30 then 
			--Utils.LUA_DEBUGOUT( "MOBILIZE " .. tostring(ministerTag) .. " " .. tostring(threat) .. "towards" .. tostring(neighborCountry) )
			local warDesirability = CalculateWarDesirability( ai, neighborCountry:GetCountry(), ministerTag )
			if warDesirability > 70 then
				local command = CToggleMobilizationCommand( ministerTag, true )
				ai:Post( command )
				return
			end
		end
	end
end

function P.ForeignMinister_CallAlly(voForeignMinisterData)
	return false
end


function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		GER = {Score = 100},
		NOR = {Score = 20},
		SOV = {Score = -50},
		SWE = {Score = 100}}
	
	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

--##########################
-- Foreign Minister Hooks

function P.ForeignMinister_Alignment(voForeignMinisterData)
	if not(voForeignMinisterData.HasFaction) and voForeignMinisterData.Year <= 1942 then
		local loSOVTag = CCountryDataBase.GetTag("SOV")
		
		-- Align with Germany if we go to war with the soviets
		if CCurrentGameState.GetProvince(698):GetOwner() == loSOVTag -- Viipuri
		or voForeignMinisterData.ministerCountry:GetRelation(loSOVTag):HasWar() then
			return Support.AlignmentPush("axis", voForeignMinisterData, true, true)
		end
	end
	
	return true
end

function P.ForeignMinister_EvaluateDecision(voDecision, voForeignMinisterData)
	-- Join the continuation war about 1 month later
	if voDecision.Name == "continuation_war" then
		local loGERTag = CCountryDataBase.GetTag("GER")
		local loGerSovDiplo = loGERTag:GetCountry():GetRelation(CCountryDataBase.GetTag("SOV"))
		
		if loGerSovDiplo:HasWar() then
			local loWar = loGerSovDiplo:GetWar()
			local liWarMonths = loWar:GetCurrentRunningTimeInMonths()
	
			if liWarMonths >= 1 then
				voDecision.Score = 100
			end
		end
		
		voDecision.Score = 0
	end
	
	return voDecision.Score
end

-- Finland has very highly trained forces
function P.CallLaw_training_laws(minister, voCurrentLaw)
	local _SPECIALIST_TRAINING_ = 30
	return CLawDataBase.GetLaw(_SPECIALIST_TRAINING_)
end

return AI_FIN
