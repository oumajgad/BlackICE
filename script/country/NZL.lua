
local P = {}
AI_NZL = P
-- #######################################
-- Start of Tech Research

-- END OF TECH RESEARCH OVERIDES
-- #######################################

-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray = {
		garrison_brigade = 1,
		infantry_brigade = 4};
		
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
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		12, -- Land
		4,  -- transport
		1}  -- invasion craft
  
	return laArray
end

function P.AirRatio(voProductionData)
	local laArray = {
		interceptor = 4,
		multi_role = 2,
		cas = 3,
		tactical_bomber = 7,
		naval_bomber = 10};	
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
		CAN = {Score = 20},
		FRA = {Score = 20}}
	
	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

return AI_NZL

