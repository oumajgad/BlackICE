-----------------------------------------------------------
-- LUA Hearts of Iron 3 Bhutan File
-- Created By: Dr Johnson 19/06/11
-----------------------------------------------------------

local P = {}
AI_BHU = P

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local lsActorTag = tostring(voDiploScoreObj.TagName)
	
	if lsActorTag == "AST"
	or lsActorTag == "BEL" 
	or lsActorTag == "BBU" 
	or lsActorTag == "IND"
	or lsActorTag == "CAN"
	or lsActorTag == "DEN"
	or lsActorTag == "EGY" 
	or lsActorTag == "FRA" 
	or lsActorTag == "GRE"
	or lsActorTag == "HOL"
	or lsActorTag == "NEP"
	or lsActorTag == "NOR" 
	or lsActorTag == "NZL" 
	or lsActorTag == "OMN"
	or lsActorTag == "SAF" 
	or lsActorTag == "YEM" then
		voDiploScoreObj.Score = voDiploScoreObj.Score + 20

	elseif lsActorTag == "ENG" 
	or lsActorTag == "USA" then
		voDiploScoreObj.Score = voDiploScoreObj.Score + 50
	end
	
	return voDiploScoreObj.Score
end

return AI_BHU
