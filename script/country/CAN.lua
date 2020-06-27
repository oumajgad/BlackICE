
local P = {}
AI_CAN = P

-- #######################################


function P.ProductionWeights(voProductionData)
	local laArray
	
	-- Check to see if manpower is to low
	-- More than 100 brigades build stuff that does not use manpower
	if (voProductionData.ManpowerTotal < 60 and voProductionData.LandCountTotal > 60)
	or voProductionData.ManpowerTotal < 45 then
		laArray = {
			0.0, -- Land
			0.50, -- Air
			0.50, -- Sea
			0.00}; -- Other	
	elseif voProductionData.Year <= 1939 and not(voProductionData.IsAtWar) then
		-- Pre war, develop and get some navy going
		laArray = {
			0.00, -- Land
			0.00, -- Air
			0.20, -- Sea
			0.80}; -- Other
	elseif voProductionData.IsAtWar then
		-- Mostly helping in Europe/North Africa, dont bother with navy for Japan
		laArray = {
			0.60, -- Land
			0.00, -- Air
			0.40, -- Sea
			0.00}; -- Other
	else
		-- 1940 and not at war(unlikely)
		laArray = {
			0.25, -- Land
			0.25, -- Air
			0.25, -- Sea
			0.25}; -- Other
	end
	
	return laArray
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = {
		5, -- Land
		1}; -- Special Force Unit

	local laUnits = {marine_brigade = 1,
				bergsjaeger_brigade = 1};
	
	return laRatio, laUnits	
end

-- Transport to Land unit distribution
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
		SAF = {Score = 20},
		NZL = {Score = 20},
		FRA = {Score = 20}}
	
	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

return AI_CAN