local P = {}
AI_PER = P

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	local loAxis = CCurrentGameState.GetFaction("axis")
	
	if voDiploScoreObj.Faction == loAxis then
		voDiploScoreObj.Score = voDiploScoreObj.Score - 40
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_OfferTrade(voDiploScoreObj)

	-- If trade involves Oil and Iran in Allies or no faction then handle it as if trading with ENG (Anglo-Persian Oil Company)
	if voDiploScoreObj.ResourceRequest["vCrudeOil"] > 0 and 
	(CCountryDataBase.GetTag("PER"):GetCountry():GetFaction() == CCurrentGameState.GetFaction("allies") or not CCountryDataBase.GetTag("ENG"):GetCountry():HasFaction()) then

		local laTrade = {
			ENG = {Score = 200},
			CAN = {Score = 20},
			AST = {Score = 20},
			SAF = {Score = 20},
			NZL = {Score = 20},
			USA = {Score = 20},
			CHI = {Score = 100},
			GER = {Score = -20},
			ITA = {Score = -20},
			JAP = {Score = 10},
			FRA = {Score = 20}}

		if laTrade[voDiploScoreObj.TagName] then
			return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score * 2
		end

	end

	return voDiploScoreObj.Score

end

return AI_PER
