-----------------------------------------------------------
-- LUA Hearts of Iron 3 Ecuador File
-- Created By: Dr Johnson 04/07/11
-----------------------------------------------------------

local P = {}
AI_ECU = P



function P.DiploScore_InviteToFaction(loDiploScoreObj)

	if loDiploScoreObj.Year >= 1945 and loDiploScoreObj.Month >= 2 and loDiploScoreObj.Day >= 2 then

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

return AI_ECU