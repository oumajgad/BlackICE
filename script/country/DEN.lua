
local P = {}
AI_DEN = P



-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray = {
			0.2, -- Land
			0.2, -- Air
			0.4, -- Sea
			0.2}; -- Other
	return laArray
end
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

function P.Build_CoastalFort(ic, voProductionData)
	return ic, false
end

function P.Build_AntiAir(ic, voProductionData)
	return ic, false
end

return AI_DEN

