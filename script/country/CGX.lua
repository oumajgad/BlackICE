local P = {}
AI_CGX = P

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
	-- Check to see if manpower is to low
	-- More than 30 brigades so build stuff that does not use manpower
	
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

		local JapRelation = voProductionData.ministerCountry:GetRelation(japTag)
		local JapWar = JapRelation:HasWar()

		if voProductionData.ManpowerTotal < 100 then
			laArray = {
				0.0, -- Land
				0.50, -- Air
				0.0, -- Sea
				0.50}; -- Other	
		elseif JapWar then
			laArray = {
				0.90, -- Land
				0.0, -- Air
				0.0, -- Sea
				0.10}; -- Other	
		else
			laArray = {
				0.25, -- Land
				0.0, -- Air
				0.0, -- Sea
				0.75}; -- Other
		end
	end
	
	return laArray
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laArray = {
		0, -- Land
		0}; -- Special Forces Unit
	
	return laArray, nil
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

-- Want more troops, let them learn on the battlefield.
--   helps them produce troops faster
function P.CallLaw_training_laws(minister, voCurrentLaw)
	local _MINIMAL_TRAINING_ = 27
	return CLawDataBase.GetLaw(_MINIMAL_TRAINING_)
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

return AI_CGX

