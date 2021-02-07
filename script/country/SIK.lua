
local P = {}
AI_SIK = P

-- END OF PRODUTION OVERIDES
-- #######################################

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

function P.DiploScore_ConsiderAccess(viScore, ai, actor, recipient, observer)
	local lsRepTag = tostring(recipient)
	
	-- Check to see who is requesting military access
	if lsRepTag == "JAP" then
		viScore = 0
	end
	
	return viScore
end

return AI_SIK 

