-----------------------------------------------------------
-- LUA Hearts of Iron 3 Luxemburg File
-- Created By: Dr Johnson 04/07/11
-----------------------------------------------------------

local P = {}
AI_SAU = P

function P.DiploScore_InviteToFaction(loDiploScoreObj)
	-- Only go through these checks if we are being asked to join the Allies
	if tostring(loDiploScoreObj.ministerTag:GetCountry():GetFaction():GetTag()) == "allies" then
		loDiploScoreObj.Score = loDiploScoreObj.Score - 100

	else
		if tostring(loDiploScoreObj.ministerTag:GetCountry():GetFaction():GetTag()) == "axis" then
			loDiploScoreObj.Score = loDiploScoreObj.Score - 100
		end
	end
	return loDiploScoreObj.Score
end

return AI_SAU