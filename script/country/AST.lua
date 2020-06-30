local P = {}
AI_AST = P


-- END OF TECH RESEARCH OVERIDES
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
		if voProductionData.Year <= 1940 then
			-- Likely called from UK vs German, more on land
			laArray = {
				0.60, -- Land
				0.10, -- Air
				0.30, -- Sea
				0.00}; -- Other
		else
			-- Likely facing Japan, more on naval
			laArray = {
				0.30, -- Land
				0.10, -- Air
				0.60, -- Sea
				0.00}; -- Other
		end
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
-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray = {infantry_brigade = 2,
			semi_motorized_brigade = 6,
			light_armor_brigade = 1,
			armor_brigade = 1};
	
	return laArray
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = {
		5, -- Land
		1}; -- Special Force Unit

	local laUnits = {marine_brigade = 1};
	
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
		CAN = {Score = 20},
		SAF = {Score = 20},
		NZL = {Score = 20},
		FRA = {Score = 20}}
	
	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

return AI_AST
