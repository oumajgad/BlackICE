local P = {}
AI_CHC = P

-- Tech weights
--   1.0 = 100% the total needs to equal 1.0
function P.TechWeights(voTechnologyData)
	local laTechWeights = {
		0.5, -- landBasedWeight
		0.4, -- landDoctrinesWeight
		0.0, -- airBasedWeight
		0.0, -- airDoctrinesWeight
		0.0, -- navalBasedWeight
		0.0, -- navalDoctrinesWeight
		0.1, -- industrialWeight
		0.0, -- secretWeaponsWeight
		0.0}; -- otherWeight
	
	return laTechWeights
end

-- END OF TECH RESEARCH OVERIDES
-- #######################################


-- #######################################
-- Production Overides the main LUA with country specific ones

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray

	local japTag = CCountryDataBase.GetTag("JAP")

	-- More land focus vs JAP player
	if (voProductionData.humanTag == japTag) then
		if voProductionData.ManpowerTotal < 100 then
			laArray = {
			0.0, -- Land
			0.50, -- Air
			0.0, -- Sea
			0.50}; -- Other
		else
			laArray = {
			0.80, -- Land
			0.15, -- Air
			0.00, -- Sea
			0.05}; -- Other	
		end	

	-- More normal focus vs JAP AI
	else
		if voProductionData.ManpowerTotal < 100 then
			laArray = {
				0.0, -- Land
				0.50, -- Air
				0.0, -- Sea
				0.50}; -- Other	
		elseif voProductionData.IsAtWar then
			laArray = {
				0.90, -- Land
				0.0, -- Air
				0.0, -- Sea
				0.10}; -- Other	
		else
			laArray = {
				0.50, -- Land
				0.0, -- Air
				0.0, -- Sea
				0.50}; -- Other
		end
	end

	return laArray
end

-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray
	
	laArray = {
		infantry_brigade = 1,
		garrison_brigade = 1,
		cavalry_brigade = 1,
		Communist_militia_brigade = 6
	};

	return laArray
end

-- Air ratio distribution
function P.AirRatio(voProductionData)
	local laArray = {
		interceptor = 3, 
		cas = 1, 
		tactical_bomber = 2};
	
	return laArray
end

-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		0, -- Land
		0,  -- transport
		0}  -- invasion craft
  
	return laArray
end

-- Do not build coastal forts
function P.Build_CoastalFort(ic, voProductionData)
	return ic, false
end

-- END OF PRODUTION OVERIDES
-- #######################################

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	-- If we are not part of the same ideology as the requesting country do not even consider it
	if not(voDiploScoreObj.IdeologyGroup == voDiploScoreObj.TargetIdeologyGroup) then
		voDiploScoreObj.Score = 0
	end
	
	-- China does not join any faction
	return voDiploScoreObj.Score
end


function P.DiploScore_Alliance(voDiploScoreObj)
	-- Make sure we are not in a faction already and China is the one asking
	if not(voDiploScoreObj.TargetHasFaction) and tostring(voDiploScoreObj.ministerTag) == "CHI" then
		-- If China and Japan are atwar then come to their help
		if voDiploScoreObj.ministerCountry:GetRelation(CCountryDataBase.GetTag("JAP")):HasWar() then
			voDiploScoreObj.Score = voDiploScoreObj.Score + 50
		end
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)
	local lsCountry = tostring(voCountry)

	-- Do not let Japan in our territory
	if lsCountry == "JAP" then
		viScore = 0
	end
	
	return viScore
end

return AI_CHC
