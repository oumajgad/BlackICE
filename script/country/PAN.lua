-----------------------------------------------------------
-- LUA Hearts of Iron 3 Panama File
-- Created By: Dr Johnson 6/8/11
-----------------------------------------------------------

local P = {}
AI_PAN = P



function P.DiploScore_InviteToFaction(loDiploScoreObj)
	local usaTag = CCountryDataBase.GetTag("USA")

	if tostring(usaTag:GetCountry():GetFaction():GetTag()) == "allies" then

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

return AI_PAN