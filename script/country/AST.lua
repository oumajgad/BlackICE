local P = {}
AI_AST = P


-- END OF TECH RESEARCH OVERIDES
-- #######################################

function P.ProductionWeights(voProductionData)
	local laArray

	-- Commonwealth Build

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
			0.10, -- Land
			0.10, -- Air
			0.30, -- Sea
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
			0.30, -- Land
			0.10, -- Air
			0.50, -- Sea
			0.10  -- Other
		};
	end

	-- Manpower Check
	if voProductionData.ManpowerTotal < 100 then
		laArray = {
			0.00, -- Land
			0.20, -- Air
			0.70, -- Sea
			0.10  -- Other
		};
	end
	
	return laArray
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = {
		3, -- Land
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

	-- Australian embargo on JAP due to war in China
	if CCountryDataBase.GetTag("AST"):GetCountry():GetFlags():IsFlagSet("australia_embargo_japan") and voDiploScoreObj.TagName == "JAP" then
		return 0
	end

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
