
local P = {}
AI_LUX = P

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray = {
		0.0, -- Land
		0.0, -- Air
		0.0, -- Sea
		1.0}; -- Other
	
	return laArray
end

return AI_LUX

