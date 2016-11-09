-----------------------------------------------------------
-- LUA Hearts of Iron 3 Luxemburg File
-- Created By: Dr Johnson 04/07/11
-----------------------------------------------------------

local P = {}
AI_SAU = P

function P.DiploScore_InviteToFaction(score, ai, actor, recipient, observer)
	-- Only go through these checks if we are being asked to join the Allies
	if tostring(actor:GetCountry():GetFaction():GetTag()) == "allies" then
		score = score - 100

	else
		if tostring(actor:GetCountry():GetFaction():GetTag()) == "axis" then
			score = score - 100
		end
	end
	return score
end

return AI_SAU