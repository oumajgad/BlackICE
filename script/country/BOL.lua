-----------------------------------------------------------
-- LUA Hearts of Iron 3 Bolivia File
-- Created By: Dr Johnson 6/8/11
-----------------------------------------------------------

local P = {}
AI_BOL = P



function P.DiploScore_InviteToFaction(loDiploScoreObj)

	if loDiploScoreObj.Year >= 1943 and loDiploScoreObj.Month >= 4 and loDiploScoreObj.Day >= 7 then

		if tostring(loDiploScoreObj.ministerTag:GetCountry():GetFaction():GetTag()) == "allies" then
			loDiploScoreObj.Score = loDiploScoreObj.Score + 100
		end

		if tostring(loDiploScoreObj.ministerTag:GetCountry():GetFaction():GetTag()) == "axis" then
			loDiploScoreObj.Score = loDiploScoreObj.Score - 100
		end

		if tostring(loDiploScoreObj.ministerTag:GetCountry():GetFaction():GetTag()) == "comintern" then
			loDiploScoreObj.Score = loDiploScoreObj.Score - 100
		end

	else

		if tostring(loDiploScoreObj.ministerTag:GetCountry():GetFaction():GetTag()) == "allies" then
			loDiploScoreObj.Score = loDiploScoreObj.Score - 100
		end

		if tostring(loDiploScoreObj.ministerTag:GetCountry():GetFaction():GetTag()) == "axis" then
			loDiploScoreObj.Score = loDiploScoreObj.Score - 100
		end

		if tostring(loDiploScoreObj.ministerTag:GetCountry():GetFaction():GetTag()) == "comintern" then
			loDiploScoreObj.Score = loDiploScoreObj.Score - 100
		end
	end
	return loDiploScoreObj.Score
end

return AI_BOL
