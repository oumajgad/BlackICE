local P = {}
AI_PER = P

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	local loAxis = CCurrentGameState.GetFaction("axis")
	
	if voDiploScoreObj.Faction == loAxis then
		voDiploScoreObj.Score = voDiploScoreObj.Score - 40
	end
	
	return voDiploScoreObj.Score
end

return AI_PER
