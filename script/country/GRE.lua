
local P = {}
AI_GRE = P

function P.LandRatio(voProductionData)
	local laArray
	if voProductionData.Year < 1939 then
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

function P.ForeignMinister_Alignment(voForeignMinisterData)
	-- If Italy and the UK ar atwar check to see if we should shift toward allies
	if not(voForeignMinisterData.HasFaction) then
		local loENGTag = CCountryDataBase.GetTag("ENG")
		local loItaCountry = CCountryDataBase.GetTag("ITA"):GetCountry()
	
		if loItaCountry:GetRelation(loENGTag):HasWar() then
			return Support.AlignmentPush("allies", voForeignMinisterData)
		end
	end
	
	return true
end

function P.DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)
	local lsCountry = tostring(voCountry)

	-- Do not let Italy in our territory
	if lsCountry == "ITA" then
		viScore = viScore - 50
	end
	
	return viScore
end

return AI_GRE
