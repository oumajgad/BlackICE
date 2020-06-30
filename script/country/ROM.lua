
local P = {}
AI_ROM = P

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = {
		5, -- Land
		1}; -- Special Force Unit

	local laUnits = { bergsjaeger_brigade = 1};
	
	return laRatio, laUnits	
end

function P.Build_garrison_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	
	if (math.random(100) < 15) then
		voType.TertiaryMain = "heavy_artillery_brigade"
		voType.SupportGroup = "Garrison"
		voType.Support = 0
	else
		voType.TertiaryMain = "artillery_brigade"
		voType.SupportGroup = "Garrison"
		voType.Support = 0
	end

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

function P.Build_motorized_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	
	if (voProductionData.Year <= 1938) then
		
		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "anti_tank_brigade"
		voType.second = "medium_artillery_brigade"
		voType.third = "motorcycle_recon_brigade"
		voType.SecondaryMain = "motorized_engineer_brigade"
		voType.Support = 0
		
		else
		
		
		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "tank_destroyer_brigade"
		voType.second = "medium_artillery_brigade"
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
		voType.forth = "motorized_engineer_brigade"
		voType.SecondaryMain = "sp_anti_air_brigade"
		voType.Support = 0
		
	else
		
		
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "medium_tank_destroyer_brigade"
		voType.second = "medium_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.forth = "motorized_engineer_brigade"
		voType.SecondaryMain = "sp_anti_air_brigade"
		voType.Support = 0
	end
	
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

function P.Build_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	
	local sovTag = CCountryDataBase.GetTag("SOV")
	

	
	if voProductionData.humanTag == sovTag then	
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "mechanized_infantry_bat"
		voType.second = "sp_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.forth = "armored_engineers_brigade"
		voType.SecondaryMain = "sp_anti_air_brigade"
		voType.sith = "medium_tank_destroyer_brigade"
		voType.Support = 0

	elseif (voProductionData.Year <= 1939) then
		
		voType.TransportMain = "truck_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "motorized_infantry_bat"
		voType.second = "medium_artillery_brigade"
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
		voType.SecondaryMain = "armored_engineers_brigade"
		voType.fifth = "sp_anti_air_brigade"
		voType.sith = "tank_destroyer_brigade"
		voType.Support = 0
	end
	
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end


function P.Build_heavy_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	local sovTag = CCountryDataBase.GetTag("SOV")
	

	if voProductionData.humanTag == sovTag then	
		voType.SecondaryMain = "ss_motorized_brigade"
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.second = "sp_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.forth = "armored_engineers_brigade"
		voType.fifth = "sp_anti_air_brigade"
		voType.sith = "medium_tank_destroyer_brigade"
		voType.Support = 0
		
	else
		voType.SecondaryMain = "semi_motorized_brigade"
		voType.TransportMain = "hftrack_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.second = "sp_artillery_brigade"
		voType.third = "armored_car_brigade"
		voType.forth = "armored_engineers_brigade"
		voType.fifth = "sp_anti_air_brigade"
		voType.sith = "medium_tank_destroyer_brigade"
		voType.Support = 0
	end	
	
		
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

function P.Build_light_armor_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)

		
		voType.SecondaryMain = "armored_engineers_brigade"
		voType.TransportMain = "light_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "motorized_infantry_bat"
		voType.second = "medium_artillery_brigade"
		voType.third = "motorcycle_recon_brigade"
		voType.forth = "motorized_engineer_brigade"


		voType.Support = 0

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
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
		
		else
		
		
		voType.TransportMain = "horse_transport"
		voType.TertiaryMain = "division_hq_standard"
		voType.first = "medium_tank_destroyer_brigade"
		voType.second = "medium_artillery_brigade"
		voType.third = "Recon_cavalry_brigade"
		voType.SecondaryMain = "engineer_brigade"
		voType.Support = 0
	end
		
	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData, laSupportUnit)
end

-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		0, -- Land
		0,  -- transport
		0}  -- invasion craft
  
	return laArray
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		GER = {Score = 100},
		ITA = {Score = 100},
		TUR = {Score = 20},
		SOV = {Score = -50},
		ENG = {Score = -20},
		FRA = {Score = -20}}
	
	if laTrade[voDiploScoreObj.TagName] then
		voDiploScoreObj.Score = voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_SendExpeditionaryForce(voForeignMinisterData)

		local  score = 0

		return score
end


function P.ForeignMinister_Alignment(...)
	return Support.AlignmentPush("axis", ...)
end

return AI_ROM