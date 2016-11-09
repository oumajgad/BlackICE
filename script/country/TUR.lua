
local P = {}
AI_TUR = P

function P.ProductionWeights(voProductionData)
	local laArray
	
	-- Check to see if manpower is to low
	-- More than 100 brigades build stuff that does not use manpower
	if (voProductionData.ManpowerTotal < 50 and voProductionData.LandCountTotal > 25)
	or voProductionData.ManpowerTotal < 25 then
		laArray = {
			0.0, -- Land
			0.50, -- Air
			0.50, -- Sea
			0.00}; -- Other	
	elseif voProductionData.Year <= 1938 and not(voProductionData.IsAtWar) then
		laArray = {
			0.00, -- Land
			0.50, -- Air
			0.50, -- Sea
			0.00}; -- Other
	elseif voProductionData.IsAtWar then
		if voProductionData.Year <= 1940 then
			laArray = {
				0.20, -- Land
				0.45, -- Air
				0.35, -- Sea
				0.00}; -- Other
		else
			laArray = {
				0.40, -- Land
				0.30, -- Air
				0.30, -- Sea
				0.00}; -- Other
		end
	else
		laArray = {
			0.30, -- Land
			0.40, -- Air
			0.30, -- Sea
			0.00}; -- Other
	end
	
	return laArray
end
-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray
	if voProductionData.Year < 1939 then
		laArray = {infantry_brigade = 5,
			semi_motorized_brigade = 6,
			light_armor_brigade = 1,
			armor_brigade = 1};
	else
		laArray = {infantry_brigade = 5,
			semi_motorized_brigade = 6,
			armor_brigade = 1};
	end
	return laArray
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = {
		5, -- Land
		1}; -- Special Force Unit

	local laUnits = {bergsjaeger_brigade = 1};
	
	return laRatio, laUnits	
end

-- Transport to Land unit distribution
function P.TransportLandRatio(voProductionData)
	local laArray = {
		12, -- Land
		1,  -- transport
		1}  -- invasion craft
  
	return laArray
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		GER = {Score = 100},
		ITA = {Score = 100},
		BUL = {Score = 20},
		ROM = {Score = 20},
		SOV = {Score = -50},
		ENG = {Score = -50},
		FRA = {Score = -20}}
	
	if laTrade[voDiploScoreObj.TagName] then
		voDiploScoreObj.Score = voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_Alliance(voDiploScoreObj)
	-- Stay out of the war, we do not care whats happening around us
	if not(voDiploScoreObj.IsAtWar) then
		voDiploScoreObj.Score = 0
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)
	-- We stay out of everything
	return 0
end

function P.ForeignMinister_Alignment(...)
	return Support.AlignmentNeutral(...)
end

return AI_TUR
