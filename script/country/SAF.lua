
local P = {}
AI_SAF = P

function P.ProductionWeights(voProductionData)
	local laArray

	-- Commonwealth Build (Less navy than rest of Commonwealth, expect a lot of land fight in Africa)

	-- Build up
	if voProductionData.Year <= 1937 then
		laArray = {
			0.00, -- Land
			0.00, -- Air
			0.00, -- Sea
			1.00  -- Other
		};
	elseif voProductionData.Year <= 1939 then
		laArray = {
			0.20, -- Land
			0.10, -- Air
			0.20, -- Sea
			0.50  -- Other
		};
	else
		laArray = {
			0.30, -- Land
			0.10, -- Air
			0.50, -- Sea
			0.10  -- Other
		};
	end
	
	-- War Check
	if voProductionData.IsAtWar then
		laArray = {
			0.50, -- Land
			0.20, -- Air
			0.20, -- Sea
			0.10  -- Other
		};
	end

	-- Manpower Check
	if voProductionData.ManpowerTotal < 100 then
		laArray = {
			0.00, -- Land
			0.30, -- Air
			0.40, -- Sea
			0.10  -- Other
		};
	end
	
	return laArray
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = {
		100, -- Land
		1}; -- Special Force Unit

	local laUnits = {marine_brigade = 1,
		bergsjaeger_brigade = 1};
	
	return laRatio, laUnits	
end

-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		12, -- Land
		4,  -- transport
		1}  -- invasion craft
  
	return laArray
end

function P.ForeignMinister_Alignment(...)
	return Support.AlignmentPush("allies", ...)
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		ENG = {Score = 20},
		AST = {Score = 20},
		CAN = {Score = 20},
		NZL = {Score = 20},
		FRA = {Score = 20}}
	
	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

return AI_SAF
