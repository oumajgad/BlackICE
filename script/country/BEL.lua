
local P = {}
AI_BEL = P

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray = {
		0.37, -- Land
		0.33, -- Air
		0.20, -- Sea
		0.10}; -- Other
	
	return laArray
end

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	-- Whatever their chance is lower it by 10 makes it harder to get them in
	return (voDiploScoreObj.Score - 10)
end

return AI_BEL

