-----------------------------------------------------------
-- LUA Hearts of Iron 3 Philipines File
-- Created By: Dr Johnson 20/08/11
-----------------------------------------------------------

local P = {}
AI_PHI = P

function P.ProductionWeights(voProductionData)
	local laArray

	laArray = {
		0.5, -- Land
		0.2, -- Air
		0.0, -- Sea
		0.3}; -- Other

	return laArray
end



return AI_PHI