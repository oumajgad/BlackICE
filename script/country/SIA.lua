
local P = {}
AI_SIA = P

-- Tech weights
--   1.0 = 100% the total needs to equal 1.0
function P.TechWeights(voTechnologyData)
	local laTechWeights = {
		0.30, -- landBasedWeight
		0.20, -- landDoctrinesWeight
		0.0, -- airBasedWeight
		0.0, -- airDoctrinesWeight
		0.0, -- navalBasedWeight
		0.0, -- navalDoctrinesWeight
		0.50, -- industrialWeight
		0.0, -- secretWeaponsWeight
		0.0}; -- otherWeight
	
	return laTechWeights
end

function P.AirTechs(voTechnologyData)
	local ignoreTech = {"all"};
	
	return ignoreTech, nil
end

function P.AirDoctrineTechs(voTechnologyData)
	local ignoreTech = {"all"};

	return ignoreTech, nil
end
		
function P.NavalTechs(voTechnologyData)
	local ignoreTech = {"all"}

	return ignoreTech, nil
end
		
function P.NavalDoctrineTechs(voTechnologyData)
	local ignoreTech = {"all"};

	return ignoreTech, nil
end
		
function P.SecretWeaponTechs(voTechnologyData)
	local ignoreTech = {"all"}
	
	return ignoreTech, nil
end

-- #######################################
-- Production Overides the main LUA with country specific ones

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray
	
	-- Japanese Puppet Production(also suitable pre-puppet), focus on Land and Development
	if voProductionData.ManpowerTotal < 50 then
		laArray = {
			0.0, -- Land
			0.0, -- Air
			0.0, -- Sea
			1.0}; -- Other
	else
		laArray = {
			0.25, -- Land
			0.0, -- Air
			0.0, -- Sea
			0.75}; -- Other
	end

	-- Build up
	if voProductionData.Year <= 1940 then
		laArray = {
			0.00, -- Land
			0.00, -- Air
			0.00, -- Sea
			1.00  -- Other
		};
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

-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		0, -- Land
		0,  -- transport
		0}  -- invasion craft
  
	return laArray
end

-- END OF PRODUTION OVERIDES
-- #######################################

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		JAP = {Score = 100}}
	
	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_Alliance(voDiploScoreObj)
	local lsTargetTag = voDiploScoreObj.TargetTag
	
	-- We like Japan so a small bonus to joining an alliance with them
	if lsTargetTag == "JAP" then
		voDiploScoreObj.Score = voDiploScoreObj.Score + 20
	elseif lsTargetTag == "CHI"
	or lsTargetTag == "CHC" 
	or lsTargetTag == "CGX" 
	or lsTargetTag == "CSX" 
	or lsTargetTag == "CXB"
	or lsTargetTag == "CYN" 
	or lsTargetTag == "SIK"
	or lsTargetTag == "ENG" 
	or lsTargetTag == "FRA" then
		voDiploScoreObj.Score = voDiploScoreObj.Score - 20
	end
	
	return voDiploScoreObj.Score
end

-- Want more troops, let them learn on the battlefield.
--   helps them produce troops faster
function P.CallLaw_training_laws(minister, voCurrentLaw)
	local _MINIMAL_TRAINING_ = 27
	return CLawDataBase.GetLaw(_MINIMAL_TRAINING_)
end

return AI_SIA
