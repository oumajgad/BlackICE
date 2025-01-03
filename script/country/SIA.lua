
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

return AI_SIA