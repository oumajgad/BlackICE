
local P = {}
AI_LUX = P

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)

	local laArray

	if voProductionData.IsAtWar then
		-- War with Germany, all on land
		laArray = {
			1, -- Land
			0.0, -- Air
			0.0, -- Sea
			0.0}; -- Other
	else
		-- Pre war
		laArray = {
			0.60, -- Land
			0.30, -- Air
			0.00, -- Sea
			0.10}; -- Other
	end

	return laArray
end

-- Lux wont join allies until really forced to
function P.DiploScore_InviteToFaction(voDiploScoreObj)
	if voDiploScoreObj.TargetIsAtWar then
		return 100
	else
		return -100
	end
end

return AI_LUX
