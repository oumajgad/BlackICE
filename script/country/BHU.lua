-----------------------------------------------------------
-- LUA Hearts of Iron 3 Bhutan File
-- Created By: Dr Johnson 19/06/11
-----------------------------------------------------------

local P = {}
AI_BHU = P

function P.DiploScore_OfferTrade(score, ai, actor, recipient, observer, voTradedFrom, voTradedTo)
	local lsActorTag = tostring(actor)
	
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
		score = score + 20

	elseif lsActorTag == "ENG" 
	or lsActorTag == "USA" then
		score = score + 50
	end
	
	return score
end
return AI_BHU
